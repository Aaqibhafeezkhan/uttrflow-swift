import Foundation

/// Records accepted suggestions one after another and off the key path, so a held key never waits on the corpus.
@MainActor
final class AcceptanceQueue {
    /// The newest recording, which every later one waits behind.
    private var last: Task<Void, Never>?

    /// Queues `work` behind every earlier recording and returns at once.
    func enqueue(_ work: @escaping @Sendable () async -> Void) {
        let previous = last
        last = Task {
            await previous?.value
            await work()
        }
    }

    /// Waits until every recording queued so far has finished, so capture hears of the acceptance first.
    func drained() async {
        await last?.value
    }
}
