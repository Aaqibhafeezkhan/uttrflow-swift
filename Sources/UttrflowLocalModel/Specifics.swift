// Keeps a model's line from adding a number, an amount, an email or a web address nobody gave it.

import Foundation
import OSLog
import UttrflowPredict

/// The specifics a model's line adds, and whether each one is grounded in what the person or the screen already holds.
enum Specifics {
    /// Where a refused line is counted, by reason and never by its words.
    private static let log = Logger(subsystem: "com.uttrflow.Uttrflow", category: "predict")

    /// Whether every specific the line adds after what was typed appears, token for token, in the typed text, the person's lines, the screen or the machine's values.
    static func areGrounded(_ line: String, typed: String, in situation: GenerationSituation) -> Bool {
        let added = specifics(in: line, after: typed)
        guard !added.isEmpty else { return true }
        let sources =
            [typed, situation.preceding, situation.surroundings, situation.document, situation.windowTitle]
            .compactMap { $0 } + situation.recentLines + situation.choices
        let known = Set(sources.flatMap(tokens(of:)))
        guard added.allSatisfy(known.contains) else {
            log.debug("DROP made-up specific")
            return false
        }
        return true
    }

    /// The tokens of the line the continuation writes or finishes that name a specific, as they compare.
    static func specifics(in line: String, after typed: String) -> [String] {
        let typedLength = typed.count
        var offset = 0
        var found: [String] = []
        for word in line.split(separator: " ", omittingEmptySubsequences: false) {
            let end = offset + word.count
            if end > typedLength, let token = normalised(word), isSpecific(token) { found.append(token) }
            offset = end + 1
        }
        return found
    }

    /// Every token of a text as it compares, split on any whitespace.
    static func tokens(of text: String) -> [String] {
        text.split(whereSeparator: \.isWhitespace).compactMap(normalised)
    }

    /// A word lowercased with the punctuation around it dropped, or nothing when no character is left.
    static func normalised(_ word: Substring) -> String? {
        let edges = CharacterSet(charactersIn: ".,;:!?()[]{}\"'`<>*")
        let token = word.trimmingCharacters(in: edges).lowercased()
        return token.isEmpty ? nil : token
    }

    /// Whether a token names a specific: a number not part of a name, an amount, a percentage, an email or a web address.
    static func isSpecific(_ token: String) -> Bool {
        if token.contains("@"), token.count > 1 { return true }
        if token.contains("://") || token.hasPrefix("www.") || isHostPath(token) { return true }
        if token.contains(where: isAmountSign) { return true }
        return startsANumber(token)
    }

    /// Whether some digit in the token opens a run of digits no letter stands before, as in `3pm`, `#12` or `12.50`, never `python3`.
    static func startsANumber(_ token: String) -> Bool {
        var previous: Character?
        for character in token {
            if character.isNumber, previous.map({ !$0.isLetter && !$0.isNumber }) ?? true { return true }
            previous = character
        }
        return false
    }

    /// Whether a character marks an amount or a share: a currency sign or a percent sign.
    static func isAmountSign(_ character: Character) -> Bool {
        character == "%"
            || character.unicodeScalars.contains { $0.properties.generalCategory == .currencySymbol }
    }

    /// Whether the token is a dotted host followed by a path, as `github.com/org` is and `docs/guide.md` is not.
    static func isHostPath(_ token: String) -> Bool {
        guard let slash = token.firstIndex(of: "/") else { return false }
        let host = token[..<slash]
        guard let dot = host.lastIndex(of: "."), dot != host.startIndex else { return false }
        let domain = host[host.index(after: dot)...]
        return domain.count >= 2 && domain.allSatisfy(\.isLetter)
    }
}
