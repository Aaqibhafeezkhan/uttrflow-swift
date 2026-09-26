import Foundation
import Synchronization
import Testing

@testable import UttrflowCore
@testable import UttrflowInput

/// A focus whose every message blocks its thread, as an app that will not answer Accessibility does.
private final class BlockingFocus: AccessibilityFocus, @unchecked Sendable {
    private let block: TimeInterval
    private let sent = Mutex(0)

    init(blockingFor block: TimeInterval) { self.block = block }

    /// How many messages reached the application.
    var messages: Int { sent.withLock { $0 } }

    private func message() {
        sent.withLock { $0 += 1 }
        Thread.sleep(forTimeInterval: block)
    }

    func focusedTextField() -> (any FocusedTextField)? { message(); return nil }
    func hasFocusedElement() -> Bool { message(); return false }
    func isSelfFrontmost() -> Bool { false }
    func tail(upTo count: Int) -> FieldTail { message(); return .unreadable }
    func frontmostApplication() -> InsertionDestination? { nil }
    func focusedFieldIsSecure() -> Bool { message(); return false }
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
        let focus = BlockingFocus(blockingFor: 1.5)
        let stuck = ProcessInfo.processInfo.activeProcessorCount * 2
        let started = ContinuousClock.now
        let insertions = (0..<stuck).map { _ in
            Task {
                let coordinator = TextInsertionCoordinator(
                    strategies: [ClipboardTextInsertionEngine(pasteboard: HeldPasteboard(), focus: focus)],
                    focus: focus)
                _ = try? await coordinator.insert("words")
            }
        }
        // Waits until every insertion is parked in its first message, which is when a shared pool would be full.
        while focus.messages < stuck { try await Task.sleep(for: .milliseconds(5)) }
        _ = await Bystander().ping()

        // Measured from the launch, so a pool held for the whole block shows up as at least 1.5 s.
        #expect(ContinuousClock.now - started < .seconds(1))
        for insertion in insertions { insertion.cancel() }
    }

    @Test("A task cancelled before its message leaves the queue sends nothing")
    func cancelledTaskSendsNoMessage() async {
        let focus = BlockingFocus(blockingFor: 0)
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
