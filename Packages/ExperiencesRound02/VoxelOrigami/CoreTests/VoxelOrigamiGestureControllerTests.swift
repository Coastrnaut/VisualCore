// VoxelOrigamiGestureControllerTests — feature 444 (R02-G15-04) T-R02G1504-003 (FR-R02G1504-001, 002, 004, 005;
// SC-R02G1504-001 … 003; clarifications Q1 … Q5). 500 seeded (SeededRandom seed 2_444) scripted gestures — taps and
// double taps on cubes (the root included), taps and double taps on empty space, drags from cubes along a predicted
// motion or anywhere, drags that come back below the threshold, drags from empty space, touches of 10 … 16 points,
// slow presses, cancelled touches, random touches, second fingers and system cancels — on certified levels 1, 10 and
// 30 (the opening and the moment after the first certified turn, both playing; won by the certified plan; failed by a
// collision, a sweep or the spent budget; each `snapshot(time: 0)`), at three view sizes and three orbits reached by
// two-finger drags, send exactly the actions an independent expectation written here predicts. What lies under the
// finger and the predicted motions are the picker tests' independent recomputations
// (`VoxelOrigamiPickerTests.reference`, `referencePrediction`, `referenceStep`: their own world mapping, hulls,
// descendants and right-hand quarter turns); the arbitration (tap, drag or nothing by travel and event timestamps; the
// pending step's changes; the explanations once per gesture; double taps within 0.35 s and 22 points; no kernel action
// outside playing) is written here too. Every kernel action is applied through the adapter's
// `apply(ExperienceAction(control:values:step:))` (turn → `hinge.turn [h, step]`, chooseHinge → `hinge.choose [h]`)
// and checked: accepted, the hinge turned by the step (or the play failed by a collision or sweep with the turns kept),
// the chosen hinge set without a digest change. Second fingers, `.cancelled` phases, `cancel()` and finished plays
// send no kernel action; a double tap on an idle hinge explains; a drag back below the threshold clears the pending
// turn; orbit changes no digest. Plain loops and explicit types (CI type-check rule); each test well under 3 s.
import Foundation
import Testing
import VisualCoreDiagnostics
import VisualCoreExperience
import VisualCoreMath
import VisualCoreScenes
import VisualCoreSimulation
@testable import VoxelOrigamiCore

@Suite struct VoxelOrigamiGestureControllerTests {
    typealias Controller = VoxelOrigamiGestureController
    typealias Snapshot = VoxelOrigamiSceneSnapshot
    typealias Action = VoxelOrigamiGestureAction
    typealias Orbit = VoxelOrigamiOrbit
    typealias Core = VoxelOrigamiExperienceCore
    typealias Independent = VoxelOrigamiPickerTests

    /// The seed of every random choice here.
    static let seed: UInt64 = 2_444
    /// The view sizes every script runs at: phone portrait, tablet landscape, tablet portrait.
    static let views: [Vec2] = [Vec2(390, 844), Vec2(1_180, 820), Vec2(1_024, 1_366)]
    /// The scripted orbits (the first is the authored one), reached by two-finger drags.
    static let orbits: [Orbit] = [.authored, Orbit(yaw: 0.5, pitch: 0.3), Orbit(yaw: -0.7, pitch: -0.2)]
    /// The certified levels used.
    static let levels: [Int] = [1, 10, 30]
    /// The turn threshold, written here on its own.
    static let threshold: Double = 24
    /// The explanations, written here on its own.
    static let rootText: String = "The root cube has no hinge"
    static let overText: String = "The play is over: undo or go to the next level"
    static func idleText(_ h: Int) -> String { "Nothing would move: hinge \(h) swings no cube" }

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

    /// The adapter action of a kernel turn.
    static func turnAction(_ h: Int, _ step: Int) -> ExperienceAction {
        action("hinge.turn", [Double(h), Double(step)])
    }

    /// Whether `a` is a kernel action (a turn).
    static func isKernel(_ a: Action) -> Bool {
        if case .turn = a { return true }
        return false
    }

    /// The digest of `core` as the engine computes it.
    static func digest(_ core: Core) throws -> String {
        var builder: DigestBuilder = DigestBuilder(domain: Core.experienceID)
        try core.writeDigest(into: &builder)
        return builder.finish().hex
    }

    /// Certified level `number`: the opening (playing), after the first certified turn (playing, when the plan has
    /// two or more turns), after the whole certified plan (won) and a failed play (a turn that collides or sweeps,
    /// else the budget spent).
    static func cases(_ number: Int) throws -> [Case] {
        let plan: [VoxelOrigamiAction] = try Core.generated(number: number).plan.turns
        try #require(!plan.isEmpty)
        let opening: Core = try Core.opening(number: number)
        #expect(opening.play.stage == .playing)
        var result: [Case] = [make(opening)]
        var core: Core = opening
        for (index, turn) in plan.enumerated() {
            guard case let .turn(h, step) = turn else { continue }
            #expect(core.apply(turnAction(h, step)) == .accepted)
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

    /// `opening` failed: by the first turn (hinge, then +1 before −1) that collides or sweeps, else by turning the
    /// first turnable hinge back and forth until the budget is spent.
    static func failed(_ opening: Core) throws -> Core {
        let count: Int = opening.play.level.cubes.count
        for h in 1..<count {
            for step in [1, -1] {
                var copy: Core = opening
                if copy.apply(turnAction(h, step)) == .accepted && copy.play.stage == .failed { return copy }
            }
        }
        var core: Core = opening
        var step: Int = 1
        var guardCount: Int = 0
        while core.play.stage == .playing && guardCount < 1_000 {
            let h: Int = try #require(core.snapshot(time: 0).turnable.first)
            #expect(core.apply(turnAction(h, step)) == .accepted)
            step = -step
            guardCount += 1
        }
        try #require(core.play.stage == .failed)
        return core
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

    /// The independent pick of `p`: the cube index, −1 for empty space.
    static func under(_ p: Vec2, _ s: Snapshot, _ view: Vec2, _ orbit: Orbit) -> Int {
        Independent.reference(simd(p), s, simd(view), orbit)
    }

    /// Cube `i`'s projected centre, independently.
    static func centre(_ i: Int, _ s: Snapshot, _ view: Vec2, _ orbit: Orbit) -> Vec2? {
        let camera: VoxelOrigamiCamera = VoxelOrigamiSceneGeometry.camera(s, aspect: view.x / view.y, orbit: orbit)
        guard let p = Independent.screen(Independent.world(s.cells[i], s), simd(view), camera) else { return nil }
        return vec(p)
    }

    /// The independent predicted motions of hinge `h` for +1 and −1, or nil.
    static func motions(_ h: Int, _ s: Snapshot, _ view: Vec2, _ orbit: Orbit) -> (plus: Vec2, minus: Vec2)? {
        guard h >= 1, h < s.cubes.count,
              let p = Independent.referencePrediction(h, s, simd(view), orbit, step: 1),
              let m = Independent.referencePrediction(h, s, simd(view), orbit, step: -1) else { return nil }
        return (vec(p), vec(m))
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

    /// A seeded cube's index and a point within 6 points of its projected centre (the pick may be a nearer cube).
    static func cubePoint(_ s: Snapshot, _ view: Vec2, _ orbit: Orbit,
                          _ random: inout SeededRandom) -> (cube: Int, point: Vec2)? {
        let i: Int = below(s.cubes.count, &random)
        guard let c = centre(i, s, view, orbit) else { return nil }
        return (i, inside(c + Vec2(unit(&random) * 12 - 6, unit(&random) * 12 - 6), view))
    }

    /// A point that picks nothing: the first of the view's corners (8 points in) that does.
    static func emptyPoint(_ s: Snapshot, _ view: Vec2, _ orbit: Orbit) -> Vec2? {
        let corners: [Vec2] = [Vec2(8, 8), Vec2(view.x - 8, 8), Vec2(8, view.y - 8), Vec2(view.x - 8, view.y - 8)]
        for c in corners where under(c, s, view, orbit) < 0 { return c }
        return nil
    }

    /// A unit direction of `v`, or (1, 0) for a zero vector.
    static func direction(_ v: Vec2) -> Vec2 {
        let l: Double = v.length
        return l > 1e-9 ? v * (1 / l) : Vec2(1, 0)
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

    // MARK: Independent expectation

    /// A tap that may start a double tap: on a cube (≥ 1) or on empty space (−1), its lift point and time.
    struct TapRecord {
        let cube: Int
        let point: Vec2
        let time: Double
    }

    /// What a one-finger script must send and the state after touch-down.
    struct Expectation {
        var actions: [Action] = []
        var state: Controller.State = .idle
    }

    /// The expectation of one-finger `steps` (the first a `.began`, the last an `.ended` or a `.cancelled`) on `s` in
    /// `view` at `orbit` after the double-tap candidate `record`, written on its own from clarifications Q1 … Q4.
    static func expected(_ steps: [Step], _ s: Snapshot, _ view: Vec2, _ orbit: Orbit,
                         record: inout TapRecord?) -> Expectation {
        let origin: Vec2 = steps[0].point
        let startTime: Double = steps[0].time
        let picked: Int = under(origin, s, view, orbit)
        let playing: Bool = s.stage == .playing
        let over: Bool = s.stage == .won || s.stage == .failed || s.stage == .result
        let turnable: Bool = s.turnable.contains(picked)
        var result: Expectation = Expectation()
        result.state = picked >= 0 ? .cubePress : .emptyPress
        var plus: SIMD2<Double>? = nil
        var minus: SIMD2<Double>? = nil
        if picked >= 1 && playing && turnable, let m = motions(picked, s, view, orbit) {
            plus = simd(m.plus)
            minus = simd(m.minus)
        }
        var reason: String? = nil
        if picked == 0 {
            reason = rootText
        } else if picked >= 1 && !playing {
            reason = over ? overText : nil
        } else if picked >= 1 && !turnable {
            reason = idleText(picked)
        }
        func stepAt(_ p: Vec2) -> Int? {
            guard let a = plus, let b = minus else { return nil }
            return Independent.referenceStep(simd(p - origin), plus: a, minus: b, threshold: threshold)
        }
        var travel: Double = 0
        var dragging: Bool = false
        var pending: Int? = nil
        for index in 1..<steps.count {
            let st: Step = steps[index]
            if st.phase == .cancelled {
                if pending != nil { result.actions.append(.clearPending) }
                record = nil
                break
            }
            travel = max(travel, (st.point - origin).length)
            if !dragging && travel >= 16 && picked >= 0 {
                dragging = true
                if let r = reason { result.actions.append(.explain(r)) }
            }
            if st.phase == .moved && dragging && plus != nil {
                let k: Int? = stepAt(st.point)
                if k != pending {
                    if let k1 = k {
                        result.actions.append(.pendingTurn(hinge: picked, step: k1))
                    } else {
                        result.actions.append(.clearPending)
                    }
                    pending = k
                }
            }
            guard st.phase == .ended else { continue }
            let tap: Bool = !dragging && travel < 10 && st.time - startTime < 0.5
            var double: Bool = false
            if tap, let r = record, r.cube == picked, picked != 0, st.time - r.time <= 0.35,
               (st.point - r.point).length <= 22 {
                double = true
            }
            var nextRecord: TapRecord? = nil
            if picked >= 1 {
                if dragging {
                    if pending != nil { result.actions.append(.clearPending) }
                    if playing, let k = stepAt(st.point) { result.actions.append(.turn(hinge: picked, step: k)) }
                } else if tap && double {
                    if playing {
                        result.actions.append(turnable ? .turn(hinge: picked, step: 1) : .explain(idleText(picked)))
                    } else {
                        result.actions.append(.chooseHinge(picked))
                        if over { result.actions.append(.explain(overText)) }
                    }
                } else if tap {
                    result.actions.append(.chooseHinge(picked))
                    nextRecord = TapRecord(cube: picked, point: st.point, time: st.time)
                }
            } else if picked < 0 {
                if tap && double {
                    result.actions.append(.resetView)
                } else if tap {
                    nextRecord = TapRecord(cube: -1, point: st.point, time: st.time)
                }
            }
            record = nextRecord
        }
        return result
    }

    // MARK: Seeded scripts

    /// One seeded one-finger gesture (or two, for a double tap) of `kind` (0 … 9, 12) on `s` in `view` at `orbit`,
    /// or nil without a target.
    static func scripts(_ kind: Int, _ s: Snapshot, _ view: Vec2, _ orbit: Orbit,
                        _ random: inout SeededRandom) -> [[Step]]? {
        switch kind {
        case 0:   // a tap on a cube
            guard let c = cubePoint(s, view, orbit, &random) else { return nil }
            let q: Vec2 = c.point + Vec2(unit(&random) * 6 - 3, unit(&random) * 6 - 3)
            let lift: Double = 1.05 + 0.4 * unit(&random)
            return [[Step(phase: .began, point: c.point, time: 1), Step(phase: .ended, point: q, time: lift)]]
        case 1:   // two taps on a cube, sometimes too late or too far for a double tap
            guard let c = cubePoint(s, view, orbit, &random) else { return nil }
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
        case 3:   // a drag from a cube along a predicted motion (or anywhere), 10 … 90 points
            guard let c = cubePoint(s, view, orbit, &random) else { return nil }
            var d: Vec2 = Vec2(cos(unit(&random) * 6.3), sin(unit(&random) * 6.3))
            if let m = motions(c.cube, s, view, orbit), unit(&random) < 0.8 {
                d = direction(unit(&random) < 0.5 ? m.plus : m.minus)
            }
            let length: Double = 10 + 80 * unit(&random)
            return [path(c.point, c.point + d * length, steps: 2 + below(4, &random), time: 1)]
        case 4:   // a drag out along a predicted motion and back below the threshold
            guard let c = cubePoint(s, view, orbit, &random) else { return nil }
            var d: Vec2 = Vec2(0, -1)
            if let m = motions(c.cube, s, view, orbit) { d = direction(unit(&random) < 0.5 ? m.plus : m.minus) }
            let out: Vec2 = c.point + d * (35 + 40 * unit(&random))
            let back: Vec2 = c.point + d * (unit(&random) * 20)
            return [outAndBack(c.point, out, back, time: 1)]
        case 5:   // a short touch of 10 … 16 points from a cube or anywhere
            var p: Vec2 = inside(Vec2(view.x * unit(&random), view.y * unit(&random)), view)
            if unit(&random) < 0.6, let c = cubePoint(s, view, orbit, &random) { p = c.point }
            let a: Double = unit(&random) * 2 * Double.pi
            let length: Double = 10.5 + 5 * unit(&random)
            return [path(p, p + Vec2(cos(a) * length, sin(a) * length), steps: 2, time: 1)]
        case 6:   // a slow press (lifted 0.5 … 1.0 s after touch-down) moving under 10 points
            var start: Vec2? = cubePoint(s, view, orbit, &random)?.point
            if start == nil || unit(&random) < 0.2 { start = emptyPoint(s, view, orbit) }
            guard let p = start else { return nil }
            let q: Vec2 = p + Vec2(unit(&random) * 8 - 4, unit(&random) * 8 - 4)
            return [[Step(phase: .began, point: p, time: 1), Step(phase: .moved, point: q, time: 1.2),
                     Step(phase: .ended, point: q, time: 1.5 + 0.5 * unit(&random))]]
        case 7:   // a cancelled touch on a cube, perhaps dragged along a predicted motion first
            guard let c = cubePoint(s, view, orbit, &random) else { return nil }
            var d: Vec2 = Vec2(0.6, -0.8)
            if let m = motions(c.cube, s, view, orbit) { d = direction(m.plus) }
            let q: Vec2 = unit(&random) < 0.3 ? c.point : c.point + d * (20 + 50 * unit(&random))
            return [[Step(phase: .began, point: c.point, time: 1), Step(phase: .moved, point: q, time: 1.1),
                     Step(phase: .cancelled, point: q, time: 1.2)]]
        case 8:   // a random touch, sometimes slow
            let p: Vec2 = inside(Vec2(view.x * unit(&random), view.y * unit(&random)), view)
            let q: Vec2 = p + Vec2(unit(&random) * 80 - 40, unit(&random) * 80 - 40)
            let slow: Double = unit(&random) < 0.3 ? 0.6 : 0
            var steps: [Step] = []
            for st in path(p, q, steps: 2, time: 1) {
                let time: Double = st.phase == .began ? st.time : st.time + slow
                steps.append(Step(phase: st.phase, point: st.point, time: time))
            }
            return [steps]
        case 9:   // a drag from empty space
            guard let e = emptyPoint(s, view, orbit) else { return nil }
            let a: Double = unit(&random) * 2 * Double.pi
            let length: Double = 20 + 200 * unit(&random)
            return [path(e, e + Vec2(cos(a) * length, sin(a) * length), steps: 3, time: 1)]
        default:  // a double tap on a cube (within the window and distance)
            guard let c = cubePoint(s, view, orbit, &random) else { return nil }
            let q: Vec2 = c.point + Vec2(unit(&random) * 8 - 4, unit(&random) * 8 - 4)
            return [[Step(phase: .began, point: c.point, time: 1), Step(phase: .ended, point: c.point, time: 1.05)],
                    [Step(phase: .began, point: q, time: 1.15), Step(phase: .ended, point: q, time: 1.2)]]
        }
    }

    /// A seeded one-finger script of `kind` checked against its expectation; nil when it has no target here.
    static func oneFinger(_ kind: Int, _ controller: inout Controller, _ s: Snapshot, _ view: Vec2, _ orbit: Orbit,
                          run: Int, _ random: inout SeededRandom) -> [Action]? {
        guard let gestures = scripts(kind, s, view, orbit, &random) else { return nil }
        var record: TapRecord? = nil
        var produced: [Action] = []
        for g in gestures {
            let got: Outcome = self.run(&controller, g, view: view, snapshot: s)
            let want: Expectation = expected(g, s, view, orbit, record: &record)
            #expect(got.actions == want.actions, "run \(run) kind \(kind)")
            #expect(got.state == want.state, "run \(run) kind \(kind)")
            #expect(controller.state == .idle)
            produced += got.actions
        }
        if kind == 5 || kind == 6 || kind == 7 {
            for a in produced { #expect(!isKernel(a), "kind \(kind) sent \(a), run \(run)") }
        }
        if kind == 9 { #expect(produced.isEmpty, "a drag from empty space, run \(run)") }
        #expect(near(controller.orbit, orbit) || produced.contains(.resetView))
        return produced
    }

    /// A seeded second-finger script: the first finger on a cube (perhaps dragged along a predicted motion first), a
    /// second finger cancels (only `clearPending` when a step was pending) and orbits; nothing kernel is sent, nothing
    /// at all after the clearing value, and the orbit turns by half the second finger's movement.
    static func secondFinger(_ controller: inout Controller, _ s: Snapshot, _ view: Vec2, _ orbit: Orbit, run: Int,
                             _ random: inout SeededRandom) -> [Action]? {
        guard let c = cubePoint(s, view, orbit, &random) else { return nil }
        let p: Vec2 = c.point
        var first: Vec2 = p
        var steps: [Step] = [Step(phase: .began, point: p, time: 1)]
        if unit(&random) < 0.6 {
            var d: Vec2 = Vec2(0, -1)
            if let m = motions(c.cube, s, view, orbit) { d = direction(m.plus) }
            first = p + d * 60
            steps.append(Step(phase: .moved, point: first, time: 1.05))
        }
        var before: [Action] = []
        for st in steps {
            before += controller.handle(event(1, st.phase, st.point, st.time), viewSize: view, snapshot: s)
        }
        // The pending step shown before the second finger, from the independent expectation.
        var record: TapRecord? = nil
        var probe: [Step] = steps
        probe.append(Step(phase: .cancelled, point: first, time: 1.1))
        let want: [Action] = expected(probe, s, view, orbit, record: &record).actions
        for a in before { #expect(!isKernel(a), "second finger run \(run)") }
        let q: Vec2 = Vec2(view.x / 2, view.y / 2)
        let clearing: [Action] = controller.handle(event(2, .began, q, 1.2), viewSize: view, snapshot: s)
        #expect(before + clearing == want, "second finger run \(run)")
        #expect(controller.state == .orbiting, "second finger run \(run)")
        let move: Vec2 = Vec2((unit(&random) - 0.5) * view.x * 0.6, (unit(&random) - 0.5) * view.y * 0.6)
        var actions: [Action] = controller.handle(event(2, .moved, q + move, 1.25), viewSize: view, snapshot: s)
        actions += controller.handle(event(1, .ended, first, 1.3), viewSize: view, snapshot: s)
        #expect(controller.state == .cancelled)
        actions += controller.handle(event(2, .ended, q + move, 1.35), viewSize: view, snapshot: s)
        #expect(controller.state == .idle)
        #expect(actions.isEmpty, "second finger run \(run)")
        #expect(near(controller.orbit, turned(orbit, by: move * 0.5, view: view)), "second finger run \(run)")
        return before + clearing + actions
    }

    /// A seeded `cancel()` in the middle of a press or a drag: the finger's later events send nothing.
    static func systemCancel(_ controller: inout Controller, _ s: Snapshot, _ view: Vec2, _ orbit: Orbit, run: Int,
                             _ random: inout SeededRandom) -> [Action]? {
        guard let c = cubePoint(s, view, orbit, &random) else { return nil }
        let q: Vec2 = unit(&random) < 0.4 ? c.point : c.point + Vec2(40, -30)
        var actions: [Action] = controller.handle(event(1, .began, c.point, 1), viewSize: view, snapshot: s)
        actions += controller.handle(event(1, .moved, q, 1.05), viewSize: view, snapshot: s)
        for a in actions { #expect(!isKernel(a), "system cancel run \(run)") }
        controller.cancel()
        #expect(controller.state == .idle)
        let after: [Action] = controller.handle(event(1, .ended, q, 1.1), viewSize: view, snapshot: s)
        #expect(after.isEmpty, "system cancel run \(run)")
        #expect(near(controller.orbit, orbit))
        return actions + after
    }

    /// The name of an action's case.
    static func name(_ a: Action) -> String {
        switch a {
        case .chooseHinge: return "chooseHinge"
        case .pendingTurn: return "pendingTurn"
        case .clearPending: return "clearPending"
        case .turn: return "turn"
        case .resetView: return "resetView"
        case .explain: return "explain"
        }
    }

    /// Applies gesture action `a` to `core` through the adapter and checks the result and its effect: a turn is
    /// accepted and turns its hinge by the step (or fails the play by a collision or sweep, the turns kept), a choice
    /// is accepted, sets the chosen hinge and keeps the digest. Returns the number of adapter actions accepted.
    static func apply(_ a: Action, to core: inout Core, run: Int) throws -> Int {
        switch a {
        case let .turn(h, step):
            let before: VoxelOrigamiPlay = core.play
            let result: ActionResult = core.apply(turnAction(h, step))
            #expect(result == .accepted, "adapter refused \(a): \(result), run \(run)")
            #expect(core.play.actionsLeft == before.actionsLeft - 1)
            if case .collision = core.play.failure {
                #expect(core.play.turns == before.turns)
            } else if case .sweep = core.play.failure {
                #expect(core.play.turns == before.turns)
            } else {
                var want: [Int] = before.turns
                want[h] = ((want[h] + step) % 4 + 4) % 4
                #expect(core.play.turns == want, "hinge \(h) did not turn by \(step), run \(run)")
            }
            return result == .accepted ? 1 : 0
        case .chooseHinge(let h):
            let digestBefore: String = try digest(core)
            let result: ActionResult = core.apply(action("hinge.choose", [Double(h)]))
            #expect(result == .accepted, "adapter refused \(a): \(result), run \(run)")
            #expect(core.chosenHinge == h)
            #expect(try digest(core) == digestBefore)
            return result == .accepted ? 1 : 0
        case .pendingTurn, .clearPending, .resetView, .explain:
            return 0
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
        let kinds: Int = 13
        var counts: [Int] = Array(repeating: 0, count: kinds)
        var sent: [String: Int] = [:]
        var accepted: Int = 0
        var finished: Int = 0
        var turns: Int = 0
        while run < 500 && attempts < 5_000 {
            attempts += 1
            let c: Case = all[Self.below(all.count, &random)]
            let view: Vec2 = Self.views[Self.below(Self.views.count, &random)]
            let nominal: Orbit = Self.orbits[Self.below(Self.orbits.count, &random)]
            let drawn: Snapshot = c.snapshot
            var controller: Controller = Self.controller(at: nominal, view: view, snapshot: drawn)
            let orbit: Orbit = controller.orbit
            let kind: Int = Self.below(kinds, &random)
            var produced: [Action]?
            if kind == 10 {
                produced = Self.secondFinger(&controller, drawn, view, orbit, run: run, &random)
            } else if kind == 11 {
                produced = Self.systemCancel(&controller, drawn, view, orbit, run: run, &random)
            } else {
                produced = Self.oneFinger(kind, &controller, drawn, view, orbit, run: run, &random)
            }
            guard let result = produced else { continue }
            var kernel: Int = 0
            var copy: Core = c.core
            for a in result {
                sent[Self.name(a), default: 0] += 1
                if Self.isKernel(a) {
                    kernel += 1
                    #expect(drawn.stage == .playing, "a kernel action outside playing, run \(run)")
                }
                accepted += try Self.apply(a, to: &copy, run: run)
            }
            #expect(kernel <= 1, "run \(run)")
            if kind == 10 || kind == 11 || kind == 7 { #expect(kernel == 0, "run \(run)") }
            if drawn.stage != .playing {
                finished += 1
                for a in result { #expect(!Self.isKernel(a), "run \(run)") }
            }
            turns += kernel
            counts[kind] += 1
            run += 1
        }
        #expect(run == 500)
        for k in 0..<kinds { #expect(counts[k] > 0, "script kind \(k) never ran") }
        for n in ["chooseHinge", "pendingTurn", "clearPending", "turn", "resetView", "explain"] {
            #expect((sent[n] ?? 0) > 0, "\(n) never sent: \(sent)")
        }
        #expect(accepted > 50)
        #expect(finished > 100)
        #expect(turns > 10)
        for index in all.indices { #expect(try Self.digest(all[index].core) == digests[index]) }
    }

    /// A point that picks cube `i` of `s` in `view` at the authored orbit (its centre, or the nearest such point of a
    /// 3-point grid within 30 points), or nil.
    static func pointOn(cube i: Int, _ s: Snapshot, _ view: Vec2) -> Vec2? {
        guard let c = centre(i, s, view, .authored) else { return nil }
        if under(c, s, view, .authored) == i { return c }
        var best: Vec2? = nil
        var bestDistance: Double = Double.infinity
        for a in -10...10 {
            for b in -10...10 {
                let p: Vec2 = c + Vec2(Double(a) * 3, Double(b) * 3)
                let d: Double = (p - c).length
                if d < bestDistance, under(p, s, view, .authored) == i {
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

    @Test func tapsChooseDoubleTapsTurnOrExplain() throws {
        let view: Vec2 = Self.views[2]
        var turnedCount: Int = 0
        var idleCount: Int = 0
        var rootCount: Int = 0
        for number in Self.levels {
            let level: [Case] = try Self.cases(number)
            let c: Case = level[0]
            let s: Snapshot = c.snapshot
            for i in s.cubes.indices {
                guard let p = Self.pointOn(cube: i, s, view) else { continue }
                var controller: Controller = Controller()
                let first: Outcome = Self.run(&controller, Self.tap(p, at: 1), view: view, snapshot: s)
                #expect(first.state == .cubePress)
                let second: [Action] = Self.run(&controller, Self.tap(p, at: 1.25), view: view, snapshot: s).actions
                if i == 0 {
                    #expect(first.actions.isEmpty && second.isEmpty, "a tap on the root changes nothing")
                    rootCount += 1
                    continue
                }
                #expect(first.actions == [.chooseHinge(i)])
                var core: Core = c.core
                #expect(try Self.apply(.chooseHinge(i), to: &core, run: -1) == 1)
                if s.turnable.contains(i) {
                    #expect(second == [.turn(hinge: i, step: 1)])
                    #expect(try Self.apply(.turn(hinge: i, step: 1), to: &core, run: -1) == 1)
                    turnedCount += 1
                    // A completed double tap starts no new one.
                    #expect(Self.run(&controller, Self.tap(p, at: 1.4), view: view, snapshot: s).actions
                        == [.chooseHinge(i)])
                } else {
                    #expect(second == [.explain(Self.idleText(i))], "a double tap on an idle hinge explains")
                    #expect(core.apply(Self.turnAction(i, 1)) != .accepted, "the kernel refuses an idle hinge")
                    idleCount += 1
                }
                // Too late (0.36 s between the lifts): two single taps.
                var late: Controller = Controller()
                _ = Self.run(&late, Self.tap(p, at: 1), view: view, snapshot: s)
                #expect(Self.run(&late, Self.tap(p, at: 1.36), view: view, snapshot: s).actions == [.chooseHinge(i)])
                // Too far (23 points between the lifts) when that point still picks the cube.
                let far: Vec2 = p + Vec2(23, 0)
                if Self.under(far, s, view, .authored) == i {
                    var apart: Controller = Controller()
                    _ = Self.run(&apart, Self.tap(p, at: 1), view: view, snapshot: s)
                    #expect(Self.run(&apart, Self.tap(far, at: 1.2), view: view, snapshot: s).actions
                        == [.chooseHinge(i)])
                }
                // On the won and failed plays a double tap chooses and says the play is over.
                for done in [level[level.count - 2], level[level.count - 1]] {
                    let fs: Snapshot = done.snapshot
                    guard let q = Self.pointOn(cube: i, fs, view) else { continue }
                    var finished: Controller = Controller()
                    var got: [Action] = Self.run(&finished, Self.tap(q, at: 1), view: view, snapshot: fs).actions
                    got += Self.run(&finished, Self.tap(q, at: 1.2), view: view, snapshot: fs).actions
                    #expect(got == [.chooseHinge(i), .chooseHinge(i), .explain(Self.overText)])
                    var doneCore: Core = done.core
                    #expect(try Self.apply(.chooseHinge(i), to: &doneCore, run: -1) == 1)
                    #expect(doneCore.play == done.core.play)
                }
            }
        }
        #expect(turnedCount > 0 && idleCount > 0 && rootCount > 0)
        // Tap thresholds: travel under 10 points, lifted before 0.5 s; 10 … 16 points do nothing.
        let s: Snapshot = try Self.cases(1)[0].snapshot
        var hinge: Int = -1
        var p: Vec2 = .zero
        for i in 1..<s.cubes.count where hinge < 0 {
            if let q = Self.pointOn(cube: i, s, view) {
                hinge = i
                p = q
            }
        }
        try #require(hinge >= 1)
        func play(_ steps: [Step]) -> [Action] {
            var controller: Controller = Controller()
            return Self.run(&controller, steps, view: view, snapshot: s).actions
        }
        #expect(play(Self.tap(p, at: 1, held: 0.49)) == [.chooseHinge(hinge)])
        #expect(play(Self.tap(p, at: 1, held: 0.5)).isEmpty)
        #expect(play(Self.tap(p, at: 1, lift: p + Vec2(0, 9.9))) == [.chooseHinge(hinge)])
        #expect(play(Self.tap(p, at: 1, lift: p + Vec2(0, 10))).isEmpty)
        #expect(play(Self.tap(p, at: 1, lift: p + Vec2(0, 15.9))).isEmpty)
        #expect(Controller.tapDistance == 10 && Controller.dragDistance == 16 && Controller.tapDuration == 0.5)
        #expect(Controller.doubleTapWindow == 0.35 && Controller.doubleTapDistance == 22)
        #expect(Controller.turnDistance == 24)
        #expect(Controller.rootReason == Self.rootText && Controller.finishedReason == Self.overText)
        #expect(Controller.idleReason(3) == Self.idleText(3))
    }

    @Test func dragsTurnTheWayTheCubeMovesAndClearWhenTheyComeBack() throws {
        let view: Vec2 = Self.views[1]
        var plusCount: Int = 0
        var minusCount: Int = 0
        var backCount: Int = 0
        for number in Self.levels {
            let level: [Case] = try Self.cases(number)
            for c in level where c.snapshot.stage == .playing {
                let s: Snapshot = c.snapshot
                for h in s.turnable {
                    guard let p = Self.pointOn(cube: h, s, view), let m = Self.motions(h, s, view, .authored) else {
                        continue
                    }
                    for useMinus in [false, true] {
                        let d: Vec2 = Self.direction(useMinus ? m.minus : m.plus)
                        let steps: [Step] = Self.path(p, p + d * 45, steps: 4, time: 1)
                        let k: Int = try #require(Independent.referenceStep(Self.simd(d * 45), plus: Self.simd(m.plus),
                                                                            minus: Self.simd(m.minus),
                                                                            threshold: Self.threshold))
                        var controller: Controller = Controller()
                        let got: [Action] = Self.run(&controller, steps, view: view, snapshot: s).actions
                        #expect(got.first == .pendingTurn(hinge: h, step: k))
                        #expect(Array(got.suffix(2)) == [.clearPending, .turn(hinge: h, step: k)],
                                "level \(number) hinge \(h): \(got)")
                        var kernel: Int = 0
                        for a in got where Self.isKernel(a) { kernel += 1 }
                        #expect(kernel == 1)
                        var record: TapRecord? = nil
                        #expect(got == Self.expected(steps, s, view, .authored, record: &record).actions)
                        var core: Core = c.core
                        #expect(try Self.apply(.turn(hinge: h, step: k), to: &core, run: -1) == 1)
                        if k > 0 { plusCount += 1 } else { minusCount += 1 }
                        // Out 45 points and back to 5 points from the start: pending, then cleared; nothing sent.
                        let back: [Step] = Self.outAndBack(p, p + d * 45, p + d * 5, time: 1)
                        var returning: Controller = Controller()
                        let none: [Action] = Self.run(&returning, back, view: view, snapshot: s).actions
                        #expect(none == [.pendingTurn(hinge: h, step: k), .clearPending], "\(none)")
                        backCount += 1
                    }
                    // Below the threshold (20 points): nothing at all.
                    let shortSteps: [Step] = Self.path(p, p + Self.direction(m.plus) * 20, steps: 3, time: 1)
                    var short: Controller = Controller()
                    #expect(Self.run(&short, shortSteps, view: view, snapshot: s).actions.isEmpty)
                }
            }
        }
        #expect(plusCount > 0 && minusCount > 0 && backCount > 0)
    }

    @Test func dragsThatCannotTurnExplainOnceAndSendNothing() throws {
        let view: Vec2 = Self.views[2]
        var rootCount: Int = 0
        var idleCount: Int = 0
        var overCount: Int = 0
        for number in Self.levels {
            let level: [Case] = try Self.cases(number)
            for c in level {
                let s: Snapshot = c.snapshot
                let over: Bool = s.stage == .won || s.stage == .failed
                for i in s.cubes.indices {
                    guard let p = Self.pointOn(cube: i, s, view) else { continue }
                    var want: [Action] = []
                    if i == 0 {
                        want = [.explain(Self.rootText)]
                        rootCount += 1
                    } else if over {
                        want = [.explain(Self.overText)]
                        overCount += 1
                    } else if !s.turnable.contains(i) {
                        want = [.explain(Self.idleText(i))]
                        idleCount += 1
                    } else {
                        continue
                    }
                    for d in [Vec2(0, -70), Vec2(60, 30)] {
                        var controller: Controller = Controller()
                        let got: Outcome = Self.run(&controller, Self.path(p, p + d, steps: 5, time: 1), view: view,
                                                    snapshot: s)
                        #expect(got.actions == want, "level \(number) cube \(i) stage \(s.stage): \(got.actions)")
                        #expect(controller.state == .idle)
                    }
                }
            }
        }
        #expect(rootCount > 0 && idleCount > 0 && overCount > 0)
    }

    @Test func secondAndThirdFingersOrbitClampedClearPendingAndSendNothing() throws {
        let c: Case = try Self.cases(1)[0]
        let s: Snapshot = c.snapshot
        let view: Vec2 = Self.views[1]
        var hinge: Int = -1
        var p: Vec2 = .zero
        var d: Vec2 = .zero
        for h in s.turnable where hinge < 0 {
            if let q = Self.pointOn(cube: h, s, view), let m = Self.motions(h, s, view, .authored) {
                hinge = h
                p = q
                d = Self.direction(m.plus)
            }
        }
        try #require(hinge >= 1)
        var controller: Controller = Controller()
        var actions: [Action] = controller.handle(Self.event(1, .began, p, 1), viewSize: view, snapshot: s)
        actions += controller.handle(Self.event(1, .moved, p + d * 50, 1.05), viewSize: view, snapshot: s)
        #expect(controller.state == .cubeDrag)
        #expect(actions.count == 1)
        let b: Vec2 = Vec2(700, 400)
        let cleared: [Action] = controller.handle(Self.event(2, .began, b, 1.1), viewSize: view, snapshot: s)
        #expect(cleared == [.clearPending])
        #expect(controller.state == .orbiting)
        var later: [Action] = controller.handle(Self.event(2, .moved, b + Vec2(100, -40), 1.12), viewSize: view,
                                                snapshot: s)
        var want: Orbit = Self.turned(.authored, by: Vec2(50, -20), view: view)
        #expect(Self.near(controller.orbit, want))
        // A third finger re-bases the midpoint: going down does not turn the camera.
        let third: Vec2 = Vec2(500, 700)
        later += controller.handle(Self.event(3, .began, third, 1.13), viewSize: view, snapshot: s)
        #expect(Self.near(controller.orbit, want))
        later += controller.handle(Self.event(3, .moved, third + Vec2(-90, 30), 1.14), viewSize: view, snapshot: s)
        want = Self.turned(want, by: Vec2(-30, 10), view: view)
        #expect(Self.near(controller.orbit, want))
        // A huge movement clamps at the limits.
        later += controller.handle(Self.event(1, .moved, p + Vec2(90_000, 90_000), 1.15), viewSize: view, snapshot: s)
        #expect(Self.near(controller.orbit, Orbit(yaw: Orbit.yawLimit, pitch: Orbit.pitchRange.lowerBound)))
        later += controller.handle(Self.event(1, .moved, p + Vec2(-90_000, -90_000), 1.16), viewSize: view,
                                   snapshot: s)
        #expect(Self.near(controller.orbit, Orbit(yaw: -Orbit.yawLimit, pitch: Orbit.pitchRange.upperBound)))
        later += controller.handle(Self.event(1, .ended, p, 1.17), viewSize: view, snapshot: s)
        #expect(controller.state == .cancelled)
        later += controller.handle(Self.event(2, .cancelled, b, 1.18), viewSize: view, snapshot: s)
        later += controller.handle(Self.event(3, .ended, third, 1.19), viewSize: view, snapshot: s)
        #expect(controller.state == .idle)
        #expect(later.isEmpty)
        // A cancelled drag clears its pending turn and sends nothing else.
        var cancelling: Controller = Controller()
        var pending: [Action] = cancelling.handle(Self.event(1, .began, p, 1), viewSize: view, snapshot: s)
        pending += cancelling.handle(Self.event(1, .moved, p + d * 50, 1.1), viewSize: view, snapshot: s)
        #expect(pending.count == 1)
        let cancelled: [Action] = cancelling.handle(Self.event(1, .cancelled, p + d * 50, 1.2), viewSize: view,
                                                    snapshot: s)
        #expect(cancelled == [.clearPending])
        #expect(cancelling.state == .idle)
        // A cancelled press sends nothing.
        var press: Controller = Controller()
        var nothing: [Action] = press.handle(Self.event(1, .began, p, 1), viewSize: view, snapshot: s)
        nothing += press.handle(Self.event(1, .cancelled, p, 1.1), viewSize: view, snapshot: s)
        #expect(nothing.isEmpty)
        // The orbit is presentation only: the digest stays; reset and a double tap on empty space return home.
        let digest: String = try Self.digest(c.core)
        controller.resetView()
        #expect(controller.orbit == .authored)
        var turnedController: Controller = Self.controller(at: Self.orbits[1], view: view, snapshot: s)
        let e: Vec2 = try #require(Self.emptyPoint(s, view, Self.orbits[1]))
        #expect(Self.run(&turnedController, Self.tap(e, at: 1), view: view, snapshot: s).actions.isEmpty)
        #expect(Self.run(&turnedController, Self.tap(e, at: 1.2), view: view, snapshot: s).actions == [.resetView])
        #expect(turnedController.orbit == .authored)
        #expect(try Self.digest(c.core) == digest)
        // The camera follows the orbit; an unusable view has none.
        let authoredCamera: VoxelOrigamiCamera? = controller.camera(viewSize: view, snapshot: s)
        #expect(authoredCamera == VoxelOrigamiSceneGeometry.camera(s, aspect: view.x / view.y))
        let turnedCamera: Controller = Self.controller(at: Self.orbits[2], view: view, snapshot: s)
        #expect(turnedCamera.camera(viewSize: view, snapshot: s)
            == VoxelOrigamiSceneGeometry.camera(s, aspect: view.x / view.y, orbit: turnedCamera.orbit))
        #expect(controller.camera(viewSize: Vec2(0, 10), snapshot: s) == nil)
    }
}
