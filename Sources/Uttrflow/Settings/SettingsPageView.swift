// The Settings page in the main window: its title and search, the tab strip, and the tab below.

import UttrflowUX
import SwiftUI

/// The Settings page: a title and search field, six tabs, and the selected tab in one centred column.
struct SettingsPageView: View {
    @Bindable var model: SettingsViewModel
    /// The Diagnostics tab's content, which the main window already holds for every page.
    let diagnostics: DiagnosticsPresentation
    /// Rises when Find is chosen; the search field takes the focus when it does.
    var searchFocusRequest = 0
    var onIntent: (MainIntent) -> Void = { _ in }

    var body: some View {
        let presentation = model.session.presentation
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.bottom, 16)
            SettingsTabStrip(
                tabs: presentation.tabs,
                selected: presentation.query.isEmpty ? presentation.selected : nil
            ) { model.select($0) }
            .padding(.bottom, 22)
            ScrollView {
                Group {
                    if presentation.query.isEmpty && presentation.selected == .diagnostics {
                        SettingsDiagnosticsView(presentation: diagnostics, onIntent: onIntent)
                    } else {
                        SettingsPaneView(pane: presentation.pane, model: model)
                    }
                }
                .padding(.bottom, 40)
            }
            .scrollIndicators(.never)
            // The column fades out at its foot rather than being cut off by the window's edge.
            .mask {
                LinearGradient(
                    stops: [.init(color: .black, location: 0.88), .init(color: .clear, location: 1)],
                    startPoint: .top, endPoint: .bottom)
            }
        }
        .frame(maxWidth: SettingsMetrics.columnWidth)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.top, SettingsMetrics.topInset)
        .padding(.horizontal, 34)
        .foregroundStyle(PagePalette.text)
        // Over the whole page rather than the scrolled column, so the question is centred in what is seen.
        .overlay {
            if let asked, let confirmation = asked.confirmation {
                ConfirmationSheet(
                    confirmation: MainConfirmation(confirmation),
                    onCancel: { model.dismissRemoval() },
                    onConfirm: { model.confirm(asked) })
            }
        }
        .animation(.easeOut(duration: 0.15), value: asked)
    }

    /// What is being asked, if anything; the session knows which button was pressed.
    private var asked: SettingsRemoval? { model.session.pendingRemoval }

    private var header: some View {
        HStack(spacing: 16) {
            Text("Settings")
                .font(BrandFont.display(size: 28, weight: .semibold))
                .tracking(-0.84)
                .fixedSize()
                .accessibilityAddTraits(.isHeader)
            SettingsSearchField(
                query: Binding(get: { model.session.query }, set: { model.search($0) }),
                focusRequest: searchFocusRequest)
        }
    }
}

/// The page's search field, which filters every tab's rows as it is typed into.
struct SettingsSearchField: View {
    @Binding var query: String
    var focusRequest = 0

    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13))
                .foregroundStyle(PagePalette.faint)
            TextField(SettingsPresenter.searchPlaceholder, text: $query)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .focused($isFocused)
            if query.isEmpty {
                Text("⌘F")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(PagePalette.faint)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(SettingsPalette.ink(0.08), in: .rect(cornerRadius: 5))
                    .accessibilityHidden(true)
            } else {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(PagePalette.faint)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear the search")
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 38)
        .frame(maxWidth: .infinity)
        .background(SettingsPalette.ink(0.05), in: .rect(cornerRadius: 11, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .strokeBorder(SettingsPalette.ink(0.1), lineWidth: 1)
        )
        .onChange(of: focusRequest) { _, _ in isFocused = true }
        // Escape empties a field with something in it, and is left alone when there is nothing to clear.
        .onKeyPress(.escape) {
            guard !query.isEmpty else { return .ignored }
            query = ""
            return .handled
        }
    }
}

/// Six tabs sharing one track, the chosen one filled; none is chosen while a search is showing.
struct SettingsTabStrip: View {
    let tabs: [SettingsTabItem]
    let selected: SettingsTab?
    let onSelect: (SettingsTab) -> Void

    var body: some View {
        HStack(spacing: 2) {
            ForEach(tabs) { item in
                let isSelected = item.tab == selected
                Button {
                    onSelect(item.tab)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: item.symbolName)
                            .font(.system(size: 11))
                        // Sized by the bold title, so selecting a tab never widens it or moves the others.
                        Text(item.title)
                            .font(.system(size: 12.5, weight: .semibold))
                            .hidden()
                            .overlay {
                                Text(item.title)
                                    .font(.system(size: 12.5, weight: isSelected ? .semibold : .regular))
                            }
                            .lineLimit(1)
                            .fixedSize()
                    }
                    .foregroundStyle(isSelected ? SettingsPalette.inverseInk : SettingsPalette.ink(0.62))
                    .frame(maxWidth: .infinity)
                    .frame(height: 32)
                    .background {
                        if isSelected {
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .fill(SettingsPalette.inverseFill)
                                .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
                        }
                    }
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(item.title)
                .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
            }
        }
        .padding(3)
        .background(SettingsPalette.ink(0.05), in: .rect(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(SettingsPalette.ink(0.06), lineWidth: 1)
        )
    }
}

enum SettingsMetrics {
    /// The one column every tab is laid out in, centred in the pane.
    static let columnWidth: CGFloat = 640
    /// The room above the title, under the window's traffic lights.
    static let topInset: CGFloat = 44
}
