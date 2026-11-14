// ScopeReadout — feature 064 (A08-P04) T-A08-402 (FR-A08-402, FR-A08-404; SC-A08-402, SC-A08-405; clarification 3;
// data-model "ScopeReadout"). The cursor readouts of the scope, host-free and locale-free, never more precise than the
// data:
// - time: Δt = |B − A| × span rounded to whole samples n = round(Δt × rate); n = 0 reads "cursors coincide" with no
//   frequency; n = 1 reads "1 sample, 20.8 µs"; otherwise n ÷ rate with three significant digits in ms (µs below
//   0.1 ms). The frequency 1/Δt = rate ÷ n is given in whole hertz with thousands grouped by a comma and is marked
//   "(limited by the sample period)" when n < 10.
// - level: a fraction of full scale with two decimals and its dBFS to 0.1 dB ("0.50 of full scale (−6.0 dBFS)");
//   |x| ≥ 1 reads "at or beyond full scale", 0 reads "0.00 of full scale (no level)".
// - spectrum cursor: the frequency of the pixel column under the cursor on the log axis of `SpectrumView`, rounded to
//   the nearest bin (k × bin width) and marked "± <bin width> Hz", with its level in dBFS when one is given.
// Negative numbers use the minus sign U+2212, as `SpectrumReadout` does; levels are never called calibrated.
import Foundation

/// The cursor readouts of the scope.
public enum ScopeReadout {
    /// The spacing in samples below which the frequency is marked as limited by the sample period.
    public static let limitedSampleCount = 10
    /// The mark appended to a frequency that is limited by the sample period.
    public static let limitedMark = " (limited by the sample period)"
    /// The time text when the cursors round to the same sample.
    public static let coincide = "cursors coincide"
    /// The frequency text when there is no frequency (cursors coincide or no valid input).
    public static let noFrequency = "no frequency"
    /// The time text when the inputs cannot give a time (a non-finite position, span or rate, or a rate ≤ 0).
    public static let noReading = "no reading"
    /// The level text at or beyond full scale (|x| ≥ 1).
    public static let beyondFullScale = "at or beyond full scale"

    // MARK: - Time

    /// The time between cursors A and B and the matching frequency.
    /// - Parameters:
    ///   - a: Cursor A as a fraction of the window (clamped to 0…1).
    ///   - b: Cursor B as a fraction of the window (clamped to 0…1).
    ///   - spanSeconds: The duration of the shown window in seconds.
    ///   - sampleRate: The sample rate of the window in hertz.
    /// - Returns: The time text ("1.00 ms", "20.8 µs", "1 sample, 20.8 µs", "cursors coincide") and the frequency text
    ///   ("1,000 Hz", "48,000 Hz (limited by the sample period)", "no frequency"); "no reading" and "no frequency"
    ///   when a position, the span or the rate is not finite, the span is negative or the rate is not positive.
    public static func time(a: Double, b: Double, spanSeconds: Double,
                            sampleRate: Double) -> (time: String, frequency: String) {
        guard a.isFinite, b.isFinite, spanSeconds.isFinite, spanSeconds >= 0, sampleRate.isFinite,
              sampleRate > 0 else { return (noReading, noFrequency) }
        let delta = abs(clampedPosition(b) - clampedPosition(a)) * spanSeconds
        let samples = (delta * sampleRate).rounded()
        guard samples >= 1, samples < Double(Int.max / 2) else { return (coincide, noFrequency) }
        let n = Int(samples)
        let period = Double(n) / sampleRate
        let timeText = n == 1 ? "1 sample, \(duration(period))" : duration(period)
        var frequencyText = "\(SpectrumReadout.grouped(Int((sampleRate / Double(n)).rounded()))) Hz"
        if n < limitedSampleCount { frequencyText += limitedMark }
        return (timeText, frequencyText)
    }

    /// `seconds` (> 0) with three significant digits in milliseconds, or in microseconds below 0.1 ms ("1.00 ms",
    /// "2.27 ms", "50.0 ms", "20.8 µs").
    static func duration(_ seconds: Double) -> String {
        let milliseconds = seconds * 1_000
        if milliseconds >= 0.1 { return "\(significant(milliseconds)) ms" }
        return "\(significant(milliseconds * 1_000)) µs"
    }

    /// `value` (> 0, finite) with three significant digits, locale-free; whole results of four or more digits are
    /// grouped with commas.
    static func significant(_ value: Double) -> String {
        var exponent = Int(floor(log10(value)))
        var decimals = max(0, 2 - exponent)
        var rounded = roundedTo(value, decimals: decimals, exponent: exponent)
        if rounded >= pow(10, Double(exponent + 1)) {   // 9.996 → 10.0, not 10.00
            exponent += 1
            decimals = max(0, 2 - exponent)
            rounded = roundedTo(value, decimals: decimals, exponent: exponent)
        }
        if decimals == 0 { return SpectrumReadout.grouped(Int(rounded)) }
        return String(format: "%.\(decimals)f", rounded)
    }

    /// `value` rounded to three significant digits for a number of order 10^`exponent`.
    private static func roundedTo(_ value: Double, decimals: Int, exponent: Int) -> Double {
        let step = pow(10, Double(exponent - 2))
        return (value / step).rounded() * step
    }

    /// `position` clamped to the window (0…1).
    private static func clampedPosition(_ position: Double) -> Double { min(max(position, 0), 1) }

    // MARK: - Level

    /// The level cursor's reading.
    /// - Parameter value: The level in full scale.
    /// - Returns: "0.50 of full scale (−6.0 dBFS)" (two decimals, dBFS to 0.1 dB, U+2212 minus); "at or beyond full
    ///   scale" when |value| ≥ 1; "0.00 of full scale (no level)" at 0 (and for a magnitude that rounds to 0.00);
    ///   "no level" when the value is not a number.
    public static func level(_ value: Double) -> String {
        if value.isNaN { return "no level" }
        let magnitude = abs(value)
        if magnitude >= 1 { return beyondFullScale }
        let fraction = String(format: "%.2f", magnitude)
        if fraction == "0.00" { return "0.00 of full scale (no level)" }
        let signed = value < 0 ? "−" + fraction : fraction
        return "\(signed) of full scale (\(SpectrumReadout.level(20 * log10(magnitude))) dBFS)"
    }

    // MARK: - Spectrum cursor

    /// The frequency cursor's reading in the spectrum view.
    /// - Parameters:
    ///   - position: The cursor as a fraction of the spectrum width (clamped to 0…1).
    ///   - sampleRate: The sample rate of the analysed window in hertz.
    ///   - width: The width of the spectrum in pixel columns; the cursor reads the centre of the column it lies in,
    ///     (column + 0.5) ÷ width, the column `SpectrumView.columns` fills. A width below 1 (or not finite) reads the
    ///     position itself.
    ///   - binWidth: The width of one analysis bin in hertz (sample rate ÷ 4,096).
    ///   - levelDB: The column's level in dB relative to full scale, or `nil` when none is known.
    /// - Returns: "996 Hz ± 11.7 Hz at −6.0 dBFS": the frequency 20 × (nyquist ÷ 20)^p rounded to the nearest bin
    ///   (at least one bin) and shown in whole hertz, the bin width to 0.1 Hz, the level to 0.1 dB; ", no level" in
    ///   place of the level when it is `nil` or not finite; "at or beyond full scale" at 0 dBFS and above; "no frequency"
    ///   when the position, rate or bin width is not usable or Nyquist is not above 20 Hz.
    public static func spectrumFrequency(position: Double, sampleRate: Double, width: Double, binWidth: Double,
                                         levelDB: Double?) -> String {
        let nyquist = sampleRate / 2
        guard position.isFinite, sampleRate.isFinite, binWidth.isFinite, binWidth > 0,
              nyquist > SpectrumView.minimumFrequency else { return noFrequency }
        var p = clampedPosition(position)
        if width.isFinite, width >= 1 {
            let columns = width.rounded(.down)
            let column = min((p * columns).rounded(.down), columns - 1)
            p = (column + 0.5) / columns
        }
        let frequency = SpectrumView.minimumFrequency * pow(nyquist / SpectrumView.minimumFrequency, p)
        let bin = max((frequency / binWidth).rounded(), 1)
        let shown = SpectrumReadout.grouped(Int((bin * binWidth).rounded()))
        let resolution = String(format: "%.1f", binWidth)
        let head = "\(shown) Hz ± \(resolution) Hz"
        guard let levelDB, levelDB.isFinite else { return head + ", no level" }
        let rounded = (levelDB * 10).rounded() / 10
        if rounded >= 0 { return head + ", " + beyondFullScale }
        return "\(head) at \(SpectrumReadout.level(rounded)) dBFS"
    }
}
