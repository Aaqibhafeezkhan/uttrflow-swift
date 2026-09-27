// Tests for UsageTelemetry: what a finished dictation adds, the switch, and the flushes.

import Foundation
import Testing
import UttrflowAccount
import UttrflowCore
import UttrflowPipeline

@testable import Uttrflow

/// Drives the app's telemetry with states a pipeline would send, and a sender that keeps reports.
@MainActor
@Suite("Usage telemetry in the app")
struct UsageTelemetryTests {
    /// A dictation that inserted `text` after speaking for `spoken`.
    private func inserted(_ text: String, spoken: Duration) -> DictationState {
        .inserted(
            UttrflowPipeline.DictationOutcome(
                text: text, method: .accessibility, cleanedBy: .foundationModels, spokenFor: spoken))
    }

    @Test("reads a calendar version as three numbers, and anything else as zeros")
    func readsTheVersion() {
        #expect(UsageTelemetry.appVersion(from: "26.0926.0") == .init(major: 26, minor: 926, patch: 0))
        #expect(UsageTelemetry.appVersion(from: "26.0926") == .init(major: 0, minor: 0, patch: 0))
        #expect(UsageTelemetry.appVersion(from: nil) == .init(major: 0, minor: 0, patch: 0))
        #expect(UsageTelemetry.appVersion(from: "a.b.c") == .init(major: 0, minor: 0, patch: 0))
    }

    @Test("counts finished and failed dictations with the wait since listening stopped, and sends them")
    func countsAndSends() async throws {
        let sender = RecordingTelemetrySender()
        let usage = UsageTelemetry(
            isEnabled: true, sender: sender, version: "26.926.0", now: Date(timeIntervalSinceNow: -60))
        let start = ContinuousClock.now
        let english = LanguageCode("en")

        usage.observe(.recording, language: english, at: start)
        usage.observe(.transcribing, language: english, at: start)
        usage.observe(.tidying, language: english, at: start + .milliseconds(100))
        usage.observe(
            inserted("Hello there.", spoken: .seconds(2)), language: english,
            at: start + .milliseconds(400))
        usage.observe(.transcribing, language: nil, at: start)
        usage.observe(
            .failed(DictationFailure(message: "no", recovery: nil, severity: .degraded)), language: nil,
            at: start)
        await usage.flushBeforeQuitting()

        let report = try #require(sender.reports.first)
        #expect(report.dictationCount == 2)
        #expect(report.failureCount == 1)
        #expect(report.charactersInserted == 12)
        #expect(report.audioTotalMs == 2000)
        #expect(report.latencyP50Ms == 400)
        #expect(report.languages.map(\.language).sorted { $0.rawValue < $1.rawValue } == [.english, .other])
    }

    @Test("switching off drops what was collected, and nothing is sent")
    func switchingOffDropsEverything() async {
        let sender = RecordingTelemetrySender()
        let usage = UsageTelemetry(
            isEnabled: true, sender: sender, version: "26.926.0", now: Date(timeIntervalSinceNow: -60))
        usage.observe(inserted("Hi.", spoken: .seconds(1)), language: nil)

        usage.setEnabled(false)
        usage.setEnabled(false)
        await usage.flushBeforeQuitting()

        #expect(!usage.service.isEnabled)
        #expect(sender.reports.isEmpty)
    }

    @Test("the timer flushes on its own")
    func theTimerFlushes() async throws {
        let sender = RecordingTelemetrySender()
        let usage = UsageTelemetry(
            isEnabled: true, sender: sender, version: "26.926.0", now: Date(timeIntervalSinceNow: -60))
        usage.observe(.idle, language: nil)
        usage.observe(inserted("Hi.", spoken: .seconds(1)), language: nil)
        #expect(usage.recorder is TelemetryCollector)

        usage.start(every: .milliseconds(10))
        for _ in 0..<200 where sender.reports.isEmpty { try await Task.sleep(for: .milliseconds(10)) }
        await usage.flushBeforeQuitting()
        #expect(sender.reports.count == 1)
    }
}
