// MicroscopicAuroraGestureControllerTests — feature 484 (R02-G19-04) T-R02G1904-003 (FR-R02G1904-001 … 005, 007, 008;
// SC-R02G1904-001 … 003). 500 seeded (SeededRandom seed 2_484) scripted gestures — taps on empty sites, on wells, on
// the scrubber, on the dish field, one or two taps on empty space, scrub drags, well drags to seeded sites, off the dish
// and out and back, touches of 10 … 16 points, slow presses, cancelled well drags, random touches, drags from a site,
// the field or empty space, second fingers and system cancels — on certified levels 1, 41 and 90 (the opening and the
// moment after the first certified placement, both playing; every slot filled, playing; won by the certified plan and
// the play; failed by playing the opening; each with a quarter of the swim shown), at three view sizes and three orbits
// reached by two-finger drags, send exactly the actions an independent expectation written here predicts. What lies
// under the finger is asked of the picker's contract (`MicroscopicAuroraPicker.pick`, `dropTarget`, `scrubTick`), so
// the expectation stays valid for any picker that keeps it; the gesture semantics (tap, drag or nothing by travel and
// event timestamps; the scrubber's ticks from touch-down on; the drop target's changes on moves only; one move or
// removal on release only for a change; a placement in the first free slot with the controller's strength and sense;
// double taps on empty space within 0.35 s and 22 points; no kernel action outside playing) are written here on their
// own. Every action is applied as the presenter would, through the adapter's `apply(ExperienceAction(control:values:
// step:))`: place and move → `well.place [slot, row, column, strength, sense]`, remove → `well.remove [slot]`
// (accepted while an action is left, else refused with the budget code), showTick → `clock.show [tick]`; the preview,
// the freeze, the selected slot and the view are presenter state; only the kernel actions may change the digest. Also:
// thresholds at their edges, well drags moving, removing, clearing or explaining, scrub drags showing every tick in any
// stage, full slots explained, and the second and third fingers' clamped orbit with the double-tap reset.
// Explicit types, plain loops; each test well under 10 s; no wall-clock asserts.
import Foundation
import Testing
import VisualCoreExperience
import VisualCoreMath
import VisualCoreScenes
import VisualCoreSimulation
@testable import MicroscopicAuroraCore

@Suite struct MicroscopicAuroraGestureControllerTests {
    typealias Controller = MicroscopicAuroraGestureController
    typealias Snapshot = MicroscopicAuroraSceneSnapshot
    typealias Action = MicroscopicAuroraGestureAction
    typealias ViewOrbit = MicroscopicAuroraViewOrbit
    typealias Target = MicroscopicAuroraPreviewTarget
    typealias Core = MicroscopicAuroraExperienceCore
    typealias Pick = MicroscopicAuroraPick
    typealias Well = MicroscopicAuroraWell
    typealias Cell = MicroscopicAuroraCell
    typealias P = MicroscopicAuroraPicker
    typealias G = MicroscopicAuroraSceneGeometry

    /// The seed of every random choice here.
    static let seed: UInt64 = 2_484
    /// The view sizes every script runs at: a phone upright, a phone on its side, a tablet.
    static let views: [Vec2] = [Vec2(390, 844), Vec2(844, 390), Vec2(1_024, 768)]
    /// The scripted orbits (the first is the authored one), reached by two-finger drags.
    static let orbits: [ViewOrbit] = [.authored, ViewOrbit(yaw: 0.5, pitch: 0.3), ViewOrbit(yaw: -0.8, pitch: -0.25)]
    /// The certified levels used.
    static let levels: [Int] = [1, 41, 90]
    /// The explanations, written here on their own.
    static let overText: String = "The play is over: undo or go to the next level"
    static let wellText: String = "Drag a well to another site, or off the dish to remove it"
    static let fullText: String = "Every well slot is used: drag a well off the dish to free one"
    /// The strength and sense the scripted controllers place (not the defaults, so a placement shows it used them).
    static let strength: Int = 3
    static let sense: MicroscopicAuroraSense = .counterclockwise

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

    /// The `well.place` values of `well` in `slot`.
    static func placeValues(_ slot: Int, _ well: Well) -> [Int] {
        [slot, well.cell.row, well.cell.column, well.strength, well.sense == .clockwise ? 0 : 1]
    }

    /// A case of `core` with a quarter of the swim shown.
    static func make(_ core: Core) -> Case {
        var shown: Core = core
        let quarter: Int = core.play.report.ticks / 4
        #expect(shown.apply(action("clock.show", [quarter])) == .accepted)
        return Case(core: shown, snapshot: shown.snapshot(time: 0))
    }

    /// Whether `a` is a kernel action (a placement, move or removal).
    static func isKernel(_ a: Action) -> Bool {
        switch a {
        case .place, .move, .remove: return true
        default: return false
        }
    }

    /// The digest of `core` as the engine computes it.
    static func digest(_ core: Core) throws -> StateDigest {
        var builder: DigestBuilder = DigestBuilder(domain: Core.experienceID)
        try core.writeDigest(into: &builder)
        return builder.finish()
    }

    /// Certified level `number`: the opening (playing), after the first certified placement (playing, when the plan has
    /// two or more), every slot filled (playing, when the sites and the budget allow), after the whole certified plan
    /// and the play (won), and the opening played at once (failed).
    static func cases(_ number: Int) throws -> [Case] {
        let plan: [MicroscopicAuroraAction] = try Core.generated(number: number).plan.actions
        try #require(!plan.isEmpty)
        let opening: Core = try Core.opening(number: number)
        #expect(opening.play.stage == .playing)
        var result: [Case] = [make(opening)]
        var core: Core = opening
        for (index, step) in plan.enumerated() {
            switch step {
            case let .place(slot, well):
                #expect(core.apply(action("well.place", placeValues(slot, well))) == .accepted)
            case .remove(let slot):
                #expect(core.apply(action("well.remove", [slot])) == .accepted)
            case .play:
                Issue.record("a plan step is never the play")
            }
            if index == 0 && plan.count >= 2 {
                #expect(core.play.stage == .playing)
                result.append(make(core))
            }
        }
        #expect(core.apply(action("swim.play", [])) == .accepted)
        #expect(core.play.stage == .won)
        result.append(make(core))
        if let full = filled(opening) { result.append(make(full)) }
        var failed: Core = opening
        #expect(failed.apply(action("swim.play", [])) == .accepted)
        try #require(failed.play.stage == .failed, "playing the opening of level \(number) did not fail")
        result.append(make(failed))
        return result
    }

    /// `opening` with every empty slot given a well of strength 1 on a free site, or nil when the sites or the budget
    /// do not allow it.
    static func filled(_ opening: Core) -> Core? {
        var core: Core = opening
        let sites: [Cell] = core.play.level.sites ?? []
        for slot in 0..<MicroscopicAuroraLevel.slots where core.play.wells[slot] == nil {
            var placed: Bool = false
            for cell in sites {
                var taken: Bool = false
                for w in core.play.wells { if w?.cell == cell { taken = true } }
                if taken { continue }
                let well: Well = Well(cell: cell, strength: 1, sense: .clockwise)
                if core.apply(action("well.place", placeValues(slot, well))) == .accepted {
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

    /// The tick the scrubber reads under `p`.
    static func tick(_ p: Vec2, _ s: Snapshot, _ view: Vec2, _ orbit: ViewOrbit) -> Int {
        P.scrubTick(simd(p), size: simd(view), snapshot: s, orbit: orbit)
    }

    /// The drop target of slot `slot`'s well under `p` (nil: no change).
    static func drop(_ p: Vec2, _ slot: Int, _ s: Snapshot, _ view: Vec2, _ orbit: ViewOrbit) -> Target? {
        P.dropTarget(simd(p), slot: slot, size: simd(view), snapshot: s, orbit: orbit)
    }

    /// The projected view point of world point `w`.
    static func project(_ w: SIMD3<Double>, _ view: Vec2, _ orbit: ViewOrbit) -> Vec2? {
        let camera: MicroscopicAuroraCamera = G.camera(aspect: view.x / view.y, orbit: orbit)
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

    /// Whether site `index` of `s` holds a well.
    static func occupied(_ index: Int, _ s: Snapshot) -> Bool {
        for w in s.wells where w?.cell == s.sites[index] { return true }
        return false
    }

    /// A seeded site free of wells and a point that picks it, or nil.
    static func emptySite(_ s: Snapshot, _ view: Vec2, _ orbit: ViewOrbit,
                          _ random: inout SeededRandom) -> (index: Int, point: Vec2)? {
        let n: Int = s.sites.count
        guard n > 0 else { return nil }
        let first: Int = below(n, &random)
        for i in 0..<n {
            let index: Int = (first + i) % n
            if occupied(index, s) { continue }
            let c: Vec2? = project(G.cellCentre(s.sites[index]), view, orbit)
            if let p = near(c, s, view, orbit, .site(index)) { return (index, p) }
        }
        return nil
    }

    /// A seeded slot holding a well and a point that picks it, or nil.
    static func wellPoint(_ s: Snapshot, _ view: Vec2, _ orbit: ViewOrbit,
                          _ random: inout SeededRandom) -> (slot: Int, point: Vec2)? {
        let n: Int = s.wells.count
        let first: Int = below(n, &random)
        for i in 0..<n {
            let slot: Int = (first + i) % n
            guard let well = s.wells[slot] else { continue }
            if let p = near(project(G.cellCentre(well.cell), view, orbit), s, view, orbit, .well(slot)) {
                return (slot, p)
            }
        }
        return nil
    }

    /// A point on the scrubber at `fraction` that picks it, or nil.
    static func scrubPoint(_ fraction: Double, _ s: Snapshot, _ view: Vec2, _ orbit: ViewOrbit) -> Vec2? {
        near(project(G.scrubberPoint(fraction), view, orbit), s, view, orbit, .scrubber)
    }

    /// A seeded point of the dish field away from wells and sites, or nil.
    static func fieldPoint(_ s: Snapshot, _ view: Vec2, _ orbit: ViewOrbit, _ random: inout SeededRandom) -> Vec2? {
        let r: Double = G.rimRadius(s)
        for _ in 0..<40 {
            let a: Double = unit(&random) * 2 * Double.pi
            let d: Double = r * 0.92 * unit(&random).squareRoot()
            guard let p = project(SIMD3(d * cos(a), d * sin(a), G.planeZ), view, orbit) else { continue }
            if pick(p, s, view, orbit) == .field { return p }
        }
        return nil
    }

    /// A point that picks nothing: the first of the view's corners (8 points in) that does.
    static func emptyPoint(_ s: Snapshot, _ view: Vec2, _ orbit: ViewOrbit) -> Vec2? {
        let corners: [Vec2] = [Vec2(8, 8), Vec2(view.x - 8, 8), Vec2(8, view.y - 8), Vec2(view.x - 8, view.y - 8)]
        for c in corners where pick(c, s, view, orbit) == .empty { return c }
        return nil
    }

    /// The projected centre of a seeded site (any: free, the dragged well's own or another's), or nil.
    static func siteTarget(_ s: Snapshot, _ view: Vec2, _ orbit: ViewOrbit, _ random: inout SeededRandom) -> Vec2? {
        guard !s.sites.isEmpty else { return nil }
        return project(G.cellCentre(s.sites[below(s.sites.count, &random)]), view, orbit)
    }

    /// A seeded point off the dish: beyond the rim in the upper half (kept in the view), or a corner.
    static func offDish(_ s: Snapshot, _ view: Vec2, _ orbit: ViewOrbit, _ random: inout SeededRandom) -> Vec2 {
        let a: Double = (0.15 + 0.7 * unit(&random)) * Double.pi
        let r: Double = G.rimRadius(s) * (1.12 + 0.1 * unit(&random))
        if unit(&random) < 0.7, let p = project(SIMD3(r * cos(a), r * sin(a), G.planeZ), view, orbit) {
            return inside(p, view)
        }
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

    /// `orbit` turned by a midpoint movement of `delta` in `view` (90° per width, 60° per height, pitch up for an
    /// upward movement), clamped to yaw ±60° and pitch −20° … 35° — computed here on its own.
    static func turned(_ orbit: ViewOrbit, by delta: Vec2, view: Vec2) -> ViewOrbit {
        let yawLimit: Double = 60.0 * Double.pi / 180
        let yaw: Double = orbit.yaw + delta.x / view.x * (Double.pi / 2)
        let pitch: Double = orbit.pitch - delta.y / view.y * (Double.pi / 3)
        return ViewOrbit(yaw: min(max(yaw, -yawLimit), yawLimit),
                         pitch: min(max(pitch, -20.0 * Double.pi / 180), 35.0 * Double.pi / 180))
    }

    /// A controller (placing ``strength`` and ``sense``) turned to `orbit` by a two-finger drag in `view`.
    static func controller(at orbit: ViewOrbit, view: Vec2, snapshot: Snapshot) -> Controller {
        var controller: Controller = Controller(strength: strength, sense: sense)
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

    /// The presenter's side: the core every action is applied to, the drawn snapshot (rebuilt only after a kernel
    /// action; a shown tick copies it with the tick) and the presentation state.
    struct Presenter {
        var core: Core
        var drawn: Snapshot
        var preview: (slot: Int, target: Target)? = nil
        var frozen: Bool = false
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

        /// `s` with tick `t` shown.
        static func showing(_ s: Snapshot, _ t: Int) -> Snapshot {
            Snapshot(radius: s.radius, positions: s.positions, velocities: s.velocities, ticksSwum: s.ticksSwum,
                     shownTick: t, density: s.density, litStencil: s.litStencil, stray: s.stray, stencil: s.stencil,
                     sites: s.sites, wells: s.wells, coverage: s.coverage, requiredCoverage: s.requiredCoverage,
                     coherence: s.coherence, requiredCoherence: s.requiredCoherence, swarm: s.swarm,
                     coherenceRadius: s.coherenceRadius, failure: s.failure, stage: s.stage,
                     actionsLeft: s.actionsLeft, budget: s.budget, levelNumber: s.levelNumber, time: s.time)
        }

        /// Applies one kernel action through the adapter: accepted (setting `wanted` in `slot`, spending one action)
        /// while an action is left, else refused with the budget code and nothing changed.
        mutating func send(_ control: String, _ values: [Int], slot: Int, wanted: Well?, run: Int) throws {
            typealias T = MicroscopicAuroraGestureControllerTests
            kernel += 1
            let spent: Int = core.play.actionsSpent
            let left: Int = core.play.actionsLeft
            let before: StateDigest = try T.digest(core)
            let result: ActionResult = core.apply(T.action(control, values))
            if left > 0 {
                #expect(result == .accepted, "\(control) \(values) refused: \(result), run \(run)")
                if result == .accepted {
                    accepted += 1
                    #expect(core.play.wells[slot] == wanted && core.play.actionsSpent == spent + 1, "run \(run)")
                }
            } else {
                #expect(result == .rejected(.rule(code: MicroscopicAuroraError.budget.reasonCode)), "run \(run)")
                #expect(try T.digest(core) == before, "run \(run)")
            }
            preview = nil
            drawn = core.snapshot(time: 0)
        }

        /// Applies gesture action `a` through the adapter and checks its effect (see the file header).
        mutating func apply(_ a: Action, run: Int) throws {
            typealias T = MicroscopicAuroraGestureControllerTests
            let before: StateDigest = try T.digest(core)
            switch a {
            case let .place(slot, well):
                #expect(core.play.wells[slot] == nil, "a placement into a full slot, run \(run)")
                #expect(well.strength == T.strength && well.sense == T.sense, "run \(run)")
                try send("well.place", T.placeValues(slot, well), slot: slot, wanted: well, run: run)
                return
            case let .move(slot, well):
                let old: Well? = core.play.wells[slot]
                #expect(old != nil && old?.cell != well.cell, "run \(run)")
                #expect(old?.strength == well.strength && old?.sense == well.sense, "a move changed the well, run \(run)")
                try send("well.place", T.placeValues(slot, well), slot: slot, wanted: well, run: run)
                return
            case .remove(let slot):
                #expect(core.play.wells[slot] != nil, "run \(run)")
                try send("well.remove", [slot], slot: slot, wanted: nil, run: run)
                return
            case .showTick(let tick):
                #expect(core.apply(T.action("clock.show", [tick])) == .accepted, "run \(run)")
                #expect(core.shownTick == tick)
                drawn = Self.showing(drawn, tick)
            case let .preview(slot, target):
                if case .site(let cell) = target {
                    #expect(core.play.level.allows(cell), "a preview on a cell that is no site, run \(run)")
                }
                preview = (slot, target)
            case .clearPreview:
                preview = nil
            case .toggleFreeze:
                frozen.toggle()
            case .selectSlot(let slot):
                #expect(core.play.wells[slot] != nil, "run \(run)")
                selected = slot
            case .explain(let words):
                let known: [String] = [T.overText, T.wellText, T.fullText]
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
        for slot in s.wells.indices where s.wells[slot]?.cell == cell {
            return [.selectSlot(slot), .explain(wellText)]
        }
        for slot in s.wells.indices where s.wells[slot] == nil {
            return [.place(slot: slot, well: Well(cell: cell, strength: strength, sense: sense))]
        }
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
        var wellSlot: Int? = nil
        switch picked {
        case .site: result.state = .sitePress
        case .well(let slot):
            result.state = .wellPress
            wellSlot = slot
        case .scrubber: result.state = .scrubberPress
        case .field: result.state = .fieldPress
        case .empty: result.state = .emptyPress
        }
        let playing: Bool = s.stage == .playing
        var travel: Double = 0
        var dragging: Bool = false
        var target: Target? = nil
        var previewing: Bool = false
        var lastTick: Int = tick(origin, s, view, orbit)
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
                let t: Int = tick(st.point, s, view, orbit)
                if t != lastTick {
                    result.actions.append(.showTick(t))
                    lastTick = t
                    scrubbed = true
                }
            }
            if wellSlot != nil && !dragging && travel >= 16 {
                dragging = true
                if !playing { result.actions.append(.explain(overText)) }
            }
            if st.phase == .moved && dragging && playing, let slot = wellSlot {
                let t: Target? = drop(st.point, slot, s, view, orbit)
                if t != target {
                    target = t
                    if let change = t {
                        result.actions.append(.preview(slot: slot, target: change))
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
            case .well(let slot):
                record = nil
                if dragging && playing {
                    let t: Target? = drop(st.point, slot, s, view, orbit)
                    if let change = t, let w = s.wells[slot] {
                        switch change {
                        case .site(let cell):
                            result.actions.append(.move(slot: slot, well: Well(cell: cell, strength: w.strength,
                                                                               sense: w.sense)))
                        case .removal:
                            result.actions.append(.remove(slot: slot))
                        }
                    } else {
                        result.actions.append(.clearPreview)
                    }
                } else if tapped {
                    result.actions.append(.selectSlot(slot))
                    result.actions.append(.explain(wellText))
                }
            case .site(let i):
                record = nil
                if tapped { result.actions += siteTapExpected(i, s) }
            case .scrubber:
                record = nil
                if tapped && !scrubbed { result.actions.append(.showTick(tick(st.point, s, view, orbit))) }
            case .field:
                record = nil
                if tapped { result.actions.append(.toggleFreeze) }
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

    /// One seeded one-finger gesture (or two, for a double tap) of `kind` (0 … 13) on `s` in `view` at `orbit`, or nil
    /// without a target.
    static func scripts(_ kind: Int, _ s: Snapshot, _ view: Vec2, _ orbit: ViewOrbit,
                        _ random: inout SeededRandom) -> [[Step]]? {
        switch kind {
        case 0:   // a tap on an empty site, sometimes slow
            guard let site = emptySite(s, view, orbit, &random) else { return nil }
            let q: Vec2 = site.point + Vec2(unit(&random) * 6 - 3, unit(&random) * 6 - 3)
            let held: Double = unit(&random) < 0.15 ? 0.6 : 0.05 + 0.4 * unit(&random)
            return [tap(site.point, at: 1, lift: q, held: held)]
        case 1:   // a tap on a well
            guard let w = wellPoint(s, view, orbit, &random) else { return nil }
            return [tap(w.point, at: 1, lift: w.point + Vec2(unit(&random) * 6 - 3, 0), held: 0.08)]
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
        case 5:   // a tap on the dish field
            guard let p = fieldPoint(s, view, orbit, &random) else { return nil }
            return [tap(p, at: 1, held: 0.07)]
        case 6:   // a well drag to a seeded site (free, its own or another well's)
            guard let w = wellPoint(s, view, orbit, &random), let q = siteTarget(s, view, orbit, &random) else {
                return nil
            }
            return [path(w.point, q, steps: 3 + below(4, &random), time: 1)]
        case 7:   // a well drag off the dish
            guard let w = wellPoint(s, view, orbit, &random) else { return nil }
            return [path(w.point, offDish(s, view, orbit, &random), steps: 3 + below(4, &random), time: 1)]
        case 8:   // a well drag out to a site or off the dish and back to the well or to anywhere
            guard let w = wellPoint(s, view, orbit, &random) else { return nil }
            var out: Vec2 = offDish(s, view, orbit, &random)
            if unit(&random) < 0.5, let q = siteTarget(s, view, orbit, &random) { out = q }
            var back: Vec2 = w.point + Vec2(unit(&random) * 6 - 3, unit(&random) * 6 - 3)
            if unit(&random) < 0.3 { back = inside(Vec2(view.x * unit(&random), view.y * unit(&random)), view) }
            return [outAndBack(w.point, out, back, time: 1)]
        case 9:   // a short touch of 10 … 16 points from a well, a site or anywhere
            var p: Vec2 = inside(Vec2(view.x * unit(&random), view.y * unit(&random)), view)
            let r: Double = unit(&random)
            if r < 0.4, let w = wellPoint(s, view, orbit, &random) { p = w.point }
            if r >= 0.4 && r < 0.7, let site = emptySite(s, view, orbit, &random) { p = site.point }
            let a: Double = unit(&random) * 2 * Double.pi
            let length: Double = 10.5 + 5 * unit(&random)
            return [path(p, p + Vec2(cos(a) * length, sin(a) * length), steps: 2, time: 1)]
        case 10:  // a slow press (lifted 0.5 … 1.0 s after touch-down) moving under 10 points
            var start: Vec2? = wellPoint(s, view, orbit, &random)?.point
            let r: Double = unit(&random)
            if start == nil || r < 0.25 { start = emptySite(s, view, orbit, &random)?.point }
            if r > 0.75 { start = fieldPoint(s, view, orbit, &random) }
            guard let p = start else { return nil }
            let q: Vec2 = p + Vec2(unit(&random) * 8 - 4, unit(&random) * 8 - 4)
            return [[Step(phase: .began, point: p, time: 1), Step(phase: .moved, point: q, time: 1.2),
                     Step(phase: .ended, point: q, time: 1.5 + 0.5 * unit(&random))]]
        case 11:  // a cancelled well drag, perhaps to a seeded site first
            guard let w = wellPoint(s, view, orbit, &random) else { return nil }
            var q: Vec2 = w.point
            if unit(&random) < 0.7, let t = siteTarget(s, view, orbit, &random) { q = t }
            return [[Step(phase: .began, point: w.point, time: 1), Step(phase: .moved, point: q, time: 1.1),
                     Step(phase: .cancelled, point: q, time: 1.2)]]
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
        default:  // a drag from a site, the field or empty space
            var start: Vec2? = emptyPoint(s, view, orbit)
            let r: Double = unit(&random)
            if r < 0.35 { start = emptySite(s, view, orbit, &random)?.point }
            if r > 0.65 { start = fieldPoint(s, view, orbit, &random) }
            guard let p = start else { return nil }
            let a: Double = unit(&random) * 2 * Double.pi
            let length: Double = 20 + 200 * unit(&random)
            return [path(p, inside(p + Vec2(cos(a) * length, sin(a) * length), view), steps: 3, time: 1)]
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

    /// A seeded second-finger script: the first finger on a well (perhaps dragged to a seeded site) or the scrubber,
    /// a second finger cancels (only `clearPreview` when a preview was showing) and orbits; nothing kernel is sent,
    /// nothing at all after the clearing value, and the orbit turns by half the second finger's movement.
    static func secondFinger(_ controller: inout Controller, _ presenter: inout Presenter, _ view: Vec2,
                             _ orbit: ViewOrbit, run: Int, _ random: inout SeededRandom) throws -> [Action]? {
        let s: Snapshot = presenter.snapshot
        var start: Vec2? = wellPoint(s, view, orbit, &random)?.point
        var onWell: Bool = start != nil
        if unit(&random) < 0.3 {
            start = scrubPoint(unit(&random), s, view, orbit)
            onWell = false
        }
        guard let p = start else { return nil }
        var first: Vec2 = p
        var steps: [Step] = [Step(phase: .began, point: p, time: 1)]
        if onWell && unit(&random) < 0.7, let q = siteTarget(s, view, orbit, &random) {
            first = q
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

    /// A seeded `cancel()` in the middle of a press or a well drag: the finger's later events send nothing.
    static func systemCancel(_ controller: inout Controller, _ presenter: inout Presenter, _ view: Vec2,
                             _ orbit: ViewOrbit, run: Int, _ random: inout SeededRandom) throws -> [Action]? {
        let s: Snapshot = presenter.snapshot
        guard let w = wellPoint(s, view, orbit, &random) else { return nil }
        let q: Vec2 = unit(&random) < 0.4 ? w.point : (siteTarget(s, view, orbit, &random) ?? w.point)
        let steps: [Step] = [Step(phase: .began, point: w.point, time: 1), Step(phase: .moved, point: q, time: 1.05)]
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
        case .place: return "place"
        case .move: return "move"
        case .remove: return "remove"
        case .showTick: return "showTick"
        case .preview: return "preview"
        case .clearPreview: return "clearPreview"
        case .toggleFreeze: return "toggleFreeze"
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
        let kinds: Int = 16
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
            if kind == 14 {
                produced = try Self.secondFinger(&controller, &presenter, view, orbit, run: run, &random)
            } else if kind == 15 {
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
            if kind == 11 || kind == 14 || kind == 15 { #expect(kernel == 0, "run \(run)") }
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
        let names: [String] = ["place", "move", "remove", "showTick", "preview", "clearPreview", "toggleFreeze",
                               "selectSlot", "resetView", "explain"]
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
            var controller: Controller = Controller(strength: Self.strength, sense: Self.sense)
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
        // The default controller places strength 2, clockwise.
        var plain: Controller = Controller()
        #expect(plain.strength == 2 && plain.sense == .clockwise)
        _ = plain.handle(Self.event(1, .began, p, 1), viewSize: view, snapshot: s)
        let placed: [Action] = plain.handle(Self.event(1, .ended, p, 1.05), viewSize: view, snapshot: s)
        if case let .place(_, well) = try #require(placed.first) {
            #expect(well.strength == 2 && well.sense == .clockwise && well.cell == s.sites[site.index])
        } else {
            Issue.record("no placement: \(placed)")
        }
        // A tap on the field toggles the freeze; on the scrubber shows the tick under the finger; slow ones nothing.
        let f: Vec2 = try #require(Self.fieldPoint(s, view, .authored, &random))
        #expect(play(Self.tap(f, at: 1)) == [.toggleFreeze])
        #expect(play(Self.tap(f, at: 1, held: 0.5)).isEmpty)
        let r: Vec2 = try #require(Self.scrubPoint(0.7, s, view, .authored))
        #expect(play(Self.tap(r, at: 1)) == [.showTick(Self.tick(r, s, view, .authored))])
        #expect(play(Self.tap(r, at: 1, held: 0.5)).isEmpty)
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
        // A completed double tap starts no new one; a slow first tap starts none; a field tap between breaks it.
        #expect(play(Self.tap(e, at: 1) + Self.tap(e, at: 1.2) + Self.tap(e, at: 1.4)) == [.resetView])
        #expect(play(Self.tap(e, at: 1, held: 0.6) + Self.tap(e, at: 1.8)).isEmpty)
        #expect(play(Self.tap(e, at: 1) + Self.tap(f, at: 1.1) + Self.tap(e, at: 1.2)) == [.toggleFreeze])
        #expect(Controller.tapDistance == 10 && Controller.dragDistance == 16 && Controller.tapDuration == 0.5)
        #expect(Controller.doubleTapWindow == 0.35 && Controller.doubleTapDistance == 22)
        #expect(Controller.finishedReason == Self.overText && Controller.wellReason == Self.wellText)
        #expect(Controller.fullReason == Self.fullText)
    }

    @Test func tapsOnWellsSitesAndFinishedPlaysExplain() throws {
        let view: Vec2 = Self.views[0]
        var full: Int = 0
        var over: Int = 0
        var wells: Int = 0
        for number in Self.levels {
            for c in try Self.cases(number) {
                let s: Snapshot = c.snapshot
                var random: SeededRandom = SeededRandom(seed: Self.seed + UInt64(number))
                if let w = Self.wellPoint(s, view, .authored, &random) {
                    var controller: Controller = Controller(strength: Self.strength, sense: Self.sense)
                    var presenter: Presenter = Presenter(core: c.core)
                    let got = try Self.run(&controller, Self.tap(w.point, at: 1), view: view, presenter: &presenter,
                                           run: -1)
                    #expect(got.state == .wellPress)
                    #expect(got.actions == [.selectSlot(w.slot), .explain(Self.wellText)], "\(got.actions)")
                    #expect(presenter.selected == w.slot)
                    wells += 1
                }
                guard let site = Self.emptySite(s, view, .authored, &random) else { continue }
                var controller: Controller = Controller(strength: Self.strength, sense: Self.sense)
                var presenter: Presenter = Presenter(core: c.core)
                let got = try Self.run(&controller, Self.tap(site.point, at: 1), view: view, presenter: &presenter,
                                       run: -1)
                #expect(got.state == .sitePress)
                var free: Bool = false
                for w in s.wells where w == nil { free = true }
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
        #expect(full > 0 && over > 0 && wells > 0, "full \(full) over \(over) wells \(wells)")
    }

    /// A free site of `s` (no well on it) other than slot `slot`'s, whose projected centre is at least 40 points from
    /// `from` and drops back exactly onto it, at the authored orbit in `view`; nil when none.
    static func freeSiteTarget(_ s: Snapshot, slot: Int, from: Vec2, _ view: Vec2) -> (point: Vec2, cell: Cell)? {
        for index in s.sites.indices where !occupied(index, s) {
            guard let q = project(G.cellCentre(s.sites[index]), view, .authored), (q - from).length >= 40 else {
                continue
            }
            if drop(q, slot, s, view, .authored) == .site(s.sites[index]) { return (q, s.sites[index]) }
        }
        return nil
    }

    @Test func wellDragsPreviewMoveRemoveOrExplain() throws {
        let view: Vec2 = Self.views[2]
        var moved: Int = 0
        var removed: Int = 0
        var over: Int = 0
        for number in Self.levels {
            for c in try Self.cases(number) {
                let s: Snapshot = c.snapshot
                var random: SeededRandom = SeededRandom(seed: Self.seed)
                guard let w = Self.wellPoint(s, view, .authored, &random), let well = s.wells[w.slot] else { continue }
                let off: Vec2 = Vec2(8, 8)
                #expect(Self.drop(off, w.slot, s, view, .authored) == .removal)
                // Off the dish: removal previewed, then removed (or explained once outside playing).
                var controller: Controller = Controller()
                var presenter: Presenter = Presenter(core: c.core)
                let gone = try Self.run(&controller, Self.path(w.point, off, steps: 6, time: 1), view: view,
                                        presenter: &presenter, run: -1)
                #expect(gone.state == .wellPress)
                if s.stage == .playing {
                    #expect(gone.actions.contains(.preview(slot: w.slot, target: .removal)), "\(gone.actions)")
                    #expect(gone.actions.last == .remove(slot: w.slot), "\(gone.actions)")
                    removed += 1
                } else {
                    #expect(gone.actions == [.explain(Self.overText)], "\(gone.actions)")
                    #expect(presenter.core.play == c.core.play)
                    over += 1
                }
                // To a free site: previewed, then one move with the same strength and sense.
                if s.stage == .playing, let t = Self.freeSiteTarget(s, slot: w.slot, from: w.point, view) {
                    var mover: Controller = Controller()
                    var pres: Presenter = Presenter(core: c.core)
                    let got = try Self.run(&mover, Self.path(w.point, t.point, steps: 6, time: 1), view: view,
                                           presenter: &pres, run: -1)
                    let wanted: Well = Well(cell: t.cell, strength: well.strength, sense: well.sense)
                    #expect(got.actions.contains(.preview(slot: w.slot, target: .site(t.cell))), "\(got.actions)")
                    #expect(got.actions.last == .move(slot: w.slot, well: wanted), "\(got.actions)")
                    moved += 1
                    // Out to the site and back to the well: previewed, then cleared; nothing sent.
                    var back: Controller = Controller()
                    var still: Presenter = Presenter(core: c.core)
                    let none: [Action] = try Self.run(&back, Self.outAndBack(w.point, t.point, w.point, time: 1),
                                                      view: view, presenter: &still, run: -1).actions
                    if Self.drop(w.point, w.slot, s, view, .authored) == nil {
                        #expect(none.last == .clearPreview && !none.contains(.move(slot: w.slot, well: wanted)))
                        #expect(try Self.digest(still.core) == Self.digest(c.core))
                    }
                    // A cancelled drag clears its preview and sends nothing else.
                    var cancelled: Controller = Controller()
                    var cpres: Presenter = Presenter(core: c.core)
                    var steps: [Step] = Self.path(w.point, t.point, steps: 4, time: 1)
                    steps[steps.count - 1] = Step(phase: .cancelled, point: t.point, time: 1.2)
                    let lost: [Action] = try Self.run(&cancelled, steps, view: view, presenter: &cpres,
                                                      run: -1).actions
                    var kernel: Bool = false
                    for a in lost where Self.isKernel(a) { kernel = true }
                    #expect(!kernel && lost.last == .clearPreview, "\(lost)")
                    #expect(cpres.core.play == c.core.play)
                }
                // 10 … 16 points from the well: nothing.
                var short: Controller = Controller()
                var quiet: Presenter = Presenter(core: c.core)
                let shortSteps: [Step] = Self.path(w.point, w.point + Vec2(0, 13), steps: 2, time: 1)
                #expect(try Self.run(&short, shortSteps, view: view, presenter: &quiet, run: -1).actions.isEmpty)
            }
        }
        #expect(moved > 0 && removed > 0 && over > 0, "moved \(moved) removed \(removed) over \(over)")
    }

    @Test func scrubDragsShowEveryTickInAnyStage() throws {
        let view: Vec2 = Self.views[1]
        var checked: Int = 0
        var stages: Set<String> = []
        for number in Self.levels {
            for c in try Self.cases(number) {
                let s: Snapshot = c.snapshot
                guard let a = Self.scrubPoint(0, s, view, .authored) else { continue }
                var steps: [Step] = [Step(phase: .began, point: a, time: 1)]
                var want: [Action] = []
                var last: Int = Self.tick(a, s, view, .authored)
                var time: Double = 1
                var end: Vec2 = a
                for i in 1...40 {
                    guard let q = Self.project(G.scrubberPoint(Double(i) / 40), view, .authored) else { continue }
                    time += 0.02
                    steps.append(Step(phase: .moved, point: q, time: time))
                    let t: Int = Self.tick(q, s, view, .authored)
                    if t != last {
                        want.append(.showTick(t))
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
                #expect(want.last == .showTick(s.ticksSwum) && want.count >= 30)
                #expect(presenter.core.shownTick == s.ticksSwum)
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
        // Far to the right and up: yaw and pitch clamp.
        let far: [Action] = Self.twoFingers(&controller, a: Vec2(100, 400), b: Vec2(300, 400),
                                            by: Vec2(view.x * 3, -view.y * 3), view: view, snapshot: s, time: 0)
        #expect(far.isEmpty)
        #expect(Self.near(controller.orbit, ViewOrbit(yaw: ViewOrbit.yawLimit, pitch: ViewOrbit.pitchRange.upperBound)))
        #expect(controller.camera(viewSize: view) == G.camera(aspect: view.x / view.y, orbit: controller.orbit))
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
