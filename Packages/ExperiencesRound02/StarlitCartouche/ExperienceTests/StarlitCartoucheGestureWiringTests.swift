// StarlitCartoucheGestureWiringTests — feature 454 (R02-G16-04) T-R02G1604-005 (FR-R02G1604-001 … 007;
// SC-R02G1604-001 … 004; clarifications Q1–Q5). On the simulator, through the one app's session host: scripted touches
// go to the presenter's `pointer(_:viewSize:port:)` with the shell's own `port` at a 720 × 480-point view (aspect 1.5),
// following Voxel Origami's wiring tests (feature 444). Targets are projected through the drawn camera of the
// controller's orbit (`StarlitCartoucheSceneGeometry.camera(_:aspect:orbit:)`, then `StarlitCartouchePicker.viewPoint`
// of `StarlitCartoucheSceneGeometry.launchCentre` for a star or the ship's star, of `waitPip` for the slider) on the
// presenter's `lastSnapshot`, and each is confirmed with `StarlitCartouchePicker.pick` at the same view size before any
// touch. Levels are chosen at run time from bare opening cores (seed n − 1 opens level n); the kernel's verdict is the
// one a bare core gives for the same actions.
// Checked:
//   a. a tap on a star chooses it as the destination (core.chosenStar, the drawn snapshot, the mirror); no leg flown,
//      the digest unchanged;
//   b. a double tap on a star while playing flies one leg (`route.choose`, then `route.fly`): one more leg, the
//      fingerprint a bare core gives, a changed digest;
//   c. a drag from the ship over a star previews it ("Fly to star s", the destination chosen) and on release flies one
//      leg; a drag from the ship over a star released on empty space flies nothing and restores the destination
//      chosen before the drag;
//   d. a tap and a drag on the slider choose the wait (core.chosenWait); no leg flown, the digest unchanged;
//   e. a two-finger orbit changes `gestures.orbit` and `scene.orbit` but never the digest; `resetView()` and a double
//      tap on empty space return to `StarlitCartoucheOrbit.authored`;
//   f. a ship drag released over a star without a corridor explains `noCorridorReason` and sends no leg; a double tap
//      on that star sends the leg, the kernel refuses it, the refusal is shown in words and its bare code (without
//      `action.rule.`) logged; a leg the chart fails ends the level as the kernel decides and the panel says so;
//   g. on a won play (level's certified plan issued through the shell) a ship drag sends nothing and `mirror.message`
//      is the finished reason.
// Explicit synthetic timestamps (no clock, no sleep, no wall-clock assertion). Explicit types and plain loops (CI
// type-check rule); no nested closure literals.
#if os(iOS)
import CoreGraphics
import Foundation
import StarlitCartoucheCore
import Testing
@testable import StarlitCartoucheExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreScenes

/// Scripted touches on Starlit Cartouche, placed through the drawn camera.
@MainActor
enum StarlitCartoucheGestureScript {
    typealias Shell = StarlitCartoucheTest.Shell
    typealias Snapshot = StarlitCartoucheSceneSnapshot
    typealias Geometry = StarlitCartoucheSceneGeometry
    typealias Core = StarlitCartoucheExperienceCore
    typealias Picker = StarlitCartouchePicker
    typealias Orbit = StarlitCartoucheOrbit

    /// The view's width in points (aspect 1.5).
    static let viewWidth: Double = 720
    /// The view's height in points.
    static let viewHeight: Double = 480
    /// The view size handed with every event.
    static var viewSize: Vec2 { Vec2(viewWidth, viewHeight) }
    /// The view size as the picker takes it.
    static var size: SIMD2<Double> { SIMD2<Double>(viewWidth, viewHeight) }
    /// The first synthetic timestamp, seconds (any finite value; the controller only compares timestamps).
    static let start: Double = 100
    /// The time between scripted events in seconds (synthetic).
    static let frame: Double = 1.0 / 60
    /// The pause between the two taps of a double tap, seconds (inside the 0.35 s window).
    static let tapGap: Double = 0.1
    /// The pause between two separate gestures, seconds (outside every double-tap window).
    static let gesturePause: Double = 1
    /// The moves of a scripted straight drag.
    static let dragMoves: Int = 6
    /// The shortest ship drag scripted, points (more than the drag distance 16).
    static let minimumDrag: Double = 24
    /// How far inside the view a touch point must lie, points.
    static let inset: Double = 8
    /// The radii in points around a projected centre at which a touch point is tried.
    static let radii: [Double] = [0, 4, 8, 12, 16]
    /// The directions tried at each radius.
    static let directions: Int = 8
    /// The grid step of the empty-space search, points.
    static let gridStep: Double = 12
    /// The candidate levels; the first that fits is used.
    static let candidateLevels: [Int] = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]
    /// The candidate levels of the failing-leg search (breadth first, at most ``failureDepth`` legs).
    static let failureLevels: [Int] = [1, 2, 3, 4, 5, 6]
    /// The longest set-up plus failing leg of the failing-leg search.
    static let failureDepth: Int = 2
    /// The widest frontier of the failing-leg search per depth.
    static let failureFrontier: Int = 8

    /// What the engine has counted so far: accepted and rejected actions.
    struct Sent: Equatable {
        /// The accepted actions.
        let accepted: Int
        /// The rejected actions.
        let rejected: Int
    }

    /// A level and one leg of it: the star and the wait.
    struct LegTarget {
        /// The level number.
        let number: Int
        /// The legs issued before (through the shell) to reach the play.
        let setUp: [StarlitCartoucheAction]
        /// The destination star.
        let star: Int
        /// The wait chosen before the gesture.
        let wait: Int
    }

    /// Opens level `number` (seed `number − 1`) at the scripted view size (one frame drawn).
    static func open(_ session: ExperienceSession, number: Int) async throws -> Shell {
        try await StarlitCartoucheTest.open(session, seed: UInt64(number - 1),
                                            size: CGSize(width: viewWidth, height: viewHeight))
    }

    /// The engine's action counters of `shell`.
    static func sent(_ shell: Shell) -> Sent {
        Sent(accepted: shell.engine.acceptedActions, rejected: shell.engine.rejectedActions)
    }

    /// The snapshot the presenter drew last (the gestures read it).
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

    /// A double tap at `location` with fingers `id` and `id + 1` (lifts ``tapGap`` plus two frames apart).
    static func doubleTap(_ shell: Shell, id: Int, at location: Vec2, time: inout Double) {
        tap(shell, id: id, at: location, time: &time)
        time += tapGap
        tap(shell, id: id + 1, at: location, time: &time)
    }

    /// ``dragMoves`` equal moves of finger `id` from `start` to `end` (no touch-down, no lift).
    static func moves(_ shell: Shell, id: Int, from start: Vec2, to end: Vec2, time: inout Double) {
        let delta: Vec2 = end - start
        for step in 1...dragMoves {
            let t: Double = Double(step) / Double(dragMoves)
            touch(shell, id: id, .moved, at: start + delta * t, time: &time)
        }
    }

    /// Whether `location` lies inside the view with a margin of ``inset`` points.
    static func inside(_ location: Vec2) -> Bool {
        location.x >= inset && location.x <= viewWidth - inset && location.y >= inset
            && location.y <= viewHeight - inset
    }

    /// What the picker gives for `location` on `snapshot` at `orbit`.
    static func pick(_ location: Vec2, _ snapshot: Snapshot, orbit: Orbit) -> StarlitCartouchePick {
        Picker.pick(SIMD2<Double>(location.x, location.y), size: size, snapshot: snapshot, orbit: orbit)
    }

    /// The wait the slider reads at `location` on `snapshot` at `orbit`.
    static func sliderWait(_ location: Vec2, _ snapshot: Snapshot, orbit: Orbit) -> Int {
        Picker.sliderWait(SIMD2<Double>(location.x, location.y), size: size, snapshot: snapshot, orbit: orbit)
    }

    /// World `point` in view points through the drawn camera of `snapshot` at `orbit`; nil when it does not project.
    static func project(_ point: SIMD3<Double>, _ snapshot: Snapshot, orbit: Orbit) -> Vec2? {
        let camera: StarlitCartoucheCamera = Geometry.camera(snapshot, aspect: viewWidth / viewHeight, orbit: orbit)
        guard let p: SIMD2<Double> = Picker.viewPoint(point, size: size, camera: camera) else { return nil }
        return Vec2(p.x, p.y)
    }

    /// A point inside the view near world `centre` (its projection, then rings about it) where the picker gives
    /// `wanted`; nil when none.
    static func point(near centre: SIMD3<Double>, _ snapshot: Snapshot, orbit: Orbit,
                      wanted: StarlitCartouchePick) -> Vec2? {
        guard let c: Vec2 = project(centre, snapshot, orbit: orbit) else { return nil }
        for radius in radii {
            let count: Int = radius == 0 ? 1 : directions
            for k in 0..<count {
                let a: Double = Double(k) * 2 * Double.pi / Double(directions)
                let p: Vec2 = c + Vec2(cos(a), sin(a)) * radius
                if inside(p), pick(p, snapshot, orbit: orbit) == wanted { return p }
            }
        }
        return nil
    }

    /// A point where the picker gives `.star(index)` (index not the ship's star); nil when none.
    static func starPoint(_ index: Int, _ snapshot: Snapshot, orbit: Orbit) -> Vec2? {
        guard index >= 0, index < snapshot.stars.count, index != snapshot.star else { return nil }
        return point(near: Geometry.launchCentre(index, snapshot), snapshot, orbit: orbit, wanted: .star(index))
    }

    /// A point where the picker gives `.ship` (on the ship's star); nil when none.
    static func shipPoint(_ snapshot: Snapshot, orbit: Orbit) -> Vec2? {
        guard snapshot.star >= 0, snapshot.star < snapshot.stars.count else { return nil }
        return point(near: Geometry.launchCentre(snapshot.star, snapshot), snapshot, orbit: orbit, wanted: .ship)
    }

    /// The first grid point inside the view that picks `.empty` and lies at least `minimum` points from `away` (when
    /// given); nil when none.
    static func emptyPoint(_ snapshot: Snapshot, orbit: Orbit, away: Vec2? = nil, minimum: Double = 0) -> Vec2? {
        var y: Double = inset
        while y <= viewHeight - inset {
            var x: Double = inset
            while x <= viewWidth - inset {
                let p: Vec2 = Vec2(x, y)
                var far: Bool = true
                if let away { far = (p - away).length >= minimum }
                if far, pick(p, snapshot, orbit: orbit) == .empty { return p }
                x += gridStep
            }
            y += gridStep
        }
        return nil
    }

    /// The slider points of `snapshot` at `orbit`, by increasing wait: the projected centre of each wait pip j where
    /// the picker gives `.slider` and the slider reads j.
    static func pipPoints(_ snapshot: Snapshot, orbit: Orbit) -> [(wait: Int, point: Vec2)] {
        var result: [(wait: Int, point: Vec2)] = []
        for j in 0..<Geometry.pipCount {
            guard let p: Vec2 = project(Geometry.waitPip(j), snapshot, orbit: orbit), inside(p),
                  pick(p, snapshot, orbit: orbit) == .slider, sliderWait(p, snapshot, orbit: orbit) == j else {
                continue
            }
            result.append((j, p))
        }
        return result
    }

    /// Whether a corridor of `snapshot` joins stars `a` and `b`.
    static func joined(_ a: Int, _ b: Int, _ snapshot: Snapshot) -> Bool {
        for corridor in snapshot.corridors where (corridor.a == a && corridor.b == b)
            || (corridor.a == b && corridor.b == a) {
            return true
        }
        return false
    }

    /// The core `before` after applying `control` with `values`, and the adapter's answer.
    static func applied(_ before: Core, _ control: String, _ values: [Double]) -> (core: Core, result: ActionResult) {
        var copy: Core = before
        let result: ActionResult = copy.apply(ExperienceAction(control: control, values: values, step: 0))
        return (copy, result)
    }

    /// `core` with destination `star` and wait `wait` chosen (`route.choose`; unchanged when refused).
    static func chosen(_ core: Core, star: Int, wait: Int) -> Core {
        applied(core, "route.choose", [Double(star), Double(wait)]).core
    }

    /// The star and wait of `action`.
    nonisolated static func leg(_ action: StarlitCartoucheAction) -> (star: Int, wait: Int) {
        switch action {
        case let .leg(star, wait): (star, wait)
        }
    }

    // MARK: Level choice (from bare cores; an issue is recorded by the caller's `#require` when none fits)

    /// The first candidate level whose opening snapshot has a star other than the ship's and the chosen one with a
    /// touch point (level and star).
    static func tapTarget() throws -> (number: Int, star: Int)? {
        for number in candidateLevels {
            let core: Core = try Core.opening(number: number)
            let snapshot: Snapshot = core.snapshot(time: 0)
            for star in 0..<snapshot.stars.count where star != snapshot.star && star != snapshot.chosenStar {
                if starPoint(star, snapshot, orbit: .authored) != nil { return (number, star) }
            }
        }
        return nil
    }

    /// The first candidate level whose certified plan's first leg (star s, wait w) has a touch point on s once wait w
    /// is chosen (and, with `ship`, a ship point at least ``minimumDrag`` from it). The kernel accepts that leg.
    static func planTarget(ship: Bool) throws -> LegTarget? {
        for number in candidateLevels {
            let legs: [StarlitCartoucheAction] = try StarlitCartoucheTest.certifiedLegs(number)
            guard let first: StarlitCartoucheAction = legs.first else { continue }
            let target: (star: Int, wait: Int) = leg(first)
            let opening: Core = try Core.opening(number: number)
            let ready: Core = chosen(opening, star: opening.chosenStar, wait: target.wait)
            let snapshot: Snapshot = ready.snapshot(time: 0)
            guard snapshot.chosenWait == target.wait,
                  let p: Vec2 = starPoint(target.star, snapshot, orbit: .authored) else { continue }
            if ship {
                guard let s: Vec2 = shipPoint(snapshot, orbit: .authored), (p - s).length >= minimumDrag else {
                    continue
                }
            }
            return LegTarget(number: number, setUp: [], star: target.star, wait: target.wait)
        }
        return nil
    }

    /// The first candidate level with a ship point and a star other than the ship's and the chosen one whose touch
    /// point lies at least ``minimumDrag`` from the ship, and an empty point at least ``minimumDrag`` from the ship
    /// (level and star).
    static func emptyDragTarget() throws -> (number: Int, star: Int)? {
        for number in candidateLevels {
            let core: Core = try Core.opening(number: number)
            let snapshot: Snapshot = core.snapshot(time: 0)
            guard let ship: Vec2 = shipPoint(snapshot, orbit: .authored),
                  emptyPoint(snapshot, orbit: .authored, away: ship, minimum: minimumDrag) != nil else { continue }
            for star in 0..<snapshot.stars.count where star != snapshot.star && star != snapshot.chosenStar {
                guard let p: Vec2 = starPoint(star, snapshot, orbit: .authored) else { continue }
                if (p - ship).length >= minimumDrag { return (number, star) }
            }
        }
        return nil
    }

    /// The first candidate level with at least two slider points on its opening snapshot.
    static func sliderLevel() throws -> Int? {
        for number in candidateLevels {
            let core: Core = try Core.opening(number: number)
            if pipPoints(core.snapshot(time: 0), orbit: .authored).count >= 2 { return number }
        }
        return nil
    }

    /// The first candidate level with a star no corridor joins to the ship's star, whose touch point lies at least
    /// ``minimumDrag`` from a ship point, and whose leg the kernel refuses (level and star).
    static func refusalTarget() throws -> (number: Int, star: Int)? {
        for number in candidateLevels {
            let core: Core = try Core.opening(number: number)
            let snapshot: Snapshot = core.snapshot(time: 0)
            guard let ship: Vec2 = shipPoint(snapshot, orbit: .authored) else { continue }
            for star in 0..<snapshot.stars.count where star != snapshot.star {
                guard !joined(snapshot.star, star, snapshot),
                      let p: Vec2 = starPoint(star, snapshot, orbit: .authored), (p - ship).length >= minimumDrag
                else { continue }
                let ready: Core = chosen(core, star: star, wait: snapshot.chosenWait)
                let flown = applied(ready, "route.fly", [Double(star), Double(snapshot.chosenWait)])
                if !flown.result.isAccepted { return (number, star) }
            }
        }
        return nil
    }

    /// A set-up of at most ``failureDepth`` − 1 accepted legs on a candidate level followed by a leg (star, wait) the
    /// kernel accepts and the chart fails, the star with a touch point once that wait is chosen; found breadth first
    /// through bare cores.
    static func failureTarget() throws -> LegTarget? {
        for number in failureLevels {
            let opening: Core = try Core.opening(number: number)
            var frontier: [Core] = [opening]
            var paths: [[StarlitCartoucheAction]] = [[]]
            for _ in 0..<failureDepth {
                var nextCores: [Core] = []
                var nextPaths: [[StarlitCartoucheAction]] = []
                for index in frontier.indices {
                    let node: Core = frontier[index]
                    for star in 0..<node.play.level.stars.count where star != node.play.star {
                        for wait in Core.waitRange {
                            let ready: Core = chosen(node, star: node.chosenStar, wait: wait)
                            let flown = applied(ready, "route.fly", [Double(star), Double(wait)])
                            guard flown.result.isAccepted else { continue }
                            if flown.core.play.stage == .failed {
                                if starPoint(star, ready.snapshot(time: 0), orbit: .authored) != nil {
                                    return LegTarget(number: number, setUp: paths[index], star: star, wait: wait)
                                }
                            } else if flown.core.play.stage == .playing, nextCores.count < failureFrontier {
                                nextCores.append(flown.core)
                                nextPaths.append(paths[index] + [StarlitCartoucheAction.leg(star, wait)])
                            }
                        }
                    }
                }
                frontier = nextCores
                paths = nextPaths
            }
        }
        return nil
    }

    /// A drag of 40 points from `start` in the first of the four axis directions that ends inside the view.
    static func anyDragEnd(from start: Vec2) -> Vec2? {
        let directions: [Vec2] = [Vec2(1, 0), Vec2(-1, 0), Vec2(0, 1), Vec2(0, -1)]
        for direction in directions {
            let end: Vec2 = start + direction * 40
            if inside(end) { return end }
        }
        return nil
    }

    /// The first candidate level whose certified plan wins and whose won snapshot has a ship point with a 40-point drag
    /// inside the view.
    static func wonLevel() throws -> Int? {
        for number in candidateLevels {
            let legs: [StarlitCartoucheAction] = try StarlitCartoucheTest.certifiedLegs(number)
            let core: Core = try StarlitCartoucheTest.coreAfter(number, legs)
            guard core.play.stage == .won else { continue }
            if let ship: Vec2 = shipPoint(core.snapshot(time: 0), orbit: .authored), anyDragEnd(from: ship) != nil {
                return number
            }
        }
        return nil
    }

    /// Chooses wait `wait` (the destination kept) through the presenter's `send` and draws a frame, so the drawn
    /// snapshot (the stars at their launch positions) shows that wait.
    static func chooseWait(_ session: ExperienceSession, _ shell: Shell, _ wait: Int) throws {
        let core: Core = try StarlitCartoucheTest.core(shell)
        let result: ActionResult = shell.presenter.send("route.choose", [Double(core.chosenStar), Double(wait)],
                                                        port: shell.port)
        #expect(result == .accepted, "route.choose wait \(wait): \(result.code)")
        try StarlitCartoucheTest.draw(session)
    }
}

@MainActor
@Suite(.serialized) struct StarlitCartoucheGestureWiringTests {
    typealias Script = StarlitCartoucheGestureScript
    typealias Core = StarlitCartoucheExperienceCore
    typealias Snapshot = StarlitCartoucheSceneSnapshot
    typealias Presenter = StarlitCartouchePresenter
    typealias Controller = StarlitCartoucheGestureController
    typealias Mirror = StarlitCartoucheMirror
    typealias T = StarlitCartoucheTest

    /// a. A tap on a star chooses it as the destination; no leg is flown and the digest does not change.
    @Test func aTapChoosesADestination() async throws {
        let target = try #require(try Script.tapTarget(), "a star other than the ship's and the chosen one picks")
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Script.open(session, number: target.number)
        let before: Core = try T.core(shell)
        let snapshot: Snapshot = try Script.drawn(shell)
        let orbit: StarlitCartoucheOrbit = shell.presenter.gestures.orbit
        let point: Vec2 = try #require(Script.starPoint(target.star, snapshot, orbit: orbit),
                                       "star \(target.star) picks inside the view")
        try #require(Script.pick(point, snapshot, orbit: orbit) == .star(target.star))
        let digest: String = try T.digest(shell)
        let sentBefore: Script.Sent = Script.sent(shell)
        var time: Double = Script.start

        Script.touch(shell, id: 1, .began, at: point, time: &time)
        #expect(shell.presenter.gestures.state == .starPress)
        Script.touch(shell, id: 1, .ended, at: point, time: &time)
        let after: Core = try T.core(shell)
        #expect(after.chosenStar == target.star, "the tap chooses the star as the destination")
        #expect(after.chosenWait == before.chosenWait, "the wait is kept")
        #expect(after.play.legs.count == before.play.legs.count, "a tap flies no leg")
        #expect(after.play.records.count == before.play.records.count)
        #expect(after.play.fingerprint == before.play.fingerprint)
        let sentAfter: Script.Sent = Script.sent(shell)
        #expect(sentAfter.accepted == sentBefore.accepted + 1, "one route.choose accepted")
        #expect(sentAfter.rejected == sentBefore.rejected)
        #expect(try T.digest(shell) == digest, "a choice never changes the digest")
        try T.draw(session)
        #expect(try Script.drawn(shell).chosenStar == target.star, "the drawn snapshot shows the destination")
        #expect(shell.presenter.mirror.destination == target.star, "the panel follows the destination")
        #expect(shell.presenter.mirror.pending == nil)
        #expect(shell.presenter.mirror.message == nil)
        #expect(shell.presenter.gestures.state == .idle)
        #expect(shell.presenter.refusalLog.isEmpty)
    }

    /// b. A double tap on a star while playing flies one leg: the kernel's verdict as a bare core gives it.
    @Test func aDoubleTapFliesOneLeg() async throws {
        let target = try #require(try Script.planTarget(ship: false), "a certified first leg's star picks")
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Script.open(session, number: target.number)
        try Script.chooseWait(session, shell, target.wait)
        let ready: Core = try T.core(shell)
        try #require(ready.play.stage == .playing)
        let snapshot: Snapshot = try Script.drawn(shell)
        #expect(snapshot.chosenWait == target.wait)
        let orbit: StarlitCartoucheOrbit = shell.presenter.gestures.orbit
        let point: Vec2 = try #require(Script.starPoint(target.star, snapshot, orbit: orbit),
                                       "star \(target.star) picks inside the view")
        try #require(Script.pick(point, snapshot, orbit: orbit) == .star(target.star))
        let expected = Script.applied(ready, "route.fly", [Double(target.star), Double(target.wait)])
        #expect(expected.result == .accepted, "the certified first leg is accepted")
        let digest: String = try T.digest(shell)
        let sentBefore: Script.Sent = Script.sent(shell)
        var time: Double = Script.start

        Script.tap(shell, id: 1, at: point, time: &time)
        let chosen: Core = try T.core(shell)
        #expect(chosen.chosenStar == target.star, "the first tap chooses the star")
        #expect(chosen.play.legs.count == ready.play.legs.count, "the first tap flies nothing")
        #expect(try T.digest(shell) == digest)
        time += Script.tapGap
        Script.tap(shell, id: 2, at: point, time: &time)
        let sentAfter: Script.Sent = Script.sent(shell)
        #expect(sentAfter.accepted == sentBefore.accepted + 2, "route.choose and route.fly accepted")
        #expect(sentAfter.rejected == sentBefore.rejected)
        let after: Core = try T.core(shell)
        #expect(after.play.legs.count == ready.play.legs.count + 1, "the double tap flies one leg")
        #expect(after.play.legs.count == expected.core.play.legs.count)
        #expect(after.play.fingerprint == expected.core.play.fingerprint, "the kernel's verdict")
        #expect(after.play.stage == expected.core.play.stage)
        #expect(try T.digest(shell) != digest, "the leg changes the digest")
        #expect(shell.presenter.mirror.pending == nil)
        #expect(shell.presenter.mirror.message == nil)
        #expect(shell.presenter.gestures.state == .idle)
        #expect(shell.presenter.refusalLog.isEmpty)
    }

    /// c. A drag from the ship over a star previews that leg and on release flies it.
    @Test func aShipDragOverAStarFliesOneLeg() async throws {
        let target = try #require(try Script.planTarget(ship: true),
                                  "a certified first leg's star picks away from the ship")
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Script.open(session, number: target.number)
        try Script.chooseWait(session, shell, target.wait)
        let ready: Core = try T.core(shell)
        try #require(ready.play.stage == .playing)
        let snapshot: Snapshot = try Script.drawn(shell)
        let orbit: StarlitCartoucheOrbit = shell.presenter.gestures.orbit
        let ship: Vec2 = try #require(Script.shipPoint(snapshot, orbit: orbit), "the ship picks inside the view")
        let point: Vec2 = try #require(Script.starPoint(target.star, snapshot, orbit: orbit),
                                       "star \(target.star) picks inside the view")
        try #require(Script.pick(ship, snapshot, orbit: orbit) == .ship)
        try #require(Script.pick(point, snapshot, orbit: orbit) == .star(target.star))
        try #require((point - ship).length >= Script.minimumDrag)
        #expect(Script.joined(snapshot.star, target.star, snapshot), "a corridor joins the ship to the star")
        let expected = Script.applied(ready, "route.fly", [Double(target.star), Double(target.wait)])
        #expect(expected.result == .accepted)
        let digest: String = try T.digest(shell)
        let rejectedBefore: Int = Script.sent(shell).rejected
        var time: Double = Script.start

        Script.touch(shell, id: 1, .began, at: ship, time: &time)
        #expect(shell.presenter.gestures.state == .shipPress)
        Script.moves(shell, id: 1, from: ship, to: point, time: &time)
        #expect(shell.presenter.gestures.state == .shipDrag)
        let pendingText: String = Presenter.pendingLegText(star: target.star)
        #expect(pendingText == "Fly to star \(target.star)")
        #expect(shell.presenter.mirror.pending == pendingText, "the pending leg is shown while dragging")
        let previewing: Core = try T.core(shell)
        #expect(previewing.chosenStar == target.star, "the preview shows the pending destination")
        #expect(previewing.play.legs.count == ready.play.legs.count, "nothing is flown before the release")
        #expect(try T.digest(shell) == digest)
        let described: String = shell.presenter.describe(previewing)
        #expect(described.contains(pendingText + "."), "\(described)")
        Script.touch(shell, id: 1, .ended, at: point, time: &time)
        #expect(shell.presenter.mirror.pending == nil, "the pending leg is cleared on release")
        let after: Core = try T.core(shell)
        #expect(after.play.legs.count == ready.play.legs.count + 1, "the release flies one leg")
        #expect(after.play.fingerprint == expected.core.play.fingerprint, "the kernel's verdict")
        #expect(after.play.stage == expected.core.play.stage)
        #expect(Script.sent(shell).rejected == rejectedBefore)
        #expect(try T.digest(shell) != digest, "the leg changes the digest")
        #expect(shell.presenter.gestures.state == .idle)
        #expect(shell.presenter.refusalLog.isEmpty)
    }

    /// c. A drag from the ship over a star released on empty space flies nothing and restores the destination chosen
    /// before the drag.
    @Test func aShipDragReleasedOnEmptySpaceFliesNothing() async throws {
        let target = try #require(try Script.emptyDragTarget(), "a ship, a star and empty space pick")
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Script.open(session, number: target.number)
        let before: Core = try T.core(shell)
        let snapshot: Snapshot = try Script.drawn(shell)
        let orbit: StarlitCartoucheOrbit = shell.presenter.gestures.orbit
        let ship: Vec2 = try #require(Script.shipPoint(snapshot, orbit: orbit), "the ship picks inside the view")
        let point: Vec2 = try #require(Script.starPoint(target.star, snapshot, orbit: orbit),
                                       "star \(target.star) picks inside the view")
        let empty: Vec2 = try #require(Script.emptyPoint(snapshot, orbit: orbit, away: ship,
                                                         minimum: Script.minimumDrag), "empty space picks")
        try #require(Script.pick(ship, snapshot, orbit: orbit) == .ship)
        try #require(Script.pick(point, snapshot, orbit: orbit) == .star(target.star))
        try #require(Script.pick(empty, snapshot, orbit: orbit) == .empty)
        try #require(target.star != before.chosenStar)
        let digest: String = try T.digest(shell)
        let rejectedBefore: Int = Script.sent(shell).rejected
        var time: Double = Script.start

        Script.touch(shell, id: 1, .began, at: ship, time: &time)
        Script.moves(shell, id: 1, from: ship, to: point, time: &time)
        #expect(shell.presenter.gestures.state == .shipDrag)
        #expect(shell.presenter.mirror.pending == Presenter.pendingLegText(star: target.star))
        #expect(try T.core(shell).chosenStar == target.star, "the preview chooses the pending destination")
        Script.moves(shell, id: 1, from: point, to: empty, time: &time)
        Script.touch(shell, id: 1, .ended, at: empty, time: &time)
        let after: Core = try T.core(shell)
        #expect(after.chosenStar == before.chosenStar, "the destination chosen before the drag is restored")
        #expect(after.chosenWait == before.chosenWait)
        #expect(after.play.legs.count == before.play.legs.count, "a release on empty space flies nothing")
        #expect(after.play.records.count == before.play.records.count)
        #expect(after.play.fingerprint == before.play.fingerprint)
        #expect(Script.sent(shell).rejected == rejectedBefore)
        #expect(try T.digest(shell) == digest)
        #expect(shell.presenter.mirror.pending == nil)
        #expect(shell.presenter.gestures.state == .idle)
        #expect(shell.presenter.refusalLog.isEmpty)
    }

    /// d. A tap and a drag on the slider choose the wait; no leg is flown and the digest does not change.
    @Test func theSliderChoosesTheWait() async throws {
        let number: Int = try #require(try Script.sliderLevel(), "two wait pips pick as the slider")
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Script.open(session, number: number)
        let before: Core = try T.core(shell)
        let snapshot: Snapshot = try Script.drawn(shell)
        let orbit: StarlitCartoucheOrbit = shell.presenter.gestures.orbit
        let pips: [(wait: Int, point: Vec2)] = Script.pipPoints(snapshot, orbit: orbit)
        try #require(pips.count >= 2, "two wait pips pick as the slider")
        let tapped: (wait: Int, point: Vec2) = pips[pips.count - 1]
        try #require(tapped.wait != before.chosenWait)
        let digest: String = try T.digest(shell)
        let rejectedBefore: Int = Script.sent(shell).rejected
        var time: Double = Script.start

        Script.touch(shell, id: 1, .began, at: tapped.point, time: &time)
        #expect(shell.presenter.gestures.state == .sliderDrag)
        Script.touch(shell, id: 1, .ended, at: tapped.point, time: &time)
        let afterTap: Core = try T.core(shell)
        #expect(afterTap.chosenWait == tapped.wait, "a tap on the slider chooses the wait under it")
        #expect(afterTap.chosenStar == before.chosenStar, "the destination is kept")
        #expect(afterTap.play.legs.count == before.play.legs.count, "the slider flies no leg")
        #expect(afterTap.play.fingerprint == before.play.fingerprint)
        #expect(try T.digest(shell) == digest, "a wait never changes the digest")
        #expect(shell.presenter.gestures.state == .idle)

        try T.draw(session)
        let redrawn: Snapshot = try Script.drawn(shell)
        #expect(redrawn.chosenWait == tapped.wait)
        #expect(shell.presenter.mirror.wait == tapped.wait, "the panel follows the wait")
        let again: [(wait: Int, point: Vec2)] = Script.pipPoints(redrawn, orbit: orbit)
        try #require(again.count >= 2, "two wait pips still pick as the slider")
        let from: (wait: Int, point: Vec2) = again[again.count - 1]
        let to: (wait: Int, point: Vec2) = again[0]
        try #require(from.wait != to.wait)
        time += Script.gesturePause
        Script.touch(shell, id: 2, .began, at: from.point, time: &time)
        Script.moves(shell, id: 2, from: from.point, to: to.point, time: &time)
        #expect(try T.core(shell).chosenWait == to.wait, "the wait follows the finger along the slider")
        Script.touch(shell, id: 2, .ended, at: to.point, time: &time)
        let afterDrag: Core = try T.core(shell)
        #expect(afterDrag.chosenWait == to.wait, "a slider drag chooses the wait where it ends")
        #expect(afterDrag.chosenStar == before.chosenStar)
        #expect(afterDrag.play.legs.count == before.play.legs.count, "the slider flies no leg")
        #expect(afterDrag.play.records.count == before.play.records.count)
        #expect(afterDrag.play.fingerprint == before.play.fingerprint)
        #expect(Script.sent(shell).rejected == rejectedBefore)
        #expect(try T.digest(shell) == digest)
        #expect(shell.presenter.mirror.pending == nil)
        #expect(shell.presenter.gestures.state == .idle)
        #expect(shell.presenter.refusalLog.isEmpty)
    }

    /// e. A two-finger drag orbits the camera and changes no digest; "Reset view" and a double tap on empty space
    /// return to the authored orbit.
    @Test func anOrbitChangesTheViewButNotTheDigest() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Script.open(session, number: Script.candidateLevels[0])
        let before: Core = try T.core(shell)
        let digest: String = try T.digest(shell)
        let sentBefore: Script.Sent = Script.sent(shell)
        #expect(shell.presenter.gestures.orbit == .authored)
        #expect(shell.presenter.scene.orbit == .authored)
        let snapshot: Snapshot = try Script.drawn(shell)
        let first: Vec2 = try #require(Script.emptyPoint(snapshot, orbit: .authored), "empty space picks")
        let second: Vec2 = try #require(Script.emptyPoint(snapshot, orbit: .authored, away: first, minimum: 200),
                                        "a second empty point picks")
        let shift: Vec2 = Vec2(100, 0)
        var time: Double = Script.start

        Script.touch(shell, id: 1, .began, at: first, time: &time)
        Script.touch(shell, id: 2, .began, at: second, time: &time)
        #expect(shell.presenter.gestures.state == .orbiting)
        Script.touch(shell, id: 1, .moved, at: first + shift, time: &time)
        Script.touch(shell, id: 2, .moved, at: second + shift, time: &time)
        Script.touch(shell, id: 1, .ended, at: first + shift, time: &time)
        Script.touch(shell, id: 2, .ended, at: second + shift, time: &time)
        let orbit: StarlitCartoucheOrbit = shell.presenter.gestures.orbit
        #expect(orbit != .authored, "two fingers orbit the camera")
        #expect(orbit == orbit.clamped())
        #expect(shell.presenter.scene.orbit == orbit, "the scene takes the controller's orbit")
        #expect(shell.presenter.gestures.state == .idle)
        #expect(Script.sent(shell) == sentBefore, "an orbit sends nothing")
        #expect(try T.digest(shell) == digest, "an orbit never changes the digest")
        try T.draw(session)
        #expect(shell.presenter.fallbackReason == nil, "\(shell.presenter.fallbackReason ?? "")")
        #expect(shell.presenter.scene.orbit == orbit)
        #expect(try T.digest(shell) == digest)

        shell.presenter.resetView()
        #expect(shell.presenter.gestures.orbit == .authored, "Reset view restores the authored orbit")
        #expect(shell.presenter.scene.orbit == .authored)

        // Orbit again, then a double tap on empty space returns to the authored orbit.
        time += Script.gesturePause
        Script.touch(shell, id: 3, .began, at: first, time: &time)
        Script.touch(shell, id: 4, .began, at: second, time: &time)
        Script.touch(shell, id: 3, .moved, at: first + shift, time: &time)
        Script.touch(shell, id: 4, .moved, at: second + shift, time: &time)
        Script.touch(shell, id: 3, .ended, at: first + shift, time: &time)
        Script.touch(shell, id: 4, .ended, at: second + shift, time: &time)
        let turned: StarlitCartoucheOrbit = shell.presenter.gestures.orbit
        #expect(turned != .authored)
        try T.draw(session)
        let drawn: Snapshot = try Script.drawn(shell)
        let empty: Vec2 = try #require(Script.emptyPoint(drawn, orbit: turned), "empty space picks at the orbit")
        try #require(Script.pick(empty, drawn, orbit: turned) == .empty)
        time += Script.gesturePause
        Script.tap(shell, id: 5, at: empty, time: &time)
        #expect(shell.presenter.gestures.orbit == turned, "a single tap on empty space keeps the orbit")
        time += Script.tapGap
        Script.tap(shell, id: 6, at: empty, time: &time)
        #expect(shell.presenter.gestures.orbit == .authored, "a double tap on empty space resets the view")
        #expect(shell.presenter.scene.orbit == .authored)
        try T.draw(session)
        #expect(shell.presenter.fallbackReason == nil)
        #expect(Script.sent(shell) == sentBefore)
        #expect(try T.digest(shell) == digest)
        let after: Core = try T.core(shell)
        #expect(after.chosenStar == before.chosenStar)
        #expect(after.chosenWait == before.chosenWait)
        #expect(shell.presenter.refusalLog.isEmpty)
    }

    /// f. A ship drag released over a star without a corridor explains why and sends no leg; a double tap on that star
    /// sends the leg, which the kernel refuses: the refusal is shown in words and its bare code logged.
    @Test func aRefusedLegIsShownAndLogged() async throws {
        let target = try #require(try Script.refusalTarget(), "a star without a corridor from the ship picks")
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Script.open(session, number: target.number)
        let before: Core = try T.core(shell)
        try #require(before.play.stage == .playing)
        let snapshot: Snapshot = try Script.drawn(shell)
        let orbit: StarlitCartoucheOrbit = shell.presenter.gestures.orbit
        let ship: Vec2 = try #require(Script.shipPoint(snapshot, orbit: orbit), "the ship picks inside the view")
        let point: Vec2 = try #require(Script.starPoint(target.star, snapshot, orbit: orbit),
                                       "star \(target.star) picks inside the view")
        try #require(Script.pick(ship, snapshot, orbit: orbit) == .ship)
        try #require(Script.pick(point, snapshot, orbit: orbit) == .star(target.star))
        #expect(!Script.joined(snapshot.star, target.star, snapshot))
        let wait: Int = snapshot.chosenWait
        let chosen = Script.applied(before, "route.choose", [Double(target.star), Double(wait)])
        #expect(chosen.result == .accepted)
        let expected = Script.applied(chosen.core, "route.fly", [Double(target.star), Double(wait)])
        #expect(!expected.result.isAccepted, "the kernel refuses a leg without a corridor")
        let digest: String = try T.digest(shell)
        let sentBefore: Script.Sent = Script.sent(shell)
        var time: Double = Script.start

        // The ship drag: the release explains and sends no leg.
        Script.touch(shell, id: 1, .began, at: ship, time: &time)
        Script.moves(shell, id: 1, from: ship, to: point, time: &time)
        #expect(shell.presenter.mirror.pending == Presenter.pendingLegText(star: target.star))
        Script.touch(shell, id: 1, .ended, at: point, time: &time)
        let reason: String = Controller.noCorridorReason(target.star)
        #expect(reason == "No corridor joins the ship's star to star \(target.star)")
        #expect(shell.presenter.mirror.message == reason, "the release says why it flies nothing")
        #expect(shell.presenter.mirror.pending == nil)
        let dragged: Core = try T.core(shell)
        #expect(dragged.chosenStar == before.chosenStar, "the destination chosen before the drag is restored")
        #expect(dragged.play.legs.count == before.play.legs.count)
        #expect(dragged.play.fingerprint == before.play.fingerprint)
        #expect(Script.sent(shell).rejected == sentBefore.rejected, "no leg was sent")
        #expect(shell.presenter.refusalLog.isEmpty)
        #expect(try T.digest(shell) == digest)

        // The double tap: the leg is sent and refused.
        try T.draw(session)
        let redrawn: Snapshot = try Script.drawn(shell)
        try #require(Script.pick(point, redrawn, orbit: orbit) == .star(target.star))
        let sentMiddle: Script.Sent = Script.sent(shell)
        time += Script.gesturePause
        Script.doubleTap(shell, id: 2, at: point, time: &time)
        let sentAfter: Script.Sent = Script.sent(shell)
        #expect(sentAfter.accepted == sentMiddle.accepted + 1, "the first tap's route.choose accepted")
        #expect(sentAfter.rejected == sentMiddle.rejected + 1, "the route.fly refused")
        let code: String = try #require(shell.presenter.refusalLog.last, "the refusal's code is logged")
        #expect(shell.presenter.refusalLog.count == 1)
        #expect(code == Mirror.bareCode(expected.result.code), "\(code) vs \(expected.result.code)")
        #expect(!code.hasPrefix(Mirror.rulePrefix), "the bare code, without the engine's prefix: \(code)")
        #expect(code == "r02-g16.action", "\(code)")
        let message: String = try #require(shell.presenter.mirror.message, "the refusal is shown")
        #expect(message == "That change was refused: \(Mirror.refusalText(code: code)).", "\(message)")
        #expect(Mirror.refusalText(code: code) == "no corridor can be flown there now")
        #expect(Mirror.refusalText(code: Mirror.rulePrefix + code) == Mirror.refusalText(code: code))
        let after: Core = try T.core(shell)
        #expect(after.play.legs.count == before.play.legs.count, "a refused leg changes nothing")
        #expect(after.play.fingerprint == before.play.fingerprint)
        #expect(after.play.stage == .playing)
        #expect(try T.digest(shell) == digest)
        #expect(shell.presenter.gestures.state == .idle)
    }

    /// f. A double tap on a star whose leg the chart fails sends the leg; the kernel ends the level and the panel says
    /// why.
    @Test func aFailingLegEndsTheLevel() async throws {
        let target = try #require(try Script.failureTarget(), "a leg the chart fails, its star picking")
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Script.open(session, number: target.number)
        let accepted: Int = T.issue(shell, target.setUp)
        #expect(accepted == target.setUp.count)
        try Script.chooseWait(session, shell, target.wait)
        let ready: Core = try T.core(shell)
        try #require(ready.play.stage == .playing)
        let snapshot: Snapshot = try Script.drawn(shell)
        #expect(snapshot.chosenWait == target.wait)
        let orbit: StarlitCartoucheOrbit = shell.presenter.gestures.orbit
        let point: Vec2 = try #require(Script.starPoint(target.star, snapshot, orbit: orbit),
                                       "star \(target.star) picks inside the view")
        try #require(Script.pick(point, snapshot, orbit: orbit) == .star(target.star))
        let chosen = Script.applied(ready, "route.choose", [Double(target.star), Double(target.wait)])
        let expected = Script.applied(chosen.core, "route.fly", [Double(target.star), Double(target.wait)])
        #expect(expected.result == .accepted)
        #expect(expected.core.play.stage == .failed, "the chart fails the leg")
        let digest: String = try T.digest(shell)
        let rejectedBefore: Int = Script.sent(shell).rejected
        var time: Double = Script.start

        Script.doubleTap(shell, id: 1, at: point, time: &time)
        let after: Core = try T.core(shell)
        #expect(after.play.stage == .failed, "the failing leg ends the level")
        #expect(after.play.fingerprint == expected.core.play.fingerprint, "the kernel's verdict")
        #expect(after.play.failure == expected.core.play.failure)
        #expect(Script.sent(shell).rejected == rejectedBefore, "the leg was accepted")
        #expect(shell.presenter.refusalLog.isEmpty)
        #expect(shell.presenter.mirror.message == nil)
        #expect(try T.digest(shell) != digest, "the failed leg changes the digest")
        let described: String = shell.presenter.describe(after)
        let failure: String = try #require(Mirror.failureText(after.play.failure), "the failure in words")
        #expect(shell.presenter.mirror.status == "Failed: " + failure, "\(shell.presenter.mirror.status)")
        #expect(shell.presenter.mirror.failureText == failure)
        #expect(described.contains(failure), "\(described)")
        #expect(described.contains(Presenter.finishedMessage + "."), "\(described)")
        #expect(shell.presenter.gestures.state == .idle)
    }

    /// g. On a won play a ship drag sends nothing and the mirror explains that the play is over.
    @Test func aShipDragOnAWonPlaySendsNothing() async throws {
        let number: Int = try #require(try Script.wonLevel(), "a won play with the ship inside the view")
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Script.open(session, number: number)
        let legs: [StarlitCartoucheAction] = try T.certifiedLegs(number)
        try #require(!legs.isEmpty, "level \(number) has a certified plan")
        let accepted: Int = T.issue(shell, legs)
        #expect(accepted == legs.count)
        let won: Core = try T.core(shell)
        try #require(won.play.stage == .won, "the certified plan wins level \(number)")
        try T.draw(session)
        let snapshot: Snapshot = try Script.drawn(shell)
        #expect(snapshot.stage == .won)
        let orbit: StarlitCartoucheOrbit = shell.presenter.gestures.orbit
        let ship: Vec2 = try #require(Script.shipPoint(snapshot, orbit: orbit), "the ship picks inside the view")
        try #require(Script.pick(ship, snapshot, orbit: orbit) == .ship)
        let end: Vec2 = try #require(Script.anyDragEnd(from: ship), "a 40-point drag fits inside the view")
        let digest: String = try T.digest(shell)
        let sentBefore: Script.Sent = Script.sent(shell)
        var time: Double = Script.start

        Script.touch(shell, id: 1, .began, at: ship, time: &time)
        Script.moves(shell, id: 1, from: ship, to: end, time: &time)
        #expect(shell.presenter.mirror.pending == nil, "a finished play previews nothing")
        #expect(shell.presenter.mirror.message == Controller.finishedReason)
        Script.touch(shell, id: 1, .ended, at: end, time: &time)
        #expect(Script.sent(shell) == sentBefore, "a ship drag on a won play sends nothing")
        #expect(try T.digest(shell) == digest)
        #expect(try T.core(shell).play.fingerprint == won.play.fingerprint)
        #expect(shell.presenter.mirror.message == Controller.finishedReason)
        #expect(Presenter.finishedMessage == Controller.finishedReason)
        #expect(Controller.finishedReason == "The play is over: undo or go to the next level")
        #expect(shell.presenter.refusalLog.isEmpty, "nothing was refused: nothing was sent")
        #expect(shell.presenter.gestures.state == .idle)
        let described: String = shell.presenter.describe(try T.core(shell))
        #expect(described.contains(Presenter.finishedMessage + "."), "\(described)")
        #expect(shell.presenter.mirror.status == "Won")
    }
}
#endif
