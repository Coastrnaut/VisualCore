// GrayScottToleranceTests — feature 118 (A16-P02) T-A16-205 (FR-A16-210; SC-A16-205; clarification Q4;
// contracts/gpu.md). The Gray-Scott tiny-grid fixture: the seeded 16 × 16 reaction-diffusion start is stepped 10 times
// with the Spots values (F 0.035, k 0.065, Δt 1) by ``GrayScottGPU`` in an RGBA16F ping-pong pair and by the CPU
// reference ``GrayScott`` rounded with `float16` and, separately, with `float16TowardZero` (GLES leaves the half
// rounding of colour writes implementation-defined). It passes when the largest |GPU − CPU| over every cell and both
// channels is at most 10 × 1e-3 = 0.01 against either reference, and reports both maxima. Without half-float render
// targets it fails with "Floating-point render targets are not available"; it never skips. The GL context comes from a
// `RenderHost` off screen whose scene runs the fixture inside one `renderOneFrame(present: false)`, with the context
// current on the main thread. One frame, a few milliseconds of work: far under 10 s.
import Foundation
import SimulationLabCore
import VisualCoreRendering
import VisualCoreSimulation
import XCTest
@testable import SimulationLabExperience

/// A scene that runs `body` inside `render`, with the context current.
@MainActor
private final class GrayScottFixtureScene: RenderScene {
    /// The work of the next frame.
    var body: ((RenderContext) throws -> Void)?
    func setup(_ context: RenderContext) throws {}
    func resize(_ context: RenderContext) {}
    func render(_ context: RenderContext, frame: FrameInfo) throws { try body?(context) }
    func teardown(_ context: RenderContext) {}
}

/// The Gray-Scott GPU step against the CPU reference.
@MainActor
final class GrayScottToleranceTests: XCTestCase {
    /// Cells per side.
    static let gridSize = 16
    /// The seed of the start.
    static let seed: UInt64 = 1
    /// Steps on each side.
    static let steps = 10
    /// The Spots preset: feed F.
    static let feed = 0.035
    /// The Spots preset: kill k.
    static let kill = 0.065
    /// The time step Δt.
    static let timeStep = 1.0
    /// One half-float storage step per step: 10 × 1e-3.
    static let tolerance: Float = 0.01

    /// The CPU reference after `steps` steps from `start`, each rounded to `precision`.
    private func reference(_ start: FieldGrid, precision: StoragePrecision) -> FieldGrid {
        var grid = start
        for _ in 0..<Self.steps {
            grid = GrayScott.step(grid, feed: Self.feed, kill: Self.kill, timeStep: Self.timeStep, precision: precision)
        }
        return grid
    }

    func testTenGPUStepsMatchTheCPUReferenceWithinTolerance() throws {
        let start = Seeding.reactionStart(gridSize: Self.gridSize, seed: Self.seed)
        XCTAssertEqual(start.width, Self.gridSize)
        XCTAssertEqual(start.height, Self.gridSize)
        XCTAssertEqual(start.channels, 2)

        let scene = GrayScottFixtureScene()
        let host = try RenderHost(scene: scene)
        host.view.frame = CGRect(x: 0, y: 0, width: 16, height: 16)
        host.view.layoutIfNeeded()
        defer { host.destroy() }

        var supported = false
        var loaded = false
        var stepCount = 0
        var gpuField: FieldGrid?
        var failure: Error?
        scene.body = { context in
            supported = FloatRenderSupport.detect(in: context.resources).supported
            guard supported else { return }
            do {
                let gpu = try GrayScottGPU(registry: context.resources, gridSize: Self.gridSize)
                defer { gpu.release() }
                loaded = gpu.load(start)
                guard loaded else { return }
                try gpu.step(feed: Float(Self.feed), kill: Float(Self.kill), timeStep: Float(Self.timeStep),
                             count: Self.steps)
                stepCount = gpu.stepCount
                gpuField = gpu.readBack()
            } catch {
                failure = error
            }
        }
        XCTAssertTrue(host.renderOneFrame(present: false), "the fixture frame ran")
        scene.body = nil

        guard supported else {
            XCTFail("Floating-point render targets are not available")
            return
        }
        XCTAssertNil(failure, "GrayScottGPU failed: \(String(describing: failure))")
        XCTAssertTrue(loaded, "the start was uploaded")
        XCTAssertEqual(stepCount, Self.steps)
        let gpu = try XCTUnwrap(gpuField, "the GPU field was read back")
        XCTAssertTrue(gpu.isFinite, "the GPU field is finite")

        let nearest = reference(start, precision: .float16)
        let towardZero = reference(start, precision: .float16TowardZero)
        // The fixture discriminates: ten steps move the field well beyond the tolerance, so a step that did nothing
        // cannot pass.
        let movement = try XCTUnwrap(nearest.maxAbsDifference(start))
        XCTAssertGreaterThan(movement, 10 * Self.tolerance, "ten CPU steps move the field")

        let nearestMax = try XCTUnwrap(gpu.maxAbsDifference(nearest))
        let towardZeroMax = try XCTUnwrap(gpu.maxAbsDifference(towardZero))
        let best = [nearestMax, towardZeroMax].filter { !$0.isNaN }.min() ?? .nan
        let report = "max |GPU − CPU| after \(Self.steps) steps on \(Self.gridSize) × \(Self.gridSize): "
            + "float16 = \(nearestMax), float16TowardZero = \(towardZeroMax), tolerance \(Self.tolerance)"
        XCTAssertTrue(best <= Self.tolerance, report)
        print("grayscott fixture: \(report)")
    }
}
