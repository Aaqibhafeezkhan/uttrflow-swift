// Tests for the clock on the floating button.

import Foundation
import UttrflowCore
import UttrflowPipeline
import Testing

@testable import Uttrflow

/// The window stamps when a recording started; the two failures are a restarting clock and a lingering one.
@MainActor
@Suite("The clock on the floating button")
struct DockClockTests {
    private func model() -> DockViewModel {
        DockViewModel(
            presentation: DictationPresenter.dock(for: .idle), shortcut: "⌥Space",
            anchor: .bottomRight)
    }

    private let start = Date(timeIntervalSinceReferenceDate: 700_000_000)

    @Test("has no clock until something is being recorded")
    func idleHasNoClock() {
        let dock = model()

        dock.show(DictationPresenter.dock(for: .idle), now: start)

        #expect(dock.recordingStartedAt == nil)
    }

    @Test("starts when the recording does")
    func startsWithTheRecording() {
        let dock = model()

        dock.show(DictationPresenter.dock(for: .recording), now: start)

        #expect(dock.recordingStartedAt == start)
    }

    /// Identical recording presentations arrive while the key is held and must not restart the clock.
    @Test("does not restart while the recording continues")
    func survivesRepeatedPresentations() {
        let dock = model()

        dock.show(DictationPresenter.dock(for: .recording), now: start)
        dock.show(DictationPresenter.dock(for: .recording), now: start.addingTimeInterval(3))
        dock.show(DictationPresenter.dock(for: .recording), now: start.addingTimeInterval(9))

        #expect(dock.recordingStartedAt == start)
    }

    /// A clock still counting on a finished button claims the microphone is open.
    @Test("stops the moment the recording does")
    func clearedWhenItEnds() {
        let dock = model()

        dock.show(DictationPresenter.dock(for: .recording), now: start)
        dock.show(DictationPresenter.dock(for: .transcribing), now: start.addingTimeInterval(5))

        #expect(dock.recordingStartedAt == nil)
    }

    /// A second dictation is a second clock, not a continuation of the first.
    @Test("the next recording starts a new clock")
    func nextRecordingRestarts() {
        let dock = model()
        let later = start.addingTimeInterval(120)

        dock.show(DictationPresenter.dock(for: .recording), now: start)
        dock.show(DictationPresenter.dock(for: .idle), now: start.addingTimeInterval(6))
        dock.show(DictationPresenter.dock(for: .recording), now: later)

        #expect(dock.recordingStartedAt == later)
    }

    @Test("reads the time since the key went down as minutes and seconds")
    func readsElapsed() {
        let recording = DictationPresenter.dock(for: .recording)

        #expect(DockView.clockText(for: recording, startedAt: start, now: start) == "0:00")
        #expect(
            DockView.clockText(for: recording, startedAt: start, now: start.addingTimeInterval(4.6))
                == "0:04")
        #expect(
            DockView.clockText(for: recording, startedAt: start, now: start.addingTimeInterval(83))
                == "1:23")
    }

    /// A clock stamped a moment after the frame it is drawn in must not read as negative.
    @Test("never counts below zero, and reads zero before a start is stamped")
    func neverNegative() {
        let recording = DictationPresenter.dock(for: .recording)

        #expect(
            DockView.clockText(for: recording, startedAt: start, now: start.addingTimeInterval(-2))
                == "0:00")
        #expect(DockView.clockText(for: recording, startedAt: nil, now: start) == "0:00")
    }

    /// Near the cap the time left matters more than the time spent, so it takes the clock's place.
    @Test("gives way to the countdown once the cap is near")
    func countdownWins() {
        let nearCap = DictationPresenter.dock(
            for: .recording, advice: .approaching(remaining: .seconds(25)))

        #expect(
            DockView.clockText(for: nearCap, startedAt: start, now: start.addingTimeInterval(275))
                == "30 sec left")
    }
}
