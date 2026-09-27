import Foundation

private import Synchronization

/// Switches on a browser engine's full Accessibility tree in the applications that need it, once each, and off again. See `Docs/predict-reliability.md`.
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
    static let chromiumBrowsers: Set<String> = [
        "com.google.Chrome", "com.google.Chrome.beta", "com.google.Chrome.dev", "com.google.Chrome.canary",
        "org.chromium.Chromium", "com.microsoft.edgemac", "com.microsoft.edgemac.Beta",
        "com.microsoft.edgemac.Dev", "com.microsoft.edgemac.Canary", "com.brave.Browser",
        "com.brave.Browser.beta", "com.brave.Browser.nightly", "com.vivaldi.Vivaldi",
        "com.operasoftware.Opera", "company.thebrowser.Browser",
    ]

    private struct State {
        /// Every process asked once already, whatever it answered, so no keystroke asks twice.
        var asked: Set<Int32> = []
        /// The processes this switch turned on, with the attribute it set, which is all it ever turns off.
        var switched: [Int32: String] = [:]
    }

    private let state = Mutex(State())

    public init() {}

    /// The processes whose tree this switch turned on and has not turned off.
    var switchedOn: [Int32: String] { state.withLock { $0.switched } }

    /// Turns the full tree on in one application, the first time it is asked about that process only.
    func switchOn(processIdentifier: Int32, bundleIdentifier: String, host: Host) {
        let isNew = state.withLock { $0.asked.insert(processIdentifier).inserted }
        guard isNew else { return }
        var attributes = [Self.manualAttribute]
        if Self.chromiumBrowsers.contains(bundleIdentifier) { attributes.append(Self.enhancedAttribute) }
        for attribute in attributes {
            // A tree something else already turned on is left alone and never turned off from here.
            if host.read(attribute) == true { return }
            // Chrome answers a write it has applied as not implemented, so the value read back decides.
            if host.write(attribute, true) || host.read(attribute) == true {
                state.withLock { $0.switched[processIdentifier] = attribute }
                return
            }
        }
    }

    /// Turns off every tree this switch turned on and forgets every process it asked, so the next start asks again.
    func switchOffEverything(host: (Int32) -> Host) {
        let switched = state.withLock { state in
            defer { state = State() }
            return state.switched
        }
        for (processIdentifier, attribute) in switched {
            _ = host(processIdentifier).write(attribute, false)
        }
    }
}
