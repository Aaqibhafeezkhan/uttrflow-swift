// Tests that keys pressed after a taken keystroke stay held while the accept runs with nothing armed.
import CoreGraphics
import Dispatch
import Testing
import UttrflowPredict

@testable import UttrflowInput

@Suite("The tap while a taken keystroke is carried out")
struct TapStateHoldTests {
    /// A state with a resumed source of its own, since libdispatch traps on freeing a suspended one.
    private static func makeState() -> TapState {
        let source = DispatchSource.makeUserDataAddSource(queue: DispatchQueue(label: "test.tap-hold"))
        source.resume()
        return TapState(signal: source)
    }

    /// A key-down for a virtual key code with no modifiers.
    private static func key(_ code: CGKeyCode) throws -> CGEvent {
        let event = try #require(CGEvent(keyboardEventSource: nil, virtualKey: code, keyDown: true))
        event.flags = []
        return event
    }

    @Test("a key pressed after Tab is held even once the accept disarms every slot, and replayed on release")
    func heldThroughDisarm() throws {
        let state = Self.makeState()
        #expect(state.arm(.tab))
        #expect(state.takes(try Self.key(48)))
        // The accept path disarms before it inserts; the tap must keep listening so the hold still works.
        #expect(state.arm([]))
        #expect(state.takes(try Self.key(49)))
        #expect(state.takes(try Self.key(45)))
        var posted: [Int64] = []
        let listening = state.releaseHeldKeys {
            posted.append($0.getIntegerValueField(.keyboardEventKeycode))
        }
        #expect(posted == [49, 45])
        #expect(!listening)
        #expect(!state.takes(try Self.key(49)))
    }

    @Test("with nothing armed and nothing held, the tap is off and every key passes")
    func idleTapIsOff() throws {
        let state = Self.makeState()
        #expect(!state.arm([]))
        #expect(!state.takes(try Self.key(48)))
    }
}
