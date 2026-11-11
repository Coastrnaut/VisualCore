// DissipationFixtureTests — feature 019 T-A02-111 (FR-A02-103, FR-A02-104, FR-A02-110; SC-A02-101, SC-A02-102;
// manual Phase 01 regression fixture: uniform dye at rest decays only according to the configured dissipation).
import FluidArtPlaygroundCore
import VisualCoreRendering
import VisualCoreSimulation
import XCTest
@testable import FluidArtPlayground

@MainActor
final class DissipationFixtureTests: XCTestCase {
    static let dissipations: [Double] = [0, 1, 5]
    static let steps = 60
    static let dt = 1.0 / 60
    static let dye = SIMD4<Float>(0.8, 0.8, 0.8, 1)

    private func makeHost(_ scene: FluidFieldsScene) throws -> RenderHost {
        let host = try RenderHost(scene: scene)
        host.view.frame = CGRect(x: 0, y: 0, width: 32, height: 32)
        host.view.layoutIfNeeded()
        return host
    }

    private func config(d: Double) -> FluidConfiguration {
        var c = FluidConfiguration()
        c.gridWidth = 16
        c.gridHeight = 16
        c.dyeDissipation = d
        c.velocityDissipation = d
        return c
    }

    private func runFixture(fallback: Bool) throws {
        for d in Self.dissipations {
            let scene = FluidFieldsScene(configuration: config(d: d), seed: .uniform(Self.dye), forceFallback: fallback)
            scene.fixedDelta = Self.dt
            let host = try makeHost(scene)
            defer { host.destroy() }
            for _ in 0..<Self.steps { XCTAssertTrue(host.renderOneFrame(present: false)) }
            XCTAssertNil(scene.lastError)
            XCTAssertEqual(scene.stepCount, Self.steps)
            let precision = try XCTUnwrap(scene.precision)
            if fallback { XCTAssertEqual(precision, .unorm8) }
            // Every step wrote the other target of each pair (one swap per pair per step).
            XCTAssertEqual(scene.velocity?.swapCount, Self.steps)
            XCTAssertEqual(scene.dye?.swapCount, Self.steps)

            // GLES leaves the half rounding of color writes implementation-defined: compare with the reference for
            // each half mode and require the closer one to be within one storage step (spec clarification 6).
            let modes: [StoragePrecision] = precision == .float16 ? [.float16, .float16TowardZero] : [precision]
            let gpu = try XCTUnwrap(scene.readDye())
            var results: [(StoragePrecision, Float)] = []
            for mode in modes {
                // The seed upload rounds to nearest; every GPU step then stores with `mode`.
                var reference = scene.initialDye().rounded(to: precision)
                for _ in 0..<Self.steps { Dissipation.step(&reference, d: d, dt: Self.dt, precision: mode) }
                results.append((mode, try XCTUnwrap(gpu.maxAbsDifference(reference))))
            }
            let best = try XCTUnwrap(results.min { $0.1 < $1.1 })
            XCTAssertLessThanOrEqual(best.1, best.0.tolerance, "d=\(d) \(precision): max |GPU-CPU| = \(results)")
            print("fixture d=\(d) storage=\(precision) matched=\(best.0) maxdiff=\(best.1) all=\(results.map { "\($0.0)=\($0.1)" })")

            let velocity = try XCTUnwrap(scene.readVelocity())
            let velocityTolerance = precision == .unorm8 ? Float(config(d: d).velocityRange) * 2 / 255 : 1e-3
            XCTAssertLessThanOrEqual(velocity.values.map(abs).max() ?? .infinity, velocityTolerance, "velocity at rest stays 0")
        }
    }

    /// SC-A02-101, half-float storage (used when the runtime supports it, which both simulators do).
    func testUniformDyeDecaysLikeReferenceHalfFloat() throws {
        let probe = FluidFieldsScene(configuration: config(d: 0), seed: .uniform(Self.dye))
        let host = try makeHost(probe)
        XCTAssertTrue(host.renderOneFrame(present: false))
        let supported = probe.storage == .rgba16f
        host.destroy()
        try XCTSkipUnless(supported, "half-float render targets unsupported; the RGBA8 test covers this runtime")
        try runFixture(fallback: false)
    }

    /// SC-A02-101, forced RGBA8 fallback.
    func testUniformDyeDecaysLikeReferenceRGBA8Fallback() throws {
        try runFixture(fallback: true)
    }

    /// FR-A02-110 (analyze C2): after upload and 0 steps, the GPU holds the CPU seed rounded to storage precision.
    func testSeedPatternMatchesOnGPUAndCPU() throws {
        for fallback in [false, true] {
            var c = FluidConfiguration()
            c.gridWidth = 24
            c.gridHeight = 20
            c.seed = 7
            let scene = FluidFieldsScene(configuration: c, seed: .pattern, forceFallback: fallback)
            scene.paused = true
            let host = try makeHost(scene)
            defer { host.destroy() }
            XCTAssertTrue(host.renderOneFrame(present: false))
            XCTAssertEqual(scene.stepCount, 0)
            let precision = try XCTUnwrap(scene.precision)
            let expected = DyeSeed.pattern(width: 24, height: 20, seed: 7).rounded(to: precision)
            let gpu = try XCTUnwrap(scene.readDye())
            XCTAssertLessThanOrEqual(try XCTUnwrap(gpu.maxAbsDifference(expected)), precision.tolerance, "\(precision)")
        }
    }

    /// SC-A02-102: the shared guard refuses a pass whose output is the texture it samples.
    func testSimulationPassCannotSampleItsOutput() throws {
        let scene = FluidFieldsScene(configuration: config(d: 1), seed: .uniform(Self.dye))
        let host = try makeHost(scene)
        defer { host.destroy() }
        XCTAssertTrue(host.renderOneFrame(present: false))
        let dye = try XCTUnwrap(scene.dye)
        // Same source as the scene's pass, so this shares its cached program; it is not released here.
        let pass = try FieldPass(registry: host.resources, fragment: FluidShaders.dissipate, inputs: ["uField"], label: "guard")
        XCTAssertThrowsError(try pass.run(output: .target(dye.read), inputs: ["uField": dye.read],
                                          uniforms: ["uFactor": .float(1)])) {
            XCTAssertEqual($0 as? FieldPassError, .inputIsOutput("uField"))
        }
        XCTAssertTrue(host.renderOneFrame(present: false), "the scene keeps rendering")
        XCTAssertNil(scene.lastError)
    }
}
