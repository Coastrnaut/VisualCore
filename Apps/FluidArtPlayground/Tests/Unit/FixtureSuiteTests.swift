// FixtureSuiteTests — feature 023 T-A02-507 (FR-A02-506, SC-A02-504; US3 AC1–AC5; clarification 3; research R6;
// analyze G1). The manual's §11 implementation-level fixtures 1–5 as one named suite. Fixtures 1, 3 and 4 also have
// their full feature-019/021/022 versions (DissipationFixtureTests, BoundaryFixtureTests, PassIsolationTests); this
// suite restates each as one pass/fail result and adds fixtures 2 and 5.
import FluidArtPlaygroundCore
import VisualCoreRendering
import VisualCoreSimulation
import XCTest
@testable import FluidArtPlayground

@MainActor
final class FixtureSuiteTests: XCTestCase {
    override func tearDown() {
        MainActor.assumeIsolated { FieldPass.runObserver = nil }
        super.tearDown()
    }

    private func host(_ scene: FluidFieldsScene) throws -> RenderHost {
        let host = try RenderHost(scene: scene)
        host.view.frame = CGRect(x: 0, y: 0, width: 32, height: 32)
        host.view.layoutIfNeeded()
        return host
    }

    private func config(size: Int = 16, d: Double) -> FluidConfiguration {
        var c = FluidConfiguration()
        c.gridWidth = size
        c.gridHeight = size
        c.dyeDissipation = d
        c.velocityDissipation = d
        return c
    }

    /// Fixture 1: uniform dye at rest decays only according to the configured dissipation (both storages).
    func testFixture1UniformDyeDecaysByDissipation() throws {
        let steps = 30, dt = 1.0 / 60, d = 1.0
        for fallback in [false, true] {
            let scene = FluidFieldsScene(configuration: config(d: d), seed: .uniform(SIMD4(0.8, 0.8, 0.8, 1)), forceFallback: fallback)
            scene.fixedDelta = dt
            let host = try host(scene)
            defer { host.destroy() }
            for _ in 0..<steps { XCTAssertTrue(host.renderOneFrame(present: false)) }
            let precision = try XCTUnwrap(scene.precision)
            let gpu = try XCTUnwrap(scene.readDye())
            let modes: [StoragePrecision] = precision == .float16 ? [.float16, .float16TowardZero] : [precision]
            let worst = try modes.map { mode -> Float in
                var reference = scene.initialDye().rounded(to: precision)
                for _ in 0..<steps { Dissipation.step(&reference, d: d, dt: dt, precision: mode) }
                return try XCTUnwrap(gpu.maxAbsDifference(reference))
            }.min() ?? .infinity
            XCTAssertLessThanOrEqual(worst, precision.tolerance, "fixture 1 \(precision)")
            print("fixture 1 \(precision): max |GPU − reference| \(worst)")
        }
    }

    /// Fixture 2: with zero velocity a known dye pattern stays bounded: no cell grows, and the total stays within the
    /// dissipation bound.
    func testFixture2ZeroVelocityKeepsPatternBounded() throws {
        let steps = 30, dt = 1.0 / 60, d = 0.5
        for fallback in [false, true] {
            let scene = FluidFieldsScene(configuration: config(size: 24, d: d), seed: .pattern, forceFallback: fallback)
            scene.fixedDelta = dt
            let host = try host(scene)
            defer { host.destroy() }
            XCTAssertTrue(host.renderOneFrame(present: false))
            let precision = try XCTUnwrap(scene.precision)
            let start = scene.initialDye().rounded(to: precision)
            for _ in 1..<steps { XCTAssertTrue(host.renderOneFrame(present: false)) }
            let gpu = try XCTUnwrap(scene.readDye())
            let tolerance = precision.tolerance * 2
            var grew = 0
            var startSum = 0.0, endSum = 0.0
            for i in 0..<(gpu.width * gpu.height) {
                for c in 0..<3 {
                    let a = start.values[i * 4 + c], b = gpu.values[i * 4 + c]
                    if b > a + tolerance { grew += 1 }
                    startSum += Double(a)
                    endSum += Double(b)
                }
            }
            let bound = startSum * pow(Double(Dissipation.factor(d: d, dt: dt)), Double(steps))
                + Double(gpu.width * gpu.height * 3) * Double(tolerance)
            XCTAssertEqual(grew, 0, "fixture 2 \(precision): no cell grows")
            XCTAssertLessThanOrEqual(endSum, bound, "fixture 2 \(precision): total within the dissipation bound")
            print("fixture 2 \(precision): total \(startSum) → \(endSum) (bound \(bound)), cells grown \(grew)")
        }
    }

    /// Fixture 3: both boundary modes, both storages: no flow through walls on the GPU, open edges keep the flow, and
    /// the CPU reference reads nothing outside the grid.
    func testFixture3BoundaryModesNoOutOfGridReads() throws {
        let size = 16
        for mode in BoundaryMode.allCases {
            for fallback in [false, true] {
                var c = config(size: size, d: 0)
                c.boundaryMode = mode
                let scene = FluidFieldsScene(configuration: c, seed: .pattern, forceFallback: fallback)
                var v = FieldGrid(width: size, height: size, channels: 4)
                for cell in 0..<(size * size) { v.values[cell * 4] = -40; v.values[cell * 4 + 1] = 25 }
                scene.initialVelocityOverride = v
                scene.fixedDelta = 1.0 / 60
                let host = try host(scene)
                defer { host.destroy() }
                XCTAssertTrue(host.renderOneFrame(present: false))
                let precision = try XCTUnwrap(scene.precision)
                let gpu = try XCTUnwrap(scene.readVelocity())
                let step: Float = precision == .unorm8 ? 1.5 / 255 * scene.velocityRangeCellsPerSecond * 2 : 1e-3
                if mode == .walls {
                    for i in 0..<size {
                        XCTAssertEqual(gpu[0, i, 0], 0, accuracy: step)
                        XCTAssertEqual(gpu[i, size - 1, 1], 0, accuracy: step)
                    }
                } else {
                    XCTAssertLessThan(gpu[0, size / 2, 0], -30)
                }
                var log = FluidSolver.AccessLog()
                var vv = scene.initialVelocity().rounded(to: precision), dd = scene.initialDye().rounded(to: precision)
                let encodings = precision == .unorm8
                    ? try XCTUnwrap(FluidEncodings.unorm8(velocityRange: scene.velocityRangeCellsPerSecond)) : .none
                FluidSolver.step(velocity: &vv, dye: &dd, splats: [], configuration: scene.configuration,
                                 pressureIterations: scene.activePressureIterations, dt: 1.0 / 60, precision: precision,
                                 encodings: encodings, log: &log)
                XCTAssertGreaterThan(log.reads, 0)
                XCTAssertEqual(log.outOfGrid, 0, "fixture 3 \(mode) \(precision)")
            }
        }
    }

    /// Fixture 4: in the full playground (effects included) driven by the test-mode script, no field pass samples
    /// its own output over 10 frames.
    func testFixture4NoPassSamplesItsOutput() throws {
        let model = TestMode.makeModel(seed: 4, viewSize: CGSize(width: 100, height: 200))
        defer { model.close() }
        let host = try XCTUnwrap(model.host)
        XCTAssertTrue(host.renderOneFrame(present: false))
        var runs: [FieldPass.Run] = []
        FieldPass.runObserver = { runs.append($0) }
        for _ in 0..<10 { XCTAssertTrue(host.renderOneFrame(present: false)) }
        FieldPass.runObserver = nil
        let violations = runs.filter { !$0.outputIsFramebuffer && $0.inputs.values.contains($0.output) }
        XCTAssertGreaterThan(runs.count, 10 * 20, "every frame ran its passes")
        XCTAssertEqual(violations.count, 0, "fixture 4: \(violations)")
        print("fixture 4: \(runs.count) runs over 10 frames, \(model.scene.appliedSplats) splats, 0 sampled their output")
    }

    /// Fixture 5: suspend/resume causes bounded catch-up, not hundreds of solver steps.
    func testFixture5SuspendResumeBoundedCatchUp() throws {
        let scene = FluidFieldsScene(configuration: config(d: 1))
        let host = try host(scene)
        defer { host.destroy() }
        scene.fixedDelta = 1.0 / 60
        for _ in 0..<5 { XCTAssertTrue(host.renderOneFrame(present: false)) }
        XCTAssertEqual(scene.stepCount, 5)
        // (a) While suspended no frame renders and no step runs.
        host.pause()
        for _ in 0..<100 { XCTAssertFalse(host.renderOneFrame(present: false)) }
        XCTAssertEqual(scene.stepCount, 5)
        // (b) The first frame after resume runs exactly one step.
        host.resume()
        XCTAssertTrue(host.renderOneFrame(present: false))
        XCTAssertEqual(scene.stepCount, 6)
        // (c) Any delta — a 10-minute gap, zero, negative, not finite — is one step of 1/240…1/30 s.
        for delta in [600.0, 0, -1, .nan, .infinity] {
            let before = scene.stepCount
            scene.fixedDelta = delta
            XCTAssertTrue(host.renderOneFrame(present: false))
            XCTAssertEqual(scene.stepCount, before + 1, "delta \(delta): one step, no catch-up loop")
            XCTAssertGreaterThanOrEqual(scene.lastStep, 1.0 / 240, "delta \(delta)")
            XCTAssertLessThanOrEqual(scene.lastStep, 1.0 / 30, "delta \(delta)")
        }
        // (d) A paused scene stays paused through suspend and resume, with no step.
        scene.fixedDelta = 600
        scene.paused = true
        let before = scene.stepCount
        host.pause()
        host.resume()
        for _ in 0..<3 { XCTAssertTrue(host.renderOneFrame(present: false)) }
        XCTAssertEqual(scene.stepCount, before)
        XCTAssertTrue(scene.paused)
        XCTAssertNil(scene.lastError)
        print("fixture 5: steps \(scene.stepCount), last step \(scene.lastStep) s")
    }
}
