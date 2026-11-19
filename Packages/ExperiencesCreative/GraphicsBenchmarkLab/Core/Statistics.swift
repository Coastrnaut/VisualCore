// Statistics — feature 173 (A24-P01) T-A24-106 (FR-A24-103, FR-A24-104; User Stories 2 and 4; clarification Q2).
// Exact nearest-rank percentiles over the measured frames of a run, and the quality flags that say how far a summary
// can be trusted. The rank of percentile p over n sorted values is ⌈p · n / 100⌉, computed in integers as
// (p · n + 99) / 100; the value is the rank-th smallest. There is no interpolation and no mean. p50 needs at least
// 1 value, p95 at least 20 and p99 at least 100; below that the percentile is absent and the summary is flagged.
// Warm-up and cool-down frames are left out and counted. Pure: no clock, no graphics.
import Foundation

/// Nearest-rank percentiles over values sorted ascending.
public enum Percentiles {
    /// The fewest values each supported percentile needs: p50 needs 1, p95 needs 20 and p99 needs 100.
    public static let minimumCount: [Int: Int] = [50: 1, 95: 20, 99: 100]

    /// The nearest-rank percentile `p` of `sortedValues` (ascending): the value at rank (p · n + 99) / 100, counted
    /// from 1. `nil` when the set is empty, when `p` is not a key of ``minimumCount`` or when the set holds fewer
    /// values than ``minimumCount`` asks for `p`.
    public static func nearestRank(_ p: Int, of sortedValues: [Double]) -> Double? {
        let n = sortedValues.count
        guard n > 0, let minimum = minimumCount[p], n >= minimum else { return nil }
        let rank = (p * n + 99) / 100
        guard rank >= 1, rank <= n else { return nil }
        return sortedValues[rank - 1]
    }
}

/// The p50, p95 and p99 of one measured quantity (milliseconds) and how many values they were taken from.
public struct Distribution: Codable, Equatable, Sendable {
    /// The median, absent when there are no values.
    public var p50: Double?
    /// The 95th percentile, absent below 20 values.
    public var p95: Double?
    /// The 99th percentile, absent below 100 values.
    public var p99: Double?
    /// How many values the percentiles were taken from.
    public var count: Int

    /// Makes a distribution from its parts.
    public init(p50: Double?, p95: Double?, p99: Double?, count: Int) {
        self.p50 = p50
        self.p95 = p95
        self.p99 = p99
        self.count = count
    }

    /// The distribution of `values` in any order: they are sorted ascending and each percentile taken by
    /// ``Percentiles/nearestRank(_:of:)``.
    public static func make(_ values: [Double]) -> Distribution {
        let sorted = values.sorted()
        return Distribution(p50: Percentiles.nearestRank(50, of: sorted),
                            p95: Percentiles.nearestRank(95, of: sorted),
                            p99: Percentiles.nearestRank(99, of: sorted),
                            count: sorted.count)
    }
}

/// A reason to read a summary with care. Flags are ordered by their raw value, the order a summary lists them in.
public enum QualityFlag: String, Codable, Comparable, Sendable {
    /// No frame was measured.
    case noSamples = "no-samples"
    /// Fewer than 20 measured intervals, so the interval p95 is absent.
    case tooFewForP95 = "too-few-for-p95"
    /// Fewer than 100 measured intervals, so the interval p99 is absent.
    case tooFewForP99 = "too-few-for-p99"
    /// At least one measured frame was dropped.
    case droppedFrames = "dropped-frames"
    /// At least one measured frame has no GPU time, so there is no GPU distribution.
    case gpuTimeNotAvailable = "gpu-time-not-available"

    /// Orders flags by their raw value.
    public static func < (lhs: QualityFlag, rhs: QualityFlag) -> Bool { lhs.rawValue < rhs.rawValue }
}

/// The statistics of one run: distributions over the measured frames only, the excluded frames counted, and the
/// quality flags.
public struct Summary: Codable, Equatable, Sendable {
    /// The frame interval over the measured frames that have one.
    public var interval: Distribution
    /// The presenter's CPU submit time over every measured frame.
    public var cpu: Distribution
    /// The GPU time over every measured frame, present only when every measured frame has one.
    public var gpu: Distribution?
    /// How many frames were measured.
    public var measured: Int
    /// How many warm-up frames were left out.
    public var warmUpExcluded: Int
    /// How many cool-down frames were left out.
    public var coolDownExcluded: Int
    /// How many measured frames were dropped.
    public var dropped: Int
    /// The quality flags, sorted and without repeats.
    public var flags: [QualityFlag]

    /// Makes a summary from its parts; `flags` is stored sorted and without repeats.
    public init(interval: Distribution, cpu: Distribution, gpu: Distribution?, measured: Int, warmUpExcluded: Int,
                coolDownExcluded: Int, dropped: Int, flags: [QualityFlag]) {
        self.interval = interval
        self.cpu = cpu
        self.gpu = gpu
        self.measured = measured
        self.warmUpExcluded = warmUpExcluded
        self.coolDownExcluded = coolDownExcluded
        self.dropped = dropped
        self.flags = Array(Set(flags)).sorted()
    }

    /// Summarises a validated sample set. The set is checked with ``SampleSet/validate(_:)`` first and its error
    /// passed on. Only frames of the measurement phase count:
    /// - the interval distribution is over the measured frames that have an interval (the run's first frame has none);
    /// - the CPU distribution is over every measured frame;
    /// - the GPU distribution is present only when there is a measured frame and every measured frame has a GPU
    ///   time; otherwise it is absent and ``QualityFlag/gpuTimeNotAvailable`` is flagged.
    ///
    /// When nothing was measured the only flag is ``QualityFlag/noSamples``: the count and GPU flags describe measured
    /// frames and are not raised for an empty measurement. Otherwise ``QualityFlag/tooFewForP95`` is raised below 20
    /// measured intervals, ``QualityFlag/tooFewForP99`` below 100, and ``QualityFlag/droppedFrames`` when a measured
    /// frame was dropped (a dropped warm-up or cool-down frame is not counted).
    public static func make(_ samples: [FrameSample]) throws(SampleError) -> Summary {
        try SampleSet.validate(samples)
        var intervals: [Double] = []
        var cpuTimes: [Double] = []
        var gpuTimes: [Double] = []
        var everyFrameHasGPU = true
        var measured = 0
        var warmUp = 0
        var coolDown = 0
        var dropped = 0
        for sample in samples {
            switch sample.phase {
            case .warmUp:
                warmUp += 1
            case .coolDown:
                coolDown += 1
            case .measure:
                measured += 1
                if let interval = sample.intervalMs { intervals.append(interval) }
                cpuTimes.append(sample.cpuMs)
                if let gpu = sample.gpuMs { gpuTimes.append(gpu) } else { everyFrameHasGPU = false }
                if sample.dropped { dropped += 1 }
            }
        }
        var flags: [QualityFlag] = []
        var gpu: Distribution?
        if measured == 0 {
            flags.append(.noSamples)
        } else {
            if everyFrameHasGPU { gpu = Distribution.make(gpuTimes) } else { flags.append(.gpuTimeNotAvailable) }
            if intervals.count < (Percentiles.minimumCount[95] ?? 20) { flags.append(.tooFewForP95) }
            if intervals.count < (Percentiles.minimumCount[99] ?? 100) { flags.append(.tooFewForP99) }
            if dropped > 0 { flags.append(.droppedFrames) }
        }
        return Summary(interval: Distribution.make(intervals), cpu: Distribution.make(cpuTimes), gpu: gpu,
                       measured: measured, warmUpExcluded: warmUp, coolDownExcluded: coolDown, dropped: dropped,
                       flags: flags)
    }
}
