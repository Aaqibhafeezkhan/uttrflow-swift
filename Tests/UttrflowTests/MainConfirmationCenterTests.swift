// Tests for the main window's question host: a yes sends the intent, a no sends nothing.
import Testing
import UttrflowUX

@testable import Uttrflow

@MainActor
@Suite("The main window's question host")
struct MainConfirmationCenterTests {
    @Test("a yes hands back the intent and takes the question down")
    func yesSendsTheIntent() {
        let center = MainConfirmationCenter()
        center.ask(.signOut, before: .signOut)
        #expect(center.pending?.confirmation == .signOut)
        #expect(center.answer(confirming: true) == .signOut)
        #expect(center.pending == nil)
    }

    @Test("a no hands back nothing and takes the question down")
    func noSendsNothing() {
        let center = MainConfirmationCenter()
        center.ask(.signOut, before: .signOut)
        #expect(center.answer(confirming: false) == nil)
        #expect(center.pending == nil)
        #expect(center.answer(confirming: true) == nil)
    }

    @Test("pressing Sign out asks first and sends nothing until the answer")
    func signOutAsksFirst() {
        let center = MainConfirmationCenter()
        var sent: [MainIntent] = []
        let signOut = MainAction(title: "Sign out", intent: .signOut, isDestructive: true)
        MainConfirmationCenter.press(signOut, in: center) { sent.append($0) }
        #expect(sent.isEmpty)
        #expect(center.pending?.confirmation == .signOut)
        #expect(center.pending?.intent == .signOut)
    }

    @Test("pressing an action with no question sends it at once")
    func plainActionActsAtOnce() {
        let center = MainConfirmationCenter()
        var sent: [MainIntent] = []
        MainConfirmationCenter.press(MainAction(title: "Sign In", intent: .signIn), in: center) {
            sent.append($0)
        }
        #expect(sent == [.signIn])
        #expect(center.pending == nil)
    }
}
