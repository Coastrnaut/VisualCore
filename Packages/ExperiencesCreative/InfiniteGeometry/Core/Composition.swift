// Composition.swift — feature 040 (A05-P01) T-A05-103 (FR-A05-112, FR-A05-113; spec Clarifications: bounds, 3D).
// Feature 044 (A05-P05) T-A05-504 (FR-A05-501, FR-A05-510): the solid's revolution segments are a parameter (default
// 24, the reference tessellation of `build`), `solidMesh(_:segments:)` builds a drawing-only mesh at a quality tier's
// segment count and `meshSignature(_:segments:)` is the mesh cache key of that mesh.
import Foundation
import VisualCoreMath
import VisualCoreScenes

/// One polygon of a 2D composition, in world coordinates, counter-clockwise.
public struct Polygon2D: Sendable, Equatable {
    /// The vertices, counter-clockwise (mirror images are reversed back to counter-clockwise).
    public var points: [Vec2]
    /// Colour slot 0…5, sampled from the preset's palette by image index (never by the GPU).
    public var colorIndex: Int

    /// Creates a polygon from its vertices and colour slot.
    public init(points: [Vec2], colorIndex: Int) {
        self.points = points
        self.colorIndex = colorIndex
    }
}

/// A built composition: a set of 2D polygons, or one closed 3D mesh (FR-A05-112).
///
/// 2D rules (spec Clarifications): the view is the square −1…1 in both axes divided by `scale`; a polygon is kept when
/// its centroid (vertex mean, which every symmetry operation maps to the image polygon's centroid) lies in the view.
/// - Tilings: the motif's images under `WallpaperLattice.images(of:rings:)` with `rings = repeats`; lattice coordinates
///   are scaled so neighbouring cell centres are `tilingCellSize` (0.4) world units apart, independent of the scale,
///   so a smaller scale shows more cells. The colour slot is the image index within its cell, modulo 6.
/// - Kaleidoscope: the motif's images under `PointGroup.dihedral(order)`, repeated in `repeats` concentric rings, ring
///   `r` (0-based) scaled about the origin by (r + 1) / repeats; world units equal motif units. The colour slot is the
///   image index within the group, modulo 6. At scale ≤ 1 every image is in view (vertex radius ≤ 0.9), so the
///   composition holds exactly 2 · order · repeats polygons.
///
/// Every image polygon is the motif with each vertex mapped through the same symmetry operation: `images(of:)` lists
/// the operations in a fixed order, so the k-th image of every vertex belongs to the k-th operation. The number of
/// polygons is counted from the centroid's images before any polygon is built; more than `maxPolygons` is refused,
/// never truncated.
///
/// 3D rule: `order` copies of the revolved motif profile (24 segments in `build`; `solidMesh(_:segments:)` takes any
/// count for drawing at a lower quality tier, its vertices on the same surfaces of revolution), each translated to
/// radius 1.5 on the z axis and rotated about the vertical axis by 2πk/order, concatenated into one mesh. For order ≥ 2 the profile's radii are
/// scaled (never enlarged) so a petal's radius is at most 0.9 · 1.5 · sin(π/order) and neighbouring petals stay apart
/// (research D3). Each petal is closed, so the whole mesh validates closed; it must fit `MeshBudget.default`.
public enum Composition: Sendable, Equatable {
    /// The polygons of a tiling or kaleidoscope.
    case plane([Polygon2D])
    /// The closed mesh of a 3D composition.
    case solid(Mesh)

    /// The most polygons a 2D composition may hold.
    public static let maxPolygons = 2048
    /// World distance between neighbouring tiling cell centres.
    static let tilingCellSize = 0.4
    /// Distance of each 3D petal from the vertical axis.
    static let petalRadius = 1.5
    /// Revolution segments of each 3D petal in the reference composition (`build`, digest and bounds).
    public static let petalSegments = 24

    /// Builds the composition of `preset` (validated first); deterministic, GPU- and clock-free (FR-A05-113).
    ///
    /// - Throws: `.invalid(code)` for a refused preset (the `PresetError.code`) or an unusable symmetry or mesh input;
    ///   `.budget(count)` when a 2D composition would hold `count` > `maxPolygons` polygons, or a mesh would exceed
    ///   the default mesh budget (`count` is then its vertex count).
    public static func build(_ preset: GeometryPreset) throws(CompositionError) -> Composition {
        let preset = try validate(preset)
        let motif = Motif.make(seed: preset.seed, kind: preset.kind, order: preset.order)
        if preset.kind == .solid { return .solid(try solid(motif, order: preset.order, segments: petalSegments)) }
        let plan = try planePlan(preset, motif: motif)
        guard plan.kept.count <= maxPolygons else { throw .budget(plan.kept.count) }
        return .plane(try planePolygons(plan, motif: motif))
    }

    /// The closed mesh of the 3D composition of `preset` (validated first) with `segments` revolution segments per
    /// petal (FR-A05-501): the drawing-only mesh of a quality tier. At `petalSegments` it equals the mesh of `build`;
    /// at fewer segments its vertices lie on the same petal surfaces, so its bounding sphere lies inside the
    /// reference one. Deterministic and GPU-free.
    ///
    /// - Throws: `.invalid(code)` for a refused preset or a preset that is not `.solid`, or an unusable mesh input;
    ///   `.budget(vertices)` when the mesh would exceed the default mesh budget.
    public static func solidMesh(_ preset: GeometryPreset,
                                 segments: Int = petalSegments) throws(CompositionError) -> Mesh {
        let preset = try validate(preset)
        guard preset.kind == .solid else { throw .invalid("solidMesh needs a solid preset") }
        let motif = Motif.make(seed: preset.seed, kind: preset.kind, order: preset.order)
        return try solid(motif, order: preset.order, segments: segments)
    }

    /// The mesh cache key of `solidMesh(preset, segments:)` (FR-A05-510; data-model "Mesh signature"): the first 8
    /// bytes (little-endian) of the SHA-256 (`StableHash`) of a little-endian byte stream of the tag
    /// `a05.solid-mesh.1`, the kind's raw value (UTF-8, length-prefixed), the order, the repetitions (`Int64`), the
    /// scale's IEEE-754 binary64 bit pattern (−0 written as +0), the motif seed (`UInt64`) and `segments` (`Int64`).
    /// Every value that changes the mesh is part of it; the palette is not (it only colours the mesh).
    public static func meshSignature(_ preset: GeometryPreset, segments: Int) -> UInt64 {
        var bytes: [UInt8] = []
        func put64(_ v: UInt64) {
            for s in stride(from: 0, to: 64, by: 8) { bytes.append(UInt8(truncatingIfNeeded: v >> UInt64(s))) }
        }
        func putText(_ text: String) {
            let utf8 = Array(text.utf8)
            put64(UInt64(utf8.count))
            bytes += utf8
        }
        putText("a05.solid-mesh.1")
        putText(preset.kind.rawValue)
        put64(UInt64(bitPattern: Int64(preset.order)))
        put64(UInt64(bitPattern: Int64(preset.repeats)))
        put64((preset.scale == 0 ? 0.0 : preset.scale).bitPattern)
        put64(preset.seed)
        put64(UInt64(bitPattern: Int64(segments)))
        let digest = StableHash.sha256(bytes)
        var key: UInt64 = 0
        for (index, byte) in digest.prefix(8).enumerated() { key |= UInt64(byte) << UInt64(8 * index) }
        return key
    }

    /// The number of polygons a 2D preset would produce, counted without building any polygon (0 for `solid`).
    static func polygonCount(_ preset: GeometryPreset) throws(CompositionError) -> Int {
        let preset = try validate(preset)
        guard preset.kind != .solid else { return 0 }
        let motif = Motif.make(seed: preset.seed, kind: preset.kind, order: preset.order)
        return try planePlan(preset, motif: motif).kept.count
    }

    /// The SHA-256 content digest as 64 lower-case hexadecimal digits.
    ///
    /// Plane: a little-endian byte stream of the polygon count (`UInt64`), then per polygon its point count
    /// (`UInt64`), every point's x and y as IEEE-754 binary64 bit patterns (−0 written as +0) and its colour slot
    /// (`Int64`). Solid: the mesh's own `digest`.
    public var digest: String {
        switch self {
        case .solid(let mesh):
            return mesh.digest
        case .plane(let polygons):
            var bytes: [UInt8] = []
            func put64(_ v: UInt64) {
                for s in stride(from: 0, to: 64, by: 8) { bytes.append(UInt8(truncatingIfNeeded: v >> UInt64(s))) }
            }
            func putDouble(_ d: Double) { put64((d == 0 ? 0.0 : d).bitPattern) }
            put64(UInt64(polygons.count))
            for polygon in polygons {
                put64(UInt64(polygon.points.count))
                for p in polygon.points { putDouble(p.x); putDouble(p.y) }
                put64(UInt64(bitPattern: Int64(polygon.colorIndex)))
            }
            return StableHash.sha256Hex(bytes)
        }
    }

    /// The number of polygons (plane) or triangles (solid).
    public var elementCount: Int {
        switch self {
        case .plane(let polygons): polygons.count
        case .solid(let mesh): mesh.triangleCount
        }
    }

    // MARK: - 2D

    /// Which images are kept, how each is coloured and scaled, before any polygon is built.
    struct PlanePlan {
        /// Per kept polygon: symmetry image index, ring (kaleidoscope) or 0, and colour slot.
        var kept: [(image: Int, ring: Int, color: Int)]
        /// The symmetry images of a point in the kind's own frame.
        var images: (Vec2) -> [Vec2]
        /// World scale of ring `r`.
        var ringScale: (Int) -> Double
    }

    private static func validate(_ preset: GeometryPreset) throws(CompositionError) -> GeometryPreset {
        do throws(PresetError) { return try preset.validated() } catch { throw .invalid(error.code) }
    }

    private static func planePlan(_ preset: GeometryPreset, motif: Motif) throws(CompositionError) -> PlanePlan {
        let half = 1 / preset.scale
        func inView(_ p: Vec2) -> Bool { abs(p.x) <= half && abs(p.y) <= half }
        let centroid = motif.points.reduce(Vec2.zero, +) / Double(motif.points.count)
        var kept: [(image: Int, ring: Int, color: Int)] = []
        switch preset.kind {
        case .squareTiling, .hexTiling:
            let lattice: WallpaperLattice = preset.kind == .squareTiling ? .square : .hexagonal
            let neighbours = lattice.cellCenters(rings: 1)
            guard neighbours.count > 1 else { throw .invalid("lattice has no neighbouring cell") }
            let spacing = neighbours.dropFirst().map { $0.distance(to: neighbours[0]) }.min() ?? 0
            guard spacing > 0, spacing.isFinite else { throw .invalid("lattice spacing is not positive") }
            let world = tilingCellSize / spacing
            let rings = preset.repeats
            let perCell = lattice.pointGroupImages
            for (k, p) in lattice.images(of: centroid, rings: rings).enumerated() where inView(p * world) {
                kept.append((k, 0, (k % perCell) % 6))
            }
            return PlanePlan(kept: kept, images: { lattice.images(of: $0, rings: rings) }, ringScale: { _ in world })
        case .kaleidoscope:
            let group = PointGroup.dihedral(preset.order)
            let repeats = preset.repeats
            let ringScale: (Int) -> Double = { Double($0 + 1) / Double(repeats) }
            let images = group.images(of: centroid)
            for ring in 0..<repeats {
                for (k, p) in images.enumerated() where inView(p * ringScale(ring)) {
                    kept.append((k, ring, k % 6))
                }
            }
            return PlanePlan(kept: kept, images: { group.images(of: $0) }, ringScale: ringScale)
        case .solid:
            return PlanePlan(kept: [], images: { [$0] }, ringScale: { _ in 1 })
        }
    }

    private static func planePolygons(_ plan: PlanePlan, motif: Motif) throws(CompositionError) -> [Polygon2D] {
        let vertexImages = motif.points.map(plan.images)
        let imageCount = plan.kept.map { $0.image }.max().map { $0 + 1 } ?? 0
        guard vertexImages.allSatisfy({ $0.count >= imageCount && $0.count == vertexImages[0].count }) else {
            throw .invalid("symmetry images differ in count between motif vertices")
        }
        return plan.kept.map { entry in
            let s = plan.ringScale(entry.ring)
            var points = vertexImages.map { $0[entry.image] * s }
            if signedArea(points) < 0 { points.reverse() }
            return Polygon2D(points: points, colorIndex: entry.color)
        }
    }

    private static func signedArea(_ points: [Vec2]) -> Double {
        var sum = 0.0
        for k in points.indices { sum += points[k].cross(points[(k + 1) % points.count]) }
        return sum / 2
    }

    // MARK: - 3D

    private static func solid(_ motif: Motif, order: Int, segments: Int) throws(CompositionError) -> Mesh {
        var profile = motif.points
        if order >= 2, let widest = profile.map(\.x).max(), widest > 0 {
            let limit = 0.9 * petalRadius * sin(Double.pi / Double(order))
            let factor = min(1, limit / widest)
            profile = profile.map { Vec2($0.x * factor, $0.y) }
        }
        let petal: Mesh
        do throws(MeshError) {
            petal = try Mesh.revolution(profile: profile, segments: segments)
        } catch {
            switch error {
            case .budget(let vertices, _, _): throw .budget(vertices)
            case .invalidInput(let reason): throw .invalid(reason)
            }
        }
        let budget = MeshBudget.default
        let vertices = petal.positions.count * order, indices = petal.indices.count * order
        guard vertices <= budget.maxVertices, indices <= budget.maxIndices else { throw .budget(vertices) }
        var mesh = petal
        mesh.positions = []; mesh.normals = []; mesh.uvs = []; mesh.indices = []
        mesh.positions.reserveCapacity(vertices); mesh.normals.reserveCapacity(vertices)
        mesh.uvs.reserveCapacity(vertices); mesh.indices.reserveCapacity(indices)
        for k in 0..<order {
            let phi = 2 * Double.pi * Double(k) / Double(order)
            let c = cos(phi), s = sin(phi)
            func rotate(_ v: Vec3) -> Vec3 { Vec3(v.x * c + v.z * s, v.y, -v.x * s + v.z * c) }
            let offset = UInt32(mesh.positions.count)
            mesh.positions += petal.positions.map { rotate($0 + Vec3(0, 0, petalRadius)) }
            mesh.normals += petal.normals.map(rotate)
            mesh.uvs += petal.uvs
            mesh.indices += petal.indices.map { $0 + offset }
        }
        return mesh
    }
}

/// Why a composition could not be built.
public enum CompositionError: Error, Sendable, Equatable {
    /// The composition would hold this many elements, more than allowed (polygons, or mesh vertices).
    case budget(Int)
    /// The preset or a derived input is unusable; the text is a refusal code or names the problem.
    case invalid(String)

    /// The stable refusal code used by the experience controls.
    public var code: String {
        switch self {
        case .budget: "a05.budget"
        case .invalid: "a05.invalid"
        }
    }
}
