// Tests for the Account page's tokens: the banner, the avatar disc, the glass list and sign out.

import Foundation
import Testing

@testable import Uttrflow

@Suite("The profile tokens")
struct ProfileTokenTests {
    typealias R = BrandPalette.Redesign

    @Test("sign out's words clear 4.5:1 on their own wash, in both appearances")
    func signOutIsLegible() {
        let wash = RedesignTokenTests.composite(R.signOutWash, over: R.windowGround)
        #expect(contrastRatio(R.signOutInk.dark, wash.dark) >= 4.5)
        #expect(contrastRatio(R.signOutInk.light, wash.light) >= 4.5)
    }

    /// The initials are large text, so the light disc's deeper ends are held to 3:1 and the dark to 4.5:1.
    @Test("the initials clear the large-text bar on both ends of the disc")
    func avatarInitialsAreLegible() {
        for end in [R.avatarLilac, R.avatarTeal] {
            #expect(contrastRatio(R.avatarInk, end.dark) >= 4.5)
            #expect(contrastRatio(R.avatarInk, end.light) >= 3)
        }
    }

    @Test("the banner stays dark in the light appearance, under white words when dark")
    func bannerStaysDark() {
        #expect(R.bannerGround.dark == R.bannerGround.light)
        #expect(relativeLuminance(R.bannerGround.light) < 0.02)
        #expect(contrastRatio(R.textStrong.dark, R.bannerGround.dark) >= 4.5)
    }

    @Test("the banner's name and address clear 4.5:1 on its ground and its violet, in both appearances")
    func bannerWordsAreLegible() {
        let violet = BrandTone(blend(R.auroraStops[0], over: R.bannerGround.dark, share: 0.75))
        for ground in [R.bannerGround, violet] {
            let soft = RedesignTokenTests.composite(R.bannerSoft, over: ground)
            #expect(contrastRatio(R.bannerInk.dark, ground.dark) >= 4.5)
            #expect(contrastRatio(R.bannerInk.light, ground.light) >= 4.5)
            #expect(contrastRatio(soft.dark, ground.dark) >= 4.5)
            #expect(contrastRatio(soft.light, ground.light) >= 4.5)
        }
    }

    @Test("the glass list is a film, dark when dark and light when light")
    func glassIsAFilm() {
        let glass = RedesignTokenTests.composite(R.glassFill, over: R.windowGround)
        #expect(relativeLuminance(glass.dark) < 0.02)
        #expect(relativeLuminance(glass.light) > 0.75)
        #expect(R.glassRule.darkOpacity < R.glassEdge.darkOpacity)
    }
}
