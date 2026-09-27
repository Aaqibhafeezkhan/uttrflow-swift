// The quick panel's glass, its aurora, the kind filter's segmented control and the panel's colours.

import AppKit
import SwiftUI
import UttrflowUX

/// The panel's ground: tinted glass over the system material, with the aurora rising from the top edge.
struct QuickPanelBackdrop: View {
    var body: some View {
        GeometryReader { proxy in
            Color.panelGlass
                .overlay(alignment: .topLeading) { aurora(width: proxy.size.width) }
        }
        .background(.ultraThinMaterial)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// A blurred conic sweep of the aurora stops, wider than the panel and mostly above it, drawn from a picture blurred once.
    @ViewBuilder private func aurora(width: CGFloat) -> some View {
        if let picture = Self.picture(width: width) {
            Image(nsImage: picture)
                .resizable()
                .frame(
                    width: width * 1.4 + Self.spread * 2,
                    height: QuickPanelMetrics.auroraHeight + Self.spread * 2
                )
                .opacity(BrandPalette.Redesign.Panel.auroraOpacity)
                .offset(x: -width * 0.2 - Self.spread, y: -QuickPanelMetrics.auroraRise - Self.spread)
        }
    }

    /// The aurora for a panel `width` wide, blurred the first time it is asked for, so scrolling the list never re-blurs it.
    @MainActor private static func picture(width: CGFloat) -> NSImage? {
        guard width > 0 else { return nil }
        if let known = blurred, known.width == width { return known.image }
        let stops = BrandPalette.Redesign.auroraStops.map { Color(rgb: $0) }
        let renderer = ImageRenderer(
            content: AngularGradient(
                colors: stops + stops.prefix(1), center: .center,
                startAngle: .degrees(120), endAngle: .degrees(480)
            )
            .frame(width: width * 1.4, height: QuickPanelMetrics.auroraHeight)
            // Room for the blur to spread into, or it stops at the band's edge.
            .padding(spread)
            .blur(radius: spread / 2))
        // A blur has no edges for a Retina pixel to sharpen.
        renderer.scale = 1
        guard let image = renderer.nsImage else { return nil }
        blurred = (width, image)
        return image
    }

    /// The last picture blurred and the width it was blurred for.
    @MainActor private static var blurred: (width: CGFloat, image: NSImage)?

    /// The blur's reach beyond the band.
    private static let spread: CGFloat = 120
}

/// The kind filters as one segmented control; the chosen segment is a solid pill.
struct QuickPanelSegments: View {
    let filters: [PanelFilterChip]
    let choose: (PanelFilter) -> Void

    var body: some View {
        HStack(spacing: 0) {
            ForEach(filters) { chip in
                Button {
                    choose(chip.filter)
                } label: {
                    Text(chip.title)
                        .font(.system(size: 11.5, weight: chip.isActive ? .semibold : .medium))
                        .foregroundStyle(chip.isActive ? Color.panelSegmentInk : Color.panelLabelSoft)
                        .padding(.horizontal, 9)
                        .frame(height: QuickPanelMetrics.segmentHeight)
                        .background(
                            chip.isActive ? Color.panelSegment : .clear, in: .rect(cornerRadius: 7)
                        )
                        .contentShape(.rect)
                        .fixedSize()
                }
                .buttonStyle(.plain)
                .accessibilityLabel(chip.title)
                .accessibilityAddTraits(chip.isActive ? [.isButton, .isSelected] : .isButton)
            }
        }
        .padding(3)
        .background(Color.panelLift, in: .rect(cornerRadius: 10))
        .fixedSize()
    }
}

extension View {
    /// The ⋯ menu's and a sheet's glass, ringed and lifted off the list.
    func panelPopover(
        cornerRadius: CGFloat, shadowOpacity: Double, radius: CGFloat, y: CGFloat
    )
        -> some View
    {
        let shape = RoundedRectangle(cornerRadius: cornerRadius)
        return background(Color.panelPopover, in: shape)
            .background(.ultraThinMaterial, in: shape)
            .clipShape(shape)
            .overlay(shape.strokeBorder(Color.panelLine, lineWidth: 1))
            .shadow(color: .black.opacity(shadowOpacity), radius: radius, y: y)
    }
}

extension Color {
    private typealias P = BrandPalette.Redesign.Panel

    /// The panel's glass, rim and the films on it, each following the appearance.
    static let panelGlass = Color(nsColor: .orbit(P.glass))
    static let panelEdge = Color(nsColor: .orbit(P.edge))
    static let panelCard = Color(nsColor: .orbit(P.film))
    static let panelLift = Color(nsColor: .orbit(P.lift))
    static let panelLine = Color(nsColor: .orbit(P.line))
    static let panelPopover = Color(nsColor: .orbit(P.popover))
    static let panelWell = Color(nsColor: .orbit(P.well))
    static let panelSegment = Color(nsColor: .orbit(P.segment))
    static let panelSegmentInk = Color(nsColor: .orbit(P.segmentInk))
    /// The text tones; contrast ratios are in Docs/app-quick-panel.md.
    static let panelLabel = Color(nsColor: .orbit(P.label))
    static let panelLabelSoft = Color(nsColor: .orbit(P.soft))
    /// The dimmest grey words are allowed, for what the eye reaches only when it goes looking.
    static let panelLabelDim = Color(nsColor: .orbit(P.dim))
    /// Below the dimmest grey, for the row glyph and the ⋯; both lift to ordinary grey when looked at.
    static let panelGhost = Color(nsColor: .orbit(P.ghost))
    /// Where you are: the focused field, the chosen row, the current tab.
    static let panelAccent = Color(nsColor: .orbit(P.accent))
    /// The accent as a foreground; `panelAccent` is mixed to sit under text.
    static let panelAccentBright = Color(nsColor: .orbit(P.accentInk))
    /// Ink on an accent fill.
    static let panelAccentText = Color(nsColor: .orbit(P.onAccent))
    static let panelLink = Color(nsColor: .orbit(BrandPalette.Redesign.infoAccent))
    static let panelCode = Color(nsColor: .orbit(BrandPalette.Redesign.suggestionAccent))
    static let panelKey = Color(nsColor: .orbit(P.key))
    static let panelDestructive = Color(nsColor: .orbit(P.destructive))
}
