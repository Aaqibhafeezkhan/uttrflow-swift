// Tests for the bundled display typeface.

import CoreText
import Foundation
import SwiftUI
import Testing

@testable import Uttrflow

@Suite("The brand typeface")
struct BrandFontTests {
    @Test("the font file and its licence ship in the bundle")
    func shipsWithLicence() {
        #expect(BrandFont.fileURL != nil)
        #expect(Bundle.module.url(forResource: "Outfit-OFL", withExtension: "txt") != nil)
    }

    @Test("registration succeeds, and a second registration still counts as available")
    func registers() {
        #expect(BrandFont.isAvailable)
        #expect(BrandFont.register(BrandFont.fileURL))
    }

    @Test("the registered family resolves to the bundled typeface")
    func resolvesFamily() {
        _ = BrandFont.isAvailable
        let font = CTFontCreateWithName(BrandFont.family as CFString, 20, nil)
        #expect(CTFontCopyFamilyName(font) as String == BrandFont.family)
    }

    @Test("a missing or unreadable file is reported as unavailable")
    func missingFile() {
        #expect(!BrandFont.register(nil))
        #expect(!BrandFont.register(URL(fileURLWithPath: "/nonexistent/font.ttf")))
    }

    @Test("the display font falls back to the system font when the typeface is missing")
    func fallsBack() {
        let fallback = BrandFont.display(size: 20, weight: .bold, available: false)
        let branded = BrandFont.display(size: 20, weight: .bold, available: true)
        #expect(fallback == .system(size: 20, weight: .bold))
        #expect(branded == .custom("Outfit", size: 20).weight(.bold))
        let preferred = BrandFont.display(size: 20, weight: .semibold, available: true)
        #expect(BrandFont.display(size: 20) == preferred)
    }
}
