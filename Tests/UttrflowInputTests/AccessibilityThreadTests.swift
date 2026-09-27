import Foundation
import Synchronization
import Testing

@testable import UttrflowCore
@testable import UttrflowInput

/// A focus whose every message parks its thread until released, as an app that will not answer Accessibility does.
private final class BlockingFocus: AccessibilityFocus, @unchecked Sendable {
    private let opened = Mutex(false)
    private let sent = Mutex(0)
    private let offPool = Mutex(true)
    private let blocks: Bool

    init(blocks: Bool = true) { self.blocks = blocks }

    /// How many messages reached the application.
    var messages: Int { sent.withLock { $0 } }

    /// Whether every message was sent from the Accessibility queue rather than a pool thread.
    var allSentOffPool: Bool { offPool.withLock { $0 } }

    /// Lets every parked message answer, and every later one answer at once.
    func release() { opened.withLock { $0 = true } }

    private func message() {
        let label = String(cString: __dispatch_queue_get_label(nil))
        let fromQueue = label == "com.uttrflow.input.accessibility"
        offPool.withLock { $0 = $0 && fromQueue }
        sent.withLock { $0 += 1 }
        // Parks only on the Accessibility queue, so a message sent from the pool fails the test rather than hanging it.
        while blocks, fromQueue, !opened.withLock({ $0 }) { Thread.sleep(forTimeInterval: 0.005) }
    }

    func focusedTextField() -> (any FocusedTextField)? { message(); return nil }
    func hasFocusedElement() -> Bool { message(); return false }
    func isSelfFrontmost() -> Bool { false }
    func tail(upTo count: Int) -> FieldTail { message(); return .unreadable }
    func frontmostApplication() -> InsertionDestination? { nil }
    func focusedFieldIsSecure() -> Bool { message(); return false }
}

/// Whether something happened, readable from any thread.
private final class Flag: Sendable {
    private let value = Mutex(false)
    var isSet: Bool { value.withLock { $0 } }
    func set() { value.withLock { $0 = true } }
}

/// A clipboard that holds what it is given.
private final class HeldPasteboard: Pasteboard, @unchecked Sendable {
    private let held = Mutex<String?>(nil)
    func text() -> String? { held.withLock { $0 } }
    func setText(_ text: String) { held.withLock { $0 = text } }
    func setText(_ text: String, richText: String?) { setText(text) }
    func setConcealedText(_ text: String) { held.withLock { $0 = text } }
    func setImage(_ data: Data) {}
}

/// Stands for any other actor in the process that needs a pool thread to make progress.
private actor Bystander {
    func ping() -> Int { 1 }
}

@Suite("Accessibility calls run off the cooperative pool")
struct AccessibilityThreadTests {
    @Test("Insertions stuck on a silent app leave other actors free to run")
    func blockedInsertionsDoNotStarveThePool() async throws {
        let focus = BlockingFocus()
        let stuck = ProcessInfo.processInfo.activeProcessorCount * 2
        // A last-resort release on a thread of its own, since a starved pool also starves the global queues.
        let released = Flag()
        Thread.detachNewThread {
            Thread.sleep(forTimeInterval: 60)
            released.set()
            focus.release()
        }
        let insertions = (0..<stuck).map { _ in
            Task {
                let coordinator = TextInsertionCoordinator(
                    strategies: [ClipboardTextInsertionEngine(pasteboard: HeldPasteboard(), focus: focus)],
                    focus: focus)
                _ = try? await coordinator.insert("words")
            }
        }
        // Waits until every insertion is parked in a message, which is when a shared pool would be full.
        while focus.messages < stuck, !released.isSet { try await Task.sleep(for: .milliseconds(5)) }
        _ = await Bystander().ping()

        #expect(!released.isSet, "the bystander ran only once the stuck messages were let go")
        #expect(focus.allSentOffPool)
        focus.release()
        for insertion in insertions { await insertion.value }
    }

    @Test("Paste confirmation reads the caret from the Accessibility queue")
    func confirmationReadsOffPool() async {
        let focus = BlockingFocus(blocks: false)
        _ = await PasteConfirmation(focus: focus).waitFor("words")
        #expect(focus.messages == 1)
        #expect(focus.allSentOffPool)
    }

    @Test("A task cancelled before its message leaves the queue sends nothing")
    func cancelledTaskSendsNoMessage() async {
        let focus = BlockingFocus(blocks: false)
        let answer = await Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return await AccessibilityThread.run(orElse: true) { focus.focusedFieldIsSecure() }
        }.value
        #expect(answer)
        #expect(focus.messages == 0)
    }

    @Test("A cancelled write refuses as the ended dictation")
    func cancelledWriteRefuses() async {
        let answer = await Task { () -> TextInsertionError? in
            withUnsafeCurrentTask { $0?.cancel() }
            do throws(TextInsertionError) {
                try await AccessibilityThread.run { () throws(TextInsertionError) in () }
                return nil
            } catch { return error }
        }.value
        #expect(answer == .insertionRejected(description: TextInsertion.dictationEnded))
    }
}
