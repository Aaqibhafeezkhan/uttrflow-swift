import UttrflowCore
import UttrflowInput

/// Whether the dictation shortcut is armed, kept apart from any dictation's state. See `Docs/shortcuts.md`.
@MainActor
final class ShortcutArming {
    /// Why the shortcut is not armed, or `nil` when it is.
    private(set) var failure: HotkeyError? {
        didSet { if failure != oldValue { onChange() } }
    }

    /// Told whenever the failure appears, changes or clears, so the lasting surfaces redraw.
    private let onChange: @MainActor () -> Void

    init(onChange: @escaping @MainActor () -> Void) {
        self.onChange = onChange
    }

    /// Arms through `start`, keeping a failure as this state rather than reporting it as a dictation.
    func arm(_ start: @MainActor () async throws(HotkeyError) -> Void) async {
        do {
            try await start()
            failure = nil
        } catch {
            failure = error
        }
    }

    /// Forgets the failure once dictation is off, since an unwatched shortcut owes nobody a notice.
    func disarm() { failure = nil }

    /// What the surfaces say while the shortcut cannot be heard, secure input first since it blocks every shortcut.
    static func unheard(secureInputBlocking: Bool, failure: HotkeyError?) -> String? {
        if secureInputBlocking { return SecureInputWatch.notice }
        return failure?.userMessage
    }
}
