import CoreGraphics
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

    @Test(
        "A Chromium browser is switched on whatever the read found, and elsewhere only a caretless text field is."
    )
    func whenTheTreeIsNeeded() {
        let reading = { (role: String, caret: CGRect?, secure: Bool) in
            FocusedFieldSnapshot(
                bundleIdentifier: "com.example.chat", applicationName: "Chat", role: role, value: "hi",
                caret: caret, isSecure: secure)
        }
        #expect(FullTreeSwitch.isNeeded(in: "com.google.Chrome", after: nil))
        #expect(FullTreeSwitch.isNeeded(in: "com.example.chat", after: reading("AXTextArea", nil, false)))
        #expect(!FullTreeSwitch.isNeeded(in: "com.example.chat", after: nil))
        #expect(!FullTreeSwitch.isNeeded(in: "com.example.chat", after: reading("AXTextArea", .zero, false)))
        #expect(!FullTreeSwitch.isNeeded(in: "com.example.chat", after: reading("AXTextField", nil, true)))
        #expect(!FullTreeSwitch.isNeeded(in: "com.example.chat", after: reading("AXGroup", nil, false)))
    }

    @Test(
        "A write whose answer timed out still belongs to the switch, so a tree that came on later is turned off on stop"
    )
    func aTreeThatCameOnLateIsTurnedOff() {
        let tree = FullTreeSwitch()
        let chrome = SlowApplication()
        tree.switchOn(processIdentifier: 9, bundleIdentifier: "com.google.Chrome", host: chrome.host, at: 0)
        #expect(tree.switchedOn.isEmpty)
        chrome.answering = true
        chrome.values[FullTreeSwitch.enhancedAttribute] = true
        tree.switchOffEverything { _ in chrome.host }
        #expect(chrome.values[FullTreeSwitch.enhancedAttribute] == false)
    }

    @Test("A process whose attempt got no answer is tried again after a while, a few times at most")
    func anUnansweredAttemptIsTriedAgain() {
        let tree = FullTreeSwitch()
        let chrome = SlowApplication()
        let wait = FullTreeSwitch.retryInNanoseconds
        tree.switchOn(processIdentifier: 9, bundleIdentifier: "com.google.Chrome", host: chrome.host, at: 0)
        let first = chrome.writes.count
        tree.switchOn(
            processIdentifier: 9, bundleIdentifier: "com.google.Chrome", host: chrome.host, at: wait - 1)
        #expect(chrome.writes.count == first)
        for attempt in 1..<(FullTreeSwitch.mostAttempts + 3) {
            tree.switchOn(
                processIdentifier: 9, bundleIdentifier: "com.google.Chrome", host: chrome.host,
                at: UInt64(attempt) * wait)
        }
        #expect(chrome.writes.count == first * FullTreeSwitch.mostAttempts)
    }

    @Test("A retry that finds the tree on after its own earlier write settles it as this switch's")
    func aRetryFindingItsOwnWriteSettles() {
        let tree = FullTreeSwitch()
        let chrome = SlowApplication()
        tree.switchOn(processIdentifier: 9, bundleIdentifier: "com.google.Chrome", host: chrome.host, at: 0)
        chrome.answering = true
        chrome.values[FullTreeSwitch.enhancedAttribute] = true
        let before = chrome.writes.count
        tree.switchOn(
            processIdentifier: 9, bundleIdentifier: "com.google.Chrome", host: chrome.host,
            at: FullTreeSwitch.retryInNanoseconds)
        #expect(tree.switchedOn == [9: FullTreeSwitch.enhancedAttribute])
        #expect(chrome.writes.count == before + 1)
        tree.switchOn(
            processIdentifier: 9, bundleIdentifier: "com.google.Chrome", host: chrome.host,
            at: 10 * FullTreeSwitch.retryInNanoseconds)
        #expect(chrome.writes.count == before + 1)
    }
}

/// A browser that answers no read in time and every write as not implemented, until told to answer.
private final class SlowApplication {
    var values: [String: Bool] = [:]
    var answering = false
    var writes: [(String, Bool)] = []

    var host: FullTreeSwitch.Host {
        FullTreeSwitch.Host(
            read: {
                self.answering && $0 == FullTreeSwitch.enhancedAttribute ? self.values[$0] ?? false : nil
            },
            write: { attribute, isOn in
                self.writes.append((attribute, isOn))
                if self.answering, attribute == FullTreeSwitch.enhancedAttribute {
                    self.values[attribute] = isOn
                }
                return false
            })
    }
}
