// Where the quick panel sits on screen: the default corner, a remembered spot, and clamping.
public import Foundation

/// Where the quick panel sits on screen, in AppKit coordinates. See Docs/ux-panel-geometry.md.
public enum PanelPlacement {
    /// The gap between the panel and the usable screen's edges; small, so the panel reads as attached.
    public static let margin: CGFloat = 12

    /// The top-right corner, out of the way of running text and where macOS puts uninvited things.
    public static func defaultOrigin(size: CGSize, in visible: CGRect) -> CGPoint {
        clamped(
            CGPoint(
                x: visible.maxX - size.width - margin,
                y: visible.maxY - size.height - margin),
            size: size, in: visible)
    }

    /// Where the panel opens: where the user left it, clamped rather than trusted, or the default corner.
    public static func origin(
        remembered: CGPoint?, size: CGSize, in visible: CGRect
    ) -> CGPoint {
        guard let remembered else { return defaultOrigin(size: size, in: visible) }
        return clamped(remembered, size: size, in: visible)
    }

    /// Pulls a rectangle back inside the visible frame; a too-large panel is pinned bottom-left.
    public static func clamped(
        _ origin: CGPoint, size: CGSize, in visible: CGRect
    ) -> CGPoint {
        CGPoint(
            x: min(max(origin.x, visible.minX), max(visible.maxX - size.width, visible.minX)),
            y: min(max(origin.y, visible.minY), max(visible.maxY - size.height, visible.minY)))
    }

    /// Shrinks a size to fit the visible frame, so a panel taller or wider than the display can still open whole.
    public static func fitted(_ size: CGSize, in visible: CGRect) -> CGSize {
        CGSize(width: min(size.width, visible.width), height: min(size.height, visible.height))
    }
}

/// Remembers where the user left the panel on the displays used most recently, so a spot on one never places it on another.
public struct PanelSpots: Sendable, Equatable {
    /// Caps how many displays keep a spot, so the stored list cannot grow with every display ever attached.
    public static let limit = 8

    /// Holds the origin last dragged to on each display, keyed by the display's number.
    public private(set) var origins: [UInt32: CGPoint]
    /// Lists the displays in `origins` from least to most recently dragged on.
    public private(set) var recency: [UInt32]

    public init(origins: [UInt32: CGPoint] = [:]) {
        self.origins = [:]
        self.recency = []
        for display in origins.keys.sorted() {
            if let origin = origins[display] { remember(origin, on: display) }
        }
    }

    /// Reads back what `propertyList` wrote, skipping anything malformed rather than guessing at it.
    public init(propertyList: Any?) {
        var ranked: [(display: UInt32, rank: Double, origin: CGPoint)] = []
        for (key, value) in propertyList as? [String: Any] ?? [:] {
            guard let display = UInt32(key), let values = value as? [Double], (2...3).contains(values.count)
            else {
                continue
            }
            ranked.append((display, values.count == 3 ? values[2] : 0, CGPoint(x: values[0], y: values[1])))
        }
        self.init()
        for entry in ranked.sorted(by: { ($0.rank, $0.display) < ($1.rank, $1.display) }) {
            remember(entry.origin, on: entry.display)
        }
    }

    /// Gives the form kept in user defaults: each display's number as a string, and `[x, y, recency rank]`.
    public var propertyList: [String: [Double]] {
        var list: [String: [Double]] = [:]
        for (rank, display) in recency.enumerated() {
            guard let origin = origins[display] else { continue }
            list[String(display)] = [Double(origin.x), Double(origin.y), Double(rank + 1)]
        }
        return list
    }

    /// Places the panel on this display at its own remembered spot, clamped, or else the default corner.
    public func origin(on display: UInt32?, size: CGSize, in visible: CGRect) -> CGPoint {
        PanelPlacement.origin(remembered: display.flatMap { origins[$0] }, size: size, in: visible)
    }

    /// Records where the user left the panel on this display, forgetting the least recently used one past `limit`.
    public mutating func remember(_ origin: CGPoint, on display: UInt32) {
        origins[display] = origin
        recency.removeAll { $0 == display }
        recency.append(display)
        while recency.count > Self.limit {
            origins[recency.removeFirst()] = nil
        }
    }
}
