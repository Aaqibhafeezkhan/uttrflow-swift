// Tests the speech model load's guessed progress and the time-left words it gives.
import Testing

@testable import UttrflowCore

@Suite("The estimate shown while the speech model loads")
struct SpeechModelLoadEstimateTests {
    private typealias Estimate = SpeechModelLoadEstimate

    /// Every quarter second from zero to well past the typical load.
    private static let sweep = (0...1_600).map { Duration.milliseconds($0 * 250) }

    @Test("starts empty, and fills to exactly the ceiling at the typical cold load")
    func endpoints() {
        #expect(Estimate(elapsed: .zero).fraction == 0)
        #expect(abs(Estimate(elapsed: Estimate.typicalColdLoad).fraction - Estimate.ceiling) < 1e-12)
        #expect(Estimate.ceiling == 0.9)
    }

    @Test("never goes backwards as the load runs on")
    func monotonic() {
        let fractions = Self.sweep.map { Estimate(elapsed: $0).fraction }
        for (earlier, later) in zip(fractions, fractions.dropFirst()) {
            #expect(later >= earlier)
        }
    }

    @Test("keeps moving until the typical load time, so the bar never looks stuck early")
    func strictlyRisesBeforeTheCeiling() {
        let before = Self.sweep.filter { $0 <= Estimate.typicalColdLoad }.map {
            Estimate(elapsed: $0).fraction
        }
        for (earlier, later) in zip(before, before.dropFirst()) {
            #expect(later > earlier)
        }
    }

    @Test("never passes the ceiling before the model is ready, however long the load runs")
    func neverPastTheCeiling() {
        for elapsed in Self.sweep + [.seconds(3_600), .seconds(86_400)] {
            let fraction = Estimate(elapsed: elapsed).fraction
            #expect(fraction >= 0)
            #expect(fraction <= Estimate.ceiling)
        }
    }

    @Test("eases out, covering more ground in its first half than its second")
    func easesOut() {
        let half = Estimate(elapsed: Estimate.typicalColdLoad / 2).fraction

        #expect(half > Estimate.ceiling / 2)
        #expect(abs(half - Estimate.ceiling * 0.75) < 1e-12)
    }

    @Test("holds at the ceiling from the typical load time on, and says almost ready")
    func holds() {
        for elapsed in [Estimate.typicalColdLoad, Estimate.typicalColdLoad + .seconds(1), .seconds(600)] {
            let estimate = Estimate(elapsed: elapsed)
            #expect(estimate.isHolding)
            #expect(estimate.fraction == Estimate.ceiling)
            #expect(estimate.remaining == .zero)
            #expect(estimate.timeLeft == "almost ready")
            #expect(estimate.shortTimeLeft == "almost")
            #expect(estimate.spokenTimeLeft == "almost ready")
            #expect(estimate.heading == "Almost ready…")
            #expect(estimate.spokenHeading == "Almost ready")
        }
        #expect(!Estimate(elapsed: Estimate.typicalColdLoad - .milliseconds(1)).isHolding)
    }

    @Test("a negative elapsed time is read as none")
    func negativeIsZero() {
        let estimate = Estimate(elapsed: .seconds(-3))

        #expect(estimate.elapsed == .zero)
        #expect(estimate.fraction == 0)
        #expect(estimate.remaining == Estimate.typicalColdLoad)
    }

    @Test(
        "says about 2 min, about 1 min, less than a minute, then almost ready, switching exactly at each boundary",
        arguments: [
            (
                Estimate.twoMinutesAbove + .milliseconds(1), "about 2 min left", "~2 min",
                "about 2 minutes left"
            ),
            (Estimate.twoMinutesAbove, "about 1 min left", "~1 min", "about 1 minute left"),
            (Estimate.oneMinuteAbove + .milliseconds(1), "about 1 min left", "~1 min", "about 1 minute left"),
            (Estimate.oneMinuteAbove, "less than a minute left", "<1 min", "less than a minute left"),
            (.milliseconds(1), "less than a minute left", "<1 min", "less than a minute left"),
            (.zero, "almost ready", "almost", "almost ready"),
        ])
    func phrasesAtTheBoundaries(left: Duration, long: String, short: String, spoken: String) {
        let estimate = Estimate(elapsed: Estimate.typicalColdLoad - left)

        #expect(estimate.remaining == left)
        #expect(estimate.timeLeft == long)
        #expect(estimate.shortTimeLeft == short)
        #expect(estimate.spokenTimeLeft == spoken)
    }

    @Test("the first estimate a person sees, at five seconds, says about 2 min")
    func firstEstimate() {
        let estimate = Estimate(elapsed: SpeechModelLoad.estimateAfter)

        #expect(estimate.timeLeft == "about 2 min left")
        #expect(estimate.heading == "Getting ready · about 2 min left")
        #expect(estimate.spokenHeading == "Getting ready, about 2 minutes left")
        #expect(estimate.fraction > 0)
        #expect(estimate.fraction < 0.1)
    }

    @Test("the phrases only ever count down as the load runs on")
    func phrasesCountDown() {
        let order = ["about 2 min left", "about 1 min left", "less than a minute left", "almost ready"]
        let ranks = Self.sweep.compactMap { order.firstIndex(of: Estimate(elapsed: $0).timeLeft) }

        #expect(ranks.count == Self.sweep.count)
        #expect(ranks == ranks.sorted())
        #expect(Set(ranks) == Set(order.indices))
    }
}
