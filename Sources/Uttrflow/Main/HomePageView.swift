// The Home page: the greeting, the hero, the stat tiles and the recent-activity rail.

import UttrflowUX
import SwiftUI

/// The page the window opens on: top bar, hero, four stat tiles, then the last few dictations.
struct HomePageView: View {
    let presentation: HomePresentation
    var onIntent: (MainIntent) -> Void = { _ in }

    var body: some View {
        ScrollView {
            HomePageContent(presentation: presentation, onIntent: onIntent)
        }
    }
}

/// Home's content, top to bottom, without the scroll view that holds it.
struct HomePageContent: View {
    let presentation: HomePresentation
    var onIntent: (MainIntent) -> Void

    /// The width the tiles are given, which decides how many share a row.
    @State private var tilesWidth: CGFloat = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            topBar
            HomeHeroCard(hero: presentation.hero, mood: presentation.mood, onIntent: onIntent)
            if let notice = presentation.speechModel {
                HomeSpeechModelCard(notice: notice, onIntent: onIntent)
            }
            if let step = presentation.nextStep {
                MainCard { MainEmptyStateView(state: step, onIntent: onIntent) }
            }
            if !presentation.tiles.isEmpty {
                tiles
            }
            HomeActivityCard(presentation: presentation, onIntent: onIntent)
        }
        .padding(.horizontal, 28)
        .padding(.top, 34)
        .padding(.bottom, 22)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// The date, and the greeting for the time of day.
    private var topBar: some View {
        HStack(alignment: .bottom, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(presentation.dateLine)
                    .font(.system(size: 13))
                    .foregroundStyle(PagePalette.quiet)
                Text(presentation.greeting)
                    .font(BrandFont.display(size: 30, weight: .semibold))
                    .tracking(-0.9)
                    .foregroundStyle(PagePalette.text)
                    .accessibilityAddTraits(.isHeader)
            }
            Spacer(minLength: 0)
            HomeSearchField(action: presentation.search, onIntent: onIntent)
        }
    }

    /// Four across where they fit, two to a row where they do not.
    private var tiles: some View {
        LazyVGrid(
            columns: Array(
                repeating: GridItem(.flexible(), spacing: 12),
                count: HomeStatTileView.columns(forWidth: tilesWidth)),
            spacing: 12
        ) {
            ForEach(presentation.tiles) { HomeStatTileView(tile: $0) }
        }
        .onGeometryChange(for: CGFloat.self, of: \.size.width) { tilesWidth = $0 }
    }
}

/// The search field in the top bar: a button that looks like a field and opens History's search, also on ⌘K.
struct HomeSearchField: View {
    let action: MainAction
    var onIntent: (MainIntent) -> Void

    var body: some View {
        Button {
            onIntent(action.intent)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: action.symbolName ?? "magnifyingglass")
                    .font(.system(size: 14))
                Text(action.title)
                    .font(.system(size: 13.5))
                    .lineLimit(1)
                Spacer(minLength: 6)
                Text("⌘ K")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(PagePalette.text.opacity(0.75))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(PagePalette.text.opacity(0.1), in: .rect(cornerRadius: 6))
            }
            .foregroundStyle(PagePalette.text.opacity(0.5))
            .padding(.horizontal, 14)
            .frame(width: 300, height: 40)
            .background(PagePalette.text.opacity(0.05), in: .rect(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(PagePalette.text.opacity(0.12), lineWidth: 1)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .keyboardShortcut("k", modifiers: .command)
        .accessibilityLabel(action.title)
    }
}

/// One figure with its icon disc and goal ring, washed in its accent.
struct HomeStatTileView: View {
    let tile: HomeStatTile

    /// The narrowest a tile is drawn in a row of four before the row breaks into two.
    static let narrowest: CGFloat = 180

    /// Four columns where four tiles fit at their narrowest, two otherwise.
    static func columns(forWidth width: CGFloat) -> Int {
        width >= narrowest * 4 + 36 ? 4 : 2
    }

    var body: some View {
        let accent = Self.accent(for: tile.kind)
        HStack(spacing: 14) {
            Image(systemName: Self.symbol(for: tile.kind))
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(accent)
                .frame(width: 42, height: 42)
                .background(accent.opacity(0.22), in: .circle)
            VStack(alignment: .leading, spacing: 1) {
                Text(tile.value)
                    .font(BrandFont.display(size: 21, weight: .semibold))
                    .tracking(-0.4)
                    .monospacedDigit()
                    .foregroundStyle(PagePalette.text)
                    .lineLimit(1)
                Text(tile.label)
                    .font(.system(size: 12.5))
                    .foregroundStyle(PagePalette.text.opacity(0.62))
                    .lineLimit(1)
            }
            // Free to run under the ring, as the design lets a long label do.
            .fixedSize()
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .overlay(alignment: .trailing) {
            ring(accent).padding(.trailing, 16)
        }
        .frame(height: 74)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [accent.opacity(0.16), PagePalette.text.opacity(0.03)],
                        startPoint: .topLeading, endPoint: .bottomTrailing))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(accent.opacity(0.28), lineWidth: 1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(tile.accessibilityLabel)
    }

    /// The goal ring, filled clockwise from the top.
    private func ring(_ accent: Color) -> some View {
        ZStack {
            Circle().stroke(PagePalette.ringTrack, lineWidth: 4)
            Circle()
                .trim(from: 0, to: tile.progress)
                .stroke(accent, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .frame(width: 30, height: 30)
        .padding(5)
    }

    static func accent(for kind: HomeStatKind) -> Color {
        switch kind {
        case .wordsToday: PagePalette.dictation
        case .streak: PagePalette.clipboard
        case .pace: PagePalette.suggestion
        case .leftAsDictated: PagePalette.info
        }
    }

    static func symbol(for kind: HomeStatKind) -> String {
        switch kind {
        case .wordsToday: "doc.text"
        case .streak: "flame.fill"
        case .pace: "bolt.fill"
        case .leftAsDictated: "target"
        }
    }
}

/// The speech model loading, or failed to: a spinner with no fraction, since nothing reports how far it has got.
struct HomeSpeechModelCard: View {
    let notice: HomeSpeechModelNotice
    var onIntent: (MainIntent) -> Void

    var body: some View {
        MainCard {
            HStack(alignment: .top, spacing: 13) {
                Group {
                    if notice.isLoading {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 18))
                            .foregroundStyle(Color.dockWarning)
                    }
                }
                .frame(width: 22, height: 22)
                VStack(alignment: .leading, spacing: 3) {
                    Text(notice.title)
                        .font(.system(size: 15, weight: .semibold))
                    Text(notice.message)
                        .font(.system(size: MainMetrics.bodySize))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if let action = notice.action {
                    MainActionButton(action: action, isProminent: true, onIntent: onIntent)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(notice.accessibilityLabel)
    }
}
