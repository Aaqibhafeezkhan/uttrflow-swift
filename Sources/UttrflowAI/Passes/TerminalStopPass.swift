public import UttrflowCore

/// Adds or takes back the final full stop the way the formatter's stop policy and layout say.
public struct TerminalStopPass: CleaningPass {
    public static let id: PassID = .terminalStop

    public let policy: TerminalStopPolicy
    public let layout: LayoutPolicy

    public init(policy: TerminalStopPolicy = .always, layout: LayoutPolicy = .paragraphs) {
        self.policy = policy
        self.layout = layout
    }

    public func apply(_ draft: Draft) -> Draft {
        var draft = draft
        if layout.contains(.singleLine) { Self.flatten(&draft) }
        if layout.contains(.paragraphs), policy != .never { Self.stopParagraphs(&draft) }
        guard let last = draft.presentIndices.last, !draft.words[last].isLayoutMark else { return draft }
        let word = draft.words[last].text
        let finished: String
        switch policy {
        case .always:
            finished = finishedLast(word, in: draft)
        case .never:
            finished = WordShape.withoutTrailingStop(word)
        case .offForShortMessages(let sentences):
            let stopped = finishedLast(word, in: draft)
            finished =
                Self.sentenceCount(draft.text) <= sentences ? WordShape.withoutTrailingStop(stopped) : stopped
        }
        draft.replace(at: last, with: finished, by: Self.id)
        return draft
    }

    /// The last word with a stop unless it ends a list item, or the layout keeps newlines and the text holds one.
    private func finishedLast(_ word: String, in draft: Draft) -> String {
        if draft.endsInListItem { return word }
        if layout.contains(.preserveNewlines), draft.text.contains(where: \.isNewline) { return word }
        // Only prose asks: "where total is greater than 12000" in a SQL editor is a clause, not a question.
        let asks = layout.contains(.paragraphs) && Self.lastSentenceAsks(draft)
        return WordShape.finished(word, with: asks ? "?" : ".")
    }

    /// Whether the sentence the draft ends on asks a direct question by its word order.
    static func lastSentenceAsks(_ draft: Draft) -> Bool {
        let live = draft.presentIndices
        let start = live.dropLast().lastIndex {
            draft.words[$0].isLayoutMark || draft.shape(at: $0).endsSentence
        }
        let sentence = live[(start.map { $0 + 1 } ?? 0)...]
        return QuestionShape.asks(sentence.map { draft.shape(at: $0) })
    }

    /// Every layout mark taken out, so the words join on one line.
    private static func flatten(_ draft: inout Draft) {
        for index in draft.presentIndices where draft.words[index].isLayoutMark {
            draft.remove(at: index, by: id)
        }
    }

    /// Ends each paragraph of three or more words before a blank line with a full stop; a list item gets none.
    private static func stopParagraphs(_ draft: inout Draft) {
        var opening: Draft.Word?
        var paragraph: [Int] = []
        for index in draft.presentIndices {
            let word = draft.words[index]
            guard word.isLayoutMark else {
                paragraph.append(index)
                continue
            }
            if word.text.hasPrefix("\n\n"), let last = paragraph.last, paragraph.count >= 3,
                !(opening?.isListMark ?? false)
            {
                draft.replace(at: last, with: WordShape.finished(draft.words[last].text), by: id)
            }
            if word.text.hasPrefix("\n\n") || word.isListMark {
                opening = word
                paragraph = []
            }
        }
    }

    /// How many sentences the text holds; the joiner asks the same question of a whole dictation.
    static func sentenceCount(_ text: String) -> Int { SentenceCount.of(text) }
}
