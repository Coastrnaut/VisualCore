// SplatFixtureTests — feature 020 T-A02-209 (FR-A02-205; US1 AC4; SC-A02-203; spec edge cases; analyze C3).
import FluidArtPlaygroundCore
import VisualCoreRendering
import VisualCoreSimulation
import XCTest
@testable import FluidArtPlayground

/// Largest per-value difference after picking the closer of several CPU references (GLES leaves the half-float
/// write rounding implementation-defined; feature 019 clarification 6). `relative` scales the tolerance by magnitude
/// for half-float values above 1.
func closestDifference(_ gpu: [Float], _ references: [[Float]], tolerance: Float, relative: Bool) -> (worst: Float, reference: Int) {
    var best = (worst: Float.infinity, reference: -1)
    for (r, ref) in references.enumerated() {
        var worst: Float = 0
        for i in gpu.indices {
            let allowed = relative ? max(tolerance, abs(ref[i]) * 0x1p-9) : tolerance
            worst = max(worst, abs(gpu[i] - ref[i]) / allowed * tolerance)
        }
        if worst < best.worst { best = (worst, r) }
    }
    return best
}

/// CPU reference of the scene's frames with the full solver (feature 021 clarification 5): `frames[k]` are the splats
/// applied in frame k. Returns one (velocity, dye) result per candidate storage rounding.
@MainActor
func solverReference(_ scene: FluidFieldsScene, frames: [[Splat]], dt: Double = 1.0 / 60) throws -> [(mode: StoragePrecision, velocity: FieldGrid, dye: FieldGrid)] {
    let precision = try XCTUnwrap(scene.precision)
    let modes: [StoragePrecision] = precision == .float16 ? [.float16, .float16TowardZero] : [.unorm8]
    let encodings = precision == .unorm8 ? try XCTUnwrap(FluidEncodings.unorm8(velocityRange: scene.velocityRangeCellsPerSecond)) : .none
    return modes.map { mode in
        var velocity = scene.initialVelocity().rounded(to: precision)
        var dye = scene.initialDye().rounded(to: precision)
        var log = FluidSolver.AccessLog()
        for splats in frames {
            FluidSolver.step(velocity: &velocity, dye: &dye, splats: splats, configuration: scene.configuration,
                             pressureIterations: scene.activePressureIterations, dt: dt, precision: mode, encodings: encodings, log: &log)
        }
        return (mode, velocity, dye)
    }
}

/// Stored passes in one frame (each may round once): splats ×2, advect ×2, viscosity, divergence, pressure, gradient.
@MainActor
func storedPassesPerFrame(_ scene: FluidFieldsScene, splats: Int) -> Float {
    Float(2 * splats + 2 + (scene.configuration.viscosity > 0 ? FluidSolver.viscosityIterations : 0) + 2 + scene.activePressureIterations)
}

@MainActor
final class SplatFixtureTests: XCTestCase {
    private func makeHost(_ scene: FluidFieldsScene) throws -> RenderHost {
        let host = try RenderHost(scene: scene)
        host.view.frame = CGRect(x: 0, y: 0, width: 32, height: 32)
        host.view.layoutIfNeeded()
        return host
    }

    private func config(_ size: Int) -> FluidConfiguration {
        var c = FluidConfiguration()
        c.gridWidth = size
        c.gridHeight = size
        c.dyeDissipation = 0
        c.velocityDissipation = 0
        return c
    }

    /// US1 AC4: one splat on 8×8 and 16×16, in both storages, equals the CPU reference within one storage step.
    func testSplatMatchesCPUReference() throws {
        let splat = try XCTUnwrap(Splat(position: SIMD2(0.3, 0.6), radius: 0.2, force: SIMD2(100, -50), color: SIMD4(0.9, 0.2, 0.4, 1)))
        for size in [8, 16] {
            for fallback in [false, true] {
                let scene = FluidFieldsScene(configuration: config(size), seed: .pattern, forceFallback: fallback)
                scene.fixedDelta = 1.0 / 60
                scene.paused = true
                let host = try makeHost(scene)
                defer { host.destroy() }
                XCTAssertTrue(host.renderOneFrame(present: false))   // set up and show the seed
                let precision = try XCTUnwrap(scene.precision)
                XCTAssertEqual([scene.configuration.gridWidth, scene.dye?.width], [size, size], "the fixture really runs at \(size)×\(size)")
                scene.paused = false
                scene.enqueue([splat])
                XCTAssertTrue(host.renderOneFrame(present: false))
                XCTAssertEqual(scene.appliedSplats, 1)
                XCTAssertNil(scene.lastError)

                // Feature 021: the same frame also projects (full-step reference, clarification 5).
                let refs = try solverReference(scene, frames: [[splat]])
                let modes = refs.map(\.mode)
                let dyeRefs = refs.map(\.dye.values), velocityRefs = refs.map(\.velocity.values)
                let gpuDye = try XCTUnwrap(scene.dye?.read.readFloatPixels())
                let gpuVelocity = try XCTUnwrap(scene.velocity?.read.readFloatPixels())
                let tol = precision.tolerance * storedPassesPerFrame(scene, splats: 1)
                let dyeDiff = closestDifference(gpuDye, dyeRefs, tolerance: tol, relative: false)
                let velDiff = closestDifference(gpuVelocity, velocityRefs, tolerance: tol, relative: precision != .unorm8)
                XCTAssertLessThanOrEqual(dyeDiff.worst, tol, "dye \(size)x\(size) \(precision)")
                XCTAssertLessThanOrEqual(velDiff.worst, tol, "velocity \(size)x\(size) \(precision)")
                print("splat fixture \(size)x\(size) \(precision): dye \(dyeDiff.worst) via \(modes[dyeDiff.reference]), velocity \(velDiff.worst) via \(modes[velDiff.reference])")
            }
        }
    }

    /// Spec edge case (analyze C3): splats queued before a context loss are applied after the rebuild.
    func testPendingSplatsSurviveContextLoss() throws {
        var c = config(16)
        c.seed = 3
        let scene = FluidFieldsScene(configuration: c, seed: .uniform(SIMD4(0, 0, 0, 1)))
        scene.fixedDelta = 1.0 / 60
        let host = try makeHost(scene)
        defer { host.destroy() }
        XCTAssertTrue(host.renderOneFrame(present: false))
        scene.enqueue([try XCTUnwrap(Splat(position: SIMD2(0.5, 0.5), radius: 0.25, force: .zero, color: SIMD4(1, 1, 1, 1)))])
        host.recreateContext()
        XCTAssertEqual(scene.rebuildCount, 1)
        XCTAssertEqual(scene.pendingSplats.count, 1, "the queue is CPU state")
        XCTAssertTrue(host.renderOneFrame(present: false))
        XCTAssertEqual(scene.appliedSplats, 1)
        let dye = try XCTUnwrap(scene.readDye())
        XCTAssertGreaterThan(dye[8, 8, 0], 0.5, "the splat reached the rebuilt field")
    }

    /// 8-bit storage holds zero velocity exactly (center 128/255), so a field at rest never drifts.
    func testRGBA8ZeroVelocityIsExact() throws {
        let scene = FluidFieldsScene(configuration: config(8), forceFallback: true)
        scene.fixedDelta = 1.0 / 60
        let host = try makeHost(scene)
        defer { host.destroy() }
        for _ in 0..<10 { XCTAssertTrue(host.renderOneFrame(present: false)) }
        let velocity = try XCTUnwrap(scene.readVelocity())
        XCTAssertEqual(velocity.values.map(abs).max(), 0)
    }
}
