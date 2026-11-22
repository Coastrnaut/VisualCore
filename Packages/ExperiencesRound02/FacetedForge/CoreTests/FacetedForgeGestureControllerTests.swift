// FacetedForgeGestureControllerTests — feature 374 (R02-G08-04) T-R02G0804-003 (FR-R02G0804-001 … 006; SC-R02G0804-001,
// 003, 004; clarifications Q1 … Q5). 500 seeded (seed 2_374) scripted rim drags, plane taps, presses and depth drags,
// piece taps and presses, short rim touches and random touches on certified levels 1, 21, 41, 61 and 81 (after their
// first certified cut, and won through the certified solution; each drawn with the initial choice and with a choice
// facing the authored eye) at three view sizes and three orbits reached by two-finger drags send exactly the actions an
// independent expectation written here predicts: the pick at touch-down, the tilt and the depth steps come from
// `FacetedForgePicker` (the geometry oracle, tested by FacetedForgePickerTests), while the arbitration (tap, drag or
// nothing by travel and duration; which action each pick sends; the middle crossing depth of a chosen piece; no cut on
// a finished play) is computed here on its own. Second fingers, `.cancelled` phases, `cancel()` and finished plays send
// no cut; 10 … 16 points of travel send nothing; a double tap on the plane cuts once; a double tap on empty space
// resets the view; the orbit follows 90° yaw per width and 60° pitch per height, clamps and re-bases on a third finger;
// choices and the orbit never change the adapter's digest. Plain loops and explicit types (CI type-check rule); well
// under 10 s per test.
import Foundation
import Testing
import VisualCoreDiagnostics
import VisualCoreExperience
import VisualCoreMath
import VisualCoreScenes
import VisualCoreSimulation
@testable import FacetedForgeCore

@Suite struct FacetedForgeGestureControllerTests {
    typealias Controller = FacetedForgeGestureController
    typealias Snapshot = FacetedForgeSceneSnapshot
    typealias Action = FacetedForgeGestureAction
    typealias Geometry = FacetedForgeSceneGeometry
    typealias Picker = FacetedForgePicker
    typealias Orbit = FacetedForgeOrbit
    typealias Core = FacetedForgeExperienceCore
    typealias Choice = FacetedForgePreviewChoice

    /// The seed of every random choice here.
    static let seed: UInt64 = 2_374
    /// The view sizes every script runs at: phone portrait, tablet landscape, tablet portrait.
    static let views: [Vec2] = [Vec2(390, 844), Vec2(1_180, 820), Vec2(1_024, 1_366)]
    /// The scripted orbits (the first is the authored one), reached by two-finger drags.
    static let orbits: [Orbit] = [.authored, Orbit(yaw: 0.5, pitch: 0.3), Orbit(yaw: -0.6, pitch: 1.0)]
    /// The certified levels used.
    static let levels: [Int] = [1, 21, 41, 61, 81]

    // MARK: Cores and snapshots

    /// A core and the snapshot drawn of it with the clamped initial preview choice at time 1 s.
    struct Case {
        let core: Core
        let snapshot: Snapshot
        var play: FacetedForgePlay { core.play }
    }

    /// An adapter action.
    static func action(_ control: String, _ values: [Double] = []) -> ExperienceAction {
        ExperienceAction(control: control, values: values, step: 0)
    }

    /// The `piece.cut` adapter action of a kernel cut.
    static func cutAction(_ cut: FacetedForgeAction) -> ExperienceAction {
        switch cut {
        case .cut(let piece, let direction, let depth):
            return action("piece.cut", [Double(piece), Double(direction), Double(depth)])
        }
    }

    /// The digest of `core` as the engine computes it.
    static func digest(_ core: Core) throws -> String {
        var builder: DigestBuilder = DigestBuilder(domain: Core.experienceID)
        try core.writeDigest(into: &builder)
        return builder.finish().hex
    }

    /// The case of `core`: its snapshot with `Choice.initial(play).clamped(to: play)` at time 1 s.
    static func drawn(_ core: Core) -> Case {
        let choice: Choice = Choice.initial(core.play).clamped(to: core.play)
        return Case(core: core, snapshot: core.snapshot(choice: choice, time: 1))
    }

    /// Certified level `number` after its first certified cut, and won through the whole certified solution when that
    /// is a different state.
    static func cases(_ number: Int) throws -> [Case] {
        let actions: [FacetedForgeAction] = Core.certifiedActions(number)
        try #require(!actions.isEmpty)
        var core: Core = try Core.opening(number: number)
        #expect(core.apply(cutAction(actions[0])) == .accepted)
        var result: [Case] = [drawn(core)]
        guard actions.count > 1 else { return result }
        var index: Int = 1
        while index < actions.count {
            #expect(core.apply(cutAction(actions[index])) == .accepted)
            index += 1
        }
        #expect(core.play.stage == .won)
        result.append(drawn(core))
        return result
    }

    /// `c` drawn with a preview that faces the authored eye: the chosen piece of the initial choice, the direction of
    /// the 13 whose unit vector has the largest |dot| with the authored eye direction among those crossing that piece
    /// (ties to the lower index), at its middle crossing depth. The initial direction (x) is seen edge-on from the
    /// authored camera, so its projected preview is all rim; the tests of plane taps need a plane that shows.
    static func facing(_ c: Case) -> Case {
        let piece: Int = c.snapshot.choice.piece
        let eye: SIMD3<Double> = Orbit.authored.eyeDirection
        var best: Choice = c.snapshot.choice
        var bestDot: Double = -1
        var index: Int = 0
        while index < FacetedForgeDirection.all.count {
            let d: FacetedForgeDirection = FacetedForgeDirection.all[index]
            let v: SIMD3<Double> = SIMD3(Double(d.x), Double(d.y), Double(d.z))
            let length: Double = (v * v).sum().squareRoot()
            let value: Double = abs((v * eye).sum()) / length
            let depths: [Int] = FacetedForgeSolver.crossingDepths(c.play.pieces[piece], direction: index)
            if !depths.isEmpty && value > bestDot {
                bestDot = value
                best = Choice(piece: piece, direction: index, depth: depths[depths.count / 2])
            }
            index += 1
        }
        return Case(core: c.core, snapshot: c.core.snapshot(choice: best, time: 1))
    }

    /// Every case of ``levels``.
    static func allCases() throws -> [Case] {
        var all: [Case] = []
        for number in levels { all += try cases(number) }
        return all
    }

    // MARK: Projection and targets

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

    /// The pick of `point` (the oracle, reduce motion off as the controller picks).
    static func pick(_ point: Vec2, snapshot: Snapshot, view: Vec2, orbit: Orbit) -> FacetedForgePick {
        Picker.pick(SIMD2(point.x, point.y), size: SIMD2(view.x, view.y), snapshot: snapshot, orbit: orbit,
                    reduceMotion: false)
    }

    /// A view point that picks the plane: of a 13 × 13 grid over the projected opened preview polygon's bounds, the
    /// point nearest the projected opened preview centre that picks ``FacetedForgePick/plane``; nil without a preview
    /// or when no grid point does (the rim's 22-point band covers a small preview).
    static func planePoint(_ snapshot: Snapshot, view: Vec2, orbit: Orbit) -> Vec2? {
        guard let centre = Geometry.previewCentre(snapshot, reduceMotion: false),
              let middle = screen(centre, snapshot: snapshot, view: view, orbit: orbit) else { return nil }
        let shift: SIMD3<Double> = Geometry.offset(piece: snapshot.choice.piece, snapshot, reduceMotion: false)
        var low: Vec2 = middle
        var high: Vec2 = middle
        for corner in snapshot.preview {
            guard let p = screen(corner + shift, snapshot: snapshot, view: view, orbit: orbit) else { return nil }
            low = Vec2(min(low.x, p.x), min(low.y, p.y))
            high = Vec2(max(high.x, p.x), max(high.y, p.y))
        }
        var best: Vec2?
        var bestDistance: Double = .infinity
        var i: Int = 0
        while i <= 12 {
            var j: Int = 0
            while j <= 12 {
                let p: Vec2 = Vec2(low.x + (high.x - low.x) * Double(i) / 12, low.y + (high.y - low.y) * Double(j) / 12)
                let distance: Double = (p - middle).length
                if distance < bestDistance, p.x > 1, p.y > 1, p.x < view.x - 1, p.y < view.y - 1,
                   pick(p, snapshot: snapshot, view: view, orbit: orbit) == .plane {
                    best = p
                    bestDistance = distance
                }
                j += 1
            }
            i += 1
        }
        return best
    }

    /// A view point that picks piece `piece`: its projected opened centre, else the first of the points halfway and
    /// four fifths from that centre to each opened corner that picks it; nil when none does.
    static func piecePoint(_ piece: Int, snapshot: Snapshot, view: Vec2, orbit: Orbit) -> Vec2? {
        let centre: SIMD3<Double> = Geometry.pieceCentre(piece, snapshot, reduceMotion: false)
        let shift: SIMD3<Double> = Geometry.offset(piece: piece, snapshot, reduceMotion: false)
        var worlds: [SIMD3<Double>] = [centre]
        for t in [0.5, 0.8] {
            for corner in snapshot.pieces[piece].corners { worlds.append(centre + (corner + shift - centre) * t) }
        }
        for world in worlds {
            guard let p = screen(world, snapshot: snapshot, view: view, orbit: orbit),
                  p.x > 1, p.y > 1, p.x < view.x - 1, p.y < view.y - 1 else { continue }
            if pick(p, snapshot: snapshot, view: view, orbit: orbit) == .piece(piece) { return p }
        }
        return nil
    }

    /// A point on the projected outline of the opened preview polygon that picks the rim and lies at least 30 points
    /// inside the view: the first of 8 points along each edge starting at edge `first`; nil when none does.
    static func rimPoint(_ snapshot: Snapshot, view: Vec2, orbit: Orbit, first: Int) -> Vec2? {
        let shift: SIMD3<Double> = Geometry.offset(piece: snapshot.choice.piece, snapshot, reduceMotion: false)
        var outline: [Vec2] = []
        for corner in snapshot.preview {
            guard let p = screen(corner + shift, snapshot: snapshot, view: view, orbit: orbit) else { return nil }
            outline.append(p)
        }
        guard outline.count >= 3 else { return nil }
        var e: Int = 0
        while e < outline.count {
            let edge: Int = (first + e) % outline.count
            let a: Vec2 = outline[edge]
            let b: Vec2 = outline[(edge + 1) % outline.count]
            var i: Int = 0
            while i < 8 {
                let t: Double = (Double(i) + 0.5) / 8
                let p: Vec2 = a + (b - a) * t
                if p.x > 30, p.y > 30, p.x < view.x - 30, p.y < view.y - 30,
                   pick(p, snapshot: snapshot, view: view, orbit: orbit) == .rim {
                    return p
                }
                i += 1
            }
            e += 1
        }
        return nil
    }

    /// A point that picks empty space: the first of the view's corners (4 points in) that does.
    static func emptyPoint(_ snapshot: Snapshot, view: Vec2, orbit: Orbit) -> Vec2? {
        let corners: [Vec2] = [Vec2(4, 4), Vec2(view.x - 4, 4), Vec2(4, view.y - 4), Vec2(view.x - 4, view.y - 4)]
        for c in corners where pick(c, snapshot: snapshot, view: view, orbit: orbit) == .empty { return c }
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

    /// What one finger produced: the actions, the state after touch-down and the candidate before the release.
    struct Outcome {
        var actions: [Action]
        var state: Controller.State
        var candidate: Choice?
    }

    /// Feeds one finger along `points` at `times` (began, moved …, ended).
    static func run(_ controller: inout Controller, _ points: [Vec2], _ times: [Double], view: Vec2,
                    snapshot: Snapshot, play: FacetedForgePlay, id: Int = 1) -> Outcome {
        var outcome: Outcome = Outcome(actions: [], state: .idle, candidate: nil)
        var index: Int = 0
        while index < points.count {
            let phase: PointerPhase = index == 0 ? .began : (index == points.count - 1 ? .ended : .moved)
            outcome.actions += controller.handle(event(id, phase, points[index], times[index]), viewSize: view,
                                                 snapshot: snapshot, play: play)
            if index == 0 { outcome.state = controller.state }
            if index == points.count - 2 { outcome.candidate = controller.candidate }
            index += 1
        }
        return outcome
    }

    /// A tap (touch-down and lift at `point`, 0.05 s apart, starting at `time`).
    static func tap(_ controller: inout Controller, _ point: Vec2, at time: Double, view: Vec2,
                    snapshot: Snapshot, play: FacetedForgePlay) -> [Action] {
        run(&controller, [point, point], [time, time + 0.05], view: view, snapshot: snapshot, play: play).actions
    }

    /// Two fingers about the view centre move their midpoint by `move` points and lift; returns the actions sent.
    static func twoFingers(_ controller: inout Controller, by move: Vec2, view: Vec2, snapshot: Snapshot,
                           play: FacetedForgePlay, time: Double) -> [Action] {
        let a: Vec2 = Vec2(view.x * 0.4, view.y * 0.5)
        let b: Vec2 = Vec2(view.x * 0.6, view.y * 0.5)
        let frame: Double = 1.0 / 60
        var actions: [Action] = controller.handle(event(7, .began, a, time), viewSize: view, snapshot: snapshot,
                                                  play: play)
        actions += controller.handle(event(8, .began, b, time + frame), viewSize: view, snapshot: snapshot,
                                     play: play)
        actions += controller.handle(event(7, .moved, a + move, time + 2 * frame), viewSize: view,
                                     snapshot: snapshot, play: play)
        actions += controller.handle(event(8, .moved, b + move, time + 3 * frame), viewSize: view,
                                     snapshot: snapshot, play: play)
        actions += controller.handle(event(7, .ended, a + move, time + 4 * frame), viewSize: view,
                                     snapshot: snapshot, play: play)
        actions += controller.handle(event(8, .ended, b + move, time + 5 * frame), viewSize: view,
                                     snapshot: snapshot, play: play)
        return actions
    }

    /// A controller turned to `orbit` by a two-finger drag in `view`.
    static func controller(at orbit: Orbit, view: Vec2, snapshot: Snapshot, play: FacetedForgePlay) -> Controller {
        var controller: Controller = Controller()
        let move: Vec2 = Vec2(orbit.yaw / (Double.pi / 2) * view.x,
                              -(orbit.pitch - Orbit.authored.pitch) / (Double.pi / 3) * view.y)
        let actions: [Action] = twoFingers(&controller, by: move, view: view, snapshot: snapshot, play: play,
                                           time: 0)
        #expect(actions.isEmpty)
        #expect(abs(controller.orbit.yaw - orbit.yaw) < 1e-9 && abs(controller.orbit.pitch - orbit.pitch) < 1e-9)
        #expect(controller.state == .idle && controller.candidate == nil)
        return controller
    }

    // MARK: Independent expectation

    /// What a one-finger script must send and preview.
    struct Expectation {
        var actions: [Action]
        var state: Controller.State
        var candidate: Choice?
        var pick: FacetedForgePick
    }

    /// The choice a drag of `drag` points from `pick` makes (the picker as the oracle for the tilt and the steps), or
    /// nil when the pick drags nothing.
    static func dragged(_ pick: FacetedForgePick, drag: SIMD2<Double>, snapshot: Snapshot, play: FacetedForgePlay,
                        view: Vec2, orbit: Orbit) -> Choice? {
        let size: SIMD2<Double> = SIMD2(view.x, view.y)
        switch pick {
        case .rim:
            return Picker.tilt(snapshot.choice, drag: drag, size: size, snapshot: snapshot, play: play, orbit: orbit)
        case .plane:
            let steps: Int = Picker.depthSteps(drag: drag, size: size, snapshot: snapshot, orbit: orbit,
                                               reduceMotion: false)
            return snapshot.choice.steppingDepth(steps, in: play)
        case .piece, .empty:
            return nil
        }
    }

    /// The expectation for one finger along `points` at `times` on a fresh controller at `orbit` (scripts never pair
    /// into double taps or double commits: each runs on a fresh controller).
    static func expected(_ points: [Vec2], _ times: [Double], snapshot: Snapshot, play: FacetedForgePlay,
                         view: Vec2, orbit: Orbit) -> Expectation {
        let down: Vec2 = points[0]
        var travel: Double = 0
        for p in points { travel = max(travel, (p - down).length) }
        var before: Double = 0
        var i: Int = 0
        while i < points.count - 1 {
            before = max(before, (points[i] - down).length)
            i += 1
        }
        let duration: Double = times[times.count - 1] - times[0]
        let picked: FacetedForgePick = pick(down, snapshot: snapshot, view: view, orbit: orbit)
        let state: Controller.State
        switch picked {
        case .rim: state = .rimDrag
        case .plane: state = .planePress
        case .piece: state = .piecePress
        case .empty: state = .idle
        }
        let penultimate: Vec2 = points[points.count - 2]
        let last: Vec2 = points[points.count - 1]
        let candidate: Choice? = before >= 10
            ? dragged(picked, drag: SIMD2(penultimate.x - down.x, penultimate.y - down.y), snapshot: snapshot,
                      play: play, view: view, orbit: orbit) : nil
        var actions: [Action] = []
        if travel >= 16 {
            if let chosen = dragged(picked, drag: SIMD2(last.x - down.x, last.y - down.y), snapshot: snapshot,
                                    play: play, view: view, orbit: orbit) {
                actions = [.choose(chosen)]
            }
        } else if travel < 10 && duration <= 0.5 {
            let choice: Choice = snapshot.choice
            switch picked {
            case .piece(let k):
                // The middle of the depths whose plane crosses piece k's interior in the current direction.
                let depths: [Int] = FacetedForgeSolver.crossingDepths(play.pieces[k], direction: choice.direction)
                var depth: Int = choice.depth
                if !depths.isEmpty { depth = depths[depths.count / 2] }
                actions = [.choose(Choice(piece: k, direction: choice.direction, depth: depth))]
            case .plane:
                if play.stage == .playing { actions = [.cut(choice.piece, choice.direction, choice.depth)] }
            case .rim, .empty:
                actions = []
            }
        }
        return Expectation(actions: actions, state: state, candidate: candidate, pick: picked)
    }

    /// A random scripted touch of kind 0 … 5: a rim drag, a plane tap or press, a plane drag (8 … 160 points), a piece
    /// tap or press, a short touch on the rim (0 … 20 points), a random touch anywhere.
    static func script(_ kind: Int, snapshot: Snapshot, view: Vec2, orbit: Orbit, start: Double,
                       random: inout SeededRandom) -> (points: [Vec2], times: [Double]) {
        let centre: Vec2 = Vec2(view.x / 2, view.y / 2)
        let direction: Double = unit(&random) * 2 * Double.pi
        let heading: Vec2 = Vec2(cos(direction), sin(direction))
        var duration: Double = 0.05 + unit(&random) * 0.4
        var points: [Vec2] = []
        switch kind {
        case 0, 4:
            let from: Vec2 = rimPoint(snapshot, view: view, orbit: orbit, first: below(8, &random)) ?? centre
            let length: Double = kind == 0 ? 16 + unit(&random) * 200 : unit(&random) * 20
            var i: Int = 0
            while i <= 6 {
                points.append(inside(from + heading * (length * Double(i) / 6), view))
                i += 1
            }
        case 1, 3:
            var target: Vec2 = centre
            if kind == 1, let p = planePoint(snapshot, view: view, orbit: orbit) { target = inside(p, view) }
            if kind == 3, let p = piecePoint(below(snapshot.pieces.count, &random), snapshot: snapshot, view: view,
                                             orbit: orbit) {
                target = inside(p, view)
            }
            points = [target, inside(target + heading * (unit(&random) * 13), view)]
            duration = 0.05 + unit(&random) * 0.8
        case 2:
            let from: Vec2 = inside(planePoint(snapshot, view: view, orbit: orbit) ?? centre, view)
            let length: Double = 8 + unit(&random) * 152
            var i: Int = 0
            while i <= 4 {
                points.append(inside(from + heading * (length * Double(i) / 4), view))
                i += 1
            }
        default:
            let a: Vec2 = Vec2(unit(&random) * view.x, unit(&random) * view.y)
            let b: Vec2 = unit(&random) < 0.5 ? a : Vec2(unit(&random) * view.x, unit(&random) * view.y)
            points = [inside(a, view), inside(b, view)]
        }
        var times: [Double] = []
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

    /// The counting key of an action sent after a touch-down on `pick`.
    static func key(_ action: Action, pick: FacetedForgePick) -> String {
        switch action {
        case .cut: return "cut"
        case .resetView: return "resetView"
        case .choose:
            switch pick {
            case .rim: return "tilt"
            case .plane: return "depth"
            case .piece: return "piece"
            case .empty: return "chooseEmpty"
            }
        }
    }

    // MARK: Tests

    @Test func seededScriptsMatchTheIndependentExpectation() throws {
        // Each certified state drawn with the initial choice and with a choice that faces the authored eye.
        var all: [Case] = []
        for c in try Self.allCases() {
            all.append(c)
            all.append(Self.facing(c))
        }
        var stages: Set<String> = []
        for c in all { stages.insert(c.play.stage.rawValue) }
        #expect(stages.contains("playing") && stages.contains("won"), "\(stages)")
        var random: SeededRandom = SeededRandom(seed: Self.seed)
        var counts: [String: Int] = [:]
        var mismatches: Int = 0
        var script: Int = 0
        while script < 500 {
            let c: Case = all[Self.below(all.count, &random)]
            let view: Vec2 = Self.views[Self.below(Self.views.count, &random)]
            let target: Orbit = Self.orbits[Self.below(Self.orbits.count, &random)]
            var controller: Controller = Self.controller(at: target, view: view, snapshot: c.snapshot, play: c.play)
            let orbit: Orbit = controller.orbit
            let kind: Int = script % 6
            let touch: (points: [Vec2], times: [Double]) =
                Self.script(kind, snapshot: c.snapshot, view: view, orbit: orbit, start: 10, random: &random)
            let want: Expectation = Self.expected(touch.points, touch.times, snapshot: c.snapshot, play: c.play,
                                                  view: view, orbit: orbit)
            let got: Outcome = Self.run(&controller, touch.points, touch.times, view: view, snapshot: c.snapshot,
                                        play: c.play)
            if got.actions != want.actions || got.state != want.state || got.candidate != want.candidate {
                mismatches += 1
                if mismatches <= 5 {
                    Issue.record(Comment(rawValue: "script \(script) kind \(kind) pick \(want.pick): \(got.actions) "
                        + "\(got.state) \(String(describing: got.candidate)) expected \(want.actions) \(want.state) "
                        + "\(String(describing: want.candidate))"))
                }
            }
            #expect(got.actions.count <= 1)
            #expect(controller.state == .idle && controller.candidate == nil)
            #expect(controller.orbit == orbit)
            for a in got.actions {
                if case .cut = a, c.play.stage != .playing { Issue.record("a cut on a finished play") }
                counts[Self.key(a, pick: want.pick), default: 0] += 1
            }
            script += 1
        }
        #expect(mismatches == 0)
        for key in ["cut", "tilt", "depth", "piece"] {
            #expect((counts[key] ?? 0) > 0, "no \(key) in 500 scripts: \(counts)")
        }
        #expect(counts["resetView"] == nil && counts["chooseEmpty"] == nil, "\(counts)")
    }

    @Test func aPieceTapChoosesTheMiddleDepthAndAPlaneTapCuts() throws {
        let c: Case = Self.facing(try Self.cases(21)[0])
        try #require(c.play.stage == .playing)
        let view: Vec2 = Self.views[1]
        var controller: Controller = Controller()
        var chosen: Int = 0
        var index: Int = 0
        while index < c.snapshot.pieces.count {
            if let p = Self.piecePoint(index, snapshot: c.snapshot, view: view, orbit: .authored),
               Self.pick(p, snapshot: c.snapshot, view: view, orbit: .authored) == .piece(index) {
                let got: [Action] = Self.tap(&controller, p, at: Double(index), view: view, snapshot: c.snapshot,
                                             play: c.play)
                #expect(got.count == 1)
                if case .choose(let choice) = got.first {
                    #expect(choice.piece == index && choice.direction == c.snapshot.choice.direction)
                    let depths: [Int] = FacetedForgeSolver.crossingDepths(c.play.pieces[index],
                                                                          direction: choice.direction)
                    if !depths.isEmpty {
                        var below: Int = 0
                        var above: Int = 0
                        for d in depths {
                            if d < choice.depth { below += 1 }
                            if d > choice.depth { above += 1 }
                        }
                        #expect(depths.contains(choice.depth) && (below == above || below == above + 1))
                    }
                } else {
                    Issue.record("a piece tap sent \(got)")
                }
                chosen += 1
            }
            index += 1
        }
        #expect(chosen >= 1)
        // A plane tap cuts the touch-down choice, accepted by the adapter exactly as a direct cut.
        let plane: Vec2 = try #require(Self.planePoint(c.snapshot, view: view, orbit: .authored))
        try #require(Self.pick(plane, snapshot: c.snapshot, view: view, orbit: .authored) == .plane)
        let got: [Action] = Self.tap(&controller, plane, at: 50, view: view, snapshot: c.snapshot, play: c.play)
        let choice: Choice = c.snapshot.choice
        #expect(got == [.cut(choice.piece, choice.direction, choice.depth)])
        var core: Core = c.core
        let before: String = try Self.digest(core)
        #expect(core.apply(Self.action("piece.cut", [Double(choice.piece), Double(choice.direction),
                                                      Double(choice.depth)])) == .accepted)
        #expect(try Self.digest(core) != before)
    }

    @Test func tenToSixteenPointsSendNothing() throws {
        let c: Case = Self.facing(try Self.cases(1)[0])
        let view: Vec2 = Self.views[0]
        let plane: Vec2 = try #require(Self.planePoint(c.snapshot, view: view, orbit: .authored))
        try #require(Self.pick(plane, snapshot: c.snapshot, view: view, orbit: .authored) == .plane)
        var piece: Vec2?
        var pieceIndex: Int = 0
        var index: Int = 0
        while index < c.snapshot.pieces.count && piece == nil {
            if let p = Self.piecePoint(index, snapshot: c.snapshot, view: view, orbit: .authored),
               Self.pick(p, snapshot: c.snapshot, view: view, orbit: .authored) == .piece(index) {
                piece = p
                pieceIndex = index
            }
            index += 1
        }
        var starts: [Vec2] = [plane]
        if let piece { starts.append(piece) }
        for start in starts {
            for length in [10.0, 12.0, 15.9] {
                var controller: Controller = Controller()
                let end: Vec2 = start + Vec2(length, 0)
                let got: Outcome = Self.run(&controller, [start, end, end], [0, 0.1, 0.2], view: view,
                                            snapshot: c.snapshot, play: c.play)
                #expect(got.actions.isEmpty, "\(length) points: \(got.actions)")
                #expect(controller.candidate == nil && controller.state == .idle)
            }
            var controller: Controller = Controller()
            let near: Vec2 = start + Vec2(9.9, 0)
            let got: [Action] = Self.run(&controller, [start, near, near], [0, 0.1, 0.2], view: view,
                                         snapshot: c.snapshot, play: c.play).actions
            #expect(got.count == (c.play.stage == .playing || start != plane ? 1 : 0), "\(got)")
            if start != plane, case .choose(let choice) = got.first { #expect(choice.piece == pieceIndex) }
            // A press longer than 0.5 s is not a tap.
            #expect(Self.run(&controller, [start, start], [5, 5.6], view: view, snapshot: c.snapshot,
                             play: c.play).actions.isEmpty)
        }
    }

    @Test func aDoubleTapOnThePlaneCutsOnce() throws {
        let c: Case = Self.facing(try Self.cases(61)[0])
        try #require(c.play.stage == .playing)
        let view: Vec2 = Self.views[2]
        let plane: Vec2 = try #require(Self.planePoint(c.snapshot, view: view, orbit: .authored))
        try #require(Self.pick(plane, snapshot: c.snapshot, view: view, orbit: .authored) == .plane)
        let choice: Choice = c.snapshot.choice
        let cut: Action = .cut(choice.piece, choice.direction, choice.depth)
        var controller: Controller = Controller()
        #expect(Self.tap(&controller, plane, at: 1, view: view, snapshot: c.snapshot, play: c.play) == [cut])
        #expect(Self.tap(&controller, plane, at: 1.2, view: view, snapshot: c.snapshot, play: c.play).isEmpty)
        // Later than 0.35 s after the commit's lift: a new commit.
        #expect(Self.tap(&controller, plane, at: 1.7, view: view, snapshot: c.snapshot, play: c.play) == [cut])
        #expect(Self.tap(&controller, plane, at: 1.9, view: view, snapshot: c.snapshot, play: c.play).isEmpty)
        #expect(Self.tap(&controller, plane, at: 3, view: view, snapshot: c.snapshot, play: c.play) == [cut])
    }

    @Test func secondFingersCancelsAndFinishedPlaysSendNoCut() throws {
        var all: [Case] = []
        for c in try Self.cases(41) { all.append(Self.facing(c)) }
        let view: Vec2 = Self.views[1]
        var finished: Int = 0
        for c in all {
            let plane: Vec2 = try #require(Self.planePoint(c.snapshot, view: view, orbit: .authored))
            let rim: Vec2 = try #require(Self.rimPoint(c.snapshot, view: view, orbit: .authored, first: 0))
            try #require(Self.pick(plane, snapshot: c.snapshot, view: view, orbit: .authored) == .plane)
            for start in [plane, rim] {
                // A second finger cancels the drag and orbits; nothing is sent when every finger lifts.
                var controller: Controller = Controller()
                let far: Vec2 = start + Vec2(60, 40)
                var actions: [Action] = controller.handle(Self.event(1, .began, start, 0), viewSize: view,
                                                          snapshot: c.snapshot, play: c.play)
                actions += controller.handle(Self.event(1, .moved, far, 0.1), viewSize: view, snapshot: c.snapshot,
                                             play: c.play)
                #expect(controller.candidate != nil)
                #expect(controller.state == (start == rim ? .rimDrag : .depthDrag))
                actions += controller.handle(Self.event(2, .began, Vec2(10, 10), 0.2), viewSize: view,
                                             snapshot: c.snapshot, play: c.play)
                #expect(controller.state == .orbiting && controller.candidate == nil)
                actions += controller.handle(Self.event(2, .ended, Vec2(10, 10), 0.3), viewSize: view,
                                             snapshot: c.snapshot, play: c.play)
                #expect(controller.state == .cancelled)
                actions += controller.handle(Self.event(1, .moved, start, 0.35), viewSize: view,
                                             snapshot: c.snapshot, play: c.play)
                actions += controller.handle(Self.event(1, .ended, start, 0.4), viewSize: view,
                                             snapshot: c.snapshot, play: c.play)
                #expect(actions.isEmpty)
                #expect(controller.state == .idle)
                // A tap with a second finger: nothing.
                actions = controller.handle(Self.event(3, .began, start, 1), viewSize: view, snapshot: c.snapshot,
                                            play: c.play)
                actions += controller.handle(Self.event(4, .began, start + Vec2(50, 0), 1.05), viewSize: view,
                                             snapshot: c.snapshot, play: c.play)
                actions += controller.handle(Self.event(3, .ended, start, 1.1), viewSize: view,
                                             snapshot: c.snapshot, play: c.play)
                actions += controller.handle(Self.event(4, .ended, start + Vec2(50, 0), 1.15), viewSize: view,
                                             snapshot: c.snapshot, play: c.play)
                #expect(actions.isEmpty && controller.state == .idle)
                // A `.cancelled` phase sends nothing, a drag or a tap.
                actions = controller.handle(Self.event(5, .began, start, 2), viewSize: view, snapshot: c.snapshot,
                                            play: c.play)
                actions += controller.handle(Self.event(5, .moved, far, 2.1), viewSize: view, snapshot: c.snapshot,
                                             play: c.play)
                actions += controller.handle(Self.event(5, .cancelled, far, 2.2), viewSize: view,
                                             snapshot: c.snapshot, play: c.play)
                actions += controller.handle(Self.event(6, .began, start, 3), viewSize: view, snapshot: c.snapshot,
                                             play: c.play)
                actions += controller.handle(Self.event(6, .cancelled, start, 3.05), viewSize: view,
                                             snapshot: c.snapshot, play: c.play)
                #expect(actions.isEmpty)
                #expect(controller.state == .idle && controller.candidate == nil)
                // `cancel()` mid-gesture: the release afterwards is unknown and sends nothing.
                actions = controller.handle(Self.event(9, .began, start, 4), viewSize: view, snapshot: c.snapshot,
                                            play: c.play)
                controller.cancel()
                actions += controller.handle(Self.event(9, .ended, start, 4.05), viewSize: view,
                                             snapshot: c.snapshot, play: c.play)
                #expect(actions.isEmpty && controller.state == .idle)
            }
            guard c.play.stage != .playing else { continue }
            finished += 1
            // A finished play: a plane tap sends no cut; tilting, sliding and choosing still work.
            var controller: Controller = Controller()
            #expect(Self.tap(&controller, plane, at: 10, view: view, snapshot: c.snapshot, play: c.play).isEmpty)
            let tilt: [Action] = Self.run(&controller, [rim, rim + Vec2(0, 120), rim + Vec2(0, 120)],
                                          [11, 11.1, 11.2], view: view, snapshot: c.snapshot, play: c.play).actions
            let tilted: Choice = Picker.tilt(c.snapshot.choice, drag: SIMD2(0, 120), size: SIMD2(view.x, view.y),
                                             snapshot: c.snapshot, play: c.play, orbit: .authored)
            #expect(tilt == [.choose(tilted)])
            let slide: [Action] = Self.run(&controller, [plane, plane + Vec2(80, 0), plane + Vec2(80, 0)],
                                           [12, 12.1, 12.2], view: view, snapshot: c.snapshot, play: c.play).actions
            #expect(slide.count == 1)
            for a in tilt + slide {
                if case .cut = a { Issue.record("a cut on a finished play") }
            }
        }
        #expect(finished >= 1)
    }

    @Test func aDoubleTapOnEmptySpaceResetsTheView() throws {
        let all: [Case] = try Self.cases(81)
        let view: Vec2 = Self.views[0]
        for c in all {
            let turned: Orbit = Orbit(yaw: 0.3, pitch: 0.9)
            var controller: Controller = Self.controller(at: turned, view: view, snapshot: c.snapshot, play: c.play)
            let corner: Vec2 = try #require(Self.emptyPoint(c.snapshot, view: view, orbit: controller.orbit))
            // Too slow (0.4 s between lifts): nothing.
            #expect(Self.tap(&controller, corner, at: 1, view: view, snapshot: c.snapshot, play: c.play).isEmpty)
            #expect(Self.tap(&controller, corner, at: 1.4, view: view, snapshot: c.snapshot, play: c.play).isEmpty)
            #expect(abs(controller.orbit.yaw - 0.3) < 1e-9)
            #expect(Self.tap(&controller, corner, at: 1.6, view: view, snapshot: c.snapshot, play: c.play)
                    == [.resetView])
            #expect(controller.orbit == .authored)
            // Two lifts 30 points apart are not a double tap.
            controller = Self.controller(at: turned, view: view, snapshot: c.snapshot, play: c.play)
            let apart: Vec2 = corner + Vec2(corner.x < view.x / 2 ? 30 : -30, 0)
            try #require(Self.pick(apart, snapshot: c.snapshot, view: view, orbit: controller.orbit) == .empty)
            _ = Self.tap(&controller, corner, at: 2, view: view, snapshot: c.snapshot, play: c.play)
            #expect(Self.tap(&controller, apart, at: 2.1, view: view, snapshot: c.snapshot, play: c.play).isEmpty)
            #expect(abs(controller.orbit.yaw - 0.3) < 1e-9)
            // A one-finger drag on empty space does not orbit.
            let moved: [Action] = Self.run(&controller, [corner, corner + Vec2(0, 200), corner + Vec2(0, 200)],
                                           [3, 3.1, 3.2], view: view, snapshot: c.snapshot, play: c.play).actions
            #expect(moved.isEmpty && abs(controller.orbit.yaw - 0.3) < 1e-9)
        }
    }

    @Test func orbitFollowsClampsAndRebases() throws {
        let c: Case = Self.facing(try Self.cases(1)[0])
        let view: Vec2 = Self.views[1]
        var controller: Controller = Controller()
        #expect(Controller.yawPerViewWidth == Double.pi / 2 && Controller.pitchPerViewHeight == Double.pi / 3)
        #expect(Controller.tapDistance == 10 && Controller.dragDistance == 16 && Controller.tapDuration == 0.5
                && Controller.doubleTapWindow == 0.35)
        // A quarter width right turns 22.5° yaw; a tenth of the height up adds 6° pitch (30° → 36°).
        var actions: [Action] = Self.twoFingers(&controller, by: Vec2(view.x * 0.25, -view.y * 0.1), view: view,
                                                snapshot: c.snapshot, play: c.play, time: 0)
        let degree: Double = Double.pi / 180
        #expect(abs(controller.orbit.yaw - 22.5 * degree) < 1e-9)
        #expect(abs(controller.orbit.pitch - 36 * degree) < 1e-9)
        // Far moves clamp.
        actions += Self.twoFingers(&controller, by: Vec2(view.x * 3, -view.y * 3), view: view, snapshot: c.snapshot,
                                   play: c.play, time: 1)
        #expect(abs(controller.orbit.yaw - Orbit.yawLimit) < 1e-12)
        #expect(abs(controller.orbit.pitch - Orbit.pitchRange.upperBound) < 1e-12)
        actions += Self.twoFingers(&controller, by: Vec2(-view.x * 3, view.y * 3), view: view, snapshot: c.snapshot,
                                   play: c.play, time: 2)
        #expect(abs(controller.orbit.yaw + Orbit.yawLimit) < 1e-12)
        #expect(abs(controller.orbit.pitch - Orbit.pitchRange.lowerBound) < 1e-12)
        #expect(actions.isEmpty)
        controller.resetView()
        #expect(controller.orbit == .authored)
        // A third finger re-bases the midpoint: the camera does not jump.
        _ = controller.handle(Self.event(1, .began, Vec2(100, 400), 3), viewSize: view, snapshot: c.snapshot,
                              play: c.play)
        _ = controller.handle(Self.event(2, .began, Vec2(300, 400), 3.1), viewSize: view, snapshot: c.snapshot,
                              play: c.play)
        _ = controller.handle(Self.event(3, .began, Vec2(900, 100), 3.2), viewSize: view, snapshot: c.snapshot,
                              play: c.play)
        #expect(controller.orbit == .authored)
        #expect(controller.state == .orbiting)
        _ = controller.handle(Self.event(3, .moved, Vec2(930, 100), 3.3), viewSize: view, snapshot: c.snapshot,
                              play: c.play)
        #expect(abs(controller.orbit.yaw - 10.0 / view.x * Double.pi / 2) < 1e-9)
        #expect(controller.camera(viewSize: view, snapshot: c.snapshot)
                == Geometry.camera(c.snapshot, aspect: view.x / view.y, orbit: controller.orbit))
        #expect(controller.camera(viewSize: Vec2(0, 100), snapshot: c.snapshot) == nil)
    }

    @Test func choicesAndOrbitNeverChangeTheDigest() throws {
        var random: SeededRandom = SeededRandom(seed: Self.seed + 1)
        let all: [Case] = try Self.allCases()
        for c in all {
            let before: String = try Self.digest(c.core)
            let view: Vec2 = Self.views[Self.below(Self.views.count, &random)]
            var controller: Controller = Controller()
            _ = Self.twoFingers(&controller, by: Vec2(Self.unit(&random) * 400 - 200, Self.unit(&random) * 400 - 200),
                                view: view, snapshot: c.snapshot, play: c.play, time: 0)
            var sent: [Action] = []
            var kind: Int = 0
            while kind < 6 {
                let touch: (points: [Vec2], times: [Double]) =
                    Self.script(kind, snapshot: c.snapshot, view: view, orbit: controller.orbit,
                                start: 10 + Double(kind), random: &random)
                sent += Self.run(&controller, touch.points, touch.times, view: view, snapshot: c.snapshot,
                                 play: c.play).actions
                kind += 1
            }
            controller.resetView()
            for a in sent {
                switch a {
                case .choose(let choice):
                    // Drawing the chosen preview reads only.
                    let drawn: Snapshot = c.core.snapshot(choice: choice, time: 2)
                    #expect(drawn.choice.piece == choice.piece)
                case .resetView:
                    break
                case .cut:
                    break
                }
            }
            #expect(try Self.digest(c.core) == before)
        }
    }
}
