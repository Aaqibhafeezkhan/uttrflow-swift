// Tests that a paste is told apart from typing, so pasted text is never learned as typed.

import AppKit
import Testing

@testable import Uttrflow

/// A key-down as the window server reports it, with the characters it types.
private func keyDown(_ characters: String, modifiers: NSEvent.ModifierFlags) -> NSEvent? {
    NSEvent.keyEvent(
        with: .keyDown, location: .zero, modifierFlags: modifiers, timestamp: 0, windowNumber: 0,
        context: nil, characters: characters, charactersIgnoringModifiers: characters, isARepeat: false,
        keyCode: 9)
}

@Suite("Telling a paste from typing")
struct SuggestionPasteTests {
    @Test("Command-V is a paste, with or without Shift or Option")
    func commandVIsAPaste() throws {
        #expect(SuggestionCoordinator.isPaste(try #require(keyDown("v", modifiers: [.command]))))
        #expect(SuggestionCoordinator.isPaste(try #require(keyDown("V", modifiers: [.command, .shift]))))
        #expect(
            SuggestionCoordinator.isPaste(try #require(keyDown("v", modifiers: [.command, .option, .shift]))))
    }

    @Test("A typed v and any other shortcut are not a paste")
    func otherKeysAreNotAPaste() throws {
        #expect(!SuggestionCoordinator.isPaste(try #require(keyDown("v", modifiers: []))))
        #expect(!SuggestionCoordinator.isPaste(try #require(keyDown("V", modifiers: [.shift]))))
        #expect(!SuggestionCoordinator.isPaste(try #require(keyDown("c", modifiers: [.command]))))
    }
}
