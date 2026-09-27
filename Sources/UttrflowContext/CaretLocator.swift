import CoreGraphics

/// Finds the caret's screen rectangle from whichever of a field's answers holds it. See `Docs/predict-reliability.md`.
enum CaretLocator {
    /// The caret at the selection, or at the text marker alone when the field refuses to say where its selection is; `frame` is the field's own.
    static func caret(
        at selection: (location: Int, length: Int)?, frame: CGRect?,
        bounds: (_ location: Int, _ length: Int) -> CGRect?, markerBounds: () -> CGRect?
    ) -> CGRect? {
        if let selection, let rect = caret(inRange: selection, bounds: bounds) { return rect }
        // A web field answers glyph bounds with a zero-size rectangle, but its selection's text-marker range still has a place on screen.
        if let rect = markerBounds(), rect.height > 0 {
            return CGRect(x: rect.minX, y: rect.minY, width: 0, height: rect.height)
        }
        // An editor that draws its own text keeps a one-pixel field at the caret for input methods, so that field's frame is the caret.
        if let frame, FocusedFieldSnapshot.isCaretShaped(frame) {
            return CGRect(x: frame.minX, y: frame.minY, width: 0, height: frame.height)
        }
        return nil
    }

    /// The caret read off the glyph beside it, because a zero-length range's own bounds lies.
    private static func caret(
        inRange selection: (location: Int, length: Int), bounds: (_ location: Int, _ length: Int) -> CGRect?
    ) -> CGRect? {
        // A real selection, unlike a caret, reports its own bounds honestly.
        if selection.length > 0, let rect = bounds(selection.location, selection.length), rect.height > 0 {
            return rect
        }
        let location = selection.location
        // The caret sits at the trailing edge of the glyph before it, which is what typing just moved past.
        if location > 0, let before = bounds(location - 1, 1), before.height > 0 {
            return CGRect(x: before.maxX, y: before.minY, width: 0, height: before.height)
        }
        // At the very start there is no glyph before, so the caret takes the leading edge of the one after.
        if let at = bounds(location, 1), at.height > 0 {
            return CGRect(x: at.minX, y: at.minY, width: 0, height: at.height)
        }
        // An empty line has no glyph beside the caret, so its own bounds is all there is.
        if let rect = bounds(selection.location, selection.length), rect.height > 0 { return rect }
        return nil
    }
}
