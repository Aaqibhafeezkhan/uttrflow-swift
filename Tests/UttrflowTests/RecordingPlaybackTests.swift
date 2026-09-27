// Tests that History's playback redraws once per change and never for a recording that cannot play.

import Foundation
import Testing
import UttrflowAudio
import UttrflowCore

@testable import Uttrflow

@MainActor
@Suite("Playing a kept recording back from History")
struct RecordingPlaybackTests {
    /// Half a second of quiet, as WAV bytes the player can open.
    private static let quiet = WAVEncoder.encode(.canonical(Array(repeating: 0, count: 8_000)))

    @Test("bytes that are not audio play nothing and ask for no redraw")
    func unplayable() {
        let playback = RecordingPlayback()
        var redraws = 0
        playback.onChange = { redraws += 1 }
        playback.play(Data("not audio".utf8), id: UUID())
        playback.stop()
        #expect(playback.playing == nil)
        #expect(redraws == 0)
    }

    @Test("moving from one recording to another redraws once, and stopping once more")
    func oneRedrawPerChange() {
        let playback = RecordingPlayback()
        var redraws = 0
        playback.onChange = { redraws += 1 }
        let first = UUID()
        playback.play(Self.quiet, id: first)
        // A Mac with no output device cannot play, and then nothing changed to redraw.
        guard playback.playing == first else { return #expect(redraws == 0) }
        #expect(redraws == 1)
        let second = UUID()
        playback.play(Self.quiet, id: second)
        #expect(playback.playing == second)
        #expect(redraws == 2)
        playback.stop()
        #expect(playback.playing == nil)
        #expect(redraws == 3)
    }
}
