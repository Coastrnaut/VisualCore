// AquariumGestureTests — feature 070 (A09-P03) T-A09-305 (FR-A09-311; SC-A09-304; clarification 1; research D1). The
// canvas gestures with synthetic pointer events (timestamps in seconds, view 1600 × 900 points so the tank is drawn at
// 100 points per unit with no letterbox): a quick tap feeds at its point and never places or moves; a 0.6 s hold places
// and never feeds; a drag from a decor piece moves that piece along with the finger; a drag from water sends nothing;
// a 0.4 s hold sends nothing; a second finger stops a drag and nothing more is sent until every finger lifts; a touch in
// the letterbox clamps to the tank edge; reset forgets a drag in progress. Host-free and short.
import Foundation
import XCTest
@testable import DigitalAquariumExperience
import DigitalAquariumCore
import VisualCoreMath
import VisualCoreScenes
import VisualCoreSimulation

final class AquariumGestureTests: XCTestCase {
    private let catalog = SpeciesCatalog.bundled
    private let view = Vec2(1600, 900)
    private typealias Action = (control: String, values: [Double])

    /// The Reef starter with one piece of the first decor kind at the tank's centre (view point 800, 450).
    private func document() throws -> HabitatDocument {
        var random = SeededRandom(seed: 9)
        var doc = HabitatDocument.starter(0, catalog: catalog, random: &random)
        let kind = try XCTUnwrap(catalog.decor.first)
        doc.decor = [DecorPlacement(kindId: kind.id, position: Vec2(8, 4.5))]
        return doc
    }

    /// Feeds `events` (pointer id, phase, x, y, time) through `gestures` and collects every action.
    private func run(_ gestures: inout AquariumGestures, _ events: [(Int, PointerPhase, Double, Double, Double)],
                     document: HabitatDocument, view: Vec2? = nil) -> [Action] {
        events.flatMap { e in
            gestures.handle(PointerEvent(id: e.0, phase: e.1, location: Vec2(e.2, e.3), timestamp: e.4),
                            document: document, catalog: catalog, viewSize: view ?? self.view)
        }
    }

    private func assertValues(_ a: [Double], _ b: [Double], _ message: String = "", line: UInt = #line) {
        XCTAssertEqual(a.count, b.count, message, line: line)
        for (x, y) in zip(a, b) { XCTAssertEqual(x, y, accuracy: 1e-9, message, line: line) }
    }

    func testTheDeclarationsAndActions() {
        XCTAssertEqual(AquariumGestures.declarations.map(\.id), ["feed", "place", "move"])
        XCTAssertEqual(AquariumGestures.declarations.map(\.kind), [.tap, .longPress, .drag])
        XCTAssertEqual(AquariumGestures.declarations.map(\.priority), [1, 2, 3])
        XCTAssertEqual(AquariumGestures.declarations.map(\.pointers), [1, 1, 1])
        XCTAssertEqual(AquariumGestures.gestureActions, ["food.drop", "decor.place", "decor.move"])
    }

    func testAQuickTapFeedsAtItsPointAndNothingElse() throws {
        var g = AquariumGestures()
        let actions = run(&g, [(1, .began, 400, 225, 10.0), (1, .ended, 400, 225, 10.1)], document: try document())
        XCTAssertEqual(actions.map(\.control), ["food.drop"])
        // Tank (4, 6.75): x (400 − 800) / 100 + 8, y (450 − 225) / 100 + 4.5.
        assertValues(actions[0].values, [0.25, 0.75])
    }

    func testAHoldOfSixTenthsPlacesAtThePressPointAndNeverFeeds() throws {
        var g = AquariumGestures()
        let actions = run(&g, [(1, .began, 1200, 675, 3.0), (1, .ended, 1200, 675, 3.6)], document: try document())
        XCTAssertEqual(actions.map(\.control), ["decor.place"])
        // Tank (12, 2.25).
        assertValues(actions[0].values, [0.75, 0.25])
    }

    func testAHoldOfFourTenthsSendsNothing() throws {
        var g = AquariumGestures()
        let actions = run(&g, [(1, .began, 1200, 675, 3.0), (1, .ended, 1200, 675, 3.4)], document: try document())
        XCTAssertTrue(actions.isEmpty, "\(actions)")
    }

    func testADragFromAPieceMovesItWithTheFinger() throws {
        var g = AquariumGestures()
        let doc = try document()
        let actions = run(&g, [(1, .began, 800, 450, 1.0), (1, .moved, 805, 450, 1.02), (1, .moved, 815, 450, 1.04),
                               (1, .moved, 830, 450, 1.06), (1, .moved, 850, 450, 1.08), (1, .ended, 850, 450, 1.1)],
                          document: doc)
        XCTAssertEqual(actions.map(\.control), ["decor.move", "decor.move", "decor.move"])
        assertValues(actions[0].values, [0, 8.15 / 16, 0.5])
        assertValues(actions[1].values, [0, 8.3 / 16, 0.5])
        assertValues(actions[2].values, [0, 8.5 / 16, 0.5])
        XCTAssertNil(g.dragging, "the lift forgets the piece")
    }

    func testTheTopmostPieceIsMoved() throws {
        var g = AquariumGestures()
        var doc = try document()
        doc.decor.append(DecorPlacement(kindId: doc.decor[0].kindId, position: Vec2(8.1, 4.5)))
        let actions = run(&g, [(1, .began, 800, 450, 1.0), (1, .moved, 820, 450, 1.05)], document: doc)
        XCTAssertEqual(actions.map(\.control), ["decor.move"])
        XCTAssertEqual(actions.first?.values.first, 1)
    }

    func testADragFromWaterSendsNothing() throws {
        var g = AquariumGestures()
        let actions = run(&g, [(1, .began, 100, 100, 1.0), (1, .moved, 120, 100, 1.05), (1, .moved, 200, 150, 1.1),
                               (1, .ended, 200, 150, 1.2)], document: try document())
        XCTAssertTrue(actions.isEmpty, "\(actions)")
    }

    func testASecondFingerStopsADragUntilEveryFingerLifts() throws {
        var g = AquariumGestures()
        let doc = try document()
        let first = run(&g, [(1, .began, 800, 450, 1.0), (1, .moved, 830, 450, 1.05)], document: doc)
        XCTAssertEqual(first.map(\.control), ["decor.move"])
        let rest = run(&g, [(2, .began, 300, 300, 1.1), (1, .moved, 860, 450, 1.15), (2, .moved, 320, 300, 1.2),
                            (2, .ended, 320, 300, 1.25), (1, .moved, 900, 450, 1.3), (1, .ended, 900, 450, 1.35)],
                       document: doc)
        XCTAssertTrue(rest.isEmpty, "\(rest)")
        XCTAssertNil(g.dragging)
        // The next touch works again.
        let tap = run(&g, [(3, .began, 400, 225, 2.0), (3, .ended, 400, 225, 2.1)], document: doc)
        XCTAssertEqual(tap.map(\.control), ["food.drop"])
    }

    func testASecondFingerFailsAPendingLongPress() throws {
        var g = AquariumGestures()
        let actions = run(&g, [(1, .began, 1200, 675, 1.0), (2, .began, 300, 300, 1.2), (2, .ended, 300, 300, 1.3),
                               (1, .ended, 1200, 675, 1.7)], document: try document())
        XCTAssertTrue(actions.isEmpty, "\(actions)")
    }

    func testALetterboxTouchClampsToTheTankEdge() throws {
        var g = AquariumGestures()
        // 2000 × 900: scale 100, the tank spans x 200…1800.
        let actions = run(&g, [(1, .began, 50, 450, 1.0), (1, .ended, 50, 450, 1.1)], document: try document(),
                          view: Vec2(2000, 900))
        XCTAssertEqual(actions.map(\.control), ["food.drop"])
        assertValues(actions[0].values, [0, 0.5])
        XCTAssertEqual(AquariumGestures.fractions(view: Vec2(1990, -40), viewSize: Vec2(2000, 900)), [1, 1])
        XCTAssertNil(AquariumGestures.fractions(view: Vec2(1, 1), viewSize: Vec2(0, 0)))
    }

    func testResetForgetsADragInProgress() throws {
        var g = AquariumGestures()
        let doc = try document()
        XCTAssertEqual(run(&g, [(1, .began, 800, 450, 1.0), (1, .moved, 830, 450, 1.05)], document: doc).count, 1)
        XCTAssertEqual(g.dragging, 0)
        g.reset()
        XCTAssertNil(g.dragging)
        XCTAssertTrue(run(&g, [(1, .moved, 860, 450, 1.1), (1, .ended, 860, 450, 1.2)], document: doc).isEmpty)
        XCTAssertEqual(run(&g, [(2, .began, 400, 225, 2.0), (2, .ended, 400, 225, 2.1)], document: doc).map(\.control),
                       ["food.drop"])
    }
}
