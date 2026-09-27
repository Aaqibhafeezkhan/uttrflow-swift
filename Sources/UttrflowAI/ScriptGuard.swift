// The guard's checks that a rewrite is written in Latin letters, romanises rather than translates, and is not a worked example.
import UttrflowCore

extension MeaningPreservationGuard {
    /// Above this share of words with no counterpart in the romanised draft, a rewrite of Devanagari is a translation.
    static let mostStrangerWords = 0.5
    /// A rewrite this much made of one worked example's words, in order, is that example.
    static let exampleCopied = 0.8

    /// Refuses a rewrite in another script, a translation of a Devanagari draft, or a worked example the draft did not say. See `Docs/latin-output.md`.
    public func scriptVerdict(draft: String, rewritten: String, examples: [String] = []) -> GuardVerdict {
        guard LatinScript.isLatin(rewritten), !Romaniser.containsDevanagari(rewritten) else {
            return .rejected(
                reason: "the rewrite is not written in the Latin alphabet", kind: .notLatinScript)
        }
        if let example = Self.echoedExample(draft: draft, rewritten: rewritten, examples: examples) {
            return .rejected(
                reason: "the rewrite repeats the worked example '\(example)'", kind: .echoedExample)
        }
        guard Romaniser.containsDevanagari(draft) else { return .accepted }
        let said = Self.withoutStammers(Self.romanisedKeys(Romaniser.romanised(draft)))
        let written = Self.withoutStammers(Self.romanisedKeys(rewritten))
        guard !written.isEmpty else { return .accepted }
        let heard = Set(said)
        let strangers = written.filter { !heard.contains($0) }.count
        guard Double(strangers) <= Double(written.count) * Self.mostStrangerWords else {
            return .rejected(
                reason: "the rewrite translated the Hindi instead of romanising it", kind: .translated)
        }
        if let changed = Self.changedWord(said: said, written: written) {
            return .rejected(
                reason: "the rewrite changed '\(changed)' while romanising the Hindi", kind: .lostWord)
        }
        return .accepted
    }

    /// The words of a romanised text as sound keys, a number word as its digits and a filler dropped.
    static func romanisedKeys(_ text: String) -> [String] {
        WordShape.words(text).compactMap { word in
            guard !FillersPass.fillerWords.contains(word) else { return nil }
            if let digits = numberWords[word] { return digits }
            return word.allSatisfy(\.isNumber) ? word : Romaniser.soundKey(word)
        }
    }

    /// The keys with each run of one word said again kept once, so a stammer dropped or kept is no change.
    static func withoutStammers(_ keys: [String]) -> [String] {
        keys.enumerated().filter { $0.offset == 0 || keys[$0.offset - 1] != $0.element }.map(\.element)
    }

    /// The first word the rewrite substituted, dropped or added against the romanised draft, in order.
    static func changedWord(said: [String], written: [String]) -> String? {
        for operation in WordErrorRate.measure(reference: said, hypothesis: written).alignment {
            switch operation {
            case .match: continue
            case .deletion(let word), .substitution(let word, _), .insertion(let word): return word
            }
        }
        return nil
    }

    /// The worked example a rewrite copies while the draft does not say it, or `nil`.
    static func echoedExample(draft: String, rewritten: String, examples: [String]) -> String? {
        let written = WordShape.words(rewritten)
        guard written.count >= 3 else { return nil }
        let said = WordShape.words(Romaniser.romanised(draft))
        return examples.first { example in
            let shown = WordShape.words(Romaniser.romanised(example))
            guard shown.count >= 3 else { return false }
            let copied = Double(inOrder(written, shown)) >= Double(written.count) * exampleCopied
            return copied && Double(inOrder(said, shown)) < Double(shown.count) / 2
        }
    }

    /// How many words the two sequences share in the same order, by exact spelling.
    static func inOrder(_ first: [String], _ second: [String]) -> Int {
        guard !first.isEmpty, !second.isEmpty else { return 0 }
        var previous = [Int](repeating: 0, count: second.count + 1)
        for word in first {
            var current = [0]
            for (index, other) in second.enumerated() {
                current.append(word == other ? previous[index] + 1 : max(previous[index + 1], current[index]))
            }
            previous = current
        }
        return previous[second.count]
    }
}
