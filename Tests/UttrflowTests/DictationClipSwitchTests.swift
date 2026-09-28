// Tests that a finished dictation reaches the clipboard history only while the Clipboard switch is on (#2084).

import Foundation
import UttrflowClipboard
import UttrflowPipeline
import UttrflowSettings
import Testing

@testable import Uttrflow

@MainActor
@Suite("Dictations and the Clipboard switch", .serialized)
struct DictationClipSwitchTests {
    private func app(clipboardOn: Bool, in sandbox: borrowing Sandbox) -> AppDelegate {
        let app = AppDelegate(container: sandbox.root, account: HeldSession(signedIn: true).layer)
        app.drawsWindows = false
        app.settingsChanged(to: Settings(clipboardEnabled: clipboardOn))
        return app
    }

    private func keptClips(in sandbox: borrowing Sandbox) async -> [String] {
        let store = ClipboardStore(file: ClipboardStore.defaultFile(in: sandbox.root))
        return await store.clips(keeping: ClipRetention(days: 7, now: Date())).map(\.text)
    }

    @Test("a dictation finished while the switch is off is not kept as a clip")
    func switchOff() async {
        let sandbox = Sandbox()
        let app = app(clipboardOn: false, in: sandbox)

        #expect(app.recordAsClip("Sample words", of: UUID()) == nil)
        app.render(
            .inserted(DictationOutcome(text: "Sample words", method: .accessibility, cleanedBy: .rules)))

        #expect(await keptClips(in: sandbox).isEmpty)
    }

    @Test("a dictation finished while the switch is on is kept as a clip")
    func switchOn() async throws {
        let sandbox = Sandbox()
        let app = app(clipboardOn: true, in: sandbox)

        let recording = try #require(app.recordAsClip("Sample words", of: UUID()))
        await recording.value

        #expect(await keptClips(in: sandbox) == ["Sample words"])
    }
}
