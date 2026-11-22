// ChronoConstellatorGestureControllerTests — feature 354 (R02-G06-04) T-R02G0604-003 (FR-R02G0604-001, 002, 003, 005,
// 006; SC-R02G0604-001, 003, 004). 500 seeded (seed 2_354) scripted star drags, presses, taps, scrubs, touches near the
// tick bar and random touches on certified levels 1, 41 and 81 (fresh, with a hold, stepped, failed and won) at three
// view sizes and three orbits reached by two-finger drags send exactly the actions an independent expectation computed
// here from `ChronoConstellatorPicker` (pick at touch-down, loop index and tick at release), the test's own tick-bar
// distance and the gesture rules predicts; the dragged star and candidate cell follow. Second fingers, `.cancelled`
// phases, `cancel()` and edits after tick 0 send no edit; a double tap on empty space resets the view in every stage
// and only within 0.35 s; the orbit follows 90° yaw per width and 60° pitch per height, clamps and re-bases on a third
// finger; every scrub applied through the adapter ends in the digest of a plain replay of the same timeline to its
// tick. Plain loops and explicit types (CI type-check rule).
import Foundation
import Testing
import VisualCoreDiagnostics
import VisualCoreExperience
import VisualCoreMath
import VisualCoreScenes
import VisualCoreSimulation
@testable import ChronoConstellatorCore

@Suite struct ChronoConstellatorGestureControllerTests {
    typealias Controller = ChronoConstellatorGestureController
    typealias Snapshot = ChronoConstellatorSceneSnapshot
    typealias Action = ChronoConstellatorGestureAction
    typealias Geometry = ChronoConstellatorSceneGeometry
    typealias Picker = ChronoConstellatorPicker
    typealias Orbit = ChronoConstellatorOrbit
    typealias Core = ChronoConstellatorExperienceCore

    /// The seed of every random choice here.
    static let seed: UInt64 = 2_354
    /// The view sizes every script runs at.
    static let views: [Vec2] = [Vec2(390, 844), Vec2(1_180, 820), Vec2(1_024, 1_366)]
    /// The scripted orbits (the first is the authored one), reached by two-finger drags.
    static let orbits: [Orbit] = [.authored, Orbit(yaw: 0.5, pitch: 0.75), Orbit(yaw: -0.6, pitch: 1.2)]
    /// The certified levels used.
    static let levels: [Int] = [1, 41, 81]
    /// The time between scripted events in seconds.
    static let frame: Double = 1.0 / 60

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

    /// Applies a gesture action to `core` as the presenter maps it (`select` and `resetView` send nothing).
    static func apply(_ gesture: Action, to core: inout Core) {
        switch gesture {
        case .phase(let star, let index):
            _ = core.apply(action("star.phase", [Double(star), Double(index)]))
        case .step(let ticks):
            _ = core.apply(action("time.step", [Double(ticks)]))
        case .rewind:
            _ = core.apply(action("time.rewind"))
        case .hold(let star, let start, let length):
            _ = core.apply(action("star.hold", [Double(star), Double(start), Double(length)]))
        case .release(let star, let start):
            _ = core.apply(action("star.release", [Double(star), Double(start)]))
        case .select, .resetView:
            break
        }
    }

    /// Snapshots of certified level `number`: fresh (playing, tick 0), with star 0's standard hold, stepped 5 ticks,
    /// failed (when stepping the fresh play to its limit fails) and won (the certified phases, then run).
    static func snapshots(_ number: Int) throws -> [Snapshot] {
        var result: [Snapshot] = []
        let fresh: Core = try Core.opening(number: number)
        #expect(fresh.play.stage == .playing)
        result.append(fresh.snapshot(time: 0))
        var held: Core = fresh
        _ = held.apply(action("star.hold", [0, 1, 10]))
        if !held.snapshot(time: 0).holds.isEmpty { result.append(held.snapshot(time: 0)) }
        var stepped: Core = fresh
        _ = stepped.apply(action("time.step", [5]))
        result.append(stepped.snapshot(time: 0))
        var failed: Core = fresh
        _ = failed.apply(action("time.step", [Double(fresh.play.level.tickLimit)]))
        if failed.play.stage == .failed { result.append(failed.snapshot(time: 0)) }
        let solution: [Int] = try Core.generated(number: number).solution.phases
        var won: Core = fresh
        var star: Int = 0
        while star < solution.count {
            if won.snapshot(time: 0).phases[star] != solution[star] {
                _ = won.apply(action("star.phase", [Double(star), Double(solution[star])]))
            }
            star += 1
        }
        _ = won.apply(action("time.step", [Double(fresh.play.level.tickLimit)]))
        #expect(won.play.stage == .won)
        result.append(won.snapshot(time: 0))
        return result
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

    /// The view point of `world` for `snapshot` in `view` at `orbit`, or nil.
    static func screen(_ world: SIMD3<Double>, snapshot: Snapshot, view: Vec2, orbit: Orbit) -> Vec2? {
        let camera: ChronoConstellatorCamera = Geometry.camera(snapshot, aspect: view.x / view.y, orbit: orbit)
        guard let v = Geometry.project(world, camera: camera) else { return nil }
        return Vec2(v.x * view.x, v.y * view.y)
    }

    /// The view point of the field point at x fraction `fraction` of the grid's width and `depth` cells inside the
    /// near edge.
    static func bandPoint(_ fraction: Double, depth: Double, snapshot: Snapshot, view: Vec2, orbit: Orbit) -> Vec2? {
        let u: Double = Geometry.cellSize(snapshot)
        let halfWidth: Double = Double(snapshot.columns) * u / 2
        let z: Double = Double(snapshot.rows) * u / 2 - depth * u
        return screen(SIMD3(-halfWidth + 2 * halfWidth * fraction, 0, z), snapshot: snapshot, view: view, orbit: orbit)
    }

    /// The test's own distance from `point` to the projected tick-bar line, by sampling the line in 200
    /// pieces and refining about the nearest sample.
    static func barDistance(_ point: Vec2, snapshot: Snapshot, view: Vec2, orbit: Orbit) -> Double {
        let u: Double = Geometry.cellSize(snapshot)
        let halfWidth: Double = Double(snapshot.columns) * u / 2
        let z: Double = Double(snapshot.rows) * u / 2 - Geometry.tickBarInset * u
        let y: Double = Geometry.trackLift * u
        var best: Double = .infinity
        var bestX: Double = 0
        var index: Int = 0
        while index <= 200 {
            let x: Double = -halfWidth + 2 * halfWidth * Double(index) / 200
            if let p = screen(SIMD3(x, y, z), snapshot: snapshot, view: view, orbit: orbit),
               (p - point).length < best {
                best = (p - point).length
                bestX = x
            }
            index += 1
        }
        // Refine within one coarse piece either side of the best sample.
        let piece: Double = 2 * halfWidth / 200
        index = 0
        while index <= 200 {
            let x: Double = min(max(bestX - piece + 2 * piece * Double(index) / 200, -halfWidth), halfWidth)
            if let p = screen(SIMD3(x, y, z), snapshot: snapshot, view: view, orbit: orbit) {
                best = min(best, (p - point).length)
            }
            index += 1
        }
        return best
    }

    /// Feeds one finger along `points` at `times` (began, moved …, ended); returns the actions, the dragged star seen
    /// after touch-down and the candidate cell seen after the last move.
    static func play(_ controller: inout Controller, _ points: [Vec2], _ times: [Double], view: Vec2,
                     snapshot: Snapshot) -> (actions: [Action], dragged: Int?, candidate: Int?) {
        var actions: [Action] = []
        var dragged: Int?
        var candidate: Int?
        var index: Int = 0
        while index < points.count {
            let phase: PointerPhase = index == 0 ? .began : (index == points.count - 1 ? .ended : .moved)
            actions += controller.handle(event(1, phase, points[index], times[index]), viewSize: view,
                                         snapshot: snapshot)
            if index == 0 { dragged = controller.draggedStar }
            if index == points.count - 2 { candidate = controller.candidateCell }
            index += 1
        }
        return (actions, dragged, candidate)
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
        let move: Vec2 = Vec2(orbit.yaw / Controller.yawPerViewWidth * view.x,
                              -(orbit.pitch - Orbit.authored.pitch) / Controller.pitchPerViewHeight * view.y)
        let actions: [Action] = twoFingers(&controller, by: move, view: view, snapshot: snapshot, time: 0)
        #expect(actions.isEmpty)
        #expect(abs(controller.orbit.yaw - orbit.yaw) < 1e-9 && abs(controller.orbit.pitch - orbit.pitch) < 1e-9)
        #expect(controller.state == .idle)
        return controller
    }

    // MARK: Independent expectation

    /// The actions a one-finger script along `points` at `times` must send, computed from the picker and the rules
    /// (no double taps: scripts are spaced 1 s apart). Also the dragged star expected at touch-down.
    static func expected(_ points: [Vec2], _ times: [Double], snapshot: Snapshot, view: Vec2,
                         orbit: Orbit) -> (actions: [Action], dragged: Int?) {
        let size: SIMD2<Double> = SIMD2(view.x, view.y)
        let down: Vec2 = points[0]
        let last: Vec2 = points[points.count - 1]
        var travel: Double = 0
        for p in points { travel = max(travel, (p - down).length) }
        let pick: ChronoConstellatorPick = Picker.pick(SIMD2(down.x, down.y), size: size, snapshot: snapshot,
                                                       orbit: orbit)
        let editable: Bool = snapshot.stage == .playing && snapshot.tick == 0
        if case .star(let s) = pick {
            if travel >= 16 {
                guard editable, let index = Picker.loopIndex(star: s, at: SIMD2(last.x, last.y), size: size,
                                                             snapshot: snapshot, orbit: orbit),
                      index != snapshot.phases[s] else { return ([], s) }
                return ([.phase(s, index)], s)
            }
            if travel >= 10 { return ([], s) }
            if times[times.count - 1] - times[0] >= 0.5 && editable {
                var has: Bool = false
                for hold in snapshot.holds where hold.star == s && hold.start == 1 { has = true }
                return (has ? [.release(s, 1)] : [.hold(s, 1, 10)], s)
            }
            return ([.select(s)], s)
        }
        var timeline: Bool = false
        if case .timeline = pick { timeline = true }
        let scrubbable: Bool = snapshot.stage == .playing || snapshot.stage == .failed
        guard scrubbable, timeline || barDistance(down, snapshot: snapshot, view: view, orbit: orbit) <= 22 else {
            return ([], nil)
        }
        var target: Int?
        for p in points {
            if let t = Picker.tick(at: SIMD2(p.x, p.y), size: size, snapshot: snapshot, orbit: orbit) { target = t }
        }
        guard let t = target else { return ([], nil) }
        if t > snapshot.tick { return (snapshot.stage == .failed ? [] : [.step(t - snapshot.tick)], nil) }
        if t < snapshot.tick { return (t > 0 ? [.rewind, .step(t)] : [.rewind], nil) }
        return ([], nil)
    }

    /// A random scripted touch of kind 0 … 4 (star drag, star press, scrub, near the tick bar, anywhere).
    static func script(_ kind: Int, snapshot: Snapshot, view: Vec2, orbit: Orbit, start: Double,
                       random: inout SeededRandom) -> (points: [Vec2], times: [Double]) {
        var from: Vec2 = Vec2(unit(&random) * view.x, unit(&random) * view.y)
        var to: Vec2 = Vec2(unit(&random) * view.x, unit(&random) * view.y)
        var duration: Double = 0.05 + unit(&random) * 0.3
        let star: Int = below(max(snapshot.stars.count, 1), &random)
        let starPoint: Vec2? = snapshot.stars.isEmpty ? nil
            : screen(Geometry.starCentre(star, snapshot), snapshot: snapshot, view: view, orbit: orbit)
        switch kind {
        case 0:
            if let p = starPoint {
                from = p
                let loop: [Int] = snapshot.stars[star].loop
                let cell: Int = loop[below(loop.count, &random)]
                if let q = screen(Geometry.cellCentre(cell, snapshot), snapshot: snapshot, view: view, orbit: orbit) {
                    to = q + Vec2(unit(&random) * 16 - 8, unit(&random) * 16 - 8)
                }
            }
        case 1:
            if let p = starPoint {
                from = p
                to = p + Vec2(unit(&random) * 12 - 6, unit(&random) * 12 - 6)
                duration = 0.1 + unit(&random) * 0.9
            }
        case 2:
            let depth: Double = unit(&random) * 0.25
            if let p = bandPoint(unit(&random), depth: depth, snapshot: snapshot, view: view, orbit: orbit),
               let q = bandPoint(unit(&random) * 1.2 - 0.1, depth: depth, snapshot: snapshot, view: view,
                                 orbit: orbit) {
                from = p
                to = q
            }
        case 3:
            if let p = bandPoint(unit(&random), depth: Geometry.tickBarInset, snapshot: snapshot, view: view,
                                 orbit: orbit) {
                from = p + Vec2(0, unit(&random) * 60 - 30)
                to = from + Vec2(unit(&random) * 200 - 100, 0)
            }
        default:
            break
        }
        var points: [Vec2] = []
        var times: [Double] = []
        let moves: Int = 4
        var index: Int = 0
        while index <= moves {
            let f: Double = Double(index) / Double(moves)
            points.append(from + (to - from) * f)
            times.append(start + duration * f)
            index += 1
        }
        // The finger rests where it lifts: the last move is at the release point, so the candidate seen there is the
        // release's.
        points.insert(to, at: points.count - 1)
        times.insert(start + duration, at: times.count - 1)
        return (points, times)
    }

    // MARK: Tests

    @Test func seededScriptsMatchTheIndependentExpectation() throws {
        var all: [Snapshot] = []
        for number in Self.levels { all += try Self.snapshots(number) }
        var random: SeededRandom = SeededRandom(seed: Self.seed)
        var counts: [String: Int] = [:]
        var mismatches: Int = 0
        var script: Int = 0
        while script < 500 {
            let snapshot: Snapshot = all[Self.below(all.count, &random)]
            let view: Vec2 = Self.views[Self.below(Self.views.count, &random)]
            let orbit: Orbit = Self.orbits[Self.below(Self.orbits.count, &random)]
            var controller: Controller = Self.controller(at: orbit, view: view, snapshot: snapshot)
            let kind: Int = script % 5
            let touch: (points: [Vec2], times: [Double]) =
                Self.script(kind, snapshot: snapshot, view: view, orbit: orbit, start: 10, random: &random)
            let want: (actions: [Action], dragged: Int?) =
                Self.expected(touch.points, touch.times, snapshot: snapshot, view: view, orbit: orbit)
            let got: (actions: [Action], dragged: Int?, candidate: Int?) =
                Self.play(&controller, touch.points, touch.times, view: view, snapshot: snapshot)
            if got.actions != want.actions || got.dragged != want.dragged {
                mismatches += 1
                if mismatches <= 5 {
                    let message: String = "script \(script) kind \(kind): \(got.actions) "
                        + "\(String(describing: got.dragged)) expected \(want.actions) "
                        + "\(String(describing: want.dragged))"
                    Issue.record(Comment(rawValue: message))
                }
            }
            #expect(got.actions.count <= 2)
            #expect(controller.state == .idle && controller.draggedStar == nil && controller.candidateCell == nil
                    && controller.scrubTick == nil)
            if case .phase(let s, let index)? = got.actions.first {
                #expect(got.candidate == snapshot.stars[s].loop[index])
            }
            if let s = want.dragged, snapshot.stage == .playing, snapshot.tick == 0 {
                var travel: Double = 0
                for p in touch.points { travel = max(travel, (p - touch.points[0]).length) }
                let last: Vec2 = touch.points[touch.points.count - 1]
                var cell: Int?
                if travel >= 10, let index = Picker.loopIndex(star: s, at: SIMD2(last.x, last.y),
                                                              size: SIMD2(view.x, view.y), snapshot: snapshot,
                                                              orbit: orbit) {
                    cell = snapshot.stars[s].loop[index]
                }
                #expect(got.candidate == cell)
            }
            if snapshot.stage != .playing || snapshot.tick != 0 { #expect(got.candidate == nil) }
            for a in got.actions {
                let key: String
                switch a {
                case .phase: key = "phase"
                case .step: key = "step"
                case .rewind: key = "rewind"
                case .hold: key = "hold"
                case .release: key = "release"
                case .select: key = "select"
                case .resetView: key = "resetView"
                }
                counts[key, default: 0] += 1
            }
            script += 1
        }
        #expect(mismatches == 0)
        for key in ["phase", "step", "rewind", "hold", "release", "select"] {
            #expect((counts[key] ?? 0) > 0, "no \(key) in 500 scripts: \(counts)")
        }
        #expect(counts["resetView"] == nil)
    }

    @Test func draggedStarAndCandidateFollowAStarDrag() throws {
        let snapshot: Snapshot = try Core.opening(number: 1).snapshot(time: 0)
        let view: Vec2 = Self.views[0]
        var controller: Controller = Controller()
        let star: Int = 0
        let p: Vec2 = try #require(Self.screen(Geometry.starCentre(star, snapshot), snapshot: snapshot, view: view,
                                               orbit: .authored))
        let loop: [Int] = snapshot.stars[star].loop
        let index: Int = (snapshot.phases[star] + 1) % loop.count
        let q: Vec2 = try #require(Self.screen(Geometry.cellCentre(loop[index], snapshot), snapshot: snapshot,
                                               view: view, orbit: .authored))
        #expect(controller.handle(Self.event(1, .began, p, 0), viewSize: view, snapshot: snapshot).isEmpty)
        #expect(controller.state == .starDrag)
        #expect(controller.draggedStar == star)
        #expect(controller.candidateCell == nil)
        #expect(controller.handle(Self.event(1, .moved, q, 0.1), viewSize: view, snapshot: snapshot).isEmpty)
        let want: Int? = Picker.loopIndex(star: star, at: SIMD2(q.x, q.y), size: SIMD2(view.x, view.y),
                                          snapshot: snapshot, orbit: .authored).map { (i: Int) -> Int in loop[i] }
        #expect(controller.candidateCell == want)
        #expect(controller.draggedStar == star)
        let actions: [Action] = controller.handle(Self.event(1, .ended, q, 0.2), viewSize: view, snapshot: snapshot)
        #expect((p - q).length < 16 || actions.count == 1)
        #expect(controller.draggedStar == nil && controller.candidateCell == nil && controller.state == .idle)
        // A cancelled star gesture clears the dragged star too.
        _ = controller.handle(Self.event(2, .began, p, 1), viewSize: view, snapshot: snapshot)
        #expect(controller.draggedStar == star)
        #expect(controller.handle(Self.event(2, .cancelled, q, 1.1), viewSize: view, snapshot: snapshot).isEmpty)
        #expect(controller.draggedStar == nil)
        _ = controller.handle(Self.event(3, .began, p, 2), viewSize: view, snapshot: snapshot)
        controller.cancel()
        #expect(controller.draggedStar == nil && controller.state == .idle)
    }

    @Test func secondFingersAndCancelsSendNothing() throws {
        let snapshot: Snapshot = try Core.opening(number: 41).snapshot(time: 0)
        let view: Vec2 = Self.views[1]
        let star: Vec2 = try #require(Self.screen(Geometry.starCentre(0, snapshot), snapshot: snapshot, view: view,
                                                  orbit: .authored))
        let band: Vec2 = try #require(Self.bandPoint(0.5, depth: 0.1, snapshot: snapshot, view: view,
                                                     orbit: .authored))
        let starts: [Vec2] = [star, band]
        for start in starts {
            // A second finger cancels and orbits; nothing is sent when every finger lifts.
            var controller: Controller = Controller()
            var actions: [Action] = controller.handle(Self.event(1, .began, start, 0), viewSize: view,
                                                      snapshot: snapshot)
            actions += controller.handle(Self.event(1, .moved, start + Vec2(60, 0), 0.1), viewSize: view,
                                         snapshot: snapshot)
            actions += controller.handle(Self.event(2, .began, Vec2(10, 10), 0.2), viewSize: view,
                                         snapshot: snapshot)
            #expect(controller.state == .orbiting)
            #expect(controller.draggedStar == nil && controller.candidateCell == nil && controller.scrubTick == nil)
            actions += controller.handle(Self.event(2, .ended, Vec2(10, 10), 0.3), viewSize: view,
                                         snapshot: snapshot)
            #expect(controller.state == .cancelled)
            actions += controller.handle(Self.event(1, .moved, start, 0.4), viewSize: view, snapshot: snapshot)
            actions += controller.handle(Self.event(1, .ended, start + Vec2(60, 0), 1.0), viewSize: view,
                                         snapshot: snapshot)
            #expect(actions.isEmpty)
            #expect(controller.state == .idle)
            // A `.cancelled` phase sends nothing.
            actions = controller.handle(Self.event(3, .began, start, 2), viewSize: view, snapshot: snapshot)
            actions += controller.handle(Self.event(3, .moved, start + Vec2(80, 0), 2.1), viewSize: view,
                                         snapshot: snapshot)
            actions += controller.handle(Self.event(3, .cancelled, start + Vec2(80, 0), 2.9), viewSize: view,
                                         snapshot: snapshot)
            #expect(actions.isEmpty)
            #expect(controller.state == .idle && controller.scrubTick == nil)
            // `cancel()` mid-gesture: the release afterwards is unknown and sends nothing.
            actions = controller.handle(Self.event(4, .began, start, 3), viewSize: view, snapshot: snapshot)
            controller.cancel()
            actions += controller.handle(Self.event(4, .ended, start + Vec2(80, 0), 3.9), viewSize: view,
                                         snapshot: snapshot)
            #expect(actions.isEmpty)
        }
    }

    @Test func editsAfterTickZeroOrOutsidePlaySendNoEdit() throws {
        var snapshots: [Snapshot] = []
        let all: [Snapshot] = try Self.snapshots(81)
        for s in all where s.tick > 0 || s.stage != .playing { snapshots.append(s) }
        #expect(snapshots.count >= 2)
        let view: Vec2 = Self.views[2]
        for snapshot in snapshots {
            var star: Int = 0
            while star < snapshot.stars.count {
                guard let p = Self.screen(Geometry.starCentre(star, snapshot), snapshot: snapshot, view: view,
                                          orbit: .authored),
                      Picker.pick(SIMD2(p.x, p.y), size: SIMD2(view.x, view.y), snapshot: snapshot,
                                  orbit: .authored) == .star(star) else {
                    star += 1
                    continue
                }
                var controller: Controller = Controller()
                let loop: [Int] = snapshot.stars[star].loop
                let cell: Int = loop[(snapshot.phases[star] + 1) % loop.count]
                let q: Vec2 = Self.screen(Geometry.cellCentre(cell, snapshot), snapshot: snapshot, view: view,
                                          orbit: .authored) ?? p + Vec2(100, 0)
                let far: Vec2 = (q - p).length >= 16 ? q : p + Vec2(100, 0)
                let drag: [Action] = Self.play(&controller, [p, far, far], [0, 0.1, 0.2], view: view,
                                               snapshot: snapshot).actions
                #expect(drag.isEmpty)
                let press: [Action] = Self.play(&controller, [p, p, p], [1, 1.5, 2], view: view,
                                                snapshot: snapshot).actions
                #expect(press == [.select(star)])
                star += 1
            }
        }
    }

    @Test func doubleTapOnEmptySpaceResetsTheViewInEveryStage() throws {
        let all: [Snapshot] = try Self.snapshots(1)
        let view: Vec2 = Self.views[0]
        let corner: Vec2 = Vec2(4, 4)
        var stages: Set<String> = []
        for snapshot in all {
            let turned: Orbit = Orbit(yaw: 0.3, pitch: 0.9)
            var controller: Controller = Self.controller(at: turned, view: view, snapshot: snapshot)
            let pick: ChronoConstellatorPick = Picker.pick(SIMD2(corner.x, corner.y), size: SIMD2(view.x, view.y),
                                                           snapshot: snapshot, orbit: turned)
            #expect(pick == .empty)
            var first: [Action] = Self.play(&controller, [corner, corner], [1, 1.05], view: view,
                                            snapshot: snapshot).actions
            var second: [Action] = Self.play(&controller, [corner, corner], [1.2, 1.4], view: view,
                                             snapshot: snapshot).actions
            #expect(first.isEmpty)
            #expect(second == [.resetView])
            #expect(controller.orbit == .authored)
            stages.insert(snapshot.stage.rawValue)
            // Too slow: 0.4 s apart.
            controller = Self.controller(at: turned, view: view, snapshot: snapshot)
            first = Self.play(&controller, [corner, corner], [1, 1.05], view: view, snapshot: snapshot).actions
            second = Self.play(&controller, [corner, corner], [1.4, 1.45], view: view, snapshot: snapshot).actions
            #expect(first.isEmpty && second.isEmpty)
            #expect(abs(controller.orbit.yaw - 0.3) < 1e-9)
            // A star tap between two empty taps breaks the pair.
            if let p = Self.screen(Geometry.starCentre(0, snapshot), snapshot: snapshot, view: view, orbit: turned),
               Picker.pick(SIMD2(p.x, p.y), size: SIMD2(view.x, view.y), snapshot: snapshot,
                           orbit: turned) == .star(0) {
                controller = Self.controller(at: turned, view: view, snapshot: snapshot)
                first = Self.play(&controller, [corner, corner], [1, 1.02], view: view, snapshot: snapshot).actions
                let tap: [Action] = Self.play(&controller, [p, p], [1.05, 1.08], view: view,
                                              snapshot: snapshot).actions
                second = Self.play(&controller, [corner, corner], [1.1, 1.12], view: view,
                                   snapshot: snapshot).actions
                #expect(first.isEmpty && tap == [.select(0)] && second.isEmpty)
            }
        }
        #expect(stages.contains("playing") && stages.contains("won"))
    }

    @Test func orbitFollowsClampsAndRebases() throws {
        let snapshot: Snapshot = try Core.opening(number: 1).snapshot(time: 0)
        let view: Vec2 = Self.views[1]
        var controller: Controller = Controller()
        // A quarter width right turns 22.5° yaw; a tenth of the height up raises the pitch 6°.
        var actions: [Action] = Self.twoFingers(&controller, by: Vec2(view.x * 0.25, -view.y * 0.1), view: view,
                                                snapshot: snapshot, time: 0)
        let degree: Double = Double.pi / 180
        #expect(abs(controller.orbit.yaw - 22.5 * degree) < 1e-9)
        #expect(abs(controller.orbit.pitch - 61 * degree) < 1e-9)
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
        let a: Vec2 = Vec2(100, 400)
        let b: Vec2 = Vec2(300, 400)
        _ = controller.handle(Self.event(1, .began, a, 3), viewSize: view, snapshot: snapshot)
        _ = controller.handle(Self.event(2, .began, b, 3.1), viewSize: view, snapshot: snapshot)
        _ = controller.handle(Self.event(3, .began, Vec2(900, 100), 3.2), viewSize: view, snapshot: snapshot)
        #expect(controller.orbit == .authored)
        #expect(controller.state == .orbiting)
        _ = controller.handle(Self.event(3, .moved, Vec2(930, 100), 3.3), viewSize: view, snapshot: snapshot)
        #expect(abs(controller.orbit.yaw - 10.0 / view.x * Double.pi / 2) < 1e-9)
        #expect(controller.camera(viewSize: view, snapshot: snapshot)
                == Geometry.camera(snapshot, aspect: view.x / view.y, orbit: controller.orbit))
        #expect(controller.camera(viewSize: Vec2(0, 100), snapshot: snapshot) == nil)
    }

    @Test func everyScrubEndsInThePlainReplayDigest() throws {
        var random: SeededRandom = SeededRandom(seed: Self.seed + 1)
        var checked: Int = 0
        var rewinds: Int = 0
        var scrub: Int = 0
        while scrub < 60 {
            let number: Int = Self.levels[scrub % Self.levels.count]
            let view: Vec2 = Self.views[Self.below(Self.views.count, &random)]
            var core: Core = try Core.opening(number: number)
            var replay: Core = core
            let starCount: Int = core.play.level.stars.count
            let star: Int = Self.below(starCount, &random)
            let length: Int = core.play.level.stars[star].length
            let phase: ExperienceAction = Self.action("star.phase", [Double(star), Double(Self.below(length, &random))])
            _ = core.apply(phase)
            _ = replay.apply(phase)
            let limit: Int = core.play.level.tickLimit
            let first: Int = Self.below(limit + 1, &random)
            if first > 0 { _ = core.apply(Self.action("time.step", [Double(first)])) }
            let snapshot: Snapshot = core.snapshot(time: 0)
            var controller: Controller = Controller()
            let from: Vec2 = try #require(Self.bandPoint(Self.unit(&random), depth: 0.12, snapshot: snapshot,
                                                         view: view, orbit: .authored))
            let to: Vec2 = try #require(Self.bandPoint(Self.unit(&random), depth: 0.12, snapshot: snapshot,
                                                       view: view, orbit: .authored))
            let touch: (actions: [Action], dragged: Int?, candidate: Int?) =
                Self.play(&controller, [from, (from + to) * 0.5, to], [0, 0.1, 0.2], view: view, snapshot: snapshot)
            #expect(touch.actions.count <= 2)
            if snapshot.stage == .won {
                #expect(touch.actions.isEmpty)
                scrub += 1
                continue
            }
            let target: Int = try #require(Picker.tick(at: SIMD2(to.x, to.y), size: SIMD2(view.x, view.y),
                                                       snapshot: snapshot, orbit: .authored))
            for a in touch.actions {
                if a == .rewind { rewinds += 1 }
                Self.apply(a, to: &core)
            }
            if target > 0 { _ = replay.apply(Self.action("time.step", [Double(target)])) }
            #expect(try Self.digest(core) == Self.digest(replay),
                    "level \(number) from tick \(snapshot.tick) to \(target): \(touch.actions)")
            checked += 1
            scrub += 1
        }
        #expect(checked >= 40)
        #expect(rewinds > 0)
    }

    /// Converge T-R02G0604-013: on a failed play a forward scrub sends nothing (no stage refusal), and a backward scrub
    /// still rewinds and steps.
    @Test func aForwardScrubOnAFailedPlaySendsNothing() throws {
        let view: Vec2 = Vec2(1180, 820)
        var checked: Int = 0
        for number in [1, 41, 81] {
            var core: Core = try Core.opening(number: number)
            _ = core.apply(Self.action("time.step", [Double(core.play.level.tickLimit)]))
            guard core.play.stage == .failed else { continue }
            let snapshot: Snapshot = core.snapshot(time: 0)
            let end: Vec2 = try #require(Self.bandPoint(1, depth: 0.12, snapshot: snapshot, view: view,
                                                        orbit: .authored))
            let size: SIMD2<Double> = SIMD2(view.x, view.y)
            let far: Int = try #require(Picker.tick(at: SIMD2(end.x, end.y), size: size, snapshot: snapshot,
                                                    orbit: .authored))
            if far > snapshot.tick {
                var forward: Controller = Controller()
                let ahead: (actions: [Action], dragged: Int?, candidate: Int?) =
                    Self.play(&forward, [end, end], [0, 0.1], view: view, snapshot: snapshot)
                #expect(ahead.actions.isEmpty, "level \(number): \(ahead.actions)")
            }
            let start: Vec2 = try #require(Self.bandPoint(0, depth: 0.12, snapshot: snapshot, view: view,
                                                          orbit: .authored))
            var backward: Controller = Controller()
            let back: (actions: [Action], dragged: Int?, candidate: Int?) =
                Self.play(&backward, [start, start], [0, 0.1], view: view, snapshot: snapshot)
            #expect(back.actions.first == .rewind, "level \(number): \(back.actions)")
            checked += 1
        }
        #expect(checked >= 1)
    }
}
