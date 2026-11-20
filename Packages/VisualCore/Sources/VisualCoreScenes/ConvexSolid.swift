// ConvexSolid — feature 212 (R02-F12) T-R02F12-003 (FR-R02F12-001, FR-R02F12-002, FR-R02F12-003, FR-R02F12-004,
// FR-R02F12-008, FR-R02F12-009; research R1–R5). A closed convex polyhedron stored as vertices and convex index
// polygons wound counter-clockwise seen from outside, each with its outward plane. A cut by a plane clips every face
// polygon against both half-spaces (Sutherland & Hodgman, "Reentrant polygon clipping", CACM 17(1), 1974) and closes
// each part with a cap polygon. The tolerance ε = 1e-9 × the bounding-box diagonal: a vertex within ε of the plane is
// on it, crossing points are created once per edge (keyed by the sorted vertex pair) and merged within ε, faces are
// cleaned (`PolygonCleanup`) and a part whose volume is at most ε × diagonal² is a sliver and reported as empty.
// Results are deterministic: vertices are numbered in first-seen order and caps are sorted by angle, ties by index.
import Foundation
import VisualCoreMath

/// The outcome of cutting a convex solid by a plane (see `ConvexSolid.cut(by:)`).
public struct ConvexCutResult: Sendable, Equatable {
    /// The part below the plane (distance ≤ 0), or nil when nothing (or only a sliver) is left there.
    public let kept: ConvexSolid?
    /// The part above the plane (distance ≥ 0), or nil when nothing (or only a sliver) is cut away.
    public let removed: ConvexSolid?
    /// The cap polygon in the plane, counter-clockwise about the plane normal; empty when the plane misses the solid.
    public let cap: [Vec3]
    /// The volume of `kept` (0 when nil).
    public let keptVolume: Double
    /// The volume of `removed` (0 when nil).
    public let removedVolume: Double

    /// A cut result from its parts, cap and volumes.
    public init(kept: ConvexSolid?, removed: ConvexSolid?, cap: [Vec3], keptVolume: Double, removedVolume: Double) {
        self.kept = kept; self.removed = removed; self.cap = cap
        self.keptVolume = keptVolume; self.removedVolume = removedVolume
    }
}

/// A closed convex polyhedron that can be cut by planes into exact convex parts (see the file header).
public struct ConvexSolid: Sendable, Equatable, Codable {
    /// The largest number of vertices of a solid.
    public static let maxVertices = 4_096
    /// The largest number of faces of a solid.
    public static let maxFaces = 1_024
    /// The largest number of corners of one face.
    public static let maxCorners = 256

    /// The vertex positions, numbered in first-seen order.
    public let vertices: [Vec3]
    /// The faces as convex polygons of 3…256 distinct vertex indices, counter-clockwise seen from outside.
    public let faces: [[Int]]
    /// The outward plane of each face (one per face, in face order).
    public let planes: [ClipPlane]
    private let storedDiagonal: Double
    private let storedVolume: Double

    /// The diagonal of the bounding box of the vertices.
    public var diagonal: Double { storedDiagonal }
    /// The tolerance ε = 1e-9 × `diagonal`.
    public var tolerance: Double { 1e-9 * storedDiagonal }
    /// The enclosed volume, Σ p0 · (p1 × p2) / 6 over the fan triangles of every face (as `Mesh.validate` sums it).
    public var volume: Double { storedVolume }

    /// A solid from vertices and faces that are already known to be valid; computes planes, diagonal and volume.
    /// `knownPlanes` may carry, per face, the plane already computed for the same corners in the same order.
    init(validatedVertices vertices: [Vec3], faces: [[Int]], knownPlanes: [ClipPlane?] = []) {
        self.vertices = vertices
        self.faces = faces
        var planes: [ClipPlane] = []
        planes.reserveCapacity(faces.count)
        for (i, face) in faces.enumerated() {
            planes.append(i < knownPlanes.count ? knownPlanes[i] ?? Self.plane(of: face, in: vertices)
                          : Self.plane(of: face, in: vertices))
        }
        self.planes = planes
        storedDiagonal = Self.diagonal(of: vertices)
        storedVolume = Self.volume(of: vertices, faces: faces)
    }

    // MARK: - Makers

    /// The axis-aligned box from `min` to `max`: 8 vertices and 6 quads. Throws `.nonFinite` for a non-finite corner
    /// and `.empty` unless `min` < `max` on every axis.
    public static func box(min: Vec3, max: Vec3) throws(ConvexSolidError) -> ConvexSolid {
        guard min.isFinite else { throw .nonFinite("min") }
        guard max.isFinite else { throw .nonFinite("max") }
        guard min.x < max.x, min.y < max.y, min.z < max.z else { throw .empty }
        var vertices: [Vec3] = []
        for i in 0..<8 {
            vertices.append(Vec3(i & 1 == 0 ? min.x : max.x, i & 2 == 0 ? min.y : max.y, i & 4 == 0 ? min.z : max.z))
        }
        let faces = [[0, 4, 6, 2], [1, 3, 7, 5], [0, 1, 5, 4], [2, 6, 7, 3], [0, 2, 3, 1], [4, 5, 7, 6]]
        return ConvexSolid(validatedVertices: vertices, faces: faces)
    }

    /// The box from `min` to `max` cut by each plane in turn, keeping the part below it. Throws as `box(min:max:)`,
    /// `.empty` when nothing is left and `.tooComplex` when a limit would be exceeded.
    public static func bounded(by planes: [ClipPlane], min: Vec3, max: Vec3) throws(ConvexSolidError) -> ConvexSolid {
        var solid = try box(min: min, max: max)
        for plane in planes {
            guard let kept = try solid.cut(by: plane, keptOnly: true).kept else { throw .empty }
            solid = kept
        }
        return solid
    }

    /// A solid from a closed convex triangle mesh: positions are welded within ε, coplanar triangles (normal within
    /// 1e-9, offset within ε) become one polygon face. Throws `.nonFinite`, `.malformed` (bad indices), `.empty`,
    /// `.notClosed` (an edge not used by exactly two consistently wound triangles), `.notConvex` (a vertex more than
    /// ε above a triangle plane) or `.tooComplex`.
    public init(mesh: Mesh) throws(ConvexSolidError) {
        for p in mesh.positions where !p.isFinite { throw .nonFinite("position") }
        guard mesh.indices.count % 3 == 0, !mesh.indices.isEmpty else { throw .malformed("indices") }
        for i in mesh.indices where Int(i) >= mesh.positions.count { throw .malformed("index") }
        let diagonal = Self.diagonal(of: mesh.positions)
        guard diagonal > 0 else { throw .empty }
        let tol = 1e-9 * diagonal
        let welded = Self.weld(mesh.positions, tolerance: tol)
        // Triangles of welded ids (collapsed ones are skipped) and their planes.
        var triangles: [[Int]] = []
        var normals: [Vec3] = []
        var offsets: [Double] = []
        for t in 0..<(mesh.indices.count / 3) {
            let ids = (0..<3).map { welded[Int(mesh.indices[3 * t + $0])] }
            if ids[0] == ids[1] || ids[1] == ids[2] || ids[0] == ids[2] { continue }
            let p = ids.map { mesh.positions[$0] }
            let n = (p[1] - p[0]).cross(p[2] - p[0])
            guard n.length > 2e-12 * diagonal * diagonal else { throw .degeneratePolygon }
            let unit = n.normalized
            triangles.append(ids); normals.append(unit); offsets.append(unit.dot(p[0]))
        }
        guard !triangles.isEmpty else { throw .empty }
        // Closed: every directed edge exactly once, and its reverse exactly once.
        var directed: [UInt64: Int] = [:]
        for t in triangles {
            for k in 0..<3 { directed[Self.key(t[k], t[(k + 1) % 3]), default: 0] += 1 }
        }
        for t in triangles {
            for k in 0..<3 where directed[Self.key(t[k], t[(k + 1) % 3])] != 1
                || directed[Self.key(t[(k + 1) % 3], t[k])] != 1 { throw .notClosed }
        }
        // Convex: every used vertex on or below every triangle plane.
        var used: [Int] = []
        var seen = Set<Int>()
        for t in triangles { for v in t where seen.insert(v).inserted { used.append(v) } }
        for i in triangles.indices {
            for v in used where normals[i].dot(mesh.positions[v]) - offsets[i] > tol { throw .notConvex }
        }
        // Coplanar groups, in order of first triangle.
        var groupOf = [Int](repeating: -1, count: triangles.count)
        var groupNormals: [Vec3] = [], groupOffsets: [Double] = []
        for i in triangles.indices {
            var found = -1
            for g in groupNormals.indices where (groupNormals[g] - normals[i]).length <= 1e-9
                && abs(groupOffsets[g] - offsets[i]) <= tol { found = g; break }
            if found < 0 {
                found = groupNormals.count
                guard found < Self.maxFaces else { throw .tooComplex("faces") }
                groupNormals.append(normals[i]); groupOffsets.append(offsets[i])
            }
            groupOf[i] = found
        }
        // Each group's boundary loop (directed edges whose reverse is not in the group), chained in order.
        var polygons: [[Int]] = []
        for g in groupNormals.indices {
            var edges: [(Int, Int)] = []
            var inGroup = Set<UInt64>()
            for i in triangles.indices where groupOf[i] == g {
                for k in 0..<3 { inGroup.insert(Self.key(triangles[i][k], triangles[i][(k + 1) % 3])) }
            }
            var next: [Int: Int] = [:]
            for i in triangles.indices where groupOf[i] == g {
                for k in 0..<3 {
                    let a = triangles[i][k], b = triangles[i][(k + 1) % 3]
                    if !inGroup.contains(Self.key(b, a)) {
                        guard next[a] == nil else { throw .notConvex }
                        next[a] = b; edges.append((a, b))
                    }
                }
            }
            guard let start = edges.first?.0 else { throw .notClosed }
            var loop = [start]
            var current = next[start]
            while let c = current, c != start {
                guard loop.count <= edges.count else { throw .notConvex }
                loop.append(c); current = next[c]
            }
            guard current == start, loop.count == edges.count else { throw .notConvex }
            polygons.append(loop)
        }
        let result = Self.finalize(points: mesh.positions, faces: polygons, normals: groupNormals,
                                   isCap: [Bool](repeating: false, count: polygons.count),
                                   dirty: [Bool](repeating: true, count: polygons.count), planes: [], tolerance: tol,
                                   minArea: 1e-12 * diagonal * diagonal)
        try Self.validate(vertices: result.vertices, faces: result.faces)
        self.init(validatedVertices: result.vertices, faces: result.faces)
    }

    // MARK: - Queries

    /// True when `p` is on or below every face plane within the tolerance.
    public func contains(_ p: Vec3) -> Bool {
        let tol = tolerance
        for plane in planes where plane.distance(to: p) > tol { return false }
        return true
    }

    /// A triangle mesh of the solid: every face fanned from its first corner, with the face's own positions, its
    /// plane normal as a flat normal and texture coordinate (0, 0). It validates closed with volume `volume`.
    public func mesh() -> Mesh {
        var m = Mesh(positions: [], normals: [], uvs: [], indices: [])
        for (f, face) in faces.enumerated() {
            let base = UInt32(m.positions.count)
            for v in face {
                m.positions.append(vertices[v]); m.normals.append(planes[f].normal); m.uvs.append(Vec2(0, 0))
            }
            for j in 1..<(face.count - 1) { m.indices += [base, base + UInt32(j), base + UInt32(j + 1)] }
        }
        return m
    }

    // MARK: - Cut

    /// Cuts the solid by `plane` (research R2): the kept part lies below the plane, the removed part above, both
    /// closed, convex and wound outward, with the cap counter-clockwise about the plane normal for the kept part and
    /// reversed for the removed one. A plane that misses keeps (or removes) the solid whole with an empty cap; a side
    /// that would be a sliver (volume ≤ ε × diagonal²) is nil and the other side is the whole solid. Throws
    /// `.tooComplex` when a part would exceed a limit.
    public func cut(by plane: ClipPlane) throws(ConvexSolidError) -> ConvexCutResult {
        try cut(by: plane, keptOnly: false)
    }

    /// The cut; with `keptOnly` the removed part is not built (its volume is the rest of the solid's).
    func cut(by plane: ClipPlane, keptOnly: Bool) throws(ConvexSolidError) -> ConvexCutResult {
        let tol = tolerance
        let count = vertices.count
        var distance = [Double](repeating: 0, count: count)
        var side = [Int](repeating: 0, count: count)
        var anyAbove = false, anyBelow = false
        for i in 0..<count {
            let d = plane.distance(to: vertices[i])
            distance[i] = d
            side[i] = abs(d) <= tol ? 0 : (d > 0 ? 1 : -1)
            if side[i] > 0 { anyAbove = true } else if side[i] < 0 { anyBelow = true }
        }
        let whole = ConvexCutResult(kept: self, removed: nil, cap: [], keptVolume: volume, removedVolume: 0)
        let gone = ConvexCutResult(kept: nil, removed: self, cap: [], keptVolume: 0, removedVolume: volume)
        if !anyAbove { return whole }
        if !anyBelow { return gone }

        // Points: the vertices, then crossing points (one per crossed edge, merged within ε with on-plane points).
        var points = vertices
        var onPlane: [Int] = []
        for i in 0..<count where side[i] == 0 { onPlane.append(i) }
        var edgePoint: [UInt64: Int] = [:]
        func crossing(_ a: Int, _ b: Int) -> Int {
            let lo = Swift.min(a, b), hi = Swift.max(a, b)
            let key = Self.key(lo, hi)
            if let known = edgePoint[key] { return known }
            let t = distance[lo] / (distance[lo] - distance[hi])
            let p = points[lo] + (points[hi] - points[lo]) * t
            var index = -1
            for q in onPlane where (points[q] - p).length <= tol { index = q; break }
            if index < 0 {
                index = points.count
                points.append(p); onPlane.append(index)
            }
            edgePoint[key] = index
            return index
        }
        var keptFaces: [[Int]] = [], keptNormals: [Vec3] = [], keptDirty: [Bool] = [], keptPlanes: [ClipPlane] = []
        var removedFaces: [[Int]] = [], removedNormals: [Vec3] = [], removedDirty: [Bool] = []
        var removedPlanes: [ClipPlane] = []
        for (f, face) in faces.enumerated() {
            var below: [Int] = [], above: [Int] = []
            var belowOff = false, aboveOff = false, crossed = false
            for j in face.indices {
                let a = face[j], b = face[(j + 1) % face.count]
                if side[a] <= 0 { below.append(a); if side[a] < 0 { belowOff = true } }
                if side[a] >= 0 { above.append(a); if side[a] > 0 { aboveOff = true } }
                if side[a] * side[b] < 0 {
                    let c = crossing(a, b)
                    below.append(c); above.append(c); crossed = true
                }
            }
            // A face is dirty (needs cleaning) when it was clipped: it gained a crossing point or lost a corner.
            if belowOff, below.count >= 3 {
                keptFaces.append(below); keptNormals.append(planes[f].normal)
                keptDirty.append(crossed || below.count != face.count); keptPlanes.append(planes[f])
            }
            if !keptOnly, aboveOff, above.count >= 3 {
                removedFaces.append(above); removedNormals.append(planes[f].normal)
                removedDirty.append(crossed || above.count != face.count); removedPlanes.append(planes[f])
            }
        }
        // One cap for both sides (so the two caps are fanned alike): counter-clockwise about +n for the kept part,
        // the same corners reversed after the first for the removed part.
        let isOnPlane = Set(onPlane)
        let minArea = 1e-12 * diagonal * diagonal
        let sliver = tol * diagonal * diagonal
        let capCorners = Self.cap(of: keptFaces + removedFaces, points: points, onPlane: isOnPlane,
                                  normal: plane.normal)
        func part(_ faces: [[Int]], _ normals: [Vec3], _ dirty: [Bool], _ planes: [ClipPlane], cap: [Int]?,
                  capNormal: Vec3)
            -> (solid: ConvexSolid, cap: [Vec3])? {
            guard let cap else { return nil }
            let done = Self.finalize(points: points, faces: faces + [cap], normals: normals + [capNormal],
                                     isCap: [Bool](repeating: false, count: faces.count) + [true],
                                     dirty: dirty + [true], planes: planes.map { $0 } + [nil], tolerance: tol,
                                     minArea: minArea)
            guard done.faces.count >= 4, Self.isClosed(done.faces) else { return nil }
            let solid = ConvexSolid(validatedVertices: done.vertices, faces: done.faces, knownPlanes: done.planes)
            let capCorners = done.isCap.firstIndex(of: true).map { done.faces[$0].map { done.vertices[$0] } } ?? []
            return (solid, capCorners)
        }
        let below = part(keptFaces, keptNormals, keptDirty, keptPlanes, cap: capCorners, capNormal: plane.normal)
        let above = keptOnly ? nil : part(removedFaces, removedNormals, removedDirty, removedPlanes,
                                          cap: capCorners.map { [$0[0]] + $0.dropFirst().reversed() },
                                          capNormal: -plane.normal)
        let keptVolume = below?.solid.volume ?? 0
        let removedVolume = keptOnly ? volume - keptVolume : above?.solid.volume ?? 0
        if keptVolume <= sliver || removedVolume <= sliver || below == nil || (!keptOnly && above == nil) {
            // One side is a sliver (or could not be closed): the plane effectively misses.
            return keptVolume >= removedVolume ? whole : gone
        }
        for p in [below!.solid] + (above.map { [$0.solid] } ?? []) {
            if p.vertices.count > Self.maxVertices { throw .tooComplex("vertices") }
            if p.faces.count > Self.maxFaces { throw .tooComplex("faces") }
            for face in p.faces where face.count > Self.maxCorners { throw .tooComplex("corners") }
        }
        return ConvexCutResult(kept: below!.solid, removed: above?.solid, cap: below!.cap, keptVolume: keptVolume,
                               removedVolume: removedVolume)
    }

    // MARK: - Codable

    private enum CodingKeys: String, CodingKey { case vertices, faces }

    /// Decodes a stored solid and re-validates it (limits, indices, closedness, convexity, volume); a refusal is
    /// `DecodingError.dataCorrupted` whose underlying error is the `ConvexSolidError`.
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let vertices = try c.decode([Vec3].self, forKey: .vertices)
        let faces = try c.decode([[Int]].self, forKey: .faces)
        do { try Self.validate(vertices: vertices, faces: faces) } catch {
            throw DecodingError.dataCorrupted(.init(codingPath: c.codingPath, debugDescription: error.reasonCode,
                                                    underlyingError: error))
        }
        self.init(validatedVertices: vertices, faces: faces)
    }

    /// Encodes the vertices and the faces (the planes, diagonal and volume are recomputed when decoding).
    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(vertices, forKey: .vertices)
        try c.encode(faces, forKey: .faces)
    }

    // MARK: - Internals

    static func key(_ a: Int, _ b: Int) -> UInt64 {
        UInt64(UInt32(truncatingIfNeeded: a)) << 32 | UInt64(UInt32(truncatingIfNeeded: b))
    }

    static func diagonal(of points: [Vec3]) -> Double {
        guard let first = points.first else { return 0 }
        var lo = first, hi = first
        for p in points {
            lo = Vec3(Swift.min(lo.x, p.x), Swift.min(lo.y, p.y), Swift.min(lo.z, p.z))
            hi = Vec3(Swift.max(hi.x, p.x), Swift.max(hi.y, p.y), Swift.max(hi.z, p.z))
        }
        return (hi - lo).length
    }

    static func volume(of vertices: [Vec3], faces: [[Int]]) -> Double {
        var sum = 0.0
        for face in faces {
            let p0 = vertices[face[0]]
            for j in 1..<(face.count - 1) { sum += p0.dot(vertices[face[j]].cross(vertices[face[j + 1]])) }
        }
        return sum / 6
    }

    /// The outward plane of a face: Newell normal, offset the mean of n · p over the corners.
    static func plane(of face: [Int], in vertices: [Vec3]) -> ClipPlane {
        let corners = face.map { vertices[$0] }
        let n = PolygonCleanup.areaVector(corners).normalized
        var sum = 0.0
        for p in corners { sum += n.dot(p) }
        let offset = sum / Double(corners.count)
        return (try? ClipPlane(normal: n, offset: offset)) ?? (try! ClipPlane(normal: Vec3(0, 0, 1), offset: 0))
    }

    /// True when every directed edge appears once and its reverse once (vertex adjacency in flat arrays).
    static func isClosed(_ faces: [[Int]]) -> Bool {
        var count = 0
        for f in faces { for v in f { count = Swift.max(count, v + 1) } }
        var start = [Int](repeating: 0, count: count + 1)
        for f in faces { for v in f { start[v + 1] += 1 } }
        for v in 0..<count { start[v + 1] += start[v] }
        var fill = start
        var target = [Int](repeating: 0, count: start[count])
        for f in faces {
            for k in f.indices {
                let a = f[k]
                target[fill[a]] = f[(k + 1) % f.count]; fill[a] += 1
            }
        }
        return target.withUnsafeBufferPointer { t in
            start.withUnsafeBufferPointer { s in
                var a = 0
                while a < count {
                    var i = s[a]
                    let end = s[a + 1]
                    while i < end {
                        let b = t[i]
                        var j = i + 1
                        while j < end { if t[j] == b { return false }; j += 1 }
                        var reverse = 0
                        j = s[b]
                        let stop = s[b + 1]
                        while j < stop { if t[j] == a { reverse += 1 }; j += 1 }
                        if reverse != 1 { return false }
                        i += 1
                    }
                    a += 1
                }
                return true
            }
        }
    }

    /// Validates a stored or built solid: limits, finite vertices, indices, closedness, face and solid convexity,
    /// positive volume.
    static func validate(vertices: [Vec3], faces: [[Int]]) throws(ConvexSolidError) {
        if vertices.count > maxVertices { throw .tooComplex("vertices") }
        if faces.count > maxFaces { throw .tooComplex("faces") }
        for p in vertices where !p.isFinite { throw .nonFinite("vertex") }
        guard faces.count >= 4, vertices.count >= 4 else { throw .empty }
        var used = [Bool](repeating: false, count: vertices.count)
        for face in faces {
            guard face.count >= 3 else { throw .malformed("face corners") }
            if face.count > maxCorners { throw .tooComplex("corners") }
            for v in face {
                guard v >= 0, v < vertices.count else { throw .malformed("index") }
                used[v] = true
            }
            guard Set(face).count == face.count else { throw .malformed("repeated index") }
        }
        guard !used.contains(false) else { throw .malformed("unused vertex") }
        guard isClosed(faces) else { throw .notClosed }
        let diagonal = diagonal(of: vertices)
        guard diagonal > 0 else { throw .empty }
        let tol = 1e-9 * diagonal
        for face in faces {
            let corners = face.map { vertices[$0] }
            let area = PolygonCleanup.areaVector(corners)
            guard area.length > 0 else { throw .degeneratePolygon }
            let n = area.normalized
            let plane = Self.plane(of: face, in: vertices)
            for p in vertices where plane.distance(to: p) > tol { throw .notConvex }
            for k in corners.indices {
                let a = corners[(k + corners.count - 1) % corners.count], b = corners[k]
                let c = corners[(k + 1) % corners.count]
                let turn = (b - a).cross(c - b).dot(n)
                if turn < 0, (b - a).cross(c - a).length / Swift.max((c - a).length, .leastNormalMagnitude) > tol {
                    throw .notConvex
                }
            }
        }
        guard volume(of: vertices, faces: faces) > 0 else { throw .empty }
    }

    /// Welds positions within `tolerance` (Euclidean) to the lowest-index representative, using a grid of cells.
    static func weld(_ positions: [Vec3], tolerance: Double) -> [Int] {
        struct Cell: Hashable { var x: Int64, y: Int64, z: Int64 }
        let size = Swift.max(tolerance, .leastNormalMagnitude)
        var cells: [Cell: [Int]] = [:]
        var result = Array(positions.indices)
        for (i, p) in positions.enumerated() {
            let cx = Int64((p.x / size).rounded(.down)), cy = Int64((p.y / size).rounded(.down))
            let cz = Int64((p.z / size).rounded(.down))
            var found: Int?
            for dx in Int64(-1)...1 {
                for dy in Int64(-1)...1 {
                    for dz in Int64(-1)...1 {
                        for r in cells[Cell(x: cx + dx, y: cy + dy, z: cz + dz)] ?? []
                        where (positions[r] - p).length <= tolerance && r < (found ?? Int.max) { found = r }
                    }
                }
            }
            if let found { result[i] = found } else { cells[Cell(x: cx, y: cy, z: cz), default: []].append(i) }
        }
        return result
    }

    /// The cap polygon of one side: the on-plane points of its faces, unique, sorted by angle about their centroid
    /// counter-clockwise about `normal` (ties by index). Nil below three points.
    static func cap(of faces: [[Int]], points: [Vec3], onPlane: Set<Int>, normal: Vec3) -> [Int]? {
        var ids: [Int] = []
        var seen = Set<Int>()
        for face in faces { for v in face where onPlane.contains(v) && seen.insert(v).inserted { ids.append(v) } }
        guard ids.count >= 3 else { return nil }
        var centroid = Vec3.zero
        for v in ids { centroid += points[v] }
        centroid = centroid / Double(ids.count)
        let helper = abs(normal.x) < 0.6 ? Vec3(1, 0, 0) : (abs(normal.y) < 0.6 ? Vec3(0, 1, 0) : Vec3(0, 0, 1))
        let u = normal.cross(helper).normalized, w = normal.cross(u)
        let keyed = ids.map { v -> (angle: Double, index: Int) in
            let r = points[v] - centroid
            return (atan2(r.dot(w), r.dot(u)), v)
        }
        return keyed.sorted { $0.angle != $1.angle ? $0.angle < $1.angle : $0.index < $1.index }.map(\.index)
    }

    /// Makes faces consistent and clean (FR-R02F12-004): repeated consecutive indices are removed; a face whose area
    /// is at most `minArea` or that `PolygonCleanup` refuses is contracted to its first corner; a corner that cleanup
    /// removes (repeated or collinear within ε) is removed from both faces when it is used by exactly two (an edge
    /// point), otherwise contracted into its nearer neighbour, so every edge stays shared by two faces. Only `dirty`
    /// faces and faces touching a changed corner are checked. Faces left with fewer than three corners are dropped;
    /// unused points are removed and the rest numbered in first-seen order.
    static func finalize(points: [Vec3], faces input: [[Int]], normals: [Vec3], isCap: [Bool], dirty input2: [Bool],
                         planes: [ClipPlane?], tolerance: Double, minArea: Double)
        -> (vertices: [Vec3], faces: [[Int]], isCap: [Bool], planes: [ClipPlane?]) {
        var rep = Array(points.indices)
        var changedPoint = [Bool](repeating: false, count: points.count)
        func find(_ i: Int) -> Int {
            var i = i
            while rep[i] != i { rep[i] = rep[rep[i]]; i = rep[i] }
            return i
        }
        var removed = [Bool](repeating: false, count: points.count)
        var faces = input, dirty = input2, modified = input2
        var alive = [Bool](repeating: true, count: faces.count)
        func current(_ face: [Int]) -> [Int] {
            var out: [Int] = []
            out.reserveCapacity(face.count)
            for v in face {
                let r = find(v)
                if removed[r] { continue }
                if out.last != r { out.append(r) }
            }
            while out.count > 1, out.first == out.last { out.removeLast() }
            return out
        }
        var stamp = [Int](repeating: 0, count: points.count), stampValue = 0
        func distinct(_ g: [Int]) -> Bool {
            stampValue += 1
            for v in g {
                if stamp[v] == stampValue { return false }
                stamp[v] = stampValue
            }
            return true
        }
        var rounds = 0
        while true {
            // Apply the contractions and removals of the last round to the faces that touch a changed corner.
            for i in faces.indices where alive[i] && (dirty[i] || faces[i].contains { changedPoint[$0] }) {
                let g = current(faces[i])
                if g.count < 3 || !distinct(g) { alive[i] = false; continue }
                if g != faces[i] { faces[i] = g; dirty[i] = true; modified[i] = true }
            }
            var uses: [Int] = []
            for v in changedPoint.indices where changedPoint[v] { changedPoint[v] = false }
            var touched = Set<Int>()
            var changed = false
            for i in faces.indices where alive[i] && dirty[i] {
                let g = faces[i]
                if g.contains(where: { touched.contains($0) }) { continue }
                dirty[i] = false
                let corners = g.map { points[$0] }
                let area = PolygonCleanup.areaVector(corners).length / 2
                let cleaned = area > minArea
                    ? try? PolygonCleanup.clean(corners, normal: normals[i], tolerance: tolerance) : nil
                guard let cleaned else {
                    for v in g.dropFirst() { rep[v] = g[0] }
                    for v in g { changedPoint[v] = true }
                    touched.formUnion(g); changed = true; dirty[i] = true
                    continue
                }
                if cleaned.count == g.count { continue }
                var remaining = cleaned
                for (k, v) in g.enumerated() {
                    if let at = remaining.firstIndex(of: points[v]) { remaining.remove(at: at); continue }
                    let a = g[(k + g.count - 1) % g.count], b = g[(k + 1) % g.count]
                    if uses.isEmpty {
                        uses = [Int](repeating: 0, count: points.count)
                        for j in faces.indices where alive[j] { for w in faces[j] { uses[w] += 1 } }
                    }
                    if uses[v] == 2 {
                        removed[v] = true
                    } else {
                        rep[v] = (points[a] - points[v]).length <= (points[b] - points[v]).length ? a : b
                    }
                    for w in [a, v, b] { changedPoint[w] = true }
                    touched.formUnion([a, v, b])
                    changed = true; dirty[i] = true
                    break
                }
            }
            rounds += 1
            if !changed || rounds > points.count + faces.count + 2 { break }
        }
        // Remove unused points; number the rest in first-seen order.
        var number = [Int](repeating: -1, count: points.count)
        var vertices: [Vec3] = []
        var out: [[Int]] = [], outCap: [Bool] = [], outPlanes: [ClipPlane?] = []
        for i in faces.indices where alive[i] {
            let stale = faces[i].contains { rep[$0] != $0 || removed[$0] }
            let g = stale ? current(faces[i]) : faces[i]
            if stale || modified[i] { guard g.count >= 3, distinct(g) else { continue } }
            out.append(g.map { v in
                if number[v] < 0 { number[v] = vertices.count; vertices.append(points[v]) }
                return number[v]
            })
            outCap.append(isCap[i])
            outPlanes.append(stale || modified[i] || i >= planes.count ? nil : planes[i])
        }
        return (vertices, out, outCap, outPlanes)
    }
}
