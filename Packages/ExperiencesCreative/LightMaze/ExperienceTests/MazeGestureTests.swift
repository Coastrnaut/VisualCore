// MazeGestureTests — feature 097 (A13-P02) T-A13-203 (FR-A13-201–204; SC-A13-201–203; clarifications Q1–Q3, Q2 as
// amended). `MazeGestures` fed with synthetic pointer events against a real `MazeCore` (a recording `send` applies
// each action to it), on a view of 40 points per cell with the board's y axis pointing up the screen; host-only, no
// GPU, each test well under a second: taps select then turn a turnable tile and refuse everything else in words; drags
// snap to the diagonal nearest their direction from 0.35 cell on, only for the tile they started on; two-finger
// rotations over the selected tile turn it once per 45° crossed; the arbiter keeps a rotation from also dragging;
// `reset()` forgets every touch; every action sent is a native one; the presenter's view → board mapping inverts its
// camera.
import Foundation
import XCTest
@testable import LightMazeExperience
import LightMazeCore
import VisualCoreExperience
import VisualCoreMath
import VisualCoreScenes

/// A core, the gestures and a recorder: board points in, actions and words out.
private final class GestureRig {
    /// View points per board cell.
    static let pointsPerCell = 40.0

    var core: MazeCore
    var gestures = MazeGestures()
    /// Every action sent, as "control" or "control [v, …]".
    var sent: [String] = []
    /// Every refusal in words, in order.
    var words: [String] = []
    private var clock = 100.0
    private var nextID = 1

    init(level: Int) throws {
        core = try mazeCore(MazeState(levelIndex: level))
    }

    var height: Double { Double(core.board.height) * Self.pointsPerCell }

    /// The view point (points, top-left origin) of the board point (x, y).
    func view(_ x: Double, _ y: Double) -> Vec2 {
        Vec2(x * Self.pointsPerCell, height - y * Self.pointsPerCell)
    }

    /// The board point of the view point `point`.
    func board(_ point: Vec2) -> Vec2? {
        Vec2(point.x / Self.pointsPerCell, (height - point.y) / Self.pointsPerCell)
    }

    /// Applies an action to the core and records it.
    @discardableResult
    func send(_ control: String, _ values: [Double]) -> ActionResult {
        var text = control
        if !values.isEmpty {
            var parts: [String] = []
            for value in values { parts.append(String(Int(value))) }
            text += " [" + parts.joined(separator: ", ") + "]"
        }
        sent.append(text)
        return core.apply(ExperienceAction(control: control, values: values, step: 0))
    }

    /// Feeds one event at the view point `at`.
    func event(_ id: Int, _ phase: PointerPhase, at point: Vec2) {
        clock += 0.02
        let event = PointerEvent(id: id, phase: phase, location: point, timestamp: clock)
        let answer = gestures.handle(event, state: { self.core.state }, toBoard: { self.board($0) },
                                     send: { control, values in self.send(control, values) })
        if let answer { words.append(answer) }
    }

    /// Feeds one event at the board point (x, y).
    func event(_ id: Int, _ phase: PointerPhase, _ x: Double, _ y: Double) {
        event(id, phase, at: view(x, y))
    }

    /// A new pointer id.
    func finger() -> Int {
        nextID += 1
        return nextID
    }

    /// A tap at the board point (x, y).
    func tap(_ x: Double, _ y: Double) {
        let id = finger()
        event(id, .began, x, y)
        event(id, .ended, x, y)
    }

    /// A one-finger drag from (x, y) through each board offset of `path` (from the start), then lifted.
    func drag(from x: Double, _ y: Double, through path: [Vec2]) {
        let id = finger()
        event(id, .began, x, y)
        var last = Vec2(x, y)
        for offset in path {
            last = Vec2(x + offset.x, y + offset.y)
            event(id, .moved, last.x, last.y)
        }
        event(id, .ended, last.x, last.y)
    }

    /// The orientation of the tile at index `tile` of the board.
    func orientation(_ tile: Int) -> Orientation? { core.board.tiles[tile].orientation }
}

final class MazeGestureTests: XCTestCase {
    // lm-01: 5 × 5; wall (2, 0), emitter (0, 2) east, mirror (2, 2) `\` (tile 2, turnable 0), target (2, 4).

    func testATapSelectsATurnableTileThenTurnsIt() throws {
        let rig = try GestureRig(level: 0)
        rig.tap(2.5, 2.5)
        XCTAssertEqual(rig.sent, ["tile.select [0]"])
        XCTAssertEqual(rig.core.state.selection, 0)
        XCTAssertEqual(rig.orientation(2), .backslash, "selecting turns nothing")
        rig.tap(2.2, 2.9)
        XCTAssertEqual(rig.sent, ["tile.select [0]", "tile.turn"], "anywhere in the selected tile's cell turns it")
        XCTAssertEqual(rig.orientation(2), .slash)
        XCTAssertTrue(rig.core.isSolved, "level 1 solved by touch")
        XCTAssertEqual(rig.words, [])
        rig.tap(2.5, 2.5)
        XCTAssertEqual(rig.orientation(2), .backslash, "and back")
    }

    func testATapOnAPrismOfALaterLevelSelectsItsTurnableIndex() throws {
        let rig = try GestureRig(level: 15)
        let board = rig.core.board
        let indices = board.turnableIndices
        XCTAssertGreaterThan(indices.count, 1)
        for (position, tile) in indices.enumerated() {
            let center = board.tiles[tile].cell.center
            rig.tap(center.x, center.y)
            XCTAssertEqual(rig.sent.last, "tile.select [\(position)]", "\(board.tiles[tile].kind) \(position)")
            XCTAssertEqual(rig.core.state.selection, position)
        }
    }

    func testTapsElsewhereChangeNothingAndAreAnsweredInWords() throws {
        let rig = try GestureRig(level: 0)
        let before = rig.core
        let fixed: [Vec2] = [Vec2(1.5, 1.5), Vec2(2.5, 0.5), Vec2(0.5, 2.5), Vec2(2.5, 4.5), Vec2(4.99, 4.99)]
        for point in fixed { rig.tap(point.x, point.y) }
        let outside: [Vec2] = [Vec2(-0.5, 2.5), Vec2(5.2, 2.5), Vec2(2.5, -0.01), Vec2(2.5, 5.5)]
        for point in outside { rig.tap(point.x, point.y) }
        XCTAssertEqual(rig.sent, [], "no action")
        XCTAssertEqual(rig.core, before, "nothing on the board changed")
        var expected: [String] = []
        for _ in fixed { expected.append("Nothing to turn there.") }
        for _ in outside { expected.append("Outside the board.") }
        XCTAssertEqual(rig.words, expected)
    }

    func testTheSnapTargetFollowsTheDirectionAndTheDistance() {
        let r = MazeGestures.snapDistance
        XCTAssertEqual(r, 0.35)
        XCTAssertNil(MazeGestures.target(of: Vec2(0.349, 0)), "below the snap distance")
        XCTAssertNil(MazeGestures.target(of: Vec2(0.2, 0.2)), "0.28 cell")
        XCTAssertNil(MazeGestures.target(of: Vec2(Double.nan, 1)))
        XCTAssertEqual(MazeGestures.target(of: Vec2(0.35, 0)), .backslash, "east: exactly 45° from both")
        let cases: [(degrees: Double, expected: Orientation)] = [
            (45, .slash), (225, .slash), (1, .slash), (89, .slash), (181, .slash), (269, .slash),
            (135, .backslash), (315, .backslash), (91, .backslash), (179, .backslash), (271, .backslash),
            (359, .backslash), (0, .backslash), (90, .backslash), (180, .backslash), (270, .backslash),
        ]
        for item in cases {
            let angle = item.degrees * Double.pi / 180
            let vector = Vec2(cos(angle) * 0.5, sin(angle) * 0.5)
            let exact = Vec2(abs(vector.x) < 1e-9 ? 0 : vector.x, abs(vector.y) < 1e-9 ? 0 : vector.y)
            XCTAssertEqual(MazeGestures.target(of: exact), item.expected, "\(item.degrees)°")
        }
    }

    func testADragSnapsToTheNearestDiagonalAndBackWhenItCrossesOver() throws {
        let rig = try GestureRig(level: 0)
        let id = rig.finger()
        rig.event(id, .began, 2.5, 2.5)
        rig.event(id, .moved, 2.7, 2.7)   // 11.3 points: the drag begins, 0.28 cell: no snap yet
        XCTAssertTrue(rig.gestures.isDragging)
        XCTAssertEqual(rig.sent, [])
        rig.event(id, .moved, 2.8, 2.8)   // 0.42 cell north-east: `/`
        XCTAssertEqual(rig.sent, ["tile.select [0]", "tile.turn"])
        XCTAssertEqual(rig.orientation(2), .slash)
        rig.event(id, .moved, 3.5, 3.4)   // still north-east: nothing more
        XCTAssertEqual(rig.sent.count, 2)
        rig.event(id, .moved, 3.2, 1.8)   // now south-east of the touch-down point: back to `\`
        XCTAssertEqual(rig.sent, ["tile.select [0]", "tile.turn", "tile.select [0]", "tile.turn"])
        XCTAssertEqual(rig.orientation(2), .backslash)
        rig.event(id, .ended, 3.2, 1.8)
        XCTAssertFalse(rig.gestures.isDragging)
        XCTAssertEqual(rig.words, [])
    }

    func testDragsInEveryDirectionLandOnTheNearestDiagonal() throws {
        let directions: [(name: String, offset: Vec2, expected: Orientation)] = [
            ("north-east", Vec2(0.4, 0.4), .slash), ("south-west", Vec2(-0.4, -0.4), .slash),
            ("north-west", Vec2(-0.4, 0.4), .backslash), ("south-east", Vec2(0.4, -0.4), .backslash),
            ("mostly north, a little east", Vec2(0.05, 0.6), .slash),
            ("mostly north, a little west", Vec2(-0.05, 0.6), .backslash),
            ("east", Vec2(0.6, 0), .backslash), ("south", Vec2(0, -0.6), .backslash),
        ]
        let starts: [Orientation] = [.backslash, .slash]
        for start in starts {
            for direction in directions {
                let rig = try GestureRig(level: 0)
                if start == .slash {
                    rig.send("tile.select", [0])
                    rig.send("tile.turn", [])
                    rig.sent = []
                }
                rig.drag(from: 2.5, 2.5, through: [direction.offset])
                let name = "\(direction.name) from \(start.symbol)"
                XCTAssertEqual(rig.orientation(2), direction.expected, name)
                XCTAssertEqual(rig.sent, start == direction.expected ? [] : ["tile.select [0]", "tile.turn"], name)
            }
        }
    }

    func testADragShorterThanTheSnapDistanceChangesNothing() throws {
        let rig = try GestureRig(level: 0)
        rig.drag(from: 2.5, 2.5, through: [Vec2(0.3, 0), Vec2(0.2, 0.2), Vec2(0.34, 0)])
        XCTAssertEqual(rig.sent, [])
        XCTAssertEqual(rig.orientation(2), .backslash)
        XCTAssertEqual(rig.core.state.selection, MazeState.noSelection)
    }

    func testADragThatBeginsElsewhereDoesNothing() throws {
        let rig = try GestureRig(level: 0)
        let before = rig.core
        rig.drag(from: 1.5, 2.5, through: [Vec2(0.5, 0), Vec2(1.0, 0.3), Vec2(1.4, 0.6)])   // across the mirror
        rig.drag(from: 2.5, 4.5, through: [Vec2(0, -1), Vec2(0.4, -2)])   // from the target onto the mirror
        rig.drag(from: -0.4, 2.5, through: [Vec2(1, 0), Vec2(3, 0.4)])   // from outside the board
        XCTAssertEqual(rig.sent, [])
        XCTAssertEqual(rig.core, before)
        XCTAssertEqual(rig.words, ["Nothing to turn there.", "Nothing to turn there.", "Outside the board."])
    }

    func testADragOnlyAffectsTheTileWhereItStarted() throws {
        // lm-02: mirrors (0, 2) `/` (tile 0, turnable 0) and (0, 3) `\` (tile 2, turnable 1).
        let rig = try GestureRig(level: 1)
        XCTAssertEqual(rig.orientation(0), .slash)
        XCTAssertEqual(rig.orientation(2), .backslash)
        // North over (0, 3), then on off the board.
        rig.drag(from: 0.5, 2.5, through: [Vec2(0, 0.6), Vec2(0.1, 1.2), Vec2(4, 6)])
        XCTAssertEqual(rig.sent, ["tile.select [0]", "tile.turn", "tile.select [0]", "tile.turn"],
                       "north (`\\`), then north-east (`/`)")
        XCTAssertEqual(rig.orientation(0), .slash)
        XCTAssertEqual(rig.orientation(2), .backslash, "the tile it crossed is untouched")
    }

    /// Two fingers 20 points either side of the board point (x, y), then turned by each angle (degrees, from the
    /// start) in `angles`, both fingers moving, then lifted.
    private func twist(_ rig: GestureRig, at x: Double, _ y: Double, angles: [Double]) {
        let a = rig.finger(), b = rig.finger()
        let center = rig.view(x, y)
        func point(_ degrees: Double, _ side: Double) -> Vec2 {
            let angle = degrees * Double.pi / 180
            return Vec2(center.x + side * 20 * cos(angle), center.y + side * 20 * sin(angle))
        }
        rig.event(a, .began, at: point(0, -1))
        rig.event(b, .began, at: point(0, 1))
        var last = 0.0
        for degrees in angles {
            rig.event(a, .moved, at: point(degrees, -1))
            rig.event(b, .moved, at: point(degrees, 1))
            last = degrees
        }
        rig.event(a, .ended, at: point(last, -1))
        rig.event(b, .ended, at: point(last, 1))
    }

    func testARotationOverTheSelectedTileTurnsItOncePerSnapAngle() throws {
        let rig = try GestureRig(level: 0)
        rig.send("tile.select", [0])
        rig.sent = []
        twist(rig, at: 2.5, 2.5, angles: [10, 30, 44])
        XCTAssertEqual(rig.sent, [], "less than 45° changes nothing")
        XCTAssertEqual(rig.orientation(2), .backslash)

        twist(rig, at: 2.5, 2.5, angles: [20, 40, 50])
        XCTAssertEqual(rig.sent, ["tile.turn"], "one turn at 45°")
        XCTAssertEqual(rig.orientation(2), .slash)

        rig.sent = []
        twist(rig, at: 2.5, 2.5, angles: [30, 60, 95, 120, 40])
        XCTAssertEqual(rig.sent, ["tile.turn", "tile.turn", "tile.turn"],
                       "45° and 90° turning one way, then 50° back from the last snap")
        rig.sent = []
        twist(rig, at: 2.5, 2.5, angles: [-20, -46])
        XCTAssertEqual(rig.sent, ["tile.turn"], "the other way too")
        XCTAssertEqual(rig.words, [])
    }

    func testARotationAwayFromTheSelectedTileOrWithNothingSelectedDoesNothing() throws {
        let rig = try GestureRig(level: 0)
        let before = rig.core
        twist(rig, at: 2.5, 2.5, angles: [30, 60, 90])
        XCTAssertEqual(rig.sent, [])
        XCTAssertEqual(rig.core, before)
        XCTAssertEqual(rig.words, ["Select a mirror or prism first."])
        rig.send("tile.select", [0])
        rig.sent = []
        twist(rig, at: 1.5, 1.5, angles: [30, 60, 90])
        XCTAssertEqual(rig.sent, [])
        XCTAssertEqual(rig.orientation(2), .backslash)
        XCTAssertEqual(rig.words, ["Select a mirror or prism first.", "Twist over the selected tile."])
    }

    func testTheArbiterLetsARotationWinOverADrag() throws {
        let rig = try GestureRig(level: 0)
        rig.send("tile.select", [0])
        rig.sent = []
        // Both fingers land on the selected mirror; the first then slides 0.9 cell north, which turns the pair.
        let a = rig.finger(), b = rig.finger()
        rig.event(a, .began, 2.3, 2.5)
        rig.event(b, .began, 2.7, 2.5)
        rig.event(a, .moved, 2.3, 3.4)
        XCTAssertFalse(rig.gestures.isDragging, "a second finger keeps the drag from starting")
        XCTAssertTrue(rig.gestures.isTwisting)
        rig.event(a, .ended, 2.3, 3.4)
        rig.event(b, .ended, 2.7, 2.5)
        // atan(0.9 / 0.4) ≈ 66°: one turn by rotation, none by dragging.
        XCTAssertEqual(rig.sent, ["tile.turn"])
    }

    func testResetForgetsEveryTouch() throws {
        let rig = try GestureRig(level: 0)
        let id = rig.finger()
        rig.event(id, .began, 2.5, 2.5)
        rig.event(id, .moved, 2.7, 2.7)
        XCTAssertTrue(rig.gestures.isDragging)
        rig.gestures.reset()
        XCTAssertFalse(rig.gestures.isDragging)
        rig.event(id, .moved, 3.2, 3.2)
        rig.event(id, .ended, 3.2, 3.2)
        XCTAssertEqual(rig.sent, [], "the forgotten drag sends nothing")
        rig.tap(2.5, 2.5)
        XCTAssertEqual(rig.sent, ["tile.select [0]"], "a fresh touch works at once")
    }

    func testEveryGestureActionHasANativeControl() throws {
        XCTAssertEqual(MazeGestures.gestureActions, ["tile.select", "tile.turn"])
        XCTAssertTrue(MazeGestures.gestureActions.isSubset(of: Set(MazeCore.actionIDs)))
        XCTAssertEqual(GestureAlternatives.missing(gesture: MazeGestures.gestureActions,
                                                   native: Set(MazeCore.actionIDs)), [])
        let rig = try GestureRig(level: 0)
        rig.tap(2.5, 2.5)
        rig.drag(from: 2.5, 2.5, through: [Vec2(0.5, 0.5)])
        rig.send("tile.select", [0])
        twist(rig, at: 2.5, 2.5, angles: [50])
        XCTAssertGreaterThan(rig.sent.count, 3)
        for text in rig.sent {
            let control = String(text.split(separator: " ").first ?? "")
            XCTAssertTrue(MazeGestures.gestureActions.contains(control), text)
        }
    }

    func testThePresentersViewToBoardMappingInvertsItsCamera() throws {
        let board = MazeState.initial.board
        let viewSize = Vec2(120, 100)
        let canvas = Vec2(360, 300)
        let points: [Vec2] = [Vec2(2.5, 2.5), Vec2(0, 0), Vec2(5, 5), Vec2(1.25, 3.75), Vec2(-0.4, 5.4)]
        for point in points {
            let pixel = MazePresenter.pixel(of: point, board: board, canvas: canvas)
            let view = Vec2(pixel.x * viewSize.x / canvas.x, viewSize.y - pixel.y * viewSize.y / canvas.y)
            let back = try XCTUnwrap(MazePresenter.boardPoint(view: view, viewSize: viewSize, canvas: canvas,
                                                              board: board))
            XCTAssertEqual(back.x, point.x, accuracy: 1e-9, "\(point)")
            XCTAssertEqual(back.y, point.y, accuracy: 1e-9, "\(point)")
        }
        let centre = try XCTUnwrap(MazePresenter.boardPoint(view: Vec2(60, 50), viewSize: viewSize, canvas: canvas,
                                                            board: board))
        XCTAssertEqual(centre.x, 2.5, accuracy: 1e-9, "the view's centre is the board's")
        XCTAssertEqual(centre.y, 2.5, accuracy: 1e-9)
        let upper = try XCTUnwrap(MazePresenter.boardPoint(view: Vec2(60, 40), viewSize: viewSize, canvas: canvas,
                                                           board: board))
        XCTAssertGreaterThan(upper.y, 2.5, "up the screen is north")
        XCTAssertNil(MazePresenter.boardPoint(view: Vec2(.nan, 1), viewSize: viewSize, canvas: canvas, board: board))
        XCTAssertNil(MazePresenter.boardPoint(view: Vec2(1, 1), viewSize: Vec2(0, 100), canvas: canvas, board: board))
    }
}
