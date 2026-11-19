// FrameSample — feature 173 (A24-P01) T-A24-104 (FR-A24-102; clarification Q3; data-model.md "RunPhase",
// "FrameSample"). One frame's measurements: its index, the run phase it fell in, the interval from the previous frame,
// the presenter's own CPU submit time, the GPU time when a timer is confirmed, and whether the frame was dropped.
// Choices recorded here: every duration is finite and within 0…1,000 ms; a run holds at most 20,000 samples (60 s at
// 120 Hz is 7,200). ``SampleSet/validate(_:)`` checks, in order: the count (`tooManySamples`), then each sample in
// turn: its durations in the order intervalMs, cpuMs, gpuMs (NaN or infinity: `notFinite`; below 0 or above
// 1,000 ms: `outOfRange`), an absent interval anywhere but the first sample (`outOfRange` of `intervalMs`), then its
// order (a negative index, an index not above the previous one or a phase before the previous one: `outOfOrder`).
// Errors name the sample's frame index. Pure Foundation; no UI, GPU or clock.
import Foundation

/// The phase of a run a frame fell in. Ordered warm-up, measurement, cool-down; phases never go back within a run.
public enum RunPhase: String, Codable, Comparable, Sendable {
    /// The warm-up; its frames are counted but left out of the statistics.
    case warmUp
    /// The measurement; its frames make the statistics.
    case measure
    /// The cool-down; its frames are counted but left out of the statistics.
    case coolDown

    /// The phase's position in the run: 0, 1, 2.
    private var order: Int {
        switch self {
        case .warmUp: 0
        case .measure: 1
        case .coolDown: 2
        }
    }

    /// Orders phases as they occur in a run.
    public static func < (lhs: RunPhase, rhs: RunPhase) -> Bool { lhs.order < rhs.order }
}

/// One frame's measurements. Durations are in milliseconds.
public struct FrameSample: Codable, Equatable, Sendable {
    /// The frame's index, at least 0 and strictly increasing within a run.
    public var frameIndex: Int
    /// The phase the frame fell in.
    public var phase: RunPhase
    /// The time from the previous frame, absent for the run's first frame.
    public var intervalMs: Double?
    /// The presenter's own CPU submit time.
    public var cpuMs: Double
    /// The GPU time, absent unless a GPU timer is confirmed.
    public var gpuMs: Double?
    /// Whether the frame was dropped (missed its presentation).
    public var dropped: Bool

    /// A sample with the given values (not checked; see ``SampleSet/validate(_:)``).
    public init(frameIndex: Int, phase: RunPhase, intervalMs: Double?, cpuMs: Double, gpuMs: Double? = nil,
                dropped: Bool = false) {
        self.frameIndex = frameIndex
        self.phase = phase
        self.intervalMs = intervalMs
        self.cpuMs = cpuMs
        self.gpuMs = gpuMs
        self.dropped = dropped
    }
}

/// The caps of a sample set.
public enum SampleLimits {
    /// The largest duration a sample may hold, in milliseconds; the smallest is 0.
    public static let maxDurationMs: Double = 1_000.0
    /// The most samples a run may hold.
    public static let maxSamples = 20_000
}

/// Why a sample set was refused. `frame` is the frame index of the offending sample.
public enum SampleError: Error, Equatable, Sendable {
    /// The named duration of the frame is NaN or infinite.
    case notFinite(frame: Int, field: String)
    /// The named duration of the frame is below 0 or above ``SampleLimits/maxDurationMs``, or (`intervalMs`) absent
    /// on a sample other than the first.
    case outOfRange(frame: Int, field: String)
    /// The frame's index is negative or not above the previous one, or its phase is before the previous one.
    case outOfOrder(frame: Int)
    /// The set holds more than ``SampleLimits/maxSamples`` samples.
    case tooManySamples(count: Int)
}

/// Checks of a run's samples as a whole.
public enum SampleSet {
    /// Refuses a sample set outside its caps. Checks the count first (``SampleError/tooManySamples(count:)``), then
    /// each sample in turn: its durations (``SampleError/notFinite(frame:field:)``,
    /// ``SampleError/outOfRange(frame:field:)``), an absent interval other than on the first sample
    /// (``SampleError/outOfRange(frame:field:)`` of `intervalMs`), then its order (``SampleError/outOfOrder(frame:)``).
    public static func validate(_ samples: [FrameSample]) throws(SampleError) {
        guard samples.count <= SampleLimits.maxSamples else { throw .tooManySamples(count: samples.count) }
        var previous: FrameSample?
        for sample in samples {
            let frame = sample.frameIndex
            if let interval = sample.intervalMs {
                try check(interval, frame: frame, field: "intervalMs")
            } else if previous != nil {
                throw .outOfRange(frame: frame, field: "intervalMs")
            }
            try check(sample.cpuMs, frame: frame, field: "cpuMs")
            if let gpu = sample.gpuMs {
                try check(gpu, frame: frame, field: "gpuMs")
            }
            guard frame >= 0 else { throw .outOfOrder(frame: frame) }
            if let previous, frame <= previous.frameIndex || sample.phase < previous.phase {
                throw .outOfOrder(frame: frame)
            }
            previous = sample
        }
    }

    /// Refuses a duration that is not finite or not within 0…``SampleLimits/maxDurationMs``.
    private static func check(_ value: Double, frame: Int, field: String) throws(SampleError) {
        guard value.isFinite else { throw .notFinite(frame: frame, field: field) }
        guard value >= 0, value <= SampleLimits.maxDurationMs else { throw .outOfRange(frame: frame, field: field) }
    }
}
