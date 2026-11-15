// ForceLevels — feature 083 (A11-P02) T-A11-203 (FR-A11-210; clarification 4; research D4; data-model "Force
// levels"). The force and stiffness levels a person chooses from:
// - gravity: off 0, Moon 1.62 and Earth 9.81 m/s² downward (levels 0…2, default 2, Earth);
// - drag: none 0, low 0.05 and high 1.0 s⁻¹, the same value for linear and angular drag (levels 0…2, default 1, low);
// - stiffness: 20, 60, 150 and 400 N/m for every spring of the world (levels 0…3, default 1, 60 N/m); each spring clamps
//   it to its stable bound 0.1·m/dt² for its effective mass (`Springs2D.stableStiffness(effectiveMass:dt:)`).
// The world's springs use the damping ratio 0.1, and a world holds at most 16 springs. A world's settings carry the
// gravity and drag of its levels exactly (`PhysicsWorld.validate(catalog:)` refuses a mismatch).
import Foundation
import VisualCoreMath

/// The gravity, drag and stiffness levels of a playground world.
public enum ForceLevels {
    /// The downward gravity of each level in m/s²: off, Moon and Earth.
    public static let gravity: [Double] = [0, 1.62, 9.81]
    /// The default gravity level (2, Earth).
    public static let defaultGravityLevel = 2
    /// The linear and angular drag of each level in s⁻¹: none, low and high.
    public static let drag: [Double] = [0, 0.05, 1.0]
    /// The default drag level (1, low).
    public static let defaultDragLevel = 1
    /// The spring stiffness of each level in N/m.
    public static let stiffness: [Double] = [20, 60, 150, 400]
    /// The default stiffness level (1, 60 N/m).
    public static let defaultStiffnessLevel = 1
    /// The damping ratio of every spring of the world.
    public static let springDampingRatio = 0.1
    /// The most springs a world holds.
    public static let maxSprings = 16

    /// The allowed gravity levels, 0…2.
    public static var gravityLevels: ClosedRange<Int> { 0...(gravity.count - 1) }
    /// The allowed drag levels, 0…2.
    public static var dragLevels: ClosedRange<Int> { 0...(drag.count - 1) }
    /// The allowed stiffness levels, 0…3.
    public static var stiffnessLevels: ClosedRange<Int> { 0...(stiffness.count - 1) }

    /// The gravity vector (0, −g) of `level`, nil outside 0…2.
    public static func gravityVector(level: Int) -> Vec2? {
        gravityLevels.contains(level) ? Vec2(0, -gravity[level]) : nil
    }

    /// The drag coefficient of `level` in s⁻¹, nil outside 0…2.
    public static func dragValue(level: Int) -> Double? {
        dragLevels.contains(level) ? drag[level] : nil
    }

    /// The stiffness of `level` in N/m, nil outside 0…3.
    public static func stiffnessValue(level: Int) -> Double? {
        stiffnessLevels.contains(level) ? stiffness[level] : nil
    }

    /// The gravity level whose vector equals `gravity` exactly, nil when none does.
    public static func gravityLevel(matching gravity: Vec2) -> Int? {
        gravityLevels.first { gravityVector(level: $0) == gravity }
    }

    /// The drag level whose value equals both `linear` and `angular` exactly, nil when none does.
    public static func dragLevel(linear: Double, angular: Double) -> Int? {
        dragLevels.first { drag[$0] == linear && drag[$0] == angular }
    }
}
