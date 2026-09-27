import CoreGraphics
import Foundation
import Testing

@testable import UttrflowContext

/// A browser SQL editor as Accessibility shows it: a hidden 1x1 input at the caret, a gutter, a cursor and two rendered lines.
private func sqlEditor(
    stub: CGRect = CGRect(x: 351, y: 189, width: 1, height: 1), secureLine: Bool = false
) -> Node {
    let run = { (id: Int, text: String, x: CGFloat, width: CGFloat, y: CGFloat) in
        label(id, text, frame: CGRect(x: x, y: y, width: width, height: 15))
    }
    let input = Node(id: 2, role: "AXTextArea", text: "", frame: stub)
    let wrapper = Node(id: 1, frame: stub, children: [input])
    let cursor = Node(
        id: 10, frame: CGRect(x: 348, y: 190, width: 2, height: 15),
        children: [run(11, " ", 349, 9, 190)])
    let first = Node(
        id: 20, frame: CGRect(x: 94, y: 175, width: 1_626, height: 15),
        children: [run(21, "-- report", 98, 71, 175)])
    var second = Node(
        id: 30, frame: CGRect(x: 94, y: 190, width: 1_626, height: 15),
        children: [
            run(31, "SELECT", 98, 47, 190), run(32, " id", 145, 24, 190), run(33, ",", 168, 9, 190),
            run(34, " name ", 176, 48, 190), run(35, "FROM", 223, 32, 190), run(36, " users ", 255, 55, 190),
            run(37, "WHERE", 309, 40, 190),
        ])
    second.secure = secureLine
    let lines = Node(
        id: 40, frame: CGRect(x: 94, y: 171, width: 1_626, height: 38),
        children: [
            Node(id: 41, frame: CGRect(x: 94, y: 175, width: 1_626, height: 0)), cursor, first, second,
        ])
    let gutter = Node(
        id: 50, frame: CGRect(x: 64, y: 171, width: 30, height: 38),
        children: [
            Node(
                id: 51, frame: CGRect(x: 64, y: 175, width: 30, height: 15),
                children: [run(52, "1", 80, 8, 175)]),
            Node(
                id: 53, frame: CGRect(x: 64, y: 190, width: 30, height: 15),
                children: [run(54, "2", 80, 8, 190)]),
        ])
    let scroller = Node(
        id: 60, frame: CGRect(x: 64, y: 171, width: 1_656, height: 300), children: [gutter, lines])
    return Node(
        id: 70, frame: CGRect(x: 64, y: 171, width: 1_656, height: 300), children: [wrapper, scroller])
}

private func input(in editor: Node) -> Node { editor.children[0].children[0] }

@Suite("Reading the line of an editor that keeps an empty input at the caret")
struct HiddenInputLineTests {
    @Test("The empty 1x1 input of a SQL editor yields the typed line and a caret at its end.")
    func sqlEditorYieldsTheTypedLine() throws {
        let editor = sqlEditor()
        let stub = CGRect(x: 351, y: 189, width: 1, height: 1)
        let reading = try #require(
            HiddenInputLine.read(around: input(in: editor), at: stub, in: FakeTree(root: editor)))
        #expect(reading.before == "SELECT id, name FROM users WHERE")
        #expect(reading.after.isEmpty)
        #expect(reading.caret == CGRect(x: 349, y: 190, width: 0, height: 15))
        #expect(reading.line.minX == 98)
    }

    @Test("The reading takes the inline ghost with the typed line as the line to complete.")
    func readingTakesTheGhost() throws {
        let editor = sqlEditor()
        let stub = CGRect(x: 351, y: 189, width: 1, height: 1)
        let reading = try #require(
            HiddenInputLine.read(around: input(in: editor), at: stub, in: FakeTree(root: editor)))
        let snapshot = FocusedFieldSnapshot(
            bundleIdentifier: "com.google.Chrome", applicationName: "Google Chrome", role: "AXTextArea",
            value: reading.before + reading.after,
            selection: NSRange(location: reading.before.utf16.count, length: 0), caret: reading.caret,
            field: reading.line)
        #expect(snapshot.placement == .inlineGhost)
        #expect(snapshot.currentLine == "SELECT id, name FROM users WHERE")
        #expect(snapshot.caretAtLineEnd)
    }

    @Test("A caret between two words splits the line there.")
    func caretMidLineSplitsTheLine() throws {
        let editor = sqlEditor(stub: CGRect(x: 223, y: 189, width: 1, height: 1))
        let stub = CGRect(x: 223, y: 189, width: 1, height: 1)
        let reading = try #require(
            HiddenInputLine.read(around: input(in: editor), at: stub, in: FakeTree(root: editor)))
        #expect(reading.before == "SELECT id, name ")
        #expect(reading.after == "FROM users WHERE")
    }

    @Test("A caret inside a word is not placed, since a run cannot be split between its characters.")
    func caretInsideARunIsRefused() {
        let editor = sqlEditor(stub: CGRect(x: 120, y: 189, width: 1, height: 1))
        let stub = CGRect(x: 120, y: 189, width: 1, height: 1)
        #expect(HiddenInputLine.read(around: input(in: editor), at: stub, in: FakeTree(root: editor)) == nil)
    }

    @Test("A line that declares itself secure is never read.")
    func secureLineIsNeverRead() {
        let editor = sqlEditor(secureLine: true)
        let stub = CGRect(x: 351, y: 189, width: 1, height: 1)
        let log = TextReadLog()
        let reading = HiddenInputLine.read(
            around: input(in: editor), at: stub, in: FakeTree(root: editor, textReads: log))
        #expect(reading == nil)
        #expect(!log.ids.contains { (31...37).contains($0) })
    }

    @Test("A caret at the start of a line reads that line, never the gutter number beside it.")
    func gutterNumberIsNotTheLine() throws {
        let stub = CGRect(x: 98, y: 189, width: 1, height: 1)
        let editor = sqlEditor(stub: stub)
        let reading = try #require(
            HiddenInputLine.read(around: input(in: editor), at: stub, in: FakeTree(root: editor)))
        #expect(reading.before.isEmpty)
        #expect(reading.after == "SELECT id, name FROM users WHERE")
    }

    @Test("An input with no rendered line beside it yields nothing.")
    func nothingBesideTheInputYieldsNothing() {
        let stub = CGRect(x: 10, y: 10, width: 1, height: 1)
        let input = Node(id: 2, role: "AXTextArea", text: "", frame: stub)
        let root = Node(id: 1, frame: CGRect(x: 0, y: 0, width: 400, height: 300), children: [input])
        #expect(HiddenInputLine.read(around: input, at: stub, in: FakeTree(root: root)) == nil)
    }

    @Test("The read gives up once its visits are spent, however large the editor.")
    func visitsAreBounded() {
        let stub = CGRect(x: 351, y: 189, width: 1, height: 1)
        let input = Node(id: 2, role: "AXTextArea", text: "", frame: stub)
        let filler = (0..<2_000).map { Node(id: 100 + $0, frame: CGRect(x: 0, y: 0, width: 10, height: 10)) }
        let root = Node(id: 1, frame: CGRect(x: 0, y: 0, width: 400, height: 300), children: [input] + filler)
        let visits = VisitCounter()
        _ = HiddenInputLine.read(around: input, at: stub, in: FakeTree(root: root, visits: visits))
        #expect(visits.count <= HiddenInputLine.maximumElements)
    }

    @Test("Only an empty input no wider than a caret is taken for the parked input.")
    func onlyAnEmptyNarrowInputIsAStub() {
        #expect(HiddenInputLine.isStub(value: "", frame: CGRect(x: 0, y: 0, width: 2, height: 1)))
        #expect(HiddenInputLine.isStub(value: nil, frame: CGRect(x: 0, y: 0, width: 1, height: 16)))
        #expect(!HiddenInputLine.isStub(value: "select", frame: CGRect(x: 0, y: 0, width: 2, height: 1)))
        #expect(!HiddenInputLine.isStub(value: "", frame: CGRect(x: 0, y: 0, width: 300, height: 20)))
        #expect(!HiddenInputLine.isStub(value: "", frame: nil))
    }
}
