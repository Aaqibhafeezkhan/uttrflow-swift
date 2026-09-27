private import Carbon
internal import CoreGraphics
internal import Foundation

/// Finds which key types a character under a keyboard layout. See `Docs/input-synthetic-keystrokes.md`.
enum LayoutKeyCode {
    /// The Carbon modifier state for ⌘ held, which selects a layout's ⌘ table where it has one.
    static let commandHeld = UInt32((cmdKey >> 8) & 0xFF)

    /// The key code that types `character` under `layoutData` with `modifiers` held, or nil if no key on the board does.
    static func code(for character: UniChar, in layoutData: Data, modifiers: UInt32 = 0) -> CGKeyCode? {
        layoutData.withUnsafeBytes { raw -> CGKeyCode? in
            guard let layout = raw.bindMemory(to: UCKeyboardLayout.self).baseAddress else { return nil }
            var deadKeyState: UInt32 = 0
            for code in CGKeyCode(0)...CGKeyCode(127) {
                var chars = [UniChar](repeating: 0, count: 4)
                var length = 0
                let status = UCKeyTranslate(
                    layout, code, UInt16(kUCKeyActionDown), modifiers, UInt32(LMGetKbdType()),
                    UInt32(kUCKeyTranslateNoDeadKeysBit), &deadKeyState, chars.count, &length, &chars)
                if status == noErr, length > 0, chars[0] == character { return code }
            }
            return nil
        }
    }
}
