// ColorfallCanyonsGestureWiringTests — feature 344 (R02-G05-04) T-R02G0504-005 (FR-R02G0504-001, 002, 004, 005, 006).
// On the simulator, through the one app's session host: scripted touches go to the presenter's
// `pointer(_:viewSize:port:)` with the shell's own `port` (the port the shell's pointer entry hands over) at a
// 720 × 480-point view (aspect 1.5). Targets are placed through the drawn camera
// (`presenter.gestures.camera(viewSize:snapshot:)` at the authored orbit, `ColorfallCanyonsSceneGeometry.project`) and
// confirmed with `ColorfallCanyonsPicker.pick`. The port's constructor is internal to the host, so what the port sent
// is recorded on the shell's engine: its accepted and rejected action counters and the core, compared with a copy of
// the core that applied the expected action itself. Checked:
//   1. a drag of at least 16 points from a carvable cell's projected top centre sends exactly one `canyon.carve [cell]`,
//      accepted; mid-drag the description starts "Carving row r, column c" and the drawn scene highlights the cell;
//      after the release the highlight is gone;
//   2. a tap on a spring's emitter top sends exactly one `canyon.valve [spring]`, accepted;
//   3. a two-finger orbit and a double tap on empty space (a view corner) change no digest and send no action;
//      `resetView()` returns the orbit to the authored one, and the scene draws the orbit on the next frame;
//   4. the gesture actions are exactly carve and valve and a subset of the native actions; `cancelPointers()` mid-drag
//      sends nothing.
// Synthetic timestamps; no sleep, no wall-clock assertion; few frames; each test well under 10 s. Explicit types and
// plain loops (CI type-check rule).
#if os(iOS)
import ColorfallCanyonsCore
import CoreGraphics
import Foundation
import Testing
@testable import ColorfallCanyonsExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreScenes

/// Scripted touches on Colorfall Canyons, placed through the drawn camera.
@MainActor
enum ColorfallCanyonsGestureScript {
    typealias Shell = ExperienceShell<ColorfallCanyonsPresenter>
    typealias Snapshot = ColorfallCanyonsSceneSnapshot
    typealias Geometry = ColorfallCanyonsSceneGeometry

    /// The view's size in points (aspect 1.5, the frame-check aspect).
    static let viewWidth: Double = 720
    static let viewHeight: Double = 480
    /// The view size handed with every event.
    static var viewSize: Vec2 { Vec2(viewWidth, viewHeight) }
    /// The time between scripted events in seconds (synthetic).
    static let frame: Double = 1.0 / 60
    /// The travel of a scripted carve drag in points (at least the 16-point drag distance).
    static let dragTravel: Double = 24

    /// What the engine has counted so far: accepted and rejected actions.
    struct Sent: Equatable {
        let accepted: Int
        let rejected: Int
    }

    /// Opens level `seed % 100 + 1` at the scripted view size (one frame drawn).
    static func open(_ session: ExperienceSession, seed: UInt64 = 0) async throws -> Shell {
        try await ColorfallCanyonsTest.open(session, seed: seed, size: CGSize(width: viewWidth, height: viewHeight))
    }

    /// The engine's action counters of `shell` (every action the port sent lands there).
    static func sent(_ shell: Shell) -> Sent {
        Sent(accepted: shell.engine.acceptedActions, rejected: shell.engine.rejectedActions)
    }

    /// The snapshot the presenter drew last (the gestures read it).
    static func drawn(_ shell: Shell) throws -> Snapshot {
        try #require(shell.presenter.lastSnapshot)
    }

    /// Sends one pointer event to the presenter with the shell's port.
    static func touch(_ shell: Shell, id: Int, _ phase: PointerPhase, at location: Vec2, time: inout Double) {
        let event: PointerEvent = PointerEvent(id: id, phase: phase, location: location, timestamp: time)
        shell.presenter.pointer(event, viewSize: viewSize, port: shell.port)
        time += frame
    }

    /// `world` projected into view points through the camera the gestures use now; nil behind the camera.
    static func viewPoint(_ shell: Shell, _ world: SIMD3<Double>) throws -> Vec2? {
        let snapshot: Snapshot = try drawn(shell)
        let camera: ColorfallCanyonsCamera =
            try #require(shell.presenter.gestures.camera(viewSize: viewSize, snapshot: snapshot))
        guard let unit: SIMD2<Double> = Geometry.project(world, camera: camera) else { return nil }
        return Vec2(unit.x * viewWidth, unit.y * viewHeight)
    }

    /// What the picker gives for `location` at the current orbit.
    static func pick(_ shell: Shell, _ location: Vec2) throws -> ColorfallCanyonsPick {
        let snapshot: Snapshot = try drawn(shell)
        return ColorfallCanyonsPicker.pick(SIMD2<Double>(location.x, location.y),
                                           size: SIMD2<Double>(viewWidth, viewHeight), snapshot: snapshot,
                                           orbit: shell.presenter.gestures.orbit)
    }

    /// Whether `location` lies inside the view with a margin of `inset` points.
    static func inside(_ location: Vec2, inset: Double = 0) -> Bool {
        location.x >= inset && location.x <= viewWidth - inset && location.y >= inset
            && location.y <= viewHeight - inset
    }

    /// The first carvable cell whose projected top centre picks that cell and leaves room for a drag, with that point.
    static func carvableTarget(_ shell: Shell) throws -> (cell: Int, point: Vec2)? {
        let snapshot: Snapshot = try drawn(shell)
        for cell in 0..<snapshot.cellCount {
            guard ColorfallCanyonsGestureController.isCarvable(cell, snapshot: snapshot) else { continue }
            guard let point: Vec2 = try viewPoint(shell, Geometry.cellTop(cell, snapshot)) else { continue }
            guard inside(point, inset: dragTravel + 2) else { continue }
            if try pick(shell, point) == .cell(cell) { return (cell, point) }
        }
        return nil
    }

    /// The first spring whose projected emitter top picks that spring, with that point.
    static func springTarget(_ shell: Shell) throws -> (spring: Int, point: Vec2)? {
        let snapshot: Snapshot = try drawn(shell)
        for spring in 0..<snapshot.springs.count {
            guard let point: Vec2 = try viewPoint(shell, Geometry.emitterTop(spring, snapshot)) else { continue }
            guard inside(point, inset: 1) else { continue }
            if try pick(shell, point) == .spring(spring) { return (spring, point) }
        }
        return nil
    }

    /// The end of a carve drag from `start`: `dragTravel` points to the right, or to the left near the right edge.
    static func dragEnd(from start: Vec2) -> Vec2 {
        let right: Vec2 = Vec2(start.x + dragTravel, start.y)
        return inside(right, inset: 1) ? right : Vec2(start.x - dragTravel, start.y)
    }

    /// Puts finger `id` down at `start` and moves it to `end` in two steps (not released).
    static func dragWithoutRelease(_ shell: Shell, id: Int = 1, from start: Vec2, to end: Vec2, time: inout Double) {
        touch(shell, id: id, .began, at: start, time: &time)
        let middle: Vec2 = Vec2((start.x + end.x) / 2, (start.y + end.y) / 2)
        touch(shell, id: id, .moved, at: middle, time: &time)
        touch(shell, id: id, .moved, at: end, time: &time)
    }

    /// The core `before` after applying `control` with `values` itself, and the adapter's answer.
    static func applied(_ before: ColorfallCanyonsExperienceCore, _ control: String,
                        _ values: [Double]) -> (core: ColorfallCanyonsExperienceCore, result: ActionResult) {
        var copy: ColorfallCanyonsExperienceCore = before
        let result: ActionResult = copy.apply(ExperienceAction(control: control, values: values, step: 0))
        return (copy, result)
    }
}

@MainActor
@Suite(.serialized) struct ColorfallCanyonsGestureWiringTests {
    typealias Script = ColorfallCanyonsGestureScript

    /// A drag of at least 16 points from a carvable cell sends exactly one `canyon.carve [cell]`; mid-drag the cell is
    /// described and highlighted in the drawn scene, and after the release the highlight is gone.
    @Test func aDragFromACarvableCellSendsOneCarve() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Script.open(session)
        #expect(shell.state == .active)
        #expect(shell.presenter.gestures.orbit == .authored)
        let before: ColorfallCanyonsExperienceCore = try ColorfallCanyonsTest.core(shell)
        #expect(before.play.stage == .playing)
        let target = try #require(try Script.carvableTarget(shell), "a carvable cell visible at the authored orbit")
        let columns: Int = try Script.drawn(shell).columns
        let digest: String = try ColorfallCanyonsTest.digest(shell)
        let sentBefore: Script.Sent = Script.sent(shell)
        var time: Double = 0
        let end: Vec2 = Script.dragEnd(from: target.point)

        Script.dragWithoutRelease(shell, from: target.point, to: end, time: &time)
        #expect(shell.presenter.gestures.state == .dragging)
        #expect(shell.presenter.gestures.highlightedCell == target.cell)
        #expect(Script.sent(shell) == sentBefore, "nothing is sent before the release")
        #expect(try ColorfallCanyonsTest.digest(shell) == digest)
        let row: Int = target.cell / columns + 1
        let column: Int = target.cell % columns + 1
        let text: String = shell.presenter.describe(try ColorfallCanyonsTest.core(shell))
        #expect(text.hasPrefix("Carving row \(row), column \(column)"), "\(text)")
        try ColorfallCanyonsTest.draw(session)
        #expect(shell.presenter.scene.highlightedCell == target.cell, "the scene outlines the dragged cell")

        Script.touch(shell, id: 1, .ended, at: end, time: &time)
        let expected = Script.applied(before, "canyon.carve", [Double(target.cell)])
        #expect(expected.result == .accepted)
        let sentAfter: Script.Sent = Script.sent(shell)
        #expect(sentAfter.accepted == sentBefore.accepted + 1, "exactly one action accepted")
        #expect(sentAfter.rejected == sentBefore.rejected, "nothing refused")
        let after: ColorfallCanyonsExperienceCore = try ColorfallCanyonsTest.core(shell)
        #expect(after.play.fingerprint == expected.core.play.fingerprint, "the drag is the adapter's carve of the cell")
        #expect(after.play.spent == before.play.spent + 1)
        #expect(try ColorfallCanyonsTest.digest(shell) != digest, "the carve changes the digest")
        #expect(shell.presenter.mirror.message == nil)
        #expect(shell.presenter.gestures.state == .idle)
        #expect(shell.presenter.gestures.highlightedCell == nil)
        let afterText: String = shell.presenter.describe(after)
        #expect(!afterText.contains("Carving row"), "\(afterText)")
        try ColorfallCanyonsTest.draw(session)
        #expect(shell.presenter.scene.highlightedCell == nil, "no highlight after the release")
    }

    /// A tap on a spring's emitter top sends exactly one `canyon.valve [spring]`.
    @Test func aTapOnASpringSendsOneValve() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Script.open(session)
        let before: ColorfallCanyonsExperienceCore = try ColorfallCanyonsTest.core(shell)
        #expect(before.play.stage == .playing)
        let target = try #require(try Script.springTarget(shell), "a spring emitter visible at the authored orbit")
        let digest: String = try ColorfallCanyonsTest.digest(shell)
        let sentBefore: Script.Sent = Script.sent(shell)
        var time: Double = 0

        Script.touch(shell, id: 1, .began, at: target.point, time: &time)
        #expect(shell.presenter.gestures.highlightedCell == nil, "a spring is never highlighted for a carve")
        Script.touch(shell, id: 1, .ended, at: target.point, time: &time)
        let expected = Script.applied(before, "canyon.valve", [Double(target.spring)])
        #expect(expected.result == .accepted)
        let sentAfter: Script.Sent = Script.sent(shell)
        #expect(sentAfter.accepted == sentBefore.accepted + 1, "exactly one action accepted")
        #expect(sentAfter.rejected == sentBefore.rejected)
        let after: ColorfallCanyonsExperienceCore = try ColorfallCanyonsTest.core(shell)
        #expect(after.play.fingerprint == expected.core.play.fingerprint, "the tap is the adapter's valve toggle")
        let wasOpen: Bool = before.snapshot(time: 0).springs[target.spring].open
        #expect(after.snapshot(time: 0).springs[target.spring].open != wasOpen, "the valve toggled")
        #expect(try ColorfallCanyonsTest.digest(shell) != digest)
        #expect(shell.presenter.mirror.message == nil)
        #expect(shell.presenter.gestures.state == .idle)
    }

    /// A two-finger orbit and a double tap on empty space change no digest and send nothing; `resetView()` returns to
    /// the authored orbit, and the scene draws the orbit on the next frame.
    @Test func orbitDoubleTapAndResetViewSendNothing() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Script.open(session)
        var time: Double = 0
        let digest: String = try ColorfallCanyonsTest.digest(shell)
        let sentBefore: Script.Sent = Script.sent(shell)
        let first: Vec2 = Vec2(8, 8)
        let second: Vec2 = Vec2(8, Script.viewHeight - 8)
        let shift: Double = 100

        /// Two fingers down in the left corners, both moved right by `shift`, both lifted.
        func orbitRight() {
            Script.touch(shell, id: 1, .began, at: first, time: &time)
            Script.touch(shell, id: 2, .began, at: second, time: &time)
            Script.touch(shell, id: 1, .moved, at: Vec2(first.x + shift, first.y), time: &time)
            Script.touch(shell, id: 2, .moved, at: Vec2(second.x + shift, second.y), time: &time)
            Script.touch(shell, id: 1, .ended, at: Vec2(first.x + shift, first.y), time: &time)
            Script.touch(shell, id: 2, .ended, at: Vec2(second.x + shift, second.y), time: &time)
        }

        orbitRight()
        let orbit: ColorfallCanyonsOrbit = shell.presenter.gestures.orbit
        let wantYaw: Double = shift / Script.viewWidth * ColorfallCanyonsGestureController.yawPerViewWidth
        #expect(Swift.abs(orbit.yaw - wantYaw) < 1e-9, "yaw \(orbit.yaw)")
        #expect(Swift.abs(orbit.pitch - ColorfallCanyonsOrbit.authored.pitch) < 1e-9, "pitch \(orbit.pitch)")
        #expect(orbit != .authored)
        #expect(Script.sent(shell) == sentBefore, "an orbit sends nothing")
        #expect(try ColorfallCanyonsTest.digest(shell) == digest, "an orbit never changes the digest")
        #expect(shell.presenter.gestures.state == .idle)
        try ColorfallCanyonsTest.draw(session)
        #expect(shell.presenter.scene.orbit == orbit, "the scene draws the controller's orbit")
        #expect(try ColorfallCanyonsTest.digest(shell) == digest)

        shell.presenter.resetView()
        #expect(shell.presenter.gestures.orbit == .authored, "Reset view restores the authored orbit")
        #expect(shell.presenter.scene.orbit == orbit, "the scene changes only on the next frame")
        try ColorfallCanyonsTest.draw(session)
        #expect(shell.presenter.scene.orbit == .authored)
        #expect(Script.sent(shell) == sentBefore)

        orbitRight()
        #expect(shell.presenter.gestures.orbit != .authored)
        try ColorfallCanyonsTest.draw(session)
        #expect(try Script.pick(shell, first) == .empty, "the corner is empty space")
        Script.touch(shell, id: 3, .began, at: first, time: &time)
        Script.touch(shell, id: 3, .ended, at: first, time: &time)
        #expect(shell.presenter.gestures.orbit != .authored, "one tap does not reset")
        Script.touch(shell, id: 4, .began, at: first, time: &time)
        Script.touch(shell, id: 4, .ended, at: first, time: &time)
        #expect(shell.presenter.gestures.orbit == .authored, "a double tap on empty space resets the view")
        #expect(Script.sent(shell) == sentBefore, "a double tap sends no action")
        #expect(try ColorfallCanyonsTest.digest(shell) == digest)
        #expect(shell.presenter.mirror.message == nil)
        try ColorfallCanyonsTest.draw(session)
        #expect(shell.presenter.scene.orbit == .authored)
        #expect(try ColorfallCanyonsTest.digest(shell) == digest)
    }

    /// The gestures send carve and valve only, both native actions; `cancelPointers()` mid-drag sends nothing.
    @Test func gestureActionsAndCancelMidDrag() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Script.open(session)
        let gestureActions: Set<String> = shell.presenter.gestureActions
        let want: Set<String> = ["canyon.carve", "canyon.valve"]
        #expect(gestureActions == want)
        #expect(gestureActions.isSubset(of: shell.presenter.nativeActions))

        let target = try #require(try Script.carvableTarget(shell), "a carvable cell visible at the authored orbit")
        let before: ColorfallCanyonsExperienceCore = try ColorfallCanyonsTest.core(shell)
        let digest: String = try ColorfallCanyonsTest.digest(shell)
        let sentBefore: Script.Sent = Script.sent(shell)
        var time: Double = 0
        let end: Vec2 = Script.dragEnd(from: target.point)

        Script.dragWithoutRelease(shell, from: target.point, to: end, time: &time)
        #expect(shell.presenter.gestures.highlightedCell == target.cell, "the drag highlights before the cancel")
        shell.presenter.cancelPointers()
        #expect(shell.presenter.gestures.highlightedCell == nil)
        #expect(shell.presenter.gestures.state == .idle)
        Script.touch(shell, id: 1, .ended, at: end, time: &time)
        #expect(Script.sent(shell) == sentBefore, "a cancelled drag sends no carve")
        #expect(try ColorfallCanyonsTest.core(shell).play.fingerprint == before.play.fingerprint)
        #expect(try ColorfallCanyonsTest.digest(shell) == digest)
        #expect(shell.presenter.mirror.message == nil)
        try ColorfallCanyonsTest.draw(session)
        #expect(shell.presenter.scene.highlightedCell == nil)
    }
}
#endif
