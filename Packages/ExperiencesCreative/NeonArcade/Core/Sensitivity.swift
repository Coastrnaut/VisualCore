// Sensitivity — feature 078 (A10-P04) T-A10-402 (FR-A10-401; clarification 1; research D1; data-model
// "Sensitivity"). The five steering sensitivity steps: step 0 (gentle) … 4 (sharp) with reaches 2.5, 2.0, 1.5, 1.0
// and 0.6 game units of finger offset for full steering; step 2 (reach 1.5, the fixed reach of A10-P01) is the
// default. `steering(offset:step:)` maps a finger's horizontal offset from the player to a steering value:
// offset ÷ reach, clamped to −1…1. A non-finite offset gives 0 (no steering). The step is checked by the
// experience's action (`settings.sensitivity [0…4]`, whole numbers); the core is defensive and clamps a step outside
// 0…4 to the nearest step (−1 → 0, 7 → 4), so a steering value is always defined and bounded.
import Foundation

/// The five steering sensitivity steps and the mapping from finger offset to steering.
public enum Sensitivity {
    /// The reach of each step in game units of finger offset for full steering, gentle (step 0) to sharp (step 4).
    public static let reaches: [Double] = [2.5, 2.0, 1.5, 1.0, 0.6]
    /// The default step (reach 1.5, the fixed reach before sensitivity existed).
    public static let defaultStep = 2
    /// The valid steps, 0…4.
    public static let steps: ClosedRange<Int> = 0...(reaches.count - 1)

    /// `step` clamped to ``steps`` (a step below 0 is 0, one above 4 is 4).
    public static func clampedStep(_ step: Int) -> Int { min(max(step, steps.lowerBound), steps.upperBound) }

    /// The reach of `step` in game units (a step outside ``steps`` is clamped first).
    public static func reach(step: Int) -> Double { reaches[clampedStep(step)] }

    /// The steering value for a finger `offset` (finger x − player x, in game units) at `step`: offset ÷ reach,
    /// clamped to −1…1; 0 for a non-finite offset. A step outside ``steps`` is clamped first.
    public static func steering(offset: Double, step: Int) -> Double {
        guard offset.isFinite else { return 0 }
        return min(max(offset / reach(step: step), -1), 1)
    }
}
