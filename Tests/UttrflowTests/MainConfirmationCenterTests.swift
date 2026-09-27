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
}
