// BackwardsAuroraGestureWiringTests — feature 394 (R02-G10-04) (FR-R02G1004-001 … 005, 007; SC-R02G1004-001 … 003;
// clarifications Q1–Q4). On the simulator, through the one app's session host: scripted touches go to the presenter's
// `pointer(_:viewSize:port:)` with the shell's own `port` at a 720 × 480-point view (aspect 1.5). Targets are world
// points (a sample point of a column on z = 0, a point of the chosen section's band) projected through the camera the
// presenter's controller draws with (`gestures.camera(viewSize:snapshot:)`, the controller's orbit) into view points
// (origin top left) and confirmed with `BackwardsAuroraPicker.pick` on the presenter's `lastSnapshot`. What the port
// sent is read from the shell's engine (accepted and rejected action counters) and the core, compared with a bare core
// that applied the expected action.
// Checked:
//   1. a tap on a sample left of the chosen section moves its start there; a tap on a sample right of it moves its
//      end; nothing is sent and the digest is unchanged;
//   2. dragging the section's end to another column moves the end there (presentation only, nothing sent);
//   3. a sideways swipe on the band of the section of level 1's first certified reversal sends one `wave.reverse`
//      (spent + 1, the last record's action is that reversal), with the section's preview during the swipe;
//   4. a band press held 0.6 s (a moved event 0.6 s after touch-down within 10 points) freezes: the preview is the
//      kernel's reversal, the mirror's preview text is set after a drawn frame, lifting sends nothing;
//   5. a two-finger drag orbits within bounds and changes no digest; a double tap on empty space and `resetView()`
//      return to `.authored`;
//   6. a swipe on a refused section (a palindrome of a catalog level's opening, else a length outside the level's
//      sections) is shown in the mirror and its reason code appended to `refusalLog`;
//   7. on a won play (level 1's certified solution sent through the port) a swipe sends nothing and the mirror shows
//      `BackwardsAuroraPresenter.finishedMessage`.
// Synthetic timestamps; no sleep, no wall-clock assertion; no frame is drawn while a band press is undecided (the
// presenter's draw ticks the controller with the system clock). Explicit types and plain loops (CI type-check rule).
#if os(iOS)
import CoreGraphics
import Foundation
import BackwardsAuroraCore
import Testing
@testable import BackwardsAuroraExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreScenes

/// Scripted touches on Backwards Aurora, placed through the drawn camera.
@MainActor
enum BackwardsAuroraGestureScript {
    typealias Shell = ExperienceShell<BackwardsAuroraPresenter>
    typealias Snapshot = BackwardsAuroraSceneSnapshot
    typealias Geometry = BackwardsAuroraSceneGeometry
    typealias Core = BackwardsAuroraExperienceCore
    typealias Picker = BackwardsAuroraPicker
    typealias Controller = BackwardsAuroraGestureController

    /// The view's size in points (aspect 1.5).
    static let viewWidth: Double = 720
    static let viewHeight: Double = 480
    /// The view size handed with every event.
    static var viewSize: Vec2 { Vec2(viewWidth, viewHeight) }
    /// The view size as the picker takes it.
    static var size: SIMD2<Double> { SIMD2<Double>(viewWidth, viewHeight) }
    /// The time between scripted events in seconds (synthetic).
    static let frame: Double = 1.0 / 60
    /// The sideways length of a scripted swipe, points (≥ 16).
    static let swipeLength: Double = 30
    /// The moves of a scripted drag or swipe.
    static let dragMoves: Int = 6
    /// The grid step in points of the searches over the view.
    static let gridStep: Double = 12

    /// What the engine has counted so far: accepted and rejected actions.
    struct Sent: Equatable {
        let accepted: Int
        let rejected: Int
    }

    /// Opens level `seed % 100 + 1` at the scripted view size (one frame drawn).
    static func open(_ session: ExperienceSession, seed: UInt64 = 0) async throws -> Shell {
        try await BackwardsAuroraTest.open(session, seed: seed, size: CGSize(width: viewWidth, height: viewHeight))
    }

    /// The engine's action counters of `shell`.
    static func sent(_ shell: Shell) -> Sent {
        Sent(accepted: shell.engine.acceptedActions, rejected: shell.engine.rejectedActions)
    }

    /// The snapshot the presenter drew last (the gestures read it).
    static func drawn(_ shell: Shell) throws -> Snapshot {
        try #require(shell.presenter.lastSnapshot)
    }

    /// Chooses the section [`start`, `end`] in the mirror and draws a frame (the drawn snapshot carries it).
    static func choose(_ session: ExperienceSession, _ shell: Shell, start: Int, end: Int) throws {
        shell.presenter.mirror.start = start
        shell.presenter.mirror.end = end
        try BackwardsAuroraTest.draw(session)
        let snapshot: Snapshot = try drawn(shell)
        #expect(snapshot.sectionStart == start && snapshot.sectionEnd == end, "the drawn section")
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

    /// The down and ``dragMoves`` equal moves of a one-finger drag with finger `id` from `start` to `end`, not lifted.
    static func press(_ shell: Shell, id: Int, from start: Vec2, to end: Vec2, time: inout Double) {
        touch(shell, id: id, .began, at: start, time: &time)
        let drag: Vec2 = end - start
        for step in 1...dragMoves {
            let t: Double = Double(step) / Double(dragMoves)
            touch(shell, id: id, .moved, at: start + drag * t, time: &time)
        }
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

    /// `world` projected into view points (origin top left) through the camera of `orbit` for `snapshot` at the
    /// scripted view size; nil behind the camera.
    static func viewPoint(_ world: SIMD3<Double>, _ snapshot: Snapshot, orbit: BackwardsAuroraOrbit) -> Vec2? {
        let camera: BackwardsAuroraCamera = Geometry.camera(snapshot, aspect: viewWidth / viewHeight, orbit: orbit)
        guard let unit: SIMD2<Double> = Geometry.project(world, camera: camera) else { return nil }
        return Vec2(unit.x * viewWidth, unit.y * viewHeight)
    }

    /// `world` projected through the controller's own camera for `snapshot` (its current orbit); nil behind it.
    static func drawnPoint(_ shell: Shell, _ world: SIMD3<Double>, _ snapshot: Snapshot) -> Vec2? {
        guard let camera: BackwardsAuroraCamera = shell.presenter.gestures.camera(viewSize: viewSize,
                                                                                  snapshot: snapshot),
              let unit: SIMD2<Double> = Geometry.project(world, camera: camera) else { return nil }
        return Vec2(unit.x * viewWidth, unit.y * viewHeight)
    }

    /// What the picker gives for `location` on `snapshot` at `orbit`.
    static func pick(_ location: Vec2, _ snapshot: Snapshot, orbit: BackwardsAuroraOrbit) -> BackwardsAuroraPick {
        Picker.pick(SIMD2<Double>(location.x, location.y), size: size, snapshot: snapshot, orbit: orbit)
    }

    /// Whether `location` lies inside the view with a margin of `inset` points.
    static func inside(_ location: Vec2, inset: Double = 0) -> Bool {
        location.x >= inset && location.x <= viewWidth - inset && location.y >= inset
            && location.y <= viewHeight - inset
    }

    /// The projected sample point of column `k` of `snapshot` when it lies 2 points inside the view and the picker
    /// gives `expected` there at `orbit`; nil otherwise.
    static func samplePoint(_ k: Int, _ snapshot: Snapshot, orbit: BackwardsAuroraOrbit,
                            expected: BackwardsAuroraPick) -> Vec2? {
        guard let point: Vec2 = viewPoint(Geometry.samplePoint(k, snapshot), snapshot, orbit: orbit),
              inside(point, inset: 2) else { return nil }
        return pick(point, snapshot, orbit: orbit) == expected ? point : nil
    }

    /// A point of the chosen section's band of `snapshot` at `orbit` from which a sideways swipe of ``swipeLength``
    /// points stays 2 points inside the view: world points (x across the band in quarter columns from its middle out,
    /// y from 0 out to ±0.65 in steps of 0.05, z = 0) projected and confirmed `.band(_)` by the picker. Returns the
    /// point and the swipe's end; nil when none.
    static func bandSwipe(_ snapshot: Snapshot, orbit: BackwardsAuroraOrbit) -> (start: Vec2, end: Vec2)? {
        let band: ClosedRange<Double> = Geometry.bandRange(snapshot)
        let u: Double = Geometry.spacing(snapshot)
        let middle: Double = (band.lowerBound + band.upperBound) / 2
        var xs: [Double] = [middle]
        var dx: Double = u / 4
        while middle + dx < band.upperBound || middle - dx > band.lowerBound {
            if middle + dx < band.upperBound { xs.append(middle + dx) }
            if middle - dx > band.lowerBound { xs.append(middle - dx) }
            dx += u / 4
        }
        var ys: [Double] = [0]
        var dy: Double = 0.05
        while dy <= 0.65 + 1e-9 {
            ys.append(dy)
            ys.append(-dy)
            dy += 0.05
        }
        for y in ys {
            for x in xs {
                guard let point: Vec2 = viewPoint(SIMD3<Double>(x, y, 0), snapshot, orbit: orbit),
                      inside(point, inset: 2) else { continue }
                guard case .band = pick(point, snapshot, orbit: orbit) else { continue }
                let right: Vec2 = Vec2(point.x + swipeLength, point.y)
                if inside(right, inset: 2) { return (point, right) }
                let left: Vec2 = Vec2(point.x - swipeLength, point.y)
                if inside(left, inset: 2) { return (point, left) }
            }
        }
        return nil
    }

    /// A point of empty space (the picker gives `.empty`) at least 8 points inside the view: the four corners first,
    /// then a grid; nil when none.
    static func emptyPoint(_ snapshot: Snapshot, orbit: BackwardsAuroraOrbit) -> Vec2? {
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

    /// Swipes the band of the drawn section along `swipe` with finger `id`: down, ``dragMoves`` moves, up. No frame is
    /// drawn in between.
    static func swipe(_ shell: Shell, id: Int, _ swipe: (start: Vec2, end: Vec2), time: inout Double) {
        press(shell, id: id, from: swipe.start, to: swipe.end, time: &time)
        touch(shell, id: id, .ended, at: swipe.end, time: &time)
    }

    /// A section of a catalog level's opening (levels 1 … 40) that the kernel refuses and whose band has a swipe at
    /// the authored orbit: a palindrome within the level's section lengths first (code `r02-g10.noop`); failing that, a
    /// section one sample longer than the level's longest (code `r02-g10.action`). Nil when none.
    static func refusedSection() throws -> (seed: UInt64, start: Int, end: Int, code: String)? {
        var fallback: (seed: UInt64, start: Int, end: Int, code: String)?
        for number in 1...40 {
            let core: Core = try Core.opening(number: number)
            let wave: BackwardsAuroraWave = core.play.wave
            let n: Int = wave.count
            let lengths: ClosedRange<Int> = core.play.level.sectionLengths
            for start in 0..<n {
                for length in lengths {
                    let end: Int = start + length - 1
                    guard end < n, wave.isPalindrome(start: start, end: end) else { continue }
                    let result: ActionResult = applied(core, "wave.reverse", [Double(start), Double(end)]).result
                    guard !result.isAccepted else { continue }
                    let snapshot: Snapshot = core.snapshot(sectionStart: start, sectionEnd: end, time: 0)
                    guard bandSwipe(snapshot, orbit: .authored) != nil else { continue }
                    return (UInt64(number - 1), start, end, result.code)
                }
            }
            let long: Int = lengths.upperBound + 1
            if fallback == nil, long <= n {
                let end: Int = long - 1
                let result: ActionResult = applied(core, "wave.reverse", [0, Double(end)]).result
                let snapshot: Snapshot = core.snapshot(sectionStart: 0, sectionEnd: end, time: 0)
                if !result.isAccepted, bandSwipe(snapshot, orbit: .authored) != nil {
                    fallback = (UInt64(number - 1), 0, end, result.code)
                }
            }
        }
        return fallback
    }
}

@MainActor
@Suite(.serialized) struct BackwardsAuroraGestureWiringTests {
    typealias Script = BackwardsAuroraGestureScript
    typealias Core = BackwardsAuroraExperienceCore
    typealias Controller = BackwardsAuroraGestureController
    typealias Geometry = BackwardsAuroraSceneGeometry

    /// 1. A tap on a sample left of the section moves its start there; a tap right of it moves its end.
    @Test func sampleTapsMoveTheSectionsEnds() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Script.open(session, seed: 0)
        #expect(shell.presenter.gestures.orbit == .authored)
        let core: Core = try BackwardsAuroraTest.core(shell)
        let n: Int = core.play.wave.count
        try #require(n >= 12, "a wave of at least 12 samples")
        try Script.choose(session, shell, start: 4, end: 7)
        let digest: String = try BackwardsAuroraTest.digest(shell)
        let sentBefore: Script.Sent = Script.sent(shell)
        var time: Double = 0

        let left: Int = 1
        let leftPoint: Vec2 = try #require(Script.samplePoint(left, try Script.drawn(shell), orbit: .authored,
                                                              expected: .sample(left)),
                                           "sample \(left) picks inside the view")
        Script.touch(shell, id: 1, .began, at: leftPoint, time: &time)
        #expect(shell.presenter.gestures.state == .samplePress)
        Script.touch(shell, id: 1, .ended, at: leftPoint, time: &time)
        #expect(shell.presenter.mirror.start == left, "a tap left of the section moves the start there")
        #expect(shell.presenter.mirror.end == 7)
        #expect(shell.presenter.gestures.state == .idle)

        try BackwardsAuroraTest.draw(session)
        let right: Int = n - 2
        let rightPoint: Vec2 = try #require(Script.samplePoint(right, try Script.drawn(shell), orbit: .authored,
                                                               expected: .sample(right)),
                                            "sample \(right) picks inside the view")
        time += 1
        Script.tap(shell, id: 2, at: rightPoint, time: &time)
        #expect(shell.presenter.mirror.start == left)
        #expect(shell.presenter.mirror.end == right, "a tap right of the section moves the end there")
        #expect(Script.sent(shell) == sentBefore, "taps on samples send nothing")
        #expect(try BackwardsAuroraTest.digest(shell) == digest, "the section never changes the digest")
        try BackwardsAuroraTest.draw(session)
        let drawn: BackwardsAuroraSceneSnapshot = try Script.drawn(shell)
        #expect(drawn.sectionStart == left && drawn.sectionEnd == right, "the next frame draws the new section")
        #expect(shell.presenter.refusalLog.isEmpty)
    }

    /// 2. Dragging the section's end to another column moves the end there; nothing is sent.
    @Test func anEndDragMovesThatEnd() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Script.open(session, seed: 0)
        let n: Int = try BackwardsAuroraTest.core(shell).play.wave.count
        try #require(n >= 12)
        try Script.choose(session, shell, start: 4, end: 7)
        let snapshot: BackwardsAuroraSceneSnapshot = try Script.drawn(shell)
        let from: Vec2 = try #require(Script.drawnPoint(shell, Geometry.samplePoint(7, snapshot), snapshot))
        #expect(Script.pick(from, snapshot, orbit: shell.presenter.gestures.orbit) == .end, "the end's sample point")
        let target: Int = 9
        let to: Vec2 = try #require(Script.drawnPoint(shell, Geometry.samplePoint(target, snapshot), snapshot))
        #expect(Script.inside(to, inset: 2))
        #expect((to - from).length >= Controller.dragDistance + 1)
        let column: Int? = BackwardsAuroraPicker.column(SIMD2<Double>(to.x, to.y), size: Script.size,
                                                        snapshot: snapshot, orbit: shell.presenter.gestures.orbit)
        #expect(column == target, "the finger ends over column \(target)")
        let digest: String = try BackwardsAuroraTest.digest(shell)
        let sentBefore: Script.Sent = Script.sent(shell)
        var time: Double = 0

        Script.touch(shell, id: 1, .began, at: from, time: &time)
        #expect(shell.presenter.gestures.state == .endDrag)
        let drag: Vec2 = to - from
        for step in 1...Script.dragMoves {
            let t: Double = Double(step) / Double(Script.dragMoves)
            Script.touch(shell, id: 1, .moved, at: from + drag * t, time: &time)
        }
        #expect(shell.presenter.mirror.end == target, "the end follows the finger")
        Script.touch(shell, id: 1, .ended, at: to, time: &time)
        #expect(shell.presenter.mirror.start == 4, "the start stays")
        #expect(shell.presenter.mirror.end == target, "the end is dropped at column \(target)")
        #expect(Script.sent(shell) == sentBefore, "an end drag sends nothing")
        #expect(try BackwardsAuroraTest.digest(shell) == digest)
        #expect(shell.presenter.gestures.state == .idle)
        #expect(shell.presenter.refusalLog.isEmpty)
    }

    /// 3. A sideways swipe on the band sends one `wave.reverse` of the chosen section.
    @Test func aSwipeAlongTheSectionReversesIt() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Script.open(session, seed: 0)
        let gestureActions: Set<String> = shell.presenter.gestureActions
        #expect(gestureActions == ["wave.reverse"])
        #expect(gestureActions.isSubset(of: shell.presenter.nativeActions))
        let before: Core = try BackwardsAuroraTest.core(shell)
        let first: BackwardsAuroraAction = try BackwardsAuroraTest.firstAction(before.levelNumber)
        let start: Int
        let end: Int
        switch first {
        case let .reverse(a, b):
            start = a
            end = b
        }
        try Script.choose(session, shell, start: start, end: end)
        let expected = Script.applied(before, "wave.reverse", [Double(start), Double(end)])
        #expect(expected.result == .accepted)
        let path = try #require(Script.bandSwipe(try Script.drawn(shell), orbit: shell.presenter.gestures.orbit),
                                "a band point with room for a swipe")
        let wanted: [Int] = before.play.wave.reversed(start: start, end: end).samples
        let sentBefore: Script.Sent = Script.sent(shell)
        var time: Double = 0

        Script.touch(shell, id: 1, .began, at: path.start, time: &time)
        #expect(shell.presenter.gestures.state == .bandPress)
        let drag: Vec2 = path.end - path.start
        for step in 1...Script.dragMoves {
            let t: Double = Double(step) / Double(Script.dragMoves)
            Script.touch(shell, id: 1, .moved, at: path.start + drag * t, time: &time)
        }
        #expect(shell.presenter.gestures.state == .swipe, "a sideways band drag is a swipe")
        #expect(shell.presenter.gestures.preview?.samples == wanted, "the swipe previews the reversal")
        #expect(Script.sent(shell) == sentBefore, "nothing is sent before the lift")
        Script.touch(shell, id: 1, .ended, at: path.end, time: &time)

        let sentAfter: Script.Sent = Script.sent(shell)
        #expect(sentAfter.accepted == sentBefore.accepted + 1, "one wave.reverse accepted")
        #expect(sentAfter.rejected == sentBefore.rejected)
        let after: Core = try BackwardsAuroraTest.core(shell)
        #expect(after.play.spent == before.play.spent + 1, "one reversal spent")
        #expect(after.play.records.last?.action == .reverse(start, end), "the recorded action is the section")
        #expect(after.play.fingerprint == expected.core.play.fingerprint)
        #expect(after.play.wave.samples == wanted)
        #expect(shell.presenter.gestures.preview == nil)
        #expect(shell.presenter.gestures.state == .idle)
        #expect(shell.presenter.mirror.message == nil)
        #expect(shell.presenter.refusalLog.isEmpty)
    }

    /// 4. A band press held 0.6 s freezes and shows the exact preview; lifting sends nothing.
    @Test func aHeldPressPreviewsTheReversal() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Script.open(session, seed: 0)
        let core: Core = try BackwardsAuroraTest.core(shell)
        let first: BackwardsAuroraAction = try BackwardsAuroraTest.firstAction(core.levelNumber)
        let start: Int
        let end: Int
        switch first {
        case let .reverse(a, b):
            start = a
            end = b
        }
        try Script.choose(session, shell, start: start, end: end)
        let path = try #require(Script.bandSwipe(try Script.drawn(shell), orbit: shell.presenter.gestures.orbit),
                                "a band point")
        let wanted: [Int] = core.play.wave.reversed(start: start, end: end).samples
        let expected: BackwardsAuroraFreezePreview = try #require(
            BackwardsAuroraFreezePreview.make(play: core.play, start: start, end: end))
        #expect(expected.samples == wanted)
        let digest: String = try BackwardsAuroraTest.digest(shell)
        let sentBefore: Script.Sent = Script.sent(shell)
        let began: Double = 10
        var time: Double = began

        Script.touch(shell, id: 1, .began, at: path.start, time: &time)
        #expect(shell.presenter.gestures.state == .bandPress)
        #expect(shell.presenter.gestures.preview == nil, "no preview before the hold")
        let near: Vec2 = Vec2(path.start.x + 3, path.start.y)
        time = began + 0.6
        Script.touch(shell, id: 1, .moved, at: near, time: &time)
        #expect(shell.presenter.gestures.state == .freeze, "held 0.6 s within 10 points freezes")
        let preview: BackwardsAuroraFreezePreview = try #require(shell.presenter.gestures.preview)
        #expect(preview == expected, "the preview is the kernel's reversal of the section")
        try BackwardsAuroraTest.draw(session)
        #expect(shell.presenter.mirror.previewText == preview.text, "the drawn frame describes the preview")
        #expect(shell.presenter.mirror.previewText != nil)
        let drawn: BackwardsAuroraSceneSnapshot = try Script.drawn(shell)
        #expect(drawn.preview.isEmpty, "the kept snapshot never carries the preview")
        #expect(drawn.withPreview(preview.samples).preview == wanted, "the drawn preview samples are the reversal")
        #expect(Script.sent(shell) == sentBefore)
        #expect(try BackwardsAuroraTest.digest(shell) == digest, "the preview never changes the digest")

        Script.touch(shell, id: 1, .ended, at: near, time: &time)
        #expect(Script.sent(shell) == sentBefore, "lifting a frozen press sends nothing")
        #expect(try BackwardsAuroraTest.digest(shell) == digest)
        #expect(shell.presenter.gestures.preview == nil)
        #expect(shell.presenter.gestures.state == .idle)
        try BackwardsAuroraTest.draw(session)
        #expect(shell.presenter.mirror.previewText == nil, "no preview text after the lift")
        #expect(shell.presenter.refusalLog.isEmpty)
    }

    /// 5. A two-finger drag orbits within bounds and changes no digest; a double tap on empty space and `resetView()`
    /// return to the authored orbit.
    @Test func anOrbitChangesTheViewAndResets() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Script.open(session, seed: 0)
        let digest: String = try BackwardsAuroraTest.digest(shell)
        let sentBefore: Script.Sent = Script.sent(shell)
        #expect(shell.presenter.scene.orbit == .authored)
        var time: Double = 0

        Script.orbit(shell, id: 1, time: &time)
        let orbit: BackwardsAuroraOrbit = shell.presenter.gestures.orbit
        #expect(orbit != .authored, "two fingers orbit the camera")
        #expect(Swift.abs(orbit.yaw) <= BackwardsAuroraOrbit.yawLimit + 1e-12)
        #expect(BackwardsAuroraOrbit.pitchRange.contains(orbit.pitch))
        #expect(orbit == orbit.clamped())
        #expect(shell.presenter.gestures.state == .idle)
        #expect(Script.sent(shell) == sentBefore, "an orbit sends nothing")
        #expect(try BackwardsAuroraTest.digest(shell) == digest, "an orbit never changes the digest")
        try BackwardsAuroraTest.draw(session)
        #expect(shell.presenter.scene.orbit == orbit, "the scene draws the controller's orbit")
        #expect(try BackwardsAuroraTest.digest(shell) == digest)

        time += 1
        let empty: Vec2 = try #require(Script.emptyPoint(try Script.drawn(shell), orbit: orbit),
                                       "empty space inside the view")
        Script.tap(shell, id: 3, at: empty, time: &time)
        #expect(shell.presenter.gestures.orbit == orbit, "one tap keeps the orbit")
        Script.tap(shell, id: 4, at: empty, time: &time)
        #expect(shell.presenter.gestures.orbit == .authored, "a double tap on empty space resets the view")
        try BackwardsAuroraTest.draw(session)
        #expect(shell.presenter.scene.orbit == .authored)
        #expect(Script.sent(shell) == sentBefore)
        #expect(try BackwardsAuroraTest.digest(shell) == digest)

        time += 1
        Script.orbit(shell, id: 5, time: &time)
        #expect(shell.presenter.gestures.orbit != .authored)
        shell.presenter.resetView()
        #expect(shell.presenter.gestures.orbit == .authored, "Reset view restores the authored orbit")
        try BackwardsAuroraTest.draw(session)
        #expect(shell.presenter.scene.orbit == .authored)
        #expect(Script.sent(shell) == sentBefore)
        #expect(try BackwardsAuroraTest.digest(shell) == digest)
        #expect(shell.presenter.mirror.message == nil)
        #expect(shell.presenter.refusalLog.isEmpty)
    }

    /// 6. A swipe on a section the kernel refuses is shown in the mirror and its code kept in `refusalLog`.
    @Test func aRefusedSwipeIsShownAndLogged() async throws {
        let refused = try #require(try Script.refusedSection(), "a refused section with a band to swipe")
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Script.open(session, seed: refused.seed)
        let core: Core = try BackwardsAuroraTest.core(shell)
        try Script.choose(session, shell, start: refused.start, end: refused.end)
        let expected = Script.applied(core, "wave.reverse", [Double(refused.start), Double(refused.end)])
        #expect(!expected.result.isAccepted)
        #expect(expected.result.code == refused.code)
        #expect(refused.code.hasSuffix("r02-g10.noop") || refused.code.hasSuffix("r02-g10.action"), "\(refused.code)")
        let path = try #require(Script.bandSwipe(try Script.drawn(shell), orbit: shell.presenter.gestures.orbit),
                                "a band point with room for a swipe")
        let digest: String = try BackwardsAuroraTest.digest(shell)
        let sentBefore: Script.Sent = Script.sent(shell)
        let logBefore: Int = shell.presenter.refusalLog.count
        #expect(shell.presenter.mirror.message == nil)
        var time: Double = 0

        Script.swipe(shell, id: 1, path, time: &time)
        let sentAfter: Script.Sent = Script.sent(shell)
        #expect(sentAfter.accepted == sentBefore.accepted)
        #expect(sentAfter.rejected == sentBefore.rejected + 1, "one wave.reverse refused")
        #expect(shell.presenter.refusalLog.count == logBefore + 1)
        #expect(shell.presenter.refusalLog.last == expected.result.code)
        let message: String = try #require(shell.presenter.mirror.message, "the refusal is shown")
        #expect(!message.isEmpty)
        #expect(try BackwardsAuroraTest.digest(shell) == digest, "a refused reversal changes nothing")
        #expect(try BackwardsAuroraTest.core(shell).play.spent == core.play.spent)
        #expect(shell.presenter.gestures.state == .idle)
    }

    /// 7. On a won play a swipe sends nothing and the mirror explains that the play is over.
    @Test func aSwipeOnAWonPlaySendsNothing() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Script.open(session, seed: 0)
        let number: Int = try BackwardsAuroraTest.core(shell).levelNumber
        let actions: [BackwardsAuroraAction] = try BackwardsAuroraTest.certifiedActions(number)
        try #require(!actions.isEmpty, "level \(number) has a certified solution")
        for action in actions {
            let issued = BackwardsAuroraTest.control(action)
            #expect(shell.port.send(issued.control, issued.values) == .accepted)
        }
        let won: Core = try BackwardsAuroraTest.core(shell)
        try #require(won.play.stage == .won, "the certified solution wins level \(number)")
        try BackwardsAuroraTest.draw(session)
        #expect(try Script.drawn(shell).stage == .won)
        try Script.choose(session, shell, start: 3, end: 6)
        let path = try #require(Script.bandSwipe(try Script.drawn(shell), orbit: shell.presenter.gestures.orbit),
                                "a band point with room for a swipe")
        let digest: String = try BackwardsAuroraTest.digest(shell)
        let sentBefore: Script.Sent = Script.sent(shell)
        #expect(shell.presenter.mirror.message == nil)
        var time: Double = 0

        Script.press(shell, id: 1, from: path.start, to: path.end, time: &time)
        #expect(shell.presenter.gestures.state == .swipe)
        Script.touch(shell, id: 1, .ended, at: path.end, time: &time)
        #expect(Script.sent(shell) == sentBefore, "a swipe on a won play sends nothing")
        #expect(try BackwardsAuroraTest.digest(shell) == digest)
        #expect(try BackwardsAuroraTest.core(shell).play.fingerprint == won.play.fingerprint)
        #expect(shell.presenter.mirror.message == BackwardsAuroraPresenter.finishedMessage)
        #expect(shell.presenter.refusalLog.isEmpty, "nothing was refused: nothing was sent")
        #expect(shell.presenter.gestures.state == .idle)
    }
}
#endif
