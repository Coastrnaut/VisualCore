// TimeStepPolicy.swift — one bounded variable step per frame (feature 019 T-A02-102; G-CPUFIELD, FR-A02-108).
// Unlike FixedStepClock (fixed sub-steps with an accumulator), this gives exactly one step per frame whose length
// follows the frame interval within bounds, so a resume after a long pause never takes one huge step and never
// runs a catch-up loop.

/// Clamps frame intervals to a simulation step length.
public struct TimeStepPolicy: Sendable, Equatable {
    /// Shortest step in seconds (default 1/240); also used for invalid deltas.
    public let minStep: Double
    /// Longest step in seconds (default 1/30).
    public let maxStep: Double
    /// Deltas longer than `maxStep` that were shortened.
    public private(set) var clampedCount = 0
    /// Deltas that were NaN, infinite, zero or negative.
    public private(set) var invalidCount = 0

    /// Bounds must satisfy 0 < minStep ≤ maxStep (both finite); otherwise the defaults 1/240…1/30 are used.
    public init(minStep: Double = 1.0 / 240, maxStep: Double = 1.0 / 30) {
        if minStep.isFinite, maxStep.isFinite, minStep > 0, minStep <= maxStep {
            self.minStep = minStep
            self.maxStep = maxStep
        } else {
            self.minStep = 1.0 / 240
            self.maxStep = 1.0 / 30
        }
    }

    /// The step for a frame of `delta` seconds: `minStep` for an invalid delta, otherwise `delta` clamped to
    /// `minStep…maxStep`.
    public mutating func clamp(_ delta: Double) -> Double {
        guard delta.isFinite, delta > 0 else {
            invalidCount += 1
            return minStep
        }
        if delta > maxStep {
            clampedCount += 1
            return maxStep
        }
        return max(delta, minStep)
    }
}
