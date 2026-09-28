// Keeps a model's line from adding a number, an amount, an email or a web address nobody gave it.

import Foundation
import OSLog
import UttrflowPredict

/// The specifics a model's line adds, and whether each one is grounded in what the person or the screen already holds.
enum Specifics {
    /// Where a refused line is counted, by reason and never by its words.
    private static let log = Logger(subsystem: "com.uttrflow.Uttrflow", category: "predict")

    /// Whether every specific the line adds after what was typed appears, token for token, in the typed text, the person's lines, the screen or the machine's values.
    static func areGrounded(
        _ line: String, typed: String, in situation: GenerationSituation, writesCode: Bool = false
    ) -> Bool {
        let added = specifics(in: line, after: typed, writesCode: writesCode)
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

    /// The tokens of the line the continuation writes or finishes that name a specific, as they compare; in code a word whose numbers are all conventional names none.
    static func specifics(in line: String, after typed: String, writesCode: Bool = false) -> [String] {
        let typedLength = typed.count
        var offset = 0
        var found: [String] = []
        for word in line.split(separator: " ", omittingEmptySubsequences: false) {
            let end = offset + word.count
            if end > typedLength, let token = normalised(word), isSpecific(token),
                !(writesCode && isConventionalCode(token, word: word, after: line.prefix(offset)))
            {
                found.append(token)
            }
            offset = end + 1
        }
        return found
    }

    /// The numbers code writes that carry no value of their own: nothing, one, the last one, as an initialiser, an index, a bound or a step. See `Docs/predict-precision.md`, P8.
    static let conventionalNumbers: Set<String> = ["0", "1", "-1", "0.0", "1.0"]

    /// The last words of a name that says its value picks out one record, so even a conventional number there is an invented id.
    static let keyWords: Set<String> = ["id", "ids", "pid", "uid", "uuid", "guid"]

    /// Whether a specific token of code is so only by numbers that are each conventional and none a chosen value.
    static func isConventionalCode(_ token: String, word: Substring, after before: Substring) -> Bool {
        guard !namesAddressOrAmount(token) else { return false }
        let characters = Array(before) + Array(word)
        var index = before.count
        while index < characters.count {
            let previous = index > 0 ? characters[index - 1] : nil
            guard characters[index].isNumber, !(previous.map(isAlphanumeric) ?? false) else {
                index += 1
                continue
            }
            var end = index
            while end < characters.count, isAlphanumeric(characters[end]) || "._".contains(characters[end]) {
                end += 1
            }
            var literal = String(characters[index..<end])
            while literal.hasSuffix(".") { literal.removeLast() }
            var start = index
            // A minus sign after a name or a number subtracts; anywhere else it is the literal's own sign.
            if previous == "-", index < 2 || !isAlphanumeric(characters[index - 2]) {
                literal = "-" + literal
                start -= 1
            }
            guard conventionalNumbers.contains(literal), !isChosenValue(at: start, in: characters) else {
                return false
            }
            index = end
        }
        return true
    }

    /// Whether the number at this offset is a threshold, as `> 0` is, or the value of a name whose last word says it is an id, as `id = 1` and `userId: 0` are and `ids[0]` is not.
    static func isChosenValue(at start: Int, in characters: [Character]) -> Bool {
        var index = start
        var operates = false
        while index > 0, " \t=!<>:\"'`".contains(characters[index - 1]) {
            if "<>".contains(characters[index - 1]) { return true }
            if "=!:".contains(characters[index - 1]) { operates = true }
            index -= 1
        }
        guard operates else { return false }
        var nameStart = index
        while nameStart > 0, isAlphanumeric(characters[nameStart - 1]) || characters[nameStart - 1] == "_" {
            nameStart -= 1
        }
        guard let last = words(of: String(characters[nameStart..<index])).last else { return false }
        return keyWords.contains(last)
    }

    /// Whether a character is a letter or a digit, which is what a name or a number is made of.
    static func isAlphanumeric(_ character: Character) -> Bool { character.isLetter || character.isNumber }

    /// The words of a name split at underscores and at each lowercase-to-uppercase step, lowercased.
    static func words(of name: String) -> [String] {
        var words: [String] = []
        var current = ""
        var previous: Character?
        for character in name {
            if character == "_" || (character.isUppercase && previous?.isLowercase == true) {
                if !current.isEmpty { words.append(current.lowercased()) }
                current = ""
            }
            if character != "_" { current.append(character) }
            previous = character
        }
        if !current.isEmpty { words.append(current.lowercased()) }
        return words
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
        namesAddressOrAmount(token) || startsANumber(token)
    }

    /// Whether a token names an email, a web address, an amount or a percentage, which no register writes as a convention.
    static func namesAddressOrAmount(_ token: String) -> Bool {
        if token.contains("@"), token.count > 1 { return true }
        if token.contains("://") || token.hasPrefix("www.") || isHostPath(token) { return true }
        return token.contains(where: isAmountSign)
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
