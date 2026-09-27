// The real clipboard.

public import struct Foundation.Data
import AppKit
private import os

/// The real clipboard, excluded from coverage; when to read it is decided and tested elsewhere.
public struct SystemClipboardSource: ClipboardSource {
    private static let log = Logger(subsystem: "com.uttrflow.Uttrflow", category: "clipboard")

    /// Where the picture bounds come from; the watcher's own bound covers text.
    private let budget: ClipboardBudget

    public init(budget: ClipboardBudget = .standard) {
        self.budget = budget
    }

    public func changeCount() -> Int {
        NSPasteboard.general.changeCount
    }

    public func text() -> String? {
        NSPasteboard.general.string(forType: .string)
    }

    public func markers() -> PasteboardMarkers {
        PasteboardMarkers(types: NSPasteboard.general.types?.map(\.rawValue) ?? [])
    }

    /// The formatted flavour, HTML only; RTF would need a conversion on a tick that must stay cheap.
    public func html() -> String? {
        NSPasteboard.general.string(forType: .html)
    }

    /// The picture on the clipboard as PNG, judged by its header first and never via a TIFF macOS translates for us.
    public func image() -> (data: Data, width: Int, height: Int)? {
        Self.picture(on: .general, within: budget)
    }

    /// The flavours asked for, compressed first: asking for TIFF makes macOS decode a JPEG or HEIC into one.
    static let pictureFlavours: [NSPasteboard.PasteboardType] = [
        .png, .init("public.heic"), .init("public.jpeg"), .tiff,
    ]

    /// The picture on `board`, the first flavour ImageIO reads, or `nil` when its header is over the bound.
    static func picture(
        on board: NSPasteboard, within budget: ClipboardBudget
    ) -> (data: Data, width: Int, height: Int)? {
        for type in pictureFlavours {
            guard let data = board.data(forType: type) else { continue }
            switch PictureFlavour.reading(data, within: budget) {
            case .kept(let picture): return picture
            case .refused(let width, let height):
                log.notice("a copied picture of \(width)×\(height) is over the bound; it is not kept")
                return nil
            case .unreadable: continue
            }
        }
        // `NSImage` is left for the flavours ImageIO cannot read, and sized before it is drawn.
        guard
            let item = board.readObjects(forClasses: [NSImage.self], options: nil)?.first as? NSImage,
            PictureFlavour.fits((Int(item.size.width), Int(item.size.height)), within: budget),
            let image = item.cgImage(forProposedRect: nil, context: nil, hints: nil)
        else { return nil }
        return PictureFlavour.png(of: image)
    }

    /// Read when the copy is noticed, since macOS does not say who wrote; the front app still served it.
    public func frontmostApplicationName() -> String? {
        NSWorkspace.shared.frontmostApplication?.localizedName
    }
}
