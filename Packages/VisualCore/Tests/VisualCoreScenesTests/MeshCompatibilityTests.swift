// MeshCompatibilityTests — feature 205 (R02-F05) T-R02F05-011 (FR-R02F05-060, FR-R02F05-050; US4; SC-R02F05-005,
// SC-R02F05-006). The plane, cube and sphere of feature 006 keep their exact outputs (digests recorded on 2026-11-13
// from MeshGenerators.swift unchanged, `git diff --exit-code` clean) and pass the new validator; a mesh at the
// default budget builds and validates in bounded time.
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

/// SC-R02F05-006: a 512 × 512 grid built through `MeshBuilder` (262,144 vertices — the default budget — and 1,560,600
/// indices) builds and validates; the elapsed time is printed. Shapes clamp their resolutions (at most 257 × 257
/// samples), so the budget-sized mesh comes from the builder. The < 1 s criterion is measured on an optimized host
/// build (`swift test -c release`); a debug build is only bounded by the 10 s test limit.
@Test func aMeshAtTheBudgetBuildsAndValidates() throws {
    let side = 512
    let clock = ContinuousClock()
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
    let elapsed = clock.now - start
    print("BUDGET-MESH: vertices \(mesh.positions.count), indices \(mesh.indices.count), build+validate \(elapsed)")
    #expect(mesh.positions.count == MeshBudget.default.maxVertices)
    #expect(mesh.indices.count <= MeshBudget.default.maxIndices)
    #expect(report.isValid, "\(report)")
    #expect(elapsed < .seconds(10))
    // One more vertex is refused: the budget is exact.
    #expect(throws: MeshError.self) { _ = try builder.vertex(Vec3(2, 2, 0), normal: Vec3(0, 0, 1), uv: .zero) }
}
