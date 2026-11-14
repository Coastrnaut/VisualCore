// MeshNormals.swift — feature 205 (R02-F05) T-R02F05-007 (FR-R02F05-020, FR-R02F05-021; research D2).
// Normals are generated from the triangles; positions, texture coordinates and winding are kept.
import Foundation
import VisualCoreMath

extension Mesh {
    /// Complete triangles whose three indices are in range, in triangle order.
    private func usableTriangles() -> [[Int]] {
        stride(from: 0, to: indices.count - indices.count % 3, by: 3).compactMap { k in
            let t = [Int(indices[k]), Int(indices[k + 1]), Int(indices[k + 2])]
            return t.allSatisfy({ $0 < positions.count }) ? t : nil
        }
    }

    /// Unnormalized face normal (cross product, twice the area) and its unit direction; the unit is nil for a
    /// degenerate face (area at most 1e-12 × squared bounding-box diagonal, or non-finite).
    private func faceNormals(_ triangles: [[Int]]) -> [(cross: Vec3, unit: Vec3?)] {
        let limit = 2e-12 * MeshPositionWelding.squaredDiagonal(of: positions)
        return triangles.map { t in
            let p0 = positions[t[0]]
            let c = (positions[t[1]] - p0).cross(positions[t[2]] - p0)
            let l = c.length
            return (c, l.isFinite && l > limit ? c / l : nil)
        }
    }

    /// The vertex's old normal when it can be normalized, else +z.
    private func fallbackNormal(_ v: Int) -> Vec3 {
        if v < normals.count, normals[v].isFinite, normals[v].length > 0 { return normals[v].normalized }
        return Vec3(0, 0, 1)
    }

    /// Texture coordinate of input vertex `v` (zero when the array is short).
    private func uv(_ v: Int) -> Vec2 { v < uvs.count ? uvs[v] : .zero }

    /// Smooth vertex normals, area- and angle-weighted (face cross product × corner angle), split at creases.
    ///
    /// Around each position-welded vertex, incident faces join one smoothing group when they share an edge and
    /// their face normals differ by at most `creaseAngle` radians (clamped to 0…π; NaN counts as 0), transitively.
    /// One output vertex is emitted per (input vertex, smoothing group) in input-vertex order, then by the group's
    /// smallest face index; positions and texture coordinates are copied from the input vertex and the indices are
    /// rewritten. Degenerate faces contribute nothing and join the first non-degenerate group of their input vertex;
    /// a vertex with zero accumulated normal keeps its old normal (or +z). An unreferenced vertex is kept once with
    /// its old normal (or +z); triangles with an out-of-range index and trailing indices are dropped.
    public func withSmoothNormals(creaseAngle: Double) -> Mesh {
        let triangles = usableTriangles()
        let faces = faceNormals(triangles)
        let welded = MeshPositionWelding.representatives(of: positions)
        let angle = creaseAngle.isNaN ? 0 : min(max(creaseAngle, 0), Double.pi)
        let cosLimit = cos(angle) - 1e-12

        var incident = [[(face: Int, corner: Int)]](repeating: [], count: positions.count)
        for (f, t) in triangles.enumerated() { for k in 0..<3 { incident[welded[t[k]]].append((f, k)) } }

        var cornerGroup = [Int](repeating: -1, count: triangles.count * 3)
        var groupSum: [Vec3] = []
        var groupFirstFace: [Int] = []
        for list in incident where !list.isEmpty {
            var parent = Array(list.indices)
            func root(_ i: Int) -> Int { var i = i; while parent[i] != i { i = parent[i] }; return i }
            func join(_ a: Int, _ b: Int) {
                let (ra, rb) = (root(a), root(b))
                if ra != rb { parent[max(ra, rb)] = min(ra, rb) }
            }
            let w = welded[triangles[list[0].face][list[0].corner]]
            for i in list.indices {
                let fi = list[i].face
                if let ni = faces[fi].unit {
                    let others = Set(triangles[fi].map { welded[$0] }).subtracting([w])
                    for j in (i + 1)..<list.count {
                        let fj = list[j].face
                        guard fj != fi, let nj = faces[fj].unit, ni.dot(nj) >= cosLimit else { continue }
                        if triangles[fj].contains(where: { others.contains(welded[$0]) }) { join(i, j) }
                    }
                } else {
                    let v = triangles[fi][list[i].corner]
                    if let j = list.indices.first(where: {
                        faces[list[$0].face].unit != nil && triangles[list[$0].face][list[$0].corner] == v
                    }) { join(i, j) }
                }
            }
            var groupOfRoot: [Int: Int] = [:]
            for i in list.indices {
                let r = root(i)
                let g: Int
                if let known = groupOfRoot[r] { g = known } else {
                    g = groupSum.count; groupOfRoot[r] = g
                    groupSum.append(.zero); groupFirstFace.append(list[i].face)
                }
                let (f, k) = list[i]
                cornerGroup[3 * f + k] = g
                guard faces[f].unit != nil else { continue }
                let t = triangles[f]
                let p = positions[t[k]]
                let e1 = positions[t[(k + 1) % 3]] - p, e2 = positions[t[(k + 2) % 3]] - p
                let cornerAngle = atan2(e1.cross(e2).length, e1.dot(e2))
                groupSum[g] += faces[f].cross * cornerAngle
            }
        }

        // Output vertices: input-vertex order, then group order by smallest face index.
        var groupsOfVertex = [[Int]](repeating: [], count: positions.count)
        for (f, t) in triangles.enumerated() {
            for k in 0..<3 where !groupsOfVertex[t[k]].contains(cornerGroup[3 * f + k]) {
                groupsOfVertex[t[k]].append(cornerGroup[3 * f + k])
            }
        }
        var out = Mesh(positions: [], normals: [], uvs: [], indices: [])
        var outIndex: [Int: UInt32] = [:]          // key: group (unique per welded vertex) × vertex count + vertex
        for v in positions.indices {
            if groupsOfVertex[v].isEmpty {                     // unreferenced: kept with its old normal
                out.positions.append(positions[v]); out.normals.append(fallbackNormal(v)); out.uvs.append(uv(v))
            }
            for g in groupsOfVertex[v].sorted(by: { groupFirstFace[$0] < groupFirstFace[$1] }) {
                outIndex[g * positions.count + v] = UInt32(out.positions.count)
                let s = groupSum[g], l = s.length
                out.positions.append(positions[v])
                out.normals.append(l.isFinite && l > 0 ? s / l : fallbackNormal(v))
                out.uvs.append(uv(v))
            }
        }
        for (f, t) in triangles.enumerated() {
            for k in 0..<3 { out.indices.append(outIndex[cornerGroup[3 * f + k] * positions.count + t[k]] ?? 0) }
        }
        return out
    }

    /// Flat normals: one output vertex per triangle corner carrying the unit face normal (positions and texture
    /// coordinates copied, indices 0, 1, 2, …). A degenerate face keeps each corner's old normal (or +z); triangles
    /// with an out-of-range index and trailing indices are dropped.
    public func withFlatNormals() -> Mesh {
        let triangles = usableTriangles()
        let faces = faceNormals(triangles)
        var out = Mesh(positions: [], normals: [], uvs: [], indices: [])
        for (f, t) in triangles.enumerated() {
            for v in t {
                out.indices.append(UInt32(out.positions.count))
                out.positions.append(positions[v])
                out.normals.append(faces[f].unit ?? fallbackNormal(v))
                out.uvs.append(uv(v))
            }
        }
        return out
    }
}
