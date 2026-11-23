// EchoCartographerGestureWiringTests — feature 404 (R02-G11-04) T-R02G1104-005. On the simulator, through the one
// app's session host: scripted touches go to the presenter's `pointer(_:viewSize:port:)` with the shell's own `port`
// at a 720 × 480-point view (aspect 1.5). Targets are cell centres on the floor (y = 0) projected through the camera
// of the controller's orbit (`EchoCartographerSceneGeometry.camera(_:aspect:orbit:)`) into view points (origin top
// left) and confirmed with `EchoCartographerPicker.pick` on the presenter's `lastSnapshot`. What the port sent is read
// from the shell's engine (accepted and rejected action counters) and the core, compared with a bare core that applied
// the expected action.
// Checked:
//   1. a tap on the entry (known open) sends one `cell.pulse` from it;
//   2. a tap on an unknown cell moves the mirror's cursor there and sends nothing (digest unchanged);
//   3. a drag between two cells without a marker sends one `cell.mark` of the target; the cursor follows;
//   4. dragging that marker to another free cell moves it (`cell.mark` of the old cell, then of the new one);
//   5. a press held 0.6 s and lifted claims: on a known wall the refusal is shown and its code kept in `refusalLog`;
//      on the entry the outcome equals a bare core's claim there;
//   6. a two-finger drag orbits (controller and scene) and changes no digest; a double tap on empty space and
//      `resetView()` return to `.authored`;
//   7. on a won play (level 1's certified solution sent through the port) a tap sends nothing and the mirror shows
//      `EchoCartographerPresenter.finishedMessage`.
// Synthetic timestamps based on the system uptime; no sleep, no wall-clock assertion; no frame is drawn while a press
// is undecided (the presenter's draw ticks the controller with the system clock). Explicit types and plain loops (CI
// type-check rule).
#if os(iOS)
import CoreGraphics
import EchoCartographerCore
import Foundation
import Testing
@testable import EchoCartographerExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreScenes

/// Scripted touches on Echo Cartographer, placed through the drawn camera.
@MainActor
enum EchoCartographerGestureScript {
    typealias Shell = ExperienceShell<EchoCartographerPresenter>
    typealias Snapshot = EchoCartographerSceneSnapshot
    typealias Geometry = EchoCartographerSceneGeometry
    typealias Core = EchoCartographerExperienceCore
    typealias Picker = EchoCartographerPicker

    /// The view's size in points (aspect 1.5).
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
    /// The grid step in points of the search for empty space.
    static let gridStep: Double = 12
    /// The least distance in points between the ends of a scripted drag (≥ 16).
    static let dragLength: Double = 24

    /// What the engine has counted so far: accepted and rejected actions.
    struct Sent: Equatable {
        let accepted: Int
        let rejected: Int
    }

    /// Opens level `seed % 100 + 1` at the scripted view size (one frame drawn).
    static func open(_ session: ExperienceSession, seed: UInt64 = 0) async throws -> Shell {
        try await EchoCartographerTest.open(session, seed: seed, size: CGSize(width: viewWidth, height: viewHeight))
    }

    /// A synthetic clock start near the system uptime (the presenter's draw ticks the controller with it).
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

    /// A one-finger drag with finger `id` from `start` to `end`: down, ``dragMoves`` equal moves, up.
    static func drag(_ shell: Shell, id: Int, from start: Vec2, to end: Vec2, time: inout Double) {
        touch(shell, id: id, .began, at: start, time: &time)
        let delta: Vec2 = end - start
        for step in 1...dragMoves {
            let t: Double = Double(step) / Double(dragMoves)
            touch(shell, id: id, .moved, at: start + delta * t, time: &time)
        }
        touch(shell, id: id, .ended, at: end, time: &time)
    }

    /// A press held still 0.6 s at `location` with finger `id` (a move to the same place 0.6 s after touch-down),
    /// then lifted.
    static func hold(_ shell: Shell, id: Int, at location: Vec2, time: inout Double) {
        let began: Double = time
        touch(shell, id: id, .began, at: location, time: &time)
        time = began + 0.6
        touch(shell, id: id, .moved, at: location, time: &time)
        touch(shell, id: id, .ended, at: location, time: &time)
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
    static func pick(_ location: Vec2, _ snapshot: Snapshot, orbit: EchoCartographerOrbit) -> EchoCartographerPick {
        Picker.pick(SIMD2<Double>(location.x, location.y), size: size, snapshot: snapshot, orbit: orbit)
    }

    /// `world` projected into view points (origin top left) through the camera of `orbit` for `snapshot` at the
    /// scripted view size; nil behind the camera.
    static func viewPoint(_ world: SIMD3<Double>, _ snapshot: Snapshot, orbit: EchoCartographerOrbit) -> Vec2? {
        let camera: EchoCartographerCamera = Geometry.camera(snapshot, aspect: viewWidth / viewHeight, orbit: orbit)
        guard let unit: SIMD2<Double> = Geometry.project(world, camera: camera) else { return nil }
        return Vec2(unit.x * viewWidth, unit.y * viewHeight)
    }

    /// The projected floor centre of `cell` when it lies 2 points inside the view and the picker gives `expected`
    /// there at `orbit`; nil otherwise.
    static func cellPoint(_ cell: EchoCartographerCell, _ snapshot: Snapshot, orbit: EchoCartographerOrbit,
                          expected: EchoCartographerPick) -> Vec2? {
        guard let point: Vec2 = viewPoint(Geometry.cellCentre(cell, snapshot), snapshot, orbit: orbit),
              inside(point, inset: 2) else { return nil }
        return pick(point, snapshot, orbit: orbit) == expected ? point : nil
    }

    /// Every cell of `snapshot`'s chamber in row order.
    static func cells(_ snapshot: Snapshot) -> [EchoCartographerCell] {
        var all: [EchoCartographerCell] = []
        for y in 0..<snapshot.height {
            for x in 0..<snapshot.width {
                all.append(EchoCartographerCell(x: x, y: y))
            }
        }
        return all
    }

    /// The first cell of `snapshot` other than those in `excluded`, known as `known`, without a marker, whose floor
    /// centre picks as that cell at `orbit` and lies at least `distance` points from `away` (when given).
    static func freeCell(_ snapshot: Snapshot, orbit: EchoCartographerOrbit, known: EchoCartographerKnown? = nil,
                         excluded: [EchoCartographerCell] = [], away: Vec2? = nil,
                         distance: Double = 0) -> (cell: EchoCartographerCell, point: Vec2)? {
        for cell in cells(snapshot) {
            if excluded.contains(cell) || snapshot.markers.contains(cell) { continue }
            if let known, snapshot.known(cell) != known { continue }
            guard let point: Vec2 = cellPoint(cell, snapshot, orbit: orbit, expected: .cell(cell)) else { continue }
            if let away, (point - away).length < distance { continue }
            return (cell, point)
        }
        return nil
    }

    /// A point of empty space (the picker gives `.empty`) at least 8 points inside the view: the four corners first,
    /// then a grid; nil when none.
    static func emptyPoint(_ snapshot: Snapshot, orbit: EchoCartographerOrbit) -> Vec2? {
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

    /// The core `before` after applying `control` with `values`, and the adapter's answer.
    static func applied(_ before: Core, _ control: String, _ values: [Double]) -> (core: Core, result: ActionResult) {
        var copy: Core = before
        let result: ActionResult = copy.apply(ExperienceAction(control: control, values: values, step: 0))
        return (copy, result)
    }
}

@MainActor
@Suite(.serialized) struct EchoCartographerGestureWiringTests {
    typealias Script = EchoCartographerGestureScript
    typealias Core = EchoCartographerExperienceCore

    /// 1. A tap on the entry (the one cell known open) sends one pulse from it.
    @Test func aTapOnAnOpenCellPulses() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Script.open(session, seed: 0)
        let gestureActions: Set<String> = shell.presenter.gestureActions
        #expect(gestureActions == ["cell.pulse", "cell.claim", "cell.mark"])
        #expect(gestureActions.isSubset(of: shell.presenter.nativeActions))
        #expect(shell.presenter.gestures.orbit == .authored)
        let before: Core = try EchoCartographerTest.core(shell)
        let entry: EchoCartographerCell = before.play.level.entry
        let expected = Script.applied(before, "cell.pulse", [Double(entry.x), Double(entry.y)])
        #expect(expected.result == .accepted)
        let snapshot: EchoCartographerSceneSnapshot = try Script.drawn(shell)
        let point: Vec2 = try #require(Script.cellPoint(entry, snapshot, orbit: .authored, expected: .cell(entry)),
                                       "the entry picks inside the view")
        let sentBefore: Script.Sent = Script.sent(shell)
        var time: Double = Script.clock()

        Script.tap(shell, id: 1, at: point, time: &time)
        let sentAfter: Script.Sent = Script.sent(shell)
        #expect(sentAfter.accepted == sentBefore.accepted + 1, "one cell.pulse accepted")
        #expect(sentAfter.rejected == sentBefore.rejected)
        let after: Core = try EchoCartographerTest.core(shell)
        #expect(after.play.energy == before.play.energy - 1, "one pulse spent")
        #expect(after.play.records.count == before.play.records.count + 1)
        #expect(after.play.records.last?.action == .pulse(entry.x, entry.y), "the recorded action is the pulse")
        #expect(after.play.fingerprint == expected.core.play.fingerprint)
        #expect(shell.presenter.gestures.state == .idle)
        #expect(shell.presenter.mirror.message == nil)
        #expect(shell.presenter.refusalLog.isEmpty)
    }

    /// 2. A tap on an unknown cell moves the mirror's cursor there; nothing is sent.
    @Test func aTapOnAnUnknownCellMovesTheCursor() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Script.open(session, seed: 0)
        let snapshot: EchoCartographerSceneSnapshot = try Script.drawn(shell)
        let target = try #require(Script.freeCell(snapshot, orbit: .authored, known: .unknown,
                                                  excluded: [snapshot.entry]),
                                  "an unknown cell picks inside the view")
        #expect(shell.presenter.mirror.cursor == snapshot.entry, "the level opens with the cursor on the entry")
        let digest: String = try EchoCartographerTest.digest(shell)
        let sentBefore: Script.Sent = Script.sent(shell)
        var time: Double = Script.clock()

        Script.touch(shell, id: 1, .began, at: target.point, time: &time)
        #expect(shell.presenter.gestures.state == .cellPress)
        Script.touch(shell, id: 1, .ended, at: target.point, time: &time)
        #expect(shell.presenter.mirror.column == target.cell.x, "the cursor's column follows the tap")
        #expect(shell.presenter.mirror.row == target.cell.y, "the cursor's row follows the tap")
        #expect(Script.sent(shell) == sentBefore, "a tap on an unknown cell sends nothing")
        #expect(try EchoCartographerTest.digest(shell) == digest, "the cursor never changes the digest")
        #expect(shell.presenter.gestures.state == .idle)
        #expect(shell.presenter.refusalLog.isEmpty)
    }

    /// 3. A drag between two cells without a marker places one marker on the target; the cursor follows.
    @Test func aDragBetweenFreeCellsPlacesAMarker() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Script.open(session, seed: 0)
        let snapshot: EchoCartographerSceneSnapshot = try Script.drawn(shell)
        let from = try #require(Script.freeCell(snapshot, orbit: .authored, excluded: [snapshot.entry]),
                                "a free cell to start from")
        let to = try #require(Script.freeCell(snapshot, orbit: .authored, excluded: [snapshot.entry, from.cell],
                                              away: from.point, distance: Script.dragLength),
                              "a free cell at least \(Script.dragLength) points away")
        let before: Core = try EchoCartographerTest.core(shell)
        #expect(before.play.markers.isEmpty)
        let sentBefore: Script.Sent = Script.sent(shell)
        var time: Double = Script.clock()

        Script.drag(shell, id: 1, from: from.point, to: to.point, time: &time)
        let sentAfter: Script.Sent = Script.sent(shell)
        #expect(sentAfter.accepted == sentBefore.accepted + 1, "one cell.mark accepted")
        #expect(sentAfter.rejected == sentBefore.rejected)
        let after: Core = try EchoCartographerTest.core(shell)
        #expect(after.play.markers == [to.cell], "the marker is placed on the target")
        #expect(after.play.records.last?.action == .mark(to.cell.x, to.cell.y))
        #expect(after.play.energy == before.play.energy, "a mark is free")
        #expect(shell.presenter.mirror.cursor == to.cell, "the cursor follows the drag")
        #expect(shell.presenter.gestures.state == .idle)
        #expect(shell.presenter.refusalLog.isEmpty)
    }

    /// 4. Dragging a marker to another free cell moves it: the old cell is unmarked, the new one marked.
    @Test func aMarkerDragMovesTheMarker() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Script.open(session, seed: 0)
        let opening: EchoCartographerSceneSnapshot = try Script.drawn(shell)
        let first = try #require(Script.freeCell(opening, orbit: .authored, excluded: [opening.entry]),
                                 "a free cell to mark")
        #expect(shell.port.send("cell.mark", [Double(first.cell.x), Double(first.cell.y)]) == .accepted)
        try EchoCartographerTest.draw(session)
        let snapshot: EchoCartographerSceneSnapshot = try Script.drawn(shell)
        #expect(snapshot.markers == [first.cell], "the drawn snapshot carries the marker")
        let from: Vec2 = try #require(Script.cellPoint(first.cell, snapshot, orbit: .authored,
                                                       expected: .marker(first.cell)),
                                      "the marker picks at its cell's centre")
        let to = try #require(Script.freeCell(snapshot, orbit: .authored, excluded: [snapshot.entry, first.cell],
                                              away: from, distance: Script.dragLength),
                              "a free cell at least \(Script.dragLength) points away")
        let before: Core = try EchoCartographerTest.core(shell)
        let sentBefore: Script.Sent = Script.sent(shell)
        var time: Double = Script.clock()

        Script.touch(shell, id: 1, .began, at: from, time: &time)
        // A press on a marker starts as a cell press and becomes a marker drag once it has moved 16 points.
        #expect(shell.presenter.gestures.state == .cellPress)
        let delta: Vec2 = to.point - from
        for step in 1...Script.dragMoves {
            let t: Double = Double(step) / Double(Script.dragMoves)
            Script.touch(shell, id: 1, .moved, at: from + delta * t, time: &time)
        }
        #expect(shell.presenter.gestures.state == .markerDrag)
        Script.touch(shell, id: 1, .ended, at: to.point, time: &time)
        let sentAfter: Script.Sent = Script.sent(shell)
        #expect(sentAfter.accepted == sentBefore.accepted + 2, "mark(old) then mark(new) accepted")
        #expect(sentAfter.rejected == sentBefore.rejected)
        let after: Core = try EchoCartographerTest.core(shell)
        #expect(after.play.markers == [to.cell], "the marker moved to the target")
        #expect(after.play.records.count == before.play.records.count + 2)
        let count: Int = after.play.records.count
        if count >= 2 {
            #expect(after.play.records[count - 2].action == .mark(first.cell.x, first.cell.y))
            #expect(after.play.records[count - 1].action == .mark(to.cell.x, to.cell.y))
        }
        #expect(shell.presenter.gestures.state == .idle)
        #expect(shell.presenter.refusalLog.isEmpty)
    }

    /// 5. A press held 0.6 s and lifted claims: on a known wall the refusal is shown and logged; on the entry the
    /// outcome is a bare core's claim there.
    @Test func aHeldPressClaims() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Script.open(session, seed: 0)
        try EchoCartographerTest.advance(shell)
        try EchoCartographerTest.draw(session)
        let snapshot: EchoCartographerSceneSnapshot = try Script.drawn(shell)
        let wall = try #require(Script.freeCell(snapshot, orbit: .authored, known: .wall),
                                "a known wall picks inside the view after the entry pulse")
        let before: Core = try EchoCartographerTest.core(shell)
        let refused = Script.applied(before, "cell.claim", [Double(wall.cell.x), Double(wall.cell.y)])
        #expect(!refused.result.isAccepted, "a claim on a known wall is refused")
        let digest: String = try EchoCartographerTest.digest(shell)
        let sentBefore: Script.Sent = Script.sent(shell)
        var time: Double = Script.clock()

        Script.hold(shell, id: 1, at: wall.point, time: &time)
        let sentAfter: Script.Sent = Script.sent(shell)
        #expect(sentAfter.accepted == sentBefore.accepted)
        #expect(sentAfter.rejected == sentBefore.rejected + 1, "one cell.claim refused")
        #expect(shell.presenter.refusalLog == [refused.result.code], "the refusal's code is logged")
        let message: String = try #require(shell.presenter.mirror.message, "the refusal is shown")
        #expect(message.contains(refused.result.code))
        #expect(try EchoCartographerTest.digest(shell) == digest, "a refused claim changes nothing")
        #expect(shell.presenter.gestures.state == .idle)

        let entry: EchoCartographerCell = snapshot.entry
        let entryPoint: Vec2 = try #require(Script.cellPoint(entry, snapshot, orbit: .authored,
                                                             expected: .cell(entry)), "the entry picks")
        let expected = Script.applied(before, "cell.claim", [Double(entry.x), Double(entry.y)])
        time += 1
        Script.hold(shell, id: 2, at: entryPoint, time: &time)
        let after: Core = try EchoCartographerTest.core(shell)
        if expected.result.isAccepted {
            #expect(Script.sent(shell).accepted == sentAfter.accepted + 1, "one cell.claim accepted")
            #expect(after.play.records.last?.action == .claim(entry.x, entry.y), "a claim record appears")
            #expect(after.play.fingerprint == expected.core.play.fingerprint)
        } else {
            #expect(Script.sent(shell).rejected == sentAfter.rejected + 1, "one cell.claim refused")
            #expect(shell.presenter.refusalLog.last == expected.result.code)
            #expect(after.play.fingerprint == before.play.fingerprint)
        }
        #expect(shell.presenter.gestures.state == .idle)
    }

    /// 6. A two-finger drag orbits and changes no digest; a double tap on empty space and `resetView()` return to
    /// the authored orbit.
    @Test func anOrbitChangesTheViewAndResets() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Script.open(session, seed: 0)
        let digest: String = try EchoCartographerTest.digest(shell)
        let sentBefore: Script.Sent = Script.sent(shell)
        #expect(shell.presenter.scene.orbit == .authored)
        var time: Double = Script.clock()

        Script.orbit(shell, id: 1, time: &time)
        let orbit: EchoCartographerOrbit = shell.presenter.gestures.orbit
        #expect(orbit != .authored, "two fingers orbit the camera")
        #expect(Swift.abs(orbit.yaw) <= EchoCartographerOrbit.yawLimit + 1e-12)
        #expect(EchoCartographerOrbit.pitchRange.contains(orbit.pitch))
        #expect(orbit == orbit.clamped())
        #expect(shell.presenter.scene.orbit == orbit, "the scene takes the controller's orbit")
        #expect(shell.presenter.gestures.state == .idle)
        #expect(Script.sent(shell) == sentBefore, "an orbit sends nothing")
        #expect(try EchoCartographerTest.digest(shell) == digest, "an orbit never changes the digest")
        try EchoCartographerTest.draw(session)
        #expect(shell.presenter.scene.orbit == orbit, "the scene draws the controller's orbit")

        time += 1
        let empty: Vec2 = try #require(Script.emptyPoint(try Script.drawn(shell), orbit: orbit),
                                       "empty space inside the view")
        Script.tap(shell, id: 3, at: empty, time: &time)
        #expect(shell.presenter.gestures.orbit == orbit, "one tap keeps the orbit")
        Script.tap(shell, id: 4, at: empty, time: &time)
        #expect(shell.presenter.gestures.orbit == .authored, "a double tap on empty space resets the view")
        #expect(shell.presenter.scene.orbit == .authored)
        #expect(Script.sent(shell) == sentBefore)
        #expect(try EchoCartographerTest.digest(shell) == digest)

        time += 1
        Script.orbit(shell, id: 5, time: &time)
        #expect(shell.presenter.gestures.orbit != .authored)
        shell.presenter.resetView()
        #expect(shell.presenter.gestures.orbit == .authored, "Reset view restores the authored orbit")
        #expect(shell.presenter.scene.orbit == .authored)
        try EchoCartographerTest.draw(session)
        #expect(shell.presenter.scene.orbit == .authored)
        #expect(Script.sent(shell) == sentBefore)
        #expect(try EchoCartographerTest.digest(shell) == digest)
        #expect(shell.presenter.mirror.message == nil)
        #expect(shell.presenter.refusalLog.isEmpty)
    }

    /// 7. On a won play a tap sends nothing and the mirror explains that the play is over.
    @Test func aTapOnAWonPlaySendsNothing() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Script.open(session, seed: 0)
        let number: Int = try EchoCartographerTest.core(shell).levelNumber
        let actions: [EchoCartographerAction] = try EchoCartographerTest.certifiedActions(number)
        try #require(!actions.isEmpty, "level \(number) has a certified solution")
        for action in actions {
            let issued = EchoCartographerTest.control(action)
            #expect(shell.port.send(issued.control, issued.values) == .accepted)
        }
        let won: Core = try EchoCartographerTest.core(shell)
        try #require(won.play.stage == .won, "the certified solution wins level \(number)")
        try EchoCartographerTest.draw(session)
        let snapshot: EchoCartographerSceneSnapshot = try Script.drawn(shell)
        #expect(snapshot.stage == .won)
        let target = try #require(Script.freeCell(snapshot, orbit: shell.presenter.gestures.orbit, known: .open),
                                  "a known-open cell picks inside the view")
        let digest: String = try EchoCartographerTest.digest(shell)
        let sentBefore: Script.Sent = Script.sent(shell)
        #expect(shell.presenter.mirror.message == nil)
        var time: Double = Script.clock()

        Script.tap(shell, id: 1, at: target.point, time: &time)
        #expect(Script.sent(shell) == sentBefore, "a tap on a won play sends nothing")
        #expect(try EchoCartographerTest.digest(shell) == digest)
        #expect(try EchoCartographerTest.core(shell).play.fingerprint == won.play.fingerprint)
        #expect(shell.presenter.mirror.message == EchoCartographerPresenter.finishedMessage)
        #expect(shell.presenter.refusalLog.isEmpty, "nothing was refused: nothing was sent")
        #expect(shell.presenter.gestures.state == .idle)
        // The description of a finished play says it is over and what to do next (T-R02G1104-013).
        let described: String = shell.presenter.describe(try EchoCartographerTest.core(shell))
        #expect(described.contains(EchoCartographerPresenter.finishedMessage), "\(described)")
        let playing: Core = try EchoCartographerTest.advanced(1)
        #expect(!shell.presenter.describe(playing).contains(EchoCartographerPresenter.finishedMessage))
    }
}
#endif
