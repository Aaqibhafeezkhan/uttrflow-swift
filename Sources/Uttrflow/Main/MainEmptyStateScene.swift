// The small pictures an empty page draws above its title, and the pieces around them.

import UttrflowUX
import SwiftUI

extension EnvironmentValues {
    /// The dictation shortcut's keys, which the dictation scene draws as keycaps; empty draws the waveform alone.
    @Entry var dictationKeycaps: [String] = []
}

extension MainAccent {
    /// The page colour an accent names.
    var color: Color {
        switch self {
        case .dictation: PagePalette.dictation
        case .suggestion: PagePalette.suggestion
        case .clipboard: PagePalette.clipboard
        case .info: PagePalette.info
        }
    }
}

/// One scene: keycaps and a waveform, a word on a chip, day bars, or the state's own symbol.
struct MainEmptyStateScene: View {
    let scene: MainEmptyScene
    let symbolName: String
    let progress: MainProgress?

    @Environment(\.dictationKeycaps) private var keycaps

    private var accent: Color { scene.accent.color }

    var body: some View {
        Group {
            switch scene {
            case .dictation:
                HStack(spacing: 6) {
                    ForEach(Array(keycaps.enumerated()), id: \.offset) { MainKeycap(label: $0.element) }
                    MainEmptyWaveform(color: accent)
                        .frame(width: 22 * 6 - 3, height: 30)
                        .padding(.leading, keycaps.isEmpty ? 0 : 10)
                }
            case .word(let text), .phrase(let text):
                Text(text)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(PagePalette.text)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(accent.opacity(0.16), in: .rect(cornerRadius: 12, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(accent.opacity(0.35), lineWidth: 1)
                    }
            case .chart:
                MainEmptyDayBars(progress: progress, color: accent)
            case .symbol:
                MainTintedTile(symbolName: symbolName, color: accent, size: 56)
            }
        }
        .accessibilityHidden(true)
    }
}

/// One key of the shortcut, raised off the page.
struct MainKeycap: View {
    let label: String

    var body: some View {
        Text(label)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(PagePalette.text)
            .padding(.horizontal, 8)
            .frame(minWidth: 26, minHeight: 26)
            .background {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [PagePalette.text.opacity(0.2), PagePalette.text.opacity(0.06)],
                            startPoint: .top, endPoint: .bottom)
                    )
                    .shadow(color: PagePalette.floatShadow, radius: 0, y: 2)
            }
            .overlay(alignment: .top) {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .strokeBorder(PagePalette.text.opacity(0.22), lineWidth: 0.5)
                    .mask(LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .center))
            }
    }
}

/// A still waveform of 22 bars in the page's colour, tallest in the middle.
struct MainEmptyWaveform: View {
    let color: Color

    /// How many bars are drawn.
    static let count = 22

    var body: some View {
        Canvas { context, size in
            let width: CGFloat = 3
            let gap = (size.width - width * CGFloat(Self.count)) / CGFloat(Self.count - 1)
            for index in 0..<Self.count {
                let height = size.height * Self.height(index)
                let rect = CGRect(
                    x: CGFloat(index) * (width + gap), y: (size.height - height) / 2, width: width,
                    height: height)
                context.fill(Path(roundedRect: rect, cornerRadius: 1.5), with: .color(color))
            }
        }
    }

    /// One bar's height as a share of the row: a rippled arch, never shorter than a fifth.
    static func height(_ index: Int) -> Double {
        let ripple = abs(sin(Double(index) * 1.3))
        let arch = sin(Double.pi * (Double(index) + 0.5) / Double(count))
        return (20 + 80 * ripple * arch) / 100
    }
}

/// A bar per day to wait for, filled for the days already spoken on.
struct MainEmptyDayBars: View {
    let progress: MainProgress?
    let color: Color

    /// The heights, in steps of nine points, a spoken day's bar is drawn at, in turn.
    private static let heights: [CGFloat] = [3, 5, 2, 4, 3, 5, 2]

    var body: some View {
        let days = progress?.steps ?? 5
        let done = progress?.stepsDone ?? 0
        HStack(alignment: .bottom, spacing: 5) {
            ForEach(0..<days, id: \.self) { day in
                UnevenRoundedRectangle(topLeadingRadius: 3, topTrailingRadius: 3)
                    .fill(day < done ? color : PagePalette.ringTrack)
                    .frame(width: 14, height: day < done ? Self.heights[day % Self.heights.count] * 9 : 4)
            }
        }
        .frame(height: 50, alignment: .bottom)
    }
}

/// How far off the page is, as one segment per step, with the two lines that explain it.
struct MainEmptyStateSteps: View {
    let progress: MainProgress
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            if let steps = progress.steps {
                HStack(spacing: 6) {
                    ForEach(0..<steps, id: \.self) { step in
                        Capsule()
                            .fill(step < progress.stepsDone ? color : PagePalette.ringTrack)
                            .frame(width: 34, height: 6)
                    }
                }
            } else {
                MainBar(fraction: progress.fraction, fill: color, height: 6).frame(width: 220)
            }
            Text("\(progress.leading) · \(progress.trailing)")
                .font(.system(size: MainMetrics.footnoteSize))
                .foregroundStyle(PagePalette.quiet)
        }
        .padding(.top, 2)
        .accessibilityElement(children: .combine)
    }
}

/// The empty page's one way on: a solid pill that glows in the page's colour.
struct MainEmptyStateButton: View {
    let action: MainAction
    let glow: Color
    var onIntent: (MainIntent) -> Void

    var body: some View {
        Button {
            onIntent(action.intent)
        } label: {
            HStack(spacing: 7) {
                if let symbol = action.symbolName {
                    Image(systemName: symbol).font(.system(size: 12, weight: .semibold))
                }
                Text(action.title)
            }
        }
        .buttonStyle(MainPrimaryButtonStyle(isDestructive: action.isDestructive))
        .shadow(color: glow.opacity(0.55), radius: 10, y: 8)
    }
}
