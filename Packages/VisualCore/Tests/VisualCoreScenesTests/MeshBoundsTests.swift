// MeshBoundsTests.swift — feature 205 (R02-F05) T-R02F05-004 (FR-R02F05-040, SC-R02F05-004).
import Testing
import VisualCoreMath
@testable import VisualCoreScenes

@Test func cubeBoundsAreTight() {
    let m = Mesh.cube()
    let b = m.bounds
    #expect(b == .box(min: Vec3(-0.5, -0.5, -0.5), max: Vec3(0.5, 0.5, 0.5)))
    guard case let .box(lo, hi) = b else { Issue.record("cube bounds are empty"); return }
    // Each of the six faces touches a vertex.
    #expect(m.positions.contains { $0.x == lo.x } && m.positions.contains { $0.x == hi.x })
    #expect(m.positions.contains { $0.y == lo.y } && m.positions.contains { $0.y == hi.y })
    #expect(m.positions.contains { $0.z == lo.z } && m.positions.contains { $0.z == hi.z })
    #expect(b.center == Vec3(0, 0, 0))
}

@Test func boundsContainEveryVertex() {
    for m in [Mesh.cube(), Mesh.plane(subdivisions: 3), Mesh.uvSphere(segments: 12, rings: 6)] {
        let b = m.bounds
        #expect(m.positions.allSatisfy { b.contains($0) })
        guard let c = b.center, let r = b.radius else { Issue.record("bounds are empty"); continue }
        let farthest = m.positions.map { ($0 - c).length }.max() ?? 0
        #expect(r >= farthest - 1e-12)
    }
    let offset = Mesh(positions: [Vec3(2, -3, 1), Vec3(4, 5, -1)], normals: [], uvs: [], indices: [])
    #expect(offset.bounds == .box(min: Vec3(2, -3, -1), max: Vec3(4, 5, 1)))
    #expect(!offset.bounds.contains(Vec3(4.1, 0, 0)))
    #expect(offset.bounds.contains(Vec3(4 + 1e-10, 0, 0)))
}

@Test func emptyMeshHasEmptyBounds() {
    let b = Mesh(positions: [], normals: [], uvs: [], indices: []).bounds
    #expect(b == .empty)
    #expect(b.center == nil && b.radius == nil)
    #expect(!b.contains(Vec3(0, 0, 0)))
}
