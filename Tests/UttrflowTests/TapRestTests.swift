// A rested tap restarts after its wait, and never once the rest is cancelled.

import Foundation
import Testing
import UttrflowPredict

@testable import Uttrflow

@MainActor
@Suite(.timeLimit(.minutes(1))) struct TapRestTests {
    @Test func restartsAfterTheWait() async throws {
        let rest = TapRest()
        var restarts = 0
        await withCheckedContinuation { (fired: CheckedContinuation<Void, Never>) in
            rest.schedule(after: .milliseconds(20)) {
                restarts += 1
                fired.resume()
            }
            #expect(rest.isPending)
        }
        #expect(restarts == 1)
        #expect(!rest.isPending)
    }

    @Test func aCancelledRestNeverRestarts() async throws {
        let rest = TapRest()
        var restarts = 0
        rest.schedule(after: .milliseconds(20)) { restarts += 1 }
        rest.cancel()
        #expect(!rest.isPending)
        // A later rest on the same clock fires only after the cancelled one's wait has run out.
        await Self.firing(TapRest(), after: .milliseconds(100))
        #expect(restarts == 0)
    }

    @Test func aSecondRestReplacesTheFirst() async throws {
        let rest = TapRest()
        var restarts = 0
        rest.schedule(after: .milliseconds(20)) { restarts += 1 }
        await withCheckedContinuation { (fired: CheckedContinuation<Void, Never>) in
            // Waits longer than the first, so a first rest left running would have fired by now.
            rest.schedule(after: .milliseconds(100)) {
                restarts += 10
                fired.resume()
            }
        }
        #expect(restarts == 10)
    }

    @Test func stoppingTheCoordinatorCancelsItsRestingTap() throws {
        let container = FileManager.default.temporaryDirectory.appending(path: "taprest-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: container, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: container) }
        let coordinator = try SuggestionCoordinator(
            container: container, preferences: SuggestionPreferences(isEnabled: true))
        coordinator.tapRest.schedule(after: .seconds(90)) {}
        coordinator.stop()
        #expect(!coordinator.tapRest.isPending)
    }

    /// Returns once `rest` has restarted after `delay`.
    private static func firing(_ rest: TapRest, after delay: Duration) async {
        await withCheckedContinuation { (fired: CheckedContinuation<Void, Never>) in
            rest.schedule(after: delay) { fired.resume() }
        }
    }
}
