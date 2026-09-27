import Foundation
import Testing

@testable import UttrflowCore
@testable import UttrflowInput

/// A secret clip reaches the clipboard marked concealed, whichever route carries it and whatever field is in front.
@Suite("Inserting a secret through a concealing pasteboard")
struct ConcealingPasteboardTests {
    @Test("a plain or formatted write goes up marked")
    func writesAreConcealed() {
        let pasteboard = FakePasteboard()
        let concealing = ConcealingPasteboard(pasteboard)

        concealing.setText("sk-live-abcdef123456")
        concealing.setText("sk-live-abcdef123456", richText: "<b>sk-live-abcdef123456</b>")

        #expect(pasteboard.concealed == ["sk-live-abcdef123456", "sk-live-abcdef123456"])
        #expect(concealing.text() == "sk-live-abcdef123456")
    }

    @Test("the paste route leaves a secret marked in an ordinary field")
    func pasteRouteConceals() async throws {
        let pasteboard = FakePasteboard()
        let engine = PasteboardTextInsertionEngine(
            focus: FakeFocus(field: FakeTextField()), pasteboard: ConcealingPasteboard(pasteboard),
            keystrokes: FakeKeystrokeSender())

        _ = try await engine.insert("sk-live-abcdef123456", richText: "<b>key</b>")

        #expect(pasteboard.concealed == ["sk-live-abcdef123456"])
    }

    @Test("the clipboard floor leaves a secret marked in an ordinary field")
    func floorConceals() async throws {
        let pasteboard = FakePasteboard()
        let engine = ClipboardTextInsertionEngine(
            pasteboard: ConcealingPasteboard(pasteboard), focus: FakeFocus(field: nil))

        _ = try await engine.insert("sk-live-abcdef123456")

        #expect(pasteboard.concealed == ["sk-live-abcdef123456"])
    }

    @Test("the built route never writes a secret unmarked")
    func builtRouteConceals() async throws {
        let pasteboard = FakePasteboard()
        let coordinator = TextInsertion.coordinator(
            focus: FakeFocus(field: nil, isSelf: true), pasteboard: ConcealingPasteboard(pasteboard),
            keystrokes: FakeKeystrokeSender())

        _ = try await coordinator.insert("sk-live-abcdef123456")

        #expect(!pasteboard.writes.isEmpty)
        #expect(pasteboard.concealed == pasteboard.writes)
    }
}
