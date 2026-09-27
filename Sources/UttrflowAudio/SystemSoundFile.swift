// Finds and decodes a macOS system sound, so a cue is built from the Mac's own audio rather than a shipped copy.
public import Foundation
import AVFoundation

/// A system sound's audio, mixed down to one channel.
public struct SystemSoundFile: Sendable {
    public let samples: [Float]
    public let sampleRate: Double

    /// Where `NSSound(named:)` looks, in its order, so a user's replacement in `~/Library/Sounds` wins.
    public static var searchDirectories: [URL] {
        let library = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)
        return library.map { $0.appending(path: "Sounds") } + [
            URL(filePath: "/Library/Sounds"), URL(filePath: "/System/Library/Sounds"),
        ]
    }

    /// The extensions a system sound is stored under.
    static let extensions = ["aiff", "aif", "caf", "wav", "m4a"]

    /// The first file named `sound` in `directories`; `nil` when there is none.
    public static func url(for sound: SystemSound, in directories: [URL] = searchDirectories) -> URL? {
        for directory in directories {
            for fileExtension in extensions {
                let candidate = directory.appending(path: "\(sound.name).\(fileExtension)")
                if FileManager.default.isReadableFile(atPath: candidate.path) { return candidate }
            }
        }
        return nil
    }

    /// Decodes the file named `sound`; `nil` when it is missing, unreadable or empty.
    public static func load(_ sound: SystemSound, in directories: [URL] = searchDirectories) -> Self? {
        guard let url = url(for: sound, in: directories) else { return nil }
        return decode(url)
    }

    /// Decodes `url` and averages its channels; `nil` when it is not audio or holds none.
    public static func decode(_ url: URL) -> Self? {
        guard let file = try? AVAudioFile(forReading: url),
            let buffer = AVAudioPCMBuffer(
                pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length)),
            (try? file.read(into: buffer)) != nil,
            let channels = buffer.floatChannelData, buffer.frameLength > 0
        else { return nil }
        let frames = Int(buffer.frameLength)
        let channelCount = Int(buffer.format.channelCount)
        var mono = [Float](repeating: 0, count: frames)
        for channel in 0..<channelCount {
            let data = channels[channel]
            for frame in 0..<frames { mono[frame] += data[frame] / Float(channelCount) }
        }
        return Self(samples: mono, sampleRate: buffer.format.sampleRate)
    }
}
