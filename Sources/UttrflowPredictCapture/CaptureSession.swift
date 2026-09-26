// One field at a time, watched for finished values and written through every refusal.
public import UttrflowPredict

public import struct Foundation.Date

/// What came of one event, which is nothing at all almost every time.
public enum CaptureOutcome: Sendable, Equatable {
    /// Nothing was finished, so nothing was written.
    case nothing
    /// A finished value reached the corpus.
    case recorded(String)
    /// A finished value was refused before it could be written.
    case refused(CaptureRefusal)
}

/// Watches one field at a time and writes what the user finishes in it.
public actor CaptureSession {
    /// Where a finished value goes once every refusal has let it through.
    private let sink: any CaptureSink
    /// The answers about each application, kept so one given today is not asked for tomorrow.
    private let preferencesFile: CapturePreferencesFile
    /// Which endings of a field's life finish its value.
    private let policy: CommitPolicy
    /// The answers as they stand, read once at launch and written back as they change.
    private var preferences: CapturePreferences
    /// The field the events are believed to be about, until a different one is read.
    private var focused: FieldReading?
    /// Where a value is watched for being finished.
    private var detector = CommitDetector()
    /// The last value written in each surface, which is what the next one is recorded as following.
    private var lastRecorded: [Surface: String] = [:]
    /// Acceptances whose write failed, oldest first, retried before the next event or acceptance.
    private var unwrittenAcceptances: [UnwrittenAcceptance] = []
    /// The most acceptances held for a retry, beyond which the oldest is dropped.
    static let unwrittenAcceptanceLimit = 32

    /// A session writing to this sink, remembering its answers in this file.
    public init(
        sink: any CaptureSink, preferencesFile: CapturePreferencesFile, policy: CommitPolicy = .everyEnding
    ) {
        self.sink = sink
        self.preferencesFile = preferencesFile
        self.policy = policy
        preferences = preferencesFile.load()
    }

    /// Takes one event in one field and answers with what it came to.
    public func handle(_ event: CaptureEvent, in reading: FieldReading) async throws -> CaptureOutcome {
        await retryUnwrittenAcceptances()
        // The application leaving is the one still focused here, whatever field the caller last read in it.
        if case .applicationDeactivated = event, focused != reading {
            defer { focused = nil }
            return try await flush(with: event)
        }
        if focused != reading {
            _ = try await flush(with: .focusLeft(at: event.moment))
            focused = reading
        }
        guard let surface = reading.surface,
            let commit = detector.receive(event, admitting: { policy.admits($0, in: reading) })
        else { return .nothing }
        return try await write(commit, from: reading, in: surface, at: event.moment)
    }

    /// Records a completion the person took, through the same refusals as anything they typed.
    public func accepted(
        _ text: String, in reading: FieldReading, at moment: Date
    ) async throws -> CaptureOutcome {
        guard let surface = reading.surface else { return .nothing }
        if let refusal = CaptureGate.refusal(toRecord: text, from: reading, given: preferences) {
            return .refused(refusal)
        }
        await retryUnwrittenAcceptances()
        if focused == reading { detector.accepted(text) }
        let acceptance = UnwrittenAcceptance(
            text: text, surface: surface, previous: lastRecorded[surface], moment: moment)
        lastRecorded[surface] = text
        do {
            try await write(acceptance)
        } catch let failure as AcceptanceWriteFailure {
            hold(failure.remaining)
            throw failure.underlying
        }
        return .recorded(text)
    }

    /// How many acceptances are waiting for their write to be retried.
    public func unwrittenAcceptanceCount() -> Int { unwrittenAcceptances.count }

    /// Writes an acceptance's line and then its count, skipping the line when it already landed.
    private func write(_ acceptance: UnwrittenAcceptance) async throws {
        var remaining = acceptance
        do {
            // Recorded before the acceptance is counted, so a new line's first acceptance is not lost.
            if !remaining.lineRecorded {
                try await sink.record(
                    remaining.text, in: remaining.surface, after: remaining.previous, selfSourced: true,
                    at: remaining.moment)
                remaining.lineRecorded = true
            }
            try await sink.recordAccepted(remaining.text, in: remaining.surface)
        } catch {
            throw AcceptanceWriteFailure(remaining: remaining, underlying: error)
        }
    }

    /// Keeps a failed acceptance for a retry, dropping the oldest past the limit.
    private func hold(_ acceptance: UnwrittenAcceptance) {
        unwrittenAcceptances.append(acceptance)
        if unwrittenAcceptances.count > Self.unwrittenAcceptanceLimit { unwrittenAcceptances.removeFirst() }
    }

    /// Retries held acceptances in order, stopping at the first that fails again.
    private func retryUnwrittenAcceptances() async {
        while let next = unwrittenAcceptances.first {
            do {
                try await write(next)
                unwrittenAcceptances.removeFirst()
            } catch let failure as AcceptanceWriteFailure {
                unwrittenAcceptances[0] = failure.remaining
                return
            } catch {
                return
            }
        }
    }

    /// What the user has decided about capture so far.
    public func decisions() -> CapturePreferences { preferences }

    /// Records the user's answer about one application and keeps it for the next launch.
    public func record(_ state: ConsentState, for bundleIdentifier: String) throws {
        preferences.record(state, for: bundleIdentifier)
        try preferencesFile.save(preferences)
    }

    /// Forgets every answer, in memory and on disk, so a reset is not undone by the next one recorded.
    public func forgetEveryAnswer() throws {
        preferences = CapturePreferences()
        try preferencesFile.remove()
    }

    /// Forgets what this session holds about one application, so its next line does not follow a forgotten one.
    public func forgetLearned(from bundleIdentifier: String) {
        let application = Surface(bundleIdentifier: bundleIdentifier, role: "").bundleIdentifier
        lastRecorded = lastRecorded.filter { $0.key.bundleIdentifier != application }
        unwrittenAcceptances.removeAll { $0.surface.bundleIdentifier == application }
        if focused?.surface?.bundleIdentifier == application { detector.reset() }
    }

    /// Forgets every line and answer this session holds, in memory and on disk.
    public func forgetEverythingLearned() throws {
        lastRecorded = [:]
        unwrittenAcceptances = []
        detector.reset()
        try forgetEveryAnswer()
    }

    /// Seeds a terminal from the shell's history, once, and only because the user asked for it.
    public func importShellHistory(
        forHomeDirectory home: String, into surface: Surface, at moment: Date
    ) async throws -> Int {
        guard !preferences.hasImportedShellHistory else { return 0 }
        preferences.hasImportedShellHistory = true
        try preferencesFile.save(preferences)
        for path in ShellHistory.paths(inHomeDirectory: home) {
            let commands = ShellHistory.read(atPath: path)
            guard !commands.isEmpty else { continue }
            var stored = 0
            for command in commands where !DestructiveCommand.matches(command, failClosedOnUnresolved: true) {
                try await sink.record(
                    command, in: surface, after: nil, selfSourced: false, at: moment)
                stored += 1
            }
            return stored
        }
        return 0
    }

    /// Ends the focused field with this event, so a half-finished value is not lost.
    private func flush(with ending: CaptureEvent) async throws -> CaptureOutcome {
        defer { detector.reset() }
        guard let leaving = focused, let surface = leaving.surface,
            let commit = detector.receive(ending, admitting: { policy.admits($0, in: leaving) })
        else { return .nothing }
        return try await write(commit, from: leaving, in: surface, at: ending.moment)
    }

    /// Puts a finished value the policy admitted through every refusal and then into the corpus.
    private func write(
        _ commit: Commit, from reading: FieldReading, in surface: Surface, at moment: Date
    ) async throws -> CaptureOutcome {
        if let refusal = CaptureGate.refusal(
            toRecord: commit.text, from: reading, given: preferences)
        {
            // Forgotten, so a refused value is never later handed to the sink as the one replaced.
            detector.forgetLastIdleCommit()
            return .refused(refusal)
        }
        do {
            if let superseded = commit.supersedes,
                CaptureGate.refusal(toRecord: superseded, from: reading, given: preferences) == nil
            {
                try await sink.supersede(superseded, with: commit.text, in: surface)
            }
            try await sink.record(
                commit.text, in: surface, after: lastRecorded[surface], selfSourced: false, at: moment)
        } catch {
            detector.forgetLastIdleCommit()
            throw error
        }
        lastRecorded[surface] = commit.text
        return .recorded(commit.text)
    }
}

/// An acceptance the corpus has not fully taken yet, and how far its write got.
struct UnwrittenAcceptance: Sendable {
    /// The completion the person took.
    let text: String
    /// Where it was taken.
    let surface: Surface
    /// The line it followed when it was taken.
    let previous: String?
    /// When it was taken.
    let moment: Date
    /// True once the line itself is in the corpus, so a retry only counts the acceptance.
    var lineRecorded = false
}

/// A failed acceptance write, carrying what is left of it to retry.
private struct AcceptanceWriteFailure: Error {
    /// The acceptance as far as it got.
    let remaining: UnwrittenAcceptance
    /// What the sink threw.
    let underlying: any Error
}
