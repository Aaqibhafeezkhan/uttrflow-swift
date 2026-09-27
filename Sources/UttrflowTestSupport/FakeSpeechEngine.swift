// A SpeechEngine that answers as scripted.
public import UttrflowCore

/// A ``SpeechEngine`` that returns a scripted transcription.
public actor FakeSpeechEngine: SpeechEngine {
    public struct TranscribeCall: Sendable, Equatable {
        public let audio: AudioSamples
        public let options: TranscriptionOptions
    }

    public let kind: SpeechEngineKind
    public let prepareCalls = CallLog<Void>()
    public let warmCalls = CallLog<Void>()
    public let transcribeCalls = CallLog<TranscribeCall>()

    private var prepareOutcome: ScriptedOutcome<Void, SpeechEngineError>
    private var transcribeOutcome: ScriptedOutcome<Transcription, SpeechEngineError>
    /// Whether `prepare()` blocks until ``finishHungLoads()``, ignoring cancellation, as a stuck model load does.
    private var prepareHangs: Bool
    private var hungLoads: [CheckedContinuation<Void, Never>] = []

    public init(
        kind: SpeechEngineKind = .whisperKit,
        prepareOutcome: ScriptedOutcome<Void, SpeechEngineError> = .ok,
        transcribeOutcome: ScriptedOutcome<Transcription, SpeechEngineError> = .success(.fixture()),
        prepareHangs: Bool = false
    ) {
        self.kind = kind
        self.prepareOutcome = prepareOutcome
        self.transcribeOutcome = transcribeOutcome
        self.prepareHangs = prepareHangs
    }

    public func prepare() async throws(SpeechEngineError) {
        await prepareCalls.append(())
        if prepareHangs {
            await withCheckedContinuation { hungLoads.append($0) }
        }
        try prepareOutcome.resolve()
    }

    /// Lets every hung `prepare()` finish with the scripted outcome, and later ones return at once.
    public func finishHungLoads() {
        prepareHangs = false
        let waiting = hungLoads
        hungLoads = []
        waiting.forEach { $0.resume() }
    }

    public func warm() async {
        await warmCalls.append(())
    }

    public func transcribe(
        _ audio: AudioSamples,
        options: TranscriptionOptions
    ) async throws(SpeechEngineError) -> Transcription {
        await transcribeCalls.append(.init(audio: audio, options: options))
        return try transcribeOutcome.resolve()
    }

    // MARK: Scripting

    public func setPrepareOutcome(_ outcome: ScriptedOutcome<Void, SpeechEngineError>) {
        prepareOutcome = outcome
    }

    public func setTranscribeOutcome(_ outcome: ScriptedOutcome<Transcription, SpeechEngineError>) {
        transcribeOutcome = outcome
    }
}
