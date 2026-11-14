// ScopeReadoutTests — feature 064 (A08-P04) T-A08-402 (FR-A08-402, FR-A08-404; SC-A08-402, SC-A08-405; clarification
// 3; story 4). The precision fixture, host-free and short: cursors one period apart on 100 Hz, 440 Hz and 1 kHz at
// 48 kHz with spans from the offered timebases read the period to three significant digits (within one sample) and the
// frequency within the shown resolution; one sample reads "1 sample, 20.8 µs" and is marked as limited by the sample
// period; coinciding cursors give no frequency; levels read two decimals and 0.1 dB, clipped values "at or beyond full
// scale"; the spectrum cursor reads its column's frequency rounded to the bin width with "± <bin width> Hz". Regular
// expressions check that no readout has more decimals than its rule allows.
import Foundation
import Testing
import OscilloscopeStudioCore

@Suite struct ScopeReadoutTests {
    private let rate = 48_000.0

    /// A readout as an array, so two readouts compare with `==`.
    private func pair(_ readout: (time: String, frequency: String)) -> [String] { [readout.time, readout.frequency] }

    private func matches(_ text: String, _ pattern: String) -> Bool {
        text.range(of: pattern, options: .regularExpression) != nil
    }

    /// Three significant digits in ms or µs, optionally after "1 sample, ".
    private let timePattern = "^(1 sample, )?(0\\.[0-9]{3}|[1-9]\\.[0-9]{2}|[1-9][0-9]\\.[0-9]|[1-9][0-9]{2})"
        + " (ms|µs)$"
    /// Whole hertz with comma grouping, optionally marked as limited.
    private let frequencyPattern = "^[0-9]{1,3}(,[0-9]{3})* Hz( \\(limited by the sample period\\))?$"

    @Test func cursorsOnePeriodApartReadThePeriodAndFrequency() throws {
        let expected: [(hz: Double, time: String, frequency: String)] = [
            (100, "10.0 ms", "100 Hz"), (440, "2.27 ms", "440 Hz"), (1_000, "1.00 ms", "1,000 Hz"),
        ]
        var checked = 0
        for entry in expected {
            let period = 1 / entry.hz
            for timebase in ScopeSettings.timebasesMilliseconds {
                let span = timebase * 10 / 1_000
                guard period <= span else { continue }
                for a in [0.0, (span - period) / span] {
                    let readout = ScopeReadout.time(a: a, b: a + period / span, spanSeconds: span, sampleRate: rate)
                    #expect(readout.time == entry.time, "\(entry.hz) Hz at \(timebase) ms/div")
                    #expect(readout.frequency == entry.frequency, "\(entry.hz) Hz at \(timebase) ms/div")
                    #expect(matches(readout.time, timePattern) && matches(readout.frequency, frequencyPattern))
                    // Reversed cursors (A after B) read the same.
                    let reversed = ScopeReadout.time(a: a + period / span, b: a, spanSeconds: span, sampleRate: rate)
                    #expect(pair(reversed) == pair(readout))
                    checked += 1
                }
            }
        }
        // 100 Hz fits 1, 2 and 5 ms/div; 440 Hz fits 0.5…5 ms/div; 1 kHz fits every timebase; two positions each.
        #expect(checked == 2 * (3 + 4 + 6))
        // The shown period is within one sample of the true one: 440 Hz → 109 samples = 2.2708 ms vs 2.2727 ms.
        let samples = (rate / 440).rounded()
        #expect(abs(samples / rate - 1 / 440) <= 1 / rate)
        // And the shown frequency within the resolution of that sample count.
        #expect(abs(rate / samples - 440) <= rate / samples - rate / (samples + 1))
    }

    @Test func oneSampleReadsTheSamplePeriodAndIsMarkedLimited() {
        let span = 0.001 * 10   // 1 ms/div
        let readout = ScopeReadout.time(a: 0.5, b: 0.5 + 1 / (rate * span), spanSeconds: span, sampleRate: rate)
        #expect(readout.time == "1 sample, 20.8 µs")
        #expect(readout.frequency == "48,000 Hz (limited by the sample period)")
        #expect(matches(readout.time, timePattern) && matches(readout.frequency, frequencyPattern))
        // Seven samples are still limited, ten are not (no rounding ties: 0.1458 ms, 0.2083 ms).
        let seven = ScopeReadout.time(a: 0, b: 7 / (rate * span), spanSeconds: span, sampleRate: rate)
        #expect(seven.time == "0.146 ms" && seven.frequency == "6,857 Hz (limited by the sample period)")
        let ten = ScopeReadout.time(a: 0, b: 10 / (rate * span), spanSeconds: span, sampleRate: rate)
        #expect(ten.time == "0.208 ms" && ten.frequency == "4,800 Hz")
        #expect(matches(seven.time, timePattern) && matches(ten.time, timePattern))
        // Microseconds below 0.1 ms, milliseconds from 0.1 ms: 4 samples = 83.3 µs, 5 samples = 0.104 ms.
        #expect(ScopeReadout.time(a: 0, b: 4 / (rate * span), spanSeconds: span, sampleRate: rate).time == "83.3 µs")
        #expect(ScopeReadout.time(a: 0, b: 5 / (rate * span), spanSeconds: span, sampleRate: rate).time == "0.104 ms")
    }

    @Test func timeIsNeverFinerThanOneSample() {
        // Two positions less than half a sample apart read the same whole-sample spacing.
        let span = 0.001 * 10
        let sample = 1 / (rate * span)
        let base = ScopeReadout.time(a: 0, b: 48 * sample, spanSeconds: span, sampleRate: rate)
        let nudged = ScopeReadout.time(a: 0, b: 48.4 * sample, spanSeconds: span, sampleRate: rate)
        #expect(pair(base) == pair(nudged) && base.time == "1.00 ms")
        // The longest offered span (5 ms/div, ten divisions) reads three significant digits.
        let full = ScopeReadout.time(a: 0, b: 1, spanSeconds: 0.05, sampleRate: rate)
        #expect(full.time == "50.0 ms" && full.frequency == "20 Hz")
        for position in stride(from: 0.0, through: 1.0, by: 0.0625) {
            let readout = ScopeReadout.time(a: 0, b: position, spanSeconds: 0.05, sampleRate: rate)
            #expect(readout.time == ScopeReadout.coincide || matches(readout.time, timePattern), "\(readout.time)")
        }
    }

    @Test func coincidingCursorsGiveNoFrequency() {
        let span = 0.01
        #expect(pair(ScopeReadout.time(a: 0.3, b: 0.3, spanSeconds: span, sampleRate: rate))
                    == ["cursors coincide", "no frequency"])
        // Less than half a sample apart rounds to zero samples.
        let near = ScopeReadout.time(a: 0.3, b: 0.3 + 0.4 / (rate * span), spanSeconds: span, sampleRate: rate)
        #expect(pair(near) == [ScopeReadout.coincide, ScopeReadout.noFrequency])
        // Positions outside the window are clamped to it.
        #expect(pair(ScopeReadout.time(a: -1, b: 2, spanSeconds: span, sampleRate: rate))
                    == pair(ScopeReadout.time(a: 0, b: 1, spanSeconds: span, sampleRate: rate)))
        #expect(ScopeReadout.time(a: .nan, b: 0.5, spanSeconds: span, sampleRate: rate).time == "no reading")
        #expect(ScopeReadout.time(a: 0, b: 0.5, spanSeconds: span, sampleRate: 0).frequency == "no frequency")
    }

    @Test func levelsReadTwoDecimalsAndATenthOfADecibel() {
        #expect(ScopeReadout.level(0.5) == "0.50 of full scale (−6.0 dBFS)")
        #expect(ScopeReadout.level(-0.5) == "−0.50 of full scale (−6.0 dBFS)")
        #expect(ScopeReadout.level(0.1) == "0.10 of full scale (−20.0 dBFS)")
        #expect(ScopeReadout.level(0) == "0.00 of full scale (no level)")
        #expect(ScopeReadout.level(-0.001) == "0.00 of full scale (no level)")
        let pattern = "^−?[0-9]\\.[0-9]{2} of full scale \\((−?[0-9]+\\.[0-9] dBFS|no level)\\)$"
        for value in stride(from: -0.995, through: 0.995, by: 0.0125) {
            #expect(matches(ScopeReadout.level(value), pattern), "\(value)")
        }
    }

    @Test func clippedValuesReadAtOrBeyondFullScale() {
        for value in [1.0, -1.0, -1.2, 1.5, .infinity] {
            #expect(ScopeReadout.level(value) == "at or beyond full scale")
        }
        #expect(ScopeReadout.level(.nan) == "no level")
        // Nothing below full scale reads a number above 1.
        #expect(!ScopeReadout.level(0.9999).contains("1.01"))
    }

    @Test func theSpectrumCursorReadsItsColumnRoundedToTheBinWidth() throws {
        let binWidth = rate / 4_096
        let width = 400.0
        let x = try #require(SpectrumView.x(frequency: 1_000, sampleRate: rate, width: width))
        let text = ScopeReadout.spectrumFrequency(position: x / width, sampleRate: rate, width: width,
                                                  binWidth: binWidth, levelDB: -6.02)
        let pattern = "^[0-9]{1,3}(,[0-9]{3})* Hz ± 11\\.7 Hz at −6\\.0 dBFS$"
        #expect(matches(text, pattern), "\(text)")
        // The frequency shown is a whole bin within one column and one bin of 1 kHz.
        let shown = try #require(Double(text.prefix { $0 != " " }.replacingOccurrences(of: ",", with: "")))
        let columnRatio = pow(rate / 2 / 20, 1 / width)
        #expect(abs(shown - 1_000) <= 1_000 * (columnRatio - 1) + binWidth)
        #expect(abs(shown / binWidth - (shown / binWidth).rounded()) * binWidth <= 0.5)
        // The ends of the axis: 20 Hz and Nyquist.
        #expect(ScopeReadout.spectrumFrequency(position: 0, sampleRate: rate, width: 0, binWidth: binWidth,
                                               levelDB: nil) == "23 Hz ± 11.7 Hz, no level")
        #expect(ScopeReadout.spectrumFrequency(position: 1, sampleRate: rate, width: 0, binWidth: binWidth,
                                               levelDB: -40) == "24,000 Hz ± 11.7 Hz at −40.0 dBFS")
        #expect(ScopeReadout.spectrumFrequency(position: 0.5, sampleRate: rate, width: width, binWidth: binWidth,
                                               levelDB: 0.2).hasSuffix(", at or beyond full scale"))
        #expect(ScopeReadout.spectrumFrequency(position: .nan, sampleRate: rate, width: width, binWidth: binWidth,
                                               levelDB: nil) == "no frequency")
    }
}
