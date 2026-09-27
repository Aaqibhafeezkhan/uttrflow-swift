// Tests for what an empty page draws above its title.
import Foundation
import Testing

@testable import UttrflowUX

@Suite("What an empty page draws above its title")
struct MainEmptySceneTests {
    /// Each page's own symbol picks its scene, so no presenter has to name one.
    @Test("each page's symbol picks the scene the design gives that page")
    func scenesFollowTheSymbol() {
        #expect(MainEmptyScene(symbolName: "mic") == .dictation)
        #expect(MainEmptyScene(symbolName: "clock") == .dictation)
        #expect(MainEmptyScene(symbolName: "waveform") == .dictation)
        #expect(MainEmptyScene(symbolName: "character.book.closed") == .word(MainEmptyScene.exampleWord))
        #expect(MainEmptyScene(symbolName: "book") == .word("Uttrflow"))
        #expect(MainEmptyScene(symbolName: "doc.on.doc") == .phrase(MainEmptyScene.examplePhrase))
        #expect(MainEmptyScene(symbolName: "chart.bar") == .chart)
        #expect(MainEmptyScene(symbolName: "hand.raised") == .symbol)
    }

    @Test("each scene glows in its page's colour")
    func scenesKeepTheirPagesColour() {
        #expect(MainEmptyScene.dictation.accent == .dictation)
        #expect(MainEmptyScene.symbol.accent == .dictation)
        #expect(MainEmptyScene.word("x").accent == .clipboard)
        #expect(MainEmptyScene.phrase("x").accent == .suggestion)
        #expect(MainEmptyScene.chart.accent == .info)
    }

    @Test("an empty state takes its scene from its symbol unless it is given one")
    func emptyStateScene() {
        #expect(MainEmptyState(symbolName: "clock", title: "T", message: "M").scene == .dictation)
        let given = MainEmptyState(symbolName: "clock", title: "T", message: "M", scene: .chart)
        #expect(given.scene == .chart)
    }

    @Test("progress counted in steps says how many are done, and a nonsense count is dropped")
    func progressSteps() {
        let three = MainProgress(fraction: 3.0 / 5.0, leading: "3 of 5", trailing: "Soon", steps: 5)
        #expect(three.steps == 5)
        #expect(three.stepsDone == 3)
        let uncounted = MainProgress(fraction: 0.5, leading: "", trailing: "")
        #expect(uncounted.steps == nil)
        #expect(uncounted.stepsDone == 0)
        #expect(MainProgress(fraction: 0.5, leading: "", trailing: "", steps: 0).steps == nil)
    }
}
