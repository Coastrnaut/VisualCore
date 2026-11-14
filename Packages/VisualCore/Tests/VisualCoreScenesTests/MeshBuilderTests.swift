// MeshBuilderTests.swift — feature 205 (R02-F05) T-R02F05-002 (FR-R02F05-050, FR-R02F05-051; research D1).
import Testing
import VisualCoreMath
@testable import VisualCoreScenes

private let up = Vec3(0, 0, 1)

@Test func budgetDefaultsAndClamping() {
    #expect(MeshBudget.default.maxVertices == 262_144)
    #expect(MeshBudget.default.maxIndices == 1_572_864)
    let low = MeshBudget(maxVertices: -5, maxIndices: -1)
    #expect(low.maxVertices == 0 && low.maxIndices == 0)
    let high = MeshBudget(maxVertices: Int.max, maxIndices: Int.max)
    #expect(high.maxVertices == Int(UInt32.max) && high.maxIndices == Int(UInt32.max))
}

@Test func weldingMergesEqualVerticesOnly() throws {
    var b = MeshBuilder()
    let a = try b.vertex(Vec3(1, 2, 3), normal: up, uv: Vec2(0.5, 0.5))
    let again = try b.vertex(Vec3(1, 2, 3), normal: up, uv: Vec2(0.5, 0.5))
    let negZero = try b.vertex(Vec3(1, 2, 3), normal: Vec3(-0.0, 0, 1), uv: Vec2(0.5, 0.5))
    #expect(a == again && a == negZero)
    let otherNormal = try b.vertex(Vec3(1, 2, 3), normal: Vec3(0, 1, 0), uv: Vec2(0.5, 0.5))
    let otherUV = try b.vertex(Vec3(1, 2, 3), normal: up, uv: Vec2(0.25, 0.5))
    let otherPosition = try b.vertex(Vec3(1, 2, 3.5), normal: up, uv: Vec2(0.5, 0.5))
    #expect([a, otherNormal, otherUV, otherPosition] == [0, 1, 2, 3])
    #expect(b.vertexCount == 4)
    // Within the tolerance (well below one grid step) the vertex welds.
    let near = try b.vertex(Vec3(1, 2, 3 + 1e-14), normal: up, uv: Vec2(0.5, 0.5))
    #expect(near == a)
}

@Test func weldingPositionsOnlyKeepsFirstAttributes() throws {
    var b = MeshBuilder(weldPositionsOnly: true)
    let a = try b.vertex(Vec3(0, 0, 0), normal: up, uv: Vec2(0, 0))
    let c = try b.vertex(Vec3(0, 0, 0), normal: Vec3(1, 0, 0), uv: Vec2(1, 1))
    #expect(a == c && b.vertexCount == 1)
    let m = b.build()
    #expect(m.normals == [up] && m.uvs == [Vec2(0, 0)])
}

@Test func indicesFollowInsertionOrder() throws {
    var b = MeshBuilder()
    let points = [Vec3(3, 0, 0), Vec3(-1, 0, 0), Vec3(0, 7, 0), Vec3(-1, 0, 0), Vec3(0, 0, 2)]
    let ids = try points.map { p throws(MeshError) in try b.vertex(p, normal: up, uv: .zero) }
    #expect(ids == [0, 1, 2, 1, 3])
}

@Test func outOfRangeTriangleIsRefused() throws {
    var b = MeshBuilder()
    for p in [Vec3(0, 0, 0), Vec3(1, 0, 0), Vec3(0, 1, 0)] { _ = try b.vertex(p, normal: up, uv: .zero) }
    #expect(throws: MeshError.self) { try b.triangle(0, 1, 3) }
    #expect(b.indexCount == 0)
    try b.triangle(0, 1, 2)
    #expect(b.indexCount == 3)
}

@Test func budgetRefusalLeavesBuilderUnchanged() throws {
    let budget = MeshBudget(maxVertices: 3, maxIndices: 3)
    var b = MeshBuilder(budget: budget)
    for p in [Vec3(0, 0, 0), Vec3(1, 0, 0), Vec3(0, 1, 0)] { _ = try b.vertex(p, normal: up, uv: .zero) }
    #expect(throws: MeshError.budget(vertices: 4, indices: 0, budget: budget)) {
        _ = try b.vertex(Vec3(1, 1, 0), normal: up, uv: .zero)
    }
    #expect(b.vertexCount == 3)
    // A welded vertex needs no room and is still accepted at the limit.
    #expect(try b.vertex(Vec3(0, 0, 0), normal: up, uv: .zero) == 0)
    try b.triangle(0, 1, 2)
    #expect(throws: MeshError.budget(vertices: 3, indices: 6, budget: budget)) { try b.triangle(0, 2, 1) }
    #expect(b.vertexCount == 3 && b.indexCount == 3)
    #expect(b.build().indices == [0, 1, 2])
}

@Test func buildHandQuad() throws {
    var b = MeshBuilder()
    let corners = [(Vec3(0, 0, 0), Vec2(0, 0)), (Vec3(1, 0, 0), Vec2(1, 0)),
                   (Vec3(1, 1, 0), Vec2(1, 1)), (Vec3(0, 1, 0), Vec2(0, 1))]
    // Two triangles sharing the diagonal: six vertex calls weld into four vertices.
    for tri in [[0, 1, 2], [0, 2, 3]] {
        let ids = try tri.map { k throws(MeshError) in try b.vertex(corners[k].0, normal: up, uv: corners[k].1) }
        try b.triangle(ids[0], ids[1], ids[2])
    }
    let expected = Mesh(positions: corners.map(\.0), normals: Array(repeating: up, count: 4),
                        uvs: corners.map(\.1), indices: [0, 1, 2, 0, 2, 3])
    #expect(b.build() == expected)
}
