import Foundation
import Synchronization
import UttrflowTestSupport

@testable import UttrflowPredict

/// A machine that says what a test tells it to, and counts how often it is asked.
actor StubEnvironment: EnvironmentReading {
    /// What to answer for each kind; a kind absent here is one the machine cannot read.
    private let answers: [EnvironmentKind: [String]]
    /// How long each read takes, for the tests about a machine too slow to wait for.
    private let delay: Duration?
    /// How many reads it has been asked for.
    private(set) var reads = 0

    /// A machine that answers this and takes this long over it.
    init(_ answers: [EnvironmentKind: [String]], delay: Duration? = nil) {
        self.answers = answers
        self.delay = delay
    }

    /// What it was told to answer for this kind, after whatever delay it was given.
    func values(of kind: EnvironmentKind, in directory: String) async -> [String]? {
        reads += 1
        if let delay { try? await Task.sleep(for: delay) }
        return answers[kind]
    }
}

/// A model that says what a test tells it to, and counts how often it is asked.
actor ScriptedScoring: CandidateScoring {
    /// The score to answer with, absent for a model that has no opinion.
    private let score: Double?
    /// Whether the model is up, for the tests about one still loading.
    private let loaded: Bool
    /// The clock a slow model runs past the budget on, for the tests about a model too slow to wait for.
    private let overrunning: ManualClock?
    /// How many scores it has been asked for.
    private(set) var asked = 0

    /// A model that answers this, is up or is not, and runs past the budget on `overrunning` when given one.
    init(_ score: Double?, loaded: Bool = true, overrunning: ManualClock? = nil) {
        self.score = score
        self.loaded = loaded
        self.overrunning = overrunning
    }

    /// Whether the model is up.
    var isReady: Bool { loaded }

    /// The score it was told to answer, only after the budget has run out when it is a slow one.
    func logLikelihood(of candidate: String, following context: String) async -> Double? {
        asked += 1
        if let overrunning {
            overrunning.advance(by: .seconds(3_600))
            // Cut short when the verifier stops waiting; a verifier that never stops gets the score late.
            try? await Task.sleep(for: .seconds(30))
        }
        return score
    }

    /// The same score for a line it wrote, which is what the generation gate reads.
    func confidence(ofGenerated line: String) async -> Double? { score }
}

/// Holds the task under test, filled in only after the task exists, so a double running inside it can cancel it.
final class TaskBox<Success: Sendable>: @unchecked Sendable {
    var task: Task<Success, Never>?
}

/// A model that cancels the turn's task the first time it is asked, so a test can see a loop over candidates stop.
actor CancellingScoring<Success: Sendable>: CandidateScoring {
    /// The score to answer with.
    private let score: Double?
    /// The task this candidate's scoring cancels, so nothing asked afterward is asked with the turn still current.
    private let box: TaskBox<Success>
    /// How many scores it has been asked for.
    private(set) var asked = 0

    /// A model that answers `score` and cancels the task held in `box` on its first call.
    init(_ score: Double?, cancelling box: TaskBox<Success>) {
        self.score = score
        self.box = box
    }

    var isReady: Bool { true }

    func logLikelihood(of candidate: String, following context: String) async -> Double? {
        asked += 1
        box.task?.cancel()
        return score
    }

    func confidence(ofGenerated line: String) async -> Double? { score }
}

/// A thread hold a test releases by hand, and whether it has ended yet.
final class ThreadHold: Sendable {
    private let released = DispatchSemaphore(value: 0)
    private let ended = Mutex(false)

    /// Whether the held thread has let go, by release or by running out its cap.
    var hasEnded: Bool { ended.withLock { $0 } }

    /// Lets the held thread go.
    func release() { released.signal() }

    /// Blocks the calling thread until released or until `cap` passes.
    func hold(for cap: Duration) {
        let milliseconds = Int(cap.components.seconds * 1_000)
        _ = released.wait(timeout: .now() + .milliseconds(milliseconds))
        ended.withLock { $0 = true }
    }
}

/// A model that answers this, but blocks a thread until released rather than honouring cancellation.
actor NoncooperativeScoring: CandidateScoring {
    /// The score to answer with once the hold ends.
    private let score: Double?
    /// The hold the scorer's thread waits on, which a test releases after the verdict.
    let holding: ThreadHold
    /// The longest the hold lasts unreleased, so a verifier that waits for it fails rather than hangs.
    private let cap: Duration
    /// The clock a deadline waits on, pushed past its budget the moment this is asked, as `ScriptedScoring` does.
    private let advancing: ManualClock?

    /// A model that answers `score` once `holding` is released or `cap` passes, cancellation or not.
    init(_ score: Double?, holding: ThreadHold, cap: Duration = .seconds(60), advancing: ManualClock? = nil) {
        self.score = score
        self.holding = holding
        self.cap = cap
        self.advancing = advancing
    }

    var isReady: Bool { true }

    /// Waits out the hold on a thread of its own, ignoring cancellation, so the hold starves no cooperative thread.
    func logLikelihood(of candidate: String, following context: String) async -> Double? {
        advancing?.advance(by: .seconds(3_600))
        let holding = holding
        let cap = cap
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            Thread.detachNewThread {
                holding.hold(for: cap)
                continuation.resume()
            }
        }
        return score
    }

    func confidence(ofGenerated line: String) async -> Double? { score }
}

/// A store that only remembers being told a candidate was wrong.
actor RecordingSupersession: SupersessionRecording {
    /// Each supersession as `wrong → right`.
    private(set) var recorded: [String] = []
    /// Each text condemned with nothing to put in its place.
    private(set) var rejected: [String] = []

    /// Notes one supersession without doing anything else about it.
    func recordSupersession(of text: String, by replacement: String, in surface: Surface) {
        recorded.append("\(text) → \(replacement)")
    }

    /// Notes one rejection without doing anything else about it.
    func recordRejection(of text: String, in surface: Surface) {
        rejected.append(text)
    }
}
