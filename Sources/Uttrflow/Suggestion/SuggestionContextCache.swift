// What a pass was told about the moment, kept briefly so two passes about one line ask the machine once.

import Foundation
import UttrflowContext
import UttrflowPredict

/// Holds the context of the turn in hand, so the alternatives pass and an unchanged window cost no second walk.
actor SuggestionContextCache {
    /// How long a window's surroundings are believed; long enough for one turn, short enough to follow the screen.
    static let surroundingsLifetime = Duration.seconds(1)

    private var built: (turn: Int, situation: GenerationSituation)?
    private var walked: (key: String, surroundings: Surroundings, at: ContinuousClock.Instant)?
    private var walking: (key: String, walk: Task<Surroundings?, Never>)?

    /// What this turn was already told, when it has been told anything.
    func situation(forTurn turn: Int) -> GenerationSituation? {
        built?.turn == turn ? built?.situation : nil
    }

    /// Keeps this turn's context, replacing the turn before it.
    func remember(_ situation: GenerationSituation, forTurn turn: Int) {
        built = (turn, situation)
    }

    /// The window's surroundings, walked only when this window has not been walked lately and is not being walked now.
    func surroundings(
        for key: String, now: ContinuousClock.Instant = ContinuousClock().now,
        reading walk: @escaping @Sendable () async -> Surroundings?
    ) async -> Surroundings? {
        if let walked, walked.key == key, now - walked.at < Self.surroundingsLifetime {
            return walked.surroundings
        }
        if let walking, walking.key == key {
            return await walking.walk.value
        }
        let task = Task { await walk() }
        walking = (key, task)
        let fresh = await task.value
        if walking?.key == key { walking = nil }
        // A walk that timed out is not kept: the next pass should try the window again.
        guard let fresh else { return nil }
        walked = (key, fresh, now)
        return fresh
    }
}
