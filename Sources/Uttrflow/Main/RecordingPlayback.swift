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

    /// Plays these WAV bytes as the recording `id`, stopping whatever was playing before.
    func play(_ wav: Data, id: UUID) {
        stop()
        guard let player = try? AVAudioPlayer(data: wav) else { return }
        player.delegate = self
        guard player.play() else { return }
        self.player = player
        playing = id
        onChange()
    }

    /// Stops the recording playing, if any.
    func stop() {
        guard let player else { return }
        player.stop()
        self.player = nil
        playing = nil
        onChange()
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
