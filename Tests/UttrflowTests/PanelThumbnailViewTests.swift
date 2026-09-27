// Tests that a picture clip's thumbnail draws from the cache at once, and the card colour until it has one.

import AppKit
import SwiftUI
import Testing

@testable import Uttrflow

@MainActor
@Suite("A picture clip's thumbnail")
struct PanelThumbnailViewTests {
    /// The colour at the middle of `view` drawn at the row's size.
    private func middle(of view: some View) -> NSColor? {
        let renderer = ImageRenderer(content: view.frame(width: 34, height: 34))
        renderer.scale = 1
        guard let cgImage = renderer.cgImage else { return nil }
        return NSBitmapImageRep(cgImage: cgImage).colorAt(x: 17, y: 17)?.usingColorSpace(.sRGB)
    }

    /// A solid red picture on disk, as a copied screenshot would be.
    private func redPicture() throws -> URL {
        let rep = try #require(
            NSBitmapImageRep(
                bitmapDataPlanes: nil, pixelsWide: 80, pixelsHigh: 80, bitsPerSample: 8, samplesPerPixel: 4,
                hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0))
        for x in 0..<80 {
            for y in 0..<80 { rep.setColor(NSColor(deviceRed: 1, green: 0, blue: 0, alpha: 1), atX: x, y: y) }
        }
        let file = FileManager.default.temporaryDirectory
            .appending(path: "uttrflow-thumbnail-view-\(UUID().uuidString).png")
        try #require(rep.representation(using: .png, properties: [:])).write(to: file)
        return file
    }

    @Test("a row scrolled back into view draws its cached picture at once")
    func aCachedPictureDrawsAtOnce() async throws {
        let file = try redPicture()
        defer { try? FileManager.default.removeItem(at: file) }
        #expect(await PanelThumbnails.shared.picture(for: file) != nil)
        let colour = try #require(middle(of: PanelThumbnailView(file: file)))
        #expect(colour.redComponent > 0.9)
        #expect(colour.greenComponent < 0.3)
        #expect(colour.blueComponent < 0.3)
        #expect(colour != middle(of: Color.panelCard))
    }

    @Test("a picture not decoded yet draws the card colour, not an empty hole")
    func aMissDrawsTheCard() throws {
        let file = URL(fileURLWithPath: "/tmp/uttrflow-never-decoded-\(UUID().uuidString).png")
        let drawn = try #require(middle(of: PanelThumbnailView(file: file)))
        let card = try #require(middle(of: Color.panelCard))
        #expect(drawn == card)
        #expect(drawn.alphaComponent > 0)
    }
}
