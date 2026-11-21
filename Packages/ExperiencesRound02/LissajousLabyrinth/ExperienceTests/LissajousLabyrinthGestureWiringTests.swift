// LissajousLabyrinthGestureWiringTests — feature 314 (R02-G02-04) T-R02G0204-006 (FR-R02G0204-001 … 006;
// SC-R02G0204-001 … 005). On the simulator, through the one app's session host: scripted touches enter through the
// shell's pointer entry (`ExperienceShell.handlePointer`, which hands them to the presenter's
// `pointer(_:viewSize:port:)` with the shell's own port while the experience is active) at a 720 × 480-point view (aspect
// 1.5; a dial ring is about 23 pt in radius there), placed at the projections of the dial knobs and ring points through
// the drawn camera (`LissajousLabyrinthSceneGeometry.project(_:aspect:snapshot:width:height:orbit:)` at the view's point
// size and the controller's orbit). A one-finger turn of a ring, knob through every intermediate value, changes that dial
// by exactly the named value with one `dial.set` (a frequency and a phase, checked against the kernel); a turn out and
// back, a second finger mid-turn, a cancelled touch and a touch on empty space send nothing; while paused (scene
// inactive), after a win and after the allowance is spent turns send nothing (orbit still works); a frequency turned to a
// value not coprime with the other frequency is refused, shown as "That change was refused: …", announced, and leaves the
// state unchanged; touching a ring selects its dial, the description says "Dial <Title> selected: <value>." and the
// drawn still shows lit copper (`LissajousLabyrinthShaders.solidColour(copper, lit: true)`, the outline's u_lit 1) on
// the selected dial's outline circle (0.6 ring radii, inside the ring) and not on the others'; undo after a gesture restores the digest,
// redo repeats it; two-finger moves reach each orbit limit without changing the digest, the scene draws that orbit,
// every checked path sample, ball and ring point projects inside the frame with a 5 % margin through the orbited camera,
// the outer 4 % band of the still is night, and Reset view returns the authored pose where the authored frame checks of
// `LissajousLabyrinthTest.checkFrame` hold. Pending play through the presenter: for all 100 certified levels (five bands
// of 20, as the Core pending tests) the solution's final dials are set with `stepPending` (the shorter way round, so
// both directions and the wrap are used), each announced as "<Title> <value> pending. Apply to change.", and one
// `applyPending` wins in exactly the certified shortest number of actions with no refusal; Clear drops the pending
// values; an outside change (undo, redo, level.next through the port) drops them; an Apply whose earlier actions already
// win stops, drops the rest and announces "The path is safe.".
// Adapted bound (documented): `LissajousLabyrinthTest.checkFrame` computes its reference through the authored camera
// only (and the thread strip faces the authored eye, so at an orbit limit parts of it are seen edge-on and may cover no
// pixel centre), so at the orbit limits the frame is checked by projection through the orbited camera plus the night
// border band and a changed picture; the full pixel check runs after Reset view.
// Announcements go to a feedback route with VoiceOver off (the presenter's own `announcements` log is read). Synthetic
// timestamps; no sleep, no wall-clock assertion; each test well under 10 s. Test data uses explicit types and plain
// loops (CI type-check rule).
#if os(iOS)
import CoreGraphics
import Foundation
import Testing
import LissajousLabyrinthCore
@testable import LissajousLabyrinthExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreRendering
import VisualCoreScenes

/// Scripted touches for Lissajous Labyrinth's dial rings and the orbit-aware checks.
@MainActor
enum LissajousLabyrinthGestureScript {
    typealias Shell = ExperienceShell<LissajousLabyrinthPresenter>
    typealias Geometry = LissajousLabyrinthSceneGeometry
    typealias Handles = LissajousLabyrinthHandles

    /// The view's size in points (aspect 1.5, the frame-check aspect).
    static let viewWidth = 720, viewHeight = 480
    /// The view size handed with every event.
    static var viewSize: Vec2 { Vec2(Double(viewWidth), Double(viewHeight)) }
    /// The time between scripted events in seconds (synthetic).
    static let frame = 1.0 / 60

    /// The dial titles, written out independently of the presenter.
    static func title(_ dial: LissajousLabyrinthDial) -> String {
        switch dial {
        case .frequencyA: "Frequency A"
        case .frequencyB: "Frequency B"
        case .phaseA: "Phase A"
        case .phaseC: "Phase C"
        }
    }

    /// Opens level `seed % 100 + 1` at the scripted view size with a feedback route that posts nothing (VoiceOver off;
    /// the presenter still logs every announcement).
    static func open(_ session: ExperienceSession, seed: UInt64 = 0) async throws -> Shell {
        let shell: Shell = try await LissajousLabyrinthTest.open(
            session, seed: seed, size: CGSize(width: Double(viewWidth), height: Double(viewHeight)))
        shell.presenter.feedback = ExperienceFeedback(voiceOverRunning: { false })
        return shell
    }

    /// The current core of `shell`.
    static func core(_ shell: Shell) throws -> LissajousLabyrinthExperienceCore {
        try #require(shell.engine.core)
    }

    /// The level the presenter drew last (the turn picks against it).
    static func drawnLevel(_ shell: Shell) throws -> LissajousLabyrinthLevel {
        try #require(shell.presenter.lastSnapshot).level
    }

    /// The point (view points, origin top left) of `world` through the drawn camera at the controller's orbit.
    static func screen(_ world: Vec3, _ shell: Shell) throws -> Vec2 {
        let snapshot: LissajousLabyrinthSceneSnapshot = try #require(shell.presenter.lastSnapshot)
        let aspect: Double = Double(viewWidth) / Double(viewHeight)
        let p: Vec2 = try #require(Geometry.project(world, aspect: aspect, snapshot: snapshot, width: viewWidth,
                                                    height: viewHeight, orbit: shell.presenter.gestures.orbit))
        return Vec2(p.x, p.y)
    }

    /// The screen point of `dial`'s knob at `value`.
    static func knob(_ shell: Shell, _ dial: LissajousLabyrinthDial, value: Int) throws -> Vec2 {
        try screen(Handles.knob(dial, value: value, level: try drawnLevel(shell)), shell)
    }

    /// Sends one pointer event through the shell's pointer entry.
    static func touch(_ shell: Shell, id: Int, _ phase: PointerPhase, at location: Vec2, time: inout Double) {
        shell.handlePointer(PointerEvent(id: id, phase: phase, location: location, timestamp: time), viewSize: viewSize)
        time += frame
    }

    /// Puts finger `id` down on `dial`'s knob at `value`.
    static func begin(_ shell: Shell, id: Int = 1, _ dial: LissajousLabyrinthDial, value: Int,
                      time: inout Double) throws {
        touch(shell, id: id, .began, at: try knob(shell, dial, value: value), time: &time)
    }

    /// Moves finger `id` to where `dial`'s knob is at `value`.
    static func move(_ shell: Shell, id: Int = 1, _ dial: LissajousLabyrinthDial, value: Int,
                     time: inout Double) throws {
        touch(shell, id: id, .moved, at: try knob(shell, dial, value: value), time: &time)
    }

    /// Ends (or cancels) finger `id` where `dial`'s knob is at `value`.
    static func end(_ shell: Shell, id: Int = 1, _ dial: LissajousLabyrinthDial, value: Int,
                    phase: PointerPhase = .ended, time: inout Double) throws {
        touch(shell, id: id, phase, at: try knob(shell, dial, value: value), time: &time)
    }

    /// A whole one-finger turn of `dial`'s ring through the knob positions of `values` (the first is where it goes
    /// down, each later one a `.moved`), released at the last.
    static func turn(_ shell: Shell, id: Int = 1, _ dial: LissajousLabyrinthDial, through values: [Int],
                     time: inout Double) throws {
        guard let first = values.first, let last = values.last else { return }
        try begin(shell, id: id, dial, value: first, time: &time)
        for index in 1..<max(values.count, 1) {
            try move(shell, id: id, dial, value: values[index], time: &time)
        }
        try end(shell, id: id, dial, value: last, time: &time)
    }

    /// The dial values one step at a time from `start`, `steps` steps (negative: anticlockwise), both ends included;
    /// phases wrap modulo 16 (frequencies are not wrapped: the caller keeps them in 1 … 9).
    static func values(_ dial: LissajousLabyrinthDial, from start: Int, steps: Int) -> [Int] {
        var result: [Int] = [start]
        var current: Int = start
        let sign: Int = steps >= 0 ? 1 : -1
        for _ in 0..<abs(steps) {
            current += sign
            if dial == .phaseA || dial == .phaseC { current = ((current % 16) + 16) % 16 }
            result.append(current)
        }
        return result
    }

    /// The greatest common divisor of two positive integers.
    static func gcd(_ a: Int, _ b: Int) -> Int {
        var x: Int = a
        var y: Int = b
        while y != 0 {
            let r: Int = x % y
            x = y
            y = r
        }
        return x
    }

    /// Whether `play` accepts `action` and is still playing afterwards.
    static func stillPlaying(_ play: LissajousLabyrinthPlay, _ action: LissajousLabyrinthAction) -> Bool {
        var trial: LissajousLabyrinthPlay = play
        do {
            try trial.apply(action, expecting: trial.fingerprint)
        } catch {
            return false
        }
        return trial.stage == .playing
    }

    /// A frequency value for `dial` 2 … 4 steps (preferably) from its current value, coprime with the other frequency,
    /// whose action keeps the level playing; nil when there is none.
    static func frequencyTarget(_ play: LissajousLabyrinthPlay, _ dial: LissajousLabyrinthDial) -> Int? {
        let current: Int = play.dials[dial]
        let other: Int = play.dials[dial == .frequencyA ? LissajousLabyrinthDial.frequencyB : .frequencyA]
        let offsets: [Int] = [3, -3, 2, -2, 4, -4, 5, -5, 6, -6, 7, -7, 8, -8, 1, -1]
        for offset in offsets {
            let target: Int = current + offset
            guard dial.range.contains(target), gcd(target, other) == 1 else { continue }
            if stillPlaying(play, LissajousLabyrinthAction(dial: dial, value: target)) { return target }
        }
        return nil
    }

    /// A phase turn (steps, sign = direction) for `dial` whose action keeps the level playing; nil when there is none.
    static func phaseSteps(_ play: LissajousLabyrinthPlay, _ dial: LissajousLabyrinthDial) -> Int? {
        let current: Int = play.dials[dial]
        let offsets: [Int] = [5, -5, 3, -3, 6, -6, 7, -7, 2, -2, 4, -4, 1, -1]
        for offset in offsets {
            let target: Int = ((current + offset) % 16 + 16) % 16
            if stillPlaying(play, LissajousLabyrinthAction(dial: dial, value: target)) { return offset }
        }
        return nil
    }

    /// Steps `dial`'s pending value with the presenter's stepper path from `current` to `target` the shorter way round
    /// its range (wrapping), as a player taps the stepper.
    static func stepPending(_ presenter: LissajousLabyrinthPresenter, _ dial: LissajousLabyrinthDial, from current: Int,
                            to target: Int) {
        let width: Int = dial.range.count
        let forward: Int = ((target - current) % width + width) % width
        let delta: Int = forward <= width / 2 ? 1 : -1
        let count: Int = delta > 0 ? forward : width - forward
        for _ in 0..<count { presenter.stepPending(dial, by: delta) }
    }

    /// The final dials of a certified level's solution.
    static func finalDials(_ generated: LissajousLabyrinthGenerated) -> LissajousLabyrinthDials {
        var final: LissajousLabyrinthDials = generated.level.start
        for action in generated.solution.actions { final[action.dial] = action.value }
        return final
    }

    // MARK: Selection outline

    /// The angles (clockwise from the ring's up, as seen from the authored eye) at which the outline is sampled: up-right,
    /// right and down-right, away from the neighbouring rings and the stage.
    static let outlineAngles: [Double] = [Double.pi / 4, Double.pi / 2, 3 * Double.pi / 4]

    /// The world point of `dial`'s selection outline circle (0.6 ring radii, the band's middle) at `angle`.
    static func outlinePoint(_ dial: LissajousLabyrinthDial, level: LissajousLabyrinthLevel, angle: Double) -> Vec3 {
        let radius: Double = Handles.ringRadius(level: level) * LissajousLabyrinthThreadScene.outlineScale
        let direction: Vec3 = Handles.up * cos(angle) + Handles.right * sin(angle)
        return Handles.ringCentre(dial, level: level) + direction * radius
    }

    /// How many of `outlineAngles` on `dial`'s outline circle show lit copper (the best pixel within the harness's
    /// 1.5 px search radius within its 0.12 per-channel tolerance) in the frame-check-size still `rgba` drawn at the
    /// authored camera.
    static func litOutlineSamples(_ rgba: [UInt8], dial: LissajousLabyrinthDial,
                                  snapshot: LissajousLabyrinthSceneSnapshot) -> Int {
        let width: Int = LissajousLabyrinthTest.width
        let height: Int = LissajousLabyrinthTest.height
        let copper: SIMD3<Double> = LissajousLabyrinthShaders.solidColour(LissajousLabyrinthPalette.copper, lit: true)
        var lit = 0
        for angle in outlineAngles {
            let world: Vec3 = outlinePoint(dial, level: snapshot.level, angle: angle)
            guard let p = Geometry.project(world, aspect: Double(width) / Double(height), snapshot: snapshot,
                                           width: width, height: height) else { continue }
            guard let best = LissajousLabyrinthTest.bestMatch(rgba, near: p.x, p.y,
                                                              radius: LissajousLabyrinthTest.colourSearch,
                                                              want: copper, width: width, height: height) else {
                continue
            }
            if best.distance <= LissajousLabyrinthTest.colourTolerance { lit += 1 }
        }
        return lit
    }

    // MARK: Orbit-aware framing

    /// The points that must lie inside the frame: every 32nd lap sample (128), each checkpoint and obstacle centre,
    /// and for each dial ring its centre, 8 points of its circle and its knob at the current value.
    static func framedPoints(_ snapshot: LissajousLabyrinthSceneSnapshot) -> [(name: String, world: Vec3)] {
        var points: [(name: String, world: Vec3)] = []
        let path: [Vec3] = Geometry.path(snapshot, tier: LissajousLabyrinthTier.of(0))
        var tick = 0
        while tick < path.count {
            points.append(("tick \(tick)", path[tick]))
            tick += LissajousLabyrinthTest.tickStep
        }
        for (index, ball) in snapshot.level.checkpoints.enumerated() {
            points.append(("checkpoint \(index)", Geometry.world(ball)))
        }
        for (index, ball) in snapshot.level.obstacles.enumerated() {
            points.append(("obstacle \(index)", Geometry.world(ball)))
        }
        let radius: Double = Handles.ringRadius(level: snapshot.level)
        for dial in LissajousLabyrinthDial.allCases {
            let centre: Vec3 = Handles.ringCentre(dial, level: snapshot.level)
            points.append(("\(dial) ring centre", centre))
            for k in 0..<8 {
                let angle: Double = 2 * Double.pi * Double(k) / 8
                let direction: Vec3 = Handles.up * cos(angle) + Handles.right * sin(angle)
                points.append(("\(dial) ring point \(k)", centre + direction * radius))
            }
            points.append(("\(dial) knob", Handles.knob(dial, value: snapshot.dials[dial], level: snapshot.level)))
        }
        return points
    }

    /// The framed points of `snapshot` that do not project inside a `width` × `height` frame with a 5 % margin on
    /// every side through the camera at `orbit`; returns the number checked and the misses.
    static func framingMisses(_ snapshot: LissajousLabyrinthSceneSnapshot, orbit: LissajousLabyrinthOrbit, width: Int,
                              height: Int) -> (checked: Int, misses: [String]) {
        let vp: Mat4 = Geometry.viewProjection(aspect: Double(width) / Double(height), snapshot: snapshot, orbit: orbit)
        let w: Double = Double(width)
        let h: Double = Double(height)
        var checked = 0
        var misses: [String] = []
        for point in framedPoints(snapshot) {
            checked += 1
            guard let p = Geometry.project(point.world, viewProjection: vp, width: width, height: height) else {
                misses.append("\(point.name): behind the camera")
                continue
            }
            let inside: Bool = p.x >= 0.05 * w && p.x <= 0.95 * w && p.y >= 0.05 * h && p.y <= 0.95 * h
            if !inside { misses.append(String(format: "%@ at (%.1f, %.1f)", point.name, p.x, p.y)) }
        }
        return (checked, misses)
    }
}

@MainActor
@Suite(.serialized) struct LissajousLabyrinthGestureWiringTests {
    typealias Script = LissajousLabyrinthGestureScript

    /// A one-finger turn of a frequency ring and of a phase ring each change that dial by exactly the named value with
    /// one action; a turn out and back sends nothing.
    @Test func oneFingerTurnsChangeADialByTheNamedValue() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Script.open(session)
        #expect(shell.state == .active)
        var time = 0.0
        let opening: String = try LissajousLabyrinthTest.digest(shell)
        let before: LissajousLabyrinthPlay = try Script.core(shell).play

        // Phase C out three steps and back: nothing is sent.
        let phase: Int = before.dials.phaseC
        var outAndBack: [Int] = Script.values(.phaseC, from: phase, steps: 3)
        outAndBack.append(contentsOf: Script.values(.phaseC, from: (phase + 3) % 16, steps: -3).dropFirst())
        try Script.turn(shell, .phaseC, through: outAndBack, time: &time)
        #expect(try LissajousLabyrinthTest.digest(shell) == opening, "a turn back to the start sends nothing")
        #expect(shell.presenter.gestures.phase == .idle)
        #expect(shell.presenter.mirror.message == nil)

        // Frequency A to a coprime value: the candidate is previewed and described, the release sends one action.
        let dial: LissajousLabyrinthDial = .frequencyA
        let start: Int = before.dials[dial]
        let target: Int = try #require(Script.frequencyTarget(before, dial), "a coprime frequency A that keeps playing")
        let steps: [Int] = Script.values(dial, from: start, steps: target - start)
        try Script.begin(shell, dial, value: start, time: &time)
        #expect(shell.presenter.gestures.selectedDial == dial)
        #expect(shell.presenter.mirror.selectedDial == dial)
        for index in 1..<steps.count {
            try Script.move(shell, dial, value: steps[index], time: &time)
        }
        let candidate = LissajousLabyrinthAction(dial: dial, value: target)
        #expect(shell.presenter.mirror.candidate == candidate)
        #expect(shell.presenter.gestures.phase == .turning(dial, start: start, candidate: target))
        let turning: String = shell.presenter.describe(try Script.core(shell))
        #expect(turning.contains("Dial Frequency A selected: \(target)."), "\(turning)")
        #expect(try LissajousLabyrinthTest.digest(shell) == opening, "nothing is sent before the release")
        try Script.end(shell, dial, value: target, time: &time)
        let afterFrequency: LissajousLabyrinthPlay = try Script.core(shell).play
        #expect(afterFrequency.dials.frequencyA == target)
        #expect(afterFrequency.dials.frequencyB == before.dials.frequencyB)
        #expect(afterFrequency.dials.phaseA == before.dials.phaseA)
        #expect(afterFrequency.dials.phaseC == before.dials.phaseC)
        #expect(afterFrequency.spent == before.spent + 1)
        #expect(shell.presenter.mirror.candidate == nil)
        #expect(shell.presenter.mirror.message == nil)
        var expected: LissajousLabyrinthPlay = before
        try expected.apply(candidate, expecting: expected.fingerprint)
        #expect(afterFrequency.fingerprint == expected.fingerprint)

        // Phase A by a few steps (either direction, wrapping at 16): exactly that value.
        try LissajousLabyrinthTest.draw(session)
        let phaseDial: LissajousLabyrinthDial = .phaseA
        let offset: Int = try #require(Script.phaseSteps(afterFrequency, phaseDial), "a phase A turn that keeps playing")
        let phaseStart: Int = afterFrequency.dials[phaseDial]
        let phaseTarget: Int = ((phaseStart + offset) % 16 + 16) % 16
        try Script.turn(shell, phaseDial, through: Script.values(phaseDial, from: phaseStart, steps: offset),
                        time: &time)
        let afterPhase: LissajousLabyrinthPlay = try Script.core(shell).play
        #expect(afterPhase.dials.phaseA == phaseTarget, "phase A \(phaseStart) turned \(offset) steps")
        #expect(afterPhase.spent == afterFrequency.spent + 1)
        var expectedPhase: LissajousLabyrinthPlay = afterFrequency
        try expectedPhase.apply(LissajousLabyrinthAction(dial: phaseDial, value: phaseTarget),
                                expecting: expectedPhase.fingerprint)
        #expect(afterPhase.fingerprint == expectedPhase.fingerprint)
        #expect(shell.presenter.gestures.selectedDial == phaseDial)
    }

    /// A second finger mid-turn, a cancelled touch and a touch on empty space send nothing; the same turn uninterrupted
    /// is sent.
    @Test func secondFingerCancelAndEmptySpaceSendNothing() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Script.open(session)
        var time = 0.0
        let opening: String = try LissajousLabyrinthTest.digest(shell)
        let play: LissajousLabyrinthPlay = try Script.core(shell).play
        let dial: LissajousLabyrinthDial = .phaseC
        let offset: Int = try #require(Script.phaseSteps(play, dial))
        let turn: [Int] = Script.values(dial, from: play.dials[dial], steps: offset)
        let target: Int = try #require(turn.last)

        // A second finger mid-turn starts an orbit and drops the turn.
        try Script.begin(shell, id: 1, dial, value: turn[0], time: &time)
        for index in 1..<turn.count { try Script.move(shell, id: 1, dial, value: turn[index], time: &time) }
        #expect(shell.presenter.mirror.candidate != nil)
        Script.touch(shell, id: 2, .began, at: Vec2(30, 30), time: &time)
        #expect(shell.presenter.gestures.phase == .orbiting)
        #expect(shell.presenter.mirror.candidate == nil)
        try Script.end(shell, id: 1, dial, value: target, time: &time)
        Script.touch(shell, id: 2, .ended, at: Vec2(30, 30), time: &time)
        #expect(shell.presenter.gestures.phase == .idle)
        #expect(shell.presenter.gestures.orbit == .authored, "no finger moved while orbiting")
        #expect(try LissajousLabyrinthTest.digest(shell) == opening, "second finger")

        // A cancelled touch ends the turn without an action.
        try Script.begin(shell, id: 3, dial, value: turn[0], time: &time)
        for index in 1..<turn.count { try Script.move(shell, id: 3, dial, value: turn[index], time: &time) }
        try Script.end(shell, id: 3, dial, value: target, phase: .cancelled, time: &time)
        #expect(shell.presenter.gestures.phase == .idle)
        #expect(shell.presenter.mirror.candidate == nil)
        #expect(try LissajousLabyrinthTest.digest(shell) == opening, "cancelled touch")

        // A touch on empty space (the top-left corner, far from every ring) starts nothing and keeps the selection.
        let selected: LissajousLabyrinthDial = shell.presenter.gestures.selectedDial
        Script.touch(shell, id: 4, .began, at: Vec2(8, 8), time: &time)
        #expect(shell.presenter.gestures.phase == .idle)
        Script.touch(shell, id: 4, .moved, at: Vec2(60, 40), time: &time)
        Script.touch(shell, id: 4, .ended, at: Vec2(60, 40), time: &time)
        #expect(shell.presenter.gestures.selectedDial == selected)
        #expect(try LissajousLabyrinthTest.digest(shell) == opening, "empty space")
        #expect(shell.presenter.mirror.message == nil)

        // The same turn uninterrupted is sent.
        try Script.turn(shell, id: 5, dial, through: turn, time: &time)
        #expect(try Script.core(shell).play.dials[dial] == target)
    }

    /// While paused (scene inactive) touches are dropped and a turn across the pause is cancelled; after resuming a turn
    /// is sent again.
    @Test func turnsWhilePausedSendNothing() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Script.open(session)
        var time = 0.0
        let opening: String = try LissajousLabyrinthTest.digest(shell)
        let play: LissajousLabyrinthPlay = try Script.core(shell).play
        let dial: LissajousLabyrinthDial = .phaseA
        let offset: Int = try #require(Script.phaseSteps(play, dial))
        let turn: [Int] = Script.values(dial, from: play.dials[dial], steps: offset)
        let target: Int = try #require(turn.last)

        // A turn that began before the pause ends after it without an action.
        try Script.begin(shell, id: 1, dial, value: turn[0], time: &time)
        for index in 1..<turn.count { try Script.move(shell, id: 1, dial, value: turn[index], time: &time) }
        session.setScenePhase(.inactive)
        #expect(shell.state == .suspended)
        // A whole turn while paused is dropped.
        try Script.turn(shell, id: 2, dial, through: turn, time: &time)
        #expect(try LissajousLabyrinthTest.digest(shell) == opening, "paused")
        session.setScenePhase(.active)
        #expect(shell.state == .active)
        try LissajousLabyrinthTest.draw(session)
        try Script.end(shell, id: 1, dial, value: target, time: &time)
        #expect(try LissajousLabyrinthTest.digest(shell) == opening, "a turn across the pause sends nothing")
        #expect(shell.presenter.mirror.message == nil)

        // Resumed: the turn is sent.
        try LissajousLabyrinthTest.draw(session)
        let now: Int = try Script.core(shell).play.dials[dial]
        try Script.turn(shell, id: 3, dial, through: Script.values(dial, from: now, steps: offset), time: &time)
        #expect(try Script.core(shell).play.dials[dial] == ((now + offset) % 16 + 16) % 16)
    }

    /// After the level is won the rings do not respond (orbit still works).
    @Test func turnsAfterAWinSendNothing() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Script.open(session)
        var time = 0.0
        let number: Int = try Script.core(shell).levelNumber
        let generated: LissajousLabyrinthGenerated = try LissajousLabyrinthExperienceCore.generated(number: number)
        for action in generated.solution.actions {
            let result: ActionResult = shell.presenter.send(action, port: shell.port)
            #expect(result == .accepted, "\(result.code)")
        }
        #expect(try Script.core(shell).play.stage == .won)
        try LissajousLabyrinthTest.draw(session)
        let won: String = try LissajousLabyrinthTest.digest(shell)
        let dial: LissajousLabyrinthDial = .phaseA
        let start: Int = try Script.core(shell).play.dials[dial]
        try Script.begin(shell, dial, value: start, time: &time)
        #expect(shell.presenter.gestures.phase == .idle, "a ring does not respond after the win")
        try Script.move(shell, dial, value: (start + 4) % 16, time: &time)
        #expect(shell.presenter.mirror.candidate == nil, "nothing is previewed")
        try Script.end(shell, dial, value: (start + 4) % 16, time: &time)
        #expect(try LissajousLabyrinthTest.digest(shell) == won)
        #expect(shell.presenter.mirror.message == nil, "nothing was sent")

        // Orbit still works.
        let w: Double = Script.viewSize.x
        let h: Double = Script.viewSize.y
        Script.touch(shell, id: 20, .began, at: Vec2(w * 0.3, h * 0.5), time: &time)
        Script.touch(shell, id: 21, .began, at: Vec2(w * 0.7, h * 0.5), time: &time)
        Script.touch(shell, id: 20, .moved, at: Vec2(w * 0.4, h * 0.5), time: &time)
        Script.touch(shell, id: 21, .moved, at: Vec2(w * 0.8, h * 0.5), time: &time)
        Script.touch(shell, id: 20, .ended, at: Vec2(w * 0.4, h * 0.5), time: &time)
        Script.touch(shell, id: 21, .ended, at: Vec2(w * 0.8, h * 0.5), time: &time)
        #expect(shell.presenter.gestures.orbit.azimuthOffset > 0, "a two-finger move right turns the camera")
        #expect(try LissajousLabyrinthTest.digest(shell) == won)
    }

    /// Once the allowance is spent without a win (a failed level) the rings do not respond.
    @Test func turnsAfterTheAllowanceIsSpentSendNothing() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Script.open(session)
        var time = 0.0
        let opening: LissajousLabyrinthPlay = try Script.core(shell).play
        let allowance: Int = opening.level.allowance
        try #require(allowance >= 2)
        // A phase C value that, alternated with the start value, spends the allowance without a win.
        let start: Int = opening.dials.phaseC
        var other: Int?
        for candidate in 0..<16 where candidate != start {
            var trial: LissajousLabyrinthPlay = opening
            var fine = true
            for index in 0..<allowance {
                let value: Int = index % 2 == 0 ? candidate : start
                do {
                    try trial.apply(LissajousLabyrinthAction(dial: .phaseC, value: value), expecting: trial.fingerprint)
                } catch {
                    fine = false
                    break
                }
                let want: LissajousLabyrinthStage = index == allowance - 1 ? .failed : .playing
                if trial.stage != want {
                    fine = false
                    break
                }
            }
            if fine {
                other = candidate
                break
            }
        }
        let losing: Int = try #require(other, "a losing alternation for phase C")
        for index in 0..<allowance {
            let value: Int = index % 2 == 0 ? losing : start
            let result: ActionResult = shell.presenter.send(LissajousLabyrinthAction(dial: .phaseC, value: value),
                                                            port: shell.port)
            #expect(result == .accepted, "\(result.code)")
        }
        #expect(try Script.core(shell).play.stage == .failed)
        try LissajousLabyrinthTest.draw(session)
        let failed: String = try LissajousLabyrinthTest.digest(shell)
        let dial: LissajousLabyrinthDial = .phaseA
        let phase: Int = try Script.core(shell).play.dials[dial]
        try Script.begin(shell, dial, value: phase, time: &time)
        #expect(shell.presenter.gestures.phase == .idle, "a ring does not respond after the allowance is spent")
        try Script.move(shell, dial, value: (phase + 3) % 16, time: &time)
        try Script.end(shell, dial, value: (phase + 3) % 16, time: &time)
        #expect(try LissajousLabyrinthTest.digest(shell) == failed)
        #expect(shell.presenter.mirror.message == nil, "nothing was sent")
    }

    /// A frequency turned to a value not coprime with the other frequency is refused: the text is shown and announced,
    /// and the state is unchanged.
    @Test func aRefusedTurnShowsItsTextAndChangesNothing() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Script.open(session)
        var time = 0.0
        // A frequency dial and a value sharing a factor with the other frequency (a level whose other frequency is 1
        // has none for that dial; level.next moves on until one is found).
        var found: (dial: LissajousLabyrinthDial, target: Int)?
        for _ in 0..<10 {
            let dials: LissajousLabyrinthDials = try Script.core(shell).play.dials
            let pairs: [(LissajousLabyrinthDial, LissajousLabyrinthDial)] = [(.frequencyA, .frequencyB),
                                                                             (.frequencyB, .frequencyA)]
            for pair in pairs where found == nil {
                for target in 1...9 where target != dials[pair.0] && Script.gcd(target, dials[pair.1]) != 1 {
                    found = (pair.0, target)
                    break
                }
            }
            if found != nil { break }
            #expect(shell.handle(control: "level.next") == .accepted)
            try LissajousLabyrinthTest.draw(session)
        }
        let refused = try #require(found, "a non-coprime frequency turn")
        try LissajousLabyrinthTest.draw(session)
        let before: LissajousLabyrinthPlay = try Script.core(shell).play
        let digest: String = try LissajousLabyrinthTest.digest(shell)
        let start: Int = before.dials[refused.dial]
        try Script.turn(shell, refused.dial, through: Script.values(refused.dial, from: start,
                                                                    steps: refused.target - start), time: &time)
        let message: String = try #require(shell.presenter.mirror.message, "the refusal is shown")
        #expect(message.hasPrefix("That change was refused: "), "\(message)")
        #expect(message.contains("r02-g02.move"), "\(message)")
        #expect(shell.presenter.announcements.last == message, "the refusal is announced")
        #expect(try LissajousLabyrinthTest.digest(shell) == digest, "a refused action leaves the state unchanged")
        #expect(try Script.core(shell).play.dials == before.dials)
        #expect(try Script.core(shell).play.spent == before.spent)
        #expect(shell.presenter.gestures.phase == .idle)
    }

    /// Touching a ring selects its dial: the description names it and the drawn still shows the copper outline on that
    /// dial's outline circle and not on the others'; the stepper path selects too.
    @Test func selectionIsDescribedAndOutlined() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Script.open(session)
        var time = 0.0
        let dials: [LissajousLabyrinthDial] = LissajousLabyrinthDial.allCases

        // At the start frequency A is selected and outlined, the others are not.
        #expect(shell.presenter.gestures.selectedDial == .frequencyA)
        let first: [UInt8] = try LissajousLabyrinthTest.still(session)
        let firstSnapshot: LissajousLabyrinthSceneSnapshot = try #require(shell.presenter.lastSnapshot)
        for dial in dials {
            let lit: Int = Script.litOutlineSamples(first, dial: dial, snapshot: firstSnapshot)
            if dial == .frequencyA {
                #expect(lit == Script.outlineAngles.count, "\(dial) outlined at \(lit) of 3 samples")
            } else {
                #expect(lit == 0, "\(dial) not outlined, \(lit) lit samples")
            }
        }

        // A tap on phase A's ring (on the ring circle, at the side farther from its knob; no movement) selects it and
        // sends nothing.
        try LissajousLabyrinthTest.draw(session)
        let opening: String = try LissajousLabyrinthTest.digest(shell)
        let level: LissajousLabyrinthLevel = try Script.drawnLevel(shell)
        let value: Int = try Script.core(shell).play.dials.phaseA
        let knobAngle: Double = LissajousLabyrinthHandles.knobAngle(.phaseA, value: value)
        let right: Double = Double.pi / 2
        let left: Double = 3 * Double.pi / 2
        func separation(_ a: Double, _ b: Double) -> Double {
            abs(LissajousLabyrinthHandles.angleDelta(from: a, to: b))
        }
        let angle: Double = separation(knobAngle, right) >= separation(knobAngle, left) ? right : left
        let direction: Vec3 = LissajousLabyrinthHandles.up * cos(angle) + LissajousLabyrinthHandles.right * sin(angle)
        let ringPoint: Vec3 = LissajousLabyrinthHandles.ringCentre(.phaseA, level: level)
            + direction * LissajousLabyrinthHandles.ringRadius(level: level)
        let at: Vec2 = try Script.screen(ringPoint, shell)
        Script.touch(shell, id: 1, .began, at: at, time: &time)
        #expect(shell.presenter.gestures.phase == .turning(.phaseA, start: value, candidate: value))
        Script.touch(shell, id: 1, .ended, at: at, time: &time)
        #expect(try LissajousLabyrinthTest.digest(shell) == opening, "a tap on a ring sends nothing")
        #expect(shell.presenter.gestures.selectedDial == .phaseA)
        #expect(shell.presenter.mirror.selectedDial == .phaseA)
        let text: String = shell.presenter.describe(try Script.core(shell))
        #expect(text.contains("Dial Phase A selected: \(value)."), "\(text)")

        let second: [UInt8] = try LissajousLabyrinthTest.still(session)
        let secondSnapshot: LissajousLabyrinthSceneSnapshot = try #require(shell.presenter.lastSnapshot)
        for dial in dials {
            let lit: Int = Script.litOutlineSamples(second, dial: dial, snapshot: secondSnapshot)
            if dial == .phaseA {
                #expect(lit == Script.outlineAngles.count, "\(dial) outlined at \(lit) of 3 samples")
            } else {
                #expect(lit == 0, "\(dial) not outlined, \(lit) lit samples")
            }
        }

        // The stepper path selects too.
        shell.presenter.select(.phaseC)
        #expect(shell.presenter.gestures.selectedDial == .phaseC)
        #expect(shell.presenter.mirror.selectedDial == .phaseC)
        let phaseC: Int = try Script.core(shell).play.dials.phaseC
        let stepped: String = shell.presenter.describe(try Script.core(shell))
        #expect(stepped.contains("Dial Phase C selected: \(phaseC)."), "\(stepped)")
        #expect(try LissajousLabyrinthTest.digest(shell) == opening)
    }

    /// Undo after a gesture restores the exact earlier digest; redo restores the later one.
    @Test func undoAfterAGestureRestoresTheDigest() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Script.open(session)
        var time = 0.0
        let earlier: String = try LissajousLabyrinthTest.digest(shell)
        let play: LissajousLabyrinthPlay = try Script.core(shell).play
        let offset: Int = try #require(Script.phaseSteps(play, .phaseC))
        let start: Int = play.dials.phaseC
        try Script.turn(shell, .phaseC, through: Script.values(.phaseC, from: start, steps: offset), time: &time)
        let later: String = try LissajousLabyrinthTest.digest(shell)
        #expect(later != earlier)
        #expect(shell.port.send("play.undo") == .accepted)
        #expect(try LissajousLabyrinthTest.digest(shell) == earlier, "undo restores the earlier digest")
        #expect(try Script.core(shell).play.dials.phaseC == start)
        #expect(shell.port.send("play.redo") == .accepted)
        #expect(try LissajousLabyrinthTest.digest(shell) == later, "redo restores the later digest")

        // A frequency gesture undoes the same way.
        try LissajousLabyrinthTest.draw(session)
        let beforeFrequency: String = try LissajousLabyrinthTest.digest(shell)
        let now: LissajousLabyrinthPlay = try Script.core(shell).play
        let target: Int = try #require(Script.frequencyTarget(now, .frequencyB))
        try Script.turn(shell, .frequencyB, through: Script.values(.frequencyB, from: now.dials.frequencyB,
                                                                   steps: target - now.dials.frequencyB), time: &time)
        #expect(try Script.core(shell).play.dials.frequencyB == target)
        let afterFrequency: String = try LissajousLabyrinthTest.digest(shell)
        #expect(shell.port.send("play.undo") == .accepted)
        #expect(try LissajousLabyrinthTest.digest(shell) == beforeFrequency)
        #expect(shell.port.send("play.redo") == .accepted)
        #expect(try LissajousLabyrinthTest.digest(shell) == afterFrequency)
    }

    /// Two-finger moves to each orbit limit never change the digest; the scene draws the orbit, the figure and the dial
    /// rings stay inside the frame with a 5 % margin through the orbited camera and the border band is night; a ring is
    /// still turned through the orbited camera; Reset view returns the authored pose and the authored frame checks hold.
    @Test func orbitLimitsKeepTheFrameAndResetViewReturns() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Script.open(session)
        var time = 0.0
        let opening: String = try LissajousLabyrinthTest.digest(shell)
        let payload: Data = try Script.core(shell).snapshotPayload()
        let authoredStill: [UInt8] = try LissajousLabyrinthTest.still(session)
        let width: Int = LissajousLabyrinthTest.width
        let height: Int = LissajousLabyrinthTest.height
        let az: ClosedRange<Double> = LissajousLabyrinthOrbit.azimuthRange
        let el: ClosedRange<Double> = LissajousLabyrinthOrbit.elevationRange
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
            #expect(shell.presenter.gestures.phase == .idle)
            let orbit: LissajousLabyrinthOrbit = shell.presenter.gestures.orbit
            let wantAzimuth: Double = sign.x > 0 ? az.upperBound : az.lowerBound
            let wantElevation: Double = sign.y > 0 ? el.upperBound : el.lowerBound
            #expect(abs(orbit.azimuthOffset - wantAzimuth) < 1e-12, "azimuth \(orbit.azimuthOffset)")
            #expect(abs(orbit.elevation - wantElevation) < 1e-12, "elevation \(orbit.elevation)")
            #expect(try LissajousLabyrinthTest.digest(shell) == opening, "orbiting changes no digest")

            let what: String = "orbit (\(sign.x), \(sign.y))"
            let rgba: [UInt8] = try LissajousLabyrinthTest.still(session)
            let snapshot: LissajousLabyrinthSceneSnapshot = try #require(shell.presenter.lastSnapshot)
            #expect(shell.presenter.scene.orbit == orbit, "\(what): the scene draws the controller's orbit")
            #expect(rgba != authoredStill, "\(what): the picture follows the orbit")
            #expect(LissajousLabyrinthTest.nonNightPixels(rgba) > 0, "\(what): something is drawn")
            let framing = Script.framingMisses(snapshot, orbit: orbit, width: width, height: height)
            #expect(framing.checked >= 128 + 4 * 10, "\(what): \(framing.checked) points")
            #expect(framing.misses.isEmpty, "\(what): \(framing.misses.prefix(6))")
            let border = LissajousLabyrinthTest.borderMisses(rgba, width: width, height: height)
            #expect(border.checked > 0)
            #expect(border.misses.isEmpty, "\(what): border \(border.misses)")
        }
        #expect(try LissajousLabyrinthTest.digest(shell) == opening)
        #expect(try Script.core(shell).snapshotPayload() == payload)

        // At the last limit a ring is still turned through the drawn (orbited) camera.
        let limit: LissajousLabyrinthOrbit = shell.presenter.gestures.orbit
        #expect(limit != .authored)
        try LissajousLabyrinthTest.draw(session)
        let play: LissajousLabyrinthPlay = try Script.core(shell).play
        let offset: Int = try #require(Script.phaseSteps(play, .phaseC))
        try Script.turn(shell, .phaseC, through: Script.values(.phaseC, from: play.dials.phaseC, steps: offset),
                        time: &time)
        #expect(try Script.core(shell).play.dials.phaseC == ((play.dials.phaseC + offset) % 16 + 16) % 16)
        #expect(shell.presenter.gestures.orbit == limit, "a turn does not move the camera")

        // Reset view returns the authored pose and the authored frame checks hold.
        shell.presenter.resetView()
        #expect(shell.presenter.gestures.orbit == .authored)
        let rgba: [UInt8] = try LissajousLabyrinthTest.still(session)
        let snapshot: LissajousLabyrinthSceneSnapshot = try #require(shell.presenter.lastSnapshot)
        #expect(shell.presenter.scene.orbit == .authored)
        LissajousLabyrinthTest.checkFrame(rgba, snapshot: snapshot, tier: 0, "after Reset view")
    }

    /// Pending play through the presenter wins every certified level of `band` (1 … 5, 20 levels each) in exactly its
    /// certified shortest number of actions with no refusal; every stepped value is announced and sends nothing.
    @Test(arguments: [1, 2, 3, 4, 5])
    func pendingApplyWinsEveryCertifiedLevel(band: Int) async throws {
        let firstNumber: Int = (band - 1) * 20 + 1
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Script.open(session, seed: UInt64(firstNumber - 1))
        let presenter: LissajousLabyrinthPresenter = shell.presenter
        var checked = 0
        for number in firstNumber..<(firstNumber + 20) {
            let generated: LissajousLabyrinthGenerated = try LissajousLabyrinthExperienceCore.generated(number: number)
            let core: LissajousLabyrinthExperienceCore = try Script.core(shell)
            #expect(core.levelNumber == number)
            #expect(core.play.level == generated.level, "level \(number)")
            #expect(core.play.stage == .playing, "level \(number)")
            let final: LissajousLabyrinthDials = Script.finalDials(generated)
            let digest: String = try LissajousLabyrinthTest.digest(shell)
            for dial in LissajousLabyrinthDial.allCases {
                let current: Int = core.play.dials[dial]
                let target: Int = final[dial]
                guard target != current else { continue }
                Script.stepPending(presenter, dial, from: current, to: target)
                #expect(presenter.mirror.pending.values[dial] == target, "level \(number) \(dial)")
                #expect(presenter.mirror.selectedDial == dial)
                let announced: String = "\(Script.title(dial)) \(target) pending. Apply to change."
                #expect(presenter.announcements.last == announced, "level \(number): \(presenter.announcements.last ?? "")")
            }
            #expect(try LissajousLabyrinthTest.digest(shell) == digest, "level \(number): pending values send nothing")
            let results: [ActionResult] = presenter.applyPending(port: shell.port)
            #expect(results.count == generated.solution.shortest, "level \(number): \(results.count) actions")
            for result in results { #expect(result == .accepted, "level \(number): \(result.code)") }
            let after: LissajousLabyrinthPlay = try Script.core(shell).play
            #expect(after.stage == .won, "level \(number)")
            #expect(after.spent == generated.solution.shortest, "level \(number): spent \(after.spent)")
            #expect(after.dials == final, "level \(number)")
            #expect(presenter.mirror.pending.isEmpty)
            #expect(presenter.mirror.message == nil, "level \(number): \(presenter.mirror.message ?? "")")
            checked += 1
            if number < firstNumber + 19 {
                #expect(shell.handle(control: "level.next") == .accepted)
            }
        }
        #expect(checked == 20)
    }

    /// Clear drops the pending values; an outside change (undo, redo, level.next through the port) drops them; an
    /// Apply whose earlier actions already win stops, drops the rest and announces the win.
    @Test func pendingClearOutsideChangeAndPartwayWin() async throws {
        // A certified level whose solution leaves phase C alone, so a pending phase C change is applied last, after the
        // win.
        var chosen: LissajousLabyrinthGenerated?
        for number in LissajousLabyrinthExperienceCore.levelNumbers {
            let generated: LissajousLabyrinthGenerated = try LissajousLabyrinthExperienceCore.generated(number: number)
            if Script.finalDials(generated).phaseC == generated.level.start.phaseC {
                chosen = generated
                break
            }
        }
        let generated: LissajousLabyrinthGenerated = try #require(chosen, "a certified solution without phase C")
        let number: Int = generated.entry.number
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Script.open(session, seed: UInt64(number - 1))
        let presenter: LissajousLabyrinthPresenter = shell.presenter
        #expect(try Script.core(shell).levelNumber == number)
        let opening: String = try LissajousLabyrinthTest.digest(shell)
        let start: LissajousLabyrinthDials = try Script.core(shell).play.dials

        // A stepped value is pending and announced; nothing is sent; Clear drops it.
        presenter.stepPending(.phaseA, by: 1)
        let stepped: Int = (start.phaseA + 1) % 16
        #expect(presenter.mirror.pending.values == [.phaseA: stepped])
        #expect(presenter.mirror.selectedDial == .phaseA)
        #expect(presenter.announcements.last == "Phase A \(stepped) pending. Apply to change.")
        #expect(try LissajousLabyrinthTest.digest(shell) == opening)
        presenter.clearPending()
        #expect(presenter.mirror.pending.isEmpty)
        #expect(try LissajousLabyrinthTest.digest(shell) == opening, "Clear sends nothing")

        // Undo and redo through the port drop pending values.
        let play: LissajousLabyrinthPlay = try Script.core(shell).play
        let offset: Int = try #require(Script.phaseSteps(play, .phaseC))
        let action = LissajousLabyrinthAction(dial: .phaseC, value: ((start.phaseC + offset) % 16 + 16) % 16)
        #expect(presenter.send(action, port: shell.port) == .accepted)
        presenter.stepPending(.phaseA, by: 1)
        #expect(!presenter.mirror.pending.isEmpty)
        #expect(shell.port.send("play.undo") == .accepted)
        #expect(presenter.mirror.pending.isEmpty, "undo drops the pending values")
        presenter.stepPending(.phaseA, by: -1)
        #expect(!presenter.mirror.pending.isEmpty)
        #expect(shell.port.send("play.redo") == .accepted)
        #expect(presenter.mirror.pending.isEmpty, "redo drops the pending values")
        #expect(shell.port.send("play.undo") == .accepted)
        #expect(try Script.core(shell).play.dials == start)
        #expect(try Script.core(shell).play.spent == 0)

        // Apply that wins partway: the solution's dials and a later phase C change; the win stops Apply.
        let final: LissajousLabyrinthDials = Script.finalDials(generated)
        for dial in LissajousLabyrinthDial.allCases where final[dial] != start[dial] {
            Script.stepPending(presenter, dial, from: start[dial], to: final[dial])
        }
        presenter.stepPending(.phaseC, by: 1)
        #expect(presenter.mirror.pending.values[.phaseC] == (start.phaseC + 1) % 16)
        let results: [ActionResult] = presenter.applyPending(port: shell.port)
        #expect(results.count == generated.solution.shortest, "\(results.count) actions sent")
        for result in results { #expect(result == .accepted, "\(result.code)") }
        let won: LissajousLabyrinthPlay = try Script.core(shell).play
        #expect(won.stage == .won)
        #expect(won.spent == generated.solution.shortest)
        #expect(won.dials.phaseC == start.phaseC, "the phase C change after the win is dropped")
        #expect(presenter.announcements.last == "The path is safe.")
        #expect(presenter.mirror.pending.isEmpty)
        #expect(presenter.mirror.message == nil)

        // level.next through the port drops pending values.
        presenter.stepPending(.frequencyB, by: 1)
        #expect(!presenter.mirror.pending.isEmpty)
        #expect(shell.port.send("level.next") == .accepted)
        #expect(presenter.mirror.pending.isEmpty, "level.next drops the pending values")
    }
}
#endif
