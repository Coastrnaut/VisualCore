// PacingMeter — feature 192 T-U06-008 (UA-F06; FR-U06-030 to FR-U06-032). Counts presented-frame intervals in a
// histogram of fixed size (1,000 bins of 0.25 ms), so that a session of any length uses the same memory, and
// summarizes them as on-time and missed frames and three percentiles. Pure and deterministic: intervals are passed in.
import Foundation

/// The frame pacing of a session: counters and percentiles of the intervals between presented frames.
public struct PacingSummary: Sendable, Equatable, Codable {
    /// Valid intervals recorded.
    public var samples: Int
    /// Intervals of at most 1.5 display periods.
    public var onTime: Int
    /// Display periods missed by the late intervals.
    public var missed: Int
    /// Intervals refused: a non-finite, zero or negative interval, or a non-finite or non-positive period.
    public var invalid: Int
    /// The median interval in milliseconds (upper edge of its 0.25 ms bin); nil without samples.
    public var medianMs: Double?
    /// The 95th percentile interval in milliseconds (upper edge of its bin); nil without samples.
    public var p95Ms: Double?
    /// The 99th percentile interval in milliseconds (upper edge of its bin); nil without samples.
    public var p99Ms: Double?

    /// Creates a summary; the default is the summary of a meter without records.
    public init(samples: Int = 0, onTime: Int = 0, missed: Int = 0, invalid: Int = 0,
                medianMs: Double? = nil, p95Ms: Double? = nil, p99Ms: Double? = nil) {
        self.samples = samples
        self.onTime = onTime
        self.missed = missed
        self.invalid = invalid
        self.medianMs = medianMs
        self.p95Ms = p95Ms
        self.p99Ms = p99Ms
    }
}

/// Measures frame pacing in constant memory: a histogram of `binCount` bins of `binWidth` seconds and counters.
public struct PacingMeter: Sendable, Equatable {
    /// Width of one histogram bin in seconds (0.25 ms).
    public static let binWidth: Double = 0.00025
    /// Number of histogram bins (1,000); intervals of 250 ms and more fall in the last bin.
    public static let binCount = 1000

    /// Largest ratio of interval to period that is counted, so that the conversion to `Int` cannot overflow.
    private static let maximumRatio: Double = 1_000_000_000

    private var samples = 0
    private var onTime = 0
    private var missed = 0
    private var invalid = 0
    private var skip = false
    private var bins: [Int]

    /// Creates an empty meter.
    public init() {
        bins = [Int](repeating: 0, count: Self.binCount)
    }

    /// Records the interval between two presented frames for a display period, both in seconds.
    ///
    /// After `skipNext()` the interval is dropped and counted nowhere. A non-finite, zero or negative interval and a
    /// non-finite or non-positive period count as invalid and are no sample. Otherwise the interval is one sample:
    /// on time when it is at most 1.5 periods, else it misses `max(1, round(interval / period) − 1)` periods.
    public mutating func record(interval: Double, period: Double) {
        if skip {
            skip = false
            return
        }
        guard interval.isFinite, interval > 0, period.isFinite, period > 0 else {
            invalid += 1
            return
        }
        samples += 1
        if interval <= 1.5 * period {
            onTime += 1
        } else {
            let ratio = min((interval / period).rounded(), Self.maximumRatio)
            missed += max(1, Int(ratio) - 1)
        }
        let position = min(Double(Self.binCount - 1), (interval / Self.binWidth).rounded(.down))
        bins[Int(position)] += 1
    }

    /// Drops the next recorded interval (the first frame after a resume).
    public mutating func skipNext() {
        skip = true
    }

    /// The counters and the median, 95th and 99th percentile; the percentiles are nil without samples.
    public var summary: PacingSummary {
        PacingSummary(samples: samples, onTime: onTime, missed: missed, invalid: invalid,
                      medianMs: percentile(0.5), p95Ms: percentile(0.95), p99Ms: percentile(0.99))
    }

    /// The upper edge in milliseconds of the bin that holds the sample of rank `ceil(share × samples)`.
    private func percentile(_ share: Double) -> Double? {
        guard samples > 0 else { return nil }
        let rank = max(1, Int((share * Double(samples)).rounded(.up)))
        var cumulative = 0
        for (index, count) in bins.enumerated() {
            cumulative += count
            if cumulative >= rank {
                return Double(index + 1) * Self.binWidth * 1000
            }
        }
        return Double(Self.binCount) * Self.binWidth * 1000
    }
}
