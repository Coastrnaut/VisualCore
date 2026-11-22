// NocturneGardenGestureControllerTests — feature 384 (R02-G09-04) T-R02G0904-004 (FR-R02G0904-001 … 005, 007;
// SC-R02G0904-001 … 004; clarifications Q1 … Q5). 500 seeded (seed 2_384) scripted gestures — taps on bed cells and
// blooms, bloom drags inside and off the bed, lantern drags, pinches, two-finger orbits, short touches and random
// touches — on certified levels 1, 21, 41, 61 and 81 (one move before their certified win, still playing, and won
// through the certified solution) at three view sizes and three orbits reached by two-finger drags send exactly the
// actions an independent expectation written here predicts: the pick at touch-down, the bed cells under the finger,
// the sun step and the pinch size come from `NocturneGardenPicker` (the geometry oracle, tested on its own), while
// the arbitration (tap, drag or nothing by travel and duration; the grab offset; move, remove or nothing; no action on
// a finished play; pinch or orbit for a second finger; the orbit arithmetic) is computed here on its own. Every drag
// preview's cells, match and leak equal the kernel's after the corresponding move or removal on a copy of the play;
// second fingers, `.cancelled` phases, `cancel()` and finished plays send nothing; 10 … 16 points of travel send
// nothing; a double tap on empty space resets the view; previews and the orbit never change the adapter's digest.
// Plain loops and explicit types (CI type-check rule); each test well under 2 s once the levels are certified.
import Foundation
import Testing
import VisualCoreDiagnostics
import VisualCoreExperience
import VisualCoreMath
import VisualCoreScenes
import VisualCoreSimulation
@testable import NocturneGardenCore

@Suite struct NocturneGardenGestureControllerTests {
    typealias Controller = NocturneGardenGestureController
    typealias Snapshot = NocturneGardenSceneSnapshot
    typealias Action = NocturneGardenGestureAction
    typealias Geometry = NocturneGardenSceneGeometry
    typealias Picker = NocturneGardenPicker
    typealias Orbit = NocturneGardenOrbit
    typealias Core = NocturneGardenExperienceCore
    typealias Play = NocturneGardenPlay
    typealias Preview = NocturneGardenDragPreview

    /// The seed of every random choice here.
    static let seed: UInt64 = 2_384
    /// The view sizes every script runs at: phone portrait, tablet landscape, tablet portrait.
    static let views: [Vec2] = [Vec2(390, 844), Vec2(1_180, 820), Vec2(1_024, 1_366)]
    /// The scripted orbits (the first is the authored one), reached by two-finger drags.
    static let orbits: [Orbit] = [.authored, Orbit(yaw: 0.3, pitch: 0.35), Orbit(yaw: -0.5, pitch: 0.05)]
    /// The certified levels used.
    static let levels: [Int] = [1, 21, 41, 61, 81]

    // MARK: Cores and snapshots

    /// A core and the snapshot drawn of it at time 1 s.
    struct Case {
        let core: Core
        let snapshot: Snapshot
        var play: Play { core.play }
    }

    /// An adapter action.
    func action(_ control: String, _ values: [Int] = []) -> ExperienceAction {
        var doubles: [Double] = []
        for v in values { doubles.append(Double(v)) }
        return ExperienceAction(control: control, values: doubles, step: 0)
    }

    /// The adapter action of a kernel action.
    func adapterAction(_ a: NocturneGardenAction) -> ExperienceAction {
        switch a {
        case let .plant(kind, column, row, size): return action("bloom.plant", [kind.order, column, row, size])
        case let .move(bloom, column, row): return action("bloom.move", [bloom, column, row])
        case let .resize(bloom, size): return action("bloom.resize", [bloom, size])
        case let .remove(bloom): return action("bloom.remove", [bloom])
        case let .sun(elevation): return action("sun.set", [elevation])
        }
    }

    /// The adapter action of a gesture action that reaches the kernel, or nil for choose and reset view.
    func adapterAction(_ a: Action) -> ExperienceAction? {
        switch a {
        case let .plant(kind, column, row, size):
            return adapterAction(NocturneGardenAction.plant(kind, column, row, size))
        case let .move(bloom, column, row): return adapterAction(NocturneGardenAction.move(bloom, column, row))
        case let .remove(bloom): return adapterAction(NocturneGardenAction.remove(bloom))
        case let .resize(bloom, size): return adapterAction(NocturneGardenAction.resize(bloom, size))
        case let .sun(elevation): return adapterAction(NocturneGardenAction.sun(elevation))
        case .choose, .resetView: return nil
        }
    }

    /// The digest of `core` as the engine computes it.
    func digest(_ core: Core) throws -> String {
        var builder: DigestBuilder = DigestBuilder(domain: Core.experienceID)
        try core.writeDigest(into: &builder)
        return builder.finish().hex
    }

    /// The case of `core`, drawn at time 1 s.
    func drawn(_ core: Core) -> Case {
        Case(core: core, snapshot: core.snapshot(time: 1))
    }

    /// Certified level `number` one action before its certified win (still playing) and after it (won).
    func cases(_ number: Int) throws -> [Case] {
        let actions: [NocturneGardenAction] = try Core.generated(number: number).solution.actions
        try #require(!actions.isEmpty)
        var core: Core = try Core.opening(number: number)
        var index: Int = 0
        while index < actions.count - 1 {
            #expect(core.apply(adapterAction(actions[index])) == .accepted)
            index += 1
        }
        #expect(core.play.stage == .playing)
        let playing: Case = drawn(core)
        #expect(core.apply(adapterAction(actions[actions.count - 1])) == .accepted)
        #expect(core.play.stage == .won)
        return [playing, drawn(core)]
    }

    /// Every case of ``levels``.
    func allCases() throws -> [Case] {
        var all: [Case] = []
        for number in Self.levels { all += try cases(number) }
        return all
    }

    /// The first playing case with at least one bloom, and the first won case.
    func playingAndWon() throws -> (playing: Case, won: Case) {
        var playing: Case?
        var won: Case?
        for c in try allCases() {
            if playing == nil, c.play.stage == .playing, !c.play.blooms.isEmpty { playing = c }
            if won == nil, c.play.stage == .won, !c.play.blooms.isEmpty { won = c }
        }
        return (try #require(playing), try #require(won))
    }

    // MARK: Projection and targets

    /// The view point of `world` for `snapshot` in `view` at `orbit`, or nil behind the eye.
    func screen(_ world: SIMD3<Double>, snapshot: Snapshot, view: Vec2, orbit: Orbit) -> Vec2? {
        let camera: NocturneGardenCamera = Geometry.camera(snapshot, aspect: view.x / view.y, orbit: orbit)
        guard let p = Geometry.project(world, camera: camera) else { return nil }
        return Vec2(p.x * view.x, p.y * view.y)
    }

    /// The pick of `point` (the oracle).
    func pick(_ point: Vec2, snapshot: Snapshot, view: Vec2, orbit: Orbit) -> NocturneGardenPick {
        Picker.pick(SIMD2(point.x, point.y), size: SIMD2(view.x, view.y), snapshot: snapshot, orbit: orbit)
    }

    /// The bed cell under `point` (the oracle).
    func cell(_ point: Vec2, snapshot: Snapshot, view: Vec2,
                     orbit: Orbit) -> (column: Int, row: Int, inside: Bool)? {
        Picker.bedCell(SIMD2(point.x, point.y), size: SIMD2(view.x, view.y), snapshot: snapshot, orbit: orbit)
    }

    /// The projected head centre of bloom `bloom`, kept inside the view.
    func bloomPoint(_ bloom: Int, snapshot: Snapshot, view: Vec2, orbit: Orbit) -> Vec2? {
        guard let p = screen(Picker.headCentre(bloom, snapshot), snapshot: snapshot, view: view, orbit: orbit) else {
            return nil
        }
        return inside(p, view)
    }

    /// The projected centre of bed cell `cell`, kept inside the view.
    func cellPoint(_ cell: Int, snapshot: Snapshot, view: Vec2, orbit: Orbit) -> Vec2? {
        guard let p = screen(Geometry.cellCentre(cell, snapshot), snapshot: snapshot, view: view, orbit: orbit) else {
            return nil
        }
        return inside(p, view)
    }

    /// A point that picks neither a bloom nor the lantern: the first of the view's corners (8 points in) that does.
    func emptyPoint(_ snapshot: Snapshot, view: Vec2, orbit: Orbit) -> Vec2? {
        let corners: [Vec2] = [Vec2(8, 8), Vec2(8, view.y - 8), Vec2(view.x - 8, view.y - 8), Vec2(view.x - 8, 8)]
        for c in corners {
            let p: NocturneGardenPick = pick(c, snapshot: snapshot, view: view, orbit: orbit)
            if p == .outside || p == .empty { return c }
        }
        return nil
    }

    // MARK: Scripting

    /// A pointer event.
    func event(_ id: Int, _ phase: PointerPhase, _ point: Vec2, _ time: Double) -> PointerEvent {
        PointerEvent(id: id, phase: phase, location: point, timestamp: time)
    }

    /// A unit random number 0 ..< 1.
    func unit(_ random: inout SeededRandom) -> Double {
        Double(random.next() >> 11) / 9_007_199_254_740_992
    }

    /// A random whole number 0 ..< `count`.
    func below(_ count: Int, _ random: inout SeededRandom) -> Int {
        min(Int(unit(&random) * Double(count)), count - 1)
    }

    /// `p` kept one point inside `view`.
    func inside(_ p: Vec2, _ view: Vec2) -> Vec2 {
        Vec2(min(max(p.x, 1), view.x - 1), min(max(p.y, 1), view.y - 1))
    }

    /// The panel's kind and size for a script.
    struct Panel {
        let kind: NocturneGardenKind
        let size: Int
    }

    /// What one finger produced: the actions, the state after touch-down and the preview before the release.
    struct Outcome {
        var actions: [Action]
        var state: Controller.State
        var preview: Preview?
    }

    /// Feeds one finger along `points` at `times` (began, moved …, ended).
    func run(_ controller: inout Controller, _ points: [Vec2], _ times: [Double], view: Vec2,
                    c: Case, panel: Panel, id: Int = 1) -> Outcome {
        var outcome: Outcome = Outcome(actions: [], state: .idle, preview: nil)
        var index: Int = 0
        while index < points.count {
            let phase: PointerPhase = index == 0 ? .began : (index == points.count - 1 ? .ended : .moved)
            outcome.actions += controller.handle(event(id, phase, points[index], times[index]), viewSize: view,
                                                 snapshot: c.snapshot, play: c.play, kind: panel.kind,
                                                 size: panel.size)
            if index == 0 { outcome.state = controller.state }
            if index == points.count - 2 { outcome.preview = controller.preview }
            index += 1
        }
        return outcome
    }

    /// A straight path of `steps` + 1 points from `a` to `b` (each kept inside the view) at 0.05 s intervals from
    /// `time`, the end repeated 0.02 s later (the last move and the release at the same place).
    func path(_ a: Vec2, _ b: Vec2, steps: Int, view: Vec2, time: Double) -> (points: [Vec2], times: [Double]) {
        var points: [Vec2] = []
        var times: [Double] = []
        var i: Int = 0
        while i <= steps {
            let t: Double = Double(i) / Double(steps)
            points.append(inside(a + (b - a) * t, view))
            times.append(time + 0.05 * Double(i))
            i += 1
        }
        points.append(points[points.count - 1])
        times.append(times[times.count - 1] + 0.02)
        return (points, times)
    }

    /// Two fingers moving their midpoint by `move` and lifting (first finger at `a`, second at `b`); returns the
    /// actions sent.
    func twoFingers(_ controller: inout Controller, a: Vec2, b: Vec2, by move: Vec2, view: Vec2, c: Case,
                           panel: Panel, time: Double) -> [Action] {
        let frame: Double = 1.0 / 60
        let evs: [PointerEvent] = [event(7, .began, a, time), event(8, .began, b, time + frame),
                                   event(7, .moved, a + move, time + 2 * frame),
                                   event(8, .moved, b + move, time + 3 * frame),
                                   event(7, .ended, a + move, time + 4 * frame),
                                   event(8, .ended, b + move, time + 5 * frame)]
        var actions: [Action] = []
        for e in evs {
            actions += controller.handle(e, viewSize: view, snapshot: c.snapshot, play: c.play, kind: panel.kind,
                                         size: panel.size)
        }
        return actions
    }

    /// Whether two orbits agree within 1e-9 radians.
    func near(_ a: Orbit, _ b: Orbit) -> Bool {
        abs(a.yaw - b.yaw) < 1e-9 && abs(a.pitch - b.pitch) < 1e-9
    }

    /// `orbit` turned by a midpoint movement of `delta` in `view` (90° per width, 60° per height, pitch up for an
    /// upward movement), clamped — computed here on its own.
    func turned(_ orbit: Orbit, by delta: Vec2, view: Vec2) -> Orbit {
        Orbit(yaw: orbit.yaw + delta.x / view.x * (Double.pi / 2),
              pitch: orbit.pitch - delta.y / view.y * (Double.pi / 3)).clamped()
    }

    /// A controller turned to `orbit` by a two-finger drag starting on empty space in `view`.
    func controller(at orbit: Orbit, view: Vec2, c: Case, panel: Panel) throws -> Controller {
        var controller: Controller = Controller()
        let a: Vec2 = try #require(emptyPoint(c.snapshot, view: view, orbit: .authored))
        let b: Vec2 = Vec2(view.x / 2, view.y / 2)
        let move: Vec2 = Vec2(orbit.yaw / (Double.pi / 2) * view.x,
                              -(orbit.pitch - Orbit.authored.pitch) / (Double.pi / 3) * view.y)
        let actions: [Action] = twoFingers(&controller, a: a, b: b, by: move, view: view, c: c, panel: panel,
                                           time: 0)
        #expect(actions.isEmpty)
        #expect(abs(controller.orbit.yaw - orbit.yaw) < 1e-9 && abs(controller.orbit.pitch - orbit.pitch) < 1e-9)
        #expect(controller.state == .idle && controller.preview == nil)
        return controller
    }

    // MARK: Independent expectation

    /// What a one-finger script must send and preview.
    struct Expectation {
        var actions: [Action]
        var state: Controller.State
        /// For a bloom drag: whether a preview shows, and its bloom, anchor and removal.
        var preview: (bloom: Int, column: Int, row: Int, removes: Bool)?
    }

    /// The expectation of one finger along `points` at `times` on case `c` in `view` at `orbit`, written on its own.
    func expected(_ points: [Vec2], _ times: [Double], c: Case, view: Vec2, orbit: Orbit,
                         panel: Panel) -> Expectation {
        let start: Vec2 = points[0]
        let end: Vec2 = points[points.count - 1]
        let picked: NocturneGardenPick = pick(start, snapshot: c.snapshot, view: view, orbit: orbit)
        var travel: Double = 0
        for p in points { travel = max(travel, (p - start).length) }
        let held: Double = times[times.count - 1] - times[0]
        let playing: Bool = c.play.stage == .playing
        var state: Controller.State
        switch picked {
        case .lantern: state = .lanternDrag
        case .bloom: state = .bloomPress
        case .cell: state = .bedPress
        case .outside, .empty: state = .idle
        }
        var result: Expectation = Expectation(actions: [], state: state, preview: nil)
        if travel >= 16 {
            switch picked {
            case .bloom(let i):
                guard let down = cell(start, snapshot: c.snapshot, view: view, orbit: orbit),
                      let now = cell(end, snapshot: c.snapshot, view: view, orbit: orbit) else { return result }
                let bloom: NocturneGardenBloom = c.play.blooms[i]
                if !now.inside {
                    result.preview = (i, now.column, now.row, true)
                    if playing { result.actions = [.remove(i)] }
                    return result
                }
                let column: Int = bloom.column + now.column - down.column
                let row: Int = bloom.row + now.row - down.row
                guard column >= 0, column < c.play.level.width, row >= 0, row < c.play.level.height else {
                    return result
                }
                result.preview = (i, column, row, false)
                if playing && (column != bloom.column || row != bloom.row) { result.actions = [.move(i, column, row)] }
            case .lantern:
                let e: Int = Picker.sunElevation(from: c.play.elevation, drag: end.y - start.y,
                                                 allowed: c.play.level.elevations.sorted())
                if playing && e != c.play.elevation { result.actions = [.sun(e)] }
            case .cell, .outside, .empty:
                break
            }
            return result
        }
        guard travel < 10, held <= 0.5 else { return result }
        switch picked {
        case .cell(let index):
            let width: Int = c.play.level.width
            if playing { result.actions = [.plant(panel.kind, index % width, index / width, panel.size)] }
        case .bloom(let i):
            result.actions = [.choose(i)]
        case .lantern, .outside, .empty:
            break
        }
        return result
    }

    /// Checks `preview` against the kernel: its cells, match and leak equal the mask of a copy of the play after the
    /// move or removal (the arrangement as it is for a move to the bloom's own anchor), and the text names them.
    func checkPreview(_ preview: Preview, play: Play) {
        var copy: Play = play
        let kernel: NocturneGardenAction = preview.removes ? .remove(preview.bloom)
            : .move(preview.bloom, preview.column, preview.row)
        let bloom: NocturneGardenBloom = play.blooms[preview.bloom]
        let own: Bool = !preview.removes && bloom.column == preview.column && bloom.row == preview.row
        var mask: NocturneGardenMask = play.mask
        if !own {
            if play.stage == .playing {
                do {
                    try copy.apply(kernel, expecting: copy.fingerprint)
                } catch {
                    Issue.record("the kernel refused \(kernel): \(error)")
                }
                mask = copy.mask
            } else {
                var blooms: [NocturneGardenBloom] = play.blooms
                if preview.removes {
                    blooms.remove(at: preview.bloom)
                } else {
                    blooms[preview.bloom] = NocturneGardenBloom(kind: bloom.kind, column: preview.column,
                                                                row: preview.row, size: bloom.size)
                }
                mask = NocturneGardenMask.union(blooms, elevation: play.elevation, width: play.level.width,
                                                height: play.level.height)
            }
        }
        #expect(preview.cells == mask.cells.sorted())
        #expect(preview.shared == mask.intersection(play.level.target))
        #expect(preview.either == mask.union(play.level.target))
        #expect(preview.leak == mask.leak(forbidden: play.level.forbidden))
        let words: String = "match \(preview.shared)/\(preview.either), leak "
            + (preview.leak == 1 ? "1 cell" : "\(preview.leak) cells")
        #expect(preview.text == (preview.removes ? "would remove: " : "would ") + words)
    }

    /// One seeded one-finger script of `kind` (0 … 6) on case `c` in `view` at `orbit` starting at `time`: points and
    /// times.
    func script(_ kind: Int, c: Case, view: Vec2, orbit: Orbit, time: Double,
                       random: inout SeededRandom) -> (points: [Vec2], times: [Double])? {
        let snapshot: Snapshot = c.snapshot
        let cells: Int = c.play.level.cellCount
        switch kind {
        case 0:   // a tap on a bed cell
            guard let p = cellPoint(below(cells, &random), snapshot: snapshot, view: view, orbit: orbit) else {
                return nil
            }
            return ([p, p], [time, time + 0.05 + 0.4 * unit(&random)])
        case 1:   // a tap on a bloom
            guard !snapshot.blooms.isEmpty,
                  let p = bloomPoint(below(snapshot.blooms.count, &random), snapshot: snapshot, view: view,
                                     orbit: orbit) else { return nil }
            let q: Vec2 = inside(p + Vec2(unit(&random) * 6 - 3, unit(&random) * 6 - 3), view)
            return ([p, q], [time, time + 0.1])
        case 2:   // a bloom drag to a bed cell
            guard !snapshot.blooms.isEmpty,
                  let p = bloomPoint(below(snapshot.blooms.count, &random), snapshot: snapshot, view: view,
                                     orbit: orbit),
                  let q = cellPoint(below(cells, &random), snapshot: snapshot, view: view, orbit: orbit) else {
                return nil
            }
            return path(p, q, steps: 4, view: view, time: time)
        case 3:   // a bloom drag off the bed
            guard !snapshot.blooms.isEmpty,
                  let p = bloomPoint(below(snapshot.blooms.count, &random), snapshot: snapshot, view: view,
                                     orbit: orbit) else { return nil }
            let height: Double = Double(c.play.level.height) * Geometry.cellSize(snapshot)
            let worlds: [SIMD3<Double>] = [SIMD3(-1.25, height * unit(&random), 0),
                                           SIMD3(1.25, height * unit(&random), 0),
                                           SIMD3(unit(&random) * 2 - 1, -0.15, 0)]
            guard let q = screen(worlds[below(worlds.count, &random)], snapshot: snapshot, view: view,
                                 orbit: orbit) else { return nil }
            return path(p, q, steps: 5, view: view, time: time)
        case 4:   // a vertical lantern drag
            guard let l = screen(Geometry.lantern(snapshot), snapshot: snapshot, view: view, orbit: orbit) else {
                return nil
            }
            let p: Vec2 = inside(l, view)
            let dy: Double = (20 + 160 * unit(&random)) * (unit(&random) < 0.5 ? -1 : 1)
            return path(p, p + Vec2(0, dy), steps: 3, view: view, time: time)
        case 5:   // a short touch of 10 … 16 points anywhere interesting
            var p: Vec2 = inside(Vec2(view.x * unit(&random), view.y * unit(&random)), view)
            if !snapshot.blooms.isEmpty && unit(&random) < 0.5,
               let b = bloomPoint(below(snapshot.blooms.count, &random), snapshot: snapshot, view: view,
                                  orbit: orbit) {
                p = b
            }
            let angle: Double = unit(&random) * 2 * Double.pi
            let length: Double = 10.5 + 5 * unit(&random)
            let q: Vec2 = p + Vec2(cos(angle) * length, sin(angle) * length)
            guard q.x > 1, q.y > 1, q.x < view.x - 1, q.y < view.y - 1 else { return nil }
            return path(p, q, steps: 2, view: view, time: time)
        default:  // a random touch
            let p: Vec2 = inside(Vec2(view.x * unit(&random), view.y * unit(&random)), view)
            let q: Vec2 = p + Vec2(unit(&random) * 60 - 30, unit(&random) * 60 - 30)
            let r: (points: [Vec2], times: [Double]) = path(p, q, steps: 2, view: view, time: time)
            let slow: Double = unit(&random) < 0.3 ? 0.6 : 0
            var times: [Double] = [r.times[0]]
            for t in r.times.dropFirst() { times.append(t + slow) }
            return (r.points, times)
        }
    }

    /// A seeded pinch script (the first finger on a bloom, or anywhere when there is none) checked against its
    /// expectation; returns the actions sent.
    func pinchScript(_ controller: inout Controller, c: Case, view: Vec2, orbit: Orbit, panel: Panel, run: Int,
                     random: inout SeededRandom) -> [Action] {
        var p: Vec2 = inside(Vec2(view.x * unit(&random), view.y * unit(&random)), view)
        if !c.snapshot.blooms.isEmpty,
           let b = bloomPoint(below(c.snapshot.blooms.count, &random), snapshot: c.snapshot, view: view, orbit: orbit) {
            p = b
        }
        let side: Double = p.x + 80 < view.x - 1 ? 1 : -1
        let q: Vec2 = Vec2(p.x + 80 * side, p.y)
        let scale: Double = 0.4 + 2.2 * unit(&random)
        let q2: Vec2 = inside(Vec2(p.x + 80 * side * scale, p.y + 10 * unit(&random)), view)
        let picked: NocturneGardenPick = pick(p, snapshot: c.snapshot, view: view, orbit: orbit)
        let sizes: [Int] = c.play.level.sizes.sorted()
        var actions: [Action] = []
        actions += controller.handle(event(1, .began, p, 1), viewSize: view, snapshot: c.snapshot, play: c.play,
                                     kind: panel.kind, size: panel.size)
        actions += controller.handle(event(2, .began, q, 1.05), viewSize: view, snapshot: c.snapshot, play: c.play,
                                     kind: panel.kind, size: panel.size)
        #expect(controller.preview == nil)
        var expectedActions: [Action] = []
        var expectedOrbit: Orbit = orbit
        if case .bloom(let i) = picked {
            #expect(controller.state == .pinch)
            let found: Int = Picker.pinchSize(from: c.play.blooms[i].size, scale: (q2 - p).length / (q - p).length,
                                              allowed: sizes)
            if c.play.stage == .playing && found != c.play.blooms[i].size { expectedActions = [.resize(i, found)] }
        } else {
            #expect(controller.state == .orbiting)
            expectedOrbit = turned(orbit, by: (q2 - q) * 0.5, view: view)
        }
        actions += controller.handle(event(2, .moved, q2, 1.1), viewSize: view, snapshot: c.snapshot, play: c.play,
                                     kind: panel.kind, size: panel.size)
        actions += controller.handle(event(1, .ended, p, 1.2), viewSize: view, snapshot: c.snapshot, play: c.play,
                                     kind: panel.kind, size: panel.size)
        #expect(controller.state == .cancelled)
        actions += controller.handle(event(2, .ended, q2, 1.25), viewSize: view, snapshot: c.snapshot, play: c.play,
                                     kind: panel.kind, size: panel.size)
        #expect(controller.state == .idle)
        #expect(actions == expectedActions, "pinch run \(run)")
        #expect(abs(controller.orbit.yaw - expectedOrbit.yaw) < 1e-9)
        #expect(abs(controller.orbit.pitch - expectedOrbit.pitch) < 1e-9)
        return actions
    }

    /// A seeded two-finger orbit from empty space checked against its expectation; returns the actions sent, or nil
    /// when no corner is empty.
    func orbitScript(_ controller: inout Controller, c: Case, view: Vec2, orbit: Orbit, panel: Panel,
                     random: inout SeededRandom) -> [Action]? {
        guard let a = emptyPoint(c.snapshot, view: view, orbit: orbit) else { return nil }
        let b: Vec2 = Vec2(view.x / 2, view.y / 2)
        let move: Vec2 = Vec2((unit(&random) - 0.5) * view.x, (unit(&random) - 0.5) * view.y)
        let actions: [Action] = twoFingers(&controller, a: a, b: b, by: move, view: view, c: c, panel: panel, time: 1)
        let expectedOrbit: Orbit = turned(orbit, by: move, view: view)
        #expect(actions.isEmpty)
        #expect(abs(controller.orbit.yaw - expectedOrbit.yaw) < 1e-9)
        #expect(abs(controller.orbit.pitch - expectedOrbit.pitch) < 1e-9)
        #expect(controller.state == .idle && controller.preview == nil)
        return actions
    }

    /// A seeded one-finger script of `kind` (0 … 6) checked against its expectation; returns the actions sent and
    /// whether a preview was checked against the kernel, or nil when the script has no target here.
    func oneFinger(_ kind: Int, _ controller: inout Controller, c: Case, view: Vec2, orbit: Orbit, panel: Panel,
                   run: Int, random: inout SeededRandom) -> (actions: [Action], previewed: Bool)? {
        guard let s = script(kind, c: c, view: view, orbit: orbit, time: 1, random: &random) else { return nil }
        let want: Expectation = expected(s.points, s.times, c: c, view: view, orbit: orbit, panel: panel)
        let got: Outcome = self.run(&controller, s.points, s.times, view: view, c: c, panel: panel)
        #expect(got.actions == want.actions, "run \(run) kind \(kind)")
        #expect(got.state == want.state, "run \(run) kind \(kind)")
        #expect(controller.state == .idle && controller.preview == nil)
        #expect(abs(controller.orbit.yaw - orbit.yaw) < 1e-9 && abs(controller.orbit.pitch - orbit.pitch) < 1e-9)
        var previewed: Bool = false
        if let w = want.preview {
            let p: Preview? = got.preview
            #expect(p?.bloom == w.bloom && p?.column == w.column && p?.row == w.row && p?.removes == w.removes,
                    "preview run \(run): \(String(describing: p)) vs \(w)")
            if let p {
                checkPreview(p, play: c.play)
                previewed = true
            }
        } else {
            #expect(got.preview == nil, "no preview run \(run) kind \(kind)")
        }
        return (got.actions, previewed)
    }

    // MARK: Tests

    @Test func seededScriptsMatchTheIndependentExpectation() throws {
        let all: [Case] = try allCases()
        var digests: [String] = []
        for c in all { digests.append(try digest(c.core)) }
        var random: SeededRandom = SeededRandom(seed: Self.seed)
        var run: Int = 0
        var attempts: Int = 0
        var counts: [Int] = Array(repeating: 0, count: 9)
        var sent: [String: Int] = [:]
        var previews: Int = 0
        while run < 500 && attempts < 5_000 {
            attempts += 1
            let caseIndex: Int = below(all.count, &random)
            let c: Case = all[caseIndex]
            let view: Vec2 = Self.views[below(Self.views.count, &random)]
            let nominal: Orbit = Self.orbits[below(Self.orbits.count, &random)]
            let sizes: [Int] = c.play.level.sizes.sorted()
            let panel: Panel = Panel(kind: NocturneGardenKind.allCases[below(NocturneGardenKind.allCases.count,
                                                                             &random)],
                                     size: sizes[below(sizes.count, &random)])
            var controller: Controller = try self.controller(at: nominal, view: view, c: c, panel: panel)
            // The expectation uses the orbit the controller reached (equal to the nominal one within 1e-9 radians).
            let orbit: Orbit = controller.orbit
            let kind: Int = below(9, &random)
            var actions: [Action] = []
            if kind == 7 {
                actions = pinchScript(&controller, c: c, view: view, orbit: orbit, panel: panel, run: run,
                                      random: &random)
            } else if kind == 8 {
                guard let sent = orbitScript(&controller, c: c, view: view, orbit: orbit, panel: panel,
                                             random: &random) else { continue }
                actions = sent
            } else {
                guard let got = oneFinger(kind, &controller, c: c, view: view, orbit: orbit, panel: panel, run: run,
                                          random: &random) else { continue }
                actions = got.actions
                if got.previewed { previews += 1 }
            }
            // Every move, removal, resize and sun the controller sends is one the adapter accepts.
            for a in actions {
                guard let adapted = adapterAction(a) else { continue }
                var copy: Core = c.core
                let result: ActionResult = copy.apply(adapted)
                if case .plant = a { continue }   // a plant may meet an empty supply
                #expect(result == .accepted, "\(a) run \(run)")
            }
            for a in actions { sent[String(describing: a).prefix(while: { $0 != "(" }).description, default: 0] += 1 }
            counts[kind] += 1
            run += 1
        }
        #expect(run == 500)
        for k in 0..<9 { #expect(counts[k] > 0, "script kind \(k) never ran") }
        for name in ["plant", "move", "remove", "resize", "sun", "choose"] {
            #expect((sent[name] ?? 0) > 0, "\(name) never sent")
        }
        #expect(previews > 20)
        var index: Int = 0
        while index < all.count {
            #expect(try digest(all[index].core) == digests[index])
            index += 1
        }
    }

    @Test func dragPreviewsEqualTheKernelsMask() throws {
        for c in try allCases() {
            let play: Play = c.play
            #expect(Preview.make(play: play, bloom: play.blooms.count, column: 0, row: 0, removes: false) == nil)
            #expect(Preview.make(play: play, bloom: -1, column: 0, row: 0, removes: true) == nil)
            var bloom: Int = 0
            while bloom < play.blooms.count {
                #expect(Preview.make(play: play, bloom: bloom, column: play.level.width, row: 0, removes: false) == nil)
                #expect(Preview.make(play: play, bloom: bloom, column: 0, row: -1, removes: false) == nil)
                let removal: Preview = try #require(Preview.make(play: play, bloom: bloom, column: -3, row: 2,
                                                                 removes: true))
                #expect(removal.text.hasPrefix("would remove: match "))
                checkPreview(removal, play: play)
                var cell: Int = bloom
                while cell < play.level.cellCount {
                    let p: Preview = try #require(Preview.make(play: play, bloom: bloom,
                                                               column: cell % play.level.width,
                                                               row: cell / play.level.width, removes: false))
                    #expect(p.text.hasPrefix("would match "))
                    checkPreview(p, play: play)
                    cell += 13
                }
                bloom += 1
            }
        }
    }

    @Test func tenToSixteenPointsSendNothing() throws {
        let (playing, _) = try playingAndWon()
        let panel: Panel = Panel(kind: .tulip, size: playing.play.level.sizes.sorted()[0])
        for view in Self.views {
            var starts: [Vec2] = []
            if let b = bloomPoint(0, snapshot: playing.snapshot, view: view, orbit: .authored) { starts.append(b) }
            if let l = screen(Geometry.lantern(playing.snapshot), snapshot: playing.snapshot, view: view,
                              orbit: .authored) { starts.append(inside(l, view)) }
            if let p = cellPoint(playing.play.level.cellCount / 2, snapshot: playing.snapshot, view: view,
                                 orbit: .authored) { starts.append(p) }
            #expect(starts.count == 3)
            for start in starts {
                for length in [10.0, 12.5, 15.9] {
                    for direction in [Vec2(1, 0), Vec2(0, 1), Vec2(-0.6, -0.8)] {
                        var controller: Controller = Controller()
                        let s: (points: [Vec2], times: [Double]) = path(start, start + direction * length, steps: 3,
                                                                       view: view, time: 1)
                        let got: Outcome = run(&controller, s.points, s.times, view: view, c: playing, panel: panel)
                        #expect(got.actions.isEmpty)
                        #expect(got.preview == nil)
                        #expect(controller.orbit == .authored)
                    }
                }
            }
        }
    }

    @Test func secondFingersCancelsAndFinishedPlaysSendNothing() throws {
        let (playing, won) = try playingAndWon()
        let view: Vec2 = Self.views[0]
        let panel: Panel = Panel(kind: .tulip, size: playing.play.level.sizes.sorted()[0])
        // A bloom drag with a preview, then a second finger: preview dropped, a pinch; a cancelled pinch sends nothing.
        let b: Vec2 = try #require(bloomPoint(0, snapshot: playing.snapshot, view: view, orbit: .authored))
        let bloomIndex: Int
        if case .bloom(let i) = pick(b, snapshot: playing.snapshot, view: view, orbit: .authored) {
            bloomIndex = i
        } else {
            Issue.record("the head centre does not pick a bloom")
            return
        }
        let far: Vec2 = inside(b + Vec2(0, 120), view)
        func send(_ c: inout Controller, _ e: PointerEvent, _ k: Case) -> [Action] {
            c.handle(e, viewSize: view, snapshot: k.snapshot, play: k.play, kind: panel.kind, size: panel.size)
        }
        var controller: Controller = Controller()
        var actions: [Action] = send(&controller, event(1, .began, b, 1), playing)
        #expect(controller.state == .bloomPress)
        actions += send(&controller, event(1, .moved, far, 1.1), playing)
        #expect(controller.state == .bloomDrag)
        actions += send(&controller, event(2, .began, Vec2(20, 20), 1.2), playing)
        #expect(controller.state == .pinch && controller.preview == nil)
        actions += send(&controller, event(2, .moved, Vec2(300, 600), 1.3), playing)
        actions += send(&controller, event(2, .cancelled, Vec2(300, 600), 1.4), playing)
        #expect(controller.state == .cancelled)
        actions += send(&controller, event(1, .ended, far, 1.5), playing)
        #expect(actions.isEmpty && controller.state == .idle)
        // A bed press then a second finger: an orbit, nothing sent.
        let cellPointValue: Vec2 = try #require(cellPoint(0, snapshot: playing.snapshot, view: view,
                                                          orbit: .authored))
        controller = Controller()
        actions = send(&controller, event(1, .began, cellPointValue, 2), playing)
        actions += send(&controller, event(2, .began, Vec2(view.x / 2, view.y / 2), 2.05), playing)
        #expect(controller.state == .orbiting)
        actions += send(&controller, event(1, .ended, cellPointValue, 2.1), playing)
        actions += send(&controller, event(2, .ended, Vec2(view.x / 2, view.y / 2), 2.15), playing)
        #expect(actions.isEmpty && controller.state == .idle)
        // A cancelled drag and a system cancel send nothing.
        controller = Controller()
        actions = send(&controller, event(1, .began, b, 3), playing)
        actions += send(&controller, event(1, .moved, far, 3.1), playing)
        actions += send(&controller, event(1, .cancelled, far, 3.2), playing)
        #expect(actions.isEmpty && controller.preview == nil && controller.state == .idle)
        actions = send(&controller, event(1, .began, b, 4), playing)
        actions += send(&controller, event(1, .moved, far, 4.1), playing)
        #expect(controller.preview != nil || controller.state == .bloomDrag)
        controller.cancel()
        #expect(controller.state == .idle && controller.preview == nil)
        actions += send(&controller, event(1, .ended, far, 4.2), playing)
        #expect(actions.isEmpty)
        // A tap on the bloom chooses it; on the finished play too.
        controller = Controller()
        #expect(send(&controller, event(1, .began, b, 5), playing).isEmpty)
        #expect(send(&controller, event(1, .ended, b, 5.05), playing) == [.choose(bloomIndex)])
        // A finished play: no plant, move, remove, resize or sun; choose and the preview still work.
        for index in won.play.blooms.indices {
            guard let p = bloomPoint(index, snapshot: won.snapshot, view: view, orbit: .authored),
                  case .bloom(let i) = pick(p, snapshot: won.snapshot, view: view, orbit: .authored) else { continue }
            controller = Controller()
            #expect(send(&controller, event(1, .began, p, 6), won).isEmpty)
            #expect(send(&controller, event(1, .ended, p, 6.05), won) == [.choose(i)])
            for target in [far, Vec2(2, p.y), Vec2(view.x - 2, view.y - 2)] {
                controller = Controller()
                actions = send(&controller, event(1, .began, p, 7), won)
                actions += send(&controller, event(1, .moved, target, 7.1), won)
                if let preview = controller.preview { checkPreview(preview, play: won.play) }
                actions += send(&controller, event(1, .ended, target, 7.2), won)
                #expect(actions.isEmpty)
            }
            controller = Controller()
            actions = send(&controller, event(1, .began, p, 8), won)
            actions += send(&controller, event(2, .began, p + Vec2(60, 0), 8.05), won)
            actions += send(&controller, event(2, .moved, p + Vec2(200, 0), 8.1), won)
            actions += send(&controller, event(1, .ended, p, 8.2), won)
            actions += send(&controller, event(2, .ended, p + Vec2(200, 0), 8.25), won)
            #expect(actions.isEmpty)
        }
        let cells: Int = won.play.level.cellCount
        var cell: Int = 0
        while cell < cells {
            if let p = cellPoint(cell, snapshot: won.snapshot, view: view, orbit: .authored) {
                controller = Controller()
                actions = send(&controller, event(1, .began, p, 9), won)
                actions += send(&controller, event(1, .ended, p, 9.05), won)
                if case .bloom = pick(p, snapshot: won.snapshot, view: view, orbit: .authored) {
                    #expect(actions.count <= 1)
                } else {
                    #expect(actions.isEmpty)
                }
            }
            cell += 7
        }
        if let l = screen(Geometry.lantern(won.snapshot), snapshot: won.snapshot, view: view, orbit: .authored) {
            controller = Controller()
            actions = send(&controller, event(1, .began, l, 10), won)
            actions += send(&controller, event(1, .moved, l + Vec2(0, 150), 10.1), won)
            actions += send(&controller, event(1, .ended, l + Vec2(0, 150), 10.2), won)
            #expect(actions.isEmpty)
        }
    }

    @Test func aDoubleTapOnEmptySpaceResetsTheView() throws {
        let (playing, _) = try playingAndWon()
        let panel: Panel = Panel(kind: .tulip, size: playing.play.level.sizes.sorted()[0])
        for view in Self.views {
            let turned: Orbit = Self.orbits[1]
            var controller: Controller = try self.controller(at: turned, view: view, c: playing, panel: panel)
            let e: Vec2 = try #require(emptyPoint(playing.snapshot, view: view, orbit: turned))
            func tapAt(_ c: inout Controller, _ p: Vec2, _ t: Double) -> [Action] {
                run(&c, [p, p], [t, t + 0.05], view: view, c: playing, panel: panel).actions
            }
            #expect(tapAt(&controller, e, 1).isEmpty)
            #expect(tapAt(&controller, e + Vec2(30, 0), 1.2).isEmpty)          // too far: a new first tap
            #expect(tapAt(&controller, e + Vec2(30, 0), 1.8).isEmpty)          // too late: a new first tap
            #expect(near(controller.orbit, turned))
            #expect(tapAt(&controller, e + Vec2(30, 5), 2.0) == [.resetView])  // 0.2 s and 5 points
            #expect(controller.orbit == .authored)
            #expect(tapAt(&controller, e + Vec2(30, 5), 2.2).isEmpty)          // a third tap starts anew
            let back: Controller = controller
            controller = try self.controller(at: turned, view: view, c: playing, panel: panel)
            controller.resetView()
            #expect(controller.orbit == back.orbit)
            #expect(controller.camera(viewSize: view, snapshot: playing.snapshot)
                    == Geometry.camera(playing.snapshot, aspect: view.x / view.y))
            #expect(controller.camera(viewSize: Vec2(0, 10), snapshot: playing.snapshot) == nil)
        }
    }

    @Test func orbitFollowsClampsAndRebases() throws {
        let (playing, _) = try playingAndWon()
        let panel: Panel = Panel(kind: .tulip, size: playing.play.level.sizes.sorted()[0])
        let view: Vec2 = Self.views[1]
        let a: Vec2 = try #require(emptyPoint(playing.snapshot, view: view, orbit: .authored))
        let b: Vec2 = Vec2(view.x / 2, view.y / 2)
        var controller: Controller = Controller()
        #expect(twoFingers(&controller, a: a, b: b, by: Vec2(view.x / 4, 0), view: view, c: playing, panel: panel,
                           time: 0).isEmpty)
        #expect(abs(controller.orbit.yaw - Double.pi / 8) < 1e-12)
        #expect(abs(controller.orbit.pitch - Orbit.authored.pitch) < 1e-12)
        #expect(twoFingers(&controller, a: a, b: b, by: Vec2(2 * view.x, -view.y), view: view, c: playing,
                           panel: panel, time: 1).isEmpty)
        #expect(controller.orbit == Orbit(yaw: Orbit.yawLimit, pitch: Orbit.pitchRange.upperBound))
        #expect(twoFingers(&controller, a: a, b: b, by: Vec2(-4 * view.x, 2 * view.y), view: view, c: playing,
                           panel: panel, time: 2).isEmpty)
        #expect(controller.orbit == Orbit(yaw: -Orbit.yawLimit, pitch: Orbit.pitchRange.lowerBound))
        // A third finger re-bases the midpoint: its touch-down turns nothing, its move by dx turns by dx / 3.
        controller = Controller()
        func send(_ e: PointerEvent) -> [Action] {
            controller.handle(e, viewSize: view, snapshot: playing.snapshot, play: playing.play, kind: panel.kind,
                              size: panel.size)
        }
        var actions: [Action] = send(event(1, .began, a, 0))
        actions += send(event(2, .began, b, 0.01))
        #expect(controller.state == .orbiting)
        actions += send(event(3, .began, Vec2(view.x - 10, 10), 0.02))
        #expect(controller.orbit == .authored)
        actions += send(event(3, .moved, Vec2(view.x - 10 - 90, 10), 0.03))
        #expect(abs(controller.orbit.yaw - (-30 / view.x * Double.pi / 2)) < 1e-12)
        actions += send(event(3, .ended, Vec2(view.x - 100, 10), 0.04))
        #expect(controller.state == .cancelled)
        actions += send(event(1, .moved, a + Vec2(200, 0), 0.05))
        #expect(abs(controller.orbit.yaw - (-30 / view.x * Double.pi / 2)) < 1e-12)
        actions += send(event(1, .ended, a, 0.06))
        actions += send(event(2, .ended, b, 0.07))
        #expect(actions.isEmpty && controller.state == .idle)
    }

    @Test func previewsAndOrbitNeverChangeTheDigest() throws {
        let (playing, won) = try playingAndWon()
        for c in [playing, won] {
            let before: String = try digest(c.core)
            let panel: Panel = Panel(kind: .tulip, size: c.play.level.sizes.sorted()[0])
            for view in Self.views {
                for orbit in Self.orbits {
                    var controller: Controller = try self.controller(at: orbit, view: view, c: c, panel: panel)
                    var bloom: Int = 0
                    while bloom < c.play.blooms.count {
                        if let p = bloomPoint(bloom, snapshot: c.snapshot, view: view, orbit: orbit) {
                            _ = controller.handle(event(1, .began, p, 1), viewSize: view, snapshot: c.snapshot,
                                                  play: c.play, kind: panel.kind, size: panel.size)
                            _ = controller.handle(event(1, .moved, inside(p + Vec2(40, 60), view), 1.1),
                                                  viewSize: view, snapshot: c.snapshot, play: c.play,
                                                  kind: panel.kind, size: panel.size)
                            if let preview = controller.preview {
                                let drawn: Snapshot = c.snapshot.withPreview(preview.cells)
                                #expect(drawn.preview == preview.cells)
                            }
                            controller.cancel()
                        }
                        bloom += 1
                    }
                    #expect(try digest(c.core) == before)
                    #expect(near(controller.orbit, orbit))
                }
            }
        }
    }
}
