// PlaygroundGestureTests — feature 084 (A11-P03) T-A11-303 (FR-A11-303; SC-A11-301; clarification 2; research D4;
// edge cases "Tap where a body already is", "Two fingers or a cancelled gesture", "A drag outside the stage"). The
// canvas gestures of Physics Playground with scripted pointer sequences (synthetic timestamps; no wall clock), each
// checking the exact actions sent through a recording port: the letterbox mapping and the hit test; a tap on the empty
// stage adds the picked shape there only after the double-tap window; a tap on a body selects it; a tap outside the
// stage does nothing; a drag on a body grabs it at the touch-down point, moves the target with the finger (clamped
// into the stage) and releases it; a drag elsewhere, on a fixed body or with a refused grab sends nothing more; a long
// press on a body pins it (on a frame tick or on an event); a double tap on a body deletes it without selecting it; a
// second finger or a cancelled touch releases the grab; a grab no finger owns is released by the next touch; reset
// forgets everything. Then, in the one app's session host on the simulator: the presenter's gestures reach the world
// through the shell's port, `gestureActions` all have native alternatives, and suspending through
// `PlaygroundExperience` releases a held body and forgets the gesture. Every test is short (well under 10 s).
import Foundation
import XCTest
@testable import PhysicsPlaygroundExperience
import PhysicsPlaygroundCore
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreRendering
import VisualCoreScenes
import VisualCoreSimulation

/// One action the gestures sent.
private struct Sent: Equatable, CustomStringConvertible {
    var control: String
    var values: [Double]
    var description: String { "\(control) \(values)" }
}

/// A recording port: every action is kept; the controls in `refused` are answered with a rule refusal.
private final class Recorder {
    var sent: [Sent] = []
    var refused: Set<String> = []

    func send(_ control: String, _ values: [Double]) -> ActionResult {
        sent.append(Sent(control: control, values: values))
        return refused.contains(control) ? .rejected(.rule(code: PlaygroundRule.notGrabbable)) : .accepted
    }
}

final class PlaygroundGestureTests: XCTestCase {
    /// 600 × 500 points: 50 points per metre for the 12 × 10 m view.
    private let view = Vec2(600, 500)
    private let world = PlaygroundCore(seed: 7).world
    private var gestures = PlaygroundGestures()
    private let port = Recorder()

    override func setUp() {
        super.setUp()
        gestures = PlaygroundGestures()
    }

    /// The view point of the stage point `p`.
    private func at(_ p: Vec2) -> Vec2 { PlaygroundGestures.viewPoint(stage: p, viewSize: view) }

    /// Feeds one event to the gestures against `world` (default: the starting scene) with the picked `kind`.
    private func touch(_ id: Int, _ phase: PointerPhase, _ location: Vec2, at time: Double,
                       world: PhysicsWorld? = nil, kind: BodyKind = .circle) {
        let event = PointerEvent(id: id, phase: phase, location: location, timestamp: time)
        gestures.handle(event, viewSize: view, world: world ?? self.world, kind: kind, send: port.send)
    }

    /// Advances the gestures' clock by `seconds` against `world` (default: the starting scene).
    private func advance(_ seconds: Double, world: PhysicsWorld? = nil) {
        gestures.advance(by: seconds, world: world ?? self.world, send: port.send)
    }

    /// Checks the actions sent so far against `expected` (values within 1e-9) and forgets them.
    private func expectSent(_ expected: [Sent], _ message: String, line: UInt = #line) {
        XCTAssertEqual(port.sent.map(\.control), expected.map(\.control), message, line: line)
        for (got, want) in zip(port.sent, expected) {
            XCTAssertEqual(got.values.count, want.values.count, "\(message): \(got)", line: line)
            for (a, b) in zip(got.values, want.values) {
                XCTAssertEqual(a, b, accuracy: 1e-9, "\(message): \(got) vs \(want)", line: line)
            }
        }
        port.sent = []
    }

    private func sent(_ control: String, _ values: [Double] = []) -> Sent { Sent(control: control, values: values) }

    /// The joined circle id 8 at (7, 1.5) m, radius 0.3 m, in every starting scene.
    private var circle: PhysicsBody { world.bodies[8] }

    func testTheMappingAndTheHitTest() throws {
        XCTAssertEqual(PlaygroundGestures.scale(viewSize: view), 50, accuracy: 1e-12)
        XCTAssertEqual(PlaygroundGestures.scale(viewSize: Vec2(390, 844)), 32.5, accuracy: 1e-12, "portrait")
        let centre = try XCTUnwrap(PlaygroundGestures.stagePoint(view: Vec2(300, 250), viewSize: view))
        XCTAssertEqual(centre, Vec2(5, 4), "the canvas centre is the stage centre")
        let corner = try XCTUnwrap(PlaygroundGestures.stagePoint(view: Vec2(50, 450), viewSize: view))
        XCTAssertEqual(corner.x, 0, accuracy: 1e-12, "the stage's bottom-left corner, y up")
        XCTAssertEqual(corner.y, 0, accuracy: 1e-12)
        for p in [Vec2(7, 1.5), Vec2(0.3, 7.9), Vec2(-0.5, 8.5)] {
            let back = try XCTUnwrap(PlaygroundGestures.stagePoint(view: at(p), viewSize: view))
            XCTAssertEqual((back - p).length, 0, accuracy: 1e-12)
        }
        XCTAssertNil(PlaygroundGestures.stagePoint(view: Vec2(1, 1), viewSize: Vec2(0, 0)))

        // Inside the circle, inside the rotated box (and not inside its unrotated corner), on nothing.
        XCTAssertEqual(PlaygroundGestures.body(at: Vec2(7.2, 1.6), in: world)?.id, 8)
        XCTAssertNil(PlaygroundGestures.body(at: Vec2(7.3, 1.8), in: world), "outside the circle's radius")
        let box = PhysicsBody(id: 3, shape: .box(halfExtents: Vec2(1, 0.2)), materialId: "wood",
                              position: Vec2(5, 5), angle: .pi / 2)
        XCTAssertTrue(PlaygroundGestures.contains(box, Vec2(5.1, 5.9)), "along the turned long side")
        XCTAssertFalse(PlaygroundGestures.contains(box, Vec2(5.9, 5.1)), "where the unturned box would be")
        XCTAssertNil(PlaygroundGestures.body(at: Vec2(4.5, 1.5), in: world))
        XCTAssertEqual(PlaygroundGestures.body(at: StartingScene.ledgeCenter, in: world)?.id, 0, "the static ledge")
        XCTAssertEqual(PlaygroundGestures.gestureActions,
                       ["edit.add", "edit.select", "edit.grab", "edit.move", "edit.release", "edit.pin",
                        "edit.delete"])
        XCTAssertEqual(PlaygroundGestures.doubleTapWindow, 0.3)
        XCTAssertEqual(PlaygroundGestures.declarations.map(\.priority), [4, 3, 2, 1],
                       "double tap > long press > drag > tap")
    }

    func testATapOnTheEmptyStageAddsThePickedShapeAfterTheDoubleTapWindow() {
        let spot = Vec2(4.5, 1.5)
        touch(1, .began, at(spot), at: 0, kind: .box)
        touch(1, .ended, at(spot) + Vec2(3, 2), at: 0.1, kind: .box)
        expectSent([], "nothing while the double-tap window is open")
        advance(0.25)
        expectSent([], "0.25 s after the lift the window is still open")
        advance(0.1)
        let lifted = PlaygroundGestures.stagePoint(view: at(spot) + Vec2(3, 2), viewSize: view) ?? .zero
        expectSent([sent("edit.add", [lifted.x, lifted.y, 1])], "a box added at the lift point")
        advance(1)
        expectSent([], "sent once")

        // The window also closes on the next event: a later touch elsewhere first sends the held tap.
        touch(2, .began, at(spot), at: 5)
        touch(2, .ended, at(spot), at: 5.05)
        touch(3, .began, at(Vec2(9, 4)), at: 5.5)
        expectSent([sent("edit.add", [spot.x, spot.y, 0])], "a circle, sent when the next touch lands")
        touch(3, .ended, at(Vec2(9, 4)), at: 5.55)
        advance(0.5)
        XCTAssertEqual(port.sent.map(\.control), ["edit.add"])
    }

    func testATapOnABodySelectsItAndATapOutsideTheStageDoesNothing() {
        touch(1, .began, at(circle.position), at: 0)
        touch(1, .ended, at(circle.position), at: 0.08)
        advance(0.4)
        expectSent([sent("edit.select", [8])], "the circle selected")

        touch(2, .began, at(Vec2(-0.5, 4)), at: 2)
        touch(2, .ended, at(Vec2(-0.5, 4)), at: 2.05)
        advance(0.5)
        expectSent([], "a tap on the wall, outside the stage")
        touch(3, .began, Vec2(5, 5), at: 3)
        touch(3, .ended, Vec2(5, 5), at: 3.05)
        advance(0.5)
        expectSent([], "a tap in the wall's corner")
    }

    func testADragOnABodyGrabsMovesAndReleasesIt() {
        let start = at(circle.position)
        touch(1, .began, start, at: 0)
        touch(1, .moved, start + Vec2(4, 0), at: 0.02)
        expectSent([], "under the drag's 10 points nothing starts")
        touch(1, .moved, start + Vec2(40, -20), at: 0.05)
        let first = circle.position + Vec2(0.8, 0.4)
        expectSent([sent("edit.grab", [8, 7, 1.5]), sent("edit.move", [first.x, first.y])],
                   "the grab at the touch-down point, then the target at the finger")
        touch(1, .moved, start + Vec2(90, -60), at: 0.1)
        touch(1, .moved, start + Vec2(500, 400), at: 0.15)
        let second = circle.position + Vec2(1.8, 1.2)
        expectSent([sent("edit.move", [second.x, second.y]), sent("edit.move", [10, 0])],
                   "every later move; outside the stage the target is clamped")
        touch(1, .ended, start + Vec2(500, 400), at: 0.2)
        expectSent([sent("edit.release")], "the lift releases")
        XCTAssertFalse(gestures.isGrabbing)
        advance(1)
        expectSent([], "nothing afterwards")
    }

    func testADragElsewhereOnAFixedBodyOrWithARefusedGrabSendsNothingMore() {
        // On the empty stage.
        touch(1, .began, at(Vec2(4.5, 1.5)), at: 0)
        touch(1, .moved, at(Vec2(5.5, 1.5)), at: 0.05)
        touch(1, .ended, at(Vec2(5.5, 1.5)), at: 0.1)
        // On the static ledge.
        touch(2, .began, at(StartingScene.ledgeCenter), at: 1)
        touch(2, .moved, at(StartingScene.ledgeCenter + Vec2(1, 1)), at: 1.05)
        touch(2, .ended, at(StartingScene.ledgeCenter + Vec2(1, 1)), at: 1.1)
        // On a pinned body.
        var pinned = world
        XCTAssertNil(WorldEditing.togglePin(&pinned, id: 8))
        touch(3, .began, at(circle.position), at: 2, world: pinned)
        touch(3, .moved, at(circle.position + Vec2(1, 1)), at: 2.05, world: pinned)
        touch(3, .ended, at(circle.position + Vec2(1, 1)), at: 2.1, world: pinned)
        advance(1)
        expectSent([], "no grab of the empty stage, a static or a pinned body")

        // A refused grab: nothing follows it.
        port.refused = ["edit.grab"]
        touch(4, .began, at(circle.position), at: 4)
        touch(4, .moved, at(circle.position + Vec2(1, 0)), at: 4.05)
        touch(4, .moved, at(circle.position + Vec2(2, 0)), at: 4.1)
        touch(4, .ended, at(circle.position + Vec2(2, 0)), at: 4.15)
        expectSent([sent("edit.grab", [8, 7, 1.5])], "only the refused grab")
    }

    func testALongPressOnABodyPinsIt() {
        touch(1, .began, at(circle.position), at: 0)
        advance(0.3)
        expectSent([], "not yet held for 0.5 s")
        advance(0.25)
        expectSent([sent("edit.pin", [8])], "pinned on the frame tick once held still for 0.5 s")
        touch(1, .moved, at(circle.position) + Vec2(30, 0), at: 0.7)
        touch(1, .ended, at(circle.position) + Vec2(30, 0), at: 0.8)
        advance(1)
        expectSent([], "nothing more until every finger lifts")

        // Recognized on an event too (a small move after 0.5 s), and on the empty stage nothing.
        touch(2, .began, at(circle.position), at: 3)
        touch(2, .moved, at(circle.position) + Vec2(2, 0), at: 3.6)
        touch(2, .ended, at(circle.position) + Vec2(2, 0), at: 3.7)
        expectSent([sent("edit.pin", [8])], "the second hold unpins (a toggle)")
        touch(3, .began, at(Vec2(4.5, 1.5)), at: 5)
        advance(0.7)
        touch(3, .ended, at(Vec2(4.5, 1.5)), at: 5.8)
        advance(1)
        expectSent([], "a hold on the empty stage")
    }

    func testADoubleTapOnABodyDeletesItWithoutSelectingIt() {
        touch(1, .began, at(circle.position), at: 0)
        touch(1, .ended, at(circle.position), at: 0.08)
        advance(0.1)
        touch(2, .began, at(circle.position) + Vec2(5, 5), at: 0.25)
        touch(2, .ended, at(circle.position) + Vec2(5, 5), at: 0.33)
        expectSent([sent("edit.delete", [8])], "deleted at the second lift")
        advance(1)
        expectSent([], "the first tap is never sent")

        // Two taps too far apart in time are a select each.
        touch(3, .began, at(circle.position), at: 3)
        touch(3, .ended, at(circle.position), at: 3.05)
        touch(4, .began, at(circle.position), at: 3.5)
        touch(4, .ended, at(circle.position), at: 3.55)
        advance(1)
        expectSent([sent("edit.select", [8]), sent("edit.select", [8])], "two single taps")
        // A double tap on the empty stage does nothing.
        touch(5, .began, at(Vec2(4.5, 1.5)), at: 6)
        touch(5, .ended, at(Vec2(4.5, 1.5)), at: 6.05)
        touch(6, .began, at(Vec2(4.5, 1.5)), at: 6.15)
        touch(6, .ended, at(Vec2(4.5, 1.5)), at: 6.2)
        advance(1)
        expectSent([], "no add and no delete")
    }

    func testASecondFingerOrACancelledTouchEndsTheGrab() {
        let start = at(circle.position)
        touch(1, .began, start, at: 0)
        touch(1, .moved, start + Vec2(40, 0), at: 0.05)
        XCTAssertTrue(gestures.isGrabbing)
        port.sent = []
        touch(2, .began, start + Vec2(100, 100), at: 0.1)
        expectSent([sent("edit.release")], "a second finger releases once")
        touch(1, .moved, start + Vec2(80, 0), at: 0.15)
        touch(2, .moved, start + Vec2(120, 100), at: 0.15)
        touch(2, .ended, start + Vec2(120, 100), at: 0.2)
        touch(1, .ended, start + Vec2(80, 0), at: 0.25)
        advance(1)
        expectSent([], "nothing until every finger lifted")
        XCTAssertFalse(gestures.isGrabbing)

        // Two fingers that tap together send nothing.
        touch(3, .began, start, at: 2)
        touch(4, .began, start + Vec2(60, 0), at: 2.01)
        touch(3, .ended, start, at: 2.05)
        touch(4, .ended, start + Vec2(60, 0), at: 2.06)
        advance(1)
        expectSent([], "a two-finger tap")

        // A cancelled touch (the view left the window) releases as a lift does.
        touch(5, .began, start, at: 4)
        touch(5, .moved, start + Vec2(0, -40), at: 4.05)
        port.sent = []
        touch(5, .cancelled, .zero, at: 4.1)
        expectSent([sent("edit.release")], "the cancel releases")
        XCTAssertFalse(gestures.isGrabbing)
    }

    func testAnUnownedGrabIsReleasedAndResetForgetsEverything() {
        var held = world
        XCTAssertNil(WorldEditing.grab(&held, id: 8, at: Vec2(7, 1.5)))
        touch(1, .began, at(Vec2(4.5, 1.5)), at: 0, world: held)
        expectSent([sent("edit.release")], "a grab no finger owns is released first")
        touch(1, .ended, at(Vec2(4.5, 1.5)), at: 0.05)

        // Reset in the middle of a drag and with a held tap: nothing is sent, and later gestures start afresh.
        advance(1)
        port.sent = []
        touch(2, .began, at(circle.position), at: 2)
        touch(2, .moved, at(circle.position) + Vec2(40, 0), at: 2.05)
        port.sent = []
        gestures.reset()
        XCTAssertFalse(gestures.isGrabbing)
        touch(2, .moved, at(circle.position) + Vec2(80, 0), at: 2.1)
        touch(2, .ended, at(circle.position) + Vec2(80, 0), at: 2.15)
        touch(3, .began, at(Vec2(4.5, 1.5)), at: 3)
        touch(3, .ended, at(Vec2(4.5, 1.5)), at: 3.05)
        gestures.reset()
        XCTAssertNil(gestures.pending)
        advance(1)
        expectSent([], "reset sends nothing and drops the held tap")
        touch(4, .began, at(circle.position), at: 6)
        touch(4, .ended, at(circle.position), at: 6.05)
        advance(0.5)
        expectSent([sent("edit.select", [8])], "a new tap works")
    }
}

// MARK: Presenter and session

@MainActor
final class PlaygroundGestureSessionTests: XCTestCase {
    /// The canvas size in points of `PlaygroundTest.open` (10 points per metre).
    private let view = Vec2(120, 100)

    private func at(_ p: Vec2) -> Vec2 { PlaygroundGestures.viewPoint(stage: p, viewSize: view) }

    private func touch(_ shell: ExperienceShell<PlaygroundPresenter>, _ id: Int, _ phase: PointerPhase, _ p: Vec2,
                       at time: Double) {
        shell.handlePointer(PointerEvent(id: id, phase: phase, location: p, timestamp: time), viewSize: view)
    }

    func testThePresenterDeclaresItsGesturesAndSendsThemThroughItsPort() async throws {
        let presenter = PlaygroundPresenter(experienceID: PlaygroundTest.id)
        XCTAssertEqual(presenter.gestureActions, PlaygroundCore.gestureActionIDs)
        XCTAssertTrue(presenter.gestureActions.isSubset(of: presenter.nativeActions))
        XCTAssertEqual(GestureAlternatives.missing(gesture: presenter.gestureActions, native: presenter.nativeActions),
                       [])
        // Before a state was seen nothing is sent.
        var sent: [String] = []
        presenter.pointer(PointerEvent(id: 1, phase: .began, location: at(Vec2(7, 1.5)), timestamp: 0),
                          viewSize: view) { control, _ in sent.append(control); return .accepted }
        XCTAssertEqual(sent, [])
        // With a drawn world the shape picker's kind goes into an add.
        presenter.sync(PlaygroundCore(seed: 7))
        presenter.mirror.shapeKind = BodyKind.box.rawValue
        var values: [[Double]] = []
        let record: PlaygroundGestures.Send = { control, value in
            sent.append(control)
            values.append(value)
            return .accepted
        }
        presenter.pointer(PointerEvent(id: 2, phase: .began, location: at(Vec2(4.5, 1.5)), timestamp: 1),
                          viewSize: view, send: record)
        presenter.pointer(PointerEvent(id: 2, phase: .ended, location: at(Vec2(4.5, 1.5)), timestamp: 1.05),
                          viewSize: view, send: record)
        presenter.advanceGestures(by: 0.5, send: record)
        XCTAssertEqual(sent, ["edit.add"])
        XCTAssertEqual(values.last?.last, 1, "a box")

        // In a session: tap, drag, hold and double tap reach the world through the shell's port.
        let session = ExperienceSession()
        let shell = try await PlaygroundTest.open(session)
        XCTAssertTrue(shell.handle(control: "world.pause", values: [1]).isAccepted)
        try PlaygroundTest.frames(session, 1)
        touch(shell, 1, .began, at(Vec2(4.5, 1.5)), at: 0)
        touch(shell, 1, .ended, at(Vec2(4.5, 1.5)), at: 0.05)
        try PlaygroundTest.frames(session, 25)
        var core = try PlaygroundTest.core(shell)
        XCTAssertEqual(core.world.bodies.count, 11, "a tap on the empty stage added a circle")
        let added = try XCTUnwrap(core.world.bodies.last)
        XCTAssertEqual((added.position - Vec2(4.5, 1.5)).length, 0, accuracy: 1e-9)

        touch(shell, 2, .began, at(Vec2(7, 1.5)), at: 2)
        touch(shell, 2, .moved, at(Vec2(7, 1.5)) + Vec2(20, -20), at: 2.05)
        core = try PlaygroundTest.core(shell)
        XCTAssertEqual(core.world.grab?.bodyId, 8, "a drag on the circle grabs it")
        XCTAssertEqual(core.world.grab?.target ?? .zero, Vec2(9, 3.5))
        touch(shell, 2, .ended, at(Vec2(7, 1.5)) + Vec2(20, -20), at: 2.1)
        XCTAssertNil(try PlaygroundTest.core(shell).world.grab, "the lift releases")

        touch(shell, 3, .began, at(Vec2(8, 1.5)), at: 4)
        try PlaygroundTest.frames(session, 40)
        touch(shell, 3, .ended, at(Vec2(8, 1.5)), at: 4.8)
        XCTAssertTrue(try XCTUnwrap(try PlaygroundTest.core(shell).world.bodies.first { $0.id == 9 }).pinned,
                      "a long press pins")

        touch(shell, 4, .began, at(Vec2(4.5, 1.5)), at: 6)
        touch(shell, 4, .ended, at(Vec2(4.5, 1.5)), at: 6.05)
        touch(shell, 5, .began, at(Vec2(4.5, 1.5)), at: 6.15)
        touch(shell, 5, .ended, at(Vec2(4.5, 1.5)), at: 6.2)
        try PlaygroundTest.frames(session, 25)
        core = try PlaygroundTest.core(shell)
        XCTAssertFalse(core.world.bodies.contains { $0.id == added.id }, "a double tap deleted the added circle")
        XCTAssertNil(core.world.selectedId, "without selecting it first")
        XCTAssertTrue(shell.accessibilitySummary.contains("1 pinned"), shell.accessibilitySummary)
        session.close()
    }

    func testSuspendingReleasesAHeldBodyAndForgetsTheGesture() async throws {
        let id = PlaygroundTest.id
        var made: PlaygroundExperience?
        let session = ExperienceSession()
        let request = ExperienceOpenRequest(id: id, seed: 7, snapshot: nil, refusedSnapshotFails: false) {
            let experience = PlaygroundExperience(shell: PhysicsPlaygroundExperience.make(id: id))
            made = experience
            return experience
        }
        let opened = await session.open(request)
        XCTAssertEqual(opened, .running)
        if let host = session.renderHost?.view {
            host.frame = CGRect(x: 0, y: 0, width: 120, height: 100)
            host.layoutIfNeeded()
        }
        let experience = try XCTUnwrap(made)
        let shell = experience.shell
        try PlaygroundTest.frames(session, 1)
        XCTAssertTrue(experience.handle(control: "world.pause", values: [1]).isAccepted)
        try PlaygroundTest.frames(session, 1)
        experience.handlePointer(PointerEvent(id: 1, phase: .began, location: at(Vec2(7, 1.5)), timestamp: 0),
                                 viewSize: view)
        experience.handlePointer(PointerEvent(id: 1, phase: .moved, location: at(Vec2(7, 1.5)) + Vec2(20, 0),
                                              timestamp: 0.05), viewSize: view)
        XCTAssertEqual(try PlaygroundTest.core(shell).world.grab?.bodyId, 8)
        XCTAssertTrue(experience.presenter.gestures.isGrabbing)

        session.setScenePhase(.background)
        XCTAssertEqual(experience.state, .suspended)
        XCTAssertNil(try PlaygroundTest.core(shell).world.grab, "the suspension let the body go")
        XCTAssertFalse(experience.presenter.gestures.isGrabbing, "the gesture is forgotten")
        session.setScenePhase(.active)
        XCTAssertEqual(experience.state, .active)
        experience.handlePointer(PointerEvent(id: 1, phase: .moved, location: at(Vec2(7, 1.5)) + Vec2(40, 0),
                                              timestamp: 1), viewSize: view)
        XCTAssertNil(try PlaygroundTest.core(shell).world.grab, "a finger from before the suspension moves nothing")
        session.close()
    }
}
