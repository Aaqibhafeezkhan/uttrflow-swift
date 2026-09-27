public import UttrflowCore
public import UttrflowPredict

/// Puts an accepted suggestion into the field, and never onto the clipboard. See `Docs/predict-accept.md`.
public struct SuggestionAcceptor: Sendable {
    /// What checking the field comes to, before a single key is sent.
    public enum Aim: Sendable, Equatable {
        /// The field is the line the suggestion was drawn for, and this is what it still needs.
        case write(Acceptance.Edit)
        /// The field already holds the whole suggestion, or nothing was offered, so nothing is written.
        case nothing
        /// The field cannot be shown to be that line, so nothing is written and the key belongs to the application.
        case refused(String)
    }

    private let completion: CompletionRoute
    private let focus: (any AccessibilityFocus)?

    /// Checks the field before writing when `focus` is given, since a read can lag the last keystroke.
    public init(completion: CompletionRoute, focus: (any AccessibilityFocus)? = nil) {
        self.completion = completion
        self.focus = focus
    }

    /// The strategies this will try, so a caller can prove the clipboard is not among them.
    public var route: [TextInsertionMethod] { completion.route }

    /// Does to the field exactly what the drawn suggestion promised, or nothing when it promised nothing.
    @discardableResult
    public func accept(
        _ suggestion: Suggestion, after typed: String
    ) async throws(TextInsertionError) -> TextInsertionMethod? {
        switch await aim(suggestion, after: typed) {
        case .write(let edit): return try await write(edit)
        case .nothing: return nil
        case .refused(let reason): throw .insertionRejected(description: reason)
        }
    }

    /// Writes an edit `aim` returned, adding its text and taking back what it replaces.
    public func write(_ edit: Acceptance.Edit) async throws(TextInsertionError) -> TextInsertionMethod? {
        try await completion.write(edit.inserted, replacing: edit.replaced)
    }

    /// The drawn edit rebased onto the field as it is now, refused unless the field can be read and is that line.
    public func aim(_ suggestion: Suggestion, after typed: String) async -> Aim {
        guard let drawn = suggestion.edit(after: typed) else { return .nothing }
        guard let focus else { return .write(drawn) }
        // A field that hides what is typed never takes a suggestion, whatever it was drawn in.
        if await AccessibilityThread.run(orElse: true, { focus.focusedFieldIsSecure() }) {
            return .refused("the focused field hides what is typed")
        }
        let reach = max(typed.count + drawn.inserted.count, 1)
        let tail = await AccessibilityThread.run(orElse: .unreadable) { focus.tail(upTo: reach) }
        // A ghost is drawn only where the field was read, so a field that cannot be read now is not the one it was drawn in.
        guard case .text(let before) = tail else { return .refused("the focused field cannot be read") }
        if let rebased = Acceptance.rebase(drawn, after: typed, onto: before) { return .write(rebased) }
        // The whole suggestion already being there means the keys got ahead of the read, and there is nothing left to do.
        if before.hasSuffix(typed + drawn.inserted), !drawn.isReplacement { return .nothing }
        return .refused("the text before the caret is not the line the suggestion was drawn for")
    }
}
