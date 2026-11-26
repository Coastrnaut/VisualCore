// ApsidesWorkshopGestureWiringTests — feature 474 (R02-G18-04) T-R02G1804-005 (FR-R02G1804-001 … 009;
// SC-R02G1804-001 … 004; clarifications Q1 … Q5). On the simulator, through the one app's session host: scripted
// touches go to the presenter's `pointer(_:viewSize:port:)` with the shell's own `port` at a 720 × 480-point view
// (aspect 1.5). Modelled on CelestialEclipseLabGestureWiringTests (feature 464). Targets are projected through the
// drawn camera of the presenter's orbit (`ApsidesWorkshopPicker.camera(size:orbit:)`, then
// `ApsidesWorkshopPicker.viewPoint` of `ApsidesWorkshopSceneGeometry.knobCentre` P(0), `handleCentre` P(T/2),
// `orbiterCentre` and the kernel positions) on the presenter's `lastSnapshot`, and each is confirmed with the picker
// (`pick`, `knobSteps`, `handleSize`, `crankTick`) at the same view size before any touch. Levels are chosen at run
// time from bare opening cores (seed n − 1 opens level n); the kernel's verdict is the one a bare core gives for the
// same actions. The orbiter is drawn last and covers a handle under it, so a knob gesture runs with the tick T/2 shown
// (the orbiter on the size handle) and a size-handle gesture with tick 0 (the orbiter on the knob).
// Checked:
//   a. a knob drag previews its pending eccentricity and direction (the drawn snapshot previews it) and on release
//      sends exactly one `orbit.periapsis`: actions left − 1, the play a bare core gives, the preview gone;
//   b. a size-handle drag likewise sends exactly one `orbit.size`;
//   c. a drag from the orbiter cranks the shown tick (`clock.show`); no action spent, the digest unchanged;
//   d. a knob drag on a won and on a failed play sends nothing and the mirror says the play is over;
//   e. a two-finger orbit changes `orbit` and never the digest; `resetView()` and a double tap on empty space return to
//      `ApsidesWorkshopViewOrbit.authored` with no kernel action;
//   f. `cancelPointers()` during a knob drag drops the preview and sends nothing, the late lift included;
//   g. the panel: the pending orbit moves without a digest change and is drawn as the preview; "Set periapsis" and
//      "Set size" (the presenter's `send`, as the controls call it) spend one action each, after which the pending
//      orbit follows the current orbit;
//   h. an invalid pending orbit says why in words and draws no preview;
//   i. a refused action (undo with nothing to undo, a knob drag with no action left) logs its bare code in
//      `refusalLog` and the mirror shows the feedback plan's sentence (since feature 476);
//   j. a tap on the knob explains the handles and sends nothing; the gestures' actions are among the native ones.
// Explicit synthetic timestamps (no clock, no sleep, no wall-clock assertion). Explicit types and plain loops (CI
// type-check rule); no nested closure literals. Synthetic data only. Each test well under 10 s.
#if os(iOS)
import ApsidesWorkshopCore
import CoreGraphics
import Foundation
import Testing
@testable import ApsidesWorkshopExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreScenes

/// Scripted touches on Apsides Workshop, placed through the drawn camera.
@MainActor
enum ApsidesWorkshopGestureScript {
    typealias Shell = ApsidesWorkshopTest.Shell
    typealias Snapshot = ApsidesWorkshopSceneSnapshot
    typealias Geometry = ApsidesWorkshopSceneGeometry
    typealias Core = ApsidesWorkshopExperienceCore
    typealias Picker = ApsidesWorkshopPicker
    typealias ViewOrbit = ApsidesWorkshopViewOrbit
    typealias Orbit = ApsidesWorkshopOrbit
    typealias Action = ApsidesWorkshopAction

    /// The view's width in points (aspect 1.5).
    static let viewWidth: Double = 720
    /// The view's height in points.
    static let viewHeight: Double = 480
    /// The view size handed with every event.
    static var viewSize: Vec2 { Vec2(viewWidth, viewHeight) }
    /// The view size as the picker takes it.
    static var size: SIMD2<Double> { SIMD2<Double>(viewWidth, viewHeight) }
    /// The first synthetic timestamp, seconds (any finite value; the controller only compares timestamps).
    static let start: Double = 100
    /// The time between scripted events in seconds (synthetic).
    static let frame: Double = 1.0 / 60
    /// The pause between the two taps of a double tap, seconds (inside the 0.35 s window).
    static let tapGap: Double = 0.1
    /// The pause between two separate gestures, seconds (outside every double-tap window).
    static let gesturePause: Double = 1
    /// The moves of a scripted straight drag.
    static let dragMoves: Int = 6
    /// The shortest crank drag scripted, points.
    static let minimumDrag: Double = 24
    /// The length of a scripted drag that only has to start a handle drag, points (more than the drag distance 16).
    static let shortDrag: Double = 40
    /// How far inside the view a touch point must lie, points.
    static let inset: Double = 8
    /// The radii in points around a projected centre at which a touch point is tried.
    static let radii: [Double] = [0, 4, 8]
    /// The directions tried at each radius.
    static let directions: Int = 8
    /// The drag lengths in points tried for a handle drag's release point (each more than the drag distance 16).
    static let dragRadii: [Double] = [32, 48, 64, 96, 128]
    /// The directions tried at each drag length.
    static let dragDirections: Int = 16
    /// The grid step of the empty-space search, points.
    static let gridStep: Double = 12
    /// The candidate levels; the first that fits is used.
    static let candidateLevels: [Int] = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]
    /// The kernel's budget refusal code.
    static let budgetCode: String = "r02-g18.budget"
    /// The kernel's refusal code of an action that cannot be taken (nothing to undo, among others).
    static let actionCode: String = "r02-g18.action"

    /// What the engine has counted so far: accepted and rejected actions.
    struct Sent: Equatable {
        /// The accepted actions.
        let accepted: Int
        /// The rejected actions.
        let rejected: Int
    }

    /// A handle drag on a snapshot: the touch-down point (picks the handle), the release point and the valid pending
    /// orbit the handle reads there (differs from the current orbit).
    struct HandleDrag {
        /// The touch-down point.
        let start: Vec2
        /// The release point.
        let end: Vec2
        /// The pending orbit read at ``end``.
        let pending: ApsidesWorkshopOrbit
    }

    /// A crank drag on a snapshot: the touch-down point on the orbiter and the tick read there, the release point and
    /// the tick read there.
    struct Crank {
        /// The touch-down point (picks the orbiter).
        let start: Vec2
        /// The tick under the touch-down point.
        let from: Int
        /// The release point.
        let end: Vec2
        /// The tick under the release point (differs from ``from``).
        let to: Int
    }

    /// A level, the actions issued through the shell before the gesture and whether the tick T/2 is shown.
    struct LevelTarget {
        /// The level number.
        let number: Int
        /// The actions issued before the gesture.
        let setUp: [Action]
        /// Whether the tick T/2 is shown (else tick 0).
        let atHalf: Bool
    }

    /// Opens level `number` (seed `number − 1`) at the scripted view size; with `atHalf` the tick T/2 is shown.
    static func open(_ session: ExperienceSession, number: Int, atHalf: Bool) async throws -> Shell {
        try await ApsidesWorkshopTest.open(session, seed: UInt64(number - 1),
                                           size: CGSize(width: viewWidth, height: viewHeight), atHalf: atHalf)
    }

    /// The engine's action counters of `shell`.
    static func sent(_ shell: Shell) -> Sent {
        Sent(accepted: shell.engine.acceptedActions, rejected: shell.engine.rejectedActions)
    }

    /// The snapshot the presenter drew last (the gestures read it), with its drawn preview.
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

    /// A two-finger orbit with fingers `first` and `second` from `a` and `b`, both moving by `shift`, then lifting.
    static func orbit(_ shell: Shell, ids first: Int, _ second: Int, from a: Vec2, _ b: Vec2, by shift: Vec2,
                      time: inout Double) {
        touch(shell, id: first, .began, at: a, time: &time)
        touch(shell, id: second, .began, at: b, time: &time)
        touch(shell, id: first, .moved, at: a + shift, time: &time)
        touch(shell, id: second, .moved, at: b + shift, time: &time)
        touch(shell, id: first, .ended, at: a + shift, time: &time)
        touch(shell, id: second, .ended, at: b + shift, time: &time)
    }

    /// Whether `location` lies inside the view with a margin of ``inset`` points.
    static func inside(_ location: Vec2) -> Bool {
        location.x >= inset && location.x <= viewWidth - inset && location.y >= inset
            && location.y <= viewHeight - inset
    }

    /// `v` as the picker takes it.
    static func simd(_ v: Vec2) -> SIMD2<Double> { SIMD2<Double>(v.x, v.y) }

    /// What the picker gives for `location` on `snapshot` at `orbit`.
    static func pick(_ location: Vec2, _ snapshot: Snapshot, orbit: ViewOrbit) -> ApsidesWorkshopPick {
        Picker.pick(simd(location), size: size, snapshot: snapshot, orbit: orbit)
    }

    /// World `point` in view points through the drawn camera at `orbit`; nil when it does not project.
    static func project(_ point: SIMD3<Double>, orbit: ViewOrbit) -> Vec2? {
        guard let camera: ApsidesWorkshopCamera = Picker.camera(size: size, orbit: orbit),
              let p: SIMD2<Double> = Picker.viewPoint(point, size: size, camera: camera) else { return nil }
        return Vec2(p.x, p.y)
    }

    /// A point inside the view near world `centre` (its projection, then rings about it) where the picker gives
    /// `wanted`; nil when none.
    static func point(near centre: SIMD3<Double>, _ snapshot: Snapshot, orbit: ViewOrbit,
                      wanted: ApsidesWorkshopPick) -> Vec2? {
        guard let c: Vec2 = project(centre, orbit: orbit) else { return nil }
        for radius in radii {
            let count: Int = radius == 0 ? 1 : directions
            for k in 0..<count {
                let a: Double = Double(k) * 2 * Double.pi / Double(directions)
                let p: Vec2 = c + Vec2(cos(a), sin(a)) * radius
                if inside(p), pick(p, snapshot, orbit: orbit) == wanted { return p }
            }
        }
        return nil
    }

    /// A point where the picker gives `.knob` (when `knob`) or `.sizeHandle`; nil when none.
    static func handlePoint(_ snapshot: Snapshot, orbit: ViewOrbit, knob: Bool) -> Vec2? {
        if knob { return point(near: Geometry.knobCentre(snapshot), snapshot, orbit: orbit, wanted: .knob) }
        return point(near: Geometry.handleCentre(snapshot), snapshot, orbit: orbit, wanted: .sizeHandle)
    }

    /// The pending orbit the knob (when `knob`) or the size handle reads at `location`; nil without a sky point.
    static func pending(_ location: Vec2, _ snapshot: Snapshot, orbit: ViewOrbit, knob: Bool) -> Orbit? {
        if knob { return Picker.knobSteps(simd(location), size: size, snapshot: snapshot, orbit: orbit) }
        return Picker.handleSize(simd(location), size: size, snapshot: snapshot, orbit: orbit)
    }

    /// The first handle drag on `snapshot` at `orbit`: a touch point on the knob (when `knob`) or the size handle and
    /// a release point inside the view, ``dragRadii`` away, where the handle reads a valid orbit other than the
    /// current one; nil when none.
    static func handleDrag(_ snapshot: Snapshot, orbit: ViewOrbit, knob: Bool) -> HandleDrag? {
        guard let start: Vec2 = handlePoint(snapshot, orbit: orbit, knob: knob) else { return nil }
        let current: Orbit = snapshot.orbit
        for radius in dragRadii {
            for k in 0..<dragDirections {
                let a: Double = Double(k) * 2 * Double.pi / Double(dragDirections)
                let end: Vec2 = start + Vec2(cos(a), sin(a)) * radius
                guard inside(end), let read: Orbit = pending(end, snapshot, orbit: orbit, knob: knob),
                      read.isValid, read != current else { continue }
                return HandleDrag(start: start, end: end, pending: read)
            }
        }
        return nil
    }

    /// The first crank drag on `snapshot` at `orbit`: a touch point on the orbiter and a tick other than the one read
    /// there whose projected kernel position lies inside the view at least ``minimumDrag`` points away and reads that
    /// tick; nil when none.
    static func crank(_ snapshot: Snapshot, orbit: ViewOrbit) -> Crank? {
        guard let start: Vec2 = point(near: Geometry.orbiterCentre(snapshot), snapshot, orbit: orbit,
                                      wanted: .orbiter) else { return nil }
        let from: Int = Picker.crankTick(simd(start), size: size, snapshot: snapshot, orbit: orbit)
        for tick in snapshot.positions.indices where tick != from {
            let world: SIMD3<Double> = Geometry.world(snapshot.positions[tick], depth: Geometry.planeZ)
            guard let end: Vec2 = project(world, orbit: orbit), inside(end),
                  (end - start).length >= minimumDrag else { continue }
            let read: Int = Picker.crankTick(simd(end), size: size, snapshot: snapshot, orbit: orbit)
            if read == tick { return Crank(start: start, from: from, end: end, to: tick) }
        }
        return nil
    }

    /// The first grid point inside the view that picks `.empty` and lies at least `minimum` points from `away` (when
    /// given); nil when none.
    static func emptyPoint(_ snapshot: Snapshot, orbit: ViewOrbit, away: Vec2? = nil, minimum: Double = 0) -> Vec2? {
        var y: Double = inset
        while y <= viewHeight - inset {
            var x: Double = inset
            while x <= viewWidth - inset {
                let p: Vec2 = Vec2(x, y)
                var far: Bool = true
                if let away { far = (p - away).length >= minimum }
                if far, pick(p, snapshot, orbit: orbit) == .empty { return p }
                x += gridStep
            }
            y += gridStep
        }
        return nil
    }

    /// A drag of ``shortDrag`` points from `start` in the first of the four axis directions that ends inside the view.
    static func anyDragEnd(from start: Vec2) -> Vec2? {
        let axes: [Vec2] = [Vec2(1, 0), Vec2(-1, 0), Vec2(0, 1), Vec2(0, -1)]
        for axis in axes {
            let end: Vec2 = start + axis * shortDrag
            if inside(end) { return end }
        }
        return nil
    }

    /// The core `before` after applying `control` with `values`, and the adapter's answer.
    static func applied(_ before: Core, _ control: String, _ values: [Double]) -> (core: Core, result: ActionResult) {
        var copy: Core = before
        let result: ActionResult = copy.apply(ExperienceAction(control: control, values: values, step: 0))
        return (copy, result)
    }

    /// The opening core of level `number` with `actions` applied and, with `atHalf`, the tick T/2 shown; nil when the
    /// kernel refuses one of them.
    static func bare(_ number: Int, _ actions: [Action], atHalf: Bool) throws -> Core? {
        var core: Core = try Core.opening(number: number)
        for action in actions {
            let result: ActionResult = core.apply(ApsidesWorkshopTest.experienceAction(action))
            if result != .accepted { return nil }
        }
        if atHalf {
            let tick: Int = ApsidesWorkshopTest.halfTick(core.play.level.period)
            let result: ActionResult = core.apply(ApsidesWorkshopTest.showAction(tick))
            if result != .accepted { return nil }
        }
        return core
    }

    // MARK: Level choice (from bare cores; an issue is recorded by the caller's `#require` when none fits)

    /// The first candidate level whose opening (tick T/2 shown for the knob, tick 0 for the size handle) has a handle
    /// drag the kernel accepts.
    static func dragLevel(knob: Bool) throws -> Int? {
        for number in candidateLevels {
            guard let core: Core = try bare(number, [], atHalf: knob) else { continue }
            let snapshot: Snapshot = core.snapshot(time: 0)
            guard let drag: HandleDrag = handleDrag(snapshot, orbit: .authored, knob: knob) else { continue }
            let control: String = knob ? "orbit.periapsis" : "orbit.size"
            let values: [Double] = knob ? [Double(drag.pending.eccentricity), Double(drag.pending.direction)]
                : [Double(drag.pending.size)]
            if applied(core, control, values).result == .accepted { return number }
        }
        return nil
    }

    /// The first candidate level whose opening at the tick T/2 has a crank drag.
    static func crankLevel() throws -> Int? {
        for number in candidateLevels {
            guard let core: Core = try bare(number, [], atHalf: true) else { continue }
            if crank(core.snapshot(time: 0), orbit: .authored) != nil { return number }
        }
        return nil
    }

    /// The first candidate level that ends in `stage` (`.won` by its certified plan and the play, `.failed` by the
    /// play of its opening orbit) with a knob drag inside the view on the finished snapshot at the tick T/2.
    static func finishedLevel(_ stage: ApsidesWorkshopStage) throws -> LevelTarget? {
        for number in candidateLevels {
            var actions: [Action] = [.play]
            if stage == .won { actions = try ApsidesWorkshopTest.certifiedPlan(number) + [.play] }
            guard let core: Core = try bare(number, actions, atHalf: true), core.play.stage == stage else { continue }
            let snapshot: Snapshot = core.snapshot(time: 0)
            guard let start: Vec2 = handlePoint(snapshot, orbit: .authored, knob: true),
                  anyDragEnd(from: start) != nil else { continue }
            return LevelTarget(number: number, setUp: actions, atHalf: true)
        }
        return nil
    }

    /// The first candidate level whose whole budget can be spent by toggling the periapsis direction between its
    /// opening step and the next, still playing, with a knob drag at the tick T/2 that the kernel refuses with
    /// ``budgetCode``.
    static func budgetTarget() throws -> LevelTarget? {
        for number in candidateLevels {
            let opening: Core = try Core.opening(number: number)
            let start: Orbit = opening.play.orbit
            let other: Int = (start.direction + 1) % 24
            var setUp: [Action] = []
            for index in 0..<opening.play.actionsLeft {
                setUp.append(.periapsis(start.eccentricity, index % 2 == 0 ? other : start.direction))
            }
            guard let spent: Core = try bare(number, setUp, atHalf: true), spent.play.actionsLeft == 0,
                  spent.play.stage == .playing else { continue }
            guard let drag: HandleDrag = handleDrag(spent.snapshot(time: 0), orbit: .authored, knob: true) else {
                continue
            }
            let values: [Double] = [Double(drag.pending.eccentricity), Double(drag.pending.direction)]
            let result: ActionResult = applied(spent, "orbit.periapsis", values).result
            if ApsidesWorkshopMirror.bareCode(result.code) == budgetCode {
                return LevelTarget(number: number, setUp: setUp, atHalf: true)
            }
        }
        return nil
    }

    /// The first candidate level with at least two actions left at its opening (the panel spends two).
    static func panelLevel() throws -> Int? {
        for number in candidateLevels {
            let opening: Core = try Core.opening(number: number)
            if opening.play.actionsLeft >= 2 && opening.play.stage == .playing { return number }
        }
        return nil
    }
}

@MainActor
@Suite(.serialized) struct ApsidesWorkshopGestureWiringTests {
    typealias Script = ApsidesWorkshopGestureScript
    typealias Core = ApsidesWorkshopExperienceCore
    typealias Snapshot = ApsidesWorkshopSceneSnapshot
    typealias Controller = ApsidesWorkshopGestureController
    typealias Mirror = ApsidesWorkshopMirror
    typealias ViewOrbit = ApsidesWorkshopViewOrbit
    typealias Orbit = ApsidesWorkshopOrbit
    typealias T = ApsidesWorkshopTest

    /// a, b. A handle drag previews its pending orbit, then on release sends exactly one tuning (`orbit.periapsis`
    /// for the knob, `orbit.size` for the size handle) with it.
    func handleDragTunesOnce(knob: Bool) async throws {
        let number: Int = try #require(try Script.dragLevel(knob: knob), "a handle drag fits (knob \(knob))")
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Script.open(session, number: number, atHalf: knob)
        let ready: Core = try T.core(shell)
        try #require(ready.play.stage == .playing)
        let snapshot: Snapshot = try Script.drawn(shell)
        let orbit: ViewOrbit = shell.presenter.orbit
        #expect(orbit == .authored)
        let drag: Script.HandleDrag = try #require(Script.handleDrag(snapshot, orbit: orbit, knob: knob),
                                                   "a handle drag fits on the drawn snapshot")
        let wanted: ApsidesWorkshopPick = knob ? .knob : .sizeHandle
        try #require(Script.pick(drag.start, snapshot, orbit: orbit) == wanted)
        let control: String = knob ? "orbit.periapsis" : "orbit.size"
        let values: [Double] = knob ? [Double(drag.pending.eccentricity), Double(drag.pending.direction)]
            : [Double(drag.pending.size)]
        let expected = Script.applied(ready, control, values)
        #expect(expected.result == .accepted, "the kernel accepts \(control) \(values)")
        let digest: String = try T.digest(shell)
        let sentBefore: Script.Sent = Script.sent(shell)
        var time: Double = Script.start

        Script.touch(shell, id: 1, .began, at: drag.start, time: &time)
        Script.moves(shell, id: 1, from: drag.start, to: drag.end, time: &time)
        #expect(Script.sent(shell) == sentBefore, "nothing is sent before the release")
        #expect(try T.digest(shell) == digest, "a preview never changes the digest")
        #expect(shell.presenter.mirror.preview == drag.pending, "the mirror keeps the drag's preview")
        #expect(try Script.drawn(shell).previewOrbit == drag.pending, "the drawn snapshot previews it at once")
        try T.draw(session)
        let previewing: Snapshot = try Script.drawn(shell)
        #expect(previewing.isPreviewing, "the drag previews its pending orbit")
        #expect(previewing.previewOrbit == drag.pending)
        #expect(previewing.orbit == ready.play.orbit, "the current orbit is still drawn")
        #expect(try T.core(shell).play == ready.play, "nothing is set before the release")

        Script.touch(shell, id: 1, .ended, at: drag.end, time: &time)
        let after: Core = try T.core(shell)
        #expect(after.play.orbit == drag.pending, "the release sets exactly the previewed orbit")
        #expect(after.play.actionsLeft == ready.play.actionsLeft - 1, "one action of the budget is spent")
        #expect(after.play == expected.core.play, "the kernel's verdict")
        let sentAfter: Script.Sent = Script.sent(shell)
        #expect(sentAfter.accepted == sentBefore.accepted + 1, "one \(control) accepted")
        #expect(sentAfter.rejected == sentBefore.rejected)
        #expect(try T.digest(shell) != digest, "the tuning changes the digest")
        #expect(shell.presenter.mirror.preview == nil, "the release drops the preview")
        #expect(shell.presenter.mirror.pendingOrbit == nil)
        #expect(shell.presenter.mirror.message == nil)
        #expect(shell.presenter.refusalLog.isEmpty)
        #expect(try Script.drawn(shell).isPreviewing == false, "the preview is dropped at the release")
        try T.draw(session)
        let drawn: Snapshot = try Script.drawn(shell)
        #expect(drawn.isPreviewing == false, "the next frame previews nothing")
        #expect(drawn.orbit == drag.pending, "the next frame draws the tuned orbit")
    }

    /// a. A knob drag sends exactly one `orbit.periapsis` with the previewed eccentricity and direction.
    @Test func aKnobDragTunesThePeriapsis() async throws {
        try await handleDragTunesOnce(knob: true)
    }

    /// b. A size-handle drag sends exactly one `orbit.size` with the previewed size.
    @Test func aSizeHandleDragTunesTheSize() async throws {
        try await handleDragTunesOnce(knob: false)
    }

    /// c. A drag from the orbiter cranks the shown tick; no kernel action, no digest change.
    @Test func anOrbiterDragCranksTheShownTick() async throws {
        let number: Int = try #require(try Script.crankLevel(), "a crank drag fits")
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Script.open(session, number: number, atHalf: true)
        let before: Core = try T.core(shell)
        let snapshot: Snapshot = try Script.drawn(shell)
        let orbit: ViewOrbit = shell.presenter.orbit
        let crank: Script.Crank = try #require(Script.crank(snapshot, orbit: orbit), "a crank drag fits")
        try #require(Script.pick(crank.start, snapshot, orbit: orbit) == .orbiter)
        let digest: String = try T.digest(shell)
        let rejectedBefore: Int = Script.sent(shell).rejected
        var time: Double = Script.start

        Script.touch(shell, id: 1, .began, at: crank.start, time: &time)
        #expect(try T.core(shell).shownTick == before.shownTick, "the touch-down sends nothing")
        Script.moves(shell, id: 1, from: crank.start, to: crank.end, time: &time)
        #expect(try T.core(shell).shownTick == crank.to, "the shown tick follows the finger")
        Script.touch(shell, id: 1, .ended, at: crank.end, time: &time)
        let after: Core = try T.core(shell)
        #expect(after.shownTick == crank.to)
        #expect(after.play == before.play, "the crank changes no kernel state")
        #expect(after.play.actionsLeft == before.play.actionsLeft, "no action is spent")
        #expect(Script.sent(shell).rejected == rejectedBefore)
        #expect(try T.digest(shell) == digest, "a shown tick never changes the digest")
        #expect(shell.presenter.refusalLog.isEmpty)
        try T.draw(session)
        #expect(shell.presenter.mirror.shownTick == crank.to, "the panel follows the shown tick")
        #expect(try Script.drawn(shell).shownTick == crank.to, "the drawn snapshot shows the tick")
        #expect(try Script.drawn(shell).isPreviewing == false, "the crank previews nothing")
    }

    /// d. On a finished play (won or failed) a knob drag sends nothing and the mirror says the play is over.
    func finishedDragSendsNothing(_ stage: ApsidesWorkshopStage) async throws {
        let target = try #require(try Script.finishedLevel(stage), "a \(stage) play with the knob inside the view")
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Script.open(session, number: target.number, atHalf: target.atHalf)
        let accepted: Int = T.issue(shell, target.setUp)
        #expect(accepted == target.setUp.count)
        let finished: Core = try T.core(shell)
        try #require(finished.play.stage == stage, "level \(target.number) ends \(stage)")
        try T.draw(session)
        let snapshot: Snapshot = try Script.drawn(shell)
        #expect(snapshot.stage == stage)
        let orbit: ViewOrbit = shell.presenter.orbit
        let start: Vec2 = try #require(Script.handlePoint(snapshot, orbit: orbit, knob: true), "the knob picks")
        let end: Vec2 = try #require(Script.anyDragEnd(from: start), "a drag fits")
        try #require(Script.pick(start, snapshot, orbit: orbit) == .knob)
        let digest: String = try T.digest(shell)
        let sentBefore: Script.Sent = Script.sent(shell)
        var time: Double = Script.start

        Script.touch(shell, id: 1, .began, at: start, time: &time)
        Script.moves(shell, id: 1, from: start, to: end, time: &time)
        #expect(shell.presenter.mirror.message == Controller.finishedReason, "the drag says the play is over")
        Script.touch(shell, id: 1, .ended, at: end, time: &time)
        #expect(Controller.finishedReason == "The play is over: undo or go to the next level")
        #expect(ApsidesWorkshopPresenter.finishedMessage == Controller.finishedReason)
        #expect(shell.presenter.mirror.message == Controller.finishedReason)
        #expect(Script.sent(shell) == sentBefore, "a knob drag on a finished play sends nothing")
        #expect(try T.digest(shell) == digest)
        #expect(try T.core(shell).play == finished.play)
        #expect(shell.presenter.refusalLog.isEmpty, "nothing was sent, so nothing was refused")
        try T.draw(session)
        #expect(try Script.drawn(shell).isPreviewing == false, "a finished play previews nothing")
    }

    /// d. On a won play a knob drag sends nothing and the mirror says the play is over.
    @Test func aKnobDragOnAWonPlaySendsNothing() async throws {
        try await finishedDragSendsNothing(.won)
    }

    /// d. On a failed play a knob drag sends nothing and the mirror says the play is over.
    @Test func aKnobDragOnAFailedPlaySendsNothing() async throws {
        try await finishedDragSendsNothing(.failed)
    }

    /// e. A two-finger drag orbits the camera and changes no digest; "Reset view" and a double tap on empty space
    /// return to the authored orbit.
    @Test func anOrbitChangesTheViewButNotTheDigest() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Script.open(session, number: Script.candidateLevels[0], atHalf: true)
        let before: Core = try T.core(shell)
        let digest: String = try T.digest(shell)
        let sentBefore: Script.Sent = Script.sent(shell)
        #expect(shell.presenter.orbit == .authored)
        let snapshot: Snapshot = try Script.drawn(shell)
        let first: Vec2 = try #require(Script.emptyPoint(snapshot, orbit: .authored), "empty space picks")
        let second: Vec2 = try #require(Script.emptyPoint(snapshot, orbit: .authored, away: first, minimum: 200),
                                        "a second empty point picks")
        let shift: Vec2 = Vec2(100, 0)
        var time: Double = Script.start

        Script.orbit(shell, ids: 1, 2, from: first, second, by: shift, time: &time)
        let orbit: ViewOrbit = shell.presenter.orbit
        #expect(orbit != .authored, "two fingers orbit the camera")
        #expect(orbit == orbit.clamped())
        #expect(orbit.isWithinBounds)
        #expect(Script.sent(shell) == sentBefore, "an orbit sends nothing")
        #expect(try T.digest(shell) == digest, "an orbit never changes the digest")
        try T.draw(session)
        #expect(shell.presenter.fallbackReason == nil, "\(shell.presenter.fallbackReason ?? "")")
        #expect(try T.digest(shell) == digest)

        shell.presenter.resetView()
        #expect(shell.presenter.orbit == .authored, "Reset view restores the authored orbit")
        #expect(Script.sent(shell) == sentBefore, "Reset view sends nothing")

        // Orbit again, then a double tap on empty space returns to the authored orbit.
        time += Script.gesturePause
        Script.orbit(shell, ids: 3, 4, from: first, second, by: shift, time: &time)
        let turned: ViewOrbit = shell.presenter.orbit
        #expect(turned != .authored)
        try T.draw(session)
        let drawn: Snapshot = try Script.drawn(shell)
        let empty: Vec2 = try #require(Script.emptyPoint(drawn, orbit: turned), "empty space picks at the orbit")
        try #require(Script.pick(empty, drawn, orbit: turned) == .empty)
        time += Script.gesturePause
        Script.tap(shell, id: 5, at: empty, time: &time)
        #expect(shell.presenter.orbit == turned, "a single tap on empty space keeps the orbit")
        time += Script.tapGap
        Script.tap(shell, id: 6, at: empty, time: &time)
        #expect(shell.presenter.orbit == .authored, "a double tap on empty space resets the view")
        try T.draw(session)
        #expect(shell.presenter.fallbackReason == nil)
        #expect(Script.sent(shell) == sentBefore, "no kernel action and no tick")
        #expect(try T.digest(shell) == digest)
        let after: Core = try T.core(shell)
        #expect(after.shownTick == before.shownTick)
        #expect(after.play == before.play)
        #expect(shell.presenter.refusalLog.isEmpty)
    }

    /// f. `cancelPointers()` during a knob drag drops the preview and sends nothing; the finger's late lift sends
    /// nothing either.
    @Test func cancelPointersDropsThePreview() async throws {
        let number: Int = try #require(try Script.dragLevel(knob: true), "a knob drag fits")
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Script.open(session, number: number, atHalf: true)
        let before: Core = try T.core(shell)
        let snapshot: Snapshot = try Script.drawn(shell)
        let orbit: ViewOrbit = shell.presenter.orbit
        let drag: Script.HandleDrag = try #require(Script.handleDrag(snapshot, orbit: orbit, knob: true),
                                                   "a knob drag fits on the drawn snapshot")
        let digest: String = try T.digest(shell)
        let sentBefore: Script.Sent = Script.sent(shell)
        var time: Double = Script.start

        Script.touch(shell, id: 1, .began, at: drag.start, time: &time)
        Script.moves(shell, id: 1, from: drag.start, to: drag.end, time: &time)
        #expect(shell.presenter.mirror.preview == drag.pending, "the drag previews")
        #expect(try Script.drawn(shell).isPreviewing)

        shell.presenter.cancelPointers()
        #expect(shell.presenter.mirror.preview == nil, "a cancel drops the preview")
        #expect(try Script.drawn(shell).isPreviewing == false, "the drawn snapshot previews nothing")
        #expect(shell.presenter.gestures.state == .idle)
        #expect(Script.sent(shell) == sentBefore, "a cancel sends nothing")

        Script.touch(shell, id: 1, .ended, at: drag.end, time: &time)
        #expect(Script.sent(shell) == sentBefore, "the lift of a cancelled finger sends nothing")
        #expect(try T.digest(shell) == digest)
        #expect(try T.core(shell).play == before.play)
        #expect(shell.presenter.refusalLog.isEmpty)
        try T.draw(session)
        #expect(try Script.drawn(shell).isPreviewing == false, "the next frame previews nothing")
    }

    /// g. The panel: the pending orbit moves (drawn as the preview, no digest change); "Set periapsis" and "Set size"
    /// send one action each, after which the pending orbit follows the current orbit.
    @Test func thePanelSetsThePendingOrbit() async throws {
        let number: Int = try #require(try Script.panelLevel(), "a level with two actions left")
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Script.open(session, number: number, atHalf: true)
        let before: Core = try T.core(shell)
        let current: Orbit = before.play.orbit
        let mirror: Mirror = shell.presenter.mirror
        #expect(mirror.pendingOrbit == nil)
        #expect(mirror.drawnPreview == nil)
        #expect(mirror.periapsisSettable == false && mirror.sizeSettable == false, "nothing to set yet")
        let digest: String = try T.digest(shell)
        let sentBefore: Script.Sent = Script.sent(shell)

        // Direction +: the pending orbit moves; nothing is sent.
        mirror.movePending(eccentricity: 0, direction: 1, size: 0)
        let turned: Orbit = Orbit(size: current.size, eccentricity: current.eccentricity,
                                  direction: (current.direction + 1) % 24)
        #expect(mirror.pendingOrbit == turned, "Direction + moves the pending direction")
        #expect(mirror.pendingReason == nil)
        #expect(mirror.periapsisSettable, "Set periapsis is enabled")
        #expect(mirror.sizeSettable == false, "the size did not move")
        #expect(mirror.drawnPreview == turned, "the pending orbit is the drawn preview")
        let line: String = mirror.pendingLine("direction", current.direction * 15, turned.direction * 15, unit: "°")
        #expect(line == "direction \(current.direction * 15)° → \(turned.direction * 15)°", "\(line)")
        #expect(Script.sent(shell) == sentBefore, "Direction + sends nothing")
        #expect(try T.digest(shell) == digest, "a pending orbit never changes the digest")
        try T.draw(session)
        let previewing: Snapshot = try Script.drawn(shell)
        #expect(previewing.isPreviewing, "the pending orbit is previewed")
        #expect(previewing.previewOrbit == turned)
        #expect(mirror.pendingOrbit == turned, "a frame keeps the pending orbit")

        // Set periapsis: one orbit.periapsis with the pending eccentricity and direction.
        let periapsis: [Double] = [Double(mirror.pending.eccentricity), Double(mirror.pending.direction)]
        let expected = Script.applied(before, "orbit.periapsis", periapsis)
        #expect(expected.result == .accepted)
        let result: ActionResult = shell.presenter.send("orbit.periapsis", periapsis, port: shell.port)
        #expect(result == .accepted, "\(result.code)")
        let tuned: Core = try T.core(shell)
        #expect(tuned.play.orbit == turned, "Set periapsis sets the pending orbit")
        #expect(tuned.play.actionsLeft == before.play.actionsLeft - 1, "one action of the budget is spent")
        #expect(tuned.play == expected.core.play, "the kernel's verdict")
        let sentTuned: Script.Sent = Script.sent(shell)
        #expect(sentTuned.accepted == sentBefore.accepted + 1, "exactly one orbit.periapsis")
        #expect(sentTuned.rejected == sentBefore.rejected)
        #expect(try T.digest(shell) != digest)
        #expect(mirror.pendingOrbit == nil, "an applied tuning: the pending orbit follows the current orbit")
        #expect(mirror.message == nil)
        try T.draw(session)
        #expect(try Script.drawn(shell).isPreviewing == false, "nothing is previewed after Set periapsis")
        #expect(mirror.periapsisSettable == false)

        // Size + (or Size − where + would be invalid), then Set size: one orbit.size.
        var step: Int = 1
        let larger: Orbit = Orbit(size: turned.size + 1, eccentricity: turned.eccentricity,
                                  direction: turned.direction)
        if !larger.isValid { step = -1 }
        let sized: Orbit = Orbit(size: turned.size + step, eccentricity: turned.eccentricity,
                                 direction: turned.direction)
        try #require(sized.isValid, "a size step is valid")
        mirror.movePending(eccentricity: 0, direction: 0, size: step)
        #expect(mirror.pendingOrbit == sized)
        #expect(mirror.sizeSettable, "Set size is enabled")
        #expect(mirror.periapsisSettable == false)
        let digestTuned: String = try T.digest(shell)
        try T.draw(session)
        #expect(try Script.drawn(shell).previewOrbit == sized)
        #expect(try T.digest(shell) == digestTuned)
        let expectedSize = Script.applied(tuned, "orbit.size", [Double(mirror.pending.size)])
        #expect(expectedSize.result == .accepted)
        let sizeResult: ActionResult = shell.presenter.send("orbit.size", [Double(mirror.pending.size)],
                                                            port: shell.port)
        #expect(sizeResult == .accepted, "\(sizeResult.code)")
        let after: Core = try T.core(shell)
        #expect(after.play.orbit == sized)
        #expect(after.play.actionsLeft == before.play.actionsLeft - 2)
        #expect(after.play == expectedSize.core.play)
        #expect(Script.sent(shell).accepted == sentBefore.accepted + 2)
        #expect(mirror.pendingOrbit == nil, "the pending orbit follows the current orbit again")
        #expect(shell.presenter.refusalLog.isEmpty)
        try T.draw(session)
        #expect(try Script.drawn(shell).isPreviewing == false)
    }

    /// h. An invalid pending orbit says why in words and draws no preview; nothing is sent.
    @Test func anInvalidPendingOrbitIsExplained() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Script.open(session, number: Script.candidateLevels[0], atHalf: true)
        let mirror: Mirror = shell.presenter.mirror
        let current: Orbit = try T.core(shell).play.orbit
        let digest: String = try T.digest(shell)
        let sentBefore: Script.Sent = Script.sent(shell)

        // The smallest size at the largest eccentricity: a periapsis of 8 · 5 = 40 < 60 dips into the star.
        mirror.movePending(eccentricity: 15, direction: 0, size: -48)
        let dip: Orbit = Orbit(size: 8, eccentricity: 15, direction: current.direction)
        #expect(mirror.pendingOrbit == dip)
        #expect(mirror.pendingReason == "The periapsis would dip into the star", "\(mirror.pendingReason ?? "")")
        #expect(Mirror.invalidReason(dip) == Controller.invalidReason(dip))
        #expect(Controller.dipReason == "The periapsis would dip into the star")
        #expect(mirror.drawnPreview == nil, "an invalid pending orbit is not drawn")
        try T.draw(session)
        #expect(try Script.drawn(shell).isPreviewing == false)

        // The largest size at the largest eccentricity: an apoapsis of 48 · 35 = 1680 > 1280 leaves the sky.
        mirror.movePending(eccentricity: 0, direction: 0, size: 48)
        let leave: Orbit = Orbit(size: 48, eccentricity: 15, direction: current.direction)
        #expect(mirror.pendingOrbit == leave)
        #expect(mirror.pendingReason == "The apoapsis would leave the sky", "\(mirror.pendingReason ?? "")")
        #expect(Mirror.invalidReason(leave) == Controller.invalidReason(leave))
        #expect(Controller.leaveReason == "The apoapsis would leave the sky")
        #expect(mirror.drawnPreview == nil)
        try T.draw(session)
        #expect(try Script.drawn(shell).isPreviewing == false, "an invalid pending orbit draws no preview")
        #expect(Script.sent(shell) == sentBefore, "a pending orbit sends nothing")
        #expect(try T.digest(shell) == digest)
    }

    /// i. A refused action logs its bare code and the mirror shows the refusal in words: undo with nothing to undo
    /// through the panel's sender, then a knob drag with no action left.
    @Test func aRefusedActionIsLoggedAndShown() async throws {
        let target = try #require(try Script.budgetTarget(), "a level whose budget can be spent, then a knob drag")
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Script.open(session, number: target.number, atHalf: target.atHalf)
        let opening: Core = try T.core(shell)

        // Undo with nothing to undo.
        let expectedUndo = Script.applied(opening, "play.undo", [])
        #expect(!expectedUndo.result.isAccepted, "nothing to undo at the opening")
        #expect(Mirror.bareCode(expectedUndo.result.code) == Script.actionCode, "\(expectedUndo.result.code)")
        let undo: ActionResult = shell.presenter.send("play.undo", [], port: shell.port)
        #expect(!undo.isAccepted)
        #expect(undo.code == Mirror.rulePrefix + Script.actionCode, "the engine prefixes the kernel's code")
        #expect(shell.presenter.refusalLog == [Script.actionCode], "the bare code is logged")
        let undoMessage: String = try #require(shell.presenter.mirror.message, "the refusal is shown")
        #expect(undoMessage == Mirror.refusalMessage(code: Script.actionCode), "\(undoMessage)")
        #expect(undoMessage == ApsidesWorkshopFeedbackPlan.refusalText(code: Script.actionCode), "\(undoMessage)")
        #expect(Mirror.refusalText(code: Mirror.rulePrefix + Script.actionCode)
                    == Mirror.refusalText(code: Script.actionCode), "codes are read with or without the prefix")
        #expect(try T.core(shell).play == opening.play, "a refused undo changes nothing")

        // Spend the budget, then a knob drag: the tuning is sent and refused.
        let accepted: Int = T.issue(shell, target.setUp)
        #expect(accepted == target.setUp.count)
        let spent: Core = try T.core(shell)
        try #require(spent.play.actionsLeft == 0, "the budget is spent")
        try #require(spent.play.stage == .playing)
        try T.draw(session)
        let snapshot: Snapshot = try Script.drawn(shell)
        let orbit: ViewOrbit = shell.presenter.orbit
        let drag: Script.HandleDrag = try #require(Script.handleDrag(snapshot, orbit: orbit, knob: true),
                                                   "a knob drag fits")
        let values: [Double] = [Double(drag.pending.eccentricity), Double(drag.pending.direction)]
        let expected = Script.applied(spent, "orbit.periapsis", values)
        #expect(Mirror.bareCode(expected.result.code) == Script.budgetCode, "\(expected.result.code)")
        let digest: String = try T.digest(shell)
        let sentBefore: Script.Sent = Script.sent(shell)
        var time: Double = Script.start

        Script.touch(shell, id: 1, .began, at: drag.start, time: &time)
        Script.moves(shell, id: 1, from: drag.start, to: drag.end, time: &time)
        Script.touch(shell, id: 1, .ended, at: drag.end, time: &time)
        let sentAfter: Script.Sent = Script.sent(shell)
        #expect(sentAfter.accepted == sentBefore.accepted, "nothing was accepted")
        #expect(sentAfter.rejected == sentBefore.rejected + 1, "the orbit.periapsis was sent and refused")
        let message: String = try #require(shell.presenter.mirror.message, "the refusal is shown")
        #expect(message == Mirror.refusalMessage(code: Script.budgetCode), "\(message)")
        #expect(message.contains(Mirror.refusalText(code: Script.budgetCode)), "\(message)")
        #expect(shell.presenter.refusalLog == [Script.actionCode, Script.budgetCode], "both bare codes, in order")
        #expect(try T.core(shell).play == spent.play, "a refused tuning changes nothing")
        #expect(try T.digest(shell) == digest)
        #expect(try Script.drawn(shell).isPreviewing == false, "the preview is dropped at the release")
        try T.draw(session)
        #expect(try Script.drawn(shell).isPreviewing == false)
    }

    /// j. A tap on the knob explains the handles and sends nothing; every gesture action is a native action.
    @Test func aKnobTapExplainsAndGesturesAreNative() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Script.open(session, number: Script.candidateLevels[0], atHalf: true)
        let presenter: ApsidesWorkshopPresenter = shell.presenter
        #expect(presenter.gestureActions.isSubset(of: presenter.nativeActions), "\(presenter.gestureActions)")
        #expect(presenter.gestureActions == ["orbit.periapsis", "orbit.size", "clock.show"])
        #expect(presenter.nativeActions == Set(Core.actionIDs))
        let before: Core = try T.core(shell)
        let snapshot: Snapshot = try Script.drawn(shell)
        let orbit: ViewOrbit = presenter.orbit
        let knob: Vec2 = try #require(Script.handlePoint(snapshot, orbit: orbit, knob: true), "the knob picks")
        let digest: String = try T.digest(shell)
        let sentBefore: Script.Sent = Script.sent(shell)
        var time: Double = Script.start

        Script.tap(shell, id: 1, at: knob, time: &time)
        #expect(presenter.mirror.message == Controller.handleReason, "the tap says how to tune")
        #expect(Controller.handleReason == "Drag the knob or the size handle to tune the orbit")
        #expect(Script.sent(shell) == sentBefore, "a tap on the knob sends nothing")
        #expect(try T.digest(shell) == digest)
        #expect(try T.core(shell).play == before.play)
        #expect(try T.core(shell).shownTick == before.shownTick)
        #expect(presenter.refusalLog.isEmpty)
        #expect(try Script.drawn(shell).isPreviewing == false, "a tap previews nothing")
    }
}
#endif
