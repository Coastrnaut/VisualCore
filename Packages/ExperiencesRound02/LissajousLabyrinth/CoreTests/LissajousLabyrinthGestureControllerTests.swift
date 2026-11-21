// LissajousLabyrinthGestureControllerTests — feature 314 (R02-G02-04) T-R02G0204-004 (FR-R02G0204-002, 003, 004, 007;
// SC-R02G0204-001, 002; clarifications Q2, Q3, Q5; research R3–R6, R8). Scripted touches at fixed view sizes
// (390 × 844, 96 × 64, 1,024 × 768) on seeded fixture levels: 500 seeded turns around the four dial rings end in
// exactly the action the swept angle names, computed independently here (start + whole steps of 40° or 22.5° swept,
// clamped 1 … 9 or modulo 16; nothing when it equals the start); full and one-and-a-half turns, frequency clamping and
// the preview; 1,000 seeded arbitration scripts (second finger mid-turn, cancelled touches, cancel(), empty space, not
// playing, a release after play stopped, unknown ids, non-finite locations and unusable views) never send an action
// they should not; a touch between knobs picks the nearest by R02-F22's rule (then depth, then the lower id), checked
// against an independent implementation of that rule; with no knob in reach a touch on a ring's band (0.7 … 1.3 ring
// radii) grabs that ring from the contact point (touching opposite the knob and turning two steps sends start ± 2;
// inside 0.5 or outside 1.5 radii of a ring never grabs it; a knob in reach wins over another ring's band); the orbit
// follows the two-finger midpoint (90° per width, 60° per height), clamps and resets by resetOrbit and a double tap on
// empty space; the selection follows the last picked ring and select(_:); the same script gives the same results. Test
// data uses explicit types and plain loops (CI type-check rule).
import Foundation
import Testing
@testable import LissajousLabyrinthCore
import VisualCoreMath
import VisualCoreScenes
import VisualCoreSimulation

@Suite struct LissajousLabyrinthGestureControllerTests {
    typealias Controller = LissajousLabyrinthGestureController
    typealias Dial = LissajousLabyrinthDial
    typealias Action = LissajousLabyrinthAction
    typealias Snapshot = LissajousLabyrinthSceneSnapshot

    /// The view sizes every script runs at.
    static let views: [Vec2] = [Vec2(390, 844), Vec2(96, 64), Vec2(1_024, 768)]
    /// The seed of the scripted turns.
    static let turnSeed: UInt64 = 2_314
    /// The seed of the arbitration scripts.
    static let arbitrationSeed: UInt64 = 2_314_001
    /// The seed of the fixture levels.
    static let levelSeed: UInt64 = 2_314_002
    /// The time between scripted events in seconds.
    static let frame: Double = 1.0 / 60
    /// One degree in radians.
    static let degree: Double = Double.pi / 180
    /// The largest angle between successive scripted points of a turn (12°).
    static let pathStep: Double = 12 * degree

    /// Six seeded fixture levels of different shapes (the rings are laid out against each level's stage).
    static let levels: [LissajousLabyrinthLevel] = {
        var random: SeededRandom = SeededRandom(seed: levelSeed)
        var result: [LissajousLabyrinthLevel] = []
        while result.count < 6 { result.append(LissajousLabyrinthFixture.next(&random).level) }
        return result
    }()

    /// Snapshots of every fixture level at eight seeded dial settings each (48), built once: a level is validated and
    /// its lap evaluated when built, so the scripts draw from this pool instead of building a level per script.
    static let snapshots: [Snapshot] = {
        var random: SeededRandom = SeededRandom(seed: levelSeed + 1)
        var result: [Snapshot] = []
        for base in levels {
            var n: Int = 0
            while n < 8 {
                result.append(randomSnapshot(&random, base: base))
                n += 1
            }
        }
        return result
    }()

    // MARK: Helpers

    /// A snapshot of `base` whose current dials are `dials` (the level rebuilt with `dials` as its start); nil when
    /// the dials are invalid or win at once.
    static func snapshot(_ base: LissajousLabyrinthLevel, dials: LissajousLabyrinthDials) -> Snapshot? {
        guard let level = try? LissajousLabyrinthLevel(
            id: base.id, seed: base.seed, band: base.band, amplitudes: base.amplitudes, frequencyC: base.frequencyC,
            start: dials, checkpoints: base.checkpoints, obstacles: base.obstacles, allowance: base.allowance)
        else { return nil }
        return Snapshot(play: LissajousLabyrinthPlay(level: level), time: 0)
    }

    /// A snapshot of `base` at random valid dials.
    static func randomSnapshot(_ random: inout SeededRandom, base: LissajousLabyrinthLevel) -> Snapshot {
        while true {
            let dials: LissajousLabyrinthDials = LissajousLabyrinthFixture.dials(&random)
            if let s = snapshot(base, dials: dials) { return s }
        }
    }

    /// The drawn camera's view-projection for `view`, `snapshot` and `orbit` (the scene's shared camera).
    static func viewProjection(view: Vec2, snapshot: Snapshot, orbit: LissajousLabyrinthOrbit = .authored) -> Mat4 {
        LissajousLabyrinthSceneGeometry.viewProjection(aspect: view.x / view.y, snapshot: snapshot, orbit: orbit)
    }

    /// The step angle of `dial`, written out here: a ninth of a turn for the frequencies, a sixteenth for the phases.
    static func step(_ dial: Dial) -> Double {
        switch dial {
        case .frequencyA, .frequencyB: 2 * Double.pi / 9
        case .phaseA, .phaseC: 2 * Double.pi / 16
        }
    }

    /// The value `k` whole steps from `start`, written out here: clamped to 1 … 9 for the frequencies, modulo 16 for
    /// the phases.
    static func expectedValue(_ dial: Dial, start: Int, steps k: Int) -> Int {
        switch dial {
        case .frequencyA, .frequencyB: min(max(start + k, 1), 9)
        case .phaseA, .phaseC: ((start + k) % 16 + 16) % 16
        }
    }

    /// The world point at ring angle `angle` (clockwise from the ring's up as seen from the authored eye) on `dial`'s
    /// ring of `level`, at `scale` times the ring radius.
    static func ringPoint(_ dial: Dial, level: LissajousLabyrinthLevel, angle: Double, scale: Double = 1) -> Vec3 {
        let centre: Vec3 = LissajousLabyrinthHandles.ringCentre(dial, level: level)
        let radius: Double = LissajousLabyrinthHandles.ringRadius(level: level) * scale
        let up: Vec3 = LissajousLabyrinthHandles.up
        let right: Vec3 = LissajousLabyrinthHandles.right
        return centre + (up * cos(angle) + right * sin(angle)) * radius
    }

    /// The knob of `dial` at its value in `snapshot`: on the ring at value × step.
    static func knob(_ dial: Dial, snapshot: Snapshot) -> Vec3 {
        ringPoint(dial, level: snapshot.level, angle: Double(snapshot.dials[dial]) * step(dial))
    }

    /// Whether `point` lies inside `view` (edges included).
    static func inside(_ point: Vec2, view: Vec2) -> Bool {
        point.x >= 0 && point.x <= view.x && point.y >= 0 && point.y <= view.y
    }

    /// The screen points of a turn of `dial` sweeping `sweep` radians from its knob: the knob, then points at most
    /// 12° apart at `scale` times the ring radius, the last exactly at the swept angle; nil when one leaves the view.
    static func turnPath(_ dial: Dial, snapshot: Snapshot, sweep: Double, scale: Double, view: Vec2,
                         orbit: LissajousLabyrinthOrbit = .authored) -> [Vec2]? {
        let vp: Mat4 = viewProjection(view: view, snapshot: snapshot, orbit: orbit)
        let start: Double = Double(snapshot.dials[dial]) * step(dial)
        let count: Int = max(1, Int((abs(sweep) / pathStep).rounded(.up)))
        var points: [Vec2] = []
        var i: Int = 0
        while i <= count {
            let angle: Double = start + sweep * Double(i) / Double(count)
            let world: Vec3 = ringPoint(dial, level: snapshot.level, angle: angle, scale: i == 0 ? 1 : scale)
            guard let p = ScreenProjection.project(world, viewProjection: vp, viewport: view)?.point,
                  inside(p, view: view) else { return nil }
            points.append(p)
            i += 1
        }
        return points
    }

    /// A one-finger script: down at the first point, moved through the rest, then ended (or cancelled).
    static func stroke(_ points: [Vec2], id: Int, time: Double, cancelled: Bool = false) -> [PointerEvent] {
        var events: [PointerEvent] = []
        var t: Double = time
        events.append(PointerEvent(id: id, phase: .began, location: points[0], timestamp: t))
        var index: Int = 1
        while index < points.count {
            t += frame
            events.append(PointerEvent(id: id, phase: .moved, location: points[index], timestamp: t))
            index += 1
        }
        t += frame
        events.append(PointerEvent(id: id, phase: cancelled ? .cancelled : .ended, location: points[points.count - 1],
                                   timestamp: t))
        return events
    }

    /// Feeds `events` and returns every action returned.
    static func run(_ controller: inout Controller, _ events: [PointerEvent], view: Vec2, snapshot: Snapshot,
                    playing: Bool = true) -> [Action] {
        var actions: [Action] = []
        for event in events {
            if let action = controller.handle(event, viewSize: view, snapshot: snapshot, playing: playing) {
                actions.append(action)
            }
        }
        return actions
    }

    /// One seeded scripted turn: its view, snapshot, dial, expected action and events.
    struct TurnCase {
        let view: Vec2
        let snapshot: Snapshot
        let dial: Dial
        let start: Int
        let expected: Action?
        let events: [PointerEvent]
    }

    /// Draws one scripted turn from `random`: a random pooled snapshot (level and dials), view and dial; a sweep of k
    /// whole steps (−10 … 10 for the frequencies, −24 … 24 for the phases, so turns past a half and a full revolution
    /// occur) plus up to ±0.35 of a step; the path at 0.8 … 1.15 of the ring radius. Nil when a point leaves the view.
    static func turnCase(_ random: inout SeededRandom, index: Int) -> TurnCase? {
        let view: Vec2 = views[random.int(0...2)]
        let snapshot: Snapshot = snapshots[random.int(0...(snapshots.count - 1))]
        let dial: Dial = Dial.allCases[random.int(0...3)]
        let start: Int = snapshot.dials[dial]
        let k: Int = dial == .frequencyA || dial == .frequencyB ? random.int(-10...10) : random.int(-24...24)
        let jitter: Double = random.range(-0.35...0.35)
        let scale: Double = random.range(0.8...1.15)
        let sweep: Double = (Double(k) + jitter) * step(dial)
        guard let points = turnPath(dial, snapshot: snapshot, sweep: sweep, scale: scale, view: view) else {
            return nil
        }
        let value: Int = expectedValue(dial, start: start, steps: k)
        let expected: Action? = value == start ? nil : Action(dial: dial, value: value)
        let events: [PointerEvent] = stroke(points, id: index % 7 + 1, time: Double(index))
        return TurnCase(view: view, snapshot: snapshot, dial: dial, start: start, expected: expected, events: events)
    }

    // MARK: Scripted turns

    @Test func fiveHundredSeededTurnsEndInTheIndependentlyComputedValue() throws {
        var random: SeededRandom = SeededRandom(seed: Self.turnSeed)
        var checked: Int = 0
        var actions: Int = 0
        var perDial: [Dial: Int] = [:]
        var perView: [Int] = [0, 0, 0]
        var index: Int = 0
        while index < 500 {
            guard let turn = Self.turnCase(&random, index: index) else {
                Issue.record("turn \(index) left the view")
                index += 1
                continue
            }
            var controller: Controller = Controller()
            let result: [Action] = Self.run(&controller, turn.events, view: turn.view, snapshot: turn.snapshot)
            if let expected = turn.expected {
                #expect(result == [expected], "turn \(index) \(turn.dial) from \(turn.start) at \(turn.view)")
                actions += 1
            } else {
                #expect(result.isEmpty, "turn \(index) returned to its start")
            }
            #expect(controller.phase == .idle)
            #expect(controller.preview == nil)
            #expect(controller.selectedDial == turn.dial)
            perDial[turn.dial, default: 0] += 1
            if let v = Self.views.firstIndex(of: turn.view) { perView[v] += 1 }
            checked += 1
            index += 1
        }
        #expect(checked == 500)
        #expect(actions > 350)
        for dial in Dial.allCases { #expect((perDial[dial] ?? 0) > 60, "\(dial)") }
        for count in perView { #expect(count > 100) }
    }

    /// A snapshot of fixture level `level` at `dials` (valid dials), or of the next fixture level where they do not
    /// win at once.
    static func fixed(_ dials: LissajousLabyrinthDials, level: Int = 0) throws -> Snapshot {
        var n: Int = 0
        while n < levels.count {
            if let s = snapshot(levels[(level + n) % levels.count], dials: dials) { return s }
            n += 1
        }
        return try #require(snapshot(levels[level], dials: dials))
    }

    /// The single turn of `dial` by `sweep` at `view`: the actions it sends.
    static func turn(_ dial: Dial, sweep: Double, snapshot: Snapshot, view: Vec2,
                     controller: inout Controller) throws -> [Action] {
        let points: [Vec2] = try #require(turnPath(dial, snapshot: snapshot, sweep: sweep, scale: 1, view: view))
        return run(&controller, stroke(points, id: 1, time: 0), view: view, snapshot: snapshot)
    }

    @Test func aFullTurnOfAPhaseRingReturnsToTheStartAndOneAndAHalfTurnsAddEightSteps() throws {
        let snapshot: Snapshot = try Self.fixed(LissajousLabyrinthDials(frequencyA: 3, frequencyB: 4, phaseA: 5,
                                                                        phaseC: 13))
        for view in Self.views {
            for dial in [Dial.phaseA, Dial.phaseC] {
                let start: Int = snapshot.dials[dial]
                var controller: Controller = Controller()
                #expect(try Self.turn(dial, sweep: 2 * Double.pi, snapshot: snapshot, view: view,
                                      controller: &controller).isEmpty, "full turn \(dial) at \(view)")
                #expect(controller.phase == .idle)
                controller = Controller()
                #expect(try Self.turn(dial, sweep: -2 * Double.pi, snapshot: snapshot, view: view,
                                      controller: &controller).isEmpty, "full turn back \(dial) at \(view)")
                controller = Controller()
                let forward: [Action] = try Self.turn(dial, sweep: 3 * Double.pi, snapshot: snapshot, view: view,
                                                      controller: &controller)
                #expect(forward == [Action(dial: dial, value: (start + 8) % 16)], "1.5 turns \(dial) at \(view)")
                controller = Controller()
                let backward: [Action] = try Self.turn(dial, sweep: -3 * Double.pi, snapshot: snapshot, view: view,
                                                       controller: &controller)
                #expect(backward == [Action(dial: dial, value: (start + 8) % 16)], "1.5 turns back \(dial)")
                // Past half a turn: 9 steps forward is 9 steps, not 7 back.
                controller = Controller()
                let past: [Action] = try Self.turn(dial, sweep: 9 * Double.pi / 8, snapshot: snapshot, view: view,
                                                   controller: &controller)
                #expect(past == [Action(dial: dial, value: (start + 9) % 16)], "nine steps \(dial) at \(view)")
            }
        }
    }

    @Test func frequenciesClampAtOneAndNine() throws {
        let s: Double = 2 * Double.pi / 9
        // (dials, dial, sweep in steps, expected value or nil for no action)
        let high: Snapshot = try Self.fixed(LissajousLabyrinthDials(frequencyA: 9, frequencyB: 2, phaseA: 0, phaseC: 0))
        let low: Snapshot = try Self.fixed(LissajousLabyrinthDials(frequencyA: 2, frequencyB: 1, phaseA: 4, phaseC: 7))
        let mid: Snapshot = try Self.fixed(LissajousLabyrinthDials(frequencyA: 5, frequencyB: 3, phaseA: 0, phaseC: 9))
        for view in Self.views {
            var c: Controller = Controller()
            #expect(try Self.turn(.frequencyA, sweep: 3 * s, snapshot: high, view: view, controller: &c).isEmpty)
            c = Controller()
            #expect(try Self.turn(.frequencyA, sweep: -2 * s, snapshot: high, view: view, controller: &c)
                    == [Action(dial: .frequencyA, value: 7)])
            c = Controller()
            #expect(try Self.turn(.frequencyB, sweep: -3 * s, snapshot: low, view: view, controller: &c).isEmpty)
            c = Controller()
            #expect(try Self.turn(.frequencyA, sweep: -4 * s, snapshot: low, view: view, controller: &c)
                    == [Action(dial: .frequencyA, value: 1)])
            c = Controller()
            #expect(try Self.turn(.frequencyB, sweep: 1.5 * 2 * Double.pi, snapshot: mid, view: view, controller: &c)
                    == [Action(dial: .frequencyB, value: 9)])
            c = Controller()
            #expect(try Self.turn(.frequencyA, sweep: -2 * Double.pi, snapshot: mid, view: view, controller: &c)
                    == [Action(dial: .frequencyA, value: 1)])
            // Over the top and back: the whole turn counts (+8 then −8 is no change; +6 then −2 is 9).
            let mp: Snapshot = mid
            let up: [Vec2] = try #require(Self.turnPath(.frequencyA, snapshot: mp, sweep: 8 * s, scale: 1, view: view))
            let start: Double = 5 * s
            var back: [Vec2] = up
            var k: Int = 7
            let vp: Mat4 = Self.viewProjection(view: view, snapshot: mp)
            while k >= 0 {
                let w: Vec3 = Self.ringPoint(.frequencyA, level: mp.level, angle: start + Double(k) * s)
                back.append(try #require(ScreenProjection.project(w, viewProjection: vp, viewport: view)?.point))
                k -= 1
            }
            c = Controller()
            #expect(Self.run(&c, Self.stroke(back, id: 2, time: 0), view: view, snapshot: mp).isEmpty)
            var there: [Vec2] = try #require(Self.turnPath(.frequencyA, snapshot: mp, sweep: 6 * s, scale: 1,
                                                           view: view))
            for j in [5, 4] {
                let w: Vec3 = Self.ringPoint(.frequencyA, level: mp.level, angle: start + Double(j) * s)
                there.append(try #require(ScreenProjection.project(w, viewProjection: vp, viewport: view)?.point))
            }
            c = Controller()
            #expect(Self.run(&c, Self.stroke(there, id: 2, time: 0), view: view, snapshot: mp)
                    == [Action(dial: .frequencyA, value: 9)])
        }
    }

    @Test func thePreviewFollowsTheTurnAndOnlyTheReleaseSends() throws {
        let view: Vec2 = Vec2(390, 844)
        let snapshot: Snapshot = try Self.fixed(LissajousLabyrinthDials(frequencyA: 2, frequencyB: 3, phaseA: 3,
                                                                        phaseC: 0))
        let s: Double = Self.step(.phaseA)
        let vp: Mat4 = Self.viewProjection(view: view, snapshot: snapshot)
        var points: [Vec2] = []
        for k in 0...5 {
            let w: Vec3 = Self.ringPoint(.phaseA, level: snapshot.level, angle: Double(3 + k) * s)
            points.append(try #require(ScreenProjection.project(w, viewProjection: vp, viewport: view)?.point))
        }
        var controller: Controller = Controller()
        let began: PointerEvent = PointerEvent(id: 4, phase: .began, location: points[0], timestamp: 0)
        #expect(controller.handle(began, viewSize: view, snapshot: snapshot, playing: true) == nil)
        #expect(controller.phase == .turning(.phaseA, start: 3, candidate: 3))
        #expect(controller.preview == nil)
        #expect(controller.selectedDial == .phaseA)
        var k: Int = 1
        while k < points.count {
            let moved: PointerEvent = PointerEvent(id: 4, phase: .moved, location: points[k], timestamp: Double(k))
            #expect(controller.handle(moved, viewSize: view, snapshot: snapshot, playing: true) == nil)
            #expect(controller.phase == .turning(.phaseA, start: 3, candidate: 3 + k))
            #expect(controller.preview == Action(dial: .phaseA, value: 3 + k))
            k += 1
        }
        // Back to the start: no preview.
        let home: PointerEvent = PointerEvent(id: 4, phase: .moved, location: points[3], timestamp: 7)
        _ = controller.handle(home, viewSize: view, snapshot: snapshot, playing: true)
        let back: PointerEvent = PointerEvent(id: 4, phase: .moved, location: points[0], timestamp: 8)
        _ = controller.handle(back, viewSize: view, snapshot: snapshot, playing: true)
        #expect(controller.preview == nil)
        let again: PointerEvent = PointerEvent(id: 4, phase: .moved, location: points[2], timestamp: 9)
        _ = controller.handle(again, viewSize: view, snapshot: snapshot, playing: true)
        #expect(controller.preview == Action(dial: .phaseA, value: 5))
        let ended: PointerEvent = PointerEvent(id: 4, phase: .ended, location: points[2], timestamp: 10)
        #expect(controller.handle(ended, viewSize: view, snapshot: snapshot, playing: true)
                == Action(dial: .phaseA, value: 5))
        #expect(controller.phase == .idle)
        #expect(controller.preview == nil)
    }

    // MARK: Arbitration

    /// The dial the shared picking rule chooses at `touch`, implemented here independently: among the knobs within
    /// the 22-point touch radius and inside the depth range, the nearest on screen, then the nearest in depth, then the
    /// lower id. Returns the dial and whether the choice was an exact screen-distance tie.
    static func expectedPick(_ touch: Vec2, view: Vec2, snapshot: Snapshot,
                             orbit: LissajousLabyrinthOrbit = .authored) -> (dial: Dial?, tie: Bool) {
        let vp: Mat4 = viewProjection(view: view, snapshot: snapshot, orbit: orbit)
        var best: (id: Int, distance: Double, depth: Double)? = nil
        var tie: Bool = false
        var id: Int = 0
        for dial in Dial.allCases {
            defer { id += 1 }
            let world: Vec3 = LissajousLabyrinthHandles.knob(dial, value: snapshot.dials[dial], level: snapshot.level)
            guard let projected = ScreenProjection.project(world, viewProjection: vp, viewport: view),
                  projected.depth >= -1, projected.depth <= 1 else { continue }
            let distance: Double = (projected.point - touch).length
            guard distance <= HandlePicker.minimumTouchRadius else { continue }
            if let current = best {
                if distance == current.distance { tie = true }
                if distance > current.distance { continue }
                if distance == current.distance && projected.depth >= current.depth { continue }
            }
            best = (id, distance, projected.depth)
        }
        guard let best else { return (nil, false) }
        return (LissajousLabyrinthHandles.dial(id: best.id), tie)
    }

    /// The ring band under `touch` when no knob is in reach, implemented here independently (clarification Q2): the
    /// touch ray meets each ring's plane (through the ring centre, normal the authored eye direction) in front of the
    /// eye; a ring counts when the hit lies within 0.7 … 1.3 ring radii of its centre; the hit nearest to the exact
    /// radius wins, ties to the lower id. Returns the dial and the hit's distance from its centre in ring radii.
    static func expectedRing(_ touch: Vec2, view: Vec2, snapshot: Snapshot,
                             orbit: LissajousLabyrinthOrbit = .authored) -> (dial: Dial, radii: Double)? {
        let vp: Mat4 = viewProjection(view: view, snapshot: snapshot, orbit: orbit)
        guard let inverse = vp.inverse,
              let ray = ScreenProjection.ray(through: touch, viewport: view, inverseViewProjection: inverse)
        else { return nil }
        let normal: Vec3 = LissajousLabyrinthSceneGeometry.eyeDirection
        let along: Double = normal.dot(ray.direction)
        guard abs(along) >= 0.1 else { return nil }
        let radius: Double = LissajousLabyrinthHandles.ringRadius(level: snapshot.level)
        var best: (dial: Dial, radii: Double)? = nil
        for dial in Dial.allCases {
            let centre: Vec3 = LissajousLabyrinthHandles.ringCentre(dial, level: snapshot.level)
            let t: Double = normal.dot(centre - ray.origin) / along
            guard t > 0 else { continue }
            let hit: Vec3 = ray.origin + ray.direction * t
            let radii: Double = (hit - centre).length / radius
            guard radii >= 0.7, radii <= 1.3 else { continue }
            if let current = best, abs(radii - 1) >= abs(current.radii - 1) { continue }
            best = (dial, radii)
        }
        return best
    }

    /// The dial a touch at `touch` grabs: the knob by the picking rule, else the ring band; nil on empty space.
    static func expectedContact(_ touch: Vec2, view: Vec2, snapshot: Snapshot,
                                orbit: LissajousLabyrinthOrbit = .authored) -> Dial? {
        if let dial = expectedPick(touch, view: view, snapshot: snapshot, orbit: orbit).dial { return dial }
        return expectedRing(touch, view: view, snapshot: snapshot, orbit: orbit)?.dial
    }

    /// A point of `view` where no knob is in reach and no ring band lies under it, drawn from `random`.
    static func emptyPoint(_ random: inout SeededRandom, view: Vec2, snapshot: Snapshot) -> Vec2? {
        var attempt: Int = 0
        while attempt < 50 {
            let p: Vec2 = Vec2(random.range(0...view.x), random.range(0...view.y))
            if expectedContact(p, view: view, snapshot: snapshot) == nil { return p }
            attempt += 1
        }
        return nil
    }

    @Test func oneThousandSeededArbitrationScriptsNeverSendAnUnwantedAction() throws {
        var random: SeededRandom = SeededRandom(seed: Self.arbitrationSeed)
        let kinds: Int = 7
        var counts: [Int] = [Int](repeating: 0, count: kinds)
        var script: Int = 0
        while script < 1_000 {
            let kind: Int = script % kinds
            guard let turn = Self.turnCase(&random, index: script) else {
                Issue.record("script \(script) left the view")
                script += 1
                continue
            }
            var controller: Controller = Controller()
            let other: Dial = Dial.allCases[(LissajousLabyrinthHandles.index(turn.dial) + 1) % 4]
            controller.select(other)
            let view: Vec2 = turn.view
            let snapshot: Snapshot = turn.snapshot
            var actions: [Action] = []
            switch kind {
            case 0:
                // A second finger mid-turn cancels the turn and orbits; nothing is sent.
                let half: Int = max(1, turn.events.count / 2)
                actions += Self.run(&controller, Array(turn.events.prefix(half)), view: view, snapshot: snapshot)
                let second: Vec2 = Vec2(random.range(0...view.x), random.range(0...view.y))
                let t: Double = Double(script) + 0.5
                let down: PointerEvent = PointerEvent(id: 99, phase: .began, location: second, timestamp: t)
                actions += Self.run(&controller, [down], view: view, snapshot: snapshot)
                #expect(controller.phase == .orbiting)
                #expect(controller.preview == nil)
                actions += Self.run(&controller, Array(turn.events.suffix(from: half)), view: view, snapshot: snapshot)
                #expect(controller.phase == .cancelled)
                let up: PointerEvent = PointerEvent(id: 99, phase: .ended, location: second, timestamp: t + 1)
                actions += Self.run(&controller, [up], view: view, snapshot: snapshot)
                #expect(controller.phase == .idle)
            case 1:
                // A cancelled touch ends the turn without an action.
                var events: [PointerEvent] = turn.events
                let last: PointerEvent = events[events.count - 1]
                events[events.count - 1] = PointerEvent(id: last.id, phase: .cancelled, location: last.location,
                                                        timestamp: last.timestamp)
                actions = Self.run(&controller, events, view: view, snapshot: snapshot)
                #expect(controller.phase == .idle)
            case 2:
                // cancel() mid-turn: cancelled until the finger lifts, then idle; nothing is sent.
                actions = Self.run(&controller, Array(turn.events.dropLast()), view: view, snapshot: snapshot)
                controller.cancel()
                #expect(controller.phase == .cancelled)
                #expect(controller.preview == nil)
                actions += Self.run(&controller, [turn.events[turn.events.count - 1]], view: view, snapshot: snapshot)
                #expect(controller.phase == .idle)
            case 3:
                // A touch on empty space selects nothing and sends nothing.
                guard let p = Self.emptyPoint(&random, view: view, snapshot: snapshot) else {
                    Issue.record("no empty point at \(view)")
                    script += 1
                    continue
                }
                let q: Vec2 = Vec2(min(max(p.x + random.range(-30...30), 0), view.x),
                                   min(max(p.y + random.range(-30...30), 0), view.y))
                actions = Self.run(&controller, Self.stroke([p, q], id: 3, time: Double(script)), view: view,
                                   snapshot: snapshot)
                #expect(controller.selectedDial == other)
                #expect(controller.phase == .idle)
            case 4:
                // Not playing: rings never turn and the selection stays.
                var turned: Bool = false
                for event in turn.events {
                    if let a = controller.handle(event, viewSize: view, snapshot: snapshot, playing: false) {
                        actions.append(a)
                    }
                    if case .turning = controller.phase { turned = true }
                }
                #expect(!turned)
                #expect(controller.selectedDial == other)
                #expect(controller.phase == .idle)
            case 5:
                // Play stops before the release: nothing is sent.
                actions = Self.run(&controller, Array(turn.events.dropLast()), view: view, snapshot: snapshot)
                actions += Self.run(&controller, [turn.events[turn.events.count - 1]], view: view, snapshot: snapshot,
                                    playing: false)
                #expect(controller.phase == .idle)
            default:
                // Unknown ids, repeated downs, non-finite locations and unusable views: no crash, no action.
                let bad: [Vec2] = [Vec2(.nan, 10), Vec2(10, .infinity), Vec2(-.infinity, .nan)]
                let t: Double = Double(script)
                var events: [PointerEvent] = []
                events.append(PointerEvent(id: 50, phase: .moved, location: Vec2(10, 10), timestamp: t))
                events.append(PointerEvent(id: 51, phase: .ended, location: Vec2(10, 10), timestamp: t))
                events.append(PointerEvent(id: 52, phase: .cancelled, location: Vec2(10, 10), timestamp: t))
                for b in bad { events.append(PointerEvent(id: 53, phase: .began, location: b, timestamp: t)) }
                events.append(contentsOf: turn.events.dropLast())
                events.append(PointerEvent(id: turn.events[0].id, phase: .began, location: Vec2(1, 1), timestamp: t))
                for b in bad {
                    events.append(PointerEvent(id: turn.events[0].id, phase: .moved, location: b, timestamp: t))
                }
                events.append(PointerEvent(id: turn.events[0].id, phase: .cancelled, location: Vec2(.nan, .nan),
                                           timestamp: .nan))
                actions = Self.run(&controller, events, view: view, snapshot: snapshot)
                let sizes: [Vec2] = [Vec2(0, 0), Vec2(.nan, 10), Vec2(-5, 5), Vec2(.infinity, 3)]
                for size in sizes {
                    let stroke: [PointerEvent] = Self.stroke([Vec2(5, 5), Vec2(6, 6)], id: 60, time: t)
                    actions += Self.run(&controller, stroke, view: size, snapshot: snapshot)
                }
                #expect(controller.phase == .idle)
            }
            #expect(actions.isEmpty, "script \(script) kind \(kind)")
            counts[kind] += 1
            script += 1
        }
        var total: Int = 0
        for c in counts { total += c }
        #expect(total == 1_000)
    }

    @Test func aTurnAfterAnOrbitUsesTheOrbitedCamera() throws {
        let view: Vec2 = Vec2(1_024, 768)
        let snapshot: Snapshot = try Self.fixed(LissajousLabyrinthDials(frequencyA: 2, frequencyB: 5, phaseA: 1,
                                                                        phaseC: 6), level: 2)
        var controller: Controller = Controller()
        let fingers: [PointerEvent] = [
            PointerEvent(id: 1, phase: .began, location: Vec2(400, 300), timestamp: 0),
            PointerEvent(id: 2, phase: .began, location: Vec2(500, 300), timestamp: 0),
            PointerEvent(id: 1, phase: .moved, location: Vec2(500, 380), timestamp: 0.1),
            PointerEvent(id: 2, phase: .moved, location: Vec2(600, 380), timestamp: 0.1),
            PointerEvent(id: 1, phase: .ended, location: Vec2(500, 380), timestamp: 0.2),
            PointerEvent(id: 2, phase: .ended, location: Vec2(600, 380), timestamp: 0.2),
        ]
        #expect(Self.run(&controller, fingers, view: view, snapshot: snapshot).isEmpty)
        let orbit: LissajousLabyrinthOrbit = controller.orbit
        #expect(orbit != .authored)
        let points: [Vec2] = try #require(Self.turnPath(.phaseC, snapshot: snapshot, sweep: -5 * Self.step(.phaseC),
                                                        scale: 1, view: view, orbit: orbit))
        let actions: [Action] = Self.run(&controller, Self.stroke(points, id: 5, time: 1), view: view,
                                         snapshot: snapshot)
        #expect(actions == [Action(dial: .phaseC, value: 1)])
    }

    // MARK: Picking

    @Test func aTouchBetweenKnobsPicksTheNearestThenTheLowerID() throws {
        var random: SeededRandom = SeededRandom(seed: Self.turnSeed + 7)
        var compared: Int = 0
        var none: Int = 0
        var ties: Int = 0
        var pairs: Int = 0
        var rings: Int = 0
        for view in Self.views {
            var n: Int = 0
            while n < 6 {
                let snapshot: Snapshot = Self.randomSnapshot(&random, base: Self.levels[n])
                let vp: Mat4 = Self.viewProjection(view: view, snapshot: snapshot)
                var screen: [Vec2] = []
                for dial in Dial.allCases {
                    let w: Vec3 = Self.knob(dial, snapshot: snapshot)
                    screen.append(try #require(ScreenProjection.project(w, viewProjection: vp, viewport: view)?.point))
                }
                for a in 0..<4 {
                    for b in (a + 1)..<4 {
                        if (screen[a] - screen[b]).length <= 2 * HandlePicker.minimumTouchRadius { pairs += 1 }
                        let fractions: [Double] = [0.2, 0.4, 0.5, 0.6, 0.8]
                        for f in fractions {
                            let touch: Vec2 = screen[a] + (screen[b] - screen[a]) * f
                            let expected: (dial: Dial?, tie: Bool) = Self.expectedPick(touch, view: view,
                                                                                         snapshot: snapshot)
                            var controller: Controller = Controller()
                            let down: PointerEvent = PointerEvent(id: 1, phase: .began, location: touch, timestamp: 0)
                            _ = controller.handle(down, viewSize: view, snapshot: snapshot, playing: true)
                            if expected.dial == nil,
                               let ring = Self.expectedRing(touch, view: view, snapshot: snapshot) {
                                // No knob in reach: the ring band under the touch.
                                let start: Int = snapshot.dials[ring.dial]
                                #expect(controller.phase == .turning(ring.dial, start: start, candidate: start))
                                rings += 1
                            } else if let dial = expected.dial {
                                let start: Int = snapshot.dials[dial]
                                #expect(controller.phase == .turning(dial, start: start, candidate: start),
                                        "touch \(touch) between \(a) and \(b) at \(view)")
                                #expect(controller.selectedDial == dial)
                                if expected.tie { ties += 1 }
                                compared += 1
                            } else {
                                #expect(controller.phase == .idle)
                                none += 1
                            }
                        }
                    }
                }
                n += 1
            }
        }
        #expect(compared > 100)
        #expect(none + rings > 0)
        // On the small view neighbouring knobs are within two touch radii, so touches between them reach both.
        #expect(pairs > 0)
        _ = ties
    }

    @Test func equidistantKnobsTieToTheLowerID() throws {
        // phaseA at 8 (the bottom of its ring) and phaseC at 0 (the top of the ring below) are mirror images about the
        // midpoint between the two rings, at equal depth. Scan touches across that midpoint on the small view: wherever
        // the two screen distances are exactly equal the lower id (phaseA) wins, and everywhere the controller agrees
        // with the independently implemented rule.
        let view: Vec2 = Vec2(96, 64)
        let snapshot: Snapshot = try Self.fixed(LissajousLabyrinthDials(frequencyA: 3, frequencyB: 2, phaseA: 8,
                                                                        phaseC: 0))
        let vp: Mat4 = Self.viewProjection(view: view, snapshot: snapshot)
        let pa: Vec2 = try #require(ScreenProjection.project(Self.knob(.phaseA, snapshot: snapshot),
                                                             viewProjection: vp, viewport: view)?.point)
        let pc: Vec2 = try #require(ScreenProjection.project(Self.knob(.phaseC, snapshot: snapshot),
                                                             viewProjection: vp, viewport: view)?.point)
        var exactTies: Int = 0
        var i: Int = -200
        while i <= 200 {
            let touch: Vec2 = (pa + pc) * 0.5 + (pc - pa) * (Double(i) * 1e-15)
            let expected: (dial: Dial?, tie: Bool) = Self.expectedPick(touch, view: view, snapshot: snapshot)
            var controller: Controller = Controller()
            _ = controller.handle(PointerEvent(id: 1, phase: .began, location: touch, timestamp: 0), viewSize: view,
                                  snapshot: snapshot, playing: true)
            let dial: Dial = try #require(expected.dial)
            #expect(controller.selectedDial == dial)
            let da: Double = (pa - touch).length
            let dc: Double = (pc - touch).length
            if da == dc {
                exactTies += 1
                #expect(controller.selectedDial == .phaseA, "tie at \(touch)")
            }
            i += 1
        }
        #expect(exactTies > 0)
    }

    // MARK: Rings

    @Test func aTouchOnTheRingOppositeTheKnobThenTwoStepsSendsStartPlusTwo() throws {
        let snapshot: Snapshot = try Self.fixed(LissajousLabyrinthDials(frequencyA: 3, frequencyB: 5, phaseA: 6,
                                                                        phaseC: 15))
        var covered: Int = 0
        var coveredViews: Set<Int> = []
        for (v, view) in Self.views.enumerated() {
            let vp: Mat4 = Self.viewProjection(view: view, snapshot: snapshot)
            for dial in Dial.allCases {
                let start: Int = snapshot.dials[dial]
                let s: Double = Self.step(dial)
                let opposite: Double = Double(start) * s + Double.pi
                // The path: the opposite point, then two steps clockwise (or counter-clockwise), 12° at most apart.
                for direction in [1.0, -1.0] {
                    var points: [Vec2] = []
                    let count: Int = max(1, Int((2 * s / Self.pathStep).rounded(.up)))
                    var i: Int = 0
                    var usable: Bool = true
                    while i <= count {
                        let angle: Double = opposite + direction * 2 * s * Double(i) / Double(count)
                        let w: Vec3 = Self.ringPoint(dial, level: snapshot.level, angle: angle)
                        guard let p = ScreenProjection.project(w, viewProjection: vp, viewport: view)?.point,
                              Self.inside(p, view: view) else {
                            usable = false
                            break
                        }
                        points.append(p)
                        i += 1
                    }
                    // Only where no knob is in reach of the first touch (knobs keep priority).
                    guard usable, Self.expectedPick(points[0], view: view, snapshot: snapshot).dial == nil else {
                        continue
                    }
                    #expect(Self.expectedRing(points[0], view: view, snapshot: snapshot)?.dial == dial)
                    // Touch and release without moving: the ring is grabbed, nothing is sent.
                    var still: Controller = Controller()
                    let tap: [PointerEvent] = Self.stroke([points[0]], id: 3, time: 0)
                    _ = still.handle(tap[0], viewSize: view, snapshot: snapshot, playing: true)
                    #expect(still.phase == .turning(dial, start: start, candidate: start), "\(dial) at \(view)")
                    #expect(still.selectedDial == dial)
                    #expect(still.preview == nil)
                    #expect(still.handle(tap[1], viewSize: view, snapshot: snapshot, playing: true) == nil)
                    #expect(still.phase == .idle)
                    // Two steps from there: start ± 2, computed here.
                    let k: Int = direction > 0 ? 2 : -2
                    let value: Int = Self.expectedValue(dial, start: start, steps: k)
                    var controller: Controller = Controller()
                    let actions: [Action] = Self.run(&controller, Self.stroke(points, id: 4, time: 1), view: view,
                                                     snapshot: snapshot)
                    #expect(actions == [Action(dial: dial, value: value)], "\(dial) \(k) at \(view)")
                    covered += 1
                    coveredViews.insert(v)
                }
            }
        }
        // 4 dials × 2 directions on the two larger views (14 here); on 96 × 64 a knob is always in reach.
        #expect(covered >= 12)
        #expect(coveredViews.contains(0))
        #expect(coveredViews.contains(2))
    }

    @Test func touchesInsideHalfOrOutsideOneAndAHalfRingRadiiNeverGrabThatRing() throws {
        let snapshot: Snapshot = try Self.fixed(LissajousLabyrinthDials(frequencyA: 7, frequencyB: 2, phaseA: 11,
                                                                        phaseC: 3), level: 1)
        var empty: Int = 0
        var banded: Int = 0
        for view in [Vec2(390, 844), Vec2(1_024, 768)] {
            let vp: Mat4 = Self.viewProjection(view: view, snapshot: snapshot)
            for dial in Dial.allCases {
                var a: Int = 0
                while a < 24 {
                    let angle: Double = Double(a) * 15 * Self.degree
                    for scale in [0.0, 0.25, 0.45, 0.5, 0.8, 1.0, 1.2, 1.5, 1.6] {
                        let w: Vec3 = Self.ringPoint(dial, level: snapshot.level, angle: angle, scale: scale)
                        guard let p = ScreenProjection.project(w, viewProjection: vp, viewport: view)?.point,
                              Self.inside(p, view: view),
                              Self.expectedPick(p, view: view, snapshot: snapshot).dial == nil else { continue }
                        var controller: Controller = Controller()
                        _ = controller.handle(PointerEvent(id: 1, phase: .began, location: p, timestamp: 0),
                                              viewSize: view, snapshot: snapshot, playing: true)
                        if scale <= 0.5 || scale >= 1.5 {
                            // Inside 0.5 or outside 1.5 ring radii: never this ring. Outside, towards a neighbour
                            // (2.5 ring radii away) the touch may lie on the neighbour's band, which then turns.
                            if case .turning(let turned, _, _) = controller.phase {
                                #expect(turned != dial, "\(dial) \(scale) at \(view)")
                            }
                            if let other = Self.expectedRing(p, view: view, snapshot: snapshot) {
                                #expect(other.dial != dial)
                                let start: Int = snapshot.dials[other.dial]
                                #expect(controller.phase == .turning(other.dial, start: start, candidate: start))
                            } else {
                                #expect(controller.phase == .idle, "\(dial) \(scale) at \(view)")
                                empty += 1
                            }
                        } else {
                            // In this ring's band (0.8 … 1.2: at least 1.3 radii from a neighbour 2.5 radii away,
                            // so no neighbour is as near its exact radius): this ring.
                            #expect(Self.expectedRing(p, view: view, snapshot: snapshot)?.dial == dial)
                            let start: Int = snapshot.dials[dial]
                            #expect(controller.phase == .turning(dial, start: start, candidate: start),
                                    "\(dial) \(scale) at \(view)")
                            banded += 1
                        }
                    }
                    a += 1
                }
            }
        }
        #expect(empty > 300)
        #expect(banded > 100)
    }

    @Test func aKnobInReachWinsOverAnotherRingsBand() throws {
        // On the small view a knob near the edge of its ring is within the 22-point touch radius of the neighbouring
        // ring's band: the knob wins (the ring is only the fallback).
        let snapshot: Snapshot = try Self.fixed(LissajousLabyrinthDials(frequencyA: 2, frequencyB: 9, phaseA: 8,
                                                                        phaseC: 4))
        var found: Int = 0
        for view in Self.views {
            let vp: Mat4 = Self.viewProjection(view: view, snapshot: snapshot)
            for dial in Dial.allCases {
                var a: Int = 0
                while a < 72 {
                    let angle: Double = Double(a) * 5 * Self.degree
                    for scale in [0.8, 1.0, 1.2] {
                        let w: Vec3 = Self.ringPoint(dial, level: snapshot.level, angle: angle, scale: scale)
                        guard let p = ScreenProjection.project(w, viewProjection: vp, viewport: view)?.point,
                              let ring = Self.expectedRing(p, view: view, snapshot: snapshot),
                              let knob = Self.expectedPick(p, view: view, snapshot: snapshot).dial,
                              knob != ring.dial else { continue }
                        var controller: Controller = Controller()
                        _ = controller.handle(PointerEvent(id: 1, phase: .began, location: p, timestamp: 0),
                                              viewSize: view, snapshot: snapshot, playing: true)
                        let start: Int = snapshot.dials[knob]
                        #expect(controller.phase == .turning(knob, start: start, candidate: start))
                        #expect(controller.selectedDial == knob)
                        found += 1
                    }
                    a += 1
                }
            }
        }
        #expect(found > 0)
    }

    // MARK: Orbit

    /// Two fingers down at `a` and `b`, both moved by `delta`, then lifted one by one.
    static func orbitScript(a: Vec2, b: Vec2, delta: Vec2, time: Double) -> [PointerEvent] {
        [PointerEvent(id: 1, phase: .began, location: a, timestamp: time),
         PointerEvent(id: 2, phase: .began, location: b, timestamp: time),
         PointerEvent(id: 1, phase: .moved, location: a + delta, timestamp: time + 0.05),
         PointerEvent(id: 2, phase: .moved, location: b + delta, timestamp: time + 0.05),
         PointerEvent(id: 1, phase: .ended, location: a + delta, timestamp: time + 0.1),
         PointerEvent(id: 2, phase: .ended, location: b + delta, timestamp: time + 0.1)]
    }

    @Test func orbitFollowsTheMidpointAndClampsAtItsLimits() throws {
        let view: Vec2 = Vec2(390, 844)
        let snapshot: Snapshot = try Self.fixed(LissajousLabyrinthDials(frequencyA: 1, frequencyB: 2, phaseA: 3,
                                                                        phaseC: 4))
        let degree: Double = Self.degree
        var controller: Controller = Controller()
        // A tenth of the width right: +9° azimuth; a tenth of the height down: +6° elevation.
        var events: [PointerEvent] = Self.orbitScript(a: Vec2(100, 400), b: Vec2(200, 400), delta: Vec2(39, 84.4),
                                                      time: 0)
        var index: Int = 0
        for event in events {
            #expect(controller.handle(event, viewSize: view, snapshot: snapshot, playing: true) == nil)
            if index == 1 { #expect(controller.phase == .orbiting) }
            if index == 4 { #expect(controller.phase == .cancelled) }
            index += 1
        }
        #expect(controller.phase == .idle)
        #expect(abs(controller.orbit.azimuthOffset - 9 * degree) < 1e-9)
        #expect(abs(controller.orbit.elevation - (LissajousLabyrinthOrbit.authored.elevation + 6 * degree)) < 1e-9)
        // Far right and down: both at their upper limits (40°, 60°).
        events = Self.orbitScript(a: Vec2(100, 400), b: Vec2(200, 400), delta: Vec2(5_000, 5_000), time: 1)
        _ = Self.run(&controller, events, view: view, snapshot: snapshot)
        #expect(controller.orbit.azimuthOffset == LissajousLabyrinthOrbit.azimuthRange.upperBound)
        #expect(controller.orbit.elevation == LissajousLabyrinthOrbit.elevationRange.upperBound)
        #expect(abs(controller.orbit.azimuthOffset - 40 * degree) < 1e-12)
        #expect(abs(controller.orbit.elevation - 60 * degree) < 1e-12)
        // Far left and up: both at their lower limits (−40°, 10°).
        events = Self.orbitScript(a: Vec2(100, 400), b: Vec2(200, 400), delta: Vec2(-9_000, -9_000), time: 2)
        _ = Self.run(&controller, events, view: view, snapshot: snapshot)
        #expect(controller.orbit.azimuthOffset == LissajousLabyrinthOrbit.azimuthRange.lowerBound)
        #expect(controller.orbit.elevation == LissajousLabyrinthOrbit.elevationRange.lowerBound)
        #expect(abs(controller.orbit.elevation - 10 * degree) < 1e-12)
        controller.resetOrbit()
        #expect(controller.orbit == .authored)
        // Orbiting works while not playing.
        events = Self.orbitScript(a: Vec2(100, 400), b: Vec2(200, 400), delta: Vec2(39, 0), time: 3)
        _ = Self.run(&controller, events, view: view, snapshot: snapshot, playing: false)
        #expect(abs(controller.orbit.azimuthOffset - 9 * degree) < 1e-9)
        // A third finger re-bases the midpoint: no jump.
        let before: LissajousLabyrinthOrbit = controller.orbit
        let three: [PointerEvent] = [
            PointerEvent(id: 1, phase: .began, location: Vec2(100, 100), timestamp: 5),
            PointerEvent(id: 2, phase: .began, location: Vec2(200, 100), timestamp: 5),
            PointerEvent(id: 3, phase: .began, location: Vec2(300, 700), timestamp: 5.1),
        ]
        _ = Self.run(&controller, three, view: view, snapshot: snapshot)
        #expect(controller.orbit == before)
        controller.cancel()
        #expect(controller.phase == .cancelled)
        let lift: [PointerEvent] = [
            PointerEvent(id: 1, phase: .ended, location: Vec2(100, 100), timestamp: 5.2),
            PointerEvent(id: 2, phase: .cancelled, location: Vec2(200, 100), timestamp: 5.2),
            PointerEvent(id: 3, phase: .ended, location: Vec2(300, 700), timestamp: 5.2),
        ]
        _ = Self.run(&controller, lift, view: view, snapshot: snapshot)
        #expect(controller.phase == .idle)
        #expect(controller.orbit == before)
    }

    @Test func doubleTapOnEmptySpaceResetsTheOrbit() throws {
        let snapshot: Snapshot = try Self.fixed(LissajousLabyrinthDials(frequencyA: 1, frequencyB: 2, phaseA: 3,
                                                                        phaseC: 4))
        for view in Self.views {
            let corner: Vec2 = Vec2(2, 2)
            #expect(Self.expectedContact(corner, view: view, snapshot: snapshot) == nil)
            let turn: [PointerEvent] = Self.orbitScript(a: Vec2(view.x * 0.3, view.y * 0.5),
                                                        b: Vec2(view.x * 0.6, view.y * 0.5),
                                                        delta: Vec2(view.x * 0.2, view.y * 0.2), time: 0)
            // Taps 0.2 s apart, 5 pt apart: reset.
            var controller: Controller = Controller()
            _ = Self.run(&controller, turn, view: view, snapshot: snapshot)
            #expect(controller.orbit != .authored)
            var taps: [PointerEvent] = Self.stroke([corner], id: 7, time: 10)
            taps.append(contentsOf: Self.stroke([corner + Vec2(3, 4)], id: 8, time: 10.2))
            #expect(Self.run(&controller, taps, view: view, snapshot: snapshot).isEmpty)
            #expect(controller.orbit == .authored, "view \(view)")
            // Too slow: no reset.
            _ = Self.run(&controller, turn, view: view, snapshot: snapshot)
            taps = Self.stroke([corner], id: 7, time: 20)
            taps.append(contentsOf: Self.stroke([corner], id: 8, time: 20.4))
            _ = Self.run(&controller, taps, view: view, snapshot: snapshot)
            #expect(controller.orbit != .authored)
            // Too far apart: no reset.
            controller.resetOrbit()
            _ = Self.run(&controller, turn, view: view, snapshot: snapshot)
            let far: Vec2 = Vec2(min(corner.x + 30, view.x), corner.y)
            if Self.expectedContact(far, view: view, snapshot: snapshot) == nil {
                taps = Self.stroke([corner], id: 7, time: 30)
                taps.append(contentsOf: Self.stroke([far], id: 8, time: 30.1))
                _ = Self.run(&controller, taps, view: view, snapshot: snapshot)
                #expect(controller.orbit != .authored)
            }
            // A tap that travels more than 20 pt is not a tap.
            controller.resetOrbit()
            _ = Self.run(&controller, turn, view: view, snapshot: snapshot)
            let slide: Vec2 = Vec2(corner.x, min(corner.y + 25, view.y))
            taps = Self.stroke([corner, slide, corner], id: 7, time: 40)
            taps.append(contentsOf: Self.stroke([corner], id: 8, time: 40.1))
            _ = Self.run(&controller, taps, view: view, snapshot: snapshot)
            #expect(controller.orbit != .authored)
            // A double tap on a knob is not on empty space: no reset.
            let knob: Vec2 = try #require(ScreenProjection.project(
                Self.knob(.frequencyB, snapshot: snapshot), viewProjection: Self.viewProjection(
                    view: view, snapshot: snapshot, orbit: controller.orbit), viewport: view)?.point)
            taps = Self.stroke([knob], id: 7, time: 50)
            taps.append(contentsOf: Self.stroke([knob], id: 8, time: 50.1))
            #expect(Self.run(&controller, taps, view: view, snapshot: snapshot).isEmpty)
            #expect(controller.orbit != .authored)
            // Double taps reset while not playing too.
            taps = Self.stroke([corner], id: 7, time: 60)
            taps.append(contentsOf: Self.stroke([corner], id: 8, time: 60.1))
            _ = Self.run(&controller, taps, view: view, snapshot: snapshot, playing: false)
            #expect(controller.orbit == .authored)
        }
    }

    // MARK: Selection

    @Test func selectionFollowsTheLastPickedRingAndSelect() throws {
        let view: Vec2 = Vec2(390, 844)
        let snapshot: Snapshot = try Self.fixed(LissajousLabyrinthDials(frequencyA: 4, frequencyB: 7, phaseA: 9,
                                                                        phaseC: 2))
        var controller: Controller = Controller()
        #expect(controller.selectedDial == .frequencyA)
        #expect(controller.phase == .idle)
        #expect(controller.orbit == .authored)
        #expect(controller.preview == nil)
        let vp: Mat4 = Self.viewProjection(view: view, snapshot: snapshot)
        let order: [Dial] = [.phaseC, .frequencyB, .phaseA, .frequencyA, .phaseC]
        var t: Double = 0
        for dial in order {
            let p: Vec2 = try #require(ScreenProjection.project(Self.knob(dial, snapshot: snapshot),
                                                                viewProjection: vp, viewport: view)?.point)
            let actions: [Action] = Self.run(&controller, Self.stroke([p], id: 1, time: t), view: view,
                                             snapshot: snapshot)
            #expect(actions.isEmpty)
            #expect(controller.selectedDial == dial)
            t += 1
        }
        for dial in Dial.allCases {
            controller.select(dial)
            #expect(controller.selectedDial == dial)
        }
        // Not playing: a knob touch does not change the selection.
        controller.select(.frequencyB)
        let p: Vec2 = try #require(ScreenProjection.project(Self.knob(.phaseA, snapshot: snapshot),
                                                            viewProjection: vp, viewport: view)?.point)
        _ = Self.run(&controller, Self.stroke([p], id: 1, time: 20), view: view, snapshot: snapshot, playing: false)
        #expect(controller.selectedDial == .frequencyB)
    }

    // MARK: Determinism

    @Test func theSameScriptGivesTheSameResults() throws {
        var results: [[String]] = []
        for _ in 0..<2 {
            var random: SeededRandom = SeededRandom(seed: Self.turnSeed)
            var lines: [String] = []
            var index: Int = 0
            while index < 120 {
                if let turn = Self.turnCase(&random, index: index) {
                    var controller: Controller = Controller()
                    var events: [PointerEvent] = turn.events
                    if index % 2 == 1 {
                        events.insert(contentsOf: Self.orbitScript(a: Vec2(10, 10), b: Vec2(40, 20),
                                                                   delta: Vec2(Double(index % 13), 3), time: -1),
                                      at: 0)
                    }
                    let actions: [Action] = Self.run(&controller, events, view: turn.view, snapshot: turn.snapshot)
                    lines.append("\(actions) \(controller.phase) \(controller.selectedDial) \(controller.orbit)")
                }
                index += 1
            }
            results.append(lines)
        }
        #expect(results[0] == results[1])
        #expect(results[0].count == 120)
    }
}
