// FloatFieldToleranceTests — feature 119 (A16-P03) T-A16-304 (FR-A16-301, FR-A16-302; SC-A16-301; clarification Q2;
// contracts/gpu.md). Both float families against their CPU reference on the GPU: the seeded 16 × 16 start of
// reaction-diffusion (Spots, Δt 1) and of the wave (Pulse: c 1, Δt 0.5, γ 0.002) is stepped 10 times by
// ``GrayScottGPU`` or ``WaveGPU`` in an RGBA16F pair and by ``GrayScott`` / ``WaveField`` rounded with `float16` and,
// separately, `float16TowardZero`. A family passes when the smaller of the two maxima of |GPU − CPU| is at most 0.01.
// Without half-float render targets it fails with "Floating-point render targets are not available"; it never skips.
// One off-screen frame per family, a few milliseconds of work.
import Foundation
import SimulationLabCore
import VisualCoreRendering
import VisualCoreSimulation
import XCTest
@testable import SimulationLabExperience

/// A scene that runs `body` inside `render`, with the context current.
@MainActor
final class FloatFixtureScene: RenderScene {
    /// The work of the next frame.
    var body: ((RenderContext) throws -> Void)?
    func setup(_ context: RenderContext) throws {}
    func resize(_ context: RenderContext) {}
    func render(_ context: RenderContext, frame: FrameInfo) throws { try body?(context) }
    func teardown(_ context: RenderContext) {}
}

/// Runs `work` in one off-screen frame; fails the test when floating-point targets are missing.
@MainActor
func withFloatContext(_ work: @escaping (ResourceRegistry) throws -> Void) throws {
    let scene = FloatFixtureScene()
    let host = try RenderHost(scene: scene)
    host.view.frame = CGRect(x: 0, y: 0, width: 16, height: 16)
    host.view.layoutIfNeeded()
    defer { host.destroy() }
    var supported = false
    var failure: Error?
    scene.body = { context in
        supported = FloatRenderSupport.detect(in: context.resources).supported
        guard supported else { return }
        do { try work(context.resources) } catch { failure = error }
    }
    XCTAssertTrue(host.renderOneFrame(present: false), "the fixture frame ran")
    scene.body = nil
    guard supported else {
        XCTFail("Floating-point render targets are not available")
        return
    }
    XCTAssertNil(failure, "the GPU work failed: \(String(describing: failure))")
}

/// The float families on the GPU against the CPU reference.
@MainActor
final class FloatFieldToleranceTests: XCTestCase {
    static let gridSize = 16
    static let seed: UInt64 = 1
    static let steps = 10
    static let tolerance: Float = 0.01
    /// The wave's Pulse preset: Courant number c · Δt = 1 · 0.5 and damping 0.002.
    static let courant = 0.5
    static let damping = 0.002

    /// The smaller of the two maxima, with a report.
    private func best(_ gpu: FieldGrid, _ nearest: FieldGrid, _ towardZero: FieldGrid, _ name: String) throws
        -> (Float, String) {
        let a = try XCTUnwrap(gpu.maxAbsDifference(nearest))
        let b = try XCTUnwrap(gpu.maxAbsDifference(towardZero))
        let report = "\(name): max |GPU − CPU| after \(Self.steps) steps on \(Self.gridSize) × \(Self.gridSize): "
            + "float16 = \(a), float16TowardZero = \(b), tolerance \(Self.tolerance)"
        return ([a, b].filter { !$0.isNaN }.min() ?? .nan, report)
    }

    func testReactionDiffusionMatchesWithinTolerance() throws {
        let start = Seeding.reactionStart(gridSize: Self.gridSize, seed: Self.seed)
        var gpuField: FieldGrid?
        try withFloatContext { registry in
            let gpu = try GrayScottGPU(registry: registry, gridSize: Self.gridSize)
            defer { gpu.release() }
            XCTAssertTrue(gpu.load(start))
            try gpu.step(feed: 0.035, kill: 0.065, timeStep: 1, count: Self.steps)
            gpuField = gpu.readBack()
        }
        let gpu = try XCTUnwrap(gpuField)
        func reference(_ precision: StoragePrecision) -> FieldGrid {
            var grid = start
            for _ in 0..<Self.steps {
                grid = GrayScott.step(grid, feed: 0.035, kill: 0.065, timeStep: 1, precision: precision)
            }
            return grid
        }
        let (value, report) = try best(gpu, reference(.float16), reference(.float16TowardZero), "reaction-diffusion")
        XCTAssertTrue(value <= Self.tolerance, report)
        print("float fixture: \(report)")
    }

    func testTheWaveMatchesWithinTolerance() throws {
        let start = Seeding.waveStart(gridSize: Self.gridSize, seed: Self.seed)
        var gpuField: SimulationField?
        try withFloatContext { registry in
            let gpu = try WaveGPU(registry: registry, gridSize: Self.gridSize)
            defer { gpu.release() }
            XCTAssertTrue(gpu.load(SimulationField(current: start, previous: start)))
            try gpu.step(courant: Float(Self.courant), damping: Float(Self.damping), count: Self.steps)
            XCTAssertEqual(gpu.stepCount, Self.steps)
            gpuField = gpu.readBack()
        }
        let gpu = try XCTUnwrap(gpuField).current
        func reference(_ precision: StoragePrecision) -> FieldGrid {
            var current = start, previous = start
            for _ in 0..<Self.steps {
                let next = WaveField.step(current: current, previous: previous, courant: Self.courant,
                                          damping: Self.damping, precision: precision)
                previous = current
                current = next
            }
            return current
        }
        let nearest = reference(.float16)
        let movement = try XCTUnwrap(nearest.maxAbsDifference(start))
        XCTAssertGreaterThan(movement, 10 * Self.tolerance, "ten CPU steps move the wave")
        let (value, report) = try best(gpu, nearest, reference(.float16TowardZero), "wave")
        XCTAssertTrue(value <= Self.tolerance, report)
        print("float fixture: \(report)")
    }
}
