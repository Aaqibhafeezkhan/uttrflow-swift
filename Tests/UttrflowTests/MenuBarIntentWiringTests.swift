// Tests that every menu bar item, signed in, reaches what it names, and a row that is gone reaches nothing.

import Foundation
import Testing
import UttrflowCore
import UttrflowUX

@testable import Uttrflow

/// What choosing an item does in a fresh signed-in app, read without a window, a microphone or the defaults.
private enum Reach: Equatable {
    /// Opens this surface.
    case opens(UttrflowUX.Destination)
    /// Leaves the app as it was, because a fresh app has no row at that position.
    case nothing
    /// Reaches the microphone, the saved settings, System Settings, a popover or the process, so no headless test drives it.
    case system
}

/// What each item is expected to do; exhaustive on purpose, so a new item cannot be added without saying.
private func reach(of intent: MenuBarIntent) -> Reach {
    switch intent {
    case .open(let destination): .opens(destination)
    // A fresh app has no speech model, and only onboarding downloads one.
    case .recover(.downloadSpeechModel): .opens(.onboarding)
    case .recover(.retryFromRecording): .opens(.main(.history))
    case .recover(.openSystemSettings), .recover(.retry), .recover(.pasteManually),
        .recover(.showRecentDictations):
        .system
    case .insertRecent, .copyRecent, .insertClip, .copyClip: .nothing
    case .startDictation, .stopDictation, .openClipboard, .setFeature, .quit: .system
    }
}

/// Names an item's case without its payload; exhaustive, so the sample count below means every case.
private func name(of intent: MenuBarIntent) -> String {
    switch intent {
    case .startDictation: "startDictation"
    case .stopDictation: "stopDictation"
    case .recover: "recover"
    case .insertRecent: "insertRecent"
    case .copyRecent: "copyRecent"
    case .insertClip: "insertClip"
    case .copyClip: "copyClip"
    case .open: "open"
    case .openClipboard: "openClipboard"
    case .setFeature: "setFeature"
    case .quit: "quit"
    }
}

/// How many cases ``MenuBarIntent`` has, bumped deliberately when one is added.
private let menuBarIntentCaseCount = 11

/// Every surface a menu item can name.
private let everyDestination: [UttrflowUX.Destination] =
    [.onboarding] + SettingsTab.allCases.map { .settings($0) } + MainTab.allCases.map { .main($0) }

/// Every item at least once, with each page, each fix and a first and a far row position.
private let samples: [MenuBarIntent] =
    [.startDictation, .stopDictation, .openClipboard, .setFeature(.dictation, isOn: false), .quit]
    + everyDestination.map { .open($0) }
    + [
        .recover(.openSystemSettings(.microphone)), .recover(.retry), .recover(.downloadSpeechModel),
        .recover(.pasteManually), .recover(.showRecentDictations), .recover(.retryFromRecording),
    ]
    + [0, 7].flatMap { index -> [MenuBarIntent] in
        [
            .insertRecent(index: index), .copyRecent(index: index), .insertClip(index: index),
            .copyClip(index: index),
        ]
    }

/// A signed-in app that draws nothing, so where a request went is read rather than seen.
@MainActor
private func signedInApp(in sandbox: borrowing Sandbox) -> AppDelegate {
    let app = AppDelegate(container: sandbox.root, account: HeldSession(signedIn: true).layer)
    app.drawsWindows = false
    return app
}

@MainActor
@Suite("Every menu bar item, signed in", .serialized)
struct MenuBarIntentWiringTests {
    @Test("every case has a sample, so a new item cannot be added without saying what it does")
    func everyCaseHasASample() {
        #expect(Set(samples.map(name(of:))).count == menuBarIntentCaseCount)
    }

    @Test(
        "an item that names a surface opens that surface",
        arguments: samples.filter { if case .opens = reach(of: $0) { true } else { false } })
    func opensWhatItNames(intent: MenuBarIntent) {
        let sandbox = Sandbox()
        let app = signedInApp(in: sandbox)

        guard case .opens(let expected) = reach(of: intent) else {
            Issue.record("\(intent) names no surface")
            return
        }

        app.carryOut(intent)

        #expect(app.lastOpened == expected)
    }

    @Test(
        "a row position the menu no longer holds opens nothing, copies nothing and opens no panel",
        arguments: samples.filter { reach(of: $0) == .nothing })
    func aRowThatIsGoneReachesNothing(intent: MenuBarIntent) async {
        let sandbox = Sandbox()
        let app = signedInApp(in: sandbox)

        app.carryOut(intent)
        await app.intentWork?.value

        #expect(app.lastOpened == nil)
        #expect(app.actionNotice == nil)
        #expect(!app.isQuickPanelOpen)
    }
}
