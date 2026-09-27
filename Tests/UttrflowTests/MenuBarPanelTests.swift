// Tests that the menu bar popover's panel takes the keyboard and closes on Escape.

import AppKit
import Testing

@testable import Uttrflow

@MainActor
@Suite("The menu bar popover's panel")
struct MenuBarPanelTests {
    private static func panel() -> MenuBarPanel {
        MenuBarPanel(
            contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true
        )
    }

    @Test("can take the keyboard, so Tab, the arrows, Return and VoiceOver reach the popover")
    func becomesKey() {
        let panel = Self.panel()
        #expect(panel.canBecomeKey)
        #expect(!panel.canBecomeMain)
    }

    @Test("reports Escape, so the popover closes as a menu does")
    func escapeCancels() {
        let panel = Self.panel()
        var cancelled = 0
        panel.onCancel = { cancelled += 1 }
        panel.cancelOperation(nil)
        #expect(cancelled == 1)
    }
}
