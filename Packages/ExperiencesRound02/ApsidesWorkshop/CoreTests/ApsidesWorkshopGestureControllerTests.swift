// ApsidesWorkshopGestureControllerTests — feature 474 (R02-G18-04) T-R02G1804-003 (FR-R02G1804-001 … 004, 006, 007;
// SC-R02G1804-001 … 003; clarifications Q1 … Q5). 500 seeded (SeededRandom seed 2_474) scripted gestures — taps on
// the orbiter, the orbit loop and the handles, one or two taps on empty space, crank drags, knob drags and size drags
// to seeded orbits (valid or not), drags out and back, touches of 10 … 16 points, slow presses, cancelled handle
// drags, random touches, drags from empty space, second fingers and system cancels — on certified levels 1, 41 and 90
// (`ApsidesWorkshopExperienceCore.opening(number:)` with a quarter period shown, so the orbiter sits on neither
// handle; the opening and the moment after the first certified tuning, both playing; won by the certified plan and
// the play; failed by playing the opening), at three view sizes and three orbits reached by two-finger drags, send
// exactly the actions an independent expectation written here predicts. What lies under the finger is asked of the
// picker's contract (`ApsidesWorkshopPicker.pick`, `crankTick`, `knobSteps`, `handleSize`), so the expectation stays
// valid for any picker that keeps it; the gesture semantics (tap, drag or nothing by travel and event timestamps; the
// crank's ticks from touch-down on; the pending orbit's changes on moves only; each turn to an invalid orbit explained
// once with its reason, written here from a(20 − k) ≥ 60 and a(20 + k) ≤ 1280; one tuning on release only when valid
// and different; double taps on empty space within 0.35 s and 22 points; no kernel action outside playing) are written
// here on their own. Every action is applied as the presenter would, through the adapter's
// `apply(ExperienceAction(control:values:step:))`: tunePeriapsis → `orbit.periapsis [k, d]` and tuneSize →
// `orbit.size [a]` (always accepted), showTick → `clock.show [tick]`, preview → the snapshot's `previewing(_:)`,
// clearPreview → the snapshot without a preview; only the tunings may change the digest. Also: thresholds at their
// edges, knob and size drags tuning once or explaining, crank drags showing every tick in any stage, invalid pending
// orbits explained with their reasons, and the second and third fingers' clamped orbit with the double-tap reset.
// Explicit types, plain loops; each test well under 10 s; no wall-clock asserts.
import Foundation
import Testing
import VisualCoreExperience
import VisualCoreMath
import VisualCoreScenes
import VisualCoreSimulation
@testable import ApsidesWorkshopCore

@Suite struct ApsidesWorkshopGestureControllerTests {
    typealias Controller = ApsidesWorkshopGestureController
    typealias Snapshot = ApsidesWorkshopSceneSnapshot
    typealias Action = ApsidesWorkshopGestureAction
    typealias ViewOrbit = ApsidesWorkshopViewOrbit
    typealias Orbit = ApsidesWorkshopOrbit
    typealias Core = ApsidesWorkshopExperienceCore
    typealias Pick = ApsidesWorkshopPick
    typealias P = ApsidesWorkshopPicker
    typealias G = ApsidesWorkshopSceneGeometry

    /// The seed of every random choice here.
    static let seed: UInt64 = 2_474
    /// The view sizes every script runs at: a phone upright, a phone on its side, a tablet.
    static let views: [Vec2] = [Vec2(390, 844), Vec2(844, 390), Vec2(1_024, 768)]
    /// The scripted orbits (the first is the authored one), reached by two-finger drags.
    static let orbits: [ViewOrbit] = [.authored, ViewOrbit(yaw: 0.6, pitch: 0.3), ViewOrbit(yaw: -0.9, pitch: -0.3)]
    /// The certified levels used.
    static let levels: [Int] = [1, 41, 90]
    /// The explanations, written here on their own.
    static let overText: String = "The play is over: undo or go to the next level"
    static let handleText: String = "Drag the knob or the size handle to tune the orbit"
    static let dipText: String = "The periapsis would dip into the star"
    static let leaveText: String = "The apoapsis would leave the sky"
    /// World units per lattice unit: 256 sky units of 0.9 / 16 384.
    static let lattice: Double = 256 * 0.9 / 16_384

    // MARK: Cases

    /// A core (for the digest and the adapter) and the snapshot the controller sees.
    struct Case {
        let core: Core
        let snapshot: Snapshot
    }

    /// A case of `core` with a quarter period shown, at presentation time 0.
    static func make(_ core: Core) -> Case {
        var shown: Core = core
        let quarter: Int = core.play.level.period / 4
        #expect(shown.apply(action("clock.show", [quarter])) == .accepted)
        return Case(core: shown, snapshot: shown.snapshot(time: 0))
    }

    /// An adapter action of `control` with whole `values`.
    static func action(_ control: String, _ values: [Int]) -> ExperienceAction {
        var doubles: [Double] = []
        for v in values { doubles.append(Double(v)) }
        return ExperienceAction(control: control, values: doubles, step: 0)
    }

    /// Whether `a` is a kernel action (a tuning).
    static func isKernel(_ a: Action) -> Bool {
        switch a {
        case .tunePeriapsis, .tuneSize: return true
        default: return false
        }
    }

    /// The digest of `core` as the engine computes it.
    static func digest(_ core: Core) throws -> StateDigest {
        var builder: DigestBuilder = DigestBuilder(domain: Core.experienceID)
        try core.writeDigest(into: &builder)
        return builder.finish()
    }

    /// Certified level `number`: the opening (playing), after the first certified tuning (playing, when the plan has
    /// two or more), after the whole certified plan and the play (won), and the opening played at once (failed).
    static func cases(_ number: Int) throws -> [Case] {
        let plan: [ApsidesWorkshopAction] = try Core.generated(number: number).plan.actions
        try #require(!plan.isEmpty)
        let opening: Core = try Core.opening(number: number)
        #expect(opening.play.stage == .playing)
        var result: [Case] = [make(opening)]
        var core: Core = opening
        for (index, tuning) in plan.enumerated() {
            switch tuning {
            case let .periapsis(k, d):
                #expect(core.apply(action("orbit.periapsis", [k, d])) == .accepted)
            case .size(let a):
                #expect(core.apply(action("orbit.size", [a])) == .accepted)
            case .play:
                Issue.record("a plan tuning is never the play")
            }
            if index == 0 && plan.count >= 2 {
                #expect(core.play.stage == .playing)
                result.append(make(core))
            }
        }
        #expect(core.apply(action("orbit.play", [])) == .accepted)
        #expect(core.play.stage == .won)
        result.append(make(core))
        var failed: Core = opening
        #expect(failed.apply(action("orbit.play", [])) == .accepted)
        try #require(failed.play.stage == .failed, "playing the opening of level \(number) did not fail")
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
    static func pick(_ p: Vec2, _ s: Snapshot, _ view: Vec2, _ orbit: ViewOrbit) -> Pick {
        P.pick(simd(p), size: simd(view), snapshot: s, orbit: orbit)
    }

    /// The tick the crank reads under `p`.
    static func tick(_ p: Vec2, _ s: Snapshot, _ view: Vec2, _ orbit: ViewOrbit) -> Int {
        P.crankTick(simd(p), size: simd(view), snapshot: s, orbit: orbit)
    }

    /// The pending orbit the knob (`knob` true) or the size handle reads under `p`, nil off the sky plane.
    static func read(_ p: Vec2, knob: Bool, _ s: Snapshot, _ view: Vec2, _ orbit: ViewOrbit) -> Orbit? {
        if knob { return P.knobSteps(simd(p), size: simd(view), snapshot: s, orbit: orbit) }
        return P.handleSize(simd(p), size: simd(view), snapshot: s, orbit: orbit)
    }

    /// Why `o` is invalid, written here on its own: the periapsis a(20 − k) below 60, the apoapsis a(20 + k) above
    /// 1280; nil when neither.
    static func reason(_ o: Orbit) -> String? {
        if o.size * (20 - o.eccentricity) < 60 { return dipText }
        if o.size * (20 + o.eccentricity) > 1280 { return leaveText }
        return nil
    }

    /// The projected view point of world point `w`.
    static func project(_ w: SIMD3<Double>, _ view: Vec2, _ orbit: ViewOrbit) -> Vec2? {
        let camera: ApsidesWorkshopCamera = G.camera(aspect: view.x / view.y, orbit: orbit)
        guard let p = P.viewPoint(w, size: simd(view), camera: camera) else { return nil }
        return vec(p)
    }

    /// The projected view point of the sky point at `radius` lattice units and `degrees` around the star.
    static func skyPoint(radius: Double, degrees: Double, _ view: Vec2, _ orbit: ViewOrbit) -> Vec2? {
        let a: Double = degrees * Double.pi / 180
        return project(SIMD3(radius * cos(a) * lattice, radius * sin(a) * lattice, 0), view, orbit)
    }

    /// The projected view point of tick `t`'s kernel position.
    static func tickPoint(_ t: Int, _ s: Snapshot, _ view: Vec2, _ orbit: ViewOrbit) -> Vec2? {
        project(G.world(s.positions[t], depth: G.planeZ), view, orbit)
    }

    /// A point near `centre` (its projection, else the nearest point of a 4-point grid within 16 points) that picks
    /// `wanted`.
    static func near(_ centre: Vec2?, _ s: Snapshot, _ view: Vec2, _ orbit: ViewOrbit, _ wanted: Pick) -> Vec2? {
        guard let c = centre else { return nil }
        if pick(c, s, view, orbit) == wanted { return c }
        var best: Vec2? = nil
        var bestDistance: Double = Double.infinity
        for a in -4...4 {
            for b in -4...4 {
                let p: Vec2 = c + Vec2(Double(a) * 4, Double(b) * 4)
                let d: Double = (p - c).length
                if d < bestDistance, pick(p, s, view, orbit) == wanted {
                    best = p
                    bestDistance = d
                }
            }
        }
        return best
    }

    /// A point that picks the orbiter, or nil.
    static func orbiterPoint(_ s: Snapshot, _ view: Vec2, _ orbit: ViewOrbit) -> Vec2? {
        near(project(G.orbiterCentre(s), view, orbit), s, view, orbit, .orbiter)
    }

    /// A point that picks the knob, or nil.
    static func knobPoint(_ s: Snapshot, _ view: Vec2, _ orbit: ViewOrbit) -> Vec2? {
        near(project(G.knobCentre(s), view, orbit), s, view, orbit, .knob)
    }

    /// A point that picks the size handle, or nil.
    static func handlePoint(_ s: Snapshot, _ view: Vec2, _ orbit: ViewOrbit) -> Vec2? {
        near(project(G.handleCentre(s), view, orbit), s, view, orbit, .sizeHandle)
    }

    /// A projected kernel position from a seeded tick on that picks the loop, or nil.
    static func loopPoint(_ s: Snapshot, _ view: Vec2, _ orbit: ViewOrbit, _ random: inout SeededRandom) -> Vec2? {
        let n: Int = s.positions.count
        let first: Int = below(n, &random)
        for i in 0..<n {
            guard let p = tickPoint((first + i) % n, s, view, orbit) else { continue }
            if pick(p, s, view, orbit) == .loop { return p }
        }
        return nil
    }

    /// A point that picks nothing: the first of the view's corners (8 points in) that does.
    static func emptyPoint(_ s: Snapshot, _ view: Vec2, _ orbit: ViewOrbit) -> Vec2? {
        let corners: [Vec2] = [Vec2(8, 8), Vec2(view.x - 8, 8), Vec2(8, view.y - 8), Vec2(view.x - 8, view.y - 8)]
        for c in corners where pick(c, s, view, orbit) == .empty { return c }
        return nil
    }

    /// The projected periapsis of the orbit of `s`'s size with steps `k` and `d`.
    static func knobTarget(_ k: Int, _ d: Int, _ s: Snapshot, _ view: Vec2, _ orbit: ViewOrbit) -> Vec2? {
        let r: Double = Double(s.orbit.size * (20 - k)) / 20
        return skyPoint(radius: r, degrees: Double(d) * 15, view, orbit)
    }

    /// The projected apoapsis of the orbit of `s`'s knob with size `a`.
    static func sizeTarget(_ a: Int, _ s: Snapshot, _ view: Vec2, _ orbit: ViewOrbit) -> Vec2? {
        let r: Double = Double(a * (20 + s.orbit.eccentricity)) / 20
        return skyPoint(radius: r, degrees: Double(s.orbit.direction) * 15 + 180, view, orbit)
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

    /// A seeded handle (the knob or the size handle) and a point that picks it.
    static func anyHandle(_ s: Snapshot, _ view: Vec2, _ orbit: ViewOrbit,
                          _ random: inout SeededRandom) -> (knob: Bool, point: Vec2)? {
        let knob: Bool = unit(&random) < 0.5
        let p: Vec2? = knob ? knobPoint(s, view, orbit) : handlePoint(s, view, orbit)
        guard let point = p else { return nil }
        return (knob, point)
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

    /// Whether two view orbits agree within 1e-9 radians.
    static func near(_ a: ViewOrbit, _ b: ViewOrbit) -> Bool {
        abs(a.yaw - b.yaw) < 1e-9 && abs(a.pitch - b.pitch) < 1e-9
    }

    /// `orbit` turned by a midpoint movement of `delta` in `view` (90° per width, 60° per height, pitch up for an
    /// upward movement), clamped to yaw ±60° and pitch −20° … 35° — computed here on its own.
    static func turned(_ orbit: ViewOrbit, by delta: Vec2, view: Vec2) -> ViewOrbit {
        let yawLimit: Double = 60.0 * Double.pi / 180
        let yaw: Double = orbit.yaw + delta.x / view.x * (Double.pi / 2)
        let pitch: Double = orbit.pitch - delta.y / view.y * (Double.pi / 3)
        return ViewOrbit(yaw: min(max(yaw, -yawLimit), yawLimit),
                         pitch: min(max(pitch, -20.0 * Double.pi / 180), 35.0 * Double.pi / 180))
    }

    /// A controller turned to `orbit` by a two-finger drag in `view`.
    static func controller(at orbit: ViewOrbit, view: Vec2, snapshot: Snapshot) -> Controller {
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
        var preview: Orbit? = nil
        var accepted: Int = 0

        /// The snapshot drawn now (previewing when a drag previews).
        var snapshot: Snapshot {
            let plain: Snapshot = core.snapshot(time: 0)
            guard let p = preview else { return plain }
            return plain.previewing(p)
        }

        /// Applies one tuning through the adapter and checks it was accepted, spent one action and set `wanted`.
        mutating func tune(_ control: String, _ values: [Int], wanted: Orbit, run: Int) {
            typealias T = ApsidesWorkshopGestureControllerTests
            let spent: Int = core.play.actionsSpent
            let result: ActionResult = core.apply(T.action(control, values))
            #expect(result == .accepted, "\(control) \(values) refused: \(result), run \(run)")
            if result == .accepted {
                accepted += 1
                #expect(core.play.orbit == wanted && core.play.actionsSpent == spent + 1, "run \(run)")
            }
            preview = nil
        }

        /// Applies gesture action `a` through the adapter and checks its effect (see the file header).
        mutating func apply(_ a: Action, run: Int) throws {
            typealias T = ApsidesWorkshopGestureControllerTests
            let before: StateDigest = try T.digest(core)
            let current: Orbit = core.play.orbit
            switch a {
            case let .tunePeriapsis(k, d):
                let wanted: Orbit = Orbit(size: current.size, eccentricity: k, direction: d)
                #expect(wanted.isValid && wanted != current, "run \(run)")
                tune("orbit.periapsis", [k, d], wanted: wanted, run: run)
                return
            case .tuneSize(let size):
                let wanted: Orbit = Orbit(size: size, eccentricity: current.eccentricity, direction: current.direction)
                #expect(wanted.isValid && wanted != current, "run \(run)")
                tune("orbit.size", [size], wanted: wanted, run: run)
                return
            case .showTick(let tick):
                #expect(core.apply(T.action("clock.show", [tick])) == .accepted, "run \(run)")
                #expect(core.shownTick == tick)
            case .preview(let orbit):
                #expect(orbit.isValid, "an invalid preview, run \(run)")
                preview = orbit
                #expect(snapshot.previewOrbit == orbit, "run \(run)")
            case .clearPreview:
                preview = nil
                #expect(!snapshot.isPreviewing)
            case .explain(let words):
                let known: [String] = [T.overText, T.handleText, T.dipText, T.leaveText]
                #expect(known.contains(words), "unknown explanation \(words), run \(run)")
            case .resetView:
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

    /// The expectation of one-finger `steps` (the first a `.began`, the last an `.ended` or a `.cancelled`) beginning
    /// on snapshot `s` in `view` at `orbit` after the double-tap candidate `record`, written on its own from
    /// clarifications Q1 … Q4 (the picker's contract says what lies under a point).
    static func expected(_ steps: [Step], _ s: Snapshot, _ view: Vec2, _ orbit: ViewOrbit,
                         record: inout TapRecord?) -> Expectation {
        let origin: Vec2 = steps[0].point
        let startTime: Double = steps[0].time
        let picked: Pick = pick(origin, s, view, orbit)
        var result: Expectation = Expectation()
        let handle: Bool = picked == .knob || picked == .sizeHandle
        let knob: Bool = picked == .knob
        switch picked {
        case .knob: result.state = .knobPress
        case .sizeHandle: result.state = .handlePress
        case .orbiter, .loop: result.state = .orbiterPress
        case .empty: result.state = .emptyPress
        }
        let playing: Bool = s.stage == .playing
        var travel: Double = 0
        var dragging: Bool = false
        var pending: Orbit? = nil
        var previewing: Bool = false
        var explained: String? = nil
        var lastTick: Int = tick(origin, s, view, orbit)
        var cranked: Bool = false
        for index in 1..<steps.count {
            let st: Step = steps[index]
            if st.phase == .cancelled {
                if previewing { result.actions.append(.clearPreview) }
                record = nil
                break
            }
            travel = max(travel, (st.point - origin).length)
            if picked == .orbiter {
                let t: Int = tick(st.point, s, view, orbit)
                if t != lastTick {
                    result.actions.append(.showTick(t))
                    lastTick = t
                    cranked = true
                }
            }
            if handle && !dragging && travel >= 16 {
                dragging = true
                if !playing { result.actions.append(.explain(overText)) }
            }
            if st.phase == .moved && dragging && playing,
               let o = read(st.point, knob: knob, s, view, orbit), o != pending {
                pending = o
                if let why = reason(o) {
                    if previewing { result.actions.append(.clearPreview) }
                    previewing = false
                    if why != explained {
                        result.actions.append(.explain(why))
                        explained = why
                    }
                } else {
                    result.actions.append(.preview(o))
                    previewing = true
                    explained = nil
                }
            }
            guard st.phase == .ended else { continue }
            let tap: Bool = !dragging && travel < 10 && st.time - startTime < 0.5
            switch picked {
            case .knob, .sizeHandle:
                record = nil
                if dragging && playing {
                    let o: Orbit? = read(st.point, knob: knob, s, view, orbit) ?? pending
                    if let w = o, reason(w) == nil, w != s.orbit {
                        if knob {
                            result.actions.append(.tunePeriapsis(eccentricity: w.eccentricity, direction: w.direction))
                        } else {
                            result.actions.append(.tuneSize(w.size))
                        }
                    } else {
                        result.actions.append(.clearPreview)
                    }
                } else if tap {
                    result.actions.append(.explain(handleText))
                }
            case .orbiter, .loop:
                record = nil
                if tap && !cranked { result.actions.append(.showTick(tick(st.point, s, view, orbit))) }
            case .empty:
                if !tap {
                    record = nil
                } else if let r = record, st.time - r.time <= 0.35, (st.point - r.point).length <= 22 {
                    result.actions.append(.resetView)
                    record = nil
                } else {
                    record = TapRecord(point: st.point, time: st.time)
                }
            }
        }
        return result
    }

    // MARK: Seeded scripts

    /// One seeded one-finger gesture (or two, for a double tap) of `kind` (0 … 12) on `s` in `view` at `orbit`, or nil
    /// without a target.
    static func scripts(_ kind: Int, _ s: Snapshot, _ view: Vec2, _ orbit: ViewOrbit,
                        _ random: inout SeededRandom) -> [[Step]]? {
        switch kind {
        case 0:   // a tap on the orbiter, sometimes slow
            guard let p = orbiterPoint(s, view, orbit) else { return nil }
            let q: Vec2 = p + Vec2(unit(&random) * 6 - 3, unit(&random) * 6 - 3)
            let lift: Double = unit(&random) < 0.2 ? 1.6 : 1.05 + 0.4 * unit(&random)
            return [[Step(phase: .began, point: p, time: 1), Step(phase: .ended, point: q, time: lift)]]
        case 1:   // a tap on the orbit loop
            guard let p = loopPoint(s, view, orbit, &random) else { return nil }
            return [[Step(phase: .began, point: p, time: 1), Step(phase: .ended, point: p, time: 1.08)]]
        case 2:   // one or two taps on empty space, sometimes too late or too far for a double tap
            guard let e = emptyPoint(s, view, orbit) else { return nil }
            let first: [Step] = [Step(phase: .began, point: e, time: 1), Step(phase: .ended, point: e, time: 1.05)]
            if unit(&random) < 0.3 { return [first] }
            let q: Vec2 = inside(e + Vec2(unit(&random) * 24 - 12, unit(&random) * 24 - 12), view)
            let gap: Double = 0.1 + 0.32 * unit(&random)
            return [first, [Step(phase: .began, point: q, time: 1.01 + gap),
                            Step(phase: .ended, point: q, time: 1.05 + gap)]]
        case 3:   // a crank drag from the orbiter to another tick, sometimes off the loop
            guard let p = orbiterPoint(s, view, orbit),
                  var q = tickPoint(below(s.positions.count, &random), s, view, orbit) else { return nil }
            if unit(&random) < 0.3 { q = inside(q + Vec2(unit(&random) * 160 - 80, unit(&random) * 120 - 60), view) }
            return [path(p, q, steps: 3 + below(5, &random), time: 1)]
        case 4:   // a knob drag to a seeded periapsis (valid or not)
            guard let p = knobPoint(s, view, orbit),
                  let q = knobTarget(below(16, &random), below(24, &random), s, view, orbit) else { return nil }
            return [path(p, q, steps: 3 + below(4, &random), time: 1)]
        case 5:   // a size drag to a seeded apoapsis (valid or not)
            guard let p = handlePoint(s, view, orbit),
                  let q = sizeTarget(8 + below(41, &random), s, view, orbit) else { return nil }
            return [path(p, q, steps: 3 + below(4, &random), time: 1)]
        case 6:   // a handle drag out to a seeded orbit and back to the handle or to anywhere
            guard let h = anyHandle(s, view, orbit, &random) else { return nil }
            let out: Vec2? = h.knob ? knobTarget(below(16, &random), below(24, &random), s, view, orbit)
                : sizeTarget(8 + below(41, &random), s, view, orbit)
            guard let o = out else { return nil }
            var back: Vec2 = h.point + Vec2(unit(&random) * 6 - 3, unit(&random) * 6 - 3)
            if unit(&random) < 0.3 { back = inside(Vec2(view.x * unit(&random), view.y * unit(&random)), view) }
            return [outAndBack(h.point, o, back, time: 1)]
        case 7:   // a short touch of 10 … 16 points from a handle or anywhere
            var p: Vec2 = inside(Vec2(view.x * unit(&random), view.y * unit(&random)), view)
            if unit(&random) < 0.7, let h = anyHandle(s, view, orbit, &random) { p = h.point }
            let a: Double = unit(&random) * 2 * Double.pi
            let length: Double = 10.5 + 5 * unit(&random)
            return [path(p, p + Vec2(cos(a) * length, sin(a) * length), steps: 2, time: 1)]
        case 8:   // a slow press (lifted 0.5 … 1.0 s after touch-down) moving under 10 points
            var start: Vec2? = anyHandle(s, view, orbit, &random)?.point
            let r: Double = unit(&random)
            if start == nil || r < 0.2 { start = emptyPoint(s, view, orbit) }
            if r > 0.8 { start = orbiterPoint(s, view, orbit) }
            guard let p = start else { return nil }
            let q: Vec2 = p + Vec2(unit(&random) * 8 - 4, unit(&random) * 8 - 4)
            return [[Step(phase: .began, point: p, time: 1), Step(phase: .moved, point: q, time: 1.2),
                     Step(phase: .ended, point: q, time: 1.5 + 0.5 * unit(&random))]]
        case 9:   // a cancelled handle drag, perhaps to a seeded orbit first
            guard let h = anyHandle(s, view, orbit, &random) else { return nil }
            var q: Vec2 = h.point
            let out: Vec2? = h.knob ? knobTarget(below(16, &random), below(24, &random), s, view, orbit)
                : sizeTarget(8 + below(41, &random), s, view, orbit)
            if unit(&random) < 0.7, let o = out { q = o }
            return [[Step(phase: .began, point: h.point, time: 1), Step(phase: .moved, point: q, time: 1.1),
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
        case 11:  // a drag from empty space
            guard let p = emptyPoint(s, view, orbit) else { return nil }
            let a: Double = unit(&random) * 2 * Double.pi
            let length: Double = 20 + 200 * unit(&random)
            return [path(p, inside(p + Vec2(cos(a) * length, sin(a) * length), view), steps: 3, time: 1)]
        default:  // a tap on a handle
            guard let h = anyHandle(s, view, orbit, &random) else { return nil }
            let q: Vec2 = h.point + Vec2(unit(&random) * 6 - 3, unit(&random) * 6 - 3)
            return [[Step(phase: .began, point: h.point, time: 1), Step(phase: .ended, point: q, time: 1.1)]]
        }
    }

    /// The script kinds that may send a tuning: knob, size and out-and-back drags.
    static let tuningKinds: Set<Int> = [4, 5, 6]

    /// A seeded one-finger script of `kind` checked against its expectation; nil when it has no target here.
    static func oneFinger(_ kind: Int, _ controller: inout Controller, _ presenter: inout Presenter, _ view: Vec2,
                          _ orbit: ViewOrbit, run: Int, _ random: inout SeededRandom) throws -> [Action]? {
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
        if !tuningKinds.contains(kind) {
            for a in produced where isKernel(a) { Issue.record("kind \(kind) sent \(a), run \(run)") }
        }
        #expect(near(controller.orbit, orbit) || produced.contains(.resetView))
        return produced
    }

    /// A seeded second-finger script: the first finger on a handle (perhaps dragged to a seeded orbit) or the orbiter,
    /// a second finger cancels (only `clearPreview` when a preview was showing) and orbits; nothing kernel is sent,
    /// nothing at all after the clearing value, and the orbit turns by half the second finger's movement.
    static func secondFinger(_ controller: inout Controller, _ presenter: inout Presenter, _ view: Vec2,
                             _ orbit: ViewOrbit, run: Int, _ random: inout SeededRandom) throws -> [Action]? {
        let s: Snapshot = presenter.snapshot
        var start: Vec2? = nil
        var knob: Bool? = nil
        if let h = anyHandle(s, view, orbit, &random) {
            start = h.point
            knob = h.knob
        }
        if unit(&random) < 0.3 {
            start = orbiterPoint(s, view, orbit)
            knob = nil
        }
        guard let p = start else { return nil }
        var first: Vec2 = p
        var steps: [Step] = [Step(phase: .began, point: p, time: 1)]
        if let k = knob, unit(&random) < 0.7 {
            let out: Vec2? = k ? knobTarget(below(16, &random), below(24, &random), s, view, orbit)
                : sizeTarget(8 + below(41, &random), s, view, orbit)
            if let o = out {
                first = o
                steps.append(Step(phase: .moved, point: first, time: 1.05))
            }
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
        let digestBefore: StateDigest = try digest(presenter.core)
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

    /// A seeded `cancel()` in the middle of a press or a handle drag: the finger's later events send nothing.
    static func systemCancel(_ controller: inout Controller, _ presenter: inout Presenter, _ view: Vec2,
                             _ orbit: ViewOrbit, run: Int, _ random: inout SeededRandom) throws -> [Action]? {
        let s: Snapshot = presenter.snapshot
        guard let h = anyHandle(s, view, orbit, &random) else { return nil }
        let q: Vec2 = unit(&random) < 0.4 ? h.point : inside(h.point + Vec2(40, -30), view)
        let steps: [Step] = [Step(phase: .began, point: h.point, time: 1), Step(phase: .moved, point: q, time: 1.05)]
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
        case .tunePeriapsis: return "tunePeriapsis"
        case .tuneSize: return "tuneSize"
        case .showTick: return "showTick"
        case .preview: return "preview"
        case .clearPreview: return "clearPreview"
        case .resetView: return "resetView"
        case .explain: return "explain"
        }
    }

    // MARK: Tests

    @Test func fiveHundredSeededScriptsMatchTheIndependentExpectation() throws {
        let all: [Case] = try Self.allCases()
        var digests: [StateDigest] = []
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
            let nominal: ViewOrbit = Self.orbits[Self.below(Self.orbits.count, &random)]
            var presenter: Presenter = Presenter(core: c.core)
            var controller: Controller = Self.controller(at: nominal, view: view, snapshot: presenter.snapshot)
            #expect(try Self.digest(presenter.core) == Self.digest(c.core), "orbit changed the digest")
            let orbit: ViewOrbit = controller.orbit
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
            #expect(presenter.accepted == kernel, "every tuning is accepted, run \(run)")
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
        let names: [String] = ["tunePeriapsis", "tuneSize", "showTick", "preview", "clearPreview", "resetView",
                               "explain"]
        for n in names { #expect((sent[n] ?? 0) > 0, "\(n) never sent: \(sent)") }
        #expect(stages == ["playing", "won", "failed"])
        #expect(accepted > 10, "\(accepted) tunings accepted")
        #expect(finished > 100)
        for index in all.indices { #expect(try Self.digest(all[index].core) == digests[index]) }
    }

    /// A valid orbit other than `s`'s that a knob (`knob` true) or size drag reads back exactly at its projected
    /// target, at least 30 points from the handle point, at the authored orbit in `view`; nil when none.
    static func dragTarget(_ s: Snapshot, _ view: Vec2, knob: Bool) -> (point: Vec2, orbit: Orbit, end: Vec2)? {
        let start: Vec2? = knob ? knobPoint(s, view, .authored) : handlePoint(s, view, .authored)
        guard let p = start else { return nil }
        var candidates: [Orbit] = []
        if knob {
            for k in 0...15 {
                for d in 0..<24 {
                    candidates.append(Orbit(size: s.orbit.size, eccentricity: k, direction: d))
                }
            }
        } else {
            for a in 8...48 {
                candidates.append(Orbit(size: a, eccentricity: s.orbit.eccentricity, direction: s.orbit.direction))
            }
        }
        for o in candidates where o.isValid && o != s.orbit {
            let end: Vec2? = knob ? knobTarget(o.eccentricity, o.direction, s, view, .authored)
                : sizeTarget(o.size, s, view, .authored)
            guard let q = end, (q - p).length >= 30, read(q, knob: knob, s, view, .authored) == o else { continue }
            return (p, o, q)
        }
        return nil
    }

    @Test func tapsAndThresholdsHoldAtTheirEdges() throws {
        let view: Vec2 = Self.views[2]
        let c: Case = try Self.cases(1)[0]
        let s: Snapshot = c.snapshot
        let p: Vec2 = try #require(Self.knobPoint(s, view, .authored))
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
        let words: [Action] = [.explain(Self.handleText)]
        // Taps on the knob: under 10 points, lifted before 0.5 s; 10 … 16 points and slow presses do nothing.
        #expect(play(tap(1, from: p, held: 0.49)) == words)
        #expect(play(tap(1, from: p, held: 0.5)).isEmpty)
        #expect(play(tap(1, from: p, lift: p + Vec2(0, 9.9))) == words)
        #expect(play(tap(1, from: p, lift: p + Vec2(0, 10))).isEmpty)
        #expect(play(tap(1, from: p, lift: p + Vec2(0, 15.9))).isEmpty)
        // A release 16 points away starts a drag: one tuning or a clearing value, never a preview.
        let o16: Orbit = try #require(Self.read(p + Vec2(16, 0), knob: true, s, view, .authored))
        let want16: [Action] = o16.isValid && o16 != s.orbit
            ? [.tunePeriapsis(eccentricity: o16.eccentricity, direction: o16.direction)] : [.clearPreview]
        #expect(play(tap(1, from: p, lift: p + Vec2(16, 0))) == want16)
        // The size handle explains a tap too.
        let h: Vec2 = try #require(Self.handlePoint(s, view, .authored))
        #expect(play(tap(1, from: h)) == words)
        // A tap on the orbiter shows the tick under the finger; a slow press does nothing.
        let r: Vec2 = try #require(Self.orbiterPoint(s, view, .authored))
        #expect(play(tap(1, from: r)) == [.showTick(Self.tick(r, s, view, .authored))])
        #expect(play(tap(1, from: r, held: 0.5)).isEmpty)
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
        // A completed double tap starts no new one; a slow first tap starts none; taps on the knob never reset.
        #expect(play(tap(1, from: e) + tap(1.2, from: e) + tap(1.4, from: e)) == [.resetView])
        #expect(play(tap(1, from: e, held: 0.6) + tap(1.8, from: e)).isEmpty)
        #expect(play(tap(1, from: p) + tap(1.2, from: p)) == words + words)
        #expect(Controller.tapDistance == 10 && Controller.dragDistance == 16 && Controller.tapDuration == 0.5)
        #expect(Controller.doubleTapWindow == 0.35 && Controller.doubleTapDistance == 22)
        #expect(Controller.finishedReason == Self.overText && Controller.handleReason == Self.handleText)
        #expect(Controller.dipReason == Self.dipText && Controller.leaveReason == Self.leaveText)
    }

    @Test func knobAndSizeDragsPreviewTuneOnceOrExplain() throws {
        let view: Vec2 = Self.views[1]
        var tunedKnob: Int = 0
        var tunedSize: Int = 0
        var over: Int = 0
        for number in Self.levels {
            for c in try Self.cases(number) {
                let s: Snapshot = c.snapshot
                for knob in [true, false] {
                    guard let t = Self.dragTarget(s, view, knob: knob) else { continue }
                    var controller: Controller = Controller()
                    var presenter: Presenter = Presenter(core: c.core)
                    let got = try Self.run(&controller, Self.path(t.point, t.end, steps: 6, time: 1), view: view,
                                           presenter: &presenter, run: -1)
                    #expect(got.state == (knob ? .knobPress : .handlePress))
                    if s.stage == .playing {
                        let last: Action = knob
                            ? .tunePeriapsis(eccentricity: t.orbit.eccentricity, direction: t.orbit.direction)
                            : .tuneSize(t.orbit.size)
                        #expect(got.actions.contains(.preview(t.orbit)), "\(got.actions)")
                        #expect(got.actions.last == last, "\(got.actions)")
                        #expect(presenter.accepted == 1 && presenter.core.play.orbit == t.orbit)
                        if knob { tunedKnob += 1 } else { tunedSize += 1 }
                        // Out to the target and back to the handle: previewed, then cleared; nothing sent.
                        var back: Controller = Controller()
                        var still: Presenter = Presenter(core: c.core)
                        let none: [Action] = try Self.run(&back, Self.outAndBack(t.point, t.end, t.point, time: 1),
                                                          view: view, presenter: &still, run: -1).actions
                        if Self.read(t.point, knob: knob, s, view, .authored) == s.orbit {
                            #expect(!none.contains { Self.isKernel($0) } && none.last == .clearPreview, "\(none)")
                            #expect(try Self.digest(still.core) == Self.digest(c.core))
                        }
                    } else {
                        #expect(got.actions == [.explain(Self.overText)], "\(got.actions)")
                        #expect(presenter.core.play == c.core.play)
                        over += 1
                    }
                    // 10 … 16 points from the handle: nothing.
                    var short: Controller = Controller()
                    var quiet: Presenter = Presenter(core: c.core)
                    let shortSteps: [Step] = Self.path(t.point, t.point + Vec2(0, 13), steps: 2, time: 1)
                    #expect(try Self.run(&short, shortSteps, view: view, presenter: &quiet, run: -1).actions.isEmpty)
                    // A cancelled drag clears its preview and sends nothing else.
                    var cancelled: Controller = Controller()
                    var cpres: Presenter = Presenter(core: c.core)
                    var steps: [Step] = Self.path(t.point, t.end, steps: 4, time: 1)
                    steps[steps.count - 1] = Step(phase: .cancelled, point: t.end, time: 1.2)
                    let gone: [Action] = try Self.run(&cancelled, steps, view: view, presenter: &cpres,
                                                      run: -1).actions
                    #expect(!gone.contains { Self.isKernel($0) })
                    if s.stage == .playing { #expect(gone.last == .clearPreview, "\(gone)") }
                    #expect(cpres.core.play == c.core.play)
                }
            }
        }
        #expect(tunedKnob > 0 && tunedSize > 0 && over > 0, "knob \(tunedKnob) size \(tunedSize) over \(over)")
    }

    /// A playing snapshot of a hand-made level on `orbit` (period 16, no planets, one full sweep target, budget 4).
    static func handSnapshot(_ orbit: Orbit) throws -> Snapshot {
        let level: ApsidesWorkshopLevel = try ApsidesWorkshopLevel(
            id: "gestures", seed: seed, difficulty: 1, period: 16, planets: [],
            targets: [ApsidesWorkshopTarget.sweep(sector: 0, low: 0, high: 1000)], orbit: orbit, budget: 4,
            tutorial: false, refusingAWin: false)
        var play: ApsidesWorkshopPlay = ApsidesWorkshopPlay(level: level)
        try play.handle(.begin)
        #expect(play.stage == .playing)
        return Snapshot(play: play, shownTick: 4, levelNumber: 1, time: 0)
    }

    @Test func invalidPendingOrbitsAreExplainedOncePerTurn() throws {
        let view: Vec2 = Self.views[2]
        // A small orbit: the knob dragged to the star dips the periapsis; back out, it previews; in again, it explains
        // again; released inside, it only clears.
        let small: Snapshot = try Self.handSnapshot(Orbit(size: 8, eccentricity: 0, direction: 0))
        let k: Vec2 = try #require(Self.knobPoint(small, view, .authored))
        let star: Vec2 = try #require(Self.skyPoint(radius: 0.5, degrees: 0, view, .authored))
        let valid: Vec2 = try #require(Self.knobTarget(4, 3, small, view, .authored))
        let validOrbit: Orbit = try #require(Self.read(valid, knob: true, small, view, .authored))
        try #require(validOrbit.isValid && validOrbit != small.orbit)
        let inner: Orbit = try #require(Self.read(star, knob: true, small, view, .authored))
        #expect(Self.reason(inner) == Self.dipText && Controller.invalidReason(inner) == Self.dipText)
        var controller: Controller = Controller()
        var actions: [Action] = []
        let points: [Vec2] = [k, star, star + Vec2(0.5, 0), valid, star]
        for (i, q) in points.enumerated() {
            let phase: PointerPhase = i == 0 ? .began : .moved
            actions += controller.handle(Self.event(1, phase, q, 1 + 0.03 * Double(i)), viewSize: view,
                                         snapshot: small)
        }
        actions += controller.handle(Self.event(1, .ended, star, 1.2), viewSize: view, snapshot: small)
        let want: [Action] = [.explain(Self.dipText), .preview(validOrbit), .clearPreview, .explain(Self.dipText),
                              .clearPreview]
        #expect(actions == want, "\(actions)")
        // A large orbit: the size handle dragged far out leaves the sky; the knob made eccentric too.
        let large: Snapshot = try Self.handSnapshot(Orbit(size: 40, eccentricity: 10, direction: 6))
        let h: Vec2 = try #require(Self.handlePoint(large, view, .authored))
        let far: Vec2 = try #require(Self.sizeTarget(48, large, view, .authored))
        let outer: Orbit = try #require(Self.read(far, knob: false, large, view, .authored))
        #expect(Self.reason(outer) == Self.leaveText && Controller.invalidReason(outer) == Self.leaveText)
        var sizing: Controller = Controller()
        var said: [Action] = []
        for (i, q) in [h, far, far + Vec2(0, 1)].enumerated() {
            let phase: PointerPhase = i == 0 ? .began : .moved
            said += sizing.handle(Self.event(1, phase, q, 1 + 0.03 * Double(i)), viewSize: view, snapshot: large)
        }
        said += sizing.handle(Self.event(1, .ended, far, 1.2), viewSize: view, snapshot: large)
        #expect(said == [.explain(Self.leaveText), .clearPreview], "\(said)")
        #expect(Controller.invalidReason(Orbit(size: 20, eccentricity: 5, direction: 0)) == nil)
    }

    @Test func crankDragsShowEveryTickInAnyStage() throws {
        let view: Vec2 = Self.views[0]
        var checked: Int = 0
        for number in Self.levels {
            for c in try Self.cases(number) {
                let s: Snapshot = c.snapshot
                let n: Int = s.positions.count
                guard let a = Self.project(G.orbiterCentre(s), view, .authored),
                      Self.pick(a, s, view, .authored) == .orbiter,
                      Self.tick(a, s, view, .authored) == s.shownTick else { continue }
                var steps: [Step] = [Step(phase: .began, point: a, time: 1)]
                var want: [Action] = []
                var time: Double = 1
                var last: Vec2 = a
                for i in 1..<n {
                    let t: Int = (s.shownTick + i) % n
                    guard let q = Self.tickPoint(t, s, view, .authored), Self.tick(q, s, view, .authored) == t else {
                        continue
                    }
                    time += 0.02
                    steps.append(Step(phase: .moved, point: q, time: time))
                    want.append(.showTick(t))
                    last = q
                }
                steps.append(Step(phase: .ended, point: last, time: time + 0.02))
                var controller: Controller = Controller()
                var presenter: Presenter = Presenter(core: c.core)
                let got = try Self.run(&controller, steps, view: view, presenter: &presenter, run: -1)
                #expect(got.state == .orbiterPress)
                #expect(got.actions == want, "level \(number) stage \(s.stage): \(got.actions)")
                #expect(want.count >= n / 2)
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
        let t = try #require(Self.dragTarget(s, view, knob: true))
        var controller: Controller = Controller()
        var actions: [Action] = controller.handle(Self.event(1, .began, t.point, 1), viewSize: view, snapshot: s)
        actions += controller.handle(Self.event(1, .moved, t.end, 1.05), viewSize: view, snapshot: s)
        #expect(controller.state == .knobDrag && actions == [.preview(t.orbit)])
        let b: Vec2 = Vec2(700, 300)
        #expect(controller.handle(Self.event(2, .began, b, 1.1), viewSize: view, snapshot: s) == [.clearPreview])
        #expect(controller.state == .orbiting)
        // The midpoint of fingers 1 and 2 moves by half of finger 2's movement.
        var orbit: ViewOrbit = .authored
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
        let camera: ApsidesWorkshopCamera = try #require(controller.camera(viewSize: view))
        #expect(camera == G.camera(aspect: view.x / view.y, orbit: controller.orbit))
        #expect(controller.camera(viewSize: Vec2(0, 100)) == nil)
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
        let authored: ApsidesWorkshopCamera = try #require(controller.camera(viewSize: view))
        #expect(authored == G.camera(aspect: view.x / view.y))
        // A system cancel mid-drag: later events of that finger send nothing.
        var cancelling: Controller = Controller()
        _ = cancelling.handle(Self.event(1, .began, t.point, 4), viewSize: view, snapshot: s)
        _ = cancelling.handle(Self.event(1, .moved, t.end, 4.05), viewSize: view, snapshot: s)
        cancelling.cancel()
        #expect(cancelling.state == .idle)
        #expect(cancelling.handle(Self.event(1, .ended, t.end, 4.1), viewSize: view, snapshot: s).isEmpty)
    }
}
