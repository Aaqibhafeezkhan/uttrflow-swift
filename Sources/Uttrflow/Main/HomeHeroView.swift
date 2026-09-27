// Home's hero card: the headline, the three features, the waveform, the start pill and the mood picture.

import UttrflowUX
import AppKit
import SwiftUI

/// The card across the top of home, with the picture for the time of day fading in from its right.
struct HomeHeroCard: View {
    let hero: HomeHero
    let mood: HomeMood
    var onIntent: (MainIntent) -> Void

    @Environment(\.colorScheme) private var colorScheme

    /// The hero's fixed height and the width its words and waveform take.
    static let height: CGFloat = 282
    static let contentWidth: CGFloat = 470

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headline
            features
                .padding(.top, 6)
                .padding(.bottom, 20)
            if let status = hero.modelStatus {
                HomeModelStatusView(status: status)
                    .padding(.top, 4)
                if let action = status.action {
                    HomeModelActionButton(action: action, tone: status.actionTone, onIntent: onIntent)
                        .padding(.top, 18)
                } else {
                    startButton
                        .padding(.top, 22)
                }
            } else {
                HomeWaveform()
                    .frame(height: 56)
                startButton
                    .padding(.top, 22)
            }
        }
        .frame(maxWidth: Self.contentWidth, alignment: .leading)
        .padding(.horizontal, 40)
        .padding(.top, 36)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .frame(height: Self.height)
        .background(alignment: .trailing) { HomeMoodPicture(mood: mood) }
        .background { ground }
        .clipShape(.rect(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(PagePalette.dictation.opacity(0.28), lineWidth: 1)
        }
        // Cast by a plain shape underneath, so a moving bar in the card never re-renders the shadow.
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(PagePalette.hero)
                .shadow(
                    color: PagePalette.dictation.opacity(isDark ? 0.18 : 0.22), radius: isDark ? 20 : 14,
                    y: isDark ? 0 : 8)
        }
    }

    private var isDark: Bool { colorScheme == .dark }

    /// "Your voice, finished for you.", the second half in the three accents.
    private var headline: some View {
        let accents = LinearGradient(
            colors: [PagePalette.dictation, PagePalette.suggestion, PagePalette.clipboard],
            startPoint: .leading, endPoint: .trailing)
        return Text("\(hero.lead) \(Text(hero.emphasis).foregroundStyle(accents))")
            .font(BrandFont.display(size: 40, weight: .heavy))
            .tracking(-1.6)
            .foregroundStyle(PagePalette.text)
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(.isHeader)
    }

    /// The three features, each in its own accent, separated by dots.
    private var features: some View {
        HStack(spacing: 4) {
            ForEach(Array(hero.features.enumerated()), id: \.element) { index, feature in
                if index > 0 {
                    Text("·").foregroundStyle(PagePalette.soft)
                }
                Text(feature.title).foregroundStyle(Self.accent(for: feature))
            }
        }
        .font(BrandFont.display(size: 16, weight: .regular))
        .accessibilityElement(children: .combine)
    }

    /// Each feature's accent: teal for dictation, lilac for suggestions, amber for the clipboard.
    static func accent(for feature: HomeFeature) -> Color {
        switch feature {
        case .dictation: PagePalette.dictation
        case .suggestions: PagePalette.suggestion
        case .clipboard: PagePalette.clipboard
        }
    }

    /// The pill, drawn plain under a clear button and dimmed per colour rather than as a layer, so nothing clips its glow.
    private var startButton: some View {
        let dim = hero.canStart ? 1.0 : 0.4
        return HStack(spacing: 12) {
            Image(systemName: hero.start.symbolName ?? "mic")
                .font(.system(size: 16, weight: .medium))
            Text(hero.start.title)
                .font(.system(size: 15, weight: .medium))
            Image(systemName: "arrow.right")
                .font(.system(size: 13, weight: .semibold))
                .padding(.leading, 6)
        }
        .foregroundStyle(PagePalette.text.opacity(dim))
        .padding(.horizontal, 26)
        .padding(.vertical, 12)
        .background(PagePalette.dictation.opacity(0.08 * dim), in: Capsule(style: .circular))
        .overlay {
            if hero.canStart {
                PillGlow(
                    inner: PagePalette.suggestion, outer: PagePalette.dictation,
                    strength: isDark ? 1 : 0.55)
            }
        }
        // The teal rim, or a plain grey one while dimmed.
        .overlay {
            Capsule(style: .circular).strokeBorder(
                hero.canStart ? PagePalette.dictation : PagePalette.text.opacity(0.3 * dim), lineWidth: 1.5)
        }
        .accessibilityHidden(true)
        .overlay {
            Button {
                onIntent(hero.start.intent)
            } label: {
                Capsule(style: .circular).fill(.clear).contentShape(Capsule(style: .circular))
            }
            .buttonStyle(.plain)
            .disabled(!hero.canStart)
            .accessibilityLabel(hero.start.title)
        }
        .help(hero.canStart ? "Start or stop a dictation" : "Uttrflow cannot listen yet")
    }

    /// The card's ground with a blue glow behind the picture and a violet one rising at the lower left.
    private var ground: some View {
        PagePalette.hero
            .overlay {
                EllipticalGradient(
                    colors: [PagePalette.glowBlue.opacity(isDark ? 0.28 : 0.14), .clear],
                    center: UnitPoint(x: 0.8, y: 0.5), startRadiusFraction: 0, endRadiusFraction: 0.6)
            }
            .overlay {
                EllipticalGradient(
                    colors: [PagePalette.glowViolet.opacity(isDark ? 0.2 : 0.12), .clear],
                    center: UnitPoint(x: 0.1, y: 1), startRadiusFraction: 0, endRadiusFraction: 0.55)
            }
            .accessibilityHidden(true)
    }
}

/// The speech model's state where the waveform would be: a dot and a title, the line under it, and the bar while setup runs.
struct HomeModelStatusView: View {
    let status: HomeModelStatus

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Circle()
                    .fill(HomeModelPalette.accent(for: status.tone))
                    .frame(width: 8, height: 8)
                Text(status.title)
                    .font(.system(size: 15, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(PagePalette.text)
            }
            Text(status.subtitle)
                .font(.system(size: 13))
                .foregroundStyle(PagePalette.quiet)
                .padding(.top, 4)
                .padding(.leading, 18)
            if let progress = status.progress {
                HomeModelBar(progress: progress)
                    .padding(.top, 10)
                    .padding(.leading, 18)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(status.accessibilityLabel)
    }
}

/// The thin bar under the status: filled to a share, or a segment sliding across while nothing measures the wait.
struct HomeModelBar: View {
    let progress: HomeModelProgress

    /// The bar's width and height, and the sliding segment's share of the width.
    static let width: CGFloat = 300
    static let height: CGFloat = 4
    static let segment: CGFloat = 0.3
    /// How long the segment takes to cross.
    static let period: TimeInterval = 1.6

    /// When the bar appeared, so the segment starts from the left.
    @State private var began = Date.now

    /// Whether its window is the one being used; starts still so a window opened behind others never moves.
    @State private var attended = false

    var body: some View {
        ZStack(alignment: .leading) {
            Capsule().fill(PagePalette.ringTrack)
            switch progress {
            case .fraction(let fraction):
                // Eases between ticks, and only steps under Reduce Motion.
                Capsule()
                    .fill(Self.fill)
                    .frame(width: Self.width * fraction)
                    .animation(
                        MotionBudgetObserver.shared.budget.workingBarsMove ? .linear(duration: 1) : nil,
                        value: fraction)
            case .sliding:
                let motion = MotionBudgetObserver.shared.budget
                TimelineView(
                    .animation(minimumInterval: 1.0 / 30, paused: !attended || !motion.workingBarsMove)
                ) { timeline in
                    Capsule()
                        .fill(Self.fill)
                        .frame(width: Self.width * Self.segment)
                        .offset(
                            x: motion.workingBarsMove
                                ? Self.offset(at: timeline.date.timeIntervalSince(began)) : 0)
                }
                .onWindowAttentionChange(includingMotionBudget: false) { attended = $0 }
            }
        }
        .frame(width: Self.width, height: Self.height)
        .clipShape(.capsule)
        .accessibilityHidden(true)
    }

    /// The dictation gradient, from the aurora's blue to teal.
    private static var fill: LinearGradient {
        LinearGradient(
            colors: [PagePalette.glowBlue, PagePalette.dictation], startPoint: .leading, endPoint: .trailing)
    }

    /// Where the sliding segment's left edge is after `elapsed`: from one length off the left to past the right, eased.
    static func offset(at elapsed: TimeInterval) -> CGFloat {
        let phase = elapsed.truncatingRemainder(dividingBy: period) / period
        let eased = (1 - cos(phase * .pi)) / 2
        let segment = width * self.segment
        return segment * (-1 + 4.4 * CGFloat(eased))
    }
}

/// The filled button in place of the start pill: amber to try loading again, teal to download.
struct HomeModelActionButton: View {
    let action: MainAction
    let tone: HomeModelTone
    var onIntent: (MainIntent) -> Void

    var body: some View {
        Button {
            onIntent(action.intent)
        } label: {
            Text(action.title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(HomeModelPalette.onAccent)
                .padding(.horizontal, 22)
                .padding(.vertical, 11)
                .background(HomeModelPalette.accent(for: tone), in: .capsule)
                .contentShape(.capsule)
        }
        .buttonStyle(.plain)
    }
}

/// The status block's colours.
enum HomeModelPalette {
    /// Words on a button filled with an accent.
    static let onAccent = Color(nsColor: .orbit(BrandPalette.Redesign.onAccentInk))

    /// Teal while setup runs, amber once it needs a hand.
    static func accent(for tone: HomeModelTone) -> Color {
        switch tone {
        case .dictation: PagePalette.dictation
        case .warning: PagePalette.clipboard
        }
    }
}

/// A still waveform of mono bars, tallest in the middle and fading at both ends.
struct HomeWaveform: View {
    /// How many bars are drawn.
    static let count = 64

    var body: some View {
        Canvas { context, size in
            let gap: CGFloat = 3
            let width = max(1, (size.width - gap * CGFloat(Self.count - 1)) / CGFloat(Self.count))
            for index in 0..<Self.count {
                let (height, opacity) = Self.bar(index)
                let barHeight = size.height * height
                let rect = CGRect(
                    x: CGFloat(index) * (width + gap), y: (size.height - barHeight) / 2,
                    width: width, height: barHeight)
                context.fill(
                    Path(roundedRect: rect, cornerRadius: min(2, width / 2)),
                    with: .color(PagePalette.waveform.opacity(opacity)))
            }
        }
        .mask {
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0), .init(color: .black, location: 0.12),
                    .init(color: .black, location: 0.88), .init(color: .clear, location: 1),
                ], startPoint: .leading, endPoint: .trailing)
        }
        .accessibilityHidden(true)
    }

    /// One bar's height as a share of the row and its opacity: a bell across the row, rippled.
    static func bar(_ index: Int) -> (height: Double, opacity: Double) {
        let position = Double(index) / Double(count - 1)
        let bell = exp(-pow(position - 0.5, 2) * 9)
        let ripple = 0.45 + 0.55 * abs(sin(Double(index) * 1.7))
        return ((10 + 90 * bell * ripple) / 100, 0.35 + 0.6 * bell)
    }
}
