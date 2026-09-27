// Home hero's pieces: the start pill's glow and the mood picture with its loader.

import UttrflowUX
import AppKit
import SwiftUI

/// The start pill's glow as fading circular rings, drawn without blur or shadow so it never shows a hard edge.
struct PillGlow: View {
    let inner: Color
    let outer: Color
    /// How strong the glow is, from 0 to 1.
    let strength: Double

    var body: some View {
        ZStack {
            // Lilac softening inward from the rim.
            ForEach(1..<5) { step in
                Capsule(style: .circular)
                    .inset(by: CGFloat(step) * 2)
                    .stroke(inner.opacity(0.16 * strength / Double(step)), lineWidth: 2)
            }
            // Teal fading outward past the rim, eased so no ring stands out.
            ForEach(1..<11) { step in
                Capsule(style: .circular)
                    .stroke(outer.opacity(0.2 * strength * pow(1 - Double(step) / 11, 2)), lineWidth: 1.5)
                    .padding(-CGFloat(step) * 1.2)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// The picture for the part of the day, filling the card's right side and fading into it.
struct HomeMoodPicture: View {
    let mood: HomeMood

    @Environment(\.colorScheme) private var colorScheme

    /// The widest the picture is drawn, and the narrowest before it is left out.
    static let widest: CGFloat = 390
    static let narrowest: CGFloat = 150

    var body: some View {
        GeometryReader { proxy in
            let width = min(Self.widest, proxy.size.width - HomeHeroCard.contentWidth - 30)
            if width >= Self.narrowest, let image = MoodPictures.image(for: mood) {
                picture(image, width: width, height: proxy.size.height)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .accessibilityHidden(true)
    }

    /// The picture cropped to fill, a little above centre, masked to fade in from the left.
    private func picture(_ image: NSImage, width: CGFloat, height: CGFloat) -> some View {
        let scaled = image.size.width > 0 ? width * image.size.height / image.size.width : height
        return Image(nsImage: image)
            .resizable()
            .interpolation(.high)
            .aspectRatio(contentMode: .fill)
            .frame(width: width, height: height)
            // Framed at 40% down rather than 50%, where the faces sit.
            .offset(y: max(0, scaled - height) * 0.1)
            .frame(width: width, height: height)
            .clipped()
            .mask {
                LinearGradient(
                    stops: colorScheme == .dark ? Self.darkFade : Self.lightFade,
                    startPoint: .leading, endPoint: .trailing)
            }
    }

    /// Clear to opaque over the left 42%, which a dark picture on the dark card needs no more than.
    static let darkFade: [Gradient.Stop] = [
        .init(color: .clear, location: 0), .init(color: .black, location: 0.42),
    ]

    /// An eased ramp over the left 60%, so a dark picture on the white card starts with no visible edge.
    static let lightFade: [Gradient.Stop] = [0, 0.02, 0.08, 0.19, 0.34, 0.52, 0.7, 0.85, 0.95, 1]
        .enumerated().map { index, opacity in
            .init(color: .black.opacity(opacity), location: Double(index) / 9 * 0.6)
        }
}

/// The six mood pictures, read from the bundle once each.
@MainActor
enum MoodPictures {
    private static var loaded: [HomeMood: NSImage] = [:]

    /// The picture for a mood, or `nil` when the bundle lacks it.
    static func image(for mood: HomeMood) -> NSImage? {
        if let image = loaded[mood] { return image }
        let image = Bundle.module.image(forResource: mood.imageName)
        loaded[mood] = image
        return image
    }
}
