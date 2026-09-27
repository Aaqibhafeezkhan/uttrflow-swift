// The popover's progress bar: the track in the glass, and the fill drawn above it.

import AppKit
import SwiftUI
import UttrflowUX

/// A thin bar's track; its fill is drawn above the glass by ``MenuBarProgressFill``.
struct MenuBarProgressBar: View {
    let progress: MenuBarProgress

    var body: some View {
        Capsule().fill(MenuBarColour.track)
            .frame(height: 3)
            .anchorPreference(key: MenuBarProgressSlot.Key.self, value: .bounds) {
                MenuBarProgressSlot(progress: progress, bounds: $0)
            }
            .accessibilityHidden(true)
    }
}

/// Where the progress track sits and what it shows, handed up to the popover.
struct MenuBarProgressSlot {
    let progress: MenuBarProgress
    let bounds: Anchor<CGRect>

    /// The one track in the popover, if it has one.
    struct Key: PreferenceKey {
        static var defaultValue: MenuBarProgressSlot? { nil }
        static func reduce(value: inout MenuBarProgressSlot?, nextValue: () -> MenuBarProgressSlot?) {
            value = value ?? nextValue()
        }
    }
}

/// The teal fill of a track `width` wide: filled to a fraction, or a short run sliding across when it is unknown.
struct MenuBarProgressFill: View {
    let progress: MenuBarProgress
    let width: CGFloat

    var body: some View {
        let motion = MotionBudgetObserver.shared.budget
        ZStack(alignment: .leading) {
            switch progress {
            case .fraction(let fraction):
                // Eases between ticks, and only steps under Reduce Motion.
                Capsule().fill(MenuBarColour.progress).frame(width: width * fraction)
                    .animation(motion.workingBarsMove ? .linear(duration: 1) : nil, value: fraction)
            case .indeterminate:
                // Held still under Reduce Motion, Low Power Mode and thermal pressure.
                MenuBarSlidingRun(moves: motion.demonstrationMoves)
            }
        }
        .frame(width: width, alignment: .leading)
        .clipShape(Capsule())
    }
}

/// A run a third of the track long, sliding across and round again while the motion budget allows.
struct MenuBarSlidingRun: NSViewRepresentable {
    /// Whether the run moves; still, it waits off the track's leading end.
    let moves: Bool

    func makeNSView(context: Context) -> MenuBarSlidingRunView { MenuBarSlidingRunView() }

    func updateNSView(_ view: MenuBarSlidingRunView, context: Context) {
        view.moves = moves
    }
}
