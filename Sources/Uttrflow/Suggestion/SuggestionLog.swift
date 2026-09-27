import Foundation
import UttrflowCore

/// The predict log's lines, which carry lengths, counts and reasons and never the text itself. See `Docs/logging.md`.
enum SuggestionLog {
    /// What the corpus held for the line.
    static func query(typed: String, corpus: Int, generatorReady: Bool) -> String {
        "QUERY typedChars=\(typed.count) corpus=\(corpus) generatorReady=\(generatorReady)"
    }

    /// The machine knows no word that could come next.
    static func optionsNone(typed: String) -> String {
        "OPTIONS typedChars=\(typed.count) none"
    }

    /// The machine knows which words could come next, and how many.
    static func optionsAmong(typed: String, among: Int) -> String {
        "OPTIONS typedChars=\(typed.count) among=\(among)"
    }

    /// Why nothing is drawn for the focused field's current line.
    static func quiet(
        typed: String, reason: String, rejections: Int, silencedHere: Bool, enabled: Bool
    ) -> String {
        "QUIET typedChars=\(typed.count) reason=\(reason) rejections=\(rejections) silencedHere=\(silencedHere) enabled=\(enabled)"
    }

    /// A model pass that threw, named by its error's type and case.
    static func generateFailed(typed: String, error: any Error) -> String {
        "GENERATE failed typedChars=\(typed.count) error=\(failure(error))"
    }

    /// What the model offered, and how long it took.
    static func generate(
        application: String, typed: String, got: Int, elapsedMilliseconds: Int, firstCompletion: String?
    ) -> String {
        "GENERATE app=\(application) typedChars=\(typed.count) got=\(got) elapsed=\(elapsedMilliseconds)ms firstChars=\(firstCompletion?.count ?? 0)"
    }

    /// A pass for the list behind the drawn line that threw.
    static func alternativesFailed(typed: String, error: any Error) -> String {
        "ALTERNATIVES failed typedChars=\(typed.count) error=\(failure(error))"
    }

    /// The list behind the drawn line.
    static func alternatives(typed: String, got: Int, elapsedMilliseconds: Int) -> String {
        "ALTERNATIVES typedChars=\(typed.count) got=\(got) elapsed=\(elapsedMilliseconds)ms"
    }

    /// How many of the model's lines the machine denied.
    static func attest(typed: String, offered: Int, standing: Int) -> String {
        "ATTEST typedChars=\(typed.count) in=\(offered) out=\(standing) dropped=\(offered - standing)"
    }

    /// How many remembered lines survived the gates.
    static func verify(
        typed: String, offered: Int, allowed: Int, elapsedMilliseconds: Int, firstCompletion: String?
    ) -> String {
        "VERIFY typedChars=\(typed.count) in=\(offered) out=\(allowed) elapsed=\(elapsedMilliseconds)ms firstChars=\(firstCompletion?.count ?? 0)"
    }

    /// A completion put into the field, and the route that took it.
    static func accept(text: String, typed: String, via route: String) -> String {
        "ACCEPT chars=\(text.count) typedChars=\(typed.count) via=\(route)"
    }

    /// Every route refused the completion; the insertion error's cases carry fixed wording only.
    static func landedNowhere(_ error: TextInsertionError, typed: String) -> String {
        "a completion landed nowhere: \(String(describing: error)) typedChars=\(typed.count)"
    }

    /// A turn left behind, named by the step it was waiting on and the bundle identifier of the application it read.
    static func stall(step: SuggestionTurnStep?, application: String?, afterSeconds seconds: Double) -> String
    {
        "STALL step=\(step?.rawValue ?? "unknown") app=\(application ?? "unknown") after=\(Int(seconds))s left behind"
    }

    /// An error's type and case, without the payload, which may hold the text a model was given or wrote.
    static func failure(_ error: any Error) -> String {
        let type = String(describing: Swift.type(of: error))
        let mirror = Mirror(reflecting: error)
        if mirror.displayStyle == .enum {
            // A case with a payload is one labelled child; a case without one has no children and describes itself.
            guard let label = mirror.children.first?.label else {
                return "\(type).\(String(describing: error))"
            }
            return "\(type).\(label)"
        }
        let bridged = error as NSError
        return "\(type) domain=\(bridged.domain) code=\(bridged.code)"
    }
}

/// The step a suggestion turn is waiting on, which is what a stall log names.
enum SuggestionTurnStep: String, Sendable {
    /// Reading the focused field of the application in front.
    case read
    /// Handing the line to capture.
    case remember
    /// Recording a declined suggestion in the store.
    case reject
    /// Asking the corpus and the machine for candidates.
    case corpus
    /// Putting remembered candidates through the gates.
    case verify
    /// Asking the machine which words may come next.
    case options
    /// Waiting on a model pass for the line.
    case generate
    /// Checking the model's lines against the machine.
    case attest
    /// Reading the field again before drawing.
    case redraw
    /// Waiting on a model pass for the list behind the drawn line.
    case alternatives
}
