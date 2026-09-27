// The Dictionary page: today's fixes, the filter chips, the words table and its editor card.

import UttrflowUX
import SwiftUI

/// The words Uttrflow knows and a general model does not.
struct DictionaryPageView: View {
    let presentation: DictionaryPresentation
    /// What is being typed into the editor, held by the window so it survives a redraw.
    @Binding var draft: DictionaryDraft
    var onIntent: (MainIntent) -> Void
    /// Reports the chosen filter chip.
    var onFilter: (String) -> Void = { _ in }

    /// The artboard's columns: word, sound, source, used, undone, and the row's controls.
    static let widths: [PageColumnWidth] = [
        .share(1.1), .share(1.1), .share(1), .fixed(55), .fixed(60), .fixed(64),
    ]

    var body: some View {
        if let empty = presentation.emptyState, presentation.filters.isEmpty {
            MainEmptyStateView(state: empty, onIntent: onIntent)
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if let editor = presentation.editor {
                        DictionaryEditorView(editor: editor, draft: $draft, onIntent: onIntent)
                            .padding(.bottom, 14)
                    }
                    if let label = presentation.fixesLabel {
                        DictionaryFixesView(
                            label: label, fixes: presentation.fixes, onIntent: onIntent
                        )
                        .padding(.bottom, 18)
                    }
                    if !presentation.filters.isEmpty {
                        filters.padding(.bottom, 14)
                    }
                    if let empty = presentation.emptyState {
                        MainEmptyStateView(state: empty, onIntent: onIntent)
                            .frame(minHeight: 220)
                    } else {
                        table
                    }
                    if let footnote = presentation.footnote {
                        MainFootnote(text: footnote)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollIndicators(.automatic)
        }
    }

    private var filters: some View {
        HStack(spacing: 6) {
            ForEach(presentation.filters) { PageFilterChip(option: $0, onSelect: onFilter) }
        }
    }

    private var table: some View {
        LazyVStack(alignment: .leading, spacing: 0) {
            PageTableHeader(
                titles: ["Write it as", "Say it like", "From", "Used", "Undone", ""],
                widths: Self.widths)
            ForEach(presentation.rows) { row in
                PageDivider()
                DictionaryRowView(row: row, onIntent: onIntent)
            }
        }
        .pageCard()
    }
}

/// One word; a retired row is dimmed and offers Restore, and Delete waits for the pointer.
struct DictionaryRowView: View {
    let row: DictionaryRow
    var onIntent: (MainIntent) -> Void

    @State private var isHovered = false
    @FocusState private var focusedControl: String?

    var body: some View {
        PageColumns(widths: DictionaryPageView.widths) {
            Text(row.word)
                .fontWeight(.semibold)
                .foregroundStyle(PagePalette.text)
                .lineLimit(1)
            Text(row.pronunciation)
                .italic()
                .foregroundStyle(PagePalette.text.opacity(0.6))
                .lineLimit(1)
            PageTintChip(text: row.source.title, tint: DictionarySourceTint.color(row.source))
                .help(row.origin)
            Text("\(row.timesUsed)×")
                .monospacedDigit()
                .foregroundStyle(PagePalette.text.opacity(0.6))
            Text("\(row.timesUndone)×")
                .monospacedDigit()
                .foregroundStyle(undoneColor)
            controls
        }
        .font(.system(size: 13))
        .opacity(row.isRetired ? 0.6 : 1)
        .padding(.horizontal, PageMetrics.rowInset)
        .padding(.vertical, 11)
        .background(isHovered ? PagePalette.text.opacity(0.03) : .clear)
        .contentShape(.rect)
        .onHover { isHovered = $0 }
        .accessibilityElement(children: .contain)
        .rowActions(row.actions, onIntent: onIntent)
    }

    /// Amber once undone, red when the undos are what is retiring it, quiet otherwise.
    private var undoneColor: Color {
        if row.undoneIsConcerning { return .criticalInk }
        return row.hasBeenUndone ? PagePalette.clipboardInk : PagePalette.faint
    }

    /// Restore is drawn at rest on a retired word; Delete's glyph waits for the pointer or the keyboard.
    private var controls: some View {
        HStack(spacing: 4) {
            Spacer(minLength: 0)
            ForEach(row.actions) { action in
                if action.isDestructive {
                    PageRowIconButton(
                        action: action,
                        isShown: RowReveal.isDrawn(isHovered: isHovered, focusedControl: focusedControl),
                        onIntent: onIntent
                    )
                    .focused($focusedControl, equals: action.id)
                } else {
                    Button(action.title) { onIntent(action.intent) }
                        .buttonStyle(.plain)
                        .font(.system(size: 11.5))
                        .foregroundStyle(PagePalette.clipboardInk)
                        .focused($focusedControl, equals: action.id)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }
}

/// Which accent each source chip wears.
enum DictionarySourceTint {
    static func color(_ source: DictionarySource) -> Color {
        switch source {
        case .added: PagePalette.dictation
        case .learned: PagePalette.suggestion
        case .seen: PagePalette.info
        case .shipped: PagePalette.neutral
        case .retired: PagePalette.clipboard
        }
    }
}

/// Today's corrections: a label, then up to three cards, each with its way back.
struct DictionaryFixesView: View {
    let label: String
    let fixes: [CorrectionRow]
    var onIntent: (MainIntent) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            PageSectionLabel(text: label)
            HStack(alignment: .top, spacing: 10) {
                ForEach(fixes) { DictionaryFixCard(fix: $0, onIntent: onIntent) }
                // Keeps a card a third of the row wide when fewer than three were fixed.
                ForEach(fixes.count..<max(fixes.count, 3), id: \.self) { _ in
                    Color.clear.frame(maxWidth: .infinity, maxHeight: 1)
                }
            }
        }
    }
}

/// One correction: when, what was heard struck through, what was written, and Undo.
struct DictionaryFixCard: View {
    let fix: CorrectionRow
    var onIntent: (MainIntent) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(fix.when)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(PagePalette.faint)
                Spacer(minLength: 6)
                if let undo = fix.undo {
                    Button {
                        onIntent(undo.intent)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.uturn.backward").font(.system(size: 10))
                            Text(undo.title)
                        }
                        .font(.system(size: 11))
                        .foregroundStyle(PagePalette.text.opacity(0.6))
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                }
            }
            HStack(spacing: 5) {
                Text(fix.heard)
                    .strikethrough()
                    .foregroundStyle(PagePalette.faint)
                Image(systemName: "arrow.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(PagePalette.dictation)
                    .accessibilityHidden(true)
                Text(fix.wrote)
                    .fontWeight(.semibold)
                    .foregroundStyle(PagePalette.text)
            }
            .font(.system(size: 13))
            .lineLimit(1)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .pageCard()
        .accessibilityElement(children: .contain)
        .accessibilityLabel("“\(fix.heard)” was changed to “\(fix.wrote)” at \(fix.when)")
    }
}

/// The word being written, on a card over the table shaped like the snippet editor.
struct DictionaryEditorView: View {
    let editor: DictionaryEditor
    @Binding var draft: DictionaryDraft
    var onIntent: (MainIntent) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("New word")
                    .font(BrandFont.display(size: 14, weight: .semibold))
                    .foregroundStyle(PagePalette.text)
                Spacer(minLength: 0)
                PageBadge(text: editor.badge.text)
            }
            PageEditorField(
                label: editor.wordLabel, symbolName: "character.cursor.ibeam",
                tint: PagePalette.dictation
            ) {
                TextField("", text: word).textFieldStyle(.plain)
            }
            VStack(alignment: .leading, spacing: 5) {
                PageEditorField(
                    label: editor.pronunciationLabel, symbolName: "ear", tint: PagePalette.suggestion
                ) {
                    TextField("", text: pronunciation).textFieldStyle(.plain)
                }
                Text(editor.pronunciationHint)
                    .font(.system(size: 11.5))
                    .foregroundStyle(PagePalette.faint)
            }
            PageEditorFooter(
                problem: editor.problem, cancel: editor.cancel, save: save,
                canSave: editor.canSave, onIntent: onIntent)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .pageCard(edge: PagePalette.dictation.opacity(0.35))
    }

    /// Rebuilt from what is in the fields now, not from the presentation drawn a keystroke ago.
    private var save: MainAction {
        MainAction(
            title: editor.save.title,
            intent: .saveWord(word: draft.word, pronunciation: draft.pronunciation))
    }

    private var word: Binding<String> {
        Binding(
            get: { draft.word },
            set: { draft = DictionaryDraft(word: $0, pronunciation: draft.pronunciation) })
    }

    private var pronunciation: Binding<String> {
        Binding(
            get: { draft.pronunciation },
            set: { draft = DictionaryDraft(word: draft.word, pronunciation: $0) })
    }
}
