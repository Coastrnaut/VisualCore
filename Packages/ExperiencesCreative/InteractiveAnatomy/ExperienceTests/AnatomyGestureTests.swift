// AnatomyGestureTests — feature 127 (A17-P04) T-A17-406 (FR-A17-401; clarification Q1; SC-A17-401; edge cases "A drag
// that starts as a tap", "Pinch and drag at once"). The canvas gestures of Interactive Anatomy with synthetic pointer
// events, short runs only (each test well under 10 s, no wall-clock assertion): tables of drag lengths and pinch
// scales give the stated `camera.turn`, `camera.tilt` and `camera.zoom` steps (right and up +1, 50 and 33⅓ points per
// step, the zoom at 1 / 0.85 and 0.85); one large move sends at most 64 steps; a short tap still taps and picks
// through the session; a pinch with a drag steps the zoom only; steps past the tilt and zoom limits are refused and
// answered "The camera is at its limit."; every gesture action has a native control.
import Foundation
import XCTest
@testable import InteractiveAnatomyExperience
import InteractiveAnatomyCore
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreScenes

/// The canvas gestures of Interactive Anatomy.
@MainActor
final class AnatomyGestureTests: XCTestCase {
    /// Records the actions a gesture sends and accepts them all.
    private final class Recorder {
        var sent: [(String, [Double])] = []
        func send(_ control: String, _ values: [Double]) -> ActionResult {
            sent.append((control, values))
            return .accepted
        }
        /// The steps sent for `control`, in order.
        func steps(_ control: String) -> [Double] {
            sent.filter { $0.0 == control }.compactMap { $0.1.first }
        }
    }

    /// The view size in points of the session tests.
    private let viewSize = Vec2(240, 160)

    private func event(_ id: Int, _ phase: PointerPhase, _ x: Double, _ y: Double, _ t: Double) -> PointerEvent {
        PointerEvent(id: id, phase: phase, location: Vec2(x, y), timestamp: t)
    }

    /// Plays `events` on `gestures`, recording into `recorder`; returns the number of taps.
    private func play(_ events: [PointerEvent], on gestures: inout AnatomyGestures, _ recorder: Recorder) -> Int {
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
        XCTAssertEqual(AnatomyGestures.turnPoints, 50, accuracy: 1e-9)
        XCTAssertEqual(AnatomyGestures.tiltPoints, 100.0 / 3, accuracy: 1e-9)
        XCTAssertEqual(AnatomyGestures.zoomRatio, 0.85)
        XCTAssertEqual(AnatomyGestures.maxStepsPerEvent, 64)
        XCTAssertEqual(AnatomyGestures.declarations.map(\.priority), [3, 2, 1])
        XCTAssertEqual(AnatomyGestures.declarations.map(\.kind), [.pinch, .drag, .tap])
    }

    func testDragLengthsGiveTheStatedTurnAndTiltSteps() {
        // (dx, dy) → (turn steps, tilt steps); right and up (view y falling) are +1.
        let table: [(dx: Double, dy: Double, turn: [Double], tilt: [Double])] = [
            (30, 0, [], []), (49, 0, [], []), (51, 0, [1], []), (120, 0, [1, 1], []), (160, 0, [1, 1, 1], []),
            (-60, 0, [-1], []), (-101, 0, [-1, -1], []),
            (0, -20, [], []), (0, -34, [], [1]), (0, -101, [], [1, 1, 1]), (0, 70, [], [-1, -1]),
            (0, 30, [], []), (120, -40, [1, 1], [1]), (-55, 75, [-1], [-1, -1]),
        ]
        for row in table {
            var gestures = AnatomyGestures()
            let recorder = Recorder()
            let count = max(2, Int((max(abs(row.dx), abs(row.dy)) / 5).rounded(.up)))
            let taps = play(drag(120, 80, dx: row.dx, dy: row.dy, count: count, t: 0), on: &gestures, recorder)
            let name = "drag (\(row.dx), \(row.dy))"
            XCTAssertEqual(recorder.steps("camera.turn"), row.turn, name)
            XCTAssertEqual(recorder.steps("camera.tilt"), row.tilt, name)
            XCTAssertEqual(recorder.sent.count, row.turn.count + row.tilt.count, "\(name): nothing else")
            XCTAssertEqual(taps, 0, "\(name): a drag is not a tap")
            XCTAssertFalse(gestures.isDragging)
        }
    }

    func testOneLargeMoveSendsAtMost64Steps() {
        var gestures = AnatomyGestures()
        let recorder = Recorder()
        _ = play([event(1, .began, 0, 80, 0), event(1, .moved, 4_000, 80, 0.02)], on: &gestures, recorder)
        XCTAssertEqual(recorder.steps("camera.turn").count, AnatomyGestures.maxStepsPerEvent)
        let more = Recorder()
        _ = play([event(1, .moved, 4_001, 80, 0.04), event(1, .ended, 4_001, 80, 0.06)], on: &gestures, more)
        XCTAssertEqual(more.steps("camera.turn").count, 16, "the points left over step on the next move")
    }

    func testPinchScalesGiveTheStatedZoomSteps() {
        // Fingers 40 points apart; the second moves to make the scale; scale → zoom steps.
        let table: [(scale: Double, zoom: [Double])] = [
            (1.1, []), (1.2, [1]), (1.4, [1, 1]), (2.0, [1, 1, 1, 1]), (0.9, []), (0.8, [-1]), (0.7, [-1, -1]),
            (0.5, [-1, -1, -1, -1]),
        ]
        for row in table {
            var gestures = AnatomyGestures()
            let recorder = Recorder()
            let taps = play([event(1, .began, 100, 80, 0), event(2, .began, 140, 80, 0.01),
                             event(2, .moved, 100 + 40 * row.scale, 80, 0.03)], on: &gestures, recorder)
            XCTAssertTrue(gestures.isPinching)
            let lift = play([event(2, .ended, 100 + 40 * row.scale, 80, 0.05), event(1, .ended, 100, 80, 0.06)],
                            on: &gestures, recorder)
            XCTAssertEqual(recorder.steps("camera.zoom"), row.zoom, "scale \(row.scale)")
            XCTAssertEqual(recorder.sent.count, row.zoom.count, "scale \(row.scale): zoom only")
            XCTAssertEqual(taps + lift, 0, "scale \(row.scale): a pinch is not a tap")
            XCTAssertFalse(gestures.isPinching)
        }
    }

    func testAPinchWithADragStepsTheZoomOnly() {
        var gestures = AnatomyGestures()
        let recorder = Recorder()
        // Both fingers move 150 points right and 50 up in alternating moves of 3 points while their distance grows
        // from 40 to 56 (never falling to 0.85 × 40 between two moves).
        var events = [event(1, .began, 60, 80, 0), event(2, .began, 100, 80, 0.01)]
        for k in 1...50 {
            let shift = 3 * Double(k)
            events.append(event(1, .moved, 60 + shift, 80 - shift / 3, 0.01 + 0.02 * Double(2 * k)))
            events.append(event(2, .moved, 100 + shift + 0.32 * Double(k), 80 - shift / 3,
                                0.01 + 0.02 * Double(2 * k + 1)))
        }
        events.append(event(1, .ended, 210, 30, 2.1))
        events.append(event(2, .ended, 266, 30, 2.12))
        let taps = play(events, on: &gestures, recorder)
        XCTAssertEqual(recorder.sent.map(\.0), ["camera.zoom", "camera.zoom"], "150 points across turn nothing")
        XCTAssertEqual(recorder.steps("camera.zoom"), [1, 1], "the scale 1.4 zooms in twice")
        XCTAssertEqual(taps, 0)
    }

    func testAShortTapTapsAndAHeldOrMovedTouchDoesNot() {
        var gestures = AnatomyGestures()
        let recorder = Recorder()
        var taps = play([event(1, .began, 50, 50, 0), event(1, .ended, 52, 51, 0.1)], on: &gestures, recorder)
        XCTAssertEqual(taps, 1, "a quick touch within 10 points is a tap")
        taps = play([event(1, .began, 50, 50, 1), event(1, .moved, 58, 50, 1.2), event(1, .ended, 58, 50, 1.5)],
                    on: &gestures, recorder)
        XCTAssertEqual(taps, 0, "a touch held for half a second is not a tap")
        taps = play([event(1, .began, 50, 50, 2), event(2, .began, 54, 50, 2.01), event(1, .ended, 50, 50, 2.05),
                     event(2, .ended, 54, 50, 2.06)], on: &gestures, recorder)
        XCTAssertEqual(taps, 0, "a two-finger touch is not a tap")
        XCTAssertTrue(recorder.sent.isEmpty, "\(recorder.sent)")
    }

    func testAResetInTheMiddleOfAGestureSendsNothingMore() {
        var gestures = AnatomyGestures()
        let recorder = Recorder()
        _ = play([event(1, .began, 20, 80, 0), event(1, .moved, 50, 80, 0.02)], on: &gestures, recorder)
        XCTAssertTrue(gestures.isDragging)
        gestures.reset()
        XCTAssertFalse(gestures.isDragging)
        let taps = play([event(1, .moved, 200, 80, 0.04), event(1, .ended, 200, 80, 0.06)], on: &gestures, recorder)
        XCTAssertTrue(recorder.sent.isEmpty, "the forgotten touch sends nothing")
        XCTAssertEqual(taps, 0)
        _ = play(drag(20, 80, dx: 60, dy: 0, count: 6, t: 1), on: &gestures, recorder)
        XCTAssertEqual(recorder.steps("camera.turn"), [1], "the next touch starts a new gesture")
    }

    func testAShortTapStillPicksThroughTheSession() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await AnatomyTest.open(session)
        let center = try AnatomyTest.core(shell).scene.structureSphere(3).center
        let ndc = try AnatomyTest.projectedNDC(of: center, presenter: shell.presenter)
        let expected = try AnatomyTest.expectedPick(shell, at: ndc)
        XCTAssertNotNil(expected)
        let point = Vec2((ndc.x + 1) / 2 * viewSize.x, (1 - ndc.y) / 2 * viewSize.y)
        shell.handlePointer(event(1, .began, point.x, point.y, 0), viewSize: viewSize)
        shell.handlePointer(event(1, .ended, point.x, point.y, 0.05), viewSize: viewSize)
        let selected = try AnatomyTest.core(shell).selectedIndex
        XCTAssertEqual(selected, expected, "a short tap picks what the picker returns")
    }

    func testADragThroughTheSessionEqualsTheButtons() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await AnatomyTest.open(session)
        let before = try AnatomyTest.core(shell).view.camera
        for item in drag(40, 120, dx: 160, dy: -70, count: 23, t: 0) { shell.handlePointer(item, viewSize: viewSize) }
        let after = try AnatomyTest.core(shell).view.camera
        XCTAssertEqual(after.turn, (before.turn + 3) % AnatomyCameraState.turnPositions, "three Turn right")
        XCTAssertEqual(after.tilt, before.tilt + 2, "two Tilt up")
        XCTAssertEqual(after.zoom, before.zoom)
        XCTAssertEqual(shell.presenter.mirror.message, "", "accepted steps answer nothing")
    }

    func testStepsPastTheLimitsAreRefusedWithTheSentence() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await AnatomyTest.open(session)
        shell.presenter.announcementSink = { _ in }
        let spokenBefore = shell.presenter.announced.count
        let opening = try AnatomyTest.core(shell).view.camera
        // 250 points up: seven tilt steps, of which only those up to the limit are accepted.
        for item in drag(120, 150, dx: 0, dy: -250, count: 25, t: 0) { shell.handlePointer(item, viewSize: viewSize) }
        let tilted = try AnatomyTest.core(shell).view.camera
        XCTAssertEqual(tilted.tilt, AnatomyCameraState.tiltRange.upperBound)
        XCTAssertGreaterThan(7, AnatomyCameraState.tiltRange.upperBound - opening.tilt, "some steps were refused")
        XCTAssertEqual(shell.presenter.mirror.message, "The camera is at its limit.")
        let spoken = Array(shell.presenter.announced.dropFirst(spokenBefore))
        XCTAssertEqual(spoken.first, "The camera is at its limit.", "the refusal is spoken")
        // Spreading two fingers ten times apart: fourteen zoom steps, only six accepted.
        let pinch = [event(5, .began, 100, 80, 1), event(6, .began, 110, 80, 1.01), event(6, .moved, 200, 80, 1.03),
                     event(6, .ended, 200, 80, 1.05), event(5, .ended, 100, 80, 1.06)]
        for item in pinch { shell.handlePointer(item, viewSize: viewSize) }
        let zoomed = try AnatomyTest.core(shell).view.camera
        XCTAssertEqual(zoomed.zoom, AnatomyCameraState.zoomRange.upperBound)
        XCTAssertEqual(zoomed.tilt, tilted.tilt, "the pinch does not tilt")
        XCTAssertEqual(shell.presenter.mirror.message, "The camera is at its limit.")
        let result = shell.presenter.send("camera.zoom", [1], through: shell.port)
        XCTAssertEqual(result.code, "action.rule.a17.camera-limit")
        XCTAssertEqual(AnatomyPresenter.answerWords(control: "camera.tilt", result: result),
                       "The camera is at its limit.")
    }

    func testEveryGestureActionHasANativeControl() {
        let presenter = AnatomyPresenter(experienceID: AnatomyTest.id)
        XCTAssertEqual(presenter.gestureActions, AnatomyGestures.gestureActions)
        XCTAssertEqual(GestureAlternatives.missing(gesture: presenter.gestureActions, native: presenter.nativeActions),
                       [])
    }
}
