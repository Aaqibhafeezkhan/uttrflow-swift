// Whether a window is the one somebody is using, decided from what AppKit reports about it.

import CoreGraphics

/// What AppKit reports about a view's window at one moment, reduced to what decides whether it may move.
struct WindowAttention: Equatable {
    /// Whether the view is in a window and not hidden, which it is not once its page is switched away.
    var isShown: Bool

    /// Whether the window takes the keyboard, which only the active application's front window does.
    var isKey: Bool

    /// Whether this application is the active one.
    var isApplicationActive: Bool

    /// Whether this application is hidden with Command-H.
    var isApplicationHidden: Bool

    /// Whether any part of the window is on screen, from `NSWindow.occlusionState`.
    var isOnScreen: Bool

    /// Whether any part of the view itself can be seen: inside its scroll view's visible bounds and on a display.
    var isViewVisible = true

    /// What Reduce Motion, Low Power Mode and thermal pressure allow.
    var motion = MotionBudget()

    /// Whether the view is in sight in the window being used, whatever the motion budget says.
    var isAttended: Bool {
        isShown && isKey && isApplicationActive && !isApplicationHidden && isOnScreen && isViewVisible
    }

    /// Moves only in the window being used, only while the view itself is in sight, and only while the budget allows.
    var animates: Bool {
        isAttended && motion.demonstrationMoves
    }

    /// The part of a view of `size` inside its scroll view's bounds, placed where the window puts the view; empty once scrolled away.
    static func uncoveredFrame(
        size: CGSize, inWindow frame: CGRect, scrollViewBounds: CGRect?
    )
        -> CGRect
    {
        let whole = CGRect(origin: .zero, size: size)
        let part = scrollViewBounds.map { whole.intersection($0) } ?? whole
        guard !part.isNull, part.width > 0, part.height > 0 else { return .zero }
        return part.offsetBy(dx: frame.minX, dy: frame.minY)
    }

    /// A rectangle measured from the top of a space `height` tall, measured from its bottom instead.
    static func flipped(_ rect: CGRect, withinHeight height: CGFloat) -> CGRect {
        CGRect(x: rect.minX, y: height - rect.maxY, width: rect.width, height: rect.height)
    }

    /// Whether a view's unclipped part, in screen coordinates and empty once scrolled away, overlaps any display by an area.
    static func isVisible(unclippedFrameOnScreen frame: CGRect, displays: [CGRect]) -> Bool {
        displays.contains { display in
            let overlap = display.intersection(frame)
            return !overlap.isNull && overlap.width > 0 && overlap.height > 0
        }
    }
}
