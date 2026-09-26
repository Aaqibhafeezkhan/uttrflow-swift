// Tests detecting and recovering from a decode that stopped because the decoder ran out of positions.
import Synchronization
import Testing

@testable import UttrflowCore
@testable import UttrflowSpeech

@Suite("A decode that stopped because it ran out of positions")
struct CappedDecodeTests {
    /// A transcript whose last segment ends at `end`, with the words and timings a capped decode produces.
    private func transcriptEnding(at end: Double, words: Int = 1) -> RawTranscript {
        let rawWords = (0..<words).map { index in
            RawWord(
                text: " word\(index)", start: Double(index) * 0.4, end: Double(index) * 0.4 + 0.4,
                probability: 0.9)
        }
        let lastWordEnd = Double(words - 1) * 0.4 + 0.4
        return RawTranscript(
            text: "words",
            segments: [
                RawSegment(text: "words", start: 0, end: max(end, lastWordEnd), words: rawWords)
            ]
        )
    }

    @Test("a transcript that ends at the audio end is not capped")
    func transcriptEndsAtAudioEnd() {
        let raw = transcriptEnding(at: 10.0)
        #expect(!raw.appearsCapped(audioDuration: .seconds(10)))
    }

    @Test("a transcript that ends shortly before the audio end is not capped")
    func transcriptEndsShortlyBeforeAudioEnd() {
        let raw = transcriptEnding(at: 9.0)
        #expect(!raw.appearsCapped(audioDuration: .seconds(10)))
    }

    @Test("a transcript that ends well before the audio end is capped")
    func transcriptEndsWellBeforeAudioEnd() {
        let raw = transcriptEnding(at: 5.0)
        #expect(raw.appearsCapped(audioDuration: .seconds(20)))
    }

    @Test("an empty transcript is not capped")
    func emptyTranscriptIsNotCapped() {
        let raw = RawTranscript(text: "")
        #expect(!raw.appearsCapped(audioDuration: .seconds(10)))
    }
}

/// A recogniser that returns one segment ending mid-clip on the first call and the rest on follow-up calls.
private actor CappedFakeBackend: TranscriptionBackend {
    struct Call: Sendable, Equatable {
        let sampleCount: Int
        let trailingSample: Float?
        let languageHint: LanguageCode?
        let vocabulary: [String]
    }

    let minimumDuration: Duration = .zero
    private let state: Mutex<State>
    private struct State {
        var calls: [Call] = []
        var firstDone = false
    }

    init(samples: Int, cappedEnd: Double, tailWords: String, firstTokensUsed: Int = 220) {
        state = Mutex(State())
        self.samples = samples
        self.cappedEnd = cappedEnd
        self.tailWords = tailWords
        self.firstTokensUsed = firstTokensUsed
    }

    private let samples: Int
    private let cappedEnd: Double
    private let tailWords: String
    private let firstTokensUsed: Int

    func load() async throws(SpeechEngineError) {}

    func transcribe(
        _ samples: [Float], languageHint: LanguageCode?
    ) async throws(SpeechEngineError) -> RawTranscript {
        try await transcribe(samples, languageHint: languageHint, biasedTowards: [])
    }

    func transcribe(
        _ samples: [Float], languageHint: LanguageCode?, biasedTowards vocabulary: [String]
    ) async throws(SpeechEngineError) -> RawTranscript {
        let outcome = state.withLock { state -> RawTranscript in
            state.calls.append(
                Call(
                    sampleCount: samples.count, trailingSample: samples.last,
                    languageHint: languageHint, vocabulary: vocabulary))
            if !state.firstDone {
                state.firstDone = true
                return RawTranscript(
                    text: "first batch",
                    segments: [
                        RawSegment(
                            text: "first batch", start: 0, end: cappedEnd,
                            words: [
                                RawWord(
                                    text: " first", start: 0, end: cappedEnd, probability: 0.9)
                            ])
                    ],
                    tokensUsed: firstTokensUsed)
            } else {
                // End just before the audio end so the retry sees a clean decode and stops.
                let end = max(0.5, Double(samples.count) / 16_000.0 - 0.3)
                return RawTranscript(
                    text: tailWords,
                    segments: [
                        RawSegment(
                            text: tailWords, start: 0, end: end,
                            words: [
                                RawWord(text: " " + tailWords, start: 0, end: end, probability: 0.9)
                            ])
                    ],
                    tokensUsed: 28)
            }
        }
        return outcome
    }

    var calls: [Call] { state.withLock(\.calls) }
}

@Suite("The retry around a capped decode")
struct CappedDecodeRetryTests {
    @Test("a decode that ended at the audio end is returned untouched")
    func uncappedIsReturned() async throws {
        let backend = CappedFakeBackend(
            samples: 16_000, cappedEnd: 1.0, tailWords: "unused", firstTokensUsed: 80)
        let samples = Array(repeating: Float(0.1), count: 16_000)

        let raw = try await CappedDecodeRetry.transcribe(
            samples: samples, languageHint: .english, vocabulary: [], using: backend)

        #expect(raw.text == "first batch")
        #expect(await backend.calls.count == 1)
    }

    @Test("a decode that ended mid-clip is followed by a decode of the remaining samples")
    func cappedIsFollowedUp() async throws {
        // 30s of audio at 16 kHz, recogniser hit the cap after 14s of words.
        let totalSamples = 30 * 16_000
        let backend = CappedFakeBackend(samples: totalSamples, cappedEnd: 14.0, tailWords: "second")
        let samples = Array(repeating: Float(0.1), count: totalSamples)

        let raw = try await CappedDecodeRetry.transcribe(
            samples: samples, languageHint: .hindi, vocabulary: ["Uttrflow"], using: backend)

        let calls = await backend.calls
        #expect(calls.count == 2)
        // The follow-up starts one sample past where the first decode stopped.
        #expect(calls[1].sampleCount == totalSamples - Int((14.0 * 16_000).rounded(.down)))
        // The tail's words are shifted by the slice so their times line up with the original audio.
        let secondSegment = raw.segments.last
        #expect(secondSegment?.start == 14.0)
        let tailWord = secondSegment?.words?.first
        #expect(tailWord?.start == 14.0)
        #expect(raw.text.contains("first batch"))
        #expect(raw.text.contains("second"))
    }

    @Test("a decode that stays capped gives up after a bounded number of retries")
    func cappedStaysCappedGivesUp() async throws {
        let totalSamples = 60 * 16_000
        // The fake returns a capped result on every call, so the retry loop should stop.
        let backend = AlwaysCappedFakeBackend(samples: totalSamples, cappedEnd: 14.0)
        let samples = Array(repeating: Float(0.1), count: totalSamples)

        let raw = try await CappedDecodeRetry.transcribe(
            samples: samples, languageHint: .hindi, vocabulary: [], using: backend)

        let calls = await backend.calls
        #expect(calls.count <= CappedDecodeRetry.maxRetries)
        #expect(calls.count > 1)
        #expect(raw.text.contains("first batch"))
    }

    @Test(
        "a token-capped decode that stretched the last fragment word to the audio end still triggers a tail retry"
    )
    func cappedByTokenBudgetWithFragmentStretchedToEnd() async throws {
        // WhisperKit stretches the last fragment word to the audio end, so `lastEnd == audioEnd` even though the decoder stopped mid-word.
        let totalSamples = 30 * 16_000
        let backend = StretchedCappedBackend(samples: totalSamples, fragmentWord: "ह")
        let samples = Array(repeating: Float(0.1), count: totalSamples)

        let raw = try await CappedDecodeRetry.transcribe(
            samples: samples, languageHint: .hindi, vocabulary: [], using: backend)

        let calls = await backend.calls
        #expect(calls.count == 2, "the second decode should recover the audio after the fragment")
        // The slice sits at the previous normal word's end, not at the fragment's start, so the second decode does not re-decode already-decoded audio.
        #expect(calls[1].sampleCount == totalSamples - Int((0.8 * 16_000).rounded(.down)))
        #expect(raw.text.contains("first batch"))
        #expect(raw.text.contains("second"))
    }
}

/// A recogniser that returns a capped result on every call, so the retry has nothing to do but stop.
private actor AlwaysCappedFakeBackend: TranscriptionBackend {
    struct Call: Sendable, Equatable {
        let sampleCount: Int
        let trailingSample: Float?
        let languageHint: LanguageCode?
        let vocabulary: [String]
    }

    let minimumDuration: Duration = .zero
    private let state: Mutex<State>
    private struct State { var calls: [Call] = [] }

    init(samples: Int, cappedEnd: Double) {
        state = Mutex(State())
        self.cappedEnd = cappedEnd
    }

    private let cappedEnd: Double

    func load() async throws(SpeechEngineError) {}

    func transcribe(
        _ samples: [Float], languageHint: LanguageCode?
    ) async throws(SpeechEngineError) -> RawTranscript {
        try await transcribe(samples, languageHint: languageHint, biasedTowards: [])
    }

    func transcribe(
        _ samples: [Float], languageHint: LanguageCode?, biasedTowards vocabulary: [String]
    ) async throws(SpeechEngineError) -> RawTranscript {
        let outcome = state.withLock { state -> RawTranscript in
            state.calls.append(
                Call(
                    sampleCount: samples.count, trailingSample: samples.last,
                    languageHint: languageHint, vocabulary: vocabulary))
            return RawTranscript(
                text: "first batch",
                segments: [
                    RawSegment(
                        text: "first batch", start: 0, end: cappedEnd,
                        words: [
                            RawWord(text: " first", start: 0, end: cappedEnd, probability: 0.9)
                        ])
                ],
                tokensUsed: 220)
        }
        return outcome
    }

    var calls: [Call] { state.withLock(\.calls) }
}

/// A recogniser that returns a token-capped decode where the final fragment word is stretched to the audio end, mirroring what WhisperKit does after a Hindi decode stops at the cap.
private actor StretchedCappedBackend: TranscriptionBackend {
    struct Call: Sendable, Equatable {
        let sampleCount: Int
        let trailingSample: Float?
        let languageHint: LanguageCode?
        let vocabulary: [String]
    }

    let minimumDuration: Duration = .zero
    private let state: Mutex<State>
    private struct State {
        var calls: [Call] = []
        var firstDone = false
    }

    init(samples: Int, fragmentWord: String) {
        state = Mutex(State())
        self.fragmentWord = fragmentWord
    }

    private let fragmentWord: String

    func load() async throws(SpeechEngineError) {}

    func transcribe(
        _ samples: [Float], languageHint: LanguageCode?
    ) async throws(SpeechEngineError) -> RawTranscript {
        try await transcribe(samples, languageHint: languageHint, biasedTowards: [])
    }

    func transcribe(
        _ samples: [Float], languageHint: LanguageCode?, biasedTowards vocabulary: [String]
    ) async throws(SpeechEngineError) -> RawTranscript {
        let outcome = state.withLock { state -> RawTranscript in
            state.calls.append(
                Call(
                    sampleCount: samples.count, trailingSample: samples.last,
                    languageHint: languageHint, vocabulary: vocabulary))
            if !state.firstDone {
                state.firstDone = true
                let lastNormalEnd = Double(samples.count) / 16_000.0 - 1.5
                let audioEnd = Double(samples.count) / 16_000.0
                return RawTranscript(
                    text: "first batch \(fragmentWord)",
                    segments: [
                        RawSegment(
                            text: "first batch \(fragmentWord)", start: 0, end: audioEnd,
                            words: [
                                RawWord(text: " first", start: 0, end: 0.4, probability: 0.9),
                                RawWord(text: " batch", start: 0.4, end: 0.8, probability: 0.9),
                                RawWord(
                                    text: " " + fragmentWord, start: lastNormalEnd,
                                    end: audioEnd, probability: 0.9),
                            ])
                    ],
                    tokensUsed: 220)
            } else {
                return RawTranscript(
                    text: "second",
                    segments: [
                        RawSegment(
                            text: "second", start: 0, end: 0.5,
                            words: [
                                RawWord(text: " second", start: 0, end: 0.5, probability: 0.9)
                            ])
                    ],
                    tokensUsed: 28)
            }
        }
        return outcome
    }

    var calls: [Call] { state.withLock(\.calls) }
}

/// A recogniser whose first window collapses to one segment ending at 30 s with its words stopping at 27 s.
private actor CollapsedWindowBackend: TranscriptionBackend {
    let minimumDuration: Duration = .zero
    private let state = Mutex<[Int]>([])

    func load() async throws(SpeechEngineError) {}

    func transcribe(
        _ samples: [Float], languageHint: LanguageCode?
    ) async throws(SpeechEngineError) -> RawTranscript {
        try await transcribe(samples, languageHint: languageHint, biasedTowards: [])
    }

    func transcribe(
        _ samples: [Float], languageHint: LanguageCode?, biasedTowards vocabulary: [String]
    ) async throws(SpeechEngineError) -> RawTranscript {
        let first = state.withLock { calls in
            calls.append(samples.count)
            return calls.count == 1
        }
        let end = Double(samples.count) / 16_000.0 - 0.3
        guard first else {
            return RawTranscript(
                text: " across the boundary and after",
                segments: [
                    RawSegment(
                        text: " across the boundary and after", start: 0, end: end,
                        words: [RawWord(text: " across", start: 0.2, end: end, probability: 0.9)])
                ], tokensUsed: 40)
        }
        return RawTranscript(
            text: " opening words after",
            segments: [
                RawSegment(
                    text: " opening words", start: 0, end: 30,
                    words: [RawWord(text: " opening", start: 0.2, end: 27, probability: 0.9)]),
                RawSegment(
                    text: " after", start: 30, end: end,
                    words: [RawWord(text: " after", start: 31, end: end, probability: 0.9)]),
            ], tokensUsed: 60)
    }

    var calls: [Int] { state.withLock { $0 } }
}

@Suite("A window that collapsed to one segment")
struct CollapsedWindowTests {
    @Test("the words dropped at the window boundary are decoded again from the last word heard")
    func collapsedWindowIsRedecoded() async throws {
        let totalSamples = 53 * 16_000
        let backend = CollapsedWindowBackend()
        let samples = Array(repeating: Float(0.1), count: totalSamples)

        let raw = try await CappedDecodeRetry.transcribe(
            samples: samples, languageHint: .english, vocabulary: ["Uttrflow"], using: backend)

        let calls = await backend.calls
        #expect(calls.count == 2)
        #expect(calls[1] == totalSamples - 27 * 16_000)
        #expect(
            raw.text.split(separator: " ").joined(separator: " ")
                == "opening words across the boundary and after")
        #expect(raw.segments.count == 2)
        #expect(raw.segments.last?.start == 27)
    }

    @Test("a segment that ends at a window with its words running to the end is left alone")
    func fullWindowIsKept() {
        let segments = [
            RawSegment(
                text: "a", start: 0, end: 30,
                words: [RawWord(text: "a", start: 0, end: 29.6, probability: 0.9)])
        ]
        #expect(CappedDecodeRetry.collapsedWindow(in: segments, sliceSeconds: 53) == nil)
    }

    @Test("a collapsed window at the end of the audio has nothing after it to lose")
    func collapseAtAudioEndIsKept() {
        let segments = [
            RawSegment(
                text: "a", start: 0, end: 30,
                words: [RawWord(text: "a", start: 0, end: 20, probability: 0.9)])
        ]
        #expect(CappedDecodeRetry.collapsedWindow(in: segments, sliceSeconds: 30.5) == nil)
    }
}
