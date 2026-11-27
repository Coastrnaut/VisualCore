// MushroomWeatherGestureControllerTests — feature 494 (R02-G20-04) T-R02G2004-003 (FR-R02G2004-001 … 006, 008, 009;
// SC-R02G2004-001 … 003; clarifications Q1–Q5). 500 seeded (SeededRandom seed 2_494) scripted gestures — taps on empty
// sites, on pods, on vents, on the moon, on the scrubber, on the floor, one or two taps on empty space, scrub drags,
// pod drags to seeded sites, off the floor and out and back, moon drags up or down and out and back, touches of 10 … 16
// points, slow presses, cancelled pod and moon drags, random touches, drags from a site, a vent, the floor or empty
// space, second fingers and system cancels — on certified levels 1, 41 and 90 (the opening and the moment after the
// first certified action, both playing; every slot filled, playing; won by the certified plan and the run; failed by
// running the opening; each with a quarter of the run shown), at three view sizes and three orbits reached by
// two-finger drags, send exactly the actions an independent expectation written here predicts. What lies under the
// finger is asked of the picker's contract (`MushroomWeatherPicker.pick`, `dropTarget`, `scrubCycle`), so the
// expectation stays valid for any picker that keeps it; the moonlight level under the finger (clamp(start +
// round(−dy / 40), 0, 3)) and the gesture semantics (tap, drag or nothing by travel and event timestamps; the
// scrubber's cycles from touch-down on; a drag's change on moves only; one move, removal or moonlight change on release
// only for a change; a placement in the first free slot; a vent tap to the other state; double taps on empty space
// within 0.35 s and 22 points; no kernel action outside playing) are written here on their own. Every action is applied
// as the presenter would, through the adapter's `apply(ExperienceAction(control:values:step:))`: place and move →
// `pod.place [slot, row, column]`, remove → `pod.remove [slot]`, setVent → `vent.set [index, open]`, setMoonlight →
// `moon.set [level]` (each accepted while an action is left, else refused with the budget code), showCycle →
// `clock.show [cycle]`; the preview (drawn with `previewing(_:level:)`, which must accept every previewed change), the
// selected slot and the view are presenter state; only the kernel actions may change the digest. Also: thresholds at
// their edges, pod drags moving, removing, clearing or explaining, moon drags previewing and setting only a different
// level, scrub drags showing every cycle in any stage, full slots explained, and the second and third fingers' clamped
// orbit with the double-tap reset. Explicit types, plain loops; each test well under 10 s; no wall-clock asserts.
// Modelled on MicroscopicAuroraGestureControllerTests (feature 484).
import Foundation
import Testing
import VisualCoreDiagnostics
import VisualCoreExperience
import VisualCoreMath
import VisualCoreScenes
import VisualCoreSimulation
@testable import MushroomWeatherCore

@Suite struct MushroomWeatherGestureControllerTests {
    typealias Controller = MushroomWeatherGestureController
    typealias Snapshot = MushroomWeatherSceneSnapshot
    typealias Action = MushroomWeatherGestureAction
    typealias ViewOrbit = MushroomWeatherViewOrbit
    typealias Kind = MushroomWeatherPreviewKind
    typealias Core = MushroomWeatherExperienceCore
    typealias Pick = MushroomWeatherPick
    typealias Cell = MushroomWeatherCell
    typealias P = MushroomWeatherPicker
    typealias G = MushroomWeatherSceneGeometry

    /// The seed of every random choice here.
    static let seed: UInt64 = 2_494
    /// The view sizes every script runs at: a phone upright, a phone on its side, a tablet.
    static let views: [Vec2] = [Vec2(390, 844), Vec2(844, 390), Vec2(1_024, 768)]
    /// The scripted orbits (the first is the authored one), reached by two-finger drags.
    static let orbits: [ViewOrbit] = [.authored, ViewOrbit(yaw: 0.5, pitch: 0.3), ViewOrbit(yaw: -0.8, pitch: -0.25)]
    /// The certified levels used.
    static let levels: [Int] = [1, 41, 90]
    /// The explanations, written here on their own.
    static let overText: String = "The play is over: undo or go to the next level"
    static let podText: String = "Drag a pod to another site, or off the floor to remove it"
    static let fullText: String = "Every pod slot is used: drag a pod off the floor to free one"
    static let moonText: String = "Drag the moon up or down to change the moonlight"

    // MARK: Cases

    /// A core (for the digest and the adapter) and the snapshot the controller sees.
    struct Case {
        let core: Core
        let snapshot: Snapshot
    }

    /// An adapter action of `control` with whole `values`.
    static func action(_ control: String, _ values: [Int]) -> ExperienceAction {
        var doubles: [Double] = []
        for v in values { doubles.append(Double(v)) }
        return ExperienceAction(control: control, values: doubles, step: 0)
    }

    /// The adapter control and values of kernel action `a` (nil for the run).
    static func adapter(_ a: MushroomWeatherAction) -> (control: String, values: [Int])? {
        switch a {
        case let .place(slot, cell): return ("pod.place", [slot, cell.row, cell.column])
        case .remove(let slot): return ("pod.remove", [slot])
        case let .vent(index, open): return ("vent.set", [index, open ? 1 : 0])
        case .moonlight(let level): return ("moon.set", [level])
        case .run: return nil
        }
    }

    /// A case of `core` with a quarter of the run shown.
    static func make(_ core: Core) -> Case {
        var shown: Core = core
        let quarter: Int = core.play.report.cycles / 4
        #expect(shown.apply(action("clock.show", [quarter])) == .accepted)
        return Case(core: shown, snapshot: shown.snapshot(time: 0))
    }

    /// Whether `a` is a kernel action (a placement, move, removal, vent or moonlight change).
    static func isKernel(_ a: Action) -> Bool {
        switch a {
        case .place, .move, .remove, .setVent, .setMoonlight: return true
        default: return false
        }
    }

    /// The digest of `core` as the engine computes it.
    static func digest(_ core: Core) throws -> StateDigest {
        var builder: DigestBuilder = DigestBuilder(domain: Core.experienceID)
        try core.writeDigest(into: &builder)
        return builder.finish()
    }

    /// Certified level `number`: the opening (playing), after the first certified action (playing, when the plan has
    /// two or more), every slot filled (playing, when the sites and the budget allow), after the whole certified plan
    /// and the run (won), and the opening run at once (failed).
    static func cases(_ number: Int) throws -> [Case] {
        let plan: [MushroomWeatherAction] = try Core.generated(number: number).plan.actions
        try #require(!plan.isEmpty)
        let opening: Core = try Core.opening(number: number)
        #expect(opening.play.stage == .playing)
        var result: [Case] = [make(opening)]
        var core: Core = opening
        for (index, step) in plan.enumerated() {
            guard let a = adapter(step) else {
                Issue.record("a plan step is never the run")
                continue
            }
            #expect(core.apply(action(a.control, a.values)) == .accepted)
            if index == 0 && plan.count >= 2 {
                #expect(core.play.stage == .playing)
                result.append(make(core))
            }
        }
        #expect(core.apply(action("weather.run", [])) == .accepted)
        #expect(core.play.stage == .won)
        result.append(make(core))
        if let full = filled(opening) { result.append(make(full)) }
        var failed: Core = opening
        #expect(failed.apply(action("weather.run", [])) == .accepted)
        try #require(failed.play.stage == .failed, "running the opening of level \(number) did not fail")
        result.append(make(failed))
        return result
    }

    /// `opening` with every empty slot given a pod on a free site, or nil when the sites or the budget do not allow
    /// it.
    static func filled(_ opening: Core) -> Core? {
        var core: Core = opening
        let sites: [Cell] = core.play.level.sites ?? []
        for slot in core.play.arrangement.pods.indices where core.play.arrangement.pods[slot] == nil {
            var placed: Bool = false
            for cell in sites {
                var taken: Bool = false
                for pod in core.play.arrangement.pods where pod == cell { taken = true }
                if taken { continue }
                if core.apply(action("pod.place", [slot, cell.row, cell.column])) == .accepted {
                    placed = true
                    break
                }
            }
            if !placed { return nil }
        }
        return core.play.stage == .playing ? core : nil
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

    /// The cycle the scrubber reads under `p`.
    static func cycle(_ p: Vec2, _ s: Snapshot, _ view: Vec2, _ orbit: ViewOrbit) -> Int {
        P.scrubCycle(simd(p), size: simd(view), snapshot: s, orbit: orbit)
    }

    /// The drop target of slot `slot`'s pod under `p` (nil: no change).
    static func drop(_ p: Vec2, _ slot: Int, _ s: Snapshot, _ view: Vec2, _ orbit: ViewOrbit) -> Kind? {
        P.dropTarget(simd(p), slot: slot, size: simd(view), snapshot: s, orbit: orbit)
    }

    /// The moonlight level under the finger after vertical travel `dy` (view points, down positive) from `start`,
    /// computed here on its own: clamp(start + round(−dy / 40), 0, 3), halves away from zero.
    static func moonLevel(_ start: Int, _ dy: Double) -> Int {
        let steps: Double = (-dy / 40).rounded(.toNearestOrAwayFromZero)
        let level: Double = min(max(Double(start) + steps, 0), 3)
        return Int(level)
    }

    /// The projected view point of world point `w`.
    static func project(_ w: SIMD3<Double>, _ view: Vec2, _ orbit: ViewOrbit) -> Vec2? {
        let camera: MushroomWeatherCamera = G.camera(aspect: view.x / view.y, orbit: orbit)
        guard let p = P.viewPoint(w, size: simd(view), camera: camera) else { return nil }
        return vec(p)
    }

    /// A point near `centre` (itself, else the nearest point of a 4-point grid within 16 points) that picks `wanted`.
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

    /// Whether site `index` of `s` holds a pod.
    static func occupied(_ index: Int, _ s: Snapshot) -> Bool {
        for pod in s.pods where pod == s.sites[index] { return true }
        return false
    }

    /// A seeded site free of pods and a point that picks it, or nil.
    static func emptySite(_ s: Snapshot, _ view: Vec2, _ orbit: ViewOrbit,
                          _ random: inout SeededRandom) -> (index: Int, point: Vec2)? {
        let n: Int = s.sites.count
        guard n > 0 else { return nil }
        let first: Int = below(n, &random)
        for i in 0..<n {
            let index: Int = (first + i) % n
            if occupied(index, s) { continue }
            if let p = near(project(G.siteCentre(index, s), view, orbit), s, view, orbit, .site(index)) {
                return (index, p)
            }
        }
        return nil
    }

    /// A seeded slot holding a pod and a point that picks it, or nil.
    static func podPoint(_ s: Snapshot, _ view: Vec2, _ orbit: ViewOrbit,
                         _ random: inout SeededRandom) -> (slot: Int, point: Vec2)? {
        let n: Int = s.pods.count
        guard n > 0 else { return nil }
        let first: Int = below(n, &random)
        for i in 0..<n {
            let slot: Int = (first + i) % n
            guard let centre = G.podCentre(slot, s) else { continue }
            if let p = near(project(centre, view, orbit), s, view, orbit, .pod(slot)) { return (slot, p) }
        }
        return nil
    }

    /// A seeded vent and a point that picks it, or nil.
    static func ventPoint(_ s: Snapshot, _ view: Vec2, _ orbit: ViewOrbit,
                          _ random: inout SeededRandom) -> (index: Int, point: Vec2)? {
        let n: Int = s.vents.count
        guard n > 0 else { return nil }
        let first: Int = below(n, &random)
        for i in 0..<n {
            let index: Int = (first + i) % n
            if let p = near(project(G.ventCentre(index, s), view, orbit), s, view, orbit, .vent(index)) {
                return (index, p)
            }
        }
        return nil
    }

    /// A point that picks the moon, or nil.
    static func moonPoint(_ s: Snapshot, _ view: Vec2, _ orbit: ViewOrbit) -> Vec2? {
        near(project(G.moonCentre(), view, orbit), s, view, orbit, .moon)
    }

    /// A point on the scrubber at `fraction` that picks it, or nil.
    static func scrubPoint(_ fraction: Double, _ s: Snapshot, _ view: Vec2, _ orbit: ViewOrbit) -> Vec2? {
        near(project(G.scrubberPoint(fraction), view, orbit), s, view, orbit, .scrubber)
    }

    /// A seeded point of the floor away from every other target, or nil.
    static func floorPoint(_ s: Snapshot, _ view: Vec2, _ orbit: ViewOrbit, _ random: inout SeededRandom) -> Vec2? {
        let half: SIMD2<Double> = G.floorHalf(s)
        for _ in 0..<40 {
            let x: Double = (unit(&random) * 2 - 1) * half.x * 0.95
            let y: Double = (unit(&random) * 2 - 1) * half.y * 0.95
            guard let p = project(SIMD3(x, y, 0), view, orbit) else { continue }
            if pick(p, s, view, orbit) == .floor { return p }
        }
        return nil
    }

    /// A point that picks nothing: the first of the view's corners (8 points in) that does.
    static func emptyPoint(_ s: Snapshot, _ view: Vec2, _ orbit: ViewOrbit) -> Vec2? {
        let corners: [Vec2] = [Vec2(8, 8), Vec2(view.x - 8, 8), Vec2(8, view.y - 8), Vec2(view.x - 8, view.y - 8)]
        for c in corners where pick(c, s, view, orbit) == .empty { return c }
        return nil
    }

    /// The projected centre of a seeded site (any: free, the dragged pod's own or another's), or nil.
    static func siteTarget(_ s: Snapshot, _ view: Vec2, _ orbit: ViewOrbit, _ random: inout SeededRandom) -> Vec2? {
        guard !s.sites.isEmpty else { return nil }
        return project(G.siteCentre(below(s.sites.count, &random), s), view, orbit)
    }

    /// A seeded point off the floor: beyond the floor rectangle in the upper half or at its sides (kept in the view),
    /// or a top corner.
    static func offFloor(_ s: Snapshot, _ view: Vec2, _ orbit: ViewOrbit, _ random: inout SeededRandom) -> Vec2 {
        let half: SIMD2<Double> = G.floorHalf(s)
        let a: Double = (0.1 * unit(&random) + 0.8 * unit(&random)) * Double.pi
        let grow: Double = 1.35 + 0.15 * unit(&random)
        let w: SIMD3<Double> = SIMD3(half.x * grow * cos(a), half.y * grow * sin(a), 0)
        if unit(&random) < 0.7, let p = project(w, view, orbit) { return inside(p, view) }
        let corners: [Vec2] = [Vec2(4, 4), Vec2(view.x - 4, 4)]
        return corners[below(2, &random)]
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

    /// A tap: down at `p` at `time`, up at `lift` (default `p`) `held` seconds later.
    static func tap(_ p: Vec2, at time: Double, lift: Vec2? = nil, held: Double = 0.05) -> [Step] {
        [Step(phase: .began, point: p, time: time), Step(phase: .ended, point: lift ?? p, time: time + held)]
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

    /// `orbit` turned by a midpoint movement of `delta` in `view` (90° per width, 60° per height, yaw up for a
    /// rightward movement, pitch up for an upward one), clamped to yaw ±60° and pitch −20° … 35° — computed here on its
    /// own.
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

    /// The presenter's side: the core every action is applied to, the drawn snapshot (rebuilt after a kernel action or
    /// a shown cycle; a preview draws it with `previewing(_:level:)`) and the presentation state.
    struct Presenter {
        var core: Core
        var drawn: Snapshot
        var preview: Kind? = nil
        var selected: Int? = nil
        var kernel: Int = 0
        var accepted: Int = 0

        /// A presenter of `core`.
        init(core: Core) {
            self.core = core
            drawn = core.snapshot(time: 0)
        }

        /// The snapshot drawn now.
        var snapshot: Snapshot { drawn }

        /// Applies one kernel action through the adapter: accepted (spending one action) while an action is left,
        /// else refused with the budget code and nothing changed. Returns whether it was accepted.
        mutating func send(_ control: String, _ values: [Int], run: Int) throws -> Bool {
            typealias T = MushroomWeatherGestureControllerTests
            kernel += 1
            let spent: Int = core.play.actionsSpent
            let left: Int = core.play.actionsLeft
            let before: StateDigest = try T.digest(core)
            let result: ActionResult = core.apply(T.action(control, values))
            var ok: Bool = false
            if left > 0 {
                #expect(result == .accepted, "\(control) \(values) refused: \(result), run \(run)")
                if result == .accepted {
                    accepted += 1
                    ok = true
                    #expect(core.play.actionsSpent == spent + 1, "run \(run)")
                }
            } else {
                #expect(result == .rejected(.rule(code: MushroomWeatherError.budget.reasonCode)), "run \(run)")
                #expect(try T.digest(core) == before, "run \(run)")
            }
            preview = nil
            drawn = core.snapshot(time: 0)
            return ok
        }

        /// Applies gesture action `a` through the adapter and checks its effect (see the file header).
        mutating func apply(_ a: Action, run: Int) throws {
            typealias T = MushroomWeatherGestureControllerTests
            let before: StateDigest = try T.digest(core)
            let pods: [Cell?] = core.play.arrangement.pods
            switch a {
            case let .place(slot, cell):
                #expect(pods[slot] == nil, "a placement into a full slot, run \(run)")
                #expect(core.play.level.allowsPod(cell), "a placement off a site, run \(run)")
                if try send("pod.place", [slot, cell.row, cell.column], run: run) {
                    #expect(core.play.arrangement.pods[slot] == cell, "run \(run)")
                }
                return
            case let .move(slot, cell):
                #expect(pods[slot] != nil && pods[slot] != cell, "run \(run)")
                if try send("pod.place", [slot, cell.row, cell.column], run: run) {
                    #expect(core.play.arrangement.pods[slot] == cell, "run \(run)")
                }
                return
            case .remove(let slot):
                #expect(pods[slot] != nil, "run \(run)")
                if try send("pod.remove", [slot], run: run) {
                    #expect(core.play.arrangement.pods[slot] == nil, "run \(run)")
                }
                return
            case let .setVent(index, open):
                #expect(core.play.arrangement.ventsOpen[index] != open, "a vent set to its own state, run \(run)")
                if try send("vent.set", [index, open ? 1 : 0], run: run) {
                    #expect(core.play.arrangement.ventsOpen[index] == open, "run \(run)")
                }
                return
            case .setMoonlight(let level):
                #expect(core.play.arrangement.moonlight != level, "an unchanged moonlight, run \(run)")
                if try send("moon.set", [level], run: run) {
                    #expect(core.play.arrangement.moonlight == level, "run \(run)")
                }
                return
            case .showCycle(let cycle):
                #expect(core.apply(T.action("clock.show", [cycle])) == .accepted, "run \(run)")
                #expect(core.shownCycle == cycle)
                drawn = core.snapshot(time: 0)
                if let kind = preview { drawn = drawn.previewing(kind, level: core.play.level) }
            case .preview(let kind):
                let shown: Snapshot = core.snapshot(time: 0).previewing(kind, level: core.play.level)
                #expect(shown.preview?.kind == kind, "a preview the kernel would refuse: \(kind), run \(run)")
                preview = kind
                drawn = shown
            case .clearPreview:
                preview = nil
                drawn = drawn.clearingPreview()
            case .selectSlot(let slot):
                #expect(pods[slot] != nil, "run \(run)")
                selected = slot
            case .explain(let words):
                let known: [String] = [T.overText, T.podText, T.fullText, T.moonText]
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

    /// The release actions of a tap on site `index` of `s`, written on its own.
    static func siteTapExpected(_ index: Int, _ s: Snapshot) -> [Action] {
        guard s.stage == .playing else { return [.explain(overText)] }
        let cell: Cell = s.sites[index]
        for slot in s.pods.indices where s.pods[slot] == cell { return [.selectSlot(slot), .explain(podText)] }
        for slot in s.pods.indices where s.pods[slot] == nil { return [.place(slot: slot, cell: cell)] }
        return [.explain(fullText)]
    }

    /// The expectation of one-finger `steps` (the first a `.began`, the last an `.ended` or a `.cancelled`) beginning
    /// on snapshot `s` in `view` at `orbit` after the double-tap candidate `record`, written on its own (the picker's
    /// contract says what lies under a point).
    static func expected(_ steps: [Step], _ s: Snapshot, _ view: Vec2, _ orbit: ViewOrbit,
                         record: inout TapRecord?) -> Expectation {
        let origin: Vec2 = steps[0].point
        let startTime: Double = steps[0].time
        let picked: Pick = pick(origin, s, view, orbit)
        var result: Expectation = Expectation()
        var podSlot: Int? = nil
        var onMoon: Bool = false
        switch picked {
        case .site: result.state = .sitePress
        case .pod(let slot):
            result.state = .podPress
            podSlot = slot
        case .vent: result.state = .ventPress
        case .moon:
            result.state = .moonPress
            onMoon = true
        case .scrubber: result.state = .scrubberPress
        case .floor: result.state = .floorPress
        case .empty: result.state = .emptyPress
        }
        let playing: Bool = s.stage == .playing
        /// The change a pod or moon drag reads at `p` (nil: no change).
        func change(_ p: Vec2) -> Kind? {
            if let slot = podSlot { return drop(p, slot, s, view, orbit) }
            let level: Int = moonLevel(s.moonlight, p.y - origin.y)
            return level == s.moonlight ? nil : .moonlight(level: level)
        }
        var travel: Double = 0
        var dragging: Bool = false
        var target: Kind? = nil
        var previewing: Bool = false
        var lastCycle: Int = cycle(origin, s, view, orbit)
        var scrubbed: Bool = false
        for index in 1..<steps.count {
            let st: Step = steps[index]
            if st.phase == .cancelled {
                if previewing { result.actions.append(.clearPreview) }
                record = nil
                break
            }
            travel = max(travel, (st.point - origin).length)
            if picked == .scrubber {
                let c: Int = cycle(st.point, s, view, orbit)
                if c != lastCycle {
                    result.actions.append(.showCycle(c))
                    lastCycle = c
                    scrubbed = true
                }
            }
            if (podSlot != nil || onMoon) && !dragging && travel >= 16 {
                dragging = true
                if !playing { result.actions.append(.explain(overText)) }
            }
            if st.phase == .moved && dragging && playing {
                let k: Kind? = change(st.point)
                if k != target {
                    target = k
                    if let changed = k {
                        result.actions.append(.preview(changed))
                        previewing = true
                    } else if previewing {
                        result.actions.append(.clearPreview)
                        previewing = false
                    }
                }
            }
            guard st.phase == .ended else { continue }
            let tapped: Bool = !dragging && travel < 10 && st.time - startTime < 0.5
            switch picked {
            case .pod(let slot):
                record = nil
                if dragging && playing {
                    if case let .pod(_, cell)? = change(st.point) {
                        if let c = cell {
                            result.actions.append(.move(slot: slot, cell: c))
                        } else {
                            result.actions.append(.remove(slot: slot))
                        }
                    } else {
                        result.actions.append(.clearPreview)
                    }
                } else if tapped {
                    result.actions.append(.selectSlot(slot))
                    result.actions.append(.explain(podText))
                }
            case .moon:
                record = nil
                if dragging && playing {
                    if case .moonlight(let level)? = change(st.point) {
                        result.actions.append(.setMoonlight(level))
                    } else {
                        result.actions.append(.clearPreview)
                    }
                } else if tapped {
                    result.actions.append(.explain(moonText))
                }
            case .site(let i):
                record = nil
                if tapped { result.actions += siteTapExpected(i, s) }
            case .vent(let i):
                record = nil
                if tapped {
                    if playing {
                        result.actions.append(.setVent(index: i, open: !s.ventsOpen[i]))
                    } else {
                        result.actions.append(.explain(overText))
                    }
                }
            case .scrubber:
                record = nil
                if tapped && !scrubbed { result.actions.append(.showCycle(cycle(st.point, s, view, orbit))) }
            case .floor:
                record = nil
            case .empty:
                if !tapped {
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

    /// The number of one-finger script kinds; kinds ``oneFingerKinds`` and ``oneFingerKinds`` + 1 are the second finger
    /// and the system cancel.
    static let oneFingerKinds: Int = 18

    /// One seeded one-finger gesture (or two or three, for a double tap) of `kind` (0 ..< ``oneFingerKinds``) on `s` in
    /// `view` at `orbit`, or nil without a target.
    static func scripts(_ kind: Int, _ s: Snapshot, _ view: Vec2, _ orbit: ViewOrbit,
                        _ random: inout SeededRandom) -> [[Step]]? {
        switch kind {
        case 0:   // a tap on an empty site, sometimes slow
            guard let site = emptySite(s, view, orbit, &random) else { return nil }
            let q: Vec2 = site.point + Vec2(unit(&random) * 6 - 3, unit(&random) * 6 - 3)
            let held: Double = unit(&random) < 0.15 ? 0.6 : 0.05 + 0.4 * unit(&random)
            return [tap(site.point, at: 1, lift: q, held: held)]
        case 1:   // a tap on a pod
            guard let pod = podPoint(s, view, orbit, &random) else { return nil }
            return [tap(pod.point, at: 1, lift: pod.point + Vec2(unit(&random) * 6 - 3, 0), held: 0.08)]
        case 2:   // one or two taps on empty space, sometimes too late or too far for a double tap
            guard let e = emptyPoint(s, view, orbit) else { return nil }
            let first: [Step] = tap(e, at: 1)
            if unit(&random) < 0.3 { return [first] }
            let q: Vec2 = inside(e + Vec2(unit(&random) * 24 - 12, unit(&random) * 24 - 12), view)
            let gap: Double = 0.1 + 0.32 * unit(&random)
            return [first, tap(q, at: 1.01 + gap, held: 0.04)]
        case 3:   // a scrub drag along the track, sometimes off it
            guard let p = scrubPoint(unit(&random), s, view, orbit),
                  var q = project(G.scrubberPoint(unit(&random)), view, orbit) else { return nil }
            if unit(&random) < 0.3 { q = inside(q + Vec2(unit(&random) * 120 - 60, unit(&random) * 80 - 40), view) }
            return [path(p, q, steps: 3 + below(6, &random), time: 1)]
        case 4:   // a tap on the scrubber, sometimes slow
            guard let p = scrubPoint(unit(&random), s, view, orbit) else { return nil }
            let held: Double = unit(&random) < 0.2 ? 0.55 : 0.06
            return [tap(p, at: 1, lift: p + Vec2(unit(&random) * 4 - 2, 0), held: held)]
        case 5:   // a tap on a vent, sometimes slow
            guard let v = ventPoint(s, view, orbit, &random) else { return nil }
            let held: Double = unit(&random) < 0.15 ? 0.52 : 0.05 + 0.3 * unit(&random)
            return [tap(v.point, at: 1, lift: v.point + Vec2(unit(&random) * 6 - 3, unit(&random) * 6 - 3),
                        held: held)]
        case 6:   // a pod drag to a seeded site (free, its own or another pod's)
            guard let pod = podPoint(s, view, orbit, &random), let q = siteTarget(s, view, orbit, &random) else {
                return nil
            }
            return [path(pod.point, q, steps: 3 + below(4, &random), time: 1)]
        case 7:   // a pod drag off the floor
            guard let pod = podPoint(s, view, orbit, &random) else { return nil }
            return [path(pod.point, offFloor(s, view, orbit, &random), steps: 3 + below(4, &random), time: 1)]
        case 8:   // a pod drag out to a site or off the floor and back to the pod or to anywhere
            guard let pod = podPoint(s, view, orbit, &random) else { return nil }
            var out: Vec2 = offFloor(s, view, orbit, &random)
            if unit(&random) < 0.5, let q = siteTarget(s, view, orbit, &random) { out = q }
            var back: Vec2 = pod.point + Vec2(unit(&random) * 6 - 3, unit(&random) * 6 - 3)
            if unit(&random) < 0.3 { back = inside(Vec2(view.x * unit(&random), view.y * unit(&random)), view) }
            return [outAndBack(pod.point, out, back, time: 1)]
        case 9:   // a short touch of 10 … 16 points from a pod, the moon, a site or anywhere
            var p: Vec2 = inside(Vec2(view.x * unit(&random), view.y * unit(&random)), view)
            let r: Double = unit(&random)
            if r < 0.3, let pod = podPoint(s, view, orbit, &random) { p = pod.point }
            if r >= 0.3 && r < 0.5, let m = moonPoint(s, view, orbit) { p = m }
            if r >= 0.5 && r < 0.7, let site = emptySite(s, view, orbit, &random) { p = site.point }
            let a: Double = unit(&random) * 2 * Double.pi
            let length: Double = 10.5 + 5 * unit(&random)
            return [path(p, p + Vec2(cos(a) * length, sin(a) * length), steps: 2, time: 1)]
        case 10:  // a slow press (lifted 0.5 … 1.0 s after touch-down) moving under 10 points
            var start: Vec2? = podPoint(s, view, orbit, &random)?.point
            let r: Double = unit(&random)
            if start == nil || r < 0.2 { start = emptySite(s, view, orbit, &random)?.point }
            if r >= 0.6 && r < 0.8 { start = ventPoint(s, view, orbit, &random)?.point }
            if r >= 0.8 { start = moonPoint(s, view, orbit) }
            guard let p = start else { return nil }
            let q: Vec2 = p + Vec2(unit(&random) * 8 - 4, unit(&random) * 8 - 4)
            return [[Step(phase: .began, point: p, time: 1), Step(phase: .moved, point: q, time: 1.2),
                     Step(phase: .ended, point: q, time: 1.5 + 0.5 * unit(&random))]]
        case 11:  // a cancelled pod drag (perhaps to a seeded site first) or moon drag
            var start: Vec2? = podPoint(s, view, orbit, &random)?.point
            var q: Vec2? = nil
            if start != nil && unit(&random) < 0.7 { q = siteTarget(s, view, orbit, &random) }
            if start == nil || unit(&random) < 0.35 {
                start = moonPoint(s, view, orbit)
                if let m = start { q = m + Vec2(0, -50 - 60 * unit(&random)) }
            }
            guard let p = start else { return nil }
            let to: Vec2 = q ?? p
            return [[Step(phase: .began, point: p, time: 1), Step(phase: .moved, point: to, time: 1.1),
                     Step(phase: .cancelled, point: to, time: 1.2)]]
        case 12:  // a random touch, sometimes slow
            let p: Vec2 = inside(Vec2(view.x * unit(&random), view.y * unit(&random)), view)
            let q: Vec2 = p + Vec2(unit(&random) * 80 - 40, unit(&random) * 80 - 40)
            let slow: Double = unit(&random) < 0.3 ? 0.6 : 0
            var steps: [Step] = []
            for st in path(p, q, steps: 2, time: 1) {
                let time: Double = st.phase == .began ? st.time : st.time + slow
                steps.append(Step(phase: st.phase, point: st.point, time: time))
            }
            return [steps]
        case 13:  // a drag from a site, a vent, the floor or empty space
            var start: Vec2? = emptyPoint(s, view, orbit)
            let r: Double = unit(&random)
            if r < 0.25 { start = emptySite(s, view, orbit, &random)?.point }
            if r >= 0.25 && r < 0.5 { start = ventPoint(s, view, orbit, &random)?.point }
            if r >= 0.5 && r < 0.75 { start = floorPoint(s, view, orbit, &random) }
            guard let p = start else { return nil }
            let a: Double = unit(&random) * 2 * Double.pi
            let length: Double = 20 + 200 * unit(&random)
            return [path(p, inside(p + Vec2(cos(a) * length, sin(a) * length), view), steps: 3, time: 1)]
        case 14:  // a moon drag up or down by 0 … 170 points, a little sideways
            guard let m = moonPoint(s, view, orbit) else { return nil }
            let dy: Double = (unit(&random) * 2 - 1) * 170
            let q: Vec2 = m + Vec2(unit(&random) * 10 - 5, dy)
            return [path(m, q, steps: 2 + below(6, &random), time: 1)]
        case 15:  // a moon drag out and back to the moon or near it
            guard let m = moonPoint(s, view, orbit) else { return nil }
            let out: Vec2 = m + Vec2(0, (unit(&random) < 0.5 ? -1 : 1) * (60 + 80 * unit(&random)))
            let back: Vec2 = m + Vec2(unit(&random) * 6 - 3, unit(&random) * 50 - 25)
            return [outAndBack(m, out, back, time: 1)]
        case 16:  // a tap on the moon
            guard let m = moonPoint(s, view, orbit) else { return nil }
            return [tap(m, at: 1, lift: m + Vec2(unit(&random) * 6 - 3, 0), held: 0.05 + 0.4 * unit(&random))]
        default:  // a tap on the floor, sometimes between two taps on empty space (it breaks the double tap)
            guard let f = floorPoint(s, view, orbit, &random) else { return nil }
            guard unit(&random) < 0.5, let e = emptyPoint(s, view, orbit) else { return [tap(f, at: 1, held: 0.07)] }
            return [tap(e, at: 1), tap(f, at: 1.1), tap(e, at: 1.2)]
        }
    }

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
        #expect(near(controller.orbit, orbit) || produced.contains(.resetView))
        return produced
    }

    /// A seeded second-finger script: the first finger on a pod (perhaps dragged to a seeded site), on the moon
    /// (perhaps dragged up or down) or on the scrubber; a second finger cancels (only `clearPreview` when a preview was
    /// showing) and orbits; nothing kernel is sent, nothing at all after the clearing value, and the orbit turns by
    /// half the second finger's movement.
    static func secondFinger(_ controller: inout Controller, _ presenter: inout Presenter, _ view: Vec2,
                             _ orbit: ViewOrbit, run: Int, _ random: inout SeededRandom) throws -> [Action]? {
        let s: Snapshot = presenter.snapshot
        var start: Vec2? = podPoint(s, view, orbit, &random)?.point
        var onPod: Bool = start != nil
        var onMoon: Bool = false
        let r: Double = unit(&random)
        if r < 0.25 {
            start = scrubPoint(unit(&random), s, view, orbit)
            onPod = false
        } else if r < 0.5 || start == nil {
            start = moonPoint(s, view, orbit)
            onPod = false
            onMoon = start != nil
        }
        guard let p = start else { return nil }
        var first: Vec2 = p
        var steps: [Step] = [Step(phase: .began, point: p, time: 1)]
        if onPod && unit(&random) < 0.7, let q = siteTarget(s, view, orbit, &random) {
            first = q
            steps.append(Step(phase: .moved, point: first, time: 1.05))
        }
        if onMoon && unit(&random) < 0.7 {
            first = p + Vec2(0, (unit(&random) * 2 - 1) * 120)
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

    /// A seeded `cancel()` in the middle of a press, a pod drag or a moon drag: the finger's later events send nothing.
    static func systemCancel(_ controller: inout Controller, _ presenter: inout Presenter, _ view: Vec2,
                             _ orbit: ViewOrbit, run: Int, _ random: inout SeededRandom) throws -> [Action]? {
        let s: Snapshot = presenter.snapshot
        var p: Vec2? = podPoint(s, view, orbit, &random)?.point
        var q: Vec2? = nil
        if let start = p { q = unit(&random) < 0.4 ? start : (siteTarget(s, view, orbit, &random) ?? start) }
        if p == nil || unit(&random) < 0.3 {
            p = moonPoint(s, view, orbit)
            if let m = p { q = m + Vec2(0, -90) }
        }
        guard let start = p, let to = q else { return nil }
        let steps: [Step] = [Step(phase: .began, point: start, time: 1), Step(phase: .moved, point: to, time: 1.05)]
        let actions: [Action] = try self.run(&controller, steps, view: view, presenter: &presenter, run: run).actions
        for a in actions { #expect(!isKernel(a), "system cancel run \(run)") }
        controller.cancel()
        #expect(controller.state == .idle)
        let after: [Action] = controller.handle(event(1, .ended, to, 1.1), viewSize: view,
                                                snapshot: presenter.snapshot)
        #expect(after.isEmpty, "system cancel run \(run)")
        #expect(near(controller.orbit, orbit))
        return actions + after
    }

    /// The name of an action's case.
    static func name(_ a: Action) -> String {
        switch a {
        case .place: return "place"
        case .move: return "move"
        case .remove: return "remove"
        case .setVent: return "setVent"
        case .setMoonlight: return "setMoonlight"
        case .showCycle: return "showCycle"
        case .preview: return "preview"
        case .clearPreview: return "clearPreview"
        case .selectSlot: return "selectSlot"
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
        let kinds: Int = Self.oneFingerKinds + 2
        var counts: [Int] = Array(repeating: 0, count: kinds)
        var sent: [String: Int] = [:]
        var accepted: Int = 0
        var finished: Int = 0
        var stages: Set<String> = []
        var orbitsUsed: Set<Int> = []
        while run < 500 && attempts < 5_000 {
            attempts += 1
            let c: Case = all[Self.below(all.count, &random)]
            let view: Vec2 = Self.views[Self.below(Self.views.count, &random)]
            let orbitIndex: Int = Self.below(Self.orbits.count, &random)
            var presenter: Presenter = Presenter(core: c.core)
            var controller: Controller = Self.controller(at: Self.orbits[orbitIndex], view: view,
                                                         snapshot: presenter.snapshot)
            let orbit: ViewOrbit = controller.orbit
            let kind: Int = Self.below(kinds, &random)
            var produced: [Action]?
            if kind == Self.oneFingerKinds {
                produced = try Self.secondFinger(&controller, &presenter, view, orbit, run: run, &random)
            } else if kind == Self.oneFingerKinds + 1 {
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
            #expect(presenter.kernel == kernel, "every kernel action applied through the adapter, run \(run)")
            if kind == 11 || kind >= Self.oneFingerKinds { #expect(kernel == 0, "run \(run)") }
            if c.snapshot.stage != .playing {
                finished += 1
                #expect(kernel == 0, "run \(run)")
                #expect(presenter.core.play == c.core.play, "run \(run)")
            }
            if presenter.accepted == 0 {
                #expect(try Self.digest(presenter.core) == Self.digest(c.core), "run \(run)")
            }
            accepted += presenter.accepted
            stages.insert(c.snapshot.stage.rawValue)
            orbitsUsed.insert(orbitIndex)
            counts[kind] += 1
            run += 1
        }
        #expect(run == 500)
        for k in 0..<kinds { #expect(counts[k] > 0, "script kind \(k) never ran: \(counts)") }
        let names: [String] = ["place", "move", "remove", "setVent", "setMoonlight", "showCycle", "preview",
                               "clearPreview", "selectSlot", "resetView", "explain"]
        for n in names { #expect((sent[n] ?? 0) > 0, "\(n) never sent: \(sent)") }
        #expect(stages == ["playing", "won", "failed"])
        #expect(orbitsUsed.count == 3)
        #expect(accepted > 10, "\(accepted) kernel actions accepted")
        #expect(finished > 100)
        for index in all.indices { #expect(try Self.digest(all[index].core) == digests[index]) }
    }

    @Test func tapsAndThresholdsHoldAtTheirEdges() throws {
        let view: Vec2 = Self.views[2]
        let c: Case = try Self.cases(1)[0]
        let s: Snapshot = c.snapshot
        var random: SeededRandom = SeededRandom(seed: Self.seed)
        func play(_ steps: [Step]) -> [Action] {
            var controller: Controller = Controller()
            var actions: [Action] = []
            for st in steps {
                actions += controller.handle(Self.event(1, st.phase, st.point, st.time), viewSize: view, snapshot: s)
            }
            return actions
        }
        // A tap on an empty site places in the first free slot: under 10 points, lifted before 0.5 s.
        let site: (index: Int, point: Vec2) = try #require(Self.emptySite(s, view, .authored, &random))
        let placing: [Action] = Self.siteTapExpected(site.index, s)
        guard case .place = try #require(placing.first) else {
            Issue.record("the opening of level 1 has no free slot")
            return
        }
        let p: Vec2 = site.point
        #expect(play(Self.tap(p, at: 1, held: 0.49)) == placing)
        #expect(play(Self.tap(p, at: 1, held: 0.5)).isEmpty)
        #expect(play(Self.tap(p, at: 1, lift: p + Vec2(0, 9.9))) == placing)
        #expect(play(Self.tap(p, at: 1, lift: p + Vec2(0, 10))).isEmpty)
        #expect(play(Self.tap(p, at: 1, lift: p + Vec2(0, 15.9))).isEmpty)
        #expect(play(Self.tap(p, at: 1, lift: p + Vec2(0, 30))).isEmpty)
        // A tap on a vent sets it to the other state; slow or far, nothing.
        let vent: (index: Int, point: Vec2) = try #require(Self.ventPoint(s, view, .authored, &random))
        let toggled: [Action] = [.setVent(index: vent.index, open: !s.ventsOpen[vent.index])]
        #expect(play(Self.tap(vent.point, at: 1, held: 0.49)) == toggled)
        #expect(play(Self.tap(vent.point, at: 1, held: 0.5)).isEmpty)
        #expect(play(Self.tap(vent.point, at: 1, lift: vent.point + Vec2(9.9, 0))) == toggled)
        #expect(play(Self.tap(vent.point, at: 1, lift: vent.point + Vec2(10, 0))).isEmpty)
        // A tap on the moon explains; on the scrubber shows the cycle under the finger; on the floor nothing.
        let m: Vec2 = try #require(Self.moonPoint(s, view, .authored))
        #expect(play(Self.tap(m, at: 1)) == [.explain(Self.moonText)])
        #expect(play(Self.tap(m, at: 1, held: 0.5)).isEmpty)
        let r: Vec2 = try #require(Self.scrubPoint(0.7, s, view, .authored))
        #expect(play(Self.tap(r, at: 1)) == [.showCycle(Self.cycle(r, s, view, .authored))])
        #expect(play(Self.tap(r, at: 1, held: 0.5)).isEmpty)
        let f: Vec2 = try #require(Self.floorPoint(s, view, .authored, &random))
        #expect(play(Self.tap(f, at: 1)).isEmpty)
        #expect(play(Self.tap(f, at: 1) + Self.tap(f, at: 1.2)).isEmpty)
        // Double taps on empty space: within 0.35 s and 22 points reset the view; later or farther do not.
        let e: Vec2 = try #require(Self.emptyPoint(s, view, .authored))
        let inward: Vec2 = Vec2(e.x < view.x / 2 ? 1 : -1, 0)
        #expect(play(Self.tap(e, at: 1) + Self.tap(e, at: 1.3)) == [.resetView])
        #expect(play(Self.tap(e, at: 1) + Self.tap(e, at: 1.36)).isEmpty)
        let at22: Vec2 = e + inward * 22
        if Self.pick(at22, s, view, .authored) == .empty {
            #expect(play(Self.tap(e, at: 1) + Self.tap(at22, at: 1.2)) == [.resetView])
        }
        let at23: Vec2 = e + inward * 23
        if Self.pick(at23, s, view, .authored) == .empty {
            #expect(play(Self.tap(e, at: 1) + Self.tap(at23, at: 1.2)).isEmpty)
        }
        // A completed double tap starts no new one; a slow first tap starts none; a floor tap between breaks it.
        #expect(play(Self.tap(e, at: 1) + Self.tap(e, at: 1.2) + Self.tap(e, at: 1.4)) == [.resetView])
        #expect(play(Self.tap(e, at: 1, held: 0.6) + Self.tap(e, at: 1.8)).isEmpty)
        #expect(play(Self.tap(e, at: 1) + Self.tap(f, at: 1.1) + Self.tap(e, at: 1.2)).isEmpty)
        #expect(Controller.tapDistance == 10 && Controller.dragDistance == 16 && Controller.tapDuration == 0.5)
        #expect(Controller.doubleTapWindow == 0.35 && Controller.doubleTapDistance == 22)
        #expect(Controller.finishedReason == Self.overText && Controller.podReason == Self.podText)
        #expect(Controller.fullReason == Self.fullText && Controller.moonReason == Self.moonText)
    }

    @Test func tapsOnPodsSitesVentsAndFinishedPlaysExplain() throws {
        let view: Vec2 = Self.views[0]
        var full: Int = 0
        var over: Int = 0
        var pods: Int = 0
        var vents: Int = 0
        for number in Self.levels {
            for c in try Self.cases(number) {
                let s: Snapshot = c.snapshot
                var random: SeededRandom = SeededRandom(seed: Self.seed + UInt64(number))
                if let pod = Self.podPoint(s, view, .authored, &random) {
                    var controller: Controller = Controller()
                    var presenter: Presenter = Presenter(core: c.core)
                    let got = try Self.run(&controller, Self.tap(pod.point, at: 1), view: view, presenter: &presenter,
                                           run: -1)
                    #expect(got.state == .podPress)
                    #expect(got.actions == [.selectSlot(pod.slot), .explain(Self.podText)], "\(got.actions)")
                    #expect(presenter.selected == pod.slot)
                    pods += 1
                }
                if let vent = Self.ventPoint(s, view, .authored, &random) {
                    var controller: Controller = Controller()
                    var presenter: Presenter = Presenter(core: c.core)
                    let got = try Self.run(&controller, Self.tap(vent.point, at: 1), view: view,
                                           presenter: &presenter, run: -1)
                    #expect(got.state == .ventPress)
                    if s.stage == .playing {
                        #expect(got.actions == [.setVent(index: vent.index, open: !s.ventsOpen[vent.index])])
                        if s.actionsLeft > 0 {
                            #expect(presenter.core.play.arrangement.ventsOpen[vent.index] != s.ventsOpen[vent.index])
                        }
                    } else {
                        #expect(got.actions == [.explain(Self.overText)], "\(got.actions)")
                        #expect(presenter.core.play == c.core.play)
                    }
                    vents += 1
                }
                guard let site = Self.emptySite(s, view, .authored, &random) else { continue }
                var controller: Controller = Controller()
                var presenter: Presenter = Presenter(core: c.core)
                let got = try Self.run(&controller, Self.tap(site.point, at: 1), view: view, presenter: &presenter,
                                       run: -1)
                #expect(got.state == .sitePress)
                var free: Bool = false
                for pod in s.pods where pod == nil { free = true }
                if s.stage != .playing {
                    #expect(got.actions == [.explain(Self.overText)], "\(got.actions)")
                    #expect(presenter.core.play == c.core.play)
                    over += 1
                } else if !free {
                    #expect(got.actions == [.explain(Self.fullText)], "\(got.actions)")
                    #expect(presenter.core.play == c.core.play)
                    full += 1
                } else {
                    #expect(got.actions.count == 1 && Self.isKernel(got.actions[0]), "\(got.actions)")
                }
            }
        }
        #expect(full > 0 && over > 0 && pods > 0 && vents > 0, "full \(full) over \(over) pods \(pods) vents \(vents)")
    }

    /// A free site of `s` (no pod on it), whose projected centre is at least 40 points from `from` and drops back
    /// exactly onto it for slot `slot`, at the authored orbit in `view`; nil when none.
    static func freeSiteTarget(_ s: Snapshot, slot: Int, from: Vec2, _ view: Vec2) -> (point: Vec2, cell: Cell)? {
        for index in s.sites.indices where !occupied(index, s) {
            guard let q = project(G.siteCentre(index, s), view, .authored), (q - from).length >= 40 else { continue }
            if drop(q, slot, s, view, .authored) == .pod(slot: slot, target: s.sites[index]) {
                return (q, s.sites[index])
            }
        }
        return nil
    }

    @Test func podDragsPreviewMoveRemoveOrExplain() throws {
        let view: Vec2 = Self.views[2]
        var moved: Int = 0
        var removed: Int = 0
        var over: Int = 0
        for number in Self.levels {
            for c in try Self.cases(number) {
                let s: Snapshot = c.snapshot
                var random: SeededRandom = SeededRandom(seed: Self.seed)
                guard let pod = Self.podPoint(s, view, .authored, &random) else { continue }
                let off: Vec2 = Vec2(8, 8)
                #expect(Self.drop(off, pod.slot, s, view, .authored) == .pod(slot: pod.slot, target: nil))
                // Off the floor: removal previewed, then removed (or explained once outside playing).
                var controller: Controller = Controller()
                var presenter: Presenter = Presenter(core: c.core)
                let gone = try Self.run(&controller, Self.path(pod.point, off, steps: 6, time: 1), view: view,
                                        presenter: &presenter, run: -1)
                #expect(gone.state == .podPress)
                if s.stage == .playing {
                    #expect(gone.actions.contains(.preview(.pod(slot: pod.slot, target: nil))), "\(gone.actions)")
                    #expect(gone.actions.last == .remove(slot: pod.slot), "\(gone.actions)")
                    removed += 1
                } else {
                    #expect(gone.actions == [.explain(Self.overText)], "\(gone.actions)")
                    #expect(presenter.core.play == c.core.play)
                    over += 1
                }
                // To a free site: previewed, then one move.
                if s.stage == .playing, let t = Self.freeSiteTarget(s, slot: pod.slot, from: pod.point, view) {
                    var mover: Controller = Controller()
                    var pres: Presenter = Presenter(core: c.core)
                    let got = try Self.run(&mover, Self.path(pod.point, t.point, steps: 6, time: 1), view: view,
                                           presenter: &pres, run: -1)
                    #expect(got.actions.contains(.preview(.pod(slot: pod.slot, target: t.cell))), "\(got.actions)")
                    #expect(got.actions.last == .move(slot: pod.slot, cell: t.cell), "\(got.actions)")
                    moved += 1
                    // Out to the site and back to the pod: previewed, then cleared; nothing sent.
                    var back: Controller = Controller()
                    var still: Presenter = Presenter(core: c.core)
                    let none: [Action] = try Self.run(&back, Self.outAndBack(pod.point, t.point, pod.point, time: 1),
                                                      view: view, presenter: &still, run: -1).actions
                    if Self.drop(pod.point, pod.slot, s, view, .authored) == nil {
                        #expect(none.last == .clearPreview && !none.contains(.move(slot: pod.slot, cell: t.cell)))
                        #expect(try Self.digest(still.core) == Self.digest(c.core))
                    }
                    // A cancelled drag clears its preview and sends nothing else.
                    var cancelled: Controller = Controller()
                    var cpres: Presenter = Presenter(core: c.core)
                    var steps: [Step] = Self.path(pod.point, t.point, steps: 4, time: 1)
                    steps[steps.count - 1] = Step(phase: .cancelled, point: t.point, time: 1.2)
                    let lost: [Action] = try Self.run(&cancelled, steps, view: view, presenter: &cpres,
                                                      run: -1).actions
                    var kernel: Bool = false
                    for a in lost where Self.isKernel(a) { kernel = true }
                    #expect(!kernel && lost.last == .clearPreview, "\(lost)")
                    #expect(cpres.core.play == c.core.play)
                }
                // 10 … 16 points from the pod: nothing.
                var short: Controller = Controller()
                var quiet: Presenter = Presenter(core: c.core)
                let shortSteps: [Step] = Self.path(pod.point, pod.point + Vec2(0, 13), steps: 2, time: 1)
                #expect(try Self.run(&short, shortSteps, view: view, presenter: &quiet, run: -1).actions.isEmpty)
            }
        }
        #expect(moved > 0 && removed > 0 && over > 0, "moved \(moved) removed \(removed) over \(over)")
    }

    @Test func moonDragsPreviewAndSetOnlyADifferentLevel() throws {
        let view: Vec2 = Self.views[2]
        var set: Int = 0
        var unchanged: Int = 0
        var over: Int = 0
        for number in Self.levels {
            for c in try Self.cases(number) {
                let s: Snapshot = c.snapshot
                guard let m = Self.moonPoint(s, view, .authored) else { continue }
                for dy in [-85.0, -45.0, -19.0, 19.0, 45.0, 125.0, -200.0] {
                    var controller: Controller = Controller()
                    var presenter: Presenter = Presenter(core: c.core)
                    let got = try Self.run(&controller, Self.path(m, m + Vec2(0, dy), steps: 4, time: 1), view: view,
                                           presenter: &presenter, run: -1)
                    #expect(got.state == .moonPress)
                    let level: Int = Self.moonLevel(s.moonlight, dy)
                    if s.stage != .playing {
                        #expect(got.actions == [.explain(Self.overText)], "\(got.actions)")
                        #expect(presenter.core.play == c.core.play)
                        over += 1
                    } else if level != s.moonlight {
                        #expect(got.actions.contains(.preview(.moonlight(level: level))), "dy \(dy): \(got.actions)")
                        #expect(got.actions.last == .setMoonlight(level), "dy \(dy): \(got.actions)")
                        if s.actionsLeft > 0 { #expect(presenter.core.play.arrangement.moonlight == level) }
                        set += 1
                    } else {
                        var previews: Int = 0
                        for a in got.actions { if case .preview = a { previews += 1 } }
                        #expect(got.actions.last == .clearPreview, "dy \(dy): \(got.actions)")
                        #expect(try Self.digest(presenter.core) == Self.digest(c.core))
                        if abs(dy) < 20 { #expect(previews == 0 && got.actions == [.clearPreview], "\(got.actions)") }
                        unchanged += 1
                    }
                }
                // Up two levels' worth and back to the start: previewed, then cleared; nothing sent.
                if s.stage == .playing {
                    var back: Controller = Controller()
                    var still: Presenter = Presenter(core: c.core)
                    let none: [Action] = try Self.run(&back, Self.outAndBack(m, m + Vec2(0, -80), m, time: 1),
                                                      view: view, presenter: &still, run: -1).actions
                    #expect(none.last == .clearPreview, "\(none)")
                    for a in none { #expect(!Self.isKernel(a)) }
                    #expect(try Self.digest(still.core) == Self.digest(c.core))
                    // A cancelled moon drag clears its preview (when one showed) and sends nothing else.
                    var cancelled: Controller = Controller()
                    var cpres: Presenter = Presenter(core: c.core)
                    let lost: [Action] = try Self.run(&cancelled, [Step(phase: .began, point: m, time: 1),
                                                                   Step(phase: .moved, point: m + Vec2(0, 90),
                                                                        time: 1.1),
                                                                   Step(phase: .cancelled, point: m + Vec2(0, 90),
                                                                        time: 1.2)],
                                                      view: view, presenter: &cpres, run: -1).actions
                    for a in lost { #expect(!Self.isKernel(a)) }
                    if Self.moonLevel(s.moonlight, 90) != s.moonlight { #expect(lost.last == .clearPreview) }
                    #expect(cpres.core.play == c.core.play)
                }
            }
        }
        #expect(set > 0 && unchanged > 0 && over > 0, "set \(set) unchanged \(unchanged) over \(over)")
    }

    @Test func scrubDragsShowEveryCycleInAnyStage() throws {
        let view: Vec2 = Self.views[1]
        var checked: Int = 0
        var stages: Set<String> = []
        for number in Self.levels {
            for c in try Self.cases(number) {
                let s: Snapshot = c.snapshot
                guard let a = Self.scrubPoint(0, s, view, .authored) else { continue }
                var steps: [Step] = [Step(phase: .began, point: a, time: 1)]
                var want: [Action] = []
                var last: Int = Self.cycle(a, s, view, .authored)
                var time: Double = 1
                var end: Vec2 = a
                let samples: Int = max(2 * s.cyclesRun, 40)
                for i in 1...samples {
                    guard let q = Self.project(G.scrubberPoint(Double(i) / Double(samples)), view, .authored) else {
                        continue
                    }
                    time += 0.02
                    steps.append(Step(phase: .moved, point: q, time: time))
                    let t: Int = Self.cycle(q, s, view, .authored)
                    if t != last {
                        want.append(.showCycle(t))
                        last = t
                    }
                    end = q
                }
                steps.append(Step(phase: .ended, point: end, time: time + 0.02))
                var controller: Controller = Controller()
                var presenter: Presenter = Presenter(core: c.core)
                let got = try Self.run(&controller, steps, view: view, presenter: &presenter, run: -1)
                #expect(got.state == .scrubberPress)
                #expect(got.actions == want, "level \(number) stage \(s.stage): \(got.actions)")
                let first: Int = Self.cycle(a, s, view, .authored)
                #expect(want.last == .showCycle(s.cyclesRun) && want.count == s.cyclesRun - first, "\(want.count)")
                #expect(presenter.core.shownCycle == s.cyclesRun)
                #expect(try Self.digest(presenter.core) == Self.digest(c.core))
                stages.insert(s.stage.rawValue)
                checked += 1
            }
        }
        #expect(checked > 0 && stages == ["playing", "won", "failed"])
    }

    @Test func fingersOrbitWithinBoundsAndResetChangesNothing() throws {
        let view: Vec2 = Self.views[0]
        let c: Case = try Self.cases(41)[0]
        let s: Snapshot = c.snapshot
        let before: StateDigest = try Self.digest(c.core)
        var controller: Controller = Controller()
        #expect(controller.camera(viewSize: view) == G.camera(aspect: view.x / view.y, orbit: .authored))
        #expect(controller.camera(viewSize: Vec2(0, 10)) == nil)
        // Far to the right and up: yaw and pitch clamp at their upper bounds.
        let far: [Action] = Self.twoFingers(&controller, a: Vec2(100, 400), b: Vec2(300, 400),
                                            by: Vec2(view.x * 3, -view.y * 3), view: view, snapshot: s, time: 0)
        #expect(far.isEmpty)
        #expect(Self.near(controller.orbit, ViewOrbit(yaw: ViewOrbit.yawLimit, pitch: ViewOrbit.pitchRange.upperBound)))
        #expect(controller.camera(viewSize: view) == G.camera(aspect: view.x / view.y, orbit: controller.orbit))
        // Far to the left and down: the lower bounds.
        _ = Self.twoFingers(&controller, a: Vec2(100, 400), b: Vec2(300, 400), by: Vec2(-view.x * 4, view.y * 4),
                            view: view, snapshot: s, time: 0.5)
        let lowest: ViewOrbit = ViewOrbit(yaw: -ViewOrbit.yawLimit, pitch: ViewOrbit.pitchRange.lowerBound)
        #expect(Self.near(controller.orbit, lowest))
        // A third finger re-bases the midpoint: the orbit follows only later movement.
        controller.resetView()
        #expect(controller.orbit == .authored)
        var actions: [Action] = []
        actions += controller.handle(Self.event(1, .began, Vec2(100, 300), 1), viewSize: view, snapshot: s)
        actions += controller.handle(Self.event(2, .began, Vec2(200, 300), 1.01), viewSize: view, snapshot: s)
        actions += controller.handle(Self.event(3, .began, Vec2(150, 600), 1.02), viewSize: view, snapshot: s)
        #expect(controller.state == .orbiting && controller.orbit == .authored)
        actions += controller.handle(Self.event(3, .moved, Vec2(150 + 39, 600), 1.03), viewSize: view, snapshot: s)
        let third: ViewOrbit = Self.turned(.authored, by: Vec2(13, 0), view: view)
        #expect(Self.near(controller.orbit, third))
        actions += controller.handle(Self.event(1, .ended, Vec2(100, 300), 1.04), viewSize: view, snapshot: s)
        #expect(controller.state == .cancelled)
        actions += controller.handle(Self.event(2, .ended, Vec2(200, 300), 1.05), viewSize: view, snapshot: s)
        actions += controller.handle(Self.event(3, .ended, Vec2(189, 600), 1.06), viewSize: view, snapshot: s)
        #expect(controller.state == .idle && actions.isEmpty)
        // A double tap on empty space returns to the authored orbit.
        let e: Vec2 = try #require(Self.emptyPoint(s, view, controller.orbit))
        var reset: [Action] = []
        for st in Self.tap(e, at: 2) + Self.tap(e, at: 2.2) {
            reset += controller.handle(Self.event(1, st.phase, st.point, st.time), viewSize: view, snapshot: s)
        }
        #expect(reset == [.resetView] && controller.orbit == .authored)
        // A second finger during a moon drag clears its preview and orbits; nothing kernel is sent.
        if let m = Self.moonPoint(s, view, .authored), Self.moonLevel(s.moonlight, -80) != s.moonlight {
            var dragged: [Action] = []
            dragged += controller.handle(Self.event(1, .began, m, 2.5), viewSize: view, snapshot: s)
            dragged += controller.handle(Self.event(1, .moved, m + Vec2(0, -80), 2.55), viewSize: view, snapshot: s)
            #expect(controller.state == .moonDrag)
            dragged += controller.handle(Self.event(2, .began, Vec2(200, 200), 2.6), viewSize: view, snapshot: s)
            #expect(dragged == [.preview(.moonlight(level: Self.moonLevel(s.moonlight, -80))), .clearPreview])
            #expect(controller.state == .orbiting)
            var later: [Action] = controller.handle(Self.event(1, .ended, m, 2.7), viewSize: view, snapshot: s)
            later += controller.handle(Self.event(2, .ended, Vec2(200, 200), 2.75), viewSize: view, snapshot: s)
            #expect(later.isEmpty && controller.state == .idle)
        }
        // A system cancel mid-press sends nothing and keeps the orbit.
        _ = Self.twoFingers(&controller, a: Vec2(100, 400), b: Vec2(300, 400), by: Vec2(40, 0), view: view,
                            snapshot: s, time: 3)
        let kept: ViewOrbit = controller.orbit
        _ = controller.handle(Self.event(1, .began, e, 4), viewSize: view, snapshot: s)
        controller.cancel()
        #expect(controller.handle(Self.event(1, .ended, e, 4.05), viewSize: view, snapshot: s).isEmpty)
        #expect(controller.orbit == kept && controller.state == .idle)
        #expect(try Self.digest(c.core) == before)
    }
}
