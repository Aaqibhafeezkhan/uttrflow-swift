// Tests for the menu bar popover's keyboard order and where the arrow keys go.

import Testing
import UttrflowUX

@testable import Uttrflow

@Suite("The menu bar popover's keyboard order")
struct MenuBarKeyboardTests {
    private static let recents = [
        MenuBarRecent(title: "Book the room", fullText: "Book the room"),
        MenuBarRecent(title: "Send the draft", fullText: "Send the draft"),
    ]

    @Test("runs the header's action, the round buttons, then the last dictation, in drawing order")
    func followsTheDrawing() throws {
        let shown = MenuBarPresenter.present(MenuBarState(speechModel: .notInstalled, recents: Self.recents))
        guard case .status(let status) = shown.header, let action = status.action else {
            Issue.record("expected the header to offer an action")
            return
        }
        let keyboard = MenuBarKeyboard(shown)
        let last = try #require(shown.lastDictation)
        #expect(
            keyboard.commands == [action] + shown.buttons.map(\.command) + [last.insert]
                + shown.clips.map(\.insert))
        #expect(keyboard.buttonsStart == 1)
        #expect(keyboard.lastDictationPlace == 1 + shown.buttons.count)
        #expect(keyboard.clipsStart == keyboard.lastDictationPlace + 1)
    }

    @Test("starts at the first control going forward and the last going back, and wraps at either end")
    func wraps() {
        let keyboard = MenuBarKeyboard(MenuBarPresenter.present(MenuBarState(recents: Self.recents)))
        let last = keyboard.commands.count - 1
        #expect(keyboard.buttonsStart == 0)
        #expect(keyboard.place(after: nil, forward: true) == 0)
        #expect(keyboard.place(after: nil, forward: false) == last)
        #expect(keyboard.place(after: last, forward: true) == 0)
        #expect(keyboard.place(after: 0, forward: false) == last)
        #expect(keyboard.place(after: 0, forward: true) == 1)
    }

    @Test("skips a control that cannot be used, and Return does nothing on one")
    func skipsDisabled() throws {
        let keyboard = MenuBarKeyboard(
            MenuBarPresenter.present(MenuBarState(speechModel: .notInstalled, recents: Self.recents)))
        let disabled = try #require(keyboard.commands.firstIndex { !$0.isEnabled })
        let before = (disabled - 1 + keyboard.commands.count) % keyboard.commands.count
        #expect(keyboard.place(after: before, forward: true) != disabled)
        #expect(keyboard.command(at: disabled) == nil)
    }

    @Test("names the command at a usable place, and nothing off the end or with no focus")
    func commandAtPlace() {
        let keyboard = MenuBarKeyboard(MenuBarPresenter.present(MenuBarState(recents: Self.recents)))
        #expect(keyboard.command(at: 0) == keyboard.commands[0])
        #expect(keyboard.command(at: nil) == nil)
        #expect(keyboard.command(at: keyboard.commands.count) == nil)
        #expect(keyboard.command(at: -1) == nil)
    }

    @Test("goes nowhere when no control can be used")
    func nothingUsable() {
        let keyboard = MenuBarKeyboard(MenuBarPresenter.present(MenuBarState()))
        let none = MenuBarKeyboard(commands: keyboard.commands.map(Self.disabled))
        #expect(none.place(after: nil, forward: true) == nil)
    }

    private static func disabled(_ command: MenuBarCommand) -> MenuBarCommand {
        MenuBarCommand(title: command.title, intent: command.intent, isEnabled: false)
    }
}
