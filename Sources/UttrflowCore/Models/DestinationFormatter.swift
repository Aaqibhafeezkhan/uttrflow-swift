/// How the first word is cased.
public enum FirstWordPolicy: Sendable, Equatable {
    /// A capital, unless the caret sits mid-sentence.
    case fromInsertionPoint
    case alwaysCapital
    /// Whatever case the word was heard in.
    case asSpoken
}

/// Whether the last sentence is given a full stop.
public enum TerminalStopPolicy: Sendable, Equatable {
    case always
    /// No full stop is added, and one the tidier or the model put there is taken back.
    case never
    /// Withheld when the text holds this many sentences or fewer.
    case offForShortMessages(sentences: Int)
}

/// How a numeral's digits are grouped, which is a separate question from which numbers become numerals.
public enum DigitGrouping: Sendable, Equatable {
    /// A separator every three digits from ten thousand up, as prose wants: 12,000.
    case thousands
    /// The digits and nothing between them, as anything that will be parsed wants: 12000.
    case none
}

/// Counting the sentences a text holds, which is what the short-message rule is asked about.
public enum SentenceCount {
    /// How many sentences the text holds, counting a last one that has no mark yet.
    public static func of(_ text: String) -> Int {
        var count = 0
        var openSentence = false
        let characters = Array(text)
        for (index, character) in characters.enumerated() {
            if ends.contains(character) {
                let next = index + 1 < characters.count ? characters[index + 1] : nil
                // A stop between two digits is a decimal point, not the end of a sentence.
                let insideNumber = character == "." && (next?.isNumber ?? false)
                let endsHere = next == nil || (next?.isWhitespace ?? false)
                if openSentence, endsHere, !insideNumber {
                    count += 1
                    openSentence = false
                }
            } else if !character.isWhitespace {
                openSentence = true
            }
        }
        return count + (openSentence ? 1 : 0)
    }

    private static let ends: Set<Character> = [".", "!", "?"]
}

/// Which spoken numbers a place wants written as numerals.
public enum NumberPolicy: Sendable, Equatable {
    /// Every number is a numeral, zero to nine included, as a cell or an editor wants.
    case always
    /// Ten and up are numerals; zero to nine stay words unless they sit in a number phrase.
    case fromTen
}

/// How much grammar a place wants repaired.
public enum GrammarPolicy: Sendable, Equatable {
    /// A slip speech left behind is fixed, changing only the form of a word the speaker said.
    case repair
    /// The words go out with the grammar they were spoken in.
    case asSpoken
}

/// How line breaks in the text are laid out: paragraphs and lists, kept as they are, or none at all.
public struct LayoutPolicy: OptionSet, Sendable, Equatable {
    public let rawValue: UInt8

    public init(rawValue: UInt8) {
        self.rawValue = rawValue
    }

    /// Every paragraph ends with a stop, and so does the last sentence, whatever line breaks the text holds.
    public static let paragraphs = LayoutPolicy(rawValue: 1 << 0)
    /// A spoken list is laid out as one; an item never gets a stop.
    public static let lists = LayoutPolicy(rawValue: 1 << 1)
    /// Line breaks are kept as given and a text holding one gets no stop, as dictated code wants.
    public static let preserveNewlines = LayoutPolicy(rawValue: 1 << 2)
    /// Every line break becomes a space, as a spreadsheet cell wants.
    public static let singleLine = LayoutPolicy(rawValue: 1 << 3)
}

/// What one kind of place wants done to the words: decisions, never code. See `Docs/cleanup-design.md`.
public struct DestinationFormatter: Sendable, Equatable {
    public let destination: Destination
    public let firstWord: FirstWordPolicy
    public let terminalStop: TerminalStopPolicy
    public let layout: LayoutPolicy
    /// Whether grammar slips are repaired here or the words go out as spoken.
    public let grammar: GrammarPolicy
    /// Which spoken numbers become numerals here.
    public let numbers: NumberPolicy
    /// How a numeral's digits are grouped here, which somewhere machine-read cannot leave to prose habits.
    public let digits: DigitGrouping
    /// The style rules and worked examples the model is shown for this place.
    public let promptBlock: PromptBlockID

    public init(
        destination: Destination, firstWord: FirstWordPolicy, terminalStop: TerminalStopPolicy,
        layout: LayoutPolicy, grammar: GrammarPolicy, numbers: NumberPolicy = .fromTen,
        digits: DigitGrouping = .thousands, promptBlock: PromptBlockID
    ) {
        self.destination = destination
        self.firstWord = firstWord
        self.terminalStop = terminalStop
        self.layout = layout
        self.grammar = grammar
        self.numbers = numbers
        self.digits = digits
        self.promptBlock = promptBlock
    }

    /// The shipped value for every destination; code stays `.never` until comments are told apart.
    public static let registry: [Destination: DestinationFormatter] = [
        .document: DestinationFormatter(
            destination: .document, firstWord: .fromInsertionPoint, terminalStop: .always,
            layout: [.paragraphs, .lists], grammar: .repair, numbers: .fromTen,
            promptBlock: "document"),
        .spreadsheet: DestinationFormatter(
            destination: .spreadsheet, firstWord: .asSpoken, terminalStop: .never, layout: .singleLine,
            grammar: .asSpoken, numbers: .always, promptBlock: "spreadsheet"),
        .sqlEditor: DestinationFormatter(
            destination: .sqlEditor, firstWord: .fromInsertionPoint, terminalStop: .always,
            layout: .preserveNewlines, grammar: .asSpoken, numbers: .always, digits: .none,
            promptBlock: "sqlEditor"),
        .codeEditor: DestinationFormatter(
            destination: .codeEditor, firstWord: .fromInsertionPoint, terminalStop: .never,
            layout: .preserveNewlines, grammar: .asSpoken, numbers: .always, digits: .none,
            promptBlock: "codeEditor"),
        .terminal: DestinationFormatter(
            destination: .terminal, firstWord: .asSpoken, terminalStop: .never,
            layout: .preserveNewlines, grammar: .asSpoken, numbers: .always, digits: .none,
            promptBlock: "terminal"),
        .messaging: DestinationFormatter(
            destination: .messaging, firstWord: .fromInsertionPoint,
            terminalStop: .offForShortMessages(sentences: 2), layout: .paragraphs,
            grammar: .asSpoken, numbers: .fromTen, promptBlock: "messaging"),
        .email: DestinationFormatter(
            destination: .email, firstWord: .fromInsertionPoint, terminalStop: .always,
            layout: [.paragraphs, .lists], grammar: .repair, numbers: .fromTen,
            promptBlock: "email"),
        .plain: DestinationFormatter(
            destination: .plain, firstWord: .fromInsertionPoint, terminalStop: .always,
            layout: [.paragraphs, .lists], grammar: .repair, numbers: .fromTen, promptBlock: "plain"),
    ]

    /// The formatter for a destination, falling back to plain text's for one the registry lacks.
    public static func standard(for destination: Destination) -> DestinationFormatter {
        registry[destination]
            ?? DestinationFormatter(
                destination: .plain, firstWord: .fromInsertionPoint, terminalStop: .always,
                layout: .paragraphs, grammar: .repair, numbers: .fromTen,
                promptBlock: "plain")
    }
}
