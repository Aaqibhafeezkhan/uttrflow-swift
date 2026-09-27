import Synchronization
import Testing

@testable import UttrflowContext

@Suite("A superseded read stops before its remaining questions")
struct CheckpointTests {
    @Test("A read that is still wanted runs and returns its answer")
    func runsWhileWanted() throws {
        #expect(try unlessSuperseded({ true }) { 7 } == 7)
    }

    @Test("Once the caller moves on, no remaining read runs")
    func stopsOnceSuperseded() {
        let answers = Mutex(2)
        let isWanted: () -> Bool = {
            answers.withLock { left in
                defer { left -= 1 }
                return left > 0
            }
        }
        var ran = 0
        let tail: () throws(Superseded) -> Void = {
            for _ in 0..<5 { try unlessSuperseded(isWanted) { ran += 1 } }
        }
        #expect(throws: Superseded.self) { try tail() }
        #expect(ran == 2)
    }
}
