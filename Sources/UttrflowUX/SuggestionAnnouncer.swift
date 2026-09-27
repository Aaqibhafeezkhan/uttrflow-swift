import UttrflowPredict

/// Decides what VoiceOver is told about the suggestion surface: each offer, and the dot Escape leaves, once when it appears, never again on a redraw.
public struct SuggestionAnnouncer: Sendable, Equatable {
    /// What makes one offer different from another, including how much of the typing taking the leader would replace.
    private struct Offer: Sendable, Equatable {
        let candidates: [String]
        let selected: String?
        let acceptKey: AcceptKey
        let replaced: Int
    }

    /// The offer last read aloud, or nothing once the surface has gone.
    private var spoken: Offer?

    public init() {}

    /// The text to announce for what is now on screen, or nothing when it was already announced or offers no text.
    public mutating func announcement(for presentation: SuggestionPresentation) -> String? {
        let label = presentation.accessibilityLabel
        guard presentation.style != .hidden, !label.isEmpty else {
            spoken = nil
            return nil
        }
        let offer = Offer(
            candidates: presentation.rows.map(\.candidate),
            selected: presentation.inline?.candidate, acceptKey: presentation.acceptKey,
            replaced: presentation.inline?.edit.replacedCount ?? 0)
        guard offer != spoken else { return nil }
        spoken = offer
        return label
    }

    /// Forgets the last offer, so the next one is announced even if it is the same text.
    public mutating func surfaceWithdrawn() {
        spoken = nil
    }
}
