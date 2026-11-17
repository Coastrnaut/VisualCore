// AmbientLoop — feature 155 (A21-P04) T-A21-402 (FR-A21-405; gap G-LOOP; spec Clarification Q1): a quiet ambient
// loop described by a few numbers and synthesised by code — a sum of up to six sine partials, each with a whole number
// of cycles per loop, under a slow swell that also has a whole number of cycles per loop, so the last sample leads
// into the first exactly as any sample leads into the next. Pure and deterministic: no files, no randomness.
import Foundation

/// One sine partial of an ``AmbientLoopRecipe``: a whole number of cycles per loop at a relative amplitude.
public struct AmbientLoopPartial: Sendable, Equatable, Hashable, Codable {
    /// Allowed relative amplitudes.
    public static let amplitudeRange: ClosedRange<Double> = 0...1

    /// Whole sine cycles in one loop (at least 1); the frequency in hertz is `cyclesPerLoop / seconds`.
    public var cyclesPerLoop: Int
    /// Relative amplitude (0…1) before the loop is normalised to its gain.
    public var amplitude: Double

    /// Creates a partial; the values are stored as given and checked by ``AmbientLoopRecipe/isValid``.
    /// - Parameters:
    ///   - cyclesPerLoop: whole sine cycles in one loop (≥ 1).
    ///   - amplitude: relative amplitude (0…1).
    public init(cyclesPerLoop: Int, amplitude: Double) {
        self.cyclesPerLoop = cyclesPerLoop
        self.amplitude = amplitude
    }
}

/// A synthesised ambient loop: ``partials`` summed, shaped by a slow swell of ``swellCycles`` whole cycles per loop
/// and normalised so the peak equals ``gain`` (FR-A21-405).
///
/// Every period is a whole number of cycles of the loop length, so the loop is seamless when repeated. Use
/// ``isValid`` to check the limits; ``AmbientLoopSynth/render(_:)`` renders an invalid recipe as an empty buffer.
public struct AmbientLoopRecipe: Sendable, Equatable, Hashable, Codable {
    /// The sample rate of every loop in hertz.
    public static let sampleRate = 48_000.0
    /// Allowed loop lengths in whole seconds.
    public static let secondsRange: ClosedRange<Int> = 4...16
    /// Allowed numbers of partials.
    public static let partialCountRange: ClosedRange<Int> = 1...6
    /// Allowed peak gains (linear amplitude).
    public static let gainRange: ClosedRange<Double> = 0...0.3

    /// A gentle default: 8 s of 110, 165 and 220 Hz (880, 1,320 and 1,760 cycles per loop) under a two-cycle swell
    /// (one swell every 4 s), peak gain 0.2.
    public static let gentle = AmbientLoopRecipe(
        seconds: 8,
        partials: [AmbientLoopPartial(cyclesPerLoop: 880, amplitude: 0.6),
                   AmbientLoopPartial(cyclesPerLoop: 1_320, amplitude: 0.3),
                   AmbientLoopPartial(cyclesPerLoop: 1_760, amplitude: 0.2)],
        swellCycles: 2,
        gain: 0.2)

    /// Loop length in whole seconds (4…16).
    public var seconds: Int
    /// The sine partials (1…6), each with a whole number of cycles per loop (≥ 1).
    public var partials: [AmbientLoopPartial]
    /// Whole cycles of the slow amplitude swell in one loop (at least 1; keep it small, such as 1 or 2, for a slow swell).
    public var swellCycles: Int
    /// Peak amplitude (0…0.3); the loop's largest sample magnitude equals it (or every sample is 0 when it is 0).
    public var gain: Double

    /// Creates a recipe; the values are stored as given and checked by ``isValid``.
    /// - Parameters:
    ///   - seconds: loop length in whole seconds (4…16; 8 by default).
    ///   - partials: the sine partials (1…6).
    ///   - swellCycles: whole swell cycles per loop (≥ 1; 1 by default).
    ///   - gain: peak amplitude (0…0.3; 0.2 by default).
    public init(seconds: Int = 8, partials: [AmbientLoopPartial], swellCycles: Int = 1, gain: Double = 0.2) {
        self.seconds = seconds
        self.partials = partials
        self.swellCycles = swellCycles
        self.gain = gain
    }

    /// Number of samples of one loop: `seconds × sampleRate`.
    public var sampleCount: Int { seconds * Int(Self.sampleRate) }

    /// Whether every value is finite and within its limits (length, partial count, cycles, amplitudes, swell, gain).
    public var isValid: Bool {
        guard Self.secondsRange.contains(seconds), Self.partialCountRange.contains(partials.count),
              swellCycles >= 1, Self.gainRange.contains(gain) else { return false }
        return partials.allSatisfy { $0.cyclesPerLoop >= 1 && AmbientLoopPartial.amplitudeRange.contains($0.amplitude) }
    }
}

/// Renders ``AmbientLoopRecipe``s to mono samples (FR-A21-405).
///
/// With `N = seconds × sampleRate`, sample `i` is `s(i) × Σ aₖ sin(2π cₖ i / N)` for the partials `(cₖ, aₖ)`, where the
/// swell is `s(i) = 0.65 − 0.35 cos(2π m i / N)` for `m` swell cycles (from 0.3 to 1, never silent). Phases are taken
/// from `(c × i) mod N` stepped in integers, so they are exact. The buffer is then scaled so its largest magnitude equals
/// the gain and clamped to ±gain. Because every period divides `N`, sample `N` would equal sample 0: the step from the
/// last sample to the first is one of the signal's own steps. The same recipe always gives the same samples.
public enum AmbientLoopSynth {
    /// Renders `recipe`.
    /// - Returns: ``AmbientLoopRecipe/sampleCount`` samples, every one finite and within ±gain; an empty buffer when
    ///   the recipe is invalid.
    public static func render(_ recipe: AmbientLoopRecipe) -> [Float] {
        guard recipe.isValid else { return [] }
        let count = recipe.sampleCount
        let length = Double(count)
        var raw = [Double](repeating: 0, count: count)
        for partial in recipe.partials where partial.amplitude > 0 {
            let cycles = partial.cyclesPerLoop % count
            var position = 0
            for index in 0..<count {
                raw[index] += partial.amplitude * sin(2 * Double.pi * Double(position) / length)
                position += cycles
                if position >= count { position -= count }
            }
        }
        var peak = 0.0
        let swellCycles = recipe.swellCycles % count
        var swellPosition = 0
        for index in 0..<count {
            let swell = 0.65 - 0.35 * cos(2 * Double.pi * Double(swellPosition) / length)
            raw[index] *= swell
            peak = max(peak, abs(raw[index]))
            swellPosition += swellCycles
            if swellPosition >= count { swellPosition -= count }
        }
        guard peak > 0, peak.isFinite else { return [Float](repeating: 0, count: count) }
        let scale = recipe.gain / peak
        let gain = Float(recipe.gain)
        return raw.map { min(gain, max(-gain, Float($0 * scale))) }
    }
}
