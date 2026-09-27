// Tests what a dictation tried while the speech model loads is answered with.
import Testing

@testable import UttrflowCore
@testable import UttrflowPipeline
@testable import UttrflowTestSupport

// MARK: - Doubles

/// Holds the model's load open until the test lets it finish.
private actor LoadGate {
    private var isOpen = false
    private var wasReached = false
    private var held: [CheckedContinuation<Void, Never>] = []
    private var watchers: [CheckedContinuation<Void, Never>] = []

    /// Called from the load: suspends there until the test opens the gate.
    func pass() async {
        wasReached = true
        for watcher in watchers { watcher.resume() }
        watchers.removeAll()
        guard !isOpen else { return }
        await withCheckedContinuation { held.append($0) }
    }

    /// Returns once the load is actually waiting at the gate.
    func waitUntilReached() async {
        guard !wasReached else { return }
        await withCheckedContinuation { watchers.append($0) }
    }

    func open() {
        isOpen = true
        for continuation in held { continuation.resume() }
        held.removeAll()
    }
}

/// A recogniser whose load takes as long as the test says, and may fail at the end of it.
private final class SlowLoadingSpeechEngine: SpeechEngine, Sendable {
    let kind: SpeechEngineKind = .whisperKit
    private let gate: LoadGate
    private let failure: SpeechEngineError?

    init(gate: LoadGate, failure: SpeechEngineError? = nil) {
        self.gate = gate
        self.failure = failure
    }

    func prepare() async throws(SpeechEngineError) {
        await gate.pass()
        if let failure { throw failure }
    }

    func transcribe(
        _ audio: AudioSamples, options: TranscriptionOptions
    ) async throws(SpeechEngineError) -> Transcription {
        .fixture(text: "Loaded and listening.")
    }
}

/// A tidier that hands the words back as they came.
private struct PassThroughCleaner: TranscriptCleaning {
    func clean(
        _ request: TransformationRequest
    ) async throws(TransformationError) -> TransformationResult {
        TransformationResult(text: request.transcription.text, producedBy: .rules)
    }
}

/// An inserter that always lands.
private struct LandingInserter: TextInserting {
    func insert(_ text: String) async throws(TextInsertionError) -> InsertionAttempt {
        InsertionAttempt(.accessibility)
    }
}

private func makePipeline(
    speech: any SpeechEngine, capture: FakeAudioCaptureEngine
) -> DictationPipeline {
    DictationPipeline(
        capture: capture, speech: speech, cleaner: PassThroughCleaner(),
        context: FakeContextEngine(context: .fixture()), inserter: LandingInserter(),
        metrics: RecordingMetricsRecorder(), clock: ManualClock())
}

/// The notice a refused attempt leaves, spelled out so the words on screen are pinned here.
private let refusal = DictationFailure(
    message: "Speech model still loading…", recovery: nil, severity: .informational)

// MARK: - Tests

@Suite("Dictating while the speech model loads")
struct DictationPipelineLoadingTests {
    @Test("says the model is still loading and never opens the microphone")
    func attemptDuringLoadIsRefused() async {
        let gate = LoadGate()
        let capture = FakeAudioCaptureEngine()
        let pipeline = makePipeline(speech: SlowLoadingSpeechEngine(gate: gate), capture: capture)
        let loading = Task { await pipeline.prepare() }
        await gate.waitUntilReached()

        await pipeline.startRecording()

        #expect(await pipeline.currentState == .failed(refusal))
        #expect(await capture.calls.isEmpty, "a recording that waits minutes for its words is not started")
        await gate.open()
        await loading.value
    }

    @Test("clears the notice when the load finishes, and then dictates as before")
    func loadFinishingRestoresDictation() async {
        let gate = LoadGate()
        let capture = FakeAudioCaptureEngine()
        let pipeline = makePipeline(speech: SlowLoadingSpeechEngine(gate: gate), capture: capture)
        let loading = Task { await pipeline.prepare() }
        await gate.waitUntilReached()
        await pipeline.startRecording()

        await gate.open()
        await loading.value

        #expect(await pipeline.currentState == .idle)
        #expect(await pipeline.isReady)
        #expect(await !pipeline.isLoading)
        await pipeline.startRecording()
        #expect(await pipeline.currentState == .recording)
        #expect(await capture.calls.events == [.start])
    }

    @Test("a load that fails is not left loading, and says so")
    func failedLoadIsNotLoading() async {
        let gate = LoadGate()
        await gate.open()
        let failure = SpeechEngineError.modelLoadFailed(description: "fixture")
        let pipeline = makePipeline(
            speech: SlowLoadingSpeechEngine(gate: gate, failure: failure),
            capture: FakeAudioCaptureEngine())

        await pipeline.prepare()

        #expect(await !pipeline.isLoading)
        #expect(await !pipeline.isReady)
        #expect(await pipeline.currentState == .failed(DictationFailure(failure)))
    }

    @Test("a pipeline nobody prepared dictates at once, loading on demand as before")
    func unpreparedPipelineIsNotRefused() async {
        let capture = FakeAudioCaptureEngine()
        let pipeline = makePipeline(speech: FakeSpeechEngine(), capture: capture)

        await pipeline.startRecording()

        #expect(await pipeline.currentState == .recording)
    }

    @Test("the refusal is the shared notice, informational and with nothing to press")
    func refusalIsTheSharedNotice() {
        #expect(DictationFailure.stillLoading == refusal)
        #expect(DictationFailure.stillLoading.message == SpeechModelLoad.refusal)
    }
}

@Suite("A speech model load that never returns", .timeLimit(.minutes(1)))
struct DictationPipelineLoadDeadlineTests {
    private func makePipeline(speech: FakeSpeechEngine, clock: ManualClock) -> DictationPipeline {
        DictationPipeline(
            capture: FakeAudioCaptureEngine(), speech: speech, cleaner: PassThroughCleaner(),
            context: FakeContextEngine(context: .fixture()), inserter: LandingInserter(),
            clock: clock, speechLoadLimit: .seconds(300))
    }

    @Test("fails with the retry once the limit passes, and is no longer loading")
    func stuckLoadFailsAtTheLimit() async {
        let clock = ManualClock()
        let speech = FakeSpeechEngine(prepareHangs: true)
        let pipeline = makePipeline(speech: speech, clock: clock)

        let loading = Task { await pipeline.prepare() }
        await clock.advanceWhenSomethingIsWaiting(by: .seconds(300))
        await loading.value

        #expect(await !pipeline.isLoading)
        #expect(await !pipeline.isReady)
        guard case .failed(let failure) = await pipeline.currentState else {
            Issue.record("a stuck load was not reported as failed")
            return
        }
        #expect(failure.recovery == .retry)
        await speech.finishHungLoads()
    }

    @Test("a retry after the stuck load finally ends loads as usual")
    func retryAfterTheStuckLoadEnds() async {
        let clock = ManualClock()
        let speech = FakeSpeechEngine(prepareHangs: true)
        let pipeline = makePipeline(speech: speech, clock: clock)
        let loading = Task { await pipeline.prepare() }
        await clock.advanceWhenSomethingIsWaiting(by: .seconds(300))
        await loading.value

        await speech.finishHungLoads()
        await pipeline.prepare()

        #expect(await pipeline.isReady)
        #expect(await pipeline.currentState == .idle)
    }

    @Test("a load inside the limit is not cut short")
    func loadInsideTheLimitSucceeds() async {
        let pipeline = makePipeline(speech: FakeSpeechEngine(), clock: ManualClock())

        await pipeline.prepare()

        #expect(await pipeline.isReady)
        #expect(await !pipeline.isLoading)
    }
}
