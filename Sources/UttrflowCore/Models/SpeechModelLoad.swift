// What every surface says while the speech model loads, or after it failed to. See `Docs/startup.md`.

/// The speech model's load as a person is told about it; one home for the words, so no two surfaces drift.
public enum SpeechModelLoad: Sendable, Equatable {
    /// Still loading, for this long so far.
    case loading(elapsed: Duration)
    /// The load ended without a model that can transcribe, and loading again is worth one try.
    case failed
    /// The model on disk is incomplete or failed to load twice, so only a fresh download repairs it.
    case broken
    /// There is no model on disk to load, because it was never downloaded or was removed.
    case missing

    /// How long a load runs before the minutes are mentioned, well past the two seconds a warm load takes.
    public static let estimateAfter = Duration.seconds(5)

    /// What an attempt to dictate during the load is answered with.
    public static let refusal = "Speech model still loading…"

    /// Whether the time estimate is said, which only a load past ``estimateAfter`` earns.
    public var showsEstimate: Bool {
        guard case .loading(let elapsed) = self else { return false }
        return elapsed >= Self.estimateAfter
    }

    /// The guessed progress and time left, only for a load past ``estimateAfter``.
    public var estimate: SpeechModelLoadEstimate? {
        guard case .loading(let elapsed) = self, showsEstimate else { return nil }
        return SpeechModelLoadEstimate(elapsed: elapsed)
    }

    /// Whether the load is still under way, as opposed to over and failed.
    public var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }

    /// The heading a window gives it.
    public var title: String {
        switch self {
        case .loading: "Loading the speech model…"
        case .failed: "The speech model didn’t load"
        case .broken: "The speech model is damaged"
        case .missing: "The speech model isn’t downloaded"
        }
    }

    /// The sentence under the heading, with the estimate only once the load has earned it.
    public var message: String { sentence(range: "2–3") }

    /// The floating button's first line, short enough for its one line.
    public var line: String {
        switch self {
        case .loading: "Loading speech model…"
        case .failed: "Speech model didn’t load"
        case .broken: "Speech model is damaged"
        case .missing: "Speech model not downloaded"
        }
    }

    /// The floating button's second line.
    public var detail: String {
        switch self {
        case .loading where showsEstimate: "First load after restart: about 2–3 min"
        case .loading: "Dictation starts once it’s ready"
        case .failed, .broken, .missing: "Dictation can’t start without it"
        }
    }

    /// The status beside the home page's ring.
    public var status: String {
        switch self {
        case .loading: "Loading speech model"
        case .failed: "Speech model didn’t load"
        case .broken: "Speech model is damaged"
        case .missing: "Speech model not downloaded"
        }
    }

    /// What VoiceOver reads: the heading and the sentence, with nothing only an eye can parse.
    public var accessibilityLabel: String {
        let heading = String(title.filter { $0 != "…" })
        if let estimate { return "\(heading), \(estimate.spokenTimeLeft). \(Self.whenReady)" }
        return "\(heading). \(sentence(range: "2 to 3"))"
    }

    /// The one way forward: a reload after a first failure, a download once a reload cannot help, nothing while loading.
    public var recovery: RecoveryAction? {
        switch self {
        case .loading: nil
        case .failed: .retry
        case .broken, .missing: .downloadSpeechModel
        }
    }

    private static let whenReady = "Dictation starts working as soon as it’s ready."

    /// The sentence with the minutes written as `range`, since a dash reads as nothing aloud.
    private func sentence(range: String) -> String {
        switch self {
        case .loading where showsEstimate:
            "The first load after a restart can take about \(range) minutes. \(Self.whenReady)"
        case .loading:
            Self.whenReady
        case .failed:
            "Dictation can’t start without it. Try loading it again."
        case .broken:
            "Dictation can’t start without it. Download it again to repair it."
        case .missing:
            "Dictation can’t start without it. Download it to start dictating."
        }
    }
}
