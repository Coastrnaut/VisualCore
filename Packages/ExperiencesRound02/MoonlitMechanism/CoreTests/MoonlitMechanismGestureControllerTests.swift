// MoonlitMechanismGestureControllerTests — feature 434 (R02-G14-04) T-R02G1404-003 (FR-R02G1404-001 … 004, 006;
// SC-R02G1404-001 … 003; clarifications Q1 … Q5). 500 seeded (SeededRandom seed 2_434) scripted gestures — taps and
// double taps on gears (the driver included), taps on key-frame cards, on the lamp and the ladder and on empty space
// (single and double), rotary gear drags (through the ±π seam and the centre's dead zone), vertical lamp and ladder
// drags, drags from cards and empty space, touches of 10 … 16 points, slow presses, cancelled touches, random touches,
// second fingers and system cancels — on certified levels 1, 50 and 100 (the opening and the moment after the certified
// set-up before the run, both playing; won by the certified run; failed by a bare run; each `snapshot(time: 0)`), at
// three view sizes and three orbits reached by two-finger drags, send exactly the actions an independent expectation
// written here predicts. What lies under the finger is the picker tests' independent pick
// (`MoonlitMechanismPickerTests.expected`, its own camera basis, projection and target places); the arbitration (tap,
// drag or nothing by travel and event timestamps; the swept angle, unwrapped here on its own, n = round(swept ÷ (2π ÷
// T)) capped at the actions left and the step direction × sign(n); the rungs round(−Δy ÷ 24); double taps within
// 0.35 s and 22 points; no kernel action outside playing) is written here too. Every kernel action is applied through
// the adapter's `apply(ExperienceAction(control:values:step:))` (turn → `handle.turn [step]` × count, lampStep →
// `lamp.step [step]` × count, reseat → `gear.reseat [g, 1]`, showFrame → `frame.show [k]`, run → `machine.run`) and
// checked: a turn moves the dragged gear by exactly n teeth, a lamp step past the range is refused with
// `r02-g14.action`. Second fingers, `.cancelled` phases, `cancel()` and finished plays send no kernel action; the
// driver's double tap sends none and raises `refusedDriverReseat`; a drag longer than the actions left is capped;
// orbit changes no digest. Plain loops and explicit types (CI type-check rule); each test well under 10 s.
import Foundation
import Testing
import VisualCoreDiagnostics
import VisualCoreExperience
import VisualCoreMath
import VisualCoreScenes
import VisualCoreSimulation
@testable import MoonlitMechanismCore

@Suite struct MoonlitMechanismGestureControllerTests {
    typealias Controller = MoonlitMechanismGestureController
    typealias Snapshot = MoonlitMechanismSceneSnapshot
    typealias Action = MoonlitMechanismGestureAction
    typealias Orbit = MoonlitMechanismOrbit
    typealias Core = MoonlitMechanismExperienceCore
    typealias Pick = MoonlitMechanismPick
    typealias Independent = MoonlitMechanismPickerTests

    /// The seed of every random choice here.
    static let seed: UInt64 = 2_434
    /// The view sizes every script runs at: phone portrait, tablet landscape, tablet portrait.
    static let views: [Vec2] = [Vec2(390, 844), Vec2(1_180, 820), Vec2(1_024, 1_366)]
    /// The scripted orbits (the first is the authored one), reached by two-finger drags.
    static let orbits: [Orbit] = [.authored, Orbit(yaw: 0.3, pitch: 0.15), Orbit(yaw: -0.4, pitch: -0.12)]
    /// The certified levels used.
    static let levels: [Int] = [1, 50, 100]
    /// The adapter's reason code for a refused action (the lamp range).
    static let actionCode: String = "r02-g14.action"

    // MARK: Cases

    /// A core (for the digest and the adapter) and the snapshot the controller sees.
    struct Case {
        let core: Core
        let snapshot: Snapshot
    }

    /// A case of `core` at presentation time 0.
    static func make(_ core: Core) -> Case { Case(core: core, snapshot: core.snapshot(time: 0)) }

    /// A panel action.
    static func action(_ control: String, _ values: [Double] = []) -> ExperienceAction {
        ExperienceAction(control: control, values: values, step: 0)
    }

    /// The adapter action of a kernel action.
    static func adapterAction(kernel a: MoonlitMechanismAction) -> ExperienceAction {
        switch a {
        case .turn(let step): return action("handle.turn", [Double(step)])
        case .reseat(let gear, let step): return action("gear.reseat", [Double(gear), Double(step)])
        case .lamp(let step): return action("lamp.step", [Double(step)])
        case .run: return action("machine.run")
        }
    }

    /// The adapter actions a gesture action sends, in order (none for presentation actions).
    static func adapterActions(_ a: Action) -> [ExperienceAction] {
        var result: [ExperienceAction] = []
        switch a {
        case let .turn(step, count):
            for _ in 0..<max(count, 0) { result.append(action("handle.turn", [Double(step)])) }
        case let .lampStep(step, count):
            for _ in 0..<max(count, 0) { result.append(action("lamp.step", [Double(step)])) }
        case .reseat(let gear):
            result.append(action("gear.reseat", [Double(gear), 1]))
        case .showFrame(let k):
            result.append(action("frame.show", [Double(k)]))
        case .run:
            result.append(action("machine.run"))
        case .chooseGear, .pendingTurn, .pendingLamp, .resetView:
            break
        }
        return result
    }

    /// Whether `a` is a kernel action (turn, lamp step, re-seat or run).
    static func isKernel(_ a: Action) -> Bool {
        switch a {
        case .turn, .lampStep, .reseat, .run: return true
        case .chooseGear, .pendingTurn, .pendingLamp, .showFrame, .resetView: return false
        }
    }

    /// The digest of `core` as the engine computes it.
    static func digest(_ core: Core) throws -> String {
        var builder: DigestBuilder = DigestBuilder(domain: Core.experienceID)
        try core.writeDigest(into: &builder)
        return builder.finish().hex
    }

    /// Certified level `number`: the opening (playing), the moment after its certified set-up before the run
    /// (playing), after the certified run (won) and the opening failed by a bare run.
    static func cases(_ number: Int) throws -> [Case] {
        let actions: [MoonlitMechanismAction] = MoonlitMechanismSolver.actions(try Core.generated(number: number).plan)
        try #require(actions.count >= 2)
        try #require(actions[actions.count - 1] == .run)
        let opening: Core = try Core.opening(number: number)
        var core: Core = opening
        var index: Int = 0
        while index < actions.count - 1 {
            #expect(core.apply(adapterAction(kernel: actions[index])) == .accepted)
            index += 1
        }
        #expect(core.play.stage == .playing)
        let placed: Case = make(core)
        #expect(core.apply(adapterAction(kernel: .run)) == .accepted)
        #expect(core.play.stage == .won)
        let won: Case = make(core)
        var failed: Core = opening
        #expect(failed.apply(adapterAction(kernel: .run)) == .accepted)
        #expect(failed.play.stage == .failed)
        return [make(opening), placed, won, make(failed)]
    }

    /// Every case of ``levels``.
    static func allCases() throws -> [Case] {
        var all: [Case] = []
        for number in levels { all += try cases(number) }
        return all
    }

    // MARK: Independent geometry

    /// `v` as SIMD.
    static func simd(_ v: Vec2) -> SIMD2<Double> { SIMD2(v.x, v.y) }
    /// `v` as a `Vec2`.
    static func vec(_ v: SIMD2<Double>) -> Vec2 { Vec2(v.x, v.y) }

    /// The independent pick of `p`.
    static func under(_ p: Vec2, _ s: Snapshot, _ view: Vec2, _ orbit: Orbit) -> Pick {
        Independent.expected(simd(p), s, simd(view), orbit)
    }

    /// The independent view point of world `w`, or nil behind the eye.
    static func screen(_ w: SIMD3<Double>, _ s: Snapshot, _ view: Vec2, _ orbit: Orbit) -> Vec2? {
        guard let p = Independent.project(w, Independent.camera(s, simd(view), orbit), simd(view)) else { return nil }
        return vec(p)
    }

    /// Gear `g`'s projected centre, independently.
    static func centre(_ g: Int, _ s: Snapshot, _ view: Vec2, _ orbit: Orbit) -> Vec2? {
        screen(Independent.gear(g, s), s, view, orbit)
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

    /// A point within 20 points of a seeded gear's projected centre.
    static func gearPoint(_ s: Snapshot, _ view: Vec2, _ orbit: Orbit, _ random: inout SeededRandom) -> Vec2? {
        guard !s.gears.isEmpty, let c = centre(below(s.gears.count, &random), s, view, orbit) else { return nil }
        let a: Double = unit(&random) * 2 * Double.pi
        let r: Double = unit(&random) * 20
        return inside(c + Vec2(cos(a) * r, sin(a) * r), view)
    }

    /// A point within 6 points of a seeded card's projected centre.
    static func cardPoint(_ s: Snapshot, _ view: Vec2, _ orbit: Orbit, _ random: inout SeededRandom) -> Vec2? {
        guard !s.keyFrames.isEmpty,
              let c = screen(Independent.card(below(s.keyFrames.count, &random), s).0, s, view, orbit) else {
            return nil
        }
        return inside(c + Vec2(unit(&random) * 12 - 6, unit(&random) * 12 - 6), view)
    }

    /// A point within 6 points of the lamp's projected centre or of a point along the ladder.
    static func lampPoint(_ s: Snapshot, _ view: Vec2, _ orbit: Orbit, _ random: inout SeededRandom) -> Vec2? {
        var world: SIMD3<Double> = Independent.lamp(s)
        if unit(&random) < 0.4 {
            let (a, b): (SIMD3<Double>, SIMD3<Double>) = Independent.ladder(s)
            world = a + (b - a) * unit(&random)
        }
        guard let c = screen(world, s, view, orbit) else { return nil }
        return inside(c + Vec2(unit(&random) * 12 - 6, unit(&random) * 12 - 6), view)
    }

    /// A point that picks nothing: the first of the view's corners (8 points in) that does.
    static func emptyPoint(_ s: Snapshot, _ view: Vec2, _ orbit: Orbit) -> Vec2? {
        let corners: [Vec2] = [Vec2(8, 8), Vec2(view.x - 8, 8), Vec2(8, view.y - 8), Vec2(view.x - 8, view.y - 8)]
        for c in corners where under(c, s, view, orbit) == .empty { return c }
        return nil
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

    /// An arc about `c` at radius `r` from angle `a0` sweeping `sweep` radians (clockwise on screen for positive) in
    /// steps of at most 0.4 rad, a sample `dip` points from the centre inserted halfway when `dip` is given, then the
    /// release at the end.
    static func arc(_ c: Vec2, r: Double, from a0: Double, sweep: Double, dip: Vec2?, time: Double) -> [Step] {
        let steps: Int = max(3, Int((abs(sweep) / 0.4).rounded(.up)))
        var result: [Step] = []
        var last: Vec2 = c
        var lastTime: Double = time
        for i in 0...steps {
            let a: Double = a0 + sweep * Double(i) / Double(steps)
            last = c + Vec2(cos(a) * r, sin(a) * r)
            lastTime = time + 0.03 * Double(i)
            result.append(Step(phase: i == 0 ? .began : .moved, point: last, time: lastTime))
            if i == steps / 2, let d = dip {
                result.append(Step(phase: .moved, point: c + d, time: lastTime + 0.01))
            }
        }
        result.append(Step(phase: .ended, point: last, time: lastTime + 0.02))
        return result
    }

    /// What a script produced: the actions and the state after touch-down.
    struct Outcome {
        var actions: [Action]
        var state: Controller.State
    }

    /// Feeds `steps` (finger 1) to `controller` for `snapshot` in `view`.
    static func run(_ controller: inout Controller, _ steps: [Step], view: Vec2, snapshot: Snapshot) -> Outcome {
        var outcome: Outcome = Outcome(actions: [], state: .idle)
        for index in steps.indices {
            let s: Step = steps[index]
            outcome.actions += controller.handle(event(1, s.phase, s.point, s.time), viewSize: view, snapshot: snapshot)
            if index == 0 { outcome.state = controller.state }
        }
        return outcome
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
    /// upward movement), clamped to yaw ±25° and pitch −10° … 15° — computed here on its own.
    static func turned(_ orbit: Orbit, by delta: Vec2, view: Vec2) -> Orbit {
        let yawLimit: Double = 25.0 * Double.pi / 180
        let yaw: Double = orbit.yaw + delta.x / view.x * (Double.pi / 2)
        let pitch: Double = orbit.pitch - delta.y / view.y * (Double.pi / 3)
        return Orbit(yaw: min(max(yaw, -yawLimit), yawLimit),
                     pitch: min(max(pitch, -10.0 * Double.pi / 180), 15.0 * Double.pi / 180))
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

    // MARK: Independent expectation

    /// A tap that may start a double tap: on a gear or on empty space (gear −1), its lift point and time.
    struct TapRecord {
        let gear: Int
        let point: Vec2
        let time: Double
    }

    /// What a one-finger script must send, the state after touch-down, the gear drag's teeth and whether the driver's
    /// double tap was refused.
    struct Expectation {
        var actions: [Action] = []
        var state: Controller.State = .idle
        var teeth: Int? = nil
        var driverRefused: Bool = false
    }

    /// `delta` brought into −π … π, written here on its own.
    static func wrap(_ delta: Double) -> Double {
        var d: Double = delta
        while d > Double.pi { d -= 2 * Double.pi }
        while d < -Double.pi { d += 2 * Double.pi }
        return d
    }

    /// Rounds half away from zero, bounded.
    static func whole(_ x: Double) -> Int {
        let r: Double = x < 0 ? -((-x + 0.5).rounded(.down)) : (x + 0.5).rounded(.down)
        return Int(min(max(r, -1_000_000), 1_000_000))
    }

    /// The expectation of one-finger `steps` (the first a `.began`, the last an `.ended` or a `.cancelled`) on `s` in
    /// `view` at `orbit` after the double-tap candidate `record`, written on its own from clarifications Q1 … Q4.
    static func expected(_ steps: [Step], _ s: Snapshot, _ view: Vec2, _ orbit: Orbit,
                         record: inout TapRecord?) -> Expectation {
        let origin: Vec2 = steps[0].point
        let startTime: Double = steps[0].time
        let picked: Pick = under(origin, s, view, orbit)
        let playing: Bool = s.stage == .playing
        var result: Expectation = Expectation()
        var gear: Int = -1
        var pivot: Vec2? = nil
        var lampLike: Bool = false
        switch picked {
        case .gear(let g):
            result.state = .gearPress
            gear = g
            pivot = centre(g, s, view, orbit)
        case .lamp, .ladder:
            result.state = .lampPress
            lampLike = true
        case .card:
            result.state = .cardPress
        case .empty:
            result.state = .emptyPress
        }
        var travel: Double = 0
        var dragging: Bool = false
        var swept: Double = 0
        var lastAngle: Double? = nil
        func sweep(_ p: Vec2) {
            guard let c = pivot, (p - c).length > 12 else { return }
            let a: Double = atan2(p.y - c.y, p.x - c.x)
            if let b = lastAngle { swept += wrap(a - b) }
            lastAngle = a
        }
        func teeth() -> Int {
            let t: Int = s.gears[gear].teeth
            let n: Int = whole(swept / (2 * Double.pi / Double(t)))
            return min(max(n, -s.actionsLeft), s.actionsLeft)
        }
        sweep(origin)
        for index in 1..<steps.count {
            let st: Step = steps[index]
            if st.phase == .cancelled {
                if dragging && playing && gear >= 0 { result.actions.append(.pendingTurn(gear: gear, teeth: 0)) }
                if dragging && playing && lampLike { result.actions.append(.pendingLamp(steps: 0)) }
                record = nil
                break
            }
            travel = max(travel, (st.point - origin).length)
            sweep(st.point)
            if !dragging && travel >= 16 && (gear >= 0 || lampLike) { dragging = true }
            let rungs: Int = whole(-(st.point.y - origin.y) / 24)
            if st.phase == .moved && dragging && playing {
                if gear >= 0 { result.actions.append(.pendingTurn(gear: gear, teeth: teeth())) }
                if lampLike { result.actions.append(.pendingLamp(steps: rungs)) }
            }
            guard st.phase == .ended else { continue }
            let tap: Bool = !dragging && travel < 10 && st.time - startTime < 0.5
            var double: Bool = false
            if tap, let r = record, r.gear == gear, st.time - r.time <= 0.35, (st.point - r.point).length <= 22,
               gear >= 0 || picked == .empty {
                double = true
            }
            var nextRecord: TapRecord? = nil
            switch picked {
            case .gear(let g):
                if dragging {
                    if playing {
                        result.actions.append(.pendingTurn(gear: g, teeth: 0))
                        let n: Int = teeth()
                        result.teeth = n
                        let direction: Int = MoonlitMechanismTrain.direction(s.gears, g)
                        if n != 0 { result.actions.append(.turn(step: direction * (n > 0 ? 1 : -1), count: abs(n))) }
                    }
                } else if tap && double {
                    if playing && g != 0 { result.actions.append(.reseat(gear: g)) }
                    if playing && g == 0 { result.driverRefused = true }
                    result.actions.append(.chooseGear(g))
                } else if tap {
                    result.actions.append(.chooseGear(g))
                    nextRecord = TapRecord(gear: g, point: st.point, time: st.time)
                }
            case .lamp, .ladder:
                if dragging {
                    if playing {
                        result.actions.append(.pendingLamp(steps: 0))
                        if rungs != 0 { result.actions.append(.lampStep(step: rungs > 0 ? 1 : -1, count: abs(rungs))) }
                    }
                } else if tap && playing && picked == .lamp {
                    result.actions.append(.run)
                }
            case .card(let k):
                if tap { result.actions.append(.showFrame(k)) }
            case .empty:
                if tap && double {
                    result.actions.append(.resetView)
                } else if tap {
                    nextRecord = TapRecord(gear: -1, point: st.point, time: st.time)
                }
            }
            record = nextRecord
        }
        return result
    }

    // MARK: Seeded scripts

    /// One seeded one-finger gesture (or two, for a double tap) of `kind` (0 … 10, 13) on `s` in `view` at `orbit`,
    /// or nil without a target.
    static func scripts(_ kind: Int, _ s: Snapshot, _ view: Vec2, _ orbit: Orbit,
                        _ random: inout SeededRandom) -> [[Step]]? {
        switch kind {
        case 0:   // a tap on a gear
            guard let p = gearPoint(s, view, orbit, &random) else { return nil }
            let q: Vec2 = p + Vec2(unit(&random) * 6 - 3, unit(&random) * 6 - 3)
            let lift: Double = 1.05 + 0.4 * unit(&random)
            return [[Step(phase: .began, point: p, time: 1), Step(phase: .ended, point: q, time: lift)]]
        case 1:   // two taps on a gear, sometimes too late or too far for a double tap
            guard let p = gearPoint(s, view, orbit, &random) else { return nil }
            let gap: Double = 0.1 + 0.32 * unit(&random)
            let q: Vec2 = inside(p + Vec2(unit(&random) * 28 - 14, unit(&random) * 28 - 14), view)
            return [[Step(phase: .began, point: p, time: 1), Step(phase: .ended, point: p, time: 1.05)],
                    [Step(phase: .began, point: q, time: 1.05 + gap - 0.04),
                     Step(phase: .ended, point: q, time: 1.05 + gap)]]
        case 2:   // a tap on a card
            guard let p = cardPoint(s, view, orbit, &random) else { return nil }
            return [[Step(phase: .began, point: p, time: 1), Step(phase: .ended, point: p, time: 1.1)]]
        case 3:   // a tap on the lamp or the ladder
            guard let p = lampPoint(s, view, orbit, &random) else { return nil }
            return [[Step(phase: .began, point: p, time: 1), Step(phase: .ended, point: p, time: 1.1)]]
        case 4:   // one or two taps on empty space
            guard let e = emptyPoint(s, view, orbit) else { return nil }
            let first: [Step] = [Step(phase: .began, point: e, time: 1), Step(phase: .ended, point: e, time: 1.05)]
            if unit(&random) < 0.3 { return [first] }
            let q: Vec2 = inside(e + Vec2(unit(&random) * 12, unit(&random) * 12), view)
            let gap: Double = 0.1 + 0.32 * unit(&random)
            return [first, [Step(phase: .began, point: q, time: 1.01 + gap),
                            Step(phase: .ended, point: q, time: 1.05 + gap)]]
        case 5:   // a rotary drag from a gear
            guard !s.gears.isEmpty else { return nil }
            let g: Int = below(s.gears.count, &random)
            guard let c = centre(g, s, view, orbit) else { return nil }
            let r: Double = 16 + 30 * unit(&random)
            let a0: Double = unit(&random) * 2 * Double.pi - Double.pi
            let sweep: Double = (unit(&random) * 2 - 1) * 2.5 * Double.pi
            var dip: Vec2? = nil
            if unit(&random) < 0.25 { dip = Vec2(unit(&random) * 16 - 8, unit(&random) * 16 - 8) }
            return [arc(c, r: r, from: a0, sweep: sweep, dip: dip, time: 1)]
        case 6:   // a vertical drag from the lamp or the ladder
            guard let p = lampPoint(s, view, orbit, &random) else { return nil }
            let dy: Double = (unit(&random) * 2 - 1) * 150
            return [path(p, p + Vec2(unit(&random) * 10 - 5, dy), steps: 2 + below(5, &random), time: 1)]
        case 7:   // a drag from a card or empty space
            var start: Vec2? = unit(&random) < 0.5 ? cardPoint(s, view, orbit, &random) : nil
            if start == nil { start = emptyPoint(s, view, orbit) }
            guard let p = start else { return nil }
            let a: Double = unit(&random) * 2 * Double.pi
            let length: Double = 20 + 200 * unit(&random)
            return [path(p, p + Vec2(cos(a) * length, sin(a) * length), steps: 3, time: 1)]
        case 8:   // a short touch of 10 … 16 points from a gear, a card, the lamp or anywhere
            var p: Vec2 = inside(Vec2(view.x * unit(&random), view.y * unit(&random)), view)
            let choice: Int = below(4, &random)
            if choice == 0, let g = gearPoint(s, view, orbit, &random) { p = g }
            if choice == 1, let c = cardPoint(s, view, orbit, &random) { p = c }
            if choice == 2, let l = lampPoint(s, view, orbit, &random) { p = l }
            let a: Double = unit(&random) * 2 * Double.pi
            let length: Double = 10.5 + 5 * unit(&random)
            return [path(p, p + Vec2(cos(a) * length, sin(a) * length), steps: 2, time: 1)]
        case 9:   // a slow press (lifted 0.5 … 1.0 s after touch-down) moving under 10 points
            var start: Vec2? = unit(&random) < 0.5 ? gearPoint(s, view, orbit, &random)
                : lampPoint(s, view, orbit, &random)
            if start == nil { start = emptyPoint(s, view, orbit) }
            guard let p = start else { return nil }
            let q: Vec2 = p + Vec2(unit(&random) * 8 - 4, unit(&random) * 8 - 4)
            return [[Step(phase: .began, point: p, time: 1), Step(phase: .moved, point: q, time: 1.2),
                     Step(phase: .ended, point: q, time: 1.5 + 0.5 * unit(&random))]]
        case 10:  // a cancelled touch on a gear or the lamp, perhaps dragged first
            var start: Vec2? = unit(&random) < 0.5 ? lampPoint(s, view, orbit, &random) : nil
            if start == nil { start = gearPoint(s, view, orbit, &random) }
            guard let p = start else { return nil }
            let q: Vec2 = unit(&random) < 0.4 ? p : p + Vec2(unit(&random) * 60 - 30, -20 - 60 * unit(&random))
            return [[Step(phase: .began, point: p, time: 1), Step(phase: .moved, point: q, time: 1.1),
                     Step(phase: .cancelled, point: q, time: 1.2)]]
        default:  // a random touch, sometimes slow
            let p: Vec2 = inside(Vec2(view.x * unit(&random), view.y * unit(&random)), view)
            let q: Vec2 = p + Vec2(unit(&random) * 60 - 30, unit(&random) * 60 - 30)
            let slow: Double = unit(&random) < 0.3 ? 0.6 : 0
            var steps: [Step] = []
            for st in path(p, q, steps: 2, time: 1) {
                let time: Double = st.phase == .began ? st.time : st.time + slow
                steps.append(Step(phase: st.phase, point: st.point, time: time))
            }
            return [steps]
        }
    }

    /// The result of a checked seeded script: the actions sent and, for a gear drag, the dragged gear and its teeth.
    struct Produced {
        var actions: [Action] = []
        var dragged: (gear: Int, teeth: Int)? = nil
    }

    /// A seeded one-finger script of `kind` checked against its expectation; nil when it has no target here.
    static func oneFinger(_ kind: Int, _ controller: inout Controller, _ s: Snapshot, _ view: Vec2, _ orbit: Orbit,
                          run: Int, _ random: inout SeededRandom) -> Produced? {
        guard let gestures = scripts(kind, s, view, orbit, &random) else { return nil }
        var record: TapRecord? = nil
        var produced: Produced = Produced()
        for g in gestures {
            let got: Outcome = self.run(&controller, g, view: view, snapshot: s)
            let want: Expectation = expected(g, s, view, orbit, record: &record)
            #expect(got.actions == want.actions, "run \(run) kind \(kind)")
            #expect(got.state == want.state, "run \(run) kind \(kind)")
            #expect(controller.refusedDriverReseat == want.driverRefused, "run \(run) kind \(kind)")
            #expect(controller.state == .idle)
            produced.actions += got.actions
            if let n = want.teeth, case .gear(let gear) = under(g[0].point, s, view, orbit) {
                produced.dragged = (gear, n)
            }
        }
        if kind == 10 || kind == 8 || kind == 9 {
            for a in produced.actions { #expect(!isKernel(a), "kind \(kind) sent \(a), run \(run)") }
        }
        if kind == 7 { #expect(produced.actions.isEmpty, "a drag from a card or empty space, run \(run)") }
        #expect(near(controller.orbit, orbit) || produced.actions.contains(.resetView))
        return produced
    }

    /// A seeded second-finger script: the first finger on a gear or the lamp (perhaps dragged first), a second finger
    /// cancels (only the clearing pending value of a playing drag) and orbits; nothing kernel is sent, nothing at all
    /// after the clearing value, and the orbit turns by half the second finger's movement.
    static func secondFinger(_ controller: inout Controller, _ s: Snapshot, _ view: Vec2, _ orbit: Orbit, run: Int,
                             _ random: inout SeededRandom) -> Produced? {
        var start: Vec2? = unit(&random) < 0.35 ? lampPoint(s, view, orbit, &random) : nil
        if start == nil { start = gearPoint(s, view, orbit, &random) }
        guard let p = start else { return nil }
        let picked: Pick = under(p, s, view, orbit)
        var before: [Action] = controller.handle(event(1, .began, p, 1), viewSize: view, snapshot: s)
        var first: Vec2 = p
        var dragged: Bool = false
        if unit(&random) < 0.5 {
            first = p + Vec2(5, -60)
            before += controller.handle(event(1, .moved, first, 1.05), viewSize: view, snapshot: s)
            dragged = true
        }
        for a in before { #expect(!isKernel(a), "second finger run \(run)") }
        let q: Vec2 = Vec2(view.x / 2, view.y / 2)
        let clearing: [Action] = controller.handle(event(2, .began, q, 1.2), viewSize: view, snapshot: s)
        var want: [Action] = []
        if dragged && s.stage == .playing {
            if case .gear(let g) = picked { want = [.pendingTurn(gear: g, teeth: 0)] }
            if picked == .lamp || picked == .ladder { want = [.pendingLamp(steps: 0)] }
        }
        #expect(clearing == want, "second finger run \(run)")
        #expect(controller.state == .orbiting, "second finger run \(run)")
        let move: Vec2 = Vec2((unit(&random) - 0.5) * view.x * 0.6, (unit(&random) - 0.5) * view.y * 0.6)
        var actions: [Action] = controller.handle(event(2, .moved, q + move, 1.25), viewSize: view, snapshot: s)
        actions += controller.handle(event(1, .ended, first, 1.3), viewSize: view, snapshot: s)
        #expect(controller.state == .cancelled)
        actions += controller.handle(event(2, .ended, q + move, 1.35), viewSize: view, snapshot: s)
        #expect(controller.state == .idle)
        #expect(actions.isEmpty, "second finger run \(run)")
        #expect(near(controller.orbit, turned(orbit, by: move * 0.5, view: view)), "second finger run \(run)")
        return Produced(actions: before + clearing + actions)
    }

    /// A seeded `cancel()` in the middle of a press or a drag: the finger's later events send nothing.
    static func systemCancel(_ controller: inout Controller, _ s: Snapshot, _ view: Vec2, _ orbit: Orbit, run: Int,
                             _ random: inout SeededRandom) -> Produced? {
        guard let p = gearPoint(s, view, orbit, &random) else { return nil }
        let q: Vec2 = unit(&random) < 0.5 ? p : p + Vec2(40, -30)
        var actions: [Action] = controller.handle(event(1, .began, p, 1), viewSize: view, snapshot: s)
        actions += controller.handle(event(1, .moved, q, 1.05), viewSize: view, snapshot: s)
        for a in actions { #expect(!isKernel(a), "system cancel run \(run)") }
        controller.cancel()
        #expect(controller.state == .idle)
        let after: [Action] = controller.handle(event(1, .ended, q, 1.1), viewSize: view, snapshot: s)
        #expect(after.isEmpty, "system cancel run \(run)")
        #expect(near(controller.orbit, orbit))
        return Produced(actions: actions + after)
    }

    /// The name of an action's case.
    static func name(_ a: Action) -> String {
        switch a {
        case .chooseGear: return "chooseGear"
        case .pendingTurn: return "pendingTurn"
        case .turn: return "turn"
        case .pendingLamp: return "pendingLamp"
        case .lampStep: return "lampStep"
        case .reseat: return "reseat"
        case .showFrame: return "showFrame"
        case .run: return "run"
        case .resetView: return "resetView"
        }
    }

    /// Applies gesture action `a` to `core` through the adapter and checks every result and effect (a turn moves
    /// `dragged`'s gear by its teeth; lamp steps past the range are refused with ``actionCode``); returns the number of
    /// adapter actions accepted.
    static func apply(_ a: Action, to core: inout Core, dragged: (gear: Int, teeth: Int)?, run: Int) throws -> Int {
        var accepted: Int = 0
        let before: MoonlitMechanismPlay = core.play
        let digestBefore: String = try digest(core)
        for adapter in adapterActions(a) {
            let prior: MoonlitMechanismPlay = core.play
            let result: ActionResult = core.apply(adapter)
            if case .lampStep(let step, _) = a {
                let next: Int = prior.height + step
                if prior.stage != .playing {
                    #expect(result != .accepted, "a lamp step after the play ended, run \(run)")
                } else if next < 0 || next >= prior.level.lampHeights {
                    #expect(result == .rejected(.rule(code: actionCode)), "lamp step past the range: \(result)")
                    #expect(core.play == prior)
                } else {
                    #expect(result == .accepted, "lamp step refused: \(result), run \(run)")
                    #expect(core.play.height == next)
                }
            } else {
                #expect(result == .accepted, "adapter refused \(a): \(result), run \(run)")
            }
            if result == .accepted { accepted += 1 }
        }
        switch a {
        case let .turn(step, count):
            #expect(core.play.phases == MoonlitMechanismTrain.turned(before.level.gears, phases: before.phases,
                                                                     by: step * count))
            if let d = dragged {
                let t: Int = before.level.gears[d.gear].teeth
                #expect(core.play.phases[d.gear] == MoonlitMechanismTrain.mod(before.phases[d.gear] + d.teeth, t),
                        "the dragged gear did not follow the finger, run \(run)")
                #expect(abs(d.teeth) == count)
            }
        case .reseat(let g):
            #expect(core.play.phases[g] == MoonlitMechanismTrain.mod(before.phases[g] + 1, before.level.gears[g].teeth))
        case .run:
            #expect(core.play.stage == .won || core.play.stage == .failed)
        case .showFrame(let k):
            #expect(core.shownFrame == k)
            #expect(try digest(core) == digestBefore)
        default:
            break
        }
        return accepted
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
        var turned: Int = 0
        while run < 500 && attempts < 5_000 {
            attempts += 1
            let c: Case = all[Self.below(all.count, &random)]
            let view: Vec2 = Self.views[Self.below(Self.views.count, &random)]
            let nominal: Orbit = Self.orbits[Self.below(Self.orbits.count, &random)]
            let drawn: Snapshot = c.snapshot
            var controller: Controller = Self.controller(at: nominal, view: view, snapshot: drawn)
            let orbit: Orbit = controller.orbit
            let kind: Int = Self.below(kinds, &random)
            var produced: Produced?
            if kind == 11 {
                produced = Self.secondFinger(&controller, drawn, view, orbit, run: run, &random)
            } else if kind == 12 {
                produced = Self.systemCancel(&controller, drawn, view, orbit, run: run, &random)
            } else {
                produced = Self.oneFinger(kind, &controller, drawn, view, orbit, run: run, &random)
            }
            guard let result = produced else { continue }
            var kernel: Int = 0
            var copy: Core = c.core
            for a in result.actions {
                sent[Self.name(a), default: 0] += 1
                if Self.isKernel(a) {
                    kernel += 1
                    #expect(drawn.stage == .playing, "a kernel action outside playing, run \(run)")
                }
                accepted += try Self.apply(a, to: &copy, dragged: result.dragged, run: run)
            }
            #expect(kernel <= 1, "run \(run)")
            if kind == 11 || kind == 12 || kind == 10 { #expect(kernel == 0, "run \(run)") }
            if drawn.stage != .playing {
                finished += 1
                for a in result.actions { #expect(!Self.isKernel(a), "run \(run)") }
            }
            if let d = result.dragged, abs(d.teeth) > 0 { turned += 1 }
            counts[kind] += 1
            run += 1
        }
        #expect(run == 500)
        for k in 0..<kinds { #expect(counts[k] > 0, "script kind \(k) never ran") }
        for n in ["chooseGear", "pendingTurn", "turn", "pendingLamp", "lampStep", "reseat", "showFrame", "run",
                  "resetView"] {
            #expect((sent[n] ?? 0) > 0, "\(n) never sent: \(sent)")
        }
        #expect(accepted > 50)
        #expect(finished > 100)
        #expect(turned > 5)
        for index in all.indices { #expect(try Self.digest(all[index].core) == digests[index]) }
    }

    /// A point that picks gear `g` of `s` in `view` at the authored orbit (its centre, or the nearest such point of a
    /// 4-point grid within 40 points), or nil.
    static func pointOn(gear g: Int, _ s: Snapshot, _ view: Vec2) -> Vec2? {
        guard let c = centre(g, s, view, .authored) else { return nil }
        if under(c, s, view, .authored) == .gear(g) { return c }
        var best: Vec2? = nil
        var bestDistance: Double = Double.infinity
        for i in -10...10 {
            for j in -10...10 {
                let p: Vec2 = c + Vec2(Double(i) * 4, Double(j) * 4)
                let d: Double = (p - c).length
                if d < bestDistance, under(p, s, view, .authored) == .gear(g) {
                    best = p
                    bestDistance = d
                }
            }
        }
        return best
    }

    /// A tap at `p` from `time`.
    static func tap(_ p: Vec2, at time: Double, lift: Vec2? = nil, held: Double = 0.05) -> [Step] {
        [Step(phase: .began, point: p, time: time), Step(phase: .ended, point: lift ?? p, time: time + held)]
    }

    @Test func tapsDoubleTapsAndTheDriver() throws {
        let view: Vec2 = Self.views[2]
        var driverChecked: Bool = false
        var reseatChecked: Bool = false
        for number in Self.levels {
            let level: [Case] = try Self.cases(number)
            let c: Case = level[0]
            let s: Snapshot = c.snapshot
            for g in s.gears.indices {
                guard let p = Self.pointOn(gear: g, s, view) else { continue }
                var controller: Controller = Controller()
                let first: Outcome = Self.run(&controller, Self.tap(p, at: 1), view: view, snapshot: s)
                #expect(first.actions == [.chooseGear(g)])
                #expect(first.state == .gearPress)
                let second: [Action] = Self.run(&controller, Self.tap(p, at: 1.25), view: view, snapshot: s).actions
                if g == 0 {
                    #expect(second == [.chooseGear(0)], "the driver's double tap sends nothing")
                    #expect(controller.refusedDriverReseat)
                    _ = controller.handle(Self.event(1, .began, p, 2), viewSize: view, snapshot: s)
                    #expect(!controller.refusedDriverReseat)
                    driverChecked = true
                } else {
                    #expect(second == [.reseat(gear: g), .chooseGear(g)])
                    #expect(!controller.refusedDriverReseat)
                    var core: Core = c.core
                    #expect(try Self.apply(.reseat(gear: g), to: &core, dragged: nil, run: -1) == 1)
                    reseatChecked = true
                    // A completed double tap starts no new one.
                    #expect(Self.run(&controller, Self.tap(p, at: 1.4), view: view, snapshot: s).actions
                        == [.chooseGear(g)])
                }
                // Too late (0.36 s between the lifts): two single taps.
                var late: Controller = Controller()
                _ = Self.run(&late, Self.tap(p, at: 1), view: view, snapshot: s)
                #expect(Self.run(&late, Self.tap(p, at: 1.36), view: view, snapshot: s).actions == [.chooseGear(g)])
                #expect(!late.refusedDriverReseat)
                // Too far (23 points between the lifts) when that point still picks the gear.
                let far: Vec2 = p + Vec2(23, 0)
                if Self.under(far, s, view, .authored) == .gear(g) {
                    var apart: Controller = Controller()
                    _ = Self.run(&apart, Self.tap(p, at: 1), view: view, snapshot: s)
                    #expect(Self.run(&apart, Self.tap(far, at: 1.2), view: view, snapshot: s).actions
                        == [.chooseGear(g)])
                }
                // On the won and failed plays a double tap only chooses.
                for finished in [level[2], level[3]] {
                    guard let q = Self.pointOn(gear: g, finished.snapshot, view) else { continue }
                    var done: Controller = Controller()
                    let fs: Snapshot = finished.snapshot
                    var got: [Action] = Self.run(&done, Self.tap(q, at: 1), view: view, snapshot: fs).actions
                    got += Self.run(&done, Self.tap(q, at: 1.2), view: view, snapshot: fs).actions
                    #expect(got == [.chooseGear(g), .chooseGear(g)])
                    #expect(!done.refusedDriverReseat)
                }
            }
        }
        #expect(driverChecked, "a driver double tap was checked")
        #expect(reseatChecked)
        // Tap thresholds: travel under 10 points, lifted before 0.5 s; 10 … 16 points do nothing.
        let s: Snapshot = try Self.cases(1)[0].snapshot
        let g: Int = s.gears.count - 1
        let p: Vec2 = try #require(Self.pointOn(gear: g, s, view))
        func play(_ steps: [Step]) -> [Action] {
            var controller: Controller = Controller()
            return Self.run(&controller, steps, view: view, snapshot: s).actions
        }
        #expect(play(Self.tap(p, at: 1, held: 0.49)) == [.chooseGear(g)])
        #expect(play(Self.tap(p, at: 1, held: 0.5)).isEmpty)
        #expect(play(Self.tap(p, at: 1, lift: p + Vec2(0, 9.9))) == [.chooseGear(g)])
        #expect(play(Self.tap(p, at: 1, lift: p + Vec2(0, 10))).isEmpty)
        #expect(play(Self.tap(p, at: 1, lift: p + Vec2(0, 15.9))).isEmpty)
        #expect(Controller.tapDistance == 10 && Controller.dragDistance == 16 && Controller.tapDuration == 0.5)
        #expect(Controller.doubleTapWindow == 0.35 && Controller.doubleTapDistance == 22)
        #expect(Controller.centreDeadZone == 12 && Controller.lampRungDistance == 24)
    }

    @Test func gearDragsTurnTheWayTheFingerWentAcrossTheSeam() throws {
        let view: Vec2 = Self.views[2]
        var senses: Set<Int> = []
        var checked: Int = 0
        for number in Self.levels {
            let c: Case = try Self.cases(number)[1]
            let s: Snapshot = c.snapshot
            for g in s.gears.indices {
                guard let centre = Self.centre(g, s, view, .authored) else { continue }
                let teeth: Int = s.gears[g].teeth
                let tooth: Double = 2 * Double.pi / Double(teeth)
                // Start left of the centre (angle π − 0.3) so the sweep crosses the ±π seam either way.
                var radius: Double? = nil
                for r in [20.0, 26.0, 32.0, 40.0] {
                    let start: Vec2 = centre + Vec2(cos(Double.pi - 0.3) * r, sin(Double.pi - 0.3) * r)
                    if radius == nil, Self.under(start, s, view, .authored) == .gear(g) { radius = r }
                }
                guard let r = radius else { continue }
                let sense: Int = MoonlitMechanismTrain.direction(s.gears, g)
                senses.insert(sense)
                for signed in [2, -2] {
                    // Clockwise (+2 teeth) and anticlockwise (−2 teeth) by 2 teeth plus a little.
                    let sweep: Double = Double(signed) * tooth + (signed > 0 ? 0.2 : -0.2) * tooth
                    let steps: [Step] = Self.arc(centre, r: r, from: Double.pi - 0.3, sweep: sweep, dip: nil, time: 1)
                    var controller: Controller = Controller()
                    let got: [Action] = Self.run(&controller, steps, view: view, snapshot: s).actions
                    let n: Int = min(max(signed, -s.actionsLeft), s.actionsLeft)
                    #expect(Array(got.suffix(2)) == [.pendingTurn(gear: g, teeth: 0),
                                                     .turn(step: sense * (signed > 0 ? 1 : -1), count: abs(n))],
                            "level \(number) gear \(g) \(signed): \(got.suffix(2))")
                    var record: TapRecord? = nil
                    #expect(got == Self.expected(steps, s, view, .authored, record: &record).actions)
                    var core: Core = c.core
                    _ = try Self.apply(.turn(step: sense * (signed > 0 ? 1 : -1), count: abs(n)), to: &core,
                                       dragged: (g, n), run: -1)
                    checked += 1
                }
                // Less than half a tooth sends nothing but the cleared preview.
                let small: [Step] = Self.arc(centre, r: max(r, 30), from: Double.pi - 0.3, sweep: 0.45 * tooth,
                                             dip: nil, time: 1)
                if Self.under(small[0].point, s, view, .authored) == .gear(g) {
                    var controller: Controller = Controller()
                    let got: [Action] = Self.run(&controller, small, view: view, snapshot: s).actions
                    for a in got { #expect(!Self.isKernel(a)) }
                }
            }
        }
        #expect(checked >= 4)
        #expect(senses == [1, -1], "gears turning both ways were dragged")
        #expect(abs(Controller.unwrapped(3 * Double.pi / 2) + Double.pi / 2) < 1e-12)
        #expect(abs(Controller.unwrapped(-3 * Double.pi / 2) - Double.pi / 2) < 1e-12)
    }

    @Test func theCentreDeadZoneAndTheCapAtTheActionsLeft() throws {
        let view: Vec2 = Self.views[2]
        let opening: Case = try Self.cases(1)[0]
        let s0: Snapshot = opening.snapshot
        var found: (gear: Int, centre: Vec2, radius: Double)? = nil
        for g in s0.gears.indices where found == nil {
            guard let c = Self.centre(g, s0, view, .authored) else { continue }
            for r in [30.0, 36.0] where found == nil {
                if Self.under(c + Vec2(r, 0), s0, view, .authored) == .gear(g) { found = (g, c, r) }
            }
        }
        let hit = try #require(found)
        let teeth: Int = s0.gears[hit.gear].teeth
        // Through the centre: a sample 5.7 points up-left of the pivot is skipped, so the sweep is the turn from angle
        // 0 to π/2 + 0.15, not 0 → −3π/4 → π/2 + 0.15 (which would unwrap to −3π/2 + 0.15).
        let end: Double = Double.pi / 2 + 0.15
        let endPoint: Vec2 = hit.centre + Vec2(cos(end) * hit.radius, sin(end) * hit.radius)
        let through: [Step] = [Step(phase: .began, point: hit.centre + Vec2(hit.radius, 0), time: 1),
                               Step(phase: .moved, point: hit.centre + Vec2(-4, -4), time: 1.05),
                               Step(phase: .moved, point: endPoint, time: 1.1),
                               Step(phase: .ended, point: endPoint, time: 1.12)]
        var a: Controller = Controller()
        let got: [Action] = Self.run(&a, through, view: view, snapshot: s0).actions
        let quarter: Int = min(Self.whole(end / (2 * Double.pi / Double(teeth))), s0.actionsLeft)
        #expect(got.contains(.pendingTurn(gear: hit.gear, teeth: quarter)), "\(got)")
        var record: TapRecord? = nil
        #expect(got == Self.expected(through, s0, view, .authored, record: &record).actions)
        // The cap: with 2 actions left, a drag of several teeth sends 2 turns.
        var core: Core = opening.core
        var flip: Int = 1
        while core.play.actionsLeft > 2 {
            #expect(core.apply(Self.action("handle.turn", [Double(flip)])) == .accepted)
            flip = -flip
        }
        #expect(core.play.stage == .playing && core.play.actionsLeft == 2)
        let low: Snapshot = core.snapshot(time: 0)
        let c: Vec2 = try #require(Self.centre(hit.gear, low, view, .authored))
        let tooth: Double = 2 * Double.pi / Double(teeth)
        let long: [Step] = Self.arc(c, r: hit.radius, from: 0, sweep: 5.1 * tooth, dip: nil, time: 1)
        try #require(Self.under(long[0].point, low, view, .authored) == .gear(hit.gear))
        var b: Controller = Controller()
        let capped: [Action] = Self.run(&b, long, view: view, snapshot: low).actions
        let sense: Int = MoonlitMechanismTrain.direction(low.gears, hit.gear)
        #expect(capped.last == .turn(step: sense, count: 2))
        for x in capped {
            if case .pendingTurn(_, let n) = x { #expect(abs(n) <= 2) }
        }
        #expect(try Self.apply(.turn(step: sense, count: 2), to: &core, dragged: (hit.gear, 2), run: -1) == 2)
        #expect(core.play.stage == .failed, "the last action of the budget without a win fails")
    }

    @Test func lampDragsCountRungsAndStopAtTheEnds() throws {
        let view: Vec2 = Self.views[0]
        var checked: Int = 0
        for number in Self.levels {
            let level: [Case] = try Self.cases(number)
            let c: Case = level[0]
            let s: Snapshot = c.snapshot
            let lamp: Vec2 = try #require(Self.screen(Independent.lamp(s), s, view, .authored))
            try #require(Self.under(lamp, s, view, .authored) == .lamp)
            for dy in [-48.0, -11.0, 37.0, -24.0 * Double(s.lampHeights + 2)] {
                let steps: [Step] = Self.path(lamp, lamp + Vec2(14, dy), steps: 4, time: 1)
                var controller: Controller = Controller()
                let got: Outcome = Self.run(&controller, steps, view: view, snapshot: s)
                var record: TapRecord? = nil
                #expect(got.actions == Self.expected(steps, s, view, .authored, record: &record).actions)
                let rungs: Int = Self.whole(-dy / 24)
                var tail: [Action] = [.pendingLamp(steps: 0)]
                if rungs != 0 { tail.append(.lampStep(step: rungs > 0 ? 1 : -1, count: abs(rungs))) }
                #expect(Array(got.actions.suffix(tail.count)) == tail, "dy \(dy): \(got.actions)")
                #expect(got.actions.contains(.pendingLamp(steps: rungs)))
                var core: Core = c.core
                if let last = got.actions.last, Self.isKernel(last), abs(rungs) < s.actionsLeft {
                    _ = try Self.apply(last, to: &core, dragged: nil, run: -1)
                    let top: Int = s.lampHeights - 1
                    #expect(core.play.height == min(max(s.height + rungs, 0), top))
                }
                // The same drag on a won play sends nothing at all.
                var done: Controller = Controller()
                let won: Snapshot = level[2].snapshot
                if let wonLamp = Self.screen(Independent.lamp(won), won, view, .authored) {
                    let none: [Action] = Self.run(&done, Self.path(wonLamp, wonLamp + Vec2(14, dy), steps: 4, time: 1),
                                                  view: view, snapshot: won).actions
                    #expect(none.isEmpty)
                }
                checked += 1
            }
            // A tap on the lamp runs; on the ladder nothing; on a failed play nothing.
            var tapper: Controller = Controller()
            #expect(Self.run(&tapper, Self.tap(lamp, at: 1), view: view, snapshot: s).actions == [.run])
            let (bottom, top): (SIMD3<Double>, SIMD3<Double>) = Independent.ladder(s)
            if let a = Self.screen(bottom, s, view, .authored), let b = Self.screen(top, s, view, .authored) {
                let rung: Vec2 = a + (b - a) * 0.5 + Vec2(0, 0)
                if Self.under(rung, s, view, .authored) == .ladder {
                    var ladder: Controller = Controller()
                    #expect(Self.run(&ladder, Self.tap(rung, at: 1), view: view, snapshot: s).actions.isEmpty)
                }
            }
            let failed: Snapshot = level[3].snapshot
            if let failedLamp = Self.screen(Independent.lamp(failed), failed, view, .authored) {
                var none: Controller = Controller()
                #expect(Self.run(&none, Self.tap(failedLamp, at: 1), view: view, snapshot: failed).actions.isEmpty)
            }
        }
        #expect(checked == 12)
    }

    @Test func secondAndThirdFingersOrbitClampedClearPendingAndSendNothing() throws {
        let c: Case = try Self.cases(1)[1]
        let s: Snapshot = c.snapshot
        let view: Vec2 = Self.views[1]
        var g: Int = -1
        var p: Vec2 = .zero
        for k in s.gears.indices where g < 0 {
            if let q = Self.pointOn(gear: k, s, view) { g = k; p = q }
        }
        try #require(g >= 0)
        var controller: Controller = Controller()
        var actions: [Action] = controller.handle(Self.event(1, .began, p, 1), viewSize: view, snapshot: s)
        actions += controller.handle(Self.event(1, .moved, p + Vec2(30, 30), 1.05), viewSize: view, snapshot: s)
        #expect(controller.state == .gearDrag)
        let b: Vec2 = Vec2(700, 400)
        let cleared: [Action] = controller.handle(Self.event(2, .began, b, 1.1), viewSize: view, snapshot: s)
        #expect(cleared == [.pendingTurn(gear: g, teeth: 0)])
        #expect(controller.state == .orbiting)
        actions += controller.handle(Self.event(2, .moved, b + Vec2(100, -40), 1.12), viewSize: view, snapshot: s)
        var want: Orbit = Self.turned(.authored, by: Vec2(50, -20), view: view)
        #expect(Self.near(controller.orbit, want))
        // A third finger re-bases the midpoint: going down does not turn the camera.
        let third: Vec2 = Vec2(500, 700)
        actions += controller.handle(Self.event(3, .began, third, 1.13), viewSize: view, snapshot: s)
        #expect(Self.near(controller.orbit, want))
        actions += controller.handle(Self.event(3, .moved, third + Vec2(-90, 30), 1.14), viewSize: view, snapshot: s)
        want = Self.turned(want, by: Vec2(-30, 10), view: view)
        #expect(Self.near(controller.orbit, want))
        // A huge movement clamps at the limits.
        actions += controller.handle(Self.event(1, .moved, p + Vec2(90_000, 90_000), 1.15), viewSize: view, snapshot: s)
        #expect(Self.near(controller.orbit, Orbit(yaw: Orbit.yawLimit, pitch: Orbit.pitchRange.lowerBound)))
        actions += controller.handle(Self.event(1, .moved, p + Vec2(-90_000, -90_000), 1.16), viewSize: view,
                                     snapshot: s)
        #expect(Self.near(controller.orbit, Orbit(yaw: -Orbit.yawLimit, pitch: Orbit.pitchRange.upperBound)))
        actions += controller.handle(Self.event(1, .ended, p, 1.17), viewSize: view, snapshot: s)
        #expect(controller.state == .cancelled)
        actions += controller.handle(Self.event(2, .cancelled, b, 1.18), viewSize: view, snapshot: s)
        actions += controller.handle(Self.event(3, .ended, third, 1.19), viewSize: view, snapshot: s)
        #expect(controller.state == .idle)
        for a in actions { #expect(!Self.isKernel(a)) }
        for a in actions {
            if case .pendingTurn = a { continue }
            Issue.record("unexpected \(a)")
        }
        // A cancelled lamp drag clears its pending steps and sends nothing else.
        let lamp: Vec2 = try #require(Self.screen(Independent.lamp(s), s, view, .authored))
        var lampController: Controller = Controller()
        var lampActions: [Action] = lampController.handle(Self.event(1, .began, lamp, 1), viewSize: view, snapshot: s)
        lampActions += lampController.handle(Self.event(1, .moved, lamp + Vec2(0, -50), 1.1), viewSize: view,
                                             snapshot: s)
        #expect(lampController.state == .lampDrag)
        let cancelled: [Action] = lampController.handle(Self.event(1, .cancelled, lamp + Vec2(0, -50), 1.2),
                                                        viewSize: view, snapshot: s)
        #expect(lampActions == [.pendingLamp(steps: 2)])
        #expect(cancelled == [.pendingLamp(steps: 0)])
        #expect(lampController.state == .idle)
        // The orbit is presentation only: the digest stays; reset and a double tap on empty space return home.
        let digest: String = try Self.digest(c.core)
        controller.resetView()
        #expect(controller.orbit == .authored)
        var turnedController: Controller = Self.controller(at: Self.orbits[1], view: view, snapshot: s)
        let e: Vec2 = try #require(Self.emptyPoint(s, view, Self.orbits[1]))
        _ = Self.run(&turnedController, Self.tap(e, at: 1), view: view, snapshot: s)
        #expect(Self.run(&turnedController, Self.tap(e, at: 1.2), view: view, snapshot: s).actions == [.resetView])
        #expect(turnedController.orbit == .authored)
        #expect(try Self.digest(c.core) == digest)
        #expect(controller.camera(viewSize: view, snapshot: s) != nil)
        #expect(controller.camera(viewSize: Vec2(0, 10), snapshot: s) == nil)
    }

    @Test func finishedPlaysSendNoKernelAction() throws {
        let view: Vec2 = Self.views[2]
        for number in Self.levels {
            let level: [Case] = try Self.cases(number)
            for finished in [level[2], level[3]] {
                let s: Snapshot = finished.snapshot
                try #require(s.stage != .playing)
                // A card tap still shows its key frame.
                let k: Int = s.keyFrames.count - 1
                let card: Vec2 = try #require(Self.screen(Independent.card(k, s).0, s, view, .authored))
                if Self.under(card, s, view, .authored) == .card(k) {
                    var a: Controller = Controller()
                    #expect(Self.run(&a, Self.tap(card, at: 1), view: view, snapshot: s).actions == [.showFrame(k)])
                    var core: Core = finished.core
                    #expect(try Self.apply(.showFrame(k), to: &core, dragged: nil, run: -1) == 1)
                    #expect(core.play == finished.core.play)
                }
                // A gear drag previews and sends nothing.
                for g in s.gears.indices {
                    guard let centre = Self.centre(g, s, view, .authored) else { continue }
                    let steps: [Step] = Self.arc(centre, r: 30, from: 0, sweep: 2, dip: nil, time: 1)
                    guard Self.under(steps[0].point, s, view, .authored) == .gear(g) else { continue }
                    var b: Controller = Controller()
                    #expect(Self.run(&b, steps, view: view, snapshot: s).actions.isEmpty)
                }
            }
        }
    }
}
