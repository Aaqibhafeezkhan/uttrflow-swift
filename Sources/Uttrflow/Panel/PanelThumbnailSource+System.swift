// The real thumbnail decoder, via ImageIO.

import AppKit
import ImageIO
import UniformTypeIdentifiers

extension PanelThumbnailSource {
    /// Decoded to the drawn size by `CGImageSourceCreateThumbnailAtIndex`, so the full picture is never held.
    static let system = PanelThumbnailSource { file, maxPixel in
        guard let source = CGImageSourceCreateWithURL(file as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: PanelThumbnailSource.longestEdge(
                of: source, covering: maxPixel),
        ]
        guard
            let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
        else { return nil }
        return NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
    }

    /// The longest edge that leaves the shorter one at `edge`, so a fill-cropped thumbnail is never upscaled.
    static func longestEdge(of source: CGImageSource, covering edge: Int) -> Int {
        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        guard let width = properties?[kCGImagePropertyPixelWidth] as? Int,
            let height = properties?[kCGImagePropertyPixelHeight] as? Int
        else { return edge }
        return longestEdge(width: width, height: height, covering: edge)
    }

    /// The same from the picture's size; a panorama is capped at four times `edge`, since the row crops it anyway.
    static func longestEdge(width: Int, height: Int, covering edge: Int) -> Int {
        let shorter = min(width, height)
        let longer = max(width, height)
        guard shorter > 0, shorter > edge else { return max(edge, min(longer, edge * 4)) }
        let scaled = (longer * edge + shorter - 1) / shorter
        return min(scaled, edge * 4)
    }
}
