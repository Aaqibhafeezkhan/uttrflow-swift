// Tests for the home hero's picture fade and the collapsed sidebar's room for the traffic lights.

import AppKit
import Testing

@testable import Uttrflow

@MainActor
@Suite("Home chrome", .timeLimit(.minutes(1)), .serialized)
struct HomeChromeTests {
    @Test("the light fade eases in over more of the picture than the dark one")
    func lightFadeIsLongerAndEased() {
        let light = HomeMoodPicture.lightFade.map(\.location)
        #expect(light.first == 0)
        #expect(abs((light.last ?? 0) - 0.6) < 0.0001)
        #expect(light == light.sorted())
        #expect(HomeMoodPicture.darkFade.map(\.location) == [0, 0.42])
    }
}
