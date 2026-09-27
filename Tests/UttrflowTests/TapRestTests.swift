// A rested tap restarts after its wait, and never once the rest is cancelled.

import Foundation
import Testing
import UttrflowPredict

@testable import Uttrflow

@MainActor
@Suite struct TapRestTests {
    @Test func restartsAfterTheWait() async throws {
        let rest = TapRest()
        var restarts = 0
        rest.schedule(after: .milliseconds(20)) { restarts += 1 }
        #expect(rest.isPending)
        try await Task.sleep(for: .milliseconds(300))
        #expect(restarts == 1)
        #expect(!rest.isPending)
    }

    @Test func aCancelledRestNeverRestarts() async throws {
        let rest = TapRest()
        var restarts = 0
        rest.schedule(after: .milliseconds(50)) { restarts += 1 }
        rest.cancel()
        #expect(!rest.isPending)
        try await Task.sleep(for: .milliseconds(300))
        #expect(restarts == 0)
    }

    @Test func aSecondRestReplacesTheFirst() async throws {
        let rest = TapRest()
        var restarts = 0
        rest.schedule(after: .milliseconds(20)) { restarts += 1 }
        rest.schedule(after: .milliseconds(20)) { restarts += 10 }
        try await Task.sleep(for: .milliseconds(300))
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
}
