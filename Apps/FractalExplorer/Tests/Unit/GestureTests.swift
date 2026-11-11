// GestureTests — feature 027 T-A03-205 (FR-A03-202, SC-A03-201; US1 AC2–AC4; manual Phase 02 fixture: a centered pinch
// keeps the selected complex coordinate stationary).
import FractalExplorerCore
import VisualCoreMath
import VisualCoreScenes
import XCTest
@testable import FractalExplorer

@MainActor
final class GestureTests: XCTestCase {
    private func ev(_ id: Int, _ phase: PointerPhase, _ x: Double, _ y: Double, _ t: Double) -> PointerEvent {
        PointerEvent(id: id, phase: phase, location: Vec2(x, y), timestamp: t)
    }

    private func model() -> ExplorerModel {
        let m = ExplorerModel(size: Vec2(300, 400))
        m.close()   // gestures are pure model logic; no rendering needed
        return m
    }

    func testCenteredPinchKeepsTheCoordinateStationary() {
        let m = model()
        let mid = Vec2(140, 220)
        let fixed = m.state.viewport.plane(fromScreen: mid)
        m.handle(ev(1, .began, 120, 220, 0))
        m.handle(ev(2, .began, 160, 220, 0))
        var t = 0.0
        for d in stride(from: 22.0, through: 140, by: 6) {   // spread symmetrically about the midpoint
            t += 0.016
            m.handle(ev(1, .moved, 140 - d, 220, t))
            m.handle(ev(2, .moved, 140 + d, 220, t))
            let now = m.state.viewport.plane(fromScreen: mid)
            XCTAssertLessThan(now.distance(to: fixed) / fixed.length, 1e-9)
            XCTAssertLessThan(m.state.viewport.screen(fromPlane: fixed).distance(to: mid), 1, "within 1 pt on screen")
        }
        XCTAssertGreaterThan(m.state.zoom, 6, "fingers spread from 40 to 280 pt: 7×")
        m.handle(ev(1, .ended, 0, 220, t))
        m.handle(ev(2, .ended, 280, 220, t))
    }

    func testMovingPinchFollowsTheFingers() {
        let m = model()
        m.handle(ev(1, .began, 100, 200, 0))
        m.handle(ev(2, .began, 200, 200, 0))
        let under = m.state.viewport.plane(fromScreen: Vec2(150, 200))
        // Both fingers move right by 30 and spread by 20: the midpoint moves to (180, 200).
        m.handle(ev(1, .moved, 120, 200, 0.02))
        m.handle(ev(2, .moved, 240, 200, 0.02))
        XCTAssertLessThan(m.state.viewport.screen(fromPlane: under).distance(to: Vec2(180, 200)), 1)
    }

    func testDragMovesExactlyWithTheFinger() {
        let m = model()
        let grabbed = m.state.viewport.plane(fromScreen: Vec2(50, 60))
        m.handle(ev(1, .began, 50, 60, 0))
        m.handle(ev(1, .moved, 80, 40, 0.02))
        m.handle(ev(1, .moved, 95, 10, 0.04))
        XCTAssertLessThan(m.state.viewport.screen(fromPlane: grabbed).distance(to: Vec2(95, 10)), 1e-9)
        m.handle(ev(1, .ended, 95, 10, 0.06))
    }

    func testLiftingAFingerMidPinchDoesNotJump() {
        let m = model()
        m.handle(ev(1, .began, 100, 200, 0))
        m.handle(ev(2, .began, 200, 200, 0))
        m.handle(ev(1, .moved, 90, 200, 0.02))
        m.handle(ev(2, .moved, 210, 200, 0.02))
        m.handle(ev(1, .ended, 90, 200, 0.04))
        let before = m.state.viewport
        let under = before.plane(fromScreen: Vec2(210, 200))
        m.handle(ev(2, .moved, 230, 220, 0.06))   // the remaining finger pans from where it is
        XCTAssertFalse(m.pinching)
        XCTAssertLessThan(m.state.viewport.screen(fromPlane: under).distance(to: Vec2(230, 220)), 1e-9, "no jump")
        XCTAssertEqual(m.state.viewport.unitsPerPoint, before.unitsPerPoint, "no zoom change")
    }

    func testControlsZoomAndReset() {
        let m = model()
        let center = m.state.viewport.center
        m.zoomIn()
        XCTAssertEqual(m.state.zoom, 2, accuracy: 1e-12)
        XCTAssertEqual(m.state.viewport.center, center, "zoom about the middle keeps the center")
        m.zoomOut(); m.zoomOut()
        XCTAssertEqual(m.state.zoom, 0.5, accuracy: 1e-12)
        m.apply(m.state.viewport.panned(by: Vec2(40, 40)))
        m.resetView()
        XCTAssertEqual(m.state.zoom, 1, accuracy: 1e-12)
        XCTAssertEqual(m.state.viewport.center, Vec2(-0.5, 0))
    }
}
