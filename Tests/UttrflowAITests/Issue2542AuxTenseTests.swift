import Foundation
import Testing

@testable import UttrflowAI
@testable import UttrflowCore

/// Issue 2542 follow-up: tense-carrying aux pairs (is/was, will/would, has/had) are not interchange on a rewrite, so the survival check refuses them as lost words rather than letting them fall under the functionWordChurn cap.
@Suite("Issue 2542 aux tense pairs count as changed words")
struct Issue2542AuxTenseTests {
    /// The guard under test.
    private let sut = MeaningPreservationGuard()

    private func verdict(_ kept: String, _ rewritten: String) -> GuardVerdict {
        sut.verdict(draft: Draft(text: kept), rewritten: rewritten)
    }

    @Test(
        "rejects a copula swap (is <-> was, are <-> were)",
        arguments: [
            ("the cat was black", "the cat is black", "is -> was"),
            ("the cat is black", "the cat was black", "was -> is"),
            ("they were ready", "they are ready", "are -> were"),
            ("they are ready", "they were ready", "were -> are"),
        ]
    )
    func rejectsCopulaSwap(kept: String, rewritten: String, hint: Comment) {
        let v = verdict(kept, rewritten)
        #expect(!v.isAccepted, hint)
    }

    @Test(
        "rejects a perfect aux swap (have/has/had)",
        arguments: [
            ("i have notes", "i has notes", "have -> has"),
            ("i have notes", "i had notes", "have -> had"),
            ("she has a plan", "she had a plan", "has -> had"),
        ]
    )
    func rejectsPerfectAuxSwap(kept: String, rewritten: String, hint: Comment) {
        let v = verdict(kept, rewritten)
        #expect(!v.isAccepted, hint)
    }

    /// A single article repair (`a -> an`) swaps a function word but stays under the churn cap, so a content-word change is still the reason for any rejection here.
    @Test(
        "still accepts an article repair only",
        arguments: [
            ("can you pass me a apple from the bowl", "Can you pass me an apple from the bowl?")
        ]
    )
    func acceptsArticleRepair(kept: String, rewritten: String) {
        #expect(verdict(kept, rewritten).isAccepted)
    }
}
