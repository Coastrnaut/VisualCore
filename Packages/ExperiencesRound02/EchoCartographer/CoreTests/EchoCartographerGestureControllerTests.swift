// EchoCartographerGestureControllerTests — feature 404 (R02-G11-04) T-R02G1104-003 (FR-R02G1104-001 … 005, 007;
// SC-R02G1104-001 … 003; clarifications Q1 … Q4). 500 seeded (LCG seed 2_404) scripted gestures — taps on cells, on
// markers and on empty space, marker drags, cell drags, held presses (armed by `tick`, by a late move or by the lift
// timestamp), held presses that then move, touches of 10 … 16 points, random and slow touches, cancelled touches,
// second fingers and double taps on empty space — on certified levels 1, 21, 41, 61 and 81 (one action before their
// certified win with three markers placed, still playing; paused; won; showing the result) and a failed fixture level,
// at three view sizes and three orbits reached by two-finger drags, send exactly the actions an independent expectation
// written here predicts: what lies under the finger (the pick at touch-down and the floor cell at release) comes from
// `EchoCartographerPicker` (the geometry oracle, tested on its own), while the arbitration (tap, drag, held press or
// nothing by travel and event timestamps; the tap, drag and hold rules of clarifications Q2 and Q3; no kernel action
// outside playing; the orbit arithmetic) is computed here on its own. Every kernel action sent is on a playing case and
// is accepted by the adapter or refused with a rule code; second fingers, `.cancelled` phases, `cancel()` and
// non-playing stages send no kernel action; the orbit clamps and a third finger re-bases it; a double tap on empty space
// resets the view; the orbit never changes the adapter's digest. Plain loops and explicit types (CI type-check rule);
// each test well under 10 s once the levels are certified.
import Foundation
import Testing
import VisualCoreExperience
import VisualCoreMath
import VisualCoreScenes
import VisualCoreSimulation
@testable import EchoCartographerCore

@Suite struct EchoCartographerGestureControllerTests {
    typealias Controller = EchoCartographerGestureController
    typealias Snapshot = EchoCartographerSceneSnapshot
    typealias Action = EchoCartographerGestureAction
    typealias Geometry = EchoCartographerSceneGeometry
    typealias Picker = EchoCartographerPicker
    typealias Orbit = EchoCartographerOrbit
    typealias Core = EchoCartographerExperienceCore
    typealias Play = EchoCartographerPlay
    typealias Cell = EchoCartographerCell

    /// The seed of every random choice here.
    static let seed: UInt64 = 2_404
    /// The view sizes every script runs at: phone portrait, tablet landscape, tablet portrait.
    static let views: [Vec2] = [Vec2(390, 844), Vec2(1_180, 820), Vec2(1_024, 1_366)]
    /// The scripted orbits (the first is the authored one), reached by two-finger drags.
    static let orbits: [Orbit] = [.authored, Orbit(yaw: 0.3, pitch: 0.2), Orbit(yaw: -0.45, pitch: -0.15)]
    /// The certified levels used.
    static let levels: [Int] = [1, 21, 41, 61, 81]

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

    /// A core (for the digest and the adapter; nil for a case the adapter cannot reach), the play the controller sees
    /// and the level number.
    struct Case {
        let core: Core?
        let play: Play
        let number: Int
    }

    /// The adapter action of a kernel action.
    static func adapterAction(_ a: EchoCartographerAction) -> ExperienceAction {
        switch a {
        case let .pulse(x, y): return ExperienceAction(control: "cell.pulse", values: [Double(x), Double(y)], step: 0)
        case let .claim(x, y): return ExperienceAction(control: "cell.claim", values: [Double(x), Double(y)], step: 0)
        case let .mark(x, y): return ExperienceAction(control: "cell.mark", values: [Double(x), Double(y)], step: 0)
        }
    }

    /// The adapter action of a gesture's kernel action, or nil for presentation actions.
    static func adapterAction(_ a: Action) -> ExperienceAction? {
        switch a {
        case let .pulse(x, y): return adapterAction(EchoCartographerAction.pulse(x, y))
        case let .claim(x, y): return adapterAction(EchoCartographerAction.claim(x, y))
        case let .mark(x, y): return adapterAction(EchoCartographerAction.mark(x, y))
        case .moveCursor, .resetView: return nil
        }
    }

    /// Whether `a` is a kernel action (pulse, claim or mark).
    static func isKernel(_ a: Action) -> Bool { adapterAction(a) != nil }

    /// The digest of `core` as the engine computes it.
    static func digest(_ core: Core) throws -> String {
        var builder: DigestBuilder = DigestBuilder(domain: Core.experienceID)
        try core.writeDigest(into: &builder)
        return builder.finish().hex
    }

    /// Certified level `number`: one action before its certified win with three seeded markers placed (playing),
    /// the same paused, after the win (won) and showing the result.
    static func cases(_ number: Int) throws -> [Case] {
        let actions: [EchoCartographerAction] = Core.certifiedActions(number)
        try #require(!actions.isEmpty)
        var core: Core = try Core.opening(number: number)
        var index: Int = 0
        while index < actions.count - 1 {
            #expect(core.apply(adapterAction(actions[index])) == .accepted)
            index += 1
        }
        var random: LCG = LCG(seed: seed &+ UInt64(number))
        let width: Int = core.play.level.chamber.width
        let height: Int = core.play.level.chamber.height
        var placed: Int = 0
        var tries: Int = 0
        while placed < 3 && tries < 50 {
            tries += 1
            let cell: Cell = Cell(x: random.below(width), y: random.below(height))
            if core.play.markers.contains(cell) || actions[actions.count - 1].cell == cell { continue }
            #expect(core.apply(adapterAction(.mark(cell.x, cell.y))) == .accepted)
            placed += 1
        }
        #expect(core.play.stage == .playing && core.play.markers.count >= 3)
        let playing: Case = Case(core: core, play: core.play, number: number)
        var paused: Play = core.play
        try paused.handle(.pause)
        #expect(core.apply(adapterAction(actions[actions.count - 1])) == .accepted)
        #expect(core.play.stage == .won)
        let won: Case = Case(core: core, play: core.play, number: number)
        var shown: Play = core.play
        try shown.handle(.showResult)
        return [playing, Case(core: nil, play: paused, number: number), won, Case(core: nil, play: shown, number: number)]
    }

    /// A fixture level failed by its budget: one pulse from the entry spends the only energy (fixture seeds from 2_401).
    static func failedCase() throws -> Case {
        var seedValue: UInt64 = EchoCartographerFixtures.seed
        var tries: Int = 0
        while tries < 200 {
            let fixture: EchoCartographerFixture = EchoCartographerFixtures.fixture(seedValue)
            if fixture.level.energy == 1 {
                var play: Play = try Core.freshPlay(of: fixture.level)
                let entry: Cell = fixture.level.entry
                try play.apply(.pulse(entry.x, entry.y), expecting: play.fingerprint)
                #expect(play.stage == .failed)
                return Case(core: nil, play: play, number: 1)
            }
            seedValue += 1
            tries += 1
        }
        Issue.record("no fixture with energy 1")
        throw EchoCartographerError.stage
    }

    /// Every case: ``levels`` and the failed fixture.
    static func allCases() throws -> [Case] {
        var all: [Case] = []
        for number in levels { all += try cases(number) }
        all.append(try failedCase())
        return all
    }

    /// The snapshot of `c` at time 1 s.
    static func snapshot(_ c: Case) -> Snapshot { Snapshot(play: c.play, levelNumber: c.number, time: 1) }

    // MARK: Projection and targets

    /// The view point of `world` for `snapshot` in `view` at `orbit`, or nil behind the eye.
    static func screen(_ world: SIMD3<Double>, snapshot: Snapshot, view: Vec2, orbit: Orbit) -> Vec2? {
        let camera: EchoCartographerCamera = Geometry.camera(snapshot, aspect: view.x / view.y, orbit: orbit)
        guard let p = Geometry.project(world, camera: camera) else { return nil }
        return Vec2(p.x * view.x, p.y * view.y)
    }

    /// The pick of `point` (the oracle).
    static func pick(_ point: Vec2, snapshot: Snapshot, view: Vec2, orbit: Orbit) -> EchoCartographerPick {
        Picker.pick(SIMD2(point.x, point.y), size: SIMD2(view.x, view.y), snapshot: snapshot, orbit: orbit)
    }

    /// The chamber cell under `point` (the oracle).
    static func floorCell(_ point: Vec2, snapshot: Snapshot, view: Vec2, orbit: Orbit) -> Cell? {
        Picker.floorCell(SIMD2(point.x, point.y), size: SIMD2(view.x, view.y), snapshot: snapshot, orbit: orbit)
    }

    /// `p` kept one point inside `view`.
    static func inside(_ p: Vec2, _ view: Vec2) -> Vec2 {
        Vec2(min(max(p.x, 1), view.x - 1), min(max(p.y, 1), view.y - 1))
    }

    /// A point over `cell`, jittered up to 0.3 cells from its centre on the floor, projected and kept in the view.
    static func cellPoint(_ cell: Cell, snapshot: Snapshot, view: Vec2, orbit: Orbit, random: inout LCG) -> Vec2? {
        let s: Double = Geometry.cellSize(snapshot)
        let c: SIMD3<Double> = Geometry.cellCentre(cell, snapshot)
        let world: SIMD3<Double> = SIMD3(c.x + (random.unit() - 0.5) * 0.6 * s, 0, c.z + (random.unit() - 0.5) * 0.6 * s)
        guard let p = screen(world, snapshot: snapshot, view: view, orbit: orbit) else { return nil }
        return inside(p, view)
    }

    /// A seeded chamber cell: half the time a known-open one.
    static func someCell(_ snapshot: Snapshot, random: inout LCG) -> Cell {
        let open: [Cell] = snapshot.openCells
        if !open.isEmpty && random.unit() < 0.5 { return open[random.below(open.count)] }
        return Cell(x: random.below(snapshot.width), y: random.below(snapshot.height))
    }

    /// A point within 4 points of a seeded marker's projected ring centre, or nil without markers.
    static func markerPoint(_ snapshot: Snapshot, view: Vec2, orbit: Orbit, random: inout LCG) -> Vec2? {
        guard !snapshot.markers.isEmpty else { return nil }
        let index: Int = random.below(snapshot.markers.count)
        guard let p = screen(Geometry.markerCentre(index, snapshot), snapshot: snapshot, view: view, orbit: orbit) else {
            return nil
        }
        return inside(p + Vec2(random.unit() * 6 - 3, random.unit() * 6 - 3), view)
    }

    /// A point that picks nothing: the first of the view's corners (8 points in) that does.
    static func emptyPoint(_ snapshot: Snapshot, view: Vec2, orbit: Orbit) -> Vec2? {
        let corners: [Vec2] = [Vec2(8, 8), Vec2(view.x - 8, 8), Vec2(8, view.y - 8), Vec2(view.x - 8, view.y - 8)]
        for c in corners where pick(c, snapshot: snapshot, view: view, orbit: orbit) == .empty {
            return c
        }
        return nil
    }

    /// A seeded drag target: usually a seeded cell, sometimes a marker, sometimes a random point of the view.
    static func dragTarget(_ snapshot: Snapshot, view: Vec2, orbit: Orbit, random: inout LCG) -> Vec2? {
        let roll: Double = random.unit()
        if roll < 0.2 { return inside(Vec2(view.x * random.unit(), view.y * random.unit()), view) }
        if roll < 0.35, let m = markerPoint(snapshot, view: view, orbit: orbit, random: &random) { return m }
        return cellPoint(someCell(snapshot, random: &random), snapshot: snapshot, view: view, orbit: orbit,
                         random: &random)
    }

    // MARK: Scripting

    /// One step of a one-finger script: a pointer event of finger 1, or a `tick` at a time.
    enum Step {
        case event(PointerPhase, Vec2, Double)
        case tick(Double)
    }

    /// A pointer event.
    static func event(_ id: Int, _ phase: PointerPhase, _ point: Vec2, _ time: Double) -> PointerEvent {
        PointerEvent(id: id, phase: phase, location: point, timestamp: time)
    }

    /// A straight path of `steps` + 1 events from `a` to `b` (each kept inside the view) at 0.05 s intervals from
    /// `time`, the end repeated 0.02 s later (the last move and the release at the same place).
    static func path(_ a: Vec2, _ b: Vec2, steps: Int, view: Vec2, time: Double) -> [Step] {
        var result: [Step] = []
        var i: Int = 0
        var last: Vec2 = a
        var lastTime: Double = time
        while i <= steps {
            let t: Double = Double(i) / Double(steps)
            last = inside(a + (b - a) * t, view)
            lastTime = time + 0.05 * Double(i)
            result.append(.event(i == 0 ? .began : .moved, last, lastTime))
            i += 1
        }
        result.append(.event(.ended, last, lastTime + 0.02))
        return result
    }

    /// What a script produced: the actions, the state after touch-down and the state just before the last step.
    struct Outcome {
        var actions: [Action]
        var state: Controller.State
        var before: Controller.State
    }

    /// Feeds `steps` (finger 1) to `controller` for `snapshot` of `c` in `view`.
    static func run(_ controller: inout Controller, _ steps: [Step], view: Vec2, snapshot: Snapshot,
                    c: Case) -> Outcome {
        var outcome: Outcome = Outcome(actions: [], state: .idle, before: .idle)
        var index: Int = 0
        while index < steps.count {
            if index == steps.count - 1 { outcome.before = controller.state }
            switch steps[index] {
            case let .event(phase, point, time):
                outcome.actions += controller.handle(event(1, phase, point, time), viewSize: view, snapshot: snapshot,
                                                     play: c.play)
            case let .tick(time):
                controller.tick(at: time)
            }
            if index == 0 { outcome.state = controller.state }
            index += 1
        }
        return outcome
    }

    /// Two fingers (7 and 8) going down at `a` and `b`, moving their midpoint by `move` and lifting; returns the
    /// actions sent.
    static func twoFingers(_ controller: inout Controller, a: Vec2, b: Vec2, by move: Vec2, view: Vec2,
                           snapshot: Snapshot, c: Case, time: Double) -> [Action] {
        let frame: Double = 1.0 / 60
        let evs: [PointerEvent] = [event(7, .began, a, time), event(8, .began, b, time + frame),
                                   event(7, .moved, a + move, time + 2 * frame),
                                   event(8, .moved, b + move, time + 3 * frame),
                                   event(7, .ended, a + move, time + 4 * frame),
                                   event(8, .ended, b + move, time + 5 * frame)]
        var actions: [Action] = []
        for e in evs {
            actions += controller.handle(e, viewSize: view, snapshot: snapshot, play: c.play)
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

    /// A controller turned to `orbit` by a two-finger drag starting on empty space in `view`.
    static func controller(at orbit: Orbit, view: Vec2, snapshot: Snapshot, c: Case) throws -> Controller {
        var controller: Controller = Controller()
        let a: Vec2 = try #require(emptyPoint(snapshot, view: view, orbit: .authored))
        let b: Vec2 = Vec2(view.x / 2, view.y / 2)
        let move: Vec2 = Vec2(orbit.yaw / (Double.pi / 2) * view.x, -orbit.pitch / (Double.pi / 3) * view.y)
        let actions: [Action] = twoFingers(&controller, a: a, b: b, by: move, view: view, snapshot: snapshot, c: c,
                                           time: 0)
        #expect(actions.isEmpty)
        #expect(near(controller.orbit, orbit))
        #expect(controller.state == .idle)
        return controller
    }

    // MARK: Independent expectation

    /// What a one-finger script must send and the states it must pass.
    struct Expectation {
        var actions: [Action]
        var state: Controller.State
        /// Whether the press armed its claim before the last step.
        var armedBefore: Bool
    }

    /// The expectation of one-finger `steps` (the first a `.began`, the last an `.ended`, or a `.cancelled`) on case
    /// `c` with `snapshot` in `view` at `orbit`, written on its own from clarifications Q2 and Q3.
    static func expected(_ steps: [Step], c: Case, snapshot: Snapshot, view: Vec2, orbit: Orbit) -> Expectation {
        guard case let .event(_, origin, startTime) = steps[0] else {
            return Expectation(actions: [], state: .idle, armedBefore: false)
        }
        let picked: EchoCartographerPick = pick(origin, snapshot: snapshot, view: view, orbit: orbit)
        let playing: Bool = c.play.stage == .playing
        var pressed: Cell?
        var marker: Bool = false
        switch picked {
        case .marker(let m):
            pressed = m
            marker = true
        case .cell(let k):
            pressed = k
        case .empty:
            pressed = nil
        }
        var result: Expectation = Expectation(actions: [], state: pressed == nil ? .idle : .cellPress,
                                              armedBefore: false)
        var travel: Double = 0
        var armed: Bool = false
        var index: Int = 1
        while index < steps.count {
            if index == steps.count - 1 { result.armedBefore = armed }
            switch steps[index] {
            case let .tick(time):
                if pressed != nil && !armed && travel < 10 && time - startTime >= 0.5 { armed = true }
            case let .event(phase, point, time):
                if pressed != nil && !armed && travel < 10 && time - startTime >= 0.5 { armed = true }
                travel = max(travel, (point - origin).length)
                if phase == .ended, let cell = pressed {
                    if armed {
                        if travel < 10 && playing { result.actions = [.claim(cell.x, cell.y), .moveCursor(cell.x, cell.y)] }
                    } else if travel >= 16 {
                        let target: Cell? = floorCell(point, snapshot: snapshot, view: view, orbit: orbit)
                        if playing, let t = target, !snapshot.markers.contains(t) {
                            if marker && t != cell {
                                result.actions = [.mark(cell.x, cell.y), .mark(t.x, t.y), .moveCursor(t.x, t.y)]
                            } else if !marker {
                                result.actions = [.mark(t.x, t.y), .moveCursor(t.x, t.y)]
                            }
                        }
                    } else if travel < 10 && time - startTime < 0.5 {
                        if playing && snapshot.known(cell) == .open {
                            result.actions = [.pulse(cell.x, cell.y)]
                        } else {
                            result.actions = [.moveCursor(cell.x, cell.y)]
                        }
                    }
                }
            }
            index += 1
        }
        return result
    }

    /// One seeded one-finger script of `kind` (0 … 8) on `snapshot` in `view` at `orbit`, or nil without a target.
    static func script(_ kind: Int, snapshot: Snapshot, view: Vec2, orbit: Orbit, random: inout LCG) -> [Step]? {
        switch kind {
        case 0:   // a tap on a cell
            guard let p = cellPoint(someCell(snapshot, random: &random), snapshot: snapshot, view: view, orbit: orbit,
                                    random: &random) else { return nil }
            let q: Vec2 = inside(p + Vec2(random.unit() * 6 - 3, random.unit() * 6 - 3), view)
            return [.event(.began, p, 1), .event(.ended, q, 1.05 + 0.4 * random.unit())]
        case 1:   // a tap on a marker
            guard let p = markerPoint(snapshot, view: view, orbit: orbit, random: &random) else { return nil }
            return [.event(.began, p, 1), .event(.ended, p, 1.05 + 0.4 * random.unit())]
        case 2:   // a marker drag
            guard let p = markerPoint(snapshot, view: view, orbit: orbit, random: &random),
                  let q = dragTarget(snapshot, view: view, orbit: orbit, random: &random) else { return nil }
            return path(p, q, steps: 4, view: view, time: 1)
        case 3:   // a cell drag
            guard let p = cellPoint(someCell(snapshot, random: &random), snapshot: snapshot, view: view, orbit: orbit,
                                    random: &random),
                  let q = dragTarget(snapshot, view: view, orbit: orbit, random: &random) else { return nil }
            return path(p, q, steps: 4, view: view, time: 1)
        case 4:   // a held press on a cell or a marker: armed by a tick, a late small move or the lift itself
            var start: Vec2? = nil
            if random.unit() < 0.3 { start = markerPoint(snapshot, view: view, orbit: orbit, random: &random) }
            if start == nil {
                start = cellPoint(someCell(snapshot, random: &random), snapshot: snapshot, view: view, orbit: orbit,
                                  random: &random)
            }
            guard let p = start else { return nil }
            let hold: Double = 0.3 + 0.5 * random.unit()
            let how: Double = random.unit()
            var steps: [Step] = [.event(.began, p, 1)]
            if how < 0.4 {
                steps.append(.tick(1 + hold))
            } else if how < 0.7 {
                steps.append(.event(.moved, inside(p + Vec2(3, 2), view), 1 + hold))
            }
            let q: Vec2 = inside(p + Vec2(random.unit() * 4 - 2, random.unit() * 4 - 2), view)
            steps.append(.event(.ended, q, 1 + hold + 0.05))
            return steps
        case 5:   // a held press that moves 12 … 120 points after arming
            guard let p = cellPoint(someCell(snapshot, random: &random), snapshot: snapshot, view: view, orbit: orbit,
                                    random: &random) else { return nil }
            let hold: Double = 0.5 + 0.3 * random.unit()
            let angle: Double = random.unit() * 2 * Double.pi
            let length: Double = 12 + 108 * random.unit()
            let q: Vec2 = inside(p + Vec2(cos(angle) * length, sin(angle) * length), view)
            var steps: [Step] = [.event(.began, p, 1)]
            if random.unit() < 0.5 { steps.append(.tick(1 + hold)) }
            steps.append(.event(.moved, q, 1 + hold + 0.1))
            steps.append(.event(.ended, q, 1 + hold + 0.15))
            return steps
        case 6:   // a short touch of 10 … 16 points from a cell, a marker or anywhere
            var p: Vec2 = inside(Vec2(view.x * random.unit(), view.y * random.unit()), view)
            let choice: Int = random.below(3)
            if choice == 0, let m = markerPoint(snapshot, view: view, orbit: orbit, random: &random) { p = m }
            if choice == 1, let k = cellPoint(someCell(snapshot, random: &random), snapshot: snapshot, view: view,
                                              orbit: orbit, random: &random) { p = k }
            let angle: Double = random.unit() * 2 * Double.pi
            let length: Double = 10.5 + 5 * random.unit()
            let q: Vec2 = p + Vec2(cos(angle) * length, sin(angle) * length)
            guard q.x > 1, q.y > 1, q.x < view.x - 1, q.y < view.y - 1 else { return nil }
            return path(p, q, steps: 2, view: view, time: 1)
        case 7:   // a cancelled touch on a cell or a marker, perhaps dragged first
            var start: Vec2? = markerPoint(snapshot, view: view, orbit: orbit, random: &random)
            if random.unit() < 0.5 || start == nil {
                start = cellPoint(someCell(snapshot, random: &random), snapshot: snapshot, view: view, orbit: orbit,
                                  random: &random)
            }
            guard let p = start else { return nil }
            let q: Vec2 = random.unit() < 0.5 ? p : inside(p + Vec2(60, 40), view)
            return [.event(.began, p, 1), .event(.moved, q, 1.05 + 0.6 * random.unit()), .event(.cancelled, q, 1.7)]
        default:  // a random touch, sometimes slow
            let p: Vec2 = inside(Vec2(view.x * random.unit(), view.y * random.unit()), view)
            let q: Vec2 = p + Vec2(random.unit() * 60 - 30, random.unit() * 60 - 30)
            let slow: Double = random.unit() < 0.3 ? 0.6 : 0
            var steps: [Step] = []
            for s in path(p, q, steps: 2, view: view, time: 1) {
                if case let .event(phase, point, time) = s {
                    steps.append(.event(phase, point, phase == .began ? time : time + slow))
                }
            }
            return steps
        }
    }

    /// A seeded one-finger script of `kind` checked against its expectation; returns the actions sent, or nil when
    /// the script has no target here.
    static func oneFinger(_ kind: Int, _ controller: inout Controller, c: Case, snapshot: Snapshot, view: Vec2,
                          orbit: Orbit, run: Int, random: inout LCG) -> [Action]? {
        guard let s = script(kind, snapshot: snapshot, view: view, orbit: orbit, random: &random) else { return nil }
        let got: Outcome = self.run(&controller, s, view: view, snapshot: snapshot, c: c)
        var want: Expectation = expected(s, c: c, snapshot: snapshot, view: view, orbit: orbit)
        if kind == 7 { want.actions = [] }   // a `.cancelled` phase sends nothing
        #expect(got.actions == want.actions, "run \(run) kind \(kind)")
        #expect(got.state == want.state, "run \(run) kind \(kind)")
        if want.armedBefore { #expect(got.before == .held, "run \(run) kind \(kind)") }
        #expect(controller.state == .idle)
        #expect(near(controller.orbit, orbit))
        return got.actions
    }

    /// A seeded second-finger script: the first finger on a cell or a marker (perhaps dragged or armed first), a
    /// second finger cancels and orbits; nothing is sent and the orbit turns by half the second finger's movement.
    static func secondFingerScript(_ controller: inout Controller, c: Case, snapshot: Snapshot, view: Vec2,
                                   orbit: Orbit, run: Int, random: inout LCG) -> [Action]? {
        var start: Vec2? = nil
        if random.unit() < 0.4 { start = markerPoint(snapshot, view: view, orbit: orbit, random: &random) }
        if start == nil {
            start = cellPoint(someCell(snapshot, random: &random), snapshot: snapshot, view: view, orbit: orbit,
                              random: &random)
        }
        guard let p = start else { return nil }
        var actions: [Action] = controller.handle(event(1, .began, p, 1), viewSize: view, snapshot: snapshot,
                                                  play: c.play)
        var first: Vec2 = p
        let what: Double = random.unit()
        if what < 0.35 {
            first = inside(p + Vec2(80, 30), view)
            actions += controller.handle(event(1, .moved, first, 1.05), viewSize: view, snapshot: snapshot,
                                         play: c.play)
        } else if what < 0.7 {
            controller.tick(at: 1.6)
        }
        let q: Vec2 = Vec2(view.x / 2, view.y / 2)
        actions += controller.handle(event(2, .began, q, 1.7), viewSize: view, snapshot: snapshot, play: c.play)
        #expect(controller.state == .orbiting, "second finger run \(run)")
        let move: Vec2 = Vec2((random.unit() - 0.5) * view.x * 0.6, (random.unit() - 0.5) * view.y * 0.6)
        actions += controller.handle(event(2, .moved, q + move, 1.75), viewSize: view, snapshot: snapshot,
                                     play: c.play)
        actions += controller.handle(event(1, .ended, first, 1.8), viewSize: view, snapshot: snapshot, play: c.play)
        #expect(controller.state == .cancelled)
        actions += controller.handle(event(2, .ended, q + move, 1.85), viewSize: view, snapshot: snapshot,
                                     play: c.play)
        #expect(controller.state == .idle)
        #expect(actions.isEmpty, "second finger run \(run)")
        #expect(near(controller.orbit, turned(orbit, by: move * 0.5, view: view)), "second finger run \(run)")
        return actions
    }

    /// A seeded double tap on empty space: `.resetView` and the authored orbit; nil without an empty corner.
    static func doubleTapScript(_ controller: inout Controller, c: Case, snapshot: Snapshot, view: Vec2, orbit: Orbit,
                                run: Int, random: inout LCG) -> [Action]? {
        guard let e = emptyPoint(snapshot, view: view, orbit: orbit) else { return nil }
        let second: Vec2 = inside(e + Vec2(random.unit() * 10, random.unit() * 10), view)
        guard pick(second, snapshot: snapshot, view: view, orbit: orbit) == .empty else { return nil }
        let tap1: [Step] = [.event(.began, e, 1), .event(.ended, e, 1.05)]
        let tap2: [Step] = [.event(.began, second, 1.2), .event(.ended, second, 1.25)]
        var actions: [Action] = self.run(&controller, tap1, view: view, snapshot: snapshot, c: c).actions
        #expect(actions.isEmpty)
        actions += self.run(&controller, tap2, view: view, snapshot: snapshot, c: c).actions
        #expect(actions == [.resetView], "double tap run \(run)")
        #expect(controller.orbit == .authored)
        return actions
    }

    /// A seeded `cancel()` in the middle of a press or a drag: the finger's later events send nothing.
    static func systemCancelScript(_ controller: inout Controller, c: Case, snapshot: Snapshot, view: Vec2,
                                   orbit: Orbit, run: Int, random: inout LCG) -> [Action]? {
        guard let p = cellPoint(someCell(snapshot, random: &random), snapshot: snapshot, view: view, orbit: orbit,
                                random: &random) else { return nil }
        let q: Vec2 = random.unit() < 0.5 ? p : inside(p + Vec2(0, 50), view)
        var actions: [Action] = controller.handle(event(1, .began, p, 1), viewSize: view, snapshot: snapshot,
                                                  play: c.play)
        actions += controller.handle(event(1, .moved, q, 1.05), viewSize: view, snapshot: snapshot, play: c.play)
        controller.cancel()
        #expect(controller.state == .idle)
        actions += controller.handle(event(1, .ended, q, 1.1), viewSize: view, snapshot: snapshot, play: c.play)
        #expect(actions.isEmpty, "system cancel run \(run)")
        #expect(near(controller.orbit, orbit))
        return actions
    }

    /// The name of an action's case.
    static func name(_ a: Action) -> String {
        switch a {
        case .pulse: return "pulse"
        case .claim: return "claim"
        case .mark: return "mark"
        case .moveCursor: return "moveCursor"
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
        var nonPlaying: Int = 0
        while run < 500 && attempts < 5_000 {
            attempts += 1
            let c: Case = all[random.below(all.count)]
            let view: Vec2 = Self.views[random.below(Self.views.count)]
            let nominal: Orbit = Self.orbits[random.below(Self.orbits.count)]
            let drawn: Snapshot = Self.snapshot(c)
            var controller: Controller = try Self.controller(at: nominal, view: view, snapshot: drawn, c: c)
            // The expectation uses the orbit the controller reached (equal to the nominal one within 1e-9 radians).
            let orbit: Orbit = controller.orbit
            let kind: Int = random.below(kinds)
            var produced: [Action]?
            if kind == 9 {
                produced = Self.secondFingerScript(&controller, c: c, snapshot: drawn, view: view, orbit: orbit,
                                                   run: run, random: &random)
            } else if kind == 10 {
                produced = Self.doubleTapScript(&controller, c: c, snapshot: drawn, view: view, orbit: orbit,
                                                run: run, random: &random)
            } else if kind == 11 {
                produced = Self.systemCancelScript(&controller, c: c, snapshot: drawn, view: view, orbit: orbit,
                                                   run: run, random: &random)
            } else {
                produced = Self.oneFinger(kind, &controller, c: c, snapshot: drawn, view: view, orbit: orbit, run: run,
                                          random: &random)
            }
            guard let actions = produced else { continue }
            // Kernel actions only on playing cases; each accepted by the adapter or refused with a rule code.
            var copy: Core? = c.core
            for a in actions {
                sent[Self.name(a), default: 0] += 1
                guard let adapter = Self.adapterAction(a) else { continue }
                #expect(c.play.stage == .playing, "a kernel action outside playing, run \(run)")
                guard var core = copy else { continue }
                let result: ActionResult = core.apply(adapter)
                if result == .accepted {
                    accepted += 1
                } else if case .rejected(.rule) = result {
                    // Refused by the kernel with its reason code (a claim on a known wall, a ninth marker, …).
                } else {
                    Issue.record("unexpected adapter result \(result), run \(run)")
                }
                copy = core
            }
            if c.play.stage != .playing {
                nonPlaying += 1
                for a in actions { #expect(!Self.isKernel(a), "run \(run)") }
            }
            counts[kind] += 1
            run += 1
        }
        #expect(run == 500)
        for k in 0..<kinds { #expect(counts[k] > 0, "script kind \(k) never ran") }
        for n in ["pulse", "claim", "mark", "moveCursor", "resetView"] {
            #expect((sent[n] ?? 0) > 0, "\(n) never sent")
        }
        #expect(accepted > 5)
        #expect(nonPlaying > 100)
        var index: Int = 0
        while index < all.count {
            if let core = all[index].core { #expect(try Self.digest(core) == digests[index]) }
            index += 1
        }
    }

    /// The playing case of level 1, its snapshot, a view, and a still point over a cell without a marker.
    static func playingSetup() throws -> (c: Case, snapshot: Snapshot, view: Vec2, point: Vec2, cell: Cell) {
        let c: Case = try cases(levels[0])[0]
        let drawn: Snapshot = snapshot(c)
        let view: Vec2 = views[0]
        var y: Int = 0
        while y < drawn.height {
            var x: Int = 0
            while x < drawn.width {
                let cell: Cell = Cell(x: x, y: y)
                let centre: Vec2? = screen(Geometry.cellCentre(cell, drawn), snapshot: drawn, view: view,
                                           orbit: .authored)
                if let p = centre, pick(p, snapshot: drawn, view: view, orbit: .authored) == .cell(cell),
                   drawn.known(cell) != .open {
                    return (c, drawn, view, p, cell)
                }
                x += 1
            }
            y += 1
        }
        Issue.record("no still cell")
        throw EchoCartographerError.stage
    }

    @Test func tapAndHoldAreToldApartByTimestampsAndTickArmsTheClaim() throws {
        let setup = try Self.playingSetup()
        let c: Case = setup.c
        let p: Vec2 = setup.point
        let cell: Cell = setup.cell
        let claim: [Action] = [.claim(cell.x, cell.y), .moveCursor(cell.x, cell.y)]
        func send(_ ctl: inout Controller, _ e: PointerEvent) -> [Action] {
            ctl.handle(e, viewSize: setup.view, snapshot: setup.snapshot, play: c.play)
        }
        // Lifted before 0.5 s: a tap (the cell is not known open: the cursor moves).
        var controller: Controller = Controller()
        var actions: [Action] = send(&controller, Self.event(1, .began, p, 2))
        #expect(controller.state == .cellPress)
        actions += send(&controller, Self.event(1, .ended, p, 2.499))
        #expect(actions == [.moveCursor(cell.x, cell.y)])
        // Lifted at exactly 0.5 s: a held press, detected at the lift.
        controller = Controller()
        actions = send(&controller, Self.event(1, .began, p, 2))
        actions += send(&controller, Self.event(1, .ended, p, 2.5))
        #expect(actions == claim)
        // A tick before 0.5 s does nothing; at 0.5 s it arms.
        controller = Controller()
        actions = send(&controller, Self.event(1, .began, p, 2))
        controller.tick(at: 2.49)
        #expect(controller.state == .cellPress)
        controller.tick(at: 2.5)
        #expect(controller.state == .held)
        actions += send(&controller, Self.event(1, .moved, p + Vec2(9.9, 0), 2.6))
        actions += send(&controller, Self.event(1, .ended, p + Vec2(9.9, 0), 2.7))
        #expect(actions == claim)
        // Armed, then moved 10 points: cancelled, nothing.
        controller = Controller()
        actions = send(&controller, Self.event(1, .began, p, 2))
        controller.tick(at: 2.6)
        actions += send(&controller, Self.event(1, .moved, p + Vec2(0, 10), 2.7))
        actions += send(&controller, Self.event(1, .ended, p, 2.8))
        #expect(actions.isEmpty && controller.state == .idle)
        // Armed by a late still move, then lifted far (a would-be drag): nothing.
        controller = Controller()
        actions = send(&controller, Self.event(1, .began, p, 2))
        actions += send(&controller, Self.event(1, .moved, p + Vec2(2, 0), 2.55))
        #expect(controller.state == .held)
        actions += send(&controller, Self.event(1, .ended, p + Vec2(0, 80), 2.6))
        #expect(actions.isEmpty)
        // Not playing (paused): the held press sends nothing, the tap still moves the cursor.
        var paused: Play = c.play
        try paused.handle(.pause)
        controller = Controller()
        actions = controller.handle(Self.event(1, .began, p, 2), viewSize: setup.view, snapshot: setup.snapshot,
                                    play: paused)
        controller.tick(at: 3)
        actions += controller.handle(Self.event(1, .ended, p, 3.1), viewSize: setup.view, snapshot: setup.snapshot,
                                     play: paused)
        #expect(actions.isEmpty)
        actions = controller.handle(Self.event(1, .began, p, 4), viewSize: setup.view, snapshot: setup.snapshot,
                                    play: paused)
        actions += controller.handle(Self.event(1, .ended, p, 4.1), viewSize: setup.view, snapshot: setup.snapshot,
                                     play: paused)
        #expect(actions == [.moveCursor(cell.x, cell.y)])
        // A held press on empty space never arms and sends nothing.
        let empty: Vec2 = try #require(Self.emptyPoint(setup.snapshot, view: setup.view, orbit: .authored))
        controller = Controller()
        actions = send(&controller, Self.event(1, .began, empty, 5))
        controller.tick(at: 6)
        #expect(controller.state == .idle)
        actions += send(&controller, Self.event(1, .ended, empty, 6.1))
        #expect(actions.isEmpty)
    }

    @Test func tenToSixteenPointsSendNothing() throws {
        let all: [Case] = try Self.cases(Self.levels[1])
        let c: Case = all[0]
        let drawn: Snapshot = Self.snapshot(c)
        var random: LCG = LCG(seed: Self.seed &+ 7)
        for view in Self.views {
            var starts: [Vec2] = []
            if let m = Self.markerPoint(drawn, view: view, orbit: .authored, random: &random) { starts.append(m) }
            if let k = Self.cellPoint(drawn.entry, snapshot: drawn, view: view, orbit: .authored, random: &random) {
                starts.append(k)
            }
            if let e = Self.emptyPoint(drawn, view: view, orbit: .authored) { starts.append(e + Vec2(20, 20)) }
            #expect(starts.count == 3)
            for start in starts {
                for length in [10.0, 12.5, 15.9] {
                    for direction in [Vec2(1, 0), Vec2(0, 1), Vec2(-0.6, -0.8)] {
                        var controller: Controller = Controller()
                        let s: [Step] = Self.path(start, start + direction * length, steps: 3, view: view, time: 1)
                        let got: Outcome = Self.run(&controller, s, view: view, snapshot: drawn, c: c)
                        #expect(got.actions.isEmpty)
                        #expect(controller.orbit == .authored)
                    }
                }
            }
        }
    }

    @Test func secondFingersCancelsAndNonPlayingStagesSendNoKernelAction() throws {
        let level: [Case] = try Self.cases(Self.levels[2])
        let playing: Case = level[0]
        let view: Vec2 = Self.views[1]
        let drawn: Snapshot = Self.snapshot(playing)
        var random: LCG = LCG(seed: Self.seed &+ 11)
        let markerDown: Vec2 = try #require(Self.markerPoint(drawn, view: view, orbit: .authored, random: &random))
        guard case .marker = Self.pick(markerDown, snapshot: drawn, view: view, orbit: .authored) else {
            Issue.record("the marker point does not pick a marker")
            return
        }
        func send(_ ctl: inout Controller, _ e: PointerEvent, _ k: Case) -> [Action] {
            ctl.handle(e, viewSize: view, snapshot: drawn, play: k.play)
        }
        // A marker drag, then a second finger: an orbit, nothing sent.
        var controller: Controller = Controller()
        var actions: [Action] = send(&controller, Self.event(1, .began, markerDown, 1), playing)
        #expect(controller.state == .cellPress)
        actions += send(&controller, Self.event(1, .moved, markerDown + Vec2(0, 60), 1.1), playing)
        #expect(controller.state == .markerDrag)
        actions += send(&controller, Self.event(2, .began, Vec2(20, 20), 1.2), playing)
        #expect(controller.state == .orbiting)
        actions += send(&controller, Self.event(2, .cancelled, Vec2(20, 20), 1.3), playing)
        #expect(controller.state == .cancelled)
        actions += send(&controller, Self.event(1, .ended, markerDown + Vec2(0, 60), 1.4), playing)
        #expect(actions.isEmpty && controller.state == .idle)
        // A held press, then a second finger: nothing sent.
        controller = Controller()
        actions = send(&controller, Self.event(1, .began, markerDown, 2), playing)
        controller.tick(at: 2.6)
        #expect(controller.state == .held)
        actions += send(&controller, Self.event(2, .began, Vec2(20, 20), 2.7), playing)
        actions += send(&controller, Self.event(1, .ended, markerDown, 2.8), playing)
        actions += send(&controller, Self.event(2, .ended, Vec2(20, 20), 2.9), playing)
        #expect(actions.isEmpty && controller.state == .idle)
        // A `.cancelled` held press sends nothing.
        controller = Controller()
        actions = send(&controller, Self.event(1, .began, markerDown, 3), playing)
        controller.tick(at: 3.6)
        actions += send(&controller, Self.event(1, .cancelled, markerDown, 3.7), playing)
        #expect(actions.isEmpty && controller.state == .idle)
        // Every non-playing stage (paused, won, result, failed): a sweep of taps, drags and holds over the view sends
        // only cursor moves.
        var others: [Case] = Array(level.dropFirst())
        others.append(try Self.failedCase())
        for c in others {
            #expect(c.play.stage != .playing)
            let s: Snapshot = Self.snapshot(c)
            var gy: Double = 0.1
            while gy < 1 {
                var gx: Double = 0.1
                while gx < 1 {
                    let p: Vec2 = Vec2(view.x * gx, view.y * gy)
                    var ctl: Controller = Controller()
                    var got: [Action] = []
                    got += ctl.handle(Self.event(1, .began, p, 1), viewSize: view, snapshot: s, play: c.play)
                    got += ctl.handle(Self.event(1, .ended, p, 1.1), viewSize: view, snapshot: s, play: c.play)
                    got += ctl.handle(Self.event(1, .began, p, 2), viewSize: view, snapshot: s, play: c.play)
                    ctl.tick(at: 2.6)
                    got += ctl.handle(Self.event(1, .ended, p, 2.7), viewSize: view, snapshot: s, play: c.play)
                    got += ctl.handle(Self.event(1, .began, p, 3), viewSize: view, snapshot: s, play: c.play)
                    got += ctl.handle(Self.event(1, .moved, p + Vec2(40, 40), 3.1), viewSize: view, snapshot: s,
                                      play: c.play)
                    got += ctl.handle(Self.event(1, .ended, p + Vec2(40, 40), 3.2), viewSize: view, snapshot: s,
                                      play: c.play)
                    for a in got { #expect(!Self.isKernel(a), "\(c.play.stage)") }
                    var cursor: [Action] = []
                    if case .cell(let k) = Self.pick(p, snapshot: s, view: view, orbit: .authored) {
                        cursor = [.moveCursor(k.x, k.y)]
                    }
                    if case .marker(let k) = Self.pick(p, snapshot: s, view: view, orbit: .authored) {
                        cursor = [.moveCursor(k.x, k.y)]
                    }
                    #expect(got == cursor, "\(c.play.stage) at \(gx), \(gy)")
                    gx += 0.2
                }
                gy += 0.2
            }
        }
    }

    @Test func orbitClampsReBasesAndResets() throws {
        let c: Case = try Self.cases(Self.levels[0])[0]
        let drawn: Snapshot = Self.snapshot(c)
        let view: Vec2 = Self.views[2]
        func send(_ ctl: inout Controller, _ e: PointerEvent) -> [Action] {
            ctl.handle(e, viewSize: view, snapshot: drawn, play: c.play)
        }
        let yawLimit: Double = 35.0 * Double.pi / 180
        // A huge two-finger drag right and up clamps at +35° yaw and +20° pitch; left and down at −35° and −15°.
        var controller: Controller = Controller()
        var actions: [Action] = Self.twoFingers(&controller, a: Vec2(100, 100), b: Vec2(300, 300),
                                                by: Vec2(5_000, -5_000), view: view, snapshot: drawn, c: c, time: 0)
        #expect(abs(controller.orbit.yaw - yawLimit) < 1e-12)
        #expect(abs(controller.orbit.pitch - 20.0 * Double.pi / 180) < 1e-12)
        actions += Self.twoFingers(&controller, a: Vec2(100, 100), b: Vec2(300, 300), by: Vec2(-9_000, 9_000),
                                   view: view, snapshot: drawn, c: c, time: 1)
        #expect(abs(controller.orbit.yaw + yawLimit) < 1e-12)
        #expect(abs(controller.orbit.pitch + 15.0 * Double.pi / 180) < 1e-12)
        #expect(actions.isEmpty)
        // The drawn camera follows the orbit; an unusable view has none.
        let camera: EchoCartographerCamera? = controller.camera(viewSize: view, snapshot: drawn)
        #expect(camera == Geometry.camera(drawn, aspect: view.x / view.y, orbit: controller.orbit))
        #expect(controller.camera(viewSize: Vec2(0, 100), snapshot: drawn) == nil)
        // resetView() returns to the authored orbit.
        controller.resetView()
        #expect(controller.orbit == .authored)
        // A third finger re-bases the midpoint: its touch-down does not turn the camera.
        controller = Controller()
        actions = send(&controller, Self.event(1, .began, Vec2(100, 100), 0))
        actions += send(&controller, Self.event(2, .began, Vec2(300, 100), 0.01))
        actions += send(&controller, Self.event(2, .moved, Vec2(400, 100), 0.02))
        let afterTwo: Orbit = Self.turned(.authored, by: Vec2(50, 0), view: view)
        #expect(Self.near(controller.orbit, afterTwo))
        actions += send(&controller, Self.event(3, .began, Vec2(900, 1_200), 0.03))
        #expect(Self.near(controller.orbit, afterTwo))
        actions += send(&controller, Self.event(3, .moved, Vec2(900, 1_170), 0.04))
        #expect(Self.near(controller.orbit, Self.turned(afterTwo, by: Vec2(0, -10), view: view)))
        actions += send(&controller, Self.event(1, .ended, Vec2(100, 100), 0.05))
        #expect(controller.state == .cancelled)
        let held: Orbit = controller.orbit
        actions += send(&controller, Self.event(2, .moved, Vec2(600, 100), 0.06))
        #expect(controller.orbit == held)
        actions += send(&controller, Self.event(2, .ended, Vec2(600, 100), 0.07))
        actions += send(&controller, Self.event(3, .ended, Vec2(900, 1_170), 0.08))
        #expect(controller.state == .idle && actions.isEmpty)
        // The orbit never changes the adapter's digest.
        let core: Core = try #require(c.core)
        #expect(try Self.digest(core) == Self.digest(try #require(Self.cases(Self.levels[0])[0].core)))
    }

    @Test func doubleTapOnEmptySpaceResetsTheView() throws {
        let c: Case = try Self.cases(Self.levels[3])[2]
        let drawn: Snapshot = Self.snapshot(c)
        let view: Vec2 = Self.views[0]
        let orbit: Orbit = Self.orbits[1]
        let e: Vec2 = try #require(Self.emptyPoint(drawn, view: view, orbit: orbit))
        let step: Vec2 = e.x < view.x / 2 ? Vec2(1, 0) : Vec2(-1, 0)
        func taps(_ ctl: inout Controller, _ a: Vec2, _ t: Double) -> [Action] {
            var out: [Action] = ctl.handle(Self.event(1, .began, a, t), viewSize: view, snapshot: drawn, play: c.play)
            out += ctl.handle(Self.event(1, .ended, a, t + 0.05), viewSize: view, snapshot: drawn, play: c.play)
            return out
        }
        // Within 0.35 s and 22 points (on a won play: presentation still works).
        var controller: Controller = try Self.controller(at: orbit, view: view, snapshot: drawn, c: c)
        var actions: [Action] = taps(&controller, e, 1)
        actions += taps(&controller, e + step * 21, 1.3)
        #expect(actions == [.resetView] && controller.orbit == .authored)
        // Too late, too far, or after a non-tap: nothing.
        let second: [(Vec2, Double)] = [(e, 1.41), (e + step * 23, 1.2)]
        for (point, time) in second {
            controller = try Self.controller(at: orbit, view: view, snapshot: drawn, c: c)
            actions = taps(&controller, e, 1)
            actions += taps(&controller, point, time)
            #expect(actions.isEmpty && Self.near(controller.orbit, orbit))
        }
        controller = try Self.controller(at: orbit, view: view, snapshot: drawn, c: c)
        actions = taps(&controller, e, 1)
        actions += controller.handle(Self.event(1, .began, e, 1.1), viewSize: view, snapshot: drawn, play: c.play)
        actions += controller.handle(Self.event(1, .moved, e + step * 40, 1.15), viewSize: view, snapshot: drawn,
                                     play: c.play)
        actions += controller.handle(Self.event(1, .ended, e + step * 40, 1.2), viewSize: view, snapshot: drawn,
                                     play: c.play)
        actions += taps(&controller, e, 1.25)
        #expect(actions.isEmpty && Self.near(controller.orbit, orbit))
    }
}
