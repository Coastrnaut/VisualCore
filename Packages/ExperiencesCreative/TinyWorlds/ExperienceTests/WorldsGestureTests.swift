// WorldsGestureTests — feature 090 (A12-P02) T-A12-205 (FR-A12-211, FR-A12-221; SC-A12-205; clarifications 2 and 3;
// research D3 and D5; acceptance scenarios US1-3, US3-1 and US3-2). The canvas gestures of Tiny Worlds with synthetic
// pointer events, short runs only (each test under 10 s, no wall-clock assertion): a drag maps to `view.orbit` steps of
// 0.3° per point (Δyaw = −0.3 · Δx, Δpitch = +0.3 · Δy, each clamped into −180…180); a pinch maps to `view.zoom`
// factors equal to the scale since the previous pinch event, clamped into 0.5…2; every gesture action has a native
// control (`GestureAlternatives.missing` empty); a tap on the terrain speaks a ground point that lies on the level-0
// terrain within 1 mm and leaves the digest unchanged; a tap on the sky speaks a miss and changes nothing.
// Feature 092 (A12-P04) T-A12-403 (FR-A12-403): a wild pinch saturates at the preset's least distance.
import Foundation
import XCTest
@testable import TinyWorldsExperience
import TinyWorldsCore
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreScenes
import VisualCoreUI

@MainActor
final class WorldsGestureTests: XCTestCase {
    /// Records the actions a gesture sends and accepts them all.
    private final class Recorder {
        var sent: [(String, [Double])] = []
        func send(_ control: String, _ values: [Double]) -> ActionResult {
            sent.append((control, values))
            return .accepted
        }
    }

    private func event(_ id: Int, _ phase: PointerPhase, _ x: Double, _ y: Double, _ t: Double) -> PointerEvent {
        PointerEvent(id: id, phase: phase, location: Vec2(x, y), timestamp: t)
    }

    func testTheMappingOfDragAndPinchValues() {
        XCTAssertEqual(WorldsGestures.degreesPerPoint, 0.3)
        XCTAssertEqual(WorldsGestures.orbitStep(dx: 10, dy: -20), [-3, -6])
        XCTAssertEqual(WorldsGestures.orbitStep(dx: -10, dy: 20), [3, 6])
        XCTAssertEqual(WorldsGestures.orbitStep(dx: -1000, dy: 1000), [180, 180], "clamped into the action's range")
        XCTAssertEqual(WorldsGestures.orbitStep(dx: 1000, dy: -1000), [-180, -180])
        XCTAssertNil(WorldsGestures.orbitStep(dx: 0, dy: 0), "no movement, no action")
        XCTAssertNil(WorldsGestures.orbitStep(dx: .nan, dy: 1))
        XCTAssertEqual(WorldsGestures.zoomFactor(from: 1, to: 1.5), 1.5)
        XCTAssertEqual(WorldsGestures.zoomFactor(from: 2, to: 1), 0.5)
        XCTAssertEqual(WorldsGestures.zoomFactor(from: 1, to: 1e-9), 0.5, "a pinch to zero saturates")
        XCTAssertEqual(WorldsGestures.zoomFactor(from: 1e-300, to: 1e300), 2, "a pinch to infinity saturates")
        XCTAssertNil(WorldsGestures.zoomFactor(from: 1, to: 1))
        XCTAssertNil(WorldsGestures.zoomFactor(from: 1, to: 0))
        XCTAssertNil(WorldsGestures.zoomFactor(from: 1, to: .infinity))
    }

    func testADragOrbitsByPointsMoved() {
        var gestures = WorldsGestures()
        let recorder = Recorder()
        var taps: [Vec2] = []
        let send: WorldsGestures.Send = { recorder.send($0, $1) }
        gestures.handle(event(1, .began, 50, 50, 0), send: send) { taps.append($0) }
        gestures.handle(event(1, .moved, 55, 50, 0.02), send: send) { taps.append($0) }
        XCTAssertTrue(recorder.sent.isEmpty, "a drag begins after 10 points")
        gestures.handle(event(1, .moved, 70, 50, 0.04), send: send) { taps.append($0) }
        gestures.handle(event(1, .moved, 80, 60, 0.06), send: send) { taps.append($0) }
        gestures.handle(event(1, .ended, 80, 60, 0.08), send: send) { taps.append($0) }
        XCTAssertEqual(recorder.sent.map(\.0), ["view.orbit", "view.orbit"])
        XCTAssertEqual(recorder.sent[0].1[0], -6, accuracy: 1e-12, "the first step carries the whole 20 points")
        XCTAssertEqual(recorder.sent[0].1[1], 0, accuracy: 1e-12)
        XCTAssertEqual(recorder.sent[1].1[0], -3, accuracy: 1e-12)
        XCTAssertEqual(recorder.sent[1].1[1], 3, accuracy: 1e-12)
        XCTAssertTrue(taps.isEmpty, "a drag is not a tap")
        XCTAssertFalse(gestures.isDragging, "the drag ended")
    }

    func testAPinchZoomsByTheScaleSinceTheLastEvent() {
        var gestures = WorldsGestures()
        let recorder = Recorder()
        var taps: [Vec2] = []
        let send: WorldsGestures.Send = { recorder.send($0, $1) }
        gestures.handle(event(1, .began, 40, 50, 0), send: send) { taps.append($0) }
        gestures.handle(event(2, .began, 60, 50, 0.01), send: send) { taps.append($0) }
        gestures.handle(event(2, .moved, 80, 50, 0.03), send: send) { taps.append($0) }    // 20 → 40 points: × 2
        gestures.handle(event(2, .moved, 100, 50, 0.05), send: send) { taps.append($0) }   // 40 → 60: × 1.5
        gestures.handle(event(2, .moved, 40.001, 50, 0.07), send: send) { taps.append($0) } // to almost 0: × 0.5
        gestures.handle(event(2, .ended, 40.001, 50, 0.09), send: send) { taps.append($0) }
        gestures.handle(event(1, .ended, 40, 50, 0.1), send: send) { taps.append($0) }
        XCTAssertEqual(recorder.sent.map(\.0), ["view.zoom", "view.zoom", "view.zoom"], "\(recorder.sent)")
        guard recorder.sent.count == 3 else { return }
        XCTAssertEqual(recorder.sent[0].1[0], 2, accuracy: 1e-12)
        XCTAssertEqual(recorder.sent[1].1[0], 1.5, accuracy: 1e-12)
        XCTAssertEqual(recorder.sent[2].1[0], 0.5, accuracy: 1e-12, "clamped into 0.5…2")
        XCTAssertTrue(taps.isEmpty)
        for (_, values) in recorder.sent { XCTAssertTrue(WorldView.zoomRange.contains(values[0])) }
    }

    func testEveryGestureHasANativeControl() async throws {
        let presenter = WorldsPresenter(experienceID: WorldsTest.id)
        XCTAssertEqual(presenter.gestureActions, ["view.orbit", "view.zoom", "prop.select"])
        XCTAssertTrue(presenter.gestureActions.isSubset(of: Set(WorldsCore.actionIDs)))
        XCTAssertEqual(GestureAlternatives.missing(gesture: presenter.gestureActions, native: presenter.nativeActions),
                       [])
        XCTAssertEqual(WorldsGestures.declarations.map(\.kind), [.pinch, .drag, .tap])
    }

    func testGesturesThroughTheShellMoveTheViewWithinTheLimits() async throws {
        let session = ExperienceSession()
        let shell = try await WorldsTest.open(session)
        let size = Vec2(120, 100)
        let start = try WorldsTest.core(shell).view
        shell.handlePointer(event(1, .began, 20, 50, 0), viewSize: size)
        shell.handlePointer(event(1, .moved, 60, 30, 0.05), viewSize: size)
        shell.handlePointer(event(1, .ended, 60, 30, 0.1), viewSize: size)
        var view = try WorldsTest.core(shell).view
        XCTAssertEqual(view.yawDegrees, start.yawDegrees - 12, accuracy: 1e-9, "40 points right: 12° of yaw back")
        XCTAssertEqual(view.pitchDegrees, start.pitchDegrees - 6, accuracy: 1e-9, "20 points up: 6° lower")

        // A wild pinch out saturates at the nearest distance and the view keeps the camera policy.
        shell.handlePointer(event(3, .began, 59, 50, 1), viewSize: size)
        shell.handlePointer(event(4, .began, 61, 50, 1.01), viewSize: size)
        for k in 1...10 {
            shell.handlePointer(event(4, .moved, 61 + Double(k * 100), 50, 1.01 + Double(k) * 0.01), viewSize: size)
        }
        shell.handlePointer(event(4, .ended, 1061, 50, 1.2), viewSize: size)
        shell.handlePointer(event(3, .ended, 59, 50, 1.21), viewSize: size)
        let core = try WorldsTest.core(shell)
        view = core.view
        XCTAssertEqual(view.distance, CameraPolicy.limits(for: core.preset).distance.lowerBound, accuracy: 1e-12,
                       "the preset's least distance (feature 092)")
        let field = try TerrainGenerator.heightField(preset: core.preset, seed: core.seed)
        XCTAssertTrue(CameraPolicy.keepsClearance(core.state, field: field))
        session.close()
    }

    func testATapOnTheTerrainSpeaksAGroundPointAndChangesNothing() async throws {
        let sink = RecordingAnnouncementSink()
        let session = ExperienceSession()
        let shell = try await WorldsTest.open(session, announcements: sink)
        let size = Vec2(120, 100)
        let digest = try shell.engine.digest()
        let core = try WorldsTest.core(shell)
        shell.handlePointer(event(1, .began, 60, 50, 0), viewSize: size)
        shell.handlePointer(event(1, .ended, 60, 50, 0.05), viewSize: size)
        let words = try XCTUnwrap(shell.presenter.lastPick)
        XCTAssertTrue(words.hasPrefix("Ground at x "), words)
        XCTAssertTrue(words.hasSuffix(" metres."), words)
        XCTAssertEqual(sink.announced.last, words, "spoken while VoiceOver runs")
        XCTAssertEqual(try shell.engine.digest(), digest, "a tap never changes the world")
        XCTAssertEqual(try WorldsTest.core(shell), core)

        // The point lies on the level-0 terrain within 1 mm and its words name it.
        let field = try TerrainGenerator.heightField(preset: core.preset, seed: core.seed)
        let point = try XCTUnwrap(WorldsPresenter.groundPoint(view: core.view, point: Vec2(60, 50), viewSize: size,
                                                              field: field))
        XCTAssertLessThan(abs(point.y - field.height(atX: point.x, z: point.z)), 1e-3)
        XCTAssertEqual(words, WorldsPresenter.pickWords(point))
        XCTAssertEqual(WorldsPresenter.pickWords(Vec3(1.24, 0.31, -0.46)),
                       "Ground at x 1.2, z -0.5, height 0.3 metres.")
        XCTAssertEqual(WorldsPresenter.pickWords(Vec3(-0.01, 0, 0.04)), "Ground at x 0.0, z 0.0, height 0.0 metres.")
        session.close()
    }

    func testATapOnTheSkySpeaksAMissAndChangesNothing() async throws {
        let sink = RecordingAnnouncementSink()
        let session = ExperienceSession()
        let shell = try await WorldsTest.open(session, announcements: sink)
        let size = Vec2(120, 100)
        let digest = try shell.engine.digest()
        shell.handlePointer(event(1, .began, 2, 2, 0), viewSize: size)
        shell.handlePointer(event(1, .ended, 2, 2, 0.05), viewSize: size)
        XCTAssertEqual(shell.presenter.lastPick, "No ground there.")
        XCTAssertEqual(sink.announced.last, "No ground there.")
        XCTAssertEqual(try shell.engine.digest(), digest)
        XCTAssertEqual(WorldsPresenter.pickWords(nil), "No ground there.")
        let field = try TerrainGenerator.heightField(preset: .island, seed: 1)
        XCTAssertNil(WorldsPresenter.groundPoint(view: .default, point: Vec2(60, 50), viewSize: Vec2(0, 100),
                                                 field: field), "a degenerate canvas picks nothing")
        session.close()
    }
}
