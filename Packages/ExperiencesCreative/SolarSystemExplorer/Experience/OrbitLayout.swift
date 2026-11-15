// OrbitLayout — feature 104 (A14-P02) T-A14-207 (FR-A14-220, FR-A14-221; clarifications Q4, Q5; research D4;
// contracts/orbit-view.md). The pure geometry of Solar System Explorer's orbit view (no GPU, no state of its own):
//   - Scene mapping (labelled "Distances and sizes not to scale"): a heliocentric ecliptic point p in AU (x toward the
//     J2000.0 equinox, y 90° ahead in the ecliptic, z toward ecliptic north) maps to the scene point
//     (p.x, p.z, −p.y) · 4√r / r with r = |p| (the scene is y up, so the ecliptic is the scene's x–z plane and
//     ecliptic north is scene +y). The distance from the Sun becomes 4√r scene units: Mercury at 0.387 AU lies 2.49
//     units out, Neptune at 30.07 AU 21.9 units, so both are visible in one overview. The Sun (r = 0) maps to the
//     origin.
//   - Display radii: A14-P01's presenter display radius (``SolarPresenter/displayRadius(index:)``) × 0.6 for a planet
//     and × 0.5 for the Sun (0.8), so the bodies fit between the orbits.
//   - Orbit paths: 128 samples over one period of the body's `KeplerOrbit`, each mapped as above; the path is a
//     closed loop (the presenter draws it as a closed tube).
//   - Camera: target the focused body's scene position (the Sun → the origin), yaw `SolarState.yawDegrees`, pitch
//     `SolarState.pitchDegrees`, distance `SolarState.cameraDistance` (60 · 1.25^−zoomSteps, 4.12 … 75), 60° field of
//     view, near 0.5 and far 200 (beyond the farthest point, 75 + 22 units). The smallest distance, 4.12 (at least
//     4), exceeds 3 × the largest display radius + 0.5 (the Sun: 3 · 0.8 + 0.5 = 2.9), so the focused body never
//     crosses the near plane.
//   - The selection ring faces the camera: it is made in the x–y plane (normal +z) and turned by the camera's pitch
//     and yaw, so its normal points at the eye; it is scaled by max(1, distance / 20) so it stays visible from afar.
import Foundation
import SolarSystemExplorerCore
import VisualCoreMath

/// The geometry of the orbit view: scene positions, display radii, orbit paths and the camera.
enum OrbitLayout {
    /// The scene distance per √AU (4).
    static let scale = 4.0
    /// The display-radius factor of the planets (0.6 × A14-P01's display radius).
    static let planetRadiusFactor = 0.6
    /// The display-radius factor of the Sun (0.5 × A14-P01's display radius, 0.8).
    static let sunRadiusFactor = 0.5
    /// The samples of one orbit path (128).
    static let orbitSamples = 128
    /// The vertical field of view (60°).
    static let fieldOfView = Double.pi / 3
    /// The near plane distance (below the smallest camera distance minus the largest display radius).
    static let near = 0.5
    /// The far plane distance (beyond the largest camera distance plus the scene's radius).
    static let far = 200.0
    /// The camera distance per unit of ring scale: the ring is scaled by max(1, distance / 20).
    static let ringScaleDistance = 20.0

    /// The scene point of the heliocentric ecliptic point `p` (AU): (p.x, p.z, −p.y) · 4√r / r; the origin for r = 0
    /// or a non-finite point.
    static func scenePosition(_ p: Vec3) -> Vec3 {
        let r = p.length
        guard r.isFinite, r > 0 else { return .zero }
        let factor = scale * r.squareRoot() / r
        return Vec3(p.x * factor, p.z * factor, -p.y * factor)
    }

    /// The scene position of the catalog body at `index` on day `day` (days since J2000.0): the origin for the Sun,
    /// an unknown index or a day the model refuses.
    static func scenePosition(index: Int, day: Double) -> Vec3 {
        guard let body = SolarCore.catalog.body(at: index),
              let p = SolarCore.model.position(bodyID: body.id, day: day) else { return .zero }
        return scenePosition(p)
    }

    /// The display radius of the catalog body at `index`: A14-P01's display radius × 0.6 for a planet, × 0.5 for the
    /// Sun.
    static func displayRadius(index: Int) -> Double {
        let base = SolarPresenter.displayRadius(index: index)
        let kind = SolarCore.catalog.body(at: index)?.kind ?? .planet
        return base * (kind == .star ? sunRadiusFactor : planetRadiusFactor)
    }

    /// The largest display radius of the catalog (the Sun's, 0.8).
    static var largestDisplayRadius: Double {
        var largest = 0.0
        for index in 0..<SolarCore.bodyCount { largest = max(largest, displayRadius(index: index)) }
        return largest
    }

    /// The orbit path of `bodyID`: 128 scene points at times k · period / 128 (k = 0 … 127) of its `KeplerOrbit`,
    /// a closed loop; empty for the Sun or an unknown id.
    static func orbitPath(bodyID: String) -> [Vec3] {
        guard let orbit = SolarCore.model.orbit(bodyID: bodyID) else { return [] }
        let period = orbit.period
        var path: [Vec3] = []
        path.reserveCapacity(orbitSamples)
        for k in 0..<orbitSamples {
            path.append(scenePosition(orbit.position(at: period * Double(k) / Double(orbitSamples))))
        }
        return path
    }

    /// The ids of the planets that have an orbit, in catalog order (Mercury … Neptune).
    static var orbitBodyIDs: [String] {
        SolarCore.catalog.bodies.filter { $0.kind == .planet && SolarCore.model.orbit(bodyID: $0.id) != nil }.map(\.id)
    }

    /// The largest distance of any orbit path point from the origin, scene units (Neptune's aphelion, about 22).
    static let sceneRadius: Double = {
        var largest = 0.0
        for id in orbitBodyIDs {
            for point in orbitPath(bodyID: id) { largest = max(largest, point.length) }
        }
        return largest
    }()

    /// The camera of `state`: target the focused body's scene position, yaw and pitch from the state (degrees to
    /// radians), distance `state.cameraDistance`, 60° field of view, near 0.5, far 200.
    static func camera(state: SolarState) -> OrbitCamera {
        let degrees = Double.pi / 180
        return OrbitCamera(target: scenePosition(index: state.selection, day: state.dayOffset),
                           distance: state.cameraDistance, yaw: state.yawDegrees * degrees,
                           pitch: Double(state.pitchDegrees) * degrees, fovY: fieldOfView, near: near, far: far)
    }

    /// The ring scale at camera distance `distance`: max(1, distance / 20).
    static func ringScale(distance: Double) -> Double {
        guard distance.isFinite else { return 1 }
        return max(1, distance / ringScaleDistance)
    }

    /// The model transform of the selection ring around `center` seen through `camera`: the ring (made in the x–y
    /// plane, normal +z) scaled by ``ringScale(distance:)``, turned by −pitch about x and then by yaw about y (so its
    /// normal points at the eye) and moved to `center`.
    static func ringModel(center: Vec3, camera: OrbitCamera) -> Mat4 {
        let s = ringScale(distance: camera.distance)
        let tilt = Mat4.rotation(Quat(axis: Vec3(1, 0, 0), angle: -camera.pitch))
        let turn = Mat4.rotation(Quat(axis: Vec3(0, 1, 0), angle: camera.yaw))
        return Mat4.translation(center) * turn * tilt * Mat4.scale(Vec3(s, s, s))
    }

    /// The pixel (x from the left, y from the bottom, as the host reads frames back) where the scene point `point` is
    /// drawn on a canvas of `canvas` pixels through the camera of `state`.
    static func pixel(of point: Vec3, state: SolarState, canvas: Vec2) -> Vec2 {
        let width = max(canvas.x, 1), height = max(canvas.y, 1)
        let ndc = camera(state: state).project(point, aspect: width / height)
        return Vec2((ndc.x + 1) / 2 * width, (ndc.y + 1) / 2 * height)
    }

    /// The radius in pixels of a sphere of `radius` at `center` seen through the camera of `state` on a canvas
    /// `height` pixels high (the small-angle size at its distance from the eye); 0 behind the eye.
    static func pixelRadius(_ radius: Double, at center: Vec3, state: SolarState, height: Double) -> Double {
        let eyeDistance = (center - camera(state: state).eye).length
        guard eyeDistance > radius, height > 0 else { return 0 }
        return radius / eyeDistance * (height / 2) / tan(fieldOfView / 2)
    }

    /// Whether the ray through the canvas point `ndc` (−1…1) of the camera of `state` at `aspect` misses the whole
    /// scene: every body's sphere (display radius + 0.1), the selection ring's sphere and the orbit slab (|y| ≤ 0.5
    /// within ``sceneRadius`` + 0.5 of the origin, enough for every orbit's inclination).
    static func rayMissesScene(ndc: Vec2, state: SolarState, aspect: Double) -> Bool {
        let view = Self.camera(state: state)
        let ray = view.ray(ndc: ndc, aspect: aspect)
        let o = ray.origin, d = ray.direction
        func hitsSphere(_ center: Vec3, _ radius: Double) -> Bool {
            let oc = center - o
            let t = max(0, oc.dot(d))
            return (o + d * t - center).length <= radius
        }
        for index in 0..<SolarCore.bodyCount {
            let center = scenePosition(index: index, day: state.dayOffset)
            if hitsSphere(center, displayRadius(index: index) + 0.1) { return false }
        }
        let ringOuter = SolarPresenter.ringRadius(displayRadius: displayRadius(index: state.selection))
            + SolarPresenter.ringTubeRadius
        if hitsSphere(view.target, ringOuter * ringScale(distance: view.distance) + 0.1) { return false }
        // The slab |y| ≤ h: the ray's parameter range inside it, clamped to t ≥ 0.
        let h = 0.5, limit = sceneRadius + 0.5
        var t0 = 0.0, t1 = Double.infinity
        if abs(d.y) < 1e-12 {
            if abs(o.y) > h { return true }
        } else {
            let a = (-h - o.y) / d.y, b = (h - o.y) / d.y
            t0 = max(0, min(a, b))
            t1 = max(a, b)
            if t1 < 0 { return true }
        }
        // The closest horizontal approach to the origin within [t0, t1].
        let horizontal = Vec2(d.x, d.z)
        let start = Vec2(o.x, o.z)
        let lengthSquared = horizontal.dot(horizontal)
        var t = lengthSquared > 0 ? -start.dot(horizontal) / lengthSquared : t0
        t = min(max(t, t0), t1.isFinite ? t1 : max(t, t0))
        let closest = Vec2(start.x + horizontal.x * t, start.y + horizontal.y * t)
        return closest.length > limit
    }
    /// Whether nothing lies in front of the centre of the body at `index` seen through the camera of `state`: the
    /// segment from the eye to the body's front surface keeps more than 0.05 scene units clear of every other body's
    /// sphere and of every orbit line (tube radius 0.04 around the 128-point paths).
    static func centreUnobstructed(index: Int, state: SolarState) -> Bool {
        let eye = camera(state: state).eye
        let center = scenePosition(index: index, day: state.dayOffset)
        let radius = displayRadius(index: index)
        let toCenter = center - eye
        let length = toCenter.length
        guard length.isFinite, length > radius else { return false }
        let end = eye + toCenter * ((length - radius) / length)
        for other in 0..<SolarCore.bodyCount where other != index {
            let c = scenePosition(index: other, day: state.dayOffset)
            if segmentDistance(eye, end, c, c) <= displayRadius(index: other) + 0.05 { return false }
        }
        let clearance = SolarPresenter.orbitTubeRadius + 0.05
        for id in orbitBodyIDs {
            let path = orbitPath(bodyID: id)
            for k in path.indices where segmentDistance(eye, end, path[k], path[(k + 1) % path.count]) <= clearance {
                return false
            }
        }
        return true
    }

    /// The smallest distance between the segments p1–q1 and p2–q2 (a segment may be a point).
    static func segmentDistance(_ p1: Vec3, _ q1: Vec3, _ p2: Vec3, _ q2: Vec3) -> Double {
        let d1 = q1 - p1, d2 = q2 - p2, r = p1 - p2
        let a = d1.dot(d1), e = d2.dot(d2), f = d2.dot(r)
        let epsilon = 1e-12
        var s = 0.0, t = 0.0
        if a <= epsilon && e <= epsilon {
            return r.length
        } else if a <= epsilon {
            t = min(max(f / e, 0), 1)
        } else {
            let c = d1.dot(r)
            if e <= epsilon {
                s = min(max(-c / a, 0), 1)
            } else {
                let b = d1.dot(d2)
                let denominator = a * e - b * b
                s = denominator > epsilon ? min(max((b * f - c * e) / denominator, 0), 1) : 0
                t = (b * s + f) / e
                if t < 0 {
                    t = 0
                    s = min(max(-c / a, 0), 1)
                } else if t > 1 {
                    t = 1
                    s = min(max((b - c) / a, 0), 1)
                }
            }
        }
        return ((p1 + d1 * s) - (p2 + d2 * t)).length
    }
}
