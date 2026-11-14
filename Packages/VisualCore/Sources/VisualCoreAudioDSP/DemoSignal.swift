// DemoSignal — feature 047 (A06-P01) T-A06-102; gap G-DEMOSIGNAL (and G-AUDIODSP, minimal).
// Spec Clarifications (demo source); contract specs/047-ml-p01-audio-source/contracts/api.md.
import Foundation

/// A seeded, deterministic test signal generated on the fly: no file and no permission.
///
/// The same seed, mode and sample rate always produce the same samples, however the output is split into
/// ``render(into:)`` calls, because every sample advances the state by exactly one step.
public struct DemoSignal: Sendable {
    /// What the signal plays.
    public enum Mode: Int, Sendable, CaseIterable {
        /// Sine notes on a pentatonic scale at −12 dBFS, one note per half second in a seeded order, plus seeded
        /// noise at −40 dBFS.
        case sequence
        /// A pure 440 Hz sine of amplitude 0.5.
        case tone440
        /// A pure 1,000 Hz sine of amplitude 0.5.
        case tone1k
        /// Digital silence.
        case silence
    }

    /// Note amplitude of ``Mode/sequence`` (−12 dBFS).
    public static let sequenceAmplitude: Float = 0.251
    /// Noise amplitude of ``Mode/sequence`` (−40 dBFS).
    public static let noiseAmplitude: Float = 0.01
    /// Amplitude of the pure tones.
    public static let toneAmplitude: Float = 0.5
    /// Duration of one note of ``Mode/sequence`` in seconds.
    public static let noteDuration = 0.5
    /// The note frequencies of ``Mode/sequence``: A minor pentatonic, A3…D5 (Hz, equal temperament).
    public static let pentatonic: [Double] = [57, 60, 62, 64, 67, 69, 72, 74].map { 440 * pow(2, (Double($0) - 69) / 12) }

    /// The seed the signal was created with.
    public let seed: UInt64
    /// The mode the signal plays.
    public let mode: Mode
    /// Samples per second.
    public let sampleRate: Double

    private var phase = 0.0
    private var frequency: Double
    private var samplesLeftInNote = 0
    private let samplesPerNote: Int
    private var noteRNG: SplitMix64
    private var noiseRNG: SplitMix64

    /// Creates a signal.
    /// - Parameters:
    ///   - seed: chooses the note order and the noise of ``Mode/sequence``.
    ///   - mode: what to play.
    ///   - sampleRate: samples per second (positive; 48,000 by default).
    public init(seed: UInt64, mode: Mode, sampleRate: Double = 48_000) {
        self.seed = seed
        self.mode = mode
        self.sampleRate = sampleRate > 0 ? sampleRate : 48_000
        self.samplesPerNote = max(1, Int((self.sampleRate * Self.noteDuration).rounded()))
        self.noteRNG = SplitMix64(seed: seed)
        self.noiseRNG = SplitMix64(seed: seed ^ 0x9E37_79B9_7F4A_7C15)
        switch mode {
        case .tone440: frequency = 440
        case .tone1k: frequency = 1_000
        case .sequence, .silence: frequency = 0
        }
    }

    /// Fills `out` with the next samples, continuing exactly where the previous call stopped.
    /// - Parameter out: the destination; every element is written.
    public mutating func render(into out: UnsafeMutableBufferPointer<Float>) {
        let twoPi = 2 * Double.pi
        switch mode {
        case .silence:
            for i in out.indices { out[i] = 0 }
        case .tone440, .tone1k:
            let step = twoPi * frequency / sampleRate
            for i in out.indices {
                out[i] = Self.toneAmplitude * Float(sin(phase))
                phase += step
                if phase >= twoPi { phase -= twoPi }
            }
        case .sequence:
            let notes = Self.pentatonic
            for i in out.indices {
                if samplesLeftInNote == 0 {
                    frequency = notes[Int(noteRNG.next() % UInt64(notes.count))]
                    samplesLeftInNote = samplesPerNote
                }
                samplesLeftInNote -= 1
                let noise = Float(Double(noiseRNG.next() >> 11) / Double(1 << 53) * 2 - 1)
                out[i] = Self.sequenceAmplitude * Float(sin(phase)) + Self.noiseAmplitude * noise
                phase += twoPi * frequency / sampleRate
                if phase >= twoPi { phase -= twoPi }
            }
        }
    }
}

/// SplitMix64 (Steele, Lea and Flood 2014): a small, fast, seedable generator. Local so that this module depends on
/// nothing.
struct SplitMix64: Sendable {
    private var state: UInt64

    /// Creates a generator from `seed`.
    init(seed: UInt64) { state = seed }

    /// Returns the next 64-bit value.
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
