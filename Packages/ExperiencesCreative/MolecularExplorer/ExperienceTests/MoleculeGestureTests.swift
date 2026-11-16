// MoleculeGestureTests — feature 112 (A15-P03) T-A15-305 (FR-A15-301, FR-A15-302; clarification Q1; SC-A15-302; edge
// cases "Very small or fast gestures" and "A suspension or teardown during a gesture"). The canvas gestures of
// Molecular Explorer with synthetic pointer events, short runs only (each test well under 10 s, no wall-clock
// assertion): a 150-point drag to the right sends three `camera.orbit [−1]` steps (the molecule follows the finger)
// and leaves the same state as pressing Turn left three times; a drag down or up sends `camera.tilt` steps every 33⅓
// points; spreading two fingers zooms in one step per 1 / 0.85 of the distance and pinching zooms out; moving two
// fingers pans one step per 40 points so the molecule follows them (it is drawn farther right after a move right);
// tiny movements send nothing; `reset()` in the middle of a gesture sends nothing more and the next touch starts anew.
import Foundation
import XCTest
@testable import MolecularExplorerExperience
import MolecularExplorerCore
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreScenes

/// The canvas gestures of Molecular Explorer.
@MainActor
final class MoleculeGestureTests: XCTestCase {
    /// Records the actions a gesture sends and accepts them all.
    private final class Recorder {
        var sent: [(String, [Double])] = []
        func send(_ control: String, _ values: [Double]) -> ActionResult {
            sent.append((control, values))
            return .accepted
        }
        var controls: [String] { sent.map(\.0) }
    }

    /// The view size in points of the drawn tests.
    private let viewSize = Vec2(240, 160)

    private func event(_ id: Int, _ phase: PointerPhase, _ x: Double, _ y: Double, _ t: Double) -> PointerEvent {
        PointerEvent(id: id, phase: phase, location: Vec2(x, y), timestamp: t)
    }

    /// Plays `events` on `gestures`, recording into `recorder` and counting taps.
    private func play(_ events: [PointerEvent], on gestures: inout MoleculeGestures, _ recorder: Recorder) -> Int {
        var taps = 0
        for item in events {
            gestures.handle(item, send: { recorder.send($0, $1) }, tap: { _ in taps += 1 })
        }
        return taps
    }

    /// A one-finger drag from (`x`, `y`) by (`dx`, `dy`) in `count` equal moves, starting at time `t`.
    private func drag(_ x: Double, _ y: Double, dx: Double, dy: Double, count: Int, t: Double) -> [PointerEvent] {
        var events = [event(1, .began, x, y, t)]
        for k in 1...count {
            let f = Double(k) / Double(count)
            events.append(event(1, .moved, x + dx * f, y + dy * f, t + 0.02 * Double(k)))
        }
        events.append(event(1, .ended, x + dx, y + dy, t + 0.02 * Double(count + 1)))
        return events
    }

    func testTheThresholds() {
        XCTAssertEqual(MoleculeGestures.orbitPoints, 50, accuracy: 1e-12)
        XCTAssertEqual(MoleculeGestures.tiltPoints, 100.0 / 3, accuracy: 1e-12)
        XCTAssertEqual(MoleculeGestures.panPoints, 40)
        XCTAssertEqual(MoleculeGestures.zoomRatio, 0.85)
        XCTAssertEqual(MoleculeGestures.declarations.map(\.priority), [3, 2, 1])
    }

    func testADragRightOf150PointsSendsThreeTurnSteps() {
        var gestures = MoleculeGestures()
        let recorder = Recorder()
        let taps = play(drag(40, 80, dx: 150, dy: 0, count: 15, t: 0), on: &gestures, recorder)
        XCTAssertEqual(recorder.controls, ["camera.orbit", "camera.orbit", "camera.orbit"])
        for entry in recorder.sent { XCTAssertEqual(entry.1, [-1], "the molecule turns right under the finger") }
        XCTAssertEqual(taps, 0, "a drag is not a tap")
        XCTAssertFalse(gestures.isDragging)
        let left = Recorder()
        _ = play(drag(200, 80, dx: -100, dy: 0, count: 10, t: 1), on: &gestures, left)
        XCTAssertEqual(left.sent.map(\.1), [[1], [1]], "dragging left turns the other way")
    }

    func testADragThroughTheSessionEqualsPressingTurnLeftThreeTimes() async throws {
        let session = ExperienceSession()
        let shell = try await MoleculeTest.open(session)
        XCTAssertTrue(shell.handle(control: "molecule.select", values: [4]).isAccepted)
        try MoleculeTest.frames(session, 1)
        for item in drag(40, 80, dx: 150, dy: 0, count: 15, t: 0) { shell.handlePointer(item, viewSize: viewSize) }
        let dragged = try MoleculeTest.core(shell).state
        var pressed = MoleculeCore(seed: 1)
        _ = pressed.apply(ExperienceAction(control: "molecule.select", values: [4], step: 0))
        for _ in 0..<3 { _ = pressed.apply(ExperienceAction(control: "camera.orbit", values: [-1], step: 0)) }
        XCTAssertEqual(dragged, pressed.state, "the same state as the Turn left button three times")
        XCTAssertEqual(dragged.camera.turnSteps, 23)
        session.close()
    }

    /// T-A15-313: a finger down when the experience is suspended is forgotten (the shell calls `cancelPointers()`;
    /// the touch's own cancellation is dropped while suspended), so after resuming a new one-finger drag turns the
    /// molecule instead of being read as a second finger.
    func testASuspensionForgetsAFingerThatWasDown() async throws {
        let session = ExperienceSession()
        let shell = try await MoleculeTest.open(session)
        try MoleculeTest.frames(session, 1)
        let held = [event(7, .began, 200, 40, 0), event(7, .moved, 185, 40, 0.02), event(7, .moved, 170, 40, 0.04)]
        for item in held { shell.handlePointer(item, viewSize: viewSize) }
        let before = try MoleculeTest.core(shell).state
        XCTAssertEqual(before.camera.turnSteps, 2, "30 points of drag send no step yet")
        session.setScenePhase(.background)
        XCTAssertEqual(shell.state, .suspended)
        session.setScenePhase(.active)
        XCTAssertEqual(shell.state, .active)
        for item in drag(40, 80, dx: 150, dy: 0, count: 15, t: 1) { shell.handlePointer(item, viewSize: viewSize) }
        let after = try MoleculeTest.core(shell).state
        XCTAssertEqual(after.camera.turnSteps, 23, "three turn steps: the old finger was forgotten")
        XCTAssertEqual(after.camera.zoomSteps, before.camera.zoomSteps, "no pinch was seen")
        XCTAssertEqual(after.camera.panX, 0)
        session.close()
    }

    func testAVerticalDragSendsTiltSteps() {
        var gestures = MoleculeGestures()
        let down = Recorder()
        _ = play(drag(100, 20, dx: 0, dy: 110, count: 11, t: 0), on: &gestures, down)
        XCTAssertEqual(down.controls, ["camera.tilt", "camera.tilt", "camera.tilt"], "110 points: three 10° steps")
        for entry in down.sent { XCTAssertEqual(entry.1, [1], "dragging down raises the eye") }
        let up = Recorder()
        _ = play(drag(100, 140, dx: 0, dy: -40, count: 4, t: 1), on: &gestures, up)
        XCTAssertEqual(up.sent.map(\.1), [[-1]])
    }

    func testAPinchZoomsInAndOutInSteps() {
        var gestures = MoleculeGestures()
        let recorder = Recorder()
        var events = [event(1, .began, 100, 80, 0), event(2, .began, 140, 80, 0.01)]
        events.append(event(2, .moved, 150, 80, 0.03))   // 50 points: ratio 1.25, one step in
        events.append(event(2, .moved, 160, 80, 0.05))   // 60 points: anchor 47.06; 60 × 0.85 = 51 < 55.4, no more
        _ = play(events, on: &gestures, recorder)
        XCTAssertEqual(recorder.sent.map(\.0), ["camera.zoom", "camera.zoom"])
        XCTAssertEqual(recorder.sent.map(\.1), [[1], [1]], "spreading the fingers zooms in")
        XCTAssertTrue(gestures.isTwoFinger)
        let out = Recorder()
        _ = play([event(2, .moved, 130, 80, 0.07)], on: &gestures, out)  // 30 points from the anchor 55.36
        XCTAssertEqual(out.sent.map(\.1), [[-1], [-1], [-1]], "pinching zooms out")
        let lift = Recorder()
        _ = play([event(2, .ended, 130, 80, 0.09), event(1, .ended, 100, 80, 0.1)], on: &gestures, lift)
        XCTAssertTrue(lift.sent.isEmpty)
        XCTAssertFalse(gestures.isTwoFinger)
    }

    /// Two fingers 40 points apart moved together by (`dx`, `dy`) in alternating moves of 4 points or less.
    private func twoFingerMove(dx: Double, dy: Double, t: Double) -> [PointerEvent] {
        var events = [event(1, .began, 80, 60, t), event(2, .began, 120, 60, t + 0.01)]
        let count = Int((max(abs(dx), abs(dy)) / 4).rounded(.up))
        for k in 1...count {
            let f = Double(k) / Double(count)
            events.append(event(1, .moved, 80 + dx * f, 60 + dy * f, t + 0.02 * Double(2 * k)))
            events.append(event(2, .moved, 120 + dx * f, 60 + dy * f, t + 0.02 * Double(2 * k + 1)))
        }
        events.append(event(1, .ended, 80 + dx, 60 + dy, t + 0.02 * Double(2 * count + 2)))
        events.append(event(2, .ended, 120 + dx, 60 + dy, t + 0.02 * Double(2 * count + 3)))
        return events
    }

    func testMovingTwoFingersPansSoTheMoleculeFollows() {
        var gestures = MoleculeGestures()
        let right = Recorder()
        _ = play(twoFingerMove(dx: 90, dy: 0, t: 0), on: &gestures, right)
        XCTAssertEqual(right.sent.map(\.0), ["camera.pan", "camera.pan"], "90 points: two steps, no zoom")
        XCTAssertEqual(right.sent.map(\.1), [[-1, 0], [-1, 0]], "fingers right: the target moves left")
        let down = Recorder()
        _ = play(twoFingerMove(dx: 0, dy: 85, t: 2), on: &gestures, down)
        XCTAssertEqual(down.sent.map(\.1), [[0, 1], [0, 1]], "fingers down: the target moves up")
    }

    func testATwoFingerMoveThroughTheSessionMovesTheDrawnMoleculeWithTheFingers() async throws {
        let session = ExperienceSession()
        let shell = try await MoleculeTest.open(session)
        let before = try XCTUnwrap(shell.presenter.lastCamera)
        let canvas = try XCTUnwrap(shell.presenter.lastCanvas)
        let scene = try XCTUnwrap(MoleculeState.initial.scene)
        for item in twoFingerMove(dx: 90, dy: 0, t: 0) { shell.handlePointer(item, viewSize: viewSize) }
        XCTAssertEqual(try MoleculeTest.core(shell).camera.panX, -2)
        try MoleculeTest.frames(session, 1)
        let after = try XCTUnwrap(shell.presenter.lastCamera)
        let x0 = MoleculePresenter.pixel(of: scene.centre, camera: before, canvas: canvas).x
        let x1 = MoleculePresenter.pixel(of: scene.centre, camera: after, canvas: canvas).x
        XCTAssertGreaterThan(x1, x0 + 1, "the molecule is drawn farther right, as the fingers moved")
        var buttons = MoleculeCore(seed: 1)
        for _ in 0..<2 { _ = buttons.apply(ExperienceAction(control: "camera.pan", values: [-1, 0], step: 0)) }
        XCTAssertEqual(try MoleculeTest.core(shell).state, buttons.state, "the same state as Pan left twice")
        session.close()
    }

    func testTinyMovementsSendNothing() {
        var gestures = MoleculeGestures()
        let recorder = Recorder()
        // 8 points held for half a second: neither a drag nor a tap.
        var taps = play([event(1, .began, 50, 50, 0), event(1, .moved, 58, 50, 0.2), event(1, .ended, 58, 50, 0.5)],
                        on: &gestures, recorder)
        XCTAssertEqual(taps, 0)
        // A 40-point drag and a 20-point vertical drag stay below one step.
        _ = play(drag(50, 50, dx: 40, dy: 0, count: 4, t: 1), on: &gestures, recorder)
        _ = play(drag(50, 50, dx: 0, dy: 30, count: 3, t: 2), on: &gestures, recorder)
        // A 20-point two-finger move stays below a pan step.
        _ = play(twoFingerMove(dx: 20, dy: 0, t: 3), on: &gestures, recorder)
        XCTAssertTrue(recorder.sent.isEmpty, "\(recorder.sent)")
        taps = play([event(1, .began, 50, 50, 5), event(1, .ended, 52, 51, 5.1)], on: &gestures, recorder)
        XCTAssertEqual(taps, 1, "a quick touch within 10 points is a tap")
    }

    func testAResetInTheMiddleOfAGestureSendsNothingMore() {
        var gestures = MoleculeGestures()
        let recorder = Recorder()
        _ = play([event(1, .began, 20, 80, 0), event(1, .moved, 50, 80, 0.02)], on: &gestures, recorder)
        XCTAssertTrue(gestures.isDragging)
        gestures.reset()
        XCTAssertFalse(gestures.isDragging)
        let taps = play([event(1, .moved, 200, 80, 0.04), event(1, .moved, 230, 80, 0.06),
                         event(1, .ended, 230, 80, 0.08)], on: &gestures, recorder)
        XCTAssertTrue(recorder.sent.isEmpty, "the forgotten touch sends nothing")
        XCTAssertEqual(taps, 0)
        _ = play([event(1, .began, 100, 80, 1), event(2, .began, 140, 80, 1.01)], on: &gestures, recorder)
        gestures.reset()
        _ = play([event(2, .moved, 200, 80, 1.03), event(1, .moved, 200, 140, 1.05)], on: &gestures, recorder)
        XCTAssertTrue(recorder.sent.isEmpty, "a forgotten pinch sends nothing")
        _ = play(drag(20, 80, dx: 60, dy: 0, count: 6, t: 2), on: &gestures, recorder)
        XCTAssertEqual(recorder.sent.map(\.0), ["camera.orbit"], "the next touch starts a new gesture")
    }

    func testEveryGestureActionHasANativeControl() {
        let presenter = MoleculePresenter(experienceID: MoleculeTest.id)
        XCTAssertEqual(presenter.gestureActions, MoleculeGestures.gestureActions)
        XCTAssertEqual(GestureAlternatives.missing(gesture: presenter.gestureActions, native: presenter.nativeActions),
                       [])
    }
}
