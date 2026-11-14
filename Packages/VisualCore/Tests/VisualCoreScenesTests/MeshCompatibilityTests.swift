// MeshCompatibilityTests — feature 205 (R02-F05) T-R02F05-011 (FR-R02F05-060, FR-R02F05-050; US4; SC-R02F05-005,
// SC-R02F05-006). The plane, cube and sphere of feature 006 keep their exact outputs (digests recorded on 2026-11-13
// from MeshGenerators.swift unchanged, `git diff --exit-code` clean) and pass the new validator; a mesh at the
// default budget builds and validates in bounded time.
import Foundation
import Testing
import VisualCoreMath
@testable import VisualCoreScenes

@Test func existingGeneratorsKeepTheirOutputs() {
    #expect(Mesh.plane().digest == "32bcb87447701ba3f9b02e11897f98ff6e9c4b6de2347cdd59a3b77b051a0cca")
    #expect(Mesh.plane(subdivisions: 8).digest == "f1dbda9a39a1e81d88bdbaac62ba302a56cef4669ed19ba33355f85fc02c7a7c")
    #expect(Mesh.cube().digest == "b480169715d578c85a67d1817629ad16c2448101954d4f3e606fc2a32899e682")
    #expect(Mesh.uvSphere().digest == "051aa4fe5e716923d4983a593929c72cd54c589a1464dd9136971c2a5cdf3fa5")
    #expect(Mesh.uvSphere(segments: 16, rings: 8).digest == "f0720d367924d34456123304b94ae37622c95cc2b8b23d5fc92999db262d63a0")
}

@Test func existingGeneratorsPassTheValidator() {
    let plane = Mesh.plane(subdivisions: 4).validate()
    #expect(plane.isValid, "\(plane)")
    #expect(plane.summary.boundaryEdges == 16 && !plane.summary.isClosed)
    // The cube and the sphere split vertices at creases, seams and poles; topology is judged by welded position.
    let cube = Mesh.cube().validate(requireClosed: true)
    #expect(cube.isValid, "\(cube)")
    #expect(abs((cube.summary.volume ?? 0) - 1) < 1e-9)
    let sphere = Mesh.uvSphere(segments: 32, rings: 16).validate(requireClosed: true)
    #expect(sphere.isValid, "\(sphere)")
    #expect((sphere.summary.volume ?? 0) > 0)
}

/// SC-R02F05-006, short form (owner rule of 2026-11-13: measure a short run and bound the rest by arithmetic): a
/// 256 × 256 grid built through `MeshBuilder` (65,536 vertices, a quarter of the default budget) builds and validates;
/// building and validating are linear in the vertex count, so four times the measured time bounds a mesh at the full
/// budget. The printed bound is the evidence; the time assertion is skipped on CI runners (`CI` set), whose speed is
/// not the project Mac's — on 2026-11-13 a full-budget build took 4.1 s locally and 14 s on a runner.
@Test func aMeshAtTheBudgetBuildsAndValidates() throws {
    let side = 256
    let clock = ContinuousClock()
    /// Builds and validates the grid once and returns the mesh, its report and the time taken.
    func buildOnce() throws -> (Mesh, MeshReport, Duration) {
        let start = clock.now
        var builder = MeshBuilder()
        for j in 0..<side {
            for i in 0..<side {
                let u = Double(i) / Double(side - 1), v = Double(j) / Double(side - 1)
                _ = try builder.vertex(Vec3(u, v, 0), normal: Vec3(0, 0, 1), uv: Vec2(u, v))
            }
        }
        for j in 0..<(side - 1) {
            for i in 0..<(side - 1) {
                let a = UInt32(j * side + i), b = a + 1, c = a + UInt32(side), d = c + 1
                try builder.triangle(a, b, d)
                try builder.triangle(a, d, c)
            }
        }
        let mesh = builder.build()
        let report = mesh.validate()
        return (mesh, report, clock.now - start)
    }
    // The faster of two runs, so that other suites running in parallel on the same machine do not inflate the bound.
    let (mesh, report, first) = try buildOnce()
    let elapsed = min(first, try buildOnce().2)
    let fullBudgetBound = elapsed * (Double(MeshBudget.default.maxVertices) / Double(mesh.positions.count))
    print("BUDGET-MESH: vertices \(mesh.positions.count), build+validate \(elapsed), full-budget bound \(fullBudgetBound)")
    #expect(mesh.positions.count * 4 == MeshBudget.default.maxVertices)
    #expect(report.isValid, "\(report)")
    if ProcessInfo.processInfo.environment["CI"] == nil {
        #expect(fullBudgetBound < .seconds(5), "SC-R02F05-006 on the project Mac")
    }
    // The budget is exact: a builder at its limit refuses one more vertex (checked on a small budget, which is the
    // same code path).
    var small = MeshBuilder(budget: MeshBudget(maxVertices: 4, maxIndices: 6))
    for k in 0..<4 { _ = try small.vertex(Vec3(Double(k), 0, 0), normal: Vec3(0, 0, 1), uv: .zero) }
    #expect(throws: MeshError.self) { _ = try small.vertex(Vec3(9, 9, 0), normal: Vec3(0, 0, 1), uv: .zero) }
}
