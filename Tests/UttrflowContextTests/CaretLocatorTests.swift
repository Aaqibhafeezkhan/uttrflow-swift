import CoreGraphics
import Foundation
import Testing

@testable import UttrflowContext

/// A field that answers only the questions a test gives it an answer for.
private struct Field {
    var bounds: (Int, Int) -> CGRect? = { _, _ in nil }
    var marker: CGRect? = nil
    var frame: CGRect? = nil
    var pointSize: CGFloat? = nil

    func caret(at selection: (location: Int, length: Int)?) -> CGRect? {
        CaretLocator.caret(
            at: selection, frame: frame, pointSize: pointSize, bounds: bounds, markerBounds: { marker })
    }
}

/// The field a test describes.
private func locator(
    bounds: @escaping (Int, Int) -> CGRect? = { _, _ in nil }, marker: CGRect? = nil, frame: CGRect? = nil
) -> Field {
    Field(bounds: bounds, marker: marker, frame: frame)
}

@Suite("Where the caret is found from a field's answers")
struct CaretLocatorTests {
    @Test("A field that refuses its selected range still gets a caret from its text-marker bounds.")
    func refusedRangeFallsBackToTheMarker() {
        let found = locator(marker: CGRect(x: 300, y: 140, width: 0, height: 17)).caret(at: nil)
        #expect(found == CGRect(x: 300, y: 140, width: 0, height: 17))
    }

    @Test("A field that refuses its range and parks a one-pixel field at the caret gets that frame.")
    func refusedRangeFallsBackToACaretShapedFrame() {
        let found = locator(frame: CGRect(x: 88, y: 60, width: 1, height: 16)).caret(at: nil)
        #expect(found == CGRect(x: 88, y: 60, width: 0, height: 16))
    }

    @Test("A refused range with no marker and a field-sized frame has no caret.")
    func refusedRangeWithNothingElseHasNoCaret() {
        #expect(locator(frame: CGRect(x: 0, y: 0, width: 400, height: 40)).caret(at: nil) == nil)
    }

    @Test("The glyph before the caret still wins over the marker where the range is answered.")
    func glyphBeforeTheCaretWins() {
        let field = locator(
            bounds: { location, length in
                location == 4 && length == 1 ? CGRect(x: 40, y: 10, width: 8, height: 16) : nil
            },
            marker: CGRect(x: 999, y: 999, width: 0, height: 16))
        #expect(field.caret(at: (location: 5, length: 0)) == CGRect(x: 48, y: 10, width: 0, height: 16))
    }

    @Test("Zero-size glyph bounds fall through to the marker, as a Chromium field answers them.")
    func zeroSizeGlyphsFallThrough() {
        let field = locator(
            bounds: { _, _ in CGRect(x: 2_865, y: 154, width: 0, height: 0) },
            marker: CGRect(x: 310, y: 150, width: 0, height: 15))
        #expect(field.caret(at: (location: 22, length: 0)) == CGRect(x: 310, y: 150, width: 0, height: 15))
    }

    @Test("A reading whose range was refused but whose value and marker answered can take the inline ghost.")
    func refusedRangeStillTakesTheGhost() {
        let caret = locator(marker: CGRect(x: 300, y: 140, width: 0, height: 17)).caret(at: nil)
        let reading = FocusedFieldSnapshot(
            bundleIdentifier: "com.google.Chrome", applicationName: "Google Chrome", role: "AXTextArea",
            value: "Thanks for the quick", selection: nil, caret: caret)
        #expect(reading.placement == .inlineGhost)
        #expect(reading.currentLine == "Thanks for the quick")
    }

    @Test("A marker rectangle that is the whole rich editor is no caret, so nothing is drawn at its corner")
    func markerAsTheWholeEditorIsNoCaret() {
        let editor = CGRect(x: 64, y: 1_117, width: 602, height: 202)
        var field = locator(
            bounds: { _, _ in CGRect(x: 0, y: 1_117, width: 0, height: 0) }, marker: editor, frame: editor)
        #expect(field.caret(at: (location: 84, length: 0)) == nil)
        field.frame = nil
        #expect(field.caret(at: (location: 84, length: 0)) == nil)
        field.frame = editor
        field.pointSize = 80
        #expect(field.caret(at: (location: 84, length: 0)) == nil)
    }

    @Test("A marker rectangle taller than a line of the field's type is no caret, and one line of it is")
    func markerTallerThanALineIsNoCaret() {
        var field = locator(marker: CGRect(x: 90, y: 40, width: 0, height: 60), frame: nil)
        field.pointSize = 14
        #expect(field.caret(at: nil) == nil)
        field.marker = CGRect(x: 90, y: 40, width: 0, height: 18)
        #expect(field.caret(at: nil) == CGRect(x: 90, y: 40, width: 0, height: 18))
        field.pointSize = nil
        field.marker = CGRect(x: 90, y: 40, width: 0, height: 40)
        #expect(field.caret(at: nil) == CGRect(x: 90, y: 40, width: 0, height: 40))
    }

    @Test(
        "A one-line field whose marker fills it is no caret, since the marker's corner is not where typing is"
    )
    func markerFillingAOneLineFieldIsNoCaret() {
        let input = CGRect(x: 10, y: 10, width: 300, height: 22)
        #expect(locator(marker: input, frame: input).caret(at: nil) == nil)
        #expect(
            locator(marker: CGRect(x: 120, y: 13, width: 0, height: 16), frame: input).caret(at: nil)
                == CGRect(x: 120, y: 13, width: 0, height: 16))
    }
}
