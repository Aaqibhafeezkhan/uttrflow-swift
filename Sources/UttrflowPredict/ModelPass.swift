/// What the model has already said about the line, and whether it should be asked again.
public struct ModelPass: Sendable {
    /// What the model does on this turn for a line.
    public enum Plan: Sendable, Equatable {
        /// An earlier answer still begun by the line is drawn without a pass.
        case reuse([String])
        /// The model's last word on this exact line was nothing, so no pass is run.
        case skip
        /// A fresh pass is run.
        case ask
    }

    /// Where the alternatives behind a single drawn line come from.
    public enum AlternativesSource: Sendable, Equatable {
        /// The machine's other values, with no pass spent on them.
        case values([String])
        /// A second model pass.
        case model
    }

    /// The last answer that stood, with the field, the line and the text before the line it was asked on.
    public private(set) var lastGenerated:
        (surface: Surface, typed: String, place: String?, completions: [String])?
    /// The last line whose pass came back empty or failed, and the text before it.
    public private(set) var lastEmpty: (surface: Surface, typed: String, place: String?)?

    /// Nothing remembered.
    public init() {}

    /// Whether the model is asked at all, given what the corpus and gates settled on.
    public static func shouldAsk(after update: SuggestionUpdate, hasGenerator: Bool, isReady: Bool) -> Bool {
        update.suggestion.accepting == nil && update.silence != .overBudget && hasGenerator && isReady
    }

    /// Whether an answer that took a while is still fresh enough to draw against the field read now.
    public static func isFresh(
        keystrokesBefore: Int, keystrokesNow: Int, isCurrent: Bool, sameReading: Bool, sameLine: Bool
    ) -> Bool {
        keystrokesBefore == keystrokesNow && isCurrent && sameReading && sameLine
    }

    /// Where the alternatives come from: the machine's values when it listed any, otherwise the model.
    public static func alternativesSource(
        typed: String, choices: [String], leader: String
    ) -> AlternativesSource {
        guard !choices.isEmpty else { return .model }
        return .values(Verification.completed(typed, with: choices).filter { $0 != leader })
    }

    /// Forgets both memories on a new field or an emptied line.
    public mutating func freshStart(surfaceChanged: Bool, lineIsEmpty: Bool) {
        guard surfaceChanged || lineIsEmpty else { return }
        lastGenerated = nil
        lastEmpty = nil
    }

    /// Forgets the last answer unless this line types on from the one it was given for, in the same place.
    public mutating func follow(_ query: SuggestionQuery, at place: String?) {
        guard let last = lastGenerated, !Self.typesOn(query, at: place, from: last) else { return }
        lastGenerated = nil
    }

    /// What to do for this query: reuse an answer the line types on from, skip a line known empty here, or ask.
    public func plan(for query: SuggestionQuery, at place: String?) -> Plan {
        let lowered = query.typed.lowercased()
        let kept =
            lastGenerated.flatMap { Self.typesOn(query, at: place, from: $0) ? $0.completions : nil }?
            .filter { $0.lowercased().hasPrefix(lowered) && $0 != query.typed } ?? []
        if !kept.isEmpty { return .reuse(kept) }
        if let lastEmpty, lastEmpty.surface == query.surface, lastEmpty.typed == query.typed,
            lastEmpty.place == place
        {
            return .skip
        }
        return .ask
    }

    /// Whether the line is the answered one typed forward, in the same field and after the same text.
    private static func typesOn(
        _ query: SuggestionQuery, at place: String?,
        from last: (surface: Surface, typed: String, place: String?, completions: [String])
    ) -> Bool {
        last.surface == query.surface && last.place == place && query.typed.hasPrefix(last.typed)
    }

    /// Remembers that this exact line came back empty or failed here, so a tick does not repeat it.
    public mutating func rememberEmpty(_ query: SuggestionQuery, at place: String?) {
        lastEmpty = (query.surface, query.typed, place)
    }

    /// Remembers what stood of an answer, or the line as empty when nothing did.
    public mutating func remember(_ standing: [String], for query: SuggestionQuery, at place: String?) {
        if standing.isEmpty {
            rememberEmpty(query, at: place)
        } else {
            lastGenerated = (query.surface, query.typed, place, standing)
        }
    }
}
