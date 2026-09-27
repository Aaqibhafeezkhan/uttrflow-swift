/// Whether a sentence asks a direct question by its word order alone, read the same way on every path. See `Docs/cleanup.md`.
public enum QuestionShape {
    /// Whether the words of one sentence ask a direct question.
    public static func asks(_ sentence: [WordShape]) -> Bool {
        let shapes = sentence.filter { !$0.key.isEmpty }
        let words = shapes.map { $0.key.replacingOccurrences(of: "\u{2019}", with: "'") }
        guard !words.isEmpty else { return false }
        if endsOnATag(words) { return true }
        // The last clause is where "I sent it, did you see it" asks.
        let lastClause = shapes.dropLast().lastIndex { $0.suffix.contains(",") }.map {
            Array(words[($0 + 1)...])
        }
        return ([words] + (lastClause.map { [$0] } ?? [])).contains {
            let clause = Array($0.drop(while: openers.contains))
            return opensAQuestion(clause) && !runsOn(clause)
        }
    }

    /// Whether a clause opens the way a question does: a question word before its verb, or a verb before its subject.
    private static func opensAQuestion(_ clause: [String]) -> Bool {
        guard let first = clause.first else { return false }
        let second = clause.dropFirst().first ?? ""
        if contractedQuestionWords.contains(first) { return true }
        if questionWords.contains(first) {
            // "what we need is…" names a thing; "what time is it" asks, so a subject before the verb says no.
            for word in clause.dropFirst().prefix(3) {
                if subjects.contains(word) { return false }
                if verbsBeforeSubject.contains(word) || pronounVerbs.contains(word) { return true }
            }
            return false
        }
        if verbsBeforeSubject.contains(first) {
            return subjects.contains(second) || determiners.contains(second)
        }
        // "Do the dishes" and "have a seat" tell rather than ask, so these ask only before a pronoun.
        if pronounVerbs.contains(first) { return subjects.contains(second) }
        return hindiQuestionWords.contains(first) || (first == "kya" && hindiSubjects.contains(second))
    }

    /// Whether a new subject starts later in the clause, as in "are you around yet I should be there", where the mark's place is unknown.
    private static func runsOn(_ clause: [String]) -> Bool {
        // The subject straight after the question's verb is the one it inverted, so the search starts past it.
        let verb =
            clause.prefix(4).firstIndex { verbsBeforeSubject.contains($0) || pronounVerbs.contains($0) } ?? 1
        return clause.dropFirst(verb + 2).contains {
            newSubjects.contains($0) || contractedNewSubjects.contains($0)
        }
    }

    /// Whether the sentence closes on a question tag: "isn't it", "don't you", or Hindi "… hai kya".
    private static func endsOnATag(_ words: [String]) -> Bool {
        guard words.count >= 3, let last = words.last else { return false }
        let before = words[words.count - 2]
        if subjects.contains(last), negativeVerbs.contains(before) { return true }
        return last == "kya" && hindiVerbs.contains(before)
    }

    /// Words a question may start after: "so did you…", "okay, can we…".
    static let openers: Set<String> = [
        "so", "and", "but", "okay", "ok", "oh", "well", "also", "then", "hey", "now", "anyway",
    ]

    /// English question words.
    static let questionWords: Set<String> = [
        "what", "where", "when", "why", "who", "whom", "whose", "which", "how",
    ]

    /// A question word contracted onto "is", which asks whatever follows.
    static let contractedQuestionWords: Set<String> = [
        "what's", "where's", "who's", "how's", "when's", "why's",
    ]

    /// Verbs that ask by standing before a subject or a determiner: "is the build green", "can we meet".
    static let verbsBeforeSubject: Set<String> = [
        "is", "are", "was", "were", "am", "does", "did", "has", "had", "can", "could", "will", "would",
        "should",
        "shall", "may", "might", "isn't", "aren't", "wasn't", "weren't", "doesn't", "didn't", "hasn't",
        "hadn't",
        "can't", "couldn't", "won't", "wouldn't", "shouldn't",
    ]

    /// Verbs that also start a command, so they ask only before a pronoun: "do you", not "do the dishes".
    static let pronounVerbs: Set<String> = ["do", "have", "don't", "haven't"]

    /// Negative verbs, which with a pronoun after them close a sentence as a tag: "isn't it", "don't you".
    static let negativeVerbs: Set<String> = [
        "isn't", "aren't", "wasn't", "weren't", "doesn't", "didn't", "hasn't", "hadn't", "can't", "couldn't",
        "won't",
        "wouldn't", "shouldn't", "don't", "haven't",
    ]

    /// Subject pronouns and the indefinite subjects a question inverts around.
    static let subjects: Set<String> = [
        "i", "you", "we", "they", "he", "she", "it", "there", "anyone", "anybody", "someone", "somebody",
        "everyone",
        "everybody", "anything", "something", "everything",
    ]

    /// Pronouns that can only be a subject, so one past a question's opening starts a second clause.
    static let newSubjects: Set<String> = ["i", "we", "he", "she", "they"]

    /// Every contracted form of those pronouns: "I'm", "we'll", "they've".
    static let contractedNewSubjects = Set(
        newSubjects.flatMap { subject in ["'m", "'s", "'re", "'ll", "'ve", "'d"].map { subject + $0 } })

    /// Words that open a noun phrase a question can invert around: "is the build", "can your team".
    static let determiners: Set<String> = [
        "the", "a", "an", "my", "your", "our", "his", "her", "their", "its", "this", "that", "these", "those",
        "any",
        "some",
    ]

    /// Romanised Hindi question words that ask from the start of a sentence.
    static let hindiQuestionWords: Set<String> = [
        "kaun", "kahan", "kab", "kaise", "kyun", "kyon", "kitna", "kitne", "kitni", "kiska", "kiski", "kiske",
        "kisne", "kisko",
    ]

    /// Romanised Hindi subject pronouns, which "kya" asks about from the start of a sentence.
    static let hindiSubjects: Set<String> = [
        "tum", "aap", "tu", "wo", "woh", "ye", "yeh", "hum", "main", "mai", "unhone", "usne", "humne",
        "tumne", "aapne",
    ]

    /// Romanised Hindi verb endings a closing "kya" turns into a question: "aa rahe ho kya".
    static let hindiVerbs: Set<String> = [
        "hai", "hain", "ho", "hoon", "tha", "thi", "the", "hoga", "hogi", "honge",
    ]
}
