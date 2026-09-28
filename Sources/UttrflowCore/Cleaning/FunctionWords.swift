/// The small words a phrase is built from, which carry structure rather than what was said.
public enum FunctionWords {
    /// Whether the word is one of the small words, apostrophes and case aside.
    public static func holds(_ word: String) -> Bool {
        all.contains(word.lowercased().replacingOccurrences(of: "\u{2019}", with: "'"))
    }

    /// Whether the word carries meaning, so a restatement may be anchored on it or replace it.
    public static func isContent(_ word: String) -> Bool { !word.isEmpty && !holds(word) }

    /// Whether a sentence cannot end on the word, since it leads into what follows ("the", "and", "is", "let's").
    public static func leadsOn(_ word: String) -> Bool {
        let key = word.lowercased()
        return leadingOn.contains(key) || Restatement.contractedSubjects.contains(key)
    }

    /// Whether the small word carries meaning the rewrite must keep: who acts, whether it is possible or required, or where it goes.
    public static func isMeaningBearing(_ word: String) -> Bool {
        let key = word.lowercased().replacingOccurrences(of: "\u{2019}", with: "'")
        return meaningBearing.contains(key)
    }

    /// Pronouns, modals, copula and perfect aux, and prepositions that set a direction; their removal or substitution changes what was said.
    public static let meaningBearing: Set<String> = [
        "i", "you", "he", "she", "it", "we", "they",
        "me", "him", "her", "us", "them",
        "my", "your", "his", "its", "our", "their",
        "mine", "yours", "hers", "ours", "theirs",
        "this", "these", "those", "there",
        "who", "whom", "whose", "which", "what",
        "myself", "yourself", "himself", "herself", "itself",
        "ourselves", "yourselves", "themselves",
        "am", "is", "are", "was", "were", "be", "been", "being",
        "have", "has", "had", "having",
        "will", "would", "shall", "should",
        "can", "could", "may", "might", "must", "ought",
        "to", "from", "without", "into", "onto",
        "through", "across", "behind", "beyond",
        "toward", "towards", "between", "against",
    ]

    /// Articles, possessives, conjunctions, prepositions that take an object, and the copula.
    static let leadingOn: Set<String> = [
        "a", "an", "the", "my", "your", "our", "their", "its",
        "and", "or", "but", "nor", "because", "although", "though", "if", "unless", "than", "whether",
        "of", "to", "into", "onto", "from", "with", "for",
        "is", "are", "was", "were",
        "let's", "let\u{2019}s", "what's", "what\u{2019}s", "who's", "who\u{2019}s", "here's",
        "here\u{2019}s",
    ]

    /// Articles, determiners, prepositions, conjunctions, auxiliaries and pronouns; dialect stays content.
    public static let all: Set<String> = [
        "a", "an", "the",
        "of", "in", "on", "at", "to", "for", "with", "by", "from", "about", "into", "onto", "over",
        "under", "after", "before", "between", "through", "during", "against", "among", "without",
        "within", "along", "across", "behind", "beyond", "near", "up", "down", "off", "out", "around",
        "past", "since", "until", "till", "upon", "toward", "towards", "per",
        "and", "or", "but", "nor", "so", "yet", "because", "although", "though", "while", "if",
        "unless", "than", "whether", "that", "as", "when", "where", "once",
        "am", "is", "are", "was", "were", "be", "been", "being", "do", "does", "did", "have", "has",
        "had", "having", "will", "would", "shall", "should", "can", "could", "may", "might", "must",
        "ought", "not",
        "don't", "doesn't", "didn't", "won't", "wouldn't", "can't", "couldn't", "shouldn't", "isn't",
        "aren't", "wasn't", "weren't", "hasn't", "haven't", "hadn't", "mustn't", "ain't",
        "dont", "doesnt", "didnt", "wont", "wouldnt", "cant", "couldnt", "shouldnt", "isnt", "arent",
        "wasnt", "werent", "hasnt", "havent", "hadnt", "aint",
        "i'll", "i'm", "i've", "i'd", "he'll", "she'll", "we'll", "they'll", "you'll", "it'll",
        "it's", "that's", "there's", "here's", "what's", "who's", "let's", "you're", "we're",
        "they're", "you've", "we've", "they've", "you'd", "we'd", "they'd", "he'd", "she'd",
        "im", "ive", "youre", "theyre", "youve", "weve", "theyve", "thats", "theres",
        "i", "you", "he", "she", "it", "we", "they", "me", "him", "her", "us", "them", "my", "your",
        "his", "its", "our", "their", "mine", "yours", "hers", "ours", "theirs", "this", "these",
        "those", "there", "who", "whom", "whose", "which", "what", "myself", "yourself", "himself",
        "herself", "itself", "ourselves", "yourselves", "themselves",
    ]
}
