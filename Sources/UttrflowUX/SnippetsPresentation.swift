// The Snippets page: its rows, the inline editor, and the presenter that draws them.
public import UttrflowCore
public import Foundation

/// One snippet ready to draw: the phrase you say, and the block of text you get instead.
public struct SnippetRow: Sendable, Equatable, Identifiable {
    /// The snippet's identity.
    public let id: UUID
    /// The phrase, as a pill.
    public let trigger: MainPill
    /// What it expands to.
    public let text: String
    /// How often it has fired, as text.
    public let timesUsed: String
    /// "Today", "Tuesday", "12 Aug" — or "Never", because an unused snippet is worth spotting.
    public let lastUsed: String
    /// Edit and Delete.
    public let actions: [MainAction]
    /// Which of the page's pill tints the trigger wears, fixed by the snippet's place in the store.
    public let tint: Int

    /// Builds a row from its parts.
    public init(
        id: UUID, trigger: MainPill, text: String, timesUsed: String, lastUsed: String,
        actions: [MainAction], tint: Int = 0
    ) {
        self.id = id
        self.trigger = trigger
        self.text = text
        self.timesUsed = timesUsed
        self.lastUsed = lastUsed
        self.actions = actions
        self.tint = tint
    }
}

/// The snippet being written, inline in the row where it will end up.
public struct SnippetEditor: Sendable, Equatable {
    /// The snippet being changed, or `nil` when this is a new one.
    public let editing: UUID?
    /// The trigger typed so far.
    public let trigger: String
    /// The text typed so far.
    public let text: String
    /// "New snippet" or "Edit snippet", over the fields.
    public let title: String
    /// The label on the trigger field.
    public let triggerLabel: String
    /// The label on the text field.
    public let textLabel: String
    /// "Editing" or "New", always present so the row is never ambiguous.
    public let badge: MainPill
    /// Why this cannot be saved yet, in words. Absent when it can.
    public let problem: String?
    /// Commits the snippet.
    public let save: MainAction
    /// Closes the editor unchanged.
    public let cancel: MainAction

    /// Whether Save is enabled.
    public var canSave: Bool { problem == nil }

    /// Builds the editor from its parts.
    public init(
        editing: UUID?,
        trigger: String,
        text: String,
        title: String,
        triggerLabel: String,
        textLabel: String,
        badge: MainPill,
        problem: String?,
        save: MainAction,
        cancel: MainAction
    ) {
        self.editing = editing
        self.trigger = trigger
        self.text = text
        self.title = title
        self.triggerLabel = triggerLabel
        self.textLabel = textLabel
        self.badge = badge
        self.problem = problem
        self.save = save
        self.cancel = cancel
    }
}

/// What the user is part-way through writing, held apart from the stored snippets.
public struct SnippetDraft: Sendable, Equatable {
    /// The snippet being changed, or `nil` for a new one.
    public let editing: UUID?
    /// The trigger typed so far.
    public let trigger: String
    /// The text typed so far.
    public let text: String

    /// Starts empty unless given text.
    public init(editing: UUID? = nil, trigger: String = "", text: String = "") {
        self.editing = editing
        self.trigger = trigger
        self.text = text
    }

    /// Nothing typed yet, so there is nothing to complain about; see `problem(with:in:)`.
    public var isUntouched: Bool { trigger.isEmpty && text.isEmpty }
}

/// Everything the snippets page is drawn from.
public struct SnippetsSnapshot: Sendable, Equatable {
    /// In the store's order.
    public let snippets: [Snippet]
    /// Set while the inline editor is open.
    public let draft: SnippetDraft?
    /// Why the last Save did not happen, when the store refused it; see ``DictionarySnapshot/refusal``.
    public let refusal: String?
    /// What has been typed into the search field.
    public let query: String
    /// The clock the page is drawn against.
    public let now: Date

    /// Builds a snapshot; everything but the clock defaults to empty.
    public init(
        snippets: [Snippet] = [], draft: SnippetDraft? = nil, refusal: String? = nil,
        query: String = "", now: Date
    ) {
        self.snippets = snippets
        self.draft = draft
        self.refusal = refusal
        self.query = query
        self.now = now
    }
}

/// What the snippets page shows.
public struct SnippetsPresentation: Sendable, Equatable {
    /// The title, caption, search field and New button across the top.
    public let chrome: MainPageChrome
    /// The snippets that match the query.
    public let rows: [SnippetRow]
    /// The open editor, above the rows.
    public let editor: SnippetEditor?
    /// Set when there is nothing to list and nothing being written.
    public let emptyState: MainEmptyState?
    /// The line under the rows, absent when there are none.
    public let footnote: String?

    /// Builds the page from its parts.
    public init(
        chrome: MainPageChrome,
        rows: [SnippetRow],
        editor: SnippetEditor?,
        emptyState: MainEmptyState?,
        footnote: String?
    ) {
        self.chrome = chrome
        self.rows = rows
        self.editor = editor
        self.emptyState = emptyState
        self.footnote = footnote
    }
}

/// Turns stored snippets into the page that edits them.
public enum SnippetsPresenter {
    /// What the empty search field says.
    public static let searchPlaceholder = "Search snippets"

    /// Draws the Snippets page from a snapshot.
    public static func page(
        for snapshot: SnippetsSnapshot,
        calendar: Calendar = .autoupdatingCurrent,
        locale: Locale = .autoupdatingCurrent
    ) -> SnippetsPresentation {
        let listed = matches(snapshot.snippets, query: snapshot.query, locale: locale)
        let places = Dictionary(
            snapshot.snippets.enumerated().map { ($1.id, $0) }, uniquingKeysWith: { first, _ in first })
        let rows = listed.map {
            row(
                for: $0, tint: (places[$0.id] ?? 0) % tints, now: snapshot.now, calendar: calendar,
                locale: locale)
        }
        let editor = snapshot.draft.map { self.editor(for: $0, in: snapshot) }
        // The empty page is the title over the scene, whose own button is the one way to add.
        let isBare = snapshot.snippets.isEmpty && editor == nil

        return SnippetsPresentation(
            chrome: MainPageChrome(
                title: "Snippets",
                caption: isBare ? nil : caption(for: snapshot.snippets.count),
                search: snapshot.snippets.isEmpty
                    ? nil
                    : MainSearchField(placeholder: searchPlaceholder, query: snapshot.query),
                addAction: isBare
                    ? nil : MainAction(title: "New Snippet", symbolName: "plus", intent: .addSnippet)),
            rows: rows,
            editor: editor,
            emptyState: rows.isEmpty && editor == nil ? emptyState(for: snapshot) : nil,
            footnote: rows.isEmpty
                ? nil
                : """
                Say the trigger anywhere in a sentence and Uttrflow swaps in the text. Triggers \
                are matched on what you said, so “my address” works whether you pause around it \
                or not.
                """)
    }

    /// How many pill tints the page cycles through.
    public static let tints = 4

    /// "Say a short phrase; Uttrflow types the whole thing. · 6 snippets", the count once there is one.
    static func caption(for count: Int) -> String {
        let lede = "Say a short phrase; Uttrflow types the whole thing."
        return count == 0 ? lede : "\(lede) · \(MainFormatting.count(count, "snippet", "snippets"))"
    }

    // MARK: - Searching

    /// Matches the trigger and the text, since the trigger is the half people forget.
    static func matches(_ snippets: [Snippet], query: String, locale: Locale) -> [Snippet] {
        SearchQuery.matches(snippets, query: query, locale: locale) { [$0.trigger, $0.expansion] }
    }

    // MARK: - One snippet

    /// One snippet as a row with Edit and Delete.
    static func row(
        for snippet: Snippet, tint: Int = 0, now: Date, calendar: Calendar, locale: Locale
    ) -> SnippetRow {
        SnippetRow(
            id: snippet.id,
            trigger: MainPill(text: snippet.trigger, tone: .accent),
            text: snippet.expansion,
            timesUsed: "\(snippet.timesUsed)",
            lastUsed: snippet.lastUsed.map {
                MainFormatting.day($0, now: now, calendar: calendar, locale: locale)
            } ?? "Never",
            actions: [
                MainAction(title: "Edit", symbolName: "pencil", intent: .editSnippet(snippet.id)),
                .delete(.forgetSnippet(snippet.id)),
            ],
            tint: tint)
    }

    // MARK: - Writing one

    /// The inline editor over a draft, with the reason it cannot be saved yet.
    static func editor(for draft: SnippetDraft, in snapshot: SnippetsSnapshot) -> SnippetEditor {
        SnippetEditor(
            editing: draft.editing,
            trigger: draft.trigger,
            text: draft.text,
            title: draft.editing == nil ? "New snippet" : "Edit snippet",
            triggerLabel: "When I say",
            textLabel: "Type this",
            badge: MainPill(text: draft.editing == nil ? "New" : "Editing"),
            problem: problem(with: draft, in: snapshot),
            save: MainAction(
                title: "Save",
                intent: .saveSnippet(
                    trigger: draft.trigger, text: draft.text, replacing: draft.editing)),
            cancel: MainAction(title: "Cancel", intent: .cancelSnippetEdit))
    }

    /// Why a draft cannot be saved; a duplicate trigger is refused, since one of two would never fire.
    static func problem(with draft: SnippetDraft, in snapshot: SnippetsSnapshot) -> String? {
        let trigger = draft.trigger.trimmingCharacters(in: .whitespacesAndNewlines)
        // An editor that opens complaining is telling somebody off for doing nothing yet.
        if draft.isUntouched { return nil }
        if trigger.isEmpty { return "A snippet needs something to say." }
        // The store's refusal wins: it is the more recent fact and about the attempt the user made.
        if let refusal = snapshot.refusal { return refusal }
        if draft.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "A snippet needs something to type."
        }
        // Compared on the matcher's view of the trigger, so "my address" and "My address:" are one snippet.
        let key = Snippet(trigger: trigger, expansion: " ", created: .distantPast).triggerWords
        let clash = snapshot.snippets.contains {
            $0.id != draft.editing && $0.triggerWords == key
        }
        return clash ? "You already have a snippet for “\(trigger)”." : nil
    }

    // MARK: - Nothing to show

    /// No matches, or no snippets at all.
    static func emptyState(for snapshot: SnippetsSnapshot) -> MainEmptyState {
        let query = SearchQuery.needle(in: snapshot.query)
        if !query.isEmpty {
            return .noMatches("No snippet of yours mentions “\(query)”.")
        }
        return MainEmptyState(
            symbolName: "doc.on.doc",
            title: "No snippets yet",
            message: "Say a short phrase, and Uttrflow types the whole thing.",
            action: MainAction(title: "New Snippet", symbolName: "plus", intent: .addSnippet))
    }
}
