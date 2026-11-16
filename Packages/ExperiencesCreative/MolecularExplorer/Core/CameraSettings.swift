// CameraSettings — feature 111 (A15-P02) T-A15-203 (FR-A15-220, FR-A15-221; clarification Q3; data-model
// "CameraSettings"; contracts/renderer.md). The stored camera of Molecular Explorer, kept apart from the molecule data:
// - turn: 0…23 steps of 15° around the vertical axis; a turn wraps (23 + 1 → 0, 0 − 1 → 23) and is never refused;
// - tilt: −8…8 steps of 10° (−80°…+80°); a step beyond is refused (false, nothing changed);
// - zoom: −4…4 steps, each moving the camera by a factor 0.85 of the framed distance; a step beyond is refused.
// The default is turn 2 (30°), tilt 2 (20°), zoom 0, so a planar molecule is never seen edge-on. The adapter maps a
// refusal to `a15.camera-limit`.
//
// Framing: the framed distance is R × 1.25 / sin(h), with R the scene's bounding radius and h the narrower half field
// of view: the vertical field of view is 60° (half 30°), the horizontal half is atan(tan 30° × aspect) with
// aspect = width / height. The camera distance is the framed distance × 0.85^zoom; at zoom +4 it is still
// 1.25 × 0.85⁴ / sin(h) ≥ 1.3 R from the centre (sin h ≤ 0.5), outside the bounding sphere. The derived `OrbitCamera`
// looks at the scene's centre with yaw = turn × 15° and pitch = tilt × 10° in radians (within its ±89° clamp), a
// vertical field of view of 60°, and near and far planes fitted around the bounding sphere.
//
// Feature 112 (A15-P03) T-A15-304 (FR-A15-302; clarification Q2; data-model "CameraSettings (extended)"):
// - pan: panX and panY, −10…10 steps each (default 0, 0). One step moves the camera's target by 0.1 × the bounding
//   radius along the view's right (panX) or up (panY) direction for the current turn and tilt:
//   right = (cos yaw, 0, −sin yaw) and up = (−sin pitch · sin yaw, cos pitch, −sin pitch · cos yaw), the axes of the
//   `OrbitCamera` view matrix (eye on the orbit, world up +y). The sign: positive panX moves the TARGET to the view's
//   right, so the molecule appears to move LEFT on the screen (positive panY moves the target up, the molecule appears
//   to move down); a gesture that makes "the molecule follow the fingers" sends dx = −1 for fingers moving right and
//   dy = +1 for fingers moving down (screen y down). The eye moves with the target, so the view direction, the camera
//   distance and the near and far planes are unchanged by a pan;
// - `pan(dx:dy:)` takes one step on each axis, each of dx and dy −1, 0 or 1 and not both 0; anything else, or a result
//   beyond −10…10 on either axis, is refused (false, nothing changed; the adapter maps a value refusal to
//   `a15.invalid-choice` and a limit to `a15.camera-limit`); `reset()` returns to the default, pan 0;
// - coded as `panX` and `panY` beside `turn`, `tilt`, `zoom` (sorted: panX, panY, tilt, turn, zoom); decoding camera
//   JSON without them (schema 2) gives pan 0; a pan outside −10…10 does not decode.
import Foundation
import VisualCoreMath

/// The stored camera steps: turn, tilt and zoom.
public struct CameraSettings: Codable, Equatable, Sendable {
    /// The number of turn positions (24 × 15° = 360°).
    public static let turnPositions = 24
    /// Degrees per turn step.
    public static let turnStepDegrees = 15
    /// The allowed tilt steps.
    public static let tiltRange = -8...8
    /// Degrees per tilt step.
    public static let tiltStepDegrees = 10
    /// The allowed zoom steps.
    public static let zoomRange = -4...4
    /// The distance factor per zoom step.
    public static let zoomFactor = 0.85
    /// The margin around the bounding sphere at the framed distance.
    public static let framingMargin = 1.25
    /// The vertical field of view, degrees.
    public static let verticalFieldOfViewDegrees = 60.0
    /// The allowed pan steps on each axis (feature 112).
    public static let panRange = -10...10
    /// The target shift per pan step as a fraction of the bounding radius (feature 112).
    public static let panStepFraction = 0.1
    /// Turn 2 (30°), tilt 2 (20°), zoom 0, pan 0, 0.
    public static let `default` = CameraSettings(turnSteps: 2, tiltSteps: 2, zoomSteps: 0)

    /// Turn steps, 0…23.
    public var turnSteps: Int
    /// Tilt steps, −8…8.
    public var tiltSteps: Int
    /// Zoom steps, −4…4.
    public var zoomSteps: Int
    /// Horizontal pan steps, −10…10 (positive: the target moves to the view's right).
    public var panX: Int
    /// Vertical pan steps, −10…10 (positive: the target moves up the view).
    public var panY: Int

    /// Creates settings: the turn is wrapped into 0…23, the tilt, zoom and pan are clamped into their ranges.
    public init(turnSteps: Int, tiltSteps: Int, zoomSteps: Int, panX: Int = 0, panY: Int = 0) {
        self.turnSteps = Self.wrapTurn(turnSteps)
        self.tiltSteps = Self.clamp(tiltSteps, Self.tiltRange)
        self.zoomSteps = Self.clamp(zoomSteps, Self.zoomRange)
        self.panX = Self.clamp(panX, Self.panRange)
        self.panY = Self.clamp(panY, Self.panRange)
    }

    /// `value` clamped into `range`.
    static func clamp(_ value: Int, _ range: ClosedRange<Int>) -> Int {
        min(max(value, range.lowerBound), range.upperBound)
    }

    /// True when every step is in its range.
    public var isValid: Bool {
        Self.isValid(turn: turnSteps, tilt: tiltSteps, zoom: zoomSteps) && Self.panRange.contains(panX)
            && Self.panRange.contains(panY)
    }

    /// True when `turn`, `tilt` and `zoom` are in their ranges (0…23, −8…8, −4…4).
    public static func isValid(turn: Int, tilt: Int, zoom: Int) -> Bool {
        (0..<turnPositions).contains(turn) && tiltRange.contains(tilt) && zoomRange.contains(zoom)
    }

    /// `steps` wrapped into 0…23 (overflow-safe).
    static func wrapTurn(_ steps: Int) -> Int {
        let r = steps % turnPositions
        return r < 0 ? r + turnPositions : r
    }

    /// The turn, degrees (0…345).
    public var turnDegrees: Int { turnSteps * Self.turnStepDegrees }
    /// The tilt, degrees (−80…80).
    public var tiltDegrees: Int { tiltSteps * Self.tiltStepDegrees }

    /// Turns by `delta` steps, wrapping around; never refused.
    public mutating func turn(_ delta: Int) {
        turnSteps = Self.wrapTurn(turnSteps + delta % Self.turnPositions)
    }

    /// Tilts by `delta` steps; false, with nothing changed, when the result leaves −8…8.
    @discardableResult
    public mutating func tilt(_ delta: Int) -> Bool {
        let (next, overflow) = tiltSteps.addingReportingOverflow(delta)
        guard !overflow, Self.tiltRange.contains(next) else { return false }
        tiltSteps = next
        return true
    }

    /// Zooms by `delta` steps (positive moves closer); false, with nothing changed, when the result leaves −4…4.
    @discardableResult
    public mutating func zoom(_ delta: Int) -> Bool {
        let (next, overflow) = zoomSteps.addingReportingOverflow(delta)
        guard !overflow, Self.zoomRange.contains(next) else { return false }
        zoomSteps = next
        return true
    }

    /// Pans by one step on each axis (`dx`, `dy` each −1, 0 or 1, not both 0); false, with nothing changed, for other
    /// values or when either result leaves −10…10.
    @discardableResult
    public mutating func pan(dx: Int, dy: Int) -> Bool {
        let steps = -1...1
        guard steps.contains(dx), steps.contains(dy), dx != 0 || dy != 0,
              Self.panRange.contains(panX + dx), Self.panRange.contains(panY + dy) else { return false }
        panX += dx
        panY += dy
        return true
    }

    /// Returns to the default: turn 2, tilt 2, zoom 0, pan 0, 0.
    public mutating func reset() {
        self = .default
    }

    /// The view's right and up directions (unit, world space) for the current turn and tilt (see the file header).
    public var viewAxes: (right: Vec3, up: Vec3) {
        let yaw = Double(turnDegrees) * .pi / 180, pitch = Double(tiltDegrees) * .pi / 180
        let right = Vec3(cos(yaw), 0, -sin(yaw))
        let up = Vec3(-sin(pitch) * sin(yaw), cos(pitch), -sin(pitch) * cos(yaw))
        return (right, up)
    }

    /// The camera's target: `centre` moved by (panX · right + panY · up) × 0.1 × `boundingRadius`.
    public func target(centre: Vec3, boundingRadius: Double) -> Vec3 {
        let axes = viewAxes
        let step = Self.panStepFraction * max(boundingRadius, 0)
        return centre + (axes.right * Double(panX) + axes.up * Double(panY)) * step
    }

    /// The narrower half field of view, radians, for `aspect` = width / height (a non-positive or non-finite aspect
    /// counts as 1).
    public static func narrowerHalfFieldOfView(aspect: Double) -> Double {
        let a = aspect > 0 && aspect.isFinite ? aspect : 1
        let halfY = verticalFieldOfViewDegrees * .pi / 360
        let halfX = atan(tan(halfY) * a)
        return min(halfY, halfX)
    }

    /// The distance at which a sphere of `boundingRadius` fits the view with the framing margin.
    public static func framedDistance(boundingRadius: Double, aspect: Double) -> Double {
        boundingRadius * framingMargin / sin(narrowerHalfFieldOfView(aspect: aspect))
    }

    /// The camera distance: the framed distance × 0.85^zoom.
    public func distance(boundingRadius: Double, aspect: Double) -> Double {
        Self.framedDistance(boundingRadius: boundingRadius, aspect: aspect) * pow(Self.zoomFactor, Double(zoomSteps))
    }

    /// The orbit camera looking at the panned target (``target(centre:boundingRadius:)``) from these steps (see the
    /// file header).
    public func camera(centre: Vec3, boundingRadius: Double, aspect: Double) -> OrbitCamera {
        let d = distance(boundingRadius: boundingRadius, aspect: aspect)
        let r = max(boundingRadius, 0)
        let near = max((d - r) * 0.5, 0.01)
        let far = max(d + r * 2, near * 2)
        return OrbitCamera(target: target(centre: centre, boundingRadius: boundingRadius), distance: d,
                           yaw: Double(turnDegrees) * .pi / 180, pitch: Double(tiltDegrees) * .pi / 180,
                           fovY: Self.verticalFieldOfViewDegrees * .pi / 180, near: near, far: far)
    }

    /// The coding keys.
    private enum CodingKeys: String, CodingKey {
        case turnSteps = "turn", tiltSteps = "tilt", zoomSteps = "zoom", panX, panY
    }

    /// Decodes settings (an absent `panX` or `panY` is 0); throws for a step outside its range.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let turn = try c.decode(Int.self, forKey: .turnSteps)
        let tilt = try c.decode(Int.self, forKey: .tiltSteps)
        let zoom = try c.decode(Int.self, forKey: .zoomSteps)
        let panX = try c.decodeIfPresent(Int.self, forKey: .panX) ?? 0
        let panY = try c.decodeIfPresent(Int.self, forKey: .panY) ?? 0
        guard Self.isValid(turn: turn, tilt: tilt, zoom: zoom), Self.panRange.contains(panX),
              Self.panRange.contains(panY) else {
            throw DecodingError.dataCorruptedError(forKey: .turnSteps, in: c, debugDescription: "camera step out of range")
        }
        self.turnSteps = turn; self.tiltSteps = tilt; self.zoomSteps = zoom; self.panX = panX; self.panY = panY
    }

    /// Encodes the steps as `turn`, `tilt`, `zoom`, `panX`, `panY`.
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(turnSteps, forKey: .turnSteps)
        try c.encode(tiltSteps, forKey: .tiltSteps)
        try c.encode(zoomSteps, forKey: .zoomSteps)
        try c.encode(panX, forKey: .panX)
        try c.encode(panY, forKey: .panY)
    }
}
