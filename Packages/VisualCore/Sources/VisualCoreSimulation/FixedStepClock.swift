// FixedStepClock.swift — fixed-timestep accumulator decoupling simulation from the display rate
// (feature 006 T-F507; FR-F503, FR-F511; research R3, after Glenn Fiedler's "Fix Your Timestep!").

/// Converts variable frame deltas into a bounded number of fixed simulation steps.
public struct FixedStepClock: Sendable, Equatable {
    /// An accumulator this close below a step boundary counts as reaching it (spec A1), so 60 frames of
    /// 1/60 s give exactly 120 steps of 1/120 s despite floating-point rounding.
    public static let boundaryTolerance = 1e-9

    /// Fixed step length in seconds (default 1/120; invalid values fall back to it).
    public let step: Double
    /// Most steps returned per frame, clamped to 1…8; time beyond it goes to `droppedTime`.
    public let maxSteps: Int
    /// Elapsed seconds not yet consumed by a step (< `step` after each advance).
    public private(set) var accumulator = 0.0
    /// Simulation time lost to the per-frame step cap (stalls, debugger, backgrounding).
    public private(set) var droppedTime = 0.0
    /// Steps returned since creation, after the cap.
    public private(set) var totalSteps = 0
    /// Frames whose delta was NaN, infinite or negative (treated as zero).
    public private(set) var invalidDeltas = 0

    /// `step` must be > 0 (default 1/120 s); `maxSteps` ≥ 1 (default 8; FR-F512 bound).
    public init(step: Double = 1.0 / 120, maxSteps: Int = 8) {
        self.step = step.isFinite && step > 0 ? step : 1.0 / 120
        self.maxSteps = min(max(maxSteps, 1), 8)
    }

    /// Fraction of a step left in the accumulator, in [0, 1): interpolate rendering between the last two states.
    public var alpha: Double { min(max(accumulator / step, 0), 1 - .ulpOfOne) }
    /// Simulated time so far.
    public var simulatedTime: Double { Double(totalSteps) * step }

    /// Adds a frame's elapsed time and returns how many fixed steps to run now (0…maxSteps).
    public mutating func advance(by dt: Double) -> Int {
        var dt = dt
        if !dt.isFinite || dt < 0 { invalidDeltas += 1; dt = 0 }
        accumulator += dt
        var n = Int(((accumulator + Self.boundaryTolerance) / step).rounded(.down))
        accumulator = max(0, accumulator - Double(n) * step)
        if n > maxSteps {
            droppedTime += Double(n - maxSteps) * step
            n = maxSteps
        }
        totalSteps += n
        return n
    }

    /// Discards accumulated time (e.g. when returning from the background) without counting it as dropped.
    public mutating func resetAccumulator() { accumulator = 0 }
}
