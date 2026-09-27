// Tests that a shortcut that could not be armed is kept as its own state until it is armed.

import Foundation
import UttrflowCore
import UttrflowInput
import Testing

@testable import Uttrflow

@MainActor
@Suite("A dictation shortcut that could not be armed")
struct ShortcutArmingTests {
    /// Counts the redraws the arming asks for.
    private final class Redraws {
        var count = 0
    }

    @Test("stays said until a later arming works, then clears")
    func failureStaysUntilArmed() async {
        let redraws = Redraws()
        let arming = ShortcutArming { redraws.count += 1 }

        await arming.arm { () throws(HotkeyError) in throw .shortcutUnavailable }
        #expect(arming.failure == .shortcutUnavailable)
        #expect(
            ShortcutArming.unheard(secureInputBlocking: false, failure: arming.failure)
                == HotkeyError.shortcutUnavailable.userMessage)
        #expect(redraws.count == 1)

        // The retry on activation fails the same way, which is no change to redraw.
        await arming.arm { () throws(HotkeyError) in throw .shortcutUnavailable }
        #expect(redraws.count == 1)

        await arming.arm { () throws(HotkeyError) in }
        #expect(arming.failure == nil)
        #expect(ShortcutArming.unheard(secureInputBlocking: false, failure: arming.failure) == nil)
        #expect(redraws.count == 2)
    }

    @Test("is forgotten when dictation is turned off")
    func disarmingForgetsTheFailure() async {
        let arming = ShortcutArming {}
        await arming.arm { () throws(HotkeyError) in throw .observationNotPermitted }

        arming.disarm()

        #expect(arming.failure == nil)
    }

    @Test("gives way to secure input, which blocks every shortcut")
    func secureInputComesFirst() {
        #expect(
            ShortcutArming.unheard(secureInputBlocking: true, failure: .shortcutUnavailable)
                == SecureInputWatch.notice)
    }

    @Test("is never reported through the dictation state")
    func armingIsNotADictation() throws {
        let source = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: "Sources/Uttrflow/AppDelegate.swift")
        let text = try String(contentsOf: source, encoding: .utf8)
        let arming = try #require(
            text.components(separatedBy: "private func startWatchingForTheShortcut()").dropFirst().first?
                .components(separatedBy: "// MARK:").first)
        #expect(arming.contains("arming.arm {"))
        #expect(!arming.contains("render("), "an arming failure would be counted as a dictation")
    }
}
