// History's soft glows, blurred once into pictures so scrolling moves bitmaps instead of re-blurring each frame.

import AppKit
import SwiftUI

/// A shape blurred once into a picture, with room around it for the blur to spill, and remembered.
@MainActor
enum HistoryGlow {
    /// How far past its shape a blur of this radius is still visible.
    static func spill(_ radius: CGFloat) -> CGFloat { radius * 3 }

    private static var pictures: [String: NSImage] = [:]

    /// The aurora behind the header, drawn at a typical page width; the page stretches it to its own.
    static var aurora: NSImage? {
        picture("aurora", size: CGSize(width: 840, height: 220), radius: 70) {
            AngularGradient(
                colors: IslandPalette.aurora + [IslandPalette.aurora[0]], center: .center,
                angle: .degrees(210))
        }
    }

    /// A white disc as a template, tinted by whichever tile draws it.
    static var disc: NSImage? {
        let image = picture("disc", size: CGSize(width: 90, height: 90), radius: 34) {
            Circle().fill(.white)
        }
        image?.isTemplate = true
        return image
    }

    /// `content` at `size`, blurred by `radius` inside its spill, rendered the first time it is asked for.
    private static func picture(
        _ key: String, size: CGSize, radius: CGFloat, content: () -> some View
    ) -> NSImage? {
        if let known = pictures[key] { return known }
        let spill = spill(radius)
        let renderer = ImageRenderer(
            content: content()
                .frame(width: size.width, height: size.height)
                .blur(radius: radius)
                .frame(width: size.width + spill * 2, height: size.height + spill * 2))
        // A blur has no edges for a Retina pixel to sharpen.
        renderer.scale = 1
        guard let image = renderer.nsImage else { return nil }
        pictures[key] = image
        return image
    }
}
