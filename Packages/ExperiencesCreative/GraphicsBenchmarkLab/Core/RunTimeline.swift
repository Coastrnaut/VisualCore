// RunTimeline — feature 174 (A24-P02) T-A24-203 (FR-A24-202; clarification Q2; data-model.md "RunTimeline"). Maps a
// frame time to the run phase it falls in: warm-up while t − start < warm-up, measure while < warm-up + measure,
// cool-down while < total, then finished (nil). The start is the host's monotonic frame time of the run's first frame.
// Choices recorded here: the boundaries are half-open, so a frame at exactly the warm-up length is measured and one at
// exactly the total finishes the run; a time before the start (negative elapsed) counts as warm-up. Pure Foundation; no
// UI, GPU or clock: times are passed in.
import Foundation

/// The phases of one run laid out from its start time, in seconds.
public struct RunTimeline: Sendable, Equatable {
    /// The run's plan: warm-up, measurement and cool-down lengths in whole seconds.
    public let plan: RunPlan
    /// The frame time, in seconds, at which the run started.
    public let start: Double

    /// A timeline of `plan` starting at the frame time `start` (seconds).
    public init(plan: RunPlan, start: Double) {
        self.plan = plan
        self.start = start
    }

    /// The frame time, in seconds, at which the run finishes: `start` plus the plan's total length.
    public var endTime: Double { start + Double(plan.totalSeconds) }

    /// The phase of a frame drawn at `time` (seconds), or nil when the run has finished (time at or after
    /// ``endTime``). A time before ``start`` counts as warm-up.
    public func phase(at time: Double) -> RunPhase? {
        let elapsed = time - start
        let warmUp = Double(plan.warmUpSeconds)
        let measureEnd = warmUp + Double(plan.measureSeconds)
        let total = Double(plan.totalSeconds)
        if elapsed < warmUp { return .warmUp }
        if elapsed < measureEnd { return .measure }
        if elapsed < total { return .coolDown }
        return nil
    }
}
