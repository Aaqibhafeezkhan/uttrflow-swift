// Tests that VoiceOver hears each AI suggestion once, as it appears, with the key that takes it.

import Testing
import UttrflowPredict

@testable import UttrflowUX

@Suite("Suggestion announcer")
struct SuggestionAnnouncerTests {
    @Test("A single completion is announced with its accept key")
    func aCompletionIsAnnounced() {
        var announcer = SuggestionAnnouncer()
        #expect(
            announcer.announcement(for: SuggestionPresentation(.certain("Sydney")))
                == "AI suggestion: Sydney. Tab to accept.")
    }

    @Test("A replacement is announced with how much of the user's typing it takes back")
    func aReplacementIsAnnounced() {
        var announcer = SuggestionAnnouncer()
        #expect(
            announcer.announcement(for: SuggestionPresentation(.certain("git commit -m"), typed: "gti c"))
                == "AI suggestion: git commit -m. Tab to accept, replacing 4 characters.")
    }

    @Test("A list is announced with its alternatives")
    func aListIsAnnounced() {
        var announcer = SuggestionAnnouncer()
        #expect(
            announcer.announcement(
                for: SuggestionPresentation(.choice(leader: "Sydney", others: ["Sydenham", "Soho"])))
                == "AI suggestion: Sydney. Tab to accept. Alternatives: Sydenham, Soho.")
    }

    @Test("The field's own accept key is the one announced")
    func theFieldsAcceptKeyIsAnnounced() {
        var announcer = SuggestionAnnouncer()
        #expect(
            announcer.announcement(
                for: SuggestionPresentation(.certain("ls -l"), typed: "ls ", acceptKey: .rightArrow))
                == "AI suggestion: ls -l. Right Arrow to accept.")
    }

    @Test("The dot Escape leaves is labelled and announced once")
    func theDotIsAnnouncedOnce() {
        var announcer = SuggestionAnnouncer()
        let dot = SuggestionPresentation(.minimised)
        #expect(dot.accessibilityLabel == SuggestionPresentation.dotLabel)
        #expect(announcer.announcement(for: SuggestionPresentation(.certain("Sydney"))) != nil)
        #expect(announcer.announcement(for: dot) == SuggestionPresentation.dotLabel)
        #expect(announcer.announcement(for: dot) == nil)
    }

    @Test("A redraw of the same offer, or typing that keeps its cost, is not announced again")
    func aRedrawIsSilent() {
        var announcer = SuggestionAnnouncer()
        #expect(announcer.announcement(for: SuggestionPresentation(.certain("Sydney"))) != nil)
        #expect(announcer.announcement(for: SuggestionPresentation(.certain("Sydney"))) == nil)
        #expect(announcer.announcement(for: SuggestionPresentation(.certain("Sydney"), typed: "Syd")) == nil)
        #expect(
            announcer.announcement(for: SuggestionPresentation(.certain("git commit -m"), typed: "gti c"))
                != nil)
        #expect(
            announcer.announcement(for: SuggestionPresentation(.certain("git commit -m"), typed: "gti co"))
                == "AI suggestion: git commit -m. Tab to accept, replacing 5 characters.")
    }

    @Test("The same leader is announced again when taking it would replace a different amount")
    func aChangedCostIsAnnounced() {
        var announcer = SuggestionAnnouncer()
        #expect(
            announcer.announcement(for: SuggestionPresentation(.certain("git commit -m"), typed: "git"))
                != nil)
        #expect(
            announcer.announcement(for: SuggestionPresentation(.certain("git commit -m"), typed: "gti c"))
                == "AI suggestion: git commit -m. Tab to accept, replacing 4 characters.")
    }

    @Test("A different offer is announced")
    func aNewOfferIsAnnounced() {
        var announcer = SuggestionAnnouncer()
        _ = announcer.announcement(for: SuggestionPresentation(.certain("Sydney")))
        #expect(
            announcer.announcement(for: SuggestionPresentation(.certain("Soho")))
                == "AI suggestion: Soho. Tab to accept.")
    }

    @Test("Moving the highlight announces the row Tab now takes")
    func movingTheHighlightIsAnnounced() {
        var announcer = SuggestionAnnouncer()
        let choice = Suggestion.choice(leader: "Sydney", others: ["Sydenham", "Soho"])
        _ = announcer.announcement(for: SuggestionPresentation(choice))
        #expect(
            announcer.announcement(
                for: SuggestionPresentation(choice, selection: SuggestionSelection(index: 2, hasMoved: true)))
                == "AI suggestion: Soho. Tab to accept. Alternatives: Sydney, Sydenham.")
    }

    @Test("Nothing is never announced, and neither it nor the dot stops the next offer being heard")
    func nothingIsSilentAndResets() {
        var announcer = SuggestionAnnouncer()
        _ = announcer.announcement(for: SuggestionPresentation(.certain("Sydney")))
        #expect(
            announcer.announcement(for: SuggestionPresentation(.minimised)) == SuggestionPresentation.dotLabel
        )
        #expect(announcer.announcement(for: SuggestionPresentation(.certain("Sydney"))) != nil)
        #expect(announcer.announcement(for: SuggestionPresentation(.silent)) == nil)
        #expect(announcer.announcement(for: SuggestionPresentation(.certain("Sydney"))) != nil)
    }

    @Test("A withdrawn surface lets the same offer be announced when it comes back")
    func withdrawalResets() {
        var announcer = SuggestionAnnouncer()
        _ = announcer.announcement(for: SuggestionPresentation(.certain("Sydney")))
        announcer.surfaceWithdrawn()
        #expect(announcer.announcement(for: SuggestionPresentation(.certain("Sydney"))) != nil)
    }
}
