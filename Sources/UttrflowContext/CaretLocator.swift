import CoreGraphics

/// Finds the caret's screen rectangle from whichever of a field's answers holds it. See `Docs/predict-reliability.md`.
struct CaretLocator {
    /// The bounds of a UTF-16 range, or nothing where the field refuses the question.
    let bounds: (_ location: Int, _ length: Int) -> CGRect?
    /// The bounds of the selection's text-marker range, which web content answers where character ranges fail.
    let markerBounds: () -> CGRect?
    /// The field's own frame, which is the caret when an editor parks a one-pixel field there.
    let frame: () -> CGRect?

    /// The caret at the selection, or at the text marker alone when the field refuses to say where its selection is.
    func caret(at selection: (location: Int, length: Int)?) -> CGRect? {
        if let selection, let rect = caret(inRange: selection) { return rect }
        // A web field answers glyph bounds with a zero-size rectangle, but its selection's text-marker range still has a place on screen.
        if let rect = markerBounds(), rect.height > 0 {
            return CGRect(x: rect.minX, y: rect.minY, width: 0, height: rect.height)
        }
        // An editor that draws its own text keeps a one-pixel field at the caret for input methods, so that field's frame is the caret.
        if let frame = frame(), FocusedFieldSnapshot.isCaretShaped(frame) {
            return CGRect(x: frame.minX, y: frame.minY, width: 0, height: frame.height)
        }
        return nil
    }

    /// The caret read off the glyph beside it, because a zero-length range's own bounds lies.
    private func caret(inRange selection: (location: Int, length: Int)) -> CGRect? {
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
