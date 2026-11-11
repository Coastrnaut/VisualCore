// StressTests — feature 023 T-A02-508 (FR-A02-507, SC-A02-505; US4 AC1–AC2; analyze A1; manual §13 risks 2 and 3).
import FluidArtPlaygroundCore
import VisualCoreMath
import VisualCoreRendering
import VisualCoreScenes
import VisualCoreSimulation
import XCTest
@testable import FluidArtPlayground

@MainActor
final class StressTests: XCTestCase {
    /// The aggressive script on the High grid: 10 pointers, maximum force (test mode), 80 pressure iterations.
    private func stress(fallback: Bool) throws {
        var base = FluidConfiguration()
        FluidDetail.high.apply(to: &base)
        base.pressureIterations = 80
        let model = TestMode.makeModel(seed: 11, script: TestMode.Script(pointers: 10, strokeSamples: 30, speed: 1_200),
                                       base: base, viewSize: CGSize(width: 150, height: 300), forceFallback: fallback)
        defer { model.close() }
        let host = try XCTUnwrap(model.host)
        let cap = model.scene.configuration.maxSplatsPerFrame
        var checks = 0
        var worst = FluidFieldsScene.FieldCheck()
        for frame in 1...600 {
            XCTAssertTrue(host.renderOneFrame(present: false))
            XCTAssertLessThanOrEqual(model.scene.lastDrained, cap, "frame \(frame)")
            if frame % 60 == 0 {
                let check = model.scene.fieldCheck()
                checks += 1
                XCTAssertNil(check.firstBad, "frame \(frame) \(fallback ? "RGBA8" : "half-float")")
                worst.maxVelocity = max(worst.maxVelocity, check.maxVelocity)
                worst.maxDye = max(worst.maxDye, check.maxDye)
                worst.maxPressure = max(worst.maxPressure, check.maxPressure)
            }
        }
        XCTAssertNil(model.scene.lastError)
        XCTAssertEqual(checks, 10)
        XCTAssertEqual(model.scene.configuration.gridWidth, 256)
        XCTAssertEqual(model.scene.activePressureIterations, 80)
        print("stress \(fallback ? "RGBA8" : "half-float"): 600 frames, \(model.scene.appliedSplats) splats, max |v| \(worst.maxVelocity) cells/s, max dye \(worst.maxDye), max |p| \(worst.maxPressure)")
    }

    func testStressHalfFloat() throws { try stress(fallback: false) }

    func testStressRGBA8() throws { try stress(fallback: true) }

    /// US4 AC2 / analyze A1: a touch flood (10 pointers × 30 samples in one frame) applies at most the cap per frame,
    /// and the queue stays within its bound.
    func testTouchFloodIsCapped() throws {
        let model = try XCTUnwrap(Optional(TestMode.makeModel(seed: 2, viewSize: CGSize(width: 150, height: 300))))
        defer { model.close() }
        model.beforeDrain = nil
        let host = try XCTUnwrap(model.host)
        XCTAssertTrue(host.renderOneFrame(present: false))
        let size = CGSize(width: 150, height: 300)
        for id in 0..<10 { model.paint(PointerEvent(id: id, phase: .began, location: Vec2(10, 10 + Double(id) * 25), timestamp: 1), viewSize: size) }
        for sample in 1...30 {
            for id in 0..<10 {
                model.paint(PointerEvent(id: id, phase: .moved, location: Vec2(10 + Double(sample) * 4, 10 + Double(id) * 25),
                                         timestamp: 1 + Double(sample) * 0.001), viewSize: size)
            }
        }
        let queued = model.queue.pendingCount
        XCTAssertGreaterThan(queued, model.scene.configuration.maxSplatsPerFrame, "the flood exceeds one frame's cap")
        XCTAssertLessThanOrEqual(queued, SplatQueue.maxPending)
        XCTAssertTrue(host.renderOneFrame(present: false))
        XCTAssertEqual(model.scene.lastDrained, model.scene.configuration.maxSplatsPerFrame, "exactly the cap applied")
        XCTAssertEqual(model.queue.pendingCount, 0, "the rest were dropped by the cap, not carried over")
        XCTAssertNil(model.scene.fieldCheck().firstBad)
    }

    /// T-A02-513 (edge case "a non-finite value appearing"; FR-A02-507): each detector fires on real field values,
    /// the automation check reports it, and nothing crashes.
    func testFieldCheckDetectsBadValues() throws {
        func scene(dye: SIMD4<Float>, velocity: (Int) -> SIMD2<Float>) throws -> (FluidFieldsScene, RenderHost) {
            var c = FluidConfiguration()
            c.gridWidth = 16
            c.gridHeight = 16
            let scene = FluidFieldsScene(configuration: c, seed: .uniform(dye))
            var v = FieldGrid(width: 16, height: 16, channels: 4)
            for cell in 0..<256 { let f = velocity(cell); v.values[cell * 4] = f.x; v.values[cell * 4 + 1] = f.y }
            scene.initialVelocityOverride = v
            scene.paused = true
            let host = try RenderHost(scene: scene)
            host.view.frame = CGRect(x: 0, y: 0, width: 32, height: 32)
            host.view.layoutIfNeeded()
            XCTAssertTrue(host.renderOneFrame(present: false))
            return (scene, host)
        }
        let cases: [(String, SIMD4<Float>, (Int) -> SIMD2<Float>, String)] = [
            ("NaN velocity", SIMD4(0.5, 0.5, 0.5, 1), { $0 == 37 ? SIMD2(.nan, 0) : .zero }, "velocity not finite at (5, 2)"),
            ("infinite dye", SIMD4(.infinity, 0.5, 0.5, 1), { _ in .zero }, "dye not finite at (0, 0)"),
            ("dye 5", SIMD4(5, 0.5, 0.5, 1), { _ in .zero }, "dye out of 0…4 at (0, 0)"),
            ("fast velocity", SIMD4(0.5, 0.5, 0.5, 1), { _ in SIMD2(2_000, 0) }, "moves past the grid at (0, 0)"),
        ]
        for (name, dye, velocity, expected) in cases {
            let (scene, host) = try scene(dye: dye, velocity: velocity)
            defer { host.destroy() }
            let check = scene.fieldCheck()
            XCTAssertFalse(check.passed, name)
            XCTAssertTrue(check.firstBad?.contains(expected) ?? false, "\(name): \(check.firstBad ?? "nil")")
            print("field check \(name): \(check.firstBad ?? "nil")")
        }
        // The automation check returns the same finding for a model whose fields went bad.
        let model = TestMode.makeModel(seed: 1, viewSize: CGSize(width: 100, height: 200))
        defer { model.close() }
        let host = try XCTUnwrap(model.host)
        var bad = FieldGrid(width: model.scene.configuration.gridWidth, height: model.scene.configuration.gridHeight, channels: 4)
        bad.values[0] = .nan
        model.scene.initialVelocityOverride = bad
        model.scene.paused = true
        host.recreateContext()
        XCTAssertTrue(host.renderOneFrame(present: false))
        XCTAssertEqual(AppAutomation.check(model), "velocity not finite at (0, 0)")
    }
}
