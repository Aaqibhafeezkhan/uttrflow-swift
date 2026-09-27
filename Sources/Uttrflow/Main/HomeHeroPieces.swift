// Home hero's pieces: the start pill's glow and the mood picture with its loader.

import UttrflowUX
import AppKit
import ImageIO
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
    /// The picture being shown, decoded away from the main thread; `nil` until the first one is ready.
    @State private var shown: MoodPictures.Picture?

    /// The widest the picture is drawn, and the narrowest before it is left out.
    static let widest: CGFloat = 390
    static let narrowest: CGFloat = 150

    init(mood: HomeMood) {
        self.mood = mood
        _shown = State(initialValue: MoodPictures.cached(for: mood))
    }

    var body: some View {
        GeometryReader { proxy in
            let width = min(Self.widest, proxy.size.width - HomeHeroCard.contentWidth - 30)
            if width >= Self.narrowest, let shown {
                picture(shown.image, width: width, height: proxy.size.height)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .id(shown.mood)
                    .transition(.opacity)
            }
        }
        .accessibilityHidden(true)
        .task(id: mood) {
            guard shown?.mood != mood, let next = await MoodPictures.picture(for: mood) else { return }
            withAnimation(MotionBudget.current().allowing(.easeInOut(duration: 0.35))) { shown = next }
        }
    }

    /// The picture cropped to fill, a little above centre, masked to fade in from the left.
    private func picture(_ image: CGImage, width: CGFloat, height: CGFloat) -> some View {
        let scaled = image.width > 0 ? width * CGFloat(image.height) / CGFloat(image.width) : height
        return Image(decorative: image, scale: 1)
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

/// The mood pictures, decoded off the main thread at the size they are drawn, keeping only the latest.
@MainActor
enum MoodPictures {
    /// One decoded picture and the mood it belongs to.
    struct Picture: @unchecked Sendable {
        let mood: HomeMood
        let image: CGImage
    }

    /// The longest side decoded, in pixels: the widest the picture is drawn at 2x, over its 4:5 shape.
    static let pixels = Int(HomeMoodPicture.widest * 2 * 1.25)
    private static var last: Picture?

    /// The picture for a mood if it is the one already decoded.
    static func cached(for mood: HomeMood) -> Picture? {
        last?.mood == mood ? last : nil
    }

    /// The picture for a mood, decoding it away from the main thread when it is not the one kept; `nil` when the bundle lacks it.
    static func picture(for mood: HomeMood) async -> Picture? {
        if let kept = cached(for: mood) { return kept }
        guard let url = Bundle.module.url(forResource: mood.imageName, withExtension: "jpg") else {
            return nil
        }
        let limit = pixels
        let image = await Task.detached(priority: .userInitiated) {
            PictureDecoder.thumbnail(at: url, longestSide: limit)
        }.value
        guard let image else { return nil }
        let picture = Picture(mood: mood, image: image)
        last = picture
        return picture
    }
}

/// Decodes a picture straight to the size it is drawn, fully, so drawing it never decodes on the main thread.
enum PictureDecoder {
    /// The picture in the file at `url`, no longer than `longestSide` pixels on either side.
    nonisolated static func thumbnail(at url: URL, longestSide: Int) -> CGImage? {
        CGImageSourceCreateWithURL(url as CFURL, nil).flatMap {
            thumbnail(from: $0, longestSide: longestSide)
        }
    }

    /// The picture in `data`, no longer than `longestSide` pixels on either side.
    nonisolated static func thumbnail(of data: Data, longestSide: Int) -> CGImage? {
        CGImageSourceCreateWithData(data as CFData, nil).flatMap {
            thumbnail(from: $0, longestSide: longestSide)
        }
    }

    private nonisolated static func thumbnail(from source: CGImageSource, longestSide: Int) -> CGImage? {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: longestSide,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }
}
