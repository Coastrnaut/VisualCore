// SoundEffect — feature 077 (A10-P03) T-A10-302 (FR-A10-301, FR-A10-302; gap G-SOUNDFX; research D1): short sound
// effects described by a few numbers and synthesised by code — an exponential frequency sweep of a sine, triangle or
// square wave, mixed with seeded noise, under a linear attack and release. Pure and deterministic: no files, no
// randomness that differs between runs.
import Foundation

/// The periodic waveform of a ``SoundEffect``.
public enum SoundWaveform: String, Sendable, Codable, CaseIterable {
    /// A sine wave.
    case sine
    /// A symmetric triangle wave (rises from zero through the first quarter of each cycle).
    case triangle
    /// A square wave (+1 for the first half of each cycle, −1 for the second).
    case square
}

/// A synthesised sound effect: a waveform sweeping exponentially from ``startFrequency`` to ``endFrequency`` over
/// ``duration``, mixed with seeded noise and shaped by a linear attack and release (FR-A10-301).
///
/// Use ``isValid`` to check the limits; ``SoundEffectSynth/render(_:sampleRate:)`` renders an invalid effect as an
/// empty buffer.
public struct SoundEffect: Sendable, Equatable, Codable {
    /// Allowed start and end frequencies in hertz.
    public static let frequencyRange: ClosedRange<Double> = 40...4_000
    /// Allowed durations in seconds.
    public static let durationRange: ClosedRange<Double> = 0.02...1
    /// Shortest allowed attack or release in seconds (2 ms, so the effect never clicks).
    public static let minimumFade = 0.002
    /// Allowed noise amounts (0 = pure waveform, 1 = pure noise).
    public static let noiseRange: ClosedRange<Double> = 0...1
    /// Allowed peak gains (linear amplitude).
    public static let gainRange: ClosedRange<Double> = 0...0.9

    /// The periodic waveform.
    public var waveform: SoundWaveform
    /// Frequency at the start, in hertz (40…4,000).
    public var startFrequency: Double
    /// Frequency at the end, in hertz (40…4,000); the frequency moves exponentially from start to end.
    public var endFrequency: Double
    /// Length in seconds (0.02…1).
    public var duration: Double
    /// Linear fade-in time in seconds (at least 0.002).
    public var attack: Double
    /// Linear fade-out time in seconds (at least 0.002).
    public var release: Double
    /// Share of seeded noise mixed into the waveform (0…1).
    public var noise: Double
    /// Peak amplitude (0…0.9); every rendered sample stays within ±gain.
    public var gain: Double

    /// Creates an effect; the values are stored as given and checked by ``isValid``.
    /// - Parameters:
    ///   - waveform: the periodic waveform.
    ///   - startFrequency: frequency at the start in hertz (40…4,000).
    ///   - endFrequency: frequency at the end in hertz (40…4,000).
    ///   - duration: length in seconds (0.02…1).
    ///   - attack: linear fade-in in seconds (≥ 0.002; 5 ms by default).
    ///   - release: linear fade-out in seconds (≥ 0.002; 20 ms by default).
    ///   - noise: noise share (0…1; none by default).
    ///   - gain: peak amplitude (0…0.9; 0.5 by default).
    public init(waveform: SoundWaveform, startFrequency: Double, endFrequency: Double, duration: Double,
                attack: Double = 0.005, release: Double = 0.02, noise: Double = 0, gain: Double = 0.5) {
        self.waveform = waveform
        self.startFrequency = startFrequency
        self.endFrequency = endFrequency
        self.duration = duration
        self.attack = attack
        self.release = release
        self.noise = noise
        self.gain = gain
    }

    /// Whether every value is finite and within its limits (frequencies, duration, fades, noise and gain).
    public var isValid: Bool {
        Self.frequencyRange.contains(startFrequency) && Self.frequencyRange.contains(endFrequency)
            && Self.durationRange.contains(duration)
            && attack.isFinite && attack >= Self.minimumFade
            && release.isFinite && release >= Self.minimumFade
            && Self.noiseRange.contains(noise) && Self.gainRange.contains(gain)
    }
}

/// Renders ``SoundEffect``s to mono samples (FR-A10-301; research D1).
///
/// Per sample, the phase advances by the instantaneous frequency `start × (end / start)^(t / duration)` divided by
/// the sample rate; the waveform value is mixed with noise as `(1 − noise) × wave + noise × n`, where `n` comes from
/// a xorshift generator seeded by ``noiseSeed(_:)``; the result is multiplied by `gain × envelope` and clamped to
/// ±gain. The envelope is `min(1, i / attackSamples, (count − 1 − i) / releaseSamples)`, so the first and last samples
/// are exactly zero (overlapping fades meet in a triangle). The same effect and rate always give the same samples.
public enum SoundEffectSynth {
    /// The default sample rate in hertz.
    public static let defaultSampleRate = 48_000.0

    /// Renders `effect` at `sampleRate`.
    /// - Returns: `round(duration × sampleRate)` samples, every one finite and within ±gain; an empty buffer when the
    ///   effect is invalid or the sample rate is not a positive finite number.
    public static func render(_ effect: SoundEffect, sampleRate: Double = defaultSampleRate) -> [Float] {
        guard effect.isValid, sampleRate.isFinite, sampleRate > 0 else { return [] }
        let count = Int((effect.duration * sampleRate).rounded())
        guard count > 0 else { return [] }
        let gain = Float(effect.gain)
        let noise = Float(effect.noise)
        let attackSamples = max(1, effect.attack * sampleRate)
        let releaseSamples = max(1, effect.release * sampleRate)
        let ratio = effect.endFrequency / effect.startFrequency
        var generator = XorShift64(seed: noiseSeed(effect))
        var phase = 0.0
        var output = [Float](repeating: 0, count: count)
        for index in 0..<count {
            let time = Double(index) / sampleRate
            let wave = Float(waveValue(effect.waveform, phase: phase))
            let mixed = noise > 0 ? (1 - noise) * wave + noise * generator.nextBipolar() : wave
            let envelope = min(1, Double(index) / attackSamples, Double(count - 1 - index) / releaseSamples)
            let sample = mixed * gain * Float(max(0, envelope))
            output[index] = min(gain, max(-gain, sample))
            let frequency = effect.startFrequency * pow(ratio, time / effect.duration)
            phase += frequency / sampleRate
            phase -= phase.rounded(.down)
        }
        return output
    }

    /// The noise seed of `effect`: FNV-1a over the bit patterns of every field (waveform name included), so it is
    /// stable across runs and processes and differs for different effects. Never zero.
    public static func noiseSeed(_ effect: SoundEffect) -> UInt64 {
        var hash: UInt64 = 0xCBF2_9CE4_8422_2325
        func mix(_ value: UInt64) {
            for shift in stride(from: 0, to: 64, by: 8) {
                hash ^= (value >> UInt64(shift)) & 0xFF
                hash = hash &* 0x0000_0100_0000_01B3
            }
        }
        for byte in effect.waveform.rawValue.utf8 { mix(UInt64(byte)) }
        for value in [effect.startFrequency, effect.endFrequency, effect.duration, effect.attack, effect.release,
                      effect.noise, effect.gain] {
            mix(value.bitPattern)
        }
        return hash == 0 ? 0x9E37_79B9_7F4A_7C15 : hash
    }

    /// The waveform value at `phase` (0 ≤ phase < 1), in −1…1.
    static func waveValue(_ waveform: SoundWaveform, phase: Double) -> Double {
        switch waveform {
        case .sine:
            return sin(2 * Double.pi * phase)
        case .triangle:
            if phase < 0.25 { return 4 * phase }
            if phase < 0.75 { return 2 - 4 * phase }
            return 4 * phase - 4
        case .square:
            return phase < 0.5 ? 1 : -1
        }
    }
}

/// Marsaglia's xorshift64 generator; the fixed noise source of ``SoundEffectSynth`` (internal).
struct XorShift64: Sendable {
    private var state: UInt64

    /// Creates a generator; a zero seed is replaced by a fixed non-zero constant.
    init(seed: UInt64) { state = seed == 0 ? 0x9E37_79B9_7F4A_7C15 : seed }

    /// Returns the next 64-bit value.
    mutating func next() -> UInt64 {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }

    /// Returns the next value uniformly spread over −1…1 (24-bit resolution).
    mutating func nextBipolar() -> Float {
        Float(next() >> 40) / Float(1 << 23) - 1
    }
}
