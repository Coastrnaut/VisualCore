// OrbitLayout — feature 104 (A14-P02) T-A14-207 (FR-A14-220, FR-A14-221; clarifications Q4, Q5; research D4;
// contracts/orbit-view.md), with the scale modes, markers and the drawn camera of feature 105 (A14-P03) T-A14-308
// (FR-A14-303, FR-A14-310, FR-A14-311, FR-A14-320; clarification Q3; contracts/bodies.md). The pure geometry of Solar
// System Explorer's 3D view (no GPU, no state of its own):
//   - Scene mapping: delegated to `ScaleMode` (``scenePosition(_:mode:)``). The enhanced mode (the default argument,
//     labelled "Distances and sizes not to scale") maps a heliocentric ecliptic point p in AU (x toward the J2000.0
//     equinox, y 90° ahead in the ecliptic, z toward ecliptic north) to (p.x, p.z, −p.y) · 4√r / r with r = |p| (the
//     scene is y up, so the ecliptic is the scene's x–z plane): Mercury at 0.387 AU lies 2.49 units out, Neptune at
//     30.07 AU 21.9 units. The true-relative mode maps it to (p.x, p.z, −p.y) · 2 (2 units per AU, Neptune about 60).
//     The Sun maps to the origin in both.
//   - Drawn radii: delegated to `ScaleMode.drawnRadius(index:)`. Enhanced (``displayRadius(index:)``): A14-P01's
//     display radius × 0.6 for a planet and × 0.5 for the Sun (0.8); true-relative: radius km ÷ 149,597,870.7 × 2.
//   - Orbit paths: 128 samples (64 at detail level 1, feature 107) over one period of the body's `KeplerOrbit`, each
//     mapped by the mode; a closed loop drawn as a tube of ``orbitTubeRadius(mode:)`` (0.04 enhanced; 0.1
//     true-relative, where the scene is about 2.8 times larger and a pixel at the overview about 0.29 units).
//   - Camera of a state (``camera(state:)``): target the focused body's position in the state's mode, yaw and pitch
//     from the state, distance `ScaleMode.cameraDistance(zoomSteps:)` (60 or 120 · 1.25^−zoomSteps), 60° field of
//     view, near and far from `ScaleMode.clipRange(distance:)` (0.5 and 200 enhanced; max(1e-4, 0.05 d) and d + 140
//     true-relative). In the enhanced mode the smallest distance, 4.12, exceeds 3 × the largest display radius + 0.5
//     (the Sun: 2.9), so the focused body never crosses the near plane. The presenter draws through the camera of its
//     focus flight, which equals this camera once the flight has ended and the eye needed no clearance push.
//     ``camera(target:eye:fovY:near:far:)`` rebuilds an orbit camera looking at a target from a given (pushed) eye.
//   - The selection ring faces the camera: it is made in the x–y plane (normal +z) and turned by the camera's pitch
//     and yaw, so its normal points at the eye. Enhanced: scaled by max(1, distance / 20) so it stays visible from
//     afar (``ringModel(center:camera:)``); true-relative, where every body is under a pixel on a phone canvas: scaled
//     to ``trueRingPixels`` (10) pixels at its distance from the eye. Saturn's selection ring surrounds its planetary
//     ring (``selectionRingRadius(index:)``).
//   - Markers (true-relative only): a body whose drawn radius divided by the scene size of one pixel at its distance
//     from the eye (``CameraRelative/pixelSize(distance:fovY:heightPixels:)``) is under `ScaleMode.markerThresholdPixels`
//     (2) gets a camera-facing marker ring of `ScaleMode.markerRadiusPixels` (6) pixels (``markerIndices``).
//   - Probes: whether a ray misses the whole drawn scene (bodies, Saturn's ring, the selection ring, markers, every
//     star and every orbit tube segment) and whether nothing lies in front of a body's centre, for any camera.
import Foundation
import SolarSystemExplorerCore
import VisualCoreMath

/// The geometry of the 3D view: scene positions, drawn radii, orbit paths, the camera, rings and markers.
enum OrbitLayout {
    /// The enhanced mode's scene distance per √AU (4).
    static let scale = ScaleMode.enhancedScale
    /// The enhanced display-radius factor of the planets (0.6 × A14-P01's display radius).
    static let planetRadiusFactor = ScaleMode.planetRadiusFactor
    /// The enhanced display-radius factor of the Sun (0.5 × A14-P01's display radius, 0.8).
    static let sunRadiusFactor = ScaleMode.sunRadiusFactor
    /// The samples of one orbit path at detail level 0 (128).
    static let orbitSamples = 128
    /// The samples of one orbit path at detail level 1 (64, every second point of level 0's path).
    static let lowOrbitSamples = 64
    /// The vertical field of view (60°).
    static let fieldOfView = Double.pi / 3
    /// The enhanced mode's near plane distance (below the smallest camera distance minus the largest display radius).
    static let near = 0.5
    /// The enhanced mode's far plane distance (beyond the largest camera distance plus the scene's radius).
    static let far = 200.0
    /// The camera distance per unit of ring scale in the enhanced mode: the ring is scaled by max(1, distance / 20).
    static let ringScaleDistance = 20.0
    /// The enhanced mode's orbit tube radius (0.04, A14-P02 research D4).
    static let enhancedOrbitTubeRadius = 0.04
    /// The true-relative mode's orbit tube radius (0.1).
    static let trueOrbitTubeRadius = 0.1
    /// The selection ring's radius in pixels in the true-relative mode (10).
    static let trueRingPixels = 10.0

    // MARK: Positions and radii

    /// The scene point of the heliocentric ecliptic point `p` (AU) in `mode` (`ScaleMode.scenePosition(_:)`); the
    /// origin for r = 0 or a non-finite point.
    static func scenePosition(_ p: Vec3, mode: ScaleMode = .enhanced) -> Vec3 {
        mode.scenePosition(p)
    }

    /// The scene position of the catalog body at `index` on day `day` (days since J2000.0) in `mode`: the origin for
    /// the Sun, an unknown index or a day the model refuses.
    static func scenePosition(index: Int, day: Double, mode: ScaleMode = .enhanced) -> Vec3 {
        guard let body = SolarCore.catalog.body(at: index),
              let p = SolarCore.model.position(bodyID: body.id, day: day) else { return .zero }
        return mode.scenePosition(p)
    }

    /// The enhanced display radius of the catalog body at `index`: A14-P01's display radius × 0.6 for a planet,
    /// × 0.5 for the Sun.
    static func displayRadius(index: Int) -> Double {
        ScaleMode.enhanced.drawnRadius(index: index)
    }

    /// The drawn radius of the catalog body at `index` in `mode`.
    static func drawnRadius(index: Int, mode: ScaleMode) -> Double {
        mode.drawnRadius(index: index)
    }

    /// The largest enhanced display radius of the catalog (the Sun's, 0.8).
    static var largestDisplayRadius: Double {
        var largest = 0.0
        for index in 0..<SolarCore.bodyCount { largest = max(largest, displayRadius(index: index)) }
        return largest
    }

    /// The radius of Saturn's planetary ring in `mode`, scene units (the A ring's outer edge in Saturn radii × Saturn's
    /// drawn radius).
    static func saturnRingRadius(mode: ScaleMode) -> Double {
        SceneMeshes.ringOuterRadius * mode.drawnRadius(index: SceneMeshes.saturnIndex)
    }

    // MARK: Orbits

    /// The orbit path of `bodyID` in `mode`: `samples` (128 by default; 64 at detail level 1) scene points at times
    /// k · period / samples (k = 0 … samples − 1) of its `KeplerOrbit`, a closed loop; empty for the Sun, an unknown id
    /// or fewer than 3 samples. The 64-sample path is every second point of the 128-sample one.
    static func orbitPath(bodyID: String, mode: ScaleMode = .enhanced, samples: Int = orbitSamples) -> [Vec3] {
        guard samples >= 3, let orbit = SolarCore.model.orbit(bodyID: bodyID) else { return [] }
        let period = orbit.period
        var path: [Vec3] = []
        path.reserveCapacity(samples)
        for k in 0..<samples {
            path.append(mode.scenePosition(orbit.position(at: period * Double(k) / Double(samples))))
        }
        return path
    }

    /// The orbit tube radius of `mode`: 0.04 (enhanced) or 0.1 (true-relative).
    static func orbitTubeRadius(mode: ScaleMode) -> Double {
        mode == .enhanced ? enhancedOrbitTubeRadius : trueOrbitTubeRadius
    }

    /// The ids of the planets that have an orbit, in catalog order (Mercury … Neptune).
    static var orbitBodyIDs: [String] {
        SolarCore.catalog.bodies.filter { $0.kind == .planet && SolarCore.model.orbit(bodyID: $0.id) != nil }.map(\.id)
    }

    /// The enhanced orbit paths of ``orbitBodyIDs``, made once.
    static let enhancedPaths: [[Vec3]] = orbitBodyIDs.map { orbitPath(bodyID: $0, mode: .enhanced) }

    /// The true-relative orbit paths of ``orbitBodyIDs``, made once.
    static let truePaths: [[Vec3]] = orbitBodyIDs.map { orbitPath(bodyID: $0, mode: .trueRelative) }

    /// The orbit paths of `mode` in the order of ``orbitBodyIDs``.
    static func paths(mode: ScaleMode) -> [[Vec3]] {
        mode == .enhanced ? enhancedPaths : truePaths
    }

    /// The largest distance of any orbit path point of `mode` from the origin and the largest |y| among them.
    static func pathExtent(mode: ScaleMode) -> (radius: Double, height: Double) {
        var radius = 0.0, height = 0.0
        for path in paths(mode: mode) {
            for point in path {
                radius = max(radius, point.length)
                height = max(height, abs(point.y))
            }
        }
        return (radius, height)
    }

    /// The largest distance of any enhanced orbit path point from the origin, scene units (Neptune's aphelion, about
    /// 22).
    static let sceneRadius: Double = pathExtent(mode: .enhanced).radius

    /// The true-relative counterpart of ``sceneRadius`` (about 61) and the largest |y| of its orbit points.
    static let trueExtent: (radius: Double, height: Double) = pathExtent(mode: .trueRelative)

    /// The scene radius of `mode`.
    static func sceneRadius(mode: ScaleMode) -> Double {
        mode == .enhanced ? sceneRadius : trueExtent.radius
    }

    // MARK: Camera

    /// The camera of `state`: target the focused body's position in the state's scale mode, yaw and pitch from the
    /// state (degrees to radians), distance `ScaleMode.cameraDistance(zoomSteps:)`, 60° field of view, near and far
    /// from `ScaleMode.clipRange(distance:)`.
    static func camera(state: SolarState) -> OrbitCamera {
        let degrees = Double.pi / 180
        let mode = state.scaleMode
        let distance = mode.cameraDistance(zoomSteps: state.zoomSteps)
        let clip = mode.clipRange(distance: distance)
        return OrbitCamera(target: scenePosition(index: state.selection, day: state.dayOffset, mode: mode),
                           distance: distance, yaw: state.yawDegrees * degrees,
                           pitch: Double(state.pitchDegrees) * degrees, fovY: fieldOfView, near: clip.near,
                           far: clip.far)
    }

    /// The orbit camera looking at `target` from `eye`: distance |eye − target|, pitch asin(offset.y / distance), yaw
    /// atan2(offset.x, offset.z) (OrbitCamera's eye formula inverted).
    static func camera(target: Vec3, eye: Vec3, fovY: Double = fieldOfView, near: Double, far: Double) -> OrbitCamera {
        let offset = eye - target
        let distance = offset.length
        guard distance.isFinite, distance > 0 else {
            return OrbitCamera(target: target, distance: 1, yaw: 0, pitch: 0, fovY: fovY, near: near, far: far)
        }
        let pitch = asin(min(max(offset.y / distance, -1), 1))
        let yaw = atan2(offset.x, offset.z)
        return OrbitCamera(target: target, distance: distance, yaw: yaw, pitch: pitch, fovY: fovY, near: near, far: far)
    }

    // MARK: Rings and markers

    /// The ring scale at camera distance `distance` in the enhanced mode: max(1, distance / 20).
    static func ringScale(distance: Double) -> Double {
        guard distance.isFinite else { return 1 }
        return max(1, distance / ringScaleDistance)
    }

    /// The radius of the selection ring mesh of the body at `index`: ``SolarPresenter/ringRadius(displayRadius:)`` of
    /// its enhanced display radius, for Saturn of its enhanced planetary ring's outer radius.
    static func selectionRingRadius(index: Int) -> Double {
        let radius = index == SceneMeshes.saturnIndex ? saturnRingRadius(mode: .enhanced) : displayRadius(index: index)
        return SolarPresenter.ringRadius(displayRadius: radius)
    }

    /// The model transform of a camera-facing object made in the x–y plane (normal +z): scaled by `scale`, turned by
    /// −pitch about x and then by yaw about y (so its normal points at an eye at that yaw and pitch) and moved to
    /// `center`.
    static func facingModel(center: Vec3, yaw: Double, pitch: Double, scale: Double) -> Mat4 {
        let tilt = Mat4.rotation(Quat(axis: Vec3(1, 0, 0), angle: -pitch))
        let turn = Mat4.rotation(Quat(axis: Vec3(0, 1, 0), angle: yaw))
        return Mat4.translation(center) * turn * tilt * Mat4.scale(Vec3(scale, scale, scale))
    }

    /// The enhanced model transform of the selection ring around `center` seen through `camera`: scaled by
    /// ``ringScale(distance:)`` and facing the camera (``facingModel(center:yaw:pitch:scale:)``).
    static func ringModel(center: Vec3, camera: OrbitCamera) -> Mat4 {
        facingModel(center: center, yaw: camera.yaw, pitch: camera.pitch, scale: ringScale(distance: camera.distance))
    }

    /// The scale of the selection ring mesh of the body at `index` in `mode`: ``ringScale(distance:)`` of the camera
    /// distance (enhanced), or ``trueRingPixels`` pixels at `eyeDistance` divided by the mesh radius (true-relative).
    static func selectionRingScale(index: Int, mode: ScaleMode, cameraDistance: Double, eyeDistance: Double,
                                   heightPixels: Double) -> Double {
        guard mode == .trueRelative else { return ringScale(distance: cameraDistance) }
        let pixel = CameraRelative.pixelSize(distance: eyeDistance, fovY: fieldOfView, heightPixels: heightPixels)
        let radius = selectionRingRadius(index: index)
        guard pixel.isFinite, pixel > 0, radius > 0 else { return 1 }
        return trueRingPixels * pixel / radius
    }

    /// The drawn radius in pixels of a sphere of `radius` at `center` seen from `eye` on a canvas `heightPixels` high
    /// (radius ÷ the scene size of a pixel at its distance); 0 for a zero distance or height.
    static func pixelRadius(_ radius: Double, at center: Vec3, eye: Vec3, heightPixels: Double) -> Double {
        let pixel = CameraRelative.pixelSize(distance: (center - eye).length, fovY: fieldOfView,
                                             heightPixels: heightPixels)
        guard pixel.isFinite, pixel > 0 else { return 0 }
        return radius / pixel
    }

    /// The bodies that get a marker in `mode` on `day` seen from `eye` on a canvas `heightPixels` high: in the
    /// true-relative mode every body drawn under 2 pixels in radius, in catalog order; none in the enhanced mode.
    static func markerIndices(mode: ScaleMode, day: Double, eye: Vec3, heightPixels: Double) -> [Int] {
        guard mode == .trueRelative else { return [] }
        var result: [Int] = []
        for index in 0..<SolarCore.bodyCount {
            let center = scenePosition(index: index, day: day, mode: mode)
            let pixels = pixelRadius(mode.drawnRadius(index: index), at: center, eye: eye, heightPixels: heightPixels)
            if pixels < ScaleMode.markerThresholdPixels { result.append(index) }
        }
        return result
    }

    /// The scale of the marker ring (unit radius) at `center` seen from `eye`: 6 pixels at its distance.
    static func markerScale(center: Vec3, eye: Vec3, heightPixels: Double) -> Double {
        ScaleMode.markerRadiusPixels * CameraRelative.pixelSize(distance: (center - eye).length, fovY: fieldOfView,
                                                                heightPixels: heightPixels)
    }

    // MARK: Pixels and probes

    /// The pixel (x from the left, y from the bottom, as the host reads frames back) where the scene point `point` is
    /// drawn on a canvas of `canvas` pixels through `camera`.
    static func pixel(of point: Vec3, camera: OrbitCamera, canvas: Vec2) -> Vec2 {
        let width = max(canvas.x, 1), height = max(canvas.y, 1)
        let ndc = camera.project(point, aspect: width / height)
        return Vec2((ndc.x + 1) / 2 * width, (ndc.y + 1) / 2 * height)
    }

    /// The pixel of `point` through the camera of `state` (``pixel(of:camera:canvas:)``).
    static func pixel(of point: Vec3, state: SolarState, canvas: Vec2) -> Vec2 {
        pixel(of: point, camera: camera(state: state), canvas: canvas)
    }

    /// The radius in pixels of a sphere of `radius` at `center` seen through the camera of `state` on a canvas
    /// `height` pixels high (the small-angle size at its distance from the eye); 0 behind the eye.
    static func pixelRadius(_ radius: Double, at center: Vec3, state: SolarState, height: Double) -> Double {
        let eyeDistance = (center - camera(state: state).eye).length
        guard eyeDistance > radius, height > 0 else { return 0 }
        return radius / eyeDistance * (height / 2) / tan(fieldOfView / 2)
    }

    /// Whether the ray through the canvas point `ndc` (−1…1) of the camera of `state` at `aspect` misses the whole
    /// scene (``rayMissesScene(ndc:camera:state:aspect:heightPixels:)`` with the state's camera) on a canvas
    /// `heightPixels` high (480 by default, the render tests' canvas).
    static func rayMissesScene(ndc: Vec2, state: SolarState, aspect: Double, heightPixels: Double = 480) -> Bool {
        rayMissesScene(ndc: ndc, camera: camera(state: state), state: state, aspect: aspect, heightPixels: heightPixels)
    }

    /// Whether the ray through the canvas point `ndc` (−1…1) of `camera` at `aspect` misses the whole scene of
    /// `state` (its scale mode, date and selection) on a canvas `heightPixels` high: every body's sphere (drawn radius
    /// + 0.1 enhanced, + 3 pixels true-relative), Saturn's planetary ring, the selection ring's sphere, every marker,
    /// every star (its angular size plus 3 pixels) and every orbit tube segment (tube radius + 3 pixels at its
    /// distance) along the ray up to the far plane.
    static func rayMissesScene(ndc: Vec2, camera: OrbitCamera, state: SolarState, aspect: Double,
                               heightPixels: Double) -> Bool {
        let mode = state.scaleMode
        let ray = camera.ray(ndc: ndc, aspect: aspect)
        let o = ray.origin, d = ray.direction.normalized
        let pixelAngle = 2 * tan(fieldOfView / 2) / max(heightPixels, 1)
        func pixelsAt(_ center: Vec3, _ count: Double) -> Double {
            count * CameraRelative.pixelSize(distance: (center - o).length, fovY: fieldOfView,
                                             heightPixels: max(heightPixels, 1))
        }
        func hitsSphere(_ center: Vec3, _ radius: Double) -> Bool {
            let oc = center - o
            let t = max(0, oc.dot(d))
            return (o + d * t - center).length <= radius
        }
        let margin: (Vec3) -> Double = { center in mode == .enhanced ? 0.1 : pixelsAt(center, 3) }
        for index in 0..<SolarCore.bodyCount {
            let center = scenePosition(index: index, day: state.dayOffset, mode: mode)
            if hitsSphere(center, mode.drawnRadius(index: index) + margin(center)) { return false }
        }
        let saturn = scenePosition(index: SceneMeshes.saturnIndex, day: state.dayOffset, mode: mode)
        if hitsSphere(saturn, saturnRingRadius(mode: mode) + margin(saturn)) { return false }
        let eye = camera.eye
        let selected = scenePosition(index: state.selection, day: state.dayOffset, mode: mode)
        let ringScale = selectionRingScale(index: state.selection, mode: mode, cameraDistance: camera.distance,
                                           eyeDistance: (selected - eye).length, heightPixels: heightPixels)
        let ringOuter = (selectionRingRadius(index: state.selection) + SolarPresenter.ringTubeRadius) * ringScale
        if hitsSphere(selected, ringOuter + margin(selected)) { return false }
        for index in markerIndices(mode: mode, day: state.dayOffset, eye: eye, heightPixels: heightPixels) {
            let center = scenePosition(index: index, day: state.dayOffset, mode: mode)
            if hitsSphere(center, pixelsAt(center, ScaleMode.markerRadiusPixels * 1.2 + 3)) { return false }
        }
        // The stars: centred on the eye, so a star is hit when its direction is within its angular size of the ray.
        let starLimit = cos(SceneMeshes.starSize * 1.5 + 3 * pixelAngle)
        for star in SceneMeshes.starField where star.dot(d) >= starLimit { return false }
        // The orbits: every tube segment (tube radius + 3 pixels at its distance) along the ray up to the far plane.
        let end = o + d * camera.far
        let tube = orbitTubeRadius(mode: mode)
        for path in paths(mode: mode) {
            for k in path.indices {
                let a = path[k], b = path[(k + 1) % path.count]
                let clearance = tube + max(pixelsAt(a, 3), pixelsAt(b, 3))
                if segmentDistance(o, end, a, b) <= clearance { return false }
            }
        }
        return true
    }

    /// Whether nothing lies in front of the centre of the body at `index` seen through the camera of `state`
    /// (``centreUnobstructed(index:eye:state:)`` from that camera's eye).
    static func centreUnobstructed(index: Int, state: SolarState) -> Bool {
        centreUnobstructed(index: index, eye: camera(state: state).eye, state: state)
    }

    /// Whether nothing lies in front of the centre of the body at `index` seen from `eye` in the scene of `state`: the
    /// segment from the eye to the body's front surface keeps more than 0.05 scene units clear of every other body's
    /// sphere, of Saturn's planetary ring (its whole sphere, for any other body) and of every orbit line of the mode.
    static func centreUnobstructed(index: Int, eye: Vec3, state: SolarState) -> Bool {
        let mode = state.scaleMode
        let center = scenePosition(index: index, day: state.dayOffset, mode: mode)
        let radius = mode.drawnRadius(index: index)
        let toCenter = center - eye
        let length = toCenter.length
        guard length.isFinite, length > radius else { return false }
        let end = eye + toCenter * ((length - radius) / length)
        for other in 0..<SolarCore.bodyCount where other != index {
            let c = scenePosition(index: other, day: state.dayOffset, mode: mode)
            var clearance = mode.drawnRadius(index: other) + 0.05
            if other == SceneMeshes.saturnIndex { clearance = max(clearance, saturnRingRadius(mode: mode) + 0.05) }
            if segmentDistance(eye, end, c, c) <= clearance { return false }
        }
        let clearance = orbitTubeRadius(mode: mode) + 0.05
        for path in paths(mode: mode) {
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
