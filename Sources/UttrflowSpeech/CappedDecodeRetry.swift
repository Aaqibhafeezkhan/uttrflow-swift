// Recovers the audio after a decode that stopped because the decoder ran out of positions.
public import UttrflowCore

/// Calls a recogniser, then calls it again on whatever audio the first call did not cover, until it stops hitting the cap.
public enum CappedDecodeRetry {
    /// The most retries, so a decode that cannot make progress gives up rather than spinning.
    public static let maxRetries = 10
    /// A token count past which a decode is treated as having stopped because the decoder ran out of positions, not at an end-of-text token. WhisperKit's 223-position shared decode budget leaves room for about 47 Hindi words or 200+ English ones, so this catches Hindi without firing on English.
    public static let tokenCapThreshold = 215
    /// A word longer than this is taken to be the fragment the recogniser stretched to fill the rest of the audio after the decoder stopped mid-word; the previous word's end is where the real decode stopped.
    public static let fragmentWordDuration: Duration = .milliseconds(900)
    /// The recogniser's fixed window; a segment that ends at one without inner timestamps is where a window collapsed.
    public static let windowSeconds = 30.0
    /// Silence between a collapsed segment's last word and its end past which words are taken to have been dropped.
    public static let collapsedGapSeconds = 1.0

    /// Decodes `samples` with `backend`, retrying the tail when the decoder's token cap stops a decode early.
    public static func transcribe(
        samples: [Float],
        sampleRate: Double = Double(AudioSamples.canonicalSampleRate),
        languageHint: LanguageCode?,
        vocabulary: [String],
        using backend: any TranscriptionBackend
    ) async throws(SpeechEngineError) -> RawTranscript {
        var accumulatedText = ""
        var accumulatedSegments: [RawSegment] = []
        var languageIdentifier: String?
        var languageProbability: Double?
        var totalEffort = DecodeEffort.none
        var totalTokensUsed = 0
        var remaining = samples
        var sliceStartSeconds = 0.0

        for _ in 0..<maxRetries {
            guard !remaining.isEmpty else { break }
            let result = try await backend.transcribe(
                remaining, languageHint: languageHint, biasedTowards: vocabulary)
            languageIdentifier = result.languageIdentifier ?? languageIdentifier
            languageProbability = result.languageProbability ?? languageProbability
            totalEffort = totalEffort.adding(result.effort)
            totalTokensUsed += result.tokensUsed

            let sliceDuration = Duration.seconds(Double(remaining.count) / sampleRate)
            let collapse = collapsedWindow(in: result.segments, sliceSeconds: sliceDuration.inSeconds)
            let kept = collapse.map { Array(result.segments[...$0.index]) } ?? result.segments
            let text =
                collapse == nil
                ? result.text
                : kept.map { $0.text.trimmingCharacters(in: .whitespaces) }.joined(separator: " ")
            if !text.isEmpty {
                accumulatedText += (accumulatedText.isEmpty ? "" : " ") + text
            }
            let shifted = kept.map { segment in
                RawSegment(
                    text: segment.text,
                    start: segment.start + sliceStartSeconds,
                    end: segment.end + sliceStartSeconds,
                    words: segment.words?.map { word in
                        RawWord(
                            text: word.text,
                            start: word.start + sliceStartSeconds,
                            end: word.end + sliceStartSeconds,
                            probability: word.probability)
                    })
            }
            accumulatedSegments.append(contentsOf: shifted)

            // The token count is the reliable signal — a recogniser that reports it has run out of room at ~223 positions. A backend that does not report tokens falls back to the segment-end heuristic.
            let hitCap =
                result.tokensUsed > 0
                ? result.tokensUsed >= tokenCapThreshold
                : result.appearsCapped(audioDuration: sliceDuration)
            // A collapsed window is checked first because the segments after it were already dropped above.
            let cutoff: Double
            if let collapse {
                cutoff = collapse.lastWordEnd
            } else {
                guard hitCap else { break }
                // The recogniser may stretch the final fragment word to the audio end; trust the last *normal* word as where it actually stopped.
                guard let capped = cappedCutoffSeconds(in: result.segments) else {
                    totalEffort = totalEffort.markingCapUnresolved()
                    break
                }
                cutoff = capped
            }
            let consumedSamples = Int((cutoff * sampleRate).rounded(.down))
            guard consumedSamples > 0, consumedSamples < remaining.count else {
                totalEffort = totalEffort.markingCapUnresolved()
                break
            }
            remaining = Array(remaining[consumedSamples...])
            sliceStartSeconds += cutoff
        }

        return RawTranscript(
            text: accumulatedText.trimmingCharacters(in: .whitespacesAndNewlines),
            languageIdentifier: languageIdentifier,
            languageProbability: languageProbability,
            segments: accumulatedSegments,
            effort: totalEffort,
            tokensUsed: totalTokensUsed
        )
    }

    /// The first segment that ran to the end of a fixed window with its words stopping well short of it, while audio continues past. See `Docs/speech-engines.md`.
    static func collapsedWindow(
        in segments: [RawSegment], sliceSeconds: Double
    ) -> (index: Int, lastWordEnd: Double)? {
        for (index, segment) in segments.enumerated() {
            guard let lastWordEnd = segment.words?.last?.end, lastWordEnd > 0 else { continue }
            let windows = (segment.end / windowSeconds).rounded()
            let endsAtWindow = windows >= 1 && abs(segment.end - windows * windowSeconds) <= 0.1
            let spansWindow = segment.end - segment.start >= windowSeconds - 0.5
            guard endsAtWindow || spansWindow else { continue }
            guard segment.end - lastWordEnd > collapsedGapSeconds else { continue }
            guard sliceSeconds - segment.end > collapsedGapSeconds else { continue }
            return (index, lastWordEnd)
        }
        return nil
    }

    /// Where in the recogniser's view the decoder actually stopped, in seconds from the start of the slice, ignoring any final fragment word it stretched past the cap.
    fileprivate static func cappedCutoffSeconds(in segments: [RawSegment]) -> Double? {
        // Walk newest-to-oldest so the first non-fragment found is the chronologically last word the recogniser finished, not the first.
        let allWords = segments.reversed().flatMap { ($0.words ?? []).reversed() }
        guard !allWords.isEmpty else {
            return segments.last?.end
        }
        let fragmentSeconds = fragmentWordDuration.inSeconds
        for word in allWords {
            let duration = word.end - word.start
            guard duration <= fragmentSeconds else { continue }
            return word.end
        }
        return segments.last?.end
    }
}
