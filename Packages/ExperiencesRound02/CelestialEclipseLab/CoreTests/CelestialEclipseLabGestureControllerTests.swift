// CelestialEclipseLabGestureControllerTests — feature 464 (R02-G17-04) T-R02G1704-003 (FR-R02G1704-001 … 004, 006,
// 007; SC-R02G1704-001 … 003; clarifications Q1 … Q5). 500 seeded (SeededRandom seed 2_464) scripted gestures — taps
// on planets (fixed ones included), taps on the time dial (some slow), one or two taps on empty space, dial drags,
// phase drags to another ring position or out and back, drags from any planet, touches of 10 … 16 points, slow
// presses, cancelled phase drags, random touches, drags from empty space, second fingers and system cancels — on
// certified levels 1, 40 and 90 (`CelestialEclipseLabExperienceCore.opening(number:)`; the opening and the moment
// after the first certified phase change, both playing; won by the certified plan and the run; failed by running the
// opening), at three view sizes and three orbits reached by two-finger drags, send exactly the actions an independent
// expectation written here predicts. What lies under the finger is asked of the picker's contract
// (`CelestialEclipseLabPicker.pick`, `dialTick`, `ringOffset`), so the expectation stays valid for any picker that
// keeps it; the gesture semantics (tap, drag or nothing by travel and event timestamps; the dial's ticks from
// touch-down on; the pending offset's changes on moves only; the explanation once per gesture; one phase change on
// release only when it differs from the current phase; double taps on empty space within 0.35 s and 22 points; no
// kernel action outside playing) are written here on their own. Every action is applied as the presenter would,
// through the adapter's `apply(ExperienceAction(control:values:step:))`: setPhase → `orbit.phase [body, offset]`
// (always accepted), choosePlanet → `orbit.choose [body]`, showTick → `clock.show [tick]`, preview → the snapshot's
// `previewing(body:offset:)`, clearPreview → the snapshot without a preview; only setPhase may change the digest.
// Also: thresholds at their boundaries, phase drags setting one phase or explaining, dial drags showing every tick in
// any stage, and the second and third fingers' clamped orbit with the double-tap reset. Explicit types, plain loops;
// each test well under 5 s; no wall-clock asserts.
import Foundation
import Testing
import VisualCoreDiagnostics
import VisualCoreExperience
import VisualCoreMath
import VisualCoreScenes
import VisualCoreSimulation
@testable import CelestialEclipseLabCore

@Suite struct CelestialEclipseLabGestureControllerTests {
    typealias Controller = CelestialEclipseLabGestureController
    typealias Snapshot = CelestialEclipseLabSceneSnapshot
    typealias Action = CelestialEclipseLabGestureAction
    typealias Orbit = CelestialEclipseLabOrbit
    typealias Core = CelestialEclipseLabExperienceCore
    typealias Pick = CelestialEclipseLabPick
    typealias P = CelestialEclipseLabPicker
    typealias G = CelestialEclipseLabSceneGeometry

    /// The seed of every random choice here.
    static let seed: UInt64 = 2_464
    /// The view sizes every script runs at: a phone upright, a phone on its side, a tablet.
    static let views: [Vec2] = [Vec2(390, 844), Vec2(844, 390), Vec2(1_024, 768)]
    /// The scripted orbits (the first is the authored one), reached by two-finger drags.
    static let orbits: [Orbit] = [.authored, Orbit(yaw: 0.6, pitch: 0.3), Orbit(yaw: -0.9, pitch: -0.3)]
    /// The certified levels used (level 1 has a fixed planet).
    static let levels: [Int] = [1, 40, 90]
    /// The explanations, written here on their own.
    static let fixedText: String = "This planet is fixed: its phase cannot change"
    static let overText: String = "The play is over: undo or go to the next level"

    // MARK: Cases

    /// A core (for the digest and the adapter) and the snapshot the controller sees.
    struct Case {
        let core: Core
        let snapshot: Snapshot
    }

    /// A case of `core` at presentation time 0.
    static func make(_ core: Core) -> Case { Case(core: core, snapshot: core.snapshot(time: 0)) }

    /// An adapter action of `control` with whole `values`.
    static func action(_ control: String, _ values: [Int]) -> ExperienceAction {
        var doubles: [Double] = []
        for v in values { doubles.append(Double(v)) }
        return ExperienceAction(control: control, values: doubles, step: 0)
    }

    /// Whether `a` is a kernel action (a phase change).
    static func isKernel(_ a: Action) -> Bool {
        if case .setPhase = a { return true }
        return false
    }

    /// The digest of `core` as the engine computes it.
    static func digest(_ core: Core) throws -> String {
        var builder: DigestBuilder = DigestBuilder(domain: Core.experienceID)
        try core.writeDigest(into: &builder)
        return builder.finish().hex
    }

    /// Certified level `number`: the opening (playing), after the first certified phase change (playing, when the plan
    /// has two or more), after the whole certified plan and the run (won), and the opening run at once (failed).
    static func cases(_ number: Int) throws -> [Case] {
        let plan: [CelestialEclipseLabAction] = try Core.generated(number: number).plan.actions
        try #require(!plan.isEmpty)
        let opening: Core = try Core.opening(number: number)
        #expect(opening.play.stage == .playing)
        var result: [Case] = [make(opening)]
        var core: Core = opening
        for (index, change) in plan.enumerated() {
            guard case let .phase(body, offset) = change else { continue }
            #expect(core.apply(action("orbit.phase", [body, offset])) == .accepted)
            if index == 0 && plan.count >= 2 {
                #expect(core.play.stage == .playing)
                result.append(make(core))
            }
        }
        #expect(core.apply(action("clock.run", [])) == .accepted)
        #expect(core.play.stage == .won)
        result.append(make(core))
        var failed: Core = opening
        #expect(failed.apply(action("clock.run", [])) == .accepted)
        try #require(failed.play.stage == .failed, "running the opening of level \(number) did not fail")
        result.append(make(failed))
        return result
    }

    /// Every case of ``levels``.
    static func allCases() throws -> [Case] {
        var all: [Case] = []
        for number in levels { all += try cases(number) }
        return all
    }

    // MARK: The picker's contract

    /// `v` as SIMD.
    static func simd(_ v: Vec2) -> SIMD2<Double> { SIMD2(v.x, v.y) }
    /// `v` as a `Vec2`.
    static func vec(_ v: SIMD2<Double>) -> Vec2 { Vec2(v.x, v.y) }

    /// What the picker finds under `p`.
    static func pick(_ p: Vec2, _ s: Snapshot, _ view: Vec2, _ orbit: Orbit) -> Pick {
        P.pick(simd(p), size: simd(view), snapshot: s, orbit: orbit)
    }

    /// The tick the picker reads under `p` on the dial.
    static func tick(_ p: Vec2, _ s: Snapshot, _ view: Vec2, _ orbit: Orbit) -> Int {
        P.dialTick(simd(p), size: simd(view), snapshot: s, orbit: orbit)
    }

    /// The ring offset the picker reads for planet `body` under `p`.
    static func ring(_ p: Vec2, _ body: Int, _ s: Snapshot, _ view: Vec2, _ orbit: Orbit) -> Int {
        P.ringOffset(simd(p), body: body, size: simd(view), snapshot: s, orbit: orbit)
    }

    /// The projected view point of world point `w`.
    static func project(_ w: SIMD3<Double>, _ s: Snapshot, _ view: Vec2, _ orbit: Orbit) -> Vec2? {
        let camera: CelestialEclipseLabCamera = G.camera(s, aspect: view.x / view.y, orbit: orbit)
        guard let p = P.viewPoint(w, size: simd(view), camera: camera) else { return nil }
        return vec(p)
    }

    /// A point near `centre` (its projection, else the nearest point of a 4-point grid within 16 points) that
    /// `wanted` accepts.
    static func near(_ centre: Vec2?, _ s: Snapshot, _ view: Vec2, _ orbit: Orbit,
                     _ wanted: (Pick) -> Bool) -> Vec2? {
        guard let c = centre else { return nil }
        if wanted(pick(c, s, view, orbit)) { return c }
        var best: Vec2? = nil
        var bestDistance: Double = Double.infinity
        for a in -4...4 {
            for b in -4...4 {
                let p: Vec2 = c + Vec2(Double(a) * 4, Double(b) * 4)
                let d: Double = (p - c).length
                if d < bestDistance, wanted(pick(p, s, view, orbit)) {
                    best = p
                    bestDistance = d
                }
            }
        }
        return best
    }

    /// A point that picks planet `i`, or nil.
    static func bodyPoint(_ i: Int, _ s: Snapshot, _ view: Vec2, _ orbit: Orbit) -> Vec2? {
        near(project(G.bodyCentre(i, s), s, view, orbit), s, view, orbit) { $0 == .body(i) }
    }

    /// A point on the dial near tick `t`, or nil.
    static func dialPoint(_ t: Int, _ s: Snapshot, _ view: Vec2, _ orbit: Orbit) -> Vec2? {
        near(project(G.tickPosition(t, s), s, view, orbit), s, view, orbit) { $0 == .dial }
    }

    /// The projected position of planet `body` at phase `offset` (its ring position at the shown tick), or nil.
    static func ringPoint(_ body: Int, _ offset: Int, _ s: Snapshot, _ view: Vec2, _ orbit: Orbit) -> Vec2? {
        project(G.ringPosition(body, offset: offset, s), s, view, orbit)
    }

    /// A point that picks nothing: the first of the view's corners (8 points in) that does.
    static func emptyPoint(_ s: Snapshot, _ view: Vec2, _ orbit: Orbit) -> Vec2? {
        let corners: [Vec2] = [Vec2(8, 8), Vec2(view.x - 8, 8), Vec2(8, view.y - 8), Vec2(view.x - 8, view.y - 8)]
        for c in corners where pick(c, s, view, orbit) == .empty { return c }
        return nil
    }

    /// `p` kept one point inside `view`.
    static func inside(_ p: Vec2, _ view: Vec2) -> Vec2 {
        Vec2(min(max(p.x, 1), view.x - 1), min(max(p.y, 1), view.y - 1))
    }

    /// A unit random number.
    static func unit(_ random: inout SeededRandom) -> Double { random.double() }
    /// A whole random number 0 ..< `count`.
    static func below(_ count: Int, _ random: inout SeededRandom) -> Int {
        min(Int(random.double() * Double(count)), max(count - 1, 0))
    }

    /// A seeded planet (perhaps fixed) and a point that picks it.
    static func anyBody(_ s: Snapshot, _ view: Vec2, _ orbit: Orbit,
                        _ random: inout SeededRandom) -> (body: Int, point: Vec2)? {
        let i: Int = below(s.bodies.count, &random)
        guard let p = bodyPoint(i, s, view, orbit) else { return nil }
        return (i, p)
    }

    /// A seeded movable planet and a point that picks it.
    static func movableBody(_ s: Snapshot, _ view: Vec2, _ orbit: Orbit,
                            _ random: inout SeededRandom) -> (body: Int, point: Vec2)? {
        var movable: [Int] = []
        for i in s.bodies.indices where !s.bodies[i].fixed { movable.append(i) }
        guard !movable.isEmpty else { return nil }
        let i: Int = movable[below(movable.count, &random)]
        guard let p = bodyPoint(i, s, view, orbit) else { return nil }
        return (i, p)
    }

    /// A seeded fixed planet (any planet when the level has none) and a point that picks it.
    static func fixedBody(_ s: Snapshot, _ view: Vec2, _ orbit: Orbit,
                          _ random: inout SeededRandom) -> (body: Int, point: Vec2)? {
        var fixed: [Int] = []
        for i in s.bodies.indices where s.bodies[i].fixed { fixed.append(i) }
        guard !fixed.isEmpty else { return anyBody(s, view, orbit, &random) }
        let i: Int = fixed[below(fixed.count, &random)]
        guard let p = bodyPoint(i, s, view, orbit) else { return nil }
        return (i, p)
    }

    // MARK: Scripting

    /// One step of a one-finger script: a pointer event of finger 1.
    struct Step {
        let phase: PointerPhase
        let point: Vec2
        let time: Double
    }

    /// A pointer event.
    static func event(_ id: Int, _ phase: PointerPhase, _ point: Vec2, _ time: Double) -> PointerEvent {
        PointerEvent(id: id, phase: phase, location: point, timestamp: time)
    }

    /// A straight path of `steps` + 1 events from `a` to `b` at 0.03 s intervals from `time`, the end repeated 0.02 s
    /// later as the release.
    static func path(_ a: Vec2, _ b: Vec2, steps: Int, time: Double) -> [Step] {
        var result: [Step] = []
        var last: Vec2 = a
        var lastTime: Double = time
        for i in 0...steps {
            last = a + (b - a) * (Double(i) / Double(steps))
            lastTime = time + 0.03 * Double(i)
            result.append(Step(phase: i == 0 ? .began : .moved, point: last, time: lastTime))
        }
        result.append(Step(phase: .ended, point: last, time: lastTime + 0.02))
        return result
    }

    /// A path from `a` out to `b` and back to `c`, 3 moves each way, then the release at `c`.
    static func outAndBack(_ a: Vec2, _ b: Vec2, _ c: Vec2, time: Double) -> [Step] {
        var result: [Step] = []
        for st in path(a, b, steps: 3, time: time) where st.phase != .ended { result.append(st) }
        for i in 1...3 {
            let p: Vec2 = b + (c - b) * (Double(i) / 3)
            result.append(Step(phase: .moved, point: p, time: time + 0.09 + 0.03 * Double(i)))
        }
        result.append(Step(phase: .ended, point: c, time: time + 0.2))
        return result
    }

    /// Two fingers (7 and 8) going down at `a` and `b`, moving their midpoint by `move` and lifting.
    static func twoFingers(_ controller: inout Controller, a: Vec2, b: Vec2, by move: Vec2, view: Vec2,
                           snapshot: Snapshot, time: Double) -> [Action] {
        let frame: Double = 1.0 / 60
        let evs: [PointerEvent] = [event(7, .began, a, time), event(8, .began, b, time + frame),
                                   event(7, .moved, a + move, time + 2 * frame),
                                   event(8, .moved, b + move, time + 3 * frame),
                                   event(7, .ended, a + move, time + 4 * frame),
                                   event(8, .ended, b + move, time + 5 * frame)]
        var actions: [Action] = []
        for e in evs { actions += controller.handle(e, viewSize: view, snapshot: snapshot) }
        return actions
    }

    /// Whether two orbits agree within 1e-9 radians.
    static func near(_ a: Orbit, _ b: Orbit) -> Bool {
        abs(a.yaw - b.yaw) < 1e-9 && abs(a.pitch - b.pitch) < 1e-9
    }

    /// `orbit` turned by a midpoint movement of `delta` in `view` (90° per width, 60° per height, pitch up for an
    /// upward movement), clamped to yaw ±60° and pitch −20° … 35° — computed here on its own.
    static func turned(_ orbit: Orbit, by delta: Vec2, view: Vec2) -> Orbit {
        let yawLimit: Double = 60.0 * Double.pi / 180
        let yaw: Double = orbit.yaw + delta.x / view.x * (Double.pi / 2)
        let pitch: Double = orbit.pitch - delta.y / view.y * (Double.pi / 3)
        return Orbit(yaw: min(max(yaw, -yawLimit), yawLimit),
                     pitch: min(max(pitch, -20.0 * Double.pi / 180), 35.0 * Double.pi / 180))
    }

    /// A controller turned to `orbit` by a two-finger drag in `view`.
    static func controller(at orbit: Orbit, view: Vec2, snapshot: Snapshot) -> Controller {
        var controller: Controller = Controller()
        let a: Vec2 = Vec2(view.x * 0.25, view.y * 0.5)
        let b: Vec2 = Vec2(view.x * 0.75, view.y * 0.5)
        let move: Vec2 = Vec2(orbit.yaw / (Double.pi / 2) * view.x, -orbit.pitch / (Double.pi / 3) * view.y)
        let actions: [Action] = twoFingers(&controller, a: a, b: b, by: move, view: view, snapshot: snapshot, time: 0)
        #expect(actions.isEmpty)
        #expect(near(controller.orbit, orbit))
        #expect(controller.state == .idle)
        return controller
    }

    // MARK: The presenter, through the adapter

    /// The presenter's side: the core every action is applied to and the preview it draws.
    struct Presenter {
        var core: Core
        var preview: (body: Int, offset: Int)? = nil
        var accepted: Int = 0

        /// The snapshot drawn now (previewing when a drag previews).
        var snapshot: Snapshot {
            let plain: Snapshot = core.snapshot(time: 0)
            guard let p = preview else { return plain }
            return plain.previewing(body: p.body, offset: p.offset)
        }

        /// Applies gesture action `a` through the adapter and checks its effect (see the file header).
        mutating func apply(_ a: Action, run: Int) throws {
            typealias T = CelestialEclipseLabGestureControllerTests
            let before: String = try T.digest(core)
            switch a {
            case let .setPhase(body, offset):
                let spent: Int = core.play.actionsSpent
                let result: ActionResult = core.apply(T.action("orbit.phase", [body, offset]))
                #expect(result == .accepted, "setPhase(\(body), \(offset)) refused: \(result), run \(run)")
                if result == .accepted {
                    accepted += 1
                    #expect(core.play.phases[body] == offset && core.play.actionsSpent == spent + 1, "run \(run)")
                }
                preview = nil
                return
            case .choosePlanet(let body):
                #expect(core.apply(T.action("orbit.choose", [body])) == .accepted, "run \(run)")
                #expect(core.chosenBody == body)
            case .showTick(let tick):
                #expect(core.apply(T.action("clock.show", [tick])) == .accepted, "run \(run)")
                #expect(core.shownTick == tick)
            case let .preview(body, offset):
                preview = (body, offset)
                let drawn: Snapshot = snapshot
                #expect(drawn.previewBody == body && drawn.previewOffset == offset, "run \(run)")
            case .clearPreview:
                preview = nil
                #expect(!snapshot.isPreviewing)
            case .resetView, .explain:
                break
            }
            #expect(try T.digest(core) == before, "a presentation action changed the digest, run \(run)")
        }
    }

    /// Feeds `steps` (finger 1) to `controller`, each event with the presenter's current snapshot, applying every
    /// action at once; returns the actions and the state after touch-down.
    static func run(_ controller: inout Controller, _ steps: [Step], view: Vec2, presenter: inout Presenter,
                    run: Int) throws -> (actions: [Action], state: Controller.State) {
        var actions: [Action] = []
        var state: Controller.State = .idle
        for index in steps.indices {
            let st: Step = steps[index]
            let got: [Action] = controller.handle(event(1, st.phase, st.point, st.time), viewSize: view,
                                                  snapshot: presenter.snapshot)
            for a in got { try presenter.apply(a, run: run) }
            actions += got
            if index == 0 { state = controller.state }
        }
        return (actions, state)
    }

    // MARK: Independent expectation

    /// A tap on empty space that may start a double tap: its lift point and time.
    struct TapRecord {
        let point: Vec2
        let time: Double
    }

    /// What a one-finger script must send and the state after touch-down.
    struct Expectation {
        var actions: [Action] = []
        var state: Controller.State = .idle
    }

    /// The expectation of a dial gesture `steps` from touch-down on: the tick under the touch, then every change.
    static func expectedDial(_ steps: [Step], _ s: Snapshot, _ view: Vec2, _ orbit: Orbit) -> [Action] {
        var last: Int = tick(steps[0].point, s, view, orbit)
        var actions: [Action] = [.showTick(last)]
        for index in 1..<steps.count where steps[index].phase != .cancelled {
            let t: Int = tick(steps[index].point, s, view, orbit)
            if t != last { actions.append(.showTick(t)) }
            last = t
        }
        return actions
    }

    /// The expectation of one-finger `steps` (the first a `.began`, the last an `.ended` or a `.cancelled`) beginning
    /// on snapshot `s` in `view` at `orbit` after the double-tap candidate `record`, written on its own from
    /// clarifications Q1 … Q4 (the picker's contract says what lies under a point).
    static func expected(_ steps: [Step], _ s: Snapshot, _ view: Vec2, _ orbit: Orbit,
                         record: inout TapRecord?) -> Expectation {
        let origin: Vec2 = steps[0].point
        let startTime: Double = steps[0].time
        let picked: Pick = pick(origin, s, view, orbit)
        var result: Expectation = Expectation()
        var body: Int = -1
        switch picked {
        case .body(let i):
            result.state = .planetPress
            body = i
        case .dial:
            result.state = .dialDrag
            result.actions = expectedDial(steps, s, view, orbit)
            record = nil
            return result
        case .empty:
            result.state = .emptyPress
        }
        let fixed: Bool = body >= 0 && s.bodies[body].fixed
        let movableWhilePlaying: Bool = body >= 0 && !fixed && s.stage == .playing
        var travel: Double = 0
        var dragging: Bool = false
        var pending: Int? = nil
        for index in 1..<steps.count {
            let st: Step = steps[index]
            if st.phase == .cancelled {
                if pending != nil { result.actions.append(.clearPreview) }
                record = nil
                break
            }
            travel = max(travel, (st.point - origin).length)
            if body >= 0 && !dragging && travel >= 16 {
                dragging = true
                if fixed {
                    result.actions.append(.explain(fixedText))
                } else if s.stage != .playing {
                    result.actions.append(.explain(overText))
                }
            }
            if st.phase == .moved && dragging && movableWhilePlaying {
                let offset: Int = ring(st.point, body, s, view, orbit)
                if offset != pending {
                    result.actions.append(.preview(body: body, offset: offset))
                    pending = offset
                }
            }
            guard st.phase == .ended else { continue }
            let tap: Bool = !dragging && travel < 10 && st.time - startTime < 0.5
            if body >= 0 {
                record = nil
                if dragging && movableWhilePlaying {
                    let offset: Int = ring(st.point, body, s, view, orbit)
                    if offset != s.phases[body] {
                        result.actions.append(.setPhase(body: body, offset: offset))
                    } else {
                        result.actions.append(.clearPreview)
                    }
                } else if tap {
                    result.actions.append(.choosePlanet(body))
                }
            } else if tap {
                if let r = record, st.time - r.time <= 0.35, (st.point - r.point).length <= 22 {
                    result.actions.append(.resetView)
                    record = nil
                } else {
                    record = TapRecord(point: st.point, time: st.time)
                }
            } else {
                record = nil
            }
        }
        return result
    }

    // MARK: Seeded scripts

    /// One seeded one-finger gesture (or two, for a double tap) of `kind` (0 … 11) on `s` in `view` at `orbit`, or nil
    /// without a target.
    static func scripts(_ kind: Int, _ s: Snapshot, _ view: Vec2, _ orbit: Orbit,
                        _ random: inout SeededRandom) -> [[Step]]? {
        switch kind {
        case 0:   // a tap on a planet (perhaps fixed)
            guard let c = anyBody(s, view, orbit, &random) else { return nil }
            let q: Vec2 = c.point + Vec2(unit(&random) * 6 - 3, unit(&random) * 6 - 3)
            return [[Step(phase: .began, point: c.point, time: 1),
                     Step(phase: .ended, point: q, time: 1.05 + 0.4 * unit(&random))]]
        case 1:   // a dial tap, sometimes slow
            guard let p = dialPoint(below(s.horizon, &random), s, view, orbit) else { return nil }
            let lift: Double = unit(&random) < 0.3 ? 1.7 : 1.08
            return [[Step(phase: .began, point: p, time: 1), Step(phase: .ended, point: p, time: lift)]]
        case 2:   // one or two taps on empty space, sometimes too late or too far for a double tap
            guard let e = emptyPoint(s, view, orbit) else { return nil }
            let first: [Step] = [Step(phase: .began, point: e, time: 1), Step(phase: .ended, point: e, time: 1.05)]
            if unit(&random) < 0.3 { return [first] }
            let q: Vec2 = inside(e + Vec2(unit(&random) * 24 - 12, unit(&random) * 24 - 12), view)
            let gap: Double = 0.1 + 0.32 * unit(&random)
            return [first, [Step(phase: .began, point: q, time: 1.01 + gap),
                            Step(phase: .ended, point: q, time: 1.05 + gap)]]
        case 3:   // a dial drag from one tick to another, sometimes past the dial's end or off it
            let a: Int = below(s.horizon, &random)
            let b: Int = below(s.horizon, &random)
            guard let p = dialPoint(a, s, view, orbit), var q = dialPoint(b, s, view, orbit) else { return nil }
            if unit(&random) < 0.3 { q = q + Vec2(unit(&random) * 160 - 80, unit(&random) * 120 - 60) }
            return [path(p, q, steps: 3 + below(5, &random), time: 1)]
        case 4:   // a phase drag to the ring position of a seeded offset
            guard let c = movableBody(s, view, orbit, &random) else { return nil }
            let offset: Int = below(s.bodies[c.body].period, &random)
            guard let end = ringPoint(c.body, offset, s, view, orbit) else { return nil }
            return [path(c.point, end, steps: 3 + below(4, &random), time: 1)]
        case 5:   // a phase drag out to a ring position and back to the body or to anywhere
            guard let c = movableBody(s, view, orbit, &random) else { return nil }
            let offset: Int = below(s.bodies[c.body].period, &random)
            guard let out = ringPoint(c.body, offset, s, view, orbit) else { return nil }
            var back: Vec2 = c.point + Vec2(unit(&random) * 6 - 3, unit(&random) * 6 - 3)
            if unit(&random) < 0.3 { back = inside(Vec2(view.x * unit(&random), view.y * unit(&random)), view) }
            return [outAndBack(c.point, out, back, time: 1)]
        case 6:   // a drag from a fixed planet (any planet when there is none) in a seeded direction
            guard let c = fixedBody(s, view, orbit, &random) else { return nil }
            let a: Double = unit(&random) * 2 * Double.pi
            let length: Double = 20 + 180 * unit(&random)
            return [path(c.point, inside(c.point + Vec2(cos(a) * length, sin(a) * length), view), steps: 3, time: 1)]
        case 7:   // a short touch of 10 … 16 points from a planet or anywhere
            var p: Vec2 = inside(Vec2(view.x * unit(&random), view.y * unit(&random)), view)
            if unit(&random) < 0.7, let c = anyBody(s, view, orbit, &random) { p = c.point }
            let a: Double = unit(&random) * 2 * Double.pi
            let length: Double = 10.5 + 5 * unit(&random)
            return [path(p, p + Vec2(cos(a) * length, sin(a) * length), steps: 2, time: 1)]
        case 8:   // a slow press (lifted 0.5 … 1.0 s after touch-down) moving under 10 points
            var start: Vec2? = anyBody(s, view, orbit, &random)?.point
            if start == nil || unit(&random) < 0.2 { start = emptyPoint(s, view, orbit) }
            guard let p = start else { return nil }
            let q: Vec2 = p + Vec2(unit(&random) * 8 - 4, unit(&random) * 8 - 4)
            return [[Step(phase: .began, point: p, time: 1), Step(phase: .moved, point: q, time: 1.2),
                     Step(phase: .ended, point: q, time: 1.5 + 0.5 * unit(&random))]]
        case 9:   // a cancelled touch on a movable planet, perhaps dragged to a ring position first
            guard let c = movableBody(s, view, orbit, &random) else { return nil }
            var q: Vec2 = c.point
            let offset: Int = below(s.bodies[c.body].period, &random)
            if unit(&random) < 0.7, let r = ringPoint(c.body, offset, s, view, orbit) { q = r }
            return [[Step(phase: .began, point: c.point, time: 1), Step(phase: .moved, point: q, time: 1.1),
                     Step(phase: .cancelled, point: q, time: 1.2)]]
        case 10:  // a random touch, sometimes slow
            let p: Vec2 = inside(Vec2(view.x * unit(&random), view.y * unit(&random)), view)
            let q: Vec2 = p + Vec2(unit(&random) * 80 - 40, unit(&random) * 80 - 40)
            let slow: Double = unit(&random) < 0.3 ? 0.6 : 0
            var steps: [Step] = []
            for st in path(p, q, steps: 2, time: 1) {
                let time: Double = st.phase == .began ? st.time : st.time + slow
                steps.append(Step(phase: st.phase, point: st.point, time: time))
            }
            return [steps]
        default:  // a drag from empty space
            guard let p = emptyPoint(s, view, orbit) else { return nil }
            let a: Double = unit(&random) * 2 * Double.pi
            let length: Double = 20 + 200 * unit(&random)
            return [path(p, inside(p + Vec2(cos(a) * length, sin(a) * length), view), steps: 3, time: 1)]
        }
    }

    /// A seeded one-finger script of `kind` checked against its expectation; nil when it has no target here.
    static func oneFinger(_ kind: Int, _ controller: inout Controller, _ presenter: inout Presenter, _ view: Vec2,
                          _ orbit: Orbit, run: Int, _ random: inout SeededRandom) throws -> [Action]? {
        guard let gestures = scripts(kind, presenter.snapshot, view, orbit, &random) else { return nil }
        var record: TapRecord? = nil
        var produced: [Action] = []
        for g in gestures {
            let want: Expectation = expected(g, presenter.snapshot, view, orbit, record: &record)
            let got: (actions: [Action], state: Controller.State) = try self.run(&controller, g, view: view,
                                                                                 presenter: &presenter, run: run)
            #expect(got.actions == want.actions, "run \(run) kind \(kind)")
            #expect(got.state == want.state, "run \(run) kind \(kind)")
            #expect(controller.state == .idle)
            produced += got.actions
        }
        if kind == 1 || kind == 3 || kind == 6 || kind == 7 || kind == 8 || kind == 9 || kind == 11 {
            for a in produced where isKernel(a) {
                // A drag "from a fixed planet" falls back to any planet on a level without one.
                let fallback: Bool = kind == 6 && !presenter.core.play.level.bodies.contains { $0.fixed }
                #expect(fallback, "kind \(kind) sent \(a), run \(run)")
            }
        }
        #expect(near(controller.orbit, orbit) || produced.contains(.resetView))
        return produced
    }

    /// A seeded second-finger script: the first finger on a movable planet (perhaps dragged to a ring position) or the
    /// dial, a second finger cancels (only `clearPreview` when a preview was pending) and orbits; nothing kernel is
    /// sent, nothing at all after the clearing value, and the orbit turns by half the second finger's movement.
    static func secondFinger(_ controller: inout Controller, _ presenter: inout Presenter, _ view: Vec2,
                             _ orbit: Orbit, run: Int, _ random: inout SeededRandom) throws -> [Action]? {
        let s: Snapshot = presenter.snapshot
        var start: Vec2? = nil
        var body: Int = -1
        if let c = movableBody(s, view, orbit, &random) {
            start = c.point
            body = c.body
        }
        if unit(&random) < 0.3 {
            start = dialPoint(below(s.horizon, &random), s, view, orbit)
            body = -1
        }
        guard let p = start else { return nil }
        var first: Vec2 = p
        var steps: [Step] = [Step(phase: .began, point: p, time: 1)]
        if body >= 0, unit(&random) < 0.7,
           let r = ringPoint(body, below(s.bodies[body].period, &random), s, view, orbit) {
            first = r
            steps.append(Step(phase: .moved, point: first, time: 1.05))
        }
        var probe: [Step] = steps
        probe.append(Step(phase: .cancelled, point: first, time: 1.1))
        var record: TapRecord? = nil
        let want: [Action] = expected(probe, s, view, orbit, record: &record).actions
        var before: [Action] = try self.run(&controller, steps, view: view, presenter: &presenter, run: run).actions
        let q: Vec2 = Vec2(view.x / 2, view.y / 2)
        let clearing: [Action] = controller.handle(event(2, .began, q, 1.2), viewSize: view,
                                                   snapshot: presenter.snapshot)
        for a in clearing { try presenter.apply(a, run: run) }
        before += clearing
        #expect(before == want, "second finger run \(run)")
        #expect(controller.state == .orbiting, "second finger run \(run)")
        let move: Vec2 = Vec2((unit(&random) - 0.5) * view.x * 0.6, (unit(&random) - 0.5) * view.y * 0.6)
        let digestBefore: String = try digest(presenter.core)
        var actions: [Action] = controller.handle(event(2, .moved, q + move, 1.25), viewSize: view,
                                                  snapshot: presenter.snapshot)
        actions += controller.handle(event(1, .ended, first, 1.3), viewSize: view, snapshot: presenter.snapshot)
        #expect(controller.state == .cancelled)
        actions += controller.handle(event(2, .ended, q + move, 1.35), viewSize: view, snapshot: presenter.snapshot)
        #expect(controller.state == .idle)
        #expect(actions.isEmpty, "second finger run \(run)")
        #expect(near(controller.orbit, turned(orbit, by: move * 0.5, view: view)), "second finger run \(run)")
        #expect(try digest(presenter.core) == digestBefore, "orbit changed the digest, run \(run)")
        return before + actions
    }

    /// A seeded `cancel()` in the middle of a press or a phase drag: the finger's later events send nothing.
    static func systemCancel(_ controller: inout Controller, _ presenter: inout Presenter, _ view: Vec2,
                             _ orbit: Orbit, run: Int, _ random: inout SeededRandom) throws -> [Action]? {
        let s: Snapshot = presenter.snapshot
        guard let c = anyBody(s, view, orbit, &random) else { return nil }
        let q: Vec2 = unit(&random) < 0.4 ? c.point : inside(c.point + Vec2(40, -30), view)
        let steps: [Step] = [Step(phase: .began, point: c.point, time: 1), Step(phase: .moved, point: q, time: 1.05)]
        let actions: [Action] = try self.run(&controller, steps, view: view, presenter: &presenter, run: run).actions
        for a in actions { #expect(!isKernel(a), "system cancel run \(run)") }
        controller.cancel()
        #expect(controller.state == .idle)
        let after: [Action] = controller.handle(event(1, .ended, q, 1.1), viewSize: view, snapshot: presenter.snapshot)
        #expect(after.isEmpty, "system cancel run \(run)")
        #expect(near(controller.orbit, orbit))
        return actions + after
    }

    /// The name of an action's case.
    static func name(_ a: Action) -> String {
        switch a {
        case .choosePlanet: return "choosePlanet"
        case .showTick: return "showTick"
        case .setPhase: return "setPhase"
        case .preview: return "preview"
        case .clearPreview: return "clearPreview"
        case .resetView: return "resetView"
        case .explain: return "explain"
        }
    }

    // MARK: Tests

    @Test func fiveHundredSeededScriptsMatchTheIndependentExpectation() throws {
        let all: [Case] = try Self.allCases()
        var digests: [String] = []
        for c in all { digests.append(try Self.digest(c.core)) }
        var random: SeededRandom = SeededRandom(seed: Self.seed)
        var run: Int = 0
        var attempts: Int = 0
        let kinds: Int = 14
        var counts: [Int] = Array(repeating: 0, count: kinds)
        var sent: [String: Int] = [:]
        var accepted: Int = 0
        var finished: Int = 0
        var stages: Set<String> = []
        while run < 500 && attempts < 5_000 {
            attempts += 1
            let c: Case = all[Self.below(all.count, &random)]
            let view: Vec2 = Self.views[Self.below(Self.views.count, &random)]
            let nominal: Orbit = Self.orbits[Self.below(Self.orbits.count, &random)]
            var presenter: Presenter = Presenter(core: c.core)
            var controller: Controller = Self.controller(at: nominal, view: view, snapshot: presenter.snapshot)
            #expect(try Self.digest(presenter.core) == Self.digest(c.core), "orbit changed the digest")
            let orbit: Orbit = controller.orbit
            let kind: Int = Self.below(kinds, &random)
            var produced: [Action]?
            if kind == 12 {
                produced = try Self.secondFinger(&controller, &presenter, view, orbit, run: run, &random)
            } else if kind == 13 {
                produced = try Self.systemCancel(&controller, &presenter, view, orbit, run: run, &random)
            } else {
                produced = try Self.oneFinger(kind, &controller, &presenter, view, orbit, run: run, &random)
            }
            guard let result = produced else { continue }
            var kernel: Int = 0
            for a in result {
                sent[Self.name(a), default: 0] += 1
                if Self.isKernel(a) {
                    kernel += 1
                    #expect(c.snapshot.stage == .playing, "a kernel action outside playing, run \(run)")
                }
            }
            #expect(kernel <= 1, "run \(run)")
            #expect(presenter.accepted == kernel, "every setPhase is accepted, run \(run)")
            if kind == 12 || kind == 13 || kind == 9 { #expect(kernel == 0, "run \(run)") }
            if c.snapshot.stage != .playing {
                finished += 1
                #expect(kernel == 0, "run \(run)")
                #expect(presenter.core.play == c.core.play, "run \(run)")
            }
            if kernel == 0 { #expect(try Self.digest(presenter.core) == Self.digest(c.core), "run \(run)") }
            accepted += presenter.accepted
            stages.insert(c.snapshot.stage.rawValue)
            counts[kind] += 1
            run += 1
        }
        #expect(run == 500)
        for k in 0..<kinds { #expect(counts[k] > 0, "script kind \(k) never ran: \(counts)") }
        for n in ["choosePlanet", "showTick", "setPhase", "preview", "clearPreview", "resetView", "explain"] {
            #expect((sent[n] ?? 0) > 0, "\(n) never sent: \(sent)")
        }
        #expect(stages == ["playing", "won", "failed"])
        #expect(accepted > 10, "\(accepted) phase changes accepted")
        #expect(finished > 100)
        for index in all.indices { #expect(try Self.digest(all[index].core) == digests[index]) }
    }

    /// A point 40 points from `p` towards the view's centre (to the right when `p` is the centre).
    static func away(_ p: Vec2, _ view: Vec2) -> Vec2 {
        let d: Vec2 = Vec2(view.x / 2, view.y / 2) - p
        guard d.length >= 1 else { return p + Vec2(40, 0) }
        return p + d * (40 / d.length)
    }

    /// A movable planet, a point picking it and an offset other than its current phase whose projected ring position
    /// lies at least 30 points away and reads back as that offset, at the authored orbit in `view`; nil when none.
    static func dragTarget(_ s: Snapshot, _ view: Vec2) -> (body: Int, point: Vec2, offset: Int, end: Vec2)? {
        for b in s.bodies.indices where !s.bodies[b].fixed {
            guard let p = bodyPoint(b, s, view, .authored) else { continue }
            for o in 0..<s.bodies[b].period where o != s.phases[b] {
                guard let q = ringPoint(b, o, s, view, .authored), (q - p).length >= 30,
                      ring(q, b, s, view, .authored) == o else { continue }
                return (b, p, o, q)
            }
        }
        return nil
    }

    @Test func tapsChooseAndThresholdsHoldAtTheirBoundaries() throws {
        let view: Vec2 = Self.views[2]
        let c: Case = try Self.cases(1)[0]
        let s: Snapshot = c.snapshot
        let t = try #require(Self.dragTarget(s, view))
        let (body, p): (Int, Vec2) = (t.body, t.point)
        func play(_ steps: [Step]) -> [Action] {
            var controller: Controller = Controller()
            var actions: [Action] = []
            for st in steps {
                actions += controller.handle(Self.event(1, st.phase, st.point, st.time), viewSize: view, snapshot: s)
            }
            return actions
        }
        func tap(_ at: Double, from: Vec2, lift: Vec2? = nil, held: Double = 0.05) -> [Step] {
            [Step(phase: .began, point: from, time: at), Step(phase: .ended, point: lift ?? from, time: at + held)]
        }
        // Taps on a planet: under 10 points, lifted before 0.5 s; 10 … 16 points and slow presses do nothing.
        #expect(play(tap(1, from: p, held: 0.49)) == [.choosePlanet(body)])
        #expect(play(tap(1, from: p, held: 0.5)).isEmpty)
        #expect(play(tap(1, from: p, lift: p + Vec2(0, 9.9))) == [.choosePlanet(body)])
        #expect(play(tap(1, from: p, lift: p + Vec2(0, 10))).isEmpty)
        #expect(play(tap(1, from: p, lift: p + Vec2(0, 15.9))).isEmpty)
        // A release 16 points away starts a drag: one phase change or a clearing value, never a preview.
        let release16: [Action] = play(tap(1, from: p, lift: p + Vec2(16, 0)))
        let o16: Int = Self.ring(p + Vec2(16, 0), body, s, view, .authored)
        let want16: [Action] = o16 == s.phases[body] ? [.clearPreview] : [.setPhase(body: body, offset: o16)]
        #expect(release16 == want16)
        // Two taps on a planet are two choices (no double tap on planets).
        #expect(play(tap(1, from: p) + tap(1.2, from: p)) == [.choosePlanet(body), .choosePlanet(body)])
        // A fixed planet is chosen by a tap and explains a drag.
        for f in s.bodies.indices where s.bodies[f].fixed {
            guard let fp = Self.bodyPoint(f, s, view, .authored) else { continue }
            #expect(play(tap(1, from: fp)) == [.choosePlanet(f)])
            #expect(play(Self.path(fp, fp + Vec2(0, 16), steps: 2, time: 1)) == [.explain(Self.fixedText)])
        }
        // Double taps on empty space: within 0.35 s and 22 points reset the view; later or farther do not.
        let e: Vec2 = try #require(Self.emptyPoint(s, view, .authored))
        let inward: Vec2 = Vec2(e.x < view.x / 2 ? 1 : -1, 0)
        #expect(play(tap(1, from: e) + tap(1.3, from: e)) == [.resetView])
        #expect(play(tap(1, from: e) + tap(1.36, from: e)).isEmpty)
        let at22: Vec2 = e + inward * 22
        if Self.pick(at22, s, view, .authored) == .empty {
            #expect(play(tap(1, from: e) + tap(1.2, from: at22)) == [.resetView])
        }
        let at23: Vec2 = e + inward * 23
        if Self.pick(at23, s, view, .authored) == .empty {
            #expect(play(tap(1, from: e) + tap(1.2, from: at23)).isEmpty)
        }
        // A completed double tap starts no new one; a slow first tap starts none.
        #expect(play(tap(1, from: e) + tap(1.2, from: e) + tap(1.4, from: e)) == [.resetView])
        #expect(play(tap(1, from: e, held: 0.6) + tap(1.8, from: e)).isEmpty)
        #expect(Controller.tapDistance == 10 && Controller.dragDistance == 16 && Controller.tapDuration == 0.5)
        #expect(Controller.doubleTapWindow == 0.35 && Controller.doubleTapDistance == 22)
        #expect(Controller.fixedReason == Self.fixedText && Controller.finishedReason == Self.overText)
    }

    @Test func phaseDragsPreviewSetOnePhaseOrExplain() throws {
        let view: Vec2 = Self.views[1]
        var set: Int = 0
        var over: Int = 0
        var fixed: Int = 0
        for number in Self.levels {
            for c in try Self.cases(number) {
                let s: Snapshot = c.snapshot
                guard let t = Self.dragTarget(s, view) else { continue }
                var controller: Controller = Controller()
                var presenter: Presenter = Presenter(core: c.core)
                let drag: [Step] = Self.path(t.point, t.end, steps: 6, time: 1)
                let got = try Self.run(&controller, drag, view: view, presenter: &presenter, run: -1)
                #expect(got.state == .planetPress)
                var kernel: Int = 0
                for a in got.actions where Self.isKernel(a) { kernel += 1 }
                if s.stage == .playing {
                    #expect(got.actions.contains(.preview(body: t.body, offset: t.offset)), "\(got.actions)")
                    #expect(got.actions.last == .setPhase(body: t.body, offset: t.offset), "\(got.actions)")
                    #expect(kernel == 1 && presenter.accepted == 1)
                    #expect(presenter.core.play.phases[t.body] == t.offset)
                    set += 1
                    // Out to the ring position and back to the body: previewed, then cleared; nothing sent.
                    var back: Controller = Controller()
                    var still: Presenter = Presenter(core: c.core)
                    let none: [Action] = try Self.run(&back, Self.outAndBack(t.point, t.end, t.point, time: 1),
                                                      view: view, presenter: &still, run: -1).actions
                    let home: Int = Self.ring(t.point, t.body, s, view, .authored)
                    if home == s.phases[t.body] {
                        #expect(!none.contains { Self.isKernel($0) } && none.last == .clearPreview, "\(none)")
                        #expect(try Self.digest(still.core) == Self.digest(c.core))
                    }
                } else {
                    #expect(got.actions == [.explain(Self.overText)], "\(got.actions)")
                    #expect(presenter.core.play == c.core.play)
                    over += 1
                }
                // From a fixed planet: explained once, in any stage.
                for f in s.bodies.indices where s.bodies[f].fixed {
                    guard let fp = Self.bodyPoint(f, s, view, .authored) else { continue }
                    var fc: Controller = Controller()
                    var fpres: Presenter = Presenter(core: c.core)
                    let words: [Action] = try Self.run(&fc, Self.path(fp, Self.away(fp, view), steps: 6, time: 1),
                                                       view: view, presenter: &fpres, run: -1).actions
                    #expect(words == [.explain(Self.fixedText)], "\(words)")
                    fixed += 1
                }
                // 10 … 16 points from a planet: nothing.
                var short: Controller = Controller()
                var quiet: Presenter = Presenter(core: c.core)
                let shortSteps: [Step] = Self.path(t.point, t.point + Vec2(0, 13), steps: 2, time: 1)
                #expect(try Self.run(&short, shortSteps, view: view, presenter: &quiet, run: -1).actions.isEmpty)
                // A cancelled phase drag clears its preview and sends nothing else.
                var cancelled: Controller = Controller()
                var cpres: Presenter = Presenter(core: c.core)
                var steps: [Step] = Self.path(t.point, t.end, steps: 4, time: 1)
                steps[steps.count - 1] = Step(phase: .cancelled, point: t.end, time: 1.2)
                let gone: [Action] = try Self.run(&cancelled, steps, view: view, presenter: &cpres, run: -1).actions
                #expect(!gone.contains { Self.isKernel($0) })
                if s.stage == .playing { #expect(gone.last == .clearPreview, "\(gone)") }
                #expect(cpres.core.play == c.core.play)
            }
        }
        #expect(set > 0 && over > 0 && fixed > 0, "set \(set) over \(over) fixed \(fixed)")
    }

    @Test func dialDragsShowEveryTickInAnyStage() throws {
        let view: Vec2 = Self.views[0]
        var checked: Int = 0
        for number in Self.levels {
            for c in try Self.cases(number) {
                let s: Snapshot = c.snapshot
                let last: Int = s.horizon - 1
                guard let a = Self.project(G.tickPosition(0, s), s, view, .authored),
                      let b = Self.project(G.tickPosition(last, s), s, view, .authored),
                      Self.pick(a, s, view, .authored) == .dial else { continue }
                var controller: Controller = Controller()
                var presenter: Presenter = Presenter(core: c.core)
                let got = try Self.run(&controller, Self.path(a, b, steps: 3 * last, time: 1), view: view,
                                       presenter: &presenter, run: -1)
                #expect(got.state == .dialDrag)
                var want: [Action] = []
                for tick in 0...last { want.append(.showTick(tick)) }
                #expect(got.actions == want, "level \(number) stage \(s.stage): \(got.actions)")
                #expect(presenter.core.shownTick == last)
                #expect(try Self.digest(presenter.core) == Self.digest(c.core))
                checked += 1
            }
        }
        #expect(checked >= 6)
    }

    @Test func secondAndThirdFingersOrbitClampedAndCameraFollows() throws {
        let c: Case = try Self.cases(1)[0]
        let s: Snapshot = c.snapshot
        let view: Vec2 = Self.views[1]
        let t = try #require(Self.dragTarget(s, view))
        var controller: Controller = Controller()
        var actions: [Action] = controller.handle(Self.event(1, .began, t.point, 1), viewSize: view, snapshot: s)
        actions += controller.handle(Self.event(1, .moved, t.end, 1.05), viewSize: view, snapshot: s)
        #expect(controller.state == .planetDrag && actions == [.preview(body: t.body, offset: t.offset)])
        let b: Vec2 = Vec2(700, 300)
        #expect(controller.handle(Self.event(2, .began, b, 1.1), viewSize: view, snapshot: s) == [.clearPreview])
        #expect(controller.state == .orbiting)
        // The midpoint of fingers 1 and 2 moves by half of finger 2's movement.
        var orbit: Orbit = .authored
        #expect(controller.handle(Self.event(2, .moved, b + Vec2(200, -100), 1.15), viewSize: view,
                                  snapshot: s).isEmpty)
        orbit = Self.turned(orbit, by: Vec2(100, -50), view: view)
        #expect(Self.near(controller.orbit, orbit))
        // A third finger re-bases: its touch-down turns nothing.
        #expect(controller.handle(Self.event(3, .began, Vec2(100, 100), 1.2), viewSize: view, snapshot: s).isEmpty)
        #expect(Self.near(controller.orbit, orbit))
        // Far beyond the limits: clamped.
        _ = controller.handle(Self.event(3, .moved, Vec2(100 + 30_000, 100 - 30_000), 1.25), viewSize: view,
                              snapshot: s)
        #expect(abs(controller.orbit.yaw - 60.0 * Double.pi / 180) < 1e-12)
        #expect(abs(controller.orbit.pitch - 35.0 * Double.pi / 180) < 1e-12)
        let camera: CelestialEclipseLabCamera = try #require(controller.camera(viewSize: view, snapshot: s))
        #expect(camera == G.camera(s, aspect: view.x / view.y, orbit: controller.orbit))
        #expect(controller.camera(viewSize: Vec2(0, 100), snapshot: s) == nil)
        for id in [1, 2, 3] {
            #expect(controller.handle(Self.event(id, .ended, b, 1.3), viewSize: view, snapshot: s).isEmpty)
        }
        #expect(controller.state == .idle)
        // A double tap on empty space resets the view; so does resetView().
        let e: Vec2 = try #require(Self.emptyPoint(s, view, controller.orbit))
        var reset: [Action] = []
        for ev in [Self.event(1, .began, e, 2), Self.event(1, .ended, e, 2.05), Self.event(1, .began, e, 2.2),
                   Self.event(1, .ended, e, 2.25)] {
            reset += controller.handle(ev, viewSize: view, snapshot: s)
        }
        #expect(reset == [.resetView] && controller.orbit == .authored)
        _ = Self.twoFingers(&controller, a: Vec2(300, 200), b: Vec2(600, 200), by: Vec2(-200, 0), view: view,
                            snapshot: s, time: 3)
        #expect(controller.orbit != .authored)
        controller.resetView()
        #expect(controller.orbit == .authored)
        let authored: CelestialEclipseLabCamera = try #require(controller.camera(viewSize: view, snapshot: s))
        #expect(authored == G.camera(s, aspect: view.x / view.y))
        // A system cancel mid-drag: later events of that finger send nothing.
        var cancelling: Controller = Controller()
        _ = cancelling.handle(Self.event(1, .began, t.point, 4), viewSize: view, snapshot: s)
        _ = cancelling.handle(Self.event(1, .moved, t.end, 4.05), viewSize: view, snapshot: s)
        cancelling.cancel()
        #expect(cancelling.state == .idle)
        #expect(cancelling.handle(Self.event(1, .ended, t.end, 4.1), viewSize: view, snapshot: s).isEmpty)
    }
}
