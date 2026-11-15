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
// Feature 076 (A10-P02) T-A10-203 (FR-A10-220; SC-A10-204; clarification 5): the five lane guides are thin dim lines at
// the lane centres under the objects, player and HUD; the wave number is drawn in seven-segment digits beside the
// score; the description names the wave; drawing a wave-3 run never changes its state or digest and keeps every
// object at its rule size.
// Feature 077 (A10-P03) T-A10-304 (FR-A10-310, FR-A10-311, FR-A10-320, FR-A10-321; SC-A10-301; story 1 scenarios 1, 3
// and 4; story 2 scenarios 1 and 2): the title screen is drawn (non-blank, its probe holding) with its emblem; the
// game-over screen shows the shade, the cross and the final score and wave digits; screens cross-fade over 0.25 s and
// change at once under Reduce Motion; the effects are drawn in the back layer, before the particles and both before
// every collision shape; a hit draws its ring and, unless reduced flashing, the full-field tint; the wave sweep runs
// down the field; particles reach the renderer in a session; the probe steps aside for effects.
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
        try ArcadeTest.frames(session, 20)   // past the 0.25 s cross-fade to the paused screen
        XCTAssertEqual(shell.presenter.lastTransitionProgress, 1)
        let held = try ArcadeTest.picture(session)
        try ArcadeTest.frames(session, 10)
        let stillHeld = try ArcadeTest.picture(session)
        XCTAssertEqual(StableHash.sha256Hex(held.rgba), StableHash.sha256Hex(stillHeld.rgba), "a paused frame holds")
        session.close()
    }

    func testDrawingNeverChangesTheDigest() async throws {
        let session = ExperienceSession()
        let shell = try await ArcadeTest.open(session, size: size)
        var entries: [ScenarioStep] = [ArcadeCore.startEntry]
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

    /// A run in wave 3 (`wall`, wave step 100, free lane 2) with the three objects of ``runWithObjects()``.
    private func waveThreeRun() -> GameRun {
        var run = runWithObjects()
        run.step = 1_300
        run.score = 57
        run.wave = 3
        run.waveStep = 100
        run.patternId = "wall"
        run.freeLane = 2
        return run
    }

    /// T-A10-203: five lane guides at the lane centres (0.9 … 8.1), bottom to top, thin and dim, below the glows,
    /// objects, player and HUD.
    func testTheLaneGuidesAreDrawnAtTheLaneCentres() throws {
        let presenter = ArcadePresenter(experienceID: ArcadeTest.id)
        presenter.layOut(try core(waveThreeRun()), width: 90, height: 160)
        let s = presenter.lastScale
        XCTAssertEqual(presenter.laneNodes.count, Lanes.count)
        for (centre, expected) in zip(Lanes.centres, [0.9, 2.7, 4.5, 6.3, 8.1]) {
            XCTAssertEqual(centre, expected, accuracy: 1e-12)
        }
        for (lane, node) in presenter.laneNodes.enumerated() {
            let x = Lanes.centre(lane)
            XCTAssertEqual(node.primitive, .line(ArcadePresenter.world(Vec2(x, ArcadePresenter.driftBottom), scale: s),
                                                 ArcadePresenter.world(Vec2(x, GameRun.fieldHeight), scale: s),
                                                 width: max(ArcadePresenter.laneWidth * s, 1)), "lane \(lane)")
            XCTAssertEqual(node.color, ArcadePresenter.laneColor)
            XCTAssertLessThan(node.z, ArcadePresenter.glowZ, "under the glows and objects")
            XCTAssertLessThan(node.z, ArcadePresenter.hudZ, "under the HUD")
        }
        XCTAssertLessThanOrEqual(ArcadePresenter.laneColor.w, 0.1, "dim")
        XCTAssertLessThan(ArcadePresenter.laneWidth, 0.05, "thin")
        // The guides start above the player's band, so the bottom-centre frame probe (on lane 2's x) sees plain field.
        XCTAssertLessThan(presenter.probeFieldPoint().y, ArcadePresenter.driftBottom)
        XCTAssertEqual(presenter.probes(try core(GameRun.new())).map(\.expected), [FrameColorClass.dark.rawValue])
    }

    /// T-A10-203: the wave number is drawn in seven-segment digits beside the score, clear of the score and the
    /// lives, and follows the run.
    func testTheWaveNumberIsDrawnBesideTheScore() throws {
        let presenter = ArcadePresenter(experienceID: ArcadeTest.id)
        var run = waveThreeRun()
        presenter.layOut(try core(run), width: 90, height: 160)
        XCTAssertEqual(presenter.lastWaveText, "3")
        XCTAssertEqual(presenter.lastScoreText, "57")
        let lit = presenter.waveDigitNodes.map { $0.filter { $0.primitive != nil }.count }
        XCTAssertEqual(lit, [ArcadePresenter.segmentTable[3].count, 0, 0], "a 3 in the first wave digit")
        XCTAssertTrue(presenter.waveDigitNodes.joined().allSatisfy { $0.z == ArcadePresenter.hudZ })
        let scoreRight = ArcadePresenter.digitOrigin.x + Double(ArcadePresenter.maxDigits - 1)
            * ArcadePresenter.digitAdvance + ArcadePresenter.digitWidth
        let waveRight = ArcadePresenter.waveOrigin.x + Double(ArcadePresenter.maxWaveDigits - 1)
            * ArcadePresenter.digitAdvance + ArcadePresenter.digitWidth
        let livesLeft = ArcadePresenter.livesOrigin.x - Double(GameRun.startLives - 1) * ArcadePresenter.livesSpacing
            - ArcadePresenter.lifeRadius
        XCTAssertLessThan(scoreRight, ArcadePresenter.waveOrigin.x, "beside the score, never over it")
        XCTAssertLessThan(waveRight, livesLeft, "clear of the lives")
        XCTAssertEqual(ArcadePresenter.waveOrigin.y, ArcadePresenter.digitOrigin.y, "on the score's line")
        run.wave = 27
        presenter.layOut(try core(run), width: 90, height: 160)
        XCTAssertEqual(presenter.lastWaveText, "27")
        XCTAssertEqual(ArcadePresenter.waveText(1_234), "999")
        XCTAssertEqual(ArcadePresenter.waveText(0), "1")
    }

    /// T-A10-203 (FR-A10-220): drawing a wave-3 run reads the core only — state and digest unchanged — and keeps the
    /// objects and the player at their rule sizes; the description names the wave.
    func testDrawingAWaveThreeRunNeverChangesTheDigest() throws {
        let presenter = ArcadePresenter(experienceID: ArcadeTest.id)
        let core = try core(waveThreeRun())
        let copy = core
        var before = DigestBuilder(domain: ArcadeTest.id.rawValue)
        try core.writeDigest(into: &before)
        for size in [(90.0, 160.0), (160.0, 90.0), (375.0, 812.0)] {
            presenter.layOut(core, width: size.0, height: size.1)
            let s = presenter.lastScale
            XCTAssertEqual(presenter.bodyNodes[0].primitive, .circle(0.5 * s), "rule size at \(size)")
            XCTAssertEqual(presenter.bodyNodes[2].primitive, .circle(0.25 * s), "rule size at \(size)")
        }
        _ = presenter.describe(core)
        _ = presenter.probes(core)
        var after = DigestBuilder(domain: ArcadeTest.id.rawValue)
        try core.writeDigest(into: &after)
        XCTAssertEqual(core, copy)
        XCTAssertEqual(after.finish(), before.finish())
        XCTAssertEqual(presenter.describe(core),
                       "Neon Arcade: Neon Dodge, wave 3, score 57, 3 lives, 3 objects falling, playing.")
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
                       "Neon Arcade: Neon Dodge, wave 1, score 0, 3 lives, no objects falling, playing.")
        run = runWithObjects()
        run.score = 40
        run.lives = 1
        run.paused = true
        XCTAssertEqual(ArcadePresenter.description(run),
                       "Neon Arcade: Neon Dodge, wave 1, score 40, 1 life, 3 objects falling, paused.")
        run.lives = 0
        run.over = true
        XCTAssertEqual(ArcadePresenter.description(run),
                       "Neon Arcade: Neon Dodge, wave 1, score 40, no lives, 3 objects falling, over.")
        run.wave = 12
        XCTAssertTrue(ArcadePresenter.description(run).hasPrefix("Neon Arcade: Neon Dodge, wave 12, score 40, "))
        XCTAssertEqual(ArcadeControls.steeringWords(0), "Straight")
        XCTAssertEqual(ArcadeControls.steeringWords(-1), "Left")
        XCTAssertEqual(ArcadeControls.steeringWords(0.5), "Right 50 percent")

        let session = ExperienceSession()
        let shell = try await ArcadeTest.open(session, size: size)
        XCTAssertTrue(shell.accessibilitySummary.contains("score 0"))
        XCTAssertTrue(shell.accessibilitySummary.contains("wave 1, "))
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

    // MARK: Feature 077 (A10-P03)

    /// A core holding `run` on `screen` (prepared with seed 7).
    private func core(_ run: GameRun, screen: ArcadeScreen) throws -> ArcadeCore {
        try ArcadeCore.restore(payload: ArcadeCore.encode(ArcadeState(run: run, random: SeededRandom(seed: 7).state,
                                                                      screen: screen)), seed: 7)
    }

    /// T-A10-304 (story 1 scenario 1): the title screen is drawn — not blank, not black, its probe holding — with the
    /// shade, the emblem and the play triangle; nothing falls.
    func testTheTitleScreenIsDrawn() async throws {
        let session = ExperienceSession()
        let shell = try await ArcadeTest.open(session, start: false, size: size)
        let frame = try ArcadeTest.picture(session)
        assertDrawn(shell, frame, "title")
        XCTAssertFalse(shell.frameProbes.isEmpty)
        let presenter = shell.presenter
        XCTAssertEqual(presenter.lastStateMark, "title")
        for node in [presenter.titleShadeNode, presenter.titleRing, presenter.titleChevron, presenter.titlePlay] {
            XCTAssertNotNil(node.primitive, node.id)
            XCTAssertEqual(node.z, ArcadePresenter.stateZ)
        }
        XCTAssertEqual(presenter.lastObjectsDrawn, 0, "nothing falls on the title screen")
        try ArcadeTest.frames(session, 30)
        XCTAssertEqual(StableHash.sha256Hex(try ArcadeTest.picture(session).rgba), StableHash.sha256Hex(frame.rgba),
                       "the title holds still")
        session.close()
    }

    /// T-A10-304 (story 1 scenario 3): the game-over screen shows the shade, the cross and the run's final score and
    /// wave in seven-segment digits centred under the cross; the title nodes are hidden.
    func testTheGameOverScreenShowsTheScoreAndTheWave() throws {
        let presenter = ArcadePresenter(experienceID: ArcadeTest.id)
        var run = waveThreeRun()
        run.lives = 0
        run.over = true
        run.score = 1_250
        presenter.layOut(try core(run, screen: .over), width: 90, height: 160)
        XCTAssertEqual(presenter.lastStateMark, "over")
        XCTAssertEqual(presenter.lastOverScoreText, "1250")
        XCTAssertEqual(presenter.lastOverWaveText, "3")
        let litScore = presenter.overScoreNodes.map { $0.filter { $0.primitive != nil }.count }
        XCTAssertEqual(Array(litScore.prefix(4)), [1, 2, 5, 0].map { ArcadePresenter.segmentTable[$0].count })
        XCTAssertEqual(Array(litScore.dropFirst(4)), [0, 0, 0])
        let litWave = presenter.overWaveNodes.map { $0.filter { $0.primitive != nil }.count }
        XCTAssertEqual(litWave, [ArcadePresenter.segmentTable[3].count, 0, 0])
        XCTAssertEqual(ArcadePresenter.centredDigitsX(1), 4.5 - ArcadePresenter.digitWidth / 2, accuracy: 1e-12)
        XCTAssertNil(presenter.titleShadeNode.primitive)
        XCTAssertEqual(presenter.describe(try core(run, screen: .over)),
                       "Neon Arcade: Neon Dodge, wave 3, score 1250, no lives, 3 objects falling, over.")
    }

    /// T-A10-304 (FR-A10-311; story 1 scenario 4; analyze addition): a screen change cross-fades over 0.25 s of frame
    /// time — the old overlay fading out while the new one fades in — and under Reduce Motion the cross-fade lasts
    /// 0 s: the change is immediate. Presentation only: the core is unchanged.
    func testScreensCrossFadeAndChangeAtOnceUnderReduceMotion() throws {
        let full = ArcadePresenter(experienceID: ArcadeTest.id)
        let reduced = ArcadePresenter(experienceID: ArcadeTest.id, reduceMotion: true)
        XCTAssertEqual(full.screenTransitionDuration, 0.25, accuracy: 1e-12)
        XCTAssertEqual(reduced.screenTransitionDuration, 0, "Reduce Motion: no animated transition")
        var run = GameRun.new()
        run.step = 200
        let playing = try core(run, screen: .playing)
        run.paused = true
        let paused = try core(run, screen: .paused)
        let copy = paused
        for presenter in [full, reduced] {
            presenter.advancePresentation(playing, seconds: 1.0 / 60)
            presenter.layOut(playing, width: 90, height: 160)
            XCTAssertEqual(presenter.lastTransitionProgress, 1, "the first screen appears at once")
            presenter.advancePresentation(paused, seconds: 1.0 / 60)
            presenter.layOut(paused, width: 90, height: 160)
        }
        XCTAssertEqual(reduced.lastTransitionProgress, 1, "immediate under Reduce Motion")
        XCTAssertEqual(reduced.overlayAlpha(.paused), 1)
        XCTAssertEqual(full.lastTransitionProgress, 0, "the cross-fade begins")
        XCTAssertEqual(full.overlayAlpha(.playing), 1, "the old screen fades out from full")
        full.advancePresentation(paused, seconds: 0.1)
        XCTAssertEqual(full.transitionProgress, 0.4, accuracy: 1e-9)
        XCTAssertEqual(full.overlayAlpha(.paused), 0.4, accuracy: 1e-9)
        XCTAssertEqual(full.overlayAlpha(.playing), 0.6, accuracy: 1e-9)
        full.layOut(paused, width: 90, height: 160)
        XCTAssertEqual(full.lastTransitionProgress, 0.4, accuracy: 1e-9)
        full.advancePresentation(paused, seconds: 0.2)
        XCTAssertEqual(full.transitionProgress, 1)
        XCTAssertNil(full.fadingScreen, "the cross-fade is over")
        XCTAssertEqual(paused, copy, "presentation only")
    }

    /// T-A10-304 (FR-A10-320): every effect node lies in the back layer, which is drawn before the particles and the
    /// front layer with the glows, objects and player: the collision shapes are always above the effects.
    func testTheEffectsAreDrawnBelowTheCollisionShapes() throws {
        let presenter = ArcadePresenter(experienceID: ArcadeTest.id)
        let back = Set(presenter.backRoot.drawList().map { ObjectIdentifier($0.node) })
        let front = Set(presenter.root.drawList().map { ObjectIdentifier($0.node) })
        for node in presenter.effects.nodes {
            XCTAssertTrue(back.contains(ObjectIdentifier(node)), "\(node.id) in the back layer")
            XCTAssertFalse(front.contains(ObjectIdentifier(node)), "\(node.id) not in the front layer")
        }
        for node in presenter.bodyNodes + presenter.glowNodes + [presenter.playerRing, presenter.playerChevron] {
            XCTAssertTrue(front.contains(ObjectIdentifier(node)), "\(node.id) in the front layer")
            XCTAssertFalse(back.contains(ObjectIdentifier(node)), "\(node.id) not in the back layer")
        }
        XCTAssertTrue(back.contains(ObjectIdentifier(presenter.field)), "the field is under the effects")
    }

    /// T-A10-304 (story 2 scenarios 1 and 2; FR-A10-321): a pickup bursts cyan particles at the orb; a hit bursts red
    /// particles, draws its ring expanding over 0.3 s and the full-field tint for 6 steps — under reduced flashing
    /// only the ring; a new wave runs the sweep down the field over 0.5 s.
    func testHitsPickupsAndWavesStartTheirEffects() throws {
        var previous = GameRun.new()
        previous.step = 599
        previous.objects = [FallingObject(id: 4, contentId: "glow-orb", kind: .orb, position: Vec2(3, 2),
                                          velocity: Vec2(0, -5), radius: 0.25, value: 10)]
        previous.nextObjectId = 5
        var current = previous
        current.step = 600
        current.objects = []
        // Events carry the step they happened in, the step before the run's new step count (GameRun.validate).
        current.events = [CollisionEvent(step: 599, objectId: 4, kind: .pickup),
                          CollisionEvent(step: 599, objectId: 2, kind: .hit)]
        current.eventCount = 2
        current.lives = 2
        current.wave = 2
        current.waveStep = 0
        for reduceFlashing in [false, true] {
            let sound = RecordingSoundSink()
            let haptics = RecordingHapticSink()
            let presenter = ArcadePresenter(experienceID: ArcadeTest.id, reduceFlashing: reduceFlashing,
                                            soundSink: sound, feedback: ArcadeTest.feedback(haptics))
            presenter.advancePresentation(try core(previous), seconds: 1.0 / 60)
            presenter.advancePresentation(try core(current), seconds: 1.0 / 60)
            XCTAssertEqual(presenter.effects.lastCues.map(\.kind), [.pickup, .hit, .wave])
            XCTAssertEqual(presenter.effects.burstCount, 2)
            XCTAssertEqual(presenter.effects.particles.aliveCount,
                           ArcadeEffectsLayer.pickupParticles + ArcadeEffectsLayer.hitParticles)
            XCTAssertEqual(sound.played, ["pickup", "hit"], "two sounds per step at most")
            XCTAssertEqual(haptics.played, [.impactLight, .impactHeavy])
            XCTAssertEqual(presenter.effects.rings.count, 1)
            XCTAssertEqual(presenter.effects.tintAlphaNow, reduceFlashing ? 0 : 0.25, "reduced flashing: ring only")
            XCTAssertEqual(presenter.effects.sweepY ?? -1, GameRun.fieldHeight, accuracy: 1e-12)
            presenter.layOut(try core(current), width: 90, height: 160)
            XCTAssertNotNil(presenter.effects.ringNodes[0].primitive, "the ring is drawn")
            XCTAssertEqual(presenter.effects.tint.primitive == nil, reduceFlashing)
            XCTAssertNotNil(presenter.effects.sweep.primitive)
            // Nine steps later: the ring has grown, the tint is gone, the sweep has moved down.
            var later = current
            later.step = 609
            presenter.advancePresentation(try core(later), seconds: 0.15)
            let start = presenter.effects.rings[0].start
            XCTAssertEqual(presenter.effects.ringRadius(start: start), 1.0, accuracy: 1e-9, "halfway from 0.4 to 1.6")
            XCTAssertEqual(presenter.effects.tintAlphaNow, 0)
            XCTAssertEqual(presenter.effects.sweepY ?? -1, 16 * (1 - 9.0 / 30), accuracy: 1e-9)
            later.step = 640
            presenter.advancePresentation(try core(later), seconds: 0.5)
            XCTAssertTrue(presenter.effects.rings.isEmpty, "the ring lasts 0.3 s")
            XCTAssertNil(presenter.effects.sweepY, "the sweep lasts 0.5 s")
            XCTAssertEqual(presenter.effects.particles.aliveCount, 0, "particles live 0.4 s")
        }
        XCTAssertEqual(ArcadeEffectsLayer.particleCapacity, 256)
    }

    /// T-A10-304: in a session the particles of a hit reach the particle renderer through the host's registry, the
    /// probe steps aside for them, and a restart clears every effect.
    func testParticlesAreDrawnInASessionAndARestartClearsThem() async throws {
        let session = ExperienceSession()
        let shell = try await ArcadeTest.open(session, size: size)
        XCTAssertTrue(shell.handle(control: "run.steer", values: [-1]).isAccepted)
        var frames = 0
        while shell.presenter.effects.rings.isEmpty, frames < 600 {
            try ArcadeTest.frames(session, 1)
            frames += 1
        }
        try ArcadeTest.frames(session, 1)
        XCTAssertGreaterThan(shell.presenter.lastParticlesDrawn, 0, "the burst is drawn")
        let frame = try ArcadeTest.picture(session)
        assertDrawn(shell, frame, "with effects")
        XCTAssertTrue(shell.handle(control: "run.pause", values: [1]).isAccepted)
        XCTAssertTrue(shell.handle(control: "run.restart").isAccepted)
        try ArcadeTest.frames(session, 1)
        XCTAssertTrue(shell.presenter.effects.rings.isEmpty, "a new run starts without effects")
        XCTAssertEqual(shell.presenter.effects.particles.aliveCount, 0)
        session.close()
        XCTAssertEqual(shell.state, .inactive, "closed without a GPU leak")
    }
}
