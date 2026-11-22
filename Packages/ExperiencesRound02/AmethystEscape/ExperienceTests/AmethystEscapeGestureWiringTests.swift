// AmethystEscapeGestureWiringTests — feature 364 (R02-G07-04) T-R02G0704-006 (FR-R02G0704-001 … 008;
// clarifications Q1–Q5). On the simulator, through the one app's session host: scripted touches go to the presenter's
// `pointer(_:viewSize:port:)` with the shell's own `port` at a 720 × 480-point view (aspect 1.5). Targets are world
// points (a wedge top centre at a chosen angle on a shell's mid radius r_k + w/2 at y = h_k; the pearl centre)
// projected through the camera the presenter draws with (`AmethystEscapeSceneGeometry.camera(_:aspect:orbit:)` at the
// controller's orbit) into view points (origin top left) and confirmed with `AmethystEscapePicker`. What the port sent
// is read from the shell's engine (accepted and rejected action counters) and the core, compared with a bare core that
// applied the expected actions itself. Checked:
//   1. a drag round a shell's ring sweeping two sectors turns that shell twice (offset ±2 mod S, moves +2); mid-drag
//      the presenter's previewed snapshot shows the turn and the description says "would turn 2 sectors";
//   2. a tap on the pearl's projected centre advances (moves +1, a `pearl.advance` record);
//   3. a tap on a shell picks it in the panel without changing the digest;
//   4. a double tap on a shell isolates it (the next frame still passes the pearl check, the digest is unchanged) and
//      "Show all layers" clears it;
//   5. a two-finger orbit changes the frame but not the digest; `resetView()` returns to the authored orbit;
//   6. on a finished play (budget spent by alternating panel turns) a drag sends nothing and the panel shows
//      `AmethystEscapePresenter.finishedMessage`;
//   7. a refused action sent by the presenter is shown in the panel and its code appended to `refusalLog`; the gesture
//      actions are native actions.
// Synthetic timestamps; no sleep, no wall-clock assertion; few frames. Explicit types and plain loops (CI type-check
// rule).
#if os(iOS)
import AmethystEscapeCore
import CoreGraphics
import Foundation
import Testing
@testable import AmethystEscapeExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreScenes

/// A shell drag target: the shell, the scripted path (touch-down point first) and the sectors it sweeps.
struct AmethystEscapeDragTarget {
    let shell: Int
    let path: [Vec2]
    let sectors: Int
}

/// Scripted touches on Amethyst Escape, placed through the drawn camera.
@MainActor
enum AmethystEscapeGestureScript {
    typealias Shell = ExperienceShell<AmethystEscapePresenter>
    typealias Snapshot = AmethystEscapeSceneSnapshot
    typealias Geometry = AmethystEscapeSceneGeometry
    typealias Core = AmethystEscapeExperienceCore

    /// The view's size in points (aspect 1.5, the frame-check aspect).
    static let viewWidth: Double = 720
    static let viewHeight: Double = 480
    /// The view size handed with every event.
    static var viewSize: Vec2 { Vec2(viewWidth, viewHeight) }
    /// The time between scripted events in seconds (synthetic).
    static let frame: Double = 1.0 / 60
    /// The moves of a scripted drag round a ring (each well under half a turn, so the sweep unwraps).
    static let dragMoves: Int = 8
    /// The seeds searched for a level with a wanted property (seed = level − 1).
    static let searchedSeeds: Int = 30

    /// What the engine has counted so far: accepted and rejected actions.
    struct Sent: Equatable {
        let accepted: Int
        let rejected: Int
    }

    /// Opens level `seed % 100 + 1` at the scripted view size (one frame drawn).
    static func open(_ session: ExperienceSession, seed: UInt64 = 0) async throws -> Shell {
        try await AmethystEscapeTest.open(session, seed: seed, size: CGSize(width: viewWidth, height: viewHeight))
    }

    /// The first seed below ``searchedSeeds`` whose opening core satisfies `wanted`, or nil.
    static func seed(where wanted: (Core) -> Bool) throws -> UInt64? {
        for seed in 0..<UInt64(searchedSeeds) {
            let core: Core = try Core.opening(number: Core.levelNumber(forSeed: seed))
            if wanted(core) { return seed }
        }
        return nil
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

    /// `world` projected into view points (origin top left) through the camera the presenter draws with at the
    /// controller's current orbit; nil behind the camera.
    static func viewPoint(_ shell: Shell, _ world: SIMD3<Double>) throws -> Vec2? {
        let snapshot: Snapshot = try drawn(shell)
        let camera: AmethystEscapeCamera = Geometry.camera(snapshot, aspect: viewWidth / viewHeight,
                                                           orbit: shell.presenter.gestures.orbit)
        guard let unit: SIMD2<Double> = Geometry.project(world, camera: camera) else { return nil }
        return Vec2(unit.x * viewWidth, unit.y * viewHeight)
    }

    /// What the picker gives for `location` at the current orbit.
    static func pick(_ shell: Shell, _ location: Vec2) throws -> AmethystEscapePick {
        let snapshot: Snapshot = try drawn(shell)
        return AmethystEscapePicker.pick(SIMD2<Double>(location.x, location.y),
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

    /// The world point on shell `shell`'s mid radius r_k + w/2 at angle `angle` (from +x towards +z), y = h_k: a wedge
    /// top centre when `angle` is a sector's middle angle.
    static func ringPoint(shell: Int, angle: Double, _ snapshot: Snapshot) -> SIMD3<Double> {
        let r: Double = Geometry.shellRadius(shell, snapshot) + Geometry.shellWidth(snapshot) / 2
        return SIMD3<Double>(r * cos(angle), Geometry.shellHeight(shell, snapshot), r * sin(angle))
    }

    /// The middle angle of world sector `world`.
    static func sectorAngle(_ world: Int, _ snapshot: Snapshot) -> Double {
        2 * Double.pi * (Double(world) + 0.5) / Double(Swift.max(snapshot.sectors, 1))
    }

    /// A wedge top centre of shell `shell` (world sectors from 0) whose projection picks that shell, else nil.
    static func shellPoint(_ shell: Shell, shell index: Int) throws -> Vec2? {
        let snapshot: Snapshot = try drawn(shell)
        for world in 0..<snapshot.sectors {
            let world3: SIMD3<Double> = ringPoint(shell: index, angle: sectorAngle(world, snapshot), snapshot)
            guard let point: Vec2 = try viewPoint(shell, world3), inside(point, inset: 2) else { continue }
            if try pick(shell, point) == .shell(index) { return point }
        }
        return nil
    }

    /// The first shell, outermost first, with a wedge top centre that picks it: (shell, point), else nil.
    static func shellTarget(_ shell: Shell) throws -> (shell: Int, point: Vec2)? {
        let count: Int = try drawn(shell).shells.count
        var index: Int = count - 1
        while index >= 0 {
            if let point: Vec2 = try shellPoint(shell, shell: index) { return (index, point) }
            index -= 1
        }
        return nil
    }

    /// A drag round shell `index`'s ring sweeping `sectors` sectors (sign: +x towards +z, the kernel's +1): from a
    /// wedge top centre that picks the shell, through ``dragMoves`` equal angle steps on the ring, every point inside
    /// the view, ending at least 20 points from the start. Nil when no start sector works.
    static func ringDrag(_ shell: Shell, shell index: Int, sectors: Int) throws -> AmethystEscapeDragTarget? {
        let snapshot: Snapshot = try drawn(shell)
        let sweep: Double = 2 * Double.pi / Double(Swift.max(snapshot.sectors, 1)) * Double(sectors)
        for world in 0..<snapshot.sectors {
            let a0: Double = sectorAngle(world, snapshot)
            var path: [Vec2] = []
            var usable: Bool = true
            for step in 0...dragMoves {
                let angle: Double = a0 + sweep * Double(step) / Double(dragMoves)
                guard let point: Vec2 = try viewPoint(shell, ringPoint(shell: index, angle: angle, snapshot)),
                      inside(point, inset: 2) else {
                    usable = false
                    break
                }
                path.append(point)
            }
            guard usable, let first: Vec2 = path.first, let last: Vec2 = path.last else { continue }
            guard distance(first, last) >= AmethystEscapeGestureController.dragDistance + 4 else { continue }
            guard try pick(shell, first) == .shell(index) else { continue }
            return AmethystEscapeDragTarget(shell: index, path: path, sectors: sectors)
        }
        return nil
    }

    /// The first ring drag of `sectors` (then −`sectors`) sectors on any shell, outermost first.
    static func dragTarget(_ shell: Shell, sectors: Int = 2) throws -> AmethystEscapeDragTarget? {
        let count: Int = try drawn(shell).shells.count
        for sign in [1, -1] {
            var index: Int = count - 1
            while index >= 0 {
                if let target = try ringDrag(shell, shell: index, sectors: sign * sectors) { return target }
                index -= 1
            }
        }
        return nil
    }

    /// Puts finger `id` down at the path's first point and moves it through the rest (not released).
    static func dragWithoutRelease(_ shell: Shell, id: Int = 1, along path: [Vec2], time: inout Double) {
        guard let first: Vec2 = path.first else { return }
        touch(shell, id: id, .began, at: first, time: &time)
        for point in path.dropFirst() {
            touch(shell, id: id, .moved, at: point, time: &time)
        }
    }

    /// A tap (down and up at `location`, one frame apart) with finger `id`.
    static func tap(_ shell: Shell, id: Int, at location: Vec2, time: inout Double) {
        touch(shell, id: id, .began, at: location, time: &time)
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

    /// The core `before` after applying `control` with `values` `times` times itself, and the adapter's last answer.
    static func applied(_ before: Core, _ control: String, _ values: [Double],
                        times: Int = 1) -> (core: Core, result: ActionResult) {
        var copy: Core = before
        var result: ActionResult = .accepted
        for _ in 0..<times {
            result = copy.apply(ExperienceAction(control: control, values: values, step: 0))
        }
        return (copy, result)
    }

    /// `value` modulo `n` in 0 … n − 1.
    static func modulo(_ value: Int, _ n: Int) -> Int {
        ((value % n) + n) % n
    }
}

@MainActor
@Suite(.serialized) struct AmethystEscapeGestureWiringTests {
    typealias Script = AmethystEscapeGestureScript
    typealias Core = AmethystEscapeExperienceCore

    /// 1. A drag round a shell's ring sweeping two sectors turns that shell twice; mid-drag the preview and the
    /// description show the turn.
    @Test func aRingDragTurnsTheShellTwice() async throws {
        let seed: UInt64 = try #require(try Script.seed { $0.play.level.budget >= 3 }, "a level with budget ≥ 3")
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Script.open(session, seed: seed)
        #expect(shell.state == .active)
        #expect(shell.presenter.gestures.orbit == .authored)
        let before: Core = try AmethystEscapeTest.core(shell)
        #expect(before.play.stage == .playing)
        let target: AmethystEscapeDragTarget =
            try #require(try Script.dragTarget(shell), "a shell ring visible at the authored orbit")
        let k: Int = target.shell
        let snapshot: AmethystEscapeSceneSnapshot = try Script.drawn(shell)
        let sectors: Int = snapshot.sectors
        let offset: Int = snapshot.shells[k].offset
        let digest: String = try AmethystEscapeTest.digest(shell)
        let sentBefore: Script.Sent = Script.sent(shell)
        var time: Double = 0

        Script.dragWithoutRelease(shell, along: target.path, time: &time)
        #expect(shell.presenter.gestures.state == .shellDrag)
        #expect(shell.presenter.gestures.draggedShell == k)
        #expect(shell.presenter.gestures.candidateSectors == target.sectors, "the sweep is two sectors")
        #expect(Script.sent(shell) == sentBefore, "nothing is sent before the release")
        let preview: AmethystEscapeSceneSnapshot = shell.presenter.previewed(snapshot)
        #expect(preview == snapshot.previewing(shell: k, sectors: target.sectors))
        #expect(preview.shells[k].offset == Script.modulo(offset + target.sectors, sectors), "the preview turns k")
        #expect(preview.moves == snapshot.moves, "a preview spends nothing")
        let text: String = shell.presenter.describe(try AmethystEscapeTest.core(shell))
        #expect(text.contains("would turn 2 sectors"), "\(text)")
        try AmethystEscapeTest.draw(session)
        #expect(try AmethystEscapeTest.digest(shell) == digest, "a preview never changes the digest")

        let last: Vec2 = try #require(target.path.last)
        Script.touch(shell, id: 1, .ended, at: last, time: &time)
        let step: Double = target.sectors > 0 ? 1 : -1
        let expected = Script.applied(before, "shell.rotate", [Double(k), step], times: 2)
        #expect(expected.result == .accepted)
        let sentAfter: Script.Sent = Script.sent(shell)
        #expect(sentAfter.accepted == sentBefore.accepted + 2, "exactly two turns accepted")
        #expect(sentAfter.rejected == sentBefore.rejected, "nothing refused")
        let after: Core = try AmethystEscapeTest.core(shell)
        #expect(after.play.fingerprint == expected.core.play.fingerprint, "the drag is two shell.rotate turns")
        let turned: AmethystEscapeSceneSnapshot = after.snapshot(time: 0)
        #expect(turned.shells[k].offset == Script.modulo(offset + target.sectors, sectors))
        #expect(turned.moves == snapshot.moves + 2)
        #expect(try AmethystEscapeTest.digest(shell) != digest, "the turns change the digest")
        #expect(shell.presenter.gestures.state == .idle)
        #expect(shell.presenter.gestures.candidateSectors == 0)
        #expect(shell.presenter.refusalLog.isEmpty)
        try AmethystEscapeTest.draw(session)
        let redrawn: AmethystEscapeSceneSnapshot = try Script.drawn(shell)
        #expect(redrawn.shells == turned.shells, "the next frame draws the kernel's turn")
        #expect(redrawn.moves == turned.moves)
    }

    /// 2. A tap on the pearl's projected centre advances it: one move and a `pearl.advance` record.
    @Test func aPearlTapAdvances() async throws {
        let seed: UInt64 = try #require(try Script.seed { core in
            Script.applied(core, "pearl.advance", []).result == .accepted
        }, "a level whose pearl can advance at the start")
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Script.open(session, seed: seed)
        let before: Core = try AmethystEscapeTest.core(shell)
        let snapshot: AmethystEscapeSceneSnapshot = try Script.drawn(shell)
        let point: Vec2 = try #require(try Script.viewPoint(shell, AmethystEscapeSceneGeometry.pearlCentre(snapshot)))
        #expect(Script.inside(point, inset: 1))
        #expect(try Script.pick(shell, point) == .pearl, "the pearl's projected centre picks the pearl")
        let digest: String = try AmethystEscapeTest.digest(shell)
        let sentBefore: Script.Sent = Script.sent(shell)
        var time: Double = 0

        Script.touch(shell, id: 1, .began, at: point, time: &time)
        #expect(shell.presenter.gestures.state == .pearlPress)
        Script.touch(shell, id: 1, .ended, at: point, time: &time)
        let expected = Script.applied(before, "pearl.advance", [])
        #expect(expected.result == .accepted)
        let sentAfter: Script.Sent = Script.sent(shell)
        #expect(sentAfter.accepted == sentBefore.accepted + 1, "one pearl.advance accepted")
        #expect(sentAfter.rejected == sentBefore.rejected)
        let after: Core = try AmethystEscapeTest.core(shell)
        #expect(after.play.fingerprint == expected.core.play.fingerprint)
        #expect(after.play.moves == before.play.moves + 1)
        #expect(after.play.records.last?.kind == .advance, "the record is an advance")
        #expect(try AmethystEscapeTest.digest(shell) != digest)
        #expect(shell.presenter.mirror.message == nil)
        #expect(shell.presenter.refusalLog.isEmpty)
    }

    /// 3. A tap on a shell picks it in the panel; nothing is sent and the digest is unchanged.
    @Test func aShellTapPicksIt() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Script.open(session)
        _ = shell.presenter.describe(try AmethystEscapeTest.core(shell))
        let target = try #require(try Script.shellTarget(shell), "a shell visible at the authored orbit")
        if target.shell == 0 { shell.presenter.mirror.pickedShell = 1 }
        #expect(shell.presenter.mirror.pickedShell != target.shell)
        let digest: String = try AmethystEscapeTest.digest(shell)
        let sentBefore: Script.Sent = Script.sent(shell)
        var time: Double = 0

        Script.tap(shell, id: 1, at: target.point, time: &time)
        #expect(shell.presenter.mirror.pickedShell == target.shell, "the tap picks the shell in the panel")
        #expect(Script.sent(shell) == sentBefore, "a tap on a shell sends no action")
        #expect(try AmethystEscapeTest.digest(shell) == digest)
        #expect(shell.presenter.gestures.isolated == nil, "one tap does not isolate")
        #expect(shell.presenter.gestures.state == .idle)
    }

    /// 4. A double tap on a shell isolates it; the next frame still shows the pearl; "Show all layers" clears it.
    @Test func aDoubleTapIsolatesAShell() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Script.open(session)
        let target = try #require(try Script.shellTarget(shell), "a shell visible at the authored orbit")
        let k: Int = target.shell
        let digest: String = try AmethystEscapeTest.digest(shell)
        let sentBefore: Script.Sent = Script.sent(shell)
        var time: Double = 0

        Script.tap(shell, id: 1, at: target.point, time: &time)
        Script.tap(shell, id: 2, at: target.point, time: &time)
        #expect(shell.presenter.gestures.isolated == k, "the double tap isolates the shell")
        #expect(Script.sent(shell) == sentBefore, "isolation sends no action")
        #expect(try AmethystEscapeTest.digest(shell) == digest, "isolation never changes the digest")
        let text: String = shell.presenter.describe(try AmethystEscapeTest.core(shell))
        #expect(text.contains("alone"), "\(text)")

        try AmethystEscapeTest.draw(session)
        #expect(shell.presenter.scene.isolated == k, "the scene draws the isolation")
        let rgba: [UInt8] = try AmethystEscapeTest.still(session)
        let snapshot: AmethystEscapeSceneSnapshot = try Script.drawn(shell)
        let pearl: [String] = AmethystEscapeTest.pearlMisses(rgba, snapshot: snapshot)
        #expect(pearl.isEmpty, "isolated frame: \(pearl)")
        let background = AmethystEscapeTest.backgroundMisses(rgba)
        #expect(background.misses.isEmpty, "isolated frame: \(background.misses)")
        #expect(try AmethystEscapeTest.digest(shell) == digest)

        shell.presenter.showAllLayers()
        #expect(shell.presenter.gestures.isolated == nil, "Show all layers clears the isolation")
        try AmethystEscapeTest.draw(session)
        #expect(shell.presenter.scene.isolated == nil)
        #expect(try AmethystEscapeTest.digest(shell) == digest)
    }

    /// 5. A two-finger orbit changes the frame, not the digest; `resetView()` returns to the authored orbit.
    @Test func anOrbitChangesTheFrameNotTheDigest() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Script.open(session)
        let digest: String = try AmethystEscapeTest.digest(shell)
        let sentBefore: Script.Sent = Script.sent(shell)
        let authoredFrame: [UInt8] = try AmethystEscapeTest.still(session)
        var time: Double = 0

        Script.orbit(shell, id: 1, time: &time)
        let orbit: AmethystEscapeOrbit = shell.presenter.gestures.orbit
        #expect(orbit != .authored, "two fingers orbit the camera")
        #expect(shell.presenter.gestures.state == .idle)
        #expect(Script.sent(shell) == sentBefore, "an orbit sends nothing")
        #expect(try AmethystEscapeTest.digest(shell) == digest, "an orbit never changes the digest")
        try AmethystEscapeTest.draw(session)
        #expect(shell.presenter.scene.orbit == orbit, "the scene draws the controller's orbit")
        let orbitedFrame: [UInt8] = try AmethystEscapeTest.still(session)
        #expect(orbitedFrame.count == authoredFrame.count)
        #expect(orbitedFrame != authoredFrame, "the orbit changes the frame")
        #expect(try AmethystEscapeTest.digest(shell) == digest)

        shell.presenter.resetView()
        #expect(shell.presenter.gestures.orbit == .authored, "Reset view restores the authored orbit")
        try AmethystEscapeTest.draw(session)
        #expect(shell.presenter.scene.orbit == .authored)
        #expect(Script.sent(shell) == sentBefore)
        #expect(try AmethystEscapeTest.digest(shell) == digest)
    }

    /// 6. On a finished play (budget spent by alternating panel turns) a drag sends nothing and the panel explains
    /// that the play is over.
    @Test func aDragOnAFinishedPlaySendsNothing() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Script.open(session)
        let budget: Int = try AmethystEscapeTest.core(shell).play.level.budget
        var turn: Int = 0
        while try AmethystEscapeTest.core(shell).play.stage == .playing && turn < budget + 1 {
            let step: Double = turn % 2 == 0 ? 1 : -1
            #expect(shell.handle(control: "shell.rotate", values: [0, step]) == .accepted)
            turn += 1
        }
        let finished: Core = try AmethystEscapeTest.core(shell)
        try #require(finished.play.stage != .playing, "the budget is spent")
        #expect(finished.play.moves == budget)
        try AmethystEscapeTest.draw(session)
        #expect(try Script.drawn(shell).stage != .playing)
        let target: AmethystEscapeDragTarget =
            try #require(try Script.dragTarget(shell), "a shell ring visible at the authored orbit")
        let digest: String = try AmethystEscapeTest.digest(shell)
        let sentBefore: Script.Sent = Script.sent(shell)
        #expect(shell.presenter.mirror.message == nil)
        var time: Double = 0

        Script.dragWithoutRelease(shell, along: target.path, time: &time)
        #expect(shell.presenter.gestures.candidateSectors == 0, "no preview on a finished play")
        let last: Vec2 = try #require(target.path.last)
        Script.touch(shell, id: 1, .ended, at: last, time: &time)
        #expect(Script.sent(shell) == sentBefore, "a drag on a finished play sends nothing")
        #expect(try AmethystEscapeTest.digest(shell) == digest)
        #expect(try AmethystEscapeTest.core(shell).play.fingerprint == finished.play.fingerprint)
        #expect(shell.presenter.mirror.message == AmethystEscapePresenter.finishedMessage)
        #expect(shell.presenter.refusalLog.isEmpty, "nothing was refused: nothing was sent")
        #expect(shell.presenter.gestures.state == .idle)
    }

    /// 7. A refused action sent by the presenter is shown in the panel and logged; the gesture actions are native
    /// actions.
    @Test func aRefusedActionIsShownAndLogged() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Script.open(session)
        let gestureActions: Set<String> = shell.presenter.gestureActions
        let want: Set<String> = ["shell.rotate", "pearl.advance"]
        #expect(gestureActions == want)
        #expect(gestureActions.isSubset(of: shell.presenter.nativeActions))

        let before: Core = try AmethystEscapeTest.core(shell)
        let missing: Double = Double(before.play.level.shells.count)
        let expected = Script.applied(before, "shell.rotate", [missing, 1])
        #expect(expected.result != .accepted, "the kernel refuses a missing shell")
        let digest: String = try AmethystEscapeTest.digest(shell)
        let sentBefore: Script.Sent = Script.sent(shell)
        let logBefore: Int = shell.presenter.refusalLog.count

        let result: ActionResult = shell.presenter.send("shell.rotate", [missing, 1], port: shell.port)
        #expect(result != .accepted)
        #expect(result.code == expected.result.code)
        let sentAfter: Script.Sent = Script.sent(shell)
        #expect(sentAfter.accepted == sentBefore.accepted)
        #expect(sentAfter.rejected == sentBefore.rejected + 1, "one shell.rotate refused")
        #expect(shell.presenter.refusalLog.count == logBefore + 1)
        #expect(shell.presenter.refusalLog.last == result.code)
        #expect(shell.presenter.mirror.message == "That change was refused: \(result.code)")
        #expect(try AmethystEscapeTest.digest(shell) == digest)
        #expect(try AmethystEscapeTest.core(shell).play.fingerprint == before.play.fingerprint)
    }
}
#endif
