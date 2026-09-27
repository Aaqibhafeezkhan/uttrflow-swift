// The Dictionary page: its rows, the inline editor, and the presenter that draws them.
public import Foundation
public import UttrflowDictionary

/// Where a word came from as its chip says it, with a retired word counted apart from its origin.
public enum DictionarySource: String, Sendable, Equatable, CaseIterable {
    case added
    case learned
    case seen
    case shipped
    case retired

    /// The chip's words.
    public var title: String {
        switch self {
        case .added: "Added by you"
        case .learned: "Learned"
        case .seen: "Seen on screen"
        case .shipped: "Shipped"
        case .retired: "Retired"
        }
    }

    /// The source an entry is listed under.
    public init(_ entry: DictionaryEntry) {
        guard entry.isTrustworthy else {
            self = .retired
            return
        }
        switch entry.origin {
        case .added: self = .added
        case .learned: self = .learned
        case .observed: self = .seen
        case .shipped: self = .shipped
        }
    }
}

/// One word as the dictionary page lists it, drawn from ``DictionaryEntry`` and never a second rule.
public struct DictionaryRow: Sendable, Equatable, Identifiable {
    /// The entry's identity.
    public let id: UUID
    /// The spelling.
    public let word: String
    /// How it sounds; an em dash where the spelling is a fair guide, so the cell never reads as missing.
    public let pronunciation: String
    /// "Learned", "Added by you", "Seen on screen".
    public let origin: String
    /// The chip the row wears, "Retired" in place of the origin once the word has retired.
    public let source: DictionarySource
    /// "12 Aug".
    public let added: String
    /// How often it has been applied, as text.
    public let timesUsed: String
    /// How often the user has undone it, as text.
    public let timesUndone: String
    /// Whether the word has been undone at all, which tints the count.
    public let hasBeenUndone: Bool
    /// Whether the undo count is the reason this word is in trouble; drawn in red before it retires.
    public let undoneIsConcerning: Bool
    /// A word that undid itself more often than it helped; dimmed and badged, but still operable.
    public let isRetired: Bool
    /// Restore on a retired word, delete on any other.
    public let actions: [MainAction]

    /// Builds a row from its parts.
    public init(
        id: UUID,
        word: String,
        pronunciation: String,
        origin: String,
        source: DictionarySource,
        added: String,
        timesUsed: String,
        timesUndone: String,
        hasBeenUndone: Bool,
        undoneIsConcerning: Bool,
        isRetired: Bool,
        actions: [MainAction]
    ) {
        self.id = id
        self.word = word
        self.pronunciation = pronunciation
        self.origin = origin
        self.source = source
        self.added = added
        self.timesUsed = timesUsed
        self.timesUndone = timesUndone
        self.hasBeenUndone = hasBeenUndone
        self.undoneIsConcerning = undoneIsConcerning
        self.isRetired = isRetired
        self.actions = actions
    }
}

/// The word being typed in; two fields and no identifier, since a row is never edited, only re-added.
public struct DictionaryDraft: Sendable, Equatable {
    /// The spelling typed so far.
    public let word: String
    /// How it sounds, when the spelling is not a fair guide. Blank is normal.
    public let pronunciation: String

    /// Starts empty unless given text.
    public init(word: String = "", pronunciation: String = "") {
        self.word = word
        self.pronunciation = pronunciation
    }

    /// Nothing typed yet, so there is nothing to complain about; see `problem(with:in:)`.
    public var isUntouched: Bool { word.isEmpty && pronunciation.isEmpty }
}

/// The word being written, in the row where it will end up; a separate type from the snippet editor.
public struct DictionaryEditor: Sendable, Equatable {
    /// The spelling typed so far.
    public let word: String
    /// The pronunciation typed so far.
    public let pronunciation: String
    /// The label on the spelling field.
    public let wordLabel: String
    /// The label on the pronunciation field.
    public let pronunciationLabel: String
    /// What the second field is for, said in the row, since the label alone does not explain it.
    public let pronunciationHint: String
    /// "New".
    public let badge: MainPill
    /// Why this cannot be saved yet, in words. Absent when it can.
    public let problem: String?
    /// Commits the word.
    public let save: MainAction
    /// Closes the editor unchanged.
    public let cancel: MainAction

    /// Whether Save is enabled.
    public var canSave: Bool { problem == nil }

    /// Builds the editor from its parts.
    public init(
        word: String,
        pronunciation: String,
        wordLabel: String,
        pronunciationLabel: String,
        pronunciationHint: String,
        badge: MainPill,
        problem: String?,
        save: MainAction,
        cancel: MainAction
    ) {
        self.word = word
        self.pronunciation = pronunciation
        self.wordLabel = wordLabel
        self.pronunciationLabel = pronunciationLabel
        self.pronunciationHint = pronunciationHint
        self.badge = badge
        self.problem = problem
        self.save = save
        self.cancel = cancel
    }
}

/// Everything the dictionary page is drawn from.
public struct DictionarySnapshot: Sendable, Equatable {
    /// In the store's order, retired entries included, so a word said to have stopped can be seen.
    public let entries: [DictionaryEntry]
    /// Set while the inline editor is open.
    public let draft: DictionaryDraft?
    /// Why the last Save did not happen, when the store refused it; known only after the button is pressed.
    public let refusal: String?
    /// What has been typed into the search field.
    public let query: String
    /// The chosen filter chip's identifier; empty or unknown lists every word.
    public let filter: String
    /// Dictionary corrections, newest first, from which today's are drawn as cards.
    public let corrections: [Correction]
    /// The clock the page is drawn against.
    public let now: Date

    /// Builds a snapshot; everything but the clock defaults to empty.
    public init(
        entries: [DictionaryEntry] = [], draft: DictionaryDraft? = nil, refusal: String? = nil,
        query: String = "", filter: String = "", corrections: [Correction] = [], now: Date
    ) {
        self.entries = entries
        self.draft = draft
        self.refusal = refusal
        self.query = query
        self.filter = filter
        self.corrections = corrections
        self.now = now
    }
}

/// What the dictionary page shows.
public struct DictionaryPresentation: Sendable, Equatable {
    /// The title, caption, search field and Add button across the top.
    public let chrome: MainPageChrome
    /// "Fixed today · 3 corrections", over today's cards; absent when nothing was fixed today.
    public let fixesLabel: String?
    /// Today's corrections still standing, newest first, at most three.
    public let fixes: [CorrectionRow]
    /// The filter chips over the table, empty while there are no words to filter.
    public let filters: [MainScopeOption]
    /// The words that match the query and the filter.
    public let rows: [DictionaryRow]
    /// The open editor, above the rows. Present only while a word is being written.
    public let editor: DictionaryEditor?
    /// Absent while the editor is open, so the user is not told the dictionary is empty mid-entry.
    public let emptyState: MainEmptyState?
    /// What the origins mean, under the rows.
    public let footnote: String?

    /// Builds the page from its parts.
    public init(
        chrome: MainPageChrome,
        fixesLabel: String?,
        fixes: [CorrectionRow],
        filters: [MainScopeOption],
        rows: [DictionaryRow],
        editor: DictionaryEditor?,
        emptyState: MainEmptyState?,
        footnote: String?
    ) {
        self.chrome = chrome
        self.fixesLabel = fixesLabel
        self.fixes = fixes
        self.filters = filters
        self.rows = rows
        self.editor = editor
        self.emptyState = emptyState
        self.footnote = footnote
    }
}

/// Turns the personal dictionary into the page that explains it.
public enum DictionaryPresenter {
    /// What the empty search field says.
    public static let searchPlaceholder = "Search words"

    /// The undo count worth pointing at; below the retirement threshold so a word is seen going wrong first.
    static let concerningUndos = 2

    /// Draws the Dictionary page from a snapshot.
    public static func page(
        for snapshot: DictionarySnapshot,
        calendar: Calendar = .autoupdatingCurrent,
        locale: Locale = .autoupdatingCurrent
    ) -> DictionaryPresentation {
        let filter = self.filter(named: snapshot.filter)
        let listed = matches(snapshot.entries, query: snapshot.query, locale: locale)
            .filter { filter == nil || DictionarySource($0) == filter }
        let rows = listed.map { row(for: $0, locale: locale) }
        let editor = snapshot.draft.map { self.editor(for: $0, in: snapshot) }
        let today = fixedToday(in: snapshot, calendar: calendar)

        return DictionaryPresentation(
            chrome: MainPageChrome(
                title: "Dictionary",
                caption: caption(for: snapshot.entries.count),
                search: snapshot.entries.isEmpty
                    ? nil
                    : MainSearchField(placeholder: searchPlaceholder, query: snapshot.query),
                addAction: MainAction(title: "Add Word", symbolName: "plus", intent: .addWord)),
            fixesLabel: today.isEmpty
                ? nil
                : "Fixed today · \(MainFormatting.count(today.count, "correction", "corrections"))",
            fixes: today.prefix(fixesShown).map { CorrectionsPresenter.row(for: $0, locale: locale) },
            filters: snapshot.entries.isEmpty ? [] : filters(selecting: filter),
            rows: rows,
            editor: editor,
            emptyState: rows.isEmpty && editor == nil ? emptyState(for: snapshot, filter: filter) : nil,
            footnote: rows.isEmpty ? nil : footnote(for: listed))
    }

    /// How many of today's corrections are drawn as cards.
    static let fixesShown = 3

    /// "Names and terms Uttrflow would otherwise get wrong. · 24 words", the count once there is one.
    static func caption(for count: Int) -> String {
        let lede = "Names and terms Uttrflow would otherwise get wrong."
        return count == 0 ? lede : "\(lede) · \(MainFormatting.count(count, "word", "words"))"
    }

    // MARK: - Today's fixes

    /// Corrections made today and not undone, newest first, matching the sidebar's count.
    static func fixedToday(in snapshot: DictionarySnapshot, calendar: Calendar) -> [Correction] {
        snapshot.corrections
            .filter { !$0.isUndone && calendar.isDate($0.when, inSameDayAs: snapshot.now) }
            .sorted { $0.when > $1.when }
    }

    // MARK: - Filtering

    /// The chips in order: every word, then each source a word can be listed under but shipped.
    static let filterSources: [DictionarySource] = [.added, .learned, .seen, .retired]

    /// The chip identifier that lists every word.
    public static let allFilter = "all"

    /// The source a chip identifier names, or `nil` for every word.
    static func filter(named id: String) -> DictionarySource? {
        DictionarySource(rawValue: id).flatMap { filterSources.contains($0) ? $0 : nil }
    }

    /// The chips, with the chosen one selected.
    static func filters(selecting chosen: DictionarySource?) -> [MainScopeOption] {
        [MainScopeOption(id: allFilter, title: "All", isSelected: chosen == nil)]
            + filterSources.map {
                MainScopeOption(id: $0.rawValue, title: $0.title, isSelected: $0 == chosen)
            }
    }

    /// What the four origins mean, and what a retired word is only when one is on screen.
    static func footnote(for entries: [DictionaryEntry]) -> String {
        let origins = """
            Learned means you said a word again over the spelling Uttrflow got wrong, and it \
            kept yours. Seen on screen means the title of what you were working in kept \
            saying it while you spoke. Added by you means you typed it in here. Shipped with \
            Uttrflow means it came with the app; delete it and it stays deleted. Every word \
            here stays on this Mac.
            """
        guard entries.contains(where: { !$0.isTrustworthy }) else { return origins }
        return """
            \(origins) A word you undo more often than you keep retires itself and stops being \
            applied. Restore to try again.
            """
    }

    // MARK: - Searching

    /// Matches the spelling and the pronunciation, ignoring case and accents.
    static func matches(
        _ entries: [DictionaryEntry], query: String, locale: Locale
    ) -> [DictionaryEntry] {
        SearchQuery.matches(entries, query: query, locale: locale) { [$0.word, $0.pronunciation] }
    }

    // MARK: - One word

    /// One entry as a row, with Restore on a retired word and Delete on every one.
    static func row(for entry: DictionaryEntry, locale: Locale) -> DictionaryRow {
        let isRetired = !entry.isTrustworthy
        return DictionaryRow(
            id: entry.id,
            word: entry.word,
            pronunciation: entry.pronunciation ?? "—",
            origin: title(for: entry.origin),
            source: DictionarySource(entry),
            added: entry.firstSeen.formatted(.dateTime.day().month(.abbreviated).locale(locale)),
            timesUsed: "\(entry.timesUsed)",
            timesUndone: "\(entry.timesReverted)",
            hasBeenUndone: entry.timesReverted > 0,
            undoneIsConcerning: entry.timesReverted > concerningUndos,
            isRetired: isRetired,
            actions: (isRetired ? [MainAction(title: "Restore", intent: .restoreWord(entry.id))] : [])
                + [.delete(.forgetWord(entry.id))])
    }

    /// The user's words for where a word came from; "Seen on screen" rather than "observed".
    public static func title(for origin: WordOrigin) -> String {
        switch origin {
        case .learned: "Learned"
        case .added: "Added by you"
        case .observed: "Seen on screen"
        case .shipped: "Shipped with Uttrflow"
        }
    }

    // MARK: - Writing one

    /// The inline editor over a draft, with the reason it cannot be saved yet.
    static func editor(
        for draft: DictionaryDraft, in snapshot: DictionarySnapshot
    ) -> DictionaryEditor {
        DictionaryEditor(
            word: draft.word,
            pronunciation: draft.pronunciation,
            wordLabel: "Write it as",
            pronunciationLabel: "Say it like",
            pronunciationHint: pronunciationHint(for: draft),
            badge: MainPill(text: "New"),
            problem: problem(with: draft, in: snapshot),
            save: MainAction(
                title: "Save",
                intent: .saveWord(word: draft.word, pronunciation: draft.pronunciation)),
            cancel: MainAction(title: "Cancel", intent: .cancelWordEdit))
    }

    /// What the pronunciation field is for, and when it is the only thing that will make the word work.
    static func pronunciationHint(for draft: DictionaryDraft) -> String {
        let word = draft.word.trimmingCharacters(in: .whitespacesAndNewlines)
        // A spelling with no English letters is matched letter for letter, which is not how dictation arrives.
        guard !word.isEmpty, draft.pronunciation.isEmpty,
            DoubleMetaphone.code(for: word).isSilent
        else {
            return """
                Leave this blank unless the spelling misleads. \u{201C}Nikhil\u{201D} written, \
                \u{201C}Nikkel\u{201D} said.
                """
        }
        return """
            \u{201C}\(word)\u{201D} has no English letters to sound out, so write here how it is \
            said — otherwise it is only matched spelt exactly this way.
            """
    }

    /// Why a draft cannot be saved; an existing word is refused, since re-adding resets its counters.
    static func problem(with draft: DictionaryDraft, in snapshot: DictionarySnapshot) -> String? {
        let word = draft.word.trimmingCharacters(in: .whitespacesAndNewlines)
        // The store's refusal wins: it is the more recent fact and about the attempt the user made.
        if let refusal = snapshot.refusal, !word.isEmpty { return refusal }
        // An editor that opens complaining is telling somebody off for doing nothing yet.
        if draft.isUntouched { return nil }
        if word.isEmpty { return "A word needs a spelling." }
        // Case only, matching ``PersonalDictionaryStore/add(_:)``, so "café" is not refused over "cafe".
        let clash = snapshot.entries.contains {
            $0.word.compare(word, options: .caseInsensitive) == .orderedSame
        }
        return clash ? "“\(word)” is already in your dictionary." : nil
    }

    // MARK: - Nothing to show

    /// No matches, nothing under the chosen chip, or no words at all.
    static func emptyState(for snapshot: DictionarySnapshot, filter: DictionarySource?) -> MainEmptyState {
        let query = SearchQuery.needle(in: snapshot.query)
        if !query.isEmpty {
            return .noMatches("No word in your dictionary looks or sounds like “\(query)”.")
        }
        if let filter, !snapshot.entries.isEmpty {
            return MainEmptyState(
                symbolName: "line.3.horizontal.decrease",
                title: "Nothing in this view",
                message: """
                    \(MainFormatting.count(snapshot.entries.count, "word", "words")), and none of \
                    them is listed as \(filter.title.lowercased()).
                    """)
        }
        return MainEmptyState(
            symbolName: "character.book.closed",
            title: "No words of your own yet",
            message: "Add names and terms Uttrflow would otherwise get wrong.",
            action: MainAction(title: "Add Word", symbolName: "plus", intent: .addWord))
    }
}
