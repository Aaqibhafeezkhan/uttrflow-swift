// How much decorative motion the Mac allows now, from Reduce Motion, Low Power Mode and thermal pressure.

import AppKit
import SwiftUI
import UttrflowCore

/// What the system asks of the app's animations at one moment, and the frame rates that follow. See `Docs/performance.md`.
struct MotionBudget: Equatable {
    /// Whether Reduce Motion is on in the Accessibility settings.
    var reducesMotion: Bool

    /// Low Power Mode and thermal pressure, as `EnergyConditions` reads them.
    var energy: EnergyConditions

    init(reducesMotion: Bool = false, energy: EnergyConditions = EnergyConditions()) {
        self.reducesMotion = reducesMotion
        self.energy = energy
    }

    /// The home demonstration's shortest gap between frames while it moves: 30 a second, not the display's rate.
    static let demonstrationFrameInterval: TimeInterval = 1.0 / 30

    /// The dock's shortest gap between frames on a Mac that asks for nothing less.
    static let fullDockFrameInterval: TimeInterval = 1.0 / 60

    /// The dock's shortest gap between frames when the Mac asks for less: the meter's own 20 Hz data rate.
    static let reducedDockFrameInterval: TimeInterval = DockMetrics.meterArrivalInterval

    /// Whether the home demonstration moves: not under Reduce Motion, Low Power Mode or serious thermal pressure.
    var demonstrationMoves: Bool {
        !reducesMotion && energy.allowsDiscretionaryWork
    }

    /// Whether the working bars rise and settle; Reduce Motion holds them still.
    var workingBarsMove: Bool {
        !reducesMotion
    }

    /// `animation` for a one-off move, or none under Reduce Motion, so the change lands in place.
    func allowing(_ animation: Animation) -> Animation? {
        reducesMotion ? nil : animation
    }

    /// The dock timelines' shortest gap between frames, longer in Low Power Mode or under thermal pressure.
    var dockFrameInterval: TimeInterval {
        energy.allowsDiscretionaryWork ? Self.fullDockFrameInterval : Self.reducedDockFrameInterval
    }

    /// What this process reads from the system right now.
    @MainActor
    static func current() -> MotionBudget {
        MotionBudget(
            reducesMotion: NSWorkspace.shared.accessibilityDisplayShouldReduceMotion,
            energy: .current())
    }

    /// Every notice after which `current()` may answer differently, with the centre that posts it.
    @MainActor
    static var changeNotices: [(centre: NotificationCenter, name: Notification.Name)] {
        [
            (.default, .NSProcessInfoPowerStateDidChange),
            (.default, ProcessInfo.thermalStateDidChangeNotification),
            (
                NSWorkspace.shared.notificationCenter,
                NSWorkspace.accessibilityDisplayOptionsDidChangeNotification
            ),
        ]
    }
}
