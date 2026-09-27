// Turns the pipeline's state into what the floating button draws.
public import UttrflowCore

/// What the floating button should show.
public struct DockPresentation: Sendable, Equatable {
    /// SF Symbol for the resting and hovered forms.
    public let symbolName: String
    /// The line of text beside it, if any. Absent when the button is a bare grip.
    public let primaryLine: String?
    /// The quieter second line — what was inserted, or why nothing was.
    public let secondaryLine: String?
    public let showsWaveform: Bool
    public let showsProgress: Bool
    /// Whether a recording indicator should be lit.
    public let isRecording: Bool
    /// Offered alongside a failure the user can do something about.
    public let action: RecoveryAction?
    /// Read aloud by VoiceOver. Never abbreviated, never an icon name.
    public let accessibilityLabel: String
    /// The speech model's setup, drawn in its own form while the button rests; absent once it can transcribe.
    public var setup: DockModelSetup? = nil
}

/// The speech model's state as the resting button draws it.
public enum DockModelSetup: Sendable, Equatable {
    /// Downloading, at a share from 0 to 1.
    case downloading(Double)
    /// On disk and loading into memory.
    case loading
    /// The load ended without a model that can transcribe.
    case failed
    /// Not on disk.
    case missing

    /// The words on the form's one button, or `nil` for a form with nothing to press.
    public var actionTitle: String? {
        switch self {
        case .downloading, .loading: nil
        case .failed: "Retry"
        case .missing: "Download"
        }
    }

    /// A share as a whole percentage, clamped to 0 through 100.
    public static func percentage(of fraction: Double) -> Int {
        Int((min(max(fraction, 0), 1) * 100).rounded())
    }
}

/// What the user has to do, or does not, to end a recording that is already under way.
public enum StopGesture: Sendable, Equatable {
    /// Hold-to-talk: releasing the keys ends the recording.
    case letGo
    /// Press-to-toggle: pressing the shortcut again ends the recording; releasing does not.
    case pressAgain
    /// A hold-to-talk double tap left the microphone open, so pressing the shortcut again ends it.
    case pressAgainHandsFree

    /// The visible instruction, in the words the dock can fit beside the waveform.
    var recordingLine: String {
        switch self {
        case .letGo: "Let go to finish"
        case .pressAgain: "Press shortcut to finish"
        case .pressAgainHandsFree: "Hands-free — press shortcut to finish"
        }
    }

    /// What VoiceOver reads before the optional countdown.
    var recordingAccessibilityPrefix: String {
        switch self {
        case .letGo: "Listening. Let go to finish"
        case .pressAgain: "Listening. Press the shortcut again to finish"
        case .pressAgainHandsFree: "Listening. Hands-free. Press the shortcut again to finish"
        }
    }
}

/// Turns the pipeline's state into what the floating button draws; never names an engine (§16).
public enum DictationPresenter {
    /// The microphone time as "0:04" or "1:23"; minutes keep counting past an hour, never rolling over.
    public static func elapsed(_ duration: Duration) -> String {
        let seconds = max(Int(duration.components.seconds), 0)
        return "\(seconds / 60):\(String(format: "%02d", seconds % 60))"
    }

    /// A passing notice about something other than a dictation, drawn like an outcome: words, no waveform, no action.
    public static func dock(
        notice symbolName: String, primaryLine: String, secondaryLine: String?,
        accessibilityLabel: String
    ) -> DockPresentation {
        DockPresentation(
            symbolName: symbolName, primaryLine: primaryLine, secondaryLine: secondaryLine,
            showsWaveform: false, showsProgress: false, isRecording: false, action: nil,
            accessibilityLabel: accessibilityLabel)
    }

    public static func dock(
        for state: DictationState, advice: DictationAdvice = .keepGoing,
        stopGesture: StopGesture = .letGo
    ) -> DockPresentation {
        switch state {
        case .idle:
            DockPresentation(
                symbolName: "mic", primaryLine: nil, secondaryLine: nil,
                showsWaveform: false, showsProgress: false, isRecording: false, action: nil,
                accessibilityLabel: "Uttrflow. Ready to listen.")

        case .recording:
            DockPresentation(
                // Says what to do, not what is happening: the waveform already says it is listening.
                symbolName: "mic.fill", primaryLine: stopGesture.recordingLine,
                secondaryLine: RemainingTime.phrase(for: advice),
                showsWaveform: true, showsProgress: false, isRecording: true, action: nil,
                accessibilityLabel: RemainingTime.phrase(for: advice)
                    .map { "\(stopGesture.recordingAccessibilityPrefix). \($0)." }
                    ?? "\(stopGesture.recordingAccessibilityPrefix).")

        // Transcribing, tidying and the wait for the app to take the words are one wait, so one line.
        case .transcribing, .tidying, .inserting:
            DockPresentation(
                symbolName: "sparkles", primaryLine: "Tidying up…", secondaryLine: nil,
                showsWaveform: false, showsProgress: true, isRecording: false, action: nil,
                accessibilityLabel: "Working on what you said.")

        case .inserted(let outcome) where outcome.method == .clipboard && outcome.isFromRecording:
            DockPresentation(
                symbolName: "doc.on.clipboard", primaryLine: "Copied — press ⌘V",
                secondaryLine: outcome.wordsToKeep.map { preview(of: $0) },
                showsWaveform: false, showsProgress: false, isRecording: false, action: nil,
                accessibilityLabel: "Copied to the clipboard. Press Command V to paste it. \(said(outcome))")

        case .inserted(let outcome) where outcome.method == .clipboard:
            // Nothing was typed, and saying "Inserted" here is what tells the user to press ⌘V.
            DockPresentation(
                symbolName: "doc.on.clipboard", primaryLine: "Copied — press ⌘V",
                secondaryLine: outcome.wordsToKeep.map { preview(of: $0) },
                showsWaveform: false, showsProgress: false, isRecording: false,
                action: .openSystemSettings(.accessibility),
                accessibilityLabel:
                    "Copied to the clipboard, not typed. Press Command V to paste it. "
                    + "Uttrflow needs Accessibility access to type for you. \(said(outcome))")

        case .inserted(let outcome) where outcome.arrival == .unconfirmed:
            // The instruction is worth more than the glance here, since the words are still recoverable.
            DockPresentation(
                symbolName: "questionmark.circle", primaryLine: "Inserted — not confirmed",
                secondaryLine: "Still on the clipboard — press ⌘V if it is missing",
                showsWaveform: false, showsProgress: false, isRecording: false, action: nil,
                accessibilityLabel:
                    "Inserted, but not confirmed. The words are still on the clipboard, so press "
                    + "Command V if they are missing. \(said(outcome))")

        case .inserted(let outcome):
            DockPresentation(
                symbolName: "checkmark", primaryLine: "Inserted",
                secondaryLine: outcome.wordsToKeep.map { preview(of: $0) },
                showsWaveform: false, showsProgress: false, isRecording: false, action: nil,
                accessibilityLabel: "Inserted: \(said(outcome))")

        // Drawn wide with its words, not as the quiet disc the other informational notice gets.
        case .failed(let failure) where failure == .stillLoading:
            DockPresentation(
                symbolName: "hourglass", primaryLine: failure.message, secondaryLine: nil,
                showsWaveform: false, showsProgress: false, isRecording: false, action: nil,
                accessibilityLabel: failure.message.filter { $0 != "…" } + ".")

        case .failed(let failure):
            DockPresentation(
                // "Didn't catch that" is not an alarm, so the badge follows the softer severity.
                symbolName: failure.severity == .informational
                    ? "waveform.slash" : "exclamationmark.triangle",
                primaryLine: failure.message,
                secondaryLine: failure.wordsToKeep.map { Self.preview(of: $0) },
                showsWaveform: false, showsProgress: false, isRecording: false,
                action: failure.recovery,
                accessibilityLabel: failure.message)
        }
    }

    /// The button with the speech model's download or load drawn in where it would otherwise rest or fall silent.
    public static func dock(
        for state: DictationState, advice: DictationAdvice = .keepGoing, speechModel: SpeechModelLoad?,
        download: Double? = nil, stopGesture: StopGesture = .letGo
    ) -> DockPresentation {
        let drawn = dock(for: state, advice: advice, stopGesture: stopGesture)
        if case .idle = state, let download { return resting(downloading: download) }
        guard let load = speechModel else { return drawn }
        switch state {
        case .idle:
            return resting(load)
        case .failed(let failure) where failure.transcript == nil && load != .missing:
            // The failure keeps its own line and button; the second line says why dictation cannot start.
            return DockPresentation(
                symbolName: drawn.symbolName, primaryLine: drawn.primaryLine,
                secondaryLine: load.detail, showsWaveform: false, showsProgress: false,
                isRecording: false, action: drawn.action,
                accessibilityLabel: failure == .stillLoading
                    ? load.accessibilityLabel : "\(drawn.accessibilityLabel) \(load.accessibilityLabel)")
        case .recording, .transcribing, .tidying, .inserting, .inserted, .failed:
            return drawn
        }
    }

    /// Resting while the speech model downloads: a ring filling to the share done.
    static func resting(downloading fraction: Double) -> DockPresentation {
        let percent = DockModelSetup.percentage(of: fraction)
        return DockPresentation(
            symbolName: "arrow.down.circle", primaryLine: "Setting up", secondaryLine: "\(percent)%",
            showsWaveform: false, showsProgress: false, isRecording: false, action: nil,
            accessibilityLabel: "Setting up. Downloading the speech model, \(percent) percent.",
            setup: .downloading(min(max(fraction, 0), 1)))
    }

    /// Resting while the speech model loads, after it failed to, or while it is not on disk.
    static func resting(_ load: SpeechModelLoad) -> DockPresentation {
        switch load {
        case .loading:
            // The estimate stays in the words read aloud and under the pointer; the capsule says only this.
            DockPresentation(
                symbolName: "hourglass", primaryLine: "Getting ready…",
                secondaryLine: load.showsEstimate ? load.detail : nil,
                showsWaveform: false, showsProgress: false, isRecording: false, action: nil,
                accessibilityLabel: load.accessibilityLabel, setup: .loading)
        case .failed:
            DockPresentation(
                symbolName: "exclamationmark.triangle", primaryLine: load.line, secondaryLine: load.detail,
                showsWaveform: false, showsProgress: false, isRecording: false, action: .retry,
                accessibilityLabel:
                    "The speech model didn’t load. Dictation can’t start without it. Try loading it again.",
                setup: .failed)
        case .missing:
            DockPresentation(
                symbolName: "exclamationmark.triangle", primaryLine: "Speech model needed",
                secondaryLine: load.detail, showsWaveform: false, showsProgress: false,
                isRecording: false, action: .downloadSpeechModel,
                accessibilityLabel: load.accessibilityLabel, setup: .missing)
        }
    }

    /// The words read aloud with the notice, withheld when the field they went into is secure.
    static func said(_ outcome: DictationOutcome) -> String {
        outcome.wordsToKeep ?? "The words are hidden because the field is secure."
    }

    /// A glance at the text, since the floating button sits over the user's work.
    static func preview(of text: String, limit: Int = 60) -> String {
        let collapsed = text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        guard collapsed.count > limit else { return collapsed }
        return collapsed.prefix(limit).trimmingSuffixWhitespace() + "…"
    }
}

extension Substring {
    fileprivate func trimmingSuffixWhitespace() -> String {
        String(reversed().drop(while: \.isWhitespace).reversed())
    }
}
