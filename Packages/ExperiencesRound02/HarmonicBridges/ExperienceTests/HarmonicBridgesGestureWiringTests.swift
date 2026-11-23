// HarmonicBridgesGestureWiringTests — feature 414 (R02-G12-04) T-R02G1204-005 (FR-R02G1204-001 … 007)
// On the simulator, through the one app's session host: scripted touches go to the presenter's
// `pointer(_:viewSize:port:)` with the shell's own `port` at a 720 × 480-point view (aspect 1.5). Targets are points on
// a string's segment between its islands' top centres, the goal island's top centre or a step pip, projected
// through the camera of the controller's orbit (`HarmonicBridgesSceneGeometry.camera(_:aspect:orbit:)`, then
// `HarmonicBridgesPicker.viewPoint`) into view points (origin top left) and confirmed with `HarmonicBridgesPicker.pick`
// on the presenter's `lastSnapshot` before any touch. The level is chosen at run time from the geometry of bare opening
// cores (the first of the candidates whose targets all pick inside the view). What the port sent is read from the
// shell's engine (accepted and rejected action counters), the core and the digest, compared with a bare core that
// applied the expected action.
// Checked:
//   1. a tap on a string chooses it at its current peg in the mirror, sends nothing (digest unchanged) and describes
//      its resonance;
//   2. a vertical drag up by 2 × 24 points from an unlocked string sends one `string.tune` to current + 2 (clamped),
//      accepted; the mirror shows that string and peg;
//   3. a drag that comes back to its start sends nothing and the mirror's peg returns to the current peg;
//   4. a tap on the goal island (or a step pip) sends one `crossing.test`;
//   5. a two-finger drag orbits and never changes the digest; `resetView()` and a double tap on empty space return to
//      `.authored`;
//   6. a refused action is shown in words and its code kept in `refusalLog`;
//   7. on a won play (the certified solution sent through the shell) a tuning drag sends nothing and the mirror shows
//      `HarmonicBridgesPresenter.finishedMessage`, which the description also contains;
//   8. the gesture actions are a subset of the native actions.
// Synthetic timestamps based on the system uptime; no sleep, no wall-clock assertion. Explicit types and plain loops
// (CI type-check rule).
#if os(iOS)
import CoreGraphics
import Foundation
import HarmonicBridgesCore
import Testing
@testable import HarmonicBridgesExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreScenes

/// Scripted touches on Harmonic Bridges, placed through the drawn camera.
@MainActor
enum HarmonicBridgesGestureScript {
    typealias Shell = ExperienceShell<HarmonicBridgesPresenter>
    typealias Snapshot = HarmonicBridgesSceneSnapshot
    typealias Geometry = HarmonicBridgesSceneGeometry
    typealias Core = HarmonicBridgesExperienceCore
    typealias Picker = HarmonicBridgesPicker
    typealias Controller = HarmonicBridgesGestureController

    /// The view's size in points (aspect 1.5).
    static let viewWidth: Double = 720
    static let viewHeight: Double = 480
    /// The view size handed with every event.
    static var viewSize: Vec2 { Vec2(viewWidth, viewHeight) }
    /// The view size as the picker takes it.
    static var size: SIMD2<Double> { SIMD2<Double>(viewWidth, viewHeight) }
    /// The time between scripted events in seconds (synthetic).
    static let frame: Double = 1.0 / 60
    /// The moves of a scripted drag.
    static let dragMoves: Int = 6
    /// The grid step in points of the search for empty space.
    static let gridStep: Double = 12
    /// The upward travel in points of a tuning drag: two pegs.
    static var lift: Double { 2 * Controller.pointsPerPeg }
    /// The least distance in points of a string point from the top of the view, so that a lift stays inside it.
    static var liftRoom: Double { lift + 8 }
    /// The candidate levels (the first whose targets all pick inside the view is used).
    static let candidateLevels: [Int] = [1, 11, 31, 41, 61]
    /// The fractions along a string at which a touch point is tried.
    static let fractions: [Double] = [0.5, 0.4, 0.6, 0.3, 0.7, 0.25, 0.75, 0.2, 0.8]

    /// What the engine has counted so far: accepted and rejected actions.
    struct Sent: Equatable {
        let accepted: Int
        let rejected: Int
    }

    /// A string to drag: its index, its current peg, the tuned peg two pegs up (clamped) and a touch point on it.
    struct Tuning {
        let string: Int
        let current: Int
        let target: Int
        let point: Vec2
    }

    /// Opens level `number` (seed `number − 1`) at the scripted view size (one frame drawn).
    static func open(_ session: ExperienceSession, number: Int) async throws -> Shell {
        try await HarmonicBridgesTest.open(session, seed: UInt64(number - 1),
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

    /// A one-finger drag with finger `id` from `start` straight up by ``lift`` points: down, moves, up.
    static func liftDrag(_ shell: Shell, id: Int, from start: Vec2, time: inout Double) {
        let end: Vec2 = Vec2(start.x, start.y - lift)
        touch(shell, id: id, .began, at: start, time: &time)
        moves(shell, id: id, from: start, to: end, time: &time)
        touch(shell, id: id, .ended, at: end, time: &time)
    }

    /// A two-finger orbit: fingers `id` and `id + 1` down near the left corners, both moved `shift` points right and
    /// lifted.
    static func orbit(_ shell: Shell, id: Int, shift: Double = 100, time: inout Double) {
        let first: Vec2 = Vec2(8, 8)
        let second: Vec2 = Vec2(8, viewHeight - 8)
        touch(shell, id: id, .began, at: first, time: &time)
        touch(shell, id: id + 1, .began, at: second, time: &time)
        touch(shell, id: id, .moved, at: Vec2(first.x + shift, first.y), time: &time)
        touch(shell, id: id + 1, .moved, at: Vec2(second.x + shift, second.y), time: &time)
        touch(shell, id: id, .ended, at: Vec2(first.x + shift, first.y), time: &time)
        touch(shell, id: id + 1, .ended, at: Vec2(second.x + shift, second.y), time: &time)
    }

    /// Whether `location` lies inside the view with a margin of `inset` points.
    static func inside(_ location: Vec2, inset: Double = 0) -> Bool {
        location.x >= inset && location.x <= viewWidth - inset && location.y >= inset
            && location.y <= viewHeight - inset
    }

    /// What the picker gives for `location` on `snapshot` at `orbit`.
    static func pick(_ location: Vec2, _ snapshot: Snapshot, orbit: HarmonicBridgesOrbit) -> HarmonicBridgesPick {
        Picker.pick(SIMD2<Double>(location.x, location.y), size: size, snapshot: snapshot, orbit: orbit)
    }

    /// `world` in view points (origin top left) through the camera of `orbit` for `snapshot` at the scripted view
    /// size; nil behind the camera.
    static func viewPoint(_ world: SIMD3<Double>, _ snapshot: Snapshot, orbit: HarmonicBridgesOrbit) -> Vec2? {
        let camera: HarmonicBridgesCamera = Geometry.camera(snapshot, aspect: viewWidth / viewHeight, orbit: orbit)
        guard let p: SIMD2<Double> = Picker.viewPoint(world, size: size, camera: camera) else { return nil }
        return Vec2(p.x, p.y)
    }

    /// A point on string `index`'s segment (between its islands' top centres) 8 points inside the view and at least
    /// `top` points from its top edge, where the picker gives `.string(index)` at `orbit`; nil when none.
    static func stringPoint(_ index: Int, _ snapshot: Snapshot, orbit: HarmonicBridgesOrbit,
                            top: Double = 8) -> Vec2? {
        let ends = Geometry.stringEnds(index, snapshot)
        for u in fractions {
            let world: SIMD3<Double> = ends.a + (ends.b - ends.a) * u
            guard let point: Vec2 = viewPoint(world, snapshot, orbit: orbit), inside(point, inset: 8),
                  point.y >= top else { continue }
            if pick(point, snapshot, orbit: orbit) == .string(index) { return point }
        }
        return nil
    }

    /// The first string of `snapshot` with a touch point (``liftRoom`` from the top) at `orbit`, locked or not.
    static func anyString(_ snapshot: Snapshot, orbit: HarmonicBridgesOrbit) -> (string: Int, point: Vec2)? {
        for index in snapshot.strings.indices {
            if let point: Vec2 = stringPoint(index, snapshot, orbit: orbit, top: liftRoom) { return (index, point) }
        }
        return nil
    }

    /// The first unlocked string of `core`'s play whose tune to current + 2 (clamped) differs from the current peg, is
    /// accepted by a copy of `core`, and has a touch point (``liftRoom`` from the top) on `snapshot` at `orbit`.
    static func tuning(_ core: Core, _ snapshot: Snapshot, orbit: HarmonicBridgesOrbit) -> Tuning? {
        for index in snapshot.strings.indices where !snapshot.strings[index].locked {
            guard index < core.play.pegs.count else { continue }
            let current: Int = core.play.pegs[index]
            let target: Int = Controller.previewedPeg(current: current, upward: lift)
            if target == current { continue }
            if !applied(core, "string.tune", [Double(index), Double(target)]).result.isAccepted { continue }
            guard let point: Vec2 = stringPoint(index, snapshot, orbit: orbit, top: liftRoom) else { continue }
            return Tuning(string: index, current: current, target: target, point: point)
        }
        return nil
    }

    /// The goal island's top centre when it picks as `.goal`, else the first step pip centre that picks as its pip,
    /// 8 points inside the view at `orbit`; nil when none.
    static func testPoint(_ snapshot: Snapshot,
                          orbit: HarmonicBridgesOrbit) -> (point: Vec2, pick: HarmonicBridgesPick)? {
        if snapshot.goal >= 0, snapshot.goal < snapshot.islands.count,
           let goal: Vec2 = viewPoint(Geometry.islandTop(snapshot.goal, snapshot), snapshot, orbit: orbit),
           inside(goal, inset: 8), pick(goal, snapshot, orbit: orbit) == .goal {
            return (goal, .goal)
        }
        for step in 0..<max(snapshot.steps, 0) {
            guard let pip: Vec2 = viewPoint(Geometry.stepPip(step, snapshot), snapshot, orbit: orbit),
                  inside(pip, inset: 8) else { continue }
            if pick(pip, snapshot, orbit: orbit) == .pip(step) { return (pip, .pip(step)) }
        }
        return nil
    }

    /// A point of empty space (the picker gives `.empty`) at least 8 points inside the view: the four corners first,
    /// then a grid; nil when none.
    static func emptyPoint(_ snapshot: Snapshot, orbit: HarmonicBridgesOrbit) -> Vec2? {
        var points: [Vec2] = [Vec2(8, 8), Vec2(viewWidth - 8, 8), Vec2(8, viewHeight - 8),
                              Vec2(viewWidth - 8, viewHeight - 8)]
        var y: Double = 8
        while y <= viewHeight - 8 {
            var x: Double = 8
            while x <= viewWidth - 8 {
                points.append(Vec2(x, y))
                x += gridStep
            }
            y += gridStep
        }
        for point in points where pick(point, snapshot, orbit: orbit) == .empty {
            return point
        }
        return nil
    }

    /// The first candidate level whose opening snapshot (authored orbit) has a tuning string and a test target inside
    /// the view; chosen from the geometry at run time.
    static func level() throws -> Int {
        for number in candidateLevels {
            let core: Core = try Core.opening(number: number)
            let snapshot: Snapshot = core.snapshot(time: 0)
            if tuning(core, snapshot, orbit: .authored) == nil { continue }
            if testPoint(snapshot, orbit: .authored) == nil { continue }
            return number
        }
        Issue.record("no candidate level has a tuning string and a test target inside the view")
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
@Suite(.serialized) struct HarmonicBridgesGestureWiringTests {
    typealias Script = HarmonicBridgesGestureScript
    typealias Core = HarmonicBridgesExperienceCore

    /// 1. A tap on a string chooses it at its current peg and describes its resonance; nothing is sent.
    @Test func aTapOnAStringChoosesIt() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Script.open(session, number: try Script.level())
        let snapshot: HarmonicBridgesSceneSnapshot = try Script.drawn(shell)
        // Prefer a string other than the one the level opens with chosen (string 0), so the choice visibly moves.
        var chosen: (string: Int, point: Vec2)? = nil
        for index in snapshot.strings.indices.reversed() {
            if let point: Vec2 = Script.stringPoint(index, snapshot, orbit: .authored) {
                chosen = (index, point)
                break
            }
        }
        let target = try #require(chosen, "a string picks inside the view")
        #expect(Script.pick(target.point, snapshot, orbit: shell.presenter.gestures.orbit) == .string(target.string))
        let digest: String = try HarmonicBridgesTest.digest(shell)
        let sentBefore: Script.Sent = Script.sent(shell)
        var time: Double = Script.clock()

        Script.touch(shell, id: 1, .began, at: target.point, time: &time)
        #expect(shell.presenter.gestures.state == .stringPress)
        Script.touch(shell, id: 1, .ended, at: target.point, time: &time)
        #expect(shell.presenter.mirror.string == target.string, "the tap chooses the string")
        #expect(shell.presenter.mirror.peg == snapshot.pegs[target.string], "at its current peg")
        let step: Int = HarmonicBridgesSceneGeometry.drawnStep(snapshot, reduceMotion: shell.presenter.reduceMotion)
        let expected: String = HarmonicBridgesPresenter.resonanceText(target.string, snapshot: snapshot, step: step)
        #expect(shell.presenter.mirror.message == expected, "the resonance is described")
        #expect(Script.sent(shell) == sentBefore, "a tap on a string sends nothing")
        #expect(try HarmonicBridgesTest.digest(shell) == digest, "a choice never changes the digest")
        #expect(shell.presenter.gestures.state == .idle)
        #expect(shell.presenter.refusalLog.isEmpty)
    }

    /// 2. A drag up by two pegs' worth of points from an unlocked string tunes it to current + 2.
    @Test func aLiftDragTunesTheString() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Script.open(session, number: try Script.level())
        let before: Core = try HarmonicBridgesTest.core(shell)
        let snapshot: HarmonicBridgesSceneSnapshot = try Script.drawn(shell)
        let tuning: Script.Tuning = try #require(Script.tuning(before, snapshot, orbit: .authored),
                                                 "an unlocked string to tune picks inside the view")
        let expected = Script.applied(before, "string.tune", [Double(tuning.string), Double(tuning.target)])
        #expect(expected.result == .accepted)
        let digest: String = try HarmonicBridgesTest.digest(shell)
        let sentBefore: Script.Sent = Script.sent(shell)
        var time: Double = Script.clock()

        Script.liftDrag(shell, id: 1, from: tuning.point, time: &time)
        let sentAfter: Script.Sent = Script.sent(shell)
        #expect(sentAfter.accepted == sentBefore.accepted + 1, "one string.tune accepted")
        #expect(sentAfter.rejected == sentBefore.rejected)
        let after: Core = try HarmonicBridgesTest.core(shell)
        #expect(after.play.pegs[tuning.string] == tuning.target, "the string is at current + 2 (clamped)")
        #expect(after.play.actionsSpent == before.play.actionsSpent + 1)
        #expect(after.play.records.last?.action == .tune(tuning.string, tuning.target))
        #expect(after.play.fingerprint == expected.core.play.fingerprint)
        #expect(try HarmonicBridgesTest.digest(shell) != digest, "the tune changes the digest")
        #expect(shell.presenter.mirror.string == tuning.string, "the mirror shows the string")
        #expect(shell.presenter.mirror.peg == tuning.target, "and the tuned peg")
        #expect(shell.presenter.mirror.message == nil)
        #expect(shell.presenter.gestures.state == .idle)
        #expect(shell.presenter.refusalLog.isEmpty)
    }

    /// 3. A drag that comes back to its start sends nothing; the mirror's peg returns to the current peg.
    @Test func aDragBackToItsStartSendsNothing() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Script.open(session, number: try Script.level())
        let before: Core = try HarmonicBridgesTest.core(shell)
        let snapshot: HarmonicBridgesSceneSnapshot = try Script.drawn(shell)
        let tuning: Script.Tuning = try #require(Script.tuning(before, snapshot, orbit: .authored),
                                                 "an unlocked string to drag picks inside the view")
        let digest: String = try HarmonicBridgesTest.digest(shell)
        let sentBefore: Script.Sent = Script.sent(shell)
        let top: Vec2 = Vec2(tuning.point.x, tuning.point.y - Script.lift)
        var time: Double = Script.clock()

        Script.touch(shell, id: 1, .began, at: tuning.point, time: &time)
        Script.moves(shell, id: 1, from: tuning.point, to: top, time: &time)
        #expect(shell.presenter.gestures.state == .pegDrag)
        #expect(shell.presenter.mirror.string == tuning.string, "the preview chooses the string")
        #expect(shell.presenter.mirror.peg == tuning.target, "the preview follows the drag")
        Script.moves(shell, id: 1, from: top, to: tuning.point, time: &time)
        Script.touch(shell, id: 1, .ended, at: tuning.point, time: &time)
        #expect(Script.sent(shell) == sentBefore, "a drag back to its start sends nothing")
        #expect(try HarmonicBridgesTest.digest(shell) == digest)
        #expect(try HarmonicBridgesTest.core(shell).play.fingerprint == before.play.fingerprint)
        #expect(shell.presenter.mirror.string == tuning.string)
        #expect(shell.presenter.mirror.peg == tuning.current, "the mirror's peg returns to the current peg")
        #expect(shell.presenter.gestures.state == .idle)
        #expect(shell.presenter.refusalLog.isEmpty)
    }

    /// 4. A tap on the goal island (or a step pip) tests the crossing.
    @Test func aTapOnTheGoalTestsTheCrossing() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Script.open(session, number: try Script.level())
        let before: Core = try HarmonicBridgesTest.core(shell)
        let snapshot: HarmonicBridgesSceneSnapshot = try Script.drawn(shell)
        let target = try #require(Script.testPoint(snapshot, orbit: .authored),
                                  "the goal island or a step pip picks inside the view")
        #expect(Script.pick(target.point, snapshot, orbit: shell.presenter.gestures.orbit) == target.pick)
        let expected = Script.applied(before, "crossing.test", [])
        #expect(expected.result.isAccepted)
        let sentBefore: Script.Sent = Script.sent(shell)
        var time: Double = Script.clock()

        Script.touch(shell, id: 1, .began, at: target.point, time: &time)
        #expect(shell.presenter.gestures.state == .targetPress)
        Script.touch(shell, id: 1, .ended, at: target.point, time: &time)
        let sentAfter: Script.Sent = Script.sent(shell)
        #expect(sentAfter.accepted == sentBefore.accepted + 1, "one crossing.test accepted")
        #expect(sentAfter.rejected == sentBefore.rejected)
        let after: Core = try HarmonicBridgesTest.core(shell)
        #expect(after.play.actionsSpent == before.play.actionsSpent + 1, "one action spent")
        #expect(after.play.records.last?.action == .test)
        #expect(after.play.stage == .won || after.play.stage == .failed, "the kernel decides the crossing")
        #expect(after.play.stage == expected.core.play.stage)
        #expect(after.play.fingerprint == expected.core.play.fingerprint)
        #expect(shell.presenter.gestures.state == .idle)
        #expect(shell.presenter.refusalLog.isEmpty)
    }

    /// 5. A two-finger drag orbits and changes no digest; a double tap on empty space and `resetView()` return to the
    /// authored orbit.
    @Test func anOrbitChangesTheViewAndResets() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Script.open(session, number: try Script.level())
        let digest: String = try HarmonicBridgesTest.digest(shell)
        let sentBefore: Script.Sent = Script.sent(shell)
        #expect(shell.presenter.gestures.orbit == .authored)
        var time: Double = Script.clock()

        Script.orbit(shell, id: 1, time: &time)
        let orbit: HarmonicBridgesOrbit = shell.presenter.gestures.orbit
        #expect(orbit != .authored, "two fingers orbit the camera")
        #expect(Swift.abs(orbit.yaw) <= HarmonicBridgesOrbit.yawLimit + 1e-12)
        #expect(HarmonicBridgesOrbit.pitchRange.contains(orbit.pitch))
        #expect(orbit == orbit.clamped())
        #expect(shell.presenter.scene.orbit == orbit, "the scene takes the controller's orbit")
        #expect(shell.presenter.gestures.state == .idle)
        #expect(Script.sent(shell) == sentBefore, "an orbit sends nothing")
        #expect(try HarmonicBridgesTest.digest(shell) == digest, "an orbit never changes the digest")
        try HarmonicBridgesTest.draw(session)
        #expect(shell.presenter.scene.orbit == orbit, "the scene draws the controller's orbit")
        #expect(try HarmonicBridgesTest.digest(shell) == digest)

        time += 1
        let empty: Vec2 = try #require(Script.emptyPoint(try Script.drawn(shell), orbit: orbit),
                                       "empty space inside the view")
        Script.tap(shell, id: 3, at: empty, time: &time)
        #expect(shell.presenter.gestures.orbit == orbit, "one tap keeps the orbit")
        Script.tap(shell, id: 4, at: empty, time: &time)
        #expect(shell.presenter.gestures.orbit == .authored, "a double tap on empty space resets the view")
        #expect(shell.presenter.scene.orbit == .authored)
        #expect(Script.sent(shell) == sentBefore)
        #expect(try HarmonicBridgesTest.digest(shell) == digest)

        time += 1
        Script.orbit(shell, id: 5, time: &time)
        #expect(shell.presenter.gestures.orbit != .authored)
        shell.presenter.resetView()
        #expect(shell.presenter.gestures.orbit == .authored, "Reset view restores the authored orbit")
        #expect(shell.presenter.scene.orbit == .authored)
        try HarmonicBridgesTest.draw(session)
        #expect(shell.presenter.scene.orbit == .authored)
        #expect(Script.sent(shell) == sentBefore)
        #expect(try HarmonicBridgesTest.digest(shell) == digest)
        #expect(shell.presenter.refusalLog.isEmpty)
    }

    /// 6. A refused action is shown in words and its code is logged.
    @Test func aRefusedActionIsShownAndLogged() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Script.open(session, number: try Script.level())
        let before: Core = try HarmonicBridgesTest.core(shell)
        var unlocked: Int? = nil
        for index in before.play.level.strings.indices where !before.play.level.strings[index].locked {
            unlocked = index
            break
        }
        let string: Int = try #require(unlocked, "the level has an unlocked string")
        let current: Int = before.play.pegs[string]
        let values: [Double] = [Double(string), Double(current)]
        let expected = Script.applied(before, "string.tune", values)
        #expect(expected.result.code == "action.rule.r02-g12.noop", "a tune to the current peg is a no-op")
        let digest: String = try HarmonicBridgesTest.digest(shell)
        let sentBefore: Script.Sent = Script.sent(shell)

        let result: ActionResult = shell.presenter.send("string.tune", values, port: shell.port)
        #expect(!result.isAccepted)
        #expect(result.code == "action.rule.r02-g12.noop")
        #expect(shell.presenter.refusalLog.last == "action.rule.r02-g12.noop", "the refusal's code is logged")
        #expect(shell.presenter.refusalLog.count == 1)
        let message: String = try #require(shell.presenter.mirror.message, "the refusal is shown")
        #expect(message.hasPrefix("That change was refused"), "\(message)")
        #expect(message == "That change was refused: "
                + HarmonicBridgesMirror.refusalText(code: "r02-g12.noop") + ".")
        #expect(message == "That change was refused: that string is already at that peg.", "the kernel code in words")
        let sentAfter: Script.Sent = Script.sent(shell)
        #expect(sentAfter.accepted == sentBefore.accepted)
        #expect(sentAfter.rejected == sentBefore.rejected + 1, "one string.tune refused")
        #expect(try HarmonicBridgesTest.digest(shell) == digest, "a refused action changes nothing")
    }

    /// 7. On a won play a tuning drag sends nothing and the mirror explains that the play is over.
    @Test func aDragOnAWonPlaySendsNothing() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Script.open(session, number: try Script.level())
        let number: Int = try HarmonicBridgesTest.core(shell).levelNumber
        let actions: [HarmonicBridgesAction] = try HarmonicBridgesTest.certifiedActions(number)
        try #require(!actions.isEmpty, "level \(number) has a certified solution")
        let accepted: Int = HarmonicBridgesTest.issue(shell, actions)
        #expect(accepted == actions.count)
        let won: Core = try HarmonicBridgesTest.core(shell)
        try #require(won.play.stage == .won, "the certified solution wins level \(number)")
        try HarmonicBridgesTest.draw(session)
        let snapshot: HarmonicBridgesSceneSnapshot = try Script.drawn(shell)
        #expect(snapshot.stage == .won)
        let orbit: HarmonicBridgesOrbit = shell.presenter.gestures.orbit
        let target = try #require(Script.anyString(snapshot, orbit: orbit), "a string picks inside the view")
        #expect(Script.pick(target.point, snapshot, orbit: orbit) == .string(target.string))
        let digest: String = try HarmonicBridgesTest.digest(shell)
        let sentBefore: Script.Sent = Script.sent(shell)
        var time: Double = Script.clock()

        Script.liftDrag(shell, id: 1, from: target.point, time: &time)
        #expect(Script.sent(shell) == sentBefore, "a drag on a won play sends nothing")
        #expect(try HarmonicBridgesTest.digest(shell) == digest)
        #expect(try HarmonicBridgesTest.core(shell).play.fingerprint == won.play.fingerprint)
        #expect(shell.presenter.mirror.message == HarmonicBridgesPresenter.finishedMessage)
        #expect(shell.presenter.refusalLog.isEmpty, "nothing was refused: nothing was sent")
        #expect(shell.presenter.gestures.state == .idle)
        let described: String = shell.presenter.describe(try HarmonicBridgesTest.core(shell))
        #expect(described.contains(HarmonicBridgesPresenter.finishedMessage), "\(described)")
    }

    /// 8. Every action a gesture sends is also available from the native controls.
    @Test func gestureActionsAreNativeActions() throws {
        let id: ExperienceID = try #require(HarmonicBridgesExperience.id)
        let shell: ExperienceShell<HarmonicBridgesPresenter> = HarmonicBridgesExperience.make(id: id)
        let gestureActions: Set<String> = shell.presenter.gestureActions
        #expect(gestureActions == ["string.tune", "crossing.test"])
        #expect(gestureActions.isSubset(of: shell.presenter.nativeActions))
        #expect(shell.presenter.gestures.orbit == .authored)
    }
}
#endif
