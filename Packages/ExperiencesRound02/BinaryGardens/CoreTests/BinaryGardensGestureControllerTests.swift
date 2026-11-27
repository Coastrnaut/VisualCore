// BinaryGardensGestureControllerTests — feature 504 (R02-G21-04) T-R02G2104-003 (FR-R02G2104-001 … 008, 010, 011,
// 012; SC-R02G2104-001 … 003; clarifications Q1–Q5). The gesture controller against an independent expectation: 500
// seeded scripted gestures — taps anywhere, star drags across the rings and along the orbit, luminosity and tilt drags,
// gauge scrubs — on certified levels at 3 sizes and 3 orbits (reached by two-finger orbits), on playing, won, failed
// and paused plays, each compared with what the rules of the specification give when computed here with the
// independent pick of `BinaryGardensPickerTests` (its own projection, cast, pips, rings, tangent and targets); every
// kernel action is applied through the adapter (at most one per gesture), ticks through `clock.show`, and nothing else
// changes the digest. Then: the thresholds at their edges (tap 10 points and 0.5 s, drag 16 points, double tap 0.35 s
// and 22 points); locks, a fixed star and a single luminosity level explained; second fingers, cancels and finished
// plays sending no kernel action; the orbit bounds and the double-tap reset; a refused change sent once with its reason
// code; orbit, previews, inspection and scrubbing never changing the digest; only event timestamps read. Seed 2_504;
// explicit types, plain loops.
import Foundation
import Testing
import VisualCoreExperience
import VisualCoreMath
import VisualCoreScenes
import VisualCoreSimulation
@testable import BinaryGardensCore

/// The rules of the specification for one-finger gestures, computed independently of the controller with
/// `BinaryGardensIndependentPick` (feature 504 tests).
struct BinaryGardensGestureExpectation {
    typealias G = BinaryGardensSceneGeometry
    typealias C = BinaryGardensGestureController
    typealias Independent = BinaryGardensIndependentPick

    /// The last tap on empty space: its lift point and time.
    var lastTap: (point: SIMD2<Double>, time: Double)? = nil

    /// The tick under view point `p` (the cast x clamped to the cells); nil when it casts nowhere.
    static func tick(_ p: SIMD2<Double>, _ pick: Independent) -> Int? {
        guard let c = pick.cast(p) else { return nil }
        let x: Double = min(max(c.x, -0.9), 0.9)
        return min(max(Int(((x + 0.9) / (1.8 / 48)).rounded(.down)) + 1, 1), 48)
    }

    /// Star `star`'s drag mode for `travel`: the locks, then along the projected tangent strictly greater than across.
    static func mode(_ travel: SIMD2<Double>, star: Int, _ s: BinaryGardensSceneSnapshot,
                     _ pick: Independent) -> BinaryGardensStarDragMode? {
        let f: BinaryGardensStarFreedom = s.freedom(star)
        if !f.ring && !f.phase { return nil }
        if f.ring != f.phase { return f.ring ? .ring : .phase }
        let step: Int = (s.arrangement.phases[star] + s.starSpeed * s.shownTick) % 48
        let points: [SIMD3<Double>] = Independent.ringPoints(s.arrangement.rings[star], s)
        guard let a = pick.project(points[(step + 1) % 48]), let b = pick.project(points[(step + 47) % 48]) else {
            return .ring
        }
        let u: SIMD2<Double> = a - b
        let l: Double = (u.x * u.x + u.y * u.y).squareRoot()
        if l < 0.5 { return .ring }
        let along: Double = abs((travel.x * u.x + travel.y * u.y) / l)
        let total: Double = travel.x * travel.x + travel.y * travel.y
        let across: Double = max(0, total - along * along).squareRoot()
        return along > across ? .phase : .ring
    }

    /// clamp(start + round(dx / 32), 0, upper), halves away from zero.
    static func stepped(_ start: Int, _ dx: Double, upper: Int) -> Int {
        min(max(start + Int((dx / 32).rounded(.toNearestOrAwayFromZero)), 0), max(upper, 0))
    }

    /// The index of the nearest of `points` (projected) to `p`, lower index on ties; nil when none projects.
    static func nearest(_ p: SIMD2<Double>, _ points: [SIMD3<Double>], _ pick: Independent) -> Int? {
        var best: Int? = nil
        var bestGap: Double = Double.infinity
        for (k, point) in points.enumerated() {
            guard let v = pick.project(point) else { continue }
            let g: Double = Independent.gap(p, v)
            if g < bestGap {
                best = k
                bestGap = g
            }
        }
        return best
    }

    /// The change a drag on `target` reads at `p` (start `start`, star drag mode `mode`).
    static func change(_ target: BinaryGardensPick, at p: SIMD2<Double>, start: SIMD2<Double>,
                       mode: BinaryGardensStarDragMode?, _ s: BinaryGardensSceneSnapshot,
                       _ pick: Independent) -> BinaryGardensAction? {
        switch target {
        case .star(let star):
            let step: Int = (s.arrangement.phases[star] + s.starSpeed * s.shownTick) % 48
            if mode == .ring {
                var points: [SIMD3<Double>] = []
                for ring in s.ringRadii.indices { points.append(Independent.ringPoints(ring, s)[step]) }
                guard let index = nearest(p, points, pick), index != s.arrangement.rings[star] else { return nil }
                return .ring(star: star, index: index)
            }
            let ringPoints: [SIMD3<Double>] = Independent.ringPoints(s.arrangement.rings[star], s)
            var grid: [Int] = []
            var points: [SIMD3<Double>] = []
            var q: Int = 0
            while q < 48 {
                grid.append(q)
                points.append(ringPoints[(q + s.starSpeed * s.shownTick) % 48])
                q += s.phaseStep
            }
            guard let k = nearest(p, points, pick), grid[k] != s.arrangement.phases[star] else { return nil }
            return .phase(star: star, step: grid[k])
        case .pips(let star):
            let current: Int = s.arrangement.luminosities[star]
            let level: Int = stepped(current, p.x - start.x, upper: s.luminosityLevels.count - 1)
            return level == current ? nil : .luminosity(star: star, index: level)
        case .dial:
            let current: Int = s.arrangement.tilt
            let step: Int = stepped(current, p.x - start.x, upper: s.maxTilt)
            return step == current ? nil : .tilt(step: step)
        default:
            return nil
        }
    }

    /// The expected actions of a one-finger gesture: down at `start` at time `down`, through `moves`, lifted at `end`
    /// at time `up`, on touch-down snapshot `s` and releasing snapshot `release`.
    mutating func gesture(start: SIMD2<Double>, moves: [SIMD2<Double>], end: SIMD2<Double>, down: Double, up: Double,
                          _ s: BinaryGardensSceneSnapshot, release: BinaryGardensSceneSnapshot,
                          _ pick: Independent) -> [BinaryGardensGestureAction] {
        let target: BinaryGardensPick = pick.pick(start, s)
        var out: [BinaryGardensGestureAction] = []
        var travel: Double = 0
        var dragging: Bool = false
        var blocked: Bool = false
        var mode: BinaryGardensStarDragMode? = nil
        var change: BinaryGardensAction? = nil
        var previewing: Bool = false
        var tick: Int? = nil
        var scrubbed: Bool = false
        var gauge: Bool = false
        if case .gauge = target {
            gauge = true
            tick = Self.tick(start, pick)
        }
        var draggable: Bool = false
        switch target {
        case .star, .pips, .dial: draggable = true
        default: break
        }
        let playing: Bool = s.stage == .playing
        func follow(_ p: SIMD2<Double>, preview: Bool) {
            travel = max(travel, Independent.gap(p, start))
            if gauge {
                if let t = Self.tick(p, pick), t != tick {
                    tick = t
                    scrubbed = true
                    out.append(.showTick(t))
                }
                return
            }
            guard draggable else { return }
            if !dragging && travel >= 16 {
                dragging = true
                if !playing {
                    blocked = true
                    out.append(.explain(C.stageReason(s.stage)))
                    return
                }
                switch target {
                case .star(let star):
                    mode = Self.mode(p - start, star: star, s, pick)
                    if mode == nil {
                        blocked = true
                        out.append(.explain(C.fixedReason))
                        return
                    }
                case .pips(let star):
                    if !s.freedom(star).luminosity {
                        blocked = true
                        out.append(.explain(C.luminosityLockedReason))
                        return
                    }
                    if s.luminosityLevels.count <= 1 {
                        blocked = true
                        out.append(.explain(C.singleLevelReason))
                        return
                    }
                default:
                    break
                }
            }
            guard preview, dragging, !blocked, playing else { return }
            let c: BinaryGardensAction? = Self.change(target, at: p, start: start, mode: mode, s, pick)
            if c != change {
                change = c
                if let action = c {
                    previewing = true
                    out.append(.preview(action))
                } else if previewing {
                    previewing = false
                    out.append(.clearPreview)
                }
            }
        }
        for m in moves { follow(m, preview: true) }
        follow(end, preview: false)
        let tap: Bool = !dragging && travel < 10 && up - down >= 0 && up - down < 0.5
        if target == .empty {
            if tap {
                if let last = lastTap, up - last.time >= 0, up - last.time <= 0.35,
                   Independent.gap(end, last.point) <= 22 {
                    lastTap = nil
                    out.append(.resetView)
                } else {
                    lastTap = (end, up)
                }
            } else {
                lastTap = nil
            }
            return out
        }
        lastTap = nil
        if dragging && !blocked && draggable && playing {
            let c: BinaryGardensAction? = Self.change(target, at: end, start: start, mode: mode, s, pick)
            guard release.stage == .playing, let action = c else { return out + [.clearPreview] }
            switch action {
            case .ring(let star, let index): out.append(.setRing(star: star, index: index))
            case .phase(let star, let step): out.append(.setPhase(star: star, step: step))
            case .luminosity(let star, let index): out.append(.setLuminosity(star: star, index: index))
            case .tilt(let step): out.append(.setTilt(step))
            case .run: break
            }
            return out
        }
        guard tap else { return out }
        switch target {
        case .star(let star):
            out += [.selectStar(star), .explain(C.starReason)]
        case .pips(let star):
            if !playing { return out + [.explain(C.stageReason(s.stage))] }
            if release.stage != .playing { return out + [.explain(C.stageReason(release.stage))] }
            if !s.freedom(star).luminosity { return out + [.explain(C.luminosityLockedReason)] }
            if s.luminosityLevels.count <= 1 { return out + [.explain(C.singleLevelReason)] }
            if let k = Self.nearest(end, pick.pips(star, s), pick), k != s.arrangement.luminosities[star] {
                out.append(.setLuminosity(star: star, index: k))
            }
        case .dial:
            if !playing { return out + [.explain(C.stageReason(s.stage))] }
            if release.stage != .playing { return out + [.explain(C.stageReason(release.stage))] }
            var pips: [SIMD3<Double>] = []
            for step in 0...s.maxTilt { pips.append(G.tiltPipCentre(step)) }
            if let k = Self.nearest(end, pips, pick), k != s.arrangement.tilt { out.append(.setTilt(k)) }
        case .world(let world):
            out.append(.inspectWorld(s.inspectedWorld == world ? nil : world))
        case .gauge(let world):
            out.append(.inspectWorld(world))
            if !scrubbed, let c = pick.cast(end), c.x <= 0.95, let t = Self.tick(end, pick) { out.append(.showTick(t)) }
        case .ring:
            out.append(.explain(C.ringReason))
        default:
            break
        }
        return out
    }
}

@Suite struct BinaryGardensGestureControllerTests {
    typealias G = BinaryGardensSceneGeometry
    typealias C = BinaryGardensGestureController
    typealias Core = BinaryGardensExperienceCore
    typealias Snapshot = BinaryGardensSceneSnapshot
    typealias Action = BinaryGardensGestureAction
    typealias Independent = BinaryGardensIndependentPick
    typealias Expectation = BinaryGardensGestureExpectation

    /// The seed of feature 504's tests.
    static let seed: UInt64 = 2_504
    /// The view sizes checked.
    static let sizes: [SIMD2<Double>] = [SIMD2(390, 844), SIMD2(1024, 768), SIMD2(844, 390)]
    /// The certified levels the seeded gestures play.
    static let numbers: [Int] = [1, 22, 43, 64, 85]

    /// `v` as a `Vec2`.
    static func vec(_ v: SIMD2<Double>) -> Vec2 { Vec2(v.x, v.y) }

    /// A pointer event.
    static func event(_ id: Int, _ phase: PointerPhase, _ p: SIMD2<Double>, _ t: Double) -> PointerEvent {
        PointerEvent(id: id, phase: phase, location: vec(p), timestamp: t)
    }

    /// The digest of `core`.
    static func digest(_ core: Core) throws -> StateDigest {
        var builder = DigestBuilder(domain: Core.experienceID)
        try core.writeDigest(into: &builder)
        return builder.finish()
    }

    /// `s` in stage `stage` (the unchecked initialiser), keeping its inspection.
    static func restaged(_ s: Snapshot, _ stage: BinaryGardensStage) -> Snapshot {
        Snapshot(ringRadii: s.ringRadii, luminosityLevels: s.luminosityLevels, maxTilt: s.maxTilt,
                 phaseStep: s.phaseStep, lethalTolerance: s.lethalTolerance, worlds: s.worlds,
                 arrangement: s.arrangement, starPositions: s.starPositions, shownTick: s.shownTick,
                 failure: s.failure, stage: stage, actionsLeft: s.actionsLeft, budget: s.budget,
                 levelNumber: s.levelNumber, time: s.time, starSpeed: s.starSpeed, freedoms: s.freedoms)
            .inspecting(s.inspectedWorld)
    }

    /// Runs a one-finger gesture through `controller`.
    static func oneFinger(_ controller: inout C, start: SIMD2<Double>, moves: [SIMD2<Double>], end: SIMD2<Double>,
                          down: Double, up: Double, size: SIMD2<Double>, _ s: Snapshot,
                          release: Snapshot? = nil) -> [Action] {
        let viewSize: Vec2 = vec(size)
        var actions: [Action] = controller.handle(event(1, .began, start, down), viewSize: viewSize, snapshot: s)
        for (k, m) in moves.enumerated() {
            let t: Double = down + (up - down) * Double(k + 1) / Double(moves.count + 1)
            actions += controller.handle(event(1, .moved, m, t), viewSize: viewSize, snapshot: s)
        }
        actions += controller.handle(event(1, .ended, end, up), viewSize: viewSize, snapshot: release ?? s)
        return actions
    }

    /// Turns `controller` by a two-finger drag of (`dx`, `dy`) points at time `t`.
    static func orbit(_ controller: inout C, dx: Double, dy: Double, size: SIMD2<Double>, _ s: Snapshot,
                      t: Double) -> [Action] {
        let viewSize: Vec2 = vec(size)
        let a: SIMD2<Double> = SIMD2(size.x * 0.4, size.y * 0.5)
        let b: SIMD2<Double> = SIMD2(size.x * 0.6, size.y * 0.5)
        var actions: [Action] = controller.handle(event(1, .began, a, t), viewSize: viewSize, snapshot: s)
        actions += controller.handle(event(2, .began, b, t + 0.01), viewSize: viewSize, snapshot: s)
        let d: SIMD2<Double> = SIMD2(dx, dy)
        actions += controller.handle(event(1, .moved, a + d, t + 0.05), viewSize: viewSize, snapshot: s)
        actions += controller.handle(event(2, .moved, b + d, t + 0.06), viewSize: viewSize, snapshot: s)
        actions += controller.handle(event(1, .ended, a + d, t + 0.1), viewSize: viewSize, snapshot: s)
        actions += controller.handle(event(2, .ended, b + d, t + 0.11), viewSize: viewSize, snapshot: s)
        return actions
    }

    /// Applies the gesture actions to `core` (kernel actions through the adapter, ticks through `clock.show`,
    /// inspection into `inspected`); returns the kernel actions sent.
    static func apply(_ actions: [Action], to core: inout Core, inspected: inout Int?) -> Int {
        var kernel: Int = 0
        for action in actions {
            var sent: ExperienceAction? = nil
            switch action {
            case .setRing(let star, let index):
                sent = ExperienceAction(control: "star.ring", values: [Double(star), Double(index)], step: 0)
            case .setPhase(let star, let step):
                sent = ExperienceAction(control: "star.phase", values: [Double(star), Double(step)], step: 0)
            case .setLuminosity(let star, let index):
                sent = ExperienceAction(control: "star.luminosity", values: [Double(star), Double(index)], step: 0)
            case .setTilt(let step):
                sent = ExperienceAction(control: "orbit.tilt", values: [Double(step)], step: 0)
            case .showTick(let tick):
                let result: ActionResult = core.apply(ExperienceAction(control: "clock.show", values: [Double(tick)],
                                                                       step: 0))
                #expect(result == .accepted && core.shownTick == tick)
            case .inspectWorld(let world):
                inspected = world
            default:
                break
            }
            if let kernelAction = sent {
                kernel += 1
                let result: ActionResult = core.apply(kernelAction)
                if result != .accepted {
                    // A change the kernel refuses is still sent once; the refusal carries the kernel's reason code.
                    #expect(result == .rejected(.rule(code: "r02-g21.action"))
                            || result == .rejected(.rule(code: "r02-g21.budget")), "\(action) \(result)")
                }
            }
        }
        return kernel
    }

    @Test func fiveHundredSeededGesturesMatchTheIndependentExpectation() async throws {
        var random: SeededRandom = SeededRandom(seed: Self.seed)
        var total: Int = 0
        var kinds: [String: Int] = [:]
        var combo: Int = 0
        while total < 500 {
            let size: SIMD2<Double> = Self.sizes[combo % 3]
            let orbitIndex: Int = (combo / 3) % 3
            var core: Core = try await Core.prepare(seed: UInt64(Self.numbers[combo % Self.numbers.count] - 1))
            var inspected: Int? = nil
            var controller: C = C()
            var time: Double = 10
            if orbitIndex > 0 {
                let dx: Double = orbitIndex == 1 ? size.x * 0.4 : -size.x * 0.5
                let dy: Double = orbitIndex == 1 ? -size.y * 0.3 : size.y * 0.25
                let turned: [Action] = Self.orbit(&controller, dx: dx, dy: dy, size: size, core.snapshot(time: 0),
                                                  t: time)
                #expect(turned.isEmpty && controller.orbit != .authored && controller.orbit.isWithinBounds)
                time += 1
            }
            var expectation: Expectation = Expectation()
            for _ in 0..<56 where total < 500 {
                let orbit: BinaryGardensViewOrbit = controller.orbit
                let pick: Independent = Independent(size: size, orbit: orbit)
                let committed: Snapshot = core.snapshot(time: 0).inspecting(inspected)
                let stageRoll: Int = random.int(0...9)
                let stages: [BinaryGardensStage] = [.won, .failed, .paused]
                let s: Snapshot = stageRoll < 7 ? committed : Self.restaged(committed, stages[stageRoll - 7])
                let kind: Int = random.int(0...5)
                var start: SIMD2<Double> = SIMD2(random.range(0...size.x), random.range(0...size.y))
                var moves: [SIMD2<Double>] = []
                var end: SIMD2<Double> = start
                let jitter: SIMD2<Double> = SIMD2(random.range(-3...3), random.range(-3...3))
                switch kind {
                case 1, 2:
                    let star: Int = random.int(0...1)
                    if let c = pick.project(G.starCentre(star, s)) { start = c + jitter }
                    let step: Int = (s.arrangement.phases[star] + s.starSpeed * s.shownTick) % 48
                    var aim: SIMD3<Double> = G.starCentre(star, s)
                    if kind == 1 {
                        let ring: Int = random.int(0...(s.ringRadii.count - 1))
                        aim = Independent.ringPoints(ring, s)[step]
                    } else {
                        let grid: Int = s.phaseStep * random.int(0...(47 / s.phaseStep))
                        let ringPoints: [SIMD3<Double>] = Independent.ringPoints(s.arrangement.rings[star], s)
                        aim = ringPoints[(grid + s.starSpeed * s.shownTick) % 48]
                    }
                    end = (pick.project(aim) ?? start) + SIMD2(random.range(-4...4), random.range(-4...4))
                    moves = [end, end]
                    kinds["star", default: 0] += 1
                case 3:
                    let star: Int = random.int(0...1)
                    let row: [SIMD3<Double>] = pick.pips(star, s)
                    if let first = row.first, let last = row.last, let c = pick.project((first + last) / 2) {
                        start = c
                    }
                    let dx: Double = random.range(-110...110)
                    moves = [start + SIMD2(dx / 2, 4), start + SIMD2(dx, -2)]
                    end = start + SIMD2(dx, 0)
                    kinds["pips", default: 0] += 1
                case 4:
                    if let c = pick.project(G.tiltPipCentre(random.int(0...max(s.maxTilt, 0)))) { start = c + jitter }
                    let dx: Double = random.range(-150...150)
                    moves = [start + SIMD2(dx / 3, 2), start + SIMD2(dx, 0)]
                    end = start + SIMD2(dx, random.range(-5...5))
                    kinds["dial", default: 0] += 1
                case 5:
                    let row: Int = random.int(0...(s.worlds.count - 1))
                    if let c = pick.project(G.cellCentre(row, tick: random.int(1...48))) { start = c }
                    for _ in 0..<3 {
                        let x: Double = random.range(-0.95...1.2)
                        if let p = pick.project(SIMD3(x, G.gaugeY(row), 0)) { moves.append(p) }
                    }
                    end = moves.last ?? start
                    kinds["scrub", default: 0] += 1
                default:
                    let aims: [SIMD2<Double>] = pick.aims(s)
                    if !aims.isEmpty && random.int(0...3) > 0 {
                        start = aims[random.int(0...(aims.count - 1))] + jitter
                    }
                    end = start
                    kinds["tap", default: 0] += 1
                }
                let down: Double = time
                let up: Double = time + (kind == 0 ? 0.2 : 0.4)
                time += 1
                let expected: [Action] = expectation.gesture(start: start, moves: moves, end: end, down: down, up: up,
                                                             s, release: s, pick)
                let before: StateDigest = try Self.digest(core)
                let actions: [Action] = Self.oneFinger(&controller, start: start, moves: moves, end: end, down: down,
                                                       up: up, size: size, s)
                #expect(actions == expected,
                        "gesture \(total) kind \(kind) stage \(s.stage) orbit \(orbit) size \(size)")
                #expect(controller.state == .idle)
                // Kernel actions only while playing, at most one per gesture; nothing else changes the digest.
                let kernel: Int = Self.apply(actions, to: &core, inspected: &inspected)
                #expect(kernel <= 1)
                if s.stage != .playing { #expect(kernel == 0) }
                if kernel == 0 { #expect(try Self.digest(core) == before, "gesture \(total) changed the digest") }
                for action in actions {
                    if case .preview(let change) = action {
                        let level: BinaryGardensLevel = core.play.level
                        #expect(committed.previewing(change, level: level).preview != nil, "\(change)")
                    }
                    if action == .resetView { #expect(controller.orbit == .authored) }
                }
                total += 1
            }
            combo += 1
        }
        #expect(total == 500)
        #expect((kinds["star"] ?? 0) > 50 && (kinds["pips"] ?? 0) > 40 && (kinds["scrub"] ?? 0) > 40)
    }

    @Test func thresholdsHoldAtTheirEdges() async throws {
        let core: Core = try await Core.prepare(seed: 0)
        let s: Snapshot = core.snapshot(time: 0)
        let size: SIMD2<Double> = SIMD2(390, 844)
        let pick: Independent = Independent(size: size, orbit: .authored)
        #expect(C.tapDistance == 10 && C.dragDistance == 16 && C.tapDuration == 0.5)
        #expect(C.doubleTapWindow == 0.35 && C.doubleTapDistance == 22)
        #expect(C.yawPerViewWidth == Double.pi / 2 && C.pitchPerViewHeight == Double.pi / 3)
        // A ring tap: under 10 points and 0.5 s explains; at 10 points or 0.5 s nothing.
        var ringPoint: SIMD2<Double>? = nil
        for ring in s.ringRadii.indices.reversed() {
            for step in stride(from: 0, to: 48, by: 3) {
                guard let p = pick.project(Independent.ringPoints(ring, s)[step]) else { continue }
                let near: [SIMD2<Double>] = [p, p + SIMD2(9.99, 0), p + SIMD2(10, 0)]
                var all: Bool = true
                for q in near where pick.pick(q, s) != .ring(ring) { all = false }
                if all && ringPoint == nil { ringPoint = p }
            }
        }
        let p: SIMD2<Double> = try #require(ringPoint, "a ring point with room around it")
        var controller: C = C()
        #expect(Self.oneFinger(&controller, start: p, moves: [p + SIMD2(9.99, 0)], end: p, down: 0, up: 0.499,
                               size: size, s) == [.explain(C.ringReason)])
        #expect(Self.oneFinger(&controller, start: p, moves: [p + SIMD2(10, 0)], end: p, down: 1, up: 1.1,
                               size: size, s).isEmpty)
        #expect(Self.oneFinger(&controller, start: p, moves: [], end: p, down: 2, up: 2.5, size: size, s).isEmpty)
        // A pip drag: 15.99 points is no drag; 16 points is (one step at 16, halves away from zero).
        var star: Int = 0
        if !s.freedom(0).luminosity { star = 1 }
        if s.freedom(star).luminosity && s.luminosityLevels.count > 1 {
            let row: [SIMD3<Double>] = pick.pips(star, s)
            let mid: SIMD2<Double> = try #require(pick.project((row[0] + row[row.count - 1]) / 2))
            if pick.pick(mid, s) == .pips(star) {
                let current: Int = s.arrangement.luminosities[star]
                let direction: Double = current == 0 ? 1 : -1
                let short: [Action] = Self.oneFinger(&controller, start: mid,
                                                     moves: [mid + SIMD2(15.99 * direction, 0)],
                                                     end: mid + SIMD2(15.99 * direction, 0), down: 3, up: 3.2,
                                                     size: size, s)
                #expect(short.isEmpty, "\(short)")
                let level: Int = current + Int(direction)
                let long: [Action] = Self.oneFinger(&controller, start: mid, moves: [mid + SIMD2(16 * direction, 0)],
                                                    end: mid + SIMD2(16 * direction, 0), down: 4, up: 4.2, size: size,
                                                    s)
                #expect(long == [.preview(.luminosity(star: star, index: level)),
                                 .setLuminosity(star: star, index: level)], "\(long)")
            }
        }
        // Double taps on empty space: within 0.35 s and 22 points reset; at 0.36 s or 23 points not; a disc tap breaks
        // a pair.
        let empty: SIMD2<Double> = SIMD2(3, 3)
        #expect(pick.pick(empty, s) == .empty)
        var double: C = C()
        _ = Self.orbit(&double, dx: 100, dy: 0, size: size, s, t: 0)
        #expect(double.orbit != .authored)
        #expect(Self.oneFinger(&double, start: empty, moves: [], end: empty, down: 10, up: 10.1, size: size, s).isEmpty)
        let second: SIMD2<Double> = empty + SIMD2(22, 0)
        #expect(pick.pick(second, s) == .empty)
        #expect(Self.oneFinger(&double, start: second, moves: [], end: second, down: 10.3, up: 10.45, size: size, s)
                == [.resetView])
        #expect(double.orbit == .authored)
        #expect(Self.oneFinger(&double, start: empty, moves: [], end: empty, down: 11, up: 11.1, size: size, s).isEmpty)
        #expect(Self.oneFinger(&double, start: empty, moves: [], end: empty, down: 11.3, up: 11.46, size: size,
                               s).isEmpty, "0.36 s apart")
        let far: SIMD2<Double> = empty + SIMD2(23, 0)
        #expect(Self.oneFinger(&double, start: far, moves: [], end: far, down: 11.5, up: 11.6, size: size, s).isEmpty,
                "23 points apart")
        let disc: SIMD2<Double> = try #require(pick.project(SIMD3(0.02, 0.9, 0)))
        if pick.pick(disc, s) == .disc {
            #expect(Self.oneFinger(&double, start: empty, moves: [], end: empty, down: 12, up: 12.05, size: size,
                                   s).isEmpty)
            #expect(Self.oneFinger(&double, start: disc, moves: [], end: disc, down: 12.1, up: 12.15, size: size,
                                   s).isEmpty)
            #expect(Self.oneFinger(&double, start: empty, moves: [], end: empty, down: 12.2, up: 12.25, size: size,
                                   s).isEmpty, "the disc tap broke the pair")
        }
    }

    @Test func locksAndASingleLevelAreExplained() throws {
        let size: SIMD2<Double> = SIMD2(1024, 768)
        let locked: BinaryGardensStarFreedom = BinaryGardensStarFreedom(ring: false, phase: false, luminosity: false)
        let s: Snapshot = BinaryGardensPickerTests.edge(rings: 4, worlds: 1, worldRadius: 60, tilt: 2, tick: 12,
                                                        freedoms: [locked, .free])
        let pick: Independent = Independent(size: size, orbit: .authored)
        var controller: C = C()
        let star: SIMD2<Double> = try #require(pick.project(G.starCentre(0, s)))
        try #require(pick.pick(star, s) == .star(0))
        let away: SIMD2<Double> = star + SIMD2(0, -60)
        #expect(Self.oneFinger(&controller, start: star, moves: [away, away + SIMD2(5, 0)], end: away, down: 0, up: 0.6,
                               size: size, s) == [.explain(C.fixedReason)])
        #expect(Self.oneFinger(&controller, start: star, moves: [], end: star, down: 1, up: 1.1, size: size, s)
                == [.selectStar(0), .explain(C.starReason)])
        let row: [SIMD3<Double>] = pick.pips(0, s)
        let mid: SIMD2<Double> = try #require(pick.project((row[0] + row[row.count - 1]) / 2))
        try #require(pick.pick(mid, s) == .pips(0))
        #expect(Self.oneFinger(&controller, start: mid, moves: [mid + SIMD2(40, 0)], end: mid + SIMD2(40, 0), down: 2,
                               up: 2.3, size: size, s) == [.explain(C.luminosityLockedReason)])
        #expect(Self.oneFinger(&controller, start: mid, moves: [], end: mid, down: 3, up: 3.1, size: size, s)
                == [.explain(C.luminosityLockedReason)])
        // A single luminosity level.
        let single: Snapshot = BinaryGardensPickerTests.edge(rings: 4, worlds: 1, worldRadius: 60, tilt: 2,
                                                             levels: [9], lums: [0, 0], tick: 12)
        let one: [SIMD3<Double>] = pick.pips(1, single)
        let pip: SIMD2<Double> = try #require(pick.project(one[0]))
        try #require(pick.pick(pip, single) == .pips(1))
        #expect(Self.oneFinger(&controller, start: pip, moves: [], end: pip, down: 4, up: 4.1, size: size, single)
                == [.explain(C.singleLevelReason)])
        #expect(Self.oneFinger(&controller, start: pip, moves: [pip + SIMD2(-50, 0)], end: pip + SIMD2(-50, 0),
                               down: 5, up: 5.3, size: size, single) == [.explain(C.singleLevelReason)])
        // A star with only its phase free always drags its phase, whatever the direction.
        let phaseOnly: Snapshot = BinaryGardensPickerTests.edge(
            rings: 4, worlds: 1, worldRadius: 60, tilt: 2, tick: 12,
            freedoms: [BinaryGardensStarFreedom(ring: false, phase: true, luminosity: true), .free])
        let outward: SIMD2<Double> = try #require(pick.project(Independent.ringPoints(0, phaseOnly)[
            phaseOnly.starStep(0, tick: 12)]))
        let actions: [Action] = Self.oneFinger(&controller, start: star, moves: [outward], end: outward, down: 6,
                                               up: 6.3, size: size, phaseOnly)
        for action in actions {
            switch action {
            case .setRing, .preview(.ring): Issue.record("a ring change from a phase-only star: \(action)")
            default: break
            }
        }
        #expect(actions.last == .clearPreview || {
            if case .setPhase = actions.last { return true }
            return false
        }())
    }

    @Test func secondFingersCancelsAndFinishedPlaysSendNoKernelAction() async throws {
        var core: Core = try await Core.prepare(seed: 42)
        let s: Snapshot = core.snapshot(time: 0)
        let size: SIMD2<Double> = SIMD2(1024, 768)
        let viewSize: Vec2 = Self.vec(size)
        let pick: Independent = Independent(size: size, orbit: .authored)
        let before: StateDigest = try Self.digest(core)
        // A star drag that previews, then a second finger: only clearPreview, then an orbit.
        var star: Int = s.freedom(0).ring || s.freedom(0).phase ? 0 : 1
        var start: SIMD2<Double> = try #require(pick.project(G.starCentre(star, s)))
        if pick.pick(start, s) != .star(star) {
            star = 1 - star
            start = try #require(pick.project(G.starCentre(star, s)))
        }
        try #require(pick.pick(start, s) == .star(star))
        var controller: C = C()
        var actions: [Action] = controller.handle(Self.event(1, .began, start, 0), viewSize: viewSize, snapshot: s)
        // A drag of 120 points up from the star.
        let far: SIMD2<Double> = start + SIMD2(0, -120)
        actions += controller.handle(Self.event(1, .moved, far, 0.1), viewSize: viewSize, snapshot: s)
        let previewed: Bool = actions.contains { if case .preview = $0 { return true } else { return false } }
        let second: [Action] = controller.handle(Self.event(2, .began, SIMD2(500, 500), 0.2), viewSize: viewSize,
                                                 snapshot: s)
        #expect(second == (previewed ? [.clearPreview] : []))
        #expect(controller.state == .orbiting)
        _ = controller.handle(Self.event(1, .moved, far + SIMD2(80, 40), 0.3), viewSize: viewSize, snapshot: s)
        _ = controller.handle(Self.event(2, .moved, SIMD2(580, 540), 0.3), viewSize: viewSize, snapshot: s)
        #expect(controller.orbit != .authored && controller.orbit.isWithinBounds)
        // A third finger re-bases; lifting one finger leaves the gesture cancelled until every finger lifts.
        #expect(controller.handle(Self.event(3, .began, SIMD2(100, 100), 0.4), viewSize: viewSize, snapshot: s)
                .isEmpty)
        let orbitBefore: BinaryGardensViewOrbit = controller.orbit
        #expect(controller.handle(Self.event(3, .ended, SIMD2(100, 100), 0.5), viewSize: viewSize, snapshot: s)
                .isEmpty)
        #expect(controller.state == .cancelled && controller.orbit == orbitBefore)
        #expect(controller.handle(Self.event(1, .ended, far, 0.6), viewSize: viewSize, snapshot: s).isEmpty)
        #expect(controller.handle(Self.event(2, .ended, SIMD2(580, 540), 0.6), viewSize: viewSize, snapshot: s)
                .isEmpty)
        #expect(controller.state == .idle)
        // The orbit stays within its bounds however far the fingers go.
        _ = Self.orbit(&controller, dx: 50_000, dy: -50_000, size: size, s, t: 1)
        #expect(controller.orbit.yaw == BinaryGardensViewOrbit.yawLimit)
        #expect(controller.orbit.pitch == BinaryGardensViewOrbit.pitchRange.upperBound)
        _ = Self.orbit(&controller, dx: -90_000, dy: 90_000, size: size, s, t: 2)
        #expect(controller.orbit.yaw == -BinaryGardensViewOrbit.yawLimit)
        #expect(controller.orbit.pitch == BinaryGardensViewOrbit.pitchRange.lowerBound)
        controller.resetView()
        #expect(controller.orbit == .authored)
        // A cancelled phase sends only clearPreview.
        var cancelled: C = C()
        var sent: [Action] = cancelled.handle(Self.event(1, .began, start, 3), viewSize: viewSize, snapshot: s)
        sent += cancelled.handle(Self.event(1, .moved, far, 3.1), viewSize: viewSize, snapshot: s)
        let showing: Bool = sent.contains { if case .preview = $0 { return true } else { return false } }
        #expect(cancelled.handle(Self.event(1, .cancelled, far, 3.2), viewSize: viewSize, snapshot: s)
                == (showing ? [.clearPreview] : []))
        #expect(cancelled.state == .idle)
        // `cancel()` drops everything silently and keeps the orbit.
        _ = cancelled.handle(Self.event(1, .began, start, 4), viewSize: viewSize, snapshot: s)
        cancelled.cancel()
        #expect(cancelled.state == .idle)
        #expect(cancelled.handle(Self.event(1, .ended, start, 4.1), viewSize: viewSize, snapshot: s).isEmpty)
        // Finished and paused plays: drags explain the stage once and send no kernel action; world taps still
        // inspect and gauge presses still show ticks.
        for stage in [BinaryGardensStage.won, .failed, .result, .paused, .loading, .tutorial] {
            let stopped: Snapshot = Self.restaged(s, stage)
            var finished: C = C()
            let drag: [Action] = Self.oneFinger(&finished, start: start, moves: [far, far], end: far, down: 5, up: 5.3,
                                                size: size, stopped)
            #expect(drag == [.explain(C.stageReason(stage))], "\(stage) \(drag)")
            let world: SIMD2<Double> = try #require(pick.project(G.worldCentre(0, stopped)))
            if pick.pick(world, stopped) == .world(0) {
                #expect(Self.oneFinger(&finished, start: world, moves: [], end: world, down: 6, up: 6.1, size: size,
                                       stopped) == [.inspectWorld(0)])
            }
            let cell: SIMD2<Double> = try #require(pick.project(G.cellCentre(0, tick: 10)))
            let later: SIMD2<Double> = try #require(pick.project(G.cellCentre(0, tick: 30)))
            #expect(Self.oneFinger(&finished, start: cell, moves: [later], end: later, down: 7, up: 7.3, size: size,
                                   stopped) == [.showTick(30)])
        }
        #expect(C.stageReason(.won) == C.finishedReason && C.stageReason(.paused) == C.notRunningReason)
        // A change released after the play stopped clears the preview and sends nothing.
        var late: C = C()
        let releasing: Snapshot = Self.restaged(s, .won)
        let lateActions: [Action] = Self.oneFinger(&late, start: start, moves: [far], end: far, down: 8, up: 8.3,
                                                   size: size, s, release: releasing)
        #expect(lateActions.last == .clearPreview)
        for action in lateActions {
            switch action {
            case .setRing, .setPhase, .setLuminosity, .setTilt: Issue.record("kernel action after the play stopped")
            default: break
            }
        }
        var inspected: Int? = nil
        #expect(Self.apply(lateActions, to: &core, inspected: &inspected) == 0)
        #expect(try Self.digest(core) == before)
    }

    @Test func aRefusedChangeIsSentOnceWithItsReasonCode() async throws {
        var core: Core = try await Core.prepare(seed: 3)
        // Spend every action (the kernel's own changes), so the next change is refused for the budget.
        let level: BinaryGardensLevel = core.play.level
        var random: SeededRandom = SeededRandom(seed: Self.seed + 7)
        var attempts: Int = 0
        while core.play.actionsLeft > 0 && attempts < 400 {
            attempts += 1
            let star: Int = random.int(0...1)
            let action: ExperienceAction
            switch random.int(0...2) {
            case 0:
                action = ExperienceAction(control: "star.ring",
                                          values: [Double(star), Double(random.int(0...(level.ringRadii.count - 1)))],
                                          step: 0)
            case 1:
                let step: Int = level.phaseStep * random.int(0...(47 / level.phaseStep))
                action = ExperienceAction(control: "star.phase", values: [Double(star), Double(step)], step: 0)
            default:
                action = ExperienceAction(control: "orbit.tilt", values: [Double(random.int(0...level.maxTilt))],
                                          step: 0)
            }
            _ = core.apply(action)
        }
        try #require(core.play.actionsLeft == 0)
        let s: Snapshot = core.snapshot(time: 0)
        let size: SIMD2<Double> = SIMD2(1024, 768)
        let pick: Independent = Independent(size: size, orbit: .authored)
        var controller: C = C()
        var expectation: Expectation = Expectation()
        var found: Bool = false
        for star in 0..<2 where !found {
            guard let start = pick.project(G.starCentre(star, s)), pick.pick(start, s) == .star(star) else { continue }
            var ends: [SIMD3<Double>] = []
            for ring in s.ringRadii.indices { ends.append(Independent.ringPoints(ring, s)[s.starStep(star, tick: 48)]) }
            for step in stride(from: 0, to: 48, by: 4) {
                ends.append(Independent.ringPoints(s.arrangement.rings[star], s)[step])
            }
            for point in ends where !found {
                guard let end = pick.project(point) else { continue }
                let expected: [Action] = expectation.gesture(start: start, moves: [end], end: end, down: 0, up: 0.4, s,
                                                             release: s, pick)
                let actions: [Action] = Self.oneFinger(&controller, start: start, moves: [end], end: end, down: 0,
                                                       up: 0.4, size: size, s)
                #expect(actions == expected)
                var change: BinaryGardensAction? = nil
                var control: String = ""
                var values: [Double] = []
                switch actions.last {
                case .setRing(let sentStar, let index)?:
                    change = .ring(star: sentStar, index: index)
                    control = "star.ring"
                    values = [Double(sentStar), Double(index)]
                case .setPhase(let sentStar, let step)?:
                    change = .phase(star: sentStar, step: step)
                    control = "star.phase"
                    values = [Double(sentStar), Double(step)]
                default:
                    break
                }
                guard let sent = change else { continue }
                found = true
                // The drag previewed the kernel's refusal (no action left, or the change rule's first), and the release
                // sent the change once; the adapter refuses it with the reason code and nothing changes.
                let preview: BinaryGardensPreview? = s.previewing(sent, level: level).preview
                #expect(preview?.refusal != nil)
                #expect(actions.contains(.preview(sent)))
                let digest: StateDigest = try Self.digest(core)
                let result: ActionResult = core.apply(ExperienceAction(control: control, values: values, step: 0))
                #expect(result == .rejected(.rule(code: preview?.refusal?.reasonCode ?? "r02-g21.budget")))
                #expect(try Self.digest(core) == digest)
                var kernelActions: Int = 0
                for action in actions {
                    switch action {
                    case .setRing, .setPhase, .setLuminosity, .setTilt: kernelActions += 1
                    default: break
                    }
                }
                #expect(kernelActions == 1)
            }
        }
        #expect(found, "a refused change was dragged")
    }

    @Test func orbitPreviewsInspectionAndScrubbingNeverChangeTheDigest() async throws {
        var core: Core = try await Core.prepare(seed: 60)
        let size: SIMD2<Double> = SIMD2(844, 390)
        let viewSize: Vec2 = Self.vec(size)
        let before: StateDigest = try Self.digest(core)
        var controller: C = C()
        let s: Snapshot = core.snapshot(time: 0)
        _ = Self.orbit(&controller, dx: 120, dy: -60, size: size, s, t: 0)
        let pick: Independent = Independent(size: size, orbit: controller.orbit)
        #expect(controller.camera(viewSize: viewSize) == G.camera(aspect: size.x / size.y, orbit: controller.orbit))
        #expect(controller.camera(viewSize: Vec2(0, 10)) == nil)
        // A scrub along world 0's row shows ticks only, and the inspected world follows the taps.
        let row: Int = 0
        let a: SIMD2<Double> = try #require(pick.project(G.cellCentre(row, tick: 3)))
        let b: SIMD2<Double> = try #require(pick.project(G.cellCentre(row, tick: 40)))
        let c: SIMD2<Double> = try #require(pick.project(SIMD3(1.1, G.gaugeY(row), 0)))
        var inspected: Int? = nil
        let scrub: [Action] = Self.oneFinger(&controller, start: a, moves: [b, c], end: c, down: 1, up: 1.4,
                                             size: size, s)
        #expect(scrub == [.showTick(40), .showTick(48)])
        _ = Self.apply(scrub, to: &core, inspected: &inspected)
        #expect(core.shownTick == 48)
        let tap: [Action] = Self.oneFinger(&controller, start: b, moves: [], end: b, down: 2, up: 2.1, size: size,
                                           core.snapshot(time: 0))
        #expect(tap == [.inspectWorld(row), .showTick(40)])
        _ = Self.apply(tap, to: &core, inspected: &inspected)
        #expect(inspected == row && core.shownTick == 40)
        let bloomTap: [Action] = Self.oneFinger(&controller, start: c, moves: [], end: c, down: 3, up: 3.1,
                                                size: size, core.snapshot(time: 0))
        #expect(bloomTap == [.inspectWorld(row)], "a tap on the bloom meter shows no tick")
        // A world tap toggles the inspection.
        let shown: Snapshot = core.snapshot(time: 0).inspecting(inspected)
        let world: SIMD2<Double> = try #require(pick.project(G.worldCentre(row, shown)))
        if pick.pick(world, shown) == .world(row) {
            #expect(Self.oneFinger(&controller, start: world, moves: [], end: world, down: 4, up: 4.1, size: size,
                                   shown) == [.inspectWorld(nil)])
            #expect(Self.oneFinger(&controller, start: world, moves: [], end: world, down: 5, up: 5.1, size: size,
                                   shown.inspecting(nil)) == [.inspectWorld(row)])
        }
        // Previews of every kind change nothing.
        let level: BinaryGardensLevel = core.play.level
        for star in 0..<2 {
            for index in level.ringRadii.indices {
                let previewed: Snapshot = shown.previewing(.ring(star: star, index: index), level: level)
                _ = try G.systemMesh(previewed, tier: BinaryGardensTier.of(2),
                                     camera: try #require(controller.camera(viewSize: viewSize)))
            }
        }
        #expect(try Self.digest(core) == before)
    }
}
