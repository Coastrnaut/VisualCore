// PacingMeterTests — feature 192 T-U06-007 (UA-F06; FR-U06-030 to FR-U06-032; SC-U06-006).
import Foundation
import Testing
@testable import VisualCoreDiagnostics

private let period60 = 1.0 / 60.0

// Intervals well inside a bin of 0.25 ms (bin = floor(interval / 0.00025); value = (bin + 1) × 0.25 ms):
//   0.0083 s → 33.2  → bin 33  → 8.5 ms      on time (≤ 0.025 s)
//   0.0166 s → 66.4  → bin 66  → 16.75 ms    on time
//   0.0333 s → 133.2 → bin 133 → 33.5 ms     late: round(1.998) − 1 = 1 missed
//   0.0501 s → 200.4 → bin 200 → 50.25 ms    late: round(3.006) − 1 = 2 missed
//   0.1001 s → 400.4 → bin 400 → 100.25 ms   late: round(6.006) − 1 = 5 missed
private let onTime60 = 0.0166
private let oneLate = 0.0333
private let twoLate = 0.0501
private let fiveLate = 0.1001
private let fast = 0.0083

private struct PacingCase: Sendable {
    let name: String
    let intervals: [Double]
    let expected: PacingSummary
}

private let pacingCases: [PacingCase] = [
    // 10 samples, all on time. Ranks: median ceil(5.0) = 5, p95 ceil(9.5) = 10, p99 ceil(9.9) = 10; all in bin 66.
    PacingCase(name: "steady",
               intervals: [Double](repeating: onTime60, count: 10),
               expected: PacingSummary(samples: 10, onTime: 10, missed: 0, invalid: 0,
                                       medianMs: 16.75, p95Ms: 16.75, p99Ms: 16.75)),
    // 20 samples: 18 on time (cumulative 18 at bin 66), 2 late by one period (bin 133). Missed 2 × 1 = 2.
    // Ranks: median 10 → bin 66; p95 ceil(19.0) = 19 → bin 133; p99 ceil(19.8) = 20 → bin 133.
    PacingCase(name: "two late frames",
               intervals: [Double](repeating: onTime60, count: 9) + [oneLate]
                   + [Double](repeating: onTime60, count: 9) + [oneLate],
               expected: PacingSummary(samples: 20, onTime: 18, missed: 2, invalid: 0,
                                       medianMs: 16.75, p95Ms: 33.5, p99Ms: 33.5)),
    // 50 samples: 47 on time (cumulative 47), 2 late by one (cumulative 49), 1 late by two (50).
    // Missed 2 × 1 + 2 = 4. Ranks: median 25 → bin 66; p95 ceil(47.5) = 48 → bin 133; p99 ceil(49.5) = 50 → bin 200.
    PacingCase(name: "a long tail",
               intervals: [twoLate, oneLate] + [Double](repeating: onTime60, count: 47) + [oneLate],
               expected: PacingSummary(samples: 50, onTime: 47, missed: 4, invalid: 0,
                                       medianMs: 16.75, p95Ms: 33.5, p99Ms: 50.25)),
    // 5 samples and 3 invalid: 4 on time (cumulative 4), 1 late by five (bin 400). Missed 5.
    // Ranks: median ceil(2.5) = 3 → bin 66; p95 ceil(4.75) = 5 → bin 400; p99 ceil(4.95) = 5 → bin 400.
    PacingCase(name: "a stall and invalid intervals",
               intervals: [onTime60, onTime60, .nan, fiveLate, -1, onTime60, 0, onTime60],
               expected: PacingSummary(samples: 5, onTime: 4, missed: 5, invalid: 3,
                                       medianMs: 16.75, p95Ms: 100.25, p99Ms: 100.25)),
    // 6 samples: 1 fast (bin 33, cumulative 1), 2 on time (bin 66, cumulative 3), 3 late by one (bin 133, 6).
    // On time 3, missed 3. Ranks: median 3 → bin 66; p95 ceil(5.7) = 6 → bin 133; p99 ceil(5.94) = 6 → bin 133.
    PacingCase(name: "every second frame late",
               intervals: [oneLate, onTime60, oneLate, fast, oneLate, onTime60],
               expected: PacingSummary(samples: 6, onTime: 3, missed: 3, invalid: 0,
                                       medianMs: 16.75, p95Ms: 33.5, p99Ms: 33.5)),
]

@Test func pacingScriptedSequencesGiveExactSummaries() {
    #expect(pacingCases.count == 5)
    for item in pacingCases {
        var meter = PacingMeter()
        for interval in item.intervals {
            meter.record(interval: interval, period: period60)
        }
        let summary = meter.summary
        #expect(summary == item.expected, "\(item.name)")
    }
}

@Test func pacingOnTimeBoundary() {
    // 1.5 × (1/60) = 0.025 s.
    var meter = PacingMeter()
    meter.record(interval: 0.024, period: period60)
    var summary = meter.summary
    #expect(summary.samples == 1 && summary.onTime == 1 && summary.missed == 0, "0.024 s ≤ 0.025 s is on time")

    meter.record(interval: 0.026, period: period60)
    summary = meter.summary
    #expect(summary.samples == 2 && summary.onTime == 1, "0.026 s > 0.025 s is late")
    #expect(summary.missed == 1, "max(1, round(1.56) − 1) = 1")

    meter.record(interval: 0.050, period: period60)
    summary = meter.summary
    #expect(summary.samples == 3 && summary.onTime == 1)
    #expect(summary.missed == 3, "round(3.0) − 1 = 2 more")
}

@Test func pacingLateIntervalMissesAtLeastOnePeriod() {
    // 0.0166 s with a period of 0.010 s: 1.66 periods > 1.5, round(1.66) − 1 = 1.
    // 0.0151 s with a period of 0.010 s: 1.51 periods > 1.5, round(1.51) − 1 = 1.
    var meter = PacingMeter()
    meter.record(interval: 0.0166, period: 0.010)
    meter.record(interval: 0.0151, period: 0.010)
    let summary = meter.summary
    #expect(summary.onTime == 0 && summary.missed == 2 && summary.samples == 2)
}

@Test func pacingInvalidInputsAreNoSamples() {
    var meter = PacingMeter()
    meter.record(interval: .nan, period: period60)
    meter.record(interval: .infinity, period: period60)
    meter.record(interval: -.infinity, period: period60)
    meter.record(interval: 0, period: period60)
    meter.record(interval: -0.0166, period: period60)
    meter.record(interval: onTime60, period: 0)
    meter.record(interval: onTime60, period: -period60)
    meter.record(interval: onTime60, period: .nan)
    meter.record(interval: onTime60, period: .infinity)
    let summary = meter.summary
    #expect(summary.invalid == 9)
    #expect(summary.samples == 0 && summary.onTime == 0 && summary.missed == 0)
    #expect(summary.medianMs == nil && summary.p95Ms == nil && summary.p99Ms == nil)
}

@Test func pacingSkipNextDropsExactlyOneInterval() {
    var meter = PacingMeter()
    meter.record(interval: onTime60, period: period60)
    meter.skipNext()
    meter.skipNext()
    meter.record(interval: 0.3, period: period60)
    var summary = meter.summary
    #expect(summary == PacingSummary(samples: 1, onTime: 1, missed: 0, invalid: 0,
                                     medianMs: 16.75, p95Ms: 16.75, p99Ms: 16.75),
            "the long interval after a resume is counted nowhere")
    meter.record(interval: oneLate, period: period60)
    summary = meter.summary
    #expect(summary.samples == 2 && summary.missed == 1, "only one interval was dropped")
}

@Test func pacingSkipNextAlsoDropsAnInvalidInterval() {
    var meter = PacingMeter()
    meter.skipNext()
    meter.record(interval: .nan, period: period60)
    let summary = meter.summary
    #expect(summary == PacingSummary())
}

@Test func pacingIntervalsBeyondTheRangeLandInTheLastBin() {
    // 0.3 s → 1200 → clamped to bin 999 → upper edge 1000 × 0.25 ms = 250 ms. Missed round(18.0) − 1 = 17.
    var meter = PacingMeter()
    meter.record(interval: 0.3, period: period60)
    var summary = meter.summary
    #expect(summary.samples == 1 && summary.onTime == 0 && summary.missed == 17)
    #expect(summary.medianMs == 250.0 && summary.p95Ms == 250.0 && summary.p99Ms == 250.0)

    // A very long interval with a very short period neither traps nor leaves the last bin.
    meter.record(interval: 1e300, period: 1e-300)
    summary = meter.summary
    #expect(summary.samples == 2 && summary.p99Ms == 250.0)
    #expect(summary.missed > 17)
}

@Test func pacingEmptySummaryHasNoPercentiles() {
    let summary = PacingMeter().summary
    #expect(summary == PacingSummary())
    #expect(summary.samples == 0 && summary.onTime == 0 && summary.missed == 0 && summary.invalid == 0)
    #expect(summary.medianMs == nil && summary.p95Ms == nil && summary.p99Ms == nil)
    #expect(PacingMeter.binWidth == 0.00025 && PacingMeter.binCount == 1000)
}

/// The number of counters the meter holds, read through reflection: its only growing storage would be the bins.
private func storedCounters(of meter: PacingMeter) -> Int {
    var total = 0
    for child in Mirror(reflecting: meter).children {
        if let list = child.value as? [Int] { total += list.count }
    }
    return total
}

// FR-U06-032: the meter keeps a bounded amount of data however many intervals it takes, also when the intervals
// differ. (Convergence T-U06-050: the earlier assertion compared `MemoryLayout` sizes, which never change.)
@Test func pacingMeterHoldsTheSameNumberOfCountersAfterAMillionRecords() {
    var meter = PacingMeter()
    #expect(storedCounters(of: meter) == PacingMeter.binCount)
    for index in 0..<1_000 {
        meter.record(interval: Double(index % 400 + 1) * 0.0007, period: period60)
    }
    #expect(storedCounters(of: meter) == PacingMeter.binCount)
    #expect(meter.summary.samples == 1_000)
    for index in 0..<1_000_000 {
        meter.record(interval: Double(index % 400 + 1) * 0.0007, period: period60)
    }
    #expect(storedCounters(of: meter) == PacingMeter.binCount, "no storage grew")
    let summary = meter.summary
    #expect(summary.samples == 1_001_000)
    #expect(summary.onTime + summary.missed >= summary.samples, "every late interval misses at least one refresh")
    #expect(summary.invalid == 0)
}

@Test func pacingSummaryCodesAndDecodes() throws {
    var meter = PacingMeter()
    for interval in [onTime60, onTime60, oneLate, .nan] {
        meter.record(interval: interval, period: period60)
    }
    let summary = meter.summary
    let data = try JSONEncoder().encode(summary)
    let decoded = try JSONDecoder().decode(PacingSummary.self, from: data)
    #expect(decoded == summary)
    #expect(decoded.samples == 3 && decoded.invalid == 1 && decoded.p99Ms == 33.5)

    let empty = PacingSummary()
    let emptyData = try JSONEncoder().encode(empty)
    let emptyDecoded = try JSONDecoder().decode(PacingSummary.self, from: emptyData)
    #expect(emptyDecoded == empty)
    #expect(emptyDecoded.medianMs == nil)
}
