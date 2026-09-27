// Tests for the size bound a copied picture meets before any of its pixels are decoded.

import AppKit
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers

@testable import UttrflowClipboard

/// A picture's header is read first; one over the bound is never decoded, and one over the edge is decoded small.
@Suite("A copied picture is bounded by its header before it is decoded")
struct PictureBoundTests {
    /// A PNG that is only a header claiming `side`×`side` one-bit pixels, with filler where the pixels would be.
    static func headerOnlyPNG(side: UInt32) -> Data {
        let header = bigEndian(side) + bigEndian(side) + [1, 0, 0, 0, 0]
        let filler = [UInt8](repeating: 0, count: 64_000)
        return Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
            + chunk("IHDR", header) + chunk("IDAT", filler) + chunk("IEND", [])
    }

    /// A PackBits TIFF that is only a header claiming `side`×`side` one-bit pixels over a kilobyte of filler.
    static func headerOnlyTIFF(side: Int) -> Data {
        let entries: [(tag: Int, type: Int, value: Int)] = [
            (256, 4, side), (257, 4, side), (258, 3, 1), (259, 3, 32773), (262, 3, 1),
            (273, 4, 8 + 2 + 9 * 12 + 4), (277, 3, 1), (278, 4, side), (279, 4, 1_000),
        ]
        var bytes: [UInt8] =
            [0x49, 0x49, 42, 0] + littleEndian(8, width: 4) + littleEndian(entries.count, width: 2)
        for entry in entries {
            bytes +=
                littleEndian(entry.tag, width: 2) + littleEndian(entry.type, width: 2)
                + littleEndian(1, width: 4)
            bytes +=
                littleEndian(entry.value, width: entry.type == 3 ? 2 : 4) + (entry.type == 3 ? [0, 0] : [])
        }
        return Data(bytes + littleEndian(0, width: 4) + [UInt8](repeating: 0, count: 1_000))
    }

    static func bigEndian(_ value: UInt32) -> [UInt8] {
        [24, 16, 8, 0].map { UInt8(truncatingIfNeeded: value >> $0) }
    }

    static func littleEndian(_ value: Int, width: Int) -> [UInt8] {
        (0..<width).map { UInt8(truncatingIfNeeded: value >> ($0 * 8)) }
    }

    /// One PNG chunk: length, type, body and the CRC-32 of type and body.
    static func chunk(_ type: String, _ body: [UInt8]) -> [UInt8] {
        let named = Array(type.utf8) + body
        var crc: UInt32 = 0xFFFF_FFFF
        for byte in named {
            crc ^= UInt32(byte)
            for _ in 0..<8 { crc = (crc >> 1) ^ (0xEDB8_8320 & (0 &- (crc & 1))) }
        }
        return bigEndian(UInt32(body.count)) + named + bigEndian(~crc)
    }

    /// The size a reading refused at, or `nil` when it was not a refusal.
    static func refusal(_ reading: PictureFlavour.Reading) -> [Int]? {
        guard case .refused(let width, let height) = reading else { return nil }
        return [width, height]
    }

    @Test(
        "the standard bound refuses a picture of 150 megapixels and more, and stores at most 4096 pixels long"
    )
    func standardBound() {
        #expect(ClipboardBudget.standard.largestPicture == 150_000_000)
        #expect(ClipboardBudget.standard.pictureEdge == 4096)
        #expect(PictureFlavour.fits((12_000, 12_000), within: .standard))
        #expect(!PictureFlavour.fits((12_300, 12_300), within: .standard))
    }

    @Test("a header too large to multiply is refused rather than wrapping round to a small number")
    func overflowRefused() {
        #expect(!PictureFlavour.fits((Int.max, 2), within: .standard))
        #expect(PictureFlavour.fits((Int.max, 2), within: .standard.limiting(largestPicture: 0)))
    }

    @Test("a PNG header claiming 20000×20000 is refused, not kept, though it is never decoded either way")
    func oversizePNGRefused() {
        let png = Self.headerOnlyPNG(side: 20_000)
        #expect(Self.refusal(PictureFlavour.readingPNG(png, within: .standard)) == [20_000, 20_000])
        #expect(PictureFlavour.fromPNG(png) == nil)
        #expect(PictureFlavour.converting(png) == nil)
    }

    @Test("a TIFF header claiming 20000×20000 is refused before the decoder is asked for anything")
    func oversizeTIFFNeverDecoded() {
        var asked: [Int] = []
        let reading = PictureFlavour.reading(Self.headerOnlyTIFF(side: 20_000), within: .standard) {
            _, edge in
            asked.append(edge)
            return nil
        }
        #expect(Self.refusal(reading) == [20_000, 20_000])
        #expect(asked.isEmpty)
    }

    @Test("with no pixel bound the same header is decoded no longer than the stored edge")
    func unboundedStillDownsampled() {
        var asked: [Int] = []
        let reading = PictureFlavour.reading(
            Self.headerOnlyTIFF(side: 20_000), within: .standard.limiting(largestPicture: 0)
        ) { _, edge in
            asked.append(edge)
            return nil
        }
        #expect(asked == [4096])
        #expect(reading.picture == nil)
    }

    @Test("a picture within the edge is decoded at its own size")
    func withinEdgeFullSize() throws {
        var asked: [Int] = []
        let jpeg = try PictureFlavourTests.encoded(
            PictureFlavourTests.image(width: 40, height: 30), as: .jpeg)
        let reading = PictureFlavour.reading(jpeg, within: .standard) { source, edge in
            asked.append(edge)
            return PictureFlavour.upright(from: source, edge: edge)
        }
        #expect(asked == [40])
        #expect(reading.picture?.width == 40)
    }

    @Test(
        "a picture over the edge is stored downsampled to it, keeping its shape",
        arguments: [UTType.jpeg, .tiff, .heic])
    func overEdgeDownsampled(_ type: UTType) throws {
        let data = try PictureFlavourTests.encoded(
            PictureFlavourTests.image(width: 400, height: 300), as: type)
        let picture = try #require(
            PictureFlavour.converting(data, within: .standard.limiting(pictureEdge: 100)))
        #expect(picture.width == 100)
        #expect((75...76).contains(picture.height))  // HEIC rounds the shorter side up by a pixel.
        let stored = try #require(CGImageSourceCreateWithData(picture.data as CFData, nil))
        #expect(CGImageSourceGetType(stored) == UTType.png.identifier as CFString)
    }

    @Test("a PNG over the edge but within the bound is still kept byte for byte")
    func pngOverEdgeKept() throws {
        let png = try PictureFlavourTests.encoded(
            PictureFlavourTests.image(width: 400, height: 300), as: .png)
        #expect(PictureFlavour.fromPNG(png, within: .standard.limiting(pictureEdge: 100))?.data == png)
    }

    @Test("unreadable bytes are neither kept nor refused")
    func unreadable() {
        guard case .unreadable = PictureFlavour.reading(Data("not a picture".utf8), within: .standard) else {
            Issue.record("garbage was read as a picture")
            return
        }
    }
}

/// The real clipboard's picture read, against a private pasteboard so no test touches the user's.
@Suite("The clipboard's picture is read from compressed flavours first and bounded")
@MainActor
struct PasteboardPictureTests {
    /// A pasteboard of its own, released when `body` returns.
    static func withBoard<T>(_ body: (NSPasteboard) throws -> T) rethrows -> T {
        let board = NSPasteboard(name: .init("com.uttrflow.tests.\(UUID().uuidString)"))
        defer { board.releaseGlobally() }
        board.clearContents()
        return try body(board)
    }

    @Test("TIFF is asked for last, since asking for it makes macOS decode a JPEG or HEIC into one")
    func tiffLast() {
        #expect(SystemClipboardSource.pictureFlavours.first == .png)
        #expect(SystemClipboardSource.pictureFlavours.last == .tiff)
    }

    @Test("a JPEG-only copy is read from its own bytes and bounded to the edge")
    func jpegRead() throws {
        let jpeg = try PictureFlavourTests.encoded(
            PictureFlavourTests.image(width: 64, height: 48), as: .jpeg)
        let picture = try Self.withBoard { board in
            board.setData(jpeg, forType: .init(UTType.jpeg.identifier))
            return try #require(
                SystemClipboardSource.picture(on: board, within: .standard.limiting(pictureEdge: 16)))
        }
        #expect(picture.width == 16)
        #expect(picture.height == 12)
    }

    @Test("a PNG copy is kept as it is")
    func pngRead() throws {
        let png = try PictureFlavourTests.encoded(PictureFlavourTests.image(), as: .png)
        let picture = Self.withBoard { board in
            board.setData(png, forType: .png)
            return SystemClipboardSource.picture(on: board, within: .standard)
        }
        #expect(picture?.data == png)
    }

    @Test("a picture over the bound is not kept, and no other flavour of it is tried")
    func overBoundRefused() throws {
        let image = try PictureFlavourTests.image(width: 64, height: 48)
        let png = try PictureFlavourTests.encoded(image, as: .png)
        let tiff = try PictureFlavourTests.encoded(image, as: .tiff)
        let picture = Self.withBoard { board in
            board.setData(png, forType: .png)
            board.setData(tiff, forType: .tiff)
            return SystemClipboardSource.picture(on: board, within: .standard.limiting(largestPicture: 1_000))
        }
        #expect(picture == nil)
    }

    @Test("a clipboard with no picture on it gives none")
    func noPicture() {
        let picture = Self.withBoard { board in
            board.setString("words", forType: .string)
            return SystemClipboardSource.picture(on: board, within: .standard)
        }
        #expect(picture == nil)
    }
}
