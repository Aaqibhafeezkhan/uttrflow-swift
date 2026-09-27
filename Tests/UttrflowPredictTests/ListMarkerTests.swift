// Tests that a list line holding only its marker asks nothing, and that the item after it does.

import Testing

@testable import UttrflowPredict

/// A notes field, which continues a list on Return.
private let notes = Surface(bundleIdentifier: "com.example.notes", role: "AXTextArea")

/// Every marker shape a notes or markdown editor writes on a fresh list line.
private let markerLines = [
    "-", "- ", "*", "* ", "+ ", "• ", "◦ ", "‣ ", "▪ ", "– ", "1.", "1. ", "12) ", "3)", "[ ]", "[x] ",
    "- [ ] ", "* [x] ", "1. [ ] ", "[]", "  -  ",
]

@Suite("A list line holding only its marker")
struct ListMarkerTests {
    @Test("every marker shape, alone or combined, is a marker alone", arguments: markerLines)
    func markerAlone(line: String) {
        #expect(ListMarker.isAlone(line))
    }

    @Test(
        "a marker with any of the item typed, or text shaped like a marker, is not",
        arguments: [
            "- B", "1. B", "- [ ] B", "--", "1.5", "-v", "*.swift", "x", "[link]", "", "   ", "10.2.3",
        ])
    func notAMarkerAlone(line: String) {
        #expect(!ListMarker.isAlone(line))
    }

    @Test("a marker-only line settles silent before the corpus or the model is asked", arguments: markerLines)
    func sessionSettlesSilent(line: String) {
        var session = SuggestionSession()
        let turn = session.turn(in: notes, at: PredictionContext(typed: line))
        guard case .settled(let update) = turn.step else {
            Issue.record("a marker alone asked for candidates")
            return
        }
        #expect(update == .quiet(because: .listMarkerOnly))
    }

    @Test("once the item has a character, the turn asks with the marker in the prefix")
    func itemAsks() {
        var session = SuggestionSession()
        let turn = session.turn(in: notes, at: PredictionContext(typed: "- B"))
        guard case .query(let query) = turn.step else {
            Issue.record("an item with a character asked nothing")
            return
        }
        #expect(query.typed == "- B")
    }
}
