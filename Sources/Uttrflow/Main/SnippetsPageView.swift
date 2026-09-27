// The Snippets page: the editor card, the table, and the worked example on the empty page.

import UttrflowUX
import SwiftUI

/// Triggers you say, and the text you get instead.
struct SnippetsPageView: View {
    let presentation: SnippetsPresentation
    /// What is being typed into the editor, held by the window so it survives a redraw.
    @Binding var draft: SnippetDraft
    var onIntent: (MainIntent) -> Void

    /// The artboard's columns: trigger, text, used, last used, and the row's controls.
    static let widths: [PageColumnWidth] = [.fixed(150), .share(1), .fixed(60), .fixed(90), .fixed(60)]

    var body: some View {
        if let empty = presentation.emptyState, presentation.editor == nil {
            // The example sits below the scene, not over it, so the scene gives up room before the card is cut.
            VStack(spacing: 0) {
                MainEmptyStateView(state: empty, onIntent: onIntent)
                if let example = presentation.example {
                    SnippetExampleCard(example: example)
                        .padding(.top, 12)
                        .padding(.bottom, 12)
                        .layoutPriority(1)
                }
            }
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if let editor = presentation.editor {
                        SnippetEditorView(editor: editor, draft: $draft, onIntent: onIntent)
                            .padding(.bottom, 14)
                    }
                    if !presentation.rows.isEmpty {
                        table
                    }
                    if let footnote = presentation.footnote {
                        MainFootnote(text: footnote)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var table: some View {
        LazyVStack(alignment: .leading, spacing: 0) {
            PageTableHeader(titles: ["When I say", "Type this", "Used", "Last", ""], widths: Self.widths)
            ForEach(presentation.rows) { row in
                PageDivider()
                SnippetRowView(row: row, onIntent: onIntent)
            }
        }
        .pageCard()
    }
}

/// One snippet; Edit sits at rest and Delete waits for the pointer.
struct SnippetRowView: View {
    let row: SnippetRow
    var onIntent: (MainIntent) -> Void

    @State private var isHovered = false
    @FocusState private var focusedControl: String?

    var body: some View {
        PageColumns(widths: SnippetsPageView.widths) {
            SnippetTriggerPill(text: row.trigger.text, tint: SnippetTint.color(row.tint))
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(row.text.replacingOccurrences(of: "\n", with: " "))
                .foregroundStyle(PagePalette.text.opacity(0.8))
                .lineLimit(1)
                .truncationMode(.tail)
            Text("\(row.timesUsed)×")
                .monospacedDigit()
                .foregroundStyle(PagePalette.text.opacity(0.6))
            Text(row.lastUsed)
                .font(.system(size: 12))
                .foregroundStyle(PagePalette.faint)
                .lineLimit(1)
            controls
        }
        .font(.system(size: 13))
        .padding(.horizontal, PageMetrics.rowInset)
        .padding(.vertical, 11)
        .background(isHovered ? PagePalette.text.opacity(0.03) : .clear)
        .contentShape(.rect)
        .onHover { isHovered = $0 }
        .rowActions(row.actions, onIntent: onIntent)
    }

    /// Hidden rather than removed, so VoiceOver can reach Delete and the row keeps its width.
    private var controls: some View {
        HStack(spacing: 2) {
            Spacer(minLength: 0)
            ForEach(row.actions) { action in
                if action.isDestructive {
                    PageRowIconButton(action: action, onIntent: onIntent)
                        .revealedInRow(action.id, isHovered: isHovered, focusedControl: $focusedControl)
                } else {
                    PageRowIconButton(action: action, onIntent: onIntent)
                        .focused($focusedControl, equals: action.id)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }
}

/// The phrase you say, as a tinted pill with a microphone.
struct SnippetTriggerPill: View {
    let text: String
    let tint: Color

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "mic")
                .font(.system(size: 10))
                .foregroundStyle(tint)
                .accessibilityHidden(true)
            Text(text).lineLimit(1)
        }
        .font(.system(size: 12.5, weight: .medium))
        .foregroundStyle(PagePalette.text)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(tint.opacity(0.16), in: Capsule())
        .overlay { Capsule().strokeBorder(tint.opacity(0.35), lineWidth: 1) }
        .fixedSize()
    }
}

/// The four accents a trigger pill cycles through, in the artboard's order.
enum SnippetTint {
    static func color(_ index: Int) -> Color {
        switch index % SnippetsPresenter.tints {
        case 0: PagePalette.clipboard
        case 1: PagePalette.info
        case 2: PagePalette.suggestion
        default: PagePalette.dictation
        }
    }
}

/// The snippet being written, on a card over the table.
struct SnippetEditorView: View {
    let editor: SnippetEditor
    @Binding var draft: SnippetDraft
    var onIntent: (MainIntent) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(editor.title)
                    .font(BrandFont.display(size: 14, weight: .semibold))
                    .foregroundStyle(PagePalette.text)
                Spacer(minLength: 0)
                PageBadge(text: editor.badge.text)
            }
            PageEditorField(label: editor.triggerLabel, symbolName: "mic", tint: PagePalette.dictation) {
                TextField("", text: trigger).textFieldStyle(.plain)
            }
            PageEditorField(label: editor.textLabel, symbolName: "keyboard", tint: PagePalette.suggestion) {
                TextEditor(text: text)
                    .scrollContentBackground(.hidden)
                    .lineSpacing(3)
                    .frame(minHeight: 64)
                    .padding(.horizontal, -5)
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
            intent: .saveSnippet(
                trigger: draft.trigger, text: draft.text, replacing: editor.editing))
    }

    private var trigger: Binding<String> {
        Binding(
            get: { draft.trigger },
            set: { draft = SnippetDraft(editing: draft.editing, trigger: $0, text: draft.text) })
    }

    private var text: Binding<String> {
        Binding(
            get: { draft.text },
            set: { draft = SnippetDraft(editing: draft.editing, trigger: draft.trigger, text: $0) })
    }
}

/// The worked example on the empty page, so the idea lands before the form does.
struct SnippetExampleCard: View {
    let example: SnippetExample

    var body: some View {
        MainCard(padding: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text(example.heading.uppercased())
                    .font(.system(size: MainMetrics.footnoteSize, weight: .semibold))
                    .foregroundStyle(.tertiary)
                HStack(spacing: 8) {
                    MainPillView(pill: example.trigger)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                    Text(example.text)
                        .font(.system(size: MainMetrics.calloutSize))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(width: 400)
        .accessibilityElement(children: .combine)
    }
}
