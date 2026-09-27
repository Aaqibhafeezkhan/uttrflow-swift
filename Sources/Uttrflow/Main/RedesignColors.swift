// The redesign's colours as SwiftUI colours, resolved per appearance from `BrandPalette.Redesign`.

import AppKit
import SwiftUI
import UttrflowUX

/// The sidebar island's colours, fixed because the island stays dark in both appearances.
enum IslandPalette {
    private typealias R = BrandPalette.Redesign

    /// The island itself, which is the one layer here that differs by appearance.
    static let ground = Color(nsColor: .orbit(R.sidebarIsland))
    /// Text and icons on the island.
    static let ink = Color(rgb: R.textStrong.dark)
    /// Headings and quiet words on the island.
    static let quiet = Color(nsColor: .orbit(R.islandQuiet))
    /// The selected row's gradient, left bar and edge.
    static let accent = Color(rgb: R.dictationAccent.dark)
    /// The aurora rising from the island's foot, first stop to last.
    static let aurora = R.auroraStops.map { Color(rgb: $0) }
    /// The avatar's disc, lilac to teal.
    static let avatar = [Color(rgb: BrandPalette.Purple.light), Color(rgb: BrandPalette.Teal.primary)]
    /// The initials on the avatar's disc.
    static let avatarInk = Color(rgb: R.avatarInk)
}

extension Color {
    /// The window body the redesigned pages sit in.
    static let redesignWindow = Color(nsColor: .orbit(BrandPalette.Redesign.windowGround))
}

/// The redesigned pages' colours, each following the appearance.
enum PagePalette {
    private typealias R = BrandPalette.Redesign

    static let text = Color(nsColor: .orbit(R.textStrong))
    static let soft = Color(nsColor: .orbit(R.textSoft))
    static let quiet = Color(nsColor: .orbit(R.textQuiet))
    /// Captions, headings and hints drawn in the page's ink, legible on its films too.
    static let faint = Color(nsColor: .orbit(R.textFaint))
    static let card = Color(nsColor: .orbit(R.cardFill))
    static let hero = Color(nsColor: .orbit(R.heroGround))
    static let waveform = Color(nsColor: .orbit(R.waveformInk))
    static let controlFill = Color(nsColor: .orbit(R.controlFill))
    static let controlEdge = Color(nsColor: .orbit(R.controlEdge))
    static let ringTrack = Color(nsColor: .orbit(R.ringTrack))
    /// The ring cut around a rail dot, the window's dark ground in both appearances.
    static let dotRing = Color(rgb: R.windowGround.dark)
    static let cardEdge = Color(nsColor: .orbit(R.cardEdge))
    static let dictation = Color(nsColor: .orbit(R.dictationAccent))
    static let suggestion = Color(nsColor: .orbit(R.suggestionAccent))
    static let clipboard = Color(nsColor: .orbit(R.clipboardAccent))
    /// The clipboard's amber when it is words rather than a mark.
    static let clipboardInk = Color(nsColor: .orbit(R.clipboardInk))
    static let info = Color(nsColor: .orbit(R.infoAccent))
    static let primaryFill = Color(nsColor: .orbit(R.primaryFill))
    static let primaryInk = Color(nsColor: .orbit(R.primaryInk))
    static let destructiveInk = Color(nsColor: .orbit(R.destructiveInk))
    static let quietFill = Color(nsColor: .orbit(R.quietFill))
    static let sheetGlass = Color(nsColor: .orbit(R.sheetGlass))
    static let toastGlass = Color(nsColor: .orbit(R.toastGlass))
    static let scrim = Color(nsColor: .orbit(R.scrim))
    static let floatShadow = Color(nsColor: .orbit(R.floatShadow))
    /// A failure's red, the same token the pages use for critical text.
    static let critical = Color(nsColor: .orbit(BrandPalette.Semantic.criticalInk))
    /// A caution's amber.
    static let caution = Color(nsColor: .orbit(BrandPalette.Semantic.warningInk))
    /// Success's green.
    static let success = Color(nsColor: .orbit(BrandPalette.Semantic.successInk))
    /// The aurora's two glow colours in the hero: its violet and its blue.
    static let glowViolet = Color(rgb: R.auroraStops[0])
    static let glowBlue = Color(rgb: R.auroraStops[2])
}

/// The Settings page's colours, each following the appearance.
enum SettingsPalette {
    private typealias R = BrandPalette.Redesign

    /// The page's ink at an opacity: the film every card, field and control is drawn in.
    static func ink(_ opacity: Double) -> Color { PagePalette.text.opacity(opacity) }

    /// A row tile's or a note's accent.
    static func tint(_ tint: SettingsTint) -> Color {
        switch tint {
        case .dictation: PagePalette.dictation
        case .suggestion: PagePalette.suggestion
        case .amber: PagePalette.clipboard
        case .info: PagePalette.info
        case .mint: mint
        case .neutral: neutral
        case .danger: danger
        }
    }

    static let mint = Color(nsColor: .orbit(R.mintAccent))
    static let neutral = Color(nsColor: .orbit(R.neutralAccent))
    static let danger = Color(nsColor: .orbit(BrandPalette.Semantic.criticalInk))
    static let dangerInk = Color(nsColor: .orbit(R.destructiveInk))
    static let good = Color(nsColor: .orbit(BrandPalette.Semantic.successInk))
    static let dictationInk = Color(nsColor: .orbit(R.badgeInk))
    static let dictationDeep = Color(nsColor: .orbit(R.dictationDeep))
    static let inverseFill = Color(nsColor: .orbit(R.primaryFill))
    static let inverseInk = Color(nsColor: .orbit(R.primaryInk))
}
