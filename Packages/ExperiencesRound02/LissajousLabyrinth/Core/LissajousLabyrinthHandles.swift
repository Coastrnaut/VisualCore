// LissajousLabyrinthHandles — feature 314 (R02-G02-04) T-R02G0204-002 (FR-R02G0204-001, 002, 004; clarifications Q1,
// Q3; research R1–R3). The four dial rings of the labyrinth: one ring per dial in a column to the right of the stage as the
// authored camera sees it (centre = stage centre + right · 1.35 R, centres 0.45 R apart along the authored up vector,
// frequencyA, frequencyB, phaseA, phaseC from top, radius 0.18 R, R the stage radius), each facing the authored eye. A
// knob sits on each ring at value · 40° (frequencies 1 … 9) or value · 22.5° (phases 0 … 15) clockwise from the ring's up
// direction as seen from the eye; a turned angle maps back to a value by whole steps from the start value. The rings are
// R02-F22 `SpatialHandle`s with id = dial index, so the shared `HandlePicker` and `HandleDrag` pick and drag them.
import Foundation
import VisualCoreMath
import VisualCoreScenes

/// The dial rings of Lissajous Labyrinth: layout, knob positions, angle ↔ value mapping and the shared spatial handles.
///
/// Every position depends on the level only through ``LissajousLabyrinthSceneGeometry/stageBounds(level:)`` (never on
/// the dials or the orbit), so the rings do not move while a dial turns or the camera orbits.
///
/// Angle convention: a ring angle is measured in radians from the ring's up direction (``up``) **clockwise as seen from
/// the eye** of the authored camera, that is towards ``right`` first. A positive turned angle is a clockwise turn and
/// raises the value. The ring normal ``ringNormal`` points towards the eye, so the right-hand-rule angle that
/// `HandleDrag(.plane(ringNormal)).angle(around: ringCentre)` reports is the *negative* of this turned angle; a gesture
/// controller should accumulate differences of ``angle(of:dial:level:)`` instead (``angleDelta(from:to:)``).
public enum LissajousLabyrinthHandles {
    /// The ring radius as a fraction of the stage radius R, 0.18.
    public static let ringRadiusFraction = 0.18
    /// The distance between neighbouring ring centres as a fraction of R, 0.45.
    public static let ringSpacingFraction = 0.45
    /// The offset of the ring column from the stage centre along ``right`` as a fraction of R, 1.35.
    public static let ringOffsetFraction = 1.35
    /// The knob radius (the drawn knob and the reserve the camera keeps around each ring) as a fraction of R, 0.045.
    public static let knobRadiusFraction = 0.045
    /// The extra hit radius of every handle in screen points (0: the picker's 22-point touch radius applies).
    public static let hitRadius = 0.0
    /// The angle of one frequency step in radians, 40° (2π / 9).
    public static let frequencyStepAngle = 40.0 * Double.pi / 180
    /// The angle of one phase step in radians, 22.5° (π / 8).
    public static let phaseStepAngle = Double.pi / 8
    /// The number of phase steps in one turn, 16.
    public static let phaseStepsPerTurn = 16

    /// The unit normal of every ring's plane: the authored eye direction (pointing from the stage towards the eye).
    public static let ringNormal: Vec3 = LissajousLabyrinthSceneGeometry.eyeDirection
    /// The authored camera's unit right vector: view direction × +y, normalized (as `Mat4.lookAt` builds it).
    public static let right: Vec3 = LissajousLabyrinthSceneGeometry.viewDirection.cross(Vec3(0, 1, 0)).normalized
    /// The authored camera's unit up vector: ``right`` × view direction; every ring's angle 0 points along it.
    public static let up: Vec3 = right.cross(LissajousLabyrinthSceneGeometry.viewDirection)

    /// The stage radius R of `level` (``LissajousLabyrinthSceneGeometry/stageBounds(level:)``).
    static func stageRadius(_ level: LissajousLabyrinthLevel) -> Double {
        LissajousLabyrinthSceneGeometry.stageBounds(level: level).radius
    }

    /// The index of `dial` in `LissajousLabyrinthDial.allCases` (frequencyA 0, frequencyB 1, phaseA 2, phaseC 3): its
    /// handle id and its row in the ring column from top.
    public static func index(_ dial: LissajousLabyrinthDial) -> Int {
        LissajousLabyrinthDial.allCases.firstIndex(of: dial) ?? 0
    }

    /// The dial of handle id `id` (0 … 3 in `LissajousLabyrinthDial.allCases` order); nil for any other id.
    public static func dial(id: Int) -> LissajousLabyrinthDial? {
        let all: [LissajousLabyrinthDial] = LissajousLabyrinthDial.allCases
        return id >= 0 && id < all.count ? all[id] : nil
    }

    /// The radius of every ring of `level`, 0.18 R.
    public static func ringRadius(level: LissajousLabyrinthLevel) -> Double {
        ringRadiusFraction * stageRadius(level)
    }

    /// The radius of every knob of `level`, 0.045 R.
    public static func knobRadius(level: LissajousLabyrinthLevel) -> Double {
        knobRadiusFraction * stageRadius(level)
    }

    /// The centre of `dial`'s ring: stage centre + ``right`` · 1.35 R + ``up`` · (0.675 − 0.45 · row) R, row =
    /// ``index(_:)``, so the column of four is centred on the stage centre's height and ordered from top.
    public static func ringCentre(_ dial: LissajousLabyrinthDial, level: LissajousLabyrinthLevel) -> Vec3 {
        let stage = LissajousLabyrinthSceneGeometry.stageBounds(level: level)
        let r: Double = stage.radius
        let row: Double = Double(index(dial))
        let height: Double = (1.5 - row) * ringSpacingFraction * r
        return stage.centre + right * (ringOffsetFraction * r) + up * height
    }

    /// The plane of `dial`'s ring: its centre and unit normal ``ringNormal``, for `HandleDrag(.plane(normal))`.
    public static func ringPlane(_ dial: LissajousLabyrinthDial,
                                 level: LissajousLabyrinthLevel) -> (centre: Vec3, normal: Vec3) {
        (ringCentre(dial, level: level), ringNormal)
    }

    /// The angle of one step of `dial` in radians: 40° for the frequencies, 22.5° for the phases.
    public static func stepAngle(_ dial: LissajousLabyrinthDial) -> Double {
        switch dial {
        case .frequencyA, .frequencyB: frequencyStepAngle
        case .phaseA, .phaseC: phaseStepAngle
        }
    }

    /// The knob angle of `value` on `dial`'s ring: value · ``stepAngle(_:)`` (clockwise from ``up`` as seen from the
    /// eye). The value is clamped to the dial's range (frequencies 1 … 9, 40° … 360°; phases 0 … 15, 0° … 337.5°).
    public static func knobAngle(_ dial: LissajousLabyrinthDial, value: Int) -> Double {
        let v: Int = min(max(value, dial.range.lowerBound), dial.range.upperBound)
        return Double(v) * stepAngle(dial)
    }

    /// The knob of `dial` at `value` (clamped to the dial's range): on the ring circle at ``knobAngle(_:value:)`` θ,
    /// centre + ringRadius · (``up`` · cos θ + ``right`` · sin θ).
    public static func knob(_ dial: LissajousLabyrinthDial, value: Int, level: LissajousLabyrinthLevel) -> Vec3 {
        let theta: Double = knobAngle(dial, value: value)
        let radius: Double = ringRadius(level: level)
        return ringCentre(dial, level: level) + (up * cos(theta) + right * sin(theta)) * radius
    }

    /// The ring angle of `point` on `dial`'s ring: the clockwise angle (as seen from the eye) from ``up`` to the
    /// point's offset from the ring centre, projected onto the ring plane, in −π … π (atan2 of the ``right`` and ``up``
    /// components). Nil for a non-finite point or one within 10⁻⁹ R of the ring's axis.
    public static func angle(of point: Vec3, dial: LissajousLabyrinthDial, level: LissajousLabyrinthLevel) -> Double? {
        guard point.isFinite else { return nil }
        let offset: Vec3 = point - ringCentre(dial, level: level)
        let x: Double = offset.dot(right), y: Double = offset.dot(up)
        guard (x * x + y * y).squareRoot() > 1e-9 * stageRadius(level) else { return nil }
        return atan2(x, y)
    }

    /// The signed change from ring angle `a` to ring angle `b`, wrapped into −π … π (the shortest turn), for
    /// accumulating a turned angle from successive ``angle(of:dial:level:)`` readings; 0 for a non-finite input.
    public static func angleDelta(from a: Double, to b: Double) -> Double {
        guard a.isFinite, b.isFinite else { return 0 }
        var d: Double = (b - a).truncatingRemainder(dividingBy: 2 * Double.pi)
        if d > Double.pi { d -= 2 * Double.pi }
        if d < -Double.pi { d += 2 * Double.pi }
        return d
    }

    /// The value of `dial` after turning it from `start` by `turnedAngle` radians (positive = clockwise as seen from
    /// the eye, see the type's angle convention): start + round(angle / ``stepAngle(_:)``) (halves away from zero),
    /// clamped to 1 … 9 for the frequencies and taken modulo 16 for the phases. `start` itself is first clamped (or
    /// wrapped) into the dial's range; a non-finite angle gives that start.
    public static func value(_ dial: LissajousLabyrinthDial, start: Int, turnedAngle: Double) -> Int {
        switch dial {
        case .frequencyA, .frequencyB:
            let low: Int = dial.range.lowerBound, high: Int = dial.range.upperBound
            let base: Int = min(max(start, low), high)
            guard turnedAngle.isFinite else { return base }
            let steps: Double = (turnedAngle / frequencyStepAngle).rounded()
            let target: Double = min(max(Double(base) + steps, Double(low)), Double(high))
            return Int(target)
        case .phaseA, .phaseC:
            let n: Int = phaseStepsPerTurn
            let base: Int = ((start % n) + n) % n
            guard turnedAngle.isFinite else { return base }
            let turns: Double = (turnedAngle / phaseStepAngle).rounded()
            let k: Int = Int(turns.truncatingRemainder(dividingBy: Double(n)))
            return ((base + k) % n + n) % n
        }
    }

    /// The four spatial handles of `level` at `dials`, in `LissajousLabyrinthDial.allCases` order with id = dial index
    /// (``index(_:)``): each a `.rotation(ringNormal)` handle at its ``knob(_:value:level:)`` for the dial's current
    /// value (dragged with `DragConstraint.plane(ringNormal)`), hit radius ``hitRadius``.
    ///
    /// - Throws: `SpatialControlError` from `SpatialHandle.init`; not expected, every position is finite.
    public static func spatialHandles(level: LissajousLabyrinthLevel,
                                      dials: LissajousLabyrinthDials) throws -> [SpatialHandle] {
        var handles: [SpatialHandle] = []
        for dial in LissajousLabyrinthDial.allCases {
            handles.append(try SpatialHandle(id: index(dial), position: knob(dial, value: dials[dial], level: level),
                                             kind: .rotation(ringNormal), hitRadius: hitRadius))
        }
        return handles
    }
}
