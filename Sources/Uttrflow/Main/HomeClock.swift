// Redraws home when the clock crosses a mood boundary or midnight, only while the main window is in sight.

import AppKit
import UttrflowUX

/// Keeps home's picture, greeting and date line in step with the clock, with one timer set for the next boundary.
@MainActor
final class HomeClock {
    /// The next boundary after home was last drawn; `nil` when a time change makes the last drawing suspect.
    private(set) var due: Date?
    /// Whether the main window is in sight, which is the only time the timer runs.
    private(set) var isRunning = false
    /// When the timer fires, or `nil` while none is set.
    var nextFire: Date? { timer?.fireDate }

    private let calendar: Calendar
    private let now: () -> Date
    private let redraw: () -> Void
    private var timer: Timer?
    private var observers: [(center: NotificationCenter, token: any NSObjectProtocol)] = []

    init(
        calendar: Calendar = .autoupdatingCurrent,
        center: NotificationCenter = .default,
        workspaceCenter: NotificationCenter = NSWorkspace.shared.notificationCenter,
        now: @escaping () -> Date = Date.init,
        redraw: @escaping () -> Void
    ) {
        self.calendar = calendar
        self.now = now
        self.redraw = redraw
        let changes: [(NotificationCenter, Notification.Name)] = [
            (workspaceCenter, NSWorkspace.didWakeNotification),
            (center, .NSSystemClockDidChange),
            (center, .NSSystemTimeZoneDidChange),
            (center, .NSCalendarDayChanged),
        ]
        observers = changes.map { center, name in
            let token = center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.timeChanged() }
            }
            return (center, token)
        }
    }

    isolated deinit {
        timer?.invalidate()
        for observer in observers { observer.center.removeObserver(observer.token) }
    }

    /// Notes that home was drawn at `date`, and sets the timer for the boundary after it.
    func drew(at date: Date) {
        if let due, date < due {
            if timer == nil { schedule() }
            return
        }
        due = HomeMood.nextBoundary(after: date, calendar: calendar)
        schedule()
    }

    /// Starts the timer when the window comes into sight, redrawing first if a boundary passed out of sight.
    func setVisible(_ visible: Bool) {
        guard visible != isRunning else { return }
        isRunning = visible
        guard visible else {
            cancel()
            return
        }
        if let due, now() < due {
            schedule()
        } else {
            tick()
        }
    }

    /// Redraws home and waits for the next boundary.
    func tick() {
        cancel()
        let date = now()
        redraw()
        drew(at: date)
    }

    /// Redraws at once after a wake or a clock change, or on next sight if the window is hidden.
    private func timeChanged() {
        due = nil
        if isRunning { tick() }
    }

    private func schedule() {
        cancel()
        guard isRunning, let due else { return }
        let timer = Timer(fire: due, interval: 0, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        timer.tolerance = 1
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func cancel() {
        timer?.invalidate()
        timer = nil
    }
}
