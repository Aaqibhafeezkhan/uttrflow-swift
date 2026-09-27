// Home's recent-activity card: the last few dictations on a time rail.

import UttrflowUX
import SwiftUI

/// The last few dictations on a time rail, with the way to History.
struct HomeActivityCard: View {
    let presentation: HomePresentation
    var onIntent: (MainIntent) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            if presentation.activity.isEmpty {
                Text(presentation.subtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(PagePalette.soft)
                    .padding(.vertical, 6)
            } else {
                rail
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PagePalette.card, in: .rect(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(PagePalette.cardEdge, lineWidth: 1)
        }
    }

    private var header: some View {
        HStack {
            HStack(spacing: 10) {
                Circle()
                    .fill(PagePalette.dictation)
                    .frame(width: 9, height: 9)
                    .shadow(color: PagePalette.dictation, radius: 4)
                Text("Recent activity")
                    .font(BrandFont.display(size: 15, weight: .semibold))
                    .foregroundStyle(PagePalette.text)
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 8)
            if let viewAll = presentation.viewAll {
                Button {
                    onIntent(viewAll.intent)
                } label: {
                    HStack(spacing: 6) {
                        Text(viewAll.title)
                        Image(systemName: "arrow.right").font(.system(size: 11, weight: .semibold))
                    }
                    .font(.system(size: 13.5))
                    .foregroundStyle(PagePalette.dictation)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
            }
        }
    }

    /// The rows beside a line that runs teal to blue to lilac down the gutter.
    private var rail: some View {
        VStack(spacing: 8) {
            ForEach(presentation.activity) { HomeActivityRowView(row: $0, onIntent: onIntent) }
        }
        .background(alignment: .leading) {
            LinearGradient(
                colors: [PagePalette.dictation, PagePalette.info, PagePalette.suggestion],
                startPoint: .top, endPoint: .bottom
            )
            .frame(width: 2)
            .padding(.vertical, 10)
            .padding(.leading, HomeActivityRowView.lineOffset)
            .accessibilityHidden(true)
        }
    }
}

/// One dictation: its time and dot in the gutter, then the app, the words, the details and the buttons.
struct HomeActivityRowView: View {
    let row: HomeActivityRow
    var onIntent: (MainIntent) -> Void

    /// The gutter the time and the dot sit in, and where the rail's line runs down it.
    static let gutter: CGFloat = 70
    static let lineOffset: CGFloat = 52

    var body: some View {
        HStack(spacing: 0) {
            gutter
            card
        }
    }

    private var gutter: some View {
        ZStack(alignment: .leading) {
            Text(row.time)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(PagePalette.quiet)
                .lineLimit(1)
            Circle()
                .fill(tone)
                .frame(width: 11, height: 11)
                .background(Circle().fill(PagePalette.dotRing).padding(-3))
                .shadow(color: tone.opacity(0.8), radius: 5)
                .padding(.leading, Self.lineOffset - 4.5)
                .accessibilityHidden(true)
        }
        .frame(width: Self.gutter, alignment: .leading)
    }

    private var card: some View {
        HStack(spacing: 14) {
            icon
            VStack(alignment: .leading, spacing: 3) {
                Text(row.text)
                    .font(.system(size: 14))
                    .foregroundStyle(PagePalette.text)
                    .lineLimit(1)
                    .truncationMode(.tail)
                details
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Button(row.view.title) { onIntent(row.view.intent) }
                .buttonStyle(HomeQuietButtonStyle())
            more
        }
        .padding(.horizontal, 14)
        .frame(height: 56)
        .background(PagePalette.card, in: .rect(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(PagePalette.cardEdge, lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
    }

    /// The app's own icon where this Mac has it, a neutral tile otherwise.
    @ViewBuilder private var icon: some View {
        if let application = row.application {
            MainApplicationTile(application: application, size: 38)
        } else {
            Image(systemName: "text.bubble")
                .font(.system(size: 16))
                .foregroundStyle(PagePalette.soft)
                .frame(width: 38, height: 38)
                .background(PagePalette.controlFill, in: .rect(cornerRadius: 10, style: .continuous))
                .accessibilityHidden(true)
        }
    }

    /// App · words · tag, the tag in the colour of what the clean-up did.
    private var details: some View {
        HStack(spacing: 10) {
            ForEach(Array(row.details.enumerated()), id: \.offset) { index, part in
                if index > 0 { Text("·") }
                Text(part)
                    .foregroundStyle(isTag(index) ? tone : PagePalette.quiet)
            }
        }
        .font(.system(size: 12))
        .foregroundStyle(PagePalette.quiet)
        .lineLimit(1)
    }

    /// Whether a detail is the tag, which is always last when there is one.
    private func isTag(_ index: Int) -> Bool {
        row.tag != nil && index == row.details.count - 1
    }

    private var more: some View {
        Menu {
            ForEach(row.more) { action in
                Button(action.title, role: action.isDestructive ? .destructive : nil) {
                    onIntent(action.intent)
                }
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 15, weight: .medium))
        }
        .menuStyle(.button)
        .buttonStyle(HomeQuietButtonStyle(isSquare: true))
        .menuIndicator(.hidden)
        .fixedSize()
        .accessibilityLabel("More")
    }

    private var tone: Color {
        switch row.tone {
        case .asDictated: PagePalette.dictation
        case .changed: PagePalette.suggestion
        case .unmeasured: PagePalette.info
        }
    }
}

/// The View and ⋯ buttons: a faint fill, a hairline edge, and a little more fill when pressed.
struct HomeQuietButtonStyle: ButtonStyle {
    var isSquare = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(PagePalette.text)
            .padding(.horizontal, isSquare ? 0 : 18)
            .frame(width: isSquare ? 34 : nil, height: isSquare ? 34 : 30)
            .background {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(PagePalette.controlFill.opacity(configuration.isPressed ? 2 : 1))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(PagePalette.controlEdge, lineWidth: 1)
            }
            .contentShape(.rect)
    }
}
