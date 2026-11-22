// FacetedForgeGestureWiringTests — feature 374 (R02-G08-04) T-R02G0804-005 (FR-R02G0804-001 … 008; clarifications
// Q1–Q5). On the simulator, through the one app's session host: scripted touches go to the presenter's
// `pointer(_:viewSize:port:)` with the shell's own `port` at a 720 × 480-point view (aspect 1.5). Targets are world
// points (the opened preview centre, a piece's opened centre, points on the opened preview outline) projected through
// the camera the presenter draws with (`FacetedForgeSceneGeometry.camera(_:aspect:orbit:)` at the controller's orbit)
// into view points (origin top left) and confirmed with `FacetedForgePicker.pick` on the presenter's `lastSnapshot`
// (reduce motion off, as the controller picks). What the port sent is read from the shell's engine (accepted and
// rejected action counters) and the core, compared with a bare core that applied the expected action itself. Checked:
//   1. a tap on the projected preview centre of level 1 (seed 0, the default plane: direction 2, z, facing the
//      authored camera) sends one `piece.cut` with the mirror's choice (cuts 0 → 1, the digest changes); a second tap
//      0.033 s later (event timestamps, within the 0.35 s commit window) sends nothing;
//   2. after one cut a tap on a piece other than the chosen one (a point the picker gives as `.piece(i)`) chooses it
//      in the mirror at its middle crossing depth; nothing is sent and the digest is unchanged;
//   3. a rim drag tilts the mirror's direction to what `FacetedForgePicker.tilt` predicts; a plane drag of at least
//      16 points moves the depth by `FacetedForgePicker.depthSteps` crossing depths; nothing is sent, the digest is
//      unchanged;
//   4. a two-finger orbit changes `gestures.orbit` and, after the next frame, the scene's orbit; the digest is
//      unchanged; `resetView()` returns both to `.authored`;
//   5. on a finished play (the certified solution of level 1 sent as `piece.cut` through the port, so it is won) a tap
//      on the plane sends nothing and the mirror shows `FacetedForgePresenter.finishedMessage`;
//   6. a refused gesture action is shown in the mirror and logged in `refusalLog`: on a level whose first certified
//      cut keeps the play going, the mirror's choice is put on the last of the two pieces and drawn, then a
//      `play.undo` is sent through the port without drawing again; the presenter still holds the two-piece snapshot,
//      so a tap on its plane sends `piece.cut` for a piece that no longer exists and the kernel refuses it
//      (`r02-g08.action`, range); the gesture actions are native actions;
//   7. a second finger during a plane press cancels it: nothing is sent and no message is shown.
// Synthetic timestamps; no sleep, no wall-clock assertion; few frames. Explicit types and plain loops (CI type-check
// rule).
#if os(iOS)
import CoreGraphics
import FacetedForgeCore
import Foundation
import Testing
@testable import FacetedForgeExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreScenes

/// Scripted touches on Faceted Forge, placed through the drawn camera.
@MainActor
enum FacetedForgeGestureScript {
    typealias Shell = ExperienceShell<FacetedForgePresenter>
    typealias Snapshot = FacetedForgeSceneSnapshot
    typealias Geometry = FacetedForgeSceneGeometry
    typealias Core = FacetedForgeExperienceCore
    typealias Choice = FacetedForgePreviewChoice

    /// The view's size in points (aspect 1.5, the frame-check aspect).
    static let viewWidth: Double = 720
    static let viewHeight: Double = 480
    /// The view size handed with every event.
    static var viewSize: Vec2 { Vec2(viewWidth, viewHeight) }
    /// The view size as the picker takes it.
    static var size: SIMD2<Double> { SIMD2<Double>(viewWidth, viewHeight) }
    /// The time between scripted events in seconds (synthetic).
    static let frame: Double = 1.0 / 60
    /// The moves of a scripted drag.
    static let dragMoves: Int = 6
    /// The seeds searched for a level with a wanted property (seed = level − 1).
    static let searchedSeeds: Int = 30
    /// The points of the grid searched over the preview's projected bounds for a plane point, per axis.
    static let gridSteps: Int = 12

    /// What the engine has counted so far: accepted and rejected actions.
    struct Sent: Equatable {
        let accepted: Int
        let rejected: Int
    }

    /// Opens level `seed % 100 + 1` at the scripted view size (one frame drawn).
    static func open(_ session: ExperienceSession, seed: UInt64 = 0) async throws -> Shell {
        try await FacetedForgeTest.open(session, seed: seed, size: CGSize(width: viewWidth, height: viewHeight))
    }

    /// The engine's action counters of `shell`.
    static func sent(_ shell: Shell) -> Sent {
        Sent(accepted: shell.engine.acceptedActions, rejected: shell.engine.rejectedActions)
    }

    /// The snapshot the presenter drew last (the gestures read it).
    static func drawn(_ shell: Shell) throws -> Snapshot {
        try #require(shell.presenter.lastSnapshot)
    }

    /// The play the presenter drew last.
    static func drawnPlay(_ shell: Shell) throws -> FacetedForgePlay {
        try #require(shell.presenter.lastPlay)
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

    /// A one-finger drag with finger `id` from `start` by `drag` in ``dragMoves`` equal moves, released at the end.
    static func drag(_ shell: Shell, id: Int, from start: Vec2, by drag: Vec2, time: inout Double) {
        touch(shell, id: id, .began, at: start, time: &time)
        for step in 1...dragMoves {
            let t: Double = Double(step) / Double(dragMoves)
            touch(shell, id: id, .moved, at: start + drag * t, time: &time)
        }
        touch(shell, id: id, .ended, at: start + drag, time: &time)
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

    /// `world` projected into view points (origin top left) through the camera the presenter draws `snapshot` with at
    /// the controller's current orbit; nil behind the camera.
    static func viewPoint(_ shell: Shell, _ world: SIMD3<Double>, _ snapshot: Snapshot) -> Vec2? {
        let camera: FacetedForgeCamera = Geometry.camera(snapshot, aspect: viewWidth / viewHeight,
                                                         orbit: shell.presenter.gestures.orbit)
        guard let unit: SIMD2<Double> = Geometry.project(world, camera: camera) else { return nil }
        return Vec2(unit.x * viewWidth, unit.y * viewHeight)
    }

    /// What the picker gives for `location` on `snapshot` at the current orbit (reduce motion off, as the controller
    /// picks).
    static func pick(_ shell: Shell, _ location: Vec2, _ snapshot: Snapshot) -> FacetedForgePick {
        FacetedForgePicker.pick(SIMD2<Double>(location.x, location.y), size: size, snapshot: snapshot,
                                orbit: shell.presenter.gestures.orbit, reduceMotion: false)
    }

    /// Whether `location` lies inside the view with a margin of `inset` points.
    static func inside(_ location: Vec2, inset: Double = 0) -> Bool {
        location.x >= inset && location.x <= viewWidth - inset && location.y >= inset
            && location.y <= viewHeight - inset
    }

    /// The projected opened preview outline of `snapshot` (empty without a preview or when a corner is behind the eye).
    static func outline(_ shell: Shell, _ snapshot: Snapshot) -> [Vec2] {
        let shift: SIMD3<Double> = Geometry.offset(piece: snapshot.choice.piece, snapshot, reduceMotion: false)
        var points: [Vec2] = []
        for corner in snapshot.preview {
            guard let point: Vec2 = viewPoint(shell, corner + shift, snapshot) else { return [] }
            points.append(point)
        }
        return points
    }

    /// The projected opened preview centre of the drawn snapshot when it picks the plane, else the grid point over the
    /// preview's projected bounds nearest that centre that does; nil without a preview or when none does.
    static func planePoint(_ shell: Shell) throws -> Vec2? {
        let snapshot: Snapshot = try drawn(shell)
        guard let centre: SIMD3<Double> = Geometry.previewCentre(snapshot, reduceMotion: false),
              let middle: Vec2 = viewPoint(shell, centre, snapshot) else { return nil }
        if inside(middle, inset: 2), pick(shell, middle, snapshot) == .plane { return middle }
        let points: [Vec2] = outline(shell, snapshot)
        guard points.count >= 3 else { return nil }
        var low: Vec2 = middle
        var high: Vec2 = middle
        for point in points {
            low = Vec2(Swift.min(low.x, point.x), Swift.min(low.y, point.y))
            high = Vec2(Swift.max(high.x, point.x), Swift.max(high.y, point.y))
        }
        var best: Vec2?
        var bestDistance: Double = .infinity
        for i in 0...gridSteps {
            for j in 0...gridSteps {
                let fx: Double = Double(i) / Double(gridSteps)
                let fy: Double = Double(j) / Double(gridSteps)
                let point: Vec2 = Vec2(low.x + (high.x - low.x) * fx, low.y + (high.y - low.y) * fy)
                let distance: Double = (point - middle).length
                guard distance < bestDistance, inside(point, inset: 2) else { continue }
                if pick(shell, point, snapshot) == .plane {
                    best = point
                    bestDistance = distance
                }
            }
        }
        return best
    }

    /// A plane point for the mirror's choice on piece `piece` (the current piece when nil): the current choice first
    /// (when it is on that piece), then each of the 13 directions at the middle crossing depth, drawing one frame per
    /// choice tried so `lastSnapshot` shows it. Returns the point, or nil when no direction gives one.
    static func planeTarget(_ session: ExperienceSession, _ shell: Shell, piece: Int? = nil) throws -> Vec2? {
        let current: Choice = shell.presenter.mirror.choice
        let wanted: Int = piece ?? current.piece
        if current.piece == wanted, try drawn(shell).choice == current, let point: Vec2 = try planePoint(shell) {
            return point
        }
        let play: FacetedForgePlay = try FacetedForgeTest.core(shell).play
        for direction in 0..<FacetedForgeDirection.all.count {
            let tried: Choice = FacetedForgeMirror.middle(Choice(piece: wanted, direction: direction, depth: 0), play)
            guard tried.piece == wanted else { continue }
            shell.presenter.mirror.choice = tried
            try FacetedForgeTest.draw(session)
            guard try drawn(shell).choice == tried else { continue }
            if let point: Vec2 = try planePoint(shell) { return point }
        }
        return nil
    }

    /// A point that picks piece `piece` on the drawn snapshot: its projected opened centre, else the first of the
    /// points halfway and four fifths from that centre to each opened corner that picks it; nil when none does.
    static func piecePoint(_ shell: Shell, piece: Int) throws -> Vec2? {
        let snapshot: Snapshot = try drawn(shell)
        guard snapshot.pieces.indices.contains(piece) else { return nil }
        let centre: SIMD3<Double> = Geometry.pieceCentre(piece, snapshot, reduceMotion: false)
        let shift: SIMD3<Double> = Geometry.offset(piece: piece, snapshot, reduceMotion: false)
        var worlds: [SIMD3<Double>] = [centre]
        for t in [0.5, 0.8] {
            for corner in snapshot.pieces[piece].corners {
                let toward: SIMD3<Double> = corner + shift - centre
                worlds.append(centre + toward * t)
            }
        }
        for world in worlds {
            guard let point: Vec2 = viewPoint(shell, world, snapshot), inside(point, inset: 2) else { continue }
            if pick(shell, point, snapshot) == .piece(piece) { return point }
        }
        return nil
    }

    /// A point on the projected opened preview outline of the drawn snapshot that picks the rim and lies at least 30
    /// points inside the view: the first of 8 points along each edge; nil when none does.
    static func rimPoint(_ shell: Shell) throws -> Vec2? {
        let snapshot: Snapshot = try drawn(shell)
        let points: [Vec2] = outline(shell, snapshot)
        guard points.count >= 3 else { return nil }
        for edge in 0..<points.count {
            let a: Vec2 = points[edge]
            let b: Vec2 = points[(edge + 1) % points.count]
            for i in 0..<8 {
                let t: Double = (Double(i) + 0.5) / 8
                let point: Vec2 = a + (b - a) * t
                if inside(point, inset: 30), pick(shell, point, snapshot) == .rim { return point }
            }
        }
        return nil
    }

    /// The drags tried from a rim or plane point (view points, x right, y down), each at least 48 points long: the
    /// long ones first (a tilt from the z axis to a face diagonal needs a turn of more than 22.5°, about 100 points
    /// at this view's height).
    static let drags: [Vec2] = [Vec2(180, 0), Vec2(-180, 0), Vec2(0, 180), Vec2(0, -180), Vec2(130, 130),
                                Vec2(-130, -130), Vec2(130, -130), Vec2(-130, 130), Vec2(120, 0), Vec2(-120, 0),
                                Vec2(0, 120), Vec2(0, -120), Vec2(72, 0), Vec2(-72, 0), Vec2(0, 72), Vec2(0, -72),
                                Vec2(48, 0), Vec2(-48, 0), Vec2(0, 48), Vec2(0, -48)]

    /// The core `before` after applying `control` with `values`, and the adapter's answer.
    static func applied(_ before: Core, _ control: String, _ values: [Double]) -> (core: Core, result: ActionResult) {
        var copy: Core = before
        let result: ActionResult = copy.apply(ExperienceAction(control: control, values: values, step: 0))
        return (copy, result)
    }

    /// The control values of a cut of `choice`.
    static func cutValues(_ choice: Choice) -> [Double] {
        [Double(choice.piece), Double(choice.direction), Double(choice.depth)]
    }

    /// The first seed below ``searchedSeeds`` whose level has a certified solution of at least two cuts and whose
    /// first certified cut keeps the play `playing`, or nil.
    static func seedPlayingAfterFirstCut() throws -> UInt64? {
        for seed in 0..<UInt64(searchedSeeds) {
            let number: Int = Core.levelNumber(forSeed: seed)
            let actions: [FacetedForgeAction] = Core.certifiedActions(number)
            guard actions.count >= 2 else { continue }
            let core: Core = try Core.opening(number: number)
            let issued = FacetedForgeTest.control(actions[0])
            let after = applied(core, issued.control, issued.values)
            if after.result == .accepted, after.core.play.stage == .playing { return seed }
        }
        return nil
    }
}

@MainActor
@Suite(.serialized) struct FacetedForgeGestureWiringTests {
    typealias Script = FacetedForgeGestureScript
    typealias Core = FacetedForgeExperienceCore
    typealias Choice = FacetedForgePreviewChoice

    /// 1. A tap on the projected preview centre of level 1 cuts once with the mirror's choice; a second tap within the
    /// commit window sends nothing.
    @Test func aPlaneTapCutsOnceWithTheMirrorsChoice() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Script.open(session, seed: 0)
        #expect(shell.state == .active)
        #expect(shell.presenter.gestures.orbit == .authored)
        let before: Core = try FacetedForgeTest.core(shell)
        #expect(before.levelNumber == 1)
        #expect(before.play.stage == .playing)
        #expect(before.play.cuts == 0)
        let snapshot: FacetedForgeSceneSnapshot = try Script.drawn(shell)
        let choice: Choice = shell.presenter.mirror.choice
        #expect(choice == Choice.initial(before.play), "the mirror starts at the default choice")
        #expect(choice.direction == Choice.facingDirection, "the default plane is direction 2, z")
        #expect(snapshot.choice == choice, "the drawn snapshot carries the mirror's choice")
        let centre: SIMD3<Double> =
            try #require(FacetedForgeSceneGeometry.previewCentre(snapshot, reduceMotion: false), "a preview")
        let point: Vec2 = try #require(Script.viewPoint(shell, centre, snapshot))
        #expect(Script.inside(point, inset: 1))
        #expect(Script.pick(shell, point, snapshot) == .plane, "the preview centre picks the plane")
        let digest: String = try FacetedForgeTest.digest(shell)
        let sentBefore: Script.Sent = Script.sent(shell)
        var time: Double = 0

        Script.touch(shell, id: 1, .began, at: point, time: &time)
        #expect(shell.presenter.gestures.state == .planePress)
        Script.touch(shell, id: 1, .ended, at: point, time: &time)
        let expected = Script.applied(before, "piece.cut", Script.cutValues(choice))
        #expect(expected.result == .accepted)
        let sentAfter: Script.Sent = Script.sent(shell)
        #expect(sentAfter.accepted == sentBefore.accepted + 1, "one piece.cut accepted")
        #expect(sentAfter.rejected == sentBefore.rejected)
        let after: Core = try FacetedForgeTest.core(shell)
        #expect(after.play.cuts == 1, "cuts 0 → 1")
        #expect(after.play.fingerprint == expected.core.play.fingerprint, "the tap is the mirror's cut")
        let cutDigest: String = try FacetedForgeTest.digest(shell)
        #expect(cutDigest != digest, "the cut changes the digest")
        #expect(shell.presenter.refusalLog.isEmpty)

        // A second tap 2 frames (0.033 s) after the commit: inside the 0.35 s window, nothing is sent.
        Script.tap(shell, id: 2, at: point, time: &time)
        #expect(Script.sent(shell) == sentAfter, "a second tap within 0.35 s sends nothing")
        #expect(try FacetedForgeTest.core(shell).play.cuts == 1)
        #expect(try FacetedForgeTest.digest(shell) == cutDigest)
        #expect(shell.presenter.gestures.state == .idle)
    }

    /// 2. After one cut, a tap on another piece chooses it in the mirror; nothing is sent, the digest is unchanged.
    @Test func aPieceTapChoosesThePiece() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Script.open(session, seed: 0)
        #expect(try FacetedForgeTest.advance(shell) == 1, "one certified cut")
        try FacetedForgeTest.draw(session)
        let play: FacetedForgePlay = try Script.drawnPlay(shell)
        #expect(play.pieces.count >= 2, "a cut makes two pieces")
        let from: Choice = try Script.drawn(shell).choice
        var target: (piece: Int, point: Vec2)?
        for piece in play.pieces.indices where piece != from.piece {
            if let point: Vec2 = try Script.piecePoint(shell, piece: piece) {
                target = (piece, point)
                break
            }
        }
        let found = try #require(target, "another piece is visible at the authored orbit")
        let crossing: [Int] = FacetedForgeTest.crossingDepths(play.pieces[found.piece], direction: from.direction)
        let depth: Int = crossing.isEmpty ? from.depth : crossing[crossing.count / 2]
        let expected: Choice = Choice(piece: found.piece, direction: from.direction, depth: depth).clamped(to: play)
        let digest: String = try FacetedForgeTest.digest(shell)
        let sentBefore: Script.Sent = Script.sent(shell)
        var time: Double = 0

        Script.touch(shell, id: 1, .began, at: found.point, time: &time)
        #expect(shell.presenter.gestures.state == .piecePress)
        Script.touch(shell, id: 1, .ended, at: found.point, time: &time)
        #expect(shell.presenter.mirror.choice == expected, "the tap chooses the piece at its middle crossing depth")
        #expect(shell.presenter.mirror.choice.piece == found.piece)
        #expect(Script.sent(shell) == sentBefore, "a tap on a piece sends no action")
        #expect(try FacetedForgeTest.digest(shell) == digest, "choosing never changes the digest")
        #expect(shell.presenter.gestures.state == .idle)
        try FacetedForgeTest.draw(session)
        #expect(try Script.drawn(shell).choice == expected, "the next frame draws the chosen piece")
        #expect(try FacetedForgeTest.digest(shell) == digest)
    }

    /// 3. A rim drag tilts the direction as `FacetedForgePicker.tilt` predicts; a plane drag moves the depth by
    /// `FacetedForgePicker.depthSteps`; neither sends anything nor changes the digest.
    @Test func rimAndPlaneDragsChangeTheChoiceOnly() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Script.open(session, seed: 0)
        let digest: String = try FacetedForgeTest.digest(shell)
        let sentBefore: Script.Sent = Script.sent(shell)
        var time: Double = 0

        // Rim drag.
        let rim: Vec2 = try #require(try Script.rimPoint(shell), "a rim point inside the view")
        let snapshot: FacetedForgeSceneSnapshot = try Script.drawn(shell)
        let play: FacetedForgePlay = try Script.drawnPlay(shell)
        let from: Choice = snapshot.choice
        var rimDrag: Vec2?
        var rimExpected: Choice?
        for candidate in Script.drags {
            let end: Vec2 = rim + candidate
            guard Script.inside(end, inset: 2) else { continue }
            let delta: SIMD2<Double> = SIMD2<Double>(end.x - rim.x, end.y - rim.y)
            let tilted: Choice = FacetedForgePicker.tilt(from, drag: delta, size: Script.size, snapshot: snapshot,
                                                         play: play, orbit: shell.presenter.gestures.orbit)
            if rimDrag == nil || (rimExpected?.direction == from.direction && tilted.direction != from.direction) {
                rimDrag = candidate
                rimExpected = tilted
            }
        }
        let rimMove: Vec2 = try #require(rimDrag, "a rim drag that stays inside the view")
        let tilted: Choice = try #require(rimExpected)
        #expect(tilted.direction != from.direction, "the scripted rim drag tilts to another direction")
        Script.touch(shell, id: 1, .began, at: rim, time: &time)
        #expect(shell.presenter.gestures.state == .rimDrag)
        for step in 1...Script.dragMoves {
            let t: Double = Double(step) / Double(Script.dragMoves)
            Script.touch(shell, id: 1, .moved, at: rim + rimMove * t, time: &time)
        }
        #expect(shell.presenter.gestures.candidate == tilted, "mid-drag the candidate is the predicted tilt")
        #expect(Script.sent(shell) == sentBefore, "nothing is sent mid-drag")
        Script.touch(shell, id: 1, .ended, at: rim + rimMove, time: &time)
        #expect(shell.presenter.mirror.choice == tilted.clamped(to: play), "the rim drag tilts the mirror's choice")
        #expect(shell.presenter.mirror.choice.direction == tilted.direction)
        #expect(shell.presenter.gestures.state == .idle)
        #expect(shell.presenter.gestures.candidate == nil)
        #expect(Script.sent(shell) == sentBefore, "a rim drag sends nothing")
        #expect(try FacetedForgeTest.digest(shell) == digest, "a rim drag never changes the digest")

        // Plane drag (on the newly drawn choice).
        time += 1
        try FacetedForgeTest.draw(session)
        let plane: Vec2 = try #require(try Script.planeTarget(session, shell), "a plane point inside the view")
        let drawn: FacetedForgeSceneSnapshot = try Script.drawn(shell)
        let drawnPlay: FacetedForgePlay = try Script.drawnPlay(shell)
        let start: Choice = drawn.choice
        var planeDrag: Vec2?
        var planeExpected: Choice?
        var planeSteps: Int = 0
        for candidate in Script.drags {
            let end: Vec2 = plane + candidate
            guard Script.inside(end, inset: 2), candidate.length >= FacetedForgeGestureController.dragDistance else {
                continue
            }
            let delta: SIMD2<Double> = SIMD2<Double>(end.x - plane.x, end.y - plane.y)
            let steps: Int = FacetedForgePicker.depthSteps(drag: delta, size: Script.size, snapshot: drawn,
                                                           orbit: shell.presenter.gestures.orbit, reduceMotion: false)
            let moved: Choice = start.steppingDepth(steps, in: drawnPlay)
            if planeDrag == nil || (planeExpected?.depth == start.depth && moved.depth != start.depth) {
                planeDrag = candidate
                planeExpected = moved
                planeSteps = steps
            }
        }
        let planeMove: Vec2 = try #require(planeDrag, "a plane drag that stays inside the view")
        let moved: Choice = try #require(planeExpected)
        #expect(planeSteps != 0, "the scripted plane drag moves by whole depth steps")
        #expect(moved.depth != start.depth, "the scripted plane drag moves the depth")
        Script.touch(shell, id: 1, .began, at: plane, time: &time)
        #expect(shell.presenter.gestures.state == .planePress)
        for step in 1...Script.dragMoves {
            let t: Double = Double(step) / Double(Script.dragMoves)
            Script.touch(shell, id: 1, .moved, at: plane + planeMove * t, time: &time)
        }
        #expect(shell.presenter.gestures.state == .depthDrag)
        #expect(shell.presenter.gestures.candidate == moved, "mid-drag the candidate is the stepped depth")
        Script.touch(shell, id: 1, .ended, at: plane + planeMove, time: &time)
        #expect(shell.presenter.mirror.choice == moved.clamped(to: drawnPlay), "the plane drag moves the depth")
        #expect(shell.presenter.mirror.choice.direction == start.direction)
        #expect(Script.sent(shell) == sentBefore, "a plane drag sends nothing")
        #expect(try FacetedForgeTest.core(shell).play.cuts == 0)
        #expect(try FacetedForgeTest.digest(shell) == digest, "a plane drag never changes the digest")
        #expect(shell.presenter.refusalLog.isEmpty)
    }

    /// 4. A two-finger orbit changes the controller's and, after the next frame, the scene's orbit, never the digest;
    /// `resetView()` returns to the authored orbit.
    @Test func anOrbitChangesTheViewNotTheDigest() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Script.open(session, seed: 0)
        let digest: String = try FacetedForgeTest.digest(shell)
        let sentBefore: Script.Sent = Script.sent(shell)
        #expect(shell.presenter.scene.orbit == .authored)
        var time: Double = 0

        Script.orbit(shell, id: 1, time: &time)
        let orbit: FacetedForgeOrbit = shell.presenter.gestures.orbit
        #expect(orbit != .authored, "two fingers orbit the camera")
        #expect(shell.presenter.gestures.state == .idle)
        #expect(Script.sent(shell) == sentBefore, "an orbit sends nothing")
        #expect(try FacetedForgeTest.digest(shell) == digest, "an orbit never changes the digest")
        try FacetedForgeTest.draw(session)
        #expect(shell.presenter.scene.orbit == orbit, "the scene draws the controller's orbit")
        #expect(try FacetedForgeTest.digest(shell) == digest)
        #expect(shell.presenter.mirror.message == nil)

        shell.presenter.resetView()
        #expect(shell.presenter.gestures.orbit == .authored, "Reset view restores the authored orbit")
        try FacetedForgeTest.draw(session)
        #expect(shell.presenter.scene.orbit == .authored)
        #expect(Script.sent(shell) == sentBefore)
        #expect(try FacetedForgeTest.digest(shell) == digest)
    }

    /// 5. On a won play (level 1's certified solution sent through the port) a tap on the plane sends nothing and the
    /// mirror explains that the play is over.
    @Test func aPlaneTapOnAFinishedPlaySendsNothing() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Script.open(session, seed: 0)
        let number: Int = try FacetedForgeTest.core(shell).levelNumber
        let actions: [FacetedForgeAction] = Core.certifiedActions(number)
        try #require(!actions.isEmpty, "level \(number) has a certified solution")
        for action in actions {
            let issued = FacetedForgeTest.control(action)
            #expect(shell.port.send(issued.control, issued.values) == .accepted)
        }
        let finished: Core = try FacetedForgeTest.core(shell)
        try #require(finished.play.stage == .won, "the certified solution wins level \(number)")
        try FacetedForgeTest.draw(session)
        #expect(try Script.drawn(shell).stage != .playing)
        let point: Vec2 = try #require(try Script.planeTarget(session, shell), "a plane point on the won play")
        let wonSnapshot: FacetedForgeSceneSnapshot = try Script.drawn(shell)
        #expect(Script.pick(shell, point, wonSnapshot) == .plane)
        let digest: String = try FacetedForgeTest.digest(shell)
        let sentBefore: Script.Sent = Script.sent(shell)
        #expect(shell.presenter.mirror.message == nil)
        var time: Double = 0

        Script.tap(shell, id: 1, at: point, time: &time)
        #expect(Script.sent(shell) == sentBefore, "a tap on a finished play sends nothing")
        #expect(try FacetedForgeTest.digest(shell) == digest)
        #expect(try FacetedForgeTest.core(shell).play.fingerprint == finished.play.fingerprint)
        #expect(shell.presenter.mirror.message == FacetedForgePresenter.finishedMessage)
        #expect(shell.presenter.refusalLog.isEmpty, "nothing was refused: nothing was sent")
        #expect(shell.presenter.gestures.state == .idle)
    }

    /// 6. A gesture cut the kernel refuses (a piece undone between frames) is shown in the mirror and logged; the
    /// gesture actions are native actions.
    @Test func aRefusedGestureCutIsShownAndLogged() async throws {
        let seed: UInt64 = try #require(try Script.seedPlayingAfterFirstCut(), "a level still playing after one cut")
        let refusing = ExperienceSession()
        defer { refusing.close() }
        let played = try await Script.open(refusing, seed: seed)
        let gestureActions: Set<String> = played.presenter.gestureActions
        let want: Set<String> = ["piece.cut"]
        #expect(gestureActions == want)
        #expect(gestureActions.isSubset(of: played.presenter.nativeActions))
        let number: Int = try FacetedForgeTest.core(played).levelNumber
        let first: FacetedForgeAction = try #require(FacetedForgeTest.firstCut(number))
        let issued = FacetedForgeTest.control(first)
        #expect(played.port.send(issued.control, issued.values) == .accepted)
        try FacetedForgeTest.draw(refusing)
        let pieces: Int = try Script.drawnPlay(played).pieces.count
        #expect(pieces >= 2)
        let last: Int = pieces - 1
        let point: Vec2 = try #require(try Script.planeTarget(refusing, played, piece: last),
                                       "a plane point on piece \(last + 1)")
        let choice: Choice = try Script.drawn(played).choice
        #expect(choice.piece == last)

        // Undo through the port without drawing: the presenter keeps the two-piece snapshot it drew.
        #expect(played.port.send("play.undo", []) == .accepted)
        let undone: Core = try FacetedForgeTest.core(played)
        #expect(undone.play.pieces.count == 1, "the undo leaves the whole crystal")
        #expect(undone.play.stage == .playing)
        #expect(try Script.drawn(played).pieces.count == pieces, "the drawn snapshot is stale")
        let expected = Script.applied(undone, "piece.cut", Script.cutValues(choice))
        #expect(expected.result != .accepted, "the kernel refuses a cut of a piece that no longer exists")
        let digest: String = try FacetedForgeTest.digest(played)
        let sentBefore: Script.Sent = Script.sent(played)
        let logBefore: Int = played.presenter.refusalLog.count
        var time: Double = 0

        Script.tap(played, id: 1, at: point, time: &time)
        let sentAfter: Script.Sent = Script.sent(played)
        #expect(sentAfter.accepted == sentBefore.accepted)
        #expect(sentAfter.rejected == sentBefore.rejected + 1, "one piece.cut refused")
        #expect(played.presenter.refusalLog.count == logBefore + 1)
        #expect(played.presenter.refusalLog.last == expected.result.code)
        #expect(played.presenter.mirror.message == FacetedForgeFeedbackPlan.refusalText(code: expected.result.code))
        #expect(try FacetedForgeTest.digest(played) == digest)
        #expect(try FacetedForgeTest.core(played).play.fingerprint == undone.play.fingerprint)
    }

    /// 7. A second finger during a plane press cancels it: nothing is sent and no message is shown.
    @Test func aSecondFingerDuringAPlanePressSendsNothing() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Script.open(session, seed: 0)
        let point: Vec2 = try #require(try Script.planeTarget(session, shell), "a plane point inside the view")
        let digest: String = try FacetedForgeTest.digest(shell)
        let sentBefore: Script.Sent = Script.sent(shell)
        let rest: Vec2 = Vec2(8, 8)
        var time: Double = 0

        Script.touch(shell, id: 1, .began, at: point, time: &time)
        #expect(shell.presenter.gestures.state == .planePress)
        Script.touch(shell, id: 2, .began, at: rest, time: &time)
        #expect(shell.presenter.gestures.state == .orbiting, "a second finger turns the press into an orbit")
        Script.touch(shell, id: 1, .ended, at: point, time: &time)
        Script.touch(shell, id: 2, .ended, at: rest, time: &time)
        #expect(Script.sent(shell) == sentBefore, "a second finger during a plane press sends nothing")
        #expect(try FacetedForgeTest.core(shell).play.cuts == 0)
        #expect(try FacetedForgeTest.digest(shell) == digest)
        #expect(shell.presenter.mirror.message == nil)
        #expect(shell.presenter.refusalLog.isEmpty)
        #expect(shell.presenter.gestures.state == .idle)
    }

    /// 8. T-R02G0804-013: when no depth of the chosen direction crosses the chosen piece, the panel's depth label and
    /// the description say the plane misses it, the snapshot has no preview and a choice that crosses reads normally.
    @Test func aPlaneThatMissesThePieceIsNamed() async throws {
        var found: (seed: UInt64, piece: Int, direction: Int)?
        var seed: UInt64 = 0
        while found == nil && seed < 30 {
            let core: Core = try FacetedForgeTest.advanced(Core.levelNumber(forSeed: seed))
            for piece in core.play.pieces.indices where found == nil {
                for direction in FacetedForgeDirection.all.indices where found == nil {
                    if FacetedForgeTest.crossingDepths(core.play.pieces[piece], direction: direction).isEmpty {
                        found = (seed, piece, direction)
                    }
                }
            }
            seed += 1
        }
        let miss = try #require(found, "a piece and direction that no plane crosses within 30 levels")
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Script.open(session, seed: miss.seed)
        #expect(try FacetedForgeTest.advance(shell) == 1)
        _ = try Script.drawn(shell)
        let core: Core = try FacetedForgeTest.core(shell)
        let digest: String = try FacetedForgeTest.digest(shell)
        shell.presenter.mirror.choice = Choice(piece: miss.piece, direction: miss.direction, depth: 0)
        #expect(shell.presenter.mirror.misses)
        #expect(shell.presenter.mirror.depthLabel == "the plane misses this piece")
        let text: String = shell.presenter.describe(core)
        let name: String = FacetedForgeDirection.all[miss.direction].name
        #expect(text.contains("The cut plane misses piece \(miss.piece + 1) in direction \(name)."), "\(text)")
        #expect(!text.contains("Next cut:"), "\(text)")
        let snapshot: FacetedForgeSceneSnapshot = core.snapshot(choice: shell.presenter.mirror.choice, time: 1)
        #expect(snapshot.preview.isEmpty, "no plane is drawn")
        shell.presenter.mirror.choice = Choice.initial(core.play).clamped(to: core.play)
        #expect(!shell.presenter.mirror.misses)
        #expect(shell.presenter.describe(core).contains("Next cut:"))
        #expect(try FacetedForgeTest.digest(shell) == digest, "naming the miss changes nothing")
    }
}
#endif
