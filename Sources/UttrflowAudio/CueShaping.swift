// Turns a system sound's samples into a cue, in plain arithmetic so it is tested without a speaker.
import Foundation

/// The varispeed, low-pass and gain chain a ``CueSound`` names, applied once when the cue is loaded.
public enum CueShaping {
    /// The coefficients of a second-order filter, normalised so `a0` is 1.
    public struct Biquad: Equatable, Sendable {
        public let b0: Double
        public let b1: Double
        public let b2: Double
        public let a1: Double
        public let a2: Double
    }

    /// Shapes mono `samples` recorded at `sourceRate` into mono samples at `outputRate`.
    public static func shape(
        _ samples: [Float], sourceRate: Double, cue: CueSound, outputRate: Double
    ) -> [Float] {
        let step = cue.playbackRate * sourceRate / outputRate
        let resampled = resample(samples, step: step)
        let filtered = filter(resampled, lowPass(cutoff: cue.lowPassHz, sampleRate: outputRate))
        return filtered.map { $0 * cue.volume }
    }

    /// Reads `samples` every `step` input samples with linear interpolation, so pitch and length change together.
    public static func resample(_ samples: [Float], step: Double) -> [Float] {
        guard let last = samples.indices.last, step > 0, step.isFinite else { return [] }
        let count = Int((Double(last) / step).rounded(.down)) + 1
        var output = [Float](repeating: 0, count: count)
        for index in 0..<count {
            let position = Double(index) * step
            let lower = min(Int(position), last)
            let upper = min(lower + 1, last)
            let fraction = Float(position - Double(lower))
            output[index] = samples[lower] + (samples[upper] - samples[lower]) * fraction
        }
        return output
    }

    /// A browser-style low-pass: `Q` is read in decibels, a cutoff at or past Nyquist passes, and one at or under 0 mutes.
    public static func lowPass(
        cutoff: Double, sampleRate: Double, resonanceDecibels: Double = CueSound.lowPassResonanceDecibels
    ) -> Biquad {
        let normalised = cutoff / (sampleRate / 2)
        if normalised >= 1 { return Biquad(b0: 1, b1: 0, b2: 0, a1: 0, a2: 0) }
        if normalised <= 0 { return Biquad(b0: 0, b1: 0, b2: 0, a1: 0, a2: 0) }
        let omega = Double.pi * normalised
        let alpha = sin(omega) / (2 * pow(10, resonanceDecibels / 20))
        let cosine = cos(omega)
        let a0 = 1 + alpha
        return Biquad(
            b0: (1 - cosine) / 2 / a0,
            b1: (1 - cosine) / a0,
            b2: (1 - cosine) / 2 / a0,
            a1: -2 * cosine / a0,
            a2: (1 - alpha) / a0
        )
    }

    /// Runs `samples` through `biquad` in direct form I, starting from silence.
    public static func filter(_ samples: [Float], _ biquad: Biquad) -> [Float] {
        var (x1, x2, y1, y2) = (0.0, 0.0, 0.0, 0.0)
        return samples.map { sample in
            let x0 = Double(sample)
            let y0 = biquad.b0 * x0 + biquad.b1 * x1 + biquad.b2 * x2 - biquad.a1 * y1 - biquad.a2 * y2
            (x2, x1, y2, y1) = (x1, x0, y1, y0)
            return Float(y0)
        }
    }
}
