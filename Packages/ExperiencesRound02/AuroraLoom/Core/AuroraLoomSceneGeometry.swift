// AuroraLoomSceneGeometry — feature 303 (R02-G01-03) T-R02G0103-003 (FR-R02G0103-001, 006; SC-R02G0103-003;
// clarifications Q1–Q3; research R3, R4). The world of the loom, built from a snapshot only: each ribbon's centre line
// (height H · sin(2π θ / 4,096), θ = wave · s · 16 + phase · 256 + ω · t, lanes −1/0/+1 in depth), its layered sheets
// (a centripetal Catmull-Rom spline through the centre line, parallel-transport frames and `Mesh.ribbon`), the gate
// rings standing across the loom and their target markers, the fixed authored camera that frames the whole loom with a
// 5 % margin for every aspect 0.4 … 2.5, and the CPU reference of the projection (pixel positions of the centre-line
// samples and markers) that the simulator tests compare with rendered frames. Doubles are used for drawing only; nothing
// here is consulted by the rules.
// Feature 304 (R02-G01-04) T-R02G0104-002 (FR-R02G0104-001, 004; clarifications Q1, Q3; research R4): the content box
// now also holds the anchor rails and phase dials of `AuroraLoomHandles`, and the camera can orbit
// (`AuroraLoomOrbit`: azimuth 18° + offset −40° … 40°, elevation 10° … 60°) with the distance refitted per orbit and
// aspect by the same bisection, so the 5 % framing guarantee holds at every orbit. The orbit is presentation only.
import Foundation
import VisualCoreMath
import VisualCoreScenes

/// The presentation-only orbit of the Aurora Loom camera (feature 304, FR-R02G0104-004): an azimuth offset added to the
/// authored azimuth (18°) and an absolute elevation above the loom plane, both in radians. Never part of the digest,
/// the snapshot payload or the kernel, and not saved.
public struct AuroraLoomOrbit: Sendable, Equatable {
    /// The azimuth offset in radians, added to `AuroraLoomSceneGeometry.azimuth`; allowed −40° … 40°.
    public var azimuthOffset: Double
    /// The elevation above the loom plane in radians; allowed 10° … 60°.
    public var elevation: Double

    /// An orbit of the given values (not clamped; see ``clamped()``).
    public init(azimuthOffset: Double, elevation: Double) {
        self.azimuthOffset = azimuthOffset
        self.elevation = elevation
    }

    /// The authored pose: offset 0, elevation 28° (`AuroraLoomSceneGeometry.elevation`).
    public static let authored = AuroraLoomOrbit(azimuthOffset: 0, elevation: AuroraLoomSceneGeometry.elevation)
    /// The allowed azimuth offsets in radians, −40° … 40°.
    public static let azimuthRange: ClosedRange<Double> = (-40.0 * Double.pi / 180)...(40.0 * Double.pi / 180)
    /// The allowed elevations in radians, 10° … 60°.
    public static let elevationRange: ClosedRange<Double> = (10.0 * Double.pi / 180)...(60.0 * Double.pi / 180)

    /// This orbit with each value clamped to its range; a non-finite value becomes the authored value.
    public func clamped() -> AuroraLoomOrbit {
        let a: Double = azimuthOffset.isFinite ? azimuthOffset : Self.authored.azimuthOffset
        let e: Double = elevation.isFinite ? elevation : Self.authored.elevation
        return AuroraLoomOrbit(
            azimuthOffset: min(max(a, Self.azimuthRange.lowerBound), Self.azimuthRange.upperBound),
            elevation: min(max(e, Self.elevationRange.lowerBound), Self.elevationRange.upperBound))
    }
}

/// The geometry of the Aurora Loom scene: centre lines, ribbon sheets, gate rings, markers, camera and projection.
///
/// World layout: the loom axis is the x axis; s sixteenths (0 … 16) map to x = −L/2 … +L/2; height is y; ribbon r lies
/// in the lane z = (r − 1) · D. Every gate ring is a circle of radius R around the loom axis in the y–z plane at its
/// gate's x, large enough to enclose every ribbon sheet at its full swing.
public enum AuroraLoomSceneGeometry {
    /// The number of ribbons, 3.
    public static let ribbonCount = 3
    /// The loom length L in world units: s = 0 … 16 maps to x = −L/2 … +L/2.
    public static let length = 8.0
    /// The height amplitude H in world units.
    public static let amplitude = 1.0
    /// The lane spacing D in world units: ribbon r lies at z = (r − 1) · D.
    public static let laneSpacing = 0.5
    /// The depth step between neighbouring layers of one ribbon, in world units.
    public static let layerSpacing = 0.07
    /// The width of a ribbon's innermost layer at the loom's middle, in world units.
    public static let baseWidth = 0.28
    /// The width lost per layer step away from the innermost layer, as a fraction of `baseWidth`.
    public static let layerTaper = 0.18
    /// The gate ring radius R in world units (1.4 · H): it encloses every ribbon sheet at its full swing in every lane.
    public static let ringRadius = 1.4
    /// The camera's vertical field of view in radians (45°).
    public static let fieldOfView = Double.pi / 4
    /// The camera's elevation above the loom plane in radians (28°): the view comes from above.
    public static let elevation = 28.0 * Double.pi / 180
    /// The camera's azimuth from the front in radians (18°): the view looks slightly along the loom.
    public static let azimuth = 18.0 * Double.pi / 180
    /// The margin the camera fit keeps on every side, as a fraction of the viewport (6 %; the guarantee is 5 %).
    public static let fitMargin = 0.06
    /// The aspect ratios (width / height) the framing is guaranteed for, 0.4 … 2.5.
    public static let aspectRange: ClosedRange<Double> = 0.4...2.5
    /// The near clipping distance of the camera.
    public static let nearPlane = 0.1

    /// The extra half extent along x beyond the rails and dials (`AuroraLoomHandles.railOffset` + dial radius) that
    /// leaves room for the drawn anchor and knob markers, 0.05.
    public static let handleMargin = 0.05

    /// The half extents of the box around the origin that holds every piece of scene geometry (ribbon sheets at any
    /// setting and time, gate rings, markers, and since feature 304 the anchor rails and phase dials):
    /// x = L/2 + 0.45 + 0.3 + 0.05 = 4.8, y = z = R (rails span ±H, dials ±0.3 around lanes ±D, both inside R).
    public static let contentHalfExtents = Vec3(length / 2 + 0.45 + 0.3 + handleMargin, ringRadius, ringRadius)

    /// The largest |coordinate| of any scene vertex, ring point or marker (the largest content half extent).
    public static let sceneBounds = max(contentHalfExtents.x, contentHalfExtents.y, contentHalfExtents.z)

    // MARK: Layout

    /// The world x of a position of `s` sixteenths along the loom (s = 0 … 16 → −L/2 … +L/2).
    public static func x(sixteenths s: Double) -> Double {
        -length / 2 + length * s / 16
    }

    /// The lane depth z of `ribbon`, (ribbon − 1) · D.
    public static func lane(ribbon: Int) -> Double {
        Double(ribbon - 1) * laneSpacing
    }

    /// The height of a phase of `theta` units (1/4,096 turn): H · sin(2π θ / 4,096).
    public static func height(phase theta: Double) -> Double {
        let wrapped = theta.isFinite ? theta.truncatingRemainder(dividingBy: Double(AuroraLoomHarmony.unitsPerTurn)) : 0
        return amplitude * sin(2 * Double.pi * wrapped / Double(AuroraLoomHarmony.unitsPerTurn))
    }

    /// `rate · time` reduced modulo one turn, so large times keep their precision and stay finite.
    static func turning(_ rate: Int, _ time: Double) -> Double {
        let turn = Double(AuroraLoomHarmony.unitsPerTurn)
        let whole = time.rounded(.down)
        let a = (Double(rate) * whole.truncatingRemainder(dividingBy: turn)).truncatingRemainder(dividingBy: turn)
        return a + Double(rate) * (time - whole)
    }

    // MARK: Ribbons

    /// The centre line of `ribbon` (0 … 2) in `snapshot`: `segments` + 1 points (segments clamped to 1 … 4,096) at
    /// s = 16 · i / segments, x = −L/2 + L · s / 16, y = H · sin(2π θ / 4,096) with
    /// θ = wave · s · 16 + phase · 256 + ω · t (the snapshot's steps, the ribbon's ω, t = `snapshot.time`, continuous),
    /// z = the ribbon's lane. Always finite. An out-of-range ribbon index is clamped to 0 … 2.
    public static func centreLine(ribbon: Int, snapshot: AuroraLoomSceneSnapshot, segments: Int) -> [Vec3] {
        let r = min(max(ribbon, 0), ribbonCount - 1)
        let n = min(max(segments, 1), 4_096)
        let wave = Double(snapshot.steps.wave[r])
        let phase = Double(snapshot.steps.phase[r])
        let spin = turning(snapshot.level.ribbons[r].omega, snapshot.time)
        let z = lane(ribbon: r)
        var points: [Vec3] = []
        points.reserveCapacity(n + 1)
        for i in 0...n {
            let s = 16 * Double(i) / Double(n)
            let theta = wave * s * 16 + phase * 256 + spin
            points.append(Vec3(x(sixteenths: s), height(phase: theta), z))
        }
        return points
    }

    /// The depth offsets of `layers` sheets around a lane: (k − (layers − 1)/2) · `layerSpacing`, symmetric.
    public static func layerOffsets(layers: Int) -> [Double] {
        let n = max(layers, 1)
        var result: [Double] = []
        for k in 0..<n { result.append((Double(k) - Double(n - 1) / 2) * layerSpacing) }
        return result
    }

    /// The middle widths of `layers` sheets: `baseWidth` · (1 − `layerTaper` · |k − (layers − 1)/2|), so outer layers
    /// are narrower.
    public static func layerWidths(layers: Int) -> [Double] {
        let n = max(layers, 1)
        var result: [Double] = []
        for k in 0..<n { result.append(baseWidth * (1 - layerTaper * abs(Double(k) - Double(n - 1) / 2))) }
        return result
    }

    /// The ribbon sheets of `snapshot` at `tier`: 3 · `tier.layers` meshes, ribbon-major (ribbon 0's layers first,
    /// each ribbon's layers from the back lane offset to the front).
    ///
    /// Each sheet follows a centripetal `CatmullRomSpline` through the ribbon's centre line at `tier.segments`
    /// segments, evaluated at two parameters per span (2 · segments + 1 samples), shifted in depth by the layer's
    /// offset, framed by `CurveFrames.parallelTransport` with the initial normal +z (so the sheet stands as a curtain in
    /// its lane, its across direction in the x–y plane) and built by `Mesh.ribbon` with a width that tapers to 40 % at
    /// the loom ends. Texture u runs across the sheet (bevel), v along it in world units.
    ///
    /// - Throws: `MeshError` from the shared builders (`.budget` beyond `MeshBudget.default`); not expected for any
    ///   snapshot.
    public static func ribbonMeshes(snapshot: AuroraLoomSceneSnapshot,
                                    tier: AuroraLoomTier) throws(MeshError) -> [Mesh] {
        let offsets = layerOffsets(layers: tier.layers)
        let widths = layerWidths(layers: tier.layers)
        var meshes: [Mesh] = []
        meshes.reserveCapacity(ribbonCount * offsets.count)
        for r in 0..<ribbonCount {
            let line = centreLine(ribbon: r, snapshot: snapshot, segments: tier.segments)
            let spline = try CatmullRomSpline(points: line, closed: false)
            var centre: [Vec3] = []
            centre.reserveCapacity(2 * spline.segmentCount + 1)
            for i in 0..<spline.segmentCount {
                centre.append(spline.position(segment: i, t: 0))
                centre.append(spline.position(segment: i, t: 0.5))
            }
            centre.append(spline.position(segment: spline.segmentCount - 1, t: 1))
            for k in 0..<offsets.count {
                var shifted: [Vec3] = []
                shifted.reserveCapacity(centre.count)
                for p in centre { shifted.append(Vec3(p.x, p.y, p.z + offsets[k])) }
                let samples = try CurveSamples(positions: shifted, closed: false)
                let count = samples.positions.count
                var sampleWidths: [Double] = []
                sampleWidths.reserveCapacity(count)
                for i in 0..<count {
                    let u = count > 1 ? Double(i) / Double(count - 1) : 0.5
                    sampleWidths.append(widths[k] * (0.4 + 0.6 * sin(Double.pi * u)))
                }
                meshes.append(try Mesh.ribbon(samples, width: .perSample(sampleWidths),
                                              initialNormal: Vec3(0, 0, 1), budget: .default))
            }
        }
        return meshes
    }

    // MARK: Gates

    /// The world x of `gate` (0 … 3, clamped) in `snapshot`: its position in sixteenths mapped along the loom.
    public static func gateX(gate: Int, snapshot: AuroraLoomSceneSnapshot) -> Double {
        let g = min(max(gate, 0), snapshot.level.gates.count - 1)
        return x(sixteenths: Double(snapshot.level.gates[g].position))
    }

    /// The ring of `gate` (0 … 3, clamped): `points` (clamped to 3 … 1,024) points of a circle of radius R around the
    /// loom axis in the y–z plane at the gate's x, starting at the top (y = R, z = 0) and turning towards +z; the first
    /// point is not repeated.
    public static func gateRing(gate: Int, snapshot: AuroraLoomSceneSnapshot, points: Int = 64) -> [Vec3] {
        let n = min(max(points, 3), 1_024)
        let gx = gateX(gate: gate, snapshot: snapshot)
        var ring: [Vec3] = []
        ring.reserveCapacity(n)
        for i in 0..<n {
            let a = 2 * Double.pi * Double(i) / Double(n)
            ring.append(Vec3(gx, ringRadius * cos(a), ringRadius * sin(a)))
        }
        return ring
    }

    /// The target marker of `gate` (0 … 3, clamped): on the ring's plane at the gate's x, height
    /// H · sin(2π (Θ_g + Ω · t) / 4,096), z = 0 (the middle lane), t = `snapshot.time`.
    public static func marker(gate: Int, snapshot: AuroraLoomSceneSnapshot) -> Vec3 {
        let g = min(max(gate, 0), snapshot.level.gates.count - 1)
        let theta = Double(snapshot.level.gates[g].target) + turning(snapshot.level.omega, snapshot.time)
        return Vec3(gateX(gate: g, snapshot: snapshot), height(phase: theta), 0)
    }

    // MARK: Camera

    /// `aspect` made usable: a non-finite or non-positive aspect becomes 1; others are clamped to 0.1 … 10.
    static func usableAspect(_ aspect: Double) -> Double {
        guard aspect.isFinite, aspect > 0 else { return 1 }
        return min(max(aspect, 0.1), 10)
    }

    /// The unit direction from the loom centre to the eye for `orbit` (clamped): elevation e and azimuth
    /// a = `azimuth` + offset, (cos e · sin a, sin e, cos e · cos a).
    static func eyeDirection(orbit: AuroraLoomOrbit) -> Vec3 {
        let o: AuroraLoomOrbit = orbit.clamped()
        let a: Double = azimuth + o.azimuthOffset
        return Vec3(cos(o.elevation) * sin(a), sin(o.elevation), cos(o.elevation) * cos(a))
    }

    /// The unit direction from the loom centre to the eye at the authored pose (elevation and azimuth).
    static var eyeDirection: Vec3 { eyeDirection(orbit: .authored) }

    /// The eight corners of the content box.
    static var contentCorners: [Vec3] {
        let h = contentHalfExtents
        var corners: [Vec3] = []
        for sx in [-1.0, 1.0] {
            for sy in [-1.0, 1.0] {
                for sz in [-1.0, 1.0] { corners.append(Vec3(sx * h.x, sy * h.y, sz * h.z)) }
            }
        }
        return corners
    }

    /// The view and projection for an eye at `distance` from the loom centre at `orbit`.
    static func matrices(distance: Double, aspect: Double,
                         orbit: AuroraLoomOrbit = .authored) -> (view: Mat4, projection: Mat4) {
        let view = Mat4.lookAt(eye: eyeDirection(orbit: orbit) * distance, target: .zero, up: Vec3(0, 1, 0))
        let far = distance + 4 * sceneBounds
        let projection = Mat4.perspective(fovY: fieldOfView, aspect: aspect, near: nearPlane, far: far)
        return (view, projection)
    }

    /// Whether every content corner lies in front of the camera and inside NDC ±(1 − 2 · margin).
    static func fits(distance: Double, aspect: Double, margin: Double, orbit: AuroraLoomOrbit = .authored) -> Bool {
        let m = matrices(distance: distance, aspect: aspect, orbit: orbit)
        let viewProjection = m.projection * m.view
        let limit = 1 - 2 * margin
        for corner in contentCorners {
            let clip = viewProjection * Vec4(corner, 1)
            guard clip.w > nearPlane else { return false }
            if abs(clip.x / clip.w) > limit || abs(clip.y / clip.w) > limit { return false }
        }
        return true
    }

    /// The eye distance from the loom centre for `aspect` at the authored pose; equal to
    /// `cameraDistance(aspect:orbit: .authored)`.
    public static func cameraDistance(aspect: Double) -> Double {
        cameraDistance(aspect: aspect, orbit: .authored)
    }

    /// The eye distance from the loom centre for `aspect` and `orbit` (clamped): the smallest distance (bisection, 60
    /// halvings) at which every corner of the content box projects inside the viewport with `fitMargin` on every side.
    /// Every scene point lies in the content box and the box is convex, so the whole scene fits.
    public static func cameraDistance(aspect: Double, orbit: AuroraLoomOrbit) -> Double {
        let a = usableAspect(aspect)
        let o = orbit.clamped()
        var low = 0.0, high = 1_000.0
        for _ in 0..<60 {
            let middle = (low + high) / 2
            if fits(distance: middle, aspect: a, margin: fitMargin, orbit: o) { high = middle } else { low = middle }
        }
        return high
    }

    /// The fixed authored camera for `aspect` (width / height): an eye above and in front of the loom (elevation 28°,
    /// azimuth 18°) looking at the loom centre with +y up, a 45° vertical field of view and the distance of
    /// `cameraDistance(aspect:)`, so the whole loom fits with at least 5 % margin on every side for aspects 0.4 … 2.5.
    /// Right-handed, GL depth range (`Mat4.perspective`, `Mat4.lookAt`). Identical to
    /// `camera(aspect:orbit: .authored)`.
    public static func camera(aspect: Double) -> (view: Mat4, projection: Mat4) {
        camera(aspect: aspect, orbit: .authored)
    }

    /// The camera for `aspect` and `orbit` (clamped; feature 304, FR-R02G0104-004): the eye at elevation
    /// `orbit.elevation` and azimuth 18° + `orbit.azimuthOffset`, looking at the loom centre with +y up, a 45° vertical
    /// field of view and the distance of `cameraDistance(aspect:orbit:)`, so the whole loom including rails and dials
    /// fits with at least 5 % margin for aspects 0.4 … 2.5 at every allowed orbit.
    public static func camera(aspect: Double, orbit: AuroraLoomOrbit) -> (view: Mat4, projection: Mat4) {
        let a = usableAspect(aspect)
        let o = orbit.clamped()
        return matrices(distance: cameraDistance(aspect: a, orbit: o), aspect: a, orbit: o)
    }

    /// The pixel position of `point` in a `width` × `height` viewport (origin top left, y down; pixel centres at
    /// half-integers) through `camera(aspect:)`, following GL: clip = projection · view · point, NDC = clip / w,
    /// x = (ndc.x + 1)/2 · width, y = (1 − ndc.y)/2 · height. Nil behind the camera, for a non-positive size or for
    /// non-finite input. The point may lie outside the viewport.
    public static func project(_ point: Vec3, aspect: Double, width: Int, height: Int) -> (x: Double, y: Double)? {
        project(point, aspect: aspect, orbit: .authored, width: width, height: height)
    }

    /// The pixel position of `point` as `project(_:aspect:width:height:)` but through `camera(aspect:orbit:)`.
    public static func project(_ point: Vec3, aspect: Double, orbit: AuroraLoomOrbit, width: Int,
                               height: Int) -> (x: Double, y: Double)? {
        guard width > 0, height > 0 else { return nil }
        let m = camera(aspect: aspect, orbit: orbit)
        return project(point, viewProjection: m.projection * m.view, width: width, height: height)
    }

    /// `point` projected through a ready view-projection (see `project(_:aspect:width:height:)`).
    static func project(_ point: Vec3, viewProjection: Mat4, width: Int, height: Int) -> (x: Double, y: Double)? {
        guard let p = ScreenProjection.project(point, viewProjection: viewProjection,
                                               viewport: Vec2(Double(width), Double(height))) else { return nil }
        return (p.point.x, p.point.y)
    }

    // MARK: CPU reference

    /// The CPU reference of the ribbons: for each ribbon 0 … 2, the pixel positions (as `project`) of its
    /// `centreLine(ribbon:snapshot:segments:)` points in a `width` × `height` viewport of aspect `aspect`; points
    /// behind the camera (none for the authored camera) are left out.
    public static func referenceSamples(snapshot: AuroraLoomSceneSnapshot, aspect: Double, width: Int, height: Int,
                                        segments: Int) -> [[(x: Double, y: Double)]] {
        guard width > 0, height > 0 else { return Array(repeating: [], count: ribbonCount) }
        let m = camera(aspect: aspect)
        let viewProjection = m.projection * m.view
        var result: [[(x: Double, y: Double)]] = []
        for r in 0..<ribbonCount {
            var pixels: [(x: Double, y: Double)] = []
            for p in centreLine(ribbon: r, snapshot: snapshot, segments: segments) {
                if let q = project(p, viewProjection: viewProjection, width: width, height: height) { pixels.append(q) }
            }
            result.append(pixels)
        }
        return result
    }

    /// The CPU reference of `gate`'s target marker: its pixel position (as `project`) in a `width` × `height` viewport of
    /// aspect `aspect`.
    public static func markerPixel(gate: Int, snapshot: AuroraLoomSceneSnapshot, aspect: Double, width: Int,
                                   height: Int) -> (x: Double, y: Double)? {
        project(marker(gate: gate, snapshot: snapshot), aspect: aspect, width: width, height: height)
    }
}
