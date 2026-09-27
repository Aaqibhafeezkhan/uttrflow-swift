public import UttrflowCore

/// Writes straight into the focused field, which leaves the clipboard alone and writes at the caret.
public struct AccessibilityTextInsertionEngine: TextInsertionEngine {
    public let method: TextInsertionMethod = .accessibility

    private let focus: any AccessibilityFocus

    public init(focus: any AccessibilityFocus) {
        self.focus = focus
    }

    public func canInsert() async -> Bool {
        // Uttrflow's own field cannot be the destination; the search field, the snippet editor and the rest are never it.
        guard !focus.isSelfFrontmost() else { return false }
        let focus = focus
        return await AccessibilityThread.run(orElse: false) { focus.focusedTextField() != nil }
    }

    /// Answers `.notReported`: the field verifies the write and does not say whether it could.
    public func insert(_ text: String) async throws(TextInsertionError) -> InsertionArrival {
        let focus = focus
        guard let field = await AccessibilityThread.run(orElse: nil, { focus.focusedTextField() })
        else { throw .noFocusedTextField }
        // Asked immediately before the write, so a stage that timed out cannot land words seconds late.
        guard !Task.isCancelled else {
            throw .insertionRejected(description: TextInsertion.dictationEnded)
        }
        try await AccessibilityThread.run { () throws(TextInsertionError) in
            try field.replaceSelection(with: text)
        }
        return .notReported
    }
}

extension AccessibilityTextInsertionEngine: CompletionWriting {
    public func canWrite() async -> Bool { await canInsert() }

    /// One write, so the field's own undo sees one edit rather than a delete and a typing run.
    public func write(_ text: String, replacing replaced: String) async throws(TextInsertionError) {
        let focus = focus
        guard let field = await AccessibilityThread.run(orElse: nil, { focus.focusedTextField() })
        else { throw .noFocusedTextField }
        try await AccessibilityThread.run { () throws(TextInsertionError) in
            try field.replaceSelection(replacing: replaced, with: text)
        }
    }
}
