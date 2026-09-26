// Tests that an answer waiting for its field read never inherits the accept key armed for another line (#1766).

import Testing
import UttrflowPredict

@testable import Uttrflow

@Suite("The accept key while an answer waits to be drawn")
struct SuggestionArmedClaimTests {
    @Test("a different line lets go of the key armed for the drawn one")
    func differentLineDropsClaim() {
        #expect(!SuggestionCoordinator.keepsClaimWhileReading(armed: "see you soon", next: .certain("see you later")))
    }

    @Test("the same leader with alternatives behind it keeps the key")
    func sameLeaderKeepsClaim() {
        #expect(
            SuggestionCoordinator.keepsClaimWhileReading(
                armed: "see you soon", next: .choice(leader: "see you soon", others: ["see you later"])))
    }

    @Test("an answer arriving with nothing armed claims nothing early")
    func nothingArmedClaimsNothing() {
        #expect(!SuggestionCoordinator.keepsClaimWhileReading(armed: nil, next: .certain("see you soon")))
        #expect(SuggestionCoordinator.keepsClaimWhileReading(armed: nil, next: .silent))
    }
}
