// MoonlitMechanismGestureWiringTests — feature 434 (R02-G14-04) T-R02G1404-005 (FR-R02G1404-001 … 004, 006 … 008;
// clarifications Q1–Q5). On the simulator, through the one app's session host: scripted touches go to the presenter's
// `pointer(_:viewSize:port:)` with the shell's own `port` at a 720 × 480-point view (aspect 1.5), following Acoustic
// Constellator's wiring tests (feature 424). Targets are gear centres (or nearby points that pick the gear), the
// lamp's centre (`MoonlitMechanismSceneGeometry.lampCentre`) and key-frame card centres
// (`MoonlitMechanismSceneGeometry.card`), projected through the camera of the controller's orbit
// (`MoonlitMechanismSceneGeometry.camera(_:aspect:orbit:)`, then `MoonlitMechanismPicker.viewPoint`) and confirmed
// with `MoonlitMechanismPicker.pick` on the presenter's `lastSnapshot` before any touch. A gear drag goes down on the
// gear, moves radially 40 points away from the gear's projected centre (`MoonlitMechanismPicker.gearCentre`) and
// sweeps clockwise about it by n teeth (n · 2π ÷ T). Levels are chosen at run time from bare opening cores. What the
// port sent is read from the shell's engine (accepted and rejected action counters), the core and the digest,
// compared with a bare core that applied the expected actions.
// Checked:
//   1. a gear drag turns the train: n `handle.turn` actions (actions spent + n, phases as n turns of sense
//      `turnSense` predict); the pending text `pendingTurnText(teeth: n)` is shown while dragging and cleared after;
//      a drag cancelled by `cancelPointers()` sends nothing and clears the pending text;
//   2. a vertical lamp drag steps the lamp (`pendingLampText(steps: 1)` while dragging, one `lamp.step`);
//   3. a tap chooses a gear (mirror.gear) and sends nothing; a double tap on gear ≥ 1 re-seats it (one action);
//   4. a double tap on the driver sends nothing and shows `driverMessage`;
//   5. a tap on a key-frame card shows that frame (core.shownFrame), spends no action and keeps the digest;
//   6. a tap on the lamp runs the machine (actions spent + 1, the play leaves playing);
//   7. a two-finger orbit changes `scene.orbit` and `gestures.orbit` but never the digest; `resetView()` returns to
//      `MoonlitMechanismOrbit.authored`;
//   8. a lamp step past the top is refused: shown with the refusal text and its bare code logged;
//   9. on a won play a gear drag sends nothing and the mirror shows `finishedMessage`;
//  10. the gesture actions are a subset of the native actions.
// Synthetic timestamps based on the system uptime; no sleep, no wall-clock assertion. Explicit types and plain loops
// (CI type-check rule).
#if os(iOS)
import CoreGraphics
import Foundation
import MoonlitMechanismCore
import Testing
@testable import MoonlitMechanismExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreScenes

/// Scripted touches on Moonlit Mechanism, placed through the drawn camera.
@MainActor
enum MoonlitMechanismGestureScript {
    typealias Shell = MoonlitMechanismTest.Shell
    typealias Snapshot = MoonlitMechanismSceneSnapshot
    typealias Geometry = MoonlitMechanismSceneGeometry
    typealias Core = MoonlitMechanismExperienceCore
    typealias Picker = MoonlitMechanismPicker
    typealias Controller = MoonlitMechanismGestureController
    typealias Orbit = MoonlitMechanismOrbit

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
    /// The moves of a scripted straight drag.
    static let dragMoves: Int = 6
    /// How far a gear drag moves radially away from the gear's projected centre before it sweeps, points.
    static let radialRoom: Double = 40
    /// The upward travel of a one-rung lamp drag, points (round(30 ÷ 24) = 1; more than the drag distance 16).
    static let lampRise: Double = 30
    /// The radii in points around a gear's projected centre at which a touch point is tried.
    static let gearRadii: [Double] = [0, 10, 20, 30, 45, 60, 80, 100, 120]
    /// The directions tried at each radius.
    static let gearDirections: Int = 8
    /// The candidate levels; the first that fits is used.
    static let candidateLevels: [Int] = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]

    /// What the engine has counted so far: accepted and rejected actions.
    struct Sent: Equatable {
        /// The accepted actions.
        let accepted: Int
        /// The rejected actions.
        let rejected: Int
    }

    /// A lamp step past the top: the level, the accepted lamp raises issued first and the code of the refused raise.
    struct Refusal {
        /// The level.
        let number: Int
        /// The `lamp.step [1]` actions issued through the shell first (all accepted, the play still playing).
        let raises: Int
        /// The code a bare core gives for the refused raise.
        let code: String
    }

    /// Opens level `number` (seed `number − 1`) at the scripted view size (one frame drawn).
    static func open(_ session: ExperienceSession, number: Int) async throws -> Shell {
        try await MoonlitMechanismTest.open(session, seed: UInt64(number - 1),
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

    /// The first part of a gear drag with finger `id` (not lifted): down at `start`, moved radially ``radialRoom``
    /// points farther from `pivot`, then swept clockwise on screen about `pivot` by `teeth` teeth of a gear of
    /// `toothCount` teeth in small steps. Returns the last point (the release point).
    static func gearDragOver(_ shell: Shell, id: Int, start: Vec2, pivot: Vec2, teeth: Int, toothCount: Int,
                             time: inout Double) -> Vec2 {
        let offset: Vec2 = start - pivot
        let r: Double = offset.length
        let a0: Double = r >= 1 ? atan2(offset.y, offset.x) : 0
        let radius: Double = r + radialRoom
        touch(shell, id: id, .began, at: start, time: &time)
        let outward: Vec2 = pivot + Vec2(cos(a0), sin(a0)) * radius
        moves(shell, id: id, from: start, to: outward, time: &time)
        let sweep: Double = Double(teeth) * 2 * Double.pi / Double(max(toothCount, 1))
        let steps: Int = max(12, abs(teeth) * 4)
        var last: Vec2 = outward
        for step in 1...steps {
            let a: Double = a0 + sweep * Double(step) / Double(steps)
            last = pivot + Vec2(cos(a), sin(a)) * radius
            touch(shell, id: id, .moved, at: last, time: &time)
        }
        return last
    }

    /// Whether `location` lies inside the view with a margin of `inset` points.
    static func inside(_ location: Vec2, inset: Double = 0) -> Bool {
        location.x >= inset && location.x <= viewWidth - inset && location.y >= inset
            && location.y <= viewHeight - inset
    }

    /// What the picker gives for `location` on `snapshot` at `orbit`.
    static func pick(_ location: Vec2, _ snapshot: Snapshot, orbit: Orbit) -> MoonlitMechanismPick {
        Picker.pick(SIMD2<Double>(location.x, location.y), size: size, snapshot: snapshot, orbit: orbit)
    }

    /// `world` in view points (origin top left) through the camera of `orbit` for `snapshot` at the scripted view
    /// size; nil behind the camera.
    static func viewPoint(_ world: SIMD3<Double>, _ snapshot: Snapshot, orbit: Orbit) -> Vec2? {
        let camera: MoonlitMechanismCamera = Geometry.camera(snapshot, aspect: viewWidth / viewHeight, orbit: orbit)
        guard let p: SIMD2<Double> = Picker.viewPoint(world, size: size, camera: camera) else { return nil }
        return Vec2(p.x, p.y)
    }

    /// Gear `index`'s projected centre (the drag's pivot) at `orbit`; nil when it does not project.
    static func pivot(_ index: Int, _ snapshot: Snapshot, orbit: Orbit) -> Vec2? {
        guard let c: SIMD2<Double> = Picker.gearCentre(index, size: size, snapshot: snapshot, orbit: orbit) else {
            return nil
        }
        return Vec2(c.x, c.y)
    }

    /// A point 8 points inside the view where the picker gives `.gear(index)` at `orbit`: the gear's projected centre
    /// first, then points on rings about it; nil when none.
    static func gearPoint(_ index: Int, _ snapshot: Snapshot, orbit: Orbit) -> Vec2? {
        guard index >= 0, index < snapshot.gears.count, let centre: Vec2 = pivot(index, snapshot, orbit: orbit) else {
            return nil
        }
        for radius in gearRadii {
            let directions: Int = radius == 0 ? 1 : gearDirections
            for k in 0..<directions {
                let a: Double = Double(k) * 2 * Double.pi / Double(gearDirections)
                let point: Vec2 = centre + Vec2(cos(a), sin(a)) * radius
                if inside(point, inset: 8), pick(point, snapshot, orbit: orbit) == .gear(index) { return point }
            }
        }
        return nil
    }

    /// The highest-numbered gear ≥ 1 of `snapshot` with a touch point at `orbit` (gear and point); nil when none.
    static func movableGear(_ snapshot: Snapshot, orbit: Orbit) -> (gear: Int, point: Vec2)? {
        for index in snapshot.gears.indices.reversed() where index >= 1 {
            if let point: Vec2 = gearPoint(index, snapshot, orbit: orbit) { return (index, point) }
        }
        return nil
    }

    /// The lamp's projected centre 8 points inside the view where the picker gives `.lamp` at `orbit`; nil otherwise.
    static func lampPoint(_ snapshot: Snapshot, orbit: Orbit) -> Vec2? {
        guard let point: Vec2 = viewPoint(Geometry.lampCentre(snapshot), snapshot, orbit: orbit),
              inside(point, inset: 8), pick(point, snapshot, orbit: orbit) == .lamp else { return nil }
        return point
    }

    /// The highest-numbered key-frame card ≥ 1 whose projected centre picks it 8 points inside the view at `orbit`
    /// (card and point); nil when none.
    static func cardPoint(_ snapshot: Snapshot, orbit: Orbit) -> (card: Int, point: Vec2)? {
        for index in snapshot.keyFrames.indices.reversed() where index >= 1 {
            guard let point: Vec2 = viewPoint(Geometry.card(index, snapshot), snapshot, orbit: orbit),
                  inside(point, inset: 8) else { continue }
            if pick(point, snapshot, orbit: orbit) == .card(index) { return (index, point) }
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

    /// The first candidate level where raising the lamp to the top keeps the play playing and the lamp at the top
    /// picks inside the view, so one more raise is refused by the lamp range; nil when none.
    static func refusal() throws -> Refusal? {
        for number in candidateLevels {
            var core: Core = try Core.opening(number: number)
            let raises: Int = core.play.level.lampHeights - 1 - core.play.height
            guard raises >= 0, raises + 1 < core.play.actionsLeft else { continue }
            var fine: Bool = true
            for _ in 0..<raises {
                let result = applied(core, "lamp.step", [1])
                guard result.result.isAccepted, result.core.play.stage == .playing else {
                    fine = false
                    break
                }
                core = result.core
            }
            guard fine, lampPoint(core.snapshot(time: 0), orbit: .authored) != nil else { continue }
            let refused = applied(core, "lamp.step", [1])
            guard !refused.result.isAccepted else { continue }
            return Refusal(number: number, raises: raises, code: refused.result.code)
        }
        return nil
    }

    /// The core `before` after applying `control` with `values`, and the adapter's answer.
    static func applied(_ before: Core, _ control: String, _ values: [Double]) -> (core: Core, result: ActionResult) {
        var copy: Core = before
        let result: ActionResult = copy.apply(ExperienceAction(control: control, values: values, step: 0))
        return (copy, result)
    }

    /// The core `before` after `count` applications of `control` with `values`, each expected to be accepted.
    static func applied(_ before: Core, _ control: String, _ values: [Double], times count: Int) -> Core {
        var copy: Core = before
        for index in 0..<max(count, 0) {
            let result: ActionResult = copy.apply(ExperienceAction(control: control, values: values, step: 0))
            #expect(result.isAccepted, "\(control) \(values) #\(index): \(result.code)")
        }
        return copy
    }
}

@MainActor
@Suite(.serialized) struct MoonlitMechanismGestureWiringTests {
    typealias Script = MoonlitMechanismGestureScript
    typealias Core = MoonlitMechanismExperienceCore
    typealias Snapshot = MoonlitMechanismSceneSnapshot
    typealias Presenter = MoonlitMechanismPresenter

    /// 1. A gear drag turns the train by the swept teeth, with the pending turn shown only while dragging; a drag
    /// cancelled by suspension sends nothing.
    @Test func aGearDragTurnsTheTrain() async throws {
        let number: Int = try Script.level("a gear ≥ 1 and two actions") { (core: Core, snapshot: Snapshot) -> Bool in
            core.play.actionsLeft >= 2 && Script.movableGear(snapshot, orbit: .authored) != nil
        }
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Script.open(session, number: number)
        let before: Core = try MoonlitMechanismTest.core(shell)
        try #require(before.play.stage == .playing)
        let snapshot: Snapshot = try Script.drawn(shell)
        let orbit: MoonlitMechanismOrbit = shell.presenter.gestures.orbit
        let target = try #require(Script.movableGear(snapshot, orbit: orbit), "a gear ≥ 1 picks inside the view")
        let gear: Int = target.gear
        let pivot: Vec2 = try #require(Script.pivot(gear, snapshot, orbit: orbit))
        let teeth: Int = before.play.actionsLeft >= 3 ? 2 : 1
        let toothCount: Int = snapshot.gears[gear].teeth
        let sense: Int = MoonlitMechanismSceneGeometry.turnSense(gear, snapshot)
        let expected: Core = Script.applied(before, "handle.turn", [Double(sense)], times: teeth)
        let digest: String = try MoonlitMechanismTest.digest(shell)
        let sentBefore: Script.Sent = Script.sent(shell)
        var time: Double = Script.clock()

        let end: Vec2 = Script.gearDragOver(shell, id: 1, start: target.point, pivot: pivot, teeth: teeth,
                                            toothCount: toothCount, time: &time)
        #expect(shell.presenter.gestures.state == .gearDrag)
        let pendingText: String = Presenter.pendingTurnText(teeth: teeth)
        #expect(shell.presenter.mirror.pending == pendingText, "the pending turn is shown while dragging")
        let unit: (tooth: String, action: String) = teeth == 1 ? ("tooth", "action") : ("teeth", "actions")
        #expect(pendingText == "Turn \(teeth) \(unit.tooth) (\(teeth) \(unit.action))")
        let described: String = shell.presenter.describe(before)
        #expect(described.contains(pendingText + "."), "\(described)")
        #expect(Script.sent(shell) == sentBefore, "nothing is sent before the release")
        #expect(try MoonlitMechanismTest.digest(shell) == digest)
        Script.touch(shell, id: 1, .ended, at: end, time: &time)
        #expect(shell.presenter.mirror.pending == nil, "the pending turn is cleared on release")
        let sentAfter: Script.Sent = Script.sent(shell)
        #expect(sentAfter.accepted == sentBefore.accepted + teeth, "\(teeth) handle.turn accepted")
        #expect(sentAfter.rejected == sentBefore.rejected)
        let after: Core = try MoonlitMechanismTest.core(shell)
        #expect(after.play.actionsSpent == before.play.actionsSpent + teeth, "one action per tooth")
        #expect(after.play.phases == expected.play.phases, "the phases move as \(teeth) handle turns predict")
        #expect(after.play.fingerprint == expected.play.fingerprint)
        #expect(after.play.records.last?.action == .turn(sense))
        #expect(try MoonlitMechanismTest.digest(shell) != digest, "the turns change the digest")
        #expect(shell.presenter.gestures.state == .idle)
        #expect(shell.presenter.refusalLog.isEmpty)

        // A drag cancelled by suspension sends nothing and clears its pending text.
        try MoonlitMechanismTest.draw(session)
        let turned: Snapshot = try Script.drawn(shell)
        if turned.stage == .playing, turned.actionsLeft >= 1,
           let again = Script.movableGear(turned, orbit: shell.presenter.gestures.orbit),
           let againPivot: Vec2 = Script.pivot(again.gear, turned, orbit: shell.presenter.gestures.orbit) {
            let digestTurned: String = try MoonlitMechanismTest.digest(shell)
            let sentTurned: Script.Sent = Script.sent(shell)
            time += 1
            _ = Script.gearDragOver(shell, id: 2, start: again.point, pivot: againPivot, teeth: 1,
                                    toothCount: turned.gears[again.gear].teeth, time: &time)
            #expect(shell.presenter.mirror.pending == Presenter.pendingTurnText(teeth: 1))
            shell.presenter.cancelPointers()
            #expect(shell.presenter.mirror.pending == nil, "a cancel clears the pending text")
            #expect(shell.presenter.gestures.state == .idle)
            #expect(Script.sent(shell) == sentTurned, "a cancelled drag sends nothing")
            #expect(try MoonlitMechanismTest.digest(shell) == digestTurned)
        }
    }

    /// 2. A vertical drag on the lamp steps it, with the pending steps shown only while dragging.
    @Test func aVerticalLampDragStepsTheLamp() async throws {
        let number: Int = try Script.level("a lamp that can rise") { (core: Core, snapshot: Snapshot) -> Bool in
            core.play.height + 1 < core.play.level.lampHeights && core.play.actionsLeft >= 2
                && Script.lampPoint(snapshot, orbit: .authored) != nil
        }
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Script.open(session, number: number)
        let before: Core = try MoonlitMechanismTest.core(shell)
        try #require(before.play.stage == .playing)
        let snapshot: Snapshot = try Script.drawn(shell)
        let start: Vec2 = try #require(Script.lampPoint(snapshot, orbit: shell.presenter.gestures.orbit),
                                       "the lamp picks inside the view")
        let expected = Script.applied(before, "lamp.step", [1])
        #expect(expected.result == .accepted)
        let sentBefore: Script.Sent = Script.sent(shell)
        var time: Double = Script.clock()

        let end: Vec2 = Vec2(start.x, start.y - Script.lampRise)
        Script.touch(shell, id: 1, .began, at: start, time: &time)
        #expect(shell.presenter.gestures.state == .lampPress)
        Script.moves(shell, id: 1, from: start, to: end, time: &time)
        #expect(shell.presenter.gestures.state == .lampDrag)
        let pendingText: String = Presenter.pendingLampText(steps: 1)
        #expect(shell.presenter.mirror.pending == pendingText, "the pending lamp step is shown while dragging")
        #expect(pendingText == "Lamp 1 step up")
        #expect(Presenter.pendingLampText(steps: 2) == "Lamp 2 steps up")
        #expect(Script.sent(shell) == sentBefore, "nothing is sent before the release")
        Script.touch(shell, id: 1, .ended, at: end, time: &time)
        #expect(shell.presenter.mirror.pending == nil, "the pending text is cleared on release")
        let sentAfter: Script.Sent = Script.sent(shell)
        #expect(sentAfter.accepted == sentBefore.accepted + 1, "one lamp.step accepted")
        #expect(sentAfter.rejected == sentBefore.rejected)
        let after: Core = try MoonlitMechanismTest.core(shell)
        #expect(after.play.height == before.play.height + 1, "the lamp rises one step")
        #expect(after.play.actionsSpent == before.play.actionsSpent + 1)
        #expect(after.play.records.last?.action == .lamp(1))
        #expect(after.play.fingerprint == expected.core.play.fingerprint)
        #expect(shell.presenter.gestures.state == .idle)
        #expect(shell.presenter.refusalLog.isEmpty)

        // A lamp drag cancelled by suspension sends nothing and clears its pending text.
        try MoonlitMechanismTest.draw(session)
        let raised: Snapshot = try Script.drawn(shell)
        if raised.stage == .playing, let again: Vec2 = Script.lampPoint(raised, orbit: shell.presenter.gestures.orbit) {
            let sentRaised: Script.Sent = Script.sent(shell)
            time += 1
            Script.touch(shell, id: 2, .began, at: again, time: &time)
            Script.moves(shell, id: 2, from: again, to: Vec2(again.x, again.y + Script.lampRise), time: &time)
            #expect(shell.presenter.mirror.pending == Presenter.pendingLampText(steps: -1))
            shell.presenter.cancelPointers()
            #expect(shell.presenter.mirror.pending == nil)
            #expect(Script.sent(shell) == sentRaised, "a cancelled lamp drag sends nothing")
        }
    }

    /// 3. A tap chooses a gear and sends nothing; a double tap on gear ≥ 1 re-seats it (one action).
    @Test func aTapChoosesAGearAndADoubleTapReseatsIt() async throws {
        let number: Int = try Script.level("a gear ≥ 1") { (core: Core, snapshot: Snapshot) -> Bool in
            core.play.actionsLeft >= 2 && Script.movableGear(snapshot, orbit: .authored) != nil
        }
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Script.open(session, number: number)
        let before: Core = try MoonlitMechanismTest.core(shell)
        try #require(before.play.stage == .playing)
        let snapshot: Snapshot = try Script.drawn(shell)
        let target = try #require(Script.movableGear(snapshot, orbit: shell.presenter.gestures.orbit),
                                  "a gear ≥ 1 picks inside the view")
        let gear: Int = target.gear
        let expected = Script.applied(before, "gear.reseat", [Double(gear), 1])
        #expect(expected.result == .accepted)
        // Choose gear 0 first through the mirror, so the tap visibly moves the choice.
        shell.presenter.mirror.gear = 0
        let digest: String = try MoonlitMechanismTest.digest(shell)
        let sentBefore: Script.Sent = Script.sent(shell)
        var time: Double = Script.clock()

        Script.touch(shell, id: 1, .began, at: target.point, time: &time)
        #expect(shell.presenter.gestures.state == .gearPress)
        Script.touch(shell, id: 1, .ended, at: target.point, time: &time)
        #expect(shell.presenter.mirror.gear == gear, "the tap chooses the gear")
        #expect(Script.sent(shell) == sentBefore, "a single tap sends nothing")
        #expect(try MoonlitMechanismTest.digest(shell) == digest, "a choice never changes the digest")

        Script.tap(shell, id: 2, at: target.point, time: &time)
        let sentAfter: Script.Sent = Script.sent(shell)
        #expect(sentAfter.accepted == sentBefore.accepted + 1, "one gear.reseat accepted")
        #expect(sentAfter.rejected == sentBefore.rejected)
        let after: Core = try MoonlitMechanismTest.core(shell)
        #expect(after.play.actionsSpent == before.play.actionsSpent + 1, "one action spent")
        let teeth: Int = before.play.level.gears[gear].teeth
        #expect(after.play.phases[gear] == (before.play.phases[gear] + 1) % teeth, "the gear moves one slot forward")
        #expect(after.play.records.last?.action == .reseat(gear, 1))
        #expect(after.play.fingerprint == expected.core.play.fingerprint)
        #expect(shell.presenter.mirror.gear == gear)
        #expect(shell.presenter.mirror.message == nil)
        #expect(shell.presenter.gestures.state == .idle)
        #expect(shell.presenter.refusalLog.isEmpty)
    }

    /// 4. A double tap on the driver sends nothing and says it cannot be re-seated.
    @Test func aDoubleTapOnTheDriverSendsNothing() async throws {
        let number: Int = try Script.level("the driver") { (_: Core, snapshot: Snapshot) -> Bool in
            Script.gearPoint(0, snapshot, orbit: .authored) != nil
        }
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Script.open(session, number: number)
        let before: Core = try MoonlitMechanismTest.core(shell)
        try #require(before.play.stage == .playing)
        let snapshot: Snapshot = try Script.drawn(shell)
        let point: Vec2 = try #require(Script.gearPoint(0, snapshot, orbit: shell.presenter.gestures.orbit),
                                       "the driver picks inside the view")
        let digest: String = try MoonlitMechanismTest.digest(shell)
        let sentBefore: Script.Sent = Script.sent(shell)
        var time: Double = Script.clock()

        Script.tap(shell, id: 1, at: point, time: &time)
        #expect(shell.presenter.mirror.gear == 0, "the tap chooses the driver")
        #expect(shell.presenter.mirror.message == nil)
        Script.tap(shell, id: 2, at: point, time: &time)
        #expect(Script.sent(shell) == sentBefore, "a double tap on the driver sends nothing")
        #expect(try MoonlitMechanismTest.digest(shell) == digest)
        #expect(try MoonlitMechanismTest.core(shell).play.fingerprint == before.play.fingerprint)
        #expect(shell.presenter.mirror.message == Presenter.driverMessage)
        #expect(Presenter.driverMessage == "The driver cannot be re-seated")
        #expect(shell.presenter.mirror.gear == 0)
        #expect(shell.presenter.refusalLog.isEmpty)
        #expect(shell.presenter.gestures.state == .idle)
    }

    /// 5. A tap on a key-frame card shows that frame, spends no action and keeps the digest.
    @Test func aTapOnAKeyFrameCardShowsIt() async throws {
        let number: Int = try Script.level("a key-frame card ≥ 1") { (_: Core, snapshot: Snapshot) -> Bool in
            Script.cardPoint(snapshot, orbit: .authored) != nil
        }
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Script.open(session, number: number)
        let before: Core = try MoonlitMechanismTest.core(shell)
        #expect(before.shownFrame == 0)
        let snapshot: Snapshot = try Script.drawn(shell)
        let target = try #require(Script.cardPoint(snapshot, orbit: shell.presenter.gestures.orbit),
                                  "a key-frame card picks inside the view")
        let digest: String = try MoonlitMechanismTest.digest(shell)
        let sentBefore: Script.Sent = Script.sent(shell)
        var time: Double = Script.clock()

        Script.touch(shell, id: 1, .began, at: target.point, time: &time)
        #expect(shell.presenter.gestures.state == .cardPress)
        Script.touch(shell, id: 1, .ended, at: target.point, time: &time)
        let after: Core = try MoonlitMechanismTest.core(shell)
        #expect(after.shownFrame == target.card, "the tap shows the card's key frame")
        #expect(after.play.actionsSpent == before.play.actionsSpent, "showing a key frame spends no action")
        #expect(after.play.fingerprint == before.play.fingerprint)
        #expect(try MoonlitMechanismTest.digest(shell) == digest, "the shown key frame is not in the digest")
        let sentAfter: Script.Sent = Script.sent(shell)
        #expect(sentAfter.accepted == sentBefore.accepted + 1, "one frame.show accepted")
        #expect(sentAfter.rejected == sentBefore.rejected)
        try MoonlitMechanismTest.draw(session)
        #expect(shell.presenter.mirror.shownFrame == target.card)
        #expect(try Script.drawn(shell).shownFrame == target.card)
        #expect(shell.presenter.refusalLog.isEmpty)
        #expect(shell.presenter.gestures.state == .idle)
    }

    /// 6. A tap on the lamp runs the machine: one action spent and the play leaves playing.
    @Test func aTapOnTheLampRuns() async throws {
        let number: Int = try Script.level("the lamp") { (_: Core, snapshot: Snapshot) -> Bool in
            Script.lampPoint(snapshot, orbit: .authored) != nil
        }
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Script.open(session, number: number)
        let before: Core = try MoonlitMechanismTest.core(shell)
        try #require(before.play.stage == .playing)
        let snapshot: Snapshot = try Script.drawn(shell)
        let point: Vec2 = try #require(Script.lampPoint(snapshot, orbit: shell.presenter.gestures.orbit),
                                       "the lamp picks inside the view")
        let expected = Script.applied(before, "machine.run", [])
        #expect(expected.result == .accepted)
        let sentBefore: Script.Sent = Script.sent(shell)
        var time: Double = Script.clock()

        Script.touch(shell, id: 1, .began, at: point, time: &time)
        #expect(shell.presenter.gestures.state == .lampPress)
        Script.touch(shell, id: 1, .ended, at: point, time: &time)
        let sentAfter: Script.Sent = Script.sent(shell)
        #expect(sentAfter.accepted == sentBefore.accepted + 1, "one machine.run accepted")
        #expect(sentAfter.rejected == sentBefore.rejected)
        let after: Core = try MoonlitMechanismTest.core(shell)
        #expect(after.play.actionsSpent == before.play.actionsSpent + 1, "one action spent")
        #expect(after.play.records.last?.action == .run)
        #expect(after.play.stage != .playing, "the run decides the play")
        #expect(after.play.stage == expected.core.play.stage)
        #expect(after.play.fingerprint == expected.core.play.fingerprint)
        #expect(shell.presenter.gestures.state == .idle)
        #expect(shell.presenter.refusalLog.isEmpty)
    }

    /// 7. A two-finger drag orbits the camera and changes no digest; "Reset view" returns to the authored orbit.
    @Test func anOrbitChangesTheViewButNotTheDigest() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Script.open(session, number: Script.candidateLevels[0])
        let digest: String = try MoonlitMechanismTest.digest(shell)
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
        let orbit: MoonlitMechanismOrbit = shell.presenter.gestures.orbit
        #expect(orbit != .authored, "two fingers orbit the camera")
        #expect(Swift.abs(orbit.yaw) <= MoonlitMechanismOrbit.yawLimit + 1e-12)
        #expect(MoonlitMechanismOrbit.pitchRange.contains(orbit.pitch))
        #expect(orbit == orbit.clamped())
        #expect(shell.presenter.scene.orbit == orbit, "the scene takes the controller's orbit")
        #expect(shell.presenter.gestures.state == .idle)
        #expect(shell.presenter.mirror.pending == nil)
        #expect(Script.sent(shell) == sentBefore, "an orbit sends nothing")
        #expect(try MoonlitMechanismTest.digest(shell) == digest, "an orbit never changes the digest")
        try MoonlitMechanismTest.draw(session)
        #expect(shell.presenter.scene.orbit == orbit, "the scene draws the controller's orbit")
        #expect(try MoonlitMechanismTest.digest(shell) == digest)

        shell.presenter.resetView()
        #expect(shell.presenter.gestures.orbit == .authored, "Reset view restores the authored orbit")
        #expect(shell.presenter.scene.orbit == .authored)
        try MoonlitMechanismTest.draw(session)
        #expect(shell.presenter.scene.orbit == .authored)
        #expect(Script.sent(shell) == sentBefore)
        #expect(try MoonlitMechanismTest.digest(shell) == digest)
        #expect(shell.presenter.refusalLog.isEmpty)
    }

    /// 8. A lamp step past the top is refused by the kernel, shown in words and logged with its bare code.
    @Test func aLampStepPastTheTopIsRefusedAndShown() async throws {
        let refusal: Script.Refusal = try #require(try Script.refusal(), "a level reaches the top of its lamp")
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Script.open(session, number: refusal.number)
        var raises: [MoonlitMechanismAction] = []
        for _ in 0..<refusal.raises { raises.append(.lamp(1)) }
        let accepted: Int = MoonlitMechanismTest.issue(shell, raises)
        #expect(accepted == refusal.raises)
        try MoonlitMechanismTest.draw(session)
        let before: Core = try MoonlitMechanismTest.core(shell)
        try #require(before.play.stage == .playing)
        try #require(before.play.height == before.play.level.lampHeights - 1, "the lamp is at the top")
        let snapshot: Snapshot = try Script.drawn(shell)
        let start: Vec2 = try #require(Script.lampPoint(snapshot, orbit: shell.presenter.gestures.orbit),
                                       "the lamp picks inside the view")
        let expected = Script.applied(before, "lamp.step", [1])
        #expect(!expected.result.isAccepted)
        #expect(expected.result.code == refusal.code)
        let digest: String = try MoonlitMechanismTest.digest(shell)
        let sentBefore: Script.Sent = Script.sent(shell)
        var time: Double = Script.clock()

        let end: Vec2 = Vec2(start.x, start.y - Script.lampRise)
        Script.touch(shell, id: 1, .began, at: start, time: &time)
        Script.moves(shell, id: 1, from: start, to: end, time: &time)
        #expect(shell.presenter.mirror.pending == Presenter.pendingLampText(steps: 1))
        Script.touch(shell, id: 1, .ended, at: end, time: &time)
        #expect(shell.presenter.mirror.pending == nil)
        let sentAfter: Script.Sent = Script.sent(shell)
        #expect(sentAfter.accepted == sentBefore.accepted)
        #expect(sentAfter.rejected == sentBefore.rejected + 1, "one lamp.step refused")
        #expect(try MoonlitMechanismTest.digest(shell) == digest, "a refused action changes nothing")
        #expect(try MoonlitMechanismTest.core(shell).play.fingerprint == before.play.fingerprint)
        let code: String = try #require(shell.presenter.refusalLog.last, "the refusal's code is logged")
        #expect(shell.presenter.refusalLog.count == 1)
        #expect(code == MoonlitMechanismMirror.bareCode(refusal.code))
        #expect(code == "r02-g14.action", "the bare code, without the engine's prefix: \(code)")
        let message: String = try #require(shell.presenter.mirror.message, "the refusal is shown")
        // Since feature 436 the panel shows the feedback plan's refusal words exactly.
        #expect(message == MoonlitMechanismMirror.refusalText(code: code))
        #expect(message == "That change is not allowed for this machine.", "\(message)")
        #expect(shell.presenter.gestures.state == .idle)
    }

    /// 9. On a won play a gear drag sends nothing and the mirror explains that the play is over.
    @Test func aGearDragOnAWonPlaySendsNothing() async throws {
        let number: Int = try Script.level("a gear") { (_: Core, snapshot: Snapshot) -> Bool in
            Script.movableGear(snapshot, orbit: .authored) != nil
                || Script.gearPoint(0, snapshot, orbit: .authored) != nil
        }
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Script.open(session, number: number)
        let actions: [MoonlitMechanismAction] = try MoonlitMechanismTest.certifiedActions(number)
        try #require(!actions.isEmpty, "level \(number) has a certified solution")
        let accepted: Int = MoonlitMechanismTest.issue(shell, actions)
        #expect(accepted == actions.count)
        let won: Core = try MoonlitMechanismTest.core(shell)
        try #require(won.play.stage == .won, "the certified solution wins level \(number)")
        try MoonlitMechanismTest.draw(session)
        let snapshot: Snapshot = try Script.drawn(shell)
        #expect(snapshot.stage == .won)
        let orbit: MoonlitMechanismOrbit = shell.presenter.gestures.orbit
        var gear: Int = 0
        var start: Vec2? = Script.gearPoint(0, snapshot, orbit: orbit)
        if let movable = Script.movableGear(snapshot, orbit: orbit) {
            gear = movable.gear
            start = movable.point
        }
        let point: Vec2 = try #require(start, "a gear picks inside the view")
        let pivot: Vec2 = try #require(Script.pivot(gear, snapshot, orbit: orbit))
        let digest: String = try MoonlitMechanismTest.digest(shell)
        let sentBefore: Script.Sent = Script.sent(shell)
        var time: Double = Script.clock()

        let end: Vec2 = Script.gearDragOver(shell, id: 1, start: point, pivot: pivot, teeth: 2,
                                            toothCount: snapshot.gears[gear].teeth, time: &time)
        #expect(shell.presenter.mirror.pending == nil, "a finished play previews nothing")
        Script.touch(shell, id: 1, .ended, at: end, time: &time)
        #expect(Script.sent(shell) == sentBefore, "a drag on a won play sends nothing")
        #expect(try MoonlitMechanismTest.digest(shell) == digest)
        #expect(try MoonlitMechanismTest.core(shell).play.fingerprint == won.play.fingerprint)
        #expect(shell.presenter.mirror.message == Presenter.finishedMessage)
        #expect(Presenter.finishedMessage == "The play is over: undo or go to the next level")
        #expect(shell.presenter.refusalLog.isEmpty, "nothing was refused: nothing was sent")
        #expect(shell.presenter.gestures.state == .idle)
        let described: String = shell.presenter.describe(try MoonlitMechanismTest.core(shell))
        #expect(described.contains(Presenter.finishedMessage + "."), "\(described)")
        #expect(shell.presenter.mirror.status == "Won")
    }

    /// 10. Every action a gesture sends is also available from the native controls.
    @Test func gestureActionsAreNativeActions() throws {
        let id: ExperienceID = try #require(MoonlitMechanismExperience.id)
        let shell: ExperienceShell<MoonlitMechanismPresenter> = MoonlitMechanismExperience.make(id: id)
        let gestureActions: Set<String> = shell.presenter.gestureActions
        #expect(gestureActions == ["handle.turn", "lamp.step", "gear.reseat", "machine.run", "frame.show"])
        #expect(gestureActions.isSubset(of: shell.presenter.nativeActions))
        #expect(shell.presenter.nativeActions == Set(MoonlitMechanismExperienceCore.actionIDs))
        #expect(shell.presenter.gestures.orbit == .authored)
        #expect(shell.presenter.mirror.pending == nil)
    }
}
#endif
