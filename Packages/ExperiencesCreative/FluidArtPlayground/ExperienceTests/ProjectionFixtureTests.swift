// ProjectionFixtureTests — feature 021 T-A02-306 (FR-A02-301, FR-A02-302, FR-A02-304, FR-A02-306; SC-A02-301;
// US1 AC1–AC3; analyze C1): GPU projection and viscosity equal the CPU reference on 8×8 and 16×16 in both storages.
import FluidArtPlaygroundCore
import VisualCoreRendering
import VisualCoreSimulation
import XCTest
@testable import FluidArtPlaygroundExperience

@MainActor
final class ProjectionFixtureTests: XCTestCase {
    private func makeHost(_ scene: FluidFieldsScene) throws -> RenderHost {
        let host = try RenderHost(scene: scene)
        host.view.frame = CGRect(x: 0, y: 0, width: 32, height: 32)
        host.view.layoutIfNeeded()
        return host
    }

    private func config(_ size: Int, _ mode: BoundaryMode, viscosity: Double = 0) -> FluidConfiguration {
        var c = FluidConfiguration()
        c.gridWidth = size
        c.gridHeight = size
        c.boundaryMode = mode
        c.viscosity = viscosity
        c.dyeDissipation = 0
        c.velocityDissipation = 0
        return c
    }

    /// A divergent field: one Gaussian push (cells/s, unencoded).
    private func divergentField(_ size: Int) throws -> FieldGrid {
        var v = FieldGrid(width: size, height: size, channels: 4)
        var dye = FieldGrid(width: size, height: size, channels: 4)
        try XCTUnwrap(Splat(position: SIMD2(0.45, 0.55), radius: 0.2, force: SIMD2(200, -80), color: .one))
            .apply(velocity: &v, dye: &dye, precision: .float32)
        return v
    }

    private func interiorDivergence(_ v: FieldGrid, encodings: FluidEncodings) -> Float {
        var log = FluidSolver.AccessLog()
        let d = FluidSolver.divergence(velocity: v, mode: .walls, precision: .float32, encodings: encodings, log: &log)
        var sum: Float = 0
        for y in 1..<(v.height - 1) { for x in 1..<(v.width - 1) { sum += abs(encodings.divergence.map { $0.decode(d[x, y, 0]) } ?? d[x, y, 0]) } }
        return sum
    }

    private func run(_ c: FluidConfiguration, fallback: Bool, velocity: FieldGrid?, steps: Int, label: String) throws {
        let scene = FluidFieldsScene(configuration: c, seed: .pattern, forceFallback: fallback)
        scene.initialVelocityOverride = velocity
        scene.fixedDelta = 1.0 / 60
        let host = try makeHost(scene)
        defer { host.destroy() }
        XCTAssertEqual(scene.configuration.gridWidth, c.gridWidth)
        for _ in 0..<steps { XCTAssertTrue(host.renderOneFrame(present: false)) }
        XCTAssertNil(scene.lastError)
        let precision = try XCTUnwrap(scene.precision)
        let refs = try solverReference(scene, frames: Array(repeating: [], count: steps))
        let tol = precision.tolerance * Float(steps) * storedPassesPerFrame(scene, splats: 0)
        let gpuV = try XCTUnwrap(scene.velocity?.read.readFloatPixels())
        let gpuD = try XCTUnwrap(scene.dye?.read.readFloatPixels())
        let v = closestDifference(gpuV, refs.map(\.velocity.values), tolerance: tol, relative: precision != .unorm8)
        let d = closestDifference(gpuD, refs.map(\.dye.values), tolerance: tol, relative: false)
        XCTAssertLessThanOrEqual(v.worst, tol, "velocity \(label) \(precision)")
        XCTAssertLessThanOrEqual(d.worst, tol, "dye \(label) \(precision)")
        print("projection fixture \(label) \(c.gridWidth)x\(c.gridHeight) \(precision): velocity \(v.worst), dye \(d.worst) (tolerance \(tol))")
    }

    /// US1 AC1 / SC-A02-301: a divergent field projected with 20 iterations matches the CPU, and divergence falls.
    func testProjectionMatchesCPU() throws {
        for size in [8, 16] {
            for fallback in [false, true] {
                try run(config(size, .walls), fallback: fallback, velocity: try divergentField(size), steps: 1, label: "walls")
            }
        }
        // Divergence on the GPU result is lower than before (half-float, 16×16).
        let scene = FluidFieldsScene(configuration: config(16, .walls), seed: .pattern)
        let field = try divergentField(16)
        scene.initialVelocityOverride = field
        scene.fixedDelta = 1.0 / 60
        let host = try makeHost(scene)
        defer { host.destroy() }
        XCTAssertTrue(host.renderOneFrame(present: false))
        let gpu = try XCTUnwrap(FieldGrid(width: 16, height: 16, channels: 4, values: try XCTUnwrap(scene.velocity?.read.readFloatPixels())))
        let encodings = scene.precision == .unorm8 ? try XCTUnwrap(FluidEncodings.unorm8(velocityRange: scene.velocityRangeCellsPerSecond)) : .none
        let after = interiorDivergence(gpu, encodings: encodings), before = interiorDivergence(field, encodings: .none)
        XCTAssertLessThan(after, before)
        print("GPU projection interior |div| \(before) -> \(after)")
    }

    /// US1 AC3: a divergence-free field (uniform motion, open edges) is unchanged by projection.
    func testUniformFieldUnchangedWithOpenEdges() throws {
        for size in [8, 16] {
            var v = FieldGrid(width: size, height: size, channels: 4)
            for cell in 0..<(size * size) { v.values[cell * 4] = 30; v.values[cell * 4 + 1] = -15 }
            for fallback in [false, true] { try run(config(size, .open), fallback: fallback, velocity: v, steps: 3, label: "uniform-open") }
        }
    }

    /// FR-A02-304 (analyze C1): viscosity 0.5 matches the CPU reference.
    func testViscosityMatchesCPU() throws {
        for size in [8, 16] {
            for fallback in [false, true] {
                try run(config(size, .walls, viscosity: 0.5), fallback: fallback, velocity: try divergentField(size), steps: 2, label: "viscosity")
            }
        }
    }

    /// FR-A02-306: tuning changes apply from the next frame without rebuilding the fields.
    func testLiveConfigurationUpdate() throws {
        let scene = FluidFieldsScene(configuration: config(16, .walls), seed: .pattern)
        scene.fixedDelta = 1.0 / 60
        let host = try makeHost(scene)
        defer { host.destroy() }
        XCTAssertTrue(host.renderOneFrame(present: false))
        XCTAssertEqual(scene.lastPressureIterations, 20)
        let dyeBefore = try XCTUnwrap(scene.readDye())
        var c = scene.configuration
        c.pressureIterations = 5
        c.boundaryMode = .open
        c.viscosity = 0.3
        c.gridWidth = 64   // ignored: the grid only changes on a rebuild
        scene.update(configuration: c)
        XCTAssertTrue(host.renderOneFrame(present: false))
        XCTAssertEqual(scene.lastPressureIterations, 5)
        XCTAssertEqual(scene.configuration.boundaryMode, .open)
        XCTAssertEqual(scene.configuration.gridWidth, 16)
        XCTAssertEqual(scene.setupCount, 1, "no rebuild")
        XCTAssertGreaterThan(try XCTUnwrap(scene.readDye()).values.reduce(0, +), dyeBefore.values.reduce(0, +) * 0.5, "the picture is kept")
    }
}
