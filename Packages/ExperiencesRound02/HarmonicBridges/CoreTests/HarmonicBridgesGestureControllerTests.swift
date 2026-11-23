// HarmonicBridgesGestureControllerTests — feature 414 (R02-G12-04) T-R02G1204-003 (FR-R02G1204-001 … 003, 005;
// SC-R02G1204-001 … 003; clarifications Q1 … Q4). 500 seeded (LCG seed 2_414) scripted gestures — taps on strings, on
// pips and the goal and on empty space, peg drags from strings, drags from pips, the goal and empty space, touches of
// 10 … 16 points, slow presses, cancelled touches, random touches, second fingers, double taps on empty space and
// system cancels — on certified levels 1, 50 and 100 (the opening and the tuned moment before the test, both playing;
// paused; won; failed by a test) and a hand-made level with a locked string (playing), at three view sizes and three
// orbits reached by two-finger drags, send exactly the actions an independent expectation written here predicts: what
// lies under the finger comes from `HarmonicBridgesPicker` (the geometry oracle, tested on its own), while the
// arbitration (tap, drag or nothing by travel and event timestamps; choose, preview, tune and test by clarifications Q2
// and Q3; the preview's rounding and clamp; no kernel action outside playing; the orbit arithmetic) is computed here on
// its own. Every tune and test sent is on a playing case and is accepted by `HarmonicBridgesExperienceCore`; second
// fingers, `.cancelled` phases, `cancel()` and finished plays send no kernel action; the orbit clamps and a third
// finger re-bases it; a double tap on empty space resets the view; the orbit never changes the adapter's digest. Plain
// loops and explicit types (CI type-check rule); each test well under 10 s once the levels are certified.
import Foundation
import Testing
import VisualCoreExperience
import VisualCoreMath
import VisualCoreScenes
import VisualCoreSimulation
@testable import HarmonicBridgesCore

@Suite struct HarmonicBridgesGestureControllerTests {
    typealias Controller = HarmonicBridgesGestureController
    typealias Snapshot = HarmonicBridgesSceneSnapshot
    typealias Action = HarmonicBridgesGestureAction
    typealias Geometry = HarmonicBridgesSceneGeometry
    typealias Picker = HarmonicBridgesPicker
    typealias Orbit = HarmonicBridgesOrbit
    typealias Core = HarmonicBridgesExperienceCore
    typealias Play = HarmonicBridgesPlay

    /// The seed of every random choice here.
    static let seed: UInt64 = 2_414
    /// The view sizes every script runs at: phone portrait, tablet landscape, tablet portrait.
    static let views: [Vec2] = [Vec2(390, 844), Vec2(1_180, 820), Vec2(1_024, 1_366)]
    /// The scripted orbits (the first is the authored one), reached by two-finger drags.
    static let orbits: [Orbit] = [.authored, Orbit(yaw: 0.3, pitch: 0.2), Orbit(yaw: -0.45, pitch: -0.15)]
    /// The certified levels used.
    static let levels: [Int] = [1, 50, 100]

    // MARK: Random numbers

    /// A 64-bit linear congruential generator (Knuth's MMIX constants); the high 53 bits make a unit number.
    struct LCG {
        var state: UInt64
        init(seed: UInt64) { state = seed }
        mutating func next() -> UInt64 {
            state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            return state
        }
        /// A unit number 0 ..< 1.
        mutating func unit() -> Double { Double(next() >> 11) / 9_007_199_254_740_992 }
        /// A whole number 0 ..< `count`.
        mutating func below(_ count: Int) -> Int { min(Int(unit() * Double(count)), max(count - 1, 0)) }
    }

    // MARK: Cases

    /// A core (for the digest and the adapter; nil for a case the adapter cannot reach) and the snapshot the
    /// controller sees.
    struct Case {
        let core: Core?
        let snapshot: Snapshot
    }

    /// The adapter action of a gesture's kernel action, or nil for presentation actions.
    static func adapterAction(_ a: Action) -> ExperienceAction? {
        switch a {
        case let .tune(string, peg):
            return ExperienceAction(control: "string.tune", values: [Double(string), Double(peg)], step: 0)
        case .test:
            return ExperienceAction(control: "crossing.test", values: [], step: 0)
        case .choose, .preview, .resetView:
            return nil
        }
    }

    /// The adapter action of a kernel action.
    static func adapterAction(kernel a: HarmonicBridgesAction) -> ExperienceAction {
        switch a {
        case let .tune(string, peg):
            return ExperienceAction(control: "string.tune", values: [Double(string), Double(peg)], step: 0)
        case .test:
            return ExperienceAction(control: "crossing.test", values: [], step: 0)
        }
    }

    /// Whether `a` is a kernel action (tune or test).
    static func isKernel(_ a: Action) -> Bool { adapterAction(a) != nil }

    /// The digest of `core` as the engine computes it.
    static func digest(_ core: Core) throws -> String {
        var builder: DigestBuilder = DigestBuilder(domain: Core.experienceID)
        try core.writeDigest(into: &builder)
        return builder.finish().hex
    }

    /// A case of `core` at presentation time 1 s.
    static func make(_ core: Core) -> Case { Case(core: core, snapshot: core.snapshot(time: 1)) }

    /// Certified level `number`: the opening (playing), the moment after its certified tunings before the test
    /// (playing), the opening paused, after the certified win (won) and the opening failed by a test.
    static func cases(_ number: Int) throws -> [Case] {
        let actions: [HarmonicBridgesAction] = HarmonicBridgesSolver.actions(try Core.generated(number: number).plan)
        try #require(actions.count >= 2)
        let opening: Core = try Core.opening(number: number)
        var core: Core = opening
        var index: Int = 0
        while index < actions.count - 1 {
            #expect(core.apply(adapterAction(kernel: actions[index])) == .accepted)
            index += 1
        }
        #expect(core.play.stage == .playing)
        let tuned: Case = make(core)
        #expect(core.apply(adapterAction(kernel: actions[actions.count - 1])) == .accepted)
        #expect(core.play.stage == .won)
        let won: Case = make(core)
        var paused: Play = opening.play
        try paused.handle(.pause)
        var failed: Core = opening
        #expect(failed.apply(adapterAction(kernel: .test)) == .accepted)
        #expect(failed.play.stage == .failed)
        return [make(opening), tuned, Case(core: nil, snapshot: Snapshot(play: paused, levelNumber: number, time: 1)),
                won, make(failed)]
    }

    /// The hand-made level with its last string locked, playing, as an adapter state.
    static func lockedCase() throws -> Case {
        let level: HarmonicBridgesLevel = HarmonicBridgesFixtures.handLevel(lockedLast: true)
        let play: Play = try Core.freshPlay(of: level)
        let core: Core = Core(levelNumber: 1, play: play, openingNumber: 1, openingPlay: play)
        return make(core)
    }

    /// Every case: ``levels`` and the locked hand-made level.
    static func allCases() throws -> [Case] {
        var all: [Case] = []
        for number in levels { all += try cases(number) }
        all.append(try lockedCase())
        return all
    }

    // MARK: Projection and targets

    /// The view point of `world` for `snapshot` in `view` at `orbit`, or nil behind the eye.
    static func screen(_ world: SIMD3<Double>, snapshot: Snapshot, view: Vec2, orbit: Orbit) -> Vec2? {
        let camera: HarmonicBridgesCamera = Geometry.camera(snapshot, aspect: view.x / view.y, orbit: orbit)
        guard let p = Geometry.project(world, camera: camera) else { return nil }
        return Vec2(p.x * view.x, p.y * view.y)
    }

    /// The pick of `point` (the oracle).
    static func pick(_ point: Vec2, snapshot: Snapshot, view: Vec2, orbit: Orbit) -> HarmonicBridgesPick {
        Picker.pick(SIMD2(point.x, point.y), size: SIMD2(view.x, view.y), snapshot: snapshot, orbit: orbit)
    }

    /// `p` kept one point inside `view`.
    static func inside(_ p: Vec2, _ view: Vec2) -> Vec2 {
        Vec2(min(max(p.x, 1), view.x - 1), min(max(p.y, 1), view.y - 1))
    }

    /// A point near a seeded string: 20 … 80 % along its projected segment, up to 8 points off it.
    static func stringPoint(_ snapshot: Snapshot, view: Vec2, orbit: Orbit, random: inout LCG) -> Vec2? {
        guard !snapshot.strings.isEmpty else { return nil }
        let ends = Geometry.stringEnds(random.below(snapshot.strings.count), snapshot)
        guard let a = screen(ends.a, snapshot: snapshot, view: view, orbit: orbit),
              let b = screen(ends.b, snapshot: snapshot, view: view, orbit: orbit) else { return nil }
        let t: Double = 0.2 + 0.6 * random.unit()
        let along: Vec2 = a + (b - a) * t
        return inside(along + Vec2(random.unit() * 16 - 8, random.unit() * 16 - 8), view)
    }

    /// A point within 6 points of a seeded step pip's or the goal's projection.
    static func targetPoint(_ snapshot: Snapshot, view: Vec2, orbit: Orbit, random: inout LCG) -> Vec2? {
        var world: SIMD3<Double> = Geometry.islandTop(snapshot.goal, snapshot)
        if random.unit() < 0.6 { world = Geometry.stepPip(random.below(max(snapshot.steps, 1)), snapshot) }
        guard let p = screen(world, snapshot: snapshot, view: view, orbit: orbit) else { return nil }
        return inside(p + Vec2(random.unit() * 12 - 6, random.unit() * 12 - 6), view)
    }

    /// A point that picks nothing: the first of the view's corners (8 points in) that does.
    static func emptyPoint(_ snapshot: Snapshot, view: Vec2, orbit: Orbit) -> Vec2? {
        let corners: [Vec2] = [Vec2(8, 8), Vec2(view.x - 8, 8), Vec2(8, view.y - 8), Vec2(view.x - 8, view.y - 8)]
        for c in corners where pick(c, snapshot: snapshot, view: view, orbit: orbit) == .empty {
            return c
        }
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

    /// A straight path of `steps` + 1 events from `a` to `b` (not clamped) at 0.05 s intervals from `time`, the end
    /// repeated 0.02 s later (the last move and the release at the same place).
    static func path(_ a: Vec2, _ b: Vec2, steps: Int, time: Double) -> [Step] {
        var result: [Step] = []
        var i: Int = 0
        var last: Vec2 = a
        var lastTime: Double = time
        while i <= steps {
            let t: Double = Double(i) / Double(steps)
            last = a + (b - a) * t
            lastTime = time + 0.05 * Double(i)
            result.append(Step(phase: i == 0 ? .began : .moved, point: last, time: lastTime))
            i += 1
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
        var index: Int = 0
        while index < steps.count {
            let s: Step = steps[index]
            outcome.actions += controller.handle(event(1, s.phase, s.point, s.time), viewSize: view, snapshot: snapshot)
            if index == 0 { outcome.state = controller.state }
            index += 1
        }
        return outcome
    }

    /// Two fingers (7 and 8) going down at `a` and `b`, moving their midpoint by `move` and lifting; returns the
    /// actions sent.
    static func twoFingers(_ controller: inout Controller, a: Vec2, b: Vec2, by move: Vec2, view: Vec2,
                           snapshot: Snapshot, time: Double) -> [Action] {
        let frame: Double = 1.0 / 60
        let evs: [PointerEvent] = [event(7, .began, a, time), event(8, .began, b, time + frame),
                                   event(7, .moved, a + move, time + 2 * frame),
                                   event(8, .moved, b + move, time + 3 * frame),
                                   event(7, .ended, a + move, time + 4 * frame),
                                   event(8, .ended, b + move, time + 5 * frame)]
        var actions: [Action] = []
        for e in evs {
            actions += controller.handle(e, viewSize: view, snapshot: snapshot)
        }
        return actions
    }

    /// Whether two orbits agree within 1e-9 radians.
    static func near(_ a: Orbit, _ b: Orbit) -> Bool {
        abs(a.yaw - b.yaw) < 1e-9 && abs(a.pitch - b.pitch) < 1e-9
    }

    /// `orbit` turned by a midpoint movement of `delta` in `view` (90° per width, 60° per height, pitch up for an
    /// upward movement), clamped to yaw ±35° and pitch −15° … 20° — computed here on its own.
    static func turned(_ orbit: Orbit, by delta: Vec2, view: Vec2) -> Orbit {
        let yawLimit: Double = 35.0 * Double.pi / 180
        let yaw: Double = orbit.yaw + delta.x / view.x * (Double.pi / 2)
        let pitch: Double = orbit.pitch - delta.y / view.y * (Double.pi / 3)
        return Orbit(yaw: min(max(yaw, -yawLimit), yawLimit),
                     pitch: min(max(pitch, -15.0 * Double.pi / 180), 20.0 * Double.pi / 180))
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

    /// The previewed peg written here on its own: `current` + the nearest whole number of 24-point steps (halves
    /// away from zero), clamped to 1 … 12.
    static func expectedPeg(_ current: Int, _ upward: Double) -> Int {
        let q: Double = upward / 24
        let magnitude: Double = (abs(q) + 0.5).rounded(.down)
        let steps: Double = q < 0 ? -magnitude : magnitude
        let raw: Double = Double(current) + steps
        return Int(min(max(raw, 1), 12))
    }

    /// What a one-finger script must send and the state after touch-down.
    struct Expectation {
        var actions: [Action]
        var state: Controller.State
    }

    /// The expectation of one-finger `steps` (the first a `.began`, the last an `.ended` or a `.cancelled`) on
    /// `snapshot` in `view` at `orbit`, written on its own from clarifications Q1 … Q4.
    static func expected(_ steps: [Step], snapshot: Snapshot, view: Vec2, orbit: Orbit) -> Expectation {
        let origin: Vec2 = steps[0].point
        let startTime: Double = steps[0].time
        let picked: HarmonicBridgesPick = pick(origin, snapshot: snapshot, view: view, orbit: orbit)
        let playing: Bool = snapshot.stage == .playing
        var result: Expectation = Expectation(actions: [], state: .idle)
        var string: Int? = nil
        var onTarget: Bool = false
        switch picked {
        case .string(let s):
            string = s
            result.state = .stringPress
        case .pip, .goal:
            onTarget = true
            result.state = .targetPress
        case .empty:
            break
        }
        var travel: Double = 0
        var dragging: Bool = false
        var shown: Int? = nil
        var index: Int = 1
        while index < steps.count {
            let s: Step = steps[index]
            index += 1
            if s.phase == .cancelled { break }
            travel = max(travel, (s.point - origin).length)
            if let k = string {
                let current: Int = snapshot.pegs[k]
                let tuning: Bool = playing && !snapshot.strings[k].locked
                if !dragging && travel >= 16 {
                    dragging = true
                    if !tuning { result.actions.append(.choose(string: k, peg: current)) }
                }
                if dragging && tuning {
                    let p: Int = expectedPeg(current, origin.y - s.point.y)
                    if p != shown {
                        shown = p
                        result.actions.append(.preview(string: k, peg: p))
                    }
                }
            }
            guard s.phase == .ended else { continue }
            let tap: Bool = !dragging && travel < 10 && s.time - startTime < 0.5
            if let k = string {
                let current: Int = snapshot.pegs[k]
                if dragging {
                    if playing && !snapshot.strings[k].locked, let p = shown, p != current {
                        result.actions.append(.tune(string: k, peg: p))
                    }
                } else if tap {
                    result.actions.append(.choose(string: k, peg: current))
                }
            } else if onTarget && tap && playing {
                result.actions.append(.test)
            }
        }
        return result
    }

    /// One seeded one-finger script of `kind` (0 … 7, 11) on `snapshot` in `view` at `orbit`, or nil without a
    /// target.
    static func script(_ kind: Int, snapshot: Snapshot, view: Vec2, orbit: Orbit, random: inout LCG) -> [Step]? {
        switch kind {
        case 0:   // a tap on a string
            guard let p = stringPoint(snapshot, view: view, orbit: orbit, random: &random) else { return nil }
            let q: Vec2 = p + Vec2(random.unit() * 6 - 3, random.unit() * 6 - 3)
            return [Step(phase: .began, point: p, time: 1),
                    Step(phase: .ended, point: q, time: 1.05 + 0.4 * random.unit())]
        case 1:   // a tap on a pip or the goal
            guard let p = targetPoint(snapshot, view: view, orbit: orbit, random: &random) else { return nil }
            return [Step(phase: .began, point: p, time: 1),
                    Step(phase: .ended, point: p, time: 1.05 + 0.4 * random.unit())]
        case 2:   // a single tap on empty space
            guard let e = emptyPoint(snapshot, view: view, orbit: orbit) else { return nil }
            return [Step(phase: .began, point: e, time: 1), Step(phase: .ended, point: e, time: 1.1)]
        case 3:   // a peg drag from a string, mostly up or down, up to 320 points either way
            guard let p = stringPoint(snapshot, view: view, orbit: orbit, random: &random) else { return nil }
            let rise: Double = (random.unit() * 2 - 1) * 320
            let side: Double = (random.unit() * 2 - 1) * 30
            return path(p, p + Vec2(side, -rise), steps: 2 + random.below(8), time: 1)
        case 4:   // a drag from a pip, the goal or empty space
            var start: Vec2? = random.unit() < 0.6 ? targetPoint(snapshot, view: view, orbit: orbit, random: &random)
                : emptyPoint(snapshot, view: view, orbit: orbit)
            if start == nil { start = emptyPoint(snapshot, view: view, orbit: orbit) }
            guard let p = start else { return nil }
            let angle: Double = random.unit() * 2 * Double.pi
            let length: Double = 20 + 200 * random.unit()
            return path(p, p + Vec2(cos(angle) * length, sin(angle) * length), steps: 3, time: 1)
        case 5:   // a short touch of 10 … 16 points from a string, a target or anywhere
            var p: Vec2 = inside(Vec2(view.x * random.unit(), view.y * random.unit()), view)
            let choice: Int = random.below(3)
            if choice == 0, let s = stringPoint(snapshot, view: view, orbit: orbit, random: &random) { p = s }
            if choice == 1, let t = targetPoint(snapshot, view: view, orbit: orbit, random: &random) { p = t }
            let angle: Double = random.unit() * 2 * Double.pi
            let length: Double = 10.5 + 5 * random.unit()
            return path(p, p + Vec2(cos(angle) * length, sin(angle) * length), steps: 2, time: 1)
        case 6:   // a slow press (lifted 0.5 … 1.0 s after touch-down) moving under 10 points
            var start: Vec2? = random.unit() < 0.5 ? stringPoint(snapshot, view: view, orbit: orbit, random: &random)
                : targetPoint(snapshot, view: view, orbit: orbit, random: &random)
            if start == nil { start = emptyPoint(snapshot, view: view, orbit: orbit) }
            guard let p = start else { return nil }
            let q: Vec2 = p + Vec2(random.unit() * 8 - 4, random.unit() * 8 - 4)
            let lift: Double = 1.5 + 0.5 * random.unit()
            return [Step(phase: .began, point: p, time: 1), Step(phase: .moved, point: q, time: 1.2),
                    Step(phase: .ended, point: q, time: lift)]
        case 7:   // a cancelled touch on a string or a target, perhaps dragged first
            var start: Vec2? = targetPoint(snapshot, view: view, orbit: orbit, random: &random)
            if random.unit() < 0.6 || start == nil {
                start = stringPoint(snapshot, view: view, orbit: orbit, random: &random)
            }
            guard let p = start else { return nil }
            let q: Vec2 = random.unit() < 0.4 ? p : p + Vec2(10, -70 * random.unit() - 20)
            return [Step(phase: .began, point: p, time: 1),
                    Step(phase: .moved, point: q, time: 1.05 + 0.3 * random.unit()),
                    Step(phase: .cancelled, point: q, time: 1.4)]
        default:  // a random touch, sometimes slow
            let p: Vec2 = inside(Vec2(view.x * random.unit(), view.y * random.unit()), view)
            let q: Vec2 = p + Vec2(random.unit() * 60 - 30, random.unit() * 60 - 30)
            let slow: Double = random.unit() < 0.3 ? 0.6 : 0
            var steps: [Step] = []
            for s in path(p, q, steps: 2, time: 1) {
                steps.append(Step(phase: s.phase, point: s.point, time: s.phase == .began ? s.time : s.time + slow))
            }
            return steps
        }
    }

    /// A seeded one-finger script of `kind` checked against its expectation; returns the actions sent, or nil when
    /// the script has no target here.
    static func oneFinger(_ kind: Int, _ controller: inout Controller, snapshot: Snapshot, view: Vec2, orbit: Orbit,
                          run: Int, random: inout LCG) -> [Action]? {
        guard let s = script(kind, snapshot: snapshot, view: view, orbit: orbit, random: &random) else { return nil }
        let got: Outcome = self.run(&controller, s, view: view, snapshot: snapshot)
        let want: Expectation = expected(s, snapshot: snapshot, view: view, orbit: orbit)
        #expect(got.actions == want.actions, "run \(run) kind \(kind)")
        #expect(got.state == want.state, "run \(run) kind \(kind)")
        if kind == 7 {
            for a in got.actions { #expect(!isKernel(a), "a cancelled touch sent \(a), run \(run)") }
        }
        if kind == 2 || kind == 5 || kind == 6 { #expect(got.actions.isEmpty, "run \(run) kind \(kind)") }
        #expect(controller.state == .idle)
        #expect(near(controller.orbit, orbit))
        return got.actions
    }

    /// A seeded second-finger script: the first finger on a string or a target (perhaps dragged first), a second
    /// finger cancels and orbits; nothing is sent from then on and the orbit turns by half the second finger's
    /// movement.
    static func secondFingerScript(_ controller: inout Controller, snapshot: Snapshot, view: Vec2, orbit: Orbit,
                                   run: Int, random: inout LCG) -> [Action]? {
        var start: Vec2? = nil
        if random.unit() < 0.3 { start = targetPoint(snapshot, view: view, orbit: orbit, random: &random) }
        if start == nil { start = stringPoint(snapshot, view: view, orbit: orbit, random: &random) }
        guard let p = start else { return nil }
        var before: [Action] = controller.handle(event(1, .began, p, 1), viewSize: view, snapshot: snapshot)
        var first: Vec2 = p
        if random.unit() < 0.5 {
            first = p + Vec2(5, -60)
            before += controller.handle(event(1, .moved, first, 1.05), viewSize: view, snapshot: snapshot)
        }
        for a in before { #expect(!isKernel(a), "second finger run \(run)") }
        let q: Vec2 = Vec2(view.x / 2, view.y / 2)
        var actions: [Action] = controller.handle(event(2, .began, q, 1.2), viewSize: view, snapshot: snapshot)
        #expect(controller.state == .orbiting, "second finger run \(run)")
        let move: Vec2 = Vec2((random.unit() - 0.5) * view.x * 0.6, (random.unit() - 0.5) * view.y * 0.6)
        actions += controller.handle(event(2, .moved, q + move, 1.25), viewSize: view, snapshot: snapshot)
        actions += controller.handle(event(1, .ended, first, 1.3), viewSize: view, snapshot: snapshot)
        #expect(controller.state == .cancelled)
        actions += controller.handle(event(2, .ended, q + move, 1.35), viewSize: view, snapshot: snapshot)
        #expect(controller.state == .idle)
        #expect(actions.isEmpty, "second finger run \(run)")
        #expect(near(controller.orbit, turned(orbit, by: move * 0.5, view: view)), "second finger run \(run)")
        return before + actions
    }

    /// A seeded double tap on empty space: `.resetView` and the authored orbit; nil without an empty corner.
    static func doubleTapScript(_ controller: inout Controller, snapshot: Snapshot, view: Vec2, orbit: Orbit, run: Int,
                                random: inout LCG) -> [Action]? {
        guard let e = emptyPoint(snapshot, view: view, orbit: orbit) else { return nil }
        let second: Vec2 = inside(e + Vec2(random.unit() * 10, random.unit() * 10), view)
        guard pick(second, snapshot: snapshot, view: view, orbit: orbit) == .empty else { return nil }
        let tap1: [Step] = [Step(phase: .began, point: e, time: 1), Step(phase: .ended, point: e, time: 1.05)]
        let tap2: [Step] = [Step(phase: .began, point: second, time: 1.2),
                            Step(phase: .ended, point: second, time: 1.25)]
        var actions: [Action] = self.run(&controller, tap1, view: view, snapshot: snapshot).actions
        #expect(actions.isEmpty)
        actions += self.run(&controller, tap2, view: view, snapshot: snapshot).actions
        #expect(actions == [.resetView], "double tap run \(run)")
        #expect(controller.orbit == .authored)
        return actions
    }

    /// A seeded `cancel()` in the middle of a press or a drag: the finger's later events send nothing.
    static func systemCancelScript(_ controller: inout Controller, snapshot: Snapshot, view: Vec2, orbit: Orbit,
                                   run: Int, random: inout LCG) -> [Action]? {
        guard let p = stringPoint(snapshot, view: view, orbit: orbit, random: &random) else { return nil }
        let q: Vec2 = random.unit() < 0.5 ? p : p + Vec2(0, -50)
        var actions: [Action] = controller.handle(event(1, .began, p, 1), viewSize: view, snapshot: snapshot)
        actions += controller.handle(event(1, .moved, q, 1.05), viewSize: view, snapshot: snapshot)
        for a in actions { #expect(!isKernel(a), "system cancel run \(run)") }
        controller.cancel()
        #expect(controller.state == .idle)
        let after: [Action] = controller.handle(event(1, .ended, q, 1.1), viewSize: view, snapshot: snapshot)
        #expect(after.isEmpty, "system cancel run \(run)")
        #expect(near(controller.orbit, orbit))
        return actions + after
    }

    /// The name of an action's case.
    static func name(_ a: Action) -> String {
        switch a {
        case .choose: return "choose"
        case .preview: return "preview"
        case .tune: return "tune"
        case .test: return "test"
        case .resetView: return "resetView"
        }
    }

    // MARK: Tests

    @Test func fiveHundredSeededScriptsMatchTheIndependentExpectation() throws {
        let all: [Case] = try Self.allCases()
        var digests: [String] = []
        for c in all {
            if let core = c.core { digests.append(try Self.digest(core)) } else { digests.append("") }
        }
        var random: LCG = LCG(seed: Self.seed)
        var run: Int = 0
        var attempts: Int = 0
        let kinds: Int = 12
        var counts: [Int] = Array(repeating: 0, count: kinds)
        var sent: [String: Int] = [:]
        var accepted: Int = 0
        var finished: Int = 0
        while run < 500 && attempts < 5_000 {
            attempts += 1
            let c: Case = all[random.below(all.count)]
            let view: Vec2 = Self.views[random.below(Self.views.count)]
            let nominal: Orbit = Self.orbits[random.below(Self.orbits.count)]
            let drawn: Snapshot = c.snapshot
            var controller: Controller = Self.controller(at: nominal, view: view, snapshot: drawn)
            // The expectation uses the orbit the controller reached (equal to the nominal one within 1e-9 radians).
            let orbit: Orbit = controller.orbit
            let kind: Int = random.below(kinds)
            var produced: [Action]?
            if kind == 8 {
                produced = Self.secondFingerScript(&controller, snapshot: drawn, view: view, orbit: orbit, run: run,
                                                   random: &random)
            } else if kind == 9 {
                produced = Self.doubleTapScript(&controller, snapshot: drawn, view: view, orbit: orbit, run: run,
                                                random: &random)
            } else if kind == 10 {
                produced = Self.systemCancelScript(&controller, snapshot: drawn, view: view, orbit: orbit, run: run,
                                                   random: &random)
            } else {
                produced = Self.oneFinger(kind, &controller, snapshot: drawn, view: view, orbit: orbit, run: run,
                                          random: &random)
            }
            guard let actions = produced else { continue }
            // Kernel actions only on playing cases; each accepted by the adapter and carried out.
            var copy: Core? = c.core
            for a in actions {
                sent[Self.name(a), default: 0] += 1
                guard let adapter = Self.adapterAction(a) else { continue }
                #expect(drawn.stage == .playing, "a kernel action outside playing, run \(run)")
                guard var core = copy else { continue }
                let spent: Int = core.play.actionsSpent
                let result: ActionResult = core.apply(adapter)
                #expect(result == .accepted, "adapter refused \(a): \(result), run \(run)")
                if result == .accepted { accepted += 1 }
                #expect(core.play.actionsSpent == spent + 1)
                if case let .tune(string, peg) = a { #expect(core.play.pegs[string] == peg) }
                if a == .test { #expect(core.play.stage == .won || core.play.stage == .failed) }
                copy = core
            }
            if drawn.stage != .playing {
                finished += 1
                for a in actions { #expect(!Self.isKernel(a), "run \(run)") }
            }
            counts[kind] += 1
            run += 1
        }
        #expect(run == 500)
        for k in 0..<kinds { #expect(counts[k] > 0, "script kind \(k) never ran") }
        for n in ["choose", "preview", "tune", "test", "resetView"] {
            #expect((sent[n] ?? 0) > 0, "\(n) never sent")
        }
        #expect(accepted > 20)
        #expect(finished > 100)
        var index: Int = 0
        while index < all.count {
            if let core = all[index].core { #expect(try Self.digest(core) == digests[index]) }
            index += 1
        }
    }

    @Test func previewRoundsHalvesAwayFromZeroAndClampsAtTheBounds() {
        let cases: [(current: Int, upward: Double, peg: Int)] = [
            (5, 0, 5), (5, 11.99, 5), (5, 12, 6), (5, 35.99, 6), (5, 36, 7), (5, -11.99, 5), (5, -12, 4),
            (5, -36, 3), (5, 24, 6), (5, -24, 4), (12, 24, 12), (12, 12, 12), (1, -24, 1), (1, -12, 1),
            (11, 1_000, 12), (2, -1_000, 1), (3, 1e300, 12), (3, -1e300, 1), (3, Double.nan, 3),
            (3, Double.infinity, 3), (6, 6 * 24, 12), (6, 7 * 24, 12), (7, -6 * 24, 1), (7, -7 * 24, 1),
        ]
        for c in cases {
            #expect(Controller.previewedPeg(current: c.current, upward: c.upward) == c.peg, "\(c)")
        }
        var upward: Double = -400
        while upward <= 400 {
            for current in 1...12 where upward.isFinite {
                #expect(Controller.previewedPeg(current: current, upward: upward) == Self.expectedPeg(current, upward))
            }
            upward += 0.5
        }
        #expect(Controller.tapDistance == 10 && Controller.dragDistance == 16 && Controller.tapDuration == 0.5)
        #expect(Controller.doubleTapWindow == 0.35 && Controller.doubleTapDistance == 22)
        #expect(Controller.pointsPerPeg == 24)
    }

    /// The locked hand-made case, a view and, at the authored orbit, a point picking string `index` (on the
    /// projected segment, searched from its middle) with room above and below.
    static func stringSetup(_ c: Case, string index: Int) throws -> (view: Vec2, point: Vec2) {
        let view: Vec2 = Vec2(1_024, 1_366)
        let s: Snapshot = c.snapshot
        let ends = Geometry.stringEnds(index, s)
        let a: Vec2 = try #require(screen(ends.a, snapshot: s, view: view, orbit: .authored))
        let b: Vec2 = try #require(screen(ends.b, snapshot: s, view: view, orbit: .authored))
        var step: Int = 0
        while step <= 30 {
            let t: Double = 0.5 + (step % 2 == 0 ? 1.0 : -1.0) * Double(step / 2) * 0.03
            let p: Vec2 = a + (b - a) * t
            if pick(p, snapshot: s, view: view, orbit: .authored) == .string(index) { return (view, p) }
            step += 1
        }
        Issue.record("no point on string \(index)")
        throw HarmonicBridgesError.stage
    }

    @Test func tapsAndShortTouchesAreToldApartByTravelAndTimestamps() throws {
        let c: Case = try Self.lockedCase()
        let setup = try Self.stringSetup(c, string: 0)
        let p: Vec2 = setup.point
        let s: Snapshot = c.snapshot
        let peg: Int = s.pegs[0]
        func play(_ steps: [Step]) -> [Action] {
            var controller: Controller = Controller()
            return Self.run(&controller, steps, view: setup.view, snapshot: s).actions
        }
        let lift: (Double, Vec2) -> [Step] = { time, end in
            [Step(phase: .began, point: p, time: 1), Step(phase: .ended, point: end, time: time)]
        }
        #expect(play(lift(1.49, p)) == [.choose(string: 0, peg: peg)])
        #expect(play(lift(1.5, p)).isEmpty)
        #expect(play(lift(1.2, p + Vec2(9.9, 0))) == [.choose(string: 0, peg: peg)])
        #expect(play(lift(1.2, p + Vec2(10, 0))).isEmpty)
        #expect(play(lift(1.2, p + Vec2(15.9, 0))).isEmpty)
        // A 16-point sideways release starts a drag at the release: preview at the current peg, no tune.
        #expect(play(lift(1.2, p + Vec2(16, 0))) == [.preview(string: 0, peg: peg)])
        // 16 points up: one peg up (16 / 24 rounds to 1), tuned on release.
        let oneUp: [Action] = [.preview(string: 0, peg: peg + 1), .tune(string: 0, peg: peg + 1)]
        #expect(play(lift(1.2, p + Vec2(0, -16))) == oneUp)
        // Moving 12 points and coming back is not a tap.
        let back: [Step] = [Step(phase: .began, point: p, time: 1),
                            Step(phase: .moved, point: p + Vec2(12, 0), time: 1.1),
                            Step(phase: .ended, point: p, time: 1.2)]
        #expect(play(back).isEmpty)
    }

    @Test func pegDragPreviewsEveryChangeAndTunesThroughTheAdapter() throws {
        let c: Case = try Self.lockedCase()
        let setup = try Self.stringSetup(c, string: 0)
        let p: Vec2 = setup.point
        let s: Snapshot = c.snapshot
        try #require(s.pegs[0] == 2 && !s.strings[0].locked)
        var controller: Controller = Controller()
        var got: [Action] = controller.handle(Self.event(1, .began, p, 1), viewSize: setup.view, snapshot: s)
        #expect(controller.state == .stringPress)
        let rises: [Double] = [8, 18, 30, 42, 54]
        var time: Double = 1
        for r in rises {
            time += 0.05
            got += controller.handle(Self.event(1, .moved, p + Vec2(0, -r), time), viewSize: setup.view, snapshot: s)
        }
        #expect(controller.state == .pegDrag)
        got += controller.handle(Self.event(1, .ended, p + Vec2(0, -54), time + 0.05), viewSize: setup.view,
                                 snapshot: s)
        #expect(got == [.preview(string: 0, peg: 3), .preview(string: 0, peg: 4), .tune(string: 0, peg: 4)])
        var core: Core = try #require(c.core)
        let before: String = try Self.digest(core)
        #expect(core.apply(try #require(Self.adapterAction(.tune(string: 0, peg: 4)))) == .accepted)
        #expect(core.play.pegs[0] == 4)
        #expect(try Self.digest(core) != before)
        // Up then back to the start: previews 3 then 2, nothing on release (the current peg).
        var again: Controller = Controller()
        var back: [Action] = again.handle(Self.event(1, .began, p, 1), viewSize: setup.view, snapshot: s)
        back += again.handle(Self.event(1, .moved, p + Vec2(0, -30), 1.1), viewSize: setup.view, snapshot: s)
        back += again.handle(Self.event(1, .moved, p, 1.2), viewSize: setup.view, snapshot: s)
        back += again.handle(Self.event(1, .ended, p, 1.3), viewSize: setup.view, snapshot: s)
        #expect(back == [.preview(string: 0, peg: 3), .preview(string: 0, peg: 2)])
        // Far down: clamped to peg 1 and tuned there.
        var down: Controller = Controller()
        var low: [Action] = down.handle(Self.event(1, .began, p, 1), viewSize: setup.view, snapshot: s)
        low += down.handle(Self.event(1, .moved, p + Vec2(0, 900), 1.1), viewSize: setup.view, snapshot: s)
        low += down.handle(Self.event(1, .ended, p + Vec2(0, 900), 1.2), viewSize: setup.view, snapshot: s)
        #expect(low == [.preview(string: 0, peg: 1), .tune(string: 0, peg: 1)])
        // Far up: clamped to peg 12.
        var up: Controller = Controller()
        var high: [Action] = up.handle(Self.event(1, .began, p, 1), viewSize: setup.view, snapshot: s)
        high += up.handle(Self.event(1, .moved, p + Vec2(0, -900), 1.1), viewSize: setup.view, snapshot: s)
        high += up.handle(Self.event(1, .ended, p + Vec2(0, -900), 1.2), viewSize: setup.view, snapshot: s)
        #expect(high == [.preview(string: 0, peg: 12), .tune(string: 0, peg: 12)])
    }

    @Test func lockedStringsAndFinishedPlaysOnlyChoose() throws {
        let c: Case = try Self.lockedCase()
        let s: Snapshot = c.snapshot
        let locked = try Self.stringSetup(c, string: 3)
        try #require(s.strings[3].locked)
        var controller: Controller = Controller()
        var got: [Action] = controller.handle(Self.event(1, .began, locked.point, 1), viewSize: locked.view,
                                              snapshot: s)
        got += controller.handle(Self.event(1, .moved, locked.point + Vec2(0, -40), 1.1), viewSize: locked.view,
                                 snapshot: s)
        got += controller.handle(Self.event(1, .moved, locked.point + Vec2(0, -90), 1.2), viewSize: locked.view,
                                 snapshot: s)
        got += controller.handle(Self.event(1, .ended, locked.point + Vec2(0, -90), 1.3), viewSize: locked.view,
                                 snapshot: s)
        #expect(got == [.choose(string: 3, peg: s.pegs[3])])
        // Level 1 won: a drag on a string chooses once; a tap on a pip sends nothing; playing, the same tap tests.
        let level: [Case] = try Self.cases(1)
        let playing: Case = level[0]
        let won: Case = level[3]
        try #require(won.snapshot.stage == .won)
        let ws = try Self.stringSetup(won, string: 0)
        var finished: Controller = Controller()
        var drag: [Action] = finished.handle(Self.event(1, .began, ws.point, 1), viewSize: ws.view,
                                             snapshot: won.snapshot)
        drag += finished.handle(Self.event(1, .moved, ws.point + Vec2(0, -60), 1.1), viewSize: ws.view,
                                snapshot: won.snapshot)
        drag += finished.handle(Self.event(1, .ended, ws.point + Vec2(0, -60), 1.2), viewSize: ws.view,
                                snapshot: won.snapshot)
        #expect(drag == [.choose(string: 0, peg: won.snapshot.pegs[0])])
        let pip: Vec2 = try #require(Self.screen(Geometry.stepPip(0, won.snapshot), snapshot: won.snapshot,
                                                 view: ws.view,
                                                 orbit: .authored))
        try #require(Self.pick(pip, snapshot: won.snapshot, view: ws.view, orbit: .authored) == .pip(0))
        let tap: [Step] = [Step(phase: .began, point: pip, time: 1), Step(phase: .ended, point: pip, time: 1.1)]
        var a: Controller = Controller()
        #expect(Self.run(&a, tap, view: ws.view, snapshot: won.snapshot).actions.isEmpty)
        var b: Controller = Controller()
        #expect(Self.run(&b, tap, view: ws.view, snapshot: playing.snapshot).actions == [.test])
        var core: Core = try #require(playing.core)
        #expect(core.apply(try #require(Self.adapterAction(.test))) == .accepted)
    }

    @Test func secondAndThirdFingersOrbitClampedAndSendNothing() throws {
        let c: Case = try Self.lockedCase()
        let s: Snapshot = c.snapshot
        let view: Vec2 = Self.views[1]
        var controller: Controller = Controller()
        let a: Vec2 = Vec2(300, 400)
        let b: Vec2 = Vec2(700, 400)
        var actions: [Action] = controller.handle(Self.event(1, .began, a, 1), viewSize: view, snapshot: s)
        actions += controller.handle(Self.event(2, .began, b, 1.01), viewSize: view, snapshot: s)
        #expect(controller.state == .orbiting)
        actions += controller.handle(Self.event(2, .moved, b + Vec2(100, -40), 1.02), viewSize: view, snapshot: s)
        var want: Orbit = Self.turned(.authored, by: Vec2(50, -20), view: view)
        #expect(Self.near(controller.orbit, want))
        // A third finger re-bases the midpoint: going down does not turn the camera.
        let third: Vec2 = Vec2(500, 700)
        actions += controller.handle(Self.event(3, .began, third, 1.03), viewSize: view, snapshot: s)
        #expect(Self.near(controller.orbit, want))
        actions += controller.handle(Self.event(3, .moved, third + Vec2(-90, 30), 1.04), viewSize: view, snapshot: s)
        want = Self.turned(want, by: Vec2(-30, 10), view: view)
        #expect(Self.near(controller.orbit, want))
        // A huge movement clamps at the limits.
        actions += controller.handle(Self.event(1, .moved, a + Vec2(90_000, 90_000), 1.05), viewSize: view, snapshot: s)
        #expect(Self.near(controller.orbit, Orbit(yaw: Orbit.yawLimit, pitch: Orbit.pitchRange.lowerBound)))
        actions += controller.handle(Self.event(1, .moved, a + Vec2(-90_000, -90_000), 1.06), viewSize: view,
                                     snapshot: s)
        #expect(Self.near(controller.orbit, Orbit(yaw: -Orbit.yawLimit, pitch: Orbit.pitchRange.upperBound)))
        actions += controller.handle(Self.event(1, .ended, a, 1.07), viewSize: view, snapshot: s)
        #expect(controller.state == .cancelled)
        actions += controller.handle(Self.event(2, .cancelled, b, 1.08), viewSize: view, snapshot: s)
        actions += controller.handle(Self.event(3, .ended, third, 1.09), viewSize: view, snapshot: s)
        #expect(controller.state == .idle)
        #expect(actions.isEmpty)
        let core: Core = try #require(c.core)
        let digest: String = try Self.digest(core)
        controller.resetView()
        #expect(controller.orbit == .authored)
        #expect(try Self.digest(core) == digest)
        #expect(controller.camera(viewSize: Vec2(0, 10), snapshot: s) == nil)
        #expect(controller.camera(viewSize: view, snapshot: s) == Geometry.camera(s, aspect: view.x / view.y))
    }

    @Test func doubleTapOnEmptySpaceResetsOnlyWithinTheWindowAndDistance() throws {
        let c: Case = try Self.lockedCase()
        let s: Snapshot = c.snapshot
        let view: Vec2 = Self.views[0]
        let orbit: Orbit = Self.orbits[1]
        let e: Vec2 = try #require(Self.emptyPoint(s, view: view, orbit: orbit))
        let f: Vec2 = Self.inside(e + Vec2(15, 15), view)
        try #require(Self.pick(f, snapshot: s, view: view, orbit: orbit) == .empty)
        func taps(_ second: Vec2, gap: Double) -> (actions: [Action], orbit: Orbit) {
            var controller: Controller = Self.controller(at: orbit, view: view, snapshot: s)
            let t1: [Step] = [Step(phase: .began, point: e, time: 1), Step(phase: .ended, point: e, time: 1.05)]
            let t2: [Step] = [Step(phase: .began, point: second, time: 1.05 + gap - 0.04),
                              Step(phase: .ended, point: second, time: 1.05 + gap)]
            var actions: [Action] = Self.run(&controller, t1, view: view, snapshot: s).actions
            actions += Self.run(&controller, t2, view: view, snapshot: s).actions
            return (actions, controller.orbit)
        }
        let reset = taps(f, gap: 0.34)
        #expect(reset.actions == [.resetView])
        #expect(reset.orbit == .authored)
        #expect(taps(f, gap: 0.36).actions.isEmpty)
        let far: Vec2 = Self.inside(e + Vec2(22.5, 0), view)
        if Self.pick(far, snapshot: s, view: view, orbit: orbit) == .empty {
            let missed = taps(far, gap: 0.2)
            #expect(missed.actions.isEmpty)
            #expect(Self.near(missed.orbit, orbit))
        }
    }
}
