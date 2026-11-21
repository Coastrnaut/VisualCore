// WaveKnotKeeperGestureWiringTests — feature 324 (R02-G03-04) T-R02G0304-005 (FR-R02G0304-002 … 006;
// SC-R02G0304-005). On the simulator, through the one app's session host: scripted touches enter through the shell's
// pointer entry (`ExperienceShell.handlePointer`, which hands them to the presenter's `pointer(_:viewSize:port:)` with
// the shell's own `port` while the experience is active) at a 720 × 480-point view (aspect 1.5), placed at the
// projections of the rope's control points through the drawn camera (`presenter.gestures.camera(for:viewSize:)` on the
// presenter's `lastSnapshot`, `WaveKnotKeeperHandles.screen` and `projectedStep`). Checked:
//   1. a one-finger drag from a handle along a legal move's projected step (1.5 × its projected length, at least
//      10 pt) selects the point and sends exactly one `point.move`: the point moves by that direction, one move is
//      spent and the digest changes;
//   2. a tap on a handle selects it without changing the digest, and the next frame's still shows that handle ember;
//   3. a drag that names a refused move leaves the play unchanged and shows the refusal with its reason code;
//   4. a two-finger move turns the orbit (the scene draws it) but never changes the digest; `resetView()` and a double
//      tap on empty space return to the authored orbit;
//   5. `cancelPointers()` mid-drag sends nothing;
//   6. while a drag previews a move, the drawn `scene.preview` is the point the move would reach.
// The handle and direction of each gesture are chosen so that the pick at the handle's projected centre is that
// handle and the controller's candidate for the scripted drag is that direction (both computed with the Core's own
// `WaveKnotKeeperHandles`); levels 1 … 5 are searched in order until one fits. Synthetic timestamps; no sleep, no
// wall-clock assertion; each test well under 10 s. Test data uses explicit types and plain loops (CI type-check rule).
#if os(iOS)
import CoreGraphics
import Foundation
import Testing
import WaveKnotKeeperCore
@testable import WaveKnotKeeperExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreScenes

/// Scripted touches on Wave Knot Keeper's handles, placed through the drawn camera.
@MainActor
enum WaveKnotKeeperGestureScript {
    typealias Shell = ExperienceShell<WaveKnotKeeperPresenter>
    typealias Geometry = WaveKnotKeeperSceneGeometry
    typealias Handles = WaveKnotKeeperHandles

    /// The view's size in points (aspect 1.5, the frame-check aspect).
    static let viewWidth: Double = 720
    static let viewHeight: Double = 480
    /// The view size handed with every event.
    static var viewSize: Vec2 { Vec2(viewWidth, viewHeight) }
    /// The time between scripted events in seconds (synthetic).
    static let frame: Double = 1.0 / 60
    /// The shortest projected step a scripted drag uses, in points (a step seen almost end-on is left out).
    static let shortestStep: Double = 4
    /// The shortest scripted drag in points.
    static let shortestDrag: Double = 10
    /// How many levels the search for a fitting gesture may try (level.next between them).
    static let levelsTried: Int = 5

    /// A scripted drag: the control point, the direction, where the finger goes down and where it is released.
    struct Drag {
        let point: Int
        let direction: WaveKnotKeeperDirection
        let start: Vec2
        let end: Vec2
    }

    /// Opens level `seed % 100 + 1` at the scripted view size (one frame drawn).
    static func open(_ session: ExperienceSession, seed: UInt64 = 0) async throws -> Shell {
        try await WaveKnotKeeperTest.open(session, seed: seed, size: CGSize(width: viewWidth, height: viewHeight))
    }

    /// The play of `shell`'s core.
    static func play(_ shell: Shell) throws -> WaveKnotKeeperPlay {
        try WaveKnotKeeperTest.core(shell).play
    }

    /// The selected point of `shell`'s core (presentation only).
    static func selected(_ shell: Shell) throws -> Int? {
        try WaveKnotKeeperTest.core(shell).snapshot(time: 0).selected
    }

    /// The snapshot the presenter drew last (the gestures pick against it).
    static func drawn(_ shell: Shell) throws -> WaveKnotKeeperSceneSnapshot {
        try #require(shell.presenter.lastSnapshot)
    }

    /// The camera the gestures use now: the drawn snapshot at the view size and the controller's orbit.
    static func camera(_ shell: Shell) throws -> WaveKnotKeeperCamera {
        let snapshot: WaveKnotKeeperSceneSnapshot = try drawn(shell)
        return try #require(shell.presenter.gestures.camera(for: snapshot, viewSize: viewSize))
    }

    /// The view size as the Core's `SIMD2` size.
    static var size: SIMD2<Double> { SIMD2<Double>(viewWidth, viewHeight) }

    /// Sends one pointer event through the shell's pointer entry.
    static func touch(_ shell: Shell, id: Int, _ phase: PointerPhase, at location: Vec2, time: inout Double) {
        shell.handlePointer(PointerEvent(id: id, phase: phase, location: location, timestamp: time), viewSize: viewSize)
        time += frame
    }

    /// Whether `location` lies inside the view.
    static func inside(_ location: Vec2) -> Bool {
        location.x >= 0 && location.x <= viewWidth && location.y >= 0 && location.y <= viewHeight
    }

    /// Whether `move` is legal for `play` (the kernel's `refusal(of:points:level:)` is nil).
    static func isLegal(_ move: WaveKnotKeeperMove, _ play: WaveKnotKeeperPlay) -> Bool {
        WaveKnotKeeperPlay.refusal(of: move, points: play.points, level: play.level) == nil
    }

    /// Whether the kernel refuses `move` for `play` with a `.move(…)` reason.
    static func isRefusedMove(_ move: WaveKnotKeeperMove, _ play: WaveKnotKeeperPlay) -> Bool {
        guard let refusal = WaveKnotKeeperPlay.refusal(of: move, points: play.points, level: play.level) else {
            return false
        }
        if case .move = refusal { return true }
        return false
    }

    /// The first drag on the drawn frame whose move satisfies `accept`, whose handle the touch at its projected centre
    /// picks, and whose release point the controller maps to that direction; nil when none fits.
    static func findDrag(_ shell: Shell, accept: (WaveKnotKeeperMove, WaveKnotKeeperPlay) -> Bool) throws -> Drag? {
        let snapshot: WaveKnotKeeperSceneSnapshot = try drawn(shell)
        let cam: WaveKnotKeeperCamera = try camera(shell)
        let play: WaveKnotKeeperPlay = try self.play(shell)
        let directions: [WaveKnotKeeperDirection] = WaveKnotKeeperDirection.allCases
        for point in 0..<snapshot.points.count {
            guard let centre = Handles.screen(Geometry.world(snapshot.points[point]), camera: cam, size: size),
                  Handles.pick(centre, snapshot: snapshot, camera: cam, size: size) == point else { continue }
            for direction in directions {
                let move: WaveKnotKeeperMove = WaveKnotKeeperMove(point: point, direction: direction)
                guard accept(move, play),
                      let step = Handles.projectedStep(point: point, direction: direction, snapshot: snapshot,
                                                       camera: cam, size: size) else { continue }
                let length: Double = (step.x * step.x + step.y * step.y).squareRoot()
                guard length.isFinite, length >= shortestStep else { continue }
                let dragLength: Double = Swift.max(1.5 * length, shortestDrag)
                let drag: SIMD2<Double> = step / length * dragLength
                guard Handles.candidate(point: point, drag: drag, snapshot: snapshot, camera: cam,
                                        size: size) == direction else { continue }
                let start: Vec2 = Vec2(centre.x, centre.y)
                let end: Vec2 = Vec2(centre.x + drag.x, centre.y + drag.y)
                guard inside(start), inside(end) else { continue }
                return Drag(point: point, direction: direction, start: start, end: end)
            }
        }
        return nil
    }

    /// Like `findDrag`, moving on with `level.next` (and a frame) until a level has a fitting drag.
    static func findDragOnSomeLevel(_ session: ExperienceSession, _ shell: Shell,
                                    accept: (WaveKnotKeeperMove, WaveKnotKeeperPlay) -> Bool) throws -> Drag? {
        for _ in 0..<levelsTried {
            if let found = try findDrag(shell, accept: accept) { return found }
            #expect(shell.handle(control: "level.next") == .accepted)
            try WaveKnotKeeperTest.draw(session)
        }
        return nil
    }

    /// The first handle (preferring one the frame check can see) that the touch at its projected centre picks, with
    /// that centre; nil when none.
    static func tappableHandle(_ shell: Shell) throws -> (point: Int, location: Vec2)? {
        let snapshot: WaveKnotKeeperSceneSnapshot = try drawn(shell)
        let cam: WaveKnotKeeperCamera = try camera(shell)
        let checkable: [Int] = WaveKnotKeeperTest.checkableHandles(snapshot)
        var fallback: (point: Int, location: Vec2)?
        for point in 0..<snapshot.points.count {
            guard let centre = Handles.screen(Geometry.world(snapshot.points[point]), camera: cam, size: size),
                  Handles.pick(centre, snapshot: snapshot, camera: cam, size: size) == point else { continue }
            let location: Vec2 = Vec2(centre.x, centre.y)
            guard inside(location) else { continue }
            if checkable.contains(point) { return (point, location) }
            if fallback == nil { fallback = (point, location) }
        }
        return fallback
    }

    /// Whether a touch at `location` picks no handle through the current camera.
    static func isEmpty(_ shell: Shell, _ location: Vec2) throws -> Bool {
        let snapshot: WaveKnotKeeperSceneSnapshot = try drawn(shell)
        let cam: WaveKnotKeeperCamera = try camera(shell)
        return Handles.pick(SIMD2<Double>(location.x, location.y), snapshot: snapshot, camera: cam, size: size) == nil
    }

    /// Puts finger `id` down at the drag's start and moves it halfway, then to the release point (not released).
    static func dragWithoutRelease(_ shell: Shell, id: Int = 1, _ drag: Drag, time: inout Double) {
        touch(shell, id: id, .began, at: drag.start, time: &time)
        let half: Vec2 = Vec2((drag.start.x + drag.end.x) / 2, (drag.start.y + drag.end.y) / 2)
        touch(shell, id: id, .moved, at: half, time: &time)
        touch(shell, id: id, .moved, at: drag.end, time: &time)
    }

    /// A whole one-finger drag: down at the start, halfway, to the end and released there.
    static func drag(_ shell: Shell, id: Int = 1, _ drag: Drag, time: inout Double) {
        dragWithoutRelease(shell, id: id, drag, time: &time)
        touch(shell, id: id, .ended, at: drag.end, time: &time)
    }
}

@MainActor
@Suite(.serialized) struct WaveKnotKeeperGestureWiringTests {
    typealias Script = WaveKnotKeeperGestureScript

    /// A one-finger drag from a handle along a legal move's projected step selects the point and sends exactly that
    /// one move.
    @Test func dragAlongAStepSendsExactlyOneMove() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Script.open(session)
        #expect(shell.state == .active)
        var time: Double = 0
        let drag: Script.Drag = try #require(try Script.findDragOnSomeLevel(session, shell, accept: Script.isLegal),
                                             "a legal move whose handle and drag direction can be scripted")
        let before: WaveKnotKeeperPlay = try Script.play(shell)
        let digest: String = try WaveKnotKeeperTest.digest(shell)
        #expect(before.spent == 0)

        Script.drag(shell, drag, time: &time)
        let after: WaveKnotKeeperPlay = try Script.play(shell)
        #expect(try Script.selected(shell) == drag.point, "the dragged point is selected")
        #expect(after.spent == before.spent + 1, "exactly one move")
        #expect(after.points[drag.point] == before.points[drag.point].moved(drag.direction),
                "point \(drag.point) moved \(drag.direction)")
        for index in 0..<before.points.count where index != drag.point {
            #expect(after.points[index] == before.points[index], "point \(index) stays")
        }
        var expected: WaveKnotKeeperPlay = before
        try expected.apply(WaveKnotKeeperMove(point: drag.point, direction: drag.direction),
                           expecting: expected.fingerprint)
        #expect(after.fingerprint == expected.fingerprint)
        #expect(try WaveKnotKeeperTest.digest(shell) != digest, "the move changes the digest")
        #expect(shell.presenter.gestures.phase == .idle)
        #expect(shell.presenter.mirror.message == nil)
        try WaveKnotKeeperTest.draw(session)
        #expect(try Script.drawn(shell).selected == drag.point)
    }

    /// A tap on a handle selects it without changing the digest; the next still shows that handle ember.
    @Test func aTapSelectsAHandleAndTheStillShowsItEmber() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Script.open(session)
        var time: Double = 0
        let handle = try #require(try Script.tappableHandle(shell), "a handle the touch at its centre picks")
        let digest: String = try WaveKnotKeeperTest.digest(shell)
        let spent: Int = try Script.play(shell).spent

        Script.touch(shell, id: 1, .began, at: handle.location, time: &time)
        Script.touch(shell, id: 1, .ended, at: handle.location, time: &time)
        #expect(try Script.selected(shell) == handle.point, "the tapped handle is selected")
        #expect(try WaveKnotKeeperTest.digest(shell) == digest, "a selection is presentation only")
        #expect(try Script.play(shell).spent == spent, "a tap sends no move")
        #expect(shell.presenter.gestures.phase == .idle)

        try WaveKnotKeeperTest.draw(session)
        let snapshot: WaveKnotKeeperSceneSnapshot = try Script.drawn(shell)
        #expect(snapshot.selected == handle.point)
        let rgba: [UInt8] = try WaveKnotKeeperTest.still(session)
        let result = WaveKnotKeeperTest.handleMisses(rgba, snapshot: snapshot)
        #expect(result.misses.isEmpty, "\(result.misses.prefix(6))")
        if WaveKnotKeeperTest.checkableHandles(snapshot).contains(handle.point) {
            #expect(result.selectedChecked, "the selected handle \(handle.point) was checked ember")
        }
    }

    /// A drag that names a refused move leaves the play unchanged and shows the refusal with its reason code.
    @Test func aRefusedDragChangesNothingAndShowsTheReason() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Script.open(session)
        var time: Double = 0
        let drag: Script.Drag = try #require(
            try Script.findDragOnSomeLevel(session, shell, accept: Script.isRefusedMove),
            "a refused move whose handle and drag direction can be scripted")
        let before: WaveKnotKeeperPlay = try Script.play(shell)
        let digest: String = try WaveKnotKeeperTest.digest(shell)

        Script.drag(shell, drag, time: &time)
        let after: WaveKnotKeeperPlay = try Script.play(shell)
        #expect(after.fingerprint == before.fingerprint, "a refused move leaves the play unchanged")
        #expect(after.spent == before.spent)
        #expect(after.points == before.points)
        #expect(try WaveKnotKeeperTest.digest(shell) == digest)
        let message: String = try #require(shell.presenter.mirror.message, "the refusal is shown")
        let code: String = WaveKnotKeeperError.move("").reasonCode
        // Feature 326: refusals are shown in words, the same words that are announced.
        #expect(message == WaveKnotKeeperFeedbackPlan.refusalText(code: code), "\(message)")
        #expect(try Script.selected(shell) == drag.point, "the touch still selected the point")
        #expect(shell.presenter.gestures.phase == .idle)
    }

    /// A two-finger move turns the orbit (and the drawn scene) but never the digest; `resetView()` and a double tap
    /// on empty space return to the authored orbit.
    @Test func twoFingerOrbitResetViewAndDoubleTap() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Script.open(session)
        var time: Double = 0
        let digest: String = try WaveKnotKeeperTest.digest(shell)
        let first: Vec2 = Vec2(8, 8)
        let second: Vec2 = Vec2(8, Script.viewHeight - 8)
        #expect(try Script.isEmpty(shell, first), "the top-left corner is empty space")
        #expect(try Script.isEmpty(shell, second), "the bottom-left corner is empty space")
        let shift: Double = 100

        /// Two fingers down on empty space, both moved right by `shift`, both lifted.
        func orbitRight() {
            Script.touch(shell, id: 1, .began, at: first, time: &time)
            Script.touch(shell, id: 2, .began, at: second, time: &time)
            Script.touch(shell, id: 1, .moved, at: Vec2(first.x + shift, first.y), time: &time)
            Script.touch(shell, id: 2, .moved, at: Vec2(second.x + shift, second.y), time: &time)
            Script.touch(shell, id: 1, .ended, at: Vec2(first.x + shift, first.y), time: &time)
            Script.touch(shell, id: 2, .ended, at: Vec2(second.x + shift, second.y), time: &time)
        }

        orbitRight()
        let orbit: WaveKnotKeeperOrbit = shell.presenter.gestures.orbit
        let wantYaw: Double = shift / Script.viewWidth * WaveKnotKeeperGestureController.yawPerViewWidth
        #expect(Swift.abs(orbit.yaw - wantYaw) < 1e-9, "yaw \(orbit.yaw)")
        #expect(Swift.abs(orbit.pitch - WaveKnotKeeperOrbit.authored.pitch) < 1e-9, "pitch \(orbit.pitch)")
        #expect(orbit != .authored)
        #expect(try WaveKnotKeeperTest.digest(shell) == digest, "an orbit never changes the digest")
        #expect(try Script.selected(shell) == nil, "fingers on empty space select nothing")
        #expect(shell.presenter.gestures.phase == .idle)
        try WaveKnotKeeperTest.draw(session)
        #expect(shell.presenter.scene.orbit == orbit, "the scene draws the controller's orbit")

        shell.presenter.resetView()
        #expect(shell.presenter.gestures.orbit == .authored)
        try WaveKnotKeeperTest.draw(session)
        #expect(shell.presenter.scene.orbit == .authored)

        orbitRight()
        #expect(shell.presenter.gestures.orbit != .authored)
        try WaveKnotKeeperTest.draw(session)
        #expect(try Script.isEmpty(shell, first), "the corner is empty space at the turned orbit")
        Script.touch(shell, id: 3, .began, at: first, time: &time)
        Script.touch(shell, id: 3, .ended, at: first, time: &time)
        #expect(shell.presenter.gestures.orbit != .authored, "one tap does not reset")
        Script.touch(shell, id: 4, .began, at: first, time: &time)
        Script.touch(shell, id: 4, .ended, at: first, time: &time)
        #expect(shell.presenter.gestures.orbit == .authored, "a double tap on empty space resets the view")
        #expect(try WaveKnotKeeperTest.digest(shell) == digest)
        try WaveKnotKeeperTest.draw(session)
        #expect(shell.presenter.scene.orbit == .authored)
    }

    /// `cancelPointers()` mid-drag drops the drag: the release sends no move.
    @Test func cancelPointersMidDragSendsNothing() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Script.open(session)
        var time: Double = 0
        let drag: Script.Drag = try #require(try Script.findDragOnSomeLevel(session, shell, accept: Script.isLegal))
        let before: WaveKnotKeeperPlay = try Script.play(shell)
        let digest: String = try WaveKnotKeeperTest.digest(shell)

        Script.dragWithoutRelease(shell, drag, time: &time)
        #expect(shell.presenter.gestures.preview != nil, "the drag names a move before the cancel")
        shell.presenter.cancelPointers()
        #expect(shell.presenter.gestures.preview == nil)
        #expect(shell.presenter.gestures.draggedPoint == nil)
        Script.touch(shell, id: 1, .ended, at: drag.end, time: &time)
        #expect(shell.presenter.gestures.phase == .idle)
        let after: WaveKnotKeeperPlay = try Script.play(shell)
        #expect(after.fingerprint == before.fingerprint, "a cancelled drag sends no move")
        #expect(after.spent == before.spent)
        #expect(try WaveKnotKeeperTest.digest(shell) == digest)
        #expect(shell.presenter.mirror.message == nil)
    }

    /// While a drag previews a move, the drawn ghost is the point the move would reach; nothing is sent before the
    /// release.
    @Test func previewMidDragIsTheWouldBePoint() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Script.open(session)
        var time: Double = 0
        let drag: Script.Drag = try #require(try Script.findDragOnSomeLevel(session, shell, accept: Script.isLegal))
        let before: WaveKnotKeeperPlay = try Script.play(shell)
        let digest: String = try WaveKnotKeeperTest.digest(shell)

        Script.dragWithoutRelease(shell, drag, time: &time)
        let preview: ScriptedAction = try #require(shell.presenter.gestures.preview, "the drag previews a move")
        #expect(preview == WaveKnotKeeperGestureController.move(point: drag.point, direction: drag.direction))
        #expect(try WaveKnotKeeperTest.digest(shell) == digest, "nothing is sent before the release")
        try WaveKnotKeeperTest.draw(session)
        let wouldBe: WaveKnotKeeperPoint = before.points[drag.point].moved(drag.direction)
        #expect(shell.presenter.scene.preview == wouldBe, "the ghost is drawn at the would-be point")

        Script.touch(shell, id: 1, .cancelled, at: drag.end, time: &time)
        #expect(try Script.play(shell).spent == before.spent, "a cancelled touch sends no move")
        try WaveKnotKeeperTest.draw(session)
        #expect(shell.presenter.scene.preview == nil, "no ghost without a drag")
    }
}
#endif
