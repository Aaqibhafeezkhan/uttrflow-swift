// Tests that a paste is told apart from typing, so pasted text is never learned as typed.

import AppKit
import Testing

@testable import Uttrflow

/// US QWERTY, Russian and Dvorak – QWERTY ⌘ all put ⌘V on this key.
private let qwertyV: UInt16 = 9

/// Plain Dvorak puts V, with or without ⌘, on the key QWERTY types `.` with.
private let dvorakV: UInt16 = 47

/// Whether the key at `keyCode` with `modifiers` held is a paste on a layout whose ⌘V is `pasteKeyCode`.
private func pastes(
    _ keyCode: UInt16, _ modifiers: NSEvent.ModifierFlags, on pasteKeyCode: UInt16 = qwertyV
) -> Bool {
    SuggestionCoordinator.isPaste(keyCode: keyCode, modifiers: modifiers, pasteKeyCode: pasteKeyCode)
}

@Suite("Telling a paste from typing")
struct SuggestionPasteTests {
    @Test("Command-V is a paste, with or without Shift or Option")
    func commandVIsAPaste() {
        #expect(pastes(qwertyV, [.command]))
        #expect(pastes(qwertyV, [.command, .shift]))
        #expect(pastes(qwertyV, [.command, .option, .shift]))
    }

    @Test("A typed v and any other shortcut are not a paste")
    func otherKeysAreNotAPaste() {
        #expect(!pastes(qwertyV, []))
        #expect(!pastes(qwertyV, [.shift]))
        #expect(!pastes(8, [.command]))
    }

    @Test("Russian: the V key types a Cyrillic letter, and ⌘ on it is still a paste")
    func cyrillicLayout() throws {
        let event = try #require(
            NSEvent.keyEvent(
                with: .keyDown, location: .zero, modifierFlags: [.command], timestamp: 0, windowNumber: 0,
                context: nil, characters: "м", charactersIgnoringModifiers: "м", isARepeat: false,
                keyCode: qwertyV))
        #expect(pastes(event.keyCode, event.modifierFlags))
    }

    @Test("Dvorak – QWERTY ⌘: ⌘ on the QWERTY V key pastes, ⌘ on the Dvorak V key does not")
    func dvorakWithQwertyCommand() {
        #expect(pastes(qwertyV, [.command]))
        #expect(!pastes(dvorakV, [.command]))
    }

    @Test("plain Dvorak: ⌘V is on the Dvorak V key")
    func plainDvorak() {
        #expect(pastes(dvorakV, [.command], on: dvorakV))
        #expect(!pastes(qwertyV, [.command], on: dvorakV))
    }
}
