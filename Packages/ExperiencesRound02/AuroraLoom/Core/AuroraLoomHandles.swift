// AuroraLoomHandles — feature 304 (R02-G01-04) T-R02G0104-002 (FR-R02G0104-001, 004; SC-R02G0104-001; clarification
// Q1; research R1). The spatial controls of the loom: each ribbon's wave anchor slides on a vertical rail just beyond the
// loom's right end in its lane (x = +L/2 + 0.45, height H · (2w/15 − 1), steps 0 … 15 spanning −H … +H), and each
// ribbon's phase dial is a ring of radius 0.3 standing across the loom just before its left end (x = −L/2 − 0.45) in its
// lane, its knob at angle p · 22.5°. Positions map back to steps by the nearest step (waveStep) or by whole 22.5° turns
// from the start step (phaseStep). The handles are R02-F22 `SpatialHandle`s with id = `AuroraLoomHandleID.raw`, so the
// shared `HandlePicker` and `HandleDrag` do the picking and the constrained dragging.
import Foundation
import VisualCoreMath
import VisualCoreScenes

/// The identity of one spatial handle: a ribbon's wave anchor or phase dial.
public struct AuroraLoomHandleID: Sendable, Equatable, Hashable {
    /// The ribbon, 0 … 2.
    public let ribbon: Int
    /// The control the handle sets: `.wave` for the rail anchor, `.phase` for the dial.
    public let control: AuroraLoomControl

    /// The handle of `control` of `ribbon`; nil for a ribbon outside 0 … 2.
    public init?(ribbon: Int, control: AuroraLoomControl) {
        guard ribbon >= 0, ribbon < AuroraLoomSceneGeometry.ribbonCount else { return nil }
        self.ribbon = ribbon
        self.control = control
    }

    /// The handle with the given `raw` value (ribbon · 2 + 0 for wave, + 1 for phase); nil outside 0 … 5.
    public init?(raw: Int) {
        guard raw >= 0, raw < 2 * AuroraLoomSceneGeometry.ribbonCount else { return nil }
        self.ribbon = raw / 2
        self.control = raw % 2 == 0 ? .wave : .phase
    }

    /// The handle's `SpatialHandle.id`: ribbon · 2 + (wave ? 0 : 1), so 0 … 5.
    public var raw: Int {
        ribbon * 2 + (control == .wave ? 0 : 1)
    }

    /// All six handles in raw order (ribbon 0 wave, ribbon 0 phase, ribbon 1 wave, …).
    public static var all: [AuroraLoomHandleID] {
        var result: [AuroraLoomHandleID] = []
        for raw in 0..<(2 * AuroraLoomSceneGeometry.ribbonCount) {
            if let id = AuroraLoomHandleID(raw: raw) { result.append(id) }
        }
        return result
    }
}

/// The anchor rails and phase dials of the loom: positions, step mappings and the shared spatial handles.
///
/// Dial angle convention: a dial lies in the y–z plane (normal +x) at its centre; angle 0 points to +y and positive
/// angles turn towards +z, which is the right-hand rule about +x, so `HandleDrag(.plane(dialNormal))`'s
/// `angle(around: dialCentre)` is a turn in the direction of increasing phase.
public enum AuroraLoomHandles {
    /// The distance of the rails and dials beyond the loom ends along x, 0.45.
    public static let railOffset = 0.45
    /// The x of every wave anchor rail, +L/2 + 0.45.
    public static let railX = AuroraLoomSceneGeometry.length / 2 + railOffset
    /// The x of every phase dial centre, −L/2 − 0.45.
    public static let dialX = -(AuroraLoomSceneGeometry.length / 2 + railOffset)
    /// The radius of a phase dial, 0.3.
    public static let dialRadius = 0.3
    /// The direction an anchor slides along, +y.
    public static let railAxis = Vec3(0, 1, 0)
    /// The normal of every dial's plane (the axis it turns about), +x.
    public static let dialNormal = Vec3(1, 0, 0)
    /// The highest wave or phase step, 15.
    public static let maxStep = 15
    /// The number of phase steps in one turn, 16.
    public static let phaseStepsPerTurn = 16
    /// The angle of one phase step in radians, 22.5° (π / 8).
    public static let phaseStepAngle = Double.pi / 8
    /// The extra hit radius of every handle in screen points (0: the picker's 22-point touch radius applies).
    public static let hitRadius = 0.0

    /// `ribbon` clamped to 0 … 2.
    static func clampedRibbon(_ ribbon: Int) -> Int {
        min(max(ribbon, 0), AuroraLoomSceneGeometry.ribbonCount - 1)
    }

    /// The position of `ribbon`'s wave anchor at `wave`: (railX, H · (2 · wave / 15 − 1), lane). The ribbon is clamped
    /// to 0 … 2 and the wave to 0 … 15.
    public static func anchorPosition(ribbon: Int, wave: Int) -> Vec3 {
        let r: Int = clampedRibbon(ribbon)
        let w: Int = min(max(wave, 0), maxStep)
        let y: Double = AuroraLoomSceneGeometry.amplitude * (2 * Double(w) / Double(maxStep) - 1)
        return Vec3(railX, y, AuroraLoomSceneGeometry.lane(ribbon: r))
    }

    /// The centre of `ribbon`'s phase dial (clamped to 0 … 2): (dialX, 0, lane).
    public static func dialCentre(ribbon: Int) -> Vec3 {
        Vec3(dialX, 0, AuroraLoomSceneGeometry.lane(ribbon: clampedRibbon(ribbon)))
    }

    /// The knob of `ribbon`'s phase dial at `phase` (taken modulo 16): on the dial circle at angle a = phase · 22.5°
    /// measured from +y towards +z, (dialX, 0.3 · cos a, lane + 0.3 · sin a).
    public static func dialKnob(ribbon: Int, phase: Int) -> Vec3 {
        let p: Int = ((phase % phaseStepsPerTurn) + phaseStepsPerTurn) % phaseStepsPerTurn
        let a: Double = Double(p) * phaseStepAngle
        let centre: Vec3 = dialCentre(ribbon: ribbon)
        return Vec3(centre.x, centre.y + dialRadius * cos(a), centre.z + dialRadius * sin(a))
    }

    /// The wave step nearest to an anchor height `y`: round((y / H + 1) · 7.5) clamped to 0 … 15 (halves round away
    /// from zero); a non-finite height gives 0.
    public static func waveStep(atHeight y: Double) -> Int {
        guard y.isFinite else { return 0 }
        let raw: Double = ((y / AuroraLoomSceneGeometry.amplitude + 1) * Double(maxStep) / 2).rounded()
        let clamped: Double = min(max(raw, 0), Double(maxStep))
        return Int(clamped)
    }

    /// The phase step after turning a dial from `start` by `turnedAngle` radians (positive towards increasing phase,
    /// see the type's angle convention): start + round(angle / 22.5°) modulo 16, in 0 … 15 (halves round away from
    /// zero). A non-finite angle gives `start` modulo 16.
    public static func phaseStep(start: Int, turnedAngle: Double) -> Int {
        let n: Int = phaseStepsPerTurn
        let base: Int = ((start % n) + n) % n
        guard turnedAngle.isFinite else { return base }
        let turns: Double = (turnedAngle / phaseStepAngle).rounded()
        let reduced: Double = turns.truncatingRemainder(dividingBy: Double(n))
        let k: Int = Int(reduced)
        return ((base + k) % n + n) % n
    }

    /// The bounds that clamp a drag of `ribbon`'s anchor (clamped to 0 … 2) to its rail: x = railX, y = −H … +H,
    /// z = the lane; for `HandleDrag(start:ray:constraint:bounds:)`.
    public static func railBounds(ribbon: Int) -> (min: Vec3, max: Vec3) {
        let z: Double = AuroraLoomSceneGeometry.lane(ribbon: clampedRibbon(ribbon))
        let h: Double = AuroraLoomSceneGeometry.amplitude
        return (min: Vec3(railX, -h, z), max: Vec3(railX, h, z))
    }

    /// The world position of handle `id` at `steps`: the anchor at the ribbon's wave step or the dial knob at its
    /// phase step. A ribbon missing from `steps` uses step 0.
    public static func position(of id: AuroraLoomHandleID, steps: AuroraLoomSteps) -> Vec3 {
        switch id.control {
        case .wave:
            let w: Int = id.ribbon < steps.wave.count ? steps.wave[id.ribbon] : 0
            return anchorPosition(ribbon: id.ribbon, wave: w)
        case .phase:
            let p: Int = id.ribbon < steps.phase.count ? steps.phase[id.ribbon] : 0
            return dialKnob(ribbon: id.ribbon, phase: p)
        }
    }

    /// The six spatial handles at `steps`, in raw order (id = `AuroraLoomHandleID.raw`): each wave anchor is an
    /// `.axis(railAxis)` handle at `anchorPosition`, each phase dial a `.rotation(dialNormal)` handle at `dialKnob`
    /// (dragged with `DragConstraint.plane(dialNormal)` and read with `HandleDrag.angle(around: dialCentre)`), all with
    /// hit radius `hitRadius`.
    ///
    /// - Throws: `SpatialControlError` from `SpatialHandle.init`; not expected, every position is finite.
    public static func spatialHandles(steps: AuroraLoomSteps) throws -> [SpatialHandle] {
        var handles: [SpatialHandle] = []
        for id in AuroraLoomHandleID.all {
            let kind: HandleKind = id.control == .wave ? .axis(railAxis) : .rotation(dialNormal)
            handles.append(try SpatialHandle(id: id.raw, position: position(of: id, steps: steps), kind: kind,
                                             hitRadius: hitRadius))
        }
        return handles
    }
}
