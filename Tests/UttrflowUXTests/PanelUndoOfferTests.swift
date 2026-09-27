import Foundation
import Testing
import UttrflowClipboard

@testable import UttrflowUX

@Suite("PanelUndoOffer")
struct PanelUndoOfferTests {
    private func clip(_ text: String) -> Clip {
        Clip(text: text, kind: .text, copiedAt: Date(timeIntervalSince1970: 0), source: nil)
    }

    @Test("two overlapping deletes leave the offer describing the later one")
    func overlappingDeletes() {
        var offer = PanelUndoOffer()
        let first = clip("first")
        let second = clip("second")
        let firstTicket = offer.offer(first)
        let secondTicket = offer.offer(second)
        #expect(offer.clip == second)
        #expect(!offer.isLatest(firstTicket))
        #expect(offer.isLatest(secondTicket))
    }

    @Test("a withdrawn offer supersedes a delete still in flight")
    func withdrawSupersedes() {
        var offer = PanelUndoOffer()
        let ticket = offer.offer(clip("gone"))
        offer.withdraw()
        #expect(offer.clip == nil)
        #expect(!offer.isLatest(ticket))
    }
}
