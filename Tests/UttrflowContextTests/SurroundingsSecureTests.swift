import ApplicationServices
import CoreGraphics
import Foundation
import Testing

@testable import UttrflowContext

/// A sign-in form: a heading, the username field the caret is in, and a filled password field beside it.
private let username = Node(id: 1, role: "AXTextField", text: "sam@example.com")
private let password = Node(id: 2, role: "AXTextField", text: "correct-horse-battery", secure: true)
private let signIn = Node(
    id: 0, role: "AXWindow",
    children: [label(3, "Sign in to Example"), username, password, label(4, "Forgot your password?")])

/// The answers a walked element gives, in the order the collector asks for them.
private func answers(_ given: [String: AnyObject]) -> FocusedFieldReader.Answers {
    let fetched = FocusedFieldReader.Answers.attributes.map { given[$0] ?? NSNull() }
    return FocusedFieldReader.Answers(AXUIElementCreateSystemWide(), fetched: fetched)
}

@Suite("A secure field beside the focused one is never read")
struct SurroundingsSecureTests {
    @Test("A password field beside the focused field is neither read nor gathered.")
    func secureSiblingIsNeverRead() {
        let reads = TextReadLog()
        let found = Surroundings.collect(
            around: username, in: FakeTree(root: signIn, textReads: reads), windowTitle: "Example",
            deadline: unhurried)
        #expect(found.text == "Sign in to Example\nForgot your password?")
        #expect(!reads.ids.contains(password.id))
        #expect(found.text?.contains("correct-horse-battery") != true)
    }

    @Test("What sits inside a secure field is never walked.")
    func secureSubtreeIsNeverWalked() {
        let wrapped = Node(
            id: 5, role: "AXGroup", secure: true, children: [label(6, "correct-horse-battery")])
        let form = Node(id: 0, role: "AXWindow", children: [label(3, "Sign in"), username, wrapped])
        let reads = TextReadLog()
        let found = Surroundings.collect(
            around: username, in: FakeTree(root: form, textReads: reads), windowTitle: nil,
            deadline: unhurried)
        #expect(found.text == "Sign in")
        #expect(!reads.ids.contains(5) && !reads.ids.contains(6))
    }

    @Test("A field that shows only mask characters is dropped though it does not declare itself.")
    func maskedSiblingIsDropped() {
        let masked = Node(id: 7, role: "AXTextField", text: "••••••••••")
        let form = Node(id: 0, role: "AXWindow", children: [label(3, "Sign in"), username, masked])
        let found = Surroundings.collect(
            around: username, in: FakeTree(root: form), windowTitle: nil, deadline: unhurried)
        #expect(found.text == "Sign in")
    }

    @Test("Nothing is read around a focused secure field, its own value included.")
    func focusedSecureFieldReadsNothing() {
        let reads = TextReadLog()
        let found = Surroundings.collect(
            around: password, in: FakeTree(root: signIn, textReads: reads), windowTitle: "Example",
            deadline: unhurried)
        #expect(found.text == nil)
        #expect(found.windowTitle == "Example")
        #expect(reads.ids.isEmpty)
    }

    @Test("The walk asks every element its subrole and names in the same message as its role.")
    func walkAsksForTheSecrecyAttributes() {
        let asked = Set(FocusedFieldReader.Answers.attributes)
        #expect(
            asked.isSuperset(of: [kAXSubroleAttribute, kAXIdentifierAttribute, kAXPlaceholderValueAttribute]))
    }

    @Test("An element with the secure subrole says nothing, not even its title.")
    func secureSubroleSaysNothing() {
        let secure = answers([
            kAXRoleAttribute: "AXTextField" as NSString, kAXSubroleAttribute: "AXSecureTextField" as NSString,
            kAXTitleAttribute: "correct-horse-battery" as NSString,
        ])
        #expect(secure.isSecure)
        #expect(secure.text == nil)
        let named = answers([
            kAXRoleAttribute: "AXTextField" as NSString, kAXIdentifierAttribute: "login_password" as NSString,
            kAXTitleAttribute: "correct-horse-battery" as NSString,
        ])
        #expect(named.isSecure)
        #expect(named.text == nil)
        let plain = answers([
            kAXRoleAttribute: "AXStaticText" as NSString, kAXTitleAttribute: "Sign in" as NSString,
        ])
        #expect(!plain.isSecure)
        #expect(plain.text == "Sign in")
    }
}
