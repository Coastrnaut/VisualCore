// PlaygroundModelTests — feature 020 T-A02-213 (FR-A02-208; analyze C1): pointer events on the canvas become capped
// splats that reach the fields; the splash control does the same without a gesture.
import FluidArtPlaygroundCore
import VisualCoreRendering
import VisualCoreMath
import VisualCoreScenes
import XCTest
@testable import FluidArtPlayground

@MainActor
final class PlaygroundModelTests: XCTestCase {
    private func makeModel() throws -> (PlaygroundModel, RenderHostRef) {
        let model = PlaygroundModel()
        let host = try XCTUnwrap(model.host)
        host.view.frame = CGRect(x: 0, y: 0, width: 400, height: 800)
        host.view.layoutIfNeeded()
        model.scene.fixedDelta = 1.0 / 60
        return (model, RenderHostRef(host: host))
    }

    func testPointerEventsBecomeAppliedSplats() throws {
        let (model, ref) = try makeModel()
        defer { model.close() }
        XCTAssertEqual(model.spacing, 0.04 * 400 / 2, accuracy: 1e-9)
        model.handle(PointerEvent(id: 1, phase: .began, location: Vec2(100, 400), timestamp: 0))
        model.handle(PointerEvent(id: 1, phase: .moved, location: Vec2(300, 400), timestamp: 0.1))
        XCTAssertGreaterThan(model.queue.pendingCount, 1)
        XCTAssertTrue(ref.host.renderOneFrame(present: false))
        XCTAssertEqual(model.scene.lastDrained, min(17, model.scene.configuration.maxSplatsPerFrame), "capped per frame")
        XCTAssertEqual(model.scene.appliedSplats, model.scene.lastDrained)
        XCTAssertEqual(model.queue.pendingCount, 0)
        XCTAssertGreaterThan(model.queue.dropped, 0, "the excess over the cap is counted")
        XCTAssertNil(model.scene.lastError)
    }

    func testCancelledTouchQueuesNothingMore() throws {
        let (model, _) = try makeModel()
        defer { model.close() }
        model.handle(PointerEvent(id: 4, phase: .began, location: Vec2(10, 10), timestamp: 0))
        model.handle(PointerEvent(id: 4, phase: .cancelled, location: Vec2(50, 10), timestamp: 0.05))
        XCTAssertEqual(model.queue.pendingCount, 1, "only the began sample")
        XCTAssertEqual(model.queue.trackedPointers, 0)
        model.handle(PointerEvent(id: 4, phase: .moved, location: Vec2(90, 10), timestamp: 0.1))
        XCTAssertEqual(model.queue.pendingCount, 1)
    }

    /// T-A02-216: the queue converts forces with the grid the fields really use, also when setup capped it.
    func testQueueFollowsSetUpGrid() throws {
        var c = FluidConfiguration()
        c.gridWidth = 256
        c.gridHeight = 256
        let model = PlaygroundModel(configuration: c, maxEdge: 64)
        defer { model.close() }
        XCTAssertEqual(model.scene.configuration.gridWidth, 64)
        XCTAssertEqual(model.queue.configuration.gridWidth, 64)
        XCTAssertEqual(model.queue.configuration.gridHeight, 64)
    }

    func testSplashIsQueuedAppliedAndDescribed() throws {
        let (model, ref) = try makeModel()
        defer { model.close() }
        model.addSplash()
        XCTAssertEqual(model.splashes, 1)
        XCTAssertTrue(model.description.hasSuffix("1 splash added"))
        XCTAssertTrue(ref.host.renderOneFrame(present: false))
        XCTAssertEqual(model.scene.appliedSplats, 1)
    }
}

/// Keeps the host reachable in tests without copying the model's optional.
@MainActor
struct RenderHostRef {
    let host: VisualCoreRendering.RenderHost
}
