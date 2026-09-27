// Plays recording cues through AppKit's system sounds, unshaped, when the shaped player cannot.
import UttrflowCore
private import AppKit
private import Synchronization

/// The part that makes noise, excluded from coverage; whether to play lives next door and is tested.
// MARK: - The part that makes noise
/// Plays a cue's named system sound at the cue's volume, without its pitch or filter; see Docs/audio-capture.md.
public final class SystemSoundPlayer: SoundPlayer {
    /// Sounds are kept rather than looked up per cue, since a restart is only reliable on the same instance.
    private let sounds = Mutex<[SystemSound: NSSound]>([:])

    public init() {}

    @discardableResult
    public func play(_ cue: CueSound) -> Bool {
        guard let nsSound = resolve(cue.sound) else { return false }

        // Stopped first, so a retrigger inside the previous cue's tail restarts the sound instead of failing.
        nsSound.stop()
        nsSound.volume = cue.volume
        return nsSound.play()
    }

    public func prewarm(_ cues: [CueSound]) {
        // Warming each is cheap and does not assume which sound a cue reaches for first.
        for cue in cues {
            guard let nsSound = resolve(cue.sound) else { continue }
            nsSound.volume = 0
            nsSound.play()
            nsSound.stop()
        }
    }

    /// Looks a sound up once and keeps it; `nil` for a name the system has no sound for.
    private func resolve(_ sound: SystemSound) -> NSSound? {
        sounds.withLock { cache in
            if let existing = cache[sound] { return existing }
            guard let loaded = NSSound(named: NSSound.Name(sound.name)) else { return nil }
            cache[sound] = loaded
            return loaded
        }
    }
}
