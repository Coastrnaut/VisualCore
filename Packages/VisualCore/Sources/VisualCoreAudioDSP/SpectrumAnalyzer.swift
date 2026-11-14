// SpectrumAnalyzer — feature 047 (A06-P01) T-A06-102; gap G-AUDIODSP (minimal: transform and peak bin only; bands,
// RMS and onsets are Phase 02). Research D2; contract specs/047-ml-p01-audio-source/contracts/api.md.
import Accelerate

/// Magnitude spectrum of a Hann-windowed frame with Accelerate's real FFT, in dB relative to full scale.
///
/// A full-scale sine (amplitude 1) centred on a bin reads about 0 dB in that bin.
public struct SpectrumAnalyzer: Sendable {
    /// Smallest supported frame size.
    public static let minimumSize = 256
    /// Largest supported frame size.
    public static let maximumSize = 4_096
    /// The floor of every magnitude in dB (returned for exact zeros).
    public static let floorDB: Float = -200
    /// Bins whose maximum lies below this level count as silence in ``peakBin(_:)``.
    public static let silenceThresholdDB: Float = -100

    /// Frame size N in samples (a power of two, 256…4,096).
    public let size: Int
    private let log2n: vDSP_Length
    private let window: [Float]
    private let setup: FFTSetupBox

    /// Creates an analyser for frames of `size` samples, or `nil` when `size` is not a power of two in 256…4,096.
    public init?(size: Int) {
        guard size >= Self.minimumSize, size <= Self.maximumSize, size & (size - 1) == 0 else { return nil }
        let log2n = vDSP_Length(size.trailingZeroBitCount)
        guard let box = FFTSetupBox(log2n: log2n) else { return nil }
        self.size = size
        self.log2n = log2n
        self.window = vDSP.window(ofType: Float.self, usingSequence: .hanningDenormalized, count: size, isHalfWindow: false)
        self.setup = box
    }

    /// Returns N/2 magnitudes in dB: bin k covers the frequency k·fs/N, bin 0 is the DC component.
    ///
    /// Each magnitude is 20·log10(|X[k]| / (N/2 · g)), where g = 0.5 is the coherent gain of the Hann window, floored
    /// at ``floorDB``. A frame shorter than N is padded with zeros, a longer one is cut to its first N samples.
    /// - Parameter frame: the time-domain samples.
    public func magnitudesDB(_ frame: [Float]) -> [Float] {
        let n = size
        let half = n / 2
        var input = [Float](repeating: 0, count: n)
        let used = min(frame.count, n)
        if used > 0 {
            input.withUnsafeMutableBufferPointer { dst in
                frame.withUnsafeBufferPointer { src in dst.baseAddress!.update(from: src.baseAddress!, count: used) }
            }
        }
        let windowed = vDSP.multiply(input, window)

        var real = [Float](repeating: 0, count: half)
        var imag = [Float](repeating: 0, count: half)
        var result = [Float](repeating: Self.floorDB, count: half)
        // vDSP_fft_zrip returns twice the DFT; the window's coherent gain is 0.5.
        let scale = 1 / (2 * Float(half) * 0.5)
        real.withUnsafeMutableBufferPointer { rp in
            imag.withUnsafeMutableBufferPointer { ip in
                var split = DSPSplitComplex(realp: rp.baseAddress!, imagp: ip.baseAddress!)
                windowed.withUnsafeBufferPointer { ib in
                    ib.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: half) { complex in
                        vDSP_ctoz(complex, 2, &split, 1, vDSP_Length(half))
                    }
                }
                vDSP_fft_zrip(setup.setup, &split, 1, log2n, FFTDirection(kFFTDirection_Forward))
                for k in 0..<half {
                    // Bin 0 packs DC in realp[0] and Nyquist in imagp[0]; only DC is reported.
                    let magnitude = k == 0 ? abs(rp[0]) * scale * 0.5 : (rp[k] * rp[k] + ip[k] * ip[k]).squareRoot() * scale
                    if magnitude > 0 { result[k] = max(Self.floorDB, 20 * log10(magnitude)) }
                }
            }
        }
        return result
    }

    /// The bin with the largest magnitude among bins 1…N/2−1, or `nil` when that maximum is below −100 dB (silence)
    /// or there are fewer than two bins.
    /// - Parameter magnitudesDB: output of ``magnitudesDB(_:)``.
    public static func peakBin(_ magnitudesDB: [Float]) -> Int? {
        guard magnitudesDB.count >= 2 else { return nil }
        var best = 1
        for k in 1..<magnitudesDB.count where magnitudesDB[k] > magnitudesDB[best] { best = k }
        return magnitudesDB[best] < silenceThresholdDB ? nil : best
    }

    /// The bin nearest to `frequency`: `Int((frequency · size / sampleRate).rounded())`.
    public static func expectedBin(frequency: Double, sampleRate: Double, size: Int) -> Int {
        Int((frequency * Double(size) / sampleRate).rounded())
    }
}

/// Owns a vDSP FFT setup for the life of every analyser copy that shares it.
///
/// `@unchecked Sendable`: the setup is created once, only read by `vDSP_fft_zrip` (which Accelerate allows from
/// several threads at once) and destroyed in `deinit`.
private final class FFTSetupBox: @unchecked Sendable {
    let setup: FFTSetup

    init?(log2n: vDSP_Length) {
        guard let s = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2)) else { return nil }
        setup = s
    }

    deinit { vDSP_destroy_fftsetup(setup) }
}
