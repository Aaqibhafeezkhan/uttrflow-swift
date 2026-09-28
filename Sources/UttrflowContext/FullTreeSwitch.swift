import Foundation
import UttrflowCore

private import Synchronization

/// Switches on a browser engine's full Accessibility tree in the applications that need it, and off again. See `Docs/predict-reliability.md`.
public final class FullTreeSwitch: Sendable {
    /// One application's switches as Accessibility exposes them: a read that is `nil` where unsupported, and a write that says whether it took.
    struct Host {
        let read: (_ attribute: String) -> Bool?
        let write: (_ attribute: String, _ isOn: Bool) -> Bool
    }

    /// The switch an application built on a bundled browser engine offers, which changes nothing but the tree.
    static let manualAttribute = "AXManualAccessibility"

    /// The switch a screen reader sets, which a Chromium browser honours where it ignores the manual one.
    static let enhancedAttribute = "AXEnhancedUserInterface"

    /// The Chromium browsers, the only applications the screen reader's switch is set on, since it slows window animations elsewhere.
    static let chromiumBrowsers = DestinationRules.chromiumBrowsers

    /// How long after an attempt that got no answer the same process may be asked again.
    static let retryInNanoseconds: UInt64 = 5_000_000_000

    /// How many attempts one process is given while the loop runs, so an application that never answers is not asked forever.
    static let mostAttempts = 4

    private struct State {
        /// How many attempts each process has had and when the last began, in uptime nanoseconds.
        var attempts: [Int32: (count: Int, at: UInt64)] = [:]
        /// The processes whose switch is settled, on by this switch or by something else, which are never asked again.
        var settled: Set<Int32> = []
        /// The processes this switch saw turn on after its own write, with the attribute that did.
        var switched: [Int32: String] = [:]
        /// Every attribute this switch wrote on, answered or not, which is what stopping turns off.
        var written: [Int32: Set<String>] = [:]
    }

    private let state = Mutex(State())

    public init() {}

    /// Whether a read calls for the tree: always in a Chromium browser, whose first read may run out of time, and elsewhere for a text field with no caret.
    static func isNeeded(in bundleIdentifier: String, after reading: FocusedFieldSnapshot?) -> Bool {
        if chromiumBrowsers.contains(bundleIdentifier) { return true }
        guard let reading else { return false }
        return reading.caret == nil && !reading.isSecure && FocusedFieldSnapshot.isTextEntry(reading.role)
    }

    /// The processes whose tree this switch turned on and has not turned off.
    var switchedOn: [Int32: String] { state.withLock { $0.switched } }

    /// Whether this process may be asked now: not settled, attempts left, and the last one long enough ago; asking counts as an attempt.
    private func mayAsk(_ processIdentifier: Int32, at now: UInt64) -> Bool {
        state.withLock { state in
            guard !state.settled.contains(processIdentifier) else { return false }
            let last = state.attempts[processIdentifier]
            if let last {
                guard last.count < Self.mostAttempts, now >= last.at + Self.retryInNanoseconds else {
                    return false
                }
            }
            state.attempts[processIdentifier] = ((last?.count ?? 0) + 1, now)
            return true
        }
    }

    /// Turns the full tree on in one application; an attempt with no answer is tried again later, a few times at most.
    func switchOn(
        processIdentifier: Int32, bundleIdentifier: String, host: Host,
        at now: UInt64 = DispatchTime.now().uptimeNanoseconds
    ) {
        guard mayAsk(processIdentifier, at: now) else { return }
        var attributes = [Self.manualAttribute]
        if Self.chromiumBrowsers.contains(bundleIdentifier) { attributes.append(Self.enhancedAttribute) }
        for attribute in attributes {
            let wrote = state.withLock { $0.written[processIdentifier]?.contains(attribute) ?? false }
            if host.read(attribute) == true {
                // On after this switch's own write is this switch's to turn off; on before it is left alone.
                state.withLock { state in
                    state.settled.insert(processIdentifier)
                    if wrote { state.switched[processIdentifier] = attribute }
                }
                return
            }
            // The write is recorded before its answer, since one that times out may still take.
            _ = state.withLock { $0.written[processIdentifier, default: []].insert(attribute) }
            // Chrome answers a write it has applied as not implemented, so the value read back decides.
            if host.write(attribute, true) || host.read(attribute) == true {
                state.withLock { state in
                    state.settled.insert(processIdentifier)
                    state.switched[processIdentifier] = attribute
                }
                return
            }
        }
    }

    /// Turns off every attribute this switch wrote that is not known to be off, and forgets every process, so the next start asks again.
    func switchOffEverything(host: (Int32) -> Host) {
        let written = state.withLock { state in
            defer { state = State() }
            return state.written
        }
        for (processIdentifier, attributes) in written {
            let application = host(processIdentifier)
            for attribute in attributes.sorted() where application.read(attribute) != false {
                _ = application.write(attribute, false)
            }
        }
    }
}
