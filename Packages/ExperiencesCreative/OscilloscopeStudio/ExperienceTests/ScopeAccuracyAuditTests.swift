// ScopeAccuracyAuditTests — feature 065 (A08-P05) T-A08-504 (FR-A08-510; SC-A08-501; story 1 scenarios 1–4). The
// accuracy audit runs the demo sine, square and sweep through the real path (buffer, acquisition, trigger, window,
// cursors, spectrum) once; every entry passes; the sines read within one bin and 1.5 dB at 48 kHz and at 44.1 kHz and
// cursors one period apart read the period within one sample; the square's extremes read ±0.50 of full scale and its
// peak is the fundamental; the sweep's peaks at 0.5, 1 and 1.5 s lie in the analysed frame's range ± one bin and rise;
// readouts say "relative to full scale" and never claim calibrated, certified, laboratory or medical accuracy. Short:
// one audit run (about 140,000 generated frames, a few FFTs), no wall-clock assertion.
import XCTest
import OscilloscopeStudioCore
import VisualCoreAudioDSP
@testable import OscilloscopeStudioExperience

final class ScopeAccuracyAuditTests: XCTestCase {
    /// One audit run shared by the tests of this class.
    nonisolated(unsafe) private static var cachedReport: AccuracyReport?

    private var report: AccuracyReport {
        if let cached = Self.cachedReport { return cached }
        let fresh = ScopeAccuracyAudit.run()
        Self.cachedReport = fresh
        return fresh
    }

    private func describe(_ entry: AccuracyReport.Entry) -> String {
        "\(entry.name) \(entry.quantity.rawValue): expected \(entry.expected) ± \(entry.tolerance), measured "
            + "\(entry.measured) (\(entry.readout))"
    }

    func testEveryCasePasses() {
        let report = report
        for entry in report.cases where !entry.pass { XCTFail(describe(entry)) }
        XCTAssertTrue(report.allPass)
        XCTAssertEqual(report.passRate, 1)
        let names = Set(report.cases.map(\.name))
        XCTAssertEqual(names, ["sine 100 Hz at 48 kHz", "sine 440 Hz at 48 kHz", "sine 1000 Hz at 48 kHz",
                               "sine 5000 Hz at 48 kHz", "sine 440 Hz at 44.1 kHz", "sine 1000 Hz at 44.1 kHz",
                               "square 440 Hz at 48 kHz", "square 1000 Hz at 48 kHz", "sweep at 0.5 s",
                               "sweep at 1.0 s", "sweep at 1.5 s", "sweep peaks rising"])
    }

    func testSinesReadWithinOneBinAndOneAndAHalfDecibels() throws {
        let cases: [(frequency: Double, rate: Double, label: String)] = [
            (100, 48_000, "48 kHz"), (440, 48_000, "48 kHz"), (1_000, 48_000, "48 kHz"), (5_000, 48_000, "48 kHz"),
            (440, 44_100, "44.1 kHz"), (1_000, 44_100, "44.1 kHz")]
        for (frequency, rate, label) in cases {
            let name = "sine \(Int(frequency)) Hz at \(label)"
            let entries = report.entries(named: name)
            let peak = try XCTUnwrap(entries.first { $0.quantity == .peakFrequency }, name)
            XCTAssertEqual(peak.expected, frequency, name)
            XCTAssertEqual(peak.tolerance, rate / 4_096, accuracy: 1e-9, name)
            XCTAssertLessThanOrEqual(abs(peak.measured - frequency), rate / 4_096, name)
            let level = try XCTUnwrap(entries.first { $0.quantity == .peakLevel }, name)
            XCTAssertEqual(level.expected, 20 * log10(0.5), accuracy: 1e-9, name)
            XCTAssertLessThanOrEqual(abs(level.measured - level.expected), 1.5, name)
            let period = try XCTUnwrap(entries.first { $0.quantity == .cursorPeriod }, name)
            XCTAssertEqual(period.expected, rate / frequency, accuracy: 1e-9, name)
            XCTAssertLessThanOrEqual(abs(period.measured - rate / frequency), 1, name)
            XCTAssertTrue(period.readout.hasPrefix("A–B "), name)
        }
    }

    func testSquareExtremesAndFundamentalPeak() throws {
        for frequency in [440.0, 1_000] {
            let name = "square \(Int(frequency)) Hz at 48 kHz"
            let entries = report.entries(named: name)
            let maximum = try XCTUnwrap(entries.first { $0.quantity == .maximum }, name)
            let minimum = try XCTUnwrap(entries.first { $0.quantity == .minimum }, name)
            XCTAssertEqual(maximum.measured, 0.5, accuracy: 0.005, name)
            XCTAssertEqual(minimum.measured, -0.5, accuracy: 0.005, name)
            XCTAssertEqual(maximum.readout, "0.50 of full scale (−6.0 dBFS)", name)
            XCTAssertEqual(minimum.readout, "−0.50 of full scale (−6.0 dBFS)", name)
            let peak = try XCTUnwrap(entries.first { $0.quantity == .peakFrequency }, name)
            XCTAssertLessThanOrEqual(abs(peak.measured - frequency), 48_000.0 / 4_096, "peak is the fundamental")
            XCTAssertTrue(peak.pass, describe(peak))
        }
    }

    func testSweepPeaksLieInTheFrameRangeAndRise() throws {
        let binWidth = 48_000.0 / 4_096
        var peaks: [Double] = []
        for time in [0.5, 1.0, 1.5] {
            let name = "sweep at \(time) s"
            let peak = try XCTUnwrap(report.entries(named: name).first { $0.quantity == .peakFrequency }, name)
            // The generator's frequency at the analysed frame's first and last sample, widened by one bin.
            let total = Int((time * 48_000).rounded())
            let first = 100 * pow(100, Double(total - 4_096) / 48_000 / 2)
            let last = 100 * pow(100, Double(total - 1) / 48_000 / 2)
            XCTAssertGreaterThanOrEqual(peak.measured, first - binWidth, name)
            XCTAssertLessThanOrEqual(peak.measured, last + binWidth, name)
            XCTAssertTrue(peak.pass, describe(peak))
            peaks.append(peak.measured)
        }
        XCTAssertLessThan(peaks[0], peaks[1])
        XCTAssertLessThan(peaks[1], peaks[2])
        let rising = try XCTUnwrap(report.entries(.rising).first)
        XCTAssertTrue(rising.pass, rising.readout)
    }

    func testReadoutWordsStayRelativeToFullScale() {
        let wording = report.entries(.wording)
        XCTAssertEqual(wording.count, 11, "one per sine, square and sweep case")
        for entry in wording { XCTAssertTrue(entry.pass, describe(entry)) }
        for entry in report.entries(.peakFrequency) {
            XCTAssertTrue(entry.readout.contains("relative to full scale"), entry.readout)
        }
        for entry in report.cases {
            let lower = entry.readout.lowercased()
            for word in ["calibrated", "certified", "laboratory", "medical"] {
                XCTAssertFalse(lower.contains(word), "\(entry.name): \(entry.readout)")
            }
        }
    }

    func testWordingEntryRefusesAForbiddenWord() {
        XCTAssertFalse(ScopeAccuracyAudit.wordingEntry("x", texts: ["peak 1,000 Hz, calibrated"]).pass)
        XCTAssertFalse(ScopeAccuracyAudit.wordingEntry("x", texts: ["peak 1,000 Hz at −6.0 dBFS"]).pass)
        XCTAssertTrue(ScopeAccuracyAudit.wordingEntry("x", texts: ["peak 1,000 Hz at −6.0 dBFS, relative to full scale"])
            .pass)
    }
}
