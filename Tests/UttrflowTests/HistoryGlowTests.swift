// Tests for History's glows: rendered once, with room for the blur, and the disc left for each tile to tint.

import AppKit
import Testing

@testable import Uttrflow

@MainActor
@Suite("History's glows")
struct HistoryGlowTests {
    /// The alpha of one pixel of `image`, counted from its top-left corner.
    private func alpha(of image: NSImage, x: Int, y: Int) -> CGFloat? {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        return NSBitmapImageRep(cgImage: cgImage).colorAt(x: x, y: y)?.alphaComponent
    }

    @Test("the disc is a template for its tile to tint, with room on every side for its blur")
    func theDiscIsATintableTemplate() throws {
        let disc = try #require(HistoryGlow.disc)
        let side = 90 + HistoryGlow.spill(34) * 2
        #expect(disc.isTemplate)
        #expect(disc.size == CGSize(width: side, height: side))
        let middle = Int(side / 2)
        #expect(try #require(alpha(of: disc, x: middle, y: middle)) > 0.5)
        #expect(try #require(alpha(of: disc, x: 1, y: 1)) < 0.05)
    }

    @Test("each glow is blurred once and handed back after that")
    func eachGlowIsRenderedOnce() throws {
        let disc = try #require(HistoryGlow.disc)
        #expect(HistoryGlow.disc === disc)
        let aurora = try #require(HistoryGlow.aurora)
        #expect(HistoryGlow.aurora === aurora)
        #expect(!aurora.isTemplate)
        #expect(aurora.size.width == 840 + HistoryGlow.spill(70) * 2)
    }
}
