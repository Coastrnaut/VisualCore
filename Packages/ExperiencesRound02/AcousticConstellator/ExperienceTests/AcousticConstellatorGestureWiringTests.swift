// AcousticConstellatorGestureWiringTests — feature 424 (R02-G13-04) T-R02G1304-005 (FR-R02G1304-001 … 007)
// On the simulator, through the one app's session host: scripted touches go to the presenter's
// `pointer(_:viewSize:port:)` with the shell's own `port` at a 720 × 480-point view (aspect 1.5). Targets are star
// centres, points on a link's spline (`AcousticConstellatorSceneGeometry.splinePoint` between its stars' centres) and
// coherence bar centres, projected through the camera of the controller's orbit
// (`AcousticConstellatorSceneGeometry.camera(_:aspect:orbit:)`, then `AcousticConstellatorPicker.viewPoint`) into view
// points (origin top left) and confirmed with `AcousticConstellatorPicker.pick` (a drag's release point with
// `AcousticConstellatorPicker.starAt`, the dragged star excluded) on the presenter's `lastSnapshot` before any touch.
// Every level is chosen at run time from the Core (bare opening cores and their snapshots): the first candidate whose
// targets all pick inside the view and whose expected actions a bare core accepts (or refuses). What the port sent is
// read from the shell's engine (accepted and rejected action counters), the core and the digest, compared with a bare
// core that applied the expected action.
// Checked:
//   1. a tap on a star while playing sends one `star.nudge [s, 1]` (actions spent + 1, phase + 1 mod 12) and chooses
//      the star in the mirror;
//   2. a drag from star a released on star b links the unlinked pair (one `link.add`); while dragging the scene's
//      filament runs from a to b's centre, after the release it is gone; a second drag from a to b unlinks it (one
//      `link.remove`);
//   3. a drag onto a fixed pair sends nothing and shows `fixedText`;
//   4. a tap on a link chooses its pair, sends nothing and shows `linkText` (", fixed." for a fixed link, ", placed."
//      for a link the player placed);
//   5. a tap on a coherence bar sends one `constellation.listen`: the play ends won or failed;
//   6. a two-finger drag orbits and never changes the digest; a double tap on empty space and `resetView()` return to
//      `.authored`;
//   7. a link drag over the degree or link limit is refused by the kernel: shown in words and its code kept in
//      `refusalLog`;
//   8. on a won play (the certified solution sent through the shell) a link drag sends nothing and the mirror shows
//      `AcousticConstellatorPresenter.finishedMessage`, which the description also contains;
//   9. the gesture actions are a subset of the native actions.
// Synthetic timestamps based on the system uptime; no sleep, no wall-clock assertion. Explicit types and plain loops
// (CI type-check rule).
#if os(iOS)
import AcousticConstellatorCore
import CoreGraphics
import Foundation
import Testing
@testable import AcousticConstellatorExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreScenes

/// Scripted touches on Acoustic Constellator, placed through the drawn camera.
@MainActor
enum AcousticConstellatorGestureScript {
    typealias Shell = ExperienceShell<AcousticConstellatorPresenter>
    typealias Snapshot = AcousticConstellatorSceneSnapshot
    typealias Geometry = AcousticConstellatorSceneGeometry
    typealias Core = AcousticConstellatorExperienceCore
    typealias Picker = AcousticConstellatorPicker
    typealias Controller = AcousticConstellatorGestureController
    typealias Orbit = AcousticConstellatorOrbit
    typealias Link = AcousticConstellatorLink

    /// The view's width in points (aspect 1.5).
    static let viewWidth: Double = 720
    /// The view's height in points.
    static let viewHeight: Double = 480
    /// The view size handed with every event.
    static var viewSize: Vec2 { Vec2(viewWidth, viewHeight) }
    /// The view size as the picker takes it.
    static var size: SIMD2<Double> { SIMD2<Double>(viewWidth, viewHeight) }
    /// The time between scripted events in seconds (synthetic).
    static let frame: Double = 1.0 / 60
    /// The moves of a scripted drag.
    static let dragMoves: Int = 6
    /// The grid step in points of the search for empty space.
    static let gridStep: Double = 12
    /// The least distance in points between a drag's start and end (the controller's drag distance with room).
    static var dragRoom: Double { Controller.dragDistance + 4 }
    /// The candidate levels of the general tests (most open with fixed links); the first that fits is used.
    static let candidateLevels: [Int] = [1, 2, 5, 7, 8, 9, 11, 13, 14, 15, 16, 21]
    /// The candidate levels of the refusal test: each reaches a link refused by the degree or link limit after one
    /// accepted link (from the levels' rules; the Core confirms it at run time).
    static let refusalLevels: [Int] = [33, 42, 45, 49, 50, 52, 58, 59, 60]
    /// The fractions along a link's spline at which a touch point is tried.
    static let fractions: [Double] = [0.5, 0.4, 0.6, 0.3, 0.7, 0.25, 0.75, 0.2, 0.8]

    /// What the engine has counted so far: accepted and rejected actions.
    struct Sent: Equatable {
        /// The accepted actions.
        let accepted: Int
        /// The rejected actions.
        let rejected: Int
    }

    /// A link drag: from star `from` at view point `start` to star `to` at view point `end`.
    struct Drag {
        /// The dragged star.
        let from: Int
        /// The star the drag is released on.
        let to: Int
        /// The touch-down point (the dragged star's projected centre).
        let start: Vec2
        /// The release point (the target star's projected centre).
        let end: Vec2
    }

    /// A refused link drag: the link issued first (accepted) and the drag whose link the kernel then refuses.
    struct Refusal {
        /// The level.
        let number: Int
        /// The link issued through the shell before the drag.
        let prepared: Link
        /// The drag whose link is refused.
        let drag: Drag
        /// The code a bare core gives for the refused link.
        let code: String
    }

    /// Opens level `number` (seed `number − 1`) at the scripted view size (one frame drawn).
    static func open(_ session: ExperienceSession, number: Int) async throws -> Shell {
        try await AcousticConstellatorTest.open(session, seed: UInt64(number - 1),
                                                size: CGSize(width: viewWidth, height: viewHeight))
    }

    /// A synthetic clock start near the system uptime.
    static func clock() -> Double {
        ProcessInfo.processInfo.systemUptime + 1
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

    /// ``dragMoves`` equal moves of finger `id` from `start` to `end` (no touch-down, no lift).
    static func moves(_ shell: Shell, id: Int, from start: Vec2, to end: Vec2, time: inout Double) {
        let delta: Vec2 = end - start
        for step in 1...dragMoves {
            let t: Double = Double(step) / Double(dragMoves)
            touch(shell, id: id, .moved, at: start + delta * t, time: &time)
        }
    }

    /// The first half of a link drag with finger `id`: down on the dragged star and moved onto the target star (not
    /// lifted).
    static func dragOver(_ shell: Shell, id: Int, _ drag: Drag, time: inout Double) {
        touch(shell, id: id, .began, at: drag.start, time: &time)
        moves(shell, id: id, from: drag.start, to: drag.end, time: &time)
    }

    /// A whole link drag with finger `id`: down, moves, lifted on the target star.
    static func linkDrag(_ shell: Shell, id: Int, _ drag: Drag, time: inout Double) {
        dragOver(shell, id: id, drag, time: &time)
        touch(shell, id: id, .ended, at: drag.end, time: &time)
    }

    /// A two-finger orbit: fingers `id` and `id + 1` down near the left corners, both moved `shift` points right and
    /// lifted.
    static func orbit(_ shell: Shell, id: Int, shift: Double = 100, time: inout Double) {
        let first: Vec2 = Vec2(8, 8)
        let second: Vec2 = Vec2(8, viewHeight - 8)
        touch(shell, id: id, .began, at: first, time: &time)
        touch(shell, id: id + 1, .began, at: second, time: &time)
        touch(shell, id: id, .moved, at: Vec2(first.x + shift, first.y), time: &time)
        touch(shell, id: id + 1, .moved, at: Vec2(second.x + shift, second.y), time: &time)
        touch(shell, id: id, .ended, at: Vec2(first.x + shift, first.y), time: &time)
        touch(shell, id: id + 1, .ended, at: Vec2(second.x + shift, second.y), time: &time)
    }

    /// Whether `location` lies inside the view with a margin of `inset` points.
    static func inside(_ location: Vec2, inset: Double = 0) -> Bool {
        location.x >= inset && location.x <= viewWidth - inset && location.y >= inset
            && location.y <= viewHeight - inset
    }

    /// What the picker gives for `location` on `snapshot` at `orbit`.
    static func pick(_ location: Vec2, _ snapshot: Snapshot, orbit: Orbit) -> AcousticConstellatorPick {
        Picker.pick(SIMD2<Double>(location.x, location.y), size: size, snapshot: snapshot, orbit: orbit)
    }

    /// The drag target the picker gives for `location` on `snapshot` at `orbit`, star `excluding` never chosen.
    static func starAt(_ location: Vec2, _ snapshot: Snapshot, orbit: Orbit, excluding: Int) -> Int? {
        Picker.starAt(SIMD2<Double>(location.x, location.y), size: size, snapshot: snapshot, orbit: orbit,
                      excluding: excluding)
    }

    /// `world` in view points (origin top left) through the camera of `orbit` for `snapshot` at the scripted view
    /// size; nil behind the camera.
    static func viewPoint(_ world: SIMD3<Double>, _ snapshot: Snapshot, orbit: Orbit) -> Vec2? {
        let camera: AcousticConstellatorCamera = Geometry.camera(snapshot, aspect: viewWidth / viewHeight, orbit: orbit)
        guard let p: SIMD2<Double> = Picker.viewPoint(world, size: size, camera: camera) else { return nil }
        return Vec2(p.x, p.y)
    }

    /// Star `index`'s projected centre 8 points inside the view where the picker gives `.star(index)` at `orbit`;
    /// nil when none.
    static func starPoint(_ index: Int, _ snapshot: Snapshot, orbit: Orbit) -> Vec2? {
        guard index >= 0, index < snapshot.stars.count,
              let point: Vec2 = viewPoint(Geometry.starCentre(index, snapshot), snapshot, orbit: orbit),
              inside(point, inset: 8), pick(point, snapshot, orbit: orbit) == .star(index) else { return nil }
        return point
    }

    /// The drag from star `from` to star `to` at `orbit`: the start picks `from`, the end (`to`'s projected centre, 8
    /// points inside the view) is `to` as the drag target, and the two lie at least ``dragRoom`` apart; nil otherwise.
    static func drag(_ from: Int, _ to: Int, _ snapshot: Snapshot, orbit: Orbit) -> Drag? {
        guard from != to, to >= 0, to < snapshot.stars.count,
              let start: Vec2 = starPoint(from, snapshot, orbit: orbit),
              let end: Vec2 = viewPoint(Geometry.starCentre(to, snapshot), snapshot, orbit: orbit),
              inside(end, inset: 8), (end - start).length >= dragRoom,
              starAt(end, snapshot, orbit: orbit, excluding: from) == to else { return nil }
        return Drag(from: from, to: to, start: start, end: end)
    }

    /// A drag joining the pair `link` in either direction (lower star first tried); nil when neither works.
    static func pairDrag(_ link: Link, _ snapshot: Snapshot, orbit: Orbit) -> Drag? {
        drag(link.a, link.b, snapshot, orbit: orbit) ?? drag(link.b, link.a, snapshot, orbit: orbit)
    }

    /// The highest-numbered star of `snapshot` that picks at its centre at `orbit` (so the choice visibly moves off
    /// star 0); nil when none.
    static func tapStar(_ snapshot: Snapshot, orbit: Orbit) -> (star: Int, point: Vec2)? {
        for index in snapshot.stars.indices.reversed() {
            if let point: Vec2 = starPoint(index, snapshot, orbit: orbit) { return (index, point) }
        }
        return nil
    }

    /// A point on the spline of link `index` of `snapshot`, 8 points inside the view, where the picker gives
    /// `.link(index)` at `orbit`; nil when none.
    static func linkPoint(_ index: Int, _ snapshot: Snapshot, orbit: Orbit) -> Vec2? {
        guard index >= 0, index < snapshot.links.count else { return nil }
        let link: Link = snapshot.links[index]
        let a: SIMD3<Double> = Geometry.starCentre(link.a, snapshot)
        let b: SIMD3<Double> = Geometry.starCentre(link.b, snapshot)
        for u in fractions {
            guard let point: Vec2 = viewPoint(Geometry.splinePoint(a, b, u: u), snapshot, orbit: orbit),
                  inside(point, inset: 8) else { continue }
            if pick(point, snapshot, orbit: orbit) == .link(index) { return point }
        }
        return nil
    }

    /// The first fixed link of `snapshot` with a touch point on its spline at `orbit` (link index and point).
    static func fixedLinkPoint(_ snapshot: Snapshot, orbit: Orbit) -> (index: Int, point: Vec2)? {
        for index in snapshot.links.indices where snapshot.fixedLinks.contains(snapshot.links[index]) {
            if let point: Vec2 = linkPoint(index, snapshot, orbit: orbit) { return (index, point) }
        }
        return nil
    }

    /// The first coherence bar centre of `snapshot` that picks as its bar 8 points inside the view at `orbit`.
    static func coherencePoint(_ snapshot: Snapshot, orbit: Orbit) -> Vec2? {
        for index in 0..<Geometry.coherenceCount {
            guard let point: Vec2 = viewPoint(Geometry.coherenceBar(index, snapshot), snapshot, orbit: orbit),
                  inside(point, inset: 8) else { continue }
            if pick(point, snapshot, orbit: orbit) == .coherence(index) { return point }
        }
        return nil
    }

    /// A point of empty space (the picker gives `.empty`) at least 8 points inside the view: the four corners first,
    /// then a grid; nil when none.
    static func emptyPoint(_ snapshot: Snapshot, orbit: Orbit) -> Vec2? {
        var points: [Vec2] = [Vec2(8, 8), Vec2(viewWidth - 8, 8), Vec2(8, viewHeight - 8),
                              Vec2(viewWidth - 8, viewHeight - 8)]
        var y: Double = 8
        while y <= viewHeight - 8 {
            var x: Double = 8
            while x <= viewWidth - 8 {
                points.append(Vec2(x, y))
                x += gridStep
            }
            y += gridStep
        }
        for point in points where pick(point, snapshot, orbit: orbit) == .empty {
            return point
        }
        return nil
    }

    /// The first unlinked pair of `core`'s play that a copy of `core` links and then unlinks (both accepted) and that
    /// a drag joins on `snapshot` at `orbit`.
    static func linkablePair(_ core: Core, _ snapshot: Snapshot, orbit: Orbit) -> Drag? {
        let count: Int = core.play.level.stars.count
        for a in 0..<count {
            for b in (a + 1)..<count {
                let link: Link = Link.between(a, b)
                if core.play.links.contains(link) { continue }
                let linked = applied(core, "link.add", [Double(a), Double(b)])
                guard linked.result.isAccepted, linked.core.play.stage == .playing else { continue }
                let unlinked = applied(linked.core, "link.remove", [Double(a), Double(b)])
                guard unlinked.result.isAccepted, unlinked.core.play.stage == .playing else { continue }
                if let drag: Drag = pairDrag(link, snapshot, orbit: orbit) { return drag }
            }
        }
        return nil
    }

    /// The first fixed link of `snapshot` that a drag joins at `orbit`.
    static func fixedDrag(_ snapshot: Snapshot, orbit: Orbit) -> Drag? {
        for link in snapshot.fixedLinks {
            if let drag: Drag = pairDrag(link, snapshot, orbit: orbit) { return drag }
        }
        return nil
    }

    /// The first of ``candidateLevels`` whose opening core and snapshot (authored orbit) pass `fits`; chosen from the
    /// Core at run time (an issue is recorded and the first candidate returned when none does).
    static func level(_ what: String, where fits: (Core, Snapshot) -> Bool) throws -> Int {
        for number in candidateLevels {
            let core: Core = try Core.opening(number: number)
            if fits(core, core.snapshot(time: 0)) { return number }
        }
        Issue.record("no candidate level has \(what) inside the view")
        return candidateLevels[0]
    }

    /// The first refused link drag of ``refusalLevels``: after one link a copy of the opening core accepts, an
    /// unlinked pair whose `link.add` the copy refuses (the degree or link limit), joined by a drag at the authored
    /// orbit; nil when none.
    static func refusal() throws -> Refusal? {
        for number in refusalLevels {
            let opening: Core = try Core.opening(number: number)
            let count: Int = opening.play.level.stars.count
            for p in 0..<count {
                for q in (p + 1)..<count {
                    let prepared: Link = Link.between(p, q)
                    if opening.play.links.contains(prepared) { continue }
                    let first = applied(opening, "link.add", [Double(p), Double(q)])
                    guard first.result.isAccepted, first.core.play.stage == .playing else { continue }
                    let snapshot: Snapshot = first.core.snapshot(time: 0)
                    for a in 0..<count {
                        for b in (a + 1)..<count {
                            let pair: Link = Link.between(a, b)
                            if first.core.play.links.contains(pair) { continue }
                            let refused = applied(first.core, "link.add", [Double(a), Double(b)])
                            if refused.result.isAccepted { continue }
                            guard let drag: Drag = pairDrag(pair, snapshot, orbit: .authored) else { continue }
                            return Refusal(number: number, prepared: prepared, drag: drag, code: refused.result.code)
                        }
                    }
                }
            }
        }
        return nil
    }

    /// The core `before` after applying `control` with `values`, and the adapter's answer.
    static func applied(_ before: Core, _ control: String, _ values: [Double]) -> (core: Core, result: ActionResult) {
        var copy: Core = before
        let result: ActionResult = copy.apply(ExperienceAction(control: control, values: values, step: 0))
        return (copy, result)
    }
}

@MainActor
@Suite(.serialized) struct AcousticConstellatorGestureWiringTests {
    typealias Script = AcousticConstellatorGestureScript
    typealias Core = AcousticConstellatorExperienceCore
    typealias Snapshot = AcousticConstellatorSceneSnapshot

    /// 1. A tap on a star while playing nudges it one step forward and chooses it.
    @Test func aTapOnAStarNudgesAndChoosesIt() async throws {
        let number: Int = try Script.level("a star that picks at its centre") { (_: Core, snapshot: Snapshot) -> Bool in
            Script.tapStar(snapshot, orbit: .authored) != nil
        }
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Script.open(session, number: number)
        let before: Core = try AcousticConstellatorTest.core(shell)
        try #require(before.play.stage == .playing)
        let snapshot: Snapshot = try Script.drawn(shell)
        let target = try #require(Script.tapStar(snapshot, orbit: shell.presenter.gestures.orbit),
                                  "a star picks inside the view")
        let star: Int = target.star
        let expected = Script.applied(before, "star.nudge", [Double(star), 1])
        #expect(expected.result == .accepted)
        let partnerBefore: Int = shell.presenter.mirror.partner
        let starCount: Int = before.play.level.stars.count
        let expectedPartner: Int = partnerBefore == star ? (star + 1) % starCount : partnerBefore
        let digest: String = try AcousticConstellatorTest.digest(shell)
        let sentBefore: Script.Sent = Script.sent(shell)
        var time: Double = Script.clock()

        Script.touch(shell, id: 1, .began, at: target.point, time: &time)
        #expect(shell.presenter.gestures.state == .starPress)
        Script.touch(shell, id: 1, .ended, at: target.point, time: &time)
        let sentAfter: Script.Sent = Script.sent(shell)
        #expect(sentAfter.accepted == sentBefore.accepted + 1, "one star.nudge accepted")
        #expect(sentAfter.rejected == sentBefore.rejected)
        let after: Core = try AcousticConstellatorTest.core(shell)
        #expect(after.play.actionsSpent == before.play.actionsSpent + 1, "one action spent")
        #expect(after.play.phases[star] == (before.play.phases[star] + 1) % 12, "the phase moves forward one step")
        #expect(after.play.records.last?.action == .nudge(star, 1))
        #expect(after.play.fingerprint == expected.core.play.fingerprint)
        #expect(try AcousticConstellatorTest.digest(shell) != digest, "the nudge changes the digest")
        #expect(shell.presenter.mirror.star == star, "the tap chooses the star")
        #expect(shell.presenter.mirror.partner == expectedPartner)
        #expect(shell.presenter.mirror.message == nil)
        #expect(shell.presenter.gestures.state == .idle)
        #expect(shell.presenter.refusalLog.isEmpty)
    }

    /// 2. A drag from star a released on star b links the pair, with the filament shown only while dragging; a second
    /// drag unlinks it.
    @Test func aLinkDragLinksAndASecondDragUnlinks() async throws {
        let number: Int = try Script.level("a linkable pair") { (core: Core, snapshot: Snapshot) -> Bool in
            Script.linkablePair(core, snapshot, orbit: .authored) != nil
        }
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Script.open(session, number: number)
        let before: Core = try AcousticConstellatorTest.core(shell)
        let snapshot: Snapshot = try Script.drawn(shell)
        let drag: Script.Drag = try #require(Script.linkablePair(before, snapshot,
                                                                orbit: shell.presenter.gestures.orbit),
                                             "an unlinked pair a drag joins inside the view")
        let link: AcousticConstellatorLink = AcousticConstellatorLink.between(drag.from, drag.to)
        let expected = Script.applied(before, "link.add", [Double(link.a), Double(link.b)])
        #expect(expected.result == .accepted)
        let sentBefore: Script.Sent = Script.sent(shell)
        var time: Double = Script.clock()

        #expect(shell.presenter.scene.filament == nil)
        Script.dragOver(shell, id: 1, drag, time: &time)
        #expect(shell.presenter.gestures.state == .linkDrag)
        let filament = try #require(shell.presenter.scene.filament, "the filament is drawn while dragging")
        #expect(filament.star == drag.from, "the filament starts at the dragged star")
        #expect(filament.point == AcousticConstellatorSceneGeometry.starCentre(drag.to, snapshot),
                "and ends at the target star's centre")
        #expect(shell.presenter.mirror.star == drag.from)
        #expect(shell.presenter.mirror.partner == drag.to)
        #expect(Script.sent(shell) == sentBefore, "nothing is sent before the release")
        Script.touch(shell, id: 1, .ended, at: drag.end, time: &time)
        #expect(shell.presenter.scene.filament == nil, "the filament disappears on release")
        let sentLinked: Script.Sent = Script.sent(shell)
        #expect(sentLinked.accepted == sentBefore.accepted + 1, "one link.add accepted")
        #expect(sentLinked.rejected == sentBefore.rejected)
        let linked: Core = try AcousticConstellatorTest.core(shell)
        #expect(linked.play.links.contains(link), "the pair is linked")
        #expect(linked.play.records.last?.action == .link(link.a, link.b))
        #expect(linked.play.fingerprint == expected.core.play.fingerprint)
        #expect(shell.presenter.mirror.star == drag.from, "the pair is chosen")
        #expect(shell.presenter.mirror.partner == drag.to)
        #expect(shell.presenter.mirror.message == nil)
        #expect(shell.presenter.gestures.state == .idle)

        try AcousticConstellatorTest.draw(session)
        let relinked: Snapshot = try Script.drawn(shell)
        #expect(relinked.links.contains(link))
        let again: Script.Drag = try #require(Script.drag(drag.from, drag.to, relinked,
                                                          orbit: shell.presenter.gestures.orbit))
        let expectedUnlink = Script.applied(linked, "link.remove", [Double(link.a), Double(link.b)])
        #expect(expectedUnlink.result == .accepted)
        time += 1
        Script.linkDrag(shell, id: 2, again, time: &time)
        #expect(shell.presenter.scene.filament == nil)
        let sentUnlinked: Script.Sent = Script.sent(shell)
        #expect(sentUnlinked.accepted == sentLinked.accepted + 1, "one link.remove accepted")
        #expect(sentUnlinked.rejected == sentBefore.rejected)
        let unlinked: Core = try AcousticConstellatorTest.core(shell)
        #expect(!unlinked.play.links.contains(link), "the second drag unlinks the pair")
        #expect(unlinked.play.records.last?.action == .unlink(link.a, link.b))
        #expect(unlinked.play.fingerprint == expectedUnlink.core.play.fingerprint)
        #expect(shell.presenter.gestures.state == .idle)
        #expect(shell.presenter.refusalLog.isEmpty)
    }

    /// 3. A drag onto a fixed pair sends nothing and says the link is fixed.
    @Test func aDragOntoAFixedPairSaysItIsFixed() async throws {
        let number: Int = try Script.level("a fixed pair a drag joins") { (_: Core, snapshot: Snapshot) -> Bool in
            Script.fixedDrag(snapshot, orbit: .authored) != nil
        }
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Script.open(session, number: number)
        let before: Core = try AcousticConstellatorTest.core(shell)
        let snapshot: Snapshot = try Script.drawn(shell)
        let drag: Script.Drag = try #require(Script.fixedDrag(snapshot, orbit: shell.presenter.gestures.orbit),
                                             "a fixed pair a drag joins inside the view")
        #expect(snapshot.fixedLinks.contains(AcousticConstellatorLink.between(drag.from, drag.to)))
        let digest: String = try AcousticConstellatorTest.digest(shell)
        let sentBefore: Script.Sent = Script.sent(shell)
        var time: Double = Script.clock()

        Script.linkDrag(shell, id: 1, drag, time: &time)
        #expect(Script.sent(shell) == sentBefore, "a drag onto a fixed pair sends nothing")
        #expect(try AcousticConstellatorTest.digest(shell) == digest)
        #expect(try AcousticConstellatorTest.core(shell).play.fingerprint == before.play.fingerprint)
        let expected: String = AcousticConstellatorPresenter.fixedText(drag.from, drag.to)
        #expect(shell.presenter.mirror.message == expected, "the link is said to be fixed")
        let link: AcousticConstellatorLink = AcousticConstellatorLink.between(drag.from, drag.to)
        #expect(expected == "The link from star \(link.a) to star \(link.b) is fixed: it cannot be removed.")
        #expect(shell.presenter.mirror.star == drag.from, "the pair is chosen")
        #expect(shell.presenter.mirror.partner == drag.to)
        #expect(shell.presenter.scene.filament == nil)
        #expect(shell.presenter.gestures.state == .idle)
        #expect(shell.presenter.refusalLog.isEmpty)
    }

    /// 4. A tap on a link chooses its pair, sends nothing and describes the link: fixed, then placed.
    @Test func aTapOnALinkChoosesItsPair() async throws {
        let number: Int = try Script.level("a fixed link and a linkable pair") {
            (core: Core, snapshot: Snapshot) -> Bool in
            guard Script.fixedLinkPoint(snapshot, orbit: .authored) != nil,
                  let drag: Script.Drag = Script.linkablePair(core, snapshot, orbit: .authored) else { return false }
            let link: AcousticConstellatorLink = AcousticConstellatorLink.between(drag.from, drag.to)
            let linked = Script.applied(core, "link.add", [Double(link.a), Double(link.b)])
            let after: Snapshot = linked.core.snapshot(time: 0)
            guard let index: Int = after.links.firstIndex(of: link) else { return false }
            return Script.linkPoint(index, after, orbit: .authored) != nil
                && Script.fixedLinkPoint(after, orbit: .authored) != nil
        }
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Script.open(session, number: number)
        let before: Core = try AcousticConstellatorTest.core(shell)
        let snapshot: Snapshot = try Script.drawn(shell)
        let orbit: AcousticConstellatorOrbit = shell.presenter.gestures.orbit
        let fixed = try #require(Script.fixedLinkPoint(snapshot, orbit: orbit), "a fixed link picks inside the view")
        let fixedLink: AcousticConstellatorLink = snapshot.links[fixed.index]
        let digest: String = try AcousticConstellatorTest.digest(shell)
        let sentBefore: Script.Sent = Script.sent(shell)
        var time: Double = Script.clock()

        Script.touch(shell, id: 1, .began, at: fixed.point, time: &time)
        #expect(shell.presenter.gestures.state == .linkPress)
        Script.touch(shell, id: 1, .ended, at: fixed.point, time: &time)
        let tick: Int = AcousticConstellatorSceneGeometry.drawnTick(snapshot,
                                                                    reduceMotion: shell.presenter.reduceMotion)
        let fixedText: String = AcousticConstellatorPresenter.linkText(fixedLink.a, fixedLink.b, snapshot: snapshot,
                                                                       tick: tick)
        #expect(shell.presenter.mirror.message == fixedText, "the link is described")
        #expect(fixedText.hasPrefix("Link star \(fixedLink.a) to star \(fixedLink.b): gap "), "\(fixedText)")
        #expect(fixedText.hasSuffix(" at tick \(tick), fixed."), "\(fixedText)")
        #expect(shell.presenter.mirror.star == fixedLink.a, "the tap chooses the link's stars")
        #expect(shell.presenter.mirror.partner == fixedLink.b)
        #expect(Script.sent(shell) == sentBefore, "a tap on a link sends nothing")
        #expect(try AcousticConstellatorTest.digest(shell) == digest, "a choice never changes the digest")
        #expect(shell.presenter.gestures.state == .idle)

        // A link the player placed is described as placed.
        let drag: Script.Drag = try #require(Script.linkablePair(before, snapshot, orbit: orbit))
        let link: AcousticConstellatorLink = AcousticConstellatorLink.between(drag.from, drag.to)
        let issued: ActionResult = shell.handle(control: "link.add", values: [Double(link.a), Double(link.b)])
        #expect(issued == .accepted)
        try AcousticConstellatorTest.draw(session)
        let placedSnapshot: Snapshot = try Script.drawn(shell)
        let index: Int = try #require(placedSnapshot.links.firstIndex(of: link))
        let point: Vec2 = try #require(Script.linkPoint(index, placedSnapshot, orbit: orbit),
                                       "the placed link picks inside the view")
        let placedDigest: String = try AcousticConstellatorTest.digest(shell)
        let sentPlaced: Script.Sent = Script.sent(shell)
        time += 1
        Script.tap(shell, id: 2, at: point, time: &time)
        let placedTick: Int = AcousticConstellatorSceneGeometry.drawnTick(placedSnapshot,
                                                                          reduceMotion: shell.presenter.reduceMotion)
        let placedText: String = AcousticConstellatorPresenter.linkText(link.a, link.b, snapshot: placedSnapshot,
                                                                        tick: placedTick)
        #expect(shell.presenter.mirror.message == placedText)
        #expect(placedText.hasSuffix(" at tick \(placedTick), placed."), "\(placedText)")
        #expect(shell.presenter.mirror.star == link.a)
        #expect(shell.presenter.mirror.partner == link.b)
        #expect(Script.sent(shell) == sentPlaced)
        #expect(try AcousticConstellatorTest.digest(shell) == placedDigest)
        #expect(shell.presenter.refusalLog.isEmpty)
    }

    /// 5. A tap on a coherence bar listens: the kernel ends the play won or failed.
    @Test func aTapOnACoherenceBarListens() async throws {
        let number: Int = try Script.level("a coherence bar") { (_: Core, snapshot: Snapshot) -> Bool in
            Script.coherencePoint(snapshot, orbit: .authored) != nil
        }
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Script.open(session, number: number)
        let before: Core = try AcousticConstellatorTest.core(shell)
        let snapshot: Snapshot = try Script.drawn(shell)
        let point: Vec2 = try #require(Script.coherencePoint(snapshot, orbit: shell.presenter.gestures.orbit),
                                       "a coherence bar picks inside the view")
        let expected = Script.applied(before, "constellation.listen", [])
        #expect(expected.result.isAccepted)
        let sentBefore: Script.Sent = Script.sent(shell)
        var time: Double = Script.clock()

        Script.touch(shell, id: 1, .began, at: point, time: &time)
        #expect(shell.presenter.gestures.state == .targetPress)
        Script.touch(shell, id: 1, .ended, at: point, time: &time)
        let sentAfter: Script.Sent = Script.sent(shell)
        #expect(sentAfter.accepted == sentBefore.accepted + 1, "one constellation.listen accepted")
        #expect(sentAfter.rejected == sentBefore.rejected)
        let after: Core = try AcousticConstellatorTest.core(shell)
        #expect(after.play.actionsSpent == before.play.actionsSpent + 1, "one action spent")
        #expect(after.play.records.last?.action == .listen)
        #expect(after.play.stage == .won || after.play.stage == .failed, "the kernel decides the listen")
        #expect(after.play.stage == expected.core.play.stage)
        #expect(after.play.fingerprint == expected.core.play.fingerprint)
        #expect(shell.presenter.gestures.state == .idle)
        #expect(shell.presenter.refusalLog.isEmpty)
    }

    /// 6. A two-finger drag orbits and changes no digest; a double tap on empty space and `resetView()` return to the
    /// authored orbit.
    @Test func anOrbitChangesTheViewAndResets() async throws {
        let number: Int = Script.candidateLevels[0]
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Script.open(session, number: number)
        let digest: String = try AcousticConstellatorTest.digest(shell)
        let sentBefore: Script.Sent = Script.sent(shell)
        #expect(shell.presenter.gestures.orbit == .authored)
        var time: Double = Script.clock()

        Script.orbit(shell, id: 1, time: &time)
        let orbit: AcousticConstellatorOrbit = shell.presenter.gestures.orbit
        #expect(orbit != .authored, "two fingers orbit the camera")
        #expect(Swift.abs(orbit.yaw) <= AcousticConstellatorOrbit.yawLimit + 1e-12)
        #expect(AcousticConstellatorOrbit.pitchRange.contains(orbit.pitch))
        #expect(orbit == orbit.clamped())
        #expect(shell.presenter.scene.orbit == orbit, "the scene takes the controller's orbit")
        #expect(shell.presenter.scene.filament == nil)
        #expect(shell.presenter.gestures.state == .idle)
        #expect(Script.sent(shell) == sentBefore, "an orbit sends nothing")
        #expect(try AcousticConstellatorTest.digest(shell) == digest, "an orbit never changes the digest")
        try AcousticConstellatorTest.draw(session)
        #expect(shell.presenter.scene.orbit == orbit, "the scene draws the controller's orbit")
        #expect(try AcousticConstellatorTest.digest(shell) == digest)

        time += 1
        let empty: Vec2 = try #require(Script.emptyPoint(try Script.drawn(shell), orbit: orbit),
                                       "empty space inside the view")
        Script.tap(shell, id: 3, at: empty, time: &time)
        #expect(shell.presenter.gestures.orbit == orbit, "one tap keeps the orbit")
        Script.tap(shell, id: 4, at: empty, time: &time)
        #expect(shell.presenter.gestures.orbit == .authored, "a double tap on empty space resets the view")
        #expect(shell.presenter.scene.orbit == .authored)
        #expect(Script.sent(shell) == sentBefore)
        #expect(try AcousticConstellatorTest.digest(shell) == digest)

        time += 1
        Script.orbit(shell, id: 5, time: &time)
        #expect(shell.presenter.gestures.orbit != .authored)
        shell.presenter.resetView()
        #expect(shell.presenter.gestures.orbit == .authored, "Reset view restores the authored orbit")
        #expect(shell.presenter.scene.orbit == .authored)
        try AcousticConstellatorTest.draw(session)
        #expect(shell.presenter.scene.orbit == .authored)
        #expect(Script.sent(shell) == sentBefore)
        #expect(try AcousticConstellatorTest.digest(shell) == digest)
        #expect(shell.presenter.refusalLog.isEmpty)
    }

    /// 7. A link drag over the degree or link limit is refused by the kernel, shown in words and logged with its code.
    @Test func aRefusedLinkDragIsShownAndLogged() async throws {
        let refusal: Script.Refusal = try #require(try Script.refusal(),
                                                   "a level reaches a refused link that a drag joins")
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Script.open(session, number: refusal.number)
        let prepared: ActionResult = shell.handle(control: "link.add",
                                                  values: [Double(refusal.prepared.a), Double(refusal.prepared.b)])
        #expect(prepared == .accepted, "the prepared link is accepted")
        try AcousticConstellatorTest.draw(session)
        let before: Core = try AcousticConstellatorTest.core(shell)
        let snapshot: Snapshot = try Script.drawn(shell)
        #expect(snapshot.stage == .playing)
        let drag: Script.Drag = try #require(Script.drag(refusal.drag.from, refusal.drag.to, snapshot,
                                                         orbit: shell.presenter.gestures.orbit))
        let pair: AcousticConstellatorLink = AcousticConstellatorLink.between(drag.from, drag.to)
        let expected = Script.applied(before, "link.add", [Double(pair.a), Double(pair.b)])
        #expect(!expected.result.isAccepted)
        #expect(expected.result.code == refusal.code)
        #expect(refusal.code.hasSuffix("r02-g13.action"), "\(refusal.code)")
        let digest: String = try AcousticConstellatorTest.digest(shell)
        let sentBefore: Script.Sent = Script.sent(shell)
        var time: Double = Script.clock()

        Script.linkDrag(shell, id: 1, drag, time: &time)
        let sentAfter: Script.Sent = Script.sent(shell)
        #expect(sentAfter.accepted == sentBefore.accepted)
        #expect(sentAfter.rejected == sentBefore.rejected + 1, "one link.add refused")
        #expect(try AcousticConstellatorTest.digest(shell) == digest, "a refused action changes nothing")
        #expect(try AcousticConstellatorTest.core(shell).play.fingerprint == before.play.fingerprint)
        let code: String = try #require(shell.presenter.refusalLog.last, "the refusal's code is logged")
        #expect(shell.presenter.refusalLog.count == 1)
        #expect(code == refusal.code)
        #expect(code == "action.rule.r02-g13.action" || code == "r02-g13.action", "\(code)")
        let message: String = try #require(shell.presenter.mirror.message, "the refusal is shown")
        // Since feature 426 the refusal is shown in the feedback plan's words.
        #expect(message == AcousticConstellatorFeedbackPlan.refusalText(code: code), "\(message)")
        #expect(message == AcousticConstellatorMirror.refusalText(code: code))
        #expect(message == "That change is not allowed for these stars.", "the kernel code in words")
        #expect(shell.presenter.scene.filament == nil)
        #expect(shell.presenter.gestures.state == .idle)
    }

    /// 8. On a won play a link drag sends nothing and the mirror explains that the play is over.
    @Test func aDragOnAWonPlaySendsNothing() async throws {
        let number: Int = try Script.level("a pair a drag joins") { (_: Core, snapshot: Snapshot) -> Bool in
            Script.drag(0, 1, snapshot, orbit: .authored) != nil || Script.drag(1, 0, snapshot, orbit: .authored) != nil
        }
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Script.open(session, number: number)
        let actions: [AcousticConstellatorAction] = try AcousticConstellatorTest.certifiedActions(number)
        try #require(!actions.isEmpty, "level \(number) has a certified solution")
        let accepted: Int = AcousticConstellatorTest.issue(shell, actions)
        #expect(accepted == actions.count)
        let won: Core = try AcousticConstellatorTest.core(shell)
        try #require(won.play.stage == .won, "the certified solution wins level \(number)")
        try AcousticConstellatorTest.draw(session)
        let snapshot: Snapshot = try Script.drawn(shell)
        #expect(snapshot.stage == .won)
        let orbit: AcousticConstellatorOrbit = shell.presenter.gestures.orbit
        let drag: Script.Drag = try #require(Script.drag(0, 1, snapshot, orbit: orbit)
            ?? Script.drag(1, 0, snapshot, orbit: orbit), "a drag between stars 0 and 1 inside the view")
        let digest: String = try AcousticConstellatorTest.digest(shell)
        let sentBefore: Script.Sent = Script.sent(shell)
        var time: Double = Script.clock()

        Script.dragOver(shell, id: 1, drag, time: &time)
        #expect(shell.presenter.scene.filament == nil, "a finished play previews nothing")
        Script.touch(shell, id: 1, .ended, at: drag.end, time: &time)
        #expect(Script.sent(shell) == sentBefore, "a drag on a won play sends nothing")
        #expect(try AcousticConstellatorTest.digest(shell) == digest)
        #expect(try AcousticConstellatorTest.core(shell).play.fingerprint == won.play.fingerprint)
        #expect(shell.presenter.mirror.message == AcousticConstellatorPresenter.finishedMessage)
        #expect(AcousticConstellatorPresenter.finishedMessage == "The play is over: undo or go to the next level")
        #expect(shell.presenter.refusalLog.isEmpty, "nothing was refused: nothing was sent")
        #expect(shell.presenter.gestures.state == .idle)
        let described: String = shell.presenter.describe(try AcousticConstellatorTest.core(shell))
        #expect(described.contains(AcousticConstellatorPresenter.finishedMessage + "."), "\(described)")
        #expect(shell.presenter.mirror.status == "Won")
    }

    /// 9. Every action a gesture sends is also available from the native controls.
    @Test func gestureActionsAreNativeActions() throws {
        let id: ExperienceID = try #require(AcousticConstellatorExperience.id)
        let shell: ExperienceShell<AcousticConstellatorPresenter> = AcousticConstellatorExperience.make(id: id)
        let gestureActions: Set<String> = shell.presenter.gestureActions
        #expect(gestureActions == ["link.add", "link.remove", "star.nudge", "constellation.listen"])
        #expect(gestureActions.isSubset(of: shell.presenter.nativeActions))
        #expect(shell.presenter.nativeActions == Set(AcousticConstellatorExperienceCore.actionIDs))
        #expect(shell.presenter.gestures.orbit == .authored)
        #expect(shell.presenter.scene.filament == nil)
    }
}
#endif
