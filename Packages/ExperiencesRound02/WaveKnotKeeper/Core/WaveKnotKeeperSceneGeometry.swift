// WaveKnotKeeperSceneGeometry — feature 323 (R02-G03-03) T-R02G0303-004 (FR-R02G0303-001, 006; SC-R02G0303-003;
// clarifications Q1–Q3; research R1, R2, R4). The world of the rope, built from a snapshot only: the control points
// scaled by 1/8 into world units, the closed glass tube along the control polygon (straight segments, corners rounded
// by quadratic arcs between the quarter points, parallel-transport frames with the closing twist spread evenly)
// carrying a per-vertex crossing weight for the caustic pulses, the glow shells, the handle icosphere and the gate
// cubes, the fixed authored camera down −z tilted 20° about x that fits the figure's bounding sphere with a 5 % margin
// for every aspect 0.4 … 2.5, and the CPU projection that the simulator frame checks compare with rendered pixels.
// Doubles are used for drawing only; nothing here is consulted by the rules.
import Foundation
import VisualCoreMath
import VisualCoreScenes

/// The fixed authored camera of the Wave Knot Keeper scene for one snapshot and one aspect.
///
/// Built only by ``WaveKnotKeeperSceneGeometry/camera(for:aspect:)``. World positions are in world units (kernel units
/// × 1/8); ``viewProjection`` maps them to GL clip space (right-handed, depth −1 … 1).
public struct WaveKnotKeeperCamera: Sendable, Equatable {
    /// The eye position in world units.
    public let eye: SIMD3<Double>
    /// The point looked at: the centre of the figure's bounding sphere.
    public let target: SIMD3<Double>
    /// The vertical field of view in radians.
    public let fovY: Double
    /// The aspect ratio (width / height) the camera was fitted for, after clamping to 0.1 … 10 (1 when unusable).
    public let aspect: Double
    /// The near clip distance.
    public let near: Double
    /// The far clip distance.
    public let far: Double
    /// The view-projection matrix: `Mat4.perspective` (GL depth range) times `Mat4.lookAt` with +y up.
    public let viewProjection: Mat4
}

/// The geometry of the Wave Knot Keeper scene: world points, rope tube and glow, handles, gates, camera and projection.
///
/// World units are kernel units × ``unitsPerKernel`` (1/8), so the kernel's bounds −16 … 16 span ±2 world units.
///
/// **Rope vertex stream** (``ropeMesh(_:tier:radius:)``): `position` (world), `normal` (unit, outwards from the tube
/// axis), `uv.x` the **crossing weight** 0 … 1 (`a_uv.x`) that the rope shader multiplies with the caustic pulse and
/// `uv.y` the arc-length fraction of the ring's centre around the loop (0 at the first ring, 1 at the closing copy of
/// it; not read by the shaders). Positions are drawn with an identity model matrix.
public enum WaveKnotKeeperSceneGeometry {
    /// World units per kernel unit, 1/8.
    public static let unitsPerKernel = 1.0 / 8
    /// The rope tube radius in world units, 0.1.
    public static let tubeRadius = 0.1
    /// The handle sphere radius in world units, 0.18.
    public static let handleRadius = 0.18
    /// The padding around a gate in kernel units, 0.5 (the cube spans min − 0.5 … max + 0.5).
    public static let gatePadding = 0.5
    /// The glow shell radius growth per shell, as a fraction of the tube radius: shell k (1 …) has radius
    /// ``tubeRadius`` × (1 + 0.5 k), so 0.15 and 0.2 world units.
    public static let glowStep = 0.5
    /// The largest glow shell radius at any tier, 0.2 world units.
    public static let maxGlowRadius = tubeRadius * (1 + glowStep * 2)
    /// The extra radius around every control point in ``bounds(_:)``: the larger of the outer glow shell and the
    /// handle radius, 0.2.
    public static let pointMargin = max(maxGlowRadius, handleRadius)
    /// The camera's vertical field of view in radians (45°).
    public static let fieldOfView = Double.pi / 4
    /// The camera's tilt about x in radians (20°).
    public static let tilt = 20.0 * Double.pi / 180
    /// The unit direction from the scene centre to the eye: (0, sin 20°, cos 20°), so the camera looks down −z, tilted
    /// 20° about x (from slightly above).
    public static let eyeDirection = SIMD3<Double>(0, sin(tilt), cos(tilt))
    /// The margin the camera fit keeps on every side, as a fraction of the viewport (6 %; the guarantee is 5 %).
    public static let fitMargin = 0.06
    /// The aspect ratios (width / height) the framing is guaranteed for, 0.4 … 2.5.
    public static let aspectRange: ClosedRange<Double> = 0.4...2.5

    // MARK: World

    /// The world position of a kernel point: each coordinate × ``unitsPerKernel``.
    public static func world(_ point: WaveKnotKeeperPoint) -> SIMD3<Double> {
        SIMD3(Double(point.x), Double(point.y), Double(point.z)) * unitsPerKernel
    }

    /// The rope's control points in world units (kernel × 1/8), in rope order. The same at every tier.
    public static func worldPoints(_ snapshot: WaveKnotKeeperSceneSnapshot) -> [SIMD3<Double>] {
        snapshot.points.map(world)
    }

    /// The world midpoint of every segment, in segment order (segment i joins point i to point i + 1, the last to the
    /// first); empty for fewer than two points. Each lies on the tube's straight middle.
    public static func segmentMidpoints(_ snapshot: WaveKnotKeeperSceneSnapshot) -> [SIMD3<Double>] {
        let p = worldPoints(snapshot)
        guard p.count >= 2 else { return [] }
        return (0..<p.count).map { (p[$0] + p[($0 + 1) % p.count]) * 0.5 }
    }

    /// The world box of a gate: (min − ``gatePadding``, max + ``gatePadding``) in kernel units, × 1/8.
    public static func gateBox(_ gate: WaveKnotKeeperGate) -> (low: SIMD3<Double>, high: SIMD3<Double>) {
        let low = SIMD3(Double(gate.min.x), Double(gate.min.y), Double(gate.min.z)) - SIMD3(repeating: gatePadding)
        let high = SIMD3(Double(gate.max.x), Double(gate.max.y), Double(gate.max.z)) + SIMD3(repeating: gatePadding)
        return (low * unitsPerKernel, high * unitsPerKernel)
    }

    /// The world centre of a gate's box.
    public static func gateCentre(_ gate: WaveKnotKeeperGate) -> SIMD3<Double> {
        let box = gateBox(gate)
        return (box.low + box.high) * 0.5
    }

    /// The world point of `mark` on its over-strand: the point of segment `mark.over` whose xy-projection is the
    /// crossing's (x, y), with the segment's z there; nil when the segment does not exist or has no xy extent.
    public static func crossingPoint(_ mark: WaveKnotKeeperCrossingMark,
                                     in snapshot: WaveKnotKeeperSceneSnapshot) -> SIMD3<Double>? {
        guard let t = crossingParameter(mark, points: snapshot.points) else { return nil }
        let n = snapshot.points.count
        let a = world(snapshot.points[mark.over]), b = world(snapshot.points[(mark.over + 1) % n])
        return a + (b - a) * t
    }

    /// The parameter 0 … 1 along segment `mark.over` of the crossing's projected point; nil when unusable.
    static func crossingParameter(_ mark: WaveKnotKeeperCrossingMark, points: [WaveKnotKeeperPoint]) -> Double? {
        let n = points.count
        guard n >= 2, (0..<n).contains(mark.over), mark.x.isFinite, mark.y.isFinite else { return nil }
        let a = points[mark.over], b = points[(mark.over + 1) % n]
        let dx = Double(b.x - a.x), dy = Double(b.y - a.y)
        let len2 = dx * dx + dy * dy
        guard len2 > 0 else { return nil }
        let t = ((mark.x - Double(a.x)) * dx + (mark.y - Double(a.y)) * dy) / len2
        return min(max(t, 0), 1)
    }

    /// The bounding sphere of the scene: the centre of the axis-aligned box around every control point (grown by
    /// ``pointMargin``) and every gate box corner, and the smallest radius about that centre holding all of them. Every
    /// vertex of the rope, glow, handle (placed at a control point) and gate meshes lies inside it. A snapshot without
    /// points or gates gives centre 0 and radius 1.
    public static func bounds(_ snapshot: WaveKnotKeeperSceneSnapshot) -> (centre: SIMD3<Double>, radius: Double) {
        var spheres: [(SIMD3<Double>, Double)] = worldPoints(snapshot).map { ($0, pointMargin) }
        for gate in snapshot.gates {
            let box = gateBox(gate)
            for corner in 0..<8 {
                spheres.append((SIMD3(corner & 1 == 0 ? box.low.x : box.high.x,
                                      corner & 2 == 0 ? box.low.y : box.high.y,
                                      corner & 4 == 0 ? box.low.z : box.high.z), 0))
            }
        }
        guard !spheres.isEmpty else { return (.zero, 1) }
        var low = SIMD3<Double>(repeating: .infinity), high = SIMD3<Double>(repeating: -.infinity)
        for (c, r) in spheres {
            low = pointwiseMin(low, c - SIMD3(repeating: r))
            high = pointwiseMax(high, c + SIMD3(repeating: r))
        }
        let centre = (low + high) * 0.5
        var radius = 0.0
        for (c, r) in spheres { radius = max(radius, length(c - centre) + r) }
        return (centre, max(radius, 1e-3))
    }

    // MARK: Camera

    /// `aspect` made usable: a non-finite or non-positive aspect becomes 1; others are clamped to 0.1 … 10.
    static func usableAspect(_ aspect: Double) -> Double {
        guard aspect.isFinite, aspect > 0 else { return 1 }
        return min(max(aspect, 0.1), 10)
    }

    /// The eye distance that fits a sphere of `radius` for `aspect` with ``fitMargin``: the sphere must lie in the cone
    /// of half-angle α around the view axis, tan α = (1 − 2 · margin) · min(tan(fovY/2), aspect · tan(fovY/2)), so the
    /// distance is radius / sin α. Every point of the sphere then projects within NDC ±(1 − 2 · margin) on both axes.
    static func distance(radius: Double, aspect: Double) -> Double {
        let half = tan(fieldOfView / 2)
        let limit = (1 - 2 * fitMargin) * min(half, usableAspect(aspect) * half)
        return max(radius, 1e-3) / sin(atan(limit))
    }

    /// The fixed authored camera for `snapshot` and `aspect` (width / height): the eye on ``eyeDirection`` from the
    /// bounds centre at the fitted distance, looking at the bounds centre with +y up and a 45° vertical field of view.
    /// For aspects 0.4 … 2.5 the whole bounding sphere (rope, glow, handles and gates) projects inside the view with at
    /// least 5 % margin on every side. Independent of the quality tier.
    public static func camera(for snapshot: WaveKnotKeeperSceneSnapshot, aspect: Double) -> WaveKnotKeeperCamera {
        let b = bounds(snapshot)
        let a = usableAspect(aspect)
        let d = distance(radius: b.radius, aspect: a)
        let eye = b.centre + eyeDirection * d
        let near = max((d - b.radius) * 0.5, 1e-3)
        let far = d + 2 * b.radius + 1
        let view = Mat4.lookAt(eye: vec(eye), target: vec(b.centre), up: Vec3(0, 1, 0))
        let projection = Mat4.perspective(fovY: fieldOfView, aspect: a, near: near, far: far)
        return WaveKnotKeeperCamera(eye: eye, target: b.centre, fovY: fieldOfView, aspect: a, near: near, far: far,
                                    viewProjection: projection * view)
    }

    /// `point` in view coordinates 0 … 1 (origin top left, y down; multiply by the viewport size for pixels, the
    /// convention of ``ScreenProjection``); nil behind the camera or for non-finite input. Points outside the view give
    /// coordinates outside 0 … 1.
    public static func project(_ point: SIMD3<Double>, camera: WaveKnotKeeperCamera) -> SIMD2<Double>? {
        guard let p = ScreenProjection.project(vec(point), viewProjection: camera.viewProjection,
                                               viewport: Vec2(1, 1))?.point else { return nil }
        return SIMD2(p.x, p.y)
    }

    /// `point` in pixels of a `width` × `height` viewport (origin top left, y down), as Lissajous Labyrinth's
    /// projection; nil for a non-positive size, behind the camera or for non-finite input.
    public static func pixel(_ point: SIMD3<Double>, camera: WaveKnotKeeperCamera, width: Int, height: Int) -> Vec2? {
        guard width > 0, height > 0, let v = project(point, camera: camera) else { return nil }
        return Vec2(v.x * Double(width), v.y * Double(height))
    }

    // MARK: Centreline

    /// One sample of the tube's centreline: its position and the segment it belongs to.
    struct Sample {
        var position: SIMD3<Double>
        var segment: Int
    }

    /// The tube's centreline at `tier`, in loop order (closed: the last joins the first).
    ///
    /// For each control point P_i (n points) with neighbours P_(i−1), P_(i+1): A_i = P_i + (P_(i−1) − P_i) / 4 and
    /// B_i = P_i + (P_(i+1) − P_i) / 4; corner i is the quadratic arc (1 − t)² A_i + 2t(1 − t) P_i + t² B_i sampled at
    /// `tier.cornerSamples` (at least 2) even values of t from 0 to 1. Samples with t < 0.5 belong to segment i − 1,
    /// the others to segment i. Between corner i and corner i + 1 lies the straight middle of segment i, from B_i to
    /// A_(i+1); for each crossing whose over-strand is segment i, the points at −2, −1, 0, +1 and +2 tube radii along
    /// the segment from the crossing point are inserted where they fall strictly inside the straight middle, so the
    /// crossing weight's ramp is carried by vertices. Fewer than two points give no samples.
    static func centreline(_ snapshot: WaveKnotKeeperSceneSnapshot, tier: WaveKnotKeeperTier,
                           radius: Double = tubeRadius) -> [Sample] {
        let p = worldPoints(snapshot)
        let n = p.count
        guard n >= 2 else { return [] }
        let c = max(tier.cornerSamples, 2)
        var extra: [[Double]] = Array(repeating: [], count: n)
        for mark in snapshot.crossings {
            guard let t = crossingParameter(mark, points: snapshot.points) else { continue }
            let length = safeLength(p[(mark.over + 1) % n] - p[mark.over])
            guard length > 0 else { continue }
            for k in -2...2 {
                let s = t + Double(k) * radius / length
                if s > 0.25 + 1e-9 && s < 0.75 - 1e-9 { extra[mark.over].append(s) }
            }
        }
        var result: [Sample] = []
        result.reserveCapacity(n * c + 5 * snapshot.crossings.count)
        for i in 0..<n {
            let previous = p[(i + n - 1) % n], next = p[(i + 1) % n]
            let a = p[i] + (previous - p[i]) * 0.25, b = p[i] + (next - p[i]) * 0.25
            for k in 0..<c {
                let t = Double(k) / Double(c - 1)
                let q = a * ((1 - t) * (1 - t)) + p[i] * (2 * t * (1 - t)) + b * (t * t)
                result.append(Sample(position: q, segment: t < 0.5 ? (i + n - 1) % n : i))
            }
            var inserts = extra[i].sorted()
            var unique: [Double] = []
            for s in inserts where unique.last.map({ s - $0 > 1e-9 }) ?? true { unique.append(s) }
            inserts = unique
            for s in inserts {
                result.append(Sample(position: p[i] + (next - p[i]) * s, segment: i))
            }
        }
        return result
    }

    /// The length of `v`, 0 for a non-finite vector.
    static func safeLength(_ v: SIMD3<Double>) -> Double {
        let l = length(v)
        return l.isFinite ? l : 0
    }

    /// The crossing weight of each centreline sample: for every crossing mark whose over-strand is the sample's
    /// segment, clamp(2 − d / radius, 0, 1) with d the distance from the sample to ``crossingPoint(_:in:)``; the
    /// largest over all marks; 0 for samples of other segments.
    static func weights(_ samples: [Sample], snapshot: WaveKnotKeeperSceneSnapshot, radius: Double) -> [Double] {
        var marks: [(segment: Int, point: SIMD3<Double>)] = []
        for mark in snapshot.crossings {
            if let x = crossingPoint(mark, in: snapshot) { marks.append((mark.over, x)) }
        }
        return samples.map { sample in
            var w = 0.0
            for m in marks where m.segment == sample.segment {
                let d = length(sample.position - m.point)
                w = max(w, min(max(2 - d / radius, 0), 1))
            }
            return w
        }
    }

    // MARK: Meshes

    /// A unit vector perpendicular to `v` (any; deterministic): `v` crossed with the axis it is least aligned with.
    static func perpendicular(_ v: SIMD3<Double>) -> SIMD3<Double> {
        let ax = abs(v.x), ay = abs(v.y), az = abs(v.z)
        let axis: SIMD3<Double> = ax <= ay && ax <= az ? SIMD3(1, 0, 0) : (ay <= az ? SIMD3(0, 1, 0) : SIMD3(0, 0, 1))
        let p = unit(cross(v, axis))
        return p == .zero ? SIMD3(1, 0, 0) : p
    }

    /// `v` normalized, or zero when its length is zero or not finite.
    static func unit(_ v: SIMD3<Double>) -> SIMD3<Double> {
        let l = length(v)
        return l > 1e-15 && l.isFinite ? v / l : .zero
    }

    /// `v` rotated by `angle` about the unit `axis` (Rodrigues).
    static func rotate(_ v: SIMD3<Double>, about axis: SIMD3<Double>, by angle: Double) -> SIMD3<Double> {
        let c = cos(angle), s = sin(angle)
        return v * c + cross(axis, v) * s + axis * (dot(axis, v) * (1 - c))
    }

    /// `normal` carried from tangent `from` to tangent `to` by the smallest rotation, then made perpendicular to `to`
    /// and unit; any perpendicular of `to` when that degenerates (a reversal).
    static func transport(_ normal: SIMD3<Double>, from: SIMD3<Double>, to: SIMD3<Double>) -> SIMD3<Double> {
        let axis = cross(from, to)
        let s = length(axis), c = dot(from, to)
        var n = normal
        if s > 1e-12 { n = rotate(normal, about: axis / s, by: atan2(s, c)) }
        n = unit(n - to * dot(n, to))
        return n == .zero ? perpendicular(to) : n
    }

    /// The tangents of a closed polyline: the central difference, else the forward difference, else the previous
    /// tangent, else +x.
    static func tangents(_ c: [SIMD3<Double>]) -> [SIMD3<Double>] {
        let m = c.count
        var result: [SIMD3<Double>] = []
        result.reserveCapacity(m)
        for j in 0..<m {
            var t = unit(c[(j + 1) % m] - c[(j + m - 1) % m])
            if t == .zero { t = unit(c[(j + 1) % m] - c[j]) }
            if t == .zero { t = unit(c[j] - c[(j + m - 1) % m]) }
            if t == .zero { t = result.last ?? SIMD3(1, 0, 0) }
            result.append(t)
        }
        return result
    }

    /// Parallel-transport normals around the closed loop of `tangents`, with the closing twist spread evenly: the
    /// first normal is a fixed perpendicular of the first tangent; each next one is the previous carried by the
    /// smallest rotation; the angle θ between the normal carried once more to the first tangent and the first normal
    /// is then added back as θ · j / m about tangent j, so the frames close without a seam.
    static func frames(_ tangents: [SIMD3<Double>]) -> [SIMD3<Double>] {
        let m = tangents.count
        guard m > 0 else { return [] }
        var normals: [SIMD3<Double>] = [perpendicular(tangents[0])]
        normals.reserveCapacity(m)
        for j in 1..<max(m, 1) {
            normals.append(transport(normals[j - 1], from: tangents[j - 1], to: tangents[j]))
        }
        let closing = transport(normals[m - 1], from: tangents[m - 1], to: tangents[0])
        let theta = atan2(dot(cross(closing, normals[0]), tangents[0]), dot(closing, normals[0]))
        guard theta.isFinite else { return normals }
        for j in 0..<m {
            normals[j] = unit(rotate(normals[j], about: tangents[j], by: theta * Double(j) / Double(m)))
            if normals[j] == .zero { normals[j] = perpendicular(tangents[j]) }
        }
        return normals
    }

    /// Adds triangle a, b, c wound so its geometric normal points along `front` (degenerate triangles keep a, b, c).
    static func facing(_ builder: inout MeshBuilder, _ a: UInt32, _ b: UInt32, _ c: UInt32, _ pa: SIMD3<Double>,
                       _ pb: SIMD3<Double>, _ pc: SIMD3<Double>, front: SIMD3<Double>) throws(MeshError) {
        if dot(cross(pb - pa, pc - pa), front) < 0 {
            try builder.triangle(a, c, b)
        } else {
            try builder.triangle(a, b, c)
        }
    }

    /// The rope: a closed tube of `radius` (non-finite or non-positive becomes ``tubeRadius``) along the centreline at
    /// `tier` (see the type's rope vertex stream).
    ///
    /// For the m centreline samples C_j with parallel-transport normals N_j and binormals T_j × N_j, ring j has
    /// `tier.sides` (at least 3) vertices C_j + r (N_j cos φ_k + B_j sin φ_k), φ_k = 2πk / sides, with that unit
    /// direction as normal; a closing ring m repeats ring 0 with uv.y = 1. Vertex j · sides + k is ring j's vertex k,
    /// so the mesh has (m + 1) · sides vertices and 2 · m · sides triangles, each wound to face outwards. uv.x is the
    /// sample's crossing weight: 1 within one tube radius of a crossing point on its over-strand segment, falling
    /// linearly to 0 one radius further, 0 on every other segment. A snapshot with fewer than two points gives an
    /// empty mesh.
    ///
    /// - Throws: `MeshError` from `MeshBuilder` (not expected: about 5,000 vertices at most).
    public static func ropeMesh(_ snapshot: WaveKnotKeeperSceneSnapshot, tier: WaveKnotKeeperTier,
                                radius: Double = tubeRadius) throws(MeshError) -> Mesh {
        let r = radius.isFinite && radius > 0 ? radius : tubeRadius
        let samples = centreline(snapshot, tier: tier)
        let m = samples.count
        var builder = MeshBuilder()
        guard m >= 2 else { return builder.build() }
        let positions = samples.map(\.position)
        let weight = weights(samples, snapshot: snapshot, radius: tubeRadius)
        let tangent = tangents(positions)
        let normal = frames(tangent)
        var cumulative: [Double] = [0]
        cumulative.reserveCapacity(m + 1)
        for j in 0..<m { cumulative.append(cumulative[j] + safeLength(positions[(j + 1) % m] - positions[j])) }
        let total = cumulative[m]
        let sides = max(tier.sides, 3)
        var ids: [UInt32] = []
        ids.reserveCapacity((m + 1) * sides)
        var points: [SIMD3<Double>] = []
        var directions: [SIMD3<Double>] = []
        for j in 0...m {
            let index = j % m
            let u = j == m ? 1 : (total > 0 ? cumulative[j] / total : Double(j) / Double(m))
            let binormal = unit(cross(tangent[index], normal[index]))
            for k in 0..<sides {
                let phi = 2 * Double.pi * Double(k) / Double(sides)
                let d = unit(normal[index] * cos(phi) + binormal * sin(phi))
                let p = positions[index] + d * r
                ids.append(try builder.vertex(vec(p), normal: vec(d), uv: Vec2(weight[index], u)))
                points.append(p)
                directions.append(d)
            }
        }
        for j in 0..<m {
            for k in 0..<sides {
                let k1 = (k + 1) % sides
                let a = j * sides + k, b = j * sides + k1, c = (j + 1) * sides + k, d = (j + 1) * sides + k1
                let out = directions[a] + directions[b] + directions[c] + directions[d]
                try facing(&builder, ids[a], ids[c], ids[b], points[a], points[c], points[b], front: out)
                try facing(&builder, ids[b], ids[c], ids[d], points[b], points[c], points[d], front: out)
            }
        }
        return builder.build()
    }

    /// The radii of the glow shells at `tier`: shell k = 1 … `tier.glowShells` has ``tubeRadius`` × (1 + ``glowStep``
    /// · k) (0.15 and 0.2); empty at `level-2`.
    public static func glowRadii(_ tier: WaveKnotKeeperTier) -> [Double] {
        guard tier.glowShells > 0 else { return [] }
        return (1...tier.glowShells).map { tubeRadius * (1 + glowStep * Double($0)) }
    }

    /// The glow: one ``ropeMesh(_:tier:radius:)`` per radius of ``glowRadii(_:)``, innermost first, in one mesh (each
    /// shell keeps the rope's uv); an empty mesh at `level-2` or with fewer than two points. Drawn additively.
    ///
    /// - Throws: `MeshError` from `MeshBuilder` (not expected).
    public static func glowMesh(_ snapshot: WaveKnotKeeperSceneSnapshot,
                                tier: WaveKnotKeeperTier) throws(MeshError) -> Mesh {
        var result = MeshBuilder().build()
        for radius in glowRadii(tier) {
            let shell = try ropeMesh(snapshot, tier: tier, radius: radius)
            let offset = UInt32(result.positions.count)
            result.positions += shell.positions
            result.normals += shell.normals
            result.uvs += shell.uvs
            result.indices += shell.indices.map { $0 + offset }
        }
        return result
    }

    /// A handle: an icosphere of ``handleRadius`` centred at the origin (the scene translates it to each control
    /// point). `subdivisions` (clamped 0 … 3) splits each face of the icosahedron into four, each new vertex pushed
    /// onto the sphere: 20 · 4^s triangles and 10 · 4^s + 2 vertices (320 and 162 at the default 2). Normals point
    /// outwards; uv = (longitude / 2π + 0.5, latitude / π + 0.5) of the normal; triangles wind counter-clockwise from
    /// outside.
    ///
    /// - Throws: `MeshError` from `MeshBuilder` (not expected).
    public static func handleMesh(subdivisions: Int = 2) throws(MeshError) -> Mesh {
        let s = min(max(subdivisions, 0), 3)
        let g = (1 + 5.0.squareRoot()) / 2
        var vertices: [SIMD3<Double>] = [
            SIMD3(-1, g, 0), SIMD3(1, g, 0), SIMD3(-1, -g, 0), SIMD3(1, -g, 0),
            SIMD3(0, -1, g), SIMD3(0, 1, g), SIMD3(0, -1, -g), SIMD3(0, 1, -g),
            SIMD3(g, 0, -1), SIMD3(g, 0, 1), SIMD3(-g, 0, -1), SIMD3(-g, 0, 1),
        ]
        for i in 0..<vertices.count { vertices[i] = unit(vertices[i]) }
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
                vertices.append(unit(vertices[min(a, b)] + vertices[max(a, b)]))
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
        var builder = MeshBuilder()
        var ids: [UInt32] = []
        var positions: [SIMD3<Double>] = []
        for n in vertices {
            let u = atan2(n.z, n.x) / (2 * Double.pi) + 0.5
            let w = asin(min(max(n.y, -1), 1)) / Double.pi + 0.5
            let p = n * handleRadius
            ids.append(try builder.vertex(vec(p), normal: vec(n), uv: Vec2(u, w)))
            positions.append(p)
        }
        for f in faces {
            let outward = vertices[f[0]] + vertices[f[1]] + vertices[f[2]]
            try facing(&builder, ids[f[0]], ids[f[1]], ids[f[2]], positions[f[0]], positions[f[1]], positions[f[2]],
                       front: outward)
        }
        return builder.build()
    }

    /// A gate: the cube of ``gateBox(_:)`` in world units, 6 faces of 4 vertices each (24 vertices, 12 triangles) with
    /// the face's outward unit normal and uv 0 … 1 across the face (for the shader's edge-distance term), wound
    /// counter-clockwise from outside.
    ///
    /// - Throws: `MeshError` from `MeshBuilder` (not expected).
    public static func gateMesh(_ gate: WaveKnotKeeperGate) throws(MeshError) -> Mesh {
        let box = gateBox(gate)
        let centre = (box.low + box.high) * 0.5, half = (box.high - box.low) * 0.5
        var builder = MeshBuilder()
        for axis in 0..<3 {
            for sign in [-1.0, 1.0] {
                var n = SIMD3<Double>(repeating: 0)
                n[axis] = sign
                var e1 = SIMD3<Double>(repeating: 0), e2 = SIMD3<Double>(repeating: 0)
                e1[(axis + 1) % 3] = 1
                e2[(axis + 2) % 3] = 1
                var corners: [SIMD3<Double>] = []
                var ids: [UInt32] = []
                for (a, b) in [(-1.0, -1.0), (1.0, -1.0), (1.0, 1.0), (-1.0, 1.0)] {
                    let p = centre + (n + e1 * a + e2 * b) * half
                    corners.append(p)
                    ids.append(try builder.vertex(vec(p), normal: vec(n), uv: Vec2((a + 1) / 2, (b + 1) / 2)))
                }
                try facing(&builder, ids[0], ids[1], ids[2], corners[0], corners[1], corners[2], front: n)
                try facing(&builder, ids[0], ids[2], ids[3], corners[0], corners[2], corners[3], front: n)
            }
        }
        return builder.build()
    }

    /// `v` as a `Vec3`.
    static func vec(_ v: SIMD3<Double>) -> Vec3 { Vec3(v.x, v.y, v.z) }

    /// The dot product of `a` and `b`.
    static func dot(_ a: SIMD3<Double>, _ b: SIMD3<Double>) -> Double { (a * b).sum() }

    /// The cross product `a` × `b`.
    static func cross(_ a: SIMD3<Double>, _ b: SIMD3<Double>) -> SIMD3<Double> {
        SIMD3(a.y * b.z - a.z * b.y, a.z * b.x - a.x * b.z, a.x * b.y - a.y * b.x)
    }

    /// The Euclidean length of `v`.
    static func length(_ v: SIMD3<Double>) -> Double { dot(v, v).squareRoot() }
}
