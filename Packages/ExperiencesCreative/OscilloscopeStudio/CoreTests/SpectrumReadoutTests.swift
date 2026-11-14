// SpectrumReadoutTests — feature 063 (A08-P03) T-A08-302 (FR-A08-301, FR-A08-303, FR-A08-320; SC-A08-301,
// SC-A08-302; clarification 3). The peak readout, host-free and short: sines of 100 Hz, 440 Hz, 1 kHz and 5 kHz at
// amplitudes 0.5 and 0.1 (48 kHz and 44.1 kHz) read within one bin and 1.5 dB of 20·log10(amplitude); silence,
// clipping and a filling frame show no value and name their reason; the texts say "dBFS, relative to full scale".
import Foundation
import Testing
import VisualCoreAudioDSP
import OscilloscopeStudioCore

@Suite struct SpectrumReadoutTests {
    private let analyzer = SpectrumAnalyzer(size: 4_096)!

    /// `count` samples of a sine of `amplitude` at `frequency` Hz sampled at `rate` Hz.
    private func sine(_ frequency: Double, amplitude: Double, rate: Double, count: Int = 4_096) -> [Float] {
        var samples = [Float](repeating: 0, count: count)
        for i in 0..<count { samples[i] = Float(amplitude * sin(2 * Double.pi * frequency * Double(i) / rate)) }
        return samples
    }

    private func readout(_ samples: [Float], rate: Double, written: Int = 4_096) -> SpectrumReadout {
        SpectrumReadout.make(magnitudesDB: analyzer.magnitudesDB(samples), samples: samples, sampleRate: rate,
                             writtenFrames: written)
    }

    @Test func knownSinesReadWithinOneBinAndOnePointFiveDecibels() throws {
        for rate in [48_000.0, 44_100.0] {
            for frequency in [100.0, 440, 1_000, 5_000] {
                for amplitude in [0.5, 0.1] {
                    let r = readout(sine(frequency, amplitude: amplitude, rate: rate), rate: rate)
                    #expect(r.validity == .valid)
                    let f = try #require(r.frequency)
                    let level = try #require(r.levelDB)
                    #expect(abs(f - frequency) <= rate / 4_096, "\(frequency) Hz at \(rate): read \(f)")
                    #expect(abs(level - 20 * log10(amplitude)) <= 1.5, "\(amplitude) at \(frequency) Hz: \(level)")
                    #expect(r.binWidth == rate / 4_096)
                    #expect(f == f.rounded() && level == (level * 10).rounded() / 10)
                }
            }
        }
    }

    @Test func silenceHasNoSignalAndNoValue() {
        let r = readout([Float](repeating: 0, count: 4_096), rate: 48_000)
        #expect(r.validity == .noSignal)
        #expect(r.frequency == nil && r.levelDB == nil)
        #expect(r.text == "no signal")
    }

    @Test func aClippingWindowHasNoValue() {
        let r = readout(sine(1_000, amplitude: 1.2, rate: 48_000), rate: 48_000)
        #expect(r.validity == .clipping)
        #expect(r.frequency == nil && r.levelDB == nil)
        #expect(r.text == "clipping, level not valid")
    }

    @Test func aFillingFrameHasNoValueAndFillingWinsFirst() {
        let partial = sine(1_000, amplitude: 0.5, rate: 48_000, count: 1_000)
        let r = readout(partial, rate: 48_000, written: 1_000)
        #expect(r.validity == .filling)
        #expect(r.frequency == nil && r.levelDB == nil)
        #expect(r.text == "filling")
        // Filling is checked before clipping and silence.
        #expect(readout(sine(1_000, amplitude: 1.2, rate: 48_000), rate: 48_000, written: 4_095).validity == .filling)
        #expect(readout([Float](repeating: 0, count: 4_096), rate: 48_000, written: 0).validity == .filling)
        #expect(SpectrumReadout.frameSize == 4_096)
    }

    @Test func theValidTextNamesFrequencyAndLevelRelativeToFullScale() throws {
        let rate = 48_000.0
        // 1,000 Hz is not a bin centre at 48 kHz (bin 85.33); the readout names the nearest bin.
        let r = readout(sine(1_000, amplitude: 0.5, rate: rate), rate: rate)
        let f = try #require(r.frequency)
        let level = try #require(r.levelDB)
        #expect(level < 0)
        let levelText = "−" + String(format: "%.1f", -level)
        let grouped = f >= 1_000 ? "\(Int(f) / 1_000),\(String(format: "%03d", Int(f) % 1_000))" : "\(Int(f))"
        #expect(r.text == "peak \(grouped) Hz at \(levelText) dBFS, relative to full scale")

        // A bin-centred tone: bin 128 at 48 kHz is exactly 1,500 Hz.
        let centred = readout(sine(1_500, amplitude: 0.5, rate: rate), rate: rate)
        #expect(centred.frequency == 1_500)
        #expect(centred.text.hasPrefix("peak 1,500 Hz at −6."))
        #expect(centred.text.hasSuffix(" dBFS, relative to full scale"))
    }

    @Test func noCalibratedWordingInAnyText() {
        let texts = [readout(sine(440, amplitude: 0.5, rate: 48_000), rate: 48_000).text,
                     readout([Float](repeating: 0, count: 4_096), rate: 48_000).text,
                     readout(sine(440, amplitude: 1.5, rate: 48_000), rate: 48_000).text,
                     readout([], rate: 48_000, written: 10).text]
        for text in texts {
            for banned in ["SPL", "volt", "calibrated", "certified"] {
                #expect(!text.localizedCaseInsensitiveContains(banned), "\(text)")
            }
        }
    }
}
