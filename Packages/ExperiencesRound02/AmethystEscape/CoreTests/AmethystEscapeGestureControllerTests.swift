// AmethystEscapeGestureControllerTests — feature 364 (R02-G07-04) T-R02G0704-004 (FR-R02G0704-001, 002, 003, 005, 006;
// SC-R02G0704-001, 003, 004; clarifications Q1 … Q5). 500 seeded (seed 2_364) scripted shell drags, shell taps and
// presses, pearl taps and presses, short drags and random touches on certified levels 1, 21, 41, 61 and 81 (fresh, won
// through the certified solution, failed by spending the budget) at three view sizes and three orbits reached by
// two-finger drags send exactly the actions an independent expectation computed here predicts: the pick at touch-down
// from `AmethystEscapePicker.pick` (the geometry oracle) and the swept angle from the test's own ray (the camera's eye
// through its own unprojection of the point with the inverse view-projection) met with the picked shell's plane, its own
// unwrapping and its own rounding to the shortest whole-sector turn. Second fingers, `.cancelled` phases, `cancel()` and
// finished plays send no turn and no advance; 10 … 16 points of travel send nothing; double taps toggle isolation and
// reset the view; the orbit follows 90° yaw per width and 60° pitch per height, clamps and re-bases on a third finger;
// the preview follows the candidate; orbit and isolation never change the core's digest or snapshot. Plain loops and
// explicit types (CI type-check rule).
import Foundation
import Testing
import VisualCoreDiagnostics
import VisualCoreExperience
import VisualCoreMath
import VisualCoreScenes
import VisualCoreSimulation
@testable import AmethystEscapeCore

@Suite struct AmethystEscapeGestureControllerTests {
    typealias Controller = AmethystEscapeGestureController
    typealias Snapshot = AmethystEscapeSceneSnapshot
    typealias Action = AmethystEscapeGestureAction
    typealias Geometry = AmethystEscapeSceneGeometry
    typealias Picker = AmethystEscapePicker
    typealias Orbit = AmethystEscapeOrbit
    typealias Core = AmethystEscapeExperienceCore

    /// The seed of every random choice here.
    static let seed: UInt64 = 2_364
    /// The view sizes every script runs at: phone portrait, tablet landscape, tablet portrait.
    static let views: [Vec2] = [Vec2(390, 844), Vec2(1_180, 820), Vec2(1_024, 1_366)]
    /// The scripted orbits (the first is the authored one), reached by two-finger drags.
    static let orbits: [Orbit] = [.authored, Orbit(yaw: 0.5, pitch: 0.75), Orbit(yaw: -0.6, pitch: 1.2)]
    /// The certified levels used.
    static let levels: [Int] = [1, 21, 41, 61, 81]
    /// The time between scripted events in seconds.
    static let frame: Double = 1.0 / 60
    /// How close (in sectors) to a rounding boundary a swept angle counts as ambiguous between two computations.
    static let ambiguity: Double = 1e-6

    // MARK: Cores and snapshots

    /// An adapter action.
    static func action(_ control: String, _ values: [Double] = []) -> ExperienceAction {
        ExperienceAction(control: control, values: values, step: 0)
    }

    /// The digest of `core` as the engine computes it.
    static func digest(_ core: Core) throws -> String {
        var builder: DigestBuilder = DigestBuilder(domain: Core.experienceID)
        try core.writeDigest(into: &builder)
        return builder.finish().hex
    }

    /// Applies a gesture action to `core` as the presenter maps it (`select`, `isolate` and `resetView` send nothing).
    static func apply(_ gesture: Action, to core: inout Core) {
        switch gesture {
        case .turn(let shell, let step):
            _ = core.apply(action("shell.rotate", [Double(shell), Double(step)]))
        case .advance:
            _ = core.apply(action("pearl.advance"))
        case .select, .isolate, .resetView:
            break
        }
    }

    /// Snapshots of certified level `number`: fresh (playing), won (the certified solution through the adapter) and
    /// failed (shell 0 turned back and forth until the budget ends the play), when those stages are reached.
    static func snapshots(_ number: Int) throws -> [Snapshot] {
        var result: [Snapshot] = []
        let fresh: Core = try Core.opening(number: number)
        #expect(fresh.play.stage == .playing)
        result.append(fresh.snapshot(time: 0))
        var won: Core = fresh
        for step in try Core.generated(number: number).solution.actions {
            switch step {
            case .rotate(let shell, let turn):
                _ = won.apply(action("shell.rotate", [Double(shell), Double(turn)]))
            case .advance:
                _ = won.apply(action("pearl.advance"))
            }
        }
        #expect(won.play.stage == .won)
        if won.play.stage == .won { result.append(won.snapshot(time: 0)) }
        var failed: Core = fresh
        var turn: Int = 0
        while failed.play.stage == .playing && turn < 400 {
            _ = failed.apply(action("shell.rotate", [0, turn % 2 == 0 ? 1 : -1]))
            turn += 1
        }
        if failed.play.stage == .failed { result.append(failed.snapshot(time: 0)) }
        return result
    }

    // MARK: The test's own projection

    /// The view point of `world` for `snapshot` in `view` at `orbit` (clip = M·(p, 1), NDC = clip / w, view points
    /// ((x + 1)/2 · width, (1 − y)/2 · height)), or nil behind the eye.
    static func screen(_ world: SIMD3<Double>, snapshot: Snapshot, view: Vec2, orbit: Orbit) -> Vec2? {
        let m: Mat4 = Geometry.camera(snapshot, aspect: view.x / view.y, orbit: orbit).viewProjection
        let p: Vec4 = Vec4(world.x, world.y, world.z, 1)
        let x: Double = m.row(0).dot(p)
        let y: Double = m.row(1).dot(p)
        let w: Double = m.row(3).dot(p)
        guard w > 1e-9 else { return nil }
        return Vec2((x / w + 1) / 2 * view.x, (1 - y / w) / 2 * view.y)
    }

    /// The test's own touch angle: the ray from the camera's eye through the unprojection (inverse view-projection) of
    /// `point` at NDC depth 0.5, met with the plane y = h_shell ahead of the eye; atan2(z, x) of the hit. Nil outside
    /// the view or when the ray misses the plane ahead.
    static func ownAngle(shell: Int, at point: Vec2, snapshot: Snapshot, view: Vec2, orbit: Orbit) -> Double? {
        guard point.x >= 0, point.y >= 0, point.x <= view.x, point.y <= view.y else { return nil }
        let camera: AmethystEscapeCamera = Geometry.camera(snapshot, aspect: view.x / view.y, orbit: orbit)
        guard let inverse = camera.viewProjection.inverse else { return nil }
        let ndc: Vec4 = Vec4(point.x / view.x * 2 - 1, 1 - point.y / view.y * 2, 0.5, 1)
        let x: Double = inverse.row(0).dot(ndc)
        let y: Double = inverse.row(1).dot(ndc)
        let z: Double = inverse.row(2).dot(ndc)
        let w: Double = inverse.row(3).dot(ndc)
        guard abs(w) > 1e-12 else { return nil }
        let through: SIMD3<Double> = SIMD3(x / w, y / w, z / w)
        let direction: SIMD3<Double> = through - camera.eye
        guard abs(direction.y) > 1e-12 else { return nil }
        let height: Double = 0.08 + 0.06 * Double(snapshot.shells.count - 1 - shell)
        let t: Double = (height - camera.eye.y) / direction.y
        guard t > 0 else { return nil }
        let hit: SIMD3<Double> = camera.eye + direction * t
        return atan2(hit.z, hit.x)
    }

    /// The point on shell `shell`'s top-ring midline (radius 0.2 + (k + ½)·0.8/K at y = h_k) at angle `angle`.
    static func ringPoint(_ shell: Int, angle: Double, snapshot: Snapshot) -> SIMD3<Double> {
        let w: Double = 0.8 / Double(snapshot.shells.count)
        let radius: Double = 0.2 + (Double(shell) + 0.5) * w
        let height: Double = 0.08 + 0.06 * Double(snapshot.shells.count - 1 - shell)
        return SIMD3(radius * cos(angle), height, radius * sin(angle))
    }

    /// The first of 32 angles from the front (π/2) round the ring whose midline point on shell `shell` lies inside the
    /// view and picks that shell (`AmethystEscapePicker.pick` as the oracle), with its view point; nil when none does.
    static func ringTarget(_ shell: Int, snapshot: Snapshot, view: Vec2, orbit: Orbit) -> (angle: Double, point: Vec2)? {
        var i: Int = 0
        while i < 32 {
            let angle: Double = Double.pi / 2 + 2 * Double.pi * Double(i) / 32
            if let p = screen(ringPoint(shell, angle: angle, snapshot: snapshot), snapshot: snapshot, view: view,
                              orbit: orbit),
               p.x > 40, p.y > 40, p.x < view.x - 40, p.y < view.y - 40,
               Picker.pick(SIMD2(p.x, p.y), size: SIMD2(view.x, view.y), snapshot: snapshot,
                           orbit: orbit) == .shell(shell) {
                return (angle, p)
            }
            i += 1
        }
        return nil
    }

    // MARK: Scripting

    /// A pointer event.
    static func event(_ id: Int, _ phase: PointerPhase, _ point: Vec2, _ time: Double) -> PointerEvent {
        PointerEvent(id: id, phase: phase, location: point, timestamp: time)
    }

    /// A unit random number 0 ..< 1.
    static func unit(_ random: inout SeededRandom) -> Double {
        Double(random.next() >> 11) / 9_007_199_254_740_992
    }

    /// A random whole number 0 ..< `count`.
    static func below(_ count: Int, _ random: inout SeededRandom) -> Int {
        min(Int(unit(&random) * Double(count)), count - 1)
    }

    /// `p` kept one point inside `view`.
    static func inside(_ p: Vec2, _ view: Vec2) -> Vec2 {
        Vec2(min(max(p.x, 1), view.x - 1), min(max(p.y, 1), view.y - 1))
    }

    /// Feeds one finger along `points` at `times` (began, moved …, ended); returns the actions, the dragged shell seen
    /// after touch-down, the candidate seen before the release and the state after touch-down.
    static func play(_ controller: inout Controller, _ points: [Vec2], _ times: [Double], view: Vec2,
                     snapshot: Snapshot, id: Int = 1)
        -> (actions: [Action], dragged: Int?, candidate: Int, state: Controller.State) {
        var actions: [Action] = []
        var dragged: Int?
        var candidate: Int = 0
        var state: Controller.State = .idle
        var index: Int = 0
        while index < points.count {
            let phase: PointerPhase = index == 0 ? .began : (index == points.count - 1 ? .ended : .moved)
            actions += controller.handle(event(id, phase, points[index], times[index]), viewSize: view,
                                         snapshot: snapshot)
            if index == 0 {
                dragged = controller.draggedShell
                state = controller.state
            }
            if index == points.count - 2 { candidate = controller.candidateSectors }
            index += 1
        }
        return (actions, dragged, candidate, state)
    }

    /// Two fingers about the view centre move their midpoint by `move` points and lift; returns the actions sent.
    static func twoFingers(_ controller: inout Controller, by move: Vec2, view: Vec2, snapshot: Snapshot,
                           time: Double) -> [Action] {
        let a: Vec2 = Vec2(view.x * 0.4, view.y * 0.5)
        let b: Vec2 = Vec2(view.x * 0.6, view.y * 0.5)
        var actions: [Action] = controller.handle(event(7, .began, a, time), viewSize: view, snapshot: snapshot)
        actions += controller.handle(event(8, .began, b, time + frame), viewSize: view, snapshot: snapshot)
        actions += controller.handle(event(7, .moved, a + move, time + 2 * frame), viewSize: view, snapshot: snapshot)
        actions += controller.handle(event(8, .moved, b + move, time + 3 * frame), viewSize: view, snapshot: snapshot)
        actions += controller.handle(event(7, .ended, a + move, time + 4 * frame), viewSize: view, snapshot: snapshot)
        actions += controller.handle(event(8, .ended, b + move, time + 5 * frame), viewSize: view, snapshot: snapshot)
        return actions
    }

    /// A controller turned to `orbit` by a two-finger drag in `view`.
    static func controller(at orbit: Orbit, view: Vec2, snapshot: Snapshot) -> Controller {
        var controller: Controller = Controller()
        let move: Vec2 = Vec2(orbit.yaw / (Double.pi / 2) * view.x,
                              -(orbit.pitch - Orbit.authored.pitch) / (Double.pi / 3) * view.y)
        let actions: [Action] = twoFingers(&controller, by: move, view: view, snapshot: snapshot, time: 0)
        #expect(actions.isEmpty)
        #expect(abs(controller.orbit.yaw - orbit.yaw) < 1e-9 && abs(controller.orbit.pitch - orbit.pitch) < 1e-9)
        #expect(controller.state == .idle)
        return controller
    }

    // MARK: Independent expectation

    /// What a one-finger script must send: the actions, the dragged shell at touch-down, the candidate before release
    /// (the release point repeats the last move), and whether the swept angle lies too near a rounding boundary to
    /// compare (then only the counts are checked).
    struct Expectation {
        var actions: [Action]
        var dragged: Int?
        var candidate: Int
        var ambiguous: Bool
    }

    /// The expectation for one finger along `points` at `times` (scripts never pair into double taps: each runs on a
    /// fresh controller).
    static func expected(_ points: [Vec2], _ times: [Double], snapshot: Snapshot, view: Vec2,
                         orbit: Orbit) -> Expectation {
        let down: Vec2 = points[0]
        var travel: Double = 0
        for p in points { travel = max(travel, (p - down).length) }
        let duration: Double = times[times.count - 1] - times[0]
        let pick: AmethystEscapePick = Picker.pick(SIMD2(down.x, down.y), size: SIMD2(view.x, view.y),
                                                   snapshot: snapshot, orbit: orbit)
        let playing: Bool = snapshot.stage == .playing
        let tap: Bool = travel < 10 && duration <= 0.5
        switch pick {
        case .pearl:
            return Expectation(actions: tap && playing ? [.advance] : [], dragged: nil, candidate: 0,
                               ambiguous: false)
        case .empty:
            return Expectation(actions: [], dragged: nil, candidate: 0, ambiguous: false)
        case .shell(let k):
            if !playing { return Expectation(actions: tap ? [.select(k)] : [], dragged: nil, candidate: 0,
                                             ambiguous: false) }
            // The swept angle: the sum of the angle changes, each taken the short way round.
            var swept: Double = 0
            var last: Double?
            var ambiguous: Bool = false
            for p in points {
                guard let a = ownAngle(shell: k, at: p, snapshot: snapshot, view: view, orbit: orbit) else { continue }
                if let l = last {
                    var d: Double = a - l
                    while d > Double.pi { d -= 2 * Double.pi }
                    while d < -Double.pi { d += 2 * Double.pi }
                    if abs(abs(d) - Double.pi) < 1e-6 { ambiguous = true }
                    swept += d
                }
                last = a
            }
            let s: Int = snapshot.sectors
            let ratio: Double = swept / (2 * Double.pi) * Double(s)
            if abs(abs(ratio - ratio.rounded(.down)) - 0.5) < ambiguity { ambiguous = true }
            var n: Int = Int(ratio.rounded(.toNearestOrAwayFromZero))
            n = ((n % s) + s) % s
            if 2 * n > s { n -= s }
            let candidate: Int = travel >= 10 ? n : 0
            if travel >= 16 {
                var turns: [Action] = []
                var i: Int = 0
                while i < abs(n) {
                    turns.append(.turn(k, n > 0 ? 1 : -1))
                    i += 1
                }
                return Expectation(actions: turns, dragged: k, candidate: candidate, ambiguous: ambiguous)
            }
            return Expectation(actions: tap ? [.select(k)] : [], dragged: k, candidate: candidate,
                               ambiguous: ambiguous)
        }
    }

    /// A random scripted touch of kind 0 … 4: a shell drag round its ring, a shell tap or press, a pearl tap or press,
    /// a short drag (8 … 20 points) from a shell, a random touch anywhere.
    static func script(_ kind: Int, snapshot: Snapshot, view: Vec2, orbit: Orbit, start: Double,
                       random: inout SeededRandom) -> (points: [Vec2], times: [Double]) {
        var points: [Vec2] = []
        var times: [Double] = []
        let shell: Int = below(snapshot.shells.count, &random)
        let from: Double = unit(&random) * 2 * Double.pi
        var duration: Double = 0.05 + unit(&random) * 0.4
        switch kind {
        case 0:
            // Up to 0.6 of a turn either way, in 12 steps (each well under half a turn).
            let sweep: Double = (unit(&random) * 2 - 1) * 1.2 * Double.pi
            var i: Int = 0
            while i <= 12 {
                let world: SIMD3<Double> = ringPoint(shell, angle: from + sweep * Double(i) / 12, snapshot: snapshot)
                if let p = screen(world, snapshot: snapshot, view: view, orbit: orbit) {
                    points.append(inside(p, view))
                }
                i += 1
            }
        case 1, 2:
            var centre: Vec2 = Vec2(view.x / 2, view.y / 2)
            let world: SIMD3<Double> = kind == 1 ? ringPoint(shell, angle: from, snapshot: snapshot)
                : Geometry.pearlCentre(snapshot)
            if let p = screen(world, snapshot: snapshot, view: view, orbit: orbit) { centre = inside(p, view) }
            let jitter: Double = unit(&random) * 13
            let direction: Double = unit(&random) * 2 * Double.pi
            points = [centre, inside(centre + Vec2(cos(direction), sin(direction)) * jitter, view)]
            duration = 0.05 + unit(&random) * 0.8
        case 3:
            var centre: Vec2 = Vec2(view.x / 2, view.y / 2)
            if let p = screen(ringPoint(shell, angle: from, snapshot: snapshot), snapshot: snapshot, view: view,
                              orbit: orbit) {
                centre = inside(p, view)
            }
            let length: Double = 8 + unit(&random) * 12
            let direction: Double = unit(&random) * 2 * Double.pi
            points = [centre, inside(centre + Vec2(cos(direction), sin(direction)) * length, view)]
        default:
            let a: Vec2 = Vec2(unit(&random) * view.x, unit(&random) * view.y)
            let b: Vec2 = unit(&random) < 0.5 ? a : Vec2(unit(&random) * view.x, unit(&random) * view.y)
            points = [inside(a, view), inside(b, view)]
        }
        if points.count < 2 { points = [Vec2(view.x / 2, view.y / 2), Vec2(view.x / 2, view.y / 2)] }
        var i: Int = 0
        while i < points.count {
            times.append(start + duration * Double(i) / Double(points.count - 1))
            i += 1
        }
        // The finger rests where it lifts: the last move is at the release point.
        points.insert(points[points.count - 1], at: points.count - 1)
        times.insert(start + duration, at: times.count - 1)
        return (points, times)
    }

    // MARK: Tests

    @Test func seededScriptsMatchTheIndependentExpectation() throws {
        var all: [Snapshot] = []
        for number in Self.levels { all += try Self.snapshots(number) }
        var stages: Set<String> = []
        for s in all { stages.insert(s.stage.rawValue) }
        #expect(stages.contains("playing") && stages.contains("won") && stages.contains("failed"), "\(stages)")
        var random: SeededRandom = SeededRandom(seed: Self.seed)
        var counts: [String: Int] = [:]
        var mismatches: Int = 0
        var ambiguous: Int = 0
        var script: Int = 0
        while script < 500 {
            let snapshot: Snapshot = all[Self.below(all.count, &random)]
            let view: Vec2 = Self.views[Self.below(Self.views.count, &random)]
            let orbit: Orbit = Self.orbits[Self.below(Self.orbits.count, &random)]
            var controller: Controller = Self.controller(at: orbit, view: view, snapshot: snapshot)
            let kind: Int = script % 5
            let touch: (points: [Vec2], times: [Double]) =
                Self.script(kind, snapshot: snapshot, view: view, orbit: orbit, start: 10, random: &random)
            let want: Expectation = Self.expected(touch.points, touch.times, snapshot: snapshot, view: view,
                                                  orbit: orbit)
            let got: (actions: [Action], dragged: Int?, candidate: Int, state: Controller.State) =
                Self.play(&controller, touch.points, touch.times, view: view, snapshot: snapshot)
            if want.ambiguous {
                ambiguous += 1
            } else if got.actions != want.actions || got.dragged != want.dragged || got.candidate != want.candidate {
                mismatches += 1
                if mismatches <= 5 {
                    Issue.record(Comment(rawValue: "script \(script) kind \(kind): \(got.actions) "
                        + "\(String(describing: got.dragged)) \(got.candidate) expected \(want.actions) "
                        + "\(String(describing: want.dragged)) \(want.candidate)"))
                }
            }
            #expect(got.actions.count <= snapshot.sectors / 2)
            #expect(controller.state == .idle && controller.draggedShell == nil && controller.candidateSectors == 0)
            #expect(controller.isolated == nil)
            if snapshot.stage != .playing {
                for a in got.actions {
                    if case .turn = a { Issue.record("a turn on a finished play") }
                    if a == .advance { Issue.record("an advance on a finished play") }
                }
            }
            for a in got.actions {
                let key: String
                switch a {
                case .turn(_, let step): key = step > 0 ? "turn+" : "turn-"
                case .advance: key = "advance"
                case .select: key = "select"
                case .isolate: key = "isolate"
                case .resetView: key = "resetView"
                }
                counts[key, default: 0] += 1
            }
            script += 1
        }
        #expect(mismatches == 0)
        #expect(ambiguous <= 5, "\(ambiguous) ambiguous scripts")
        for key in ["turn+", "turn-", "advance", "select"] {
            #expect((counts[key] ?? 0) > 0, "no \(key) in 500 scripts: \(counts)")
        }
        #expect(counts["isolate"] == nil && counts["resetView"] == nil)
    }

    @Test func aDragTurnsTheShellItsSweptSectorsAndPreviewsThem() throws {
        var core: Core = try Core.opening(number: 21)
        let snapshot: Snapshot = core.snapshot(time: 0)
        let view: Vec2 = Self.views[1]
        let s: Int = snapshot.sectors
        let k: Int = snapshot.shells.count - 1
        var controller: Controller = Controller()
        // Two sectors clockwise from above (+x towards +z), starting where the ring picks shell k.
        let from: Double = try #require(Self.ringTarget(k, snapshot: snapshot, view: view, orbit: .authored)).angle
        var points: [Vec2] = []
        var i: Int = 0
        while i <= 8 {
            let angle: Double = from + 2 * (2 * Double.pi / Double(s)) * Double(i) / 8
            points.append(try #require(Self.screen(Self.ringPoint(k, angle: angle, snapshot: snapshot),
                                                   snapshot: snapshot, view: view, orbit: .authored)))
            i += 1
        }
        try #require(Picker.pick(SIMD2(points[0].x, points[0].y), size: SIMD2(view.x, view.y), snapshot: snapshot,
                                 orbit: .authored) == .shell(k))
        #expect(controller.handle(Self.event(1, .began, points[0], 0), viewSize: view, snapshot: snapshot).isEmpty)
        #expect(controller.state == .shellDrag && controller.draggedShell == k && controller.candidateSectors == 0)
        i = 1
        while i < points.count {
            #expect(controller.handle(Self.event(1, .moved, points[i], 0.05 * Double(i)), viewSize: view,
                                      snapshot: snapshot).isEmpty)
            i += 1
        }
        #expect(controller.candidateSectors == 2)
        #expect(controller.preview(of: snapshot) == snapshot.previewing(shell: k, sectors: 2))
        let before: String = try Self.digest(core)
        let actions: [Action] = controller.handle(Self.event(1, .ended, points[points.count - 1], 0.5),
                                                  viewSize: view, snapshot: snapshot)
        #expect(actions == [.turn(k, 1), .turn(k, 1)])
        #expect(try Self.digest(core) == before)
        #expect(controller.draggedShell == nil && controller.candidateSectors == 0 && controller.state == .idle)
        #expect(controller.preview(of: snapshot) == snapshot)
        for a in actions { Self.apply(a, to: &core) }
        var direct: Core = try Core.opening(number: 21)
        _ = direct.apply(Self.action("shell.rotate", [Double(k), 1]))
        _ = direct.apply(Self.action("shell.rotate", [Double(k), 1]))
        #expect(try Self.digest(core) == Self.digest(direct))
        #expect(core.snapshot(time: 0).shells[k].offset == (snapshot.shells[k].offset + 2) % s)
    }

    @Test func tenToSixteenPointsSendNothing() throws {
        let snapshot: Snapshot = try Core.opening(number: 1).snapshot(time: 0)
        let view: Vec2 = Self.views[0]
        let pearl: Vec2 = try #require(Self.screen(Geometry.pearlCentre(snapshot), snapshot: snapshot, view: view,
                                                   orbit: .authored))
        let k: Int = snapshot.shells.count - 1
        let ring: Vec2 = try #require(Self.ringTarget(k, snapshot: snapshot, view: view, orbit: .authored)).point
        #expect(Picker.pick(SIMD2(pearl.x, pearl.y), size: SIMD2(view.x, view.y), snapshot: snapshot,
                            orbit: .authored) == .pearl)
        #expect(Picker.pick(SIMD2(ring.x, ring.y), size: SIMD2(view.x, view.y), snapshot: snapshot,
                            orbit: .authored) == .shell(k))
        let starts: [(Vec2, [Action])] = [(pearl, [.advance]), (ring, [.select(k)])]
        for (start, tap) in starts {
            for length in [10.0, 12.0, 15.9] {
                var controller: Controller = Controller()
                let end: Vec2 = start + Vec2(length, 0)
                let got: [Action] = Self.play(&controller, [start, end, end], [0, 0.1, 0.2], view: view,
                                              snapshot: snapshot).actions
                #expect(got.isEmpty, "\(length) points: \(got)")
            }
            var controller: Controller = Controller()
            let near: Vec2 = start + Vec2(9.9, 0)
            #expect(Self.play(&controller, [start, near, near], [0, 0.1, 0.2], view: view,
                              snapshot: snapshot).actions == tap)
            // A press longer than 0.5 s is not a tap.
            #expect(Self.play(&controller, [start, start], [5, 5.6], view: view, snapshot: snapshot).actions.isEmpty)
        }
    }

    @Test func secondFingersCancelsAndFinishedPlaysSendNothing() throws {
        let all: [Snapshot] = try Self.snapshots(41)
        let view: Vec2 = Self.views[2]
        var finished: Int = 0
        for snapshot in all {
            let pearl: Vec2 = try #require(Self.screen(Geometry.pearlCentre(snapshot), snapshot: snapshot,
                                                       view: view, orbit: .authored))
            let k: Int = 0
            let ring: Vec2 = try #require(Self.screen(Self.ringPoint(k, angle: Double.pi / 2, snapshot: snapshot),
                                                      snapshot: snapshot, view: view, orbit: .authored))
            let far: Vec2 = try #require(Self.screen(Self.ringPoint(k, angle: Double.pi, snapshot: snapshot),
                                                     snapshot: snapshot, view: view, orbit: .authored))
            for start in [pearl, ring] {
                // A second finger cancels and orbits; nothing is sent when every finger lifts.
                var controller: Controller = Controller()
                var actions: [Action] = controller.handle(Self.event(1, .began, start, 0), viewSize: view,
                                                          snapshot: snapshot)
                actions += controller.handle(Self.event(1, .moved, far, 0.1), viewSize: view, snapshot: snapshot)
                actions += controller.handle(Self.event(2, .began, Vec2(10, 10), 0.2), viewSize: view,
                                             snapshot: snapshot)
                #expect(controller.state == .orbiting)
                #expect(controller.draggedShell == nil && controller.candidateSectors == 0)
                actions += controller.handle(Self.event(2, .ended, Vec2(10, 10), 0.3), viewSize: view,
                                             snapshot: snapshot)
                #expect(controller.state == .cancelled)
                actions += controller.handle(Self.event(1, .moved, start, 0.35), viewSize: view, snapshot: snapshot)
                actions += controller.handle(Self.event(1, .ended, start, 0.4), viewSize: view, snapshot: snapshot)
                #expect(actions.isEmpty)
                #expect(controller.state == .idle)
                // A `.cancelled` phase sends nothing, a drag or a tap.
                actions = controller.handle(Self.event(3, .began, start, 2), viewSize: view, snapshot: snapshot)
                actions += controller.handle(Self.event(3, .moved, far, 2.1), viewSize: view, snapshot: snapshot)
                actions += controller.handle(Self.event(3, .cancelled, far, 2.2), viewSize: view, snapshot: snapshot)
                actions += controller.handle(Self.event(4, .began, start, 3), viewSize: view, snapshot: snapshot)
                actions += controller.handle(Self.event(4, .cancelled, start, 3.05), viewSize: view,
                                             snapshot: snapshot)
                #expect(actions.isEmpty)
                #expect(controller.state == .idle && controller.draggedShell == nil)
                // `cancel()` mid-gesture: the release afterwards is unknown and sends nothing.
                actions = controller.handle(Self.event(5, .began, start, 4), viewSize: view, snapshot: snapshot)
                controller.cancel()
                actions += controller.handle(Self.event(5, .ended, start, 4.05), viewSize: view, snapshot: snapshot)
                #expect(actions.isEmpty && controller.state == .idle)
            }
            guard snapshot.stage != .playing else { continue }
            finished += 1
            // A finished play: drags and pearl taps send nothing; a shell tap still selects.
            var controller: Controller = Controller()
            let drag: [Action] = Self.play(&controller, [ring, far, far], [10, 10.1, 10.2], view: view,
                                           snapshot: snapshot).actions
            #expect(drag.isEmpty)
            if Picker.pick(SIMD2(pearl.x, pearl.y), size: SIMD2(view.x, view.y), snapshot: snapshot,
                           orbit: .authored) == .pearl {
                #expect(Self.play(&controller, [pearl, pearl], [11, 11.1], view: view,
                                  snapshot: snapshot).actions.isEmpty)
            }
            if Picker.pick(SIMD2(ring.x, ring.y), size: SIMD2(view.x, view.y), snapshot: snapshot,
                           orbit: .authored) == .shell(k) {
                #expect(Self.play(&controller, [ring, ring], [12, 12.1], view: view,
                                  snapshot: snapshot).actions == [.select(k)])
            }
        }
        #expect(finished >= 1)
    }

    @Test func doubleTapsToggleIsolationAndResetTheView() throws {
        let all: [Snapshot] = try Self.snapshots(61)
        let view: Vec2 = Self.views[0]
        let corner: Vec2 = Vec2(4, 4)
        for snapshot in all {
            let turned: Orbit = Orbit(yaw: 0.3, pitch: 0.9)
            var controller: Controller = Self.controller(at: turned, view: view, snapshot: snapshot)
            let size: SIMD2<Double> = SIMD2(view.x, view.y)
            let inner: Int = 0
            let outer: Int = snapshot.shells.count - 1
            let a: Vec2 = try #require(Self.ringTarget(outer, snapshot: snapshot, view: view, orbit: turned)).point
            let b: Vec2 = try #require(Self.ringTarget(inner, snapshot: snapshot, view: view, orbit: turned)).point
            try #require(Picker.pick(SIMD2(a.x, a.y), size: size, snapshot: snapshot, orbit: turned) == .shell(outer))
            try #require(Picker.pick(SIMD2(b.x, b.y), size: size, snapshot: snapshot, orbit: turned) == .shell(inner))
            try #require(Picker.pick(SIMD2(corner.x, corner.y), size: size, snapshot: snapshot,
                                     orbit: turned) == .empty)
            // Double tap on the outer shell isolates it; again clears it.
            #expect(Self.play(&controller, [a, a], [1, 1.05], view: view, snapshot: snapshot).actions
                    == [.select(outer)])
            #expect(Self.play(&controller, [a, a], [1.2, 1.3], view: view, snapshot: snapshot).actions
                    == [.isolate(outer)])
            #expect(controller.isolated == outer)
            #expect(Self.play(&controller, [a, a], [2, 2.05], view: view, snapshot: snapshot).actions
                    == [.select(outer)])
            #expect(Self.play(&controller, [a, a], [2.2, 2.3], view: view, snapshot: snapshot).actions
                    == [.isolate(nil)])
            #expect(controller.isolated == nil)
            // Isolating another shell replaces the isolation.
            _ = Self.play(&controller, [a, a], [3, 3.05], view: view, snapshot: snapshot)
            _ = Self.play(&controller, [a, a], [3.2, 3.3], view: view, snapshot: snapshot)
            _ = Self.play(&controller, [b, b], [4, 4.05], view: view, snapshot: snapshot)
            #expect(Self.play(&controller, [b, b], [4.2, 4.3], view: view, snapshot: snapshot).actions
                    == [.isolate(inner)])
            #expect(controller.isolated == inner)
            // Too slow (0.4 s between lifts) or two different shells: two selections, isolation unchanged.
            #expect(Self.play(&controller, [b, b], [5, 5.05], view: view, snapshot: snapshot).actions
                    == [.select(inner)])
            #expect(Self.play(&controller, [b, b], [5.4, 5.45], view: view, snapshot: snapshot).actions
                    == [.select(inner)])
            _ = Self.play(&controller, [a, a], [6, 6.05], view: view, snapshot: snapshot)
            #expect(Self.play(&controller, [b, b], [6.1, 6.15], view: view, snapshot: snapshot).actions
                    == [.select(inner)])
            #expect(controller.isolated == inner)
            controller.clearIsolation()
            #expect(controller.isolated == nil)
            // A double tap on empty space resets the view in every stage; too slow does not.
            #expect(Self.play(&controller, [corner, corner], [7, 7.05], view: view,
                              snapshot: snapshot).actions.isEmpty)
            #expect(abs(controller.orbit.yaw - 0.3) < 1e-9)
            #expect(Self.play(&controller, [corner, corner], [7.4, 7.45], view: view,
                              snapshot: snapshot).actions.isEmpty)
            #expect(Self.play(&controller, [corner, corner], [7.6, 7.65], view: view,
                              snapshot: snapshot).actions == [.resetView])
            #expect(controller.orbit == .authored)
            // Two lifts 30 points apart are not a double tap.
            controller = Self.controller(at: turned, view: view, snapshot: snapshot)
            let apart: Vec2 = corner + Vec2(30, 0)
            try #require(Picker.pick(SIMD2(apart.x, apart.y), size: size, snapshot: snapshot,
                                     orbit: turned) == .empty)
            _ = Self.play(&controller, [corner, corner], [8, 8.05], view: view, snapshot: snapshot)
            #expect(Self.play(&controller, [apart, apart], [8.1, 8.15], view: view,
                              snapshot: snapshot).actions.isEmpty)
            #expect(abs(controller.orbit.yaw - 0.3) < 1e-9)
        }
    }

    @Test func orbitFollowsClampsAndRebases() throws {
        let snapshot: Snapshot = try Core.opening(number: 1).snapshot(time: 0)
        let view: Vec2 = Self.views[1]
        var controller: Controller = Controller()
        #expect(Controller.yawPerViewWidth == Double.pi / 2 && Controller.pitchPerViewHeight == Double.pi / 3)
        #expect(Controller.tapDistance == 10 && Controller.dragDistance == 16 && Controller.tapDuration == 0.5
                && Controller.doubleTapWindow == 0.35)
        // A quarter width right turns 22.5° yaw; a tenth of the height up adds 6° pitch.
        var actions: [Action] = Self.twoFingers(&controller, by: Vec2(view.x * 0.25, -view.y * 0.1), view: view,
                                                snapshot: snapshot, time: 0)
        let degree: Double = Double.pi / 180
        #expect(abs(controller.orbit.yaw - 22.5 * degree) < 1e-9)
        #expect(abs(controller.orbit.pitch - 56 * degree) < 1e-9)
        // Far moves clamp.
        actions += Self.twoFingers(&controller, by: Vec2(view.x * 3, -view.y * 3), view: view, snapshot: snapshot,
                                   time: 1)
        #expect(abs(controller.orbit.yaw - Orbit.yawLimit) < 1e-12)
        #expect(abs(controller.orbit.pitch - Orbit.pitchRange.upperBound) < 1e-12)
        actions += Self.twoFingers(&controller, by: Vec2(-view.x * 3, view.y * 3), view: view, snapshot: snapshot,
                                   time: 2)
        #expect(abs(controller.orbit.yaw + Orbit.yawLimit) < 1e-12)
        #expect(abs(controller.orbit.pitch - Orbit.pitchRange.lowerBound) < 1e-12)
        #expect(actions.isEmpty)
        controller.resetView()
        #expect(controller.orbit == .authored)
        // A third finger re-bases the midpoint: the camera does not jump.
        _ = controller.handle(Self.event(1, .began, Vec2(100, 400), 3), viewSize: view, snapshot: snapshot)
        _ = controller.handle(Self.event(2, .began, Vec2(300, 400), 3.1), viewSize: view, snapshot: snapshot)
        _ = controller.handle(Self.event(3, .began, Vec2(900, 100), 3.2), viewSize: view, snapshot: snapshot)
        #expect(controller.orbit == .authored)
        #expect(controller.state == .orbiting)
        _ = controller.handle(Self.event(3, .moved, Vec2(930, 100), 3.3), viewSize: view, snapshot: snapshot)
        #expect(abs(controller.orbit.yaw - 10.0 / view.x * Double.pi / 2) < 1e-9)
        #expect(controller.camera(viewSize: view, snapshot: snapshot)
                == Geometry.camera(snapshot, aspect: view.x / view.y, orbit: controller.orbit))
        #expect(controller.camera(viewSize: Vec2(0, 100), snapshot: snapshot) == nil)
    }

    @Test func orbitAndIsolationNeverChangeTheDigest() throws {
        var random: SeededRandom = SeededRandom(seed: Self.seed + 1)
        for number in Self.levels {
            let core: Core = try Core.opening(number: number)
            let before: String = try Self.digest(core)
            let snapshot: Snapshot = core.snapshot(time: 0)
            let view: Vec2 = Self.views[Self.below(Self.views.count, &random)]
            var controller: Controller = Controller()
            _ = Self.twoFingers(&controller, by: Vec2(Self.unit(&random) * 400 - 200, Self.unit(&random) * 400 - 200),
                                view: view, snapshot: snapshot, time: 0)
            let k: Int = Self.below(snapshot.shells.count, &random)
            let p: Vec2 = try #require(Self.ringTarget(k, snapshot: snapshot, view: view,
                                                       orbit: controller.orbit)).point
            var sent: [Action] = Self.play(&controller, [p, p], [1, 1.05], view: view, snapshot: snapshot).actions
            sent += Self.play(&controller, [p, p], [1.2, 1.25], view: view, snapshot: snapshot).actions
            controller.resetView()
            var copy: Core = core
            for a in sent {
                if case .turn = a { Issue.record("a tap sent a turn") }
                if a == .advance { Issue.record("a shell tap sent an advance") }
                Self.apply(a, to: &copy)
            }
            #expect(try Self.digest(copy) == before)
            #expect(copy.snapshot(time: 0) == snapshot)
            #expect(try Self.digest(core) == before)
        }
    }
}
