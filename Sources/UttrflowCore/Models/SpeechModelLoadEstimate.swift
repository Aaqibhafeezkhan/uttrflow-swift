// A guess at how far the speech model's load has got, from its elapsed time alone. See `Docs/startup.md`.

/// How far a load has probably got and how long it probably has left, paced to a typical cold load.
public struct SpeechModelLoadEstimate: Sendable, Equatable {
    /// How long a cold load after a restart typically runs; the one number that paces the estimate. See `Docs/startup.md`.
    public static let typicalColdLoad = Duration.seconds(150)

    /// The share the bar eases towards and holds at until the model is really ready.
    public static let ceiling = 0.9

    /// How often a surface redraws the estimate while a load runs.
    public static let redrawInterval = Duration.seconds(1)

    /// More than this left reads as about two minutes.
    public static let twoMinutesAbove = Duration.seconds(90)

    /// More than this left reads as about one minute, and anything less as under a minute.
    public static let oneMinuteAbove = Duration.seconds(45)

    /// How long the load has run, never negative.
    public let elapsed: Duration

    /// An estimate for a load that has run this long.
    public init(elapsed: Duration) {
        self.elapsed = max(elapsed, .zero)
    }

    /// The share to fill: easing out from zero to ``ceiling`` over ``typicalColdLoad``, then holding.
    public var fraction: Double {
        let progress = min(Self.seconds(in: elapsed) / Self.seconds(in: Self.typicalColdLoad), 1)
        let rest = 1 - progress
        return Self.ceiling * (1 - rest * rest)
    }

    /// Whether the typical load time has passed, so the bar holds at ``ceiling`` until the model is ready.
    public var isHolding: Bool { elapsed >= Self.typicalColdLoad }

    /// How long a typical cold load still has to run, zero once holding.
    public var remaining: Duration { isHolding ? .zero : Self.typicalColdLoad - elapsed }

    /// "about 2 min left", "about 1 min left", "less than a minute left", or "almost ready".
    public var timeLeft: String {
        switch band {
        case .twoMinutes: "about 2 min left"
        case .oneMinute: "about 1 min left"
        case .underAMinute: "less than a minute left"
        case .holding: "almost ready"
        }
    }

    /// The floating button's form: "~2 min", "~1 min", "<1 min", or "almost".
    public var shortTimeLeft: String {
        switch band {
        case .twoMinutes: "~2 min"
        case .oneMinute: "~1 min"
        case .underAMinute: "<1 min"
        case .holding: "almost"
        }
    }

    /// What VoiceOver reads, with the minutes written out and no symbol standing for a word.
    public var spokenTimeLeft: String {
        switch band {
        case .twoMinutes: "about 2 minutes left"
        case .oneMinute: "about 1 minute left"
        case .underAMinute: "less than a minute left"
        case .holding: "almost ready"
        }
    }

    /// The status heading: "Getting ready · about 1 min left", or "Almost ready…" while holding.
    public var heading: String {
        isHolding ? "Almost ready…" : "Getting ready · \(timeLeft)"
    }

    /// The heading as VoiceOver reads it: "Getting ready, about 1 minute left", or "Almost ready".
    public var spokenHeading: String {
        isHolding ? "Almost ready" : "Getting ready, \(spokenTimeLeft)"
    }

    /// Which of the four phrases the time left falls in.
    private var band: Band {
        let left = remaining
        if isHolding { return .holding }
        if left > Self.twoMinutesAbove { return .twoMinutes }
        if left > Self.oneMinuteAbove { return .oneMinute }
        return .underAMinute
    }

    private enum Band {
        case twoMinutes
        case oneMinute
        case underAMinute
        case holding
    }

    /// A duration in seconds, with its fraction kept.
    private static func seconds(in duration: Duration) -> Double {
        let parts = duration.components
        return Double(parts.seconds) + Double(parts.attoseconds) / 1e18
    }
}
