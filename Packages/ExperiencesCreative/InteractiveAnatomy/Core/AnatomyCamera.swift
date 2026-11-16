// AnatomyCamera — feature 125 (A17-P02) T-A17-203 (FR-A17-203, FR-A17-208; clarification Q3; data-model
// "AnatomyCameraState"; contracts/scene.md; SC-A17-203). The stored camera steps of Interactive Anatomy, after the
// Molecular Explorer precedent:
// - turn: 0…23 steps of 15° about the vertical axis; a step wraps (23 + 1 → 0, 0 − 1 → 23);
// - tilt: −6…6 steps of 10°; a step beyond is refused;
// - zoom: −4…6 steps, each multiplying the framed distance by 0.85; a step beyond is refused.
// A step is −1 or +1; any other step, or a step beyond a limit, returns false and leaves the state unchanged (the
// adapter maps a limit to `a17.camera-limit`). The opening view is turn 2 (30°), tilt 1 (10°), zoom 0.
//
// Framing: the framed distance is r × 1.25 / sin(h) for a sphere of radius r, with h the narrower half field of view:
// the vertical field of view is 60° (half 30°), the horizontal half is atan(tan 30° × aspect), aspect = width /
// height. The camera distance is the framed distance × 0.85^zoom. The derived `OrbitCamera` looks at the sphere's
// centre with yaw = turn × 15° and pitch = tilt × 10° (radians), a 60° vertical field of view, and near and far planes
// fitted around the sphere. The opening view frames the region sphere; a selection frames its part's sphere.
import Foundation
import VisualCoreMath

/// The stored camera steps: turn, tilt and zoom (see the file header).
public struct AnatomyCameraState: Codable, Equatable, Sendable {
    /// The number of turn positions (24 × 15° = 360°).
    public static let turnPositions = 24
    /// Degrees per turn step.
    public static let turnStepDegrees = 15.0
    /// The allowed tilt steps.
    public static let tiltRange = -6...6
    /// Degrees per tilt step.
    public static let tiltStepDegrees = 10.0
    /// The allowed zoom steps.
    public static let zoomRange = -4...6
    /// The distance factor per zoom step.
    public static let zoomFactor = 0.85
    /// The margin around the framed sphere.
    public static let framingMargin = 1.25
    /// The vertical field of view, degrees.
    public static let verticalFieldOfViewDegrees = 60.0
    /// The opening view: turn 2 (30°), tilt 1 (10°), zoom 0.
    public static let opening = AnatomyCameraState(turn: 2, tilt: 1, zoom: 0)

    /// Turn steps, 0…23.
    public var turn: Int
    /// Tilt steps, −6…6.
    public var tilt: Int
    /// Zoom steps, −4…6 (positive is closer).
    public var zoom: Int

    /// Creates a state from raw steps (not checked; see `isValid`).
    public init(turn: Int, tilt: Int, zoom: Int) {
        self.turn = turn
        self.tilt = tilt
        self.zoom = zoom
    }

    /// True when every step is in its range.
    public var isValid: Bool {
        (0..<Self.turnPositions).contains(turn) && Self.tiltRange.contains(tilt) && Self.zoomRange.contains(zoom)
    }

    /// Turns by `delta` (−1 or +1), wrapping around; false, with nothing changed, for any other delta.
    public mutating func turn(_ delta: Int) -> Bool {
        guard delta == 1 || delta == -1 else { return false }
        turn = ((turn + delta) % Self.turnPositions + Self.turnPositions) % Self.turnPositions
        return true
    }

    /// Tilts by `delta` (−1 or +1); false, with nothing changed, for any other delta or a result outside −6…6.
    public mutating func tilt(_ delta: Int) -> Bool {
        guard delta == 1 || delta == -1, Self.tiltRange.contains(tilt + delta) else { return false }
        tilt += delta
        return true
    }

    /// Zooms by `delta` (−1 or +1; positive is closer); false, with nothing changed, for any other delta or a result
    /// outside −4…6.
    public mutating func zoom(_ delta: Int) -> Bool {
        guard delta == 1 || delta == -1, Self.zoomRange.contains(zoom + delta) else { return false }
        zoom += delta
        return true
    }

    /// Returns to the opening view (Reset view).
    public mutating func reset() {
        self = .opening
    }

    /// The narrower half field of view, radians, for `aspect` = width / height (a non-positive or non-finite aspect
    /// counts as 1).
    public static func narrowerHalfFieldOfView(aspect: Double) -> Double {
        let a = aspect > 0 && aspect.isFinite ? aspect : 1
        let halfY = verticalFieldOfViewDegrees * .pi / 360
        return min(halfY, atan(tan(halfY) * a))
    }

    /// The distance at which a sphere of `radius` fits the narrower axis with the framing margin.
    public static func framedDistance(radius: Double, aspect: Double) -> Double {
        max(radius, 0) * framingMargin / sin(narrowerHalfFieldOfView(aspect: aspect))
    }

    /// The orbit camera framing the sphere at `center` with `radius` from these steps (see the file header).
    public func camera(center: Vec3, radius: Double, aspect: Double) -> OrbitCamera {
        let r = max(radius, 0)
        let d = Self.framedDistance(radius: r, aspect: aspect) * pow(Self.zoomFactor, Double(zoom))
        let near = max((d - r) * 0.5, 0.01)
        let far = max(d + r * 2, near * 2)
        return OrbitCamera(target: center, distance: d, yaw: Double(turn) * Self.turnStepDegrees * .pi / 180,
                           pitch: Double(tilt) * Self.tiltStepDegrees * .pi / 180,
                           fovY: Self.verticalFieldOfViewDegrees * .pi / 180, near: near, far: far)
    }
}
