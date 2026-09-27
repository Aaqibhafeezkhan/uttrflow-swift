import Foundation
import Testing

@testable import UttrflowPredict

/// The field every test in this suite types into.
private let field = Surface(bundleIdentifier: "com.apple.Terminal", role: "AXTextArea")

/// A second field, for the tests about leaving one.
private let other = Surface(bundleIdentifier: "com.apple.Safari", role: "AXTextField")

/// The line the corpus offers over its own prefix.
private let exact = [remembered("git commit -m", count: 40)]

/// The same line offered as a correction of a typo.
private let corrected = [remembered("git commit -m", count: 40, editDistance: 1)]

/// A session that drew `candidates` over `typed` and had the offer taken.
private func taking(_ candidates: [Candidate], over typed: String) throws -> SuggestionSession {
    var session = SuggestionSession()
    let update = try draw(&session, typing: typed, candidates: candidates)
    try #require(update?.suggestion.accepting == "git commit -m")
    try #require(session.route(KeyStroke(.tab)) == .accept("git commit -m"))
    // The read that lands the taken line.
    _ = try draw(&session, typing: "git commit -m", candidates: [])
    return session
}

@Suite("A line taken and undone is not offered again straight away")
struct SuggestionUndoTests {
    @Test("Undo back to the prefix, or backspacing into the line, silences the same offer for that prefix.")
    func undoneLineIsNotReoffered() throws {
        for undone in ["git c", "git comm", "git commit -"] {
            var session = try taking(exact, over: "git c")
            let update = try draw(&session, typing: undone, candidates: exact)
            #expect(update?.suggestion.accepting == nil, "undone to \(undone)")
            #expect(session.undoneHere == ["git commit -m"])
        }
    }

    @Test("An undo of a fuzzy acceptance, back to its typo, silences the correction too.")
    func undoneCorrectionIsNotReoffered() throws {
        var session = try taking(corrected, over: "gti c")
        let update = try draw(&session, typing: "gti c", candidates: corrected)
        #expect(update?.suggestion.accepting == nil)
        #expect(session.undoneHere == ["git commit -m"])
    }

    @Test("A model line taken and undone is not drawn again from the model either.")
    func undoneGeneratedLineIsNotRedrawn() throws {
        var session = try taking(exact, over: "git c")
        guard case .query(let asked) = session.turn(in: field, at: PredictionContext(typed: "git c")).step
        else {
            Issue.record("expected a query")
            return
        }
        let update = session.resolveGenerated(
            ["git commit -m", "git commit --amend"], for: asked, elapsedMilliseconds: 0)
        #expect(update?.suggestion == .certain("git commit --amend"))
    }

    @Test("Typing on from the taken line, ending the line or leaving the field leaves the offer free.")
    func keptLineIsStillOffered() throws {
        var typedOn = try taking(exact, over: "git c")
        _ = try draw(&typedOn, typing: "git commit -m fix", candidates: [])
        #expect(
            try draw(&typedOn, typing: "git c", candidates: exact)?.suggestion.accepting == "git commit -m")

        var ended = try taking(exact, over: "git c")
        ended.lineEnded()
        _ = try draw(&ended, typing: "", candidates: [])
        #expect(try draw(&ended, typing: "git c", candidates: exact)?.suggestion.accepting == "git commit -m")

        var left = try taking(exact, over: "git c")
        _ = try draw(&left, typing: "git c", candidates: exact)
        _ = try draw(&left, typing: "", candidates: [], in: other)
        #expect(try draw(&left, typing: "git c", candidates: exact)?.suggestion.accepting == "git commit -m")
    }

    @Test("Only the undone line is silenced, so another line in the same field is still offered.")
    func onlyTheUndoneLineIsSilenced() throws {
        var session = try taking(exact, over: "git c")
        _ = try draw(&session, typing: "git c", candidates: exact)
        let others = [remembered("git checkout main", count: 40)]
        #expect(
            try draw(&session, typing: "git ch", candidates: others)?.suggestion.accepting
                == "git checkout main")
    }
}
