// VoxelOrigamiGestureWiringTests — feature 444 (R02-G15-04) T-R02G1504-005 (FR-R02G1504-001 … 005; SC-R02G1504-001 …
// 003; clarifications Q1–Q5). On the simulator, through the one app's session host: scripted touches go to the
// presenter's `pointer(_:viewSize:port:)` with the shell's own `port` at a 720 × 480-point view (aspect 1.5), following
// Moonlit Mechanism's wiring tests (feature 434). Targets are cube centres (or nearby points that pick the cube),
// projected through the drawn camera of the controller's orbit (`VoxelOrigamiGestureController.camera(viewSize:
// snapshot:)`, then `VoxelOrigamiPicker.viewPoint` of `VoxelOrigamiSceneGeometry.cubeCentre`) and confirmed with
// `VoxelOrigamiPicker.pick` on the presenter's `lastSnapshot` before any touch. A cube drag goes down on a turnable
// cube and moves 40 points along the unit direction of the hinge's predicted `+1` motion
// (`VoxelOrigamiPicker.prediction(_:size:snapshot:orbit:)`), in equal moves. Levels are chosen at run time from bare
// opening cores (seed n − 1 opens level n). What the port sent is read from the shell's engine (accepted and rejected
// action counters), the core and the digest, compared with a bare core that applied the expected actions.
// Checked:
//   1. a tap on a non-root cube chooses its hinge (core.chosenHinge, mirror.hinge); the digest does not change;
//   2. a drag along the predicted `+1` motion shows "Turn hinge h forward" while dragging and on release sends one
//      `hinge.turn [h, 1]` (the kernel's verdict as a bare core gives it); the pending text is cleared;
//   3. a double tap on a turnable cube turns its hinge forward (`hinge.choose`, then `hinge.turn [h, 1]`);
//   4. a drag from the root explains `rootReason` and sends nothing;
//   5. a two-finger orbit changes `gestures.orbit` and `scene.orbit` but never the digest, a frame still draws without
//      the fallback; `resetView()` and a double tap on empty space return to `VoxelOrigamiOrbit.authored`;
//   6. on a won play (the certified plan of a level issued through the shell) a cube drag sends nothing and the mirror
//      shows `finishedReason`;
//   7. a refused action (`hinge.turn [0, 1]`, the root) is shown in words and its bare code `r02-g15.action` logged;
//   8. `cancelPointers()` in the middle of a drag clears the pending text and sends nothing.
// Synthetic timestamps based on the system uptime; no sleep, no wall-clock assertion. Explicit types and plain loops
// (CI type-check rule).
#if os(iOS)
import CoreGraphics
import Foundation
import Testing
@testable import VoxelOrigamiExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreScenes
import VoxelOrigamiCore

/// Scripted touches on Voxel Origami, placed through the drawn camera.
@MainActor
enum VoxelOrigamiGestureScript {
    typealias Shell = VoxelOrigamiTest.Shell
    typealias Snapshot = VoxelOrigamiSceneSnapshot
    typealias Geometry = VoxelOrigamiSceneGeometry
    typealias Core = VoxelOrigamiExperienceCore
    typealias Picker = VoxelOrigamiPicker
    typealias Orbit = VoxelOrigamiOrbit

    /// The view's width in points (aspect 1.5).
    static let viewWidth: Double = 720
    /// The view's height in points.
    static let viewHeight: Double = 480
    /// The view size handed with every event.
    static var viewSize: Vec2 { Vec2(viewWidth, viewHeight) }
    /// The view size as the picker takes it.
    static var size: SIMD2<Double> { SIMD2<Double>(viewWidth, viewHeight) }
    /// The time between scripted events in seconds (synthetic).
    static let frame: Double = 1.0 / 60
    /// The pause between the two taps of a double tap, seconds (inside the 0.35 s window).
    static let tapGap: Double = 0.1
    /// The moves of a scripted straight drag.
    static let dragMoves: Int = 6
    /// The length of a cube drag, points (more than the drag distance 16 and the turn distance 24).
    static let dragLength: Double = 40
    /// How far inside the view a touch point must lie, points.
    static let inset: Double = 8
    /// The radii in points around a cube's projected centre at which a touch point is tried.
    static let cubeRadii: [Double] = [0, 6, 12, 18, 24]
    /// The directions tried at each radius.
    static let cubeDirections: Int = 8
    /// The candidate levels; the first that fits is used.
    static let candidateLevels: [Int] = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]

    /// What the engine has counted so far: accepted and rejected actions.
    struct Sent: Equatable {
        /// The accepted actions.
        let accepted: Int
        /// The rejected actions.
        let rejected: Int
    }

    /// A straight cube drag: the cube (hinge), the touch-down point and the release point.
    struct Drag {
        /// The cube touched (its hinge).
        let hinge: Int
        /// The touch-down point.
        let start: Vec2
        /// The release point.
        let end: Vec2
    }

    /// Opens level `number` (seed `number − 1`) at the scripted view size (one frame drawn).
    static func open(_ session: ExperienceSession, number: Int) async throws -> Shell {
        try await VoxelOrigamiTest.open(session, seed: UInt64(number - 1),
                                        size: CGSize(width: viewWidth, height: viewHeight))
    }

    /// A synthetic clock start near the system uptime.
    static func clock() -> Double {
        ProcessInfo.processInfo.systemUptime + 1
    }

    /// The engine's action counters of `shell`.
    static func sent(_ shell: Shell) -> Sent {
        Sent(accepted: shell.engine.acceptedActions, rejected: shell.engine.rejectedActions)
    }

    /// The snapshot the presenter drew last (the gestures read it).
    static func drawn(_ shell: Shell) throws -> Snapshot {
        try #require(shell.presenter.lastSnapshot)
    }

    /// Sends one pointer event to the presenter with the shell's port; the synthetic clock advances one frame.
    static func touch(_ shell: Shell, id: Int, _ phase: PointerPhase, at location: Vec2, time: inout Double) {
        let event: PointerEvent = PointerEvent(id: id, phase: phase, location: location, timestamp: time)
        shell.presenter.pointer(event, viewSize: viewSize, port: shell.port)
        time += frame
    }

    /// A tap (down and up at `location`, one frame apart) with finger `id`.
    static func tap(_ shell: Shell, id: Int, at location: Vec2, time: inout Double) {
        touch(shell, id: id, .began, at: location, time: &time)
        touch(shell, id: id, .ended, at: location, time: &time)
    }

    /// ``dragMoves`` equal moves of finger `id` from `start` to `end` (no touch-down, no lift).
    static func moves(_ shell: Shell, id: Int, from start: Vec2, to end: Vec2, time: inout Double) {
        let delta: Vec2 = end - start
        for step in 1...dragMoves {
            let t: Double = Double(step) / Double(dragMoves)
            touch(shell, id: id, .moved, at: start + delta * t, time: &time)
        }
    }

    /// Down at `drag.start` and ``dragMoves`` moves to `drag.end` with finger `id` (not lifted).
    static func dragOver(_ shell: Shell, id: Int, _ drag: Drag, time: inout Double) {
        touch(shell, id: id, .began, at: drag.start, time: &time)
        moves(shell, id: id, from: drag.start, to: drag.end, time: &time)
    }

    /// Whether `location` lies inside the view with a margin of `margin` points.
    static func inside(_ location: Vec2, margin: Double = inset) -> Bool {
        location.x >= margin && location.x <= viewWidth - margin && location.y >= margin
            && location.y <= viewHeight - margin
    }

    /// What the picker gives for `location` on `snapshot` at `orbit`.
    static func pick(_ location: Vec2, _ snapshot: Snapshot, orbit: Orbit) -> VoxelOrigamiPick {
        Picker.pick(SIMD2<Double>(location.x, location.y), size: size, snapshot: snapshot, orbit: orbit)
    }

    /// Cube `index`'s projected centre in view points at `orbit`; nil when it does not project.
    static func centre(_ index: Int, _ snapshot: Snapshot, orbit: Orbit) -> Vec2? {
        let camera: VoxelOrigamiCamera = Geometry.camera(snapshot, aspect: viewWidth / viewHeight, orbit: orbit)
        let world: SIMD3<Double> = Geometry.cubeCentre(index, snapshot)
        guard let p: SIMD2<Double> = Picker.viewPoint(world, size: size, camera: camera) else { return nil }
        return Vec2(p.x, p.y)
    }

    /// A point ``inset`` points inside the view where the picker gives `.cube(index)` at `orbit`: the cube's projected
    /// centre first, then points on rings about it; nil when none.
    static func cubePoint(_ index: Int, _ snapshot: Snapshot, orbit: Orbit) -> Vec2? {
        guard index >= 0, index < snapshot.cubes.count, let c: Vec2 = centre(index, snapshot, orbit: orbit) else {
            return nil
        }
        for radius in cubeRadii {
            let directions: Int = radius == 0 ? 1 : cubeDirections
            for k in 0..<directions {
                let a: Double = Double(k) * 2 * Double.pi / Double(cubeDirections)
                let point: Vec2 = c + Vec2(cos(a), sin(a)) * radius
                if inside(point), pick(point, snapshot, orbit: orbit) == .cube(index) { return point }
            }
        }
        return nil
    }

    /// The first cube ≥ 1 of `snapshot` other than `excluded` with a touch point at `orbit` (cube and point).
    static func otherCube(_ snapshot: Snapshot, excluding excluded: Int, orbit: Orbit) -> (cube: Int, point: Vec2)? {
        for index in 1..<max(snapshot.cubes.count, 1) where index != excluded {
            if let point: Vec2 = cubePoint(index, snapshot, orbit: orbit) { return (index, point) }
        }
        return nil
    }

    /// The first turnable hinge of `snapshot` whose cube has a touch point at `orbit` (hinge and point).
    static func turnableCube(_ snapshot: Snapshot, orbit: Orbit) -> (hinge: Int, point: Vec2)? {
        for hinge in snapshot.turnable where hinge >= 1 {
            if let point: Vec2 = cubePoint(hinge, snapshot, orbit: orbit) { return (hinge, point) }
        }
        return nil
    }

    /// A drag of ``dragLength`` points from a turnable cube along its hinge's predicted `+1` motion, ending inside the
    /// view, for which the prediction gives step `+1`; nil when none.
    static func forwardDrag(_ snapshot: Snapshot, orbit: Orbit) -> Drag? {
        for hinge in snapshot.turnable where hinge >= 1 {
            guard let start: Vec2 = cubePoint(hinge, snapshot, orbit: orbit),
                  let prediction: VoxelOrigamiTurnPrediction = Picker.prediction(hinge, size: size,
                                                                                 snapshot: snapshot, orbit: orbit)
            else { continue }
            let plus: Vec2 = Vec2(prediction.plus.x, prediction.plus.y)
            guard plus.length > 0, plus.isFinite else { continue }
            let end: Vec2 = start + plus.normalized * dragLength
            guard inside(end) else { continue }
            let travel: Vec2 = end - start
            let step: Int? = prediction.step(for: SIMD2<Double>(travel.x, travel.y),
                                             threshold: VoxelOrigamiGestureController.turnDistance)
            if step == 1 { return Drag(hinge: hinge, start: start, end: end) }
        }
        return nil
    }

    /// A drag of ``dragLength`` points from cube `index` in the first of the four axis directions that ends inside the
    /// view; nil when the cube has no touch point.
    static func anyDrag(from index: Int, _ snapshot: Snapshot, orbit: Orbit) -> Drag? {
        guard let start: Vec2 = cubePoint(index, snapshot, orbit: orbit) else { return nil }
        let directions: [Vec2] = [Vec2(1, 0), Vec2(-1, 0), Vec2(0, 1), Vec2(0, -1)]
        for direction in directions {
            let end: Vec2 = start + direction * dragLength
            if inside(end) { return Drag(hinge: index, start: start, end: end) }
        }
        return nil
    }

    /// The first of ``candidateLevels`` whose opening core and snapshot (authored orbit) pass `fits`; chosen from the
    /// Core at run time (an issue is recorded and the first candidate returned when none does).
    static func level(_ what: String, where fits: (Core, Snapshot) -> Bool) throws -> Int {
        for number in candidateLevels {
            let core: Core = try Core.opening(number: number)
            if fits(core, core.snapshot(time: 0)) { return number }
        }
        Issue.record("no candidate level has \(what) inside the view")
        return candidateLevels[0]
    }

    /// The first of ``candidateLevels`` whose certified plan wins and whose won snapshot (authored orbit) has a
    /// non-root cube with a drag inside the view (an issue is recorded and the first candidate returned when none has).
    static func wonLevel() throws -> Int {
        for number in candidateLevels {
            let turns: [VoxelOrigamiAction] = try VoxelOrigamiTest.certifiedTurns(number)
            let core: Core = try VoxelOrigamiTest.coreAfter(number, turns)
            guard core.play.stage == .won else { continue }
            let snapshot: Snapshot = core.snapshot(time: 0)
            for index in 1..<max(snapshot.cubes.count, 1) {
                if anyDrag(from: index, snapshot, orbit: .authored) != nil { return number }
            }
        }
        Issue.record("no candidate level has a won play with a non-root cube inside the view")
        return candidateLevels[0]
    }

    /// The core `before` after applying `control` with `values`, and the adapter's answer.
    static func applied(_ before: Core, _ control: String, _ values: [Double]) -> (core: Core, result: ActionResult) {
        var copy: Core = before
        let result: ActionResult = copy.apply(ExperienceAction(control: control, values: values, step: 0))
        return (copy, result)
    }
}

@MainActor
@Suite(.serialized) struct VoxelOrigamiGestureWiringTests {
    typealias Script = VoxelOrigamiGestureScript
    typealias Core = VoxelOrigamiExperienceCore
    typealias Snapshot = VoxelOrigamiSceneSnapshot
    typealias Presenter = VoxelOrigamiPresenter
    typealias Controller = VoxelOrigamiGestureController

    /// 1. A tap on a non-root cube chooses its hinge; the play and the digest do not change.
    @Test func aTapChoosesAHinge() async throws {
        let what: String = "a cube ≥ 1 other than the chosen hinge"
        let number: Int = try Script.level(what) { (core: Core, s: Snapshot) -> Bool in
            Script.otherCube(s, excluding: core.chosenHinge, orbit: .authored) != nil
        }
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Script.open(session, number: number)
        let before: Core = try VoxelOrigamiTest.core(shell)
        let snapshot: Snapshot = try Script.drawn(shell)
        let target = try #require(Script.otherCube(snapshot, excluding: before.chosenHinge,
                                                   orbit: shell.presenter.gestures.orbit),
                                  "a cube other than the chosen hinge picks inside the view")
        let digest: String = try VoxelOrigamiTest.digest(shell)
        let sentBefore: Script.Sent = Script.sent(shell)
        var time: Double = Script.clock()

        Script.touch(shell, id: 1, .began, at: target.point, time: &time)
        #expect(shell.presenter.gestures.state == .cubePress)
        Script.touch(shell, id: 1, .ended, at: target.point, time: &time)
        let after: Core = try VoxelOrigamiTest.core(shell)
        #expect(after.chosenHinge == target.cube, "the tap chooses the cube's hinge")
        #expect(after.play.fingerprint == before.play.fingerprint, "a choice spends nothing")
        #expect(after.play.actionsSpent == before.play.actionsSpent)
        let sentAfter: Script.Sent = Script.sent(shell)
        #expect(sentAfter.accepted == sentBefore.accepted + 1, "one hinge.choose accepted")
        #expect(sentAfter.rejected == sentBefore.rejected)
        #expect(try VoxelOrigamiTest.digest(shell) == digest, "a choice never changes the digest")
        try VoxelOrigamiTest.draw(session)
        #expect(shell.presenter.mirror.hinge == target.cube, "the panel follows the chosen hinge")
        #expect(try Script.drawn(shell).chosenHinge == target.cube)
        #expect(shell.presenter.mirror.pending == nil)
        #expect(shell.presenter.gestures.state == .idle)
        #expect(shell.presenter.refusalLog.isEmpty)
    }

    /// 2. A drag along the predicted forward motion shows the pending turn and sends one forward quarter turn.
    @Test func aDragTurnsAHingeForward() async throws {
        let number: Int = try Script.level("a forward drag") { (core: Core, s: Snapshot) -> Bool in
            core.play.stage == .playing && core.play.actionsLeft >= 1
                && Script.forwardDrag(s, orbit: .authored) != nil
        }
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Script.open(session, number: number)
        let before: Core = try VoxelOrigamiTest.core(shell)
        try #require(before.play.stage == .playing)
        let snapshot: Snapshot = try Script.drawn(shell)
        let drag: Script.Drag = try #require(Script.forwardDrag(snapshot, orbit: shell.presenter.gestures.orbit),
                                             "a turnable cube can be dragged forward inside the view")
        let expected = Script.applied(before, "hinge.turn", [Double(drag.hinge), 1])
        #expect(expected.result == .accepted)
        let digest: String = try VoxelOrigamiTest.digest(shell)
        let sentBefore: Script.Sent = Script.sent(shell)
        var time: Double = Script.clock()

        Script.dragOver(shell, id: 1, drag, time: &time)
        #expect(shell.presenter.gestures.state == .cubeDrag)
        let pendingText: String = Presenter.pendingTurnText(hinge: drag.hinge, step: 1)
        #expect(pendingText == "Turn hinge \(drag.hinge) forward")
        #expect(Presenter.pendingTurnText(hinge: drag.hinge, step: -1) == "Turn hinge \(drag.hinge) back")
        #expect(shell.presenter.mirror.pending == pendingText, "the pending turn is shown while dragging")
        let described: String = shell.presenter.describe(before)
        #expect(described.contains(pendingText + "."), "\(described)")
        #expect(Script.sent(shell) == sentBefore, "nothing is sent before the release")
        #expect(try VoxelOrigamiTest.digest(shell) == digest)
        Script.touch(shell, id: 1, .ended, at: drag.end, time: &time)
        #expect(shell.presenter.mirror.pending == nil, "the pending turn is cleared on release")
        let sentAfter: Script.Sent = Script.sent(shell)
        #expect(sentAfter.accepted == sentBefore.accepted + 1, "one hinge.turn accepted")
        #expect(sentAfter.rejected == sentBefore.rejected)
        let after: Core = try VoxelOrigamiTest.core(shell)
        #expect(after.play.actionsSpent == before.play.actionsSpent + 1, "one quarter turn spends one action")
        #expect(after.play.turns == expected.core.play.turns, "the turns follow the kernel's verdict")
        #expect(after.play.stage == expected.core.play.stage)
        #expect(after.play.fingerprint == expected.core.play.fingerprint)
        #expect(after.play.records.last?.action == .turn(drag.hinge, 1))
        #expect(try VoxelOrigamiTest.digest(shell) != digest, "the turn changes the digest")
        #expect(shell.presenter.gestures.state == .idle)
        #expect(shell.presenter.refusalLog.isEmpty)
    }

    /// 3. A double tap on a turnable cube chooses its hinge and turns it forward.
    @Test func aDoubleTapTurnsAHingeForward() async throws {
        let number: Int = try Script.level("a turnable cube") { (core: Core, s: Snapshot) -> Bool in
            core.play.stage == .playing && core.play.actionsLeft >= 1
                && Script.turnableCube(s, orbit: .authored) != nil
        }
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Script.open(session, number: number)
        let before: Core = try VoxelOrigamiTest.core(shell)
        try #require(before.play.stage == .playing)
        let snapshot: Snapshot = try Script.drawn(shell)
        let target = try #require(Script.turnableCube(snapshot, orbit: shell.presenter.gestures.orbit),
                                  "a turnable cube picks inside the view")
        let chosen = Script.applied(before, "hinge.choose", [Double(target.hinge)])
        #expect(chosen.result == .accepted)
        let expected = Script.applied(chosen.core, "hinge.turn", [Double(target.hinge), 1])
        #expect(expected.result == .accepted)
        let sentBefore: Script.Sent = Script.sent(shell)
        var time: Double = Script.clock()

        Script.tap(shell, id: 1, at: target.point, time: &time)
        #expect(try VoxelOrigamiTest.core(shell).chosenHinge == target.hinge, "the first tap chooses the hinge")
        #expect(try VoxelOrigamiTest.core(shell).play.actionsSpent == before.play.actionsSpent)
        time += Script.tapGap
        Script.tap(shell, id: 2, at: target.point, time: &time)
        let sentAfter: Script.Sent = Script.sent(shell)
        #expect(sentAfter.accepted == sentBefore.accepted + 2, "hinge.choose and hinge.turn accepted")
        #expect(sentAfter.rejected == sentBefore.rejected)
        let after: Core = try VoxelOrigamiTest.core(shell)
        #expect(after.play.actionsSpent == before.play.actionsSpent + 1, "one quarter turn")
        #expect(after.play.records.last?.action == .turn(target.hinge, 1))
        #expect(after.play.fingerprint == expected.core.play.fingerprint)
        #expect(after.chosenHinge == target.hinge)
        #expect(shell.presenter.mirror.pending == nil)
        #expect(shell.presenter.gestures.state == .idle)
        #expect(shell.presenter.refusalLog.isEmpty)
    }

    /// 4. A drag from the root explains that the root has no hinge and sends nothing.
    @Test func aDragFromTheRootExplainsAndSendsNothing() async throws {
        let number: Int = try Script.level("the root") { (_: Core, s: Snapshot) -> Bool in
            Script.anyDrag(from: 0, s, orbit: .authored) != nil
        }
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Script.open(session, number: number)
        let before: Core = try VoxelOrigamiTest.core(shell)
        let snapshot: Snapshot = try Script.drawn(shell)
        let drag: Script.Drag = try #require(Script.anyDrag(from: 0, snapshot, orbit: shell.presenter.gestures.orbit),
                                             "the root picks inside the view")
        let digest: String = try VoxelOrigamiTest.digest(shell)
        let sentBefore: Script.Sent = Script.sent(shell)
        var time: Double = Script.clock()

        Script.dragOver(shell, id: 1, drag, time: &time)
        #expect(shell.presenter.mirror.message == Controller.rootReason, "the drag says why it does nothing")
        #expect(Controller.rootReason == "The root cube has no hinge")
        #expect(shell.presenter.mirror.pending == nil, "the root previews nothing")
        Script.touch(shell, id: 1, .ended, at: drag.end, time: &time)
        #expect(Script.sent(shell) == sentBefore, "a drag from the root sends nothing")
        #expect(try VoxelOrigamiTest.digest(shell) == digest)
        #expect(try VoxelOrigamiTest.core(shell).play.fingerprint == before.play.fingerprint)
        #expect(shell.presenter.mirror.message == Controller.rootReason)
        #expect(shell.presenter.mirror.pending == nil)
        #expect(shell.presenter.gestures.state == .idle)
        #expect(shell.presenter.refusalLog.isEmpty)
    }

    /// 5. A two-finger drag orbits the camera and changes no digest; a frame still draws; "Reset view" and a double tap
    /// on empty space return to the authored orbit.
    @Test func anOrbitChangesTheViewButNotTheDigest() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Script.open(session, number: Script.candidateLevels[0])
        let digest: String = try VoxelOrigamiTest.digest(shell)
        let sentBefore: Script.Sent = Script.sent(shell)
        #expect(shell.presenter.gestures.orbit == .authored)
        #expect(shell.presenter.scene.orbit == .authored)
        var time: Double = Script.clock()

        let first: Vec2 = Vec2(8, 8)
        let second: Vec2 = Vec2(8, Script.viewHeight - 8)
        let shift: Double = 100
        Script.touch(shell, id: 1, .began, at: first, time: &time)
        Script.touch(shell, id: 2, .began, at: second, time: &time)
        #expect(shell.presenter.gestures.state == .orbiting)
        Script.touch(shell, id: 1, .moved, at: Vec2(first.x + shift, first.y), time: &time)
        Script.touch(shell, id: 2, .moved, at: Vec2(second.x + shift, second.y), time: &time)
        Script.touch(shell, id: 1, .ended, at: Vec2(first.x + shift, first.y), time: &time)
        Script.touch(shell, id: 2, .ended, at: Vec2(second.x + shift, second.y), time: &time)
        let orbit: VoxelOrigamiOrbit = shell.presenter.gestures.orbit
        #expect(orbit != .authored, "two fingers orbit the camera")
        #expect(orbit == orbit.clamped())
        #expect(shell.presenter.scene.orbit == orbit, "the scene takes the controller's orbit")
        #expect(shell.presenter.gestures.state == .idle)
        #expect(shell.presenter.mirror.pending == nil)
        #expect(Script.sent(shell) == sentBefore, "an orbit sends nothing")
        #expect(try VoxelOrigamiTest.digest(shell) == digest, "an orbit never changes the digest")
        try VoxelOrigamiTest.draw(session)
        #expect(shell.presenter.fallbackReason == nil, "\(shell.presenter.fallbackReason ?? "")")
        #expect(shell.presenter.lastSnapshot != nil)
        #expect(shell.presenter.scene.orbit == orbit, "the scene draws the controller's orbit")
        #expect(try VoxelOrigamiTest.digest(shell) == digest)

        shell.presenter.resetView()
        #expect(shell.presenter.gestures.orbit == .authored, "Reset view restores the authored orbit")
        #expect(shell.presenter.scene.orbit == .authored)

        // Orbit again, then a double tap on empty space returns to the authored orbit.
        time += 1
        Script.touch(shell, id: 3, .began, at: first, time: &time)
        Script.touch(shell, id: 4, .began, at: second, time: &time)
        Script.touch(shell, id: 3, .moved, at: Vec2(first.x + shift, first.y), time: &time)
        Script.touch(shell, id: 4, .moved, at: Vec2(second.x + shift, second.y), time: &time)
        Script.touch(shell, id: 3, .ended, at: Vec2(first.x + shift, first.y), time: &time)
        Script.touch(shell, id: 4, .ended, at: Vec2(second.x + shift, second.y), time: &time)
        #expect(shell.presenter.gestures.orbit != .authored)
        try VoxelOrigamiTest.draw(session)
        let snapshot: Snapshot = try Script.drawn(shell)
        let corner: Vec2 = Vec2(5, 5)
        try #require(Script.pick(corner, snapshot, orbit: shell.presenter.gestures.orbit) == .empty,
                     "the corner is empty space")
        time += 1
        Script.tap(shell, id: 5, at: corner, time: &time)
        #expect(shell.presenter.gestures.orbit != .authored, "a single tap on empty space keeps the orbit")
        time += Script.tapGap
        Script.tap(shell, id: 6, at: corner, time: &time)
        #expect(shell.presenter.gestures.orbit == .authored, "a double tap on empty space resets the view")
        #expect(shell.presenter.scene.orbit == .authored)
        try VoxelOrigamiTest.draw(session)
        #expect(shell.presenter.fallbackReason == nil)
        #expect(Script.sent(shell) == sentBefore)
        #expect(try VoxelOrigamiTest.digest(shell) == digest)
        #expect(shell.presenter.refusalLog.isEmpty)
    }

    /// 6. On a won play a cube drag sends nothing and the mirror explains that the play is over.
    @Test func aDragOnAWonPlaySendsNothing() async throws {
        let number: Int = try Script.wonLevel()
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Script.open(session, number: number)
        let turns: [VoxelOrigamiAction] = try VoxelOrigamiTest.certifiedTurns(number)
        try #require(!turns.isEmpty, "level \(number) has a certified plan")
        let accepted: Int = VoxelOrigamiTest.issue(shell, turns)
        #expect(accepted == turns.count)
        let won: Core = try VoxelOrigamiTest.core(shell)
        try #require(won.play.stage == .won, "the certified plan wins level \(number)")
        try VoxelOrigamiTest.draw(session)
        let snapshot: Snapshot = try Script.drawn(shell)
        #expect(snapshot.stage == .won)
        let orbit: VoxelOrigamiOrbit = shell.presenter.gestures.orbit
        var found: Script.Drag?
        for index in 1..<max(snapshot.cubes.count, 1) where found == nil {
            found = Script.anyDrag(from: index, snapshot, orbit: orbit)
        }
        let drag: Script.Drag = try #require(found, "a non-root cube picks inside the view")
        let digest: String = try VoxelOrigamiTest.digest(shell)
        let sentBefore: Script.Sent = Script.sent(shell)
        var time: Double = Script.clock()

        Script.dragOver(shell, id: 1, drag, time: &time)
        #expect(shell.presenter.mirror.pending == nil, "a finished play previews nothing")
        Script.touch(shell, id: 1, .ended, at: drag.end, time: &time)
        #expect(Script.sent(shell) == sentBefore, "a drag on a won play sends nothing")
        #expect(try VoxelOrigamiTest.digest(shell) == digest)
        #expect(try VoxelOrigamiTest.core(shell).play.fingerprint == won.play.fingerprint)
        #expect(shell.presenter.mirror.message == Controller.finishedReason)
        #expect(Presenter.finishedMessage == Controller.finishedReason)
        #expect(Controller.finishedReason == "The play is over: undo or go to the next level")
        #expect(shell.presenter.refusalLog.isEmpty, "nothing was refused: nothing was sent")
        #expect(shell.presenter.gestures.state == .idle)
        let described: String = shell.presenter.describe(try VoxelOrigamiTest.core(shell))
        #expect(described.contains(Presenter.finishedMessage + "."), "\(described)")
        #expect(shell.presenter.mirror.status == "Won")
    }

    /// 7. A refused action is shown in words and its bare code logged.
    @Test func aRefusedActionIsShownAndLogged() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Script.open(session, number: Script.candidateLevels[0])
        let before: Core = try VoxelOrigamiTest.core(shell)
        try #require(before.play.stage == .playing)
        let expected = Script.applied(before, "hinge.turn", [0, 1])
        #expect(!expected.result.isAccepted, "the root has no hinge to turn")
        let digest: String = try VoxelOrigamiTest.digest(shell)
        let sentBefore: Script.Sent = Script.sent(shell)

        let result: ActionResult = shell.presenter.send("hinge.turn", [0, 1], port: shell.port)
        #expect(!result.isAccepted)
        #expect(VoxelOrigamiMirror.bareCode(result.code) == "r02-g15.action", "\(result.code)")
        let sentAfter: Script.Sent = Script.sent(shell)
        #expect(sentAfter.accepted == sentBefore.accepted)
        #expect(sentAfter.rejected == sentBefore.rejected + 1, "one hinge.turn refused")
        #expect(try VoxelOrigamiTest.digest(shell) == digest, "a refused action changes nothing")
        #expect(try VoxelOrigamiTest.core(shell).play.fingerprint == before.play.fingerprint)
        let code: String = try #require(shell.presenter.refusalLog.last, "the refusal's code is logged")
        #expect(shell.presenter.refusalLog.count == 1)
        #expect(code == "r02-g15.action", "the bare code, without the engine's prefix: \(code)")
        let message: String = try #require(shell.presenter.mirror.message, "the refusal is shown")
        #expect(message.hasPrefix("That change was refused"), "\(message)")
        #expect(message == "That change was refused: \(VoxelOrigamiMirror.refusalText(code: code)).")
    }

    /// 8. A drag cancelled by suspension clears the pending text and sends nothing.
    @Test func aCancelledDragSendsNothing() async throws {
        let number: Int = try Script.level("a forward drag") { (core: Core, s: Snapshot) -> Bool in
            core.play.stage == .playing && core.play.actionsLeft >= 1
                && Script.forwardDrag(s, orbit: .authored) != nil
        }
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Script.open(session, number: number)
        let before: Core = try VoxelOrigamiTest.core(shell)
        let snapshot: Snapshot = try Script.drawn(shell)
        let drag: Script.Drag = try #require(Script.forwardDrag(snapshot, orbit: shell.presenter.gestures.orbit),
                                             "a turnable cube can be dragged forward inside the view")
        let digest: String = try VoxelOrigamiTest.digest(shell)
        let sentBefore: Script.Sent = Script.sent(shell)
        var time: Double = Script.clock()

        Script.dragOver(shell, id: 1, drag, time: &time)
        #expect(shell.presenter.mirror.pending == Presenter.pendingTurnText(hinge: drag.hinge, step: 1))
        shell.presenter.cancelPointers()
        #expect(shell.presenter.mirror.pending == nil, "a cancel clears the pending text")
        #expect(shell.presenter.gestures.state == .idle)
        #expect(Script.sent(shell) == sentBefore, "a cancelled drag sends nothing")
        #expect(try VoxelOrigamiTest.digest(shell) == digest)
        #expect(try VoxelOrigamiTest.core(shell).play.fingerprint == before.play.fingerprint)
        #expect(shell.presenter.refusalLog.isEmpty)
    }
}
#endif
