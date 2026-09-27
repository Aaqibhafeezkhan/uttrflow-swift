import Foundation
import Synchronization
import Testing

@testable import UttrflowAI
@testable import UttrflowCore
@testable import UttrflowPipeline
@testable import UttrflowTestSupport

// MARK: - Doubles

/// A recogniser that reads out a scripted line per call, so a dictation's pieces are known in advance.
private actor SeamSpeechEngine: SpeechEngine {
    let kind = SpeechEngineKind.whisperKit
    private let lines: [String]
    private var calls = 0

    init(_ lines: [String]) {
        self.lines = lines
    }

    func prepare() async throws(SpeechEngineError) {}

    func transcribe(
        _ audio: AudioSamples, options: TranscriptionOptions
    ) async throws(SpeechEngineError) -> Transcription {
        calls += 1
        guard calls <= lines.count else { throw .nothingHeard }
        return Transcription(
            text: lines[calls - 1], detectedLanguage: DetectedLanguage(code: .english, confidence: 1),
            audioDuration: audio.duration)
    }
}

/// A language model that answers each piece with the sentence it was scripted for, as a model that punctuates would.
private struct SentenceModel: CleanupModel {
    let answers: [String: String]

    func availability(for language: LanguageCode?) async -> TransformerAvailability { .available }

    func rewrite(
        _ text: String, instructions: String, kind: TransformerKind
    ) async throws(TransformationError) -> String {
        guard let answer = answers.first(where: { text.contains($0.key) })?.value else {
            throw .transformFailed(kind: kind, description: "no scripted answer")
        }
        return answer
    }
}

private final class SeamInserter: TextInserting, Sendable {
    private let received = Mutex<[String]>([])

    func insert(_ text: String) async throws(TextInsertionError) -> InsertionAttempt {
        received.withLock { $0.append(text) }
        return InsertionAttempt(.accessibility)
    }
}

/// A recording with a clear pause between each of its phrases, cut into one piece per phrase.
private enum SeamTake {
    static let rate = AudioSamples.canonicalSampleRate

    static func tone(_ seconds: Double) -> [Float] {
        (0..<Int(seconds * Double(rate))).map { 0.3 * Float(sin(Double($0) * 0.07)) }
    }

    static func silence(_ seconds: Double) -> [Float] {
        [Float](repeating: 0, count: Int(seconds * Double(rate)))
    }

    static func pieces(_ count: Int) -> AudioSamples {
        AudioSamples.canonical(
            Array((0..<count).map { _ in tone(1.2) }.joined(separator: silence(0.5))))
    }
}

/// Windows short enough for a test recording to have several.
private let seamWindows = SpeechWindowing(
    minimumLength: 1, sentencePause: 0.3, comfortableLength: 2, anyPause: 0.2, maximumLength: 5)

// MARK: - Tests

@Suite("Dictation pipeline: the stops at the seams between pieces, through the real cleaner")
struct DictationPipelineSeamTests {
    private static let chat = AppContext.fixture()
    private static let document = AppContext.fixture(
        applicationName: "TextEdit", bundleIdentifier: "com.apple.TextEdit", documentName: "Notes")
    private static let terminal = AppContext.fixture(
        applicationName: "Terminal", bundleIdentifier: "com.apple.Terminal", documentName: "zsh")

    /// One whole dictation, a piece per line, cleaned by `cleaner` against the screen `context` shows.
    private func dictate(
        _ lines: [String], seeing context: AppContext, cleaner: any TranscriptCleaning = rules
    ) async -> String? {
        let take = SeamTake.pieces(lines.count)
        let capture = FakeAudioCaptureEngine(stopOutcome: .success(take))
        await capture.setCaptured(take)
        let pipeline = DictationPipeline(
            capture: capture, speech: SeamSpeechEngine(lines), cleaner: cleaner,
            context: FakeContextEngine(context: context), inserter: SeamInserter(),
            windowing: seamWindows, earlyPoll: .milliseconds(2))

        await pipeline.startRecording()
        await pipeline.finishRecording()
        guard case .inserted(let outcome) = await pipeline.currentState else { return nil }
        return outcome.text
    }

    /// The shipping floor: the deterministic passes, with no model in front of them.
    private static let rules = TransformerRouter(
        engines: [RuleBasedTransformer()], preference: [.rules])

    /// The shipping model engine over a model scripted to answer each piece, with the floor beneath it.
    private static func model(_ answers: [String: String]) -> TransformerRouter {
        TransformerRouter(
            engines: [
                GenerativeTextTransformer(kind: .foundationModels, model: SentenceModel(answers: answers)),
                RuleBasedTransformer(),
            ],
            preference: [.foundationModels, .rules])
    }

    @Test("a chat message cut at its sentence ends keeps the stop at every seam and its final one")
    func longChatMessageKeepsItsSeams() async {
        let text = await dictate(
            ["I left the office.", "The traffic is bad.", "I will be late."], seeing: Self.chat)
        #expect(text == "I left the office. The traffic is bad. I will be late.")
    }

    @Test("a short chat message in two pieces keeps the stop between them and drops only the last")
    func shortChatMessageKeepsItsSeam() async {
        let text = await dictate(["On my way.", "Be there soon."], seeing: Self.chat)
        #expect(text == "On my way. Be there soon")
    }

    @Test("a seam the recogniser left unmarked is still a sentence end in a chat")
    func unmarkedSeamInAChat() async {
        let text = await dictate(["on my way", "be there soon"], seeing: Self.chat)
        #expect(text == "On my way. Be there soon")
    }

    @Test("a question at a seam keeps its mark and the message still reads as sentences")
    func questionAtASeam() async {
        let text = await dictate(
            ["Can you bring the charger?", "I left mine at home.", "See you soon."], seeing: Self.chat)
        #expect(text == "Can you bring the charger? I left mine at home. See you soon.")
    }

    @Test("the model's answers keep their seams in a chat, not only the rules'")
    func modelAnswersKeepTheirSeams() async {
        let cleaner = Self.model([
            "left the office": "I left the office.", "traffic": "The traffic is bad.",
            "late": "I will be late.",
        ])
        let text = await dictate(
            ["i left the office", "the traffic is bad", "i will be late"], seeing: Self.chat,
            cleaner: cleaner)
        #expect(text == "I left the office. The traffic is bad. I will be late.")
    }

    @Test("a document stops every seam and the end, as it always has")
    func documentIsUnchanged() async {
        let text = await dictate(
            ["i left the office", "the traffic is bad", "i will be late"], seeing: Self.document)
        #expect(text == "I left the office. The traffic is bad. I will be late.")
    }

    @Test("a terminal takes no stop at a seam or at the end, even one the recogniser wrote")
    func terminalTakesNoStops() async {
        let text = await dictate(["git status.", "git diff."], seeing: Self.terminal)
        #expect(text?.contains(".") == false)
    }

    /// A terminal's seam is no sentence end, so the second piece is cased as it would be in one breath.
    @Test("a terminal cases the words after a seam as it would have in one breath")
    func terminalSeamIsNotASentenceStart() async {
        let text = await dictate(["git status.", "git diff."], seeing: Self.terminal)
        #expect(text == "git status git diff")
    }

    @Test("the caret's mid-sentence case applies to the message's first word, not to every piece's")
    func midSentenceCaretCasesOnlyTheFirstWord() async {
        let context = AppContext.fixture(
            applicationName: "TextEdit", bundleIdentifier: "com.apple.TextEdit", documentName: "Notes",
            precedingText: "We stopped because ")
        let text = await dictate(["the build failed.", "The tests are red."], seeing: context)
        #expect(text == "the build failed. The tests are red.")
    }
}
