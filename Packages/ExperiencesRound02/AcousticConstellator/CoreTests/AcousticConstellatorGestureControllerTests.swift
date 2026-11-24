// AcousticConstellatorGestureControllerTests — feature 424 (R02-G13-04) T-R02G1304-003 (FR-R02G1304-001 … 004, 006;
// SC-R02G1304-001 … 003; clarifications Q1 … Q5). 500 seeded (LCG seed 2_424) scripted gestures — taps on stars, on
// gauge targets, on links and on empty space, link drags from stars (towards unlinked, player-linked and fixed
// partners, or nowhere), drags from links, gauges and empty space, touches of 10 … 16 points, slow presses, cancelled
// touches, random touches, second fingers, double taps on empty space and system cancels — on certified levels 1, 50
// and 100 (the opening and the moment after the certified links and nudges before the listen, both playing; paused; won;
// failed by a bare listen), at three view sizes and three orbits reached by two-finger drags, send exactly the actions
// an independent expectation written here predicts. What lies under the finger is computed here on its own from the
// public geometry (`starCentre`, `splinePoint`, `coherenceBar`, `holdPip`, the orbit camera and `project`) in the
// clarified order (gauge targets, stars, links, each within 22 points); the arbitration (tap, drag or nothing by travel
// and event timestamps; choose, choosePair, preview, link, unlink, nudge and listen by clarifications Q2 and Q3; no
// kernel action outside playing; the orbit arithmetic) is written here too. Every kernel action sent is on a playing
// case and is applied through `AcousticConstellatorExperienceCore`: accepted, except a link the degree or link limit
// refuses (predicted here); second fingers, `.cancelled` phases, `cancel()` and finished plays send no kernel action;
// fixed pairs send none; the orbit clamps and a third finger re-bases it; a double tap on empty space resets the view;
// the orbit never changes the adapter's digest. Plain loops and explicit types (CI type-check rule); each test well
// under 10 s once the levels are certified.
import Foundation
import Testing
import VisualCoreExperience
import VisualCoreMath
import VisualCoreScenes
import VisualCoreSimulation
@testable import AcousticConstellatorCore

@Suite struct AcousticConstellatorGestureControllerTests {
    typealias Controller = AcousticConstellatorGestureController
    typealias Snapshot = AcousticConstellatorSceneSnapshot
    typealias Action = AcousticConstellatorGestureAction
    typealias Geometry = AcousticConstellatorSceneGeometry
    typealias Orbit = AcousticConstellatorOrbit
    typealias Core = AcousticConstellatorExperienceCore
    typealias Play = AcousticConstellatorPlay
    typealias Link = AcousticConstellatorLink

    /// The seed of every random choice here.
    static let seed: UInt64 = 2_424
    /// The view sizes every script runs at: phone portrait, tablet landscape, tablet portrait.
    static let views: [Vec2] = [Vec2(390, 844), Vec2(1_180, 820), Vec2(1_024, 1_366)]
    /// The scripted orbits (the first is the authored one), reached by two-finger drags.
    static let orbits: [Orbit] = [.authored, Orbit(yaw: 0.3, pitch: 0.2), Orbit(yaw: -0.45, pitch: -0.15)]
    /// The certified levels used.
    static let levels: [Int] = [1, 50, 100]
    /// The touch target in view points (clarification Q1), written here on its own.
    static let reach: Double = 22
    /// Distances within this many points of the best so far tie (to the earlier candidate).
    static let tie: Double = 1e-6
    /// The adapter's reason code for a refused action.
    static let actionCode: String = "r02-g13.action"

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
        case let .link(u, v):
            return ExperienceAction(control: "link.add", values: [Double(u), Double(v)], step: 0)
        case let .unlink(u, v):
            return ExperienceAction(control: "link.remove", values: [Double(u), Double(v)], step: 0)
        case let .nudge(star):
            return ExperienceAction(control: "star.nudge", values: [Double(star), 1], step: 0)
        case .listen:
            return ExperienceAction(control: "constellation.listen", values: [], step: 0)
        case .choose, .choosePair, .preview, .resetView:
            return nil
        }
    }

    /// The adapter action of a kernel action.
    static func adapterAction(kernel a: AcousticConstellatorAction) -> ExperienceAction {
        switch a {
        case let .link(u, v):
            return ExperienceAction(control: "link.add", values: [Double(u), Double(v)], step: 0)
        case let .unlink(u, v):
            return ExperienceAction(control: "link.remove", values: [Double(u), Double(v)], step: 0)
        case let .nudge(star, step):
            return ExperienceAction(control: "star.nudge", values: [Double(star), Double(step)], step: 0)
        case .listen:
            return ExperienceAction(control: "constellation.listen", values: [], step: 0)
        }
    }

    /// Whether `a` is a kernel action (link, unlink, nudge or listen).
    static func isKernel(_ a: Action) -> Bool { adapterAction(a) != nil }

    /// The digest of `core` as the engine computes it.
    static func digest(_ core: Core) throws -> String {
        var builder: DigestBuilder = DigestBuilder(domain: Core.experienceID)
        try core.writeDigest(into: &builder)
        return builder.finish().hex
    }

    /// A case of `core` at presentation time 1 s.
    static func make(_ core: Core) -> Case { Case(core: core, snapshot: core.snapshot(time: 1)) }

    /// Certified level `number`: the opening (playing), the moment after its certified links and nudges before the
    /// listen (playing), the opening paused, after the certified win (won) and the opening failed by a bare listen.
    static func cases(_ number: Int) throws -> [Case] {
        let actions: [AcousticConstellatorAction] =
            AcousticConstellatorSolver.actions(try Core.generated(number: number).plan)
        try #require(actions.count >= 2)
        try #require(actions[actions.count - 1] == .listen)
        let opening: Core = try Core.opening(number: number)
        var core: Core = opening
        var index: Int = 0
        while index < actions.count - 1 {
            #expect(core.apply(adapterAction(kernel: actions[index])) == .accepted)
            index += 1
        }
        #expect(core.play.stage == .playing)
        let placed: Case = make(core)
        #expect(core.apply(adapterAction(kernel: .listen)) == .accepted)
        #expect(core.play.stage == .won)
        let won: Case = make(core)
        var paused: Play = opening.play
        try paused.handle(.pause)
        var failed: Core = opening
        #expect(failed.apply(adapterAction(kernel: .listen)) == .accepted)
        #expect(failed.play.stage == .failed)
        return [make(opening), placed, Case(core: nil, snapshot: Snapshot(play: paused, levelNumber: number, time: 1)),
                won, make(failed)]
    }

    /// Every case of ``levels``.
    static func allCases() throws -> [Case] {
        var all: [Case] = []
        for number in levels { all += try cases(number) }
        return all
    }

    // MARK: Independent geometry and pick

    /// The camera of `snapshot` in `view` at `orbit`.
    static func camera(_ snapshot: Snapshot, view: Vec2, orbit: Orbit) -> AcousticConstellatorCamera {
        Geometry.camera(snapshot, aspect: view.x / view.y, orbit: orbit)
    }

    /// The view point of `world` through `camera` in `view`, or nil behind the eye.
    static func screen(_ world: SIMD3<Double>, camera: AcousticConstellatorCamera, view: Vec2) -> Vec2? {
        guard let p = Geometry.project(world, camera: camera) else { return nil }
        return Vec2(p.x * view.x, p.y * view.y)
    }

    /// The view point of `world` for `snapshot` in `view` at `orbit`, or nil behind the eye.
    static func screen(_ world: SIMD3<Double>, snapshot: Snapshot, view: Vec2, orbit: Orbit) -> Vec2? {
        screen(world, camera: camera(snapshot, view: view, orbit: orbit), view: view)
    }

    /// The distance from `p` to the segment `a` … `b` (to `a` for a segment of no length), written here on its own.
    static func segment(_ p: Vec2, _ a: Vec2, _ b: Vec2) -> Double {
        let d: Vec2 = b - a
        let l2: Double = d.x * d.x + d.y * d.y
        guard l2 > 0 else { return (p - a).length }
        let w: Vec2 = p - a
        let t: Double = (w.x * d.x + w.y * d.y) / l2
        if t <= 0 { return (p - a).length }
        if t >= 1 { return (p - b).length }
        return (p - (a + d * t)).length
    }

    /// What lies under a point, written here on its own (clarification Q1).
    enum Under: Equatable {
        case coherence(Int), hold(Int), star(Int), link(Int), empty
    }

    /// The other star whose projected centre lies nearest `p` within 22 points (ties to the lower index), skipping
    /// `excluding`; nil for none.
    static func starNear(_ p: Vec2, snapshot: Snapshot, view: Vec2, orbit: Orbit, excluding: Int?) -> Int? {
        let cam: AcousticConstellatorCamera = camera(snapshot, view: view, orbit: orbit)
        var best: Int? = nil
        var bestDistance: Double = Double.infinity
        var index: Int = 0
        while index < snapshot.stars.count {
            if index != excluding,
               let q = screen(Geometry.starCentre(index, snapshot), camera: cam, view: view) {
                let d: Double = (p - q).length
                if d <= reach && d < bestDistance - tie {
                    best = index
                    bestDistance = d
                }
            }
            index += 1
        }
        return best
    }

    /// What lies under `p`: a coherence bar or hold pip within 22 points (nearest; ties to the coherence bars, then the
    /// lower index); else a star; else a link (its 16-segment projected spline); else empty space.
    static func under(_ p: Vec2, snapshot: Snapshot, view: Vec2, orbit: Orbit) -> Under {
        let cam: AcousticConstellatorCamera = camera(snapshot, view: view, orbit: orbit)
        var gauge: Under = .empty
        var gaugeDistance: Double = Double.infinity
        var bar: Int = 0
        while bar < 12 {
            if let q = screen(Geometry.coherenceBar(bar, snapshot), camera: cam, view: view) {
                let d: Double = (p - q).length
                if d <= reach && d < gaugeDistance - tie {
                    gauge = .coherence(bar)
                    gaugeDistance = d
                }
            }
            bar += 1
        }
        var pip: Int = 0
        while pip < snapshot.hold {
            if let q = screen(Geometry.holdPip(pip, snapshot), camera: cam, view: view) {
                let d: Double = (p - q).length
                if d <= reach && d < gaugeDistance - tie {
                    gauge = .hold(pip)
                    gaugeDistance = d
                }
            }
            pip += 1
        }
        if gauge != .empty { return gauge }
        if let s = starNear(p, snapshot: snapshot, view: view, orbit: orbit, excluding: nil) { return .star(s) }
        var best: Int? = nil
        var bestDistance: Double = Double.infinity
        var index: Int = 0
        while index < snapshot.links.count {
            let a: SIMD3<Double> = Geometry.starCentre(snapshot.links[index].a, snapshot)
            let b: SIMD3<Double> = Geometry.starCentre(snapshot.links[index].b, snapshot)
            var previous: Vec2? = screen(a, camera: cam, view: view)
            var step: Int = 1
            while step <= 16 {
                let next: Vec2? = screen(Geometry.splinePoint(a, b, u: Double(step) / 16), camera: cam, view: view)
                if let u = previous, let v = next {
                    let d: Double = segment(p, u, v)
                    if d <= reach && d < bestDistance - tie {
                        best = index
                        bestDistance = d
                    }
                }
                previous = next
                step += 1
            }
            index += 1
        }
        if let index = best { return .link(index) }
        return .empty
    }

    /// `p` kept one point inside `view`.
    static func inside(_ p: Vec2, _ view: Vec2) -> Vec2 {
        Vec2(min(max(p.x, 1), view.x - 1), min(max(p.y, 1), view.y - 1))
    }

    /// A point within 6 points of a seeded star's projected centre.
    static func starPoint(_ snapshot: Snapshot, view: Vec2, orbit: Orbit, random: inout LCG) -> Vec2? {
        guard !snapshot.stars.isEmpty else { return nil }
        let star: Int = random.below(snapshot.stars.count)
        guard let p = screen(Geometry.starCentre(star, snapshot), snapshot: snapshot, view: view, orbit: orbit) else {
            return nil
        }
        return inside(p + Vec2(random.unit() * 12 - 6, random.unit() * 12 - 6), view)
    }

    /// A point within 6 points of a seeded coherence bar's or hold pip's projected centre.
    static func gaugePoint(_ snapshot: Snapshot, view: Vec2, orbit: Orbit, random: inout LCG) -> Vec2? {
        var world: SIMD3<Double> = Geometry.coherenceBar(random.below(12), snapshot)
        if random.unit() < 0.4 { world = Geometry.holdPip(random.below(max(snapshot.hold, 1)), snapshot) }
        guard let p = screen(world, snapshot: snapshot, view: view, orbit: orbit) else { return nil }
        return inside(p + Vec2(random.unit() * 12 - 6, random.unit() * 12 - 6), view)
    }

    /// A point near a seeded link: 25 … 75 % along its spline, up to 4 points off it.
    static func linkPoint(_ snapshot: Snapshot, view: Vec2, orbit: Orbit, random: inout LCG) -> Vec2? {
        guard !snapshot.links.isEmpty else { return nil }
        let link: Link = snapshot.links[random.below(snapshot.links.count)]
        let a: SIMD3<Double> = Geometry.starCentre(link.a, snapshot)
        let b: SIMD3<Double> = Geometry.starCentre(link.b, snapshot)
        let u: Double = 0.25 + 0.5 * random.unit()
        guard let p = screen(Geometry.splinePoint(a, b, u: u), snapshot: snapshot, view: view, orbit: orbit) else {
            return nil
        }
        return inside(p + Vec2(random.unit() * 8 - 4, random.unit() * 8 - 4), view)
    }

    /// A point that picks nothing: the first of the view's corners (8 points in) that does.
    static func emptyPoint(_ snapshot: Snapshot, view: Vec2, orbit: Orbit) -> Vec2? {
        let corners: [Vec2] = [Vec2(8, 8), Vec2(view.x - 8, 8), Vec2(8, view.y - 8), Vec2(view.x - 8, view.y - 8)]
        for c in corners where under(c, snapshot: snapshot, view: view, orbit: orbit) == .empty {
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

    /// What a one-finger script must send and the state after touch-down.
    struct Expectation {
        var actions: [Action]
        var state: Controller.State
    }

    /// The release of a playing link drag from `star` to `aim`: link, unlink or (fixed) nothing, then the pair.
    static func expectedLink(_ star: Int, _ aim: Int, snapshot: Snapshot) -> [Action] {
        let a: Int = min(star, aim)
        let b: Int = max(star, aim)
        var fixed: Bool = false
        for l in snapshot.fixedLinks where l.a == a && l.b == b { fixed = true }
        var linked: Bool = false
        for l in snapshot.links where l.a == a && l.b == b { linked = true }
        if fixed { return [.choosePair(star, aim)] }
        if linked { return [.unlink(a, b), .choosePair(star, aim)] }
        return [.link(a, b), .choosePair(star, aim)]
    }

    /// The expectation of one-finger `steps` (the first a `.began`, the last an `.ended` or a `.cancelled`) on
    /// `snapshot` in `view` at `orbit`, written on its own from clarifications Q1 … Q4.
    static func expected(_ steps: [Step], snapshot: Snapshot, view: Vec2, orbit: Orbit) -> Expectation {
        let origin: Vec2 = steps[0].point
        let startTime: Double = steps[0].time
        let picked: Under = under(origin, snapshot: snapshot, view: view, orbit: orbit)
        let playing: Bool = snapshot.stage == .playing
        var result: Expectation = Expectation(actions: [], state: .idle)
        switch picked {
        case .star: result.state = .starPress
        case .coherence, .hold: result.state = .targetPress
        case .link: result.state = .linkPress
        case .empty: result.state = .idle
        }
        var travel: Double = 0
        var dragging: Bool = false
        var shownAt: Vec2? = nil
        var aim: Int? = nil
        var index: Int = 1
        while index < steps.count {
            let s: Step = steps[index]
            index += 1
            if s.phase == .cancelled { break }
            travel = max(travel, (s.point - origin).length)
            if case .star(let k) = picked {
                if !dragging && travel >= 16 { dragging = true }
                if dragging && playing && s.point != shownAt {
                    shownAt = s.point
                    aim = starNear(s.point, snapshot: snapshot, view: view, orbit: orbit, excluding: k)
                    result.actions.append(.preview(from: k, target: aim, point: SIMD2(s.point.x, s.point.y)))
                }
            }
            guard s.phase == .ended else { continue }
            let tap: Bool = !dragging && travel < 10 && s.time - startTime < 0.5
            switch picked {
            case .star(let k):
                if dragging {
                    if playing, let t = aim { result.actions += expectedLink(k, t, snapshot: snapshot) }
                } else if tap {
                    result.actions += playing ? [.nudge(star: k), .choose(star: k)] : [.choose(star: k)]
                }
            case .link(let i):
                if tap { result.actions.append(.choosePair(snapshot.links[i].a, snapshot.links[i].b)) }
            case .coherence, .hold:
                if tap && playing { result.actions.append(.listen) }
            case .empty:
                break
            }
        }
        return result
    }

    /// A drag end for a link drag from a star at `p`: near a fixed partner, a player-linked partner, an unlinked star
    /// or a random place.
    static func dragEnd(_ p: Vec2, snapshot: Snapshot, view: Vec2, orbit: Orbit, random: inout LCG) -> Vec2 {
        let start: Int? = starNear(p, snapshot: snapshot, view: view, orbit: orbit, excluding: nil)
        var partners: [Int] = []
        let choice: Double = random.unit()
        if let s = start {
            let pool: [Link] = choice < 0.35 ? snapshot.fixedLinks : snapshot.links
            for l in pool where l.a == s || l.b == s { partners.append(l.a == s ? l.b : l.a) }
            if choice >= 0.7 || partners.isEmpty {
                partners = []
                for i in snapshot.stars.indices where i != s { partners.append(i) }
            }
        }
        if !partners.isEmpty && choice < 0.92,
           let q = screen(Geometry.starCentre(partners[random.below(partners.count)], snapshot), snapshot: snapshot,
                          view: view, orbit: orbit) {
            return inside(q + Vec2(random.unit() * 10 - 5, random.unit() * 10 - 5), view)
        }
        return inside(Vec2(view.x * random.unit(), view.y * random.unit()), view)
    }

    /// One seeded one-finger script of `kind` (0 … 9) on `snapshot` in `view` at `orbit`, or nil without a target.
    static func script(_ kind: Int, snapshot: Snapshot, view: Vec2, orbit: Orbit, random: inout LCG) -> [Step]? {
        switch kind {
        case 0:   // a tap on a star
            guard let p = starPoint(snapshot, view: view, orbit: orbit, random: &random) else { return nil }
            let q: Vec2 = p + Vec2(random.unit() * 6 - 3, random.unit() * 6 - 3)
            return [Step(phase: .began, point: p, time: 1),
                    Step(phase: .ended, point: q, time: 1.05 + 0.4 * random.unit())]
        case 1:   // a tap on a coherence bar or a hold pip
            guard let p = gaugePoint(snapshot, view: view, orbit: orbit, random: &random) else { return nil }
            return [Step(phase: .began, point: p, time: 1),
                    Step(phase: .ended, point: p, time: 1.05 + 0.4 * random.unit())]
        case 2:   // a tap on a link
            guard let p = linkPoint(snapshot, view: view, orbit: orbit, random: &random) else { return nil }
            return [Step(phase: .began, point: p, time: 1),
                    Step(phase: .ended, point: p + Vec2(random.unit() * 4, 0), time: 1.1)]
        case 3:   // a single tap on empty space
            guard let e = emptyPoint(snapshot, view: view, orbit: orbit) else { return nil }
            return [Step(phase: .began, point: e, time: 1), Step(phase: .ended, point: e, time: 1.1)]
        case 4:   // a link drag from a star
            guard let p = starPoint(snapshot, view: view, orbit: orbit, random: &random) else { return nil }
            let end: Vec2 = dragEnd(p, snapshot: snapshot, view: view, orbit: orbit, random: &random)
            return path(p, end, steps: 2 + random.below(7), time: 1)
        case 5:   // a drag from a link, a gauge or empty space
            var start: Vec2? = nil
            let choice: Int = random.below(3)
            if choice == 0 { start = linkPoint(snapshot, view: view, orbit: orbit, random: &random) }
            if choice == 1 { start = gaugePoint(snapshot, view: view, orbit: orbit, random: &random) }
            if start == nil { start = emptyPoint(snapshot, view: view, orbit: orbit) }
            guard let p = start else { return nil }
            let angle: Double = random.unit() * 2 * Double.pi
            let length: Double = 20 + 200 * random.unit()
            return path(p, p + Vec2(cos(angle) * length, sin(angle) * length), steps: 3, time: 1)
        case 6:   // a short touch of 10 … 16 points from a star, a link, a gauge or anywhere
            var p: Vec2 = inside(Vec2(view.x * random.unit(), view.y * random.unit()), view)
            let choice: Int = random.below(4)
            if choice == 0, let s = starPoint(snapshot, view: view, orbit: orbit, random: &random) { p = s }
            if choice == 1, let l = linkPoint(snapshot, view: view, orbit: orbit, random: &random) { p = l }
            if choice == 2, let g = gaugePoint(snapshot, view: view, orbit: orbit, random: &random) { p = g }
            let angle: Double = random.unit() * 2 * Double.pi
            let length: Double = 10.5 + 5 * random.unit()
            return path(p, p + Vec2(cos(angle) * length, sin(angle) * length), steps: 2, time: 1)
        case 7:   // a slow press (lifted 0.5 … 1.0 s after touch-down) moving under 10 points
            var start: Vec2? = random.unit() < 0.5 ? starPoint(snapshot, view: view, orbit: orbit, random: &random)
                : gaugePoint(snapshot, view: view, orbit: orbit, random: &random)
            if start == nil { start = emptyPoint(snapshot, view: view, orbit: orbit) }
            guard let p = start else { return nil }
            let q: Vec2 = p + Vec2(random.unit() * 8 - 4, random.unit() * 8 - 4)
            let lift: Double = 1.5 + 0.5 * random.unit()
            return [Step(phase: .began, point: p, time: 1), Step(phase: .moved, point: q, time: 1.2),
                    Step(phase: .ended, point: q, time: lift)]
        case 8:   // a cancelled touch on a star or a gauge, perhaps dragged first
            var start: Vec2? = gaugePoint(snapshot, view: view, orbit: orbit, random: &random)
            if random.unit() < 0.6 || start == nil {
                start = starPoint(snapshot, view: view, orbit: orbit, random: &random)
            }
            guard let p = start else { return nil }
            let q: Vec2 = random.unit() < 0.4 ? p
                : dragEnd(p, snapshot: snapshot, view: view, orbit: orbit, random: &random)
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
        if kind == 8 {
            for a in got.actions { #expect(!isKernel(a), "a cancelled touch sent \(a), run \(run)") }
        }
        if kind == 3 || kind == 6 || kind == 7 { #expect(got.actions.isEmpty, "run \(run) kind \(kind)") }
        if kind == 5, case .star = under(s[0].point, snapshot: snapshot, view: view, orbit: orbit) {
            // A link or gauge point that lies within reach of a star picks the star (stars come before links).
        } else if kind == 5 {
            #expect(got.actions.isEmpty, "run \(run) kind \(kind)")
        }
        #expect(controller.state == .idle)
        #expect(near(controller.orbit, orbit))
        return got.actions
    }

    /// A seeded second-finger script: the first finger on a star or a gauge (perhaps dragged first), a second finger
    /// cancels and orbits; nothing kernel is sent and nothing at all from then on, and the orbit turns by half the
    /// second finger's movement.
    static func secondFingerScript(_ controller: inout Controller, snapshot: Snapshot, view: Vec2, orbit: Orbit,
                                   run: Int, random: inout LCG) -> [Action]? {
        var start: Vec2? = nil
        if random.unit() < 0.3 { start = gaugePoint(snapshot, view: view, orbit: orbit, random: &random) }
        if start == nil { start = starPoint(snapshot, view: view, orbit: orbit, random: &random) }
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
        guard under(second, snapshot: snapshot, view: view, orbit: orbit) == .empty else { return nil }
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
        guard let p = starPoint(snapshot, view: view, orbit: orbit, random: &random) else { return nil }
        let q: Vec2 = random.unit() < 0.5 ? p : dragEnd(p, snapshot: snapshot, view: view, orbit: orbit, random: &random)
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
        case .choosePair: return "choosePair"
        case .preview: return "preview"
        case .link: return "link"
        case .unlink: return "unlink"
        case .nudge: return "nudge"
        case .listen: return "listen"
        case .resetView: return "resetView"
        }
    }

    /// Whether the kernel takes a new link between `a` and `b` on `play` (degree and link limits), written here on
    /// its own.
    static func linkFits(_ a: Int, _ b: Int, play: Play) -> Bool {
        var degreeA: Int = 0
        var degreeB: Int = 0
        for l in play.links {
            if l.a == a || l.b == a { degreeA += 1 }
            if l.a == b || l.b == b { degreeB += 1 }
        }
        return degreeA < play.level.degreeLimit && degreeB < play.level.degreeLimit
            && play.links.count < play.level.linkLimit
    }

    /// Applies kernel action `a` to `core` through the adapter and checks the result and its effect; returns whether
    /// it was accepted.
    static func applyKernel(_ a: Action, to core: inout Core, run: Int) -> Bool {
        guard let adapter = adapterAction(a) else { return false }
        let before: Play = core.play
        var expectAccepted: Bool = true
        if case let .link(u, v) = a { expectAccepted = linkFits(u, v, play: before) }
        let result: ActionResult = core.apply(adapter)
        if expectAccepted {
            #expect(result == .accepted, "adapter refused \(a): \(result), run \(run)")
        } else {
            #expect(result == .rejected(.rule(code: actionCode)), "\(a) over a limit: \(result), run \(run)")
            #expect(core.play == before)
            return false
        }
        guard result == .accepted else { return false }
        #expect(core.play.actionsSpent == before.actionsSpent + 1)
        switch a {
        case let .link(u, v):
            #expect(core.play.links.contains(Link.between(u, v)))
        case let .unlink(u, v):
            #expect(!core.play.links.contains(Link.between(u, v)))
        case let .nudge(star):
            #expect(core.play.phases[star] == (before.phases[star] + 1) % 12)
        case .listen:
            #expect(core.play.stage == .won || core.play.stage == .failed)
        default:
            break
        }
        return true
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
        let kinds: Int = 13
        var counts: [Int] = Array(repeating: 0, count: kinds)
        var sent: [String: Int] = [:]
        var accepted: Int = 0
        var finished: Int = 0
        var fixedDrags: Int = 0
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
            if kind == 10 {
                produced = Self.secondFingerScript(&controller, snapshot: drawn, view: view, orbit: orbit, run: run,
                                                   random: &random)
            } else if kind == 11 {
                produced = Self.doubleTapScript(&controller, snapshot: drawn, view: view, orbit: orbit, run: run,
                                                random: &random)
            } else if kind == 12 {
                produced = Self.systemCancelScript(&controller, snapshot: drawn, view: view, orbit: orbit, run: run,
                                                   random: &random)
            } else {
                produced = Self.oneFinger(kind, &controller, snapshot: drawn, view: view, orbit: orbit, run: run,
                                          random: &random)
            }
            guard let actions = produced else { continue }
            // At most one kernel action per gesture, only on playing cases, applied through the adapter.
            var kernel: Int = 0
            var copy: Core? = c.core
            for a in actions {
                sent[Self.name(a), default: 0] += 1
                guard Self.isKernel(a) else { continue }
                kernel += 1
                #expect(drawn.stage == .playing, "a kernel action outside playing, run \(run)")
                guard var core = copy else { continue }
                if Self.applyKernel(a, to: &core, run: run) { accepted += 1 }
                copy = core
            }
            #expect(kernel <= 1, "run \(run)")
            // A pair chosen by a drag with no kernel action is a fixed pair.
            if kind == 4 && kernel == 0, case let .choosePair(s, t)? = actions.last {
                let pair: Link = Link.between(s, t)
                #expect(drawn.fixedLinks.contains(pair), "run \(run)")
                fixedDrags += 1
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
        for n in ["choose", "choosePair", "preview", "link", "unlink", "nudge", "listen", "resetView"] {
            #expect((sent[n] ?? 0) > 0, "\(n) never sent")
        }
        #expect(accepted > 20)
        #expect(finished > 100)
        #expect(fixedDrags > 0)
        var index: Int = 0
        while index < all.count {
            if let core = all[index].core { #expect(try Self.digest(core) == digests[index]) }
            index += 1
        }
    }

    /// A star of `c` whose projected centre picks it in the tablet portrait view at the authored orbit, with that
    /// point.
    static func starSetup(_ c: Case, avoiding: Set<Int> = []) throws -> (view: Vec2, star: Int, point: Vec2) {
        let view: Vec2 = Self.views[2]
        let s: Snapshot = c.snapshot
        for star in s.stars.indices where !avoiding.contains(star) {
            guard let p = screen(Geometry.starCentre(star, s), snapshot: s, view: view, orbit: .authored) else {
                continue
            }
            if under(p, snapshot: s, view: view, orbit: .authored) == .star(star) { return (view, star, p) }
        }
        Issue.record("no pickable star")
        throw AcousticConstellatorError.stage
    }

    @Test func tapsAndShortTouchesAreToldApartByTravelAndTimestamps() throws {
        let c: Case = try Self.cases(1)[0]
        let setup = try Self.starSetup(c)
        let p: Vec2 = setup.point
        let s: Snapshot = c.snapshot
        let k: Int = setup.star
        func play(_ steps: [Step]) -> [Action] {
            var controller: Controller = Controller()
            return Self.run(&controller, steps, view: setup.view, snapshot: s).actions
        }
        let lift: (Double, Vec2) -> [Step] = { time, end in
            [Step(phase: .began, point: p, time: 1), Step(phase: .ended, point: end, time: time)]
        }
        #expect(play(lift(1.49, p)) == [.nudge(star: k), .choose(star: k)])
        #expect(play(lift(1.5, p)).isEmpty)
        #expect(play(lift(1.2, p + Vec2(9.9, 0))) == [.nudge(star: k), .choose(star: k)])
        #expect(play(lift(1.2, p + Vec2(10, 0))).isEmpty)
        #expect(play(lift(1.2, p + Vec2(15.9, 0))).isEmpty)
        // A 16-point release starts a drag at the release: one preview, then whatever its target asks for.
        let end: Vec2 = p + Vec2(16, 0)
        let aim: Int? = Self.starNear(end, snapshot: s, view: setup.view, orbit: .authored, excluding: k)
        var want: [Action] = [.preview(from: k, target: aim, point: SIMD2(end.x, end.y))]
        if let t = aim { want += Self.expectedLink(k, t, snapshot: s) }
        #expect(play(lift(1.2, end)) == want)
        // Moving 12 points and coming back is not a tap.
        let back: [Step] = [Step(phase: .began, point: p, time: 1),
                            Step(phase: .moved, point: p + Vec2(12, 0), time: 1.1),
                            Step(phase: .ended, point: p, time: 1.2)]
        #expect(play(back).isEmpty)
        // The tap's nudge is accepted by the adapter and moves the star's phase one step.
        var core: Core = try #require(c.core)
        #expect(Self.applyKernel(.nudge(star: k), to: &core, run: -1))
        #expect(Controller.tapDistance == 10 && Controller.dragDistance == 16 && Controller.tapDuration == 0.5)
        #expect(Controller.doubleTapWindow == 0.35 && Controller.doubleTapDistance == 22)
    }

    /// The drag from star `a`'s projected centre to star `b`'s on `c` in the tablet portrait view, or nil when `a`'s
    /// centre does not pick `a` or `b`'s centre is not `a`'s nearest other star there.
    static func drag(_ c: Case, from a: Int, to b: Int) -> (steps: [Step], view: Vec2)? {
        let view: Vec2 = Self.views[2]
        let s: Snapshot = c.snapshot
        guard let p = screen(Geometry.starCentre(a, s), snapshot: s, view: view, orbit: .authored),
              let q = screen(Geometry.starCentre(b, s), snapshot: s, view: view, orbit: .authored),
              under(p, snapshot: s, view: view, orbit: .authored) == .star(a),
              starNear(q, snapshot: s, view: view, orbit: .authored, excluding: a) == b else { return nil }
        return (path(p, q, steps: 6, time: 1), view)
    }

    @Test func linkDragsLinkUnlinkAndFixedPairsSendNothing() throws {
        var fixedSeen: Int = 0
        var unlinkSeen: Int = 0
        var linkSeen: Int = 0
        for number in Self.levels {
            let level: [Case] = try Self.cases(number)
            let placed: Case = level[1]
            let s: Snapshot = placed.snapshot
            for a in s.stars.indices {
                for b in s.stars.indices where b != a {
                    guard let d = Self.drag(placed, from: a, to: b) else { continue }
                    var controller: Controller = Controller()
                    let got: [Action] = Self.run(&controller, d.steps, view: d.view, snapshot: s).actions
                    #expect(controller.state == .idle)
                    let want: Expectation = Self.expected(d.steps, snapshot: s, view: d.view, orbit: .authored)
                    #expect(got == want.actions, "level \(number) \(a) → \(b)")
                    let tail: [Action] = Self.expectedLink(a, b, snapshot: s)
                    #expect(Array(got.suffix(tail.count)) == tail)
                    let pair: Link = Link.between(a, b)
                    var kernel: [Action] = []
                    for x in got where Self.isKernel(x) { kernel.append(x) }
                    if s.fixedLinks.contains(pair) {
                        #expect(kernel.isEmpty, "a fixed pair sent \(kernel)")
                        fixedSeen += 1
                    } else if s.links.contains(pair) {
                        #expect(kernel == [.unlink(pair.a, pair.b)])
                        unlinkSeen += 1
                    } else {
                        #expect(kernel == [.link(pair.a, pair.b)])
                        linkSeen += 1
                    }
                    var core: Core = try #require(placed.core)
                    for x in kernel { _ = Self.applyKernel(x, to: &core, run: -1) }
                    // The same drag on the won and failed plays sends nothing at all.
                    for finishedCase in [level[3], level[4]] {
                        guard let e = Self.drag(finishedCase, from: a, to: b) else { continue }
                        var finishedController: Controller = Controller()
                        let none: [Action] = Self.run(&finishedController, e.steps, view: e.view,
                                                      snapshot: finishedCase.snapshot).actions
                        #expect(none.isEmpty, "a drag on a finished play sent \(none)")
                    }
                }
            }
        }
        #expect(fixedSeen > 0)
        #expect(unlinkSeen > 0)
        #expect(linkSeen > 0)
    }

    @Test func finishedPlaysOnlyChooseAndInspect() throws {
        let level: [Case] = try Self.cases(50)
        for finished in [level[3], level[4], level[2]] {
            let s: Snapshot = finished.snapshot
            try #require(s.stage != .playing)
            let setup = try Self.starSetup(finished)
            var a: Controller = Controller()
            let tap: [Step] = [Step(phase: .began, point: setup.point, time: 1),
                               Step(phase: .ended, point: setup.point, time: 1.1)]
            #expect(Self.run(&a, tap, view: setup.view, snapshot: s).actions == [.choose(star: setup.star)])
            // A gauge tap sends nothing; playing, the same tap listens.
            let bar: Vec2 = try #require(Self.screen(Geometry.coherenceBar(6, s), snapshot: s, view: setup.view,
                                                     orbit: .authored))
            try #require(Self.under(bar, snapshot: s, view: setup.view, orbit: .authored) == .coherence(6))
            let gaugeTap: [Step] = [Step(phase: .began, point: bar, time: 1), Step(phase: .ended, point: bar, time: 1.1)]
            var b: Controller = Controller()
            #expect(Self.run(&b, gaugeTap, view: setup.view, snapshot: s).actions.isEmpty)
            var c: Controller = Controller()
            #expect(Self.run(&c, gaugeTap, view: setup.view, snapshot: level[0].snapshot).actions == [.listen])
            // A link tap still chooses its stars.
            let view: Vec2 = setup.view
            var index: Int = 0
            var inspected: Bool = false
            while index < s.links.count && !inspected {
                let link: Link = s.links[index]
                let mid: SIMD3<Double> = Geometry.splinePoint(Geometry.starCentre(link.a, s),
                                                              Geometry.starCentre(link.b, s), u: 0.5)
                if let m = Self.screen(mid, snapshot: s, view: view, orbit: .authored),
                   Self.under(m, snapshot: s, view: view, orbit: .authored) == .link(index) {
                    var d: Controller = Controller()
                    let linkTap: [Step] = [Step(phase: .began, point: m, time: 1),
                                           Step(phase: .ended, point: m, time: 1.1)]
                    #expect(Self.run(&d, linkTap, view: view, snapshot: s).actions == [.choosePair(link.a, link.b)])
                    #expect(d.state == .idle)
                    inspected = true
                }
                index += 1
            }
            #expect(inspected || s.links.isEmpty)
        }
        var core: Core = try #require(level[0].core)
        #expect(Self.applyKernel(.listen, to: &core, run: -1))
    }

    @Test func secondAndThirdFingersOrbitClampedAndSendNothing() throws {
        let c: Case = try Self.cases(1)[1]
        let s: Snapshot = c.snapshot
        let view: Vec2 = Self.views[1]
        let setup = try Self.starSetup(c)
        var controller: Controller = Controller()
        let a: Vec2 = Vec2(setup.point.x * view.x / setup.view.x, setup.point.y * view.y / setup.view.y)
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
        #expect(abs(Orbit.yawLimit - 35.0 * Double.pi / 180) < 1e-12)
        #expect(abs(Orbit.pitchRange.lowerBound + 15.0 * Double.pi / 180) < 1e-12)
        #expect(abs(Orbit.pitchRange.upperBound - 20.0 * Double.pi / 180) < 1e-12)
        // The orbit is presentation only: the digest stays.
        let core: Core = try #require(c.core)
        let digest: String = try Self.digest(core)
        controller.resetView()
        #expect(controller.orbit == .authored)
        #expect(try Self.digest(core) == digest)
        #expect(controller.camera(viewSize: Vec2(0, 10), snapshot: s) == nil)
        #expect(controller.camera(viewSize: view, snapshot: s) == Geometry.camera(s, aspect: view.x / view.y))
    }

    @Test func doubleTapOnEmptySpaceResetsOnlyWithinTheWindowAndDistance() throws {
        let c: Case = try Self.cases(1)[0]
        let s: Snapshot = c.snapshot
        let view: Vec2 = Self.views[0]
        let orbit: Orbit = Self.orbits[1]
        let e: Vec2 = try #require(Self.emptyPoint(s, view: view, orbit: orbit))
        let f: Vec2 = Self.inside(e + Vec2(15, 15), view)
        try #require(Self.under(f, snapshot: s, view: view, orbit: orbit) == .empty)
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
        if Self.under(far, snapshot: s, view: view, orbit: orbit) == .empty {
            let missed = taps(far, gap: 0.2)
            #expect(missed.actions.isEmpty)
            #expect(Self.near(missed.orbit, orbit))
        }
    }

    @Test func theIndependentPickAgreesWithThePicker() throws {
        let all: [Case] = try Self.allCases()
        var random: LCG = LCG(seed: Self.seed &+ 1)
        var kinds: Set<String> = []
        var n: Int = 0
        while n < 600 {
            let c: Case = all[random.below(all.count)]
            let view: Vec2 = Self.views[random.below(Self.views.count)]
            let orbit: Orbit = Self.orbits[random.below(Self.orbits.count)]
            let s: Snapshot = c.snapshot
            var p: Vec2? = nil
            switch random.below(4) {
            case 0: p = Self.starPoint(s, view: view, orbit: orbit, random: &random)
            case 1: p = Self.gaugePoint(s, view: view, orbit: orbit, random: &random)
            case 2: p = Self.linkPoint(s, view: view, orbit: orbit, random: &random)
            default: p = Vec2(view.x * random.unit(), view.y * random.unit())
            }
            n += 1
            guard let point = p else { continue }
            let mine: Under = Self.under(point, snapshot: s, view: view, orbit: orbit)
            let theirs: AcousticConstellatorPick =
                AcousticConstellatorPicker.pick(SIMD2(point.x, point.y), size: SIMD2(view.x, view.y), snapshot: s,
                                                orbit: orbit)
            switch (mine, theirs) {
            case let (.coherence(x), .coherence(y)), let (.hold(x), .hold(y)), let (.star(x), .star(y)),
                 let (.link(x), .link(y)):
                #expect(x == y, "\(mine) vs \(theirs)")
            case (.empty, .empty):
                break
            default:
                Issue.record("independent pick \(mine) vs picker \(theirs)")
            }
            kinds.insert("\(mine)".components(separatedBy: "(")[0])
        }
        #expect(kinds.count == 5)
    }
}
