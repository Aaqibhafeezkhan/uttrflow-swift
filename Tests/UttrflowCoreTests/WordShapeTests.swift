import Testing

@testable import UttrflowCore

@Suite("WordShape")
struct WordShapeTests {
    @Test(
        "an ellipsis with no question or exclamation mark trails off",
        arguments: [
            ("...", true), ("\u{2026}", true), ("..,", true), (".", false), ("...?", false), ("", false),
        ]
    )
    func trailsOff(marks: String, expected: Bool) {
        #expect(WordShape.trailsOff(marks) == expected)
    }

    @Test(
        "a sentence cannot end on an article, a conjunction, the copula or a contracted subject",
        arguments: [
            ("the", true), ("And", true), ("is", true), ("let's", true), ("we're", true),
            ("he\u{2019}s", true),
            ("done", false), ("should", false), ("it", false), ("that", false),
        ]
    )
    func leadsOn(word: String, expected: Bool) {
        #expect(FunctionWords.leadsOn(word) == expected)
    }

    @Test(
        "puts a mark on the end of a word, replacing a clause mark already there",
        arguments: [
            ("today", "?", "today?"),
            ("today,", "?", "today?"),
            ("today.", "!", "today!"),
            ("today", "\"", "today\""),
            ("today\"", ".", "today\"."),
            ("today", "\u{2014}", "today \u{2014}"),
        ]
    )
    func marked(text: String, mark: String, expected: String) {
        #expect(WordShape.marked(text, with: mark) == expected)
    }

    @Test(
        "folds several marks on in turn, under the same rule",
        arguments: [
            ("today", "?\"", "today?\""),
            ("today,", "?", "today?"),
            // An ellipsis is three clause marks, so it ends as the one mark they collapse to.
            ("today", "...", "today."),
            ("today", "", "today"),
        ]
    )
    func markedWithSeveral(text: String, marks: String, expected: String) {
        #expect(WordShape.marked(text, withAll: marks) == expected)
    }
}
