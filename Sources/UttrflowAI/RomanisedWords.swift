// The word-by-word check that a romanised rewrite of Hindi changed no word the speaker said.
import UttrflowCore
import UttrflowDictionary

extension MeaningPreservationGuard {
    /// One word of a romanised text: as written, and as the key two spellings of it share.
    struct RomanisedWord: Equatable {
        let word: String
        let key: String
    }

    /// The first content word the rewrite substituted, dropped or added against the romanised draft, in order, or `nil`. See `Docs/latin-output.md`.
    static func changedWord(said: String, written: String) -> String? {
        let spoken = withoutStammers(romanisedWords(said))
        let spelt = withoutStammers(romanisedWords(written))
        // A key either side spells as a grammar word is left out of both, so "arre" goes with the English "are".
        let grammar = Set((spoken + spelt).filter { isGrammarWord($0.word) }.map(\.key))
        let heard = spoken.filter { !grammar.contains($0.key) }
        let wrote = spelt.filter { !grammar.contains($0.key) }
        let alignment = WordErrorRate.measure(reference: heard.map(\.key), hypothesis: wrote.map(\.key))
            .alignment
        var next = (heard: 0, wrote: 0)
        for operation in alignment {
            switch operation {
            case .match:
                next = (next.heard + 1, next.wrote + 1)
            case .substitution:
                let (spoken, spelt) = (heard[next.heard].word, wrote[next.wrote].word)
                next = (next.heard + 1, next.wrote + 1)
                guard sameRomanisedForm(spoken, spelt) || isRespelling(spoken, as: spelt) else {
                    return spoken
                }
            case .deletion:
                return heard[next.heard].word
            case .insertion:
                return wrote[next.wrote].word
            }
        }
        return nil
    }

    /// The words of a romanised text, a filler dropped, a number word keyed as its digits and the rest by sound.
    static func romanisedWords(_ text: String) -> [RomanisedWord] {
        WordShape.words(text).compactMap { word in
            guard !FillersPass.fillerWords.contains(word) else { return nil }
            if let digits = numberWords[word] { return RomanisedWord(word: digits, key: digits) }
            return RomanisedWord(
                word: word, key: word.allSatisfy(\.isNumber) ? word : Romaniser.soundKey(word))
        }
    }

    /// The words with each run of one word said again kept once, so a stammer dropped or kept is no change.
    static func withoutStammers(_ words: [RomanisedWord]) -> [RomanisedWord] {
        words.enumerated().filter { $0.offset == 0 || words[$0.offset - 1].key != $0.element.key }.map(
            \.element)
    }

    /// Whether the rewrite wrote a loanword the rules romanised in its English spelling: "ticket" for the rules' "tikat".
    static func isRespelling(_ spoken: String, as spelt: String) -> Bool {
        guard !spoken.contains(where: \.isNumber), !spelt.contains(where: \.isNumber) else { return false }
        guard !ReadingRestraint.isOrdinaryCollision(spelt, heard: spoken) else { return false }
        let heard = DoubleMetaphone.code(for: spoken)
        let spelling = DoubleMetaphone.code(for: spelt)
        // One sound says too little to call two words one: "dhai" and "doh" both encode as a lone T.
        return heard.keys.contains { $0.count > 1 && spelling.keys.contains($0) }
    }

    /// Whether a word only ties the sentence together, so adding or dropping it changes no content: never a number, a negation or a Hindi pronoun.
    static func isGrammarWord(_ word: String) -> Bool {
        guard !word.contains(where: \.isNumber), !negatingWords.contains(word) else { return false }
        let key = Romaniser.soundKey(word)
        guard hindiPronouns[key] == nil else { return false }
        return FunctionWords.holds(word) || hindiGrammarWords.contains(key)
    }

    /// Hindi auxiliaries, postpositions and particles, by sound key; pronouns, verbs and negations stay content.
    static let hindiGrammarWords: Set<String> = Set(
        [
            "hai", "hain", "hoon", "hun", "tha", "thi", "the", "raha", "rahi", "rahe",
            "ko", "ka", "ki", "ke", "se", "mein", "par", "ne", "to", "toh", "bhi", "hi",
        ].map(Romaniser.soundKey))
}
