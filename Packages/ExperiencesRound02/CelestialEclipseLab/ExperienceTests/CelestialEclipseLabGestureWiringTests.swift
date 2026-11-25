// CelestialEclipseLabGestureWiringTests — feature 464 (R02-G17-04) T-R02G1704-005 (FR-R02G1704-001 … 009;
// SC-R02G1704-001 … 005; clarifications Q1–Q5). On the simulator, through the one app's session host: scripted touches
// go to the presenter's `pointer(_:viewSize:port:)` with the shell's own `port` at a 720 × 480-point view (aspect 1.5),
// following Starlit Cartouche's wiring tests (feature 454). Targets are projected through the drawn camera of the
// presenter's orbit (`CelestialEclipseLabPicker.camera(size:snapshot:orbit:)`, then
// `CelestialEclipseLabPicker.viewPoint` of `CelestialEclipseLabSceneGeometry.bodyCentre` for a planet,
// `ringPosition(_:offset:_:)` for a ring offset and `tickPosition(_:_:)` for the time dial) on the presenter's
// `lastSnapshot`, and each is confirmed with the picker (`pick`, `ringOffset`, `dialTick`) at the same view size before
// any touch. Levels are chosen at run time from bare
// opening cores (seed n − 1 opens level n); the kernel's verdict is the one a bare core gives for the same actions.
// Checked:
//   a. a tap on a planet chooses it (`orbit.choose`; core.chosenBody, the drawn snapshot, the mirror); the digest is
//      unchanged;
//   b. a ring drag on a movable planet while playing previews the pending offset (the drawn snapshot previews it) and
//      on release sets exactly that phase: one `orbit.phase`, actions left − 1, the fingerprint a bare core gives;
//   c. a drag along the time dial shows the ticks under the finger (`clock.show`; shownTick follows); the digest is
//      unchanged;
//   d. a drag from a fixed planet sends nothing and the mirror says the planet is fixed;
//   e. on a won play (the certified plan and `clock.run` issued through the shell) a phase drag sends nothing and the
//      mirror says the play is over;
//   f. a two-finger orbit changes `orbit` and never the digest; `resetView()` and a double tap on empty space return
//      to `CelestialEclipseLabOrbit.authored`;
//   g. a ring drag with no action left sends the phase change, the kernel refuses it (`r02-g17.budget`) and the mirror
//      shows the refusal in words;
//   h. the panel: phase + moves the pending offset (previewed, no digest change); "Set phase" (the presenter's `send`,
//      as the controls call it) sends one `orbit.phase`.
// Explicit synthetic timestamps (no clock, no sleep, no wall-clock assertion). Explicit types and plain loops (CI
// type-check rule); no nested closure literals.
#if os(iOS)
import CelestialEclipseLabCore
import CoreGraphics
import Foundation
import Testing
@testable import CelestialEclipseLabExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreScenes

/// Scripted touches on Celestial Eclipse Lab, placed through the drawn camera.
@MainActor
enum CelestialEclipseLabGestureScript {
    typealias Shell = CelestialEclipseLabTest.Shell
    typealias Snapshot = CelestialEclipseLabSceneSnapshot
    typealias Geometry = CelestialEclipseLabSceneGeometry
    typealias Core = CelestialEclipseLabExperienceCore
    typealias Picker = CelestialEclipseLabPicker
    typealias Orbit = CelestialEclipseLabOrbit
    typealias Action = CelestialEclipseLabAction

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
    /// The shortest phase drag scripted, points (more than the drag distance 16).
    static let minimumDrag: Double = 24
    /// The length of a scripted drag that only has to start a phase drag, points.
    static let shortDrag: Double = 40
    /// How far inside the view a touch point must lie, points.
    static let inset: Double = 8
    /// The radii in points around a projected centre at which a touch point is tried.
    static let radii: [Double] = [0, 4, 8, 12, 16]
    /// The directions tried at each radius.
    static let directions: Int = 8
    /// The grid step of the empty-space search, points.
    static let gridStep: Double = 12
    /// The candidate levels; the first that fits is used.
    static let candidateLevels: [Int] = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]
    /// The kernel's budget refusal code.
    static let budgetCode: String = "r02-g17.budget"

    /// What the engine has counted so far: accepted and rejected actions.
    struct Sent: Equatable {
        /// The accepted actions.
        let accepted: Int
        /// The rejected actions.
        let rejected: Int
    }

    /// A phase drag on a snapshot: the movable planet, the offset aimed at and the touch-down and release points.
    struct RingDrag {
        /// The planet dragged.
        let body: Int
        /// The ring offset at the release point (differs from the planet's current phase).
        let offset: Int
        /// The touch-down point (picks the planet).
        let start: Vec2
        /// The release point (the ring offset reads ``offset`` there).
        let end: Vec2
    }

    /// A level and the actions issued through the shell before the gesture.
    struct LevelTarget {
        /// The level number.
        let number: Int
        /// The actions issued before the gesture.
        let setUp: [Action]
    }

    /// Opens level `number` (seed `number − 1`) at the scripted view size (one frame drawn).
    static func open(_ session: ExperienceSession, number: Int) async throws -> Shell {
        try await CelestialEclipseLabTest.open(session, seed: UInt64(number - 1),
                                               size: CGSize(width: viewWidth, height: viewHeight))
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
    static func pick(_ location: Vec2, _ snapshot: Snapshot, orbit: Orbit) -> CelestialEclipseLabPick {
        Picker.pick(simd(location), size: size, snapshot: snapshot, orbit: orbit)
    }

    /// World `point` in view points through the drawn camera of `snapshot` at `orbit`; nil when it does not project.
    static func project(_ point: SIMD3<Double>, _ snapshot: Snapshot, orbit: Orbit) -> Vec2? {
        guard let camera: CelestialEclipseLabCamera = Picker.camera(size: size, snapshot: snapshot, orbit: orbit),
              let p: SIMD2<Double> = Picker.viewPoint(point, size: size, camera: camera) else { return nil }
        return Vec2(p.x, p.y)
    }

    /// A point inside the view near world `centre` (its projection, then rings about it) where the picker gives
    /// `wanted`; nil when none.
    static func point(near centre: SIMD3<Double>, _ snapshot: Snapshot, orbit: Orbit,
                      wanted: CelestialEclipseLabPick) -> Vec2? {
        guard let c: Vec2 = project(centre, snapshot, orbit: orbit) else { return nil }
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

    /// A point where the picker gives `.body(index)`; nil when none.
    static func bodyPoint(_ index: Int, _ snapshot: Snapshot, orbit: Orbit) -> Vec2? {
        guard snapshot.bodies.indices.contains(index) else { return nil }
        return point(near: Geometry.bodyCentre(index, snapshot), snapshot, orbit: orbit, wanted: .body(index))
    }

    /// The first grid point inside the view that picks `.empty` and lies at least `minimum` points from `away` (when
    /// given); nil when none.
    static func emptyPoint(_ snapshot: Snapshot, orbit: Orbit, away: Vec2? = nil, minimum: Double = 0) -> Vec2? {
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

    /// The first phase drag on `snapshot` at `orbit`: a movable planet with a touch point, and an offset other than
    /// its current phase whose ring position projects inside the view at least ``minimumDrag`` points away and reads
    /// that offset there; nil when none.
    static func ringDrag(_ snapshot: Snapshot, orbit: Orbit) -> RingDrag? {
        for body in snapshot.bodies.indices where !snapshot.bodies[body].fixed {
            guard let start: Vec2 = bodyPoint(body, snapshot, orbit: orbit) else { continue }
            let current: Int = snapshot.phases[body]
            for offset in 0..<snapshot.bodies[body].period where offset != current {
                let world: SIMD3<Double> = Geometry.ringPosition(body, offset: offset, snapshot)
                guard let end: Vec2 = project(world, snapshot, orbit: orbit), inside(end),
                      (end - start).length >= minimumDrag else { continue }
                let read: Int = Picker.ringOffset(simd(end), body: body, size: size, snapshot: snapshot, orbit: orbit)
                if read == offset { return RingDrag(body: body, offset: offset, start: start, end: end) }
            }
        }
        return nil
    }

    /// The dial points of `snapshot` at `orbit`, by increasing tick: the projected place of each tick where the picker
    /// gives `.dial` and the dial reads that tick.
    static func dialPoints(_ snapshot: Snapshot, orbit: Orbit) -> [(tick: Int, point: Vec2)] {
        var result: [(tick: Int, point: Vec2)] = []
        for tick in 0..<snapshot.horizon {
            guard let p: Vec2 = project(Geometry.tickPosition(tick, snapshot), snapshot, orbit: orbit), inside(p),
                  pick(p, snapshot, orbit: orbit) == .dial,
                  Picker.dialTick(simd(p), size: size, snapshot: snapshot, orbit: orbit) == tick else { continue }
            result.append((tick, p))
        }
        return result
    }

    /// A drag from a planet of `snapshot` (fixed when `fixed`, else movable) at `orbit`: the planet, its touch point
    /// and a ``shortDrag``-point release inside the view; nil when none.
    static func plainDrag(_ snapshot: Snapshot, orbit: Orbit,
                          fixed: Bool) -> (body: Int, start: Vec2, end: Vec2)? {
        for body in snapshot.bodies.indices where snapshot.bodies[body].fixed == fixed {
            guard let start: Vec2 = bodyPoint(body, snapshot, orbit: orbit),
                  let end: Vec2 = anyDragEnd(from: start) else { continue }
            return (body, start, end)
        }
        return nil
    }

    /// The core `before` after applying `control` with `values`, and the adapter's answer.
    static func applied(_ before: Core, _ control: String, _ values: [Double]) -> (core: Core, result: ActionResult) {
        var copy: Core = before
        let result: ActionResult = copy.apply(ExperienceAction(control: control, values: values, step: 0))
        return (copy, result)
    }

    // MARK: Level choice (from bare cores; an issue is recorded by the caller's `#require` when none fits)

    /// The first candidate level whose opening snapshot has a planet other than the chosen one with a touch point.
    static func tapTarget() throws -> (number: Int, body: Int)? {
        for number in candidateLevels {
            let snapshot: Snapshot = try Core.opening(number: number).snapshot(time: 0)
            for body in snapshot.bodies.indices where body != snapshot.chosenBody {
                if bodyPoint(body, snapshot, orbit: .authored) != nil { return (number, body) }
            }
        }
        return nil
    }

    /// The first candidate level whose opening snapshot has a phase drag.
    static func ringLevel() throws -> Int? {
        for number in candidateLevels {
            let snapshot: Snapshot = try Core.opening(number: number).snapshot(time: 0)
            if ringDrag(snapshot, orbit: .authored) != nil { return number }
        }
        return nil
    }

    /// The first candidate level with at least two dial points on its opening snapshot.
    static func dialLevel() throws -> Int? {
        for number in candidateLevels {
            let snapshot: Snapshot = try Core.opening(number: number).snapshot(time: 0)
            if dialPoints(snapshot, orbit: .authored).count >= 2 { return number }
        }
        return nil
    }

    /// The first candidate level with a fixed planet that has a touch point and a drag inside the view.
    static func fixedLevel() throws -> Int? {
        for number in candidateLevels {
            let snapshot: Snapshot = try Core.opening(number: number).snapshot(time: 0)
            if plainDrag(snapshot, orbit: .authored, fixed: true) != nil { return number }
        }
        return nil
    }

    /// The first candidate level whose certified plan and run win, with a movable planet's drag inside the view on the
    /// won snapshot.
    static func wonLevel() throws -> LevelTarget? {
        for number in candidateLevels {
            let actions: [Action] = try CelestialEclipseLabTest.certifiedPlan(number) + [.run]
            let core: Core = try CelestialEclipseLabTest.coreAfter(number, actions)
            guard core.play.stage == .won else { continue }
            if plainDrag(core.snapshot(time: 0), orbit: .authored, fixed: false) != nil {
                return LevelTarget(number: number, setUp: actions)
            }
        }
        return nil
    }

    /// The first candidate level where the whole budget can be spent by toggling one movable planet between its
    /// opening phase and the next, and the spent snapshot (still playing) has a phase drag.
    static func budgetTarget() throws -> LevelTarget? {
        for number in candidateLevels {
            let opening: Core = try Core.opening(number: number)
            let level: CelestialEclipseLabLevel = opening.play.level
            for body in level.bodies.indices where !level.bodies[body].fixed && level.bodies[body].period >= 2 {
                let first: Int = opening.play.phases[body]
                let other: Int = (first + 1) % level.bodies[body].period
                var setUp: [Action] = []
                for index in 0..<level.budget { setUp.append(.phase(body, index % 2 == 0 ? other : first)) }
                let spent: Core = try CelestialEclipseLabTest.coreAfter(number, setUp)
                guard spent.play.actionsLeft == 0, spent.play.stage == .playing else { continue }
                if ringDrag(spent.snapshot(time: 0), orbit: .authored) != nil {
                    return LevelTarget(number: number, setUp: setUp)
                }
                break
            }
        }
        return nil
    }
}

@MainActor
@Suite(.serialized) struct CelestialEclipseLabGestureWiringTests {
    typealias Script = CelestialEclipseLabGestureScript
    typealias Core = CelestialEclipseLabExperienceCore
    typealias Snapshot = CelestialEclipseLabSceneSnapshot
    typealias Controller = CelestialEclipseLabGestureController
    typealias Mirror = CelestialEclipseLabMirror
    typealias Orbit = CelestialEclipseLabOrbit
    typealias T = CelestialEclipseLabTest

    /// a. A tap on a planet chooses it; no kernel action is taken and the digest does not change.
    @Test func aTapChoosesAPlanet() async throws {
        let target = try #require(try Script.tapTarget(), "a planet other than the chosen one picks")
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Script.open(session, number: target.number)
        let before: Core = try T.core(shell)
        let snapshot: Snapshot = try Script.drawn(shell)
        let orbit: Orbit = shell.presenter.orbit
        #expect(orbit == .authored)
        let point: Vec2 = try #require(Script.bodyPoint(target.body, snapshot, orbit: orbit),
                                       "planet \(target.body) picks inside the view")
        try #require(Script.pick(point, snapshot, orbit: orbit) == .body(target.body))
        let digest: String = try T.digest(shell)
        let sentBefore: Script.Sent = Script.sent(shell)
        var time: Double = Script.start

        Script.tap(shell, id: 1, at: point, time: &time)
        let after: Core = try T.core(shell)
        #expect(after.chosenBody == target.body, "the tap chooses the planet")
        #expect(after.shownTick == before.shownTick, "the shown tick is kept")
        #expect(after.play == before.play, "a tap changes no kernel state")
        let sentAfter: Script.Sent = Script.sent(shell)
        #expect(sentAfter.accepted == sentBefore.accepted + 1, "one orbit.choose accepted")
        #expect(sentAfter.rejected == sentBefore.rejected)
        #expect(try T.digest(shell) == digest, "a choice never changes the digest")
        try T.draw(session)
        #expect(try Script.drawn(shell).chosenBody == target.body, "the drawn snapshot shows the chosen planet")
        #expect(shell.presenter.mirror.chosenBody == target.body, "the panel follows the chosen planet")
        #expect(shell.presenter.mirror.message == nil)
        #expect(try Script.drawn(shell).isPreviewing == false, "a tap previews nothing")
    }

    /// b. A ring drag on a movable planet previews the pending offset, then on release sets exactly that phase.
    @Test func aRingDragSetsOnePhase() async throws {
        let number: Int = try #require(try Script.ringLevel(), "a movable planet and a ring offset pick")
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Script.open(session, number: number)
        let ready: Core = try T.core(shell)
        try #require(ready.play.stage == .playing)
        let snapshot: Snapshot = try Script.drawn(shell)
        let orbit: Orbit = shell.presenter.orbit
        let drag: Script.RingDrag = try #require(Script.ringDrag(snapshot, orbit: orbit), "a phase drag fits")
        try #require(Script.pick(drag.start, snapshot, orbit: orbit) == .body(drag.body))
        let expected = Script.applied(ready, "orbit.phase", [Double(drag.body), Double(drag.offset)])
        #expect(expected.result == .accepted, "the kernel accepts that phase")
        let digest: String = try T.digest(shell)
        let sentBefore: Script.Sent = Script.sent(shell)
        var time: Double = Script.start

        Script.touch(shell, id: 1, .began, at: drag.start, time: &time)
        Script.moves(shell, id: 1, from: drag.start, to: drag.end, time: &time)
        #expect(Script.sent(shell) == sentBefore, "nothing is sent before the release")
        #expect(try T.digest(shell) == digest, "a preview never changes the digest")
        try T.draw(session)
        let previewing: Snapshot = try Script.drawn(shell)
        #expect(previewing.isPreviewing, "the drag previews its pending offset")
        #expect(previewing.previewBody == drag.body)
        #expect(previewing.previewOffset == drag.offset)
        #expect(try T.core(shell).play == ready.play, "nothing is set before the release")

        Script.touch(shell, id: 1, .ended, at: drag.end, time: &time)
        let after: Core = try T.core(shell)
        #expect(after.play.phases[drag.body] == drag.offset, "the release sets exactly the previewed phase")
        #expect(after.play.actionsLeft == ready.play.actionsLeft - 1, "one action of the budget is spent")
        #expect(after.play == expected.core.play, "the kernel's verdict")
        let sentAfter: Script.Sent = Script.sent(shell)
        #expect(sentAfter.accepted == sentBefore.accepted + 1, "one orbit.phase accepted")
        #expect(sentAfter.rejected == sentBefore.rejected)
        #expect(try T.digest(shell) != digest, "the phase change changes the digest")
        try T.draw(session)
        #expect(try Script.drawn(shell).isPreviewing == false, "the preview is dropped after the release")
        #expect(shell.presenter.mirror.message == nil)
    }

    /// c. A drag along the time dial shows the ticks under the finger; no kernel action, no digest change.
    @Test func aDialDragShowsTheTicks() async throws {
        let number: Int = try #require(try Script.dialLevel(), "two ticks pick on the dial")
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Script.open(session, number: number)
        let before: Core = try T.core(shell)
        let snapshot: Snapshot = try Script.drawn(shell)
        let orbit: Orbit = shell.presenter.orbit
        let points: [(tick: Int, point: Vec2)] = Script.dialPoints(snapshot, orbit: orbit)
        try #require(points.count >= 2, "two ticks pick on the dial")
        let from: (tick: Int, point: Vec2) = points[points.count - 1]
        let to: (tick: Int, point: Vec2) = points[0]
        try #require(from.tick != before.shownTick && from.tick != to.tick)
        let digest: String = try T.digest(shell)
        let rejectedBefore: Int = Script.sent(shell).rejected
        var time: Double = Script.start

        Script.touch(shell, id: 1, .began, at: from.point, time: &time)
        #expect(try T.core(shell).shownTick == from.tick, "the touch-down shows the tick under the finger")
        Script.moves(shell, id: 1, from: from.point, to: to.point, time: &time)
        #expect(try T.core(shell).shownTick == to.tick, "the shown tick follows the finger")
        Script.touch(shell, id: 1, .ended, at: to.point, time: &time)
        let after: Core = try T.core(shell)
        #expect(after.shownTick == to.tick)
        #expect(after.chosenBody == before.chosenBody, "the chosen planet is kept")
        #expect(after.play == before.play, "the dial changes no kernel state")
        #expect(Script.sent(shell).rejected == rejectedBefore)
        #expect(try T.digest(shell) == digest, "a shown tick never changes the digest")
        try T.draw(session)
        #expect(shell.presenter.mirror.shownTick == to.tick, "the panel follows the shown tick")
        #expect(try Script.drawn(shell).shownTick == to.tick, "the drawn snapshot shows the tick")
    }

    /// d. A drag from a fixed planet sends nothing and the mirror says the planet is fixed.
    @Test func aFixedPlanetDragSendsNothing() async throws {
        let number: Int = try #require(try Script.fixedLevel(), "a fixed planet picks with a drag inside the view")
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Script.open(session, number: number)
        let before: Core = try T.core(shell)
        let snapshot: Snapshot = try Script.drawn(shell)
        let orbit: Orbit = shell.presenter.orbit
        let drag = try #require(Script.plainDrag(snapshot, orbit: orbit, fixed: true), "a fixed planet's drag fits")
        try #require(Script.pick(drag.start, snapshot, orbit: orbit) == .body(drag.body))
        let digest: String = try T.digest(shell)
        let sentBefore: Script.Sent = Script.sent(shell)
        var time: Double = Script.start

        Script.touch(shell, id: 1, .began, at: drag.start, time: &time)
        Script.moves(shell, id: 1, from: drag.start, to: drag.end, time: &time)
        #expect(shell.presenter.mirror.message == Controller.fixedReason, "the drag says why it does nothing")
        Script.touch(shell, id: 1, .ended, at: drag.end, time: &time)
        #expect(Controller.fixedReason == "This planet is fixed: its phase cannot change")
        #expect(shell.presenter.mirror.message == Controller.fixedReason)
        #expect(Script.sent(shell) == sentBefore, "a drag from a fixed planet sends nothing")
        #expect(try T.digest(shell) == digest)
        #expect(try T.core(shell).play == before.play)
        try T.draw(session)
        #expect(try Script.drawn(shell).isPreviewing == false, "a fixed planet previews nothing")
    }

    /// e. On a won play a phase drag sends nothing and the mirror says the play is over.
    @Test func aPhaseDragOnAWonPlaySendsNothing() async throws {
        let target = try #require(try Script.wonLevel(), "a won play with a movable planet inside the view")
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Script.open(session, number: target.number)
        let accepted: Int = T.issue(shell, target.setUp)
        #expect(accepted == target.setUp.count)
        let won: Core = try T.core(shell)
        try #require(won.play.stage == .won, "the certified plan and the run win level \(target.number)")
        try T.draw(session)
        let snapshot: Snapshot = try Script.drawn(shell)
        #expect(snapshot.stage == .won)
        let orbit: Orbit = shell.presenter.orbit
        let drag = try #require(Script.plainDrag(snapshot, orbit: orbit, fixed: false), "a movable planet's drag fits")
        try #require(Script.pick(drag.start, snapshot, orbit: orbit) == .body(drag.body))
        let digest: String = try T.digest(shell)
        let sentBefore: Script.Sent = Script.sent(shell)
        var time: Double = Script.start

        Script.touch(shell, id: 1, .began, at: drag.start, time: &time)
        Script.moves(shell, id: 1, from: drag.start, to: drag.end, time: &time)
        #expect(shell.presenter.mirror.message == Controller.finishedReason, "the drag says the play is over")
        Script.touch(shell, id: 1, .ended, at: drag.end, time: &time)
        #expect(Controller.finishedReason == "The play is over: undo or go to the next level")
        #expect(shell.presenter.mirror.message == Controller.finishedReason)
        #expect(Script.sent(shell) == sentBefore, "a phase drag on a won play sends nothing")
        #expect(try T.digest(shell) == digest)
        #expect(try T.core(shell).play == won.play)
        try T.draw(session)
        #expect(try Script.drawn(shell).isPreviewing == false, "a finished play previews nothing")
    }

    /// f. A two-finger drag orbits the camera and changes no digest; "Reset view" and a double tap on empty space
    /// return to the authored orbit.
    @Test func anOrbitChangesTheViewButNotTheDigest() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Script.open(session, number: Script.candidateLevels[0])
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
        let orbit: Orbit = shell.presenter.orbit
        #expect(orbit != .authored, "two fingers orbit the camera")
        #expect(orbit == orbit.clamped())
        #expect(Script.sent(shell) == sentBefore, "an orbit sends nothing")
        #expect(try T.digest(shell) == digest, "an orbit never changes the digest")
        try T.draw(session)
        #expect(shell.presenter.fallbackReason == nil, "\(shell.presenter.fallbackReason ?? "")")
        #expect(try T.digest(shell) == digest)

        shell.presenter.resetView()
        #expect(shell.presenter.orbit == .authored, "Reset view restores the authored orbit")

        // Orbit again, then a double tap on empty space returns to the authored orbit.
        time += Script.gesturePause
        Script.orbit(shell, ids: 3, 4, from: first, second, by: shift, time: &time)
        let turned: Orbit = shell.presenter.orbit
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
        #expect(Script.sent(shell) == sentBefore)
        #expect(try T.digest(shell) == digest)
        let after: Core = try T.core(shell)
        #expect(after.chosenBody == before.chosenBody)
        #expect(after.shownTick == before.shownTick)
        #expect(after.play == before.play)
    }

    /// g. With no action left a ring drag sends the phase change; the kernel refuses it and the mirror says why.
    @Test func aRefusedPhaseChangeIsShown() async throws {
        let target = try #require(try Script.budgetTarget(), "a level whose budget can be spent, then a phase drag")
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Script.open(session, number: target.number)
        let accepted: Int = T.issue(shell, target.setUp)
        #expect(accepted == target.setUp.count)
        let spent: Core = try T.core(shell)
        try #require(spent.play.actionsLeft == 0, "the budget is spent")
        try #require(spent.play.stage == .playing)
        try T.draw(session)
        let snapshot: Snapshot = try Script.drawn(shell)
        let orbit: Orbit = shell.presenter.orbit
        let drag: Script.RingDrag = try #require(Script.ringDrag(snapshot, orbit: orbit), "a phase drag fits")
        let expected = Script.applied(spent, "orbit.phase", [Double(drag.body), Double(drag.offset)])
        #expect(!expected.result.isAccepted, "the kernel refuses a phase change with no action left")
        #expect(Mirror.bareCode(expected.result.code) == Script.budgetCode, "\(expected.result.code)")
        let digest: String = try T.digest(shell)
        let sentBefore: Script.Sent = Script.sent(shell)
        var time: Double = Script.start

        Script.touch(shell, id: 1, .began, at: drag.start, time: &time)
        Script.moves(shell, id: 1, from: drag.start, to: drag.end, time: &time)
        Script.touch(shell, id: 1, .ended, at: drag.end, time: &time)
        let sentAfter: Script.Sent = Script.sent(shell)
        #expect(sentAfter.accepted == sentBefore.accepted, "nothing was accepted")
        #expect(sentAfter.rejected == sentBefore.rejected + 1, "the orbit.phase was sent and refused")
        let message: String = try #require(shell.presenter.mirror.message, "the refusal is shown")
        #expect(message == Mirror.refusalMessage(code: Script.budgetCode), "\(message)")
        #expect(message.contains(Mirror.refusalText(code: Script.budgetCode)), "\(message)")
        #expect(Mirror.refusalText(code: Mirror.rulePrefix + Script.budgetCode)
                    == Mirror.refusalText(code: Script.budgetCode), "codes are read with or without the prefix")
        #expect(shell.presenter.refusalLog == [Script.budgetCode], "the bare code is logged")
        let after: Core = try T.core(shell)
        #expect(after.play == spent.play, "a refused phase change changes nothing")
        #expect(try T.digest(shell) == digest)
        try T.draw(session)
        #expect(try Script.drawn(shell).isPreviewing == false, "the preview is dropped after the release")
    }

    /// h. The panel: phase + moves the pending offset (previewed, no digest change); "Set phase" sends one
    /// `orbit.phase` with it.
    @Test func thePanelSetsThePendingPhase() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Script.open(session, number: Script.candidateLevels[0])
        let before: Core = try T.core(shell)
        let body: Int = before.chosenBody
        try #require(!before.play.level.bodies[body].fixed, "a level opens with a movable planet chosen")
        try #require(before.play.level.bodies[body].period >= 2)
        let mirror: Mirror = shell.presenter.mirror
        #expect(mirror.pendingOffset == nil)
        let digest: String = try T.digest(shell)
        let sentBefore: Script.Sent = Script.sent(shell)

        // Phase +: the pending offset moves; nothing is sent.
        let pending: Int = mirror.steppedPending(1)
        #expect(pending == (before.play.phases[body] + 1) % before.play.level.bodies[body].period)
        mirror.pendingOffset = pending
        #expect(mirror.pendingDiffers, "Set phase is enabled")
        #expect(Script.sent(shell) == sentBefore, "phase + sends nothing")
        #expect(try T.digest(shell) == digest, "a pending offset never changes the digest")
        try T.draw(session)
        let previewing: Snapshot = try Script.drawn(shell)
        #expect(previewing.isPreviewing, "the pending offset is previewed")
        #expect(previewing.previewBody == body)
        #expect(previewing.previewOffset == pending)
        #expect(mirror.pendingOffset == pending, "a frame keeps the pending offset")

        // Set phase: one orbit.phase with the pending offset.
        let expected = Script.applied(before, "orbit.phase", [Double(body), Double(pending)])
        #expect(expected.result == .accepted)
        let values: [Double] = [Double(body), Double(mirror.pendingPhase)]
        let result: ActionResult = shell.presenter.send("orbit.phase", values, port: shell.port)
        #expect(result == .accepted, "\(result.code)")
        let after: Core = try T.core(shell)
        #expect(after.play.phases[body] == pending, "Set phase sets the pending offset")
        #expect(after.play.actionsLeft == before.play.actionsLeft - 1, "one action of the budget is spent")
        #expect(after.play == expected.core.play, "the kernel's verdict")
        let sentAfter: Script.Sent = Script.sent(shell)
        #expect(sentAfter.accepted == sentBefore.accepted + 1, "exactly one orbit.phase")
        #expect(sentAfter.rejected == sentBefore.rejected)
        #expect(try T.digest(shell) != digest)
        #expect(mirror.pendingOffset == nil, "an applied phase change drops the pending offset")
        #expect(mirror.message == nil)
        try T.draw(session)
        #expect(try Script.drawn(shell).isPreviewing == false, "nothing is previewed after Set phase")
    }
}
#endif
