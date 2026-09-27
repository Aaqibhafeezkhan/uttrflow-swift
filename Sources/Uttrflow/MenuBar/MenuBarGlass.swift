// The menu bar popover's aurora glass and its colours, resolved per appearance from `BrandPalette`.

import AppKit
import SwiftUI
import UttrflowUX

// MARK: - Glass

/// The aurora rising behind the header, clipped by the glass.
struct MenuBarAurora: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let stops = BrandPalette.Redesign.auroraStops.map { Color(rgb: $0) }
        let opacity = BrandPalette.Redesign.MenuBar.glowOpacity
        AngularGradient(
            colors: stops + [stops[0]], center: UnitPoint(x: 0.5, y: 0.6),
            startAngle: .degrees(120), endAngle: .degrees(480)
        )
        .frame(width: MenuBarPopoverView.width + 80, height: 200)
        .blur(radius: 40)
        .opacity(scheme == .dark ? opacity.dark : opacity.light)
        .offset(y: -90)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

extension View {
    /// The popover's glass: the tint over the system material, a hairline edge and a soft shadow.
    func menuBarGlass() -> some View {
        let shape = RoundedRectangle(cornerRadius: 18)
        return clipShape(shape)
            .background(MenuBarColour.glass, in: shape)
            .background(.ultraThinMaterial, in: shape)
            .overlay(shape.strokeBorder(MenuBarColour.glassEdge, lineWidth: 1))
            // Clipped and flattened before the shadow, or the material's rectangular backing leaks a square halo.
            .clipShape(shape)
            .compositingGroup()
            .shadow(color: MenuBarColour.shadow, radius: 20, y: 12)
    }
}

// MARK: - Colours

/// The popover's colours, each following the appearance.
enum MenuBarColour {
    private typealias M = BrandPalette.Redesign.MenuBar
    private typealias R = BrandPalette.Redesign

    static let glass = Color(nsColor: .orbit(M.glass))
    static let glassEdge = Color(nsColor: .orbit(M.glassEdge))
    static let shadow = Color(nsColor: .orbit(M.shadow))
    static let tile = Color(nsColor: .orbit(M.tile))
    static let fillInk = Color(nsColor: .orbit(M.fillInk))
    static let text = Color(nsColor: .orbit(R.textStrong))
    static let hint = Color(nsColor: .orbit(M.hint))
    static let buttonLabel = Color(nsColor: .orbit(M.buttonLabel))
    static let detail = Color(nsColor: .orbit(M.detail))
    static let row = Color(nsColor: .orbit(M.row))
    static let quiet = Color(nsColor: .orbit(M.quiet))
    static let track = Color(nsColor: .orbit(M.track))
    static let rule = Color(nsColor: .orbit(M.rule))
    static let buttonFill = Color(nsColor: .orbit(M.buttonFill))
    static let buttonEdge = Color(nsColor: .orbit(M.buttonEdge))
    static let keycap = Color(nsColor: .orbit(M.keycap))
    static let hover = Color(nsColor: .orbit(M.hover))
    static let dictation = Color(nsColor: .orbit(R.dictationAccent))
    static let amber = Color(nsColor: .orbit(R.clipboardAccent))
    static let live = Color(rgb: BrandPalette.Semantic.recording)
    /// The progress fill, aurora blue into dictation teal.
    static let progress = LinearGradient(
        colors: [Color(rgb: R.auroraStops[2]), dictation], startPoint: .leading, endPoint: .trailing)

    /// A status dot or pill: teal at work, red while listening, amber when the user is needed.
    static func dot(_ emphasis: MenuBarEmphasis) -> Color {
        switch emphasis {
        case .normal: dictation
        case .live: live
        case .attention: amber
        }
    }
}
