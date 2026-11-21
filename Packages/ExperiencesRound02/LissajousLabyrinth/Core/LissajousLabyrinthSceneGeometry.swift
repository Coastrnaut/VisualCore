// LissajousLabyrinthSceneGeometry — feature 313 (R02-G02-03) T-R02G0203-004 (FR-R02G0203-001, 006; clarifications Q1,
// Q3; research R1–R4). The world of the labyrinth, built from a snapshot only: the lap's exact kernel samples scaled by
// 1/1,024 into world units (at the tier's stride), the camera-facing thread strip through them, the checkpoint rings, the
// obstacle icospheres and the tracer head disc, the authored camera that fits the scene with a 5 % margin for every
// aspect 0.4 … 2.5 (since feature 314 the dial-independent content sphere, see below), and the CPU projection that
// the simulator frame checks compare with rendered pixels. Doubles are used for drawing only; nothing here is consulted by the rules.
// Feature 314 (R02-G02-04) T-R02G0204-002 (FR-R02G0204-001, 002, 004; clarifications Q1, Q3; research R1, R2, R6): the
// dial-independent stage (`stageBounds`), the content sphere around the stage and the dial rings (`contentBounds`) that
// the camera now fits, and the camera orbit (`LissajousLabyrinthOrbit`, azimuth ±40°, elevation 10° … 60°).
import Foundation
import VisualCoreMath
import VisualCoreScenes

/// The geometry of the Lissajous Labyrinth scene: path, thread, rings, spheres, head, camera and projection.
///
/// World units are kernel units × ``unitsPerKernel`` (1/1,024), so a lap with amplitude 4 spans ±4 world units and a
/// ball centre at ±5,000 kernel units lies at about ±4.88. Every mesh builder takes a *view direction*: the unit
/// direction the camera looks along (from the eye towards the scene), ``viewDirection`` for the authored camera.
public enum LissajousLabyrinthSceneGeometry {
    /// World units per kernel unit, 1/1,024.
    public static let unitsPerKernel = 1.0 / 1_024
    /// The camera's vertical field of view in radians (45°).
    public static let fieldOfView = Double.pi / 4
    /// The unit direction from the scene centre to the eye: normalize(0.55, 0.45, 1.0), above, right and in front.
    public static let eyeDirection = Vec3(0.55, 0.45, 1.0).normalized
    /// The unit direction the authored camera looks along (from the eye towards the target), −``eyeDirection``.
    public static let viewDirection = -eyeDirection
    /// The margin the camera fit keeps on every side, as a fraction of the viewport (6 %; the guarantee is 5 %).
    public static let fitMargin = 0.06
    /// The aspect ratios (width / height) the framing is guaranteed for, 0.4 … 2.5.
    public static let aspectRange: ClosedRange<Double> = 0.4...2.5
    /// The default thread width in world units, 0.035.
    public static let threadWidth = 0.035
    /// The default tracer head radius in world units, 0.06.
    public static let headRadius = 0.06
    /// The extra radius added around every path sample in ``bounds(_:)`` so the thread and the head fit too
    /// (the larger of half the thread width and the head radius), 0.06.
    public static let pathMargin = max(threadWidth / 2, headRadius)
    /// The ring's inner radius as a fraction of the ball radius, 0.8.
    public static let ringInner = 0.8
    /// The number of rim segments of the head disc, 24 (24 triangles, 25 vertices).
    public static let headSegments = 24

    // MARK: Path

    /// The world position of a kernel point: each coordinate × ``unitsPerKernel``.
    public static func world(_ point: LissajousLabyrinthPoint) -> Vec3 {
        Vec3(Double(point.x) * unitsPerKernel, Double(point.y) * unitsPerKernel, Double(point.z) * unitsPerKernel)
    }

    /// The world centre of a ball (checkpoint or obstacle).
    public static func world(_ ball: LissajousLabyrinthBall) -> Vec3 {
        Vec3(Double(ball.x) * unitsPerKernel, Double(ball.y) * unitsPerKernel, Double(ball.z) * unitsPerKernel)
    }

    /// The world radius of a ball.
    public static func radius(_ ball: LissajousLabyrinthBall) -> Double {
        Double(ball.radius) * unitsPerKernel
    }

    /// The lap's samples of `snapshot` in world units at `tier`'s stride: samples 0, stride, 2 · stride, … (4,096 /
    /// stride points, in order), each exactly the kernel's sample (``LissajousLabyrinthLap/samples(_:level:)``) scaled by
    /// ``unitsPerKernel``. Shared samples have identical coordinates at every tier.
    public static func path(_ snapshot: LissajousLabyrinthSceneSnapshot, tier: LissajousLabyrinthTier) -> [Vec3] {
        let samples = LissajousLabyrinthLap.samples(snapshot.dials, level: snapshot.level)
        let stride = max(tier.stride, 1)
        var result: [Vec3] = []
        result.reserveCapacity(samples.count / stride + 1)
        var i = 0
        while i < samples.count {
            result.append(world(samples[i]))
            i += stride
        }
        return result
    }

    /// The world position of the tracer head: the lap sample at `snapshot.headTick`.
    public static func headPosition(_ snapshot: LissajousLabyrinthSceneSnapshot) -> Vec3 {
        let tick = min(max(snapshot.headTick, 0), LissajousLabyrinthLap.ticks - 1)
        return world(LissajousLabyrinthLap.position(tick: tick, dials: snapshot.dials, level: snapshot.level))
    }

    /// The bounding sphere of the scene: the centre of the axis-aligned box around every path sample (grown by
    /// ``pathMargin``), checkpoint ball and obstacle ball (each with its radius), and the smallest radius about that
    /// centre that holds all of them. Every vertex of ``threadMesh(_:tier:width:viewDirection:)`` (default width),
    /// ``ringMesh(_:segments:viewDirection:)``, ``sphereMesh(_:subdivisions:)`` and
    /// ``headMesh(position:radius:viewDirection:)`` (default radius) lies inside it.
    public static func bounds(_ snapshot: LissajousLabyrinthSceneSnapshot) -> (centre: Vec3, radius: Double) {
        var spheres: [(Vec3, Double)] = []
        for p in path(snapshot, tier: .of(0)) { spheres.append((p, pathMargin)) }
        for ball in snapshot.level.checkpoints { spheres.append((world(ball), radius(ball))) }
        for ball in snapshot.level.obstacles { spheres.append((world(ball), radius(ball))) }
        var low = Vec3(Double.infinity, Double.infinity, Double.infinity)
        var high = Vec3(-Double.infinity, -Double.infinity, -Double.infinity)
        for (c, r) in spheres {
            low = Vec3(min(low.x, c.x - r), min(low.y, c.y - r), min(low.z, c.z - r))
            high = Vec3(max(high.x, c.x + r), max(high.y, c.y + r), max(high.z, c.z + r))
        }
        let centre = (low + high) * 0.5
        var radius = 0.0
        for (c, r) in spheres { radius = max(radius, (c - centre).length + r) }
        return (centre, radius)
    }

    /// The smallest sphere about the centre of the axis-aligned box around `spheres` that holds all of them.
    static func enclosing(_ spheres: [(Vec3, Double)]) -> (centre: Vec3, radius: Double) {
        var low = Vec3(Double.infinity, Double.infinity, Double.infinity)
        var high = Vec3(-Double.infinity, -Double.infinity, -Double.infinity)
        for (c, r) in spheres {
            low = Vec3(min(low.x, c.x - r), min(low.y, c.y - r), min(low.z, c.z - r))
            high = Vec3(max(high.x, c.x + r), max(high.y, c.y + r), max(high.z, c.z + r))
        }
        let centre = (low + high) * 0.5
        var radius = 0.0
        for (c, r) in spheres { radius = max(radius, (c - centre).length + r) }
        return (centre, radius)
    }

    /// The stage of `level`: a bounding sphere that does not depend on the dials (feature 314, research R1).
    ///
    /// Every kernel sample of every setting lies in the amplitude box ±amplitude · 1,024 kernel units per axis (the
    /// integer sine is at most 1,024), that is ±amplitude world units; the box is grown by ``pathMargin`` so the thread
    /// and the head fit too. The sphere is the smallest one about the centre of the axis-aligned box around that grown
    /// box and every checkpoint and obstacle ball (each with its radius) that holds all of them, so every path the level
    /// can draw, at any dials, lies inside it. The dial rings of ``LissajousLabyrinthHandles`` are laid out against it.
    public static func stageBounds(level: LissajousLabyrinthLevel) -> (centre: Vec3, radius: Double) {
        let scale = Double(LissajousLabyrinthSine.scale) * unitsPerKernel
        let ax = Double(level.amplitudes[0]) * scale + pathMargin
        let ay = Double(level.amplitudes[1]) * scale + pathMargin
        let az = Double(level.amplitudes[2]) * scale + pathMargin
        var spheres: [(Vec3, Double)] = []
        for sx in [-1.0, 1.0] {
            for sy in [-1.0, 1.0] {
                for sz in [-1.0, 1.0] { spheres.append((Vec3(sx * ax, sy * ay, sz * az), 0)) }
            }
        }
        for ball in level.checkpoints { spheres.append((world(ball), radius(ball))) }
        for ball in level.obstacles { spheres.append((world(ball), radius(ball))) }
        return enclosing(spheres)
    }

    /// The content of `level` the camera fits: the sphere about the centre of the box around ``stageBounds(level:)``
    /// and the four dial rings (each ring circle of ``LissajousLabyrinthHandles/ringRadius(level:)`` grown by
    /// ``LissajousLabyrinthHandles/knobRadius(level:)`` so the knobs fit too) that holds all of them. Independent of
    /// the dials.
    public static func contentBounds(level: LissajousLabyrinthLevel) -> (centre: Vec3, radius: Double) {
        let stage = stageBounds(level: level)
        var spheres: [(Vec3, Double)] = [(stage.centre, stage.radius)]
        let extent = LissajousLabyrinthHandles.ringRadius(level: level) + LissajousLabyrinthHandles.knobRadius(level: level)
        for dial in LissajousLabyrinthDial.allCases {
            spheres.append((LissajousLabyrinthHandles.ringCentre(dial, level: level), extent))
        }
        return enclosing(spheres)
    }

    // MARK: Camera

    /// `aspect` made usable: a non-finite or non-positive aspect becomes 1; others are clamped to 0.1 … 10.
    static func usableAspect(_ aspect: Double) -> Double {
        guard aspect.isFinite, aspect > 0 else { return 1 }
        return min(max(aspect, 0.1), 10)
    }

    /// The eye distance from the bounds centre that fits a sphere of `radius` for `aspect` with ``fitMargin``: the
    /// sphere must lie in the cone of half-angle α around the view axis, tan α = (1 − 2 · margin) · min(tan(fovY/2),
    /// aspect · tan(fovY/2)), so the distance is radius / sin α. Every point of the sphere then projects within
    /// NDC ±(1 − 2 · margin) on both axes.
    static func distance(radius: Double, aspect: Double) -> Double {
        let half = tan(fieldOfView / 2)
        let limit = (1 - 2 * fitMargin) * min(half, usableAspect(aspect) * half)
        let alpha = atan(limit)
        return max(radius, 1e-3) / sin(alpha)
    }

    /// The camera for `aspect` (width / height) at the authored orbit: ``camera(aspect:snapshot:orbit:)`` with
    /// ``LissajousLabyrinthOrbit/authored``.
    public static func camera(aspect: Double,
                              snapshot: LissajousLabyrinthSceneSnapshot) -> (eye: Vec3, target: Vec3, fovY: Double) {
        camera(aspect: aspect, snapshot: snapshot, orbit: .authored)
    }

    /// The camera for `aspect` (width / height) at `orbit` (clamped): the eye on the orbit's eye direction from the
    /// centre of ``contentBounds(level:)`` of the snapshot's level at the closed-form fitted distance, looking at that
    /// centre, a 45° vertical field of view. The fitted content is a sphere, so for every orbit and every aspect
    /// 0.4 … 2.5 the stage (every path the level can draw, checkpoints, obstacles, thread and head) and the four dial
    /// rings with their knobs fit with at least 5 % margin on every side. The framing does not depend on the dials.
    public static func camera(aspect: Double, snapshot: LissajousLabyrinthSceneSnapshot,
                              orbit: LissajousLabyrinthOrbit) -> (eye: Vec3, target: Vec3, fovY: Double) {
        let b = contentBounds(level: snapshot.level)
        let d = distance(radius: b.radius, aspect: aspect)
        return (b.centre + orbit.eyeDirection * d, b.centre, fieldOfView)
    }

    /// The eye distances of the front and back of the drawn figure's bounding sphere (``bounds(_:)``) from the eye of
    /// ``camera(aspect:snapshot:orbit:)``: the distance from the eye to the sphere's centre minus and plus its radius,
    /// the front at least 0.001. These are the `u_fadeNear` and `u_fadeFar` of the thread's depth fading.
    public static func depthRange(aspect: Double, snapshot: LissajousLabyrinthSceneSnapshot,
                                  orbit: LissajousLabyrinthOrbit = .authored) -> (near: Double, far: Double) {
        let b = bounds(snapshot)
        let eye = camera(aspect: usableAspect(aspect), snapshot: snapshot, orbit: orbit).eye
        let d = (b.centre - eye).length
        return (max(d - b.radius, 1e-3), d + b.radius)
    }

    /// The view-projection of ``camera(aspect:snapshot:orbit:)``: `Mat4.perspective` (GL depth range, near half the
    /// gap to the content sphere, far beyond it) times `Mat4.lookAt` with +y up.
    public static func viewProjection(aspect: Double, snapshot: LissajousLabyrinthSceneSnapshot,
                                      orbit: LissajousLabyrinthOrbit = .authored) -> Mat4 {
        let b = contentBounds(level: snapshot.level)
        let a = usableAspect(aspect)
        let d = distance(radius: b.radius, aspect: a)
        let eye = b.centre + orbit.eyeDirection * d
        let view = Mat4.lookAt(eye: eye, target: b.centre, up: Vec3(0, 1, 0))
        let near = max((d - b.radius) * 0.5, 1e-3)
        let projection = Mat4.perspective(fovY: fieldOfView, aspect: a, near: near, far: d + 2 * b.radius + 1)
        return projection * view
    }

    /// The pixel position of `p` in a `width` × `height` viewport (origin top left, y down) through
    /// ``viewProjection(aspect:snapshot:orbit:)``; nil behind the camera, for a non-positive size or non-finite input.
    public static func project(_ p: Vec3, aspect: Double, snapshot: LissajousLabyrinthSceneSnapshot, width: Int,
                               height: Int, orbit: LissajousLabyrinthOrbit = .authored) -> Vec2? {
        guard width > 0, height > 0 else { return nil }
        return project(p, viewProjection: viewProjection(aspect: aspect, snapshot: snapshot, orbit: orbit),
                       width: width, height: height)
    }

    /// `p` projected through a ready view-projection (see ``project(_:aspect:snapshot:width:height:)``).
    public static func project(_ p: Vec3, viewProjection: Mat4, width: Int, height: Int) -> Vec2? {
        guard width > 0, height > 0 else { return nil }
        return ScreenProjection.project(p, viewProjection: viewProjection,
                                        viewport: Vec2(Double(width), Double(height)))?.point
    }

    // MARK: Meshes

    /// A unit vector perpendicular to `v` (any; deterministic): `v` crossed with the axis it is least aligned with.
    static func perpendicular(_ v: Vec3) -> Vec3 {
        let ax = abs(v.x), ay = abs(v.y), az = abs(v.z)
        let axis: Vec3 = ax <= ay && ax <= az ? Vec3(1, 0, 0) : (ay <= az ? Vec3(0, 1, 0) : Vec3(0, 0, 1))
        let p = v.cross(axis).normalized
        return p == .zero ? Vec3(1, 0, 0) : p
    }

    /// `direction` as a usable unit view direction: a zero or non-finite one becomes ``viewDirection``.
    static func usableView(_ direction: Vec3) -> Vec3 {
        let v = direction.isFinite ? direction.normalized : .zero
        return v == .zero ? viewDirection : v
    }

    /// Adds triangle a, b, c wound so its geometric normal points along `front` (degenerate triangles keep a, b, c).
    static func facing(_ builder: inout MeshBuilder, _ a: UInt32, _ b: UInt32, _ c: UInt32, _ pa: Vec3, _ pb: Vec3,
                       _ pc: Vec3, front: Vec3) throws(MeshError) {
        if (pb - pa).cross(pc - pa).dot(front) < 0 {
            try builder.triangle(a, c, b)
        } else {
            try builder.triangle(a, b, c)
        }
    }

    /// The thread: a closed camera-facing strip through ``path(_:tier:)``.
    ///
    /// For each of the N = 4,096 / stride samples p_i two vertices p_i ± (w/2) · s_i, where
    /// s_i = normalize(t_i × v), t_i = p_(i+1) − p_(i−1) (cyclic), v = `viewDirection`; when that is degenerate the
    /// forward difference is tried, then any perpendicular of v. Vertex 2i is the − side (uv.y = −1), 2i + 1 the + side
    /// (uv.y = +1); uv.x = i · stride / 4,096, the lap fraction. The loop is closed by an extra pair (vertices 2N and
    /// 2N + 1) at the first sample's position and offsets with uv.x = 1, so the closing segment interpolates the lap
    /// fraction from (N − 1) · stride / 4,096 to 1 rather than back to 0. The mesh has exactly 2N + 2 vertices and 2N
    /// triangles, each wound to face the camera; all positions are in world space. Normals are −v (towards the
    /// camera; unused by the thread program). A non-finite or non-positive width becomes ``threadWidth``.
    ///
    /// - Throws: `MeshError` from `MeshBuilder` (not expected: 8,192 vertices at most).
    public static func threadMesh(_ snapshot: LissajousLabyrinthSceneSnapshot, tier: LissajousLabyrinthTier,
                                  width: Double = threadWidth,
                                  viewDirection: Vec3 = viewDirection) throws(MeshError) -> Mesh {
        let points = path(snapshot, tier: tier)
        let v = usableView(viewDirection)
        let half = (width.isFinite && width > 0 ? width : threadWidth) / 2
        let n = points.count
        let stride = max(tier.stride, 1)
        let normal = -v
        var builder = MeshBuilder()
        var ids: [UInt32] = []
        ids.reserveCapacity(2 * n + 2)
        var positions: [Vec3] = []
        positions.reserveCapacity(2 * n + 2)
        for i in 0..<n {
            let next = points[(i + 1) % n], previous = points[(i + n - 1) % n]
            var side = (next - previous).cross(v).normalized
            if side == .zero { side = (next - points[i]).cross(v).normalized }
            if side == .zero { side = perpendicular(v) }
            let u = Double(i * stride) / Double(LissajousLabyrinthLap.ticks)
            let minus = points[i] - side * half, plus = points[i] + side * half
            ids.append(try builder.vertex(minus, normal: normal, uv: Vec2(u, -1)))
            ids.append(try builder.vertex(plus, normal: normal, uv: Vec2(u, 1)))
            positions.append(minus)
            positions.append(plus)
        }
        // The closing pair: the first sample's vertices again, at lap fraction 1.
        ids.append(try builder.vertex(positions[0], normal: normal, uv: Vec2(1, -1)))
        ids.append(try builder.vertex(positions[1], normal: normal, uv: Vec2(1, 1)))
        positions.append(positions[0])
        positions.append(positions[1])
        for i in 0..<n {
            let j = i + 1
            let a = 2 * i, b = 2 * i + 1, c = 2 * j, d = 2 * j + 1
            try facing(&builder, ids[a], ids[c], ids[b], positions[a], positions[c], positions[b], front: normal)
            try facing(&builder, ids[b], ids[c], ids[d], positions[b], positions[c], positions[d], front: normal)
        }
        return builder.build()
    }

    /// A checkpoint ring: a flat annulus at the ball's centre facing the camera (in the plane perpendicular to
    /// `viewDirection`), outer radius the ball's world radius, inner ``ringInner`` × that. `segments` (clamped 8 … 256)
    /// gives 2 · segments vertices (inner at even, outer at odd indices) and 2 · segments triangles; uv.x = k /
    /// segments around, uv.y = 0 inner, 1 outer; normals −v (towards the camera, unit). World-space positions.
    ///
    /// - Throws: `MeshError` from `MeshBuilder` (not expected).
    public static func ringMesh(_ ball: LissajousLabyrinthBall, segments: Int = 48,
                                viewDirection: Vec3 = viewDirection) throws(MeshError) -> Mesh {
        let n = min(max(segments, 8), 256)
        let v = usableView(viewDirection)
        let e1 = perpendicular(v), e2 = v.cross(e1).normalized
        let centre = world(ball), outer = radius(ball), inner = ringInner * outer
        let normal = -v
        var builder = MeshBuilder()
        var ids: [UInt32] = []
        var positions: [Vec3] = []
        for k in 0..<n {
            let angle = 2 * Double.pi * Double(k) / Double(n)
            let direction = e1 * cos(angle) + e2 * sin(angle)
            let u = Double(k) / Double(n)
            let pi = centre + direction * inner, po = centre + direction * outer
            ids.append(try builder.vertex(pi, normal: normal, uv: Vec2(u, 0)))
            ids.append(try builder.vertex(po, normal: normal, uv: Vec2(u, 1)))
            positions.append(pi)
            positions.append(po)
        }
        for k in 0..<n {
            let j = (k + 1) % n
            let a = 2 * k, b = 2 * k + 1, c = 2 * j, d = 2 * j + 1
            try facing(&builder, ids[a], ids[b], ids[c], positions[a], positions[b], positions[c], front: normal)
            try facing(&builder, ids[b], ids[d], ids[c], positions[b], positions[d], positions[c], front: normal)
        }
        return builder.build()
    }

    /// A point on a checkpoint ring's band at mid-radius (0.9 × the ball's world radius) from its centre, along the
    /// camera's up axis (+y made perpendicular to `viewDirection`; any perpendicular when +y is parallel), for frame
    /// checks that sample the ring's colour rather than its hollow centre. It lies in the plane of
    /// ``ringMesh(_:segments:viewDirection:)`` between its inner and outer radius.
    public static func ringBandPoint(_ ball: LissajousLabyrinthBall, viewDirection: Vec3 = viewDirection) -> Vec3 {
        let v = usableView(viewDirection)
        var up = (Vec3(0, 1, 0) - v * v.y).normalized
        if up == .zero { up = perpendicular(v) }
        return world(ball) + up * ((1 + ringInner) / 2 * radius(ball))
    }

    /// An obstacle sphere: an icosphere at the ball's centre with the ball's world radius. `subdivisions` (clamped
    /// 0 … 3) splits each face of the icosahedron into four, each new vertex pushed onto the sphere: 20 · 4^s triangles
    /// and 10 · 4^s + 2 vertices (320 and 162 at the default 2). Every vertex lies exactly on the sphere (to rounding);
    /// normals point outwards; uv = (longitude / 2π + 0.5, latitude / π + 0.5) of the normal; triangles wind
    /// counter-clockwise seen from outside.
    ///
    /// - Throws: `MeshError` from `MeshBuilder` (not expected).
    public static func sphereMesh(_ ball: LissajousLabyrinthBall,
                                  subdivisions: Int = 2) throws(MeshError) -> Mesh {
        let s = min(max(subdivisions, 0), 3)
        let t = (1 + 5.0.squareRoot()) / 2
        var vertices: [Vec3] = [
            Vec3(-1, t, 0), Vec3(1, t, 0), Vec3(-1, -t, 0), Vec3(1, -t, 0),
            Vec3(0, -1, t), Vec3(0, 1, t), Vec3(0, -1, -t), Vec3(0, 1, -t),
            Vec3(t, 0, -1), Vec3(t, 0, 1), Vec3(-t, 0, -1), Vec3(-t, 0, 1),
        ]
        for i in 0..<vertices.count { vertices[i] = vertices[i].normalized }
        var faces: [[Int]] = [
            [0, 11, 5], [0, 5, 1], [0, 1, 7], [0, 7, 10], [0, 10, 11],
            [1, 5, 9], [5, 11, 4], [11, 10, 2], [10, 7, 6], [7, 1, 8],
            [3, 9, 4], [3, 4, 2], [3, 2, 6], [3, 6, 8], [3, 8, 9],
            [4, 9, 5], [2, 4, 11], [6, 2, 10], [8, 6, 7], [9, 8, 1],
        ]
        for _ in 0..<s {
            var midpoints: [Int: Int] = [:]
            func midpoint(_ a: Int, _ b: Int) -> Int {
                let key = min(a, b) * 65_536 + max(a, b)
                if let found = midpoints[key] { return found }
                vertices.append((vertices[min(a, b)] + vertices[max(a, b)]).normalized)
                midpoints[key] = vertices.count - 1
                return vertices.count - 1
            }
            var next: [[Int]] = []
            next.reserveCapacity(faces.count * 4)
            for f in faces {
                let ab = midpoint(f[0], f[1]), bc = midpoint(f[1], f[2]), ca = midpoint(f[2], f[0])
                next.append([f[0], ab, ca])
                next.append([f[1], bc, ab])
                next.append([f[2], ca, bc])
                next.append([ab, bc, ca])
            }
            faces = next
        }
        let centre = world(ball), r = radius(ball)
        var builder = MeshBuilder()
        var ids: [UInt32] = []
        var positions: [Vec3] = []
        for n in vertices {
            let u = atan2(n.z, n.x) / (2 * Double.pi) + 0.5
            let w = asin(min(max(n.y, -1), 1)) / Double.pi + 0.5
            let p = centre + n * r
            ids.append(try builder.vertex(p, normal: n, uv: Vec2(u, w)))
            positions.append(p)
        }
        for f in faces {
            let outward = (vertices[f[0]] + vertices[f[1]] + vertices[f[2]]).normalized
            try facing(&builder, ids[f[0]], ids[f[1]], ids[f[2]], positions[f[0]], positions[f[1]], positions[f[2]],
                       front: outward)
        }
        return builder.build()
    }

    /// The tracer head: a flat disc of `radius` (non-finite or non-positive becomes ``headRadius``) at `position`
    /// facing the camera, a centre vertex (uv 0.5, 0.5) and ``headSegments`` rim vertices (uv on the unit circle mapped
    /// to 0 … 1): 25 vertices and 24 triangles, normals −v (towards the camera).
    ///
    /// - Throws: `MeshError` from `MeshBuilder` (not expected).
    public static func headMesh(position: Vec3, radius: Double = headRadius,
                                viewDirection: Vec3 = viewDirection) throws(MeshError) -> Mesh {
        let v = usableView(viewDirection)
        let r = radius.isFinite && radius > 0 ? radius : headRadius
        let centre = position.isFinite ? position : .zero
        let e1 = perpendicular(v), e2 = v.cross(e1).normalized
        let normal = -v
        var builder = MeshBuilder()
        let middle = try builder.vertex(centre, normal: normal, uv: Vec2(0.5, 0.5))
        var ids: [UInt32] = []
        var positions: [Vec3] = []
        for k in 0..<headSegments {
            let angle = 2 * Double.pi * Double(k) / Double(headSegments)
            let p = centre + (e1 * cos(angle) + e2 * sin(angle)) * r
            ids.append(try builder.vertex(p, normal: normal, uv: Vec2(0.5 + 0.5 * cos(angle), 0.5 + 0.5 * sin(angle))))
            positions.append(p)
        }
        for k in 0..<headSegments {
            let j = (k + 1) % headSegments
            try facing(&builder, middle, ids[k], ids[j], centre, positions[k], positions[j], front: normal)
        }
        return builder.build()
    }
}

/// The orbit of the Lissajous Labyrinth camera (feature 314, R02-G02-04, research R6): an azimuth offset around the
/// authored azimuth and an elevation above the x–z plane, both in radians. Presentation only, never saved.
///
/// The azimuth is measured about +y from +z towards +x; the authored azimuth is atan2(0.55, 1.0) ≈ 28.8° and the authored
/// elevation asin(0.45 / |(0.55, 0.45, 1.0)|) ≈ 21.5°, so ``authored`` reproduces
/// `LissajousLabyrinthSceneGeometry.eyeDirection`.
public struct LissajousLabyrinthOrbit: Sendable, Equatable {
    /// The azimuth offset in radians, added to ``azimuth``; allowed −40° … 40°.
    public var azimuthOffset: Double
    /// The elevation above the x–z plane in radians; allowed 10° … 60°.
    public var elevation: Double

    /// An orbit of the given offset and elevation (not clamped; see ``clamped()``).
    public init(azimuthOffset: Double, elevation: Double) {
        self.azimuthOffset = azimuthOffset
        self.elevation = elevation
    }

    /// The authored azimuth in radians, atan2(0.55, 1.0) ≈ 28.8°.
    public static let azimuth: Double = atan2(0.55, 1.0)
    /// The authored orbit: offset 0, elevation asin(0.45 / |(0.55, 0.45, 1.0)|) ≈ 21.5°.
    public static let authored = LissajousLabyrinthOrbit(
        azimuthOffset: 0, elevation: asin(0.45 / Vec3(0.55, 0.45, 1.0).length))
    /// The allowed azimuth offsets in radians, −40° … 40°.
    public static let azimuthRange: ClosedRange<Double> = (-40.0 * Double.pi / 180)...(40.0 * Double.pi / 180)
    /// The allowed elevations in radians, 10° … 60°.
    public static let elevationRange: ClosedRange<Double> = (10.0 * Double.pi / 180)...(60.0 * Double.pi / 180)

    /// This orbit with each angle clamped to its range; a non-finite angle becomes the authored one.
    public func clamped() -> LissajousLabyrinthOrbit {
        let a: Double = azimuthOffset.isFinite ? azimuthOffset : Self.authored.azimuthOffset
        let e: Double = elevation.isFinite ? elevation : Self.authored.elevation
        return LissajousLabyrinthOrbit(
            azimuthOffset: min(max(a, Self.azimuthRange.lowerBound), Self.azimuthRange.upperBound),
            elevation: min(max(e, Self.elevationRange.lowerBound), Self.elevationRange.upperBound))
    }

    /// The unit direction from the content centre to the eye at the clamped orbit:
    /// (cos e · sin a, sin e, cos e · cos a) with a = ``azimuth`` + offset and e the elevation.
    public var eyeDirection: Vec3 {
        let o: LissajousLabyrinthOrbit = clamped()
        let a: Double = Self.azimuth + o.azimuthOffset
        return Vec3(cos(o.elevation) * sin(a), sin(o.elevation), cos(o.elevation) * cos(a))
    }
}
