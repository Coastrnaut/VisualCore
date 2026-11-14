// TestSignal — feature 061 (A08-P01) T-A08-102 (FR-A08-101, FR-A08-104); gap G-DEMOWAVES.
// Spec Clarifications (new types beside DemoSignal); data-model.md; contract specs/061-os-p01-acquisition/contracts/api.md.
import Foundation

/// A deterministic sine, square or logarithmic-sweep test signal with an optional second channel.
///
/// Every sample is a closed-form function of its frame index (``value(atFrame:channel:)``), so identical settings
/// always give identical samples however the output is split into ``render(frames:left:right:)`` calls. Phases are
/// computed in `Double` from the frame index, which keeps the signal exact over arbitrarily long runs.
///
/// The second channel (``channelCount`` 2) plays ``rightRatio`` × the frequency (for a sweep: both ends of the sweep)
/// with an extra phase offset of ``rightPhase`` radians.
public struct TestSignal: Sendable, Equatable {
    /// The waveform the signal plays.
    public enum Waveform: Int, Sendable, CaseIterable {
        /// `a · sin(2π f t + φ)`.
        case sine
        /// `+a` while the sine's phase gives a value ≥ 0, else `−a`. Naive, not band-limited: aliasing is expected
        /// and acceptable for a scope test signal.
        case square
        /// A logarithmic sweep `f(t) = f0 · (f1/f0)^(t/T)` with exactly integrated phase, looping every `T` seconds.
        case sweep
    }

    /// Default amplitude (−6 dBFS).
    public static let defaultAmplitude = 0.5
    /// Default sample rate in Hz.
    public static let defaultSampleRate = 48_000.0
    /// Default sweep end frequency in Hz.
    public static let defaultSweepEnd = 10_000.0
    /// Default sweep duration in seconds.
    public static let defaultSweepDuration = 2.0
    /// Default frequency in Hz, used when a non-finite frequency is passed.
    public static let defaultFrequency = 1_000.0
    /// Allowed frequency range in Hz (sine and square frequency, sweep start and end).
    public static let frequencyRange = 20.0...20_000.0
    /// Allowed right-channel frequency ratio.
    public static let rightRatioRange = 0.01...100.0
    /// Allowed sample rate range in Hz.
    public static let sampleRateRange = 1_000.0...768_000.0
    /// Allowed sweep duration range in seconds.
    public static let sweepDurationRange = 0.001...3_600.0

    /// The waveform.
    public let waveform: Waveform
    /// Frequency in Hz (the sweep's start frequency), 20…20,000.
    public let frequency: Double
    /// Peak amplitude, 0…1.
    public let amplitude: Double
    /// Samples per second.
    public let sampleRate: Double
    /// Number of channels rendered, 1 or 2.
    public let channelCount: Int
    /// Right-channel frequency divided by left-channel frequency, 0.01…100.
    public let rightRatio: Double
    /// Right-channel phase offset in radians.
    public let rightPhase: Double
    /// Sweep end frequency in Hz, 20…20,000 (sweep only).
    public let sweepEnd: Double
    /// Sweep duration in seconds; the sweep loops after this time (sweep only).
    public let sweepDuration: Double
    /// Index of the next frame ``render(frames:left:right:)`` produces.
    public private(set) var framePosition: Int = 0

    /// Creates a test signal. Values are clamped to their ranges; non-finite values fall back to the defaults.
    ///
    /// - Parameters:
    ///   - waveform: sine, square or sweep.
    ///   - frequency: Hz, clamped to 20…20,000 (sweep start for ``Waveform/sweep``).
    ///   - amplitude: peak amplitude, clamped to 0…1.
    ///   - sampleRate: Hz, clamped to 1,000…768,000.
    ///   - channelCount: clamped to 1…2.
    ///   - rightRatio: right/left frequency ratio, clamped to 0.01…100.
    ///   - rightPhase: right-channel phase offset in radians.
    ///   - sweepEnd: sweep end frequency in Hz, clamped to 20…20,000.
    ///   - sweepDuration: sweep length in seconds, clamped to 0.001…3,600.
    public init(waveform: Waveform, frequency: Double = TestSignal.defaultFrequency,
                amplitude: Double = TestSignal.defaultAmplitude, sampleRate: Double = TestSignal.defaultSampleRate,
                channelCount: Int = 1, rightRatio: Double = 1, rightPhase: Double = 0,
                sweepEnd: Double = TestSignal.defaultSweepEnd, sweepDuration: Double = TestSignal.defaultSweepDuration) {
        func clamp(_ v: Double, _ r: ClosedRange<Double>, _ fallback: Double) -> Double {
            v.isFinite ? min(max(v, r.lowerBound), r.upperBound) : fallback
        }
        self.waveform = waveform
        self.frequency = clamp(frequency, Self.frequencyRange, Self.defaultFrequency)
        self.amplitude = clamp(amplitude, 0...1, Self.defaultAmplitude)
        self.sampleRate = clamp(sampleRate, Self.sampleRateRange, Self.defaultSampleRate)
        self.channelCount = min(max(channelCount, 1), 2)
        self.rightRatio = clamp(rightRatio, Self.rightRatioRange, 1)
        self.rightPhase = rightPhase.isFinite ? rightPhase : 0
        self.sweepEnd = clamp(sweepEnd, Self.frequencyRange, Self.defaultSweepEnd)
        self.sweepDuration = clamp(sweepDuration, Self.sweepDurationRange, Self.defaultSweepDuration)
    }

    /// The sample at `frame` on `channel` (closed form).
    ///
    /// Channel 1 is the right channel only when ``channelCount`` is 2; otherwise every channel returns the left one.
    /// - Parameters:
    ///   - frame: absolute frame index from the start of the signal (negative frames are allowed).
    ///   - channel: 0 (left) or 1 (right).
    /// - Returns: the sample value.
    public func value(atFrame frame: Int, channel: Int) -> Float {
        let right = channel == 1 && channelCount == 2
        let ratio = right ? rightRatio : 1
        let offset = right ? rightPhase : 0
        let phase: Double
        switch waveform {
        case .sine, .square:
            phase = 2 * .pi * Self.cycleFraction(frequency: frequency * ratio, frame: frame, sampleRate: sampleRate)
                + offset
        case .sweep:
            let t = Double(frame) / sampleRate
            var tm = t.truncatingRemainder(dividingBy: sweepDuration)
            if tm < 0 { tm += sweepDuration }
            let f0 = frequency * ratio
            let k = log(sweepEnd / frequency)
            let cycles: Double
            if abs(k) < 1e-12 {
                cycles = f0 * tm
            } else {
                cycles = f0 * sweepDuration / k * (exp(k * tm / sweepDuration) - 1)
            }
            phase = 2 * .pi * (cycles - cycles.rounded(.down)) + offset
        }
        let s = sin(phase)
        switch waveform {
        case .sine, .sweep: return Float(amplitude * s)
        case .square: return Float(s >= 0 ? amplitude : -amplitude)
        }
    }

    /// Renders the next `frames` frames and advances ``framePosition``.
    ///
    /// `left` is resized to exactly `frames` elements (no allocation when it already has that size or capacity) and
    /// filled with channel 0. When ``channelCount`` is 2, `right` is resized the same way and filled with channel 1;
    /// for a mono signal `right` is left untouched. `frames` ≤ 0 renders nothing.
    /// - Parameters:
    ///   - frames: the number of frames to render.
    ///   - left: receives the left channel.
    ///   - right: receives the right channel (stereo only).
    public mutating func render(frames: Int, left: inout [Float], right: inout [Float]) {
        guard frames > 0 else { return }
        Self.resize(&left, to: frames)
        let start = framePosition
        for i in 0..<frames { left[i] = value(atFrame: start + i, channel: 0) }
        if channelCount == 2 {
            Self.resize(&right, to: frames)
            for i in 0..<frames { right[i] = value(atFrame: start + i, channel: 1) }
        }
        framePosition = start + frames
    }

    /// The number of periods of `frequency` that fit into `sampleCount` samples at `sampleRate`.
    ///
    /// - Returns: `frequency × sampleCount / sampleRate`, or 0 when the sample rate is not positive and finite.
    public static func periods(frequency: Double, sampleCount: Int, sampleRate: Double) -> Double {
        guard sampleRate.isFinite, sampleRate > 0 else { return 0 }
        return frequency * Double(sampleCount) / sampleRate
    }

    /// Fractional part of `frequency × frame / sampleRate`, computed so that large frame indices stay exact.
    private static func cycleFraction(frequency: Double, frame: Int, sampleRate: Double) -> Double {
        // Split the frame index so that the product stays well inside Double's exact range.
        let block = 1 << 20
        let high = Double(frame / block) * Double(block)
        let low = Double(frame % block)
        var a = (frequency * high / sampleRate).truncatingRemainder(dividingBy: 1)
        a += (frequency * low / sampleRate).truncatingRemainder(dividingBy: 1)
        let f = a - a.rounded(.down)
        return f
    }

    private static func resize(_ array: inout [Float], to count: Int) {
        if array.count < count {
            array.append(contentsOf: repeatElement(0, count: count - array.count))
        } else if array.count > count {
            array.removeLast(array.count - count)
        }
    }
}
