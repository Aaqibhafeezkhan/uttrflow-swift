// The redesign's colours as SwiftUI colours, resolved per appearance from `BrandPalette.Redesign`.

import AppKit
import SwiftUI

/// The sidebar island's colours, fixed because the island stays dark in both appearances.
enum IslandPalette {
    private typealias R = BrandPalette.Redesign

    /// The island itself, which is the one layer here that differs by appearance.
    static let ground = Color(nsColor: .orbit(R.sidebarIsland))
    /// Text and icons on the island.
    static let ink = Color(rgb: R.textStrong.dark)
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
