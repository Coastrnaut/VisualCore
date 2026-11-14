// ScopeAccuracyAudit — feature 065 (A08-P05) T-A08-504 (FR-A08-510; SC-A08-501; story 1 scenarios 1–4; clarification 2;
// research D2; data-model "AccuracyReport"); gap G-ACCURACY. Runs every demo waveform through the scope's real path and
// compares each readout with the generator's defining values:
//   generator (`TestSignal`, the presenter's `testSignal(for:)` at 48 kHz, the same signal at 44.1 kHz)
//   → `StereoSampleBuffer` (rendered in 512-frame blocks, as a source writes it)
//   → `ScopeAcquisition` (trigger at level 0, rising, auto; the window of the state's timebase)
//   → cursors one period apart (`ScopeReadout.time`; the second crossing found with `ScopeTrigger.find`)
//   → the newest 4,096 frames of the left channel → `SpectrumAnalyzer(size: 4096)` → `SpectrumReadout`.
// Cases (clarification 2): sine 100 Hz, 440 Hz, 1 kHz, 5 kHz at 48 kHz; sine 440 Hz and 1 kHz at 44.1 kHz (the
// delivered rate of many routes); square 440 Hz and 1 kHz; the sweep (100 Hz → 10 kHz over 2 s) sampled at 0.5 s, 1 s
// and 1.5 s.
// Tolerances:
//   - spectrum peak frequency: one bin (sample rate ÷ 4,096); the readout is rounded to 1 Hz, far below a bin;
//   - sine level: 1.5 dB around 20·log10(amplitude). The Hann window's scalloping loss is at most 1.42 dB at half a bin
//     off centre and the readout is rounded to 0.1 dB, so 1.5 dB holds at any frequency;
//   - square fundamental level: 1.5 dB around 20·log10(4 · amplitude ÷ π) (the fundamental of an ideal square of peak
//     `amplitude`), for the same reason;
//   - cursor period: one sample around sample rate ÷ frequency (crossings land on whole samples);
//   - square extremes: ±0.50 of full scale within 0.005 (the readout's two decimals);
//   - sweep: the peak lies within the frequencies the generator plays at the analysed frame's first and last sample,
//     widened by one bin on each side (the analysed frame spans a range of frequencies, 4,096 samples ≈ 85 ms), and the
//     peaks rise from 0.5 s to 1 s to 1.5 s;
//   - wording: every spectrum readout says "relative to full scale", and no readout says "calibrated", "certified",
//     "laboratory" or "medical".
// Short by design: about 140,000 generated frames in all, a few FFTs, no wall clock.
import Foundation
import OscilloscopeStudioCore
import VisualCoreAudioDSP

/// The result of the accuracy audit: one entry per compared quantity.
struct AccuracyReport: Sendable, Equatable {
    /// What an entry compares.
    enum Quantity: String, Sendable, Equatable {
        /// The spectrum peak frequency in hertz.
        case peakFrequency
        /// The spectrum peak level in dB relative to full scale.
        case peakLevel
        /// The period between cursors on consecutive rising crossings, in samples.
        case cursorPeriod
        /// The largest sample of the window in full scale.
        case maximum
        /// The smallest sample of the window in full scale.
        case minimum
        /// The readout words (expected 1 = the required words present and no forbidden word; measured 1 or 0).
        case wording
        /// The sweep peaks rising from one sampling time to the next (expected 1; measured 1 or 0).
        case rising
    }

    /// One compared quantity of one case.
    struct Entry: Sendable, Equatable {
        /// The case, e.g. "sine 440 Hz at 48 kHz" or "sweep at 1.5 s".
        let name: String
        /// The quantity compared.
        let quantity: Quantity
        /// The generator's defining value (for the sweep's peak frequency: the centre of the allowed range).
        let expected: Double
        /// The value the scope's path read.
        let measured: Double
        /// The allowed absolute difference between `measured` and `expected`.
        let tolerance: Double
        /// The readout text the measurement came from (as shown and spoken).
        let readout: String
        /// Whether `measured` lies within `tolerance` of `expected`.
        let pass: Bool
    }

    /// Every entry in audit order.
    let cases: [Entry]

    /// Whether every entry passes (false for an empty report).
    var allPass: Bool { !cases.isEmpty && cases.allSatisfy(\.pass) }

    /// The fraction of entries that pass, 0…1 (0 for an empty report).
    var passRate: Double {
        cases.isEmpty ? 0 : Double(cases.filter(\.pass).count) / Double(cases.count)
    }

    /// The entries of the case `name`.
    func entries(named name: String) -> [Entry] { cases.filter { $0.name == name } }

    /// The entries comparing `quantity`.
    func entries(_ quantity: Quantity) -> [Entry] { cases.filter { $0.quantity == quantity } }
}

/// Runs the demo waveforms through acquisition, trigger, window, cursors and spectrum and builds an `AccuracyReport`.
enum ScopeAccuracyAudit {
    /// The words every spectrum readout must contain.
    static let requiredWords = "relative to full scale"
    /// Words no readout may contain (no claim of calibrated, certified, laboratory or medical accuracy).
    static let forbiddenWords = ["calibrated", "certified", "laboratory", "medical"]
    /// The sine frequencies audited at 48 kHz (the scope's frequency table).
    static let sineFrequencies48k: [Double] = [100, 440, 1_000, 5_000]
    /// The sine frequencies audited at 44.1 kHz.
    static let sineFrequencies44k: [Double] = [440, 1_000]
    /// The square frequencies audited at 48 kHz.
    static let squareFrequencies: [Double] = [440, 1_000]
    /// The sweep sampling times in seconds of source time.
    static let sweepTimes: [Double] = [0.5, 1.0, 1.5]
    /// The level tolerance in dB.
    static let levelToleranceDB = 1.5
    /// The cursor period tolerance in samples.
    static let periodToleranceSamples = 1.0
    /// The extremes' tolerance in full scale (the level readout's two decimals).
    static let extremeTolerance = 0.005
    /// Frames rendered for a steady (sine or square) case: three spectrum frames, more than 2 × any window span.
    static let steadyFrames = 3 * SpectrumReadout.frameSize
    /// The block size the generator writes in, as a running source does.
    static let blockFrames = 512
    /// The 44.1 kHz rate.
    static let rate44k = 44_100.0

    /// Runs every case and returns the report.
    static func run() -> AccuracyReport {
        guard let analyzer = SpectrumAnalyzer(size: SpectrumReadout.frameSize) else { return AccuracyReport(cases: []) }
        var entries: [AccuracyReport.Entry] = []
        for frequency in sineFrequencies48k {
            let signal = demoSignal(waveform: .sine, frequency: frequency, sampleRate: TestSignal.defaultSampleRate)
            entries += steadyCase(name: "sine \(Int(frequency)) Hz at 48 kHz", signal: signal, analyzer: analyzer)
        }
        for frequency in sineFrequencies44k {
            let signal = demoSignal(waveform: .sine, frequency: frequency, sampleRate: rate44k)
            entries += steadyCase(name: "sine \(Int(frequency)) Hz at 44.1 kHz", signal: signal, analyzer: analyzer)
        }
        for frequency in squareFrequencies {
            let signal = demoSignal(waveform: .square, frequency: frequency, sampleRate: TestSignal.defaultSampleRate)
            entries += steadyCase(name: "square \(Int(frequency)) Hz at 48 kHz", signal: signal, analyzer: analyzer)
        }
        entries += sweepCases(analyzer: analyzer)
        return AccuracyReport(cases: entries)
    }

    /// The demo signal of the scope: the presenter's `testSignal(for:)` at 48 kHz (its waveform and frequency,
    /// amplitude 0.5, two channels with the right at 1.5 × the frequency, the sweep from 100 Hz to 10 kHz over 2 s), or
    /// the same settings at another `sampleRate`.
    static func demoSignal(waveform: TestSignal.Waveform, frequency: Double, sampleRate: Double) -> TestSignal {
        if sampleRate == TestSignal.defaultSampleRate, waveform != .sweep,
           let index = ScopeSettings.frequencies.firstIndex(of: frequency),
           let state = ScopeState(source: .testSignal, waveform: waveform, frequencyIndex: index,
                                  gainIndex: ScopeSettings.defaultGainIndex,
                                  timebaseIndex: ScopeSettings.defaultTimebaseIndex, triggerLevel: 0,
                                  triggerSlope: .rising, triggerMode: .auto) {
            return ScopePresenter.testSignal(for: state)
        }
        if waveform == .sweep {
            return TestSignal(waveform: .sweep, frequency: ScopePresenter.sweepStart,
                              amplitude: ScopePresenter.testAmplitude, sampleRate: sampleRate, channelCount: 2,
                              rightRatio: ScopePresenter.rightRatio, sweepEnd: ScopePresenter.sweepEnd,
                              sweepDuration: ScopePresenter.sweepDuration)
        }
        return TestSignal(waveform: waveform, frequency: frequency, amplitude: ScopePresenter.testAmplitude,
                          sampleRate: sampleRate, channelCount: 2, rightRatio: ScopePresenter.rightRatio)
    }

    /// A buffer holding the first `frames` frames of `signal`, written in `blockFrames` blocks.
    static func render(_ signal: TestSignal, frames: Int) -> StereoSampleBuffer {
        var generator = signal
        let buffer = StereoSampleBuffer(capacityFrames: 4 * SpectrumReadout.frameSize)
        var left = [Float](repeating: 0, count: blockFrames)
        var right = [Float](repeating: 0, count: blockFrames)
        var remaining = frames
        while remaining > 0 {
            let count = min(blockFrames, remaining)
            generator.render(frames: count, left: &left, right: &right)
            if generator.channelCount == 1 { right = left }
            buffer.write(left: Array(left.prefix(count)), right: Array(right.prefix(count)))
            remaining -= count
        }
        return buffer
    }

    /// The spectrum readout of the newest 4,096 frames of the left channel of `buffer`, as the presenter reads it.
    static func spectrum(of buffer: StereoSampleBuffer, sampleRate: Double,
                         analyzer: SpectrumAnalyzer) -> SpectrumReadout {
        var left = [Float](repeating: 0, count: SpectrumReadout.frameSize)
        var right = [Float](repeating: 0, count: SpectrumReadout.frameSize)
        let n = buffer.latestFrames(SpectrumReadout.frameSize, left: &left, right: &right)
        let samples = Array(left[0..<n])
        return SpectrumReadout.make(magnitudesDB: analyzer.magnitudesDB(samples), samples: samples,
                                    sampleRate: sampleRate, writtenFrames: buffer.totalFrames)
    }

    /// The smallest timebase index whose window holds at least two periods of `frequency` at `sampleRate`.
    static func timebaseIndex(frequency: Double, sampleRate: Double) -> Int {
        let need = 2 * sampleRate / frequency
        for (index, milliseconds) in ScopeSettings.timebasesMilliseconds.enumerated() {
            let span = TimebaseWindow(secondsPerDivision: milliseconds / 1_000).sampleCount(sampleRate: sampleRate)
            if Double(span) >= need { return index }
        }
        return ScopeSettings.timebasesMilliseconds.count - 1
    }

    /// The entries of one sine or square case: cursor period, spectrum frequency and level, wording, and for a square
    /// the window's extremes.
    static func steadyCase(name: String, signal: TestSignal, analyzer: SpectrumAnalyzer) -> [AccuracyReport.Entry] {
        let rate = signal.sampleRate
        let frequency = signal.frequency
        let amplitude = signal.amplitude
        let binWidth = rate / Double(SpectrumReadout.frameSize)
        let buffer = render(signal, frames: steadyFrames)
        var entries: [AccuracyReport.Entry] = []

        // Acquisition, trigger and window, then cursors on two consecutive rising crossings.
        let frequencyIndex = ScopeSettings.frequencies.firstIndex(of: frequency) ?? ScopeSettings.defaultFrequencyIndex
        let expectedPeriod = rate / frequency
        if let state = ScopeState(source: .testSignal, waveform: signal.waveform, frequencyIndex: frequencyIndex,
                                  gainIndex: ScopeSettings.defaultGainIndex,
                                  timebaseIndex: timebaseIndex(frequency: frequency, sampleRate: rate),
                                  triggerLevel: 0, triggerSlope: .rising, triggerMode: .auto) {
            let window = ScopeAcquisition().window(from: buffer, channelCount: signal.channelCount, sampleRate: rate,
                                                   state: state)
            let span = window.sampleCount
            // The window starts at a crossing; the next one lies about one period in. The search covers 1.5 expected
            // periods, so exactly one crossing is in range.
            let upper = min(Int((1.5 * expectedPeriod).rounded()), span)
            var measuredPeriod = Double.nan
            var readout = ScopeReadout.noReading
            if window.triggered, span > 1,
               let settings = TriggerSettings(channel: 0, level: state.triggerLevel, slope: state.triggerSlope,
                                              hysteresis: ScopeSettings.triggerHysteresis, mode: state.triggerMode),
               let crossing = ScopeTrigger.find(in: window.left, settings: settings, searchRange: 1..<upper) {
                let a = 0.0
                let b = Double(crossing) / Double(span)
                let time = ScopeReadout.time(a: a, b: b, spanSeconds: Double(span) / rate, sampleRate: rate)
                measuredPeriod = ((b - a) * Double(span)).rounded()
                readout = "A–B \(time.time), \(time.frequency)"
            }
            entries.append(entry(name, .cursorPeriod, expected: expectedPeriod, measured: measuredPeriod,
                                 tolerance: periodToleranceSamples, readout: readout))
            if signal.waveform == .square {
                let maximum = Double(window.left.max() ?? 0)
                let minimum = Double(window.left.min() ?? 0)
                entries.append(entry(name, .maximum, expected: amplitude, measured: maximum,
                                     tolerance: extremeTolerance, readout: ScopeReadout.level(maximum)))
                entries.append(entry(name, .minimum, expected: -amplitude, measured: minimum,
                                     tolerance: extremeTolerance, readout: ScopeReadout.level(minimum)))
            }
        }

        // Spectrum of the newest 4,096 frames.
        let readout = spectrum(of: buffer, sampleRate: rate, analyzer: analyzer)
        entries.append(entry(name, .peakFrequency, expected: frequency, measured: readout.frequency ?? .nan,
                             tolerance: binWidth, readout: readout.text))
        let expectedLevel = signal.waveform == .square ? 20 * log10(4 * amplitude / .pi) : 20 * log10(amplitude)
        entries.append(entry(name, .peakLevel, expected: expectedLevel, measured: readout.levelDB ?? .nan,
                             tolerance: levelToleranceDB, readout: readout.text))
        let otherTexts = entries.filter { $0.quantity != .peakFrequency && $0.quantity != .peakLevel }.map(\.readout)
        entries.append(wordingEntry(name, texts: [readout.text] + otherTexts))
        return entries
    }

    /// The entries of the sweep at each sampling time, then the rising check.
    static func sweepCases(analyzer: SpectrumAnalyzer) -> [AccuracyReport.Entry] {
        let signal = demoSignal(waveform: .sweep, frequency: ScopePresenter.sweepStart,
                                sampleRate: TestSignal.defaultSampleRate)
        let rate = signal.sampleRate
        let binWidth = rate / Double(SpectrumReadout.frameSize)
        var entries: [AccuracyReport.Entry] = []
        var peaks: [Double] = []
        for time in sweepTimes {
            let name = "sweep at \(time) s"
            let total = Int((time * rate).rounded())
            let buffer = render(signal, frames: total)
            let readout = spectrum(of: buffer, sampleRate: rate, analyzer: analyzer)
            let first = sweepFrequency(signal, frame: total - SpectrumReadout.frameSize)
            let last = sweepFrequency(signal, frame: total - 1)
            let low = min(first, last) - binWidth
            let high = max(first, last) + binWidth
            let measured = readout.frequency ?? .nan
            peaks.append(measured)
            entries.append(entry(name, .peakFrequency, expected: (low + high) / 2, measured: measured,
                                 tolerance: (high - low) / 2, readout: readout.text))
            entries.append(wordingEntry(name, texts: [readout.text]))
        }
        let rising = peaks.count >= 2 && zip(peaks, peaks.dropFirst()).allSatisfy { $0 < $1 }
        entries.append(AccuracyReport.Entry(name: "sweep peaks rising", quantity: .rising, expected: 1,
                                            measured: rising ? 1 : 0, tolerance: 0,
                                            readout: peaks.map { "\(Int($0)) Hz" }.joined(separator: " < "),
                                            pass: rising))
        return entries
    }

    /// The left-channel frequency the sweep `signal` plays at `frame`: f0 · (f1 ÷ f0)^(t ÷ T), t looped over T.
    static func sweepFrequency(_ signal: TestSignal, frame: Int) -> Double {
        var t = (Double(frame) / signal.sampleRate).truncatingRemainder(dividingBy: signal.sweepDuration)
        if t < 0 { t += signal.sweepDuration }
        return signal.frequency * pow(signal.sweepEnd / signal.frequency, t / signal.sweepDuration)
    }

    /// An entry that passes when `measured` is finite and within `tolerance` of `expected`.
    static func entry(_ name: String, _ quantity: AccuracyReport.Quantity, expected: Double, measured: Double,
                      tolerance: Double, readout: String) -> AccuracyReport.Entry {
        AccuracyReport.Entry(name: name, quantity: quantity, expected: expected, measured: measured,
                             tolerance: tolerance, readout: readout,
                             pass: measured.isFinite && abs(measured - expected) <= tolerance)
    }

    /// The wording entry of `texts`: the first (the spectrum readout) says `requiredWords`, none says a forbidden word.
    static func wordingEntry(_ name: String, texts: [String]) -> AccuracyReport.Entry {
        let required = texts.first.map { $0.contains(requiredWords) } ?? false
        let clean = texts.allSatisfy { text in
            let lower = text.lowercased()
            return !forbiddenWords.contains { lower.contains($0) }
        }
        let pass = required && clean
        return AccuracyReport.Entry(name: name, quantity: .wording, expected: 1, measured: pass ? 1 : 0, tolerance: 0,
                                    readout: texts.joined(separator: " | "), pass: pass)
    }
}
