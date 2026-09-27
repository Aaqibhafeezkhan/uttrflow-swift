// Chains cue players so a failing one hands the cue to the next, ending in silence rather than an error.

/// Tries each player in order and stops at the first that will be heard; silent when none will.
public struct FallbackSoundPlayer: SoundPlayer {
    private let players: [any SoundPlayer]

    /// Tries `players` first to last on every cue.
    public init(_ players: [any SoundPlayer]) {
        self.players = players
    }

    @discardableResult
    public func play(_ sound: CueSound) -> Bool {
        players.contains { $0.play(sound) }
    }

    public func prewarm(_ sounds: [CueSound]) {
        for player in players { player.prewarm(sounds) }
    }
}
