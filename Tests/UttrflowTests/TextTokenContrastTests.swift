// Tests that the quiet text tokens clear 4.5:1 on every ground the pages, the island and the menu bar set them on.

import Testing

@testable import Uttrflow

@Suite("The quiet text tokens are legible in both appearances")
struct TextTokenContrastTests {
    typealias R = BrandPalette.Redesign
    typealias M = BrandPalette.Redesign.MenuBar

    /// The page's ink at an opacity, the film a settings card, a field or a keycap is drawn in.
    private static func film(_ opacity: Double, over ground: BrandTone) -> BrandTone {
        RedesignTokenTests.composite(
            BrandLayer(tone: R.textStrong, darkOpacity: opacity, lightOpacity: opacity), over: ground)
    }

    /// The page grounds plus the films the settings and pages lay over them.
    private static let grounds: [(String, BrandTone)] =
        RedesignTokenTests.grounds + [
            ("card film", film(0.045, over: R.windowGround)),
            ("search film", film(0.05, over: R.windowGround)),
            ("hover film", film(0.07, over: R.windowGround)),
            ("keycap", film(0.08, over: film(0.05, over: R.windowGround))),
        ]

    private static func expectLegible(
        _ name: String, _ text: BrandTone, on ground: BrandTone, _ surface: String
    ) {
        let dark = contrastRatio(text.dark, ground.dark)
        let light = contrastRatio(text.light, ground.light)
        #expect(dark >= 4.5, "\(name) on dark \(surface) is \(dark)")
        #expect(light >= 4.5, "\(name) on light \(surface) is \(light)")
    }

    @Test("the faint text clears 4.5:1 on the page, a card and every film over them")
    func faintClearsAA() {
        for (surface, ground) in Self.grounds {
            let faint = RedesignTokenTests.composite(R.textFaint, over: ground)
            Self.expectLegible("faint", faint, on: ground, surface)
        }
    }

    @Test("the clipboard's amber as words clears 4.5:1 on the page, a card and its own wash")
    func clipboardInkClearsAA() {
        let wash = RedesignTokenTests.composite(
            BrandLayer(tone: R.clipboardAccent, darkOpacity: 0.1, lightOpacity: 0.1), over: R.windowGround)
        for (surface, ground) in RedesignTokenTests.grounds + [("wash", wash)] {
            Self.expectLegible("clipboard ink", R.clipboardInk, on: ground, surface)
        }
    }

    @Test("the island's quiet words clear 4.5:1 on the island")
    func islandQuietClearsAA() {
        let island = RedesignTokenTests.composite(R.sidebarIsland, over: R.windowGround)
        let quiet = RedesignTokenTests.composite(R.islandQuiet, over: island)
        Self.expectLegible("island quiet", quiet, on: island, "island")
    }

    @Test("a light calendar tile's day number clears 4.5:1 at every shade below the deep ink")
    func calendarNumbersClearAA() {
        let card = Self.film(0.045, over: R.windowGround)
        for shade in stride(from: 0.15, through: 0.66, by: 0.01) {
            let tile = blend(R.dictationAccent.dark, over: card.light, share: shade)
            let number = blend(R.textFaint.tone.light, over: tile, share: R.textFaint.lightOpacity)
            #expect(contrastRatio(number, tile) >= 4.5, "shade \(shade)")
        }
    }

    /// The popover's glass over a mid-grey desktop in each appearance.
    private static let menuGlass = RedesignTokenTests.composite(
        M.glass, over: BrandTone(dark: 0x1E_1E24, light: 0xE8_E8EC))

    @Test("the popover's words clear 4.5:1 on its glass, and the amber pill's ink on the pill")
    func menuBarTextClearsAA() {
        for (name, layer) in [("detail", M.detail), ("quiet", M.quiet), ("hint", M.hint), ("row", M.row)] {
            let text = RedesignTokenTests.composite(layer, over: Self.menuGlass)
            Self.expectLegible(name, text, on: Self.menuGlass, "glass")
        }
        Self.expectLegible("amber", R.clipboardInk, on: Self.menuGlass, "glass")
        Self.expectLegible("pill ink", M.fillInk, on: R.clipboardInk, "amber pill")
    }
}
