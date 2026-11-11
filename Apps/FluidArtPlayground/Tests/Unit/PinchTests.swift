// PinchTests — feature 022 T-A02-404 (FR-A02-404; SC-A02-402; US2 AC1–AC2; spec edge case; analyze C1).
import FluidArtPlaygroundCore
import VisualCoreMath
import VisualCoreScenes
import XCTest
@testable import FluidArtPlayground

@MainActor
final class PinchTests: XCTestCase {
    private func makeModel() throws -> PlaygroundModel {
        let model = PlaygroundModel()
        let host = try XCTUnwrap(model.host)
        host.view.frame = CGRect(x: 0, y: 0, width: 400, height: 800)
        host.view.layoutIfNeeded()
        return model
    }

    private func ev(_ id: Int, _ phase: PointerPhase, _ x: Double, _ y: Double, _ t: Double) -> PointerEvent {
        PointerEvent(id: id, phase: phase, location: Vec2(x, y), timestamp: t)
    }

    /// US2 AC1–AC2: spreading two fingers to twice their distance doubles the radius, and pinching makes no splats.
    func testPinchScalesTheBrushWithoutSplats() throws {
        let model = try makeModel()
        defer { model.close() }
        XCTAssertEqual(model.configuration.brushRadius, 0.04)
        model.handle(ev(1, .began, 100, 400, 0))
        model.handle(ev(2, .began, 300, 400, 0.01))
        XCTAssertTrue(model.pinching)
        let pending = model.queue.pendingCount
        for (i, x) in [350.0, 400, 450, 500].enumerated() {
            model.handle(ev(2, .moved, x, 400, 0.02 + Double(i) * 0.01))
            model.handle(ev(1, .moved, 100, 400, 0.025 + Double(i) * 0.01))
        }
        XCTAssertEqual(model.configuration.brushRadius, 0.08, accuracy: 0.08 * 0.01, "distance 200 → 400 doubles the radius")
        XCTAssertEqual(model.queue.pendingCount, pending, "pinching fingers make no splats")
        model.handle(ev(1, .ended, 100, 400, 0.2))
        model.handle(ev(2, .ended, 500, 400, 0.2))
        XCTAssertFalse(model.pinching)
        model.handle(ev(3, .began, 50, 50, 0.3))
        XCTAssertGreaterThan(model.queue.pendingCount, pending, "painting resumes with the next touch")
    }

    func testPinchIsClampedToTheBounds() throws {
        let model = try makeModel()
        defer { model.close() }
        model.handle(ev(1, .began, 190, 400, 0))
        model.handle(ev(2, .began, 210, 400, 0.01))
        model.handle(ev(2, .moved, 400, 400, 0.02))   // scale 10.5
        XCTAssertEqual(model.configuration.brushRadius, 0.25)
        model.handle(ev(2, .moved, 191, 400, 0.03))   // scale 0.05
        XCTAssertEqual(model.configuration.brushRadius, 0.005)
    }

    /// Edge case (analyze C1): a stroke in progress ends when the second finger lands.
    func testSecondFingerEndsAStroke() throws {
        let model = try makeModel()
        defer { model.close() }
        model.handle(ev(1, .began, 100, 100, 0))
        model.handle(ev(1, .moved, 150, 100, 0.02))
        let afterStroke = model.queue.pendingCount
        XCTAssertGreaterThan(afterStroke, 1)
        model.handle(ev(2, .began, 300, 300, 0.03))
        model.handle(ev(1, .moved, 200, 100, 0.04))
        model.handle(ev(1, .moved, 250, 100, 0.05))
        XCTAssertEqual(model.queue.pendingCount, afterStroke, "the first finger's stroke ended")
        XCTAssertEqual(model.queue.trackedPointers, 0)
    }
}
