// Tests that the quick panel takes its row chords ahead of the main menu, so ⌘M moves a clip.

import AppKit
import Testing
import UttrflowUX

@testable import Uttrflow

/// A view that records the keys the window hands it.
private final class KeyRecorder: NSView {
    var keys: [String] = []
    override var acceptsFirstResponder: Bool { true }
    override func keyDown(with event: NSEvent) { keys.append(event.charactersIgnoringModifiers ?? "") }
}

/// A key-down for `character` with `modifiers` held, addressed to `window`.
@MainActor
private func key(
    _ character: String, _ modifiers: NSEvent.ModifierFlags, in window: NSWindow? = nil
) throws -> NSEvent {
    try #require(
        NSEvent.keyEvent(
            with: .keyDown, location: .zero, modifierFlags: modifiers, timestamp: 0,
            windowNumber: window?.windowNumber ?? 0, context: nil, characters: character,
            charactersIgnoringModifiers: character, isARepeat: false, keyCode: 0))
}

@MainActor
@Suite("The quick panel's row chords")
struct QuickPanelChordTests {
    @Test("every row chord is recognised, with ⇧ where the chord takes it")
    func recognisesRowChords() throws {
        #expect(QuickPanel.isRowChord(try key("m", .command)))
        #expect(QuickPanel.isRowChord(try key("p", .command)))
        #expect(QuickPanel.isRowChord(try key("C", [.command, .shift])))
    }

    @Test("keys that are not row chords are left to the menu and the field")
    func leavesOtherKeysAlone() throws {
        #expect(!QuickPanel.isRowChord(try key("m", [])))
        #expect(!QuickPanel.isRowChord(try key("w", .command)))
        #expect(!QuickPanel.isRowChord(try key("z", .command)))
        #expect(!QuickPanel.isRowChord(try key("c", .command)))
        #expect(!QuickPanel.isRowChord(try key("m", [.command, .option])))
        #expect(!QuickPanel.isRowChord(try key("m", [.command, .control])))
    }

    /// Window ▸ Minimise is ⌘M, and the menu swallows it even where it is disabled.
    @Test("Move's chord is one the Window menu also binds")
    func moveSharesMinimiseKey() throws {
        let minimise = try #require(MainMenu.window.items.first { $0.title == "Minimise" })
        #expect(minimise.keyEquivalent == String(PanelRowAction.move.chord.character))
        #expect(minimise.keyEquivalentModifierMask == .command)
        #expect(!PanelRowAction.move.chord.isShifted)
    }

    @Test("⌘M reaches the panel's own key handler and is claimed before the menu")
    func commandMReachesThePanel() throws {
        let panel = QuickPanel(
            contentRect: CGRect(x: 0, y: 0, width: 200, height: 100),
            styleMask: [.nonactivatingPanel], backing: .buffered, defer: true)
        let recorder = KeyRecorder()
        panel.contentView = recorder
        panel.makeFirstResponder(recorder)

        #expect(panel.performKeyEquivalent(with: try key("m", .command, in: panel)))
        #expect(recorder.keys == ["m"])
    }

    @Test("a key that is not a row chord is not claimed")
    func otherKeysAreNotClaimed() throws {
        let panel = QuickPanel(
            contentRect: CGRect(x: 0, y: 0, width: 200, height: 100),
            styleMask: [.nonactivatingPanel], backing: .buffered, defer: true)
        let recorder = KeyRecorder()
        panel.contentView = recorder
        panel.makeFirstResponder(recorder)

        #expect(!panel.performKeyEquivalent(with: try key("w", .command, in: panel)))
        #expect(recorder.keys.isEmpty)
    }
}
