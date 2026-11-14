// LevelMeter — feature 048 (A06-P02) T-A06-202 (FR-A06-201, FR-A06-206; SC-A06-201): RMS and peak of one window of
// mono samples and their dBFS form floored at −120 dBFS. Contract specs/048-ml-p02-feature-analysis/contracts/api.md.
import Foundation

/// Level measurements of one window of mono samples, free of allocation.
///
/// Non-finite samples (NaN, ±infinity) count as 0; an empty window measures 0.
public enum LevelMeter {
    /// The dBFS floor returned for silence, zero, negative or non-finite amplitudes.
    public static let floorDB: Float = -120

    /// Root mean square of `samples`: √(Σ x² / count), with non-finite samples counted as 0; 0 for an empty window.
    /// - Parameter samples: the time-domain samples (full scale = 1).
    public static func rms(_ samples: UnsafeBufferPointer<Float>) -> Float {
        guard !samples.isEmpty else { return 0 }
        var sum: Double = 0
        for sample in samples where sample.isFinite {
            let value = Double(sample)
            sum += value * value
        }
        return Float((sum / Double(samples.count)).squareRoot())
    }

    /// Peak level of `samples`: the largest absolute finite sample; 0 for an empty window.
    /// - Parameter samples: the time-domain samples (full scale = 1).
    public static func peak(_ samples: UnsafeBufferPointer<Float>) -> Float {
        var best: Float = 0
        for sample in samples where sample.isFinite {
            let magnitude = abs(sample)
            if magnitude > best { best = magnitude }
        }
        return best
    }

    /// The amplitude in dB relative to full scale: 20·log10(amplitude), floored at ``floorDB``.
    ///
    /// Zero, negative and non-finite amplitudes return ``floorDB``.
    /// - Parameter amplitude: a linear amplitude (full scale = 1).
    public static func dBFS(_ amplitude: Float) -> Float {
        guard amplitude.isFinite, amplitude > 0 else { return floorDB }
        return max(floorDB, 20 * log10(amplitude))
    }
}
