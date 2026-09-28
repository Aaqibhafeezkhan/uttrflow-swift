// Lifts Google's G off its button tile: the same tile on white and on dark gives each pixel's exact alpha.
//
// Usage:  swift Scripts/lift-google-mark.swift <light-tile.png> <dark-tile.png> <out.png>
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Reads a PNG as premultiplied RGBA bytes.
func pixels(_ path: String) -> (bytes: [UInt8], width: Int, height: Int) {
    guard let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil),
        let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
    else { fail("could not read \(path)") }
    let width = image.width
    let height = image.height
    var bytes = [UInt8](repeating: 0, count: width * height * 4)
    let drawn = bytes.withUnsafeMutableBytes { buffer -> Bool in
        guard
            let context = CGContext(
                data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8,
                bytesPerRow: width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return false }
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return true
    }
    guard drawn else { fail("could not decode \(path)") }
    return (bytes, width, height)
}

/// Prints the reason and exits non-zero.
func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("lift-google-mark: \(message)\n".utf8))
    exit(1)
}

let arguments = CommandLine.arguments
guard arguments.count == 4 else { fail("usage: lift-google-mark.swift <light.png> <dark.png> <out.png>") }
let light = pixels(arguments[1])
let dark = pixels(arguments[2])
guard light.width == dark.width, light.height == dark.height else { fail("the two tiles differ in size") }
let width = light.width
let height = light.height

// The tiles' grounds, sampled at the centre of the top edge's inside, where no mark reaches.
let groundIndex = (height / 10 * width + width / 2) * 4
let lightGround = (0..<3).map { Double(light.bytes[groundIndex + $0]) }
let darkGround = (0..<3).map { Double(dark.bytes[groundIndex + $0]) }
let spread = (0..<3).map { lightGround[$0] - darkGround[$0] }
guard spread.allSatisfy({ $0 > 128 }) else { fail("the tiles' grounds are not light and dark") }

// Alpha is how far the two grounds still show through; colour is what remains once they are removed.
// The tile's rounded corners and outline differ between themes, so only its inside is read.
let inset = width / 11
var lifted = [UInt8](repeating: 0, count: width * height * 4)
var top = height
var bottom = -1
var left = width
var right = -1
for y in inset..<(height - inset) {
    for x in inset..<(width - inset) {
        let index = (y * width + x) * 4
        let through = (0..<3).map { (Double(light.bytes[index + $0]) - Double(dark.bytes[index + $0])) / spread[$0] }
        let alpha = min(1, max(0, 1 - through.reduce(0, +) / 3))
        guard alpha > 0.02 else { continue }
        for channel in 0..<3 {
            // Premultiplied: the dark tile minus its ground's share is the mark's colour times alpha.
            let colour = Double(dark.bytes[index + channel]) - (1 - alpha) * darkGround[channel]
            lifted[index + channel] = UInt8(min(255, max(0, colour.rounded())))
        }
        lifted[index + 3] = UInt8((alpha * 255).rounded())
        if alpha > 0.1 {
            top = min(top, y)
            bottom = max(bottom, y)
            left = min(left, x)
            right = max(right, x)
        }
    }
}
guard bottom >= top, right >= left else { fail("no mark found between the two tiles") }

// Cropped to a square around the G, with a pixel of air so its soft edge is kept whole.
let side = max(bottom - top, right - left) + 3
let originX = (left + right) / 2 - side / 2
let originY = (top + bottom) / 2 - side / 2
var cropped = [UInt8](repeating: 0, count: side * side * 4)
for y in 0..<side {
    for x in 0..<side {
        let sourceX = originX + x
        let sourceY = originY + y
        guard (0..<width).contains(sourceX), (0..<height).contains(sourceY) else { continue }
        for channel in 0..<4 {
            cropped[(y * side + x) * 4 + channel] = lifted[(sourceY * width + sourceX) * 4 + channel]
        }
    }
}

let written = cropped.withUnsafeMutableBytes { buffer -> Bool in
    guard
        let context = CGContext(
            data: buffer.baseAddress, width: side, height: side, bitsPerComponent: 8, bytesPerRow: side * 4,
            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
        let image = context.makeImage(),
        let destination = CGImageDestinationCreateWithURL(
            URL(fileURLWithPath: arguments[3]) as CFURL, UTType.png.identifier as CFString, 1, nil)
    else { return false }
    CGImageDestinationAddImage(destination, image, nil)
    return CGImageDestinationFinalize(destination)
}
guard written else { fail("could not write \(arguments[3])") }
print("lifted a \(side)×\(side) G from \(width)×\(height) tiles")
