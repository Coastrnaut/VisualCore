// HueCompassGestureWiringTests — feature 334 (R02-G04-04) T-R02G0404-005 (FR-R02G0404-001 … 006; SC-R02G0404-001 …
// 003; clarifications Q2–Q5). On the simulator, through the one app's session host: scripted touches enter through the
// shell's pointer entry (`ExperienceShell.handlePointer`, which hands them to the presenter's
// `pointer(_:viewSize:port:)` with the shell's own `port` while the experience is active) at a 720 × 480-point view
// (aspect 1.5). Swipes are arcs of radius 120 points about the compass centre projected through the drawn camera
// (`presenter.gestures.camera(viewSize:)`, `HueCompassDial.centre`), swept by k × 2π / 96 in steps smaller than half a
// turn. Checked:
//   1. a swipe of k bearings sends one `compass.turn [k]`: the play equals the adapter's own turn of k and the digest
//      changes;
//   2. mid-swipe the preview is the start bearing plus k, the scene draws the ghost at it, the description reads
//      "Turning to bearing n of 96", and nothing is sent before the release;
//   3. a tap on the hub probes: one more clue, one more unit spent;
//   4. a two-finger move turns the orbit (the scene draws it) but never changes the digest; `resetView()` and a double
//      tap on empty space return to the authored orbit;
//   5. `cancelPointers()` mid-swipe sends nothing;
//   6. once the play is won, a swipe shows no preview and sends nothing, and a hub tap sends nothing.
// Synthetic timestamps; no sleep, no wall-clock assertion; each test well under 10 s. Explicit types and plain loops
// (CI type-check rule).
#if os(iOS)
import CoreGraphics
import Foundation
import HueCompassCore
import Testing
@testable import HueCompassExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreScenes

/// Scripted touches on Hue Compass, placed through the drawn camera.
@MainActor
enum HueCompassGestureScript {
    typealias Shell = ExperienceShell<HueCompassPresenter>

    /// The view's size in points (aspect 1.5, the frame-check aspect).
    static let viewWidth: Double = 720
    static let viewHeight: Double = 480
    /// The view size handed with every event.
    static var viewSize: Vec2 { Vec2(viewWidth, viewHeight) }
    /// The view size as the Core's `SIMD2` size.
    static var size: SIMD2<Double> { SIMD2<Double>(viewWidth, viewHeight) }
    /// The time between scripted events in seconds (synthetic).
    static let frame: Double = 1.0 / 60
    /// The radius of a scripted swipe about the projected centre, points (well outside the 20-point dead zone).
    static let swipeRadius: Double = 120
    /// The angle of a swipe's first point about the centre, radians (to the right of the centre).
    static let swipeStart: Double = 0

    /// Opens level `seed % 100 + 1` at the scripted view size (one frame drawn).
    static func open(_ session: ExperienceSession, seed: UInt64 = 0) async throws -> Shell {
        try await HueCompassTest.open(session, seed: seed, size: CGSize(width: viewWidth, height: viewHeight))
    }

    /// The play of `shell`'s core.
    static func play(_ shell: Shell) throws -> HueCompassPlay {
        try HueCompassTest.core(shell).play
    }

    /// The snapshot the presenter drew last (the gestures read it).
    static func drawn(_ shell: Shell) throws -> HueCompassSceneSnapshot {
        try #require(shell.presenter.lastSnapshot)
    }

    /// The projected compass centre through the camera the gestures use now.
    static func centre(_ shell: Shell) throws -> SIMD2<Double> {
        let camera: HueCompassCamera = try #require(shell.presenter.gestures.camera(viewSize: viewSize))
        return try #require(HueCompassDial.centre(camera: camera, size: size))
    }

    /// Sends one pointer event through the shell's pointer entry.
    static func touch(_ shell: Shell, id: Int, _ phase: PointerPhase, at location: Vec2, time: inout Double) {
        shell.handlePointer(PointerEvent(id: id, phase: phase, location: location, timestamp: time), viewSize: viewSize)
        time += frame
    }

    /// Whether `location` lies inside the view.
    static func inside(_ location: Vec2) -> Bool {
        location.x >= 0 && location.x <= viewWidth && location.y >= 0 && location.y <= viewHeight
    }

    /// The points of a swipe of `steps` bearings about `centre`: the arc from ``swipeStart`` through
    /// steps × 2π / 96 (counter-clockwise on screen for positive steps; screen y down), in pieces of at most 1/16 turn.
    static func arc(steps: Int, centre: SIMD2<Double>) -> [Vec2] {
        let sweep: Double = Double(steps) * 2 * Double.pi / Double(HueCompassWheel.bearings)
        let pieces: Int = Swift.max(4, Swift.abs(steps) / 6 + 1)
        var points: [Vec2] = []
        for i in 0...pieces {
            let a: Double = swipeStart + sweep * Double(i) / Double(pieces)
            points.append(Vec2(centre.x + swipeRadius * cos(a), centre.y - swipeRadius * sin(a)))
        }
        return points
    }

    /// Puts finger `id` down at the arc's first point and moves it along the rest (not released); returns the arc.
    @discardableResult
    static func swipeWithoutRelease(_ shell: Shell, id: Int = 1, steps: Int, time: inout Double) throws -> [Vec2] {
        let c: SIMD2<Double> = try centre(shell)
        let points: [Vec2] = arc(steps: steps, centre: c)
        for point in points { #expect(inside(point), "swipe point \(point) inside the view") }
        touch(shell, id: id, .began, at: points[0], time: &time)
        for index in 1..<points.count {
            touch(shell, id: id, .moved, at: points[index], time: &time)
        }
        return points
    }

    /// A whole one-finger swipe of `steps` bearings, released at its last point.
    static func swipe(_ shell: Shell, id: Int = 1, steps: Int, time: inout Double) throws {
        let points: [Vec2] = try swipeWithoutRelease(shell, id: id, steps: steps, time: &time)
        touch(shell, id: id, .ended, at: points[points.count - 1], time: &time)
    }

    /// A tap on the projected compass centre (inside the hub).
    static func tapHub(_ shell: Shell, id: Int = 1, time: inout Double) throws {
        let c: SIMD2<Double> = try centre(shell)
        let location: Vec2 = Vec2(c.x, c.y)
        touch(shell, id: id, .began, at: location, time: &time)
        touch(shell, id: id, .ended, at: location, time: &time)
    }

    /// The bearing `steps` away from `bearing`, 0 … 95.
    static func turned(_ bearing: Int, by steps: Int) -> Int {
        let bearings: Int = HueCompassWheel.bearings
        let raw: Int = (bearing + steps) % bearings
        return raw < 0 ? raw + bearings : raw
    }
}

@MainActor
@Suite(.serialized) struct HueCompassGestureWiringTests {
    typealias Script = HueCompassGestureScript

    /// A swipe of k bearings sends exactly the adapter's turn of k: the play matches and the digest changes.
    @Test func aSwipeTurnsTheNeedleByTheScriptedSteps() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Script.open(session)
        #expect(shell.state == .active)
        var time: Double = 0
        let turns: [Int] = [7, -13, 30]
        for k in turns {
            let before: HueCompassExperienceCore = try HueCompassTest.core(shell)
            #expect(before.play.stage == .playing)
            let digest: String = try HueCompassTest.digest(shell)

            try Script.swipe(shell, steps: k, time: &time)
            let after: HueCompassPlay = try Script.play(shell)
            var expected: HueCompassExperienceCore = before
            let turn: ExperienceAction = ExperienceAction(control: "compass.turn", values: [Double(k)], step: 0)
            let accepted: ActionResult = expected.apply(turn)
            #expect(accepted == .accepted)
            #expect(after.bearing == Script.turned(before.play.bearing, by: k), "turned by \(k)")
            #expect(after.fingerprint == expected.play.fingerprint, "the swipe is the adapter's turn of \(k)")
            #expect(after.spent == before.play.spent, "a turn spends nothing")
            #expect(try HueCompassTest.digest(shell) != digest, "the turn changes the digest")
            #expect(shell.presenter.gestures.state == .idle)
            #expect(shell.presenter.gestures.previewBearing == nil)
            #expect(shell.presenter.mirror.message == nil)
            try HueCompassTest.draw(session)
            #expect(try Script.drawn(shell).bearing == after.bearing)
        }
    }

    /// Mid-swipe the preview is the start bearing plus k: the ghost is drawn there, the description says so, and
    /// nothing is sent before the release.
    @Test func midSwipeThePreviewIsDrawnAndDescribed() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Script.open(session)
        var time: Double = 0
        let k: Int = 11
        let start: Int = try Script.play(shell).bearing
        let digest: String = try HueCompassTest.digest(shell)
        let want: Int = Script.turned(start, by: k)

        let points: [Vec2] = try Script.swipeWithoutRelease(shell, steps: k, time: &time)
        #expect(shell.presenter.gestures.state == .swiping)
        #expect(shell.presenter.gestures.previewBearing == want)
        #expect(try HueCompassTest.digest(shell) == digest, "nothing is sent before the release")
        let text: String = shell.presenter.describe(try HueCompassTest.core(shell))
        #expect(text.contains("Turning to bearing \(want) of 96"), "\(text)")
        try HueCompassTest.draw(session)
        #expect(shell.presenter.scene.previewBearing == want, "the scene draws the ghost at the preview")
        #expect(try Script.drawn(shell).bearing == start, "the real needle stays")

        Script.touch(shell, id: 1, .ended, at: points[points.count - 1], time: &time)
        #expect(try Script.play(shell).bearing == want)
        let after: String = shell.presenter.describe(try HueCompassTest.core(shell))
        #expect(!after.contains("Turning to bearing"), "\(after)")
        try HueCompassTest.draw(session)
        #expect(shell.presenter.scene.previewBearing == nil, "no ghost without a swipe")
    }

    /// A tap on the hub probes: one more clue and one more unit spent.
    @Test func aHubTapProbes() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Script.open(session)
        var time: Double = 0
        let before: HueCompassPlay = try Script.play(shell)
        #expect(before.remaining >= 2)
        let digest: String = try HueCompassTest.digest(shell)

        try Script.tapHub(shell, time: &time)
        let after: HueCompassPlay = try Script.play(shell)
        #expect(after.clues.count == before.clues.count + 1, "one probe")
        #expect(after.spent == before.spent + 1)
        #expect(after.clues.last?.bearing == before.bearing, "the clue is at the needle's bearing")
        #expect(after.bearing == before.bearing, "a tap does not turn")
        #expect(try HueCompassTest.digest(shell) != digest)
        #expect(shell.presenter.gestures.state == .idle)
        #expect(shell.presenter.mirror.message == nil)
    }

    /// A two-finger move turns the orbit (and the drawn scene) but never the digest; `resetView()` and a double tap
    /// on empty space return to the authored orbit.
    @Test func twoFingerOrbitResetViewAndDoubleTap() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Script.open(session)
        var time: Double = 0
        let digest: String = try HueCompassTest.digest(shell)
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
        let orbit: HueCompassOrbit = shell.presenter.gestures.orbit
        // The midpoint moves right by shift / 2 after the first finger's move and by shift after the second.
        let wantYaw: Double = shift / Script.viewWidth * HueCompassGestureController.yawPerViewWidth
        #expect(Swift.abs(orbit.yaw - wantYaw) < 1e-9, "yaw \(orbit.yaw)")
        #expect(Swift.abs(orbit.tilt - HueCompassOrbit.authored.tilt) < 1e-9, "tilt \(orbit.tilt)")
        #expect(orbit != .authored)
        #expect(try HueCompassTest.digest(shell) == digest, "an orbit never changes the digest")
        #expect(shell.presenter.gestures.state == .idle)
        try HueCompassTest.draw(session)
        #expect(shell.presenter.scene.orbit == orbit, "the scene draws the controller's orbit")
        #expect(try HueCompassTest.digest(shell) == digest)

        shell.presenter.resetView()
        #expect(shell.presenter.gestures.orbit == .authored, "Reset view restores the authored orbit")
        try HueCompassTest.draw(session)
        #expect(shell.presenter.scene.orbit == .authored)

        orbitRight()
        #expect(shell.presenter.gestures.orbit != .authored)
        try HueCompassTest.draw(session)
        Script.touch(shell, id: 3, .began, at: first, time: &time)
        Script.touch(shell, id: 3, .ended, at: first, time: &time)
        #expect(shell.presenter.gestures.orbit != .authored, "one tap does not reset")
        Script.touch(shell, id: 4, .began, at: first, time: &time)
        Script.touch(shell, id: 4, .ended, at: first, time: &time)
        #expect(shell.presenter.gestures.orbit == .authored, "a double tap on empty space resets the view")
        #expect(try HueCompassTest.digest(shell) == digest)
        try HueCompassTest.draw(session)
        #expect(shell.presenter.scene.orbit == .authored)
    }

    /// `cancelPointers()` mid-swipe drops the swipe: the release sends no turn.
    @Test func cancelPointersMidSwipeSendsNothing() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Script.open(session)
        var time: Double = 0
        let before: HueCompassPlay = try Script.play(shell)
        let digest: String = try HueCompassTest.digest(shell)

        let points: [Vec2] = try Script.swipeWithoutRelease(shell, steps: 9, time: &time)
        #expect(shell.presenter.gestures.previewBearing != nil, "the swipe previews before the cancel")
        shell.presenter.cancelPointers()
        #expect(shell.presenter.gestures.previewBearing == nil)
        Script.touch(shell, id: 1, .ended, at: points[points.count - 1], time: &time)
        #expect(shell.presenter.gestures.state == .idle)
        #expect(try Script.play(shell).fingerprint == before.fingerprint, "a cancelled swipe sends no turn")
        #expect(try HueCompassTest.digest(shell) == digest)
        #expect(shell.presenter.mirror.message == nil)
    }

    /// Once the play is won, a swipe shows no preview and sends nothing, and a hub tap sends nothing.
    @Test func nothingHappensWhileThePlayIsWon() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Script.open(session)
        var time: Double = 0
        let level: HueCompassLevel = try Script.play(shell).level
        #expect(shell.handle(control: "compass.select",
                             values: [Double(level.target), Double(level.targetBand)]) == .accepted)
        #expect(try Script.play(shell).stage == .won)
        try HueCompassTest.draw(session)
        #expect(try Script.drawn(shell).stage == .won)
        let won: HueCompassPlay = try Script.play(shell)
        let digest: String = try HueCompassTest.digest(shell)

        let points: [Vec2] = try Script.swipeWithoutRelease(shell, steps: 12, time: &time)
        #expect(shell.presenter.gestures.previewBearing == nil, "no preview while won")
        let text: String = shell.presenter.describe(try HueCompassTest.core(shell))
        #expect(!text.contains("Turning to bearing"), "\(text)")
        Script.touch(shell, id: 1, .ended, at: points[points.count - 1], time: &time)
        try Script.tapHub(shell, id: 2, time: &time)
        let after: HueCompassPlay = try Script.play(shell)
        #expect(after.fingerprint == won.fingerprint, "a won play does not change")
        #expect(after.clues.count == won.clues.count, "no probe while won")
        #expect(try HueCompassTest.digest(shell) == digest)
        #expect(shell.presenter.mirror.message == nil, "nothing was sent, so nothing was refused")
        #expect(shell.presenter.gestures.state == .idle)
        try HueCompassTest.draw(session)
        #expect(shell.presenter.scene.previewBearing == nil)
    }
}
#endif
