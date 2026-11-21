// ColorfallCanyonsGestureControllerTests — feature 344 (R02-G05-04) T-R02G0504-003 (FR-R02G0504-001, 002, 004, 005;
// SC-R02G0504-001, 002). Scripted touches on the first three certified catalog levels at three view sizes (390 × 844,
// 844 × 390, 1,024 × 1,366) and three orbits reached by two-finger drags: 500 seeded (seed 2_344) drags and taps per
// size and orbit send exactly the action computed here from `ColorfallCanyonsPicker.pick` at the touch-down point, the
// level's own `isCarvable(_:heights:)` and the travel rules (≥ 16 points carves a carvable start cell, < 10 points taps
// a spring's valve, 10 … 16 points nothing), with the highlight set at touch-down and cleared at release. Second
// fingers, `.cancelled` phases and every non-playing stage send no carve or valve; a double tap on empty space resets
// the view in a non-playing stage, and only within 0.35 s; the orbit follows 90° yaw per view width and 60° pitch per
// view height (upwards raises the pitch), clamps at its bounds and a third finger re-bases the midpoint; an unusable
// view size sends nothing and highlights nothing. Plain loops and explicit types (CI type-check rule).
import Foundation
import Testing
@testable import ColorfallCanyonsCore
import VisualCoreMath
import VisualCoreScenes

@Suite struct ColorfallCanyonsGestureControllerTests {
    typealias Controller = ColorfallCanyonsGestureController
    typealias Snapshot = ColorfallCanyonsSceneSnapshot
    typealias Action = ColorfallCanyonsGestureAction
    typealias Geometry = ColorfallCanyonsSceneGeometry

    /// The seed of every random choice here.
    static let seed: UInt64 = 2_344
    /// The view sizes every script runs at.
    static let views: [Vec2] = [Vec2(390, 844), Vec2(844, 390), Vec2(1_024, 1_366)]
    /// Two-finger midpoint moves, as fractions of the view, that set the scripted orbits (the first keeps the authored).
    static let orbitMoves: [Vec2] = [Vec2(0, 0), Vec2(0.2, -0.2), Vec2(-0.4, 0.3)]
    /// The time between scripted events in seconds.
    static let frame: Double = 1.0 / 60
    /// Degrees to radians.
    static let degree: Double = Double.pi / 180

    // MARK: Snapshots

    /// A level with its playing snapshot.
    struct Case {
        let level: ColorfallCanyonsLevel
        let snapshot: Snapshot
    }

    /// The first three certified catalog levels begun (tutorial dismissed), playing.
    static func certified() throws -> [Case] {
        var result: [Case] = []
        var number: Int = 0
        while number < 3 {
            let generated: ColorfallCanyonsGenerated =
                try ColorfallCanyonsGenerator.generate(ColorfallCanyonsManifest.entries[number])
            var play: ColorfallCanyonsPlay = ColorfallCanyonsPlay(level: generated.level)
            try play.handle(.begin)
            if play.stage == .tutorial { try play.handle(.dismissTutorial) }
            #expect(play.stage == .playing)
            result.append(Case(level: generated.level, snapshot: Snapshot(play: play, levelNumber: number + 1,
                                                                            time: 0)))
            number += 1
        }
        return result
    }

    /// A begun play of fixture `index`.
    static func begun(_ index: Int, tutorial: Bool = false) throws -> ColorfallCanyonsPlay {
        let fixture: ColorfallCanyonsFixture = ColorfallCanyonsFixtures.fixture(index, tutorial: tutorial)
        var play: ColorfallCanyonsPlay = ColorfallCanyonsPlay(level: fixture.level)
        try play.handle(.begin)
        return play
    }

    /// Snapshots of fixture 0 in every stage other than playing: loading, tutorial, paused, won, failed and result.
    static func notPlaying() throws -> [Snapshot] {
        let fixture: ColorfallCanyonsFixture = ColorfallCanyonsFixtures.fixture(0)
        var result: [Snapshot] = []
        result.append(Snapshot(play: ColorfallCanyonsPlay(level: fixture.level), levelNumber: 1, time: 0))
        result.append(Snapshot(play: try begun(0, tutorial: true), levelNumber: 1, time: 0))
        var paused: ColorfallCanyonsPlay = try begun(0)
        try paused.handle(.pause)
        result.append(Snapshot(play: paused, levelNumber: 1, time: 0))
        var won: ColorfallCanyonsPlay = try begun(0)
        for action in fixture.solution where won.stage == .playing {
            try won.apply(action, expecting: won.fingerprint)
        }
        result.append(Snapshot(play: won, levelNumber: 1, time: 0))
        var failed: ColorfallCanyonsPlay = try begun(0)
        try failed.apply(.step(fixture.level.tickLimit), expecting: failed.fingerprint)
        result.append(Snapshot(play: failed, levelNumber: 1, time: 0))
        var shown: ColorfallCanyonsPlay = won
        try shown.handle(.showResult)
        result.append(Snapshot(play: shown, levelNumber: 1, time: 0))
        let stages: [ColorfallCanyonsStage] = [.loading, .tutorial, .paused, .won, .failed, .result]
        var index: Int = 0
        while index < stages.count {
            #expect(result[index].stage == stages[index])
            index += 1
        }
        return result
    }

    // MARK: Scripting

    /// A pointer event.
    static func event(_ id: Int, _ phase: PointerPhase, _ point: Vec2, _ time: Double) -> PointerEvent {
        PointerEvent(id: id, phase: phase, location: point, timestamp: time)
    }

    /// A unit random number 0 ..< 1.
    static func unit(_ random: inout ColorfallCanyonsRandom) -> Double {
        Double(random.next() >> 11) / 9_007_199_254_740_992
    }

    /// Plays one finger along `points` (began, moved …, ended) from time `start`; returns every action sent and the
    /// highlight seen right after touch-down.
    static func drag(_ controller: inout Controller, _ points: [Vec2], view: Vec2, snapshot: Snapshot,
                     start: Double) -> (actions: [Action], highlight: Int?) {
        var actions: [Action] = []
        var highlight: Int?
        var index: Int = 0
        while index < points.count {
            let phase: PointerPhase = index == 0 ? .began : (index == points.count - 1 ? .ended : .moved)
            let e: PointerEvent = event(1, phase, points[index], start + Double(index) * frame)
            actions += controller.handle(e, viewSize: view, snapshot: snapshot)
            if index == 0 { highlight = controller.highlightedCell }
            index += 1
        }
        return (actions, highlight)
    }

    /// A tap (began and ended at `point`) ending at `time`.
    static func tap(_ controller: inout Controller, _ point: Vec2, view: Vec2, snapshot: Snapshot,
                    time: Double) -> [Action] {
        var actions: [Action] = controller.handle(event(1, .began, point, time - 0.05), viewSize: view,
                                                  snapshot: snapshot)
        actions += controller.handle(event(1, .ended, point, time), viewSize: view, snapshot: snapshot)
        return actions
    }

    /// Two fingers about the view centre move their midpoint by `move` (fractions of the view) in two half steps and
    /// lift; returns the actions sent.
    static func orbit(_ controller: inout Controller, by move: Vec2, view: Vec2, snapshot: Snapshot,
                      time: Double) -> [Action] {
        let a: Vec2 = Vec2(view.x * 0.4, view.y * 0.5)
        let b: Vec2 = Vec2(view.x * 0.6, view.y * 0.5)
        let d: Vec2 = Vec2(move.x * view.x, move.y * view.y)
        var actions: [Action] = controller.handle(event(1, .began, a, time), viewSize: view, snapshot: snapshot)
        actions += controller.handle(event(2, .began, b, time + frame), viewSize: view, snapshot: snapshot)
        actions += controller.handle(event(1, .moved, a + d, time + 2 * frame), viewSize: view, snapshot: snapshot)
        actions += controller.handle(event(2, .moved, b + d, time + 3 * frame), viewSize: view, snapshot: snapshot)
        actions += controller.handle(event(1, .ended, a + d, time + 4 * frame), viewSize: view, snapshot: snapshot)
        actions += controller.handle(event(2, .ended, b + d, time + 5 * frame), viewSize: view, snapshot: snapshot)
        return actions
    }

    /// The orbit expected after a midpoint move of `move` (fractions of the view) from `from`: yaw + 90° per width,
    /// pitch − 60° per height (screen y down, so upwards raises the pitch), each clamped to its bounds here.
    static func expectedOrbit(_ from: ColorfallCanyonsOrbit, move: Vec2) -> ColorfallCanyonsOrbit {
        let limit: Double = 40 * degree
        let yaw: Double = min(max(from.yaw + move.x * 90 * degree, -limit), limit)
        let pitch: Double = min(max(from.pitch - move.y * 60 * degree, 25 * degree), 70 * degree)
        return ColorfallCanyonsOrbit(yaw: yaw, pitch: pitch)
    }

    /// Whether two orbits agree within 1e-9 radians.
    static func close(_ a: ColorfallCanyonsOrbit, _ b: ColorfallCanyonsOrbit) -> Bool {
        abs(a.yaw - b.yaw) < 1e-9 && abs(a.pitch - b.pitch) < 1e-9
    }

    /// The view point of `world` for `snapshot` in `view` at `orbit`, or nil.
    static func screen(_ world: SIMD3<Double>, snapshot: Snapshot, view: Vec2,
                       orbit: ColorfallCanyonsOrbit) -> Vec2? {
        let camera: ColorfallCanyonsCamera = Geometry.camera(snapshot, aspect: view.x / view.y, orbit: orbit)
        guard let v = Geometry.project(world, camera: camera) else { return nil }
        return Vec2(v.x * view.x, v.y * view.y)
    }

    /// A point that picks `.cell(c)` for a cell carvable by `level`'s own rule, or nil.
    static func carvablePoint(_ level: ColorfallCanyonsLevel?, snapshot: Snapshot, view: Vec2,
                              orbit: ColorfallCanyonsOrbit) -> (point: Vec2, cell: Int)? {
        var cell: Int = 0
        while cell < snapshot.cellCount {
            let carvable: Bool = level.map { $0.isCarvable(cell, heights: snapshot.heights) }
                ?? Controller.isCarvable(cell, snapshot: snapshot)
            if carvable, let p = screen(Geometry.cellTop(cell, snapshot), snapshot: snapshot, view: view, orbit: orbit),
               ColorfallCanyonsPicker.pick(SIMD2(p.x, p.y), size: SIMD2(view.x, view.y), snapshot: snapshot,
                                           orbit: orbit) == .cell(cell) {
                return (p, cell)
            }
            cell += 1
        }
        return nil
    }

    /// A point that picks `.spring(s)`, or nil.
    static func springPoint(_ snapshot: Snapshot, view: Vec2,
                            orbit: ColorfallCanyonsOrbit) -> (point: Vec2, spring: Int)? {
        var s: Int = 0
        while s < snapshot.springs.count {
            if let p = screen(Geometry.emitterTop(s, snapshot), snapshot: snapshot, view: view, orbit: orbit),
               ColorfallCanyonsPicker.pick(SIMD2(p.x, p.y), size: SIMD2(view.x, view.y), snapshot: snapshot,
                                           orbit: orbit) == .spring(s) {
                return (p, s)
            }
            s += 1
        }
        return nil
    }

    /// A point near a view corner that picks `.empty`, or nil.
    static func emptyPoint(_ snapshot: Snapshot, view: Vec2, orbit: ColorfallCanyonsOrbit) -> Vec2? {
        let candidates: [Vec2] = [Vec2(3, 3), Vec2(view.x - 3, 3), Vec2(3, view.y - 3), Vec2(view.x - 3, view.y - 3)]
        for p in candidates where ColorfallCanyonsPicker.pick(SIMD2(p.x, p.y), size: SIMD2(view.x, view.y),
                                                               snapshot: snapshot, orbit: orbit) == .empty {
            return p
        }
        return nil
    }

    // MARK: Seeded drags and taps

    @Test func seededDragsAndTapsMatchTheIndependentExpectation() throws {
        let cases: [Case] = try Self.certified()
        var carves: Int = 0, valves: Int = 0, silentTaps: Int = 0, middles: Int = 0, highlights: Int = 0
        var mismatches: Int = 0
        for view in Self.views {
            for move in Self.orbitMoves {
                var random: ColorfallCanyonsRandom = ColorfallCanyonsRandom(seed: Self.seed)
                var controller: Controller = Controller()
                let orbitActions: [Action] = Self.orbit(&controller, by: move, view: view,
                                                        snapshot: cases[0].snapshot, time: 0)
                #expect(orbitActions.isEmpty)
                let orbit: ColorfallCanyonsOrbit = controller.orbit
                #expect(Self.close(orbit, Self.expectedOrbit(.authored, move: move)))
                var trial: Int = 0
                while trial < 500 {
                    let c: Case = cases[trial % cases.count]
                    let snapshot: Snapshot = c.snapshot
                    // Start: a uniform point, a cell top centre or an emitter top, each with a little jitter.
                    var start: Vec2 = Vec2(Self.unit(&random) * view.x, Self.unit(&random) * view.y)
                    let kind: Int = random.int(0...3)
                    if kind == 1 || kind == 2 {
                        let cell: Int = random.int(0...(snapshot.cellCount - 1))
                        if let p = Self.screen(Geometry.cellTop(cell, snapshot), snapshot: snapshot, view: view,
                                               orbit: orbit) { start = p }
                    } else if kind == 3, !snapshot.springs.isEmpty {
                        let s: Int = random.int(0...(snapshot.springs.count - 1))
                        if let p = Self.screen(Geometry.emitterTop(s, snapshot), snapshot: snapshot, view: view,
                                               orbit: orbit) { start = p }
                    }
                    start = start + Vec2(Self.unit(&random) * 4 - 2, Self.unit(&random) * 4 - 2)
                    // Path: out to `reach` points along a random direction, then back towards the start.
                    let band: Int = random.int(0...2)
                    let reach: Double
                    if band == 0 {
                        reach = Self.unit(&random) * 9.5
                    } else if band == 1 {
                        reach = 10.5 + Self.unit(&random) * 5
                    } else {
                        reach = 16.5 + Self.unit(&random) * 200
                    }
                    let theta: Double = Self.unit(&random) * 2 * Double.pi
                    let direction: Vec2 = Vec2(cos(theta), sin(theta))
                    let outward: Int = random.int(1...6)
                    let back: Double = Self.unit(&random)
                    var points: [Vec2] = [start]
                    var k: Int = 1
                    while k <= outward {
                        points.append(start + direction * (reach * Double(k) / Double(outward)))
                        k += 1
                    }
                    points.append(start + direction * (reach * back))
                    // Independent expectation.
                    var travel: Double = 0
                    for p in points {
                        let dx: Double = p.x - start.x, dy: Double = p.y - start.y
                        travel = max(travel, (dx * dx + dy * dy).squareRoot())
                    }
                    let pick: ColorfallCanyonsPick = ColorfallCanyonsPicker.pick(SIMD2(start.x, start.y),
                                                                                 size: SIMD2(view.x, view.y),
                                                                                 snapshot: snapshot, orbit: orbit)
                    var carvable: Int?
                    if case .cell(let cell) = pick, c.level.isCarvable(cell, heights: snapshot.heights) {
                        carvable = cell
                    }
                    var expected: [Action] = []
                    if travel >= 16, let cell = carvable {
                        expected = [.carve(cell)]
                        carves += 1
                    } else if travel < 10, case .spring(let s) = pick {
                        expected = [.valve(s)]
                        valves += 1
                    } else if travel < 10 {
                        silentTaps += 1
                    } else if travel < 16 {
                        middles += 1
                    }
                    if carvable != nil { highlights += 1 }
                    let result: (actions: [Action], highlight: Int?) =
                        Self.drag(&controller, points, view: view, snapshot: snapshot, start: Double(trial + 1))
                    if result.actions != expected || result.highlight != carvable { mismatches += 1 }
                    #expect(result.actions == expected, "trial \(trial) view \(view) orbit \(orbit) pick \(pick)")
                    #expect(result.highlight == carvable)
                    #expect(controller.highlightedCell == nil)
                    #expect(controller.state == .idle)
                    #expect(Self.close(controller.orbit, orbit))
                    trial += 1
                }
            }
        }
        #expect(mismatches == 0)
        #expect(carves > 100 && valves > 50 && silentTaps > 100 && middles > 100 && highlights > 100,
                "carves \(carves) valves \(valves) taps \(silentTaps) middles \(middles) highlights \(highlights)")
    }

    // MARK: Arbitration

    @Test func aSecondFingerCancelsADragAndSendsNothing() throws {
        let c: Case = try Self.certified()[0]
        for view in Self.views {
            guard let target = Self.carvablePoint(c.level, snapshot: c.snapshot, view: view, orbit: .authored) else {
                Issue.record("no carvable target in \(view)")
                continue
            }
            var controller: Controller = Controller()
            var actions: [Action] = controller.handle(Self.event(1, .began, target.point, 0), viewSize: view,
                                                      snapshot: c.snapshot)
            #expect(controller.highlightedCell == target.cell)
            #expect(controller.state == .dragging)
            actions += controller.handle(Self.event(1, .moved, target.point + Vec2(40, 0), 0.1), viewSize: view,
                                         snapshot: c.snapshot)
            actions += controller.handle(Self.event(2, .began, Vec2(view.x / 2, view.y / 2), 0.2), viewSize: view,
                                         snapshot: c.snapshot)
            #expect(controller.state == .orbiting)
            #expect(controller.highlightedCell == nil)
            actions += controller.handle(Self.event(1, .moved, target.point + Vec2(80, 0), 0.3), viewSize: view,
                                         snapshot: c.snapshot)
            actions += controller.handle(Self.event(1, .ended, target.point + Vec2(80, 0), 0.4), viewSize: view,
                                         snapshot: c.snapshot)
            #expect(controller.state == .cancelled)
            actions += controller.handle(Self.event(2, .moved, Vec2(10, 10), 0.5), viewSize: view,
                                         snapshot: c.snapshot)
            actions += controller.handle(Self.event(2, .ended, Vec2(10, 10), 0.6), viewSize: view,
                                         snapshot: c.snapshot)
            #expect(actions.isEmpty)
            #expect(controller.state == .idle)
            // The finger after the cancelled gesture carves again.
            let again: (actions: [Action], highlight: Int?) =
                Self.drag(&controller, [target.point, target.point + Vec2(0, 30)], view: view,
                          snapshot: c.snapshot, start: 2)
            let orbit: ColorfallCanyonsOrbit = controller.orbit
            let pick: ColorfallCanyonsPick = ColorfallCanyonsPicker.pick(SIMD2(target.point.x, target.point.y),
                                                                         size: SIMD2(view.x, view.y),
                                                                         snapshot: c.snapshot, orbit: orbit)
            var expected: [Action] = []
            if case .cell(let cell) = pick, c.level.isCarvable(cell, heights: c.snapshot.heights) {
                expected = [.carve(cell)]
            }
            #expect(again.actions == expected)
        }
    }

    @Test func cancelledPhasesSendNothing() throws {
        let c: Case = try Self.certified()[0]
        let view: Vec2 = Self.views[0]
        let target: (point: Vec2, cell: Int)? = Self.carvablePoint(c.level, snapshot: c.snapshot, view: view,
                                                                    orbit: .authored)
        let spring: (point: Vec2, spring: Int)? = Self.springPoint(c.snapshot, view: view, orbit: .authored)
        #expect(target != nil && spring != nil)
        var controller: Controller = Controller()
        if let target {
            var actions: [Action] = controller.handle(Self.event(1, .began, target.point, 0), viewSize: view,
                                                      snapshot: c.snapshot)
            actions += controller.handle(Self.event(1, .moved, target.point + Vec2(0, 50), 0.1), viewSize: view,
                                         snapshot: c.snapshot)
            actions += controller.handle(Self.event(1, .cancelled, target.point + Vec2(0, 50), 0.2), viewSize: view,
                                         snapshot: c.snapshot)
            #expect(actions.isEmpty)
            #expect(controller.highlightedCell == nil)
            #expect(controller.state == .idle)
        }
        if let spring {
            var actions: [Action] = controller.handle(Self.event(1, .began, spring.point, 1), viewSize: view,
                                                      snapshot: c.snapshot)
            actions += controller.handle(Self.event(1, .cancelled, spring.point, 1.05), viewSize: view,
                                         snapshot: c.snapshot)
            #expect(actions.isEmpty)
            // The same tap ended normally toggles the valve.
            #expect(Self.tap(&controller, spring.point, view: view, snapshot: c.snapshot, time: 2) ==
                [.valve(spring.spring)])
        }
        // An orbit ended by a cancelled phase sends nothing either; cancel() drops a drag and keeps the orbit.
        _ = Self.orbit(&controller, by: Vec2(0.1, 0), view: view, snapshot: c.snapshot, time: 3)
        let turned: ColorfallCanyonsOrbit = controller.orbit
        if let target {
            var actions: [Action] = controller.handle(Self.event(1, .began, target.point, 4), viewSize: view,
                                                      snapshot: c.snapshot)
            controller.cancel()
            #expect(controller.highlightedCell == nil)
            #expect(controller.state == .idle)
            actions += controller.handle(Self.event(1, .ended, target.point + Vec2(0, 50), 4.1), viewSize: view,
                                         snapshot: c.snapshot)
            #expect(actions.isEmpty)
        }
        #expect(Self.close(controller.orbit, turned))
    }

    @Test func nonPlayingStagesSendNoCarveOrValveAndNoHighlight() throws {
        let snapshots: [Snapshot] = try Self.notPlaying()
        let fixture: ColorfallCanyonsFixture = ColorfallCanyonsFixtures.fixture(0)
        var targets: Int = 0, springs: Int = 0
        for snapshot in snapshots {
            for view in Self.views {
                var controller: Controller = Controller()
                if let target = Self.carvablePoint(fixture.level, snapshot: snapshot, view: view, orbit: .authored) {
                    targets += 1
                    let result: (actions: [Action], highlight: Int?) =
                        Self.drag(&controller, [target.point, target.point + Vec2(20, 0), target.point + Vec2(40, 0)],
                                  view: view, snapshot: snapshot, start: 0)
                    #expect(result.actions.isEmpty, "stage \(snapshot.stage)")
                    #expect(result.highlight == nil)
                }
                if let spring = Self.springPoint(snapshot, view: view, orbit: .authored) {
                    springs += 1
                    #expect(Self.tap(&controller, spring.point, view: view, snapshot: snapshot, time: 1).isEmpty)
                }
            }
        }
        #expect(targets >= 12 && springs >= 12, "targets \(targets) springs \(springs)")
    }

    // MARK: Double tap

    @Test func doubleTapOnEmptySpaceResetsTheViewInANonPlayingStage() throws {
        let snapshots: [Snapshot] = try Self.notPlaying()
        let paused: Snapshot = snapshots[2]
        #expect(paused.stage == .paused)
        for view in Self.views {
            var controller: Controller = Controller()
            _ = Self.orbit(&controller, by: Vec2(0.2, -0.2), view: view, snapshot: paused, time: 0)
            #expect(!Self.close(controller.orbit, .authored))
            guard let empty = Self.emptyPoint(paused, view: view, orbit: controller.orbit) else {
                Issue.record("no empty point in \(view)")
                continue
            }
            #expect(Self.tap(&controller, empty, view: view, snapshot: paused, time: 1).isEmpty)
            #expect(Self.tap(&controller, empty, view: view, snapshot: paused, time: 1.34) == [.resetView])
            #expect(Self.close(controller.orbit, .authored))
            // The counter cleared: a third tap right after is a first tap again.
            #expect(Self.tap(&controller, empty, view: view, snapshot: paused, time: 1.5).isEmpty)
            // Too slow: 0.36 s apart sends nothing.
            _ = Self.orbit(&controller, by: Vec2(0.2, 0), view: view, snapshot: paused, time: 3)
            let turned: ColorfallCanyonsOrbit = controller.orbit
            #expect(Self.tap(&controller, empty, view: view, snapshot: paused, time: 5).isEmpty)
            #expect(Self.tap(&controller, empty, view: view, snapshot: paused, time: 5.36).isEmpty)
            #expect(Self.close(controller.orbit, turned))
        }
    }

    @Test func aTapOnACellOrADragBetweenTapsBreaksTheDoubleTap() throws {
        let c: Case = try Self.certified()[0]
        let view: Vec2 = Self.views[0]
        let empty: Vec2? = Self.emptyPoint(c.snapshot, view: view, orbit: .authored)
        let target: (point: Vec2, cell: Int)? = Self.carvablePoint(c.level, snapshot: c.snapshot, view: view,
                                                                    orbit: .authored)
        #expect(empty != nil && target != nil)
        guard let empty, let target else { return }
        var controller: Controller = Controller()
        #expect(Self.tap(&controller, empty, view: view, snapshot: c.snapshot, time: 1).isEmpty)
        #expect(Self.tap(&controller, target.point, view: view, snapshot: c.snapshot, time: 1.1).isEmpty)
        #expect(Self.tap(&controller, empty, view: view, snapshot: c.snapshot, time: 1.2).isEmpty)
        // A press that moves 10 … 16 points on empty space is not a tap.
        let middle: (actions: [Action], highlight: Int?) =
            Self.drag(&controller, [empty, empty + Vec2(12, 0)], view: view, snapshot: c.snapshot, start: 1.25)
        #expect(middle.actions.isEmpty)
        #expect(Self.tap(&controller, empty, view: view, snapshot: c.snapshot, time: 1.4).isEmpty)
        #expect(Self.tap(&controller, empty, view: view, snapshot: c.snapshot, time: 1.6) == [.resetView])
    }

    // MARK: Orbit

    @Test func orbitFollowsTheMidpointAndClampsAtItsBounds() throws {
        let c: Case = try Self.certified()[0]
        for view in Self.views {
            var controller: Controller = Controller()
            // Small move: right 10 % of the width and up 10 % of the height: yaw +9°, pitch +6°.
            #expect(Self.orbit(&controller, by: Vec2(0.1, -0.1), view: view, snapshot: c.snapshot, time: 0).isEmpty)
            #expect(abs(controller.orbit.yaw - 9 * Self.degree) < 1e-9)
            #expect(abs(controller.orbit.pitch - 56 * Self.degree) < 1e-9)
            // Far right and far up clamp at +40° and 70°.
            _ = Self.orbit(&controller, by: Vec2(2, -2), view: view, snapshot: c.snapshot, time: 1)
            #expect(abs(controller.orbit.yaw - 40 * Self.degree) < 1e-9)
            #expect(abs(controller.orbit.pitch - 70 * Self.degree) < 1e-9)
            // Far left and far down clamp at −40° and 25°.
            _ = Self.orbit(&controller, by: Vec2(-3, 3), view: view, snapshot: c.snapshot, time: 2)
            #expect(abs(controller.orbit.yaw + 40 * Self.degree) < 1e-9)
            #expect(abs(controller.orbit.pitch - 25 * Self.degree) < 1e-9)
            // Clamped every step: back the other way moves at once.
            _ = Self.orbit(&controller, by: Vec2(0.1, -0.1), view: view, snapshot: c.snapshot, time: 3)
            #expect(abs(controller.orbit.yaw + 31 * Self.degree) < 1e-9)
            #expect(abs(controller.orbit.pitch - 31 * Self.degree) < 1e-9)
            controller.resetView()
            #expect(controller.orbit == .authored)
        }
    }

    @Test func aThirdFingerReBasesTheMidpoint() throws {
        let c: Case = try Self.certified()[0]
        let view: Vec2 = Self.views[0]
        var controller: Controller = Controller()
        let a: Vec2 = Vec2(100, 400), b: Vec2 = Vec2(300, 400)
        var actions: [Action] = controller.handle(Self.event(1, .began, a, 0), viewSize: view, snapshot: c.snapshot)
        actions += controller.handle(Self.event(2, .began, b, 0.1), viewSize: view, snapshot: c.snapshot)
        actions += controller.handle(Self.event(1, .moved, a + Vec2(39, 0), 0.2), viewSize: view,
                                     snapshot: c.snapshot)
        let afterTwo: ColorfallCanyonsOrbit = controller.orbit
        #expect(abs(afterTwo.yaw - 19.5 / view.x * 90 * Self.degree) < 1e-9)
        // A third finger far away: the midpoint jumps, the orbit does not.
        actions += controller.handle(Self.event(3, .began, Vec2(380, 10), 0.3), viewSize: view,
                                     snapshot: c.snapshot)
        #expect(Self.close(controller.orbit, afterTwo))
        #expect(controller.state == .orbiting)
        // Moving the third finger 30 points right moves the midpoint 10 points: yaw + 10 / width × 90°.
        actions += controller.handle(Self.event(3, .moved, Vec2(410, 10), 0.4), viewSize: view,
                                     snapshot: c.snapshot)
        #expect(abs(controller.orbit.yaw - afterTwo.yaw - 10 / view.x * 90 * Self.degree) < 1e-9)
        #expect(abs(controller.orbit.pitch - afterTwo.pitch) < 1e-9)
        actions += controller.handle(Self.event(3, .ended, Vec2(410, 10), 0.5), viewSize: view,
                                     snapshot: c.snapshot)
        actions += controller.handle(Self.event(1, .ended, a, 0.6), viewSize: view, snapshot: c.snapshot)
        actions += controller.handle(Self.event(2, .ended, b, 0.7), viewSize: view, snapshot: c.snapshot)
        #expect(actions.isEmpty)
        #expect(controller.state == .idle)
    }

    // MARK: Unusable views

    @Test func anUnusableViewSizeSendsNothingAndHighlightsNothing() throws {
        let c: Case = try Self.certified()[0]
        let good: Vec2 = Self.views[0]
        let target: (point: Vec2, cell: Int)? = Self.carvablePoint(c.level, snapshot: c.snapshot, view: good,
                                                                    orbit: .authored)
        let spring: (point: Vec2, spring: Int)? = Self.springPoint(c.snapshot, view: good, orbit: .authored)
        #expect(target != nil && spring != nil)
        guard let target, let spring else { return }
        let bad: [Vec2] = [Vec2(0, 844), Vec2(390, 0), Vec2(-390, 844), Vec2(Double.nan, 844),
                           Vec2(390, Double.infinity)]
        for view in bad {
            var controller: Controller = Controller()
            let result: (actions: [Action], highlight: Int?) =
                Self.drag(&controller, [target.point, target.point + Vec2(0, 40)], view: view, snapshot: c.snapshot,
                          start: 0)
            #expect(result.actions.isEmpty)
            #expect(result.highlight == nil)
            #expect(Self.tap(&controller, spring.point, view: view, snapshot: c.snapshot, time: 1).isEmpty)
            #expect(Self.tap(&controller, Vec2(3, 3), view: view, snapshot: c.snapshot, time: 2).isEmpty)
            #expect(Self.tap(&controller, Vec2(3, 3), view: view, snapshot: c.snapshot, time: 2.1).isEmpty)
            #expect(Self.orbit(&controller, by: Vec2(0.3, 0.3), view: view, snapshot: c.snapshot, time: 3).isEmpty)
            #expect(controller.orbit == .authored)
            #expect(controller.camera(viewSize: view, snapshot: c.snapshot) == nil)
        }
        var controller: Controller = Controller()
        #expect(controller.camera(viewSize: good, snapshot: c.snapshot) != nil)
        // Non-finite touch locations are rejected by the tracker and send nothing.
        let actions: [Action] = controller.handle(Self.event(1, .began, Vec2(Double.nan, 10), 0), viewSize: good,
                                                  snapshot: c.snapshot)
        #expect(actions.isEmpty)
        #expect(controller.state == .idle)
    }

    @Test func snapshotCarvabilityMatchesTheLevelRule() throws {
        let cases: [Case] = try Self.certified()
        var carvable: Int = 0
        for c in cases {
            var cell: Int = 0
            while cell < c.snapshot.cellCount {
                let expected: Bool = c.level.isCarvable(cell, heights: c.snapshot.heights)
                #expect(Controller.isCarvable(cell, snapshot: c.snapshot) == expected)
                if expected { carvable += 1 }
                cell += 1
            }
            #expect(!Controller.isCarvable(-1, snapshot: c.snapshot))
            #expect(!Controller.isCarvable(c.snapshot.cellCount, snapshot: c.snapshot))
        }
        #expect(carvable > 0)
    }
}
