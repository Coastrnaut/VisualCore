// PlantShapes — feature 219 (R02-F19) T-R02F19-004 (FR-R02F19-003; SC-R02F19-002; clarification Q3; research R3).
// Closed-form petal, cap and stem meshes built with `MeshBuilder`: exact stated dimensions, normals and texture
// coordinates, valid per `Mesh.validate`, no assets.
import Foundation
import VisualCoreMath

/// A point on a circular arc in the y–z plane that starts at the origin heading +y and turns by `bend` in total over
/// the arc length `length`, towards +z for a positive bend (a straight segment for 0), at arc fraction `t`.
///
/// The closed form `length · t · (sin a / a, 2 sin²(a/2) / a)` with `a = bend · t` keeps the arc length exact and stays
/// finite for bends close to zero.
private func plantArcPoint(length: Double, bend: Double, t: Double) -> (point: Vec3, tangent: Vec3) {
    let a = bend * t
    let s = length * t
    guard a != 0 else { return (Vec3(0, s, 0), Vec3(0, 1, 0)) }
    let half = sin(a / 2)
    return (Vec3(0, s * sin(a) / a, s * 2 * half * half / a), Vec3(0, cos(a), sin(a)))
}

/// The unit sine and cosine of `count` equal steps around a circle, the last entry repeating the first exactly so
/// seam vertices coincide bit for bit.
private func plantRing(_ count: Int) -> [(sine: Double, cosine: Double)] {
    var table: [(sine: Double, cosine: Double)] = []
    for i in 0..<count {
        let phi = 2 * Double.pi * Double(i) / Double(count)
        table.append((sin(phi), cos(phi)))
    }
    table.append(table[0])
    return table
}

/// A curled petal (or leaf): a thin, two-sided blade along a spine of arc length ``length`` from the origin heading
/// +y, bent in the y–z plane by a total ``curl`` towards +z (towards −z for a negative curl), with half-width
/// `width · sin(π t)` along ±x at spine fraction t.
///
/// Each of the ``segments`` + 1 spine rows has 3 points across (−x rim, spine, +x rim). The two sides are separate faces
/// with opposite normals (the sheet normal `x × tangent` on the front, its negation on the back); they share the rim
/// points and the spine points of the two sides lie `0.02 · width · sin(π t)` in front of and behind the spine, so
/// the blade is a thin lens that validates as a closed, consistently wound mesh (two coincident sheets would use every
/// inner edge four times and fail as non-manifold). Rows 0 and n collapse to the two spine ends, joined by fans.
/// Vertex count `6n − 2`, triangle count `8(n − 1)`.
public struct PetalShape: Sendable, Equatable {
    /// Spine arc length ℓ, 0 < ℓ ≤ 100.
    public let length: Double
    /// Largest half-width w (at the middle of the spine), 0 < w ≤ ℓ.
    public let width: Double
    /// Total bend c of the spine in radians, |c| ≤ π; positive bends towards +z.
    public let curl: Double
    /// Number of spine segments n, 2 … 64.
    public let segments: Int

    /// A petal with the given dimensions.
    ///
    /// - Throws: ``PlantError/shapeParameter(_:)`` naming the first parameter (`length`, `width`, `curl`, `segments`)
    ///   outside its range, including NaN.
    public init(length: Double, width: Double, curl: Double, segments: Int) throws(PlantError) {
        guard length > 0, length <= 100 else { throw .shapeParameter("length") }
        guard width > 0, width <= length else { throw .shapeParameter("width") }
        guard abs(curl) <= .pi else { throw .shapeParameter("curl") }
        guard (2...64).contains(segments) else { throw .shapeParameter("segments") }
        self.length = length; self.width = width; self.curl = curl; self.segments = segments
    }

    /// The petal mesh: front and back faces with opposite unit normals, texture u across (0 at −x, 1 at +x) and v
    /// along the spine (0 at the base, 1 at the tip); the tip vertex is the analytic arc end.
    ///
    /// - Throws: `.budget` when the mesh would exceed ``MeshBudget/default`` (never for valid parameters).
    public func mesh() throws(MeshError) -> Mesh {
        var builder = MeshBuilder(budget: .default)
        let n = segments
        // rows[i][side] holds the indices across (left, spine, right); side 0 front, 1 back. End rows are one apex.
        var rows: [[[UInt32]]] = []
        for i in 0...n {
            let t = Double(i) / Double(n)
            let (spine, tangent) = plantArcPoint(length: length, bend: curl, t: t)
            let normal = Vec3(0, -tangent.z, tangent.y)  // x × tangent
            var sides: [[UInt32]] = []
            for side in 0..<2 {
                let sign: Double = side == 0 ? 1 : -1
                let faceNormal = normal * sign
                if i == 0 || i == n {
                    sides.append([try builder.vertex(spine, normal: faceNormal, uv: Vec2(0.5, t))])
                    continue
                }
                let half = width * sin(Double.pi * t)
                let thickness = 0.02 * width * sin(Double.pi * t)
                let left = try builder.vertex(spine + Vec3(-half, 0, 0), normal: faceNormal, uv: Vec2(0, t))
                let middle = try builder.vertex(spine + normal * (sign * thickness), normal: faceNormal,
                                                uv: Vec2(0.5, t))
                let right = try builder.vertex(spine + Vec3(half, 0, 0), normal: faceNormal, uv: Vec2(1, t))
                sides.append([left, middle, right])
            }
            rows.append(sides)
        }
        for side in 0..<2 {
            // Front triangles wind counter-clockwise seen from +normal; the back reverses them.
            func face(_ a: UInt32, _ b: UInt32, _ c: UInt32) throws(MeshError) {
                if side == 0 { try builder.triangle(a, b, c) } else { try builder.triangle(a, c, b) }
            }
            let base = rows[0][side][0], tip = rows[n][side][0]
            let first = rows[1][side], last = rows[n - 1][side]
            try face(base, first[2], first[1]); try face(base, first[1], first[0])
            try face(last[0], last[1], tip); try face(last[1], last[2], tip)
            if n > 2 {
                for i in 1..<(n - 1) {
                    let lower = rows[i][side], upper = rows[i + 1][side]
                    for k in 0..<2 {
                        let a = lower[k], b = lower[k + 1], c = upper[k + 1], d = upper[k]
                        try face(a, b, c); try face(a, c, d)
                    }
                }
            }
        }
        return builder.build()
    }
}

/// A mushroom-style cap: a closed surface of revolution about +y with an elliptic dome
/// `y = height · √(1 − (r/radius)²)` from the apex (r = 0, y = ``height``) to the edge (r = ``radius``, y = 0), a
/// vertical rim band from y = 0 down to y = −``rim`` (none when the rim is 0) and a flat underside disc at y = −rim.
///
/// Dome rings are spaced evenly in the elliptic angle; each ring and the rim band have ``sides`` + 1 vertices (the
/// seam is duplicated with texture u = 0 and 1), the underside ``sides`` + 1 (ring plus centre). Vertex count
/// `(k + 1)(s + 1) + (rim > 0 ? 2(s + 1) : 0) + s + 1`, triangle count `s(2k − 1) + (rim > 0 ? 2s : 0) + s`.
public struct CapShape: Sendable, Equatable {
    /// Radius R of the cap edge, 0 < R ≤ 100.
    public let radius: Double
    /// Height h of the apex above the edge, 0 < h ≤ 100.
    public let height: Double
    /// Depth d of the rim band below the edge, 0 ≤ d < h.
    public let rim: Double
    /// Number of sides s around the axis, 8 … 128.
    public let sides: Int
    /// Number of dome rings k from apex to edge, 2 … 64.
    public let rings: Int

    /// A cap with the given dimensions.
    ///
    /// - Throws: ``PlantError/shapeParameter(_:)`` naming the first parameter (`radius`, `height`, `rim`, `sides`,
    ///   `rings`) outside its range, including NaN.
    public init(radius: Double, height: Double, rim: Double, sides: Int, rings: Int) throws(PlantError) {
        guard radius > 0, radius <= 100 else { throw .shapeParameter("radius") }
        guard height > 0, height <= 100 else { throw .shapeParameter("height") }
        guard rim >= 0, rim < height else { throw .shapeParameter("rim") }
        guard (8...128).contains(sides) else { throw .shapeParameter("sides") }
        guard (2...64).contains(rings) else { throw .shapeParameter("rings") }
        self.radius = radius; self.height = height; self.rim = rim; self.sides = sides; self.rings = rings
    }

    /// The closed cap mesh with outward unit normals: dome texture v 0 … 0.5 (apex to edge), rim band 0.55 … 0.75,
    /// underside mapped planar into the unit square.
    ///
    /// - Throws: `.budget` when the mesh would exceed ``MeshBudget/default`` (never for valid parameters).
    public func mesh() throws(MeshError) -> Mesh {
        var builder = MeshBuilder(budget: .default)
        let s = sides, k = rings
        let ring = plantRing(s)
        // Rows from the top down; each row has s + 1 vertices (the dome apex row repeats the apex per column).
        var rowsOut: [[UInt32]] = []
        for j in 0...k {
            let alpha = Double.pi / 2 * Double(j) / Double(k)
            let r = j == k ? radius : radius * sin(alpha)
            let y = j == k ? 0 : height * cos(alpha)
            let radial = j == k ? 1 : sin(alpha), axial = j == k ? 0 : cos(alpha)
            var row: [UInt32] = []
            for i in 0...s {
                let (sine, cosine) = ring[i]
                let normal = Vec3(radial / radius * sine, axial / height, radial / radius * cosine).normalized
                row.append(try builder.vertex(Vec3(r * sine, y, r * cosine), normal: normal,
                                              uv: Vec2(Double(i) / Double(s), 0.5 * Double(j) / Double(k))))
            }
            rowsOut.append(row)
        }
        for j in 0..<k {
            let upper = rowsOut[j], lower = rowsOut[j + 1]
            for i in 0..<s {
                let a = upper[i], b = upper[i + 1], c = lower[i], d = lower[i + 1]
                try builder.triangle(a, c, d)
                if j != 0 { try builder.triangle(a, d, b) }
            }
        }
        if rim > 0 {
            var top: [UInt32] = [], bottom: [UInt32] = []
            for i in 0...s {
                let (sine, cosine) = ring[i]
                let normal = Vec3(sine, 0, cosine)
                let u = Double(i) / Double(s)
                top.append(try builder.vertex(Vec3(radius * sine, 0, radius * cosine), normal: normal,
                                              uv: Vec2(u, 0.55)))
                bottom.append(try builder.vertex(Vec3(radius * sine, -rim, radius * cosine), normal: normal,
                                                 uv: Vec2(u, 0.75)))
            }
            for i in 0..<s {
                try builder.triangle(top[i], bottom[i], bottom[i + 1])
                try builder.triangle(top[i], bottom[i + 1], top[i + 1])
            }
        }
        let down = Vec3(0, -1, 0)
        let centre = try builder.vertex(Vec3(0, -rim, 0), normal: down, uv: Vec2(0.5, 0.5))
        var disc: [UInt32] = []
        for i in 0...s {
            let (sine, cosine) = ring[i]
            disc.append(try builder.vertex(Vec3(radius * sine, -rim, radius * cosine), normal: down,
                                           uv: Vec2(0.5 + 0.5 * sine, 0.5 + 0.5 * cosine)))
        }
        for i in 0..<s { try builder.triangle(centre, disc[i + 1], disc[i]) }
        return builder.build()
    }
}

/// A stem: a closed tapered tube along a spine of arc length ``length`` from the origin heading +y, bent by a total
/// ``bend`` in the y–z plane towards +z (towards −z for a negative bend), with radius falling linearly from
/// ``baseRadius`` to ``tipRadius`` along the arc and flat end caps.
///
/// The ``segments`` + 1 rings lie in planes perpendicular to the spine; each has ``sides`` + 1 vertices (the seam is
/// duplicated with texture u = 0 and 1), each cap ``sides`` + 1 (ring plus centre). Vertex count
/// `(m + 1)(s + 1) + 2(s + 1)`, triangle count `2sm + 2s`.
public struct StemShape: Sendable, Equatable {
    /// Spine arc length L, 0 < L ≤ 100.
    public let length: Double
    /// Radius r₀ at the base, finite and r₀ ≥ r₁.
    public let baseRadius: Double
    /// Radius r₁ at the tip, 0 < r₁ ≤ r₀.
    public let tipRadius: Double
    /// Total bend b of the spine in radians, |b| ≤ π; positive bends towards +z.
    public let bend: Double
    /// Number of sides s around the spine, 3 … 64.
    public let sides: Int
    /// Number of segments m along the spine, 1 … 64.
    public let segments: Int

    /// A stem with the given dimensions.
    ///
    /// - Throws: ``PlantError/shapeParameter(_:)`` naming the first parameter (`length`, `baseRadius`, `tipRadius`,
    ///   `bend`, `sides`, `segments`) outside its range, including NaN.
    public init(length: Double, baseRadius: Double, tipRadius: Double, bend: Double, sides: Int,
                segments: Int) throws(PlantError) {
        guard length > 0, length <= 100 else { throw .shapeParameter("length") }
        guard baseRadius > 0, baseRadius.isFinite else { throw .shapeParameter("baseRadius") }
        guard tipRadius > 0, tipRadius <= baseRadius else { throw .shapeParameter("tipRadius") }
        guard abs(bend) <= .pi else { throw .shapeParameter("bend") }
        guard (3...64).contains(sides) else { throw .shapeParameter("sides") }
        guard (1...64).contains(segments) else { throw .shapeParameter("segments") }
        self.length = length; self.baseRadius = baseRadius; self.tipRadius = tipRadius; self.bend = bend
        self.sides = sides; self.segments = segments
    }

    /// The closed stem mesh with outward unit normals (walls tilted by the taper, caps ∓ the spine tangent), wall
    /// texture u around and v along the spine, caps mapped planar into the unit square; the tip centre is the analytic
    /// arc end.
    ///
    /// - Throws: `.budget` when the mesh would exceed ``MeshBudget/default`` (never for valid parameters).
    public func mesh() throws(MeshError) -> Mesh {
        var builder = MeshBuilder(budget: .default)
        let s = sides, m = segments
        let ring = plantRing(s)
        let slope = (tipRadius - baseRadius) / length
        var walls: [[UInt32]] = []
        var frames: [(centre: Vec3, tangent: Vec3, across: Vec3, out: Vec3, radius: Double)] = []
        for j in 0...m {
            let t = Double(j) / Double(m)
            let (centre, tangent) = plantArcPoint(length: length, bend: bend, t: t)
            let across = Vec3(1, 0, 0)
            let out = Vec3(0, -tangent.z, tangent.y)  // x × tangent
            let r = j == 0 ? baseRadius : (j == m ? tipRadius : baseRadius + (tipRadius - baseRadius) * t)
            frames.append((centre, tangent, across, out, r))
            var row: [UInt32] = []
            for i in 0...s {
                let (sine, cosine) = ring[i]
                let direction = across * sine + out * cosine
                let normal = (direction - tangent * slope).normalized
                row.append(try builder.vertex(centre + direction * r, normal: normal,
                                              uv: Vec2(Double(i) / Double(s), t)))
            }
            walls.append(row)
        }
        for j in 0..<m {
            let lower = walls[j], upper = walls[j + 1]
            for i in 0..<s {
                let a = lower[i], b = lower[i + 1], c = upper[i], d = upper[i + 1]
                try builder.triangle(a, d, c)
                try builder.triangle(a, b, d)
            }
        }
        for end in [0, m] {
            let frame = frames[end]
            let normal = end == 0 ? frame.tangent * -1 : frame.tangent
            let centre = try builder.vertex(frame.centre, normal: normal, uv: Vec2(0.5, 0.5))
            var disc: [UInt32] = []
            for i in 0...s {
                let (sine, cosine) = ring[i]
                let direction = frame.across * sine + frame.out * cosine
                disc.append(try builder.vertex(frame.centre + direction * frame.radius, normal: normal,
                                               uv: Vec2(0.5 + 0.5 * sine, 0.5 + 0.5 * cosine)))
            }
            for i in 0..<s {
                if end == 0 { try builder.triangle(centre, disc[i + 1], disc[i]) }
                else { try builder.triangle(centre, disc[i], disc[i + 1]) }
            }
        }
        return builder.build()
    }
}
