// Tests for the redesign's colours as the window resolves them.

import AppKit
import SwiftUI
import Testing

@testable import Uttrflow

/// The island must not follow the light, and the window ground must.
@MainActor
@Suite("The redesign's colours")
struct RedesignColorsTests {
    private func components(_ colour: NSColor, in appearance: NSAppearance.Name) -> [CGFloat] {
        var resolved: [CGFloat] = []
        NSAppearance(named: appearance)?.performAsCurrentDrawingAppearance {
            let srgb = colour.usingColorSpace(.sRGB) ?? colour
            resolved = [
                srgb.redComponent, srgb.greenComponent, srgb.blueComponent, srgb.alphaComponent,
            ]
        }
        return resolved.map { ($0 * 255).rounded() / 255 }
    }

    /// The island is dark in both appearances, so its ink and accent must not move with the theme.
    @Test("the island's ink and accent are the same in both appearances")
    func islandInksAreFixed() {
        for colour in [IslandPalette.ink, IslandPalette.accent, IslandPalette.avatarInk] {
            #expect(components(NSColor(colour), in: .darkAqua) == components(NSColor(colour), in: .aqua))
        }
        #expect(IslandPalette.aurora.count == BrandPalette.Redesign.auroraStops.count)
        #expect(IslandPalette.avatar.count == 2)
    }

    @Test("the island's ground stays dark in the light appearance")
    func islandGroundStaysDark() {
        let light = components(NSColor(IslandPalette.ground), in: .aqua)
        #expect((light[0] + light[1] + light[2]) / 3 < 0.15)
    }

    @Test("the window ground follows the appearance")
    func windowFollows() {
        let dark = components(NSColor(Color.redesignWindow), in: .darkAqua)
        let light = components(NSColor(Color.redesignWindow), in: .aqua)
        #expect(dark[0] < 0.1)
        #expect(light[0] > 0.9)
    }
}
