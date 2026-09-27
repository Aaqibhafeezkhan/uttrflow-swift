import Dispatch
import Synchronization
import UttrflowCore

/// Runs blocking Accessibility messages on a queue of their own, off Swift's cooperative pool. See `Docs/insertion.md`.
enum AccessibilityThread {
    /// Concurrent, so one app that will not answer cannot hold up a message to another.
    private static let queue = DispatchQueue(
        label: "com.uttrflow.input.accessibility", qos: .userInitiated, attributes: .concurrent)

    /// Answers `work` from the queue, or `fallback` without sending anything once the task is cancelled.
    static func run<T: Sendable>(
        orElse fallback: T, _ work: @escaping @Sendable () -> T
    ) async -> T {
        guard !Task.isCancelled else { return fallback }
        let expired = Expired()
        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                queue.async { continuation.resume(returning: expired.isSet ? fallback : work()) }
            }
        } onCancel: {
            expired.set()
        }
    }

    /// The throwing form, which refuses as the ended dictation once the task is cancelled.
    static func run<T: Sendable>(
        _ work: @escaping @Sendable () throws(TextInsertionError) -> T
    ) async throws(TextInsertionError) -> T {
        let ended = Result<T, TextInsertionError>.failure(
            .insertionRejected(description: TextInsertion.dictationEnded))
        let result = await run(orElse: ended) { Result { () throws(TextInsertionError) -> T in try work() } }
        return try result.get()
    }

    /// A cancellation flag a dispatch closure can read, since it runs outside the task that queued it.
    private final class Expired: Sendable {
        private let flag = Mutex(false)
        var isSet: Bool { flag.withLock { $0 } }
        func set() { flag.withLock { $0 = true } }
    }
}
