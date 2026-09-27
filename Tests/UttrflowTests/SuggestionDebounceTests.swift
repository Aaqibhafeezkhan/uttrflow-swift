// Tests that the model debounce counts from the keystroke, not from the work before the pass (#878).

import Foundation
import Testing

@testable import Uttrflow

@Suite("The quiet before a model pass")
struct SuggestionDebounceTests {
    static let key = Date(timeIntervalSince1970: 1_800_000_000)

    @Test("a key just pressed waits the whole debounce")
    func freshKeystrokeWaitsInFull() {
        let waiting = SuggestionCoordinator.remainingDebounce(sinceKeystroke: Self.key, now: Self.key)
        #expect(waiting == .milliseconds(SuggestionCoordinator.generationDebounceInMilliseconds))
    }

    @Test("work done since the key comes off the wait")
    func workSinceTheKeyCounts() {
        let now = Self.key.addingTimeInterval(0.05)
        let waiting = SuggestionCoordinator.remainingDebounce(sinceKeystroke: Self.key, now: now)
        #expect(waiting < .milliseconds(SuggestionCoordinator.generationDebounceInMilliseconds))
        #expect(waiting > .zero)
    }

    @Test("a pause already longer than the debounce waits no second time")
    func aLongPauseDoesNotWaitAgain() {
        let now = Self.key.addingTimeInterval(5)
        #expect(SuggestionCoordinator.remainingDebounce(sinceKeystroke: Self.key, now: now) == .zero)
    }
}

@Suite("The wake-up after a prose pause")
struct SuggestionHesitationWakeTests {
    static let key = Date(timeIntervalSince1970: 1_800_000_000)

    @Test("a turn settling right at the last key waits the whole pause")
    func settlingAtTheKeyWaitsTheWholePause() {
        #expect(SuggestionCoordinator.hesitationWake(sinceKeystroke: Self.key, now: Self.key) == 420)
    }

    @Test("a turn started before a later key still wakes 400ms after that key (#1623)")
    func aLaterKeyDoesNotPushTheWakeLater() {
        let now = Self.key.addingTimeInterval(0.1)
        #expect(SuggestionCoordinator.hesitationWake(sinceKeystroke: Self.key, now: now) == 320)
    }

    @Test("a pause already long enough wakes at once")
    func aLongPauseWakesAtOnce() {
        let now = Self.key.addingTimeInterval(2)
        #expect(SuggestionCoordinator.hesitationWake(sinceKeystroke: Self.key, now: now) == 20)
    }
}
