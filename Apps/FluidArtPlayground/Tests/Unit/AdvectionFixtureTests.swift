// AdvectionFixtureTests — feature 020 T-A02-211 (FR-A02-206, FR-A02-207; SC-A02-202, SC-A02-203; US2 AC1–AC2;
// manual Phase 02 regression fixture: zero velocity keeps a known dye pattern bounded).
import FluidArtPlaygroundCore
import VisualCoreRendering
import VisualCoreSimulation
import XCTest
@testable import FluidArtPlayground

@MainActor
final class AdvectionFixtureTests: XCTestCase {
    private func makeHost(_ scene: FluidFieldsScene) throws -> RenderHost {
        let host = try RenderHost(scene: scene)
        host.view.frame = CGRect(x: 0, y: 0, width: 32, height: 32)
        host.view.layoutIfNeeded()
        return host
    }

    private func config(_ size: Int, d: Double = 0) -> FluidConfiguration {
        var c = FluidConfiguration()
        c.gridWidth = size
        c.gridHeight = size
        c.dyeDissipation = d
        c.velocityDissipation = d
        c.seed = 11
        return c
    }

    /// Runs `steps` frames and compares dye and velocity with the CPU reference for each candidate storage rounding.
    private func compare(_ scene: FluidFieldsScene, host: RenderHost, steps: Int, file: StaticString = #filePath, line: UInt = #line) throws {
        for _ in 0..<steps { XCTAssertTrue(host.renderOneFrame(present: false), file: file, line: line) }
        XCTAssertNil(scene.lastError, file: file, line: line)
        XCTAssertEqual(scene.stepCount, steps, file: file, line: line)
        let precision = try XCTUnwrap(scene.precision)
        let modes: [StoragePrecision] = precision == .float16 ? [.float16, .float16TowardZero] : [.unorm8]
        var dyeRefs: [[Float]] = [], velocityRefs: [[Float]] = []
        let c = scene.configuration
        XCTAssertEqual(scene.dye?.width, c.gridWidth, file: file, line: line)
        for mode in modes {
            var velocity = scene.initialVelocity().rounded(to: precision)
            var dye = scene.initialDye().rounded(to: precision)
            for _ in 0..<steps {
                Advection.step(velocity: &velocity, dye: &dye, dt: 1.0 / 60, velocityDissipation: c.velocityDissipation,
                               dyeDissipation: c.dyeDissipation, precision: mode, velocityEncoding: scene.encoding)
            }
            dyeRefs.append(dye.values)
            velocityRefs.append(velocity.values)
        }
        let gpuDye = try XCTUnwrap(scene.dye?.read.readFloatPixels())
        let gpuVelocity = try XCTUnwrap(scene.velocity?.read.readFloatPixels())
        // SC-A02-203: within one storage step per step.
        let tol = precision.tolerance * Float(steps == 120 ? 1 : steps)
        let d = closestDifference(gpuDye, dyeRefs, tolerance: tol, relative: false)
        let v = closestDifference(gpuVelocity, velocityRefs, tolerance: tol, relative: precision != .unorm8)
        XCTAssertLessThanOrEqual(d.worst, tol, "dye \(c.gridWidth)² \(precision)", file: file, line: line)
        XCTAssertLessThanOrEqual(v.worst, tol, "velocity \(c.gridWidth)² \(precision)", file: file, line: line)
        print("advection fixture \(c.gridWidth)x\(c.gridHeight) \(precision) steps=\(steps): dye \(d.worst) via \(modes[d.reference]), velocity \(v.worst) via \(modes[v.reference])")
    }

    /// FR-A02-207 / SC-A02-202: zero velocity, zero dissipation, 120 steps: the pattern is unchanged and bounded.
    func testZeroVelocityKeepsPatternBounded() throws {
        for size in [8, 16] {
            for fallback in [false, true] {
                let scene = FluidFieldsScene(configuration: config(size), seed: .pattern, forceFallback: fallback)
                scene.fixedDelta = 1.0 / 60
                let host = try makeHost(scene)
                defer { host.destroy() }
                XCTAssertEqual(scene.configuration.gridWidth, size, "the fixture really runs at \(size)×\(size)")
                try compare(scene, host: host, steps: 120)
                let precision = try XCTUnwrap(scene.precision)
                let start = scene.initialDye().rounded(to: precision)
                let dye = try XCTUnwrap(scene.readDye())
                XCTAssertLessThanOrEqual(try XCTUnwrap(dye.maxAbsDifference(start)), precision.tolerance)
                XCTAssertLessThanOrEqual(dye.values.max()!, start.values.max()! + precision.tolerance)
                XCTAssertGreaterThanOrEqual(dye.minValue, 0)
            }
        }
    }

    /// US2 AC2 / SC-A02-203: uniform motion of half a cell per step, 4 steps, GPU = CPU on both grids and storages.
    func testUniformVelocityMatchesCPU() throws {
        for size in [8, 16] {
            for fallback in [false, true] {
                let scene = FluidFieldsScene(configuration: config(size), seed: .pattern, forceFallback: fallback)
                var v = FieldGrid(width: size, height: size, channels: 4)
                for cell in 0..<(size * size) { v.values[cell * 4] = 30; v.values[cell * 4 + 1] = -15 }
                scene.initialVelocityOverride = v
                scene.fixedDelta = 1.0 / 60
                let host = try makeHost(scene)
                defer { host.destroy() }
                try compare(scene, host: host, steps: 4)
            }
        }
    }

    /// Advection with dissipation and a splat, the full Phase 02 step, still matches the CPU reference.
    func testSplatThenAdvectWithDissipationMatchesCPU() throws {
        let scene = FluidFieldsScene(configuration: config(16, d: 1), seed: .pattern)
        scene.fixedDelta = 1.0 / 60
        let host = try makeHost(scene)
        defer { host.destroy() }
        let splat = try XCTUnwrap(Splat(position: SIMD2(0.4, 0.5), radius: 0.15, force: SIMD2(240, 60), color: SIMD4(0.2, 0.8, 0.9, 1)))
        scene.paused = true
        XCTAssertTrue(host.renderOneFrame(present: false))
        scene.paused = false
        scene.enqueue([splat])
        for _ in 0..<3 { XCTAssertTrue(host.renderOneFrame(present: false)) }
        let precision = try XCTUnwrap(scene.precision)
        let modes: [StoragePrecision] = precision == .float16 ? [.float16, .float16TowardZero] : [.unorm8]
        var refs: [[Float]] = []
        for mode in modes {
            var velocity = scene.initialVelocity().rounded(to: precision)
            var dye = scene.initialDye().rounded(to: precision)
            splat.apply(velocity: &velocity, dye: &dye, precision: mode, velocityEncoding: scene.encoding)
            for _ in 0..<3 {
                Advection.step(velocity: &velocity, dye: &dye, dt: 1.0 / 60, velocityDissipation: 1, dyeDissipation: 1,
                               precision: mode, velocityEncoding: scene.encoding)
            }
            refs.append(dye.values)
        }
        let gpu = try XCTUnwrap(scene.dye?.read.readFloatPixels())
        let d = closestDifference(gpu, refs, tolerance: precision.tolerance * 4, relative: false)
        XCTAssertLessThanOrEqual(d.worst, precision.tolerance * 4)
        print("splat+advect fixture 16x16 \(precision): dye \(d.worst) via \(modes[d.reference])")
    }
}
