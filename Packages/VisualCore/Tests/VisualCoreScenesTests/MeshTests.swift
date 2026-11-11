// MeshTests — feature 006 T-F516 (FR-F509, FR-F512; US4 AC2).
import Foundation
import Testing
import VisualCoreMath
@testable import VisualCoreScenes

/// Every triangle's geometric normal agrees with its vertex normals (outward, counter-clockwise).
private func facesOutward(_ m: Mesh) -> Bool {
    stride(from: 0, to: m.indices.count, by: 3).allSatisfy { k in
        let (i, j, l) = (Int(m.indices[k]), Int(m.indices[k + 1]), Int(m.indices[k + 2]))
        let face = (m.positions[j] - m.positions[i]).cross(m.positions[l] - m.positions[i])
        guard face.length > 1e-12 else { return false }   // no degenerate triangles
        let avg = m.normals[i] + m.normals[j] + m.normals[l]
        return face.dot(avg) > 0
    }
}

@Test func sphereCountsAndUnitNormals() {
    // AC2: 16 segments × 8 rings.
    let m = Mesh.uvSphere(segments: 16, rings: 8)
    #expect(m.positions.count == 17 * 9)
    #expect(m.indices.count == 6 * 16 * 7)
    let unit = m.normals.allSatisfy { abs($0.length - 1) < 1e-12 }
    #expect(unit)
    let onSphere = m.positions.indices.allSatisfy { abs(m.positions[$0].length - 1) < 1e-12 }
    #expect(onSphere)
    let indexInRange = m.indices.allSatisfy { Int($0) < m.positions.count }
    #expect(indexInRange)
    #expect(facesOutward(m))
}

@Test func cubeAndPlane() {
    let c = Mesh.cube()
    #expect(c.positions.count == 24 && c.indices.count == 36)
    #expect(facesOutward(c))
    let p = Mesh.plane(subdivisions: 4)
    #expect(p.positions.count == 25 && p.indices.count == 4 * 4 * 6)
    #expect(facesOutward(p))
    #expect(p.interleavedPositionNormal().count == 25 * 6)
}

@Test func resolutionsAreClamped() {
    #expect(Mesh.uvSphere(segments: 1, rings: 1).positions.count == 4 * 3)
    #expect(Mesh.uvSphere(segments: 10_000, rings: 10_000).positions.count == 257 * 257)
    #expect(Mesh.plane(subdivisions: 0).positions.count == 4)
    #expect(Mesh.plane(subdivisions: 1_000).positions.count == 257 * 257)
    #expect(Mesh.uvSphere(radius: -3).positions.allSatisfy { abs($0.length - 1) < 1e-12 })
    #expect(Mesh.uvSphere(segments: 8, rings: 4, radius: 2.5).positions.allSatisfy { abs($0.length - 2.5) < 1e-12 })
}
