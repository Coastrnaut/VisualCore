// ChronoConstellatorGestureWiringTests — feature 354 (R02-G06-04) T-R02G0604-005 (FR-R02G0604-001 … 008;
// clarifications Q1–Q5). On the simulator, through the one app's session host: scripted touches go to the presenter's
// `pointer(_:viewSize:port:)` with the shell's own `port` at a 720 × 480-point view (aspect 1.5). Targets are placed
// through the drawn camera (`presenter.gestures.camera(viewSize:snapshot:)`, `ChronoConstellatorSceneGeometry.project`)
// and confirmed with `ChronoConstellatorPicker`. What the port sent is recorded on the shell's engine (its accepted and
// rejected action counters) and the core, compared with a bare core that applied the expected action itself. Checked:
//   1. a star drag at tick 0 from the star's projected node centre to the projected centre of another cell of its loop
//      sends exactly one accepted `star.phase`: the star's phase becomes that cell's loop index and the digest changes;
//      mid-drag the candidate cell is outlined and described;
//   2. a scrub on the timeline band steps to the released tick t′ (or the deciding tick); a scrub back to a smaller
//      tick ends in the digest of a plain replay (a fresh session stepping straight to that tick);
//   3. a long press (≥ 0.5 s by event timestamps, no movement) on a star adds its standard hold; a second removes it;
//   4. a tap on a star picks it in the panel; a two-finger orbit and a double tap on empty space change no digest and
//      send nothing; `resetView()` restores the authored orbit;
//   5. a star drag after a time step sends nothing and shows `tickZeroMessage`; a refused action (a long press when
//      the edit budget is used up, and an out-of-range `star.phase` sent by the presenter) is shown in the panel and
//      its code appended to `refusalLog`;
//   6. a `.cancelled` phase mid-drag sends nothing.
// Synthetic timestamps; no sleep, no wall-clock assertion; few frames. Explicit types and plain loops (CI type-check
// rule).
#if os(iOS)
import ChronoConstellatorCore
import CoreGraphics
import Foundation
import Testing
@testable import ChronoConstellatorExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreScenes

/// A star drag target: the star, its touch-down point, the release point and the loop index there.
struct ChronoConstellatorDragTarget {
    let star: Int
    let start: Vec2
    let end: Vec2
    let index: Int
    let cell: Int
}

/// Scripted touches on Chrono Constellator, placed through the drawn camera.
@MainActor
enum ChronoConstellatorGestureScript {
    typealias Shell = ExperienceShell<ChronoConstellatorPresenter>
    typealias Snapshot = ChronoConstellatorSceneSnapshot
    typealias Geometry = ChronoConstellatorSceneGeometry
    typealias Core = ChronoConstellatorExperienceCore

    /// The view's size in points (aspect 1.5, the frame-check aspect).
    static let viewWidth: Double = 720
    static let viewHeight: Double = 480
    /// The view size handed with every event.
    static var viewSize: Vec2 { Vec2(viewWidth, viewHeight) }
    /// The time between scripted events in seconds (synthetic).
    static let frame: Double = 1.0 / 60
    /// The smallest travel of a scripted phase drag in points (above the 16-point drag distance).
    static let dragTravel: Double = 24
    /// The moves of a scripted drag.
    static let dragMoves: Int = 4

    /// What the engine has counted so far: accepted and rejected actions.
    struct Sent: Equatable {
        let accepted: Int
        let rejected: Int
    }

    /// Opens level `seed % 100 + 1` at the scripted view size (one frame drawn).
    static func open(_ session: ExperienceSession, seed: UInt64 = 0) async throws -> Shell {
        try await ChronoConstellatorTest.open(session, seed: seed, size: CGSize(width: viewWidth, height: viewHeight))
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

    /// `world` projected into view points through the camera the gestures use now; nil behind the camera.
    static func viewPoint(_ shell: Shell, _ world: SIMD3<Double>) throws -> Vec2? {
        let snapshot: Snapshot = try drawn(shell)
        let camera: ChronoConstellatorCamera =
            try #require(shell.presenter.gestures.camera(viewSize: viewSize, snapshot: snapshot))
        guard let unit: SIMD2<Double> = Geometry.project(world, camera: camera) else { return nil }
        return Vec2(unit.x * viewWidth, unit.y * viewHeight)
    }

    /// What the picker gives for `location` at the current orbit.
    static func pick(_ shell: Shell, _ location: Vec2) throws -> ChronoConstellatorPick {
        let snapshot: Snapshot = try drawn(shell)
        return ChronoConstellatorPicker.pick(SIMD2<Double>(location.x, location.y),
                                             size: SIMD2<Double>(viewWidth, viewHeight), snapshot: snapshot,
                                             orbit: shell.presenter.gestures.orbit)
    }

    /// The picker's loop index of `star` at `location` at the current orbit.
    static func loopIndex(_ shell: Shell, star: Int, _ location: Vec2) throws -> Int? {
        let snapshot: Snapshot = try drawn(shell)
        return ChronoConstellatorPicker.loopIndex(star: star, at: SIMD2<Double>(location.x, location.y),
                                                  size: SIMD2<Double>(viewWidth, viewHeight), snapshot: snapshot,
                                                  orbit: shell.presenter.gestures.orbit)
    }

    /// The picker's scrub tick at `location` at the current orbit.
    static func tick(_ shell: Shell, _ location: Vec2) throws -> Int? {
        let snapshot: Snapshot = try drawn(shell)
        return ChronoConstellatorPicker.tick(at: SIMD2<Double>(location.x, location.y),
                                             size: SIMD2<Double>(viewWidth, viewHeight), snapshot: snapshot,
                                             orbit: shell.presenter.gestures.orbit)
    }

    /// Whether `location` lies inside the view with a margin of `inset` points.
    static func inside(_ location: Vec2, inset: Double = 0) -> Bool {
        location.x >= inset && location.x <= viewWidth - inset && location.y >= inset
            && location.y <= viewHeight - inset
    }

    /// The distance between two view points.
    static func distance(_ a: Vec2, _ b: Vec2) -> Double {
        let dx: Double = a.x - b.x
        let dy: Double = a.y - b.y
        return (dx * dx + dy * dy).squareRoot()
    }

    /// Star `star`'s projected node centre when it picks that star (inside the view with `inset`), else nil.
    static func starPoint(_ shell: Shell, star: Int, inset: Double = 1) throws -> Vec2? {
        let snapshot: Snapshot = try drawn(shell)
        guard let point: Vec2 = try viewPoint(shell, Geometry.starCentre(star, snapshot)) else { return nil }
        guard inside(point, inset: inset) else { return nil }
        return try pick(shell, point) == .star(star) ? point : nil
    }

    /// The first star (preferring index `from` and later) whose projected node centre picks it.
    static func starTarget(_ shell: Shell, from: Int = 0, inset: Double = 1) throws -> (star: Int, point: Vec2)? {
        let count: Int = try drawn(shell).stars.count
        for offset in 0..<count {
            let star: Int = (from + offset) % Swift.max(count, 1)
            if let point: Vec2 = try starPoint(shell, star: star, inset: inset) { return (star, point) }
        }
        return nil
    }

    /// The first star drag at the current orbit: from a star's node centre to the centre of another loop cell whose
    /// first loop index differs from the star's phase, at least `dragTravel` points away and picked as that index.
    static func dragTarget(_ shell: Shell) throws -> ChronoConstellatorDragTarget? {
        let snapshot: Snapshot = try drawn(shell)
        for star in 0..<snapshot.stars.count {
            guard let start: Vec2 = try starPoint(shell, star: star) else { continue }
            let loop: [Int] = snapshot.stars[star].loop
            for k in 0..<loop.count {
                let cell: Int = loop[k]
                guard cell != snapshot.stars[star].cell, let index: Int = loop.firstIndex(of: cell),
                      index != snapshot.phases[star] else { continue }
                guard let end: Vec2 = try viewPoint(shell, Geometry.cellCentre(cell, snapshot)) else { continue }
                guard inside(end, inset: 1), distance(start, end) >= dragTravel else { continue }
                guard try loopIndex(shell, star: star, end) == index else { continue }
                return ChronoConstellatorDragTarget(star: star, start: start, end: end, index: index, cell: cell)
            }
        }
        return nil
    }

    /// The point on the timeline band (field z = halfDepth − 0.1·u, y = 0) at the x fraction of tick `tick`, when it
    /// picks the band and scrubs to exactly `tick`; else nil.
    static func bandPoint(_ shell: Shell, tick: Int) throws -> Vec2? {
        let snapshot: Snapshot = try drawn(shell)
        guard snapshot.tickLimit > 0, tick >= 0, tick <= snapshot.tickLimit else { return nil }
        let u: Double = Geometry.cellSize(snapshot)
        let halfWidth: Double = Double(snapshot.columns) * u / 2
        let halfDepth: Double = Double(snapshot.rows) * u / 2
        let fraction: Double = Double(tick) / Double(snapshot.tickLimit)
        let world: SIMD3<Double> = SIMD3<Double>(-halfWidth + fraction * 2 * halfWidth, 0, halfDepth - 0.1 * u)
        guard let point: Vec2 = try viewPoint(shell, world), inside(point, inset: 1) else { return nil }
        guard case .timeline = try pick(shell, point) else { return nil }
        guard try self.tick(shell, point) == tick else { return nil }
        return point
    }

    /// Puts finger `id` down at `start` and moves it to `end` in `dragMoves` steps (not released).
    static func dragWithoutRelease(_ shell: Shell, id: Int = 1, from start: Vec2, to end: Vec2, time: inout Double) {
        touch(shell, id: id, .began, at: start, time: &time)
        for step in 1...dragMoves {
            let f: Double = Double(step) / Double(dragMoves)
            let point: Vec2 = Vec2(start.x + (end.x - start.x) * f, start.y + (end.y - start.y) * f)
            touch(shell, id: id, .moved, at: point, time: &time)
        }
    }

    /// A tap (down and up at `location`, one frame apart) with finger `id`.
    static func tap(_ shell: Shell, id: Int, at location: Vec2, time: inout Double) {
        touch(shell, id: id, .began, at: location, time: &time)
        touch(shell, id: id, .ended, at: location, time: &time)
    }

    /// A long press on `location` with finger `id`: down, held 0.6 s by the timestamps, up without movement.
    static func longPress(_ shell: Shell, id: Int, at location: Vec2, time: inout Double) {
        touch(shell, id: id, .began, at: location, time: &time)
        time += 0.6
        touch(shell, id: id, .ended, at: location, time: &time)
    }

    /// The core `before` after applying `control` with `values` itself, and the adapter's answer.
    static func applied(_ before: Core, _ control: String, _ values: [Double]) -> (core: Core, result: ActionResult) {
        var copy: Core = before
        let result: ActionResult = copy.apply(ExperienceAction(control: control, values: values, step: 0))
        return (copy, result)
    }

    /// Whether `snapshot` has a hold of `star` starting at tick 1 (the gesture's standard hold).
    static func hasStandardHold(_ snapshot: Snapshot, star: Int) -> Bool {
        let start: Int = ChronoConstellatorGestureController.holdStart
        for hold in snapshot.holds where hold.star == star && hold.start == start {
            return true
        }
        return false
    }
}

@MainActor
@Suite(.serialized) struct ChronoConstellatorGestureWiringTests {
    typealias Script = ChronoConstellatorGestureScript
    typealias Core = ChronoConstellatorExperienceCore

    /// 1. A star drag at tick 0 to another cell of its loop sends one accepted `star.phase [star, index]`.
    @Test func aStarDragSendsOnePhase() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Script.open(session)
        #expect(shell.state == .active)
        #expect(shell.presenter.gestures.orbit == .authored)
        let before: Core = try ChronoConstellatorTest.core(shell)
        #expect(before.play.stage == .playing)
        #expect(before.play.tick == 0)
        let target: ChronoConstellatorDragTarget =
            try #require(try Script.dragTarget(shell), "a star and another loop cell visible at the authored orbit")
        let columns: Int = try Script.drawn(shell).columns
        let digest: String = try ChronoConstellatorTest.digest(shell)
        let sentBefore: Script.Sent = Script.sent(shell)
        var time: Double = 0

        Script.dragWithoutRelease(shell, from: target.start, to: target.end, time: &time)
        #expect(shell.presenter.gestures.state == .starDrag)
        #expect(shell.presenter.gestures.draggedStar == target.star)
        #expect(shell.presenter.gestures.candidateCell == target.cell, "the candidate is the cell under the finger")
        #expect(Script.sent(shell) == sentBefore, "nothing is sent before the release")
        let text: String = shell.presenter.describe(try ChronoConstellatorTest.core(shell))
        let row: Int = target.cell / columns + 1
        let column: Int = target.cell % columns + 1
        #expect(text.hasPrefix("Star \(target.star + 1) ("), "\(text)")
        #expect(text.contains("would start at row \(row), column \(column)"), "\(text)")
        try ChronoConstellatorTest.draw(session)

        Script.touch(shell, id: 1, .ended, at: target.end, time: &time)
        let expected = Script.applied(before, "star.phase", [Double(target.star), Double(target.index)])
        #expect(expected.result == .accepted)
        let sentAfter: Script.Sent = Script.sent(shell)
        #expect(sentAfter.accepted == sentBefore.accepted + 1, "exactly one action accepted")
        #expect(sentAfter.rejected == sentBefore.rejected, "nothing refused")
        let after: Core = try ChronoConstellatorTest.core(shell)
        #expect(after.play.fingerprint == expected.core.play.fingerprint, "the drag is the adapter's star.phase")
        #expect(after.snapshot(time: 0).phases[target.star] == target.index)
        #expect(try ChronoConstellatorTest.digest(shell) != digest, "the phase change changes the digest")
        #expect(shell.presenter.mirror.message == nil)
        #expect(shell.presenter.gestures.state == .idle)
        #expect(shell.presenter.gestures.candidateCell == nil)
        #expect(shell.presenter.refusalLog.isEmpty)
    }

    /// 2. A scrub on the timeline band steps to the released tick; a scrub back ends in a plain replay's digest.
    @Test func aScrubStepsAndAScrubBackMatchesAPlainReplay() async throws {
        var level: Int = 0
        var back: Int = 0
        var scrubbedDigest: String = ""
        do {
            let session = ExperienceSession()
            defer { session.close() }
            let shell = try await Script.open(session)
            let opening: Core = try ChronoConstellatorTest.core(shell)
            level = opening.levelNumber
            #expect(opening.play.stage == .playing)
            let limit: Int = try Script.drawn(shell).tickLimit
            var forward: Int = 0
            var forwardPoint: Vec2 = Vec2(0, 0)
            var t: Int = 2
            while t <= Swift.min(limit, 16) && forward == 0 {
                if let point: Vec2 = try Script.bandPoint(shell, tick: t) {
                    forward = t
                    forwardPoint = point
                }
                t += 1
            }
            try #require(forward >= 2, "a band point for a tick ≥ 2 at the authored orbit")
            let sentBefore: Script.Sent = Script.sent(shell)
            var time: Double = 0

            Script.touch(shell, id: 1, .began, at: forwardPoint, time: &time)
            #expect(shell.presenter.gestures.state == .scrub)
            #expect(shell.presenter.gestures.scrubTick == forward)
            let text: String = shell.presenter.describe(opening)
            #expect(text.hasPrefix("Scrub to tick \(forward) of \(limit)"), "\(text)")
            Script.touch(shell, id: 1, .ended, at: forwardPoint, time: &time)
            let expected = Script.applied(opening, "time.step", [Double(forward)])
            #expect(expected.result == .accepted)
            let sentAfter: Script.Sent = Script.sent(shell)
            #expect(sentAfter.accepted == sentBefore.accepted + 1, "one time.step accepted")
            #expect(sentAfter.rejected == sentBefore.rejected)
            let stepped: Core = try ChronoConstellatorTest.core(shell)
            #expect(stepped.play.fingerprint == expected.core.play.fingerprint, "the scrub is the adapter's step")
            #expect(stepped.play.tick == expected.core.play.tick, "tick t′ or the deciding tick")
            #expect(stepped.play.tick <= forward)
            #expect(stepped.play.stage != .won, "a fresh level is not won by waiting")
            try ChronoConstellatorTest.draw(session)

            let reached: Int = stepped.play.tick
            var backPoint: Vec2? = nil
            var candidate: Int = reached - 1
            while candidate >= 0 && backPoint == nil {
                if let point: Vec2 = try Script.bandPoint(shell, tick: candidate) {
                    back = candidate
                    backPoint = point
                }
                candidate -= 1
            }
            let point: Vec2 = try #require(backPoint, "a band point for a tick below \(reached)")
            let sentMiddle: Script.Sent = Script.sent(shell)
            Script.touch(shell, id: 2, .began, at: point, time: &time)
            #expect(shell.presenter.gestures.state == .scrub)
            Script.touch(shell, id: 2, .ended, at: point, time: &time)
            let sentEnd: Script.Sent = Script.sent(shell)
            let actions: Int = back > 0 ? 2 : 1
            #expect(sentEnd.accepted == sentMiddle.accepted + actions, "rewind, then step when t″ > 0")
            #expect(sentEnd.rejected == sentMiddle.rejected)
            var replay: Core = try Core.opening(number: level)
            if back > 0 {
                let result: ActionResult =
                    replay.apply(ExperienceAction(control: "time.step", values: [Double(back)], step: 0))
                #expect(result == .accepted)
            }
            let scrubbed: Core = try ChronoConstellatorTest.core(shell)
            #expect(scrubbed.play.tick == back)
            #expect(scrubbed.levelNumber == replay.levelNumber)
            #expect(scrubbed.play.fingerprint == replay.play.fingerprint, "the scrub back is a plain replay")
            #expect(shell.presenter.mirror.message == nil)
            scrubbedDigest = try ChronoConstellatorTest.digest(shell)
        }

        // The plain replay through a fresh session of the same seed: step straight to t″.
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Script.open(session)
        #expect(try ChronoConstellatorTest.core(shell).levelNumber == level)
        if back > 0 {
            #expect(shell.handle(control: "time.step", values: [Double(back)]) == .accepted)
        }
        #expect(try ChronoConstellatorTest.digest(shell) == scrubbedDigest, "the digest of a plain replay")
    }

    /// 3. A long press on a star adds its standard hold; a second long press removes it.
    @Test func aLongPressTogglesTheStandardHold() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Script.open(session)
        let before: Core = try ChronoConstellatorTest.core(shell)
        let target = try #require(try Script.starTarget(shell), "a star visible at the authored orbit")
        #expect(!Script.hasStandardHold(before.snapshot(time: 0), star: target.star))
        let digest: String = try ChronoConstellatorTest.digest(shell)
        let sentBefore: Script.Sent = Script.sent(shell)
        var time: Double = 0

        Script.longPress(shell, id: 1, at: target.point, time: &time)
        let hold: [Double] = [Double(target.star), Double(ChronoConstellatorGestureController.holdStart),
                              Double(ChronoConstellatorGestureController.holdLength)]
        let expected = Script.applied(before, "star.hold", hold)
        #expect(expected.result == .accepted)
        let sentHeld: Script.Sent = Script.sent(shell)
        #expect(sentHeld.accepted == sentBefore.accepted + 1, "one star.hold accepted")
        #expect(sentHeld.rejected == sentBefore.rejected)
        let held: Core = try ChronoConstellatorTest.core(shell)
        #expect(held.play.fingerprint == expected.core.play.fingerprint)
        #expect(Script.hasStandardHold(held.snapshot(time: 0), star: target.star), "the hold is present")
        #expect(try ChronoConstellatorTest.digest(shell) != digest)
        #expect(shell.presenter.mirror.message == nil)

        try ChronoConstellatorTest.draw(session)
        let again: Vec2 = try #require(try Script.starPoint(shell, star: target.star), "the star is still visible")
        Script.longPress(shell, id: 2, at: again, time: &time)
        let sentReleased: Script.Sent = Script.sent(shell)
        #expect(sentReleased.accepted == sentHeld.accepted + 1, "one star.release accepted")
        #expect(sentReleased.rejected == sentHeld.rejected)
        let released: Core = try ChronoConstellatorTest.core(shell)
        #expect(!Script.hasStandardHold(released.snapshot(time: 0), star: target.star), "the hold is removed")
        #expect(released.play.spent == before.play.spent)
        #expect(shell.presenter.gestures.state == .idle)
    }

    /// 4. A tap on a star picks it; a two-finger orbit and a double tap on empty space change no digest and send
    /// nothing; `resetView()` restores the authored orbit.
    @Test func aTapPicksAndOrbitAndDoubleTapSendNothing() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Script.open(session)
        let digest: String = try ChronoConstellatorTest.digest(shell)
        let sentBefore: Script.Sent = Script.sent(shell)
        var time: Double = 0
        _ = shell.presenter.describe(try ChronoConstellatorTest.core(shell))
        let target = try #require(try Script.starTarget(shell, from: 1), "a star visible at the authored orbit")

        Script.tap(shell, id: 1, at: target.point, time: &time)
        #expect(shell.presenter.mirror.pickedStar == target.star, "the tap picks the star in the panel")
        #expect(Script.sent(shell) == sentBefore, "a tap sends no action")
        #expect(try ChronoConstellatorTest.digest(shell) == digest)

        let first: Vec2 = Vec2(8, 8)
        let second: Vec2 = Vec2(8, Script.viewHeight - 8)
        let shift: Double = 100
        Script.touch(shell, id: 2, .began, at: first, time: &time)
        Script.touch(shell, id: 3, .began, at: second, time: &time)
        #expect(shell.presenter.gestures.state == .orbiting)
        Script.touch(shell, id: 2, .moved, at: Vec2(first.x + shift, first.y), time: &time)
        Script.touch(shell, id: 3, .moved, at: Vec2(second.x + shift, second.y), time: &time)
        Script.touch(shell, id: 2, .ended, at: Vec2(first.x + shift, first.y), time: &time)
        Script.touch(shell, id: 3, .ended, at: Vec2(second.x + shift, second.y), time: &time)
        let orbit: ChronoConstellatorOrbit = shell.presenter.gestures.orbit
        #expect(orbit != .authored, "two fingers orbit the camera")
        #expect(shell.presenter.gestures.state == .idle)
        #expect(Script.sent(shell) == sentBefore, "an orbit sends nothing")
        #expect(try ChronoConstellatorTest.digest(shell) == digest, "an orbit never changes the digest")
        try ChronoConstellatorTest.draw(session)
        #expect(shell.presenter.scene.orbit == orbit, "the scene draws the controller's orbit")

        shell.presenter.resetView()
        #expect(shell.presenter.gestures.orbit == .authored, "Reset view restores the authored orbit")
        try ChronoConstellatorTest.draw(session)
        #expect(shell.presenter.scene.orbit == .authored)

        Script.touch(shell, id: 4, .began, at: first, time: &time)
        Script.touch(shell, id: 5, .began, at: second, time: &time)
        Script.touch(shell, id: 4, .moved, at: Vec2(first.x + shift, first.y), time: &time)
        Script.touch(shell, id: 5, .moved, at: Vec2(second.x + shift, second.y), time: &time)
        Script.touch(shell, id: 4, .ended, at: Vec2(first.x + shift, first.y), time: &time)
        Script.touch(shell, id: 5, .ended, at: Vec2(second.x + shift, second.y), time: &time)
        #expect(shell.presenter.gestures.orbit != .authored)
        try ChronoConstellatorTest.draw(session)
        #expect(try Script.pick(shell, first) == .empty, "the corner is empty space")
        Script.tap(shell, id: 6, at: first, time: &time)
        #expect(shell.presenter.gestures.orbit != .authored, "one tap does not reset")
        Script.tap(shell, id: 7, at: first, time: &time)
        #expect(shell.presenter.gestures.orbit == .authored, "a double tap on empty space resets the view")
        #expect(Script.sent(shell) == sentBefore, "a double tap sends no action")
        #expect(try ChronoConstellatorTest.digest(shell) == digest)
        #expect(shell.presenter.mirror.message == nil)
        try ChronoConstellatorTest.draw(session)
        #expect(shell.presenter.scene.orbit == .authored)
        #expect(try ChronoConstellatorTest.digest(shell) == digest)
    }

    /// 5a. A star drag after a time step sends nothing and explains that edits are made at tick 0.
    @Test func aStarDragAfterAStepShowsTheTickZeroMessage() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Script.open(session)
        #expect(shell.handle(control: "time.step", values: [1]) == .accepted)
        let stepped: Core = try ChronoConstellatorTest.core(shell)
        try #require(stepped.play.stage == .playing, "one tick of a fresh level keeps playing")
        #expect(stepped.play.tick == 1)
        try ChronoConstellatorTest.draw(session)
        #expect(try Script.drawn(shell).tick == 1)
        let target = try #require(try Script.starTarget(shell, inset: Script.dragTravel + 2), "a star visible")
        let digest: String = try ChronoConstellatorTest.digest(shell)
        let sentBefore: Script.Sent = Script.sent(shell)
        var time: Double = 0
        let right: Vec2 = Vec2(target.point.x + Script.dragTravel, target.point.y)

        Script.dragWithoutRelease(shell, from: target.point, to: right, time: &time)
        #expect(shell.presenter.gestures.state == .starDrag)
        #expect(shell.presenter.gestures.candidateCell == nil, "no candidate after tick 0")
        Script.touch(shell, id: 1, .ended, at: right, time: &time)
        #expect(Script.sent(shell) == sentBefore, "a star drag after tick 0 sends nothing")
        #expect(try ChronoConstellatorTest.digest(shell) == digest)
        #expect(shell.presenter.mirror.message == ChronoConstellatorPresenter.tickZeroMessage)
        #expect(shell.presenter.refusalLog.isEmpty, "nothing was refused: nothing was sent")
    }

    /// 5b. A refused action is shown in the panel and its code kept in `refusalLog`: a long press when the edit
    /// budget is used up, and an out-of-range `star.phase` the presenter sends.
    @Test func aRefusedActionIsShownAndLogged() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Script.open(session)
        let target = try #require(try Script.starTarget(shell), "a star visible at the authored orbit")
        let star: Int = target.star

        // Use up the budget with one-tick holds from tick 13 on (clear of the standard hold 1 … 10), every star.
        let limit: Int = try ChronoConstellatorTest.core(shell).play.level.tickLimit
        let count: Int = try Script.drawn(shell).stars.count
        for q in 0..<count {
            var start: Int = 13
            while start <= limit {
                let left: Int = try ChronoConstellatorTest.core(shell).play.remaining
                if left <= 0 { break }
                _ = shell.handle(control: "star.hold", values: [Double(q), Double(start), 1])
                start += 2
            }
        }
        // A short tick limit: start phases of the other stars cover the rest of the budget.
        for q in 0..<count where q != star {
            let snapshot: ChronoConstellatorSceneSnapshot = try ChronoConstellatorTest.core(shell).snapshot(time: 0)
            let length: Int = snapshot.stars[q].loop.count
            guard snapshot.remaining > 0, length > 1 else { continue }
            let next: Int = (snapshot.phases[q] + 1) % length
            _ = shell.handle(control: "star.phase", values: [Double(q), Double(next)])
        }
        let full: Core = try ChronoConstellatorTest.core(shell)
        try #require(full.play.remaining == 0, "the budget is used up")
        try ChronoConstellatorTest.draw(session)
        let point: Vec2 = try #require(try Script.starPoint(shell, star: star), "the star is still visible")
        #expect(!Script.hasStandardHold(try Script.drawn(shell), star: star))
        let hold: [Double] = [Double(star), Double(ChronoConstellatorGestureController.holdStart),
                              Double(ChronoConstellatorGestureController.holdLength)]
        let expected = Script.applied(full, "star.hold", hold)
        #expect(expected.result != .accepted, "the kernel refuses a hold over the budget")
        let digest: String = try ChronoConstellatorTest.digest(shell)
        let sentBefore: Script.Sent = Script.sent(shell)
        let logBefore: Int = shell.presenter.refusalLog.count
        var time: Double = 0

        Script.longPress(shell, id: 1, at: point, time: &time)
        let sentAfter: Script.Sent = Script.sent(shell)
        #expect(sentAfter.accepted == sentBefore.accepted)
        #expect(sentAfter.rejected == sentBefore.rejected + 1, "one star.hold refused")
        #expect(try ChronoConstellatorTest.digest(shell) == digest)
        #expect(shell.presenter.refusalLog.count == logBefore + 1)
        #expect(shell.presenter.refusalLog.last == expected.result.code)
        #expect(shell.presenter.mirror.message == "That change was refused: \(expected.result.code)")

        // An out-of-range start phase sent through the presenter's own path.
        let phase: ActionResult = shell.presenter.send("star.phase", [Double(star), 99], port: shell.port)
        #expect(phase != .accepted)
        #expect(shell.presenter.refusalLog.count == logBefore + 2)
        #expect(shell.presenter.refusalLog.last == phase.code)
        #expect(shell.presenter.mirror.message == "That change was refused: \(phase.code)")
        #expect(try ChronoConstellatorTest.digest(shell) == digest)
    }

    /// 6. A `.cancelled` phase mid-drag sends nothing; the gesture actions are native actions.
    @Test func aCancelledDragSendsNothing() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Script.open(session)
        let gestureActions: Set<String> = shell.presenter.gestureActions
        let want: Set<String> = ["star.phase", "star.hold", "star.release", "time.step", "time.rewind"]
        #expect(gestureActions == want)
        #expect(gestureActions.isSubset(of: shell.presenter.nativeActions))

        let target: ChronoConstellatorDragTarget =
            try #require(try Script.dragTarget(shell), "a star and another loop cell visible at the authored orbit")
        let before: Core = try ChronoConstellatorTest.core(shell)
        let digest: String = try ChronoConstellatorTest.digest(shell)
        let sentBefore: Script.Sent = Script.sent(shell)
        var time: Double = 0

        Script.dragWithoutRelease(shell, from: target.start, to: target.end, time: &time)
        #expect(shell.presenter.gestures.candidateCell == target.cell, "the drag previews before the cancel")
        Script.touch(shell, id: 1, .cancelled, at: target.end, time: &time)
        #expect(shell.presenter.gestures.state == .idle)
        #expect(shell.presenter.gestures.candidateCell == nil)
        #expect(Script.sent(shell) == sentBefore, "a cancelled drag sends no phase")
        #expect(try ChronoConstellatorTest.core(shell).play.fingerprint == before.play.fingerprint)
        #expect(try ChronoConstellatorTest.digest(shell) == digest)
        #expect(shell.presenter.mirror.message == nil)
        try ChronoConstellatorTest.draw(session)
        #expect(shell.presenter.scene.candidateCell == nil)
    }
}
#endif
