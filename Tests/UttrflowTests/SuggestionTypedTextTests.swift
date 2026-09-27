// Tests which keys count as typing a ghost's next letters, which is the only kind that keeps it on screen.

import AppKit
import Testing

@testable import Uttrflow

@Suite("The text a key types, for typing through a ghost")
struct SuggestionTypedTextTests {
    @Test("a letter, a shifted letter and a space are text")
    func plainKeysAreText() {
        #expect(SuggestionCoordinator.typedText(characters: "a", modifiers: []) == "a")
        #expect(SuggestionCoordinator.typedText(characters: "A", modifiers: .shift) == "A")
        #expect(SuggestionCoordinator.typedText(characters: " ", modifiers: []) == " ")
    }

    @Test("a shortcut types nothing, whatever letter it carries")
    func shortcutsAreNotText() {
        #expect(SuggestionCoordinator.typedText(characters: "a", modifiers: .command) == nil)
        #expect(SuggestionCoordinator.typedText(characters: "a", modifiers: .control) == nil)
        #expect(SuggestionCoordinator.typedText(characters: "å", modifiers: .option) == nil)
    }

    @Test("Tab, Return, Delete, an arrow and a dead key type nothing")
    func controlKeysAreNotText() {
        #expect(SuggestionCoordinator.typedText(characters: "\t", modifiers: []) == nil)
        #expect(SuggestionCoordinator.typedText(characters: "\r", modifiers: []) == nil)
        #expect(SuggestionCoordinator.typedText(characters: "\u{7F}", modifiers: []) == nil)
        #expect(SuggestionCoordinator.typedText(characters: "\u{F701}", modifiers: .function) == nil)
        #expect(SuggestionCoordinator.typedText(characters: "\u{F701}", modifiers: []) == nil)
        #expect(SuggestionCoordinator.typedText(characters: "", modifiers: []) == nil)
        #expect(SuggestionCoordinator.typedText(characters: nil, modifiers: []) == nil)
    }
}
