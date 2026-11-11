// TouchAdapterTests — feature 006 T-F518 (FR-F502): touch samples → PointerEvents with stable ids,
// points and timestamps; window removal cancels active touches. Real UITouch delivery is exercised by
// the InteractiveDemo UI test (T-F520).
import UIKit
import VisualCoreMath
import VisualCoreScenes
import XCTest
@testable import VisualCoreRendering

@MainActor
final class TouchAdapterTests: XCTestCase {
    private final class Key {}

    func testStableIdsPhasesLocationsAndTimestamps() {
        let t = TouchTranslator()
        var events: [PointerEvent] = []
        t.handler = { events.append($0) }
        let a = Key(), b = Key()
        t.translate(.began, [(ObjectIdentifier(a), CGPoint(x: 10, y: 20), 1.0)])
        t.translate(.began, [(ObjectIdentifier(b), CGPoint(x: 50, y: 60), 1.1)])
        t.translate(.moved, [(ObjectIdentifier(a), CGPoint(x: 12.5, y: 21), 1.2), (ObjectIdentifier(b), CGPoint(x: 55, y: 66), 1.2)])
        t.translate(.ended, [(ObjectIdentifier(a), CGPoint(x: 13, y: 22), 1.3)])
        t.translate(.cancelled, [(ObjectIdentifier(b), CGPoint(x: 55, y: 66), 1.4)])
        XCTAssertEqual(events.map(\.id), [1, 2, 1, 2, 1, 2])
        XCTAssertEqual(events.map(\.phase), [.began, .began, .moved, .moved, .ended, .cancelled])
        XCTAssertEqual(events[2].location, Vec2(12.5, 21))
        XCTAssertEqual(events[4].timestamp, 1.3)
        XCTAssertEqual(t.activeCount, 0)
        let c = Key()
        t.translate(.began, [(ObjectIdentifier(c), .zero, 2)])
        XCTAssertEqual(events.last?.id, 3, "ids are not reused")
    }

    func testUnknownTouchesAreIgnoredAndCancelAllEndsActiveOnes() {
        let t = TouchTranslator()
        var events: [PointerEvent] = []
        t.handler = { events.append($0) }
        let a = Key(), b = Key(), ghost = Key()
        t.translate(.moved, [(ObjectIdentifier(ghost), .zero, 0)])
        XCTAssertTrue(events.isEmpty)
        t.translate(.began, [(ObjectIdentifier(a), .zero, 0), (ObjectIdentifier(b), .zero, 0)])
        t.cancelAll(timestamp: 5)
        XCTAssertEqual(events.suffix(2).map(\.phase), [.cancelled, .cancelled])
        XCTAssertEqual(events.suffix(2).map(\.id), [1, 2])
        XCTAssertEqual(t.activeCount, 0)
    }

    func testHostExposesHandlerAndFeedsRecognizers() throws {
        let host = try RenderHost(scene: ClearColorScene())
        XCTAssertFalse(host.view.isMultipleTouchEnabled)
        var tracker = PointerTracker(), pinch = PinchRecognizer()
        host.pointerHandler = { e in tracker.handle(e); pinch.handle(e, tracker: tracker) }
        XCTAssertTrue(host.view.isMultipleTouchEnabled)
        let a = Key(), b = Key()
        let translator = host.renderView.touchTranslator
        translator.translate(.began, [(ObjectIdentifier(a), CGPoint(x: 100, y: 100), 0), (ObjectIdentifier(b), CGPoint(x: 200, y: 100), 0)])
        translator.translate(.moved, [(ObjectIdentifier(b), CGPoint(x: 300, y: 100), 0.1)])
        XCTAssertEqual(pinch.state, .began)
        XCTAssertEqual(pinch.scale, 2, accuracy: 1e-12)
        host.pointerHandler = nil
        XCTAssertFalse(host.view.isMultipleTouchEnabled)
        host.destroy()
    }
}
