/// Cuts a recording into pieces the recogniser can take one at a time, at pauses. See `Docs/early-transcription.md`.
public struct SpeechWindowing: Sendable, Equatable {
    /// Audio collected before the window is checked for a cut, in seconds.
    public var minimumLength: Double

    /// Audio a window must hold before a long early pause may end it, in seconds.
    public var earlyLength: Double

    /// A pause this long ends a window before ``minimumLength``, in seconds.
    public var earlyPause: Double

    /// A pause this long ends a window that has reached ``minimumLength``, in seconds.
    public var sentencePause: Double

    /// A window this long is ended by the shorter ``anyPause`` instead, in seconds.
    public var comfortableLength: Double

    /// A pause this long ends a window that has reached ``comfortableLength``, in seconds.
    public var anyPause: Double

    /// A window never holds more than this, which is the recogniser's own window, in seconds.
    public var maximumLength: Double

    /// Speech a window must hold before a pause may end it, so one word after a long pause is never decoded alone, in seconds.
    public var minimumSpeech: Double

    public init(
        minimumLength: Double = 5, earlyLength: Double = 2.5, earlyPause: Double = 1.0,
        sentencePause: Double = 0.8,
        comfortableLength: Double = 15, anyPause: Double = 0.4, maximumLength: Double = 30,
        minimumSpeech: Double = 0.8
    ) {
        self.minimumLength = minimumLength
        self.earlyLength = earlyLength
        self.earlyPause = earlyPause
        self.sentencePause = sentencePause
        self.comfortableLength = comfortableLength
        self.anyPause = anyPause
        self.maximumLength = maximumLength
        self.minimumSpeech = minimumSpeech
    }

    /// The windowing the product ships with.
    public static let standard = SpeechWindowing()

    /// Where the window beginning at `start` ends, or `nil` while the audio so far gives no reason to end it.
    public func nextCut(in samples: [Float], sampleRate: Int, from start: Int) -> Int? {
        guard sampleRate > 0, start >= 0, start < samples.count else { return nil }
        let available = samples.count - start
        guard Double(available) >= minimumLength * Double(sampleRate) else { return nil }

        let limit = Swift.min(samples.count, start + Int(maximumLength * Double(sampleRate)))
        let frameLength = Swift.max(1, Int(VoiceActivity.frameDuration * Double(sampleRate)))
        let loudness = VoiceActivity.frameLoudness(
            of: Array(samples[start..<limit]), frameLength: frameLength)
        // A recording with no speech left in it is one piece, whatever its length.
        let hasSpeechAhead =
            (loudness.max() ?? 0) >= VoiceActivity.absoluteFloor
            || VoiceActivity.hasSpeech(in: samples[limit...], frameLength: frameLength)
        guard hasSpeechAhead else { return nil }

        let sorted = loudness.sorted()
        let floor = VoiceActivity.percentile(sorted, 0.1)
        let threshold = VoiceActivity.threshold(forFloor: floor)

        let earliest = Int(Swift.min(earlyLength, minimumLength) / VoiceActivity.frameDuration)
        let ordinary = Int(minimumLength / VoiceActivity.frameDuration)
        let comfortable = Int(comfortableLength / VoiceActivity.frameDuration)
        var spoken = [0]
        for value in loudness { spoken.append(spoken[spoken.count - 1] + (value >= threshold ? 1 : 0)) }
        if let pause = firstPause(
            in: loudness, below: threshold, after: earliest, ordinaryAt: ordinary,
            comfortableAt: comfortable, spoken: spoken)
        {
            return start + pause * frameLength
        }
        guard limit - start >= Int(maximumLength * Double(sampleRate)) else { return nil }
        // Nobody paused, so the cut goes where the speaker was quietest: between words, not inside one.
        let quietest = loudness[comfortable...].enumerated().min { $0.element < $1.element }
        return start + (quietest.map { comfortable + $0.offset } ?? loudness.count) * frameLength
    }

    /// Every window in a finished recording; a last one holding only a word or two joins the window before it.
    public func windows(in samples: [Float], sampleRate: Int, from start: Int = 0) -> [Range<Int>] {
        var windows: [Range<Int>] = []
        var cursor = start
        while let end = nextCut(in: samples, sampleRate: sampleRate, from: cursor), end > cursor {
            windows.append(cursor..<end)
            cursor = end
        }
        guard cursor < samples.count else { return windows }
        if let before = windows.last, isFragment(samples[cursor...], sampleRate: sampleRate),
            Double(samples.count - before.lowerBound) <= maximumLength * Double(sampleRate)
        {
            windows[windows.count - 1] = before.lowerBound..<samples.count
        } else {
            windows.append(cursor..<samples.count)
        }
        return windows
    }

    /// Whether the audio holds some speech but less than ``minimumSpeech`` of it.
    private func isFragment(_ samples: ArraySlice<Float>, sampleRate: Int) -> Bool {
        let frameLength = Swift.max(1, Int(VoiceActivity.frameDuration * Double(sampleRate)))
        let loudness = VoiceActivity.frameLoudness(of: Array(samples), frameLength: frameLength)
        let threshold = VoiceActivity.threshold(forFloor: VoiceActivity.percentile(loudness.sorted(), 0.1))
        let voiced = loudness.filter { $0 >= threshold }.count
        return voiced > 0 && Double(voiced) * VoiceActivity.frameDuration < minimumSpeech
    }

    /// The middle frame of the first quiet run long enough for where that middle falls, counting a run still open at the end.
    private func firstPause(
        in loudness: [Float], below threshold: Float, after earliest: Int,
        ordinaryAt ordinary: Int, comfortableAt comfortable: Int, spoken: [Int]
    ) -> Int? {
        let speechFrames = Int((minimumSpeech / VoiceActivity.frameDuration).rounded())
        let earlyFrames = Swift.max(1, Int(earlyPause / VoiceActivity.frameDuration))
        let sentenceFrames = Swift.max(1, Int(sentencePause / VoiceActivity.frameDuration))
        let anyFrames = Swift.max(1, Int(anyPause / VoiceActivity.frameDuration))
        var runStart: Int?
        // A pause is measured from where it began, but never from before `earliest`, which is not scanned.
        for index in earliest..<loudness.count {
            if loudness[index] < threshold {
                if runStart == nil { runStart = index }
            } else if let began = runStart {
                if let middle = middle(
                    ofRun: began..<index, ordinary, comfortable, earlyFrames, sentenceFrames, anyFrames),
                    spoken[middle] >= speechFrames
                {
                    return middle
                }
                runStart = nil
            }
        }
        if let began = runStart,
            let middle = middle(
                ofRun: began..<loudness.count, ordinary, comfortable, earlyFrames, sentenceFrames,
                anyFrames),
            spoken[middle] >= speechFrames
        {
            return middle
        }
        return nil
    }

    /// The middle of `run` when a cut may fall there and the pause is long enough for where it falls, else `nil`.
    private func middle(
        ofRun run: Range<Int>, _ ordinary: Int, _ comfortable: Int,
        _ earlyFrames: Int, _ sentenceFrames: Int, _ anyFrames: Int
    ) -> Int? {
        let middle = run.lowerBound + run.count / 2
        let required =
            middle >= comfortable
            ? anyFrames
            : middle >= ordinary ? sentenceFrames : earlyFrames
        guard run.count >= required else { return nil }
        return middle
    }
}
