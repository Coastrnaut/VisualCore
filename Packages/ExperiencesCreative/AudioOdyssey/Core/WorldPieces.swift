// WorldPieces — feature 054 (A07-P01) T-A07-103 (FR-A07-110, FR-A07-111; SC-A07-104; clarification 4; research D5).
// The geometry of the three worlds as consecutive pieces of 8 units of rail each. A piece is a pure function of
// (world, index, rail, seed): every vertex is built in rail space from the unwrapped distance d = index · 8 + t and a
// lateral offset or angle, then placed with `rail.pose(at: d)` (which wraps continuously at the loop). Seeded detail
// depends only on (seed, d, lateral or angle), never on the piece index, so the last ring (row) of piece i and the first
// ring (row) of piece i + 1 are computed from bitwise identical inputs and are identical: the joins are watertight.
//
// Vertex layouts (vertices are added in this order and never welded, see `edgeVertexRanges`):
//   - Tunnel: 9 rings × 24 sides, ring-major; vertex (ring j, side k) is j · 24 + k; ring j sits at d = index · 8 + j.
//   - Landscape: 9 rows × 33 columns, row-major; vertex (row j, column c) is j · 33 + c; row j at d = index · 8 + j;
//     column c at lateral −12 + 24 · c / 32 (along the rail's right axis), 2 units below the rail on its up axis.
//   - Star corridor: 48 octahedra of 24 vertices (flat faces), then 4 guide rings of 24 vertices; its join rule is that
//     every star belongs to exactly one piece by its distance (`starDistances`).
import Foundation
import VisualCoreMath
import VisualCoreScenes
import VisualCoreSimulation

/// Generates the world pieces of Audio Odyssey.
public enum WorldPieces {
    /// The rail length one piece covers, in units.
    public static let pieceLength = 8.0
    /// The most vertices one piece may hold.
    public static let vertexBudget = 4_096
    /// The pieces drawn behind the camera's piece.
    public static let windowBehind = 2
    /// The pieces drawn ahead of the camera's piece.
    public static let windowAhead = 8
    /// The drawn window around the camera's piece: 2 behind and 8 ahead.
    public static let window: (behind: Int, ahead: Int) = (windowBehind, windowAhead)

    /// Rings (tunnel) or rows (landscape) per piece, both edges included.
    public static let ringsPerPiece = 9
    /// The sides of the tunnel tube.
    public static let tunnelSides = 24
    /// The mean tunnel radius, in units.
    public static let tunnelRadius = 3.0
    /// The largest relative ripple of the tunnel radius (±8 %).
    public static let tunnelRipple = 0.08
    /// The columns of the landscape strip, both edges included.
    public static let landscapeColumns = 33
    /// The width of the landscape strip, in units, centred under the rail.
    public static let landscapeWidth = 24.0
    /// How far the landscape lies below the rail on its up axis, in units.
    public static let landscapeDrop = 2.0
    /// The stars per piece.
    public static let starsPerPiece = 48
    /// The distance from a star's centre to each of its six corners, in units.
    public static let starSize = 0.08
    /// The radii from the rail at which star centres are placed, in units.
    public static let starRadii: ClosedRange<Double> = 1.5...6
    /// The guide rings per piece.
    public static let guideRingsPerPiece = 4
    /// The sides of a guide ring.
    public static let guideRingSides = 12
    /// The outer radius of a guide ring, in units.
    public static let guideRingRadius = 6.0
    /// The radial width of a guide ring, in units.
    public static let guideRingWidth = 0.1

    /// The index of the piece that holds the unwrapped `distance` (non-finite or negative distances count as 0).
    public static func pieceIndex(of distance: Double) -> Int {
        guard distance.isFinite, distance > 0 else { return 0 }
        return Int(min(distance, 1e15) / pieceLength)
    }

    /// The piece indices to draw around the unwrapped `distance`: 2 behind and 8 ahead of its piece, never below 0.
    public static func indices(around distance: Double) -> ClosedRange<Int> {
        let current = pieceIndex(of: distance)
        return max(0, current - windowBehind)...(current + windowAhead)
    }

    /// The vertex index ranges of a piece's first and last ring (tunnel) or row (landscape); nil for the star
    /// corridor, whose pieces join by star ownership instead.
    public static func edgeVertexRanges(_ world: JourneyWorld) -> (start: Range<Int>, end: Range<Int>)? {
        let width: Int
        switch world {
        case .tunnel: width = tunnelSides
        case .landscape: width = landscapeColumns
        case .starCorridor: return nil
        }
        return (0..<width, (ringsPerPiece - 1) * width..<ringsPerPiece * width)
    }

    /// The piece `index` (negative counts as 0) of `world` along `rail` for `seed`, at most `vertexBudget` vertices.
    public static func piece(_ world: JourneyWorld, index: Int, rail: CameraRail, seed: UInt64) -> Mesh {
        let index = max(0, index)
        var draft = PieceDraft()
        switch world {
        case .tunnel: buildTunnel(&draft, index: index, rail: rail, seed: seed)
        case .landscape: buildLandscape(&draft, index: index, rail: rail, seed: seed)
        case .starCorridor: buildStars(&draft, index: index, rail: rail, seed: seed)
        }
        return draft.build()
    }

    /// The unwrapped distances of the star centres of piece `index` (negative counts as 0), in star order; each lies in
    /// `index · pieceLength ..< (index + 1) · pieceLength`.
    public static func starDistances(index: Int, seed: UInt64) -> [Double] {
        let index = max(0, index)
        return (0..<starsPerPiece).map { starPlacement(seed: seed, index: index, star: $0).distance }
    }

    // MARK: - Tunnel

    /// The unwrapped distance of ring (row) `j` of piece `index`; ring 8 of piece i equals ring 0 of piece i + 1 exactly.
    static func ringDistance(index: Int, ring j: Int) -> Double {
        Double(index) * pieceLength + Double(j) * pieceLength / Double(ringsPerPiece - 1)
    }

    /// The tunnel radius at unwrapped distance `d` and angle `angle`: 3 · (1 + 0.08 · f), f in −1…1 periodic in angle.
    static func tunnelRadius(seed: UInt64, distance d: Double, angle: Double) -> Double {
        let phase1 = 2 * Double.pi * unit(hash(seed, 1, 0)), phase2 = 2 * Double.pi * unit(hash(seed, 2, 0))
        let f = 0.6 * sin(3 * angle + 0.31 * d + phase1) + 0.4 * sin(5 * angle - 0.17 * d + phase2)
        return tunnelRadius * (1 + tunnelRipple * f)
    }

    private static func buildTunnel(_ draft: inout PieceDraft, index: Int, rail: CameraRail, seed: UInt64) {
        let sides = tunnelSides
        for j in 0..<ringsPerPiece {
            let d = ringDistance(index: index, ring: j)
            let pose = rail.pose(at: d)
            for k in 0..<sides {
                let angle = 2 * Double.pi * Double(k) / Double(sides)
                let radial = pose.right * cos(angle) + pose.up * sin(angle)
                let r = tunnelRadius(seed: seed, distance: d, angle: angle)
                draft.vertex(pose.position + radial * r, normal: -radial,
                             uv: Vec2(Double(k) / Double(sides), Double(j) / Double(ringsPerPiece - 1)))
            }
        }
        for j in 0..<(ringsPerPiece - 1) {
            for k in 0..<sides {
                let a = j * sides + k, b = j * sides + (k + 1) % sides
                draft.quad(a, b, a + sides, b + sides, facing: draft.normals[a])   // seen from inside the tube
            }
        }
    }

    // MARK: - Landscape

    /// The terrain height above the strip's base at unwrapped distance `d` and lateral offset `lateral`; low under the
    /// rail (≤ 0.35) and rising toward the sides (≤ 3.15), so the camera always clears it.
    static func landscapeHeight(seed: UInt64, distance d: Double, lateral: Double) -> Double {
        let side = min(1, abs(lateral) / (landscapeWidth / 2))
        let broad = valueNoise(seed, d / 9, lateral / 6)
        let fine = valueNoise(seed ^ 0xA076_1D64_78BD_642F, d / 3.5, lateral / 2.5)
        return 0.35 * broad + side * side * (2.2 * broad + 0.6 * fine)
    }

    private static func buildLandscape(_ draft: inout PieceDraft, index: Int, rail: CameraRail, seed: UInt64) {
        let cols = landscapeColumns, eps = 0.01
        for j in 0..<ringsPerPiece {
            let d = ringDistance(index: index, ring: j)
            let pose = rail.pose(at: d)
            for c in 0..<cols {
                let lateral = -landscapeWidth / 2 + landscapeWidth * Double(c) / Double(cols - 1)
                let h = landscapeHeight(seed: seed, distance: d, lateral: lateral)
                let dl = (landscapeHeight(seed: seed, distance: d, lateral: lateral + eps)
                    - landscapeHeight(seed: seed, distance: d, lateral: lateral - eps)) / (2 * eps)
                let dd = (landscapeHeight(seed: seed, distance: d + eps, lateral: lateral)
                    - landscapeHeight(seed: seed, distance: d - eps, lateral: lateral)) / (2 * eps)
                let normal = (pose.up - pose.right * dl - pose.direction * dd).normalized
                draft.vertex(pose.position + pose.right * lateral + pose.up * (h - landscapeDrop), normal: normal,
                             uv: Vec2(Double(c) / Double(cols - 1), Double(j) / Double(ringsPerPiece - 1)))
            }
        }
        for j in 0..<(ringsPerPiece - 1) {
            for c in 0..<(cols - 1) {
                let a = j * cols + c
                draft.quad(a, a + 1, a + cols, a + cols + 1, facing: draft.normals[a])   // seen from above
            }
        }
    }

    // MARK: - Star corridor

    /// Where star `star` of piece `index` sits: its unwrapped distance (inside the piece), radius and angle.
    static func starPlacement(seed: UInt64, index: Int, star: Int) -> (distance: Double, radius: Double, angle: Double) {
        var rng = SeededRandom(seed: hash(seed, index, star))
        let start = Double(index) * pieceLength, end = Double(index + 1) * pieceLength
        var d = start + rng.double() * pieceLength
        if d >= end { d = end.nextDown }
        if d < start { d = start }
        let radius = rng.range(starRadii)
        let angle = rng.range(0...(2 * Double.pi))
        return (d, radius, angle)
    }

    private static func buildStars(_ draft: inout PieceDraft, index: Int, rail: CameraRail, seed: UInt64) {
        for k in 0..<starsPerPiece {
            let place = starPlacement(seed: seed, index: index, star: k)
            let pose = rail.pose(at: place.distance)
            let centre = pose.position + (pose.right * cos(place.angle) + pose.up * sin(place.angle)) * place.radius
            let axes = (pose.right * starSize, pose.up * starSize, pose.direction * starSize)
            for sx in [1.0, -1.0] {
                for sy in [1.0, -1.0] {
                    for sz in [1.0, -1.0] {
                        let p = [axes.0 * sx, axes.1 * sy, axes.2 * sz]
                        let n = (p[0] + p[1] + p[2]).normalized
                        let a = draft.vertex(centre + p[0], normal: n, uv: Vec2(0, 0))
                        let b = draft.vertex(centre + p[1], normal: n, uv: Vec2(1, 0))
                        let c = draft.vertex(centre + p[2], normal: n, uv: Vec2(0.5, 1))
                        draft.triangle(a, b, c, facing: n)
                    }
                }
            }
        }
        let sides = guideRingSides
        for m in 0..<guideRingsPerPiece {
            let d = Double(index) * pieceLength + (Double(m) + 0.5) * pieceLength / Double(guideRingsPerPiece)
            let pose = rail.pose(at: d)
            let facing = -pose.direction   // toward the approaching camera
            let base = draft.positions.count
            for s in 0..<sides {
                let angle = 2 * Double.pi * Double(s) / Double(sides)
                let radial = pose.right * cos(angle) + pose.up * sin(angle)
                let u = Double(s) / Double(sides)
                draft.vertex(pose.position + radial * (guideRingRadius - guideRingWidth), normal: facing, uv: Vec2(u, 0))
                draft.vertex(pose.position + radial * guideRingRadius, normal: facing, uv: Vec2(u, 1))
            }
            for s in 0..<sides {
                let inner = base + 2 * s, next = base + 2 * ((s + 1) % sides)
                draft.quad(inner, next, inner + 1, next + 1, facing: facing)
            }
        }
    }

    // MARK: - Hashing and noise (pure functions of their inputs)

    /// SplitMix64 finaliser of `z`.
    static func mix(_ z0: UInt64) -> UInt64 {
        var z = z0 &+ 0x9E37_79B9_7F4A_7C15
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// A 64-bit hash of `seed` and two integers.
    static func hash(_ seed: UInt64, _ a: Int, _ b: Int) -> UInt64 {
        mix(mix(mix(seed) ^ UInt64(bitPattern: Int64(a))) ^ UInt64(bitPattern: Int64(b)))
    }

    /// The top 53 bits of `h` as a value in [0, 1).
    static func unit(_ h: UInt64) -> Double { Double(h >> 11) * 0x1.0p-53 }

    /// Smoothed 2D value noise in [0, 1] on the unit lattice, seeded by `seed`.
    static func valueNoise(_ seed: UInt64, _ x: Double, _ y: Double) -> Double {
        let fx = x.rounded(.down), fy = y.rounded(.down)
        let ix = Int(max(min(fx, 1e15), -1e15)), iy = Int(max(min(fy, 1e15), -1e15))
        let tx = x - fx, ty = y - fy
        let sx = tx * tx * (3 - 2 * tx), sy = ty * ty * (3 - 2 * ty)
        let v00 = unit(hash(seed, ix, iy)), v10 = unit(hash(seed, ix + 1, iy))
        let v01 = unit(hash(seed, ix, iy + 1)), v11 = unit(hash(seed, ix + 1, iy + 1))
        let top = v00 + (v10 - v00) * sx, bottom = v01 + (v11 - v01) * sx
        return top + (bottom - top) * sy
    }
}

/// Collects a piece's vertices and triangles in order, then builds the mesh through `MeshBuilder` without welding
/// (bit-identical vertices only, which the generators never emit), so the documented vertex layout holds.
struct PieceDraft {
    var positions: [Vec3] = []
    var normals: [Vec3] = []
    var uvs: [Vec2] = []
    var triangles: [Int] = []

    /// Appends a vertex and returns its index.
    @discardableResult
    mutating func vertex(_ p: Vec3, normal: Vec3, uv: Vec2) -> Int {
        positions.append(p); normals.append(normal); uvs.append(uv)
        return positions.count - 1
    }

    /// Appends the triangle a, b, c, wound counter-clockwise seen from the side `facing` points to.
    mutating func triangle(_ a: Int, _ b: Int, _ c: Int, facing: Vec3) {
        let face = (positions[b] - positions[a]).cross(positions[c] - positions[a])
        triangles += face.dot(facing) < 0 ? [a, c, b] : [a, b, c]
    }

    /// Appends the quad a (u0 v0), b (u1 v0), c (u0 v1), d (u1 v1) as two triangles facing `facing`.
    mutating func quad(_ a: Int, _ b: Int, _ c: Int, _ d: Int, facing: Vec3) {
        triangle(a, b, d, facing: facing)
        triangle(a, d, c, facing: facing)
    }

    /// The mesh (empty if the budget were ever exceeded, which the fixed layouts rule out).
    func build() -> Mesh {
        var builder = MeshBuilder(budget: MeshBudget(maxVertices: WorldPieces.vertexBudget,
                                                     maxIndices: 6 * WorldPieces.vertexBudget),
                                  weldTolerance: 0)
        do {
            var map: [UInt32] = []
            map.reserveCapacity(positions.count)
            for i in positions.indices {
                map.append(try builder.vertex(positions[i], normal: normals[i], uv: uvs[i]))
            }
            for t in stride(from: 0, to: triangles.count - triangles.count % 3, by: 3) {
                try builder.triangle(map[triangles[t]], map[triangles[t + 1]], map[triangles[t + 2]])
            }
            return builder.build()
        } catch {
            return MeshBuilder().build()
        }
    }
}
