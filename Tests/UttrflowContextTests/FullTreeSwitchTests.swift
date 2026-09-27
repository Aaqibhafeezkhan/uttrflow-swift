import Testing

@testable import UttrflowContext

/// One application's switches, recording every write it takes.
private final class FakeApplication {
    var values: [String: Bool]
    let supported: Set<String>
    var writes: [(String, Bool)] = []
    /// Whether a write that takes is still answered as a failure, as Chrome answers it.
    let reportsFailure: Bool

    init(values: [String: Bool] = [:], supported: Set<String>, reportsFailure: Bool = false) {
        self.values = values
        self.supported = supported
        self.reportsFailure = reportsFailure
    }

    var host: FullTreeSwitch.Host {
        FullTreeSwitch.Host(
            read: { self.supported.contains($0) ? self.values[$0] ?? false : nil },
            write: { attribute, isOn in
                self.writes.append((attribute, isOn))
                guard self.supported.contains(attribute) else { return false }
                self.values[attribute] = isOn
                return !self.reportsFailure
            })
    }
}

@Suite("Turning a browser engine's full Accessibility tree on and off")
struct FullTreeSwitchTests {
    @Test("An application on a bundled browser engine takes the manual switch.")
    func bundledEngineTakesTheManualSwitch() {
        let tree = FullTreeSwitch()
        let app = FakeApplication(supported: [FullTreeSwitch.manualAttribute])
        tree.switchOn(processIdentifier: 7, bundleIdentifier: "com.example.chat", host: app.host)
        #expect(app.values[FullTreeSwitch.manualAttribute] == true)
        #expect(tree.switchedOn == [7: FullTreeSwitch.manualAttribute])
    }

    @Test("Chrome, which ignores the manual switch, takes the screen reader's one.")
    func chromeTakesTheEnhancedSwitch() {
        let tree = FullTreeSwitch()
        let chrome = FakeApplication(supported: [FullTreeSwitch.enhancedAttribute])
        tree.switchOn(processIdentifier: 9, bundleIdentifier: "com.google.Chrome", host: chrome.host)
        #expect(chrome.values[FullTreeSwitch.enhancedAttribute] == true)
        #expect(tree.switchedOn == [9: FullTreeSwitch.enhancedAttribute])
    }

    @Test("A write that takes but is answered as a failure still counts, so it is turned off again.")
    func appliedWriteAnsweredAsFailureCounts() {
        let tree = FullTreeSwitch()
        let chrome = FakeApplication(supported: [FullTreeSwitch.enhancedAttribute], reportsFailure: true)
        tree.switchOn(processIdentifier: 9, bundleIdentifier: "com.google.Chrome", host: chrome.host)
        #expect(tree.switchedOn == [9: FullTreeSwitch.enhancedAttribute])
        tree.switchOffEverything { _ in chrome.host }
        #expect(chrome.values[FullTreeSwitch.enhancedAttribute] == false)
    }

    @Test("An application that is not a Chromium browser is never given the screen reader's switch.")
    func otherApplicationsKeepTheirWindowAnimations() {
        let tree = FullTreeSwitch()
        let native = FakeApplication(supported: [FullTreeSwitch.enhancedAttribute])
        tree.switchOn(processIdentifier: 3, bundleIdentifier: "com.example.notes", host: native.host)
        #expect(native.values[FullTreeSwitch.enhancedAttribute] == nil)
        #expect(tree.switchedOn.isEmpty)
    }

    @Test("A process is asked once, so a keystroke after the first costs no message.")
    func eachProcessIsAskedOnce() {
        let tree = FullTreeSwitch()
        let chrome = FakeApplication(supported: [FullTreeSwitch.enhancedAttribute])
        for _ in 0..<5 {
            tree.switchOn(processIdentifier: 9, bundleIdentifier: "com.google.Chrome", host: chrome.host)
        }
        #expect(chrome.writes.count == 2)
    }

    @Test("A tree something else turned on is left on when the loop stops.")
    func aTreeAlreadyOnIsNeverTurnedOff() {
        let tree = FullTreeSwitch()
        let chrome = FakeApplication(
            values: [FullTreeSwitch.enhancedAttribute: true], supported: [FullTreeSwitch.enhancedAttribute])
        tree.switchOn(processIdentifier: 9, bundleIdentifier: "com.google.Chrome", host: chrome.host)
        tree.switchOffEverything { _ in chrome.host }
        #expect(chrome.values[FullTreeSwitch.enhancedAttribute] == true)
        #expect(chrome.writes.allSatisfy { $0.0 != FullTreeSwitch.enhancedAttribute })
    }

    @Test("Stopping turns off what was turned on, and the next start asks again.")
    func stoppingTurnsItOffAndForgets() {
        let tree = FullTreeSwitch()
        let chrome = FakeApplication(supported: [FullTreeSwitch.enhancedAttribute])
        tree.switchOn(processIdentifier: 9, bundleIdentifier: "com.google.Chrome", host: chrome.host)
        tree.switchOffEverything { _ in chrome.host }
        #expect(chrome.values[FullTreeSwitch.enhancedAttribute] == false)
        #expect(tree.switchedOn.isEmpty)
        tree.switchOn(processIdentifier: 9, bundleIdentifier: "com.google.Chrome", host: chrome.host)
        #expect(chrome.values[FullTreeSwitch.enhancedAttribute] == true)
    }
}
