// MeshNormalsTests.swift — feature 205 (R02-F05) T-R02F05-007 (FR-R02F05-020, FR-R02F05-021; research D2).
import Foundation
import Testing
import VisualCoreMath
@testable import VisualCoreScenes

private func allUnit(_ m: Mesh) -> Bool { m.normals.allSatisfy { abs($0.length - 1) < 1e-12 } }

private func faceNormal(_ m: Mesh, _ t: Int) -> Vec3 {
    let (a, b, c) = (Int(m.indices[3 * t]), Int(m.indices[3 * t + 1]), Int(m.indices[3 * t + 2]))
    return (m.positions[b] - m.positions[a]).cross(m.positions[c] - m.positions[a]).normalized
}

@Test func cubeBelowCreaseKeepsFaceNormals() {
    let cube = Mesh.cube()
    let m = cube.withSmoothNormals(creaseAngle: 30 * .pi / 180)
    #expect(m.positions.count == 24)
    #expect(m.positions == cube.positions && m.uvs == cube.uvs && m.indices == cube.indices)
    let same = m.normals.indices.allSatisfy { (m.normals[$0] - cube.normals[$0]).length < 1e-12 }
    #expect(same)
    #expect(allUnit(m))
}

@Test func cubeAboveCreaseSharesEightCornerNormals() {
    // The cube's 24 vertices carry per-face texture coordinates, which are kept: the vertex count stays 24, and
    // the three vertices at each corner share one normal along the corner diagonal (±1, ±1, ±1)/√3 — 8 normals.
    let m = Mesh.cube().withSmoothNormals(creaseAngle: 100 * .pi / 180)
    #expect(m.positions.count == 24)
    let diagonal = m.positions.indices.allSatisfy { (m.normals[$0] - m.positions[$0].normalized).length < 1e-12 }
    #expect(diagonal)
    let distinct = Set(m.normals.map { [($0.x * 1e6).rounded(), ($0.y * 1e6).rounded(), ($0.z * 1e6).rounded()] })
    #expect(distinct.count == 8)
    #expect(allUnit(m))
    #expect(m.validate(requireClosed: true).isValid)
}

@Test func sphereSmoothNormalsAreRadial() {
    // Tolerance: on a faceted 32 × 16 sphere the area- and angle-weighted average of the chord-plane face normals
    // differs from the exact radial direction by up to about 0.0112 (0.64°, measured with the same weights); 1e-6 is
    // not reachable at this resolution, so 0.015 bounds it. Seam copies and poles are checked exactly.
    let sphere = Mesh.uvSphere(segments: 32, rings: 16)
    let m = sphere.withSmoothNormals(creaseAngle: 60 * .pi / 180)
    #expect(m.positions.count == 33 * 17)
    #expect(m.positions == sphere.positions && m.uvs == sphere.uvs && m.indices == sphere.indices)
    let radial = m.positions.indices.allSatisfy { (m.normals[$0] - m.positions[$0].normalized).length < 0.015 }
    #expect(radial)
    let seamShared = (0...16).allSatisfy { j in (m.normals[j * 33] - m.normals[j * 33 + 32]).length < 1e-12 }
    #expect(seamShared)
    let poles = (0...32).allSatisfy { i in
        (m.normals[i] - Vec3(0, 1, 0)).length < 1e-9 && (m.normals[16 * 33 + i] - Vec3(0, -1, 0)).length < 1e-9
    }
    #expect(poles)
    #expect(allUnit(m))
}

@Test func flatNormalsOneVertexPerCorner() {
    for source in [Mesh.cube(), Mesh.uvSphere(segments: 12, rings: 6)] {
        let m = source.withFlatNormals()
        #expect(m.positions.count == 3 * source.triangleCount)
        #expect(m.indices == (0..<UInt32(m.positions.count)).map { $0 })
        let flat = (0..<m.triangleCount).allSatisfy { t in
            let n = faceNormal(m, t)
            return (0..<3).allSatisfy { (m.normals[3 * t + $0] - n).length < 1e-12 }
        }
        #expect(flat)
        #expect(allUnit(m))
    }
    let cube = Mesh.cube().withFlatNormals()
    let matchesCube = cube.positions.indices.allSatisfy { k in
        (cube.normals[k] - Mesh.cube().normals[Int(Mesh.cube().indices[k])]).length < 1e-12
    }
    #expect(matchesCube)
}

@Test func degenerateFaceKeepsOldNormal() {
    let m = Mesh(positions: [Vec3(0, 0, 0), Vec3(1, 0, 0), Vec3(0, 1, 0), Vec3(2, 0, 0)],
                 normals: [Vec3(0, 0, 1), Vec3(0, 0, 1), Vec3(0, 0, 1), Vec3(0, 1, 0)],
                 uvs: [Vec2(0, 0), Vec2(1, 0), Vec2(0, 1), Vec2(1, 1)],
                 indices: [0, 1, 2, 0, 1, 3])            // second triangle is collinear
    let s = m.withSmoothNormals(creaseAngle: .pi / 4)
    #expect(s.positions.count == 4)
    #expect((s.normals[3] - Vec3(0, 1, 0)).length < 1e-12)
    #expect((s.normals[0] - Vec3(0, 0, 1)).length < 1e-12)
    let f = m.withFlatNormals()
    #expect((f.normals[5] - Vec3(0, 1, 0)).length < 1e-12)
}
