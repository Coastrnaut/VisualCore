// AuroraLoomGestureWiringTests — feature 304 (R02-G01-04) T-R02G0104-005 (FR-R02G0104-002 … 005; SC-R02G0104-004;
// clarifications Q2–Q5; edge cases). On the simulator, through the one app's session host: scripted touches enter
// through the shell's pointer entry (`ExperienceShell.handlePointer`, which hands them to the presenter's
// `pointer(_:viewSize:port:)` with the shell's own port while the experience is active) at a 360 × 240-point view,
// placed at the projections of the anchors and dial knobs through the drawn camera
// (`AuroraLoomSceneGeometry.project(_:aspect:orbit:width:height:)` at the view's point size and the controller's orbit).
// An anchor drag moves the kernel's wave by exactly the named step and spends one move; a drag back to the start, a
// second finger mid-drag, a cancelled touch and a suspension mid-drag send nothing; a quarter turn of a dial moves the
// phase by 4 (mod 16); gestures while paused (scene inactive) or after the level is won or failed send nothing; a move
// the kernel refuses (the allowance spent while the presenter still drew a playing frame) shows its text and leaves the
// state unchanged; the selection follows the picked handle, is named by the description and is drawn as a lit-gold
// outline; undo after a gesture restores the exact earlier digest (redo the later one); the frame checks of R02-G01-03
// hold at the four orbit limits (computed through the orbited camera), orbiting never changes the digest and Reset view
// returns the authored pose. Synthetic timestamps; no sleep, no wall-clock assertion; each test well under 10 s.
// Test data uses explicit types and plain loops (CI type-check rule).
#if os(iOS)
import CoreGraphics
import Foundation
import Testing
import AuroraLoomCore
@testable import AuroraLoomExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreRendering
import VisualCoreScenes

/// Scripted touches for Aurora Loom's canvas and the orbit-aware frame checks.
@MainActor
enum AuroraLoomGestureScript {
    typealias Shell = ExperienceShell<AuroraLoomPresenter>

    /// The view's size in points (aspect 1.5).
    static let viewWidth = 360, viewHeight = 240
    /// The view size handed with every event.
    static var viewSize: Vec2 { Vec2(Double(viewWidth), Double(viewHeight)) }
    /// The time between scripted events in seconds (synthetic).
    static let frame = 1.0 / 60

    /// Opens level 1 (seed 0) at the scripted view size.
    static func open(_ session: ExperienceSession, seed: UInt64 = 0) async throws -> Shell {
        try await AuroraLoomTest.open(session, seed: seed,
                                      size: CGSize(width: Double(viewWidth), height: Double(viewHeight)))
    }

    /// The point (view points, origin top left) of `world` through the drawn camera at `orbit`.
    static func screen(_ world: Vec3, orbit: AuroraLoomOrbit) throws -> Vec2 {
        let aspect: Double = Double(viewWidth) / Double(viewHeight)
        let p = try #require(AuroraLoomSceneGeometry.project(world, aspect: aspect, orbit: orbit, width: viewWidth,
                                                             height: viewHeight))
        return Vec2(p.x, p.y)
    }

    /// The world position of `ribbon`'s `control` handle at `step`.
    static func handle(_ control: AuroraLoomControl, ribbon: Int, step: Int) -> Vec3 {
        control == .wave ? AuroraLoomHandles.anchorPosition(ribbon: ribbon, wave: step)
            : AuroraLoomHandles.dialKnob(ribbon: ribbon, phase: step)
    }

    /// Sends one pointer event through the shell's pointer entry.
    static func touch(_ shell: Shell, id: Int, _ phase: PointerPhase, at location: Vec2, time: inout Double) {
        shell.handlePointer(PointerEvent(id: id, phase: phase, location: location, timestamp: time), viewSize: viewSize)
        time += frame
    }

    /// Puts finger `id` down on `ribbon`'s `control` handle at `step`.
    static func begin(_ shell: Shell, id: Int = 1, _ control: AuroraLoomControl, ribbon: Int, step: Int,
                      time: inout Double) throws {
        let at: Vec2 = try screen(handle(control, ribbon: ribbon, step: step), orbit: shell.presenter.gestures.orbit)
        touch(shell, id: id, .began, at: at, time: &time)
    }

    /// Moves finger `id` to where `ribbon`'s `control` handle is at `step`.
    static func move(_ shell: Shell, id: Int = 1, _ control: AuroraLoomControl, ribbon: Int, step: Int,
                     time: inout Double) throws {
        let at: Vec2 = try screen(handle(control, ribbon: ribbon, step: step), orbit: shell.presenter.gestures.orbit)
        touch(shell, id: id, .moved, at: at, time: &time)
    }

    /// Ends (or cancels) finger `id` where `ribbon`'s `control` handle is at `step`.
    static func end(_ shell: Shell, id: Int = 1, _ control: AuroraLoomControl, ribbon: Int, step: Int,
                    phase: PointerPhase = .ended, time: inout Double) throws {
        let at: Vec2 = try screen(handle(control, ribbon: ribbon, step: step), orbit: shell.presenter.gestures.orbit)
        touch(shell, id: id, phase, at: at, time: &time)
    }

    /// A whole one-finger drag of `ribbon`'s `control` handle through `steps` (the first is where it goes down, each
    /// later one a `.moved`), released at the last.
    static func drag(_ shell: Shell, _ control: AuroraLoomControl, ribbon: Int, through steps: [Int],
                     time: inout Double) throws {
        guard let first = steps.first, let last = steps.last else { return }
        try begin(shell, control, ribbon: ribbon, step: first, time: &time)
        for index in 1..<max(steps.count, 1) {
            try move(shell, control, ribbon: ribbon, step: steps[index], time: &time)
        }
        try end(shell, control, ribbon: ribbon, step: last, time: &time)
    }

    /// The wave steps from `start` to `target` one at a time, both included.
    static func path(from start: Int, to target: Int) -> [Int] {
        var result: [Int] = [start]
        var current: Int = start
        while current != target {
            current += target > current ? 1 : -1
            result.append(current)
        }
        return result
    }

    /// A wave step six steps away from `wave` within 0 … 15.
    static func farWave(_ wave: Int) -> Int {
        wave < 8 ? wave + 6 : wave - 6
    }

    /// The current core of `shell`.
    static func core(_ shell: Shell) throws -> AuroraLoomExperienceCore {
        try #require(shell.engine.core)
    }

    /// Sends `move` as the `ribbon.move` action through the shell, as a stepper does.
    @discardableResult
    static func send(_ shell: Shell, _ move: AuroraLoomMove) -> ActionResult {
        let control: Double = move.control == .wave ? 0 : 1
        return shell.handle(control: "ribbon.move", values: [Double(move.ribbon), control, Double(move.step)])
    }

    // MARK: Orbit-aware frame checks (R02-G01-03, clarification Q3, through the orbited camera)

    /// The drawn camera's view-projection at `width` × `height` and `orbit`.
    static func viewProjection(width: Int, height: Int, orbit: AuroraLoomOrbit) -> Mat4 {
        let camera: (view: Mat4, projection: Mat4) =
            AuroraLoomSceneGeometry.camera(aspect: Double(width) / Double(height), orbit: orbit)
        return camera.projection * camera.view
    }

    /// The pixel of `world` through `viewProjection` in a `width` × `height` picture, or nil behind the camera.
    static func pixel(_ world: Vec3, _ viewProjection: Mat4, width: Int, height: Int) -> (x: Double, y: Double)? {
        guard let p = ScreenProjection.project(world, viewProjection: viewProjection,
                                               viewport: Vec2(Double(width), Double(height))) else { return nil }
        return (p.point.x, p.point.y)
    }

    /// The three frame checks of clarification Q3 at `orbit`: every ribbon centre-line sample (32 segments) within 2 px
    /// of a lit pixel, every gate marker (not covered by a later marker of the other lit state) within 0.12 of its gold,
    /// and every corner pixel 6 px clear of the scene within 0.05 of night.
    static func checkFrame(_ rgba: [UInt8], snapshot: AuroraLoomSceneSnapshot, orbit: AuroraLoomOrbit, _ what: String,
                           sourceLocation: SourceLocation = #_sourceLocation) {
        let width: Int = AuroraLoomTest.width
        let height: Int = AuroraLoomTest.height
        #expect(rgba.count == width * height * 4, "\(what): picture size", sourceLocation: sourceLocation)
        guard rgba.count == width * height * 4 else { return }
        let vp: Mat4 = viewProjection(width: width, height: height, orbit: orbit)
        var scene: [(x: Double, y: Double)] = []
        // Ribbons.
        let threshold: Double = AuroraLoomTest.nightLuminance + AuroraLoomTest.litMargin
        var samples = 0
        var ribbonMisses: [String] = []
        for ribbon in 0..<AuroraLoomSceneGeometry.ribbonCount {
            let line: [Vec3] = AuroraLoomSceneGeometry.centreLine(ribbon: ribbon, snapshot: snapshot, segments: 32)
            for (index, world) in line.enumerated() {
                guard let p = pixel(world, vp, width: width, height: height) else {
                    ribbonMisses.append("ribbon \(ribbon) sample \(index) behind the camera")
                    continue
                }
                samples += 1
                let found: Bool = AuroraLoomTest.anyPixel(rgba, near: p.x, p.y, radius: AuroraLoomTest.sampleRadius,
                                                          width: width, height: height) { c in
                    AuroraLoomTest.luminance(c) >= threshold
                }
                if !found {
                    ribbonMisses.append(String(format: "ribbon %ld sample %ld at (%.1f, %.1f)", ribbon, index, p.x, p.y))
                }
            }
            for world in AuroraLoomSceneGeometry.centreLine(ribbon: ribbon, snapshot: snapshot, segments: 128) {
                if let p = pixel(world, vp, width: width, height: height) { scene.append(p) }
            }
        }
        #expect(samples == 3 * 33, "\(what): ribbon samples \(samples)", sourceLocation: sourceLocation)
        #expect(ribbonMisses.isEmpty, "\(what): \(ribbonMisses.count) ribbon misses: \(ribbonMisses.prefix(6))",
                sourceLocation: sourceLocation)
        // Markers.
        var centres: [(x: Double, y: Double)?] = []
        var lits: [Bool] = []
        for gate in 0..<4 {
            centres.append(pixel(AuroraLoomSceneGeometry.marker(gate: gate, snapshot: snapshot), vp, width: width,
                                 height: height))
            lits.append(AuroraLoomTest.gateLit(snapshot, gate: gate))
            for world in AuroraLoomSceneGeometry.gateRing(gate: gate, snapshot: snapshot) {
                if let p = pixel(world, vp, width: width, height: height) { scene.append(p) }
            }
        }
        var checked = 0
        var markerMisses: [String] = []
        for gate in 0..<4 {
            guard let c = centres[gate] else {
                markerMisses.append("gate \(gate): no projection")
                continue
            }
            scene.append(c)
            var covered = false
            for later in (gate + 1)..<4 {
                guard let d = centres[later], lits[later] != lits[gate] else { continue }
                let dx: Double = d.x - c.x
                let dy: Double = d.y - c.y
                if dx * dx + dy * dy < 9 { covered = true }
            }
            if covered { continue }
            let x = Int(c.x.rounded(.down)), y = Int(c.y.rounded(.down))
            guard x >= 0, x < width, y >= 0, y < height else {
                markerMisses.append("gate \(gate): outside at (\(x), \(y))")
                continue
            }
            checked += 1
            let want: SIMD3<Double> = AuroraLoomShaders.gateColour(AuroraLoomPalette.gold, lit: lits[gate])
            let got: SIMD3<Double> = AuroraLoomTest.colour(rgba, x: x, y: y, width: width)
            if AuroraLoomTest.channelDistance(got, want) > AuroraLoomTest.markerTolerance {
                markerMisses.append(String(format: "gate %ld at (%ld, %ld): got (%.3f, %.3f, %.3f) want (%.3f, %.3f, %.3f)",
                                           gate, x, y, got.x, got.y, got.z, want.x, want.y, want.z))
            }
        }
        #expect(checked >= 1, "\(what): no marker checked", sourceLocation: sourceLocation)
        #expect(markerMisses.isEmpty, "\(what): \(markerMisses)", sourceLocation: sourceLocation)
        // Background: the corner pixels 2 px in, where 6 px clear of every scene point.
        let corners: [(x: Int, y: Int)] = [(2, 2), (width - 3, 2), (2, height - 3), (width - 3, height - 3)]
        var backgroundMisses: [String] = []
        for corner in corners {
            let cx: Double = Double(corner.x) + 0.5
            let cy: Double = Double(corner.y) + 0.5
            var nearest: Double = .infinity
            for p in scene {
                let dx: Double = p.x - cx
                let dy: Double = p.y - cy
                nearest = Swift.min(nearest, (dx * dx + dy * dy).squareRoot())
            }
            guard nearest >= AuroraLoomTest.backgroundClearance else { continue }
            let got: SIMD3<Double> = AuroraLoomTest.colour(rgba, x: corner.x, y: corner.y, width: width)
            if AuroraLoomTest.channelDistance(got, AuroraLoomPalette.night) > AuroraLoomTest.backgroundTolerance {
                backgroundMisses.append(String(format: "background (%ld, %ld): (%.3f, %.3f, %.3f)", corner.x, corner.y,
                                               got.x, got.y, got.z))
            }
        }
        #expect(backgroundMisses.isEmpty, "\(what): \(backgroundMisses)", sourceLocation: sourceLocation)
    }

    // MARK: Selection outline

    /// The number of pixels within `radius` of `world`'s pixel (authored camera at `width` × `height`) that are within
    /// 0.15 per channel of lit gold, and the radius used (the outline disc's projected radius plus 1 px).
    static func litGoldPixels(_ rgba: [UInt8], around world: Vec3, width: Int, height: Int) -> (count: Int, radius: Double) {
        let camera: (view: Mat4, projection: Mat4) =
            AuroraLoomSceneGeometry.camera(aspect: Double(width) / Double(height), orbit: .authored)
        let vp: Mat4 = camera.projection * camera.view
        let view: Mat4 = camera.view
        let right: Vec3 = Vec3(view.c0.x, view.c1.x, view.c2.x).normalized
        guard let centre = pixel(world, vp, width: width, height: height),
              let rim = pixel(world + right * AuroraLoomRibbonScene.outlineRadius, vp, width: width,
                              height: height) else { return (0, 0) }
        let rx: Double = rim.x - centre.x
        let ry: Double = rim.y - centre.y
        let radius: Double = (rx * rx + ry * ry).squareRoot() + 1
        let gold: SIMD3<Double> = AuroraLoomShaders.gateColour(AuroraLoomPalette.gold, lit: true)
        let reach: Int = Int(radius.rounded(.up)) + 1
        let cx: Int = Int(centre.x.rounded(.down))
        let cy: Int = Int(centre.y.rounded(.down))
        var count = 0
        for y in (cy - reach)...(cy + reach) {
            guard y >= 0, y < height else { continue }
            for x in (cx - reach)...(cx + reach) {
                guard x >= 0, x < width else { continue }
                let dx: Double = Double(x) + 0.5 - centre.x
                let dy: Double = Double(y) + 0.5 - centre.y
                guard dx * dx + dy * dy <= radius * radius else { continue }
                let c: SIMD3<Double> = AuroraLoomTest.colour(rgba, x: x, y: y, width: width)
                if AuroraLoomTest.channelDistance(c, gold) <= 0.15 { count += 1 }
            }
        }
        return (count, radius)
    }
}

@MainActor
@Suite(.serialized) struct AuroraLoomGestureWiringTests {
    typealias Script = AuroraLoomGestureScript

    /// An anchor drag sends exactly one move to the target wave; a drag back to the start sends nothing.
    @Test func anchorDragMovesTheWaveByTheNamedStep() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Script.open(session)
        #expect(shell.state == .active)
        var time = 0.0
        let ribbon = 0
        let before: AuroraLoomExperienceCore = try Script.core(shell)
        let start: Int = before.play.steps.wave[ribbon]
        let target: Int = Script.farWave(start)
        let opening: String = try AuroraLoomTest.digest(shell)

        // Out to the target and back to the start: nothing is sent.
        var outAndBack: [Int] = Script.path(from: start, to: target)
        outAndBack.append(contentsOf: Script.path(from: target, to: start).dropFirst())
        try Script.drag(shell, .wave, ribbon: ribbon, through: outAndBack, time: &time)
        #expect(try AuroraLoomTest.digest(shell) == opening, "a drag back to the start sends nothing")
        #expect(shell.presenter.mirror.message == nil)
        #expect(shell.presenter.gestures.phase == .idle)

        // To the target: the preview names it while dragging, the release sends one move.
        let steps: [Int] = Script.path(from: start, to: target)
        try Script.begin(shell, .wave, ribbon: ribbon, step: start, time: &time)
        #expect(shell.presenter.gestures.selectedRibbon == ribbon)
        for index in 1..<steps.count {
            try Script.move(shell, .wave, ribbon: ribbon, step: steps[index], time: &time)
        }
        let preview = AuroraLoomMove(ribbon: ribbon, control: .wave, step: target)
        #expect(shell.presenter.mirror.preview == preview)
        let dragging: AuroraLoomExperienceCore = try Script.core(shell)
        #expect(shell.presenter.describe(dragging).contains("Dragging ribbon 1 wave to \(target)"))
        #expect(try AuroraLoomTest.digest(shell) == opening, "nothing is sent before the release")
        try Script.end(shell, .wave, ribbon: ribbon, step: target, time: &time)
        let after: AuroraLoomExperienceCore = try Script.core(shell)
        #expect(after.play.steps.wave[ribbon] == target)
        #expect(after.play.spent == before.play.spent + 1)
        #expect(after.play.steps.phase == before.play.steps.phase)
        #expect(shell.presenter.mirror.message == nil)
        #expect(shell.presenter.mirror.preview == nil)

        // The kernel state equals applying the named move to the opening play.
        var expected: AuroraLoomPlay = before.play
        try expected.apply(preview, expecting: expected.fingerprint)
        #expect(after.play.fingerprint == expected.fingerprint)
    }

    /// A quarter turn of a dial (the knob through four intermediate phases) moves the phase by 4 modulo 16.
    @Test func quarterTurnOfADialMovesThePhaseByFour() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Script.open(session)
        var time = 0.0
        let ribbon = 1
        let before: AuroraLoomExperienceCore = try Script.core(shell)
        let start: Int = before.play.steps.phase[ribbon]
        var phases: [Int] = []
        for k in 0...4 { phases.append((start + k) % 16) }
        let target: Int = (start + 4) % 16
        try Script.begin(shell, .phase, ribbon: ribbon, step: start, time: &time)
        #expect(shell.presenter.gestures.selectedRibbon == ribbon)
        for index in 1..<phases.count {
            try Script.move(shell, .phase, ribbon: ribbon, step: phases[index], time: &time)
        }
        #expect(shell.presenter.mirror.preview == AuroraLoomMove(ribbon: ribbon, control: .phase, step: target))
        try Script.end(shell, .phase, ribbon: ribbon, step: target, time: &time)
        let after: AuroraLoomExperienceCore = try Script.core(shell)
        #expect(after.play.steps.phase[ribbon] == target)
        #expect(after.play.steps.wave == before.play.steps.wave)
        #expect(after.play.spent == before.play.spent + 1)
    }

    /// A second finger mid-drag, a cancelled touch and a suspension mid-drag send nothing; a plain drag still works.
    @Test func secondFingerAndCancelSendNothing() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Script.open(session)
        var time = 0.0
        let ribbon = 0
        let start: Int = try Script.core(shell).play.steps.wave[ribbon]
        let target: Int = Script.farWave(start)
        let opening: String = try AuroraLoomTest.digest(shell)

        // A second finger mid-drag starts an orbit and drops the drag.
        try Script.begin(shell, id: 1, .wave, ribbon: ribbon, step: start, time: &time)
        try Script.move(shell, id: 1, .wave, ribbon: ribbon, step: target, time: &time)
        #expect(shell.presenter.mirror.preview != nil)
        Script.touch(shell, id: 2, .began, at: Vec2(30, 30), time: &time)
        #expect(shell.presenter.gestures.phase == .orbiting)
        #expect(shell.presenter.mirror.preview == nil)
        try Script.end(shell, id: 1, .wave, ribbon: ribbon, step: target, time: &time)
        Script.touch(shell, id: 2, .ended, at: Vec2(30, 30), time: &time)
        #expect(shell.presenter.gestures.phase == .idle)
        #expect(try AuroraLoomTest.digest(shell) == opening, "second finger")

        // A cancelled touch ends the drag without a move.
        try Script.begin(shell, id: 3, .wave, ribbon: ribbon, step: start, time: &time)
        try Script.move(shell, id: 3, .wave, ribbon: ribbon, step: target, time: &time)
        try Script.end(shell, id: 3, .wave, ribbon: ribbon, step: target, phase: .cancelled, time: &time)
        #expect(shell.presenter.gestures.phase == .idle)
        #expect(try AuroraLoomTest.digest(shell) == opening, "cancelled touch")

        // The presenter's cancelPointers (the shell's suspension path) drops a drag; its later release sends nothing.
        try Script.begin(shell, id: 4, .wave, ribbon: ribbon, step: start, time: &time)
        try Script.move(shell, id: 4, .wave, ribbon: ribbon, step: target, time: &time)
        shell.presenter.cancelPointers()
        #expect(shell.presenter.mirror.preview == nil)
        try Script.end(shell, id: 4, .wave, ribbon: ribbon, step: target, time: &time)
        #expect(shell.presenter.gestures.phase == .idle)
        #expect(try AuroraLoomTest.digest(shell) == opening, "cancelPointers")
        #expect(shell.presenter.mirror.message == nil)

        // The same drag without interruption is sent.
        try Script.drag(shell, .wave, ribbon: ribbon, through: [start, target], time: &time)
        #expect(try Script.core(shell).play.steps.wave[ribbon] == target)
        #expect(try AuroraLoomTest.digest(shell) != opening)
    }

    /// While paused (scene inactive, the experience suspended) touches are dropped and a drag across the pause is
    /// cancelled; after resuming a drag is sent again.
    @Test func gesturesWhilePausedSendNothing() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Script.open(session)
        var time = 0.0
        let ribbon = 2
        let start: Int = try Script.core(shell).play.steps.wave[ribbon]
        let target: Int = Script.farWave(start)
        let opening: String = try AuroraLoomTest.digest(shell)

        // A drag that began before the pause ends after it without a move.
        try Script.begin(shell, id: 1, .wave, ribbon: ribbon, step: start, time: &time)
        try Script.move(shell, id: 1, .wave, ribbon: ribbon, step: target, time: &time)
        session.setScenePhase(.inactive)
        #expect(shell.state == .suspended)
        // A whole drag while paused is dropped.
        try Script.drag(shell, .wave, ribbon: ribbon, through: [start, target], time: &time)
        #expect(try AuroraLoomTest.digest(shell) == opening, "paused")
        session.setScenePhase(.active)
        #expect(shell.state == .active)
        try AuroraLoomTest.draw(session)
        try Script.end(shell, id: 1, .wave, ribbon: ribbon, step: target, time: &time)
        #expect(try AuroraLoomTest.digest(shell) == opening, "a drag across the pause")
        #expect(shell.presenter.mirror.message == nil)

        // Resumed: the drag is sent.
        try Script.drag(shell, .wave, ribbon: ribbon, through: [start, target], time: &time)
        #expect(try Script.core(shell).play.steps.wave[ribbon] == target)
    }

    /// After the level is won the handles do not respond.
    @Test func gesturesAfterAWinSendNothing() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Script.open(session)
        var time = 0.0
        let level: AuroraLoomLevel = try Script.core(shell).play.level
        let solution: AuroraLoomSolution = try #require(AuroraLoomSolver.solve(level))
        for move in solution.moves {
            let result: ActionResult = Script.send(shell, move)
            #expect(result == .accepted, "\(result.code)")
        }
        #expect(try Script.core(shell).play.stage == .won)
        try AuroraLoomTest.draw(session)
        let won: String = try AuroraLoomTest.digest(shell)
        let start: Int = try Script.core(shell).play.steps.wave[0]
        try Script.begin(shell, .wave, ribbon: 0, step: start, time: &time)
        #expect(shell.presenter.gestures.phase == .idle, "a handle does not respond after the win")
        try Script.move(shell, .wave, ribbon: 0, step: Script.farWave(start), time: &time)
        try Script.end(shell, .wave, ribbon: 0, step: Script.farWave(start), time: &time)
        #expect(try AuroraLoomTest.digest(shell) == won)
        #expect(shell.presenter.mirror.message == nil, "nothing was sent")
    }

    /// A move the kernel refuses (the allowance spent after the last frame the presenter drew) shows its text and leaves
    /// the state unchanged; once a failed frame is drawn the handles do not respond.
    @Test func aRefusedMoveShowsItsTextAndTheFailedLevelIgnoresGestures() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Script.open(session)
        var time = 0.0
        let opening: AuroraLoomPlay = try Script.core(shell).play
        let allowance: Int = opening.level.allowance
        try #require(allowance >= 2)
        // A wave step for ribbon 0 that, alternated with the start step, spends the allowance without a win.
        let start: Int = opening.steps.wave[0]
        var other: Int?
        for candidate in 0..<16 where candidate != start {
            var trial: AuroraLoomPlay = opening
            var fine = true
            for index in 0..<allowance {
                let step: Int = index % 2 == 0 ? candidate : start
                do {
                    try trial.apply(AuroraLoomMove(ribbon: 0, control: .wave, step: step), expecting: trial.fingerprint)
                } catch {
                    fine = false
                    break
                }
                let last: Bool = index == allowance - 1
                if trial.stage != (last ? .failed : .playing) { fine = false; break }
            }
            if fine { other = candidate; break }
        }
        let losing: Int = try #require(other, "a losing alternation for ribbon 0")
        for index in 0..<(allowance - 1) {
            let step: Int = index % 2 == 0 ? losing : start
            #expect(Script.send(shell, AuroraLoomMove(ribbon: 0, control: .wave, step: step)) == .accepted)
        }
        try AuroraLoomTest.draw(session)   // the presenter last saw a playing frame
        let lastStep: Int = (allowance - 1) % 2 == 0 ? losing : start
        #expect(Script.send(shell, AuroraLoomMove(ribbon: 0, control: .wave, step: lastStep)) == .accepted)
        #expect(try Script.core(shell).play.stage == .failed)
        let failed: String = try AuroraLoomTest.digest(shell)

        // The presenter still believes the level is playing: the drag is sent, refused and shown.
        let wave1: Int = try Script.core(shell).play.steps.wave[1]
        try Script.drag(shell, .wave, ribbon: 1, through: [wave1, Script.farWave(wave1)], time: &time)
        let message: String = try #require(shell.presenter.mirror.message)
        #expect(message.hasPrefix("That move was refused: "), "\(message)")
        #expect(try AuroraLoomTest.digest(shell) == failed, "a refused move leaves the state unchanged")

        // Once the failed frame is drawn the handles do not respond.
        try AuroraLoomTest.draw(session)
        shell.presenter.mirror.message = nil
        try Script.begin(shell, .wave, ribbon: 1, step: wave1, time: &time)
        #expect(shell.presenter.gestures.phase == .idle)
        try Script.move(shell, .wave, ribbon: 1, step: Script.farWave(wave1), time: &time)
        try Script.end(shell, .wave, ribbon: 1, step: Script.farWave(wave1), time: &time)
        #expect(shell.presenter.mirror.message == nil, "nothing was sent")
        #expect(try AuroraLoomTest.digest(shell) == failed)
    }

    /// Picking ribbon 3's anchor selects it, the description names it, and its handles are drawn with the lit-gold
    /// outline (compared with the same frame while ribbon 1 is selected).
    @Test func selectionIsDescribedAndOutlined() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Script.open(session)
        var time = 0.0
        // At 288 × 192 (the frame-check aspect at three times its size) the outline rim is about 2 px wide.
        let width = 288, height = 192
        let steps: AuroraLoomSteps = try Script.core(shell).play.steps
        let anchor2: Vec3 = AuroraLoomHandles.anchorPosition(ribbon: 2, wave: steps.wave[2])
        let knob2: Vec3 = AuroraLoomHandles.dialKnob(ribbon: 2, phase: steps.phase[2])
        let anchor0: Vec3 = AuroraLoomHandles.anchorPosition(ribbon: 0, wave: steps.wave[0])
        #expect(shell.presenter.gestures.selectedRibbon == 0)
        let unselected: [UInt8] = try AuroraLoomTest.still(session, width: width, height: height)
        let anchor2Before = Script.litGoldPixels(unselected, around: anchor2, width: width, height: height)
        let knob2Before = Script.litGoldPixels(unselected, around: knob2, width: width, height: height)
        let anchor0Before = Script.litGoldPixels(unselected, around: anchor0, width: width, height: height)
        #expect(anchor0Before.count >= 1, "ribbon 1 starts selected and outlined")

        // A tap on ribbon 3's anchor (no movement) selects it and sends nothing.
        let opening: String = try AuroraLoomTest.digest(shell)
        try Script.begin(shell, .wave, ribbon: 2, step: steps.wave[2], time: &time)
        try Script.end(shell, .wave, ribbon: 2, step: steps.wave[2], time: &time)
        #expect(try AuroraLoomTest.digest(shell) == opening)
        #expect(shell.presenter.gestures.selectedRibbon == 2)
        #expect(shell.presenter.mirror.selectedRibbon == 2)
        let current: AuroraLoomExperienceCore = try Script.core(shell)
        let text: String = shell.presenter.describe(current)
        #expect(text.contains("Ribbon 3 selected: wave \(steps.wave[2]), phase \(steps.phase[2])."), "\(text)")

        let selected: [UInt8] = try AuroraLoomTest.still(session, width: width, height: height)
        let anchor2After = Script.litGoldPixels(selected, around: anchor2, width: width, height: height)
        let knob2After = Script.litGoldPixels(selected, around: knob2, width: width, height: height)
        let anchor0After = Script.litGoldPixels(selected, around: anchor0, width: width, height: height)
        #expect(anchor2After.count >= 1, "anchor outline (radius \(anchor2After.radius) px)")
        #expect(anchor2After.count > anchor2Before.count, "\(anchor2Before.count) → \(anchor2After.count)")
        #expect(knob2After.count > knob2Before.count, "knob \(knob2Before.count) → \(knob2After.count)")
        #expect(anchor0After.count < anchor0Before.count, "ribbon 1 loses its outline")

        // The stepper path selects too.
        shell.presenter.select(ribbon: 1)
        #expect(shell.presenter.gestures.selectedRibbon == 1)
        #expect(shell.presenter.describe(current).contains("Ribbon 2 selected"))
    }

    /// Undo after a gesture restores the exact earlier digest; redo restores the later one.
    @Test func undoAfterAGestureRestoresTheDigest() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Script.open(session)
        var time = 0.0
        let earlier: String = try AuroraLoomTest.digest(shell)
        let start: Int = try Script.core(shell).play.steps.wave[1]
        try Script.drag(shell, .wave, ribbon: 1, through: Script.path(from: start, to: Script.farWave(start)),
                        time: &time)
        let later: String = try AuroraLoomTest.digest(shell)
        #expect(later != earlier)
        #expect(shell.port.send("play.undo") == .accepted)
        #expect(try AuroraLoomTest.digest(shell) == earlier, "undo restores the earlier digest")
        #expect(try Script.core(shell).play.steps.wave[1] == start)
        #expect(shell.port.send("play.redo") == .accepted)
        #expect(try AuroraLoomTest.digest(shell) == later, "redo restores the later digest")

        // A dial gesture undoes the same way.
        try AuroraLoomTest.draw(session)
        let beforeDial: String = try AuroraLoomTest.digest(shell)
        let phase: Int = try Script.core(shell).play.steps.phase[0]
        try Script.drag(shell, .phase, ribbon: 0, through: [phase, (phase + 1) % 16, (phase + 2) % 16], time: &time)
        #expect(try Script.core(shell).play.steps.phase[0] == (phase + 2) % 16)
        #expect(shell.port.send("play.undo") == .accepted)
        #expect(try AuroraLoomTest.digest(shell) == beforeDial)
    }

    /// Two-finger pans to each orbit limit keep the frame checks at 96 × 64, never change the digest, and Reset view
    /// returns the authored pose; a handle is still picked through the orbited camera.
    @Test func orbitLimitsKeepTheFrameAndResetViewReturns() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Script.open(session)
        var time = 0.0
        let opening: String = try AuroraLoomTest.digest(shell)
        let payload: Data = try Script.core(shell).snapshotPayload()
        let az: ClosedRange<Double> = AuroraLoomOrbit.azimuthRange
        let el: ClosedRange<Double> = AuroraLoomOrbit.elevationRange
        let signs: [(x: Double, y: Double)] = [(1, 1), (-1, -1), (1, -1), (-1, 1)]
        let w: Double = Script.viewSize.x
        let h: Double = Script.viewSize.y
        for sign in signs {
            shell.presenter.resetView()
            #expect(shell.presenter.gestures.orbit == .authored)
            var a = Vec2(w * 0.3, h * 0.5)
            var b = Vec2(w * 0.7, h * 0.5)
            Script.touch(shell, id: 10, .began, at: a, time: &time)
            Script.touch(shell, id: 11, .began, at: b, time: &time)
            #expect(shell.presenter.gestures.phase == .orbiting)
            let delta = Vec2(sign.x * w * 2 / 8, sign.y * h * 2 / 8)
            for _ in 0..<8 {
                a = a + delta
                b = b + delta
                Script.touch(shell, id: 10, .moved, at: a, time: &time)
                Script.touch(shell, id: 11, .moved, at: b, time: &time)
            }
            Script.touch(shell, id: 10, .ended, at: a, time: &time)
            Script.touch(shell, id: 11, .ended, at: b, time: &time)
            let orbit: AuroraLoomOrbit = shell.presenter.gestures.orbit
            let wantAzimuth: Double = sign.x > 0 ? az.upperBound : az.lowerBound
            let wantElevation: Double = sign.y > 0 ? el.upperBound : el.lowerBound
            #expect(abs(orbit.azimuthOffset - wantAzimuth) < 1e-12, "azimuth \(orbit.azimuthOffset)")
            #expect(abs(orbit.elevation - wantElevation) < 1e-12, "elevation \(orbit.elevation)")
            #expect(try AuroraLoomTest.digest(shell) == opening, "orbiting changes no digest")

            let rgba: [UInt8] = try AuroraLoomTest.still(session)
            let snapshot: AuroraLoomSceneSnapshot = try #require(shell.presenter.lastSnapshot)
            #expect(shell.presenter.scene.orbit == orbit, "the scene draws the controller's orbit")
            Script.checkFrame(rgba, snapshot: snapshot, orbit: orbit, "orbit (\(sign.x), \(sign.y))")
        }
        #expect(try AuroraLoomTest.digest(shell) == opening)
        #expect(try Script.core(shell).snapshotPayload() == payload)

        // At the last limit a handle is still picked through the drawn camera.
        let limit: AuroraLoomOrbit = shell.presenter.gestures.orbit
        #expect(limit != .authored)
        let start: Int = try Script.core(shell).play.steps.wave[0]
        try Script.drag(shell, .wave, ribbon: 0, through: Script.path(from: start, to: Script.farWave(start)),
                        time: &time)
        #expect(try Script.core(shell).play.steps.wave[0] == Script.farWave(start))

        // Reset view returns the authored pose and the authored frame check holds.
        shell.presenter.resetView()
        #expect(shell.presenter.gestures.orbit == .authored)
        let rgba: [UInt8] = try AuroraLoomTest.still(session)
        let snapshot: AuroraLoomSceneSnapshot = try #require(shell.presenter.lastSnapshot)
        AuroraLoomTest.checkFrame(rgba, snapshot: snapshot, "after Reset view")
    }
}
#endif
