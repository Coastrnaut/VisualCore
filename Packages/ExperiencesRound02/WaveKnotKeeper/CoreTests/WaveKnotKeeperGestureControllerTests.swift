// WaveKnotKeeperGestureControllerTests — feature 324 (R02-G03-04) T-R02G0304-003 (FR-R02G0304-003, 005, 007;
// SC-R02G0304-002; clarifications Q2, Q3, Q5). Scripted touches at fixed view sizes (390 × 844, 1,024 × 768,
// 844 × 390) on seeded fixture plays: 300 seeded drags from seeded handles (at the authored orbit and after a seeded
// orbit) send `point.select` on touch-down and, on release, exactly the `point.move` that
// `WaveKnotKeeperHandles.candidate` names for the whole drag computed here (or nothing), with the same preview before
// release; a short drag selects only; a second finger cancels the drag and orbits without a move (a first finger that
// lands on a handle still selects it); a cancelled touch and `cancel()` send nothing; one finger
// on empty space does nothing and never orbits; a double tap on empty space resets the orbit (taps too far apart in
// time or place do not); won, failed and paused plays select but never move; the orbit follows the two-finger midpoint
// (90° yaw per width, 60° pitch per height, upwards raises the pitch) and clamps to ±40° and 5° … 60°; the same
// script gives the same results. Plain loops and explicit types (CI type-check rule); seed 2_324.
import Foundation
import Testing
@testable import WaveKnotKeeperCore
import VisualCoreExperience
import VisualCoreMath
import VisualCoreScenes

@Suite struct WaveKnotKeeperGestureControllerTests {
    typealias Controller = WaveKnotKeeperGestureController
    typealias Snapshot = WaveKnotKeeperSceneSnapshot

    /// The seed of every random choice here.
    static let seed: UInt64 = 2_324
    /// The view sizes every script runs at.
    static let views: [Vec2] = [Vec2(390, 844), Vec2(1_024, 768), Vec2(844, 390)]
    /// The time between scripted events in seconds.
    static let frame: Double = 1.0 / 60

    /// Playing snapshots of the first eight fixture levels.
    static let playing: [Snapshot] = {
        var result: [Snapshot] = []
        var index: Int = 0
        while index < 8 {
            let fixture: WaveKnotKeeperFixture = WaveKnotKeeperFixtures.fixture(index, gates: index % 2 == 1)
            if let play = try? WaveKnotKeeperFixtures.playing(fixture.level) {
                result.append(Snapshot(play: play, levelNumber: index + 1, time: 0))
            }
            index += 1
        }
        return result
    }()

    // MARK: Helpers

    /// A fixture play won through its known solution.
    static func wonSnapshot() throws -> Snapshot {
        let fixture: WaveKnotKeeperFixture = WaveKnotKeeperFixtures.fixture(0)
        var play: WaveKnotKeeperPlay = try WaveKnotKeeperFixtures.playing(fixture.level)
        for move in fixture.solution where play.stage == .playing {
            try play.apply(move, expecting: play.fingerprint)
        }
        #expect(play.stage == .won)
        return Snapshot(play: play, levelNumber: 1, time: 0)
    }

    /// A fixture play failed by spending its allowance on legal moves that do not win.
    static func failedSnapshot() throws -> Snapshot? {
        var index: Int = 0
        while index < 20 {
            let fixture: WaveKnotKeeperFixture = WaveKnotKeeperFixtures.fixture(index)
            var play: WaveKnotKeeperPlay = try WaveKnotKeeperFixtures.playing(fixture.level)
            var progressed: Bool = true
            while play.stage == .playing && progressed {
                progressed = false
                let rules: WaveKnotKeeperRules = WaveKnotKeeperRules(level: fixture.level)
                for move in rules.moves(in: play.points) {
                    var trial: WaveKnotKeeperPlay = play
                    guard (try? trial.apply(move, expecting: trial.fingerprint)) != nil,
                          trial.stage != .won else { continue }
                    play = trial
                    progressed = true
                    break
                }
            }
            if play.stage == .failed { return Snapshot(play: play, levelNumber: 1, time: 0) }
            index += 1
        }
        return nil
    }

    /// A paused fixture play.
    static func pausedSnapshot() throws -> Snapshot {
        var play: WaveKnotKeeperPlay = try WaveKnotKeeperFixtures.playing(WaveKnotKeeperFixtures.fixture(1).level)
        try play.handle(.pause)
        return Snapshot(play: play, levelNumber: 1, time: 0)
    }

    /// A uniform double in `low … high` from `random`.
    static func uniform(_ random: inout WaveKnotKeeperRandom, _ low: Double, _ high: Double) -> Double {
        low + (high - low) * Double(random.int(0...1_000_000)) / 1_000_000
    }

    /// The drawn camera for `snapshot` in `view` at `orbit`, computed here.
    static func camera(_ snapshot: Snapshot, view: Vec2, orbit: WaveKnotKeeperOrbit) -> WaveKnotKeeperCamera {
        WaveKnotKeeperSceneGeometry.camera(for: snapshot, aspect: view.x / view.y, orbit: orbit)
    }

    /// The screen centre of control point `index` in `view` at `orbit`, or nil when it does not project inside.
    static func handleCentre(_ index: Int, snapshot: Snapshot, view: Vec2, orbit: WaveKnotKeeperOrbit) -> Vec2? {
        let cam: WaveKnotKeeperCamera = camera(snapshot, view: view, orbit: orbit)
        let world: SIMD3<Double> = WaveKnotKeeperSceneGeometry.world(snapshot.points[index])
        guard let p = WaveKnotKeeperHandles.screen(world, camera: cam, size: SIMD2(view.x, view.y)) else { return nil }
        return Vec2(p.x, p.y)
    }

    /// The point `WaveKnotKeeperHandles.pick` gives at `location`.
    static func picked(_ location: Vec2, snapshot: Snapshot, view: Vec2, orbit: WaveKnotKeeperOrbit) -> Int? {
        WaveKnotKeeperHandles.pick(SIMD2(location.x, location.y), snapshot: snapshot,
                                   camera: camera(snapshot, view: view, orbit: orbit), size: SIMD2(view.x, view.y))
    }

    /// The direction `WaveKnotKeeperHandles.candidate` names for a drag of `drag` from `point`.
    static func expected(point: Int, drag: Vec2, snapshot: Snapshot, view: Vec2,
                         orbit: WaveKnotKeeperOrbit) -> WaveKnotKeeperDirection? {
        WaveKnotKeeperHandles.candidate(point: point, drag: SIMD2(drag.x, drag.y), snapshot: snapshot,
                                        camera: camera(snapshot, view: view, orbit: orbit),
                                        size: SIMD2(view.x, view.y))
    }

    /// A location in `view` where no handle is picked (scanning a coarse grid from the top left), or nil.
    static func emptySpot(_ snapshot: Snapshot, view: Vec2, orbit: WaveKnotKeeperOrbit = .authored) -> Vec2? {
        var y: Double = 4
        while y < view.y {
            var x: Double = 4
            while x < view.x {
                let p: Vec2 = Vec2(x, y)
                if picked(p, snapshot: snapshot, view: view, orbit: orbit) == nil
                    && picked(p + Vec2(10, 5), snapshot: snapshot, view: view, orbit: orbit) == nil
                    && picked(p + Vec2(30, 0), snapshot: snapshot, view: view, orbit: orbit) == nil {
                    return p
                }
                x += 40
            }
            y += 40
        }
        return nil
    }

    /// A one-finger stroke from `start` by `drag` in `steps` moves, then ended (or cancelled).
    static func stroke(from start: Vec2, drag: Vec2, steps: Int, id: Int, time: Double,
                       cancelled: Bool = false) -> [PointerEvent] {
        var events: [PointerEvent] = [PointerEvent(id: id, phase: .began, location: start, timestamp: time)]
        var t: Double = time
        var i: Int = 1
        while i <= steps {
            t += frame
            events.append(PointerEvent(id: id, phase: .moved, location: start + drag * (Double(i) / Double(steps)),
                                       timestamp: t))
            i += 1
        }
        t += frame
        events.append(PointerEvent(id: id, phase: cancelled ? .cancelled : .ended, location: start + drag,
                                   timestamp: t))
        return events
    }

    /// A two-finger gesture around the centre of `view` whose midpoint moves by `delta` in `steps` moves.
    static func orbitGesture(view: Vec2, delta: Vec2, steps: Int, time: Double, ids: (Int, Int) = (10, 11))
        -> [PointerEvent] {
        let a: Vec2 = Vec2(view.x * 0.4, view.y * 0.5)
        let b: Vec2 = Vec2(view.x * 0.6, view.y * 0.5)
        var events: [PointerEvent] = [PointerEvent(id: ids.0, phase: .began, location: a, timestamp: time),
                                      PointerEvent(id: ids.1, phase: .began, location: b, timestamp: time)]
        var t: Double = time
        var i: Int = 1
        while i <= steps {
            t += frame
            let d: Vec2 = delta * (Double(i) / Double(steps))
            events.append(PointerEvent(id: ids.0, phase: .moved, location: a + d, timestamp: t))
            events.append(PointerEvent(id: ids.1, phase: .moved, location: b + d, timestamp: t))
            i += 1
        }
        t += frame
        events.append(PointerEvent(id: ids.0, phase: .ended, location: a + delta, timestamp: t))
        events.append(PointerEvent(id: ids.1, phase: .ended, location: b + delta, timestamp: t))
        return events
    }

    /// Feeds `events` and returns every action returned.
    static func run(_ controller: inout Controller, _ events: [PointerEvent], view: Vec2,
                    snapshot: Snapshot) -> [ScriptedAction] {
        var actions: [ScriptedAction] = []
        for event in events {
            if let action = controller.handle(event, viewSize: view, snapshot: snapshot) { actions.append(action) }
        }
        return actions
    }

    /// The number of `point.move` actions in `actions`.
    static func moves(_ actions: [ScriptedAction]) -> Int {
        var n: Int = 0
        for a in actions where a.control == "point.move" { n += 1 }
        return n
    }

    /// One seeded drag case: a handle's centre (at an optional seeded orbit) and a seeded drag vector.
    struct DragCase {
        let view: Vec2
        let snapshot: Snapshot
        let orbitDelta: Vec2?
        let orbit: WaveKnotKeeperOrbit
        let start: Vec2
        let point: Int
        let drag: Vec2
        let steps: Int
    }

    /// Draws one drag case; nil when the chosen handle does not project inside the view.
    static func dragCase(_ random: inout WaveKnotKeeperRandom) -> DragCase? {
        let view: Vec2 = views[random.int(0...(views.count - 1))]
        let snapshot: Snapshot = playing[random.int(0...(playing.count - 1))]
        var orbitDelta: Vec2? = nil
        var orbit: WaveKnotKeeperOrbit = .authored
        if random.int(0...1) == 1 {
            let d: Vec2 = Vec2(uniform(&random, -0.3, 0.3) * view.x, uniform(&random, -0.3, 0.3) * view.y)
            orbitDelta = d
            // The orbit the gesture reaches, read from a controller (summed per step, so not recomputed here).
            var probe: Controller = Controller()
            _ = run(&probe, orbitGesture(view: view, delta: d, steps: 4, time: 0), view: view, snapshot: snapshot)
            orbit = probe.orbit
            let yaw: Double = d.x / view.x * 90
            let pitch: Double = 20 - d.y / view.y * 60
            #expect(abs(orbit.yaw - min(max(yaw, -40), 40)) < 1e-9)
            #expect(abs(orbit.pitch - min(max(pitch, 5), 60)) < 1e-9)
        }
        let index: Int = random.int(0...(snapshot.points.count - 1))
        guard let start = handleCentre(index, snapshot: snapshot, view: view, orbit: orbit),
              start.x >= 0, start.x <= view.x, start.y >= 0, start.y <= view.y,
              let point = picked(start, snapshot: snapshot, view: view, orbit: orbit) else { return nil }
        let angle: Double = uniform(&random, 0, 2 * Double.pi)
        let length: Double = uniform(&random, 0, 140)
        return DragCase(view: view, snapshot: snapshot, orbitDelta: orbitDelta, orbit: orbit, start: start,
                        point: point, drag: Vec2(cos(angle) * length, sin(angle) * length),
                        steps: random.int(1...8))
    }

    // MARK: Drags

    @Test func seededDragsSendExactlyTheCandidateMove() {
        #expect(Self.playing.count == 8)
        var random: WaveKnotKeeperRandom = WaveKnotKeeperRandom(seed: Self.seed)
        var cases: Int = 0
        var moves: Int = 0
        var taps: Int = 0
        var attempts: Int = 0
        while cases < 300 && attempts < 3_000 {
            attempts += 1
            guard let c = Self.dragCase(&random) else { continue }
            cases += 1
            var controller: Controller = Controller()
            if let d = c.orbitDelta {
                // The first finger may land on a handle and select it; the second cancels, so nothing moves.
                let events: [PointerEvent] = Self.orbitGesture(view: c.view, delta: d, steps: 4, time: 0)
                let orbitActions: [ScriptedAction] = Self.run(&controller, events, view: c.view, snapshot: c.snapshot)
                #expect(Self.moves(orbitActions) == 0)
                #expect(controller.orbit == c.orbit)
            }
            let events: [PointerEvent] = Self.stroke(from: c.start, drag: c.drag, steps: c.steps, id: 1, time: 1)
            let direction: WaveKnotKeeperDirection? = Self.expected(point: c.point, drag: c.drag, snapshot: c.snapshot,
                                                               view: c.view, orbit: c.orbit)
            var actions: [ScriptedAction] = []
            var index: Int = 0
            while index < events.count {
                if index == events.count - 1 {
                    // Before release the preview names the move the release will send.
                    let preview: ScriptedAction? = direction.map { Controller.move(point: c.point, direction: $0) }
                    #expect(controller.preview == preview)
                    #expect(controller.phase == .dragging(point: c.point, start: c.start))
                }
                if let a = controller.handle(events[index], viewSize: c.view, snapshot: c.snapshot) {
                    actions.append(a)
                }
                index += 1
            }
            var want: [ScriptedAction] = [ScriptedAction("point.select", [Double(c.point)])]
            if let direction {
                let dIndex: Int = WaveKnotKeeperDirection.allCases.firstIndex(of: direction) ?? -1
                want.append(ScriptedAction("point.move", [Double(c.point), Double(dIndex)]))
                moves += 1
            } else {
                taps += 1
            }
            #expect(actions == want)
            #expect(controller.phase == .idle)
            #expect(controller.preview == nil)
        }
        #expect(cases == 300)
        #expect(moves > 100)
        #expect(taps > 10)
    }

    @Test func shortDragAndTapSelectOnly() throws {
        let snapshot: Snapshot = Self.playing[0]
        let view: Vec2 = Self.views[0]
        var index: Int = 0
        var checked: Int = 0
        while index < snapshot.points.count {
            defer { index += 1 }
            guard let start = Self.handleCentre(index, snapshot: snapshot, view: view, orbit: .authored),
                  let point = Self.picked(start, snapshot: snapshot, view: view, orbit: .authored) else { continue }
            var controller: Controller = Controller()
            let tapEvents: [PointerEvent] = Self.stroke(from: start, drag: Vec2(0, 0), steps: 1, id: 1, time: 0)
            let tap: [ScriptedAction] = Self.run(&controller, tapEvents, view: view, snapshot: snapshot)
            #expect(tap == [Controller.select(point: point)])
            let shortEvents: [PointerEvent] = Self.stroke(from: start, drag: Vec2(3, -4), steps: 3, id: 2, time: 1)
            let short: [ScriptedAction] = Self.run(&controller, shortEvents, view: view, snapshot: snapshot)
            #expect(short == [Controller.select(point: point)])
            checked += 1
        }
        #expect(checked > 3)
    }

    // MARK: Arbitration

    /// The first drag case with a candidate, at the authored orbit.
    static func movingCase() -> DragCase? {
        var random: WaveKnotKeeperRandom = WaveKnotKeeperRandom(seed: seed + 1)
        var attempts: Int = 0
        while attempts < 500 {
            attempts += 1
            guard let c = dragCase(&random), c.orbitDelta == nil,
                  expected(point: c.point, drag: c.drag, snapshot: c.snapshot, view: c.view, orbit: c.orbit) != nil
            else { continue }
            return c
        }
        return nil
    }

    @Test func secondFingerCancelsTheDragAndOrbits() throws {
        let c: DragCase = try #require(Self.movingCase())
        var controller: Controller = Controller()
        var actions: [ScriptedAction] = []
        let down: PointerEvent = PointerEvent(id: 1, phase: .began, location: c.start, timestamp: 0)
        let move: PointerEvent = PointerEvent(id: 1, phase: .moved, location: c.start + c.drag, timestamp: Self.frame)
        for e in [down, move] {
            if let a = controller.handle(e, viewSize: c.view, snapshot: c.snapshot) { actions.append(a) }
        }
        #expect(controller.preview != nil)
        let second: Vec2 = Vec2(c.view.x * 0.5, c.view.y * 0.5)
        let extra: [PointerEvent] = [
            PointerEvent(id: 2, phase: .began, location: second, timestamp: 2 * Self.frame),
            PointerEvent(id: 1, phase: .moved, location: c.start + c.drag + Vec2(40, -60), timestamp: 3 * Self.frame),
            PointerEvent(id: 2, phase: .moved, location: second + Vec2(40, -60), timestamp: 3 * Self.frame),
        ]
        actions += Self.run(&controller, extra, view: c.view, snapshot: c.snapshot)
        #expect(controller.phase == .orbiting)
        #expect(controller.preview == nil)
        #expect(controller.draggedPoint == nil)
        let end: [PointerEvent] = [
            PointerEvent(id: 1, phase: .ended, location: c.start + c.drag + Vec2(40, -60), timestamp: 4 * Self.frame),
            PointerEvent(id: 2, phase: .ended, location: second + Vec2(40, -60), timestamp: 5 * Self.frame),
        ]
        actions += Self.run(&controller, end, view: c.view, snapshot: c.snapshot)
        #expect(actions == [Controller.select(point: c.point)])
        #expect(controller.phase == .idle)
        let yaw: Double = 40 / c.view.x * 90
        let pitch: Double = 20 + 60 / c.view.y * 60
        #expect(abs(controller.orbit.yaw - yaw) < 1e-9)
        #expect(abs(controller.orbit.pitch - pitch) < 1e-9)
    }

    @Test func cancelledTouchAndCancelSendNothing() throws {
        let c: DragCase = try #require(Self.movingCase())
        var controller: Controller = Controller()
        let cancelled: [ScriptedAction] = Self.run(&controller,
                                                   Self.stroke(from: c.start, drag: c.drag, steps: 3, id: 1, time: 0,
                                                               cancelled: true),
                                                   view: c.view, snapshot: c.snapshot)
        #expect(cancelled == [Controller.select(point: c.point)])
        #expect(controller.phase == .idle)
        // cancel() mid-drag: no move on the later release, cancelled until the finger lifts.
        var events: [PointerEvent] = Self.stroke(from: c.start, drag: c.drag, steps: 3, id: 2, time: 1)
        let release: PointerEvent = events.removeLast()
        var actions: [ScriptedAction] = Self.run(&controller, events, view: c.view, snapshot: c.snapshot)
        #expect(controller.preview != nil)
        controller.cancel()
        #expect(controller.phase == .cancelled)
        #expect(controller.preview == nil)
        if let a = controller.handle(release, viewSize: c.view, snapshot: c.snapshot) { actions.append(a) }
        #expect(actions == [Controller.select(point: c.point)])
        #expect(controller.phase == .idle)
    }

    @Test func oneFingerOnEmptySpaceDoesNothing() throws {
        let snapshot: Snapshot = Self.playing[2]
        for view in Self.views {
            let spot: Vec2 = try #require(Self.emptySpot(snapshot, view: view))
            var controller: Controller = Controller()
            let actions: [ScriptedAction] = Self.run(&controller,
                                                     Self.stroke(from: spot, drag: Vec2(120, 90), steps: 6, id: 1,
                                                                 time: 0),
                                                     view: view, snapshot: snapshot)
            #expect(actions.isEmpty)
            #expect(controller.orbit == .authored)
            #expect(controller.phase == .idle)
        }
    }

    @Test func doubleTapOnEmptySpaceResetsTheOrbit() throws {
        let snapshot: Snapshot = Self.playing[3]
        let view: Vec2 = Self.views[1]
        // Taps: (second tap offset, second tap start time, Self.expected reset).
        let offsets: [Vec2] = [Vec2(10, 5), Vec2(10, 5), Vec2(30, 0)]
        let starts: [Double] = [10.2, 10.4, 10.2]
        let resets: [Bool] = [true, false, false]
        var k: Int = 0
        while k < offsets.count {
            var controller: Controller = Controller()
            _ = Self.run(&controller, Self.orbitGesture(view: view, delta: Vec2(0.2 * view.x, -0.1 * view.y),
                                                        steps: 5, time: 0),
                         view: view, snapshot: snapshot)
            let away: WaveKnotKeeperOrbit = controller.orbit
            #expect(abs(away.yaw - 18) < 1e-9)
            #expect(abs(away.pitch - 26) < 1e-9)
            let spot: Vec2 = try #require(Self.emptySpot(snapshot, view: view, orbit: away))
            var actions: [ScriptedAction] = Self.run(&controller,
                                                     Self.stroke(from: spot, drag: Vec2(0, 0), steps: 1, id: 3,
                                                                 time: 10),
                                                     view: view, snapshot: snapshot)
            actions += Self.run(&controller,
                                Self.stroke(from: spot + offsets[k], drag: Vec2(0, 0), steps: 1, id: 4,
                                            time: starts[k]),
                                view: view, snapshot: snapshot)
            #expect(actions.isEmpty)
            #expect((controller.orbit == .authored) == resets[k])
            k += 1
        }
        // resetOrbit() (the panel's "Reset view") also returns to the authored orbit.
        var controller: Controller = Controller()
        _ = Self.run(&controller, Self.orbitGesture(view: view, delta: Vec2(100, 100), steps: 2, time: 0),
                     view: view, snapshot: snapshot)
        #expect(controller.orbit != .authored)
        controller.resetOrbit()
        #expect(controller.orbit == .authored)
    }

    @Test func notPlayingSelectsButNeverMoves() throws {
        var snapshots: [Snapshot] = [try Self.wonSnapshot(), try Self.pausedSnapshot()]
        let failed: Snapshot = try #require(try Self.failedSnapshot())
        snapshots.append(failed)
        #expect(snapshots.map { $0.stage } == [.won, .paused, .failed])
        var random: WaveKnotKeeperRandom = WaveKnotKeeperRandom(seed: Self.seed + 2)
        for snapshot in snapshots {
            var selects: Int = 0
            var trial: Int = 0
            while trial < 40 {
                trial += 1
                let view: Vec2 = Self.views[random.int(0...(Self.views.count - 1))]
                let index: Int = random.int(0...(snapshot.points.count - 1))
                guard let start = Self.handleCentre(index, snapshot: snapshot, view: view, orbit: .authored),
                      let point = Self.picked(start, snapshot: snapshot, view: view, orbit: .authored) else { continue }
                let angle: Double = Self.uniform(&random, 0, 2 * Double.pi)
                let drag: Vec2 = Vec2(cos(angle) * 120, sin(angle) * 120)
                var controller: Controller = Controller()
                var events: [PointerEvent] = Self.stroke(from: start, drag: drag, steps: 4, id: 1, time: 0)
                let release: PointerEvent = events.removeLast()
                var actions: [ScriptedAction] = Self.run(&controller, events, view: view, snapshot: snapshot)
                #expect(controller.preview == nil)
                #expect(controller.candidate == nil)
                if let a = controller.handle(release, viewSize: view, snapshot: snapshot) { actions.append(a) }
                #expect(actions == [Controller.select(point: point)])
                selects += 1
            }
            #expect(selects > 10)
        }
        // A release after play stopped sends nothing, though the drag had a candidate while Self.playing.
        let c: DragCase = try #require(Self.movingCase())
        var controller: Controller = Controller()
        var events: [PointerEvent] = Self.stroke(from: c.start, drag: c.drag, steps: 2, id: 1, time: 0)
        let release: PointerEvent = events.removeLast()
        _ = Self.run(&controller, events, view: c.view, snapshot: c.snapshot)
        #expect(controller.preview != nil)
        let stopped: Snapshot = try Self.pausedSnapshot()
        #expect(controller.handle(release, viewSize: c.view, snapshot: stopped) == nil)
    }

    // MARK: Orbit

    @Test func orbitRatesAndClamping() {
        let snapshot: Snapshot = Self.playing[4]
        for view in Self.views {
            var controller: Controller = Controller()
            let actions: [ScriptedAction] = Self.run(&controller,
                                                     Self.orbitGesture(view: view,
                                                                       delta: Vec2(0.1 * view.x, -0.1 * view.y),
                                                                       steps: 3, time: 0),
                                                     view: view, snapshot: snapshot)
            #expect(Self.moves(actions) == 0)
            #expect(abs(controller.orbit.yaw - 9) < 1e-9)
            #expect(abs(controller.orbit.pitch - 26) < 1e-9)
            _ = Self.run(&controller, Self.orbitGesture(view: view, delta: Vec2(2 * view.x, -2 * view.y), steps: 3,
                                                        time: 1),
                         view: view, snapshot: snapshot)
            #expect(controller.orbit == WaveKnotKeeperOrbit(yaw: 40, pitch: 60))
            _ = Self.run(&controller, Self.orbitGesture(view: view, delta: Vec2(-3 * view.x, 3 * view.y), steps: 3,
                                                        time: 2),
                         view: view, snapshot: snapshot)
            #expect(controller.orbit == WaveKnotKeeperOrbit(yaw: -40, pitch: 5))
            // Dragging down lowers the pitch, dragging left lowers the yaw (from the authored orbit).
            controller.resetOrbit()
            _ = Self.run(&controller, Self.orbitGesture(view: view, delta: Vec2(-0.2 * view.x, 0.1 * view.y),
                                                        steps: 2, time: 3),
                         view: view, snapshot: snapshot)
            #expect(abs(controller.orbit.yaw + 18) < 1e-9)
            #expect(abs(controller.orbit.pitch - 14) < 1e-9)
        }
        // A third finger re-bases the midpoint: the camera does not jump when it lands.
        let view: Vec2 = Self.views[0]
        var controller: Controller = Controller()
        var events: [PointerEvent] = Self.orbitGesture(view: view, delta: Vec2(20, 0), steps: 2, time: 0)
        events.removeLast(2)
        _ = Self.run(&controller, events, view: view, snapshot: snapshot)
        let before: WaveKnotKeeperOrbit = controller.orbit
        _ = controller.handle(PointerEvent(id: 12, phase: .began, location: Vec2(10, 10), timestamp: 1),
                              viewSize: view, snapshot: snapshot)
        #expect(controller.orbit == before)
        #expect(controller.phase == .orbiting)
        // One finger lifting leaves the rest cancelled until every finger is up.
        _ = controller.handle(PointerEvent(id: 12, phase: .ended, location: Vec2(10, 10), timestamp: 2),
                              viewSize: view, snapshot: snapshot)
        #expect(controller.phase == .cancelled)
    }

    // MARK: Determinism

    @Test func sameScriptSameResults() {
        var outputs: [[ScriptedAction]] = []
        var orbits: [WaveKnotKeeperOrbit] = []
        var round: Int = 0
        while round < 2 {
            var random: WaveKnotKeeperRandom = WaveKnotKeeperRandom(seed: Self.seed + 3)
            var controller: Controller = Controller()
            var actions: [ScriptedAction] = []
            var made: Int = 0
            var attempts: Int = 0
            var time: Double = 0
            while made < 60 && attempts < 600 {
                attempts += 1
                guard let c = Self.dragCase(&random) else { continue }
                made += 1
                if let d = c.orbitDelta {
                    actions += Self.run(&controller, Self.orbitGesture(view: c.view, delta: d, steps: 2, time: time),
                                        view: c.view, snapshot: c.snapshot)
                    time += 1
                }
                let cancelled: Bool = random.int(0...4) == 0
                actions += Self.run(&controller, Self.stroke(from: c.start, drag: c.drag, steps: c.steps, id: 1,
                                                             time: time, cancelled: cancelled),
                                    view: c.view, snapshot: c.snapshot)
                time += 1
            }
            outputs.append(actions)
            orbits.append(controller.orbit)
            round += 1
        }
        #expect(outputs[0] == outputs[1])
        #expect(orbits[0] == orbits[1])
        #expect(outputs[0].count > 60)
    }

    @Test func unusableInputSendsNothing() {
        let snapshot: Snapshot = Self.playing[0]
        var controller: Controller = Controller()
        let bad: [Vec2] = [Vec2(0, 0), Vec2(-1, 100), Vec2(Double.nan, 100), Vec2(Double.infinity, 10)]
        for view in bad {
            let actions: [ScriptedAction] = Self.run(&controller,
                                                     Self.stroke(from: Vec2(10, 10), drag: Vec2(50, 0), steps: 2,
                                                                 id: 1, time: 0),
                                                     view: view, snapshot: snapshot)
            #expect(actions.isEmpty)
        }
        // Unknown ids and non-finite locations are ignored.
        #expect(controller.handle(PointerEvent(id: 99, phase: .ended, location: Vec2(1, 1), timestamp: 0),
                                  viewSize: Self.views[0], snapshot: snapshot) == nil)
        #expect(controller.handle(PointerEvent(id: 5, phase: .began, location: Vec2(Double.nan, 1), timestamp: 0),
                                  viewSize: Self.views[0], snapshot: snapshot) == nil)
        #expect(controller.phase == .idle)
    }
}
