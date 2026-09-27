// Asserts the upstream facts the prompt is sized from, since prose cannot fail a build.
import Testing
import WhisperKit

@testable import UttrflowSpeech

/// What the product assumes about the recogniser it links, checked against the recogniser it links.
@Suite("The WhisperKit contract")
struct WhisperKitContractTests {
    @Test("the decoder's context window is the 224 tokens every budget here is derived from")
    func contextWindow() {
        #expect(Constants.maxTokenContext == 224)
    }

    /// The one derivation: exceed this and the decoder drops the words we asked it to listen for.
    @Test("the prompt cap the decoder enforces is the number VocabularyPrompt sizes itself to")
    func promptCapIsTheOneWeSizeTo() {
        #expect((Constants.maxTokenContext / 2) - 1 == VocabularyPrompt.maximumTokens)
    }

    /// The decoder builds its fallback through this initialiser, so its reason is the one `judged` sees.
    @Test("a compression fallback is named by the reason LanguageHeldDecoder relaxes for")
    func compressionFallbackReason() throws {
        let options = DecodingOptions(
            compressionRatioThreshold: 2.4, logProbThreshold: -1.0, noSpeechThreshold: 0.6)
        let fallback = try #require(
            DecodingFallback(
                options: options, isFirstTokenLogProbTooLow: false, noSpeechProb: 0, compressionRatio: 2.8,
                avgLogProb: 0))

        #expect(fallback.needsFallback)
        #expect(fallback.fallbackReason == LanguageHeldDecoder.compressionFallbackReason)
    }

    /// A clip WhisperKitBackend's shortest clip is derived from, so audio shorter than it is padded.
    @Test("the window clip the product asks for is a field the decoder still takes")
    func windowClipSurvives() {
        let options = DecodingOptions(windowClipTime: VocabularyPrompt.windowClipTime)

        #expect(options.windowClipTime == VocabularyPrompt.windowClipTime)
    }

    /// Every option the product names, read back off the options it built, so an upstream default cannot move one.
    @Test("the decode the product asks for is the decode it wrote down")
    func decodeIsWhatWasAskedFor() {
        let options = VocabularyPrompt.decodingOptions(languageHint: .english)

        #expect(options.task == .transcribe)
        #expect(options.temperature == 0)
        #expect(options.temperatureIncrementOnFallback == 0.2)
        #expect(options.temperatureFallbackCount == 5)
        #expect(options.sampleLength == Constants.maxTokenContext)
        #expect(options.topK == 5)
        #expect(options.usePrefillPrompt)
        #expect(options.skipSpecialTokens)
        #expect(!options.withoutTimestamps)
        #expect(options.wordTimestamps)
        #expect(options.maxInitialTimestamp == nil)
        #expect(options.clipTimestamps.isEmpty)
        #expect(options.windowClipTime == VocabularyPrompt.windowClipTime)
        #expect(!options.suppressBlank)
        #expect(options.suppressTokens.isEmpty)
        #expect(options.chunkingStrategy == nil)
    }

    /// Whisper's own tests for a window of repetition, low confidence or silence, which the product does not retune.
    @Test("the thresholds a window is accepted or retried on are the ones written down here")
    func thresholdsAreWhatWasAskedFor() {
        let options = VocabularyPrompt.decodingOptions(languageHint: nil)

        #expect(options.compressionRatioThreshold == 2.4)
        #expect(options.logProbThreshold == -1.0)
        #expect(options.firstTokenLogProbThreshold == -1.5)
        #expect(options.noSpeechThreshold == 0.6)
        #expect(options.concurrentWorkerCount == 16)
    }

    /// The prefill the timestamp rules are told to start sampling after, counted from these.
    @Test("a multilingual decode still prefills the four tokens DecoderPrefill counts without a prompt")
    func prefillLengthIsStillFour() {
        let prefill = DecoderPrefill(
            promptTokens: nil, specialTokenBegin: 50_257, isMultilingual: true)

        #expect(prefill.count == 4)
    }
}
