// Plays a kept recording back through the speakers, one at a time, from History's row.

import AVFoundation
import Foundation

/// One kept recording playing at a time, and which one, so its row can show stop. See `Docs/recordings.md`.
@MainActor
final class RecordingPlayback: NSObject, AVAudioPlayerDelegate {
    /// The recording playing now, if one is.
    private(set) var playing: UUID?
    /// Told whenever ``playing`` changes, so the page is redrawn.
    var onChange: () -> Void = {}

    private var player: AVAudioPlayer?

    /// Plays these WAV bytes as the recording `id`, stopping whatever was playing, with one redraw for both.
    func play(_ wav: Data, id: UUID) {
        let before = playing
        halt()
        if let player = try? AVAudioPlayer(data: wav) {
            player.delegate = self
            if player.play() {
                self.player = player
                playing = id
            }
        }
        if playing != before { onChange() }
    }

    /// Stops the recording playing, if any.
    func stop() {
        guard player != nil else { return }
        halt()
        onChange()
    }

    /// Stops and forgets the player without asking for a redraw.
    private func halt() {
        player?.stop()
        player = nil
        playing = nil
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        let finished = ObjectIdentifier(player)
        Task { @MainActor [weak self] in self?.finish(finished) }
    }

    /// Clears the row once the player that finished is still the one playing.
    private func finish(_ finished: ObjectIdentifier) {
        guard let player, ObjectIdentifier(player) == finished else { return }
        stop()
    }
}
