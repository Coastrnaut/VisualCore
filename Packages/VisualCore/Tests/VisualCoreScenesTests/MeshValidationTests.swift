// MeshValidationTests.swift — feature 205 (R02-F05) T-R02F05-005 (FR-R02F05-030, FR-R02F05-031, FR-R02F05-032,
// FR-R02F05-070; SC-R02F05-002). One planted defect per MeshProblem.Kind with exact location.
import Foundation
import Testing
import VisualCoreMath
@testable import VisualCoreScenes

/// Closed tetrahedron with corners (0,0,0), (1,0,0), (0,1,0), (0,0,1), outward counter-clockwise faces.
private func tetrahedron() -> Mesh {
    let positions = [Vec3(0, 0, 0), Vec3(1, 0, 0), Vec3(0, 1, 0), Vec3(0, 0, 1)]
    let center = Vec3(0.25, 0.25, 0.25)
    return Mesh(positions: positions,
                normals: positions.map { ($0 - center).normalized },
                uvs: positions.map { Vec2($0.x, $0.y) },
                indices: [0, 2, 1, 0, 1, 3, 0, 3, 2, 1, 2, 3])
}

/// Reverses the winding of triangle `t`.
private func reversed(_ m: Mesh, triangle t: Int) -> Mesh {
    var m = m
    m.indices.swapAt(3 * t + 1, 3 * t + 2)
    return m
}

private func has(_ r: MeshReport, _ kind: MeshProblem.Kind, triangle: Int? = nil, vertex: Int? = nil,
                 edge: [UInt32]? = nil) -> Bool {
    r.problems.contains(MeshProblem(kind: kind, triangle: triangle, vertex: vertex, edge: edge))
}

@Test func closedTetrahedronIsValidWithAnalyticVolume() {
    let r = tetrahedron().validate(requireClosed: true)
    #expect(r.isValid)
    #expect(r.summary.vertices == 4 && r.summary.triangles == 4 && r.summary.boundaryEdges == 0)
    #expect(r.summary.isClosed)
    #expect(abs((r.summary.volume ?? 0) - 1.0 / 6.0) < 1e-12)
    #expect(r.summary.boundsMin == Vec3(0, 0, 0) && r.summary.boundsMax == Vec3(1, 1, 1))
}

@Test func existingCubeIsClosedByWeldedTopology() {
    let r = Mesh.cube().validate(requireClosed: true)
    #expect(r.problems.isEmpty && r.moreProblems == 0)
    #expect(r.summary.vertices == 24 && r.summary.triangles == 12 && r.summary.isClosed)
    #expect(abs((r.summary.volume ?? 0) - 1) < 1e-9)
}

@Test func validationDoesNotMutate() {
    let m = tetrahedron()
    let copy = m
    _ = m.validate(requireClosed: true)
    #expect(m == copy)
}

@Test func kindCount() { #expect(MeshProblem.Kind.allCases.count == 14) }

@Test func plantedIndexOutOfRange() {
    var m = tetrahedron(); m.indices[4] = 7
    #expect(has(m.validate(), .indexOutOfRange, triangle: 1, vertex: 7))
}

@Test func plantedIndexCountNotMultipleOfThree() {
    var m = tetrahedron(); m.indices.append(0)
    let r = m.validate()
    #expect(has(r, .indexCountNotMultipleOfThree))
    #expect(r.summary.triangles == 4)
}

@Test func plantedArrayLengthMismatch() {
    var m = tetrahedron(); m.normals.removeLast()
    let r = m.validate()
    #expect(has(r, .arrayLengthMismatch))
    #expect(r.problems.count == 1)
}

@Test func plantedDegenerateTriangle() {
    var m = tetrahedron(); m.indices[9...11] = [1, 2, 1]
    #expect(has(m.validate(), .degenerateTriangle, triangle: 3))
}

@Test func plantedNonFinitePosition() {
    var m = tetrahedron(); m.positions[3] = Vec3(.nan, 0, 0)
    let r = m.validate()
    #expect(has(r, .nonFinitePosition, triangle: 1, vertex: 3))
    #expect(r.problems.filter { $0.kind == .nonFinitePosition }.count == 1)
    #expect(r.summary.volume == nil)
}

@Test func plantedNonFiniteNormal() {
    var m = tetrahedron(); m.normals[2] = Vec3(.infinity, 0, 0)
    #expect(has(m.validate(), .nonFiniteNormal, vertex: 2))
}

@Test func plantedNonFiniteUV() {
    var m = tetrahedron(); m.uvs[1] = Vec2(.nan, 0)
    #expect(has(m.validate(), .nonFiniteUV, vertex: 1))
}

@Test func plantedNonUnitNormal() {
    var m = tetrahedron(); m.normals[0] = Vec3(0, 0, 2)
    let r = m.validate()
    #expect(has(r, .nonUnitNormal, vertex: 0))
    #expect(r.problems.count == 1)
}

@Test func plantedUVOutOfRange() {
    var m = tetrahedron(); m.uvs[3] = Vec2(1.5, 0)
    #expect(has(m.validate(), .uvOutOfRange, vertex: 3))
}

@Test func plantedNonManifoldEdge() {
    var m = tetrahedron()
    m.positions.append(Vec3(0.5, -1, 0)); m.normals.append(Vec3(0, -1, 0)); m.uvs.append(Vec2(0.5, 0))
    m.indices += [0, 1, 4]
    let r = m.validate()
    #expect(has(r, .nonManifoldEdge, triangle: 4, edge: [0, 1]))
    #expect(!r.summary.isClosed && r.summary.volume == nil)
}

@Test func plantedInconsistentWinding() {
    let r = reversed(tetrahedron(), triangle: 3).validate(requireClosed: true)
    #expect(has(r, .inconsistentWinding, triangle: 3, edge: [1, 2]))
    #expect(r.problems.filter { $0.kind == .inconsistentWinding }.count == 3)
    #expect(!r.problems.contains { $0.kind == .invertedFaces })
    #expect(r.summary.volume == nil)
}

@Test func plantedBoundaryEdgeOnlyWhenClosedRequired() {
    var m = tetrahedron(); m.indices.removeLast(3)
    let closed = m.validate(requireClosed: true)
    #expect(has(closed, .boundaryEdge, triangle: 0, edge: [1, 2]))
    #expect(has(closed, .boundaryEdge, triangle: 1, edge: [1, 3]))
    #expect(has(closed, .boundaryEdge, triangle: 2, edge: [2, 3]))
    #expect(closed.problems.count == 3)
    #expect(closed.summary.boundaryEdges == 3 && !closed.summary.isClosed && closed.summary.volume == nil)
    let open = m.validate()
    #expect(open.isValid && open.summary.boundaryEdges == 3)
}

@Test func plantedInvertedFaces() {
    var m = tetrahedron()
    for t in 0..<4 { m = reversed(m, triangle: t) }
    let r = m.validate(requireClosed: true)
    #expect(r.problems == [MeshProblem(kind: .invertedFaces)])
    #expect(abs((r.summary.volume ?? 0) + 1.0 / 6.0) < 1e-12)
}

@Test func plantedBudget() {
    let r = tetrahedron().validate(budget: MeshBudget(maxVertices: 3, maxIndices: 1_000))
    #expect(r.problems == [MeshProblem(kind: .budget)])
    #expect(!r.isValid)
}

@Test func problemsBeyondLimitAreCounted() {
    var m = tetrahedron()
    for _ in 0..<50 { m.indices += [100, 101, 102] }
    let r = m.validate()
    #expect(r.problems.count == MeshReport.problemLimit)
    #expect(r.moreProblems == 50)
    #expect(r.problems.allSatisfy { $0.kind == .indexOutOfRange })
    #expect(r.problems[0] == MeshProblem(kind: .indexOutOfRange, triangle: 4, vertex: 100))
}

@Test func reportRoundTripsAsJSONAndText() throws {
    var m = reversed(tetrahedron(), triangle: 3)
    m.normals[0] = Vec3(0, 0, 2)
    let r = m.validate(requireClosed: true)
    let data = try JSONEncoder().encode(r)
    let back = try JSONDecoder().decode(MeshReport.self, from: data)
    #expect(back == r)
    let valid = tetrahedron().validate(requireClosed: true)
    #expect(try JSONDecoder().decode(MeshReport.self, from: JSONEncoder().encode(valid)) == valid)

    let lines = r.description.split(separator: "\n")
    #expect(lines.count == r.problems.count + 1)
    #expect(lines[0] == "inconsistentWinding triangle 3 edge 1-2")
    #expect(lines.last?.hasPrefix("summary: 4 vertices, 4 triangles, 0 boundary edges, closed") == true)
}
