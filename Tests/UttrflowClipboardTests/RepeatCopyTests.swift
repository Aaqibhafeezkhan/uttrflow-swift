// Tests that copying a kept clip's text again never loses what the user made of it.

import Foundation
import Testing

@testable import UttrflowClipboard

@Suite("Copying a kept clip's text again")
struct RepeatCopyTests {
    private func copy(_ text: String, as kind: ClipKind = .text, at offset: TimeInterval = 0) -> Clip {
        Clip(text: text, kind: kind, copiedAt: noon.addingTimeInterval(offset), source: "Notes")
    }

    @Test("a pinned clip copied again as a secret stays on disk across a relaunch (#2078)")
    func pinnedRepeatAsSecret() async throws {
        let file = TemporaryFile()
        let store = ClipboardStore(file: file.url)
        let first = copy("staging deploy key")
        try await store.record(first, keeping: week())
        try await store.setPinned(true, of: first.id, keeping: week())

        let clips = try await store.record(copy("staging deploy key", as: .secret, at: 60), keeping: week())
        #expect(clips.map(\.kind) == [.text])

        let reopened = await ClipboardStore(file: file.url).clips(keeping: week())
        #expect(reopened.map(\.text) == ["staging deploy key"])
        #expect(reopened.first?.isPinned == true)
    }

    @Test("a clip nobody kept copied again as a secret becomes one and leaves the disk")
    func unkeptRepeatAsSecret() async throws {
        let file = TemporaryFile()
        let store = ClipboardStore(file: file.url)
        try await store.record(copy("hunter2 again"), keeping: week())

        let clips = try await store.record(copy("hunter2 again", as: .secret, at: 60), keeping: week())
        #expect(clips.map(\.kind) == [.secret])
        #expect(await ClipboardStore(file: file.url).clips(keeping: week()).isEmpty)
    }

    @Test("a note copied again as plain text keeps the note and its checklist (#2079)")
    func noteSurvivesPlainRepeat() async throws {
        let file = TemporaryFile()
        let store = ClipboardStore(file: file.url)
        let first = copy("shopping")
        try await store.record(first, keeping: week())
        let note = "<ul><li data-checked=\"true\">milk</li><li>bread</li></ul>"
        try await store.setRichText(note, of: first.id, keeping: week())

        let clips = try await store.record(copy("shopping", at: 60), keeping: week())
        #expect(clips.map(\.richText) == [note])
        #expect(await ClipboardStore(file: file.url).clips(keeping: week()).map(\.richText) == [note])
    }

    @Test("a repeat that carries rich text of its own replaces the old")
    func richRepeatReplaces() async throws {
        let file = TemporaryFile()
        let store = ClipboardStore(file: file.url)
        let first = copy("shopping")
        try await store.record(first, keeping: week())
        try await store.setRichText("<p>old</p>", of: first.id, keeping: week())

        let arrival = Clip(
            text: "shopping", kind: .text, copiedAt: noon.addingTimeInterval(60), source: "Notes",
            richText: "<p><b>shopping</b></p>")
        let clips = try await store.record(arrival, keeping: week())
        #expect(clips.map(\.richText) == ["<p><b>shopping</b></p>"])
    }
}
