import CoreGraphics

/// Reads the caret's line off the rendered text of an editor whose focused field is an empty input parked at the caret. See `Docs/predict-reliability.md`.
enum HiddenInputLine {
    /// The line the caret is on, split at the caret, and where the caret and the line are on screen.
    struct Reading: Equatable, Sendable {
        /// The line's text before the caret.
        let before: String
        /// The line's text after the caret.
        let after: String
        /// The caret, a zero-width rectangle as tall as the line.
        let caret: CGRect
        /// The rendered line, which is the widest the ghost may run.
        let line: CGRect
    }

    /// The widest an input may be and still be parked at the caret rather than be the field itself.
    static let stubWidth: CGFloat = 3

    /// The tallest such an input may be, since some editors size it to a line and some to one pixel.
    static let stubHeight: CGFloat = 80

    /// How many ancestors are searched for the rendered text, nearest first.
    static let maximumAncestors = 4

    /// How many elements one read may visit, so an editor holding a long document costs a bounded read.
    static let maximumElements = 400

    /// How far short of the caret a row's text may end and still be the caret's row, about one character.
    static let reach: CGFloat = 6

    /// How long one read may take before it gives up, since it runs on the keystroke's own read.
    static let budget = Duration.milliseconds(40)

    /// How far apart two edges may be and still meet, in points.
    static let tolerance: CGFloat = 3

    /// Whether a focused field is the empty, caret-sized input an editor that draws its own text keeps focused.
    static func isStub(value: String?, frame: CGRect?) -> Bool {
        guard let frame, (value ?? "").isEmpty else { return false }
        return frame.width <= stubWidth && frame.height <= stubHeight
    }

    /// The caret's line around an input stub at `stub`, or nothing when no rendered line sits where the stub is.
    static func read<Tree: ElementTree>(
        around field: Tree.Element, at stub: CGRect, in tree: Tree,
        deadline: ContinuousClock.Instant = .now + budget
    ) -> Reading? {
        var visits = maximumElements
        var ancestor = field
        for _ in 0..<maximumAncestors {
            guard visits > 0, let parent = tree.parent(of: ancestor) else { return nil }
            ancestor = parent
            let rows = rows(under: parent, in: tree, visits: &visits, deadline: deadline)
            if let reading = reading(of: rows, at: stub) { return reading }
        }
        return nil
    }

    /// One rendered row: the static texts laid out under one element no taller than a line.
    struct Row {
        var runs: [(text: String, frame: CGRect)]
        var frame: CGRect { runs.map(\.frame).reduce(CGRect.null) { $0.union($1) } }
        var hasText: Bool { runs.contains { $0.text.contains { !$0.isWhitespace } } }
    }

    /// Every row of text under a root, each keyed by the outermost element on its path that holds one line only.
    static func rows<Tree: ElementTree>(
        under root: Tree.Element, in tree: Tree, visits: inout Int, deadline: ContinuousClock.Instant
    ) -> [Row] {
        var rows: [(container: Tree.Element, row: Row)] = []
        var stack: [(element: Tree.Element, path: [(Tree.Element, CGRect?)])] = [(root, [])]
        while visits > 0, ContinuousClock.now < deadline, let (element, path) = stack.popLast() {
            visits -= 1
            // A field that hides what is typed is passed over whole, its text never asked for.
            guard !tree.isSecure(element) else { continue }
            let frame = tree.frame(of: element)
            if let frame, frame.width <= 0 || frame.height <= 0 { continue }
            let here = path + [(element, frame)]
            if tree.role(of: element) == "AXStaticText" {
                guard let frame, let text = tree.text(of: element), !text.isEmpty else { continue }
                // The row is held by the outermost ancestor still too short to hold a second line.
                var container = element
                for (ancestor, bounds) in here.reversed().dropFirst() {
                    guard let bounds, bounds.height < frame.height * 1.8 else { break }
                    container = ancestor
                }
                if let index = rows.firstIndex(where: { $0.container == container }) {
                    rows[index].row.runs.append((text, frame))
                } else {
                    rows.append((container, Row(runs: [(text, frame)])))
                }
                continue
            }
            // Children are pushed last first, so the walk reads them in layout order.
            for child in tree.children(of: element).reversed() { stack.append((child, here)) }
        }
        return rows.map(\.row)
    }

    /// The row the stub is parked on, split at the stub, or nothing when none lines up with it.
    static func reading(of rows: [Row], at stub: CGRect) -> Reading? {
        let candidates = rows.filter { row in
            let frame = row.frame
            // A row the caret is on starts before it and reaches it, which a gutter number beside an empty line does not.
            return row.hasText && abs(frame.minY - stub.minY) <= max(tolerance, frame.height / 2)
                && frame.minX <= stub.minX + tolerance && frame.maxX >= stub.minX - reach
        }
        // The nearest row wins, and on one row the text rather than a gutter left of it.
        guard
            let row = candidates.min(by: { lhs, rhs in
                let lhsGap = abs(lhs.frame.minY - stub.minY)
                let rhsGap = abs(rhs.frame.minY - stub.minY)
                if abs(lhsGap - rhsGap) > tolerance { return lhsGap < rhsGap }
                return lhs.frame.minX > rhs.frame.minX
            })
        else { return nil }
        let runs = row.runs.sorted { $0.frame.minX < $1.frame.minX }
        // A caret inside a run cannot be placed between its characters, so the line is not read.
        let caretX = stub.minX
        guard
            !runs.contains(where: {
                $0.frame.minX < caretX - tolerance && $0.frame.maxX > caretX + tolerance
            })
        else { return nil }
        let before = runs.filter { $0.frame.midX < caretX }
        let after = runs.filter { $0.frame.midX >= caretX }
        let lineFrame = row.frame
        let x = before.last.map(\.frame.maxX) ?? caretX
        return Reading(
            before: before.map(\.text).joined(), after: after.map(\.text).joined(),
            caret: CGRect(x: x, y: lineFrame.minY, width: 0, height: lineFrame.height), line: lineFrame)
    }
}
