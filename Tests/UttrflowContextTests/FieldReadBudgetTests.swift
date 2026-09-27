// Tests that a field read stops at its budget and that a field that ran over is left alone for a while.

import Testing

@testable import UttrflowContext

private let second: UInt64 = 1_000_000_000
private let field = SlowFields.Key(process: 42, element: 7)
private let other = SlowFields.Key(process: 42, element: 8)

@Suite("One field read's budget")
struct FieldReadBudgetTests {
    @Test("A read is spent once its allowance has passed, and not a nanosecond before")
    func spentAtTheAllowance() {
        let budget = FieldReadBudget(started: 5 * second)
        #expect(!budget.isSpent(at: 5 * second))
        #expect(!budget.isSpent(at: 5 * second + FieldReadBudget.allowanceInNanoseconds - 1))
        #expect(budget.isSpent(at: 5 * second + FieldReadBudget.allowanceInNanoseconds))
    }

    @Test("A clock read before the start is not a spent budget")
    func anEarlierClockIsNotSpent() {
        #expect(!FieldReadBudget(started: 5 * second).isSpent(at: second))
    }

    @Test("The allowance is shorter than one message's own timeout, so one stalled message is enough to stop")
    func shorterThanOneTimeout() {
        let timeout = UInt64(Double(FocusedFieldReader.elementTimeoutInSeconds) * 1_000_000_000)
        #expect(FieldReadBudget.allowanceInNanoseconds < timeout)
    }
}

@Suite("Fields left alone after a slow read")
struct SlowFieldsTests {
    @Test("A field that ran over rests for the first rest, and only that field")
    func restsAfterRunningOver() {
        let slow = SlowFields()
        #expect(!slow.isResting(field, at: second))
        slow.ranOver(field, at: second)
        #expect(slow.isResting(field, at: second + SlowFields.firstRestInNanoseconds - 1))
        #expect(!slow.isResting(field, at: second + SlowFields.firstRestInNanoseconds))
        #expect(!slow.isResting(other, at: second))
    }

    @Test("Each further run over doubles the rest, up to the longest")
    func doublesUpToTheLongest() {
        let slow = SlowFields()
        var now = second
        slow.ranOver(field, at: now)
        now += SlowFields.firstRestInNanoseconds
        slow.ranOver(field, at: now)
        #expect(slow.isResting(field, at: now + 2 * SlowFields.firstRestInNanoseconds - 1))
        #expect(!slow.isResting(field, at: now + 2 * SlowFields.firstRestInNanoseconds))
        for _ in 0..<20 { slow.ranOver(field, at: now) }
        #expect(slow.isResting(field, at: now + SlowFields.longestRestInNanoseconds - 1))
        #expect(!slow.isResting(field, at: now + SlowFields.longestRestInNanoseconds))
    }

    @Test("A read that keeps to its budget ends the rest")
    func aFastReadEndsTheRest() {
        let slow = SlowFields()
        slow.ranOver(field, at: second)
        slow.answered(field)
        #expect(!slow.isResting(field, at: second))
        slow.ranOver(field, at: second)
        #expect(slow.isResting(field, at: second + SlowFields.firstRestInNanoseconds - 1))
    }

    @Test("Past its capacity the field whose rest ends first is forgotten")
    func forgetsTheOldestPastCapacity() {
        let slow = SlowFields()
        for element in 0...UInt(SlowFields.capacity) {
            slow.ranOver(SlowFields.Key(process: 1, element: element), at: second + UInt64(element))
        }
        #expect(!slow.isResting(SlowFields.Key(process: 1, element: 0), at: second + 100))
        #expect(slow.isResting(SlowFields.Key(process: 1, element: 1), at: second + 100))
        #expect(
            slow.isResting(SlowFields.Key(process: 1, element: UInt(SlowFields.capacity)), at: second + 100))
    }
}
