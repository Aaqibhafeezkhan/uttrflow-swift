// Plays shaped recording cues through an output-only audio engine kept ready between dictations.
import AVFoundation
private import Synchronization

// MARK: - The part that makes noise
/// Plays each cue's shaped buffer through a prepared engine, so a cue costs an engine start rather than a load.
public final class ShapedSoundPlayer: SoundPlayer {
    /// The rate every cue is rendered at, so one connection format serves every player node.
    static let outputRate = 48_000.0
    /// How long the engine stays running after the last cue ends, so the output device is not held at rest.
    static let idleSeconds = 1.0

    /// A cue ready to play: its own node, so a stop cue never cuts off a start cue still sounding.
    private struct Voice {
        let node: AVAudioPlayerNode
        let buffer: AVAudioPCMBuffer
    }

    private struct State {
        var engine: AVAudioEngine?
        var voices: [CueSound: Voice] = [:]
        var known: [CueSound] = []
        var busyUntil = DispatchTime.now()
        var observer: (any NSObjectProtocol)?
    }

    private let state = Mutex(State())
    private let queue = DispatchQueue(label: "uttrflow.cue-engine", qos: .userInitiated)

    public init() {}

    deinit {
        state.withLock { Self.tearDown(&$0) }
    }

    public func prewarm(_ cues: [CueSound]) {
        // Off the caller's thread, since decoding, shaping and the first engine start take about 150 ms.
        queue.async { [self] in
            state.withLock { state in
                state.known = cues
                _ = prepare(cues, in: &state)
                guard let engine = state.engine, !engine.isRunning else { return }
                // Started once and paused, because the first start of a process costs several times a later one.
                guard (try? engine.start()) != nil else { return Self.tearDown(&state) }
                engine.pause()
            }
        }
    }

    @discardableResult
    public func play(_ cue: CueSound) -> Bool {
        let ready = state.withLock { $0.engine != nil && $0.voices[cue] != nil }
        // Started on the queue, so no caller ever waits on the output device waking.
        queue.async { [self] in ready ? sound(cue) : recover(cue) }
        return ready
    }

    /// Starts the engine if it is paused and plays `cue` from its first sample.
    private func sound(_ cue: CueSound) {
        let heard = state.withLock { state -> Bool in
            guard let engine = state.engine, let voice = state.voices[cue] else { return false }
            if !engine.isRunning, (try? engine.start()) == nil {
                Self.tearDown(&state)
                return false
            }
            // Stopped first, so a retrigger inside the previous cue's tail restarts it.
            voice.node.stop()
            voice.node.scheduleBuffer(voice.buffer)
            voice.node.play()
            let length = Double(voice.buffer.frameLength) / Self.outputRate
            state.busyUntil = max(state.busyUntil, .now() + length)
            return true
        }
        if heard { pauseWhenIdle() }
    }

    /// Rebuilds whatever a cue found missing, so the next cue can be shaped again.
    private func recover(_ cue: CueSound) {
        state.withLock { state in
            if !state.known.contains(cue) { state.known.append(cue) }
            _ = prepare(state.known, in: &state)
        }
    }

    /// Pauses the engine once no cue has sounded for ``idleSeconds``; a later cue moves the moment on.
    private func pauseWhenIdle() {
        let due = state.withLock { $0.busyUntil } + Self.idleSeconds
        queue.asyncAfter(deadline: due) { [weak self] in
            self?.state.withLock { state in
                guard DispatchTime.now() >= state.busyUntil + Self.idleSeconds else { return }
                state.engine?.pause()
            }
        }
    }

    /// Builds the engine and every voice it can; `false` when any sound cannot be had.
    private func prepare(_ cues: [CueSound], in state: inout State) -> Bool {
        guard let format = AVAudioFormat(standardFormatWithSampleRate: Self.outputRate, channels: 1) else {
            return false
        }
        let engine = state.engine ?? makeEngine(in: &state)
        var complete = true
        for cue in cues where state.voices[cue] == nil {
            guard let file = SystemSoundFile.load(cue.sound),
                let buffer = Self.buffer(
                    CueShaping.shape(
                        file.samples, sourceRate: file.sampleRate, cue: cue, outputRate: Self.outputRate),
                    format: format)
            else {
                complete = false
                continue
            }
            let node = AVAudioPlayerNode()
            CueEngineWiring.wire(node, into: engine, format: format)
            state.voices[cue] = Voice(node: node, buffer: buffer)
        }
        engine.prepare()
        return complete
    }

    /// A fresh engine that only ever reaches the output, rebuilt whenever the output device changes.
    private func makeEngine(in state: inout State) -> AVAudioEngine {
        let engine = AVAudioEngine()
        state.engine = engine
        state.observer = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange, object: engine, queue: nil
        ) { [weak self] _ in
            // Hopped onto the queue, since the notice can arrive while a cue holds the lock.
            self?.queue.async { [weak self] in self?.rebuild() }
        }
        return engine
    }

    /// Replaces an engine whose output moved, so the next cue plays on the device now in use.
    private func rebuild() {
        state.withLock { state in
            let known = state.known
            Self.tearDown(&state)
            _ = prepare(known, in: &state)
        }
    }

    /// Drops the engine and its voices; the next cue builds them again.
    private static func tearDown(_ state: inout State) {
        if let observer = state.observer { NotificationCenter.default.removeObserver(observer) }
        state.engine?.stop()
        state.engine = nil
        state.voices = [:]
        state.observer = nil
    }

    /// Copies `samples` into a buffer of `format`; `nil` for no samples.
    private static func buffer(_ samples: [Float], format: AVAudioFormat) -> AVAudioPCMBuffer? {
        guard !samples.isEmpty,
            let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count)),
            let channel = buffer.floatChannelData?[0]
        else { return nil }
        buffer.frameLength = AVAudioFrameCount(samples.count)
        samples.withUnsafeBufferPointer { source in
            if let base = source.baseAddress { channel.update(from: base, count: samples.count) }
        }
        return buffer
    }
}
