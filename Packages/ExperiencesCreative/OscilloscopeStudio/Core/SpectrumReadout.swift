// SpectrumReadout — feature 063 (A08-P03) T-A08-302 (FR-A08-301, FR-A08-303, FR-A08-320; SC-A08-301, SC-A08-302;
// clarification 3; data-model "SpectrumReadout"). The peak readout of the spectrum view, host-free: the strongest bin
// of a 4,096-point analysis named by its frequency (bin × rate ÷ 4,096, rounded to 1 Hz) and its level in dB relative
// to full scale (rounded to 0.1 dB). A value is given only when it is valid; otherwise the readout names why not, in
// this order: the frame is still filling, the analysed samples clip, or the strongest bin is below −100 dBFS. Levels
// are never called sound pressure, volts or calibrated: the words are always "dBFS, relative to full scale".
import Foundation
import VisualCoreAudioDSP

/// The peak readout of the spectrum view: a frequency and level, or the reason none is shown.
public struct SpectrumReadout: Sendable, Equatable {
    /// Whether the readout carries a value, and why not when it does not.
    public enum Validity: Sendable, Equatable {
        /// The strongest bin is named by its frequency and level.
        case valid
        /// The strongest bin lies below −100 dBFS (``SpectrumAnalyzer/peakBin(_:)`` is nil).
        case noSignal
        /// An analysed sample reached full scale (|x| ≥ 1), so the level is not valid.
        case clipping
        /// Fewer than ``SpectrumReadout/frameSize`` frames have been written; the frame is zero-padded.
        case filling
    }

    /// The analysis size in frames (the newest 4,096 frames of the left or only channel).
    public static let frameSize = 4_096

    /// Whether a value is shown.
    public let validity: Validity
    /// The peak frequency in hertz, rounded to 1 Hz; `nil` unless ``validity`` is `.valid`.
    public let frequency: Double?
    /// The peak level in dB relative to full scale, rounded to 0.1 dB; `nil` unless ``validity`` is `.valid`.
    public let levelDB: Double?
    /// The width of one bin in hertz (sample rate ÷ 4,096), the frequency resolution of the readout.
    public let binWidth: Double

    /// The readout of one analysis.
    /// - Parameters:
    ///   - magnitudesDB: the output of `SpectrumAnalyzer(size: 4096).magnitudesDB` for `samples`.
    ///   - samples: the analysed time-domain samples (checked for clipping).
    ///   - sampleRate: the sample rate of the samples in hertz.
    ///   - writtenFrames: how many frames the acquisition has written in total.
    /// - Returns: `.filling` when `writtenFrames` < 4,096; else `.clipping` when any |sample| ≥ 1; else `.noSignal`
    ///   when ``SpectrumAnalyzer/peakBin(_:)`` is nil; else `.valid` with the bin's frequency and level.
    public static func make(magnitudesDB: [Float], samples: [Float], sampleRate: Double,
                            writtenFrames: Int) -> SpectrumReadout {
        let binWidth = sampleRate / Double(frameSize)
        if writtenFrames < frameSize { return SpectrumReadout(validity: .filling, binWidth: binWidth) }
        if samples.contains(where: { abs($0) >= 1 }) { return SpectrumReadout(validity: .clipping, binWidth: binWidth) }
        guard let bin = SpectrumAnalyzer.peakBin(magnitudesDB) else {
            return SpectrumReadout(validity: .noSignal, binWidth: binWidth)
        }
        let frequency = (Double(bin) * binWidth).rounded()
        var level = (Double(magnitudesDB[bin]) * 10).rounded() / 10
        if level == 0 { level = 0 }   // −0.0 reads as 0.0
        return SpectrumReadout(validity: .valid, frequency: frequency, levelDB: level, binWidth: binWidth)
    }

    private init(validity: Validity, frequency: Double? = nil, levelDB: Double? = nil, binWidth: Double) {
        self.validity = validity
        self.frequency = frequency
        self.levelDB = levelDB
        self.binWidth = binWidth
    }

    /// The readout as shown and spoken: "peak 1,000 Hz at −6.0 dBFS, relative to full scale" when valid (thousands
    /// grouped with a comma, negative levels with the minus sign U+2212), else "no signal", "clipping, level not
    /// valid" or "filling".
    public var text: String {
        switch validity {
        case .filling: return "filling"
        case .clipping: return "clipping, level not valid"
        case .noSignal: return "no signal"
        case .valid:
            guard let frequency, let levelDB else { return "no signal" }
            return "peak \(Self.grouped(Int(frequency))) Hz at \(Self.level(levelDB)) dBFS, relative to full scale"
        }
    }

    /// `value` with a comma between groups of three digits ("1,000", "12,345").
    static func grouped(_ value: Int) -> String {
        let digits = String(value.magnitude)
        var out = ""
        for (i, ch) in digits.enumerated() {
            if i > 0, (digits.count - i) % 3 == 0 { out.append(",") }
            out.append(ch)
        }
        return value < 0 ? "−" + out : out
    }

    /// `value` with one decimal, negative values with the minus sign U+2212 ("−6.0", "0.0").
    static func level(_ value: Double) -> String {
        let text = String(format: "%.1f", abs(value))
        return value < 0 && text != "0.0" ? "−" + text : text
    }
}
