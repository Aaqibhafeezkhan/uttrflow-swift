import CoreGraphics
import Testing

@testable import UttrflowContext

/// A tree whose parent chain never reaches a window, counting every parent lookup it answers.
private final class EndlessChain: ElementTree {
    var parentLookups = 0
    let cycle: Int?

    init(cycle: Int? = nil) { self.cycle = cycle }

    func role(of element: Int) -> String? { element == 2 ? "AXStaticText" : "AXGroup" }
    func isSecure(_ element: Int) -> Bool { false }
    func text(of element: Int) -> String? { element == 2 ? "Nearby message" : nil }
    func children(of element: Int) -> [Int] { element == 1 ? [2, 0] : [] }
    func parent(of element: Int) -> Int? {
        parentLookups += 1
        if element == 0 { return 1 }
        return cycle.map { (element % $0) + 1 } ?? element + 10
    }
    func frame(of element: Int) -> CGRect? { nil }
}

@Suite("How far the surroundings walk climbs")
struct SurroundingsAncestorTests {
    @Test("A parent chain deeper than the allowance stops climbing and keeps the nearest ring.")
    func aDeepChainIsCapped() {
        let tree = EndlessChain()
        let found = Surroundings.collect(
            around: 0, in: tree, windowTitle: nil, deadline: .now + .seconds(60))
        #expect(tree.parentLookups == Surroundings.maximumAncestors)
        #expect(found.text == "Nearby message")
    }

    @Test("A parent chain that loops back on itself stops climbing within the allowance.")
    func aCyclicChainIsCapped() {
        let tree = EndlessChain(cycle: 3)
        let found = Surroundings.collect(
            around: 0, in: tree, windowTitle: nil, deadline: .now + .seconds(60))
        #expect(tree.parentLookups <= Surroundings.maximumAncestors)
        #expect(found.text?.hasPrefix("Nearby message") == true)
    }
}
