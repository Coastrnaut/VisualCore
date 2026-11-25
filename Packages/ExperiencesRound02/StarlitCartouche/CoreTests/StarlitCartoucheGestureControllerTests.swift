// StarlitCartoucheGestureControllerTests — feature 454 (R02-G16-04) T-R02G1604-003 (FR-R02G1604-001, 002, 004, 006,
// 007; SC-R02G1604-001 … 003; clarifications Q1 … Q5). 500 seeded (SeededRandom seed 2_454) scripted gestures — taps
// and double taps on stars (the ship's included), taps and double taps on empty space, slider taps and slider drags,
// ship drags to a star, out and back, or anywhere, touches of 10 … 16 points, slow presses, cancelled touches, random
// touches, drags from stars and empty space, second fingers and system cancels — on certified levels 1, 40 and 90
// (`StarlitCartoucheExperienceCore.opening(number:)`; the opening and the moment after the first certified leg, both
// playing; won by the certified plan; failed by a leg that breaks a rule), at three view sizes and three orbits reached
// by two-finger drags, send exactly the actions an independent expectation written here predicts. What lies under the
// finger is asked of the picker's contract (`StarlitCartouchePicker.pick`, `sliderWait`), so the expectation stays
// valid for any picker that keeps it; the gesture semantics (tap, drag or nothing by travel and event timestamps; the
// slider's waits from touch-down on; the pending destination's changes on moves only; the explanation once per
// gesture; the corridor check on release; double taps within 0.35 s and 22 points on the same star; no kernel action
// outside playing) are written here on their own. Every action is applied as the presenter would, through the
// adapter's `apply(ExperienceAction(control:values:step:))`: fly → `route.fly [star, wait]`, chooseDestination →
// `route.choose [star, chosen wait]`, chooseWait → `route.choose [chosen star, wait]`, preview → `route.choose` of the
// previewed star (the earlier destination kept), clearPreview → `route.choose` of the earlier destination; choices
// and previews keep the digest, a fly is accepted (one leg more, or a failure) or refused by a kernel rule with
// nothing changed. Second fingers, `.cancelled` phases, `cancel()` and finished plays send no kernel action; orbit
// changes no digest. Plain loops and explicit types (CI type-check rule); each test well under 10 s.
import Foundation
import Testing
import VisualCoreDiagnostics
import VisualCoreExperience
import VisualCoreMath
import VisualCoreScenes
import VisualCoreSimulation
@testable import StarlitCartoucheCore

@Suite struct StarlitCartoucheGestureControllerTests {
    typealias Controller = StarlitCartoucheGestureController
    typealias Snapshot = StarlitCartoucheSceneSnapshot
    typealias Action = StarlitCartoucheGestureAction
    typealias Orbit = StarlitCartoucheOrbit
    typealias Core = StarlitCartoucheExperienceCore
    typealias Pick = StarlitCartouchePick
    typealias G = StarlitCartoucheSceneGeometry

    /// The seed of every random choice here.
    static let seed: UInt64 = 2_454
    /// The view sizes every script runs at: phone portrait, tablet landscape, tablet portrait.
    static let views: [Vec2] = [Vec2(390, 844), Vec2(1_180, 820), Vec2(1_024, 1_366)]
    /// The scripted orbits (the first is the authored one), reached by two-finger drags.
    static let orbits: [Orbit] = [.authored, Orbit(yaw: 0.5, pitch: 0.3), Orbit(yaw: -0.7, pitch: -0.2)]
    /// The certified levels used.
    static let levels: [Int] = [1, 40, 90]
    /// The explanations, written here on their own.
    static let overText: String = "The play is over: undo or go to the next level"
    static func corridorText(_ star: Int) -> String { "No corridor joins the ship's star to star \(star)" }

    // MARK: Cases

    /// A core (for the digest and the adapter) and the snapshot the controller sees.
    struct Case {
        let core: Core
        let snapshot: Snapshot
    }

    /// A case of `core` at presentation time 0.
    static func make(_ core: Core) -> Case { Case(core: core, snapshot: core.snapshot(time: 0)) }

    /// A panel action.
    static func action(_ control: String, _ values: [Int]) -> ExperienceAction {
        var doubles: [Double] = []
        for v in values { doubles.append(Double(v)) }
        return ExperienceAction(control: control, values: doubles, step: 0)
    }

    /// Whether `a` is a kernel action (a leg).
    static func isKernel(_ a: Action) -> Bool {
        if case .fly = a { return true }
        return false
    }

    /// The digest of `core` as the engine computes it.
    static func digest(_ core: Core) throws -> String {
        var builder: DigestBuilder = DigestBuilder(domain: Core.experienceID)
        try core.writeDigest(into: &builder)
        return builder.finish().hex
    }

    /// Certified level `number`: the opening (playing), after the first certified leg (playing, when the plan has two
    /// or more legs), after the whole certified plan (won) and a failed play (the first leg from the opening, star
    /// then wait, that the kernel accepts and that fails the level).
    static func cases(_ number: Int) throws -> [Case] {
        let plan: [StarlitCartoucheAction] = try Core.generated(number: number).plan.legs
        try #require(!plan.isEmpty)
        let opening: Core = try Core.opening(number: number)
        #expect(opening.play.stage == .playing)
        var result: [Case] = [make(opening)]
        var core: Core = opening
        for (index, leg) in plan.enumerated() {
            guard case let .leg(star, wait) = leg else { continue }
            #expect(core.apply(action("route.fly", [star, wait])) == .accepted)
            if index == 0 && plan.count >= 2 {
                #expect(core.play.stage == .playing)
                result.append(make(core))
            }
        }
        #expect(core.play.stage == .won)
        result.append(make(core))
        result.append(make(try failed(opening)))
        return result
    }

    /// `opening` failed by its first accepted leg (star, then wait 8 down to 0) that fails the level.
    static func failed(_ opening: Core) throws -> Core {
        let count: Int = opening.play.level.stars.count
        for star in 0..<count {
            for k in 0...8 {
                var copy: Core = opening
                if copy.apply(action("route.fly", [star, 8 - k])) == .accepted && copy.play.stage == .failed {
                    return copy
                }
            }
        }
        try #require(Bool(false), "no failing leg from the opening of level \(opening.levelNumber)")
        return opening
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
        StarlitCartouchePicker.pick(simd(p), size: simd(view), snapshot: s, orbit: orbit)
    }

    /// The wait the picker reads under `p` on the slider.
    static func wait(_ p: Vec2, _ s: Snapshot, _ view: Vec2, _ orbit: Orbit) -> Int {
        StarlitCartouchePicker.sliderWait(simd(p), size: simd(view), snapshot: s, orbit: orbit)
    }

    /// The star other than the ship's under `p`, or nil.
    static func destination(_ p: Vec2, _ s: Snapshot, _ view: Vec2, _ orbit: Orbit) -> Int? {
        if case .star(let i) = pick(p, s, view, orbit), i != s.star { return i }
        return nil
    }

    /// The projected view point of world point `w`.
    static func project(_ w: SIMD3<Double>, _ s: Snapshot, _ view: Vec2, _ orbit: Orbit) -> Vec2? {
        let camera: StarlitCartoucheCamera = G.camera(s, aspect: view.x / view.y, orbit: orbit)
        guard let p = StarlitCartouchePicker.viewPoint(w, size: simd(view), camera: camera) else { return nil }
        return vec(p)
    }

    /// A point near `centre` (its projection, else the nearest point of a 3-point grid within 18 points) that
    /// `wanted` accepts.
    static func near(_ centre: Vec2?, _ s: Snapshot, _ view: Vec2, _ orbit: Orbit,
                     _ wanted: (Pick) -> Bool) -> Vec2? {
        guard let c = centre else { return nil }
        if wanted(pick(c, s, view, orbit)) { return c }
        var best: Vec2? = nil
        var bestDistance: Double = Double.infinity
        for a in -6...6 {
            for b in -6...6 {
                let p: Vec2 = c + Vec2(Double(a) * 3, Double(b) * 3)
                let d: Double = (p - c).length
                if d < bestDistance, wanted(pick(p, s, view, orbit)) {
                    best = p
                    bestDistance = d
                }
            }
        }
        return best
    }

    /// A point that picks star `i` (`.ship` for the ship's star), or nil.
    static func starPoint(_ i: Int, _ s: Snapshot, _ view: Vec2, _ orbit: Orbit) -> Vec2? {
        let want: Pick = i == s.star ? .ship : .star(i)
        return near(project(G.starCentre(i, s), s, view, orbit), s, view, orbit) { $0 == want }
    }

    /// A point on the slider near wait pip `j`, or nil.
    static func pipPoint(_ j: Int, _ s: Snapshot, _ view: Vec2, _ orbit: Orbit) -> Vec2? {
        near(project(G.waitPip(j), s, view, orbit), s, view, orbit) { $0 == .slider }
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

    /// A seeded star (perhaps the ship's) and a point that picks it.
    static func anyStar(_ s: Snapshot, _ view: Vec2, _ orbit: Orbit,
                        _ random: inout SeededRandom) -> (star: Int, point: Vec2)? {
        let i: Int = below(s.stars.count, &random)
        guard let p = starPoint(i, s, view, orbit) else { return nil }
        return (i, p)
    }

    /// A seeded star other than the ship's, joined to it by a corridor three times in four, and a point picking it.
    static func otherStar(_ s: Snapshot, _ view: Vec2, _ orbit: Orbit,
                          _ random: inout SeededRandom) -> (star: Int, point: Vec2)? {
        var joined: [Int] = []
        for c in s.corridors where c.a == s.star || c.b == s.star { joined.append(c.a == s.star ? c.b : c.a) }
        var i: Int = below(s.stars.count, &random)
        if !joined.isEmpty && unit(&random) < 0.75 { i = joined[below(joined.count, &random)] }
        guard i != s.star, let p = starPoint(i, s, view, orbit) else { return nil }
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

    /// The presenter's side: the core every action is applied to and the destination a preview replaced.
    struct Presenter {
        var core: Core
        var saved: Int? = nil
        var accepted: Int = 0
        var refused: Int = 0

        /// The snapshot drawn now.
        var snapshot: Snapshot { core.snapshot(time: 0) }

        /// Applies gesture action `a` through the adapter and checks its effect (see the file header).
        mutating func apply(_ a: Action, run: Int) throws {
            typealias T = StarlitCartoucheGestureControllerTests
            let before: String = try T.digest(core)
            switch a {
            case let .fly(star, wait):
                let legs: Int = core.play.legs.count
                let play: StarlitCartouchePlay = core.play
                let result: ActionResult = core.apply(T.action("route.fly", [star, wait]))
                if result == .accepted {
                    accepted += 1
                    #expect(core.play.legs.count == legs + 1 || core.play.stage == .failed, "run \(run)")
                } else {
                    refused += 1
                    guard case .rejected(.rule) = result else {
                        Issue.record("fly refused outside the kernel's rules: \(result), run \(run)")
                        return
                    }
                    let after: String = try T.digest(core)
                    #expect(core.play == play && after == before, "run \(run)")
                }
                saved = nil
                return
            case .chooseDestination(let star):
                #expect(core.apply(T.action("route.choose", [star, core.chosenWait])) == .accepted, "run \(run)")
                #expect(core.chosenStar == star)
            case .chooseWait(let wait):
                #expect(core.apply(T.action("route.choose", [core.chosenStar, wait])) == .accepted, "run \(run)")
                #expect(core.chosenWait == wait)
            case .preview(let star):
                if saved == nil { saved = core.chosenStar }
                #expect(core.apply(T.action("route.choose", [star, core.chosenWait])) == .accepted, "run \(run)")
            case .clearPreview:
                if let earlier = saved {
                    #expect(core.apply(T.action("route.choose", [earlier, core.chosenWait])) == .accepted)
                    #expect(core.chosenStar == earlier)
                }
                saved = nil
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

    /// A tap that may start a double tap: on a star (its index) or on empty space (−1), its lift point and time.
    struct TapRecord {
        let target: Int
        let point: Vec2
        let time: Double
    }

    /// What a one-finger script must send and the state after touch-down.
    struct Expectation {
        var actions: [Action] = []
        var state: Controller.State = .idle
    }

    /// The expectation of one-finger `steps` (the first a `.began`, the last an `.ended` or a `.cancelled`) beginning
    /// on snapshot `s` in `view` at `orbit` after the double-tap candidate `record`, written on its own from
    /// clarifications Q1 … Q4 (the picker's contract says what lies under a point).
    static func expected(_ steps: [Step], _ s: Snapshot, _ view: Vec2, _ orbit: Orbit,
                         record: inout TapRecord?) -> Expectation {
        let origin: Vec2 = steps[0].point
        let startTime: Double = steps[0].time
        let picked: Pick = pick(origin, s, view, orbit)
        let playing: Bool = s.stage == .playing
        let over: Bool = s.stage == .won || s.stage == .failed || s.stage == .result
        var result: Expectation = Expectation()
        switch picked {
        case .star: result.state = .starPress
        case .ship: result.state = .shipPress
        case .slider: result.state = .sliderDrag
        case .empty: result.state = .emptyPress
        }
        if picked == .slider {
            var last: Int = wait(origin, s, view, orbit)
            result.actions.append(.chooseWait(last))
            for index in 1..<steps.count where steps[index].phase != .cancelled {
                let w: Int = wait(steps[index].point, s, view, orbit)
                if w != last { result.actions.append(.chooseWait(w)) }
                last = w
            }
            record = nil
            return result
        }
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
            if picked == .ship && !dragging && travel >= 16 {
                dragging = true
                if !playing {
                    result.actions.append(.explain(over ? overText : "The play is not under way"))
                }
            }
            if st.phase == .moved && dragging && playing {
                let under: Int? = destination(st.point, s, view, orbit)
                if under != pending {
                    result.actions.append(under.map { Action.preview($0) } ?? .clearPreview)
                    pending = under
                }
            }
            guard st.phase == .ended else { continue }
            let tap: Bool = !dragging && travel < 10 && st.time - startTime < 0.5
            var target: Int = -2
            if case .star(let i) = picked { target = i }
            if picked == .empty { target = -1 }
            var double: Bool = false
            if tap, target != -2, let r = record, r.target == target, st.time - r.time <= 0.35,
               (st.point - r.point).length <= 22 {
                double = true
            }
            var next: TapRecord? = nil
            if dragging && playing {
                if pending != nil { result.actions.append(.clearPreview) }
                if let t = destination(st.point, s, view, orbit) {
                    var joined: Bool = false
                    for c in s.corridors where (c.a == s.star && c.b == t) || (c.b == s.star && c.a == t) {
                        joined = true
                    }
                    result.actions.append(joined ? .fly(star: t, wait: s.chosenWait) : .explain(corridorText(t)))
                }
            } else if target >= 0 && tap {
                if !double {
                    result.actions.append(.chooseDestination(target))
                    next = TapRecord(target: target, point: st.point, time: st.time)
                } else if playing {
                    result.actions.append(.fly(star: target, wait: s.chosenWait))
                } else {
                    result.actions.append(.chooseDestination(target))
                    if over { result.actions.append(.explain(overText)) }
                }
            } else if target == -1 && tap {
                if double {
                    result.actions.append(.resetView)
                } else {
                    next = TapRecord(target: -1, point: st.point, time: st.time)
                }
            }
            record = next
        }
        return result
    }

    // MARK: Seeded scripts

    /// One seeded one-finger gesture (or two, for a double tap) of `kind` (0 … 12, 15) on `s` in `view` at `orbit`,
    /// or nil without a target.
    static func scripts(_ kind: Int, _ s: Snapshot, _ view: Vec2, _ orbit: Orbit,
                        _ random: inout SeededRandom) -> [[Step]]? {
        switch kind {
        case 0:   // a tap on a star (perhaps the ship's)
            guard let c = anyStar(s, view, orbit, &random) else { return nil }
            let q: Vec2 = c.point + Vec2(unit(&random) * 6 - 3, unit(&random) * 6 - 3)
            return [[Step(phase: .began, point: c.point, time: 1),
                     Step(phase: .ended, point: q, time: 1.05 + 0.4 * unit(&random))]]
        case 1:   // two taps on a star, sometimes too late or too far for a double tap
            guard let c = otherStar(s, view, orbit, &random) else { return nil }
            let gap: Double = 0.1 + 0.32 * unit(&random)
            let q: Vec2 = inside(c.point + Vec2(unit(&random) * 30 - 15, unit(&random) * 30 - 15), view)
            return [[Step(phase: .began, point: c.point, time: 1), Step(phase: .ended, point: c.point, time: 1.05)],
                    [Step(phase: .began, point: q, time: 1.05 + gap - 0.04),
                     Step(phase: .ended, point: q, time: 1.05 + gap)]]
        case 2:   // one or two taps on empty space
            guard let e = emptyPoint(s, view, orbit) else { return nil }
            let first: [Step] = [Step(phase: .began, point: e, time: 1), Step(phase: .ended, point: e, time: 1.05)]
            if unit(&random) < 0.3 { return [first] }
            let q: Vec2 = inside(e + Vec2(unit(&random) * 12, unit(&random) * 12), view)
            let gap: Double = 0.1 + 0.32 * unit(&random)
            return [first, [Step(phase: .began, point: q, time: 1.01 + gap),
                            Step(phase: .ended, point: q, time: 1.05 + gap)]]
        case 3:   // a slider tap, sometimes slow
            guard let p = pipPoint(below(9, &random), s, view, orbit) else { return nil }
            let lift: Double = unit(&random) < 0.3 ? 1.7 : 1.08
            return [[Step(phase: .began, point: p, time: 1), Step(phase: .ended, point: p, time: lift)]]
        case 4:   // a slider drag from one pip to another, sometimes past the slider's end or off it
            let a: Int = below(9, &random)
            let b: Int = below(9, &random)
            guard let p = pipPoint(a, s, view, orbit), var q = pipPoint(b, s, view, orbit) else { return nil }
            if unit(&random) < 0.3 { q = q + Vec2(unit(&random) * 160 - 80, unit(&random) * 120 - 60) }
            return [path(p, q, steps: 3 + below(5, &random), time: 1)]
        case 5:   // a ship drag to a star, or anywhere
            guard let ship = starPoint(s.star, s, view, orbit) else { return nil }
            var end: Vec2 = inside(ship + Vec2(unit(&random) * 300 - 150, unit(&random) * 300 - 150), view)
            if unit(&random) < 0.75, let c = otherStar(s, view, orbit, &random) { end = c.point }
            guard (end - ship).length >= 16 else { return nil }
            return [path(ship, end, steps: 3 + below(4, &random), time: 1)]
        case 6:   // a ship drag out to a star and back to the ship or to empty space
            guard let ship = starPoint(s.star, s, view, orbit), let c = otherStar(s, view, orbit, &random),
                  (c.point - ship).length >= 16 else { return nil }
            var back: Vec2 = ship + Vec2(unit(&random) * 6 - 3, unit(&random) * 6 - 3)
            if unit(&random) < 0.5, let e = emptyPoint(s, view, orbit) { back = e }
            return [outAndBack(ship, c.point, back, time: 1)]
        case 7:   // a short touch of 10 … 16 points from a star, the ship or anywhere
            var p: Vec2 = inside(Vec2(view.x * unit(&random), view.y * unit(&random)), view)
            if unit(&random) < 0.7, let c = anyStar(s, view, orbit, &random) { p = c.point }
            let a: Double = unit(&random) * 2 * Double.pi
            let length: Double = 10.5 + 5 * unit(&random)
            return [path(p, p + Vec2(cos(a) * length, sin(a) * length), steps: 2, time: 1)]
        case 8:   // a slow press (lifted 0.5 … 1.0 s after touch-down) moving under 10 points
            var start: Vec2? = anyStar(s, view, orbit, &random)?.point
            if start == nil || unit(&random) < 0.2 { start = emptyPoint(s, view, orbit) }
            guard let p = start else { return nil }
            let q: Vec2 = p + Vec2(unit(&random) * 8 - 4, unit(&random) * 8 - 4)
            return [[Step(phase: .began, point: p, time: 1), Step(phase: .moved, point: q, time: 1.2),
                     Step(phase: .ended, point: q, time: 1.5 + 0.5 * unit(&random))]]
        case 9:   // a cancelled touch on the ship, perhaps dragged to a star first
            guard let ship = starPoint(s.star, s, view, orbit) else { return nil }
            var q: Vec2 = ship
            if unit(&random) < 0.7, let c = otherStar(s, view, orbit, &random) { q = c.point }
            return [[Step(phase: .began, point: ship, time: 1), Step(phase: .moved, point: q, time: 1.1),
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
        case 11:  // a drag from a star other than the ship's, or from empty space
            var start: Vec2? = otherStar(s, view, orbit, &random)?.point
            if start == nil || unit(&random) < 0.4 { start = emptyPoint(s, view, orbit) }
            guard let p = start else { return nil }
            let a: Double = unit(&random) * 2 * Double.pi
            let length: Double = 20 + 200 * unit(&random)
            return [path(p, inside(p + Vec2(cos(a) * length, sin(a) * length), view), steps: 3, time: 1)]
        default:  // a double tap on a star (within the window and distance)
            guard let c = otherStar(s, view, orbit, &random) else { return nil }
            let q: Vec2 = c.point + Vec2(unit(&random) * 6 - 3, unit(&random) * 6 - 3)
            guard pick(q, s, view, orbit) == .star(c.star) else { return nil }
            return [[Step(phase: .began, point: c.point, time: 1), Step(phase: .ended, point: c.point, time: 1.05)],
                    [Step(phase: .began, point: q, time: 1.15), Step(phase: .ended, point: q, time: 1.2)]]
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
        if kind == 3 || kind == 4 || kind == 7 || kind == 8 || kind == 9 || kind == 11 {
            for a in produced { #expect(!isKernel(a), "kind \(kind) sent \(a), run \(run)") }
        }
        #expect(near(controller.orbit, orbit) || produced.contains(.resetView))
        return produced
    }

    /// A seeded second-finger script: the first finger on the ship (perhaps dragged to a star) or the slider, a second
    /// finger cancels (only `clearPreview` when a destination was pending) and orbits; nothing kernel is sent, nothing
    /// at all after the clearing value, and the orbit turns by half the second finger's movement.
    static func secondFinger(_ controller: inout Controller, _ presenter: inout Presenter, _ view: Vec2,
                             _ orbit: Orbit, run: Int, _ random: inout SeededRandom) throws -> [Action]? {
        let s: Snapshot = presenter.snapshot
        var start: Vec2? = starPoint(s.star, s, view, orbit)
        if unit(&random) < 0.3 { start = pipPoint(below(9, &random), s, view, orbit) }
        guard let p = start else { return nil }
        var first: Vec2 = p
        var steps: [Step] = [Step(phase: .began, point: p, time: 1)]
        if unit(&random) < 0.7, let c = otherStar(s, view, orbit, &random) {
            first = c.point
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

    /// A seeded `cancel()` in the middle of a press or a ship drag: the finger's later events send nothing.
    static func systemCancel(_ controller: inout Controller, _ presenter: inout Presenter, _ view: Vec2,
                             _ orbit: Orbit, run: Int, _ random: inout SeededRandom) throws -> [Action]? {
        let s: Snapshot = presenter.snapshot
        guard let c = anyStar(s, view, orbit, &random) else { return nil }
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
        case .chooseDestination: return "chooseDestination"
        case .chooseWait: return "chooseWait"
        case .fly: return "fly"
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
        let kinds: Int = 15
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
            if kind == 13 {
                produced = try Self.secondFinger(&controller, &presenter, view, orbit, run: run, &random)
            } else if kind == 14 {
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
            if kind == 13 || kind == 14 || kind == 9 { #expect(kernel == 0, "run \(run)") }
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
        for n in ["chooseDestination", "chooseWait", "fly", "preview", "clearPreview", "resetView", "explain"] {
            #expect((sent[n] ?? 0) > 0, "\(n) never sent: \(sent)")
        }
        #expect(stages == ["playing", "won", "failed"])
        #expect(accepted > 10, "\(accepted) legs accepted")
        #expect(finished > 100)
        for index in all.indices { #expect(try Self.digest(all[index].core) == digests[index]) }
    }

    /// A star other than the ship's joined to it, one not joined, and points picking them and the ship, at the
    /// authored orbit in `view`; nil when the level has no such pair here.
    static func targets(_ s: Snapshot, _ view: Vec2)
        -> (ship: Vec2, joined: (Int, Vec2), lone: (Int, Vec2)?)? {
        guard let ship = starPoint(s.star, s, view, .authored) else { return nil }
        var joined: (Int, Vec2)? = nil
        var lone: (Int, Vec2)? = nil
        for i in 0..<s.stars.count where i != s.star {
            guard let p = starPoint(i, s, view, .authored), (p - ship).length >= 30 else { continue }
            var linked: Bool = false
            for c in s.corridors where (c.a == s.star && c.b == i) || (c.b == s.star && c.a == i) { linked = true }
            if linked && joined == nil { joined = (i, p) }
            if !linked && lone == nil { lone = (i, p) }
        }
        guard let j = joined else { return nil }
        return (ship, j, lone)
    }

    @Test func tapsChooseDoubleTapsFlyAndThresholdsHold() throws {
        let view: Vec2 = Self.views[2]
        var checked: Int = 0
        for number in Self.levels {
            let level: [Case] = try Self.cases(number)
            for c in level {
                let s: Snapshot = c.snapshot
                guard let t = Self.targets(s, view) else { continue }
                let (star, p): (Int, Vec2) = t.joined
                var presenter: Presenter = Presenter(core: c.core)
                var controller: Controller = Controller()
                let tap1: [Step] = [Step(phase: .began, point: p, time: 1), Step(phase: .ended, point: p, time: 1.05)]
                let tap2: [Step] = [Step(phase: .began, point: p, time: 1.2), Step(phase: .ended, point: p, time: 1.25)]
                let first = try Self.run(&controller, tap1, view: view, presenter: &presenter, run: -1)
                #expect(first.state == .starPress && first.actions == [.chooseDestination(star)])
                let second: [Action] = try Self.run(&controller, tap2, view: view, presenter: &presenter,
                                                    run: -1).actions
                if s.stage == .playing {
                    #expect(second == [.fly(star: star, wait: s.chosenWait)])
                    #expect(presenter.accepted + presenter.refused == 1)
                } else {
                    #expect(second == [.chooseDestination(star), .explain(Self.overText)])
                    #expect(presenter.core.play == c.core.play)
                }
                // A tap on the ship changes nothing, twice.
                var shipController: Controller = Controller()
                var still: Presenter = Presenter(core: c.core)
                let shipTaps: [Step] = [Step(phase: .began, point: t.ship, time: 1),
                                        Step(phase: .ended, point: t.ship, time: 1.05),
                                        Step(phase: .began, point: t.ship, time: 1.1),
                                        Step(phase: .ended, point: t.ship, time: 1.15)]
                #expect(try Self.run(&shipController, shipTaps, view: view, presenter: &still, run: -1).actions
                    .isEmpty)
                checked += 1
            }
        }
        #expect(checked >= 6)
        // Thresholds: travel under 10 points, lifted before 0.5 s; 10 … 16 points do nothing; too late, too far.
        let c: Case = try Self.cases(1)[0]
        let t = try #require(Self.targets(c.snapshot, view))
        let (star, p): (Int, Vec2) = t.joined
        func play(_ steps: [Step]) -> [Action] {
            var controller: Controller = Controller()
            var actions: [Action] = []
            for st in steps {
                actions += controller.handle(Self.event(1, st.phase, st.point, st.time), viewSize: view,
                                             snapshot: c.snapshot)
            }
            return actions
        }
        func tap(_ at: Double, lift: Vec2? = nil, held: Double = 0.05, from: Vec2? = nil) -> [Step] {
            [Step(phase: .began, point: from ?? p, time: at), Step(phase: .ended, point: lift ?? from ?? p,
                                                                   time: at + held)]
        }
        #expect(play(tap(1, held: 0.49)) == [.chooseDestination(star)])
        #expect(play(tap(1, held: 0.5)).isEmpty)
        #expect(play(tap(1, lift: p + Vec2(0, 9.9))) == [.chooseDestination(star)])
        #expect(play(tap(1, lift: p + Vec2(0, 10))).isEmpty)
        #expect(play(tap(1, lift: p + Vec2(0, 15.9))).isEmpty)
        #expect(play(tap(1) + tap(1.36)) == [.chooseDestination(star), .chooseDestination(star)])
        let far: Vec2 = p + Vec2(0, 23)
        if Self.pick(far, c.snapshot, view, .authored) == .star(star) {
            #expect(play(tap(1) + tap(1.2, from: far)) == [.chooseDestination(star), .chooseDestination(star)])
        }
        // A completed double tap starts no new one.
        let third: [Action] = play(tap(1) + tap(1.2) + tap(1.4))
        #expect(third == [.chooseDestination(star), .fly(star: star, wait: c.snapshot.chosenWait),
                          .chooseDestination(star)])
        #expect(Controller.tapDistance == 10 && Controller.dragDistance == 16 && Controller.tapDuration == 0.5)
        #expect(Controller.doubleTapWindow == 0.35 && Controller.doubleTapDistance == 22)
        #expect(Controller.finishedReason == Self.overText && Controller.noCorridorReason(4) == Self.corridorText(4))
    }

    @Test func shipDragsPreviewFlyOnceOrExplain() throws {
        let view: Vec2 = Self.views[1]
        var flown: Int = 0
        var lone: Int = 0
        var over: Int = 0
        for number in Self.levels {
            for c in try Self.cases(number) {
                let s: Snapshot = c.snapshot
                guard let t = Self.targets(s, view) else { continue }
                let (star, p): (Int, Vec2) = t.joined
                var controller: Controller = Controller()
                var presenter: Presenter = Presenter(core: c.core)
                let drag: [Step] = Self.path(t.ship, p, steps: 6, time: 1)
                let got = try Self.run(&controller, drag, view: view, presenter: &presenter, run: -1)
                #expect(got.state == .shipPress)
                var kernel: Int = 0
                for a in got.actions where Self.isKernel(a) { kernel += 1 }
                if s.stage == .playing {
                    #expect(got.actions.contains(.preview(star)))
                    #expect(Array(got.actions.suffix(2)) == [.clearPreview, .fly(star: star, wait: s.chosenWait)],
                            "\(got.actions)")
                    #expect(kernel == 1)
                    flown += 1
                    // Out to the star and back to the ship: previewed, then cleared; nothing sent.
                    var back: Controller = Controller()
                    var still: Presenter = Presenter(core: c.core)
                    let none: [Action] = try Self.run(&back, Self.outAndBack(t.ship, p, t.ship, time: 1), view: view,
                                                      presenter: &still, run: -1).actions
                    #expect(!none.contains { Self.isKernel($0) } && none.last == .clearPreview, "\(none)")
                    #expect(still.core.chosenStar == c.core.chosenStar, "the earlier destination is restored")
                    if let (other, q) = t.lone {
                        var loneController: Controller = Controller()
                        var lonePresenter: Presenter = Presenter(core: c.core)
                        let words: [Action] = try Self.run(&loneController, Self.path(t.ship, q, steps: 6, time: 1),
                                                           view: view, presenter: &lonePresenter, run: -1).actions
                        #expect(words.last == .explain(Self.corridorText(other)), "\(words)")
                        #expect(!words.contains { Self.isKernel($0) })
                        lone += 1
                    }
                } else {
                    #expect(got.actions == [.explain(Self.overText)], "\(got.actions)")
                    over += 1
                }
                // 10 … 16 points from the ship: nothing.
                var short: Controller = Controller()
                var quiet: Presenter = Presenter(core: c.core)
                let shortSteps: [Step] = Self.path(t.ship, t.ship + Vec2(0, 13), steps: 2, time: 1)
                #expect(try Self.run(&short, shortSteps, view: view, presenter: &quiet, run: -1).actions.isEmpty)
            }
        }
        #expect(flown > 0 && over > 0)
        _ = lone
    }

    @Test func sliderDragsChooseEveryWaitInAnyStage() throws {
        let view: Vec2 = Self.views[0]
        for number in Self.levels {
            for c in try Self.cases(number) {
                let s: Snapshot = c.snapshot
                let p0: Vec2 = try #require(Self.pipPoint(0, s, view, .authored))
                let p8: Vec2 = try #require(Self.pipPoint(8, s, view, .authored))
                var controller: Controller = Controller()
                var presenter: Presenter = Presenter(core: c.core)
                let got = try Self.run(&controller, Self.path(p0, p8, steps: 40, time: 1), view: view,
                                       presenter: &presenter, run: -1)
                #expect(got.state == .sliderDrag)
                var want: [Action] = []
                for w in 0...8 { want.append(.chooseWait(w)) }
                #expect(got.actions == want, "level \(number) stage \(s.stage): \(got.actions)")
                #expect(presenter.core.chosenWait == 8)
                #expect(try Self.digest(presenter.core) == Self.digest(c.core))
            }
        }
    }

    @Test func secondAndThirdFingersOrbitClampedAndCameraFollows() throws {
        let c: Case = try Self.cases(1)[0]
        let s: Snapshot = c.snapshot
        let view: Vec2 = Self.views[1]
        let t = try #require(Self.targets(s, view))
        var controller: Controller = Controller()
        var actions: [Action] = controller.handle(Self.event(1, .began, t.ship, 1), viewSize: view, snapshot: s)
        actions += controller.handle(Self.event(1, .moved, t.joined.1, 1.05), viewSize: view, snapshot: s)
        #expect(controller.state == .shipDrag && actions == [.preview(t.joined.0)])
        let b: Vec2 = Vec2(700, 400)
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
        let camera: StarlitCartoucheCamera = try #require(controller.camera(viewSize: view, snapshot: s))
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
        _ = Self.twoFingers(&controller, a: Vec2(300, 400), b: Vec2(800, 400), by: Vec2(-200, 0), view: view,
                            snapshot: s, time: 3)
        #expect(controller.orbit != .authored)
        controller.resetView()
        #expect(controller.orbit == .authored)
        let authored: StarlitCartoucheCamera = try #require(controller.camera(viewSize: view, snapshot: s))
        #expect(authored == G.camera(s, aspect: view.x / view.y))
    }
}
