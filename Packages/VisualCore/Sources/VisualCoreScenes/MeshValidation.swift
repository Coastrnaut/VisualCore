// MeshValidation.swift — feature 205 (R02-F05) T-R02F05-006 (FR-R02F05-030, FR-R02F05-031, FR-R02F05-032,
// FR-R02F05-070; research D7). Validation is pure, deterministic and never changes the mesh.
import Foundation
import VisualCoreMath

/// One defect found by `Mesh.validate(requireClosed:budget:)`, naming its kind and where it is.
public struct MeshProblem: Sendable, Equatable, Codable {
    /// The kinds of defect the validator reports, in no particular order (report order is discovery order).
    public enum Kind: String, Sendable, Codable, CaseIterable {
        /// An index refers to a vertex that does not exist (`vertex` holds the index value).
        case indexOutOfRange
        /// The index count is not a multiple of three; trailing indices form no triangle.
        case indexCountNotMultipleOfThree
        /// The normal or texture-coordinate array length differs from the position count.
        case arrayLengthMismatch
        /// A triangle's area is at most 1e-12 × the squared bounding-box diagonal.
        case degenerateTriangle
        /// A vertex position has a NaN or infinite component.
        case nonFinitePosition
        /// A vertex normal has a NaN or infinite component.
        case nonFiniteNormal
        /// A texture coordinate has a NaN or infinite component.
        case nonFiniteUV
        /// A finite normal whose length differs from 1 by more than 1e-6.
        case nonUnitNormal
        /// A finite texture coordinate outside 0…1 by more than 1e-9.
        case uvOutOfRange
        /// An edge (of welded vertices) shared by more than two triangles.
        case nonManifoldEdge
        /// An edge used twice in the same direction: its two triangles wind inconsistently.
        case inconsistentWinding
        /// An edge used by one triangle only (a hole); reported only when a closed mesh is required.
        case boundaryEdge
        /// A closed, consistently wound mesh encloses negative volume: its faces point inward.
        case invertedFaces
        /// The vertex or index count exceeds the budget; nothing else is checked.
        case budget
    }

    /// What is wrong.
    public var kind: Kind
    /// The triangle concerned (index into the triangle list), if any.
    public var triangle: Int?
    /// The vertex concerned (index into the vertex arrays, or the out-of-range index value), if any.
    public var vertex: Int?
    /// The edge concerned as two welded vertex ids, smaller first; a welded id is the lowest vertex index at that
    /// position (within the weld tolerance).
    public var edge: [UInt32]?

    /// Creates a problem of `kind` at the given location.
    public init(kind: Kind, triangle: Int? = nil, vertex: Int? = nil, edge: [UInt32]? = nil) {
        self.kind = kind; self.triangle = triangle; self.vertex = vertex; self.edge = edge
    }

    /// One text line naming the kind and the location.
    var line: String {
        var text = kind.rawValue
        if let triangle { text += " triangle \(triangle)" }
        if let vertex { text += " vertex \(vertex)" }
        if let edge { text += " edge " + edge.map(String.init).joined(separator: "-") }
        return text
    }
}

/// Shape facts gathered while validating a mesh.
public struct MeshSummary: Sendable, Equatable, Codable {
    /// Number of vertices (positions, unwelded).
    public var vertices: Int
    /// Number of complete triangles (`indices.count / 3`).
    public var triangles: Int
    /// Number of welded edges used by exactly one triangle.
    public var boundaryEdges: Int
    /// True when the mesh has triangles, no boundary edges and no non-manifold edges.
    public var isClosed: Bool
    /// Smallest corner of the axis-aligned box of the finite positions; nil when there are none.
    public var boundsMin: Vec3?
    /// Largest corner of the axis-aligned box of the finite positions; nil when there are none.
    public var boundsMax: Vec3?
    /// Signed enclosed volume of a closed, consistently wound mesh with finite positions (negative when inverted);
    /// nil otherwise.
    public var volume: Double?

    /// Creates a summary from its parts.
    public init(vertices: Int, triangles: Int, boundaryEdges: Int, isClosed: Bool,
                boundsMin: Vec3?, boundsMax: Vec3?, volume: Double?) {
        self.vertices = vertices; self.triangles = triangles; self.boundaryEdges = boundaryEdges
        self.isClosed = isClosed; self.boundsMin = boundsMin; self.boundsMax = boundsMax; self.volume = volume
    }
}

/// The result of validating a mesh: the first problems in discovery order, a count of the rest, and a summary.
/// Readable as text (`description`) and as structured data (`Codable`).
public struct MeshReport: Sendable, Equatable, Codable, CustomStringConvertible {
    /// Maximum number of problems listed; further problems are only counted in `moreProblems`.
    public static let problemLimit = 100
    /// The first `problemLimit` problems in discovery order (budget, arrays, indices, triangles, edges, vertices,
    /// volume).
    public var problems: [MeshProblem]
    /// Number of problems found beyond `problemLimit`.
    public var moreProblems: Int
    /// Counts, closedness, bounds and volume.
    public var summary: MeshSummary

    /// Creates a report from its parts.
    public init(problems: [MeshProblem], moreProblems: Int, summary: MeshSummary) {
        self.problems = problems; self.moreProblems = moreProblems; self.summary = summary
    }

    /// True when no problem was found.
    public var isValid: Bool { problems.isEmpty && moreProblems == 0 }

    /// One line per listed problem, then one summary line.
    public var description: String {
        var lines = problems.map(\.line)
        let s = summary
        let volume = s.volume.map { "volume \($0)" } ?? "volume none"
        lines.append("summary: \(s.vertices) vertices, \(s.triangles) triangles, \(s.boundaryEdges) boundary edges, "
                     + "\(s.isClosed ? "closed" : "open"), \(volume), \(moreProblems) more problems")
        return lines.joined(separator: "\n")
    }
}

/// Position welding shared by validation and normal generation: vertices whose positions differ by at most
/// 1e-9 × (1 + largest coordinate magnitude) per component share one id, the lowest vertex index at that position.
enum MeshPositionWelding {
    private struct Cell: Hashable { var x: Int64, y: Int64, z: Int64 }

    /// Welded id per vertex (the representative vertex index); non-finite positions keep their own index.
    static func representatives(of positions: [Vec3]) -> [Int] {
        var largest = 0.0
        for p in positions where p.isFinite { largest = max(largest, abs(p.x), abs(p.y), abs(p.z)) }
        let tolerance = 1e-9 * (1 + largest)
        var cells: [Cell: [Int]] = [:]
        var result = Array(positions.indices)
        for (i, p) in positions.enumerated() where p.isFinite {
            let cx = Int64((p.x / tolerance).rounded(.down)), cy = Int64((p.y / tolerance).rounded(.down))
            let cz = Int64((p.z / tolerance).rounded(.down))
            var found: Int?
            for dx in Int64(-1)...1 {
                for dy in Int64(-1)...1 {
                    for dz in Int64(-1)...1 {
                        for r in cells[Cell(x: cx + dx, y: cy + dy, z: cz + dz)] ?? [] {
                            let q = positions[r]
                            if abs(q.x - p.x) <= tolerance, abs(q.y - p.y) <= tolerance, abs(q.z - p.z) <= tolerance,
                               r < (found ?? Int.max) { found = r }
                        }
                    }
                }
            }
            if let found { result[i] = found } else { cells[Cell(x: cx, y: cy, z: cz), default: []].append(i) }
        }
        return result
    }

    /// Axis-aligned box of the finite positions, nil when there are none.
    static func box(of positions: [Vec3]) -> (min: Vec3, max: Vec3)? {
        var box: (min: Vec3, max: Vec3)?
        for p in positions where p.isFinite {
            if let b = box {
                box = (Vec3(min(b.min.x, p.x), min(b.min.y, p.y), min(b.min.z, p.z)),
                       Vec3(max(b.max.x, p.x), max(b.max.y, p.y), max(b.max.z, p.z)))
            } else { box = (p, p) }
        }
        return box
    }

    /// Squared diagonal of the box of the finite positions (0 when there are none).
    static func squaredDiagonal(of positions: [Vec3]) -> Double {
        guard let b = box(of: positions) else { return 0 }
        let d = b.max - b.min
        return d.dot(d)
    }
}

/// Collects the first `MeshReport.problemLimit` problems and counts the rest.
private struct ProblemCollector {
    var problems: [MeshProblem] = []
    var more = 0
    mutating func add(_ kind: MeshProblem.Kind, triangle: Int? = nil, vertex: Int? = nil, edge: [UInt32]? = nil) {
        if problems.count < MeshReport.problemLimit {
            problems.append(MeshProblem(kind: kind, triangle: triangle, vertex: vertex, edge: edge))
        } else { more += 1 }
    }
}

extension Mesh {
    /// Validates the mesh without changing it (research D7 order): budget (on failure nothing else is checked) →
    /// array lengths → index count → index range → triangles (finite positions, degenerate area) → edges of the
    /// position-welded topology (non-manifold, inconsistent winding, boundary when `requireClosed`) → vertices
    /// (normals, texture coordinates, unreferenced non-finite positions) → inward faces by signed volume (closed,
    /// consistently wound meshes only). Lists the first 100 problems in that order and counts the rest.
    public func validate(requireClosed: Bool = false, budget: MeshBudget = .default) -> MeshReport {
        var collector = ProblemCollector()
        let vertexCount = positions.count
        let triangleCount = indices.count / 3
        let box = MeshPositionWelding.box(of: positions)
        func report(boundary: Int, closed: Bool, volume: Double?) -> MeshReport {
            MeshReport(problems: collector.problems, moreProblems: collector.more,
                       summary: MeshSummary(vertices: vertexCount, triangles: triangleCount, boundaryEdges: boundary,
                                            isClosed: closed, boundsMin: box?.min, boundsMax: box?.max,
                                            volume: volume))
        }

        // Budget: a mesh over budget is refused before any per-element work.
        if vertexCount > budget.maxVertices || indices.count > budget.maxIndices {
            collector.add(.budget)
            return report(boundary: 0, closed: false, volume: nil)
        }
        // Arrays and counts.
        if normals.count != vertexCount { collector.add(.arrayLengthMismatch) }
        if uvs.count != vertexCount { collector.add(.arrayLengthMismatch) }
        if indices.count % 3 != 0 { collector.add(.indexCountNotMultipleOfThree) }
        // Indices.
        var usable = [Bool](repeating: true, count: triangleCount)
        for (k, index) in indices.enumerated() where Int(index) >= vertexCount {
            collector.add(.indexOutOfRange, triangle: k / 3, vertex: Int(index))
            if k / 3 < triangleCount { usable[k / 3] = false }
        }
        // Triangles.
        let degenerateArea = 1e-12 * MeshPositionWelding.squaredDiagonal(of: positions)
        let welded = MeshPositionWelding.representatives(of: positions)
        var reportedPosition = Set<Int>()
        var allFinite = true
        var topology: [(triangle: Int, corners: [Int])] = []
        for t in 0..<triangleCount where usable[t] {
            let corners = [Int(indices[3 * t]), Int(indices[3 * t + 1]), Int(indices[3 * t + 2])]
            var finite = true
            for v in corners where !positions[v].isFinite {
                finite = false; allFinite = false
                if reportedPosition.insert(v).inserted { collector.add(.nonFinitePosition, triangle: t, vertex: v) }
            }
            if finite {
                let p0 = positions[corners[0]]
                let area = 0.5 * (positions[corners[1]] - p0).cross(positions[corners[2]] - p0).length
                if area <= degenerateArea { collector.add(.degenerateTriangle, triangle: t) }
            }
            let ids = corners.map { welded[$0] }
            if ids[0] != ids[1], ids[1] != ids[2], ids[0] != ids[2] { topology.append((t, corners)) }
        }
        // Edges of the welded topology, in order of first use.
        var edgeOrder: [UInt64] = []
        var edgeTriangles: [UInt64: [Int]] = [:]
        var edgeForward: [UInt64: Int] = [:]
        for entry in topology {
            for k in 0..<3 {
                let u = welded[entry.corners[k]], v = welded[entry.corners[(k + 1) % 3]]
                let key = UInt64(min(u, v)) << 32 | UInt64(max(u, v))
                if edgeTriangles[key] == nil { edgeOrder.append(key) }
                edgeTriangles[key, default: []].append(entry.triangle)
                if u < v { edgeForward[key, default: 0] += 1 }
            }
        }
        var boundary = 0, manifold = true, consistent = true
        for key in edgeOrder {
            let users = edgeTriangles[key] ?? []
            let edge = [UInt32(key >> 32), UInt32(key & 0xFFFF_FFFF)]
            switch users.count {
            case 1:
                boundary += 1
                if requireClosed { collector.add(.boundaryEdge, triangle: users[0], edge: edge) }
            case 2:
                if edgeForward[key, default: 0] != 1 {
                    consistent = false
                    collector.add(.inconsistentWinding, triangle: users[1], edge: edge)
                }
            default:
                manifold = false
                collector.add(.nonManifoldEdge, triangle: users[2], edge: edge)
            }
        }
        // Vertices.
        for v in 0..<vertexCount {
            if !positions[v].isFinite, reportedPosition.insert(v).inserted {
                allFinite = false
                collector.add(.nonFinitePosition, vertex: v)
            }
            if v < normals.count {
                let n = normals[v]
                if !n.isFinite { collector.add(.nonFiniteNormal, vertex: v) }
                else if abs(n.length - 1) > 1e-6 { collector.add(.nonUnitNormal, vertex: v) }
            }
            if v < uvs.count {
                let uv = uvs[v]
                if !uv.isFinite { collector.add(.nonFiniteUV, vertex: v) }
                else if uv.x < -1e-9 || uv.x > 1 + 1e-9 || uv.y < -1e-9 || uv.y > 1 + 1e-9 {
                    collector.add(.uvOutOfRange, vertex: v)
                }
            }
        }
        // Volume of a closed, consistently wound mesh.
        let closed = !topology.isEmpty && boundary == 0 && manifold
        var volume: Double?
        if closed, consistent, allFinite {
            var sum = 0.0
            for entry in topology {
                let p = entry.corners.map { positions[$0] }
                sum += p[0].dot(p[1].cross(p[2]))
            }
            volume = sum / 6
            if sum < 0 { collector.add(.invertedFaces) }
        }
        return report(boundary: boundary, closed: closed, volume: volume)
    }
}
