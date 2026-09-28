// Tests that lines learned before the credential rules widened are removed from the corpus once.

import Foundation
import Testing
import UttrflowPredict
import UttrflowPredictStore

@testable import UttrflowPredictCapture

@Suite("Credentials learned before the rules recognised them are swept from the corpus")
struct SecretSweepTests {
    private static let moment = Date(timeIntervalSince1970: 1_800_000_000)
    private static let shell = Surface(
        bundleIdentifier: "com.example.terminal", role: "AXTextArea", scope: "/work")

    /// Every line written straight to the store, as an older build without the widened rules wrote them.
    private static let learned = [
        "mysql -u root -pS3cretPass appdb",
        "git status",
        "sshpass -p sunshine ssh deploy@db.example.com",
        "ls -la",
        "git log",
    ]

    private func taught(_ store: PredictStore) async throws {
        var previous: String?
        for line in Self.learned {
            try await store.record(line, in: Self.shell, after: previous, at: Self.moment)
            previous = line
        }
    }

    @Test("A stored credential line and every succession naming it go; ordinary lines and their order stay")
    func sweepsStoredCredentials() async throws {
        let scratch = Scratch()
        let store = try PredictStore(path: scratch.path("predict.sqlite"))
        try await taught(store)

        #expect(try await CaptureGate.sweepSecrets(from: store) == 2)

        #expect(try await store.entryCount() == 3)
        #expect(try await store.candidates(for: Self.shell, matching: "mysql").isEmpty)
        #expect(try await store.candidates(for: Self.shell, matching: "sshpass").isEmpty)
        #expect(
            Set(try await store.candidates(for: Self.shell, matching: "git").map(\.text)) == [
                "git status", "git log",
            ])
        #expect(try await store.successors(for: Self.shell, after: "git status").isEmpty)
        #expect(try await store.successors(for: Self.shell, after: "ls -la").map(\.text) == ["git log"])
    }

    @Test("The sweep runs once per version of the rules, and again when the rules widen")
    func sweepsOncePerVersion() async throws {
        let scratch = Scratch()
        let store = try PredictStore(path: scratch.path("predict.sqlite"))
        try await taught(store)
        #expect(try await CaptureGate.sweepSecrets(from: store) == 2)
        try await store.record("mysql -u root -pS3cretPass appdb", in: Self.shell, at: Self.moment)

        #expect(try await CaptureGate.sweepSecrets(from: store) == 0)
        let reopened = try PredictStore(path: scratch.path("predict.sqlite"))
        #expect(try await CaptureGate.sweepSecrets(from: reopened) == 0)
        #expect(
            try await reopened.sweep(
                "looksLikeSecret", version: CaptureGate.secretRulesVersion + 1,
                removing: CaptureGate.looksLikeSecret) == 1)
    }

    @Test("A retired line that points at a credential goes with it")
    func sweepsRetirementsNamingCredentials() async throws {
        let scratch = Scratch()
        let store = try PredictStore(path: scratch.path("predict.sqlite"))
        try await store.record("mysql -u root", in: Self.shell, at: Self.moment)
        try await store.supersede("mysql -u root", with: "mysql -u root -pS3cretPass appdb", in: Self.shell)

        #expect(try await CaptureGate.sweepSecrets(from: store) >= 1)
        #expect(try await store.entryCount() == 0)
    }
}
