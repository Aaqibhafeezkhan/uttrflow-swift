// A secret clip stays in memory, whatever the user does to it in the panel.

import Foundation
import Testing

@testable import UttrflowClipboard

@Suite("A kept secret never reaches the disk")
struct SecretClipDiskTests {
    private let secretText = "api_key = ff00aa11ff00aa11ff00aa11"

    /// What `work` wrote: how many files, and every encoded list.
    private func writes(_ work: () async throws -> Void) async rethrows -> (count: Int, bytes: [Data]) {
        let tally = StoreWriteTally()
        try await ClipboardStore.$writes.withValue(tally) { try await work() }
        return (tally.count, tally.written)
    }

    /// Whether any written list carries the secret's text.
    private func carriesSecret(_ bytes: [Data]) -> Bool {
        bytes.contains { String(decoding: $0, as: UTF8.self).contains("ff00aa11ff00aa11") }
    }

    @Test("pinning, aliasing and filing a secret writes nothing")
    func keepingASecretWritesNothing() async throws {
        let file = TemporaryFile()
        let store = ClipboardStore(file: file.url)
        let secret = Clip(text: secretText, kind: .secret, copiedAt: noon)
        try await store.record(secret, keeping: week())

        let written = try await writes {
            try await store.setPinned(true, of: secret.id, keeping: week())
            try await store.setAlias("key", of: secret.id, keeping: week())
            try await store.setCategory("Work", of: secret.id, keeping: week())
        }

        #expect(written.count == 0)
        #expect(!carriesSecret(written.bytes))
        #expect(await store.clips(keeping: week()).first { $0.id == secret.id }?.category == "Work")
        #expect(await ClipboardStore(file: file.url).clips(keeping: week()).isEmpty)
    }

    @Test("a clip leaving the saved file does not carry a kept secret with it")
    func leavingClipDoesNotBridgeASecret() async throws {
        let file = TemporaryFile()
        let store = ClipboardStore(file: file.url)
        let plain = Clip(text: "plain", kind: .text, copiedAt: noon.addingTimeInterval(-60))
        let secret = Clip(text: secretText, kind: .secret, copiedAt: noon)
        try await store.record(plain, keeping: week())
        try await store.record(secret, keeping: week())
        try await store.setPinned(true, of: plain.id, keeping: week())
        try await store.setPinned(true, of: secret.id, keeping: week())

        let written = try await writes {
            try await store.setPinned(false, of: plain.id, keeping: week())
        }

        #expect(written.count >= 1)
        #expect(!carriesSecret(written.bytes))
        let onDisk = try FileManager.default.contentsOfDirectory(
            at: file.url.deletingLastPathComponent(), includingPropertiesForKeys: nil
        ).filter { $0.pathExtension == "json" }
        #expect(!carriesSecret(onDisk.compactMap { try? Data(contentsOf: $0) }))
    }
}
