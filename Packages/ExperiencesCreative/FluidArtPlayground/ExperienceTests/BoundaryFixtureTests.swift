// BoundaryFixtureTests — feature 021 T-A02-306 (FR-A02-303; SC-A02-303; US2 AC1–AC3; manual Phase 03 regression
// fixture "boundary modes have fixture tests and no out-of-bounds sampling").
import FluidArtPlaygroundCore
import VisualCoreRendering
import VisualCoreSimulation
import XCTest
@testable import FluidArtPlaygroundExperience

@MainActor
final class BoundaryFixtureTests: XCTestCase {
    private func run(size: Int, mode: BoundaryMode, fallback: Bool) throws {
        var c = FluidConfiguration()
        c.gridWidth = size
        c.gridHeight = size
        c.boundaryMode = mode
        c.dyeDissipation = 0
        c.velocityDissipation = 0
        let scene = FluidFieldsScene(configuration: c, seed: .pattern, forceFallback: fallback)
        var v = FieldGrid(width: size, height: size, channels: 4)
        for cell in 0..<(size * size) { v.values[cell * 4] = -40; v.values[cell * 4 + 1] = 25 }
        scene.initialVelocityOverride = v
        scene.fixedDelta = 1.0 / 60
        let host = try RenderHost(scene: scene)
        host.view.frame = CGRect(x: 0, y: 0, width: 32, height: 32)
        host.view.layoutIfNeeded()
        defer { host.destroy() }
        XCTAssertTrue(host.renderOneFrame(present: false))
        let precision = try XCTUnwrap(scene.precision)
        let gpu = try XCTUnwrap(scene.readVelocity())
        let step: Float = precision == .unorm8 ? 1.5 / 255 * scene.velocityRangeCellsPerSecond * 2 : 1e-3
        if mode == .walls {
            for i in 0..<size {
                XCTAssertEqual(gpu[0, i, 0], 0, accuracy: step, "no flow through the left wall")
                XCTAssertEqual(gpu[size - 1, i, 0], 0, accuracy: step, "no flow through the right wall")
                XCTAssertEqual(gpu[i, 0, 1], 0, accuracy: step, "no flow through the bottom wall")
                XCTAssertEqual(gpu[i, size - 1, 1], 0, accuracy: step, "no flow through the top wall")
            }
        } else {
            XCTAssertLessThan(gpu[0, size / 2, 0], -30, "open edges keep the outward flow")
            XCTAssertGreaterThan(gpu[size / 2, size - 1, 1], 15)
        }
        // Edges compared exactly with the CPU reference, whose access log proves 0 out-of-grid reads.
        let refs = try solverReference(scene, frames: [[]])
        let raw = try XCTUnwrap(scene.velocity?.read.readFloatPixels())
        let tol = precision.tolerance * storedPassesPerFrame(scene, splats: 0)
        let diff = closestDifference(raw, refs.map(\.velocity.values), tolerance: tol, relative: precision != .unorm8)
        XCTAssertLessThanOrEqual(diff.worst, tol, "\(mode) \(size)² \(precision)")
        var log = FluidSolver.AccessLog()
        var vv = scene.initialVelocity().rounded(to: precision), dd = scene.initialDye().rounded(to: precision)
        let encodings = precision == .unorm8 ? try XCTUnwrap(FluidEncodings.unorm8(velocityRange: scene.velocityRangeCellsPerSecond)) : .none
        FluidSolver.step(velocity: &vv, dye: &dd, splats: [], configuration: scene.configuration,
                         pressureIterations: scene.activePressureIterations, dt: 1.0 / 60, precision: precision, encodings: encodings, log: &log)
        XCTAssertEqual(log.outOfGrid, 0)
        print("boundary fixture \(mode) \(size)x\(size) \(precision): velocity \(diff.worst), reads \(log.reads), out-of-grid \(log.outOfGrid)")
    }

    func testWallsAndOpenOnBothGridsAndStorages() throws {
        for mode in BoundaryMode.allCases {
            for size in [8, 16] {
                for fallback in [false, true] { try run(size: size, mode: mode, fallback: fallback) }
            }
        }
    }
}
