// Tests that the account picture is decoded once per drawn size and kept for those bytes.

import AppKit
import Testing

@testable import Uttrflow

@MainActor
@Suite("Account pictures")
struct AccountPictureTests {
    /// A square PNG `side` pixels wide, filled with one colour.
    private static func png(side: Int, grey: CGFloat) throws -> Data {
        let space = try #require(CGColorSpace(name: CGColorSpace.sRGB))
        let context = try #require(
            CGContext(
                data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: 0, space: space,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.setFillColor(CGColor(gray: grey, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: side, height: side))
        let image = try #require(context.makeImage())
        return try #require(NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]))
    }

    @Test("a picture is decoded to the size it is drawn at, and kept for that size and those bytes")
    func decodesAtTheDrawnSize() async throws {
        let bytes = try Self.png(side: 400, grey: 0.3)
        let large = try #require(await AccountPictures.image(for: bytes, longestSide: 168))
        #expect(max(large.width, large.height) == 168)
        #expect(AccountPictures.cached(for: bytes, longestSide: 168) === large)
        #expect(AccountPictures.cached(for: bytes, longestSide: 90) == nil)
        #expect(await AccountPictures.image(for: bytes, longestSide: 168) === large)
        #expect(AccountPictures.cached(for: try Self.png(side: 400, grey: 0.6), longestSide: 168) == nil)
    }

    @Test("while the drawn size decodes, the largest size already decoded stands in")
    func anySizeStandsIn() async throws {
        let bytes = try Self.png(side: 300, grey: 0.45)
        #expect(AccountPictures.anyCached(for: bytes) == nil)
        let small = try #require(await AccountPictures.image(for: bytes, longestSide: 40))
        #expect(AccountPictures.anyCached(for: bytes) === small)
        let large = try #require(await AccountPictures.image(for: bytes, longestSide: 180))
        #expect(AccountPictures.anyCached(for: bytes) === large)
    }
}
