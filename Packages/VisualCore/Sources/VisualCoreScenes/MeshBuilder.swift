// MeshBuilder.swift — feature 205 (R02-F05) T-R02F05-002 (FR-R02F05-050, FR-R02F05-051; research D1).
// Collects vertices and triangles, welds equal vertices deterministically and refuses growth beyond a budget.
import VisualCoreMath

/// Size limits of one mesh: the most vertices and indices a builder or validator accepts.
public struct MeshBudget: Sendable, Equatable {
    /// Largest number of vertices allowed (0…`UInt32.max`).
    public var maxVertices: Int
    /// Largest number of triangle-list indices allowed (0…`UInt32.max`).
    public var maxIndices: Int

    /// The default budget: 262,144 vertices and 1,572,864 indices (524,288 triangles).
    public static let `default` = MeshBudget(maxVertices: 262_144, maxIndices: 1_572_864)

    /// A budget with both limits clamped to 0…`UInt32.max` (the 32-bit index range).
    public init(maxVertices: Int, maxIndices: Int) {
        let upper = Int(UInt32.max)
        self.maxVertices = min(max(maxVertices, 0), upper)
        self.maxIndices = min(max(maxIndices, 0), upper)
    }
}

/// Why a mesh could not be built.
public enum MeshError: Error, Sendable, Equatable {
    /// The result would hold `vertices` vertices and `indices` indices, more than `budget` allows.
    case budget(vertices: Int, indices: Int, budget: MeshBudget)
    /// The input itself is unusable; the text names the problem.
    case invalidInput(String)
}

/// Builds a `Mesh` vertex by vertex and triangle by triangle, welding equal vertices.
///
/// Welding (research D1): every component is snapped to a grid and the snapped values form a dictionary key; the first
/// vertex with a key keeps its index, so indices follow insertion order and the result is deterministic. Normals and
/// texture coordinates use the grid step `weldTolerance`. A position component `v` uses the step
/// `weldTolerance × p`, where `p` is the power of two at or above `max(1, |v|)`: a step relative to the magnitude (the
/// clarified tolerance 1e-9 × (1 + magnitude), within a factor of two) that is shared by every value of one binade, so
/// nearby values are snapped consistently. Equal inputs always weld; values just across a grid line or a binade
/// boundary may stay apart. A tolerance that is not finite and positive welds bit-identical components only (with −0
/// equal to +0).
public struct MeshBuilder: Sendable {
    /// The limits this builder enforces.
    public let budget: MeshBudget
    /// The weld grid step for normals and texture coordinates, and the relative step for positions.
    public let weldTolerance: Double
    /// When `true`, only positions form the weld key and the first normal and texture coordinate are kept.
    public let weldPositionsOnly: Bool

    private var positions: [Vec3] = []
    private var normals: [Vec3] = []
    private var uvs: [Vec2] = []
    private var indices: [UInt32] = []
    private var lookup: [WeldKey: UInt32] = [:]

    /// A builder with the given budget and weld settings.
    public init(budget: MeshBudget = .default, weldTolerance: Double = 1e-9, weldPositionsOnly: Bool = false) {
        self.budget = budget
        self.weldTolerance = weldTolerance
        self.weldPositionsOnly = weldPositionsOnly
    }

    /// Number of distinct (welded) vertices so far.
    public var vertexCount: Int { positions.count }
    /// Number of triangle-list indices so far.
    public var indexCount: Int { indices.count }

    /// Adds a vertex, or returns the index of an earlier vertex it welds with.
    ///
    /// Throws `.budget` when a new vertex would exceed `budget.maxVertices`; the builder is then unchanged.
    public mutating func vertex(_ position: Vec3, normal: Vec3, uv: Vec2) throws(MeshError) -> UInt32 {
        let key = weldKey(position, normal, uv)
        if let existing = lookup[key] { return existing }
        guard positions.count < budget.maxVertices else {
            throw .budget(vertices: positions.count + 1, indices: indices.count, budget: budget)
        }
        let index = UInt32(positions.count)
        positions.append(position); normals.append(normal); uvs.append(uv)
        lookup[key] = index
        return index
    }

    /// Adds the triangle `a`, `b`, `c` (counter-clockwise seen from the front).
    ///
    /// Throws `.invalidInput` when an index is not a vertex of this builder and `.budget` when three more indices
    /// would exceed `budget.maxIndices`; the builder is then unchanged.
    public mutating func triangle(_ a: UInt32, _ b: UInt32, _ c: UInt32) throws(MeshError) {
        for i in [a, b, c] where Int(i) >= positions.count {
            throw .invalidInput("triangle index \(i) is out of range (vertex count \(positions.count))")
        }
        guard indices.count + 3 <= budget.maxIndices else {
            throw .budget(vertices: positions.count, indices: indices.count + 3, budget: budget)
        }
        indices += [a, b, c]
    }

    /// The mesh built so far; the builder stays usable.
    public func build() -> Mesh {
        Mesh(positions: positions, normals: normals, uvs: uvs, indices: indices)
    }

    // MARK: - Weld keys

    private struct WeldKey: Hashable {
        var p0: UInt64, p1: UInt64, p2: UInt64
        var n0: UInt64 = 0, n1: UInt64 = 0, n2: UInt64 = 0, u0: UInt64 = 0, u1: UInt64 = 0
    }

    private func weldKey(_ p: Vec3, _ n: Vec3, _ uv: Vec2) -> WeldKey {
        var key = WeldKey(p0: snapPosition(p.x), p1: snapPosition(p.y), p2: snapPosition(p.z))
        if !weldPositionsOnly {
            key.n0 = snap(n.x, step: weldTolerance); key.n1 = snap(n.y, step: weldTolerance)
            key.n2 = snap(n.z, step: weldTolerance)
            key.u0 = snap(uv.x, step: weldTolerance); key.u1 = snap(uv.y, step: weldTolerance)
        }
        return key
    }

    private func snapPosition(_ v: Double) -> UInt64 {
        let m = Swift.max(1, v.magnitude)
        guard m.isFinite else { return snap(v, step: 0) }
        var scale = Double(sign: .plus, exponent: m.exponent, significand: 1)
        if scale < m { scale *= 2 }
        return snap(v, step: weldTolerance * scale)
    }

    /// The bit pattern of `v` snapped to the nearest multiple of `step` (−0 as +0); exact when `step` is unusable.
    private func snap(_ v: Double, step: Double) -> UInt64 {
        var s = v
        if step > 0, step.isFinite, v.isFinite {
            let q = (v / step).rounded() * step
            if q.isFinite { s = q }
        }
        return (s == 0 ? 0.0 : s).bitPattern
    }
}
