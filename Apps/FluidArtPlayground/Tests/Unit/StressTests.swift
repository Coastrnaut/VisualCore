// StressTests — feature 023 T-A02-508 (FR-A02-507, SC-A02-505; US4 AC1–AC2; analyze A1; manual §13 risks 2 and 3).
import FluidArtPlaygroundCore
import VisualCoreMath
import VisualCoreRendering
import VisualCoreScenes
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
}
