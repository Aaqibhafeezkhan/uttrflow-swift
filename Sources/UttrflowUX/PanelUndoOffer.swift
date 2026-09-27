// Tracks which delete the panel's undo offer describes, so an older delete finishing late cannot claim it.
public import UttrflowClipboard

/// The one delete that can be undone, and a count of deletes so a late one can tell it was superseded.
public struct PanelUndoOffer: Sendable, Equatable {
    /// The clip the undo offer restores, or nil when there is nothing to undo.
    public private(set) var clip: Clip?
    /// How many deletes have been offered; each delete's ticket is the value it saw.
    public private(set) var deletes = 0

    /// An empty offer.
    public init() {}

    /// Offers `clip` as the undo for a delete starting now and returns that delete's ticket.
    public mutating func offer(_ clip: Clip?) -> Int {
        deletes += 1
        self.clip = clip
        return deletes
    }

    /// Whether the delete holding `ticket` is still the one the offer describes.
    public func isLatest(_ ticket: Int) -> Bool { ticket == deletes }

    /// Withdraws the offer; a delete still in flight is superseded by it.
    public mutating func withdraw() {
        deletes += 1
        clip = nil
    }
}
