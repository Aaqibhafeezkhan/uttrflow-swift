// Holds the one AVAudioEngine call whose name the offline audit reads as a socket, so it is allowed alone.
import AVFoundation

/// Wires cue player nodes into an output-only engine.
enum CueEngineWiring {
    /// Attaches `node` to `engine` and feeds it into the main mixer in `format`.
    static func wire(_ node: AVAudioPlayerNode, into engine: AVAudioEngine, format: AVAudioFormat) {
        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: format)
    }
}
