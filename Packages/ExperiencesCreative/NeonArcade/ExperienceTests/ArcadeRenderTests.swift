// ArcadeRenderTests — feature 075 (A10-P01) T-A10-104 (FR-A10-120, FR-A10-121, FR-A10-122; story 1 scenarios 1–5;
// story 2 scenario 3; SC-A10-101). Neon Arcade rendered inside the one app's session host on the simulator, short
// runs only (each test under 10 s, no wall-clock assertion): the first frame is non-blank and not black with its field
// probe holding; frames differ once objects fall while a paused run draws the same frame; drawing never changes the
// digest (a drawn session equals the bare replay of the same inputs at the same steps); objects, the player ring and
// the chevron are drawn at the rule sizes; the score, lives and paused/over marks follow the run; Reduce Motion halves
// the pulse and drift amounts the presenter draws with and leaves the core untouched; the description names score,
// lives and playing, paused or over; the drag steers by the finger's offset ÷ 1.5 and its release sends 0; the probe
// steps aside for objects near it; a failed draw reaches the session; and the experience's sources never create a
// graphics context of their own.
import Foundation
import XCTest
@testable import NeonArcadeExperience
import NeonArcadeCore
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreRendering
import VisualCoreScenes
import VisualCoreSimulation

@MainActor
final class ArcadeRenderTests: XCTestCase {
    private let size = CGSize(width: 90, height: 160)

    private func assertDrawn(_ shell: ExperienceShell<ArcadePresenter>,
                             _ frame: (rgba: [UInt8], width: Int, height: Int), _ name: String) {
        XCTAssertGreaterThan(frame.width, 0)
        XCTAssertTrue(FrameChecks.isNonBlank(frame.rgba, width: frame.width, height: frame.height), "\(name) not blank")
        XCTAssertFalse(FrameChecks.isBlack(frame.rgba, width: frame.width, height: frame.height), "\(name) not black")
        for probe in shell.frameProbes {
            XCTAssertEqual(FrameChecks.probe(probe, rgba: frame.rgba, width: frame.width, height: frame.height)?.rawValue,
                           probe.expected, "\(name) \(probe.name)")
        }
    }

    /// A core holding `run` (prepared with seed 7).
    private func core(_ run: GameRun) throws -> ArcadeCore {
        try ArcadeCore.restore(payload: ArcadeCore.encode(ArcadeState(run: run, random: SeededRandom(seed: 7).state)),
                               seed: 7)
    }

    /// A run at step 100 with a spike ball, a bar and an orb in the upper field.
    private func runWithObjects() -> GameRun {
        var run = GameRun.new()
        run.step = 100
        run.objects = [
            FallingObject(id: 0, contentId: "spike-ball", kind: .hazard, position: Vec2(2, 12), velocity: Vec2(0, -4),
                          radius: 0.5),
            FallingObject(id: 1, contentId: "bar", kind: .hazard, position: Vec2(5, 10), velocity: Vec2(0, -3),
                          radius: 0.2, halfLength: 0.8),
            FallingObject(id: 2, contentId: "glow-orb", kind: .orb, position: Vec2(7, 8), velocity: Vec2(0, -5),
                          radius: 0.25, value: 10),
        ]
        run.nextObjectId = 3
        return run
    }

    func testTheFirstFrameIsNonBlankWithItsFieldProbe() async throws {
        let session = ExperienceSession()
        let shell = try await ArcadeTest.open(session, size: size)
        let first = try ArcadeTest.picture(session)
        XCTAssertFalse(shell.frameProbes.isEmpty, "the dark field has a probe while no object is near it")
        assertDrawn(shell, first, "first frame")
        session.close()
        XCTAssertEqual(session.hostsAlive, 0)
    }

    func testFramesDifferOnceObjectsFallAndAPausedRunHolds() async throws {
        let session = ExperienceSession()
        let shell = try await ArcadeTest.open(session, size: size)
        let start = try ArcadeTest.picture(session)
        try ArcadeTest.frames(session, 100)
        XCTAssertGreaterThan(try ArcadeTest.core(shell).run.nextObjectId, 1, "objects have spawned")
        let later = try ArcadeTest.picture(session)
        assertDrawn(shell, later, "later")
        XCTAssertNotEqual(StableHash.sha256Hex(start.rgba), StableHash.sha256Hex(later.rgba), "objects fall")
        XCTAssertGreaterThan(ArcadeTest.differingPixels(start.rgba, later.rgba), 0)
        try ArcadeTest.frames(session, 20)
        let further = try ArcadeTest.picture(session)
        XCTAssertNotEqual(StableHash.sha256Hex(later.rgba), StableHash.sha256Hex(further.rgba), "and keep falling")

        XCTAssertTrue(shell.handle(control: "run.pause", values: [1]).isAccepted)
        let held = try ArcadeTest.picture(session)
        try ArcadeTest.frames(session, 10)
        let stillHeld = try ArcadeTest.picture(session)
        XCTAssertEqual(StableHash.sha256Hex(held.rgba), StableHash.sha256Hex(stillHeld.rgba), "a paused frame holds")
        session.close()
    }

    func testDrawingNeverChangesTheDigest() async throws {
        let session = ExperienceSession()
        let shell = try await ArcadeTest.open(session, size: size)
        var entries: [ScenarioStep] = []
        var last = 0
        func steer(_ value: Double) {
            let step = shell.engine.stepIndex
            XCTAssertTrue(shell.handle(control: "run.steer", values: [value]).isAccepted)
            entries.append(ScenarioStep(steps: step - last, action: ScriptedAction("run.steer", [value])))
            last = step
        }
        steer(0.8)
        try ArcadeTest.frames(session, 50)
        steer(-1)
        try ArcadeTest.frames(session, 70)
        let drawnSteps = shell.engine.stepIndex
        entries.append(ScenarioStep(steps: drawnSteps - last))
        let bare = ArcadeCore.played(seed: 7, entries: entries)
        XCTAssertEqual(try ArcadeTest.core(shell), bare, "the drawn session equals the undrawn replay")

        // Drawing a paused run again and again changes nothing.
        XCTAssertTrue(shell.handle(control: "run.pause", values: [1]).isAccepted)
        let digest = try shell.engine.digest()
        try ArcadeTest.frames(session, 15)
        _ = shell.accessibilitySummary
        _ = shell.frameProbes
        XCTAssertEqual(try shell.engine.digest(), digest)
        session.close()
    }

    func testObjectsAndThePlayerAreDrawnAtTheRuleSizes() throws {
        let presenter = ArcadePresenter(experienceID: ArcadeTest.id)
        let core = try core(runWithObjects())
        presenter.layOut(core, width: 90, height: 160)
        let s = presenter.lastScale
        XCTAssertEqual(s, 10, accuracy: 1e-12, "the 9 × 16 field fills a 90 × 160 canvas")
        XCTAssertEqual(presenter.lastObjectsDrawn, 3)
        let world = { (p: Vec2) in ArcadePresenter.world(p, scale: s) }

        XCTAssertEqual(presenter.bodyNodes[0].primitive, .circle(0.5 * s), "the spike ball at its radius")
        XCTAssertEqual(presenter.bodyNodes[0].position, world(Vec2(2, 12)))
        XCTAssertEqual(presenter.bodyNodes[1].primitive, .line(world(Vec2(4.2, 10)), world(Vec2(5.8, 10)), width: 0.4 * s),
                       "the bar's segment, 2 × radius wide")
        XCTAssertEqual(presenter.bodyNodes[2].primitive, .circle(0.25 * s), "the orb at its radius")
        XCTAssertEqual(presenter.glowNodes[0].primitive, .circle(0.5 * ArcadePresenter.glowScale * s))

        guard case .polyline(let ring, _)? = presenter.playerRing.primitive else { return XCTFail("no ring") }
        XCTAssertEqual(ring.count, ArcadePresenter.ringPoints)
        let center = world(Vec2(4.5, GameRun.playerY))
        for point in ring {
            XCTAssertEqual((point - center).length, PlayerState.hitRadius * s, accuracy: 1e-9, "the ring at the hit radius")
        }
        guard case .polygon(let chevron)? = presenter.playerChevron.primitive else { return XCTFail("no chevron") }
        XCTAssertEqual(chevron.count, 4)
        XCTAssertTrue(chevron.allSatisfy { ($0 - center).length < PlayerState.hitRadius * s }, "inside the ring")
    }

    func testTheScoreLivesAndStateMarksFollowTheRun() throws {
        let presenter = ArcadePresenter(experienceID: ArcadeTest.id)
        var run = GameRun.new()
        run.step = 400
        run.score = 120
        run.lives = 2
        presenter.layOut(try core(run), width: 90, height: 160)
        XCTAssertEqual(presenter.lastScoreText, "120")
        XCTAssertEqual(presenter.lastLivesLit, 2)
        XCTAssertEqual(presenter.lastStateMark, "none")
        run.paused = true
        presenter.layOut(try core(run), width: 90, height: 160)
        XCTAssertEqual(presenter.lastStateMark, "paused")
        run.lives = 0
        run.over = true
        run.score = GameRun.maxScore
        presenter.layOut(try core(run), width: 90, height: 160)
        XCTAssertEqual(presenter.lastStateMark, "over")
        XCTAssertEqual(presenter.lastLivesLit, 0)
        XCTAssertEqual(presenter.lastScoreText, "9999999")
        XCTAssertEqual(ArcadePresenter.segmentTable.count, 10)
        XCTAssertEqual(ArcadePresenter.segmentTable[8].count, 7)
        XCTAssertEqual(ArcadePresenter.segmentTable[1], [1, 2])
    }

    func testReduceMotionHalvesPulseAndDriftAndLeavesTheCoreAlone() throws {
        let full = ArcadePresenter(experienceID: ArcadeTest.id)
        let reduced = ArcadePresenter(experienceID: ArcadeTest.id, reduceMotion: true)
        XCTAssertEqual(full.pulseAmount, 0.15, accuracy: 1e-12)
        XCTAssertEqual(reduced.pulseAmount, 0.075, accuracy: 1e-12)
        XCTAssertEqual(full.driftAmount, 0.6, accuracy: 1e-12)
        XCTAssertEqual(reduced.driftAmount, 0.3, accuracy: 1e-12)

        var run = runWithObjects()
        run.step = 20   // sin(20 × 0.08) ≈ 1: near the pulse's peak
        let core = try core(run)
        let copy = core
        full.layOut(core, width: 90, height: 160)
        reduced.layOut(core, width: 90, height: 160)
        XCTAssertEqual(core, copy, "drawing reads the core only")
        let fullSwing = full.glowNodes[0].color.w / ArcadeCore.catalog.item(id: "spike-ball")!.glowColor.a
            - ArcadePresenter.glowBase
        let reducedSwing = reduced.glowNodes[0].color.w / ArcadeCore.catalog.item(id: "spike-ball")!.glowColor.a
            - ArcadePresenter.glowBase
        XCTAssertGreaterThan(abs(fullSwing), 0.1)
        XCTAssertEqual(reducedSwing, fullSwing / 2, accuracy: 1e-9, "the glow pulse is halved")
        XCTAssertEqual(ArcadePresenter.driftOffset(step: 50, speed: reduced.driftAmount),
                       ArcadePresenter.driftOffset(step: 50, speed: full.driftAmount) / 2, accuracy: 1e-12,
                       "the drift is halved")
        for index in 0..<ArcadePresenter.driftLines {
            let y = ArcadePresenter.driftLineY(index: index, offset: 1.3)
            XCTAssertTrue(y > ArcadePresenter.driftBottom && y <= ArcadePresenter.fieldHeight, "line \(index) at \(y)")
        }
    }

    func testTheDescriptionNamesScoreLivesAndState() async throws {
        var run = GameRun.new()
        XCTAssertEqual(ArcadePresenter.description(run),
                       "Neon Arcade: Neon Dodge, score 0, 3 lives, no objects falling, playing.")
        run = runWithObjects()
        run.score = 40
        run.lives = 1
        run.paused = true
        XCTAssertEqual(ArcadePresenter.description(run),
                       "Neon Arcade: Neon Dodge, score 40, 1 life, 3 objects falling, paused.")
        run.lives = 0
        run.over = true
        XCTAssertEqual(ArcadePresenter.description(run),
                       "Neon Arcade: Neon Dodge, score 40, no lives, 3 objects falling, over.")
        XCTAssertEqual(ArcadeControls.steeringWords(0), "Straight")
        XCTAssertEqual(ArcadeControls.steeringWords(-1), "Left")
        XCTAssertEqual(ArcadeControls.steeringWords(0.5), "Right 50 percent")

        let session = ExperienceSession()
        let shell = try await ArcadeTest.open(session, size: size)
        XCTAssertTrue(shell.accessibilitySummary.contains("score 0"))
        XCTAssertTrue(shell.accessibilitySummary.contains("3 lives"))
        XCTAssertTrue(shell.handle(control: "run.pause", values: [1]).isAccepted)
        XCTAssertTrue(shell.accessibilitySummary.hasSuffix("paused."))
        XCTAssertTrue(shell.handle(control: "run.restart").isAccepted)
        XCTAssertTrue(shell.accessibilitySummary.hasSuffix("playing."))
        session.close()
    }

    func testADragSteersByTheFingerOffsetAndReleaseStops() async throws {
        let session = ExperienceSession()
        let shell = try await ArcadeTest.open(session, size: size)
        let view = Vec2(90, 160)   // 10 points per unit; the player (x 4.5) is at view x 45
        XCTAssertEqual(try ArcadeTest.core(shell).run.player.x, 4.5)
        func steering() throws -> Double { try ArcadeTest.core(shell).run.steering }

        shell.handlePointer(ArcadeTest.touch(1, .began, 45, 140, at: 0), viewSize: view)
        XCTAssertEqual(try steering(), 0, "a touch alone does not steer")
        shell.handlePointer(ArcadeTest.touch(1, .moved, 60, 140, at: 0.05), viewSize: view)
        XCTAssertEqual(try steering(), 1, accuracy: 1e-12, "1.5 units right of the player: full right")
        shell.handlePointer(ArcadeTest.touch(1, .moved, 52.5, 140, at: 0.1), viewSize: view)
        XCTAssertEqual(try steering(), 0.5, accuracy: 1e-12, "0.75 units right: half")
        shell.handlePointer(ArcadeTest.touch(1, .moved, 0, 140, at: 0.15), viewSize: view)
        XCTAssertEqual(try steering(), -1, accuracy: 1e-12, "far left: clamped to −1")
        shell.handlePointer(ArcadeTest.touch(1, .ended, 0, 140, at: 0.2), viewSize: view)
        XCTAssertEqual(try steering(), 0, "the release stops steering")

        // A second finger stops the steering, and nothing more is sent until every finger lifts.
        shell.handlePointer(ArcadeTest.touch(2, .began, 45, 140, at: 1), viewSize: view)
        shell.handlePointer(ArcadeTest.touch(2, .moved, 60, 140, at: 1.05), viewSize: view)
        XCTAssertEqual(try steering(), 1, accuracy: 1e-12)
        shell.handlePointer(ArcadeTest.touch(3, .began, 30, 100, at: 1.1), viewSize: view)
        XCTAssertEqual(try steering(), 0)
        shell.handlePointer(ArcadeTest.touch(2, .moved, 75, 140, at: 1.15), viewSize: view)
        XCTAssertEqual(try steering(), 0)
        shell.handlePointer(ArcadeTest.touch(3, .ended, 30, 100, at: 1.2), viewSize: view)
        shell.handlePointer(ArcadeTest.touch(2, .ended, 75, 140, at: 1.25), viewSize: view)
        XCTAssertEqual(try steering(), 0)

        XCTAssertEqual(ArcadeGestures.steeringValue(view: Vec2(45, 0), playerX: 4.5, viewSize: view), 0)
        XCTAssertNil(ArcadeGestures.steeringValue(view: Vec2(45, 0), playerX: 4.5, viewSize: Vec2(0, 0)))
        XCTAssertNil(ArcadeGestures.steeringValue(view: Vec2(.nan, 0), playerX: 4.5, viewSize: view))
        session.close()
    }

    /// T-A10-115 (FR-A10-121; clarification 4): a finger held still keeps steering by its offset from the player as
    /// the player moves, reaching 0 under the finger, and nothing is sent while the value is unchanged.
    func testAHeldDragFollowsTheFingerAsThePlayerMoves() {
        var gestures = ArcadeGestures()
        let view = Vec2(90, 160)   // 10 points per unit
        XCTAssertTrue(gestures.follow(playerX: 4.5).isEmpty, "no drag, nothing")
        _ = gestures.handle(ArcadeTest.touch(1, .began, 45, 140, at: 0), playerX: 4.5, viewSize: view)
        let moved = gestures.handle(ArcadeTest.touch(1, .moved, 60, 140, at: 0.05), playerX: 4.5, viewSize: view)
        XCTAssertEqual(moved.last?.values, [1], "1.5 units right of the player: full right")
        XCTAssertTrue(gestures.follow(playerX: 4.5).isEmpty, "unchanged value, nothing sent")
        XCTAssertEqual(gestures.follow(playerX: 5.25).first?.values, [0.5], "the player moved halfway: half")
        XCTAssertTrue(gestures.follow(playerX: 5.25).isEmpty)
        XCTAssertEqual(gestures.follow(playerX: 6.0).first?.values, [0], "under the finger: no steering")
        XCTAssertEqual(gestures.follow(playerX: 6.75).first?.values, [-0.5], "past the finger: steers back")
        _ = gestures.handle(ArcadeTest.touch(1, .ended, 60, 140, at: 0.3), playerX: 6.75, viewSize: view)
        XCTAssertTrue(gestures.follow(playerX: 4.5).isEmpty, "released: nothing follows")
    }

    func testTheProbeStepsAsideForObjectsNearIt() throws {
        let presenter = ArcadePresenter(experienceID: ArcadeTest.id)
        var run = GameRun.new()
        presenter.layOut(try core(run), width: 160, height: 90)
        XCTAssertEqual(presenter.probes(try core(run)).map(\.expected), ["dark"])
        run.objects = [FallingObject(id: 0, contentId: "spike-ball", kind: .hazard, position: Vec2(4.6, 0.3),
                                     velocity: Vec2(0, -4), radius: 0.4)]
        run.nextObjectId = 1
        run.step = 10
        XCTAssertEqual(presenter.probes(try core(run)), [], "an object over the probe point")
        XCTAssertEqual(ArcadePresenter.colorClassOfField, FrameColorClass.dark.rawValue)
    }

    func testAFailedDrawReachesTheSession() async throws {
        let session = ExperienceSession()
        let shell = try await ArcadeTest.open(session, size: size)
        try ArcadeTest.frames(session, 1)
        shell.presenter.failNextDraw = true
        _ = session.renderHost?.renderOneFrame(present: false)
        XCTAssertEqual(session.state, .failed, "a drawing failure fails the session")
        XCTAssertNotNil(session.failure)
        XCTAssertFalse(shell.presenter.failNextDraw, "the seam clears itself")
        session.close()
        XCTAssertEqual(session.hostsAlive, 0)
    }

    func testTheExperienceNeverCreatesAGraphicsContextOfItsOwn() throws {
        let directory = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Experience")
        let files = try XCTUnwrap(FileManager.default.enumerator(at: directory, includingPropertiesForKeys: nil))
            .compactMap { $0 as? URL }.filter { $0.pathExtension == "swift" }
        XCTAssertGreaterThanOrEqual(files.count, 5)
        // Split so the repository's own source scanners do not read this list as a use.
        let forbidden = ["egl" + "CreateContext", "egl" + "GetDisplay", "egl" + "GetPlatformDisplay", "EAGL" + "Context",
                         "MTL" + "CreateSystemDefaultDevice", "RenderHost" + "(", "CVisualCore" + "GL", "vc" + "gl",
                         "AV" + "AudioEngine", "AV" + "AudioPlayer"]
        for file in files {
            let text = try String(contentsOf: file, encoding: .utf8)
            for word in forbidden {
                XCTAssertFalse(text.contains(word), "\(file.lastPathComponent) mentions \(word)")
            }
        }
    }
}
