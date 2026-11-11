// ControlTests — feature 023 T-A02-504 (FR-A02-501–FR-A02-503; SC-A02-501; US1 AC2–AC4; analyze G2).
import FluidArtPlaygroundCore
import VisualCoreMath
import VisualCoreRendering
import VisualCoreScenes
import VisualCoreSimulation
import XCTest
@testable import FluidArtPlayground

@MainActor
final class ControlTests: XCTestCase {
    private func makeModel(fallback: Bool = false) throws -> PlaygroundModel {
        var c = FluidConfiguration()
        c.gridWidth = 32
        c.gridHeight = 32
        let model = PlaygroundModel(configuration: c, forceFallback: fallback)
        let host = try XCTUnwrap(model.host)
        host.view.frame = CGRect(x: 0, y: 0, width: 100, height: 200)
        host.view.layoutIfNeeded()
        model.scene.fixedDelta = 1.0 / 60
        return model
    }

    /// US1 AC2: Step runs exactly one step while paused; Step while running adds nothing extra.
    func testStepWhilePausedRunsExactlyOneStep() throws {
        let model = try makeModel()
        defer { model.close() }
        let host = try XCTUnwrap(model.host)
        XCTAssertTrue(host.renderOneFrame(present: false))
        XCTAssertEqual(model.scene.stepCount, 1)
        model.scene.paused = true
        for _ in 0..<3 { XCTAssertTrue(host.renderOneFrame(present: false)) }
        XCTAssertEqual(model.scene.stepCount, 1, "paused frames do not step")
        for i in 1...3 {
            model.scene.requestStep()
            XCTAssertTrue(host.renderOneFrame(present: false))
            XCTAssertEqual(model.scene.stepCount, 1 + i)
            XCTAssertTrue(host.renderOneFrame(present: false))
            XCTAssertEqual(model.scene.stepCount, 1 + i, "one step per request")
        }
        XCTAssertTrue(model.scene.paused, "Step keeps the pause")
        model.scene.paused = false
        model.scene.requestStep()
        XCTAssertTrue(host.renderOneFrame(present: false))
        XCTAssertEqual(model.scene.stepCount, 5, "while running a request adds no extra step")
        XCTAssertFalse(model.scene.stepRequested)
    }

    /// US1 AC3: touches made while paused are queued and applied by the next Step.
    func testTouchesWhilePausedApplyOnStep() throws {
        let model = try makeModel()
        defer { model.close() }
        let host = try XCTUnwrap(model.host)
        model.scene.paused = true
        XCTAssertTrue(host.renderOneFrame(present: false))
        model.handle(PointerEvent(id: 1, phase: .began, location: Vec2(20, 50), timestamp: 0))
        model.handle(PointerEvent(id: 1, phase: .moved, location: Vec2(40, 60), timestamp: 0.05))
        let queued = model.queue.pendingCount
        XCTAssertGreaterThan(queued, 0)
        for _ in 0..<3 { XCTAssertTrue(host.renderOneFrame(present: false)) }
        XCTAssertEqual(model.queue.pendingCount, queued, "nothing is lost or applied while paused")
        XCTAssertEqual(model.scene.appliedSplats, 0)
        model.scene.requestStep()
        XCTAssertTrue(host.renderOneFrame(present: false))
        XCTAssertEqual(model.scene.appliedSplats, queued)
        XCTAssertEqual(model.queue.pendingCount, 0)
    }

    /// US1 AC4 / SC-A02-501: Reset zeroes velocity and pressure, restores the seed and step count, keeps the pause.
    func testResetRestoresTheStartingFields() throws {
        for fallback in [false, true] {
            let model = try makeModel(fallback: fallback)
            defer { model.close() }
            let host = try XCTUnwrap(model.host)
            model.handle(PointerEvent(id: 1, phase: .began, location: Vec2(20, 50), timestamp: 0))
            model.handle(PointerEvent(id: 1, phase: .moved, location: Vec2(80, 150), timestamp: 0.05))
            for _ in 0..<10 { XCTAssertTrue(host.renderOneFrame(present: false)) }
            let moving = try XCTUnwrap(model.scene.readVelocity())
            XCTAssertGreaterThan(moving.values.map(abs).max() ?? 0, 0.5, "the stroke moved the fluid")
            model.scene.paused = true
            model.scene.resetFields()
            XCTAssertTrue(host.renderOneFrame(present: false))
            XCTAssertEqual(model.scene.stepCount, 0)
            XCTAssertTrue(model.scene.paused, "Reset keeps the pause")
            let velocity = try XCTUnwrap(model.scene.readVelocity())
            XCTAssertEqual(velocity.values.map(abs).max(), 0, "velocity exactly zero (fallback \(fallback))")
            let precision = try XCTUnwrap(model.scene.precision)
            let expected = model.scene.initialDye().rounded(to: precision)
            let dye = try XCTUnwrap(model.scene.readDye())
            XCTAssertLessThanOrEqual(try XCTUnwrap(dye.maxAbsDifference(expected)), precision.tolerance, "fallback \(fallback)")
            XCTAssertEqual(model.scene.resetCount, 1)
            XCTAssertEqual(host.resources.stats.leaked, 0)
        }
    }

    /// Analyze G2: a capture while paused after steps shows the stepped picture and does not step.
    func testCaptureAfterStepsDoesNotStep() throws {
        let model = try makeModel()
        defer { model.close() }
        let host = try XCTUnwrap(model.host)
        model.scene.paused = true
        for _ in 0..<2 {
            model.scene.requestStep()
            XCTAssertTrue(host.renderOneFrame(present: false))
        }
        XCTAssertEqual(model.scene.stepCount, 2)
        model.captureStill()
        guard case .done = model.capture.state else { return XCTFail("\(model.capture.state)") }
        XCTAssertEqual(model.scene.stepCount, 2)
        XCTAssertTrue(model.scene.paused)
    }

    /// T-A02-505 (analyze G3): Reset during a swipe ends that stroke (its later samples add nothing); painting resumes
    /// with the next touch. The model's controls follow SimulationControl and keep the pause.
    func testResetDuringSwipeEndsTheStroke() throws {
        let model = try makeModel()
        defer { model.close() }
        let host = try XCTUnwrap(model.host)
        model.togglePause()
        XCTAssertTrue(model.control.paused)
        XCTAssertTrue(model.scene.paused)
        model.handle(PointerEvent(id: 1, phase: .began, location: Vec2(20, 50), timestamp: 0))
        model.handle(PointerEvent(id: 1, phase: .moved, location: Vec2(40, 60), timestamp: 0.05))
        XCTAssertGreaterThan(model.queue.pendingCount, 0)
        model.resetCanvas()
        XCTAssertEqual(model.queue.pendingCount, 0, "queued touches are dropped")
        model.handle(PointerEvent(id: 1, phase: .moved, location: Vec2(60, 70), timestamp: 0.1))
        model.handle(PointerEvent(id: 1, phase: .ended, location: Vec2(70, 80), timestamp: 0.15))
        XCTAssertEqual(model.queue.pendingCount, 0, "the ended stroke adds nothing")
        XCTAssertTrue(host.renderOneFrame(present: false))
        XCTAssertEqual(model.scene.resetCount, 1)
        XCTAssertTrue(model.control.paused, "Reset keeps the pause")
        model.handle(PointerEvent(id: 2, phase: .began, location: Vec2(30, 30), timestamp: 0.2))
        XCTAssertGreaterThan(model.queue.pendingCount, 0, "a new touch paints again")
        model.step()
        XCTAssertTrue(host.renderOneFrame(present: false))
        XCTAssertEqual(model.scene.stepCount, 1)
        model.togglePause()
        XCTAssertFalse(model.scene.paused)
        model.step()
        XCTAssertFalse(model.scene.stepRequested, "Step does nothing while running")
    }

    /// T-A02-514 (US1 AC4): Reset keeps viscosity, palette, brush radius and detail.
    func testResetKeepsTuning() throws {
        let model = try makeModel()
        defer { model.close() }
        let host = try XCTUnwrap(model.host)
        XCTAssertTrue(host.renderOneFrame(present: false))
        model.configuration.viscosity = 0.4
        model.configuration.paletteID = "ink"
        model.configuration.brushRadius = 0.1
        model.setDetail(.low)
        XCTAssertTrue(host.renderOneFrame(present: false))
        let before = model.scene.configuration
        model.resetCanvas()
        XCTAssertTrue(host.renderOneFrame(present: false))
        XCTAssertEqual(model.scene.resetCount, 1)
        XCTAssertEqual(model.scene.configuration, before, "the scene's configuration is unchanged by Reset")
        XCTAssertEqual(model.configuration.viscosity, 0.4)
        XCTAssertEqual(model.configuration.paletteID, "ink")
        XCTAssertEqual(model.configuration.brushRadius, 0.1)
        XCTAssertEqual(model.detail, .low)
    }
}
