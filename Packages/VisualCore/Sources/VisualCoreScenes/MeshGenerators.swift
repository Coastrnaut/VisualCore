// MeshGenerators.swift — plane, cube and UV-sphere meshes with normals and UVs (feature 006 T-F516;
// FR-F509, FR-F512; research R8). Triangles are counter-clockwise seen from outside (front faces).
import Foundation
import VisualCoreMath

public struct Mesh: Sendable, Equatable {
    public var positions: [Vec3]
    public var normals: [Vec3]
    public var uvs: [Vec2]
    public var indices: [UInt32]

    public static let subdivisionRange = 1...256
    public static let segmentRange = 3...256
    public static let ringRange = 2...256

    public var triangleCount: Int { indices.count / 3 }

    /// Position + normal per vertex, 6 floats each (for GL upload).
    public func interleavedPositionNormal() -> [Float] {
        positions.indices.flatMap { i in
            [Float(positions[i].x), Float(positions[i].y), Float(positions[i].z),
             Float(normals[i].x), Float(normals[i].y), Float(normals[i].z)]
        }
    }

    /// Unit plane in XY (−0.5…0.5) facing +z, `subdivisions` quads per side (clamped 1…256).
    public static func plane(subdivisions: Int = 1) -> Mesh {
        let n = min(max(subdivisions, subdivisionRange.lowerBound), subdivisionRange.upperBound)
        var m = Mesh(positions: [], normals: [], uvs: [], indices: [])
        for j in 0...n {
            for i in 0...n {
                let u = Double(i) / Double(n), v = Double(j) / Double(n)
                m.positions.append(Vec3(u - 0.5, v - 0.5, 0)); m.normals.append(Vec3(0, 0, 1)); m.uvs.append(Vec2(u, v))
            }
        }
        let row = UInt32(n + 1)
        for j in 0..<UInt32(n) {
            for i in 0..<UInt32(n) {
                let a = j * row + i, b = a + 1, c = a + row, d = c + 1
                m.indices += [a, b, d, a, d, c]
            }
        }
        return m
    }

    /// Unit cube (−0.5…0.5): 6 faces × 4 vertices with flat normals, 36 indices.
    public static func cube() -> Mesh {
        var m = Mesh(positions: [], normals: [], uvs: [], indices: [])
        let faces: [(n: Vec3, u: Vec3, v: Vec3)] = [
            (Vec3(1, 0, 0), Vec3(0, 0, -1), Vec3(0, 1, 0)), (Vec3(-1, 0, 0), Vec3(0, 0, 1), Vec3(0, 1, 0)),
            (Vec3(0, 1, 0), Vec3(1, 0, 0), Vec3(0, 0, -1)), (Vec3(0, -1, 0), Vec3(1, 0, 0), Vec3(0, 0, 1)),
            (Vec3(0, 0, 1), Vec3(1, 0, 0), Vec3(0, 1, 0)), (Vec3(0, 0, -1), Vec3(-1, 0, 0), Vec3(0, 1, 0)),
        ]
        for f in faces {
            let base = UInt32(m.positions.count)
            for (su, sv) in [(-0.5, -0.5), (0.5, -0.5), (0.5, 0.5), (-0.5, 0.5)] {
                m.positions.append(f.n * 0.5 + f.u * su + f.v * sv)
                m.normals.append(f.n)
                m.uvs.append(Vec2(su + 0.5, sv + 0.5))
            }
            m.indices += [base, base + 1, base + 2, base, base + 2, base + 3]
        }
        return m
    }

    /// UV sphere of `radius`: (segments + 1) × (rings + 1) vertices, 6 · segments · (rings − 1) indices
    /// (one triangle per quad at each pole). segments 3…256, rings 2…256 (clamped).
    public static func uvSphere(segments: Int = 32, rings: Int = 16, radius: Double = 1) -> Mesh {
        let s = min(max(segments, segmentRange.lowerBound), segmentRange.upperBound)
        let r = min(max(rings, ringRange.lowerBound), ringRange.upperBound)
        let radius = radius.isFinite && radius > 0 ? radius : 1
        var m = Mesh(positions: [], normals: [], uvs: [], indices: [])
        for j in 0...r {
            let v = Double(j) / Double(r), theta = v * .pi            // 0 at the north pole
            for i in 0...s {
                let u = Double(i) / Double(s), phi = u * 2 * .pi
                let n = Vec3(sin(theta) * sin(phi), cos(theta), sin(theta) * cos(phi))
                m.positions.append(n * radius); m.normals.append(n); m.uvs.append(Vec2(u, v))
            }
        }
        let row = UInt32(s + 1)
        for j in 0..<UInt32(r) {
            for i in 0..<UInt32(s) {
                let a = j * row + i, b = a + 1, c = a + row, d = c + 1
                if j != 0 { m.indices += [a, c, b] }
                if j != UInt32(r) - 1 { m.indices += [b, c, d] }
            }
        }
        return m
    }
}
