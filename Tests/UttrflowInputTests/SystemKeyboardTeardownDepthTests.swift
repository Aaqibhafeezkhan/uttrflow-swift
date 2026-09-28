// Tests that the dictation keyboard carries and then stops after a long session on a small stack, so no chain builds per keystroke.
import CoreGraphics
import Foundation
import Synchronization
import Testing

@testable import UttrflowCore
@testable import UttrflowInput

/// Says the shortcut is still held, so the reconciliation poll never delivers a release of its own.
private struct KeyStillDown: RealKeyStateReading {
    func isDown(_ binding: HotkeyBinding) -> Bool { true }
}

/// The address of a local in a frame of its own, which is how deep the stack is where it is called.
@inline(never)
private func stackAddress() -> Int {
    var marker: UInt8 = 0
    return withUnsafeMutablePointer(to: &marker) { Int(bitPattern: $0) }
}

/// One tap event as the window server hands it over: its type, key code and modifier flags.
private struct TapEvent {
    let type: CGEventType
    let keyCode: CGKeyCode
    let flags: CGEventFlags
}

/// ⌥ down, ⌥Space pressed and let go, ⌥ up, then a letter typed: a press, a release and ordinary typing.
private let session: [TapEvent] = [
    TapEvent(type: .flagsChanged, keyCode: 58, flags: .maskAlternate),
    TapEvent(type: .keyDown, keyCode: 49, flags: .maskAlternate),
    TapEvent(type: .keyUp, keyCode: 49, flags: .maskAlternate),
    TapEvent(type: .flagsChanged, keyCode: 58, flags: []),
    TapEvent(type: .keyDown, keyCode: 0, flags: []),
    TapEvent(type: .keyUp, keyCode: 0, flags: []),
]

/// The real tap callback's arguments, built on the test's thread and handed to the small-stack one.
private struct Feed: @unchecked Sendable {
    let events: [(CGEventType, CGEvent)]
    let userInfo: UnsafeMutableRawPointer
    let proxy: CGEventTapProxy

    /// Calls the tap's callback exactly as the window server would for this event.
    func deliver(_ index: Int) {
        let (type, event) = events[index]
        _ = systemKeyboardCallback(proxy: proxy, type: type, event: event, userInfo: userInfo)
    }
}

/// What the small-stack thread saw, written there and read after it has finished.
private final class Readings: @unchecked Sendable {
    var firstDepth = 0
    var lastDepth = 0
    var strokes = 0
    var strokesAfterStop = 0
}

@Suite("The dictation keyboard after a long session", .timeLimit(.minutes(1)))
struct SystemKeyboardTeardownDepthTests {
    /// Stack for the typing and the stop, far below the 512 KiB a quit's cooperative thread has.
    private static let smallStack = 64 * 1024
    /// Keystrokes delivered before stopping, past the 3,347-link chain #1468 crashed freeing.
    private static let cycles = 20_000

    /// A plain Mach port, which stands in for the session tap without needing Accessibility.
    private static func makePort(_: UnsafeMutableRawPointer, _: Bool) -> CFMachPort? {
        CFMachPortCreate(nil, { _, _, _, _ in }, nil, nil)
    }

    /// Runs `body` on a thread with a stack of `bytes`, where a recursive release overflows at once.
    private static func onSmallStack(_ bytes: Int, _ body: @escaping @Sendable () -> Void) {
        let finished = DispatchSemaphore(value: 0)
        let thread = Thread {
            body()
            finished.signal()
        }
        thread.stackSize = bytes
        thread.start()
        finished.wait()
    }

    @Test("thousands of keystrokes through the real tap callback, then stop, fit a 64 KiB stack")
    @MainActor
    func longSessionStopsOnASmallStack() throws {
        let readings = Readings()
        let keyboard = SystemKeyboard(makePort: Self.makePort)
        let monitor = ActivationMonitor(
            source: keyboard, keyState: KeyStillDown(),
            strokeLeftLock: {
                readings.strokes += 1
                if readings.strokes == 1 { readings.firstDepth = stackAddress() }
                readings.lastDepth = stackAddress()
            })
        try monitor.start(binding: .optionSpace)
        let events = try session.map { tap in
            let event = try #require(
                CGEvent(keyboardEventSource: nil, virtualKey: tap.keyCode, keyDown: tap.type != .keyUp))
            event.flags = tap.flags
            return (tap.type, event)
        }
        let feed = Feed(
            events: events, userInfo: Unmanaged.passUnretained(keyboard.delivery).toOpaque(),
            proxy: try #require(OpaquePointer(bitPattern: 1)))

        Self.onSmallStack(Self.smallStack) { [monitor] in
            for _ in 0..<Self.cycles {
                for index in feed.events.indices { feed.deliver(index) }
            }
            // The quit path's own call, which is where #140 and #1468 overflowed.
            monitor.stop()
            let before = readings.strokes
            feed.deliver(1)
            readings.strokesAfterStop = readings.strokes - before
        }

        #expect(readings.strokes == Self.cycles * session.count)
        let growth = readings.firstDepth - readings.lastDepth
        #expect(growth < 4096, "stack growth, first keystroke -> last: \(growth) bytes")
        #expect(readings.strokesAfterStop == 0, "a stopped keyboard still delivered a keystroke")
        withExtendedLifetime(keyboard) {}
    }
}
