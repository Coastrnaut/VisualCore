// FocusFlight — feature 105 (A14-P03) T-A14-307 (FR-A14-320, FR-A14-321; SC-A14-303; clarification Q4; research D4;
// data-model "FocusFlight"; contracts/bodies.md). The eased camera flight Solar System Explorer draws when the focus
// changes. Presentation only: it is never part of the core state, so the state digest stays independent of frame
// timing.
//   - A flight goes from a `from` view (target, distance) to a `to` view over `frameCount` = 30 host steps. At frame f
//     (clamped to 0…30) with t = f / 30 and s = smoothstep(t) = t²(3 − 2t), the target is lerp(from, to, s) and the
//     distance exp(lerp(log from, log to, s)) (log space, so a zoom feels even). Frame 0 is exactly `from` and frame 30
//     exactly `to`.
//   - Reduce Motion cuts: `view(at:)` returns `to` for every frame, frame 0 included, so the new view is drawn on the
//     very first step (a single-step flight).
//   - Clearance: the eye comes from the view through OrbitCamera's own formula (target + (cos p · sin y, sin p,
//     cos p · cos y) · distance). If it lies within 3 × drawn radius + 0.5 × near of a body's scene centre it is
//     pushed radially out to that distance, over every body and up to `clearancePasses` passes, so it never enters a
//     body and the near plane never cuts one.
//   - Restart: a new focus during a flight starts a new flight whose `from` is the view drawn at that moment.
import Foundation
import SolarSystemExplorerCore
import VisualCoreMath

/// The eased flight of the camera between two views (presentation only).
struct FocusFlight: Equatable, Sendable {
    /// A camera view: the point looked at and the eye's distance from it (scene units).
    struct View: Equatable, Sendable {
        /// The scene point the camera looks at.
        var target: Vec3
        /// The eye's distance from the target, scene units (> 0).
        var distance: Double
    }

    /// A body as the clearance sees it: its scene centre and drawn radius.
    struct Body: Equatable, Sendable {
        /// The body's scene centre.
        var center: Vec3
        /// The body's drawn radius, scene units.
        var radius: Double
    }

    /// The host steps of one flight (30).
    static let frameCount = 30
    /// The factor on a body's drawn radius in the clearance (3).
    static let clearanceRadiusFactor = 3.0
    /// The factor on the near plane distance in the clearance (0.5).
    static let clearanceNearFactor = 0.5
    /// The passes over all bodies the clearance push-out makes at most (4).
    static let clearancePasses = 4
    /// The smallest distance used in the log-space interpolation (a non-positive distance is raised to it).
    static let smallestDistance = 1e-9

    /// The view the flight starts from.
    var from: View
    /// The view the flight ends at.
    var to: View
    /// Whether Reduce Motion is on (the flight is cut to `to` at once).
    var reduceMotion: Bool

    /// Creates a flight from `from` to `to`.
    init(from: View, to: View, reduceMotion: Bool = false) {
        self.from = from
        self.to = to
        self.reduceMotion = reduceMotion
    }

    /// The smoothstep easing t²(3 − 2t) of `t` clamped to 0…1.
    static func smoothstep(_ t: Double) -> Double {
        let x = t.isFinite ? min(max(t, 0), 1) : 0
        return x * x * (3 - 2 * x)
    }

    /// The view drawn at `frame` (clamped to 0…30): eased target, log-space distance; `to` for every frame with
    /// Reduce Motion.
    func view(at frame: Int) -> View {
        if reduceMotion { return to }
        let f = min(max(frame, 0), Self.frameCount)
        if f == 0 { return from }
        if f == Self.frameCount { return to }
        let s = Self.smoothstep(Double(f) / Double(Self.frameCount))
        let target = from.target + (to.target - from.target) * s
        let a = log(max(from.distance, Self.smallestDistance))
        let b = log(max(to.distance, Self.smallestDistance))
        return View(target: target, distance: exp(a + (b - a) * s))
    }

    /// Whether the flight has reached `to` at `frame` (always with Reduce Motion).
    func isFinished(at frame: Int) -> Bool { reduceMotion || frame >= Self.frameCount }

    /// A new flight to `to` starting from `currentView` (the view drawn when the new focus arrives), keeping Reduce
    /// Motion.
    func restarted(from currentView: View, to: View) -> FocusFlight {
        FocusFlight(from: currentView, to: to, reduceMotion: reduceMotion)
    }

    /// The clearance of a body of drawn `radius` with the near plane at `near`: 3 × radius + 0.5 × near.
    static func clearance(radius: Double, near: Double) -> Double {
        clearanceRadiusFactor * max(radius, 0) + clearanceNearFactor * max(near, 0)
    }

    /// The unit offset from target to eye at `yaw` and `pitch` (radians), OrbitCamera's formula.
    static func eyeDirection(yaw: Double, pitch: Double) -> Vec3 {
        OrbitCamera(target: .zero, distance: 1, yaw: yaw, pitch: pitch).eye
    }

    /// The eye at `frame` seen at `yaw` and `pitch` (radians), from OrbitCamera's formula, pushed out of every body's
    /// clearance (see ``clearedEye(_:direction:bodies:near:)``).
    func eye(at frame: Int, yaw: Double, pitch: Double, bodies: [Body], near: Double) -> Vec3 {
        let v = view(at: frame)
        let raw = OrbitCamera(target: v.target, distance: v.distance, yaw: yaw, pitch: pitch).eye
        return Self.clearedEye(raw, direction: Self.eyeDirection(yaw: yaw, pitch: pitch), bodies: bodies, near: near)
    }

    /// `eye` pushed radially out of every body's clearance sphere (3 × radius + 0.5 × near around its centre), over all
    /// bodies and up to ``clearancePasses`` passes; an eye exactly at a centre is pushed along `direction`.
    static func clearedEye(_ eye: Vec3, direction: Vec3, bodies: [Body], near: Double) -> Vec3 {
        var e = eye
        let fallback = direction.length > 0 ? direction.normalized : Vec3(0, 1, 0)
        for _ in 0..<clearancePasses {
            var moved = false
            for body in bodies {
                let c = clearance(radius: body.radius, near: near)
                let offset = e - body.center
                let d = offset.length
                if d < c {
                    let unit = d > 0 ? offset / d : fallback
                    e = body.center + unit * c
                    moved = true
                }
            }
            if !moved { break }
        }
        return e
    }

    /// The nine catalog bodies in `mode` on `day` (days since J2000.0): scene centre from the model's heliocentric
    /// position (the Sun, an unknown body or a refused day at the origin) and the mode's drawn radius.
    static func bodies(mode: ScaleMode, day: Double) -> [Body] {
        var result: [Body] = []
        result.reserveCapacity(SolarCore.bodyCount)
        for index in 0..<SolarCore.bodyCount {
            var center = Vec3.zero
            if let body = SolarCore.catalog.body(at: index),
               let p = SolarCore.model.position(bodyID: body.id, day: day) {
                center = mode.scenePosition(p)
            }
            result.append(Body(center: center, radius: mode.drawnRadius(index: index)))
        }
        return result
    }

    /// Whether a body of `focusedRadius` centred on `target` lies within the depth range near…far seen from `eye`: its
    /// nearest point (distance − radius) is at least `near` and its farthest (distance + radius) at most `far`.
    static func isInsideDepth(target: Vec3, eye: Vec3, near: Double, far: Double, focusedRadius: Double) -> Bool {
        let d = (target - eye).length
        guard d.isFinite else { return false }
        return d - focusedRadius >= near && d + focusedRadius <= far
    }
}
