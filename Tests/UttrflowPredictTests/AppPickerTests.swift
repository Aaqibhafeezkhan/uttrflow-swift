// Tests that a word opening a chat app's own mention, emoji or command picker draws nothing and claims no key.

import Testing

@testable import UttrflowPredict

/// A chat composer, which has its own pickers.
private let composer = Surface(bundleIdentifier: "com.example.chat", role: "AXTextArea")

@Suite("A word that opens the application's own picker")
struct AppPickerTests {
    @Test(
        "a mention, a shortcode, a channel or a slash command still being typed is a picker",
        arguments: ["@", "@jo", "hey @jo", ":smi", "nice :thumbs_up", "#gen", "see #", "/rem", "  /remind"])
    func pickerOpen(line: String) {
        #expect(AppPicker.isOpen(after: line))
    }

    @Test(
        "a finished word, an address, a time, an emoticon or a slash inside a line is not",
        arguments: [
            "@jo ", "me@example.com", "at 12:30", "ok :)", ":", "/remind me", "and/or", "see /usr/bin", "",
            "Note: ",
        ])
    func pickerClosed(line: String) {
        #expect(!AppPicker.isOpen(after: line))
    }

    @Test("with the picker open, the turn settles quiet and neither Tab nor Escape is armed")
    func pickerLeavesTabAndEscape() {
        for line in ["@jo", ":smi", "/rem"] {
            var session = SuggestionSession()
            let turn = session.turn(in: composer, at: PredictionContext(typed: line, isProse: true))
            guard case .settled(let update) = turn.step else {
                Issue.record("\(line) asked for candidates while the app's picker is open")
                continue
            }
            #expect(update.silence == .applicationPicker)
            #expect(update.armed.isEmpty)
            #expect(
                KeyRouting.decision(for: KeyStroke(.tab), showing: update.suggestion) == .passThrough)
            #expect(
                KeyRouting.decision(for: KeyStroke(.escape), showing: update.suggestion) == .passThrough)
        }
    }

    @Test("a terminal's command line opens no picker, so a path or a flag still asks")
    func commandLineIsNotAPicker() {
        let context = PredictionContext(typed: "/usr", isCommandLine: true)
        #expect(Quieting.reason(context) == nil)
        #expect(Quieting.reason(PredictionContext(typed: "/usr")) == .applicationPicker)
    }
}
