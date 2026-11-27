// BinaryGardensGestureWiringTests — feature 504 (R02-G21-04) T-R02G2104-005 (FR-R02G2104-001 … 016;
// SC-R02G2104-001 … 006). On the simulator, through the one app's session host: scripted touches go to the
// presenter's `pointer(_:viewSize:port:)` with the shell's own `port` at a 1,200 × 800-point view (aspect 1.5; large
// enough that a star's luminosity pips lie well clear of its disc centre). Modelled on
// MushroomWeatherGestureWiringTests (feature 494). Targets are projected through the drawn camera of the presenter's
// orbit (`BinaryGardensSceneGeometry.camera(aspect:orbit:)`, then `BinaryGardensPicker.viewPoint` of `starCentre`,
// `luminosityPips`, `tiltPipCentre`, `worldCentre`, `cellCentre` and `ringVertex`) on the presenter's `lastSnapshot`,
// and each is confirmed with the picker (`pick`, `dragMode`, `ringTarget`, `phaseTarget`, `nearestPip`,
// `nearestTiltPip`, `stepValue`, `gaugeTick`) at the same view size before any touch. Levels are chosen at run time
// from bare opening cores (seed n − 1 opens level n, tick 48 shown); the kernel's verdict is the one a bare core gives
// for the same actions.
// Checked:
//   a. a radial star drag previews the star on the ring under the finger (the kernel's preview, drawn, no digest
//      change) and on release sends exactly one `star.ring [star, index]` (FR-R02G2104-002, 004, 008);
//   b. a tangential star drag previews and sends exactly one `star.phase [star, step]` on the phase grid
//      (FR-R02G2104-003, 004, 008);
//   c. a pip tap sends exactly one `star.luminosity [star, index]` for the pip under the finger; a sideways pip drag
//      previews and sends exactly one for the level the travel reads (FR-R02G2104-005);
//   d. a dial tap sends exactly one `orbit.tilt [step]`; a sideways dial drag previews and sends exactly one
//      (FR-R02G2104-006);
//   e. a world tap inspects the world (the drawn snapshot marks it, the description gives the kernel's words for it at
//      the shown tick) and a second tap clears it; nothing is sent (FR-R02G2104-001);
//   f. a gauge scrub shows the ticks under the finger (`clock.show`), and a gauge tap inspects its world and shows the
//      tick under the finger; no action spent, the digest unchanged (FR-R02G2104-007);
//   g. a two-finger orbit changes the orbit and never the digest; `resetView()` and a double tap on empty space return
//      to the authored orbit with no kernel action (FR-R02G2104-010);
//   h. a change with no action left is previewed as refused (named in words), sent once on release, refused, shown in
//      the mirror message and logged with its bare code (FR-R02G2104-008, 011, 014);
//   i. a star drag on a won play sends nothing and says "The play is over: undo or go to the next level"
//      (FR-R02G2104-011);
//   j. a tap on a star selects it in the panel and explains the drag; a tap on a ring explains the ring drag; nothing
//      is sent (FR-R02G2104-001, 011);
//   k. a new level (since feature 505 the daily level of another level, as `level.next` needs the next level open)
//      and a reset clear the preview, the inspection and the orbit (FR-R02G2104-016);
//   l. the gesture actions are the five declared controls of the canvas and the native actions every declared control
//      (FR-R02G2104-013).
// Explicit synthetic timestamps (no clock, no sleep, no wall-clock assertion). Explicit types and plain loops (CI
// type-check rule); no nested closure literals. Synthetic data only. Each test well under 10 s.
//
// Presenter API used (T-R02G2104-005): `BinaryGardensPresenter.pointer(_:viewSize:port:)`, `orbit`, `gestureState`,
// `resetView()`, `inspect(_:)`, `send(_:_:port:)`, `refusalLog` (bare codes, oldest first), `lastSnapshot` (carries
// the drawn `preview` and `inspectedWorld`), `describe(_:)` ("Inspected " and the kernel's words of the inspected
// world, then a full stop), `mirror.message` (the controller's explain texts verbatim; a refusal as
// `BinaryGardensMirror.refusalMessage(code:)`, since feature 506 the feedback plan's sentence), `mirror.preview`,
// `mirror.previewRefusal` and
// `mirror.previewRefusalLabel` (`BinaryGardensMirror.previewRefusalMessage(_:)`), `mirror.inspectedWorld`,
// `mirror.selectedStar`, `mirror.phaseTarget`, `gestureActions`, `nativeActions`. Explain texts: the controller's
// `starReason`, `ringReason` and `finishedReason`.
#if os(iOS)
import BinaryGardensCore
import CoreGraphics
import Foundation
import Testing
@testable import BinaryGardensExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreScenes

/// Scripted touches on Binary Gardens, placed through the drawn camera.
@MainActor
enum BinaryGardensGestureScript {
    typealias Shell = BinaryGardensTest.Shell
    typealias Snapshot = BinaryGardensSceneSnapshot
    typealias Geometry = BinaryGardensSceneGeometry
    typealias Core = BinaryGardensExperienceCore
    typealias Picker = BinaryGardensPicker
    typealias Pick = BinaryGardensPick
    typealias ViewOrbit = BinaryGardensViewOrbit
    typealias Action = BinaryGardensAction
    typealias Controller = BinaryGardensGestureController
    typealias T = BinaryGardensTest

    /// The view's width in points (aspect 1.5).
    nonisolated static let viewWidth: Double = 1_200
    /// The view's height in points.
    nonisolated static let viewHeight: Double = 800
    /// The view size handed with every event.
    static var viewSize: Vec2 { Vec2(viewWidth, viewHeight) }
    /// The view size as the picker takes it.
    static var size: SIMD2<Double> { SIMD2<Double>(viewWidth, viewHeight) }
    /// The first synthetic timestamp, seconds (the controller only compares timestamps).
    nonisolated static let start: Double = 100
    /// The time between scripted events in seconds (synthetic).
    nonisolated static let frame: Double = 1.0 / 60
    /// The pause between the two taps of a double tap, seconds (inside the 0.35 s window).
    nonisolated static let tapGap: Double = 0.1
    /// The pause between two separate gestures, seconds (outside every double-tap window).
    nonisolated static let gesturePause: Double = 1
    /// The moves of a scripted straight drag.
    nonisolated static let dragMoves: Int = 6
    /// The shortest star drag scripted, points (twice the drag distance 16).
    nonisolated static let minimumDrag: Double = 32
    /// The length of a drag that only has to start a drag, points (more than the drag distance 16).
    nonisolated static let shortDrag: Double = 40
    /// How far inside the view a touch point must lie, points.
    nonisolated static let inset: Double = 8
    /// The radii in points around a projected centre at which a touch point is tried.
    nonisolated static let radii: [Double] = [0, 4, 8, 12]
    /// The directions tried at each radius (the first straight up, away from a star's pips).
    nonisolated static let directions: Int = 8
    /// The grid step of the empty-space search, points.
    nonisolated static let gridStep: Double = 12
    /// The step counts tried for a luminosity or tilt drag (each ``BinaryGardensPicker/stepTravel`` points of
    /// horizontal travel), nearest first, right before left.
    nonisolated static let travelSteps: [Int] = [1, -1, 2, -2, 3, -3]
    /// The grid-step offsets tried for a phase drag, nearest first.
    nonisolated static let phaseOffsets: [Int] = [1, -1, 2, -2, 3, -3, 4, -4, 6, -6]
    /// The ring steps tried for a ring tap (every sixth vertex of the 48-gon).
    nonisolated static let ringSteps: [Int] = [0, 6, 12, 18, 24, 30, 36, 42]
    /// The ticks a gauge scrub runs between.
    nonisolated static let scrubTicks: (from: Int, to: Int) = (8, 40)
    /// The tick a gauge tap aims at.
    nonisolated static let tapTick: Int = 20
    /// The candidate levels; the first that fits is used.
    nonisolated static let candidateLevels: [Int] = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19,
                                                     20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30]
    /// The kernel's budget refusal code.
    nonisolated static let budgetCode: String = "r02-g21.budget"
    /// The engine's prefix of a rule refusal.
    nonisolated static let rulePrefix: String = "action.rule."
    /// The explain text of a tap on a star.
    nonisolated static let starTapText: String = BinaryGardensGestureController.starReason
    /// The explain text of a tap on a ring.
    nonisolated static let ringTapText: String = BinaryGardensGestureController.ringReason
    /// The explain text of a gesture on a finished play.
    nonisolated static let finishedText: String = BinaryGardensGestureController.finishedReason

    /// What the engine has counted so far: accepted and rejected actions.
    struct Sent: Equatable {
        /// The accepted actions.
        let accepted: Int
        /// The rejected actions.
        let rejected: Int
    }

    /// A level, the actions issued through the shell before the gesture and the star the gesture is about.
    struct LevelTarget {
        /// The level number.
        let number: Int
        /// The actions issued before the gesture.
        let setUp: [Action]
        /// The star the gesture concerns (0 or 1; unused for the dial).
        let star: Int
    }

    /// A one-finger drag on a snapshot: the touch-down point, the release point and the change it makes.
    struct Drag {
        /// The touch-down point.
        let start: Vec2
        /// The release point.
        let end: Vec2
        /// The change the release reads (a `.ring`, `.phase`, `.luminosity` or `.tilt` action).
        let change: Action
    }

    /// A tap on a snapshot: the point and the change it makes.
    struct Tap {
        /// The tap point.
        let point: Vec2
        /// The change the tap reads (a `.luminosity` or `.tilt` action).
        let change: Action
    }

    /// Opens level `number` (seed `number − 1`) at the scripted view size with tick 48 shown, issues `setUp` and draws
    /// a frame so `lastSnapshot` is current.
    static func open(_ session: ExperienceSession, number: Int, setUp: [Action] = []) async throws -> Shell {
        let shell: Shell = try await T.open(session, seed: UInt64(number - 1), setUp: setUp,
                                            size: CGSize(width: viewWidth, height: viewHeight), atCheckTick: false)
        try T.draw(session)
        return shell
    }

    /// The engine's action counters of `shell`.
    static func sent(_ shell: Shell) -> Sent {
        Sent(accepted: shell.engine.acceptedActions, rejected: shell.engine.rejectedActions)
    }

    /// The snapshot the presenter drew last.
    static func drawn(_ shell: Shell) throws -> Snapshot {
        try #require(shell.presenter.lastSnapshot)
    }

    /// Sends one pointer event to the presenter with the shell's port; the synthetic clock advances one frame.
    static func touch(_ shell: Shell, id: Int, _ phase: PointerPhase, at location: Vec2, time: inout Double) {
        let event: PointerEvent = PointerEvent(id: id, phase: phase, location: location, timestamp: time)
        shell.presenter.pointer(event, viewSize: viewSize, port: shell.port)
        time += frame
    }

    /// A tap (down and up at `location`, one frame apart) with finger `id`.
    static func tap(_ shell: Shell, id: Int, at location: Vec2, time: inout Double) {
        touch(shell, id: id, .began, at: location, time: &time)
        touch(shell, id: id, .ended, at: location, time: &time)
    }

    /// ``dragMoves`` equal moves of finger `id` from `start` to `end` (no touch-down, no lift).
    static func moves(_ shell: Shell, id: Int, from start: Vec2, to end: Vec2, time: inout Double) {
        let delta: Vec2 = end - start
        for step in 1...dragMoves {
            let t: Double = Double(step) / Double(dragMoves)
            touch(shell, id: id, .moved, at: start + delta * t, time: &time)
        }
    }

    /// A two-finger orbit with fingers `first` and `second` from `a` and `b`, both moving by `shift`, then lifting.
    static func orbit(_ shell: Shell, ids first: Int, _ second: Int, from a: Vec2, _ b: Vec2, by shift: Vec2,
                      time: inout Double) {
        touch(shell, id: first, .began, at: a, time: &time)
        touch(shell, id: second, .began, at: b, time: &time)
        touch(shell, id: first, .moved, at: a + shift, time: &time)
        touch(shell, id: second, .moved, at: b + shift, time: &time)
        touch(shell, id: first, .ended, at: a + shift, time: &time)
        touch(shell, id: second, .ended, at: b + shift, time: &time)
    }

    /// Whether `location` lies inside the view with a margin of ``inset`` points.
    static func inside(_ location: Vec2) -> Bool {
        location.x >= inset && location.x <= viewWidth - inset && location.y >= inset
            && location.y <= viewHeight - inset
    }

    /// `v` as the picker takes it.
    static func simd(_ v: Vec2) -> SIMD2<Double> { SIMD2<Double>(v.x, v.y) }

    /// What the picker gives for `location` on `snapshot` at `orbit`.
    static func pick(_ location: Vec2, _ snapshot: Snapshot, orbit: ViewOrbit) -> Pick {
        Picker.pick(simd(location), size: size, snapshot: snapshot, orbit: orbit)
    }

    /// The drawn camera at `orbit`.
    static func camera(orbit: ViewOrbit) -> BinaryGardensCamera {
        Geometry.camera(aspect: viewWidth / viewHeight, orbit: orbit)
    }

    /// World `point` in view points through the drawn camera at `orbit`; nil when it does not project.
    static func project(_ point: SIMD3<Double>, orbit: ViewOrbit) -> Vec2? {
        guard let p: SIMD2<Double> = Picker.viewPoint(point, size: size, camera: camera(orbit: orbit)) else {
            return nil
        }
        return Vec2(p.x, p.y)
    }

    /// The touch points tried about view point `c`: `c` itself, then rings of ``radii`` in ``directions`` directions,
    /// the first straight up (y down in view points), inside the view only.
    static func candidates(around c: Vec2) -> [Vec2] {
        var points: [Vec2] = []
        for radius in radii {
            let count: Int = radius == 0 ? 1 : directions
            for k in 0..<count {
                let a: Double = -Double.pi / 2 + Double(k) * 2 * Double.pi / Double(directions)
                let p: Vec2 = c + Vec2(cos(a), sin(a)) * radius
                if inside(p) { points.append(p) }
            }
        }
        return points
    }

    /// A point inside the view near world `centre` (its projection, then rings about it) where the picker gives
    /// `wanted`; nil when none.
    static func point(near centre: SIMD3<Double>, _ snapshot: Snapshot, orbit: ViewOrbit, wanted: Pick) -> Vec2? {
        guard let c: Vec2 = project(centre, orbit: orbit) else { return nil }
        for p in candidates(around: c) where pick(p, snapshot, orbit: orbit) == wanted { return p }
        return nil
    }

    /// A point that picks star `star`'s disc; nil when none.
    static func starPoint(_ star: Int, _ snapshot: Snapshot, orbit: ViewOrbit) -> Vec2? {
        point(near: Geometry.starCentre(star, snapshot), snapshot, orbit: orbit, wanted: .star(star))
    }

    /// A point that picks world `world`; nil when none.
    static func worldPoint(_ world: Int, _ snapshot: Snapshot, orbit: ViewOrbit) -> Vec2? {
        point(near: Geometry.worldCentre(world, snapshot), snapshot, orbit: orbit, wanted: .world(world))
    }

    /// A point that picks star `star`'s luminosity pips with pip `level` the nearest; nil when none.
    static func pipPoint(_ star: Int, level: Int, _ snapshot: Snapshot, orbit: ViewOrbit) -> Vec2? {
        let pips = Geometry.luminosityPips(star, snapshot, eye: camera(orbit: orbit).eye)
        guard pips.indices.contains(level), let c: Vec2 = project(pips[level].centre, orbit: orbit) else { return nil }
        for p in candidates(around: c) where pick(p, snapshot, orbit: orbit) == .pips(star) {
            let nearest: Int = Picker.nearestPip(simd(p), star: star, size: size, snapshot: snapshot, orbit: orbit)
            if nearest == level { return p }
        }
        return nil
    }

    /// A point that picks the tilt dial with pip `step` the nearest; nil when none.
    static func dialPoint(_ step: Int, _ snapshot: Snapshot, orbit: ViewOrbit) -> Vec2? {
        guard let c: Vec2 = project(Geometry.tiltPipCentre(step), orbit: orbit) else { return nil }
        for p in candidates(around: c) where pick(p, snapshot, orbit: orbit) == .dial {
            let nearest: Int = Picker.nearestTiltPip(simd(p), size: size, snapshot: snapshot, orbit: orbit)
            if nearest == step { return p }
        }
        return nil
    }

    /// A point on world `world`'s gauge row where the tick under the finger is `tick`; nil when none.
    static func gaugePoint(_ world: Int, tick: Int, _ snapshot: Snapshot, orbit: ViewOrbit) -> Vec2? {
        guard let c: Vec2 = project(Geometry.cellCentre(world, tick: tick), orbit: orbit) else { return nil }
        for p in candidates(around: c) where pick(p, snapshot, orbit: orbit) == .gauge(world) {
            if Picker.gaugeTick(simd(p), size: size, orbit: orbit) == tick { return p }
        }
        return nil
    }

    /// A point that picks ring `ring`, near one of its vertices at ``ringSteps``; nil when none.
    static func ringPoint(_ ring: Int, _ snapshot: Snapshot, orbit: ViewOrbit) -> Vec2? {
        guard snapshot.ringRadii.indices.contains(ring) else { return nil }
        for step in ringSteps {
            let vertex: SIMD3<Double> = Geometry.ringVertex(radius: snapshot.ringRadii[ring], step: step,
                                                            tilt: snapshot.arrangement.tilt,
                                                            scale: snapshot.fitScale)
            if let p: Vec2 = point(near: vertex, snapshot, orbit: orbit, wanted: .ring(ring)) { return p }
        }
        return nil
    }

    /// The first grid point inside the view that picks `wanted` and lies at least `minimum` points from `away` (when
    /// given); nil when none.
    static func gridPoint(_ snapshot: Snapshot, orbit: ViewOrbit, wanted: Pick, away: Vec2? = nil,
                          minimum: Double = 0) -> Vec2? {
        var y: Double = inset
        while y <= viewHeight - inset {
            var x: Double = inset
            while x <= viewWidth - inset {
                let p: Vec2 = Vec2(x, y)
                var far: Bool = true
                if let away { far = (p - away).length >= minimum }
                if far, pick(p, snapshot, orbit: orbit) == wanted { return p }
                x += gridStep
            }
            y += gridStep
        }
        return nil
    }

    /// The table step a star of grid phase `phase` stands at at the shown tick: (phase + ω · tick) mod 48.
    static func drawnStep(phase: Int, _ snapshot: Snapshot) -> Int {
        let cycle: Int = Snapshot.cycle
        return ((phase + snapshot.starSpeed * snapshot.shownTick) % cycle + cycle) % cycle
    }

    /// A radial drag of star `star` on `snapshot`: from a point on its disc to the projection of its drawn table step
    /// on another ring, at least ``minimumDrag`` away, where the picker reads a ring drag to that ring; nil when none.
    static func ringDrag(_ star: Int, _ snapshot: Snapshot, orbit: ViewOrbit) -> Drag? {
        guard let start: Vec2 = starPoint(star, snapshot, orbit: orbit) else { return nil }
        let current: Int = snapshot.arrangement.rings[star]
        let step: Int = snapshot.starStep(star, tick: snapshot.shownTick)
        for index in snapshot.ringRadii.indices where index != current {
            let vertex: SIMD3<Double> = Geometry.ringVertex(radius: snapshot.ringRadii[index], step: step,
                                                            tilt: snapshot.arrangement.tilt,
                                                            scale: snapshot.fitScale)
            guard let end: Vec2 = project(vertex, orbit: orbit), inside(end),
                  (end - start).length >= minimumDrag else { continue }
            let mode = Picker.dragMode(travel: simd(end - start), star: star, size: size, snapshot: snapshot,
                                       orbit: orbit)
            guard mode == .ring else { continue }
            let target: Int = Picker.ringTarget(simd(end), star: star, size: size, snapshot: snapshot, orbit: orbit)
            if target == index { return Drag(start: start, end: end, change: .ring(star: star, index: index)) }
        }
        return nil
    }

    /// A tangential drag of star `star` on `snapshot`: from a point on its disc to the drawn position of a nearby
    /// grid phase on its ring, at least ``minimumDrag`` away, where the picker reads a phase drag to that phase; nil
    /// when none.
    static func phaseDrag(_ star: Int, _ snapshot: Snapshot, orbit: ViewOrbit) -> Drag? {
        guard let start: Vec2 = starPoint(star, snapshot, orbit: orbit) else { return nil }
        let cycle: Int = Snapshot.cycle
        let g: Int = max(snapshot.phaseStep, 1)
        let current: Int = snapshot.arrangement.phases[star]
        let radius: Int = snapshot.ringRadii[snapshot.arrangement.rings[star]]
        for offset in phaseOffsets {
            let phase: Int = ((current + offset * g) % cycle + cycle) % cycle
            guard phase != current, phase % g == 0 else { continue }
            let vertex: SIMD3<Double> = Geometry.ringVertex(radius: radius, step: drawnStep(phase: phase, snapshot),
                                                            tilt: snapshot.arrangement.tilt,
                                                            scale: snapshot.fitScale)
            guard let end: Vec2 = project(vertex, orbit: orbit), inside(end),
                  (end - start).length >= minimumDrag else { continue }
            let mode = Picker.dragMode(travel: simd(end - start), star: star, size: size, snapshot: snapshot,
                                       orbit: orbit)
            guard mode == .phase else { continue }
            let target: Int = Picker.phaseTarget(simd(end), star: star, size: size, snapshot: snapshot, orbit: orbit)
            if target == phase { return Drag(start: start, end: end, change: .phase(star: star, step: phase)) }
        }
        return nil
    }

    /// A sideways drag from `start` by whole step travels where the value read from `current` (clamped to 0 …
    /// `upper`) differs from it, ending inside the view: the release point and the value; nil when none.
    static func stepDrag(from start: Vec2, current: Int, upper: Int) -> (end: Vec2, value: Int)? {
        for steps in travelSteps {
            let travel: Double = Double(steps) * Picker.stepTravel
            let end: Vec2 = start + Vec2(travel, 0)
            guard inside(end) else { continue }
            let value: Int = Picker.stepValue(start: current, travel: travel, upper: upper)
            if value != current { return (end, value) }
        }
        return nil
    }

    /// A sideways drag along star `star`'s luminosity pips on `snapshot`; nil when none.
    static func pipDrag(_ star: Int, _ snapshot: Snapshot, orbit: ViewOrbit) -> Drag? {
        let current: Int = snapshot.arrangement.luminosities[star]
        guard let start: Vec2 = pipPoint(star, level: current, snapshot, orbit: orbit),
              let found = stepDrag(from: start, current: current,
                                   upper: snapshot.luminosityLevels.count - 1) else { return nil }
        return Drag(start: start, end: found.end, change: .luminosity(star: star, index: found.value))
    }

    /// A tap on a pip of star `star` other than its current level on `snapshot`; nil when none.
    static func pipTap(_ star: Int, _ snapshot: Snapshot, orbit: ViewOrbit) -> Tap? {
        let current: Int = snapshot.arrangement.luminosities[star]
        for level in snapshot.luminosityLevels.indices where level != current {
            if let p: Vec2 = pipPoint(star, level: level, snapshot, orbit: orbit) {
                return Tap(point: p, change: .luminosity(star: star, index: level))
            }
        }
        return nil
    }

    /// A sideways drag along the tilt dial on `snapshot`; nil when none.
    static func dialDrag(_ snapshot: Snapshot, orbit: ViewOrbit) -> Drag? {
        let current: Int = snapshot.arrangement.tilt
        guard snapshot.maxTilt > 0, let start: Vec2 = dialPoint(current, snapshot, orbit: orbit),
              let found = stepDrag(from: start, current: current, upper: snapshot.maxTilt) else { return nil }
        return Drag(start: start, end: found.end, change: .tilt(step: found.value))
    }

    /// A tap on a dial pip other than the current tilt on `snapshot`; nil when none.
    static func dialTap(_ snapshot: Snapshot, orbit: ViewOrbit) -> Tap? {
        guard snapshot.maxTilt > 0 else { return nil }
        for step in 0...snapshot.maxTilt where step != snapshot.arrangement.tilt {
            if let p: Vec2 = dialPoint(step, snapshot, orbit: orbit) { return Tap(point: p, change: .tilt(step: step)) }
        }
        return nil
    }

    /// A drag of ``shortDrag`` points from `start` in the first of the four axis directions that ends inside the view.
    static func anyDragEnd(from start: Vec2) -> Vec2? {
        let axes: [Vec2] = [Vec2(0, -1), Vec2(0, 1), Vec2(1, 0), Vec2(-1, 0)]
        for axis in axes {
            let end: Vec2 = start + axis * shortDrag
            if inside(end) { return end }
        }
        return nil
    }

    /// The core `before` after applying `control` with `values`, and the adapter's answer.
    static func applied(_ before: Core, _ control: String, _ values: [Double]) -> (core: Core, result: ActionResult) {
        var copy: Core = before
        let result: ActionResult = copy.apply(ExperienceAction(control: control, values: values, step: 0))
        return (copy, result)
    }

    /// The core `before` after the kernel action `change`, and the adapter's answer.
    static func applied(_ before: Core, _ change: Action) -> (core: Core, result: ActionResult) {
        let issued = T.control(change)
        return applied(before, issued.control, issued.values)
    }

    /// The opening core of level `number` with `actions` applied; nil when the kernel refuses one of them.
    static func bare(_ number: Int, _ actions: [Action]) throws -> Core? {
        var core: Core = try Core.opening(number: number)
        for action in actions {
            let result: ActionResult = core.apply(T.experienceAction(action))
            if result != .accepted { return nil }
        }
        return core
    }

    /// The opening core of level `number` when it is playing with an action left; nil otherwise.
    static func playingOpening(_ number: Int) throws -> Core? {
        guard let core: Core = try bare(number, []), core.play.stage == .playing, core.play.actionsLeft >= 1 else {
            return nil
        }
        return core
    }

    // MARK: Level choice (from bare cores; the caller's `#require` records an issue when none fits)

    /// The first candidate level and star with a radial (`ring`) or tangential drag the kernel accepts.
    static func starDragTarget(ring: Bool) throws -> LevelTarget? {
        for number in candidateLevels {
            guard let core: Core = try playingOpening(number) else { continue }
            let snapshot: Snapshot = core.snapshot(time: 0)
            for star in 0..<2 {
                let found: Drag? = ring ? ringDrag(star, snapshot, orbit: .authored)
                    : phaseDrag(star, snapshot, orbit: .authored)
                guard let drag = found else { continue }
                if applied(core, drag.change).result == .accepted {
                    return LevelTarget(number: number, setUp: [], star: star)
                }
            }
        }
        return nil
    }

    /// The first candidate level and star with a pip drag (`drag`) or a pip tap the kernel accepts.
    static func pipTarget(drag: Bool) throws -> LevelTarget? {
        for number in candidateLevels {
            guard let core: Core = try playingOpening(number) else { continue }
            let snapshot: Snapshot = core.snapshot(time: 0)
            for star in 0..<2 where snapshot.freedom(star).luminosity {
                var change: Action?
                if drag {
                    change = pipDrag(star, snapshot, orbit: .authored)?.change
                } else {
                    change = pipTap(star, snapshot, orbit: .authored)?.change
                }
                guard let made = change else { continue }
                if applied(core, made).result == .accepted {
                    return LevelTarget(number: number, setUp: [], star: star)
                }
            }
        }
        return nil
    }

    /// The first candidate level with a dial drag (`drag`) or a dial tap the kernel accepts.
    static func dialTarget(drag: Bool) throws -> LevelTarget? {
        for number in candidateLevels {
            guard let core: Core = try playingOpening(number) else { continue }
            let snapshot: Snapshot = core.snapshot(time: 0)
            let change: Action? = drag ? dialDrag(snapshot, orbit: .authored)?.change
                : dialTap(snapshot, orbit: .authored)?.change
            guard let made = change else { continue }
            if applied(core, made).result == .accepted {
                return LevelTarget(number: number, setUp: [], star: 0)
            }
        }
        return nil
    }

    /// A date whose daily level differs from `number` (feature 505): 2026-01-02 (level 14), else 2026-01-03 (level 27);
    /// the date's values and that level.
    static func otherDaily(_ number: Int) -> (date: [Double], level: Int)? {
        let days: [Int] = [2, 3]
        for day in days {
            guard let level = BinaryGardensProgress.dailyLevel(year: 2026, month: 1, day: day), level != number else {
                continue
            }
            return ([2026, 1, Double(day)], level)
        }
        return nil
    }

    /// The first candidate level whose opening has a world that picks; the target's star is that world.
    static func worldTarget() throws -> LevelTarget? {
        for number in candidateLevels {
            guard let core: Core = try bare(number, []) else { continue }
            let snapshot: Snapshot = core.snapshot(time: 0)
            for world in snapshot.worlds.indices where worldPoint(world, snapshot, orbit: .authored) != nil {
                return LevelTarget(number: number, setUp: [], star: world)
            }
        }
        return nil
    }

    /// The first candidate level whose opening has a gauge row with a scrub from ``scrubTicks``'s first tick to its
    /// second and a tap at ``tapTick``; the target's star is that world.
    static func gaugeTarget() throws -> LevelTarget? {
        for number in candidateLevels {
            guard let core: Core = try bare(number, []) else { continue }
            let snapshot: Snapshot = core.snapshot(time: 0)
            for world in snapshot.worlds.indices {
                guard gaugePoint(world, tick: scrubTicks.from, snapshot, orbit: .authored) != nil,
                      gaugePoint(world, tick: scrubTicks.to, snapshot, orbit: .authored) != nil,
                      gaugePoint(world, tick: tapTick, snapshot, orbit: .authored) != nil else { continue }
                return LevelTarget(number: number, setUp: [], star: world)
            }
        }
        return nil
    }

    /// The first candidate level and star whose whole budget can be spent on luminosity changes of that star (back and
    /// forth), still playing, after which a pip drag on it is refused with ``budgetCode``.
    static func budgetTarget() throws -> LevelTarget? {
        for number in candidateLevels {
            guard let opening: Core = try playingOpening(number) else { continue }
            let first: Snapshot = opening.snapshot(time: 0)
            let budget: Int = opening.play.actionsLeft
            for star in 0..<2 where first.freedom(star).luminosity && first.luminosityLevels.count > 1 {
                let current: Int = first.arrangement.luminosities[star]
                let other: Int = current == 0 ? 1 : 0
                var setUp: [Action] = []
                for step in 0..<budget {
                    setUp.append(.luminosity(star: star, index: step % 2 == 0 ? other : current))
                }
                guard let spent: Core = try bare(number, setUp), spent.play.actionsLeft == 0,
                      spent.play.stage == .playing else { continue }
                let snapshot: Snapshot = spent.snapshot(time: 0)
                guard let drag: Drag = pipDrag(star, snapshot, orbit: .authored) else { continue }
                if applied(spent, drag.change).result.code.hasSuffix(budgetCode) {
                    return LevelTarget(number: number, setUp: setUp, star: star)
                }
            }
        }
        return nil
    }

    /// The first candidate level won by its certified plan and the run, with a drag inside the view from a star that
    /// picks on its snapshot.
    static func wonTarget() throws -> (target: LevelTarget, start: Vec2, end: Vec2)? {
        for number in candidateLevels {
            let actions: [Action] = try T.certifiedPlan(number) + [.run]
            guard let core: Core = try bare(number, actions), core.play.stage == .won else { continue }
            let snapshot: Snapshot = core.snapshot(time: 0)
            for star in 0..<2 {
                guard let start: Vec2 = starPoint(star, snapshot, orbit: .authored),
                      let end: Vec2 = anyDragEnd(from: start) else { continue }
                return (LevelTarget(number: number, setUp: actions, star: star), start, end)
            }
        }
        return nil
    }

    /// The first candidate level whose opening has both stars that pick.
    static func starsTarget() throws -> LevelTarget? {
        for number in candidateLevels {
            guard let core: Core = try bare(number, []) else { continue }
            let snapshot: Snapshot = core.snapshot(time: 0)
            if starPoint(0, snapshot, orbit: .authored) != nil, starPoint(1, snapshot, orbit: .authored) != nil {
                return LevelTarget(number: number, setUp: [], star: 0)
            }
        }
        return nil
    }
}

@MainActor
@Suite(.serialized) struct BinaryGardensGestureWiringTests {
    typealias Script = BinaryGardensGestureScript
    typealias Core = BinaryGardensExperienceCore
    typealias Snapshot = BinaryGardensSceneSnapshot
    typealias Mirror = BinaryGardensMirror
    typealias ViewOrbit = BinaryGardensViewOrbit
    typealias Action = BinaryGardensAction
    typealias T = BinaryGardensTest

    /// Drives `drag` on `shell` (drawn in `session`): nothing is sent and the digest stays before the release, the
    /// next frame draws the kernel's preview of the change; the release sends exactly one accepted action with the
    /// kernel's verdict, drops the preview and the next frame draws the change.
    func dragChangesOnce(_ drag: Script.Drag, shell: Script.Shell, session: ExperienceSession) throws {
        let ready: Core = try T.core(shell)
        let issued = T.control(drag.change)
        let expected = Script.applied(ready, drag.change)
        #expect(expected.result == .accepted, "the kernel accepts \(issued.control) \(issued.values)")
        let wantedPreview: BinaryGardensPreview? = BinaryGardensPreview.of(drag.change,
                                                                           arrangement: ready.play.arrangement,
                                                                           actionsLeft: ready.play.actionsLeft,
                                                                           level: ready.play.level)
        let digest: String = try T.digest(shell)
        let sentBefore: Script.Sent = Script.sent(shell)
        var time: Double = Script.start

        Script.touch(shell, id: 1, .began, at: drag.start, time: &time)
        Script.moves(shell, id: 1, from: drag.start, to: drag.end, time: &time)
        #expect(Script.sent(shell) == sentBefore, "nothing is sent before the release")
        #expect(try T.digest(shell) == digest, "a preview never changes the digest")
        #expect(try T.core(shell).play == ready.play, "nothing is changed before the release")
        #expect(shell.presenter.mirror.preview == drag.change, "the mirror keeps the preview")
        try T.draw(session)
        let previewing: Snapshot = try Script.drawn(shell)
        let preview: BinaryGardensPreview = try #require(previewing.preview, "the drag is previewed")
        #expect(preview.change == drag.change)
        #expect(preview == wantedPreview, "the preview is the kernel's")
        #expect(preview.refusal == nil, "an accepted change previews no refusal")
        #expect(shell.presenter.mirror.previewRefusalLabel == nil)
        #expect(previewing.arrangement == ready.play.arrangement, "the committed arrangement is still the snapshot's")
        #expect(try T.digest(shell) == digest)

        Script.touch(shell, id: 1, .ended, at: drag.end, time: &time)
        let after: Core = try T.core(shell)
        #expect(after.play == expected.core.play, "the kernel's verdict")
        #expect(after.play.actionsLeft == ready.play.actionsLeft - 1, "one action of the budget is spent")
        let sentAfter: Script.Sent = Script.sent(shell)
        #expect(sentAfter.accepted == sentBefore.accepted + 1, "exactly one \(issued.control)")
        #expect(sentAfter.rejected == sentBefore.rejected)
        #expect(try T.digest(shell) != digest)
        #expect(shell.presenter.refusalLog.isEmpty)
        #expect(shell.presenter.mirror.preview == nil, "the release drops the preview")
        try T.draw(session)
        let drawn: Snapshot = try Script.drawn(shell)
        #expect(drawn.preview == nil, "the next frame draws no preview")
        #expect(drawn.arrangement == after.play.arrangement, "the next frame draws the change")
        #expect(shell.presenter.fallbackReason == nil)
    }

    /// Taps `tap` on `shell`: exactly one accepted action with the kernel's verdict, no preview.
    func tapChangesOnce(_ tap: Script.Tap, shell: Script.Shell, session: ExperienceSession) throws {
        let ready: Core = try T.core(shell)
        let issued = T.control(tap.change)
        let expected = Script.applied(ready, tap.change)
        #expect(expected.result == .accepted, "the kernel accepts \(issued.control) \(issued.values)")
        let digest: String = try T.digest(shell)
        let sentBefore: Script.Sent = Script.sent(shell)
        var time: Double = Script.start

        Script.tap(shell, id: 1, at: tap.point, time: &time)
        let after: Core = try T.core(shell)
        #expect(after.play == expected.core.play, "the kernel's verdict")
        #expect(after.play.actionsLeft == ready.play.actionsLeft - 1, "one action of the budget is spent")
        let sentAfter: Script.Sent = Script.sent(shell)
        #expect(sentAfter.accepted == sentBefore.accepted + 1, "exactly one \(issued.control)")
        #expect(sentAfter.rejected == sentBefore.rejected)
        #expect(try T.digest(shell) != digest)
        #expect(shell.presenter.refusalLog.isEmpty)
        try T.draw(session)
        let drawn: Snapshot = try Script.drawn(shell)
        #expect(drawn.preview == nil, "a tap previews nothing")
        #expect(drawn.arrangement == after.play.arrangement, "the next frame draws the change")
    }

    /// a. A radial star drag previews the ring under the finger and sends exactly one `star.ring`.
    @Test func aRadialStarDragMovesItToARing() async throws {
        let target = try #require(try Script.starDragTarget(ring: true), "a radial star drag fits")
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Script.open(session, number: target.number, setUp: target.setUp)
        try #require(try T.core(shell).play.stage == .playing)
        let snapshot: Snapshot = try Script.drawn(shell)
        let orbit: ViewOrbit = shell.presenter.orbit
        #expect(orbit == .authored)
        let drag: Script.Drag = try #require(Script.ringDrag(target.star, snapshot, orbit: orbit), "a ring drag fits")
        try #require(Script.pick(drag.start, snapshot, orbit: orbit) == .star(target.star))
        try dragChangesOnce(drag, shell: shell, session: session)
    }

    /// b. A tangential star drag previews the grid phase under the finger and sends exactly one `star.phase`.
    @Test func aTangentialStarDragShiftsItsPhase() async throws {
        let target = try #require(try Script.starDragTarget(ring: false), "a tangential star drag fits")
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Script.open(session, number: target.number, setUp: target.setUp)
        try #require(try T.core(shell).play.stage == .playing)
        let snapshot: Snapshot = try Script.drawn(shell)
        let orbit: ViewOrbit = shell.presenter.orbit
        let drag: Script.Drag = try #require(Script.phaseDrag(target.star, snapshot, orbit: orbit),
                                             "a phase drag fits")
        try #require(Script.pick(drag.start, snapshot, orbit: orbit) == .star(target.star))
        if case .phase(_, let step) = drag.change {
            #expect(step % max(snapshot.phaseStep, 1) == 0, "the phase is on the level's phase grid")
        }
        try dragChangesOnce(drag, shell: shell, session: session)
    }

    /// c. A tap on a pip sends exactly one `star.luminosity` for that pip.
    @Test func aPipTapSetsTheLuminosity() async throws {
        let target = try #require(try Script.pipTarget(drag: false), "a pip tap fits")
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Script.open(session, number: target.number, setUp: target.setUp)
        let snapshot: Snapshot = try Script.drawn(shell)
        let orbit: ViewOrbit = shell.presenter.orbit
        let tap: Script.Tap = try #require(Script.pipTap(target.star, snapshot, orbit: orbit), "a pip tap fits")
        try #require(Script.pick(tap.point, snapshot, orbit: orbit) == .pips(target.star))
        try tapChangesOnce(tap, shell: shell, session: session)
    }

    /// c. A sideways drag along the pips previews and sends exactly one `star.luminosity`.
    @Test func aPipDragSetsTheLuminosity() async throws {
        let target = try #require(try Script.pipTarget(drag: true), "a pip drag fits")
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Script.open(session, number: target.number, setUp: target.setUp)
        let snapshot: Snapshot = try Script.drawn(shell)
        let orbit: ViewOrbit = shell.presenter.orbit
        let drag: Script.Drag = try #require(Script.pipDrag(target.star, snapshot, orbit: orbit), "a pip drag fits")
        try #require(Script.pick(drag.start, snapshot, orbit: orbit) == .pips(target.star))
        try dragChangesOnce(drag, shell: shell, session: session)
    }

    /// d. A tap on a dial pip sends exactly one `orbit.tilt` for that step.
    @Test func aDialTapSetsTheTilt() async throws {
        let target = try #require(try Script.dialTarget(drag: false), "a dial tap fits")
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Script.open(session, number: target.number, setUp: target.setUp)
        let snapshot: Snapshot = try Script.drawn(shell)
        let orbit: ViewOrbit = shell.presenter.orbit
        let tap: Script.Tap = try #require(Script.dialTap(snapshot, orbit: orbit), "a dial tap fits")
        try #require(Script.pick(tap.point, snapshot, orbit: orbit) == .dial)
        try tapChangesOnce(tap, shell: shell, session: session)
    }

    /// d. A sideways drag along the dial previews and sends exactly one `orbit.tilt`.
    @Test func aDialDragSetsTheTilt() async throws {
        let target = try #require(try Script.dialTarget(drag: true), "a dial drag fits")
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Script.open(session, number: target.number, setUp: target.setUp)
        let snapshot: Snapshot = try Script.drawn(shell)
        let orbit: ViewOrbit = shell.presenter.orbit
        let drag: Script.Drag = try #require(Script.dialDrag(snapshot, orbit: orbit), "a dial drag fits")
        try #require(Script.pick(drag.start, snapshot, orbit: orbit) == .dial)
        try dragChangesOnce(drag, shell: shell, session: session)
    }

    /// e. A world tap inspects the world (drawn, described) and a second tap clears it; nothing is sent.
    @Test func aWorldTapInspectsAndASecondTapClears() async throws {
        let target = try #require(try Script.worldTarget(), "a world that picks")
        let world: Int = target.star
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Script.open(session, number: target.number, setUp: target.setUp)
        let before: Core = try T.core(shell)
        let snapshot: Snapshot = try Script.drawn(shell)
        let orbit: ViewOrbit = shell.presenter.orbit
        let point: Vec2 = try #require(Script.worldPoint(world, snapshot, orbit: orbit), "the world picks")
        let digest: String = try T.digest(shell)
        let sentBefore: Script.Sent = Script.sent(shell)
        var time: Double = Script.start

        Script.tap(shell, id: 1, at: point, time: &time)
        #expect(shell.presenter.mirror.inspectedWorld == world, "the tap inspects the world")
        #expect(Script.sent(shell) == sentBefore, "an inspection sends nothing")
        #expect(try T.digest(shell) == digest, "an inspection never changes the digest")
        try T.draw(session)
        #expect(try Script.drawn(shell).inspectedWorld == world, "the drawn snapshot marks the world")
        let level: BinaryGardensLevel = before.play.level
        let tick: Int = Mirror.wrappedTick(before.shownTick)
        let words: String = level.worldTickDescription(world, tick: tick, report: before.play.report) + "; "
            + level.worldDescription(world, report: before.play.report)
        #expect(shell.presenter.mirror.inspectedLabel == words)
        let text: String = shell.presenter.describe(try T.core(shell))
        #expect(text.hasSuffix("Inspected " + words + "."), "\(text)")

        time += Script.gesturePause
        Script.tap(shell, id: 2, at: point, time: &time)
        #expect(shell.presenter.mirror.inspectedWorld == nil, "a second tap clears the inspection")
        try T.draw(session)
        #expect(try Script.drawn(shell).inspectedWorld == nil)
        #expect(!shell.presenter.describe(try T.core(shell)).contains("Inspected "))
        #expect(Script.sent(shell) == sentBefore)
        #expect(try T.digest(shell) == digest)
        #expect(try T.core(shell).play == before.play)
        #expect(shell.presenter.refusalLog.isEmpty)
    }

    /// f. A gauge scrub shows the ticks under the finger and a gauge tap inspects its world and shows the tick; no
    /// action spent, no digest change.
    @Test func aGaugeScrubShowsTicks() async throws {
        let target = try #require(try Script.gaugeTarget(), "a gauge row with a scrub and a tap")
        let world: Int = target.star
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Script.open(session, number: target.number, setUp: target.setUp)
        let before: Core = try T.core(shell)
        let snapshot: Snapshot = try Script.drawn(shell)
        let orbit: ViewOrbit = shell.presenter.orbit
        let from: Vec2 = try #require(Script.gaugePoint(world, tick: Script.scrubTicks.from, snapshot, orbit: orbit))
        let to: Vec2 = try #require(Script.gaugePoint(world, tick: Script.scrubTicks.to, snapshot, orbit: orbit))
        let digest: String = try T.digest(shell)
        let rejectedBefore: Int = Script.sent(shell).rejected
        var time: Double = Script.start

        Script.touch(shell, id: 1, .began, at: from, time: &time)
        #expect(try T.core(shell).shownTick == before.shownTick, "touch-down only reads the tick")
        Script.moves(shell, id: 1, from: from, to: to, time: &time)
        #expect(try T.core(shell).shownTick == Script.scrubTicks.to, "the shown tick follows the finger")
        Script.touch(shell, id: 1, .ended, at: to, time: &time)
        var after: Core = try T.core(shell)
        #expect(after.shownTick == Script.scrubTicks.to)
        #expect(after.play == before.play, "a scrub changes no kernel state")
        #expect(after.play.actionsLeft == before.play.actionsLeft, "no action is spent")
        #expect(shell.presenter.mirror.inspectedWorld == nil, "a scrub inspects nothing")
        #expect(Script.sent(shell).rejected == rejectedBefore)
        #expect(try T.digest(shell) == digest, "a shown tick never changes the digest")
        try T.draw(session)
        #expect(shell.presenter.mirror.shownTick == Script.scrubTicks.to, "the panel follows the shown tick")
        #expect(try Script.drawn(shell).shownTick == Script.scrubTicks.to, "the drawn snapshot shows the tick")
        #expect(try Script.drawn(shell).preview == nil, "a scrub previews nothing")

        let drawn: Snapshot = try Script.drawn(shell)
        let tapPoint: Vec2 = try #require(Script.gaugePoint(world, tick: Script.tapTick, drawn, orbit: orbit))
        time += Script.gesturePause
        Script.tap(shell, id: 2, at: tapPoint, time: &time)
        after = try T.core(shell)
        #expect(after.shownTick == Script.tapTick, "a gauge tap shows the tick under the finger")
        #expect(shell.presenter.mirror.inspectedWorld == world, "a gauge tap inspects its world")
        #expect(after.play == before.play)
        #expect(Script.sent(shell).rejected == rejectedBefore)
        #expect(try T.digest(shell) == digest)
        #expect(shell.presenter.refusalLog.isEmpty)
        try T.draw(session)
        #expect(try Script.drawn(shell).inspectedWorld == world)
    }

    /// g. A two-finger drag orbits the camera and changes no digest; "Reset view" and a double tap on empty space
    /// return to the authored orbit.
    @Test func anOrbitChangesTheViewButNotTheDigest() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Script.open(session, number: Script.candidateLevels[0])
        let before: Core = try T.core(shell)
        let digest: String = try T.digest(shell)
        let sentBefore: Script.Sent = Script.sent(shell)
        #expect(shell.presenter.orbit == .authored)
        let snapshot: Snapshot = try Script.drawn(shell)
        let first: Vec2 = try #require(Script.gridPoint(snapshot, orbit: .authored, wanted: .empty),
                                       "empty space picks")
        let second: Vec2 = try #require(Script.gridPoint(snapshot, orbit: .authored, wanted: .empty, away: first,
                                                         minimum: 200), "a second empty point picks")
        let shift: Vec2 = Vec2(100, 0)
        var time: Double = Script.start

        Script.orbit(shell, ids: 1, 2, from: first, second, by: shift, time: &time)
        let orbit: ViewOrbit = shell.presenter.orbit
        #expect(orbit != .authored, "two fingers orbit the camera")
        #expect(orbit == orbit.clamped(), "the orbit stays within its bounds")
        #expect(shell.presenter.gestureState == .idle, "every finger lifted")
        #expect(Script.sent(shell) == sentBefore, "an orbit sends nothing")
        #expect(try T.digest(shell) == digest, "an orbit never changes the digest")
        try T.draw(session)
        #expect(shell.presenter.scene.orbit == orbit, "the scene draws the orbit")
        #expect(shell.presenter.fallbackReason == nil, "\(shell.presenter.fallbackReason ?? "")")
        #expect(try T.digest(shell) == digest)

        shell.presenter.resetView()
        #expect(shell.presenter.orbit == .authored, "Reset view restores the authored orbit")
        #expect(Script.sent(shell) == sentBefore, "Reset view sends nothing")
        #expect(try T.digest(shell) == digest)

        // Orbit again, then a double tap on empty space returns to the authored orbit.
        time += Script.gesturePause
        Script.orbit(shell, ids: 3, 4, from: first, second, by: shift, time: &time)
        let turned: ViewOrbit = shell.presenter.orbit
        #expect(turned != .authored)
        try T.draw(session)
        let drawn: Snapshot = try Script.drawn(shell)
        let empty: Vec2 = try #require(Script.gridPoint(drawn, orbit: turned, wanted: .empty),
                                       "empty space picks at the orbit")
        time += Script.gesturePause
        Script.tap(shell, id: 5, at: empty, time: &time)
        #expect(shell.presenter.orbit == turned, "a single tap on empty space keeps the orbit")
        time += Script.tapGap
        Script.tap(shell, id: 6, at: empty, time: &time)
        #expect(shell.presenter.orbit == .authored, "a double tap on empty space resets the view")
        try T.draw(session)
        #expect(shell.presenter.scene.orbit == .authored)
        #expect(shell.presenter.fallbackReason == nil)
        #expect(Script.sent(shell) == sentBefore, "no kernel action and no tick")
        #expect(try T.digest(shell) == digest)
        let after: Core = try T.core(shell)
        #expect(after.shownTick == before.shownTick)
        #expect(after.play == before.play)
        #expect(shell.presenter.refusalLog.isEmpty)
    }

    /// h. A pip drag with no action left is previewed as refused (named in words), sent once on release and refused;
    /// the mirror shows the refusal in words and the bare code is logged.
    @Test func aRefusedChangeIsPreviewedSentOnceAndLogged() async throws {
        let target = try #require(try Script.budgetTarget(), "a level whose budget can be spent, then a pip drag")
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Script.open(session, number: target.number, setUp: target.setUp)
        let spent: Core = try T.core(shell)
        try #require(spent.play.actionsLeft == 0, "the budget is spent")
        try #require(spent.play.stage == .playing)
        let snapshot: Snapshot = try Script.drawn(shell)
        let orbit: ViewOrbit = shell.presenter.orbit
        let drag: Script.Drag = try #require(Script.pipDrag(target.star, snapshot, orbit: orbit), "a pip drag fits")
        let expected = Script.applied(spent, drag.change)
        #expect(expected.result.code.hasSuffix(Script.budgetCode), "\(expected.result.code)")
        let digest: String = try T.digest(shell)
        let sentBefore: Script.Sent = Script.sent(shell)
        var time: Double = Script.start

        Script.touch(shell, id: 1, .began, at: drag.start, time: &time)
        Script.moves(shell, id: 1, from: drag.start, to: drag.end, time: &time)
        #expect(Script.sent(shell) == sentBefore, "nothing is sent before the release")
        #expect(shell.presenter.mirror.previewRefusal == .budget, "the preview is refused for the budget")
        #expect(shell.presenter.mirror.previewRefusalLabel == Mirror.previewRefusalMessage(.budget),
                "the refused preview is named in words")
        try T.draw(session)
        let previewing: Snapshot = try Script.drawn(shell)
        let preview: BinaryGardensPreview = try #require(previewing.preview, "the drag is previewed")
        #expect(preview.change == drag.change)
        #expect(preview.refusal == .budget, "the kernel's refusal")
        #expect(try T.digest(shell) == digest)

        Script.touch(shell, id: 1, .ended, at: drag.end, time: &time)
        let sentAfter: Script.Sent = Script.sent(shell)
        #expect(sentAfter.accepted == sentBefore.accepted, "nothing was accepted")
        #expect(sentAfter.rejected == sentBefore.rejected + 1, "the change was sent once and refused")
        let message: String = try #require(shell.presenter.mirror.message, "the refusal is shown")
        #expect(message.contains(Mirror.refusalText(code: Script.budgetCode)), "\(message)")
        // Since feature 506 (FR-R02G2106-009) the panel shows the feedback plan's sentence alone.
        #expect(message == "No actions are left: run the light or undo a change.", "\(message)")
        #expect(message == Mirror.refusalMessage(code: Script.rulePrefix + Script.budgetCode), "\(message)")
        #expect(Mirror.refusalText(code: Script.rulePrefix + Script.budgetCode)
                    == Mirror.refusalText(code: Script.budgetCode), "codes are read with or without the prefix")
        #expect(shell.presenter.refusalLog == [Script.budgetCode], "the bare code is logged once")
        #expect(try T.core(shell).play == spent.play, "a refused change changes nothing")
        #expect(try T.digest(shell) == digest)
        try T.draw(session)
        #expect(try Script.drawn(shell).preview == nil, "the release drops the preview")
        #expect(shell.presenter.mirror.previewRefusal == nil)
    }

    /// i. On a won play a star drag sends nothing and the mirror says the play is over.
    @Test func aDragOnAWonPlaySendsNothing() async throws {
        let found = try #require(try Script.wonTarget(), "a won play with a star inside the view")
        let target: Script.LevelTarget = found.target
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Script.open(session, number: target.number, setUp: target.setUp)
        let won: Core = try T.core(shell)
        try #require(won.play.stage == .won, "level \(target.number) is won")
        let snapshot: Snapshot = try Script.drawn(shell)
        let orbit: ViewOrbit = shell.presenter.orbit
        try #require(Script.pick(found.start, snapshot, orbit: orbit) == .star(target.star))
        let digest: String = try T.digest(shell)
        let sentBefore: Script.Sent = Script.sent(shell)
        var time: Double = Script.start

        Script.touch(shell, id: 1, .began, at: found.start, time: &time)
        Script.moves(shell, id: 1, from: found.start, to: found.end, time: &time)
        #expect(shell.presenter.mirror.message == Script.finishedText, "the drag says the play is over")
        Script.touch(shell, id: 1, .ended, at: found.end, time: &time)
        #expect(shell.presenter.mirror.message == Script.finishedText)
        #expect(Script.sent(shell) == sentBefore, "a drag on a won play sends nothing")
        #expect(try T.digest(shell) == digest)
        #expect(try T.core(shell).play == won.play)
        #expect(shell.presenter.refusalLog.isEmpty, "nothing was sent, so nothing was refused")
        try T.draw(session)
        #expect(try Script.drawn(shell).preview == nil, "a won play previews nothing")
    }

    /// j. A tap on a star selects it and explains the drag; a tap on a ring explains the ring drag; nothing is sent.
    @Test func aStarOrRingTapExplains() async throws {
        let target = try #require(try Script.starsTarget(), "both stars pick")
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Script.open(session, number: target.number, setUp: target.setUp)
        let before: Core = try T.core(shell)
        let snapshot: Snapshot = try Script.drawn(shell)
        let orbit: ViewOrbit = shell.presenter.orbit
        let digest: String = try T.digest(shell)
        let sentBefore: Script.Sent = Script.sent(shell)
        var time: Double = Script.start
        let stars: [Int] = [1, 0]

        for star in stars {
            let point: Vec2 = try #require(Script.starPoint(star, snapshot, orbit: orbit), "star \(star) picks")
            Script.tap(shell, id: star + 1, at: point, time: &time)
            #expect(shell.presenter.mirror.message == Script.starTapText, "the tap says how to drag a star")
            #expect(shell.presenter.mirror.selectedStar == star, "a tapped star is selected in the panel")
            #expect(shell.presenter.mirror.phaseTarget == before.play.arrangement.phases[star],
                    "the phase target follows the selected star")
            #expect(Script.sent(shell) == sentBefore, "a tap on a star sends nothing")
            time += Script.gesturePause
        }
        for ring in snapshot.ringRadii.indices.reversed() {
            guard let point: Vec2 = Script.ringPoint(ring, snapshot, orbit: orbit) else { continue }
            Script.tap(shell, id: 10 + ring, at: point, time: &time)
            #expect(shell.presenter.mirror.message == Script.ringTapText, "the tap says how to change a ring")
            #expect(Script.sent(shell) == sentBefore, "a tap on a ring sends nothing")
            break
        }
        #expect(try T.digest(shell) == digest)
        #expect(try T.core(shell).play == before.play)
        try T.draw(session)
        #expect(try Script.drawn(shell).preview == nil, "a tap previews nothing")
        #expect(shell.presenter.refusalLog.isEmpty)
    }

    /// k. A new level and a reset clear the preview, the inspection and the orbit. Since feature 505 `level.next`
    /// needs the next level open (no wrap), so the new level is the daily level of a date naming another level.
    @Test func aNewPlayClearsThePresentation() async throws {
        let target = try #require(try Script.worldTarget(), "a world that picks")
        let world: Int = target.star
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Script.open(session, number: target.number, setUp: target.setUp)
        let snapshot: Snapshot = try Script.drawn(shell)
        let point: Vec2 = try #require(Script.worldPoint(world, snapshot, orbit: .authored), "the world picks")
        let first: Vec2 = try #require(Script.gridPoint(snapshot, orbit: .authored, wanted: .empty),
                                       "empty space picks")
        let second: Vec2 = try #require(Script.gridPoint(snapshot, orbit: .authored, wanted: .empty, away: first,
                                                         minimum: 200), "a second empty point picks")
        var time: Double = Script.start

        Script.tap(shell, id: 1, at: point, time: &time)
        time += Script.gesturePause
        Script.orbit(shell, ids: 2, 3, from: first, second, by: Vec2(100, 0), time: &time)
        try T.draw(session)
        #expect(shell.presenter.mirror.inspectedWorld == world)
        #expect(shell.presenter.orbit != .authored)

        let daily = try #require(Script.otherDaily(target.number))
        let result: ActionResult = shell.presenter.send("mode.daily", daily.date, port: shell.port)
        #expect(result == .accepted, "\(result.code)")
        #expect(try T.core(shell).levelNumber == daily.level)
        #expect(shell.presenter.mirror.inspectedWorld == nil, "the next level clears the inspection")
        #expect(shell.presenter.mirror.preview == nil)
        #expect(shell.presenter.orbit == .authored, "the next level returns the camera to the authored view")
        try T.draw(session)
        #expect(try Script.drawn(shell).inspectedWorld == nil)
        #expect(shell.presenter.scene.orbit == .authored)

        shell.presenter.inspect(0)
        #expect(shell.presenter.mirror.inspectedWorld == 0, "the panel's Inspect inspects")
        try T.draw(session)
        #expect(try Script.drawn(shell).inspectedWorld == 0)
        try shell.reset()
        #expect(try T.core(shell).levelNumber == target.number, "a reset returns to the opening level")
        #expect(shell.presenter.mirror.inspectedWorld == nil, "a reset clears the inspection")
        #expect(shell.presenter.orbit == .authored)
        try T.draw(session)
        #expect(try Script.drawn(shell).inspectedWorld == nil)
        #expect(shell.presenter.refusalLog.isEmpty)
    }

    /// k2. A restore through the shell of a saved play other than the shown one clears the preview, the inspection and
    /// the orbit (spec Edge Cases; FR-R02G2104-016; convergence task T-R02G2104-013).
    @Test func aRestoreClearsThePresentation() async throws {
        let target = try #require(try Script.worldTarget(), "a world that picks")
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Script.open(session, number: target.number, setUp: target.setUp)
        let saved: ExperienceSnapshot = try shell.snapshot()
        let daily = try #require(Script.otherDaily(target.number))
        let result: ActionResult = shell.presenter.send("mode.daily", daily.date, port: shell.port)
        #expect(result == .accepted, "\(result.code)")
        try T.draw(session)
        let snapshot: Snapshot = try Script.drawn(shell)
        let first: Vec2 = try #require(Script.gridPoint(snapshot, orbit: .authored, wanted: .empty),
                                       "empty space picks")
        let second: Vec2 = try #require(Script.gridPoint(snapshot, orbit: .authored, wanted: .empty, away: first,
                                                         minimum: 200), "a second empty point picks")
        var time: Double = Script.start
        shell.presenter.inspect(0)
        Script.orbit(shell, ids: 2, 3, from: first, second, by: Vec2(100, 0), time: &time)
        try T.draw(session)
        #expect(shell.presenter.mirror.inspectedWorld == 0)
        #expect(shell.presenter.orbit != .authored)

        try shell.restore(saved)
        try T.draw(session)
        #expect(try T.core(shell).levelNumber == target.number, "the restore returns to the saved level")
        #expect(shell.presenter.mirror.inspectedWorld == nil, "a restore clears the inspection")
        #expect(shell.presenter.mirror.preview == nil, "a restore clears the preview")
        #expect(shell.presenter.orbit == .authored, "a restore returns the camera to the authored view")
        #expect(try Script.drawn(shell).inspectedWorld == nil)
        #expect(shell.presenter.scene.orbit == .authored)
    }

    /// l. The canvas gestures send the five declared gesture controls; the native controls every declared control.
    @Test func theGestureAndNativeActionSets() {
        let presenter = BinaryGardensPresenter(reduceMotion: false, reduceFlashing: false)
        let gestures: Set<String> = ["star.ring", "star.phase", "star.luminosity", "orbit.tilt", "clock.show"]
        #expect(presenter.gestureActions == gestures)
        #expect(presenter.nativeActions == Set(Core.actionIDs))
        #expect(presenter.gestureActions.isSubset(of: presenter.nativeActions), "the panel can do what a gesture can")
        #expect(presenter.orbit == .authored)
        #expect(presenter.gestureState == .idle)
        #expect(presenter.refusalLog.isEmpty)
        #expect(BinaryGardensPresenter.refusalLogLimit == 64)
    }
}
#endif
