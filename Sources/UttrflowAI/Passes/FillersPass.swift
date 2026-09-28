public import UttrflowCore

/// Removes the sounds people make while thinking, and nothing that is ever a word on its own.
public struct FillersPass: CleaningPass {
    public static let id: PassID = .fillers
    public static let removes: RemovalGrant = .sound

    /// Whole words that carry no meaning; "like", "well", "so", "basically" and "mm" (millimetres) are out.
    static let fillerWords: Set<String> = [
        "um", "umm", "uh", "uhh", "uhm", "er", "erm", "ah", "hmm", "mmm", "aah", "ahh", "mhm",
    ]

    public init() {}

    public func apply(_ draft: Draft) -> Draft {
        var draft = draft
        let live = draft.presentIndices
        var previous: Int?
        for (position, index) in live.enumerated() {
            let word = draft.words[index].text
            // A filler sound is never preceded by a determiner; a noun spelled like one — "the ER" — always is.
            guard Self.fillerWords.contains(draft.shape(at: index).key),
                position == 0
                    || !MentionGuard.isMentioned(at: position, spanning: 1, in: live, of: draft)
            else {
                previous = index
                continue
            }
            // A filler with a comma on both sides was bracketed by them, so the opening one goes too.
            if word.hasSuffix(","), let before = previous, draft.words[before].text.hasSuffix(",") {
                draft.replace(
                    at: before, with: String(draft.words[before].text.dropLast()), by: Self.id)
            }
            if Self.stopIsThePause(at: position, in: live, of: draft) {
                Self.runOn(live[position + 1], in: &draft)
                draft.replace(at: index, with: draft.shape(at: index).core, by: Self.id)
            }
            draft.remove(at: index, by: Self.id, carryingMarks: true)
        }
        return draft
    }

    /// Whether the filler's full stop marks the pause in a clause: the next word runs on in lower case, or the one before cannot end a sentence.
    static func stopIsThePause(at position: Int, in live: [Int], of draft: Draft) -> Bool {
        guard draft.shape(at: live[position]).suffix == ".", position > 0, position + 1 < live.count
        else { return false }
        let before = draft.words[live[position - 1]]
        let after = draft.words[live[position + 1]]
        let marks = WordShape(before.text).suffix
        guard !before.isLayoutMark, !after.isLayoutMark, marks.isEmpty || WordShape.trailsOff(marks)
        else { return false }
        return WordShape.lowercased(after.text) == after.text
            || FunctionWords.leadsOn(WordShape(before.text).key)
    }

    /// Lowers the capital the filler's stop gave the next word, unless it is "I", an acronym or a name the text shows.
    private static func runOn(_ index: Int, in draft: inout Draft) {
        let word = draft.words[index].text
        guard !FirstWordPass.keepsCapital(word), !FirstWordPass.looksLikeName(word, in: [draft.text]) else {
            return
        }
        draft.replace(at: index, with: WordShape.lowercased(word), by: Self.id)
    }
}
