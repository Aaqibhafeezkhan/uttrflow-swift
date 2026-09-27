// Tests that every Insights calendar tile's day number clears 4.5:1 in both appearances.

import Testing
import UttrflowUX

@testable import Uttrflow

@Suite("The Insights calendar's day numbers are legible on every shade")
struct InsightsCalendarContrastTests {
    typealias R = BrandPalette.Redesign

    /// A spoken-on tile at this share of the busiest day.
    private static func tile(_ fraction: Double) -> InsightsCalendarDay {
        InsightsCalendarDay(
            date: .now, number: "1", words: 1, fraction: fraction, isToday: false, detail: "")
    }

    @Test("the number clears 4.5:1 on its tile from the quietest day to the busiest, dark and light")
    func everyShadeClearsAA() {
        let card = RedesignTokenTests.composite(
            BrandLayer(tone: R.textStrong, darkOpacity: 0.045, lightOpacity: 0.045), over: R.windowGround)
        for step in 0...100 {
            let day = Self.tile(Double(step) / 100)
            let ink = day.usesDeepInk ? BrandTone(R.calendarDeepInk) : R.textStrong
            let dark = blend(R.dictationAccent.dark, over: card.dark, share: day.shade)
            let light = blend(R.dictationAccent.dark, over: card.light, share: day.shade)
            #expect(
                contrastRatio(ink.dark, dark) >= 4.5, "dark at \(step)%: \(contrastRatio(ink.dark, dark))")
            #expect(contrastRatio(ink.light, light) >= 4.5, "light at \(step)%")
        }
    }
}
