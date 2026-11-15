// AquariumRenderTests — feature 068 (A09-P01) T-A09-103 (FR-A09-120; story 1 scenarios 1 and 3; SC-A09-101,
// SC-A09-105). Digital Aquarium rendered inside the one app's session host on the simulator, short runs only (each
// test under 10 s, no wall-clock assertion): the Reef draws a non-blank, non-black frame with its declared water probe
// holding; the Kelp draws a different frame (by pixel hash and in a visible number of pixels); swimming fish change the
// frame while a paused aquarium draws the same frame; the lighting changes the frame; a failed draw reaches the session
// as a failure; and the experience's sources never create a graphics context of their own.
//
// Feature 069 (A09-P02) T-A09-205 (FR-A09-211; research D5): the swim animation and the decor drawing. A faster fish's
// outline repeats sooner (the outline is 2π-periodic in the phase and the phase advances faster with speed); a left
// turn bends the outline and the tail left, a right turn right; a fish swimming left is drawn as the mirror of one
// swimming right; Reduce Motion halves every point's sideways displacement; two moments of a swim draw different
// outlines; decor polygons follow their rotation and scale and are drawn for the starter decor; the state digest is
// unchanged by Reduce Motion.
//
// Feature 070 (A09-P03) T-A09-307 (FR-A09-311–313): food pellets are drawn and change the frame; every gesture action
// has a native control (`GestureAlternatives.missing` is empty); the description names the pellet and decor counts and
// follows a feed and a removal; a quick tap on the canvas, forwarded through the presenter, drops food exactly once.
//
// Feature 071 (A09-P04) T-A09-405 (FR-A09-404, 410, 411, 430; SC-A09-402–404): back-layer fish and plants are drawn
// before (lower z), at 0.75 of the front scale and tinted toward the water; the caustics are drawn, change between two
// frames 60 steps apart and hold under Reduce Motion (time 0); dim caustics are fainter than bright ones; a broken
// caustics shader falls back to the Phase 03 water and gravel and the frame still draws; bubbles and motes are drawn
// (at least one pixel in radius); the state digest does not depend on Reduce Motion and the effects; unknown plant and
// decor kinds are skipped when drawn.
import Foundation
import XCTest
@testable import DigitalAquariumExperience
import DigitalAquariumCore
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreRendering
import VisualCoreScenes

@MainActor
final class AquariumRenderTests: XCTestCase {
    private let size = CGSize(width: 160, height: 90)

    private func assertDrawn(_ shell: ExperienceShell<AquariumPresenter>,
                             _ frame: (rgba: [UInt8], width: Int, height: Int), _ name: String) {
        XCTAssertGreaterThan(frame.width, 0)
        XCTAssertTrue(FrameChecks.isNonBlank(frame.rgba, width: frame.width, height: frame.height), "\(name) not blank")
        XCTAssertFalse(FrameChecks.isBlack(frame.rgba, width: frame.width, height: frame.height), "\(name) not black")
        for probe in shell.frameProbes {
            XCTAssertEqual(FrameChecks.probe(probe, rgba: frame.rgba, width: frame.width, height: frame.height)?.rawValue,
                           probe.expected, "\(name) \(probe.name)")
        }
    }

    func testTheTwoHabitatsDrawNonBlankFramesThatDiffer() async throws {
        let session = ExperienceSession()
        let shell = try await AquariumTest.open(session, size: size)
        try AquariumTest.frames(session, 2)
        let reef = try AquariumTest.picture(session)
        XCTAssertFalse(shell.frameProbes.isEmpty, "the soft Reef water has a clear colour class")
        assertDrawn(shell, reef, "reef")

        XCTAssertTrue(shell.handle(control: "habitat.select", values: [1]).isAccepted)
        try AquariumTest.frames(session, 2)
        let kelp = try AquariumTest.picture(session)
        assertDrawn(shell, kelp, "kelp")
        XCTAssertNotEqual(StableHash.sha256Hex(reef.rgba), StableHash.sha256Hex(kelp.rgba))
        let differing = AquariumTest.differingPixels(reef.rgba, kelp.rgba)
        XCTAssertGreaterThan(differing, reef.width * reef.height / 10, "the water colour and the scene change visibly")
        session.close()
        XCTAssertEqual(session.hostsAlive, 0)
    }

    func testSwimmingChangesTheFrameAndPauseHoldsIt() async throws {
        let session = ExperienceSession()
        let shell = try await AquariumTest.open(session, size: size)
        let start = try AquariumTest.picture(session)
        try AquariumTest.frames(session, 30)
        let later = try AquariumTest.picture(session)
        XCTAssertNotEqual(StableHash.sha256Hex(start.rgba), StableHash.sha256Hex(later.rgba), "the fish swim")

        XCTAssertTrue(shell.handle(control: "motion.pause", values: [1]).isAccepted)
        let held = try AquariumTest.picture(session)
        try AquariumTest.frames(session, 10)
        let stillHeld = try AquariumTest.picture(session)
        XCTAssertEqual(StableHash.sha256Hex(held.rgba), StableHash.sha256Hex(stillHeld.rgba), "a paused frame holds")
        session.close()
    }

    func testTheLightingChangesTheFrame() async throws {
        let session = ExperienceSession()
        let shell = try await AquariumTest.open(session, size: size)
        XCTAssertTrue(shell.handle(control: "motion.pause", values: [1]).isAccepted)
        let soft = try AquariumTest.picture(session)
        XCTAssertTrue(shell.handle(control: "lighting.level", values: [2]).isAccepted)
        let bright = try AquariumTest.picture(session)
        assertDrawn(shell, bright, "bright")
        XCTAssertGreaterThan(AquariumTest.differingPixels(soft.rgba, bright.rgba), soft.width * soft.height / 2,
                             "the whole aquarium is lit brighter")
        session.close()
    }

    func testAFailedDrawReachesTheSession() async throws {
        let session = ExperienceSession()
        let shell = try await AquariumTest.open(session, size: size)
        try AquariumTest.frames(session, 1)
        shell.presenter.failNextDraw = true
        _ = session.renderHost?.renderOneFrame(present: false)
        XCTAssertEqual(session.state, .failed, "a drawing failure fails the session")
        XCTAssertNotNil(session.failure)
        XCTAssertFalse(shell.presenter.failNextDraw, "the seam clears itself")
        session.close()
        XCTAssertEqual(session.hostsAlive, 0)
    }

    // MARK: Swim animation and decor (feature 069, T-A09-205)

    private func assertSame(_ a: [Vec2], _ b: [Vec2], _ message: String, accuracy: Double = 1e-9,
                            file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(a.count, b.count, message, file: file, line: line)
        for (p, q) in zip(a, b) {
            XCTAssertEqual(p.x, q.x, accuracy: accuracy, message, file: file, line: line)
            XCTAssertEqual(p.y, q.y, accuracy: accuracy, message, file: file, line: line)
        }
    }

    private func meanY(_ points: [Vec2]) -> Double { points.map(\.y).reduce(0, +) / Double(max(points.count, 1)) }

    func testAFasterFishsOutlineRepeatsSooner() {
        let length = 0.8
        for shape in FishShape.allCases {
            for phase in [0.0, 1.1, 2.7] {
                assertSame(AquariumPresenter.animatedOutline(shape, length: length, phase: phase, turn: 0.4, factor: 1),
                           AquariumPresenter.animatedOutline(shape, length: length, phase: phase + 2 * .pi, turn: 0.4,
                                                             factor: 1), "the outline repeats every 2π of phase")
            }
        }
        assertSame(AquariumPresenter.animatedTail(length: length, phase: 0.5, turn: 0, factor: 1),
                   AquariumPresenter.animatedTail(length: length, phase: 0.5 + 2 * .pi, turn: 0, factor: 1),
                   "the tail repeats every 2π of phase")
        // The simulation advances the phase by 2π × beats per second; the time one outline cycle takes is 1 / beats.
        func cycleSeconds(speed: Double) -> Double { 1 / (AquariumSimulation.tailBeatsPerLength * speed / length) }
        XCTAssertLessThan(cycleSeconds(speed: 2.0), cycleSeconds(speed: 1.0), "a faster fish repeats sooner")
        XCTAssertEqual(cycleSeconds(speed: 2.0), cycleSeconds(speed: 1.0) / 2, accuracy: 1e-12)
    }

    func testATurnBendsTheOutlineTowardTheTurn() {
        let length = 1.0, phase = 0.9
        for shape in FishShape.allCases {
            let straight = AquariumPresenter.animatedOutline(shape, length: length, phase: phase, turn: 0, factor: 1)
            let left = AquariumPresenter.animatedOutline(shape, length: length, phase: phase, turn: 2, factor: 1)
            let right = AquariumPresenter.animatedOutline(shape, length: length, phase: phase, turn: -2, factor: 1)
            // Index 6 is the back of the body (angle π); the nose (index 0) stays where it is.
            XCTAssertGreaterThan(left[6].y, straight[6].y + 0.01, "a left turn bends the back to the left (+y)")
            XCTAssertLessThan(right[6].y, straight[6].y - 0.01, "a right turn bends the back to the right (−y)")
            XCTAssertEqual(left[0].y, straight[0].y, accuracy: 1e-9, "the nose does not move")
        }
        let straightTail = AquariumPresenter.animatedTail(length: length, phase: phase, turn: 0, factor: 1)
        XCTAssertGreaterThan(meanY(AquariumPresenter.animatedTail(length: length, phase: phase, turn: 2, factor: 1)),
                             meanY(straightTail))
        XCTAssertLessThan(meanY(AquariumPresenter.animatedTail(length: length, phase: phase, turn: -2, factor: 1)),
                          meanY(straightTail))
        // The bend is capped at ±0.35 rad.
        XCTAssertEqual(AquariumPresenter.bendAngle(turn: 100, factor: 1), 0.35, accuracy: 1e-12)
        XCTAssertEqual(AquariumPresenter.bendAngle(turn: -100, factor: 1), -0.35, accuracy: 1e-12)
        XCTAssertEqual(AquariumPresenter.bendAngle(turn: 1, factor: 1), 0.12, accuracy: 1e-12)
        XCTAssertEqual(AquariumPresenter.bendAngle(turn: 100, factor: 0.5), 0.175, accuracy: 1e-12)
    }

    func testAFishSwimmingLeftIsTheMirrorOfOneSwimmingRight() {
        let centre = Vec2(5, 5)
        // The left swimmer's motion is the right swimmer's mirrored about x = 5: velocity, heading and turn mirror.
        let right = FishAgent(speciesId: "x", position: centre, velocity: Vec2(1, 0), heading: 0, animationPhase: 1.3,
                              turn: 1.5)
        let left = FishAgent(speciesId: "x", position: centre, velocity: Vec2(-1, 0), heading: .pi,
                             animationPhase: 1.3, turn: -1.5)
        for shape in FishShape.allCases {
            let r = AquariumPresenter.fishPolygons(right, shape: shape, length: 0.9, factor: 1)
            let l = AquariumPresenter.fishPolygons(left, shape: shape, length: 0.9, factor: 1)
            assertSame(l.body, r.body.map { Vec2(2 * centre.x - $0.x, $0.y) }, "the body is mirrored")
            assertSame(l.tail, r.tail.map { Vec2(2 * centre.x - $0.x, $0.y) }, "the tail is mirrored")
            // The right swimmer turns left (+y in the tank): its back bends to +y of the straight fish.
            let straight = AquariumPresenter.fishPolygons(
                FishAgent(speciesId: "x", position: centre, velocity: Vec2(1, 0), heading: 0, animationPhase: 1.3),
                shape: shape, length: 0.9, factor: 1)
            XCTAssertGreaterThan(r.body[6].y, straight.body[6].y)
        }
    }

    func testReduceMotionHalvesEveryPointsDisplacement() {
        let length = 0.7
        for shape in FishShape.allCases {
            for phase in [0.4, 2.0, 4.4] {
                let still = AquariumPresenter.animatedOutline(shape, length: length, phase: phase, turn: 0, factor: 0)
                assertSame(still, AquariumPresenter.outline(shape, length: length), "factor 0 is the straight fish")
                let full = AquariumPresenter.animatedOutline(shape, length: length, phase: phase, turn: 0, factor: 1)
                let half = AquariumPresenter.animatedOutline(shape, length: length, phase: phase, turn: 0, factor: 0.5)
                for i in still.indices {
                    XCTAssertEqual(half[i].y - still[i].y, (full[i].y - still[i].y) / 2, accuracy: 1e-12)
                    XCTAssertEqual(half[i].x, still[i].x, accuracy: 1e-12)
                }
                let tailStill = AquariumPresenter.animatedTail(length: length, phase: phase, turn: 0, factor: 0)
                let tailFull = AquariumPresenter.animatedTail(length: length, phase: phase, turn: 0, factor: 1)
                let tailHalf = AquariumPresenter.animatedTail(length: length, phase: phase, turn: 0, factor: 0.5)
                for i in tailStill.indices {
                    XCTAssertEqual(tailHalf[i].y - tailStill[i].y, (tailFull[i].y - tailStill[i].y) / 2,
                                   accuracy: 1e-12)
                }
            }
        }
        // The tail tips swing by 0.15 body lengths at full motion (sin(π/2) = 1, joint aside).
        let tips = AquariumPresenter.animatedTail(length: 1, phase: .pi / 2, turn: 0, factor: 1)
        let rest = AquariumPresenter.animatedTail(length: 1, phase: .pi / 2, turn: 0, factor: 0)
        XCTAssertEqual(tips[1].y - rest[1].y, 0.15, accuracy: 1e-12)
        XCTAssertEqual(tips[2].y - rest[2].y, 0.15, accuracy: 1e-12)
    }

    func testTwoMomentsOfASwimDrawDifferentOutlines() {
        for shape in FishShape.allCases {
            let a = AquariumPresenter.animatedOutline(shape, length: 1, phase: 0.3, turn: 0, factor: 1)
            let b = AquariumPresenter.animatedOutline(shape, length: 1, phase: 1.9, turn: 0, factor: 1)
            let largest = zip(a, b).map { abs($0.y - $1.y) }.max() ?? 0
            XCTAssertGreaterThan(largest, 0.01, "\(shape) moves between two moments")
        }
        let a = AquariumPresenter.animatedTail(length: 1, phase: 0.3, turn: 0, factor: 1)
        let b = AquariumPresenter.animatedTail(length: 1, phase: 1.9, turn: 0, factor: 1)
        XCTAssertGreaterThan(abs(a[1].y - b[1].y), 0.05, "the tail swings")
    }

    func testDecorPolygonsFollowRotationAndScale() {
        for shape in DecorShape.allCases {
            let base = AquariumPresenter.decorOutline(shape, size: 0.9, rotation: 0, scale: 1)
            XCTAssertGreaterThanOrEqual(base.count, 8)
            let width = (base.map(\.x).max() ?? 0) - (base.map(\.x).min() ?? 0)
            XCTAssertGreaterThan(width, 0.9 * 0.8, "\(shape) is about its size wide")
            XCTAssertLessThan(width, 0.9 * 1.02, "\(shape) is not much wider than its size")
            let doubled = AquariumPresenter.decorOutline(shape, size: 0.9, rotation: 0, scale: 2)
            assertSame(doubled, base.map { $0 * 2 }, "\(shape) scales with the piece's scale")
            let turned = AquariumPresenter.decorOutline(shape, size: 0.9, rotation: .pi / 2, scale: 1)
            assertSame(turned, base.map { Vec2(-$0.y, $0.x) }, "\(shape) turns with the piece's rotation")
            XCTAssertEqual(AquariumPresenter.decorOutline(shape, size: 0.9, rotation: 0.4, scale: 1.3),
                           AquariumPresenter.decorOutline(shape, size: 0.9, rotation: 0.4, scale: 1.3),
                           "\(shape) is deterministic")
        }
    }

    func testTheStarterDecorIsDrawnAndReduceMotionKeepsTheDigest() async throws {
        let full = ExperienceSession()
        let fullShell = try await AquariumTest.open(full)
        try AquariumTest.frames(full, 20)
        let reduced = ExperienceSession()
        let reducedShell = try await AquariumTest.open(reduced, reduceMotion: true)
        try AquariumTest.frames(reduced, 20)
        let core = try AquariumTest.core(fullShell)
        XCTAssertFalse(core.document.decor.isEmpty, "the Reef carries starter decor")
        XCTAssertEqual(fullShell.presenter.lastDecorDrawn, core.document.decor.count)
        XCTAssertEqual(reducedShell.presenter.lastSwayFactor, 0.5)
        XCTAssertEqual(core.document, try AquariumTest.core(reducedShell).document, "drawing never writes the state")
        XCTAssertEqual(try fullShell.engine.digest(), try reducedShell.engine.digest(),
                       "the digest does not depend on Reduce Motion")
        full.close()
        reduced.close()
    }

    // MARK: Feeding and decor editing (feature 070, T-A09-307)

    func testPelletsAreDrawnAndChangeTheFrame() async throws {
        let session = ExperienceSession()
        let shell = try await AquariumTest.open(session, size: CGSize(width: 640, height: 360))
        XCTAssertTrue(shell.handle(control: "motion.pause", values: [1]).isAccepted)
        let before = try AquariumTest.picture(session)
        XCTAssertEqual(shell.presenter.lastFoodDrawn, 0, "a starter habitat has no food")
        XCTAssertTrue(shell.handle(control: "food.drop", values: [0.5, 0.8]).isAccepted)
        let after = try AquariumTest.picture(session)
        let core = try AquariumTest.core(shell)
        XCTAssertEqual(core.document.food.count, Feeding.pelletsPerFeed)
        XCTAssertEqual(shell.presenter.lastFoodDrawn, core.document.food.count, "every pellet is drawn")
        XCTAssertNotEqual(StableHash.sha256Hex(before.rgba), StableHash.sha256Hex(after.rgba), "the pellets show")
        XCTAssertGreaterThan(AquariumTest.differingPixels(before.rgba, after.rgba), 0)
        session.close()
    }

    func testEveryGestureActionHasANativeControl() {
        let presenter = AquariumPresenter(experienceID: AquariumTest.id)
        XCTAssertEqual(presenter.gestureActions, ["food.drop", "decor.place", "decor.move"])
        XCTAssertEqual(presenter.nativeActions, Set(AquariumCore.actionIDs))
        XCTAssertEqual(GestureAlternatives.missing(gesture: presenter.gestureActions,
                                                   native: presenter.nativeActions), [])
    }

    func testTheDescriptionNamesPelletAndDecorCounts() async throws {
        XCTAssertEqual(AquariumPresenter.foodWords(0), "no food")
        XCTAssertEqual(AquariumPresenter.foodWords(1), "1 food pellet")
        XCTAssertEqual(AquariumPresenter.foodWords(3), "3 food pellets")
        XCTAssertEqual(AquariumPresenter.decorWords(1), "1 decoration")
        XCTAssertEqual(AquariumPresenter.decorWords(4), "4 decorations")
        let session = ExperienceSession()
        let shell = try await AquariumTest.open(session)
        XCTAssertTrue(shell.handle(control: "motion.pause", values: [1]).isAccepted)
        let decor = try AquariumTest.core(shell).document.decor.count
        XCTAssertGreaterThan(decor, 0, "the Reef carries starter decor")
        let start = shell.accessibilitySummary
        XCTAssertTrue(start.hasPrefix("Digital Aquarium: Reef, "), start)
        XCTAssertTrue(start.contains(", \(AquariumPresenter.decorWords(decor)), no food, lighting soft"), start)

        XCTAssertTrue(shell.handle(control: "food.drop", values: [0.5, 0.8]).isAccepted)
        let fed = shell.accessibilitySummary
        XCTAssertTrue(fed.contains(", \(Feeding.pelletsPerFeed) food pellets, "), fed)
        XCTAssertNotEqual(fed, start)

        XCTAssertTrue(shell.handle(control: "decor.remove", values: [0]).isAccepted)
        let removed = shell.accessibilitySummary
        XCTAssertTrue(removed.contains(", \(AquariumPresenter.decorWords(decor - 1)), "), removed)
        XCTAssertNotEqual(removed, fed)
        XCTAssertTrue(removed.hasSuffix("paused."), removed)
        session.close()
    }

    func testAQuickTapOnTheCanvasDropsFoodOnce() async throws {
        let session = ExperienceSession()
        let shell = try await AquariumTest.open(session)
        XCTAssertTrue(shell.handle(control: "motion.pause", values: [1]).isAccepted)
        let decorBefore = try AquariumTest.core(shell).document.decor.count
        let view = Vec2(Double(size.width), Double(size.height))
        let point = Vec2(80, 30)
        shell.presenter.pointer(PointerEvent(id: 1, phase: .began, location: point, timestamp: 10.0), viewSize: view,
                                port: shell.port)
        XCTAssertTrue(try AquariumTest.core(shell).document.food.isEmpty, "nothing before the finger lifts")
        shell.presenter.pointer(PointerEvent(id: 1, phase: .ended, location: point, timestamp: 10.1), viewSize: view,
                                port: shell.port)
        let core = try AquariumTest.core(shell)
        XCTAssertEqual(core.document.food.count, Feeding.pelletsPerFeed, "exactly one food.drop")
        XCTAssertEqual(core.document.decor.count, decorBefore, "a tap places nothing")
        XCTAssertTrue(shell.accessibilitySummary.contains("\(Feeding.pelletsPerFeed) food pellets"))
        session.close()
    }

    /// The experience draws only through the `RenderContext` the host hands it: none of its sources creates a
    /// context, a display, a device or a render host, or calls GL directly.
    func testTheExperienceNeverCreatesAGraphicsContextOfItsOwn() throws {
        let directory = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Experience")
        let files = try XCTUnwrap(FileManager.default.enumerator(at: directory, includingPropertiesForKeys: nil))
            .compactMap { $0 as? URL }.filter { $0.pathExtension == "swift" }
        XCTAssertGreaterThanOrEqual(files.count, 4)
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
    // MARK: Water effects and depth (feature 071, T-A09-405)

    /// The largest distance of `points` (world pixels) from `centre` (habitat units) in habitat units at `scale`.
    private func reach(_ primitive: Primitive?, centre: Vec2, scale: Double) -> Double {
        guard case .polygon(let points)? = primitive else { return 0 }
        let c = AquariumPresenter.world(centre, scale: scale)
        return points.map { ($0 - c).length }.max().map { $0 / scale } ?? 0
    }

    /// The RGB distance of two colours.
    private func distance(_ a: Vec4, _ b: Vec4) -> Double {
        ((a.x - b.x) * (a.x - b.x) + (a.y - b.y) * (a.y - b.y) + (a.z - b.z) * (a.z - b.z)).squareRoot()
    }

    /// The red + green + blue sums of the pixels of the gravel strip x 0.5…15.5, y 0.1…0.5 (habitat units) of a
    /// frame read bottom row first.
    private func gravelStrip(_ frame: (rgba: [UInt8], width: Int, height: Int)) -> [Int] {
        let w = Double(frame.width), h = Double(frame.height)
        let s = AquariumPresenter.scale(width: w, height: h)
        let originX = w / 2 - 8 * s, originY = h / 2 - 4.5 * s
        var sums: [Int] = []
        for row in Int(originY + 0.1 * s)..<Int(originY + 0.5 * s) {
            for column in Int(originX + 0.5 * s)..<Int(originX + 15.5 * s) {
                let i = (row * frame.width + column) * 4
                sums.append(Int(frame.rgba[i]) + Int(frame.rgba[i + 1]) + Int(frame.rgba[i + 2]))
            }
        }
        return sums
    }

    func testBackLayersAreDrawnFirstSmallerAndTintedTowardTheWater() throws {
        let presenter = AquariumPresenter(experienceID: AquariumTest.id)
        let core = AquariumCore(seed: 7)
        let document = core.document
        XCTAssertGreaterThanOrEqual(document.fish.count, 3)
        let width = 1600.0, height = 900.0, scale = AquariumPresenter.scale(width: width, height: height)
        presenter.layOut(core, width: width, height: height)
        // Research D2: back plants 2, back fish 3, middle plants 4, decor 5, pellets 6, middle fish 7, front plants 8,
        // front fish 9, bubbles and motes 10; a tail shares its body's z.
        XCTAssertEqual(presenter.plantNodes.prefix(3).map { $0[0].z }, [2, 4, 8])
        XCTAssertEqual(presenter.bodyNodes.prefix(3).map(\.z), [3, 7, 9])
        XCTAssertEqual(presenter.tailNodes.map(\.z), presenter.bodyNodes.map(\.z))
        XCTAssertEqual(Set(presenter.bubbleNodes.map(\.z) + presenter.moteNodes.map(\.z)), [10])
        XCTAssertEqual(presenter.water.z, 0)
        XCTAssertEqual(presenter.gravel.z, 1)
        for index in document.fish.indices {
            let fish = document.fish[index]
            let species = try XCTUnwrap(AquariumCore.catalog.species(id: fish.speciesId))
            let layer = WaterEffects.layer(index: index)
            // The drawn body reaches as far from the fish's position as an unscaled one times the layer's scale.
            let full = AquariumPresenter.fishPolygons(fish, shape: species.shape, length: species.length, factor: 1)
            let fullReach = reach(.polygon(full.body.map { AquariumPresenter.world($0, scale: scale) }),
                                  centre: fish.position, scale: scale)
            let drawn = reach(presenter.bodyNodes[index].primitive, centre: fish.position, scale: scale)
            XCTAssertEqual(drawn / fullReach, WaterEffects.scale(layer: layer), accuracy: 1e-9, "fish \(index)")
            let water = AquariumPresenter.waterColor(document)
            let plain = AquariumPresenter.lit(species.bodyColor, level: document.lighting)
            if layer == 2 {
                XCTAssertEqual(presenter.bodyNodes[index].color, plain, "a front fish keeps its colour")
            } else {
                XCTAssertLessThan(distance(presenter.bodyNodes[index].color, water), distance(plain, water),
                                  "fish \(index) in layer \(layer) is tinted toward the water")
            }
        }
        XCTAssertEqual(WaterEffects.scale(layer: 0) / WaterEffects.scale(layer: 2), 0.75, accuracy: 1e-12)
        // A back plant is paler toward the water than the same kind in front.
        let plants = document.plants
        let kind = try XCTUnwrap(AquariumCore.catalog.plant(id: plants[0].kindId))
        XCTAssertLessThan(distance(presenter.plantNodes[0][0].color, AquariumPresenter.waterColor(document)),
                          distance(AquariumPresenter.lit(kind.color, level: document.lighting),
                                   AquariumPresenter.waterColor(document)))
    }

    func testTheCausticsChangeOverTimeAndHoldUnderReduceMotion() async throws {
        let big = CGSize(width: 320, height: 180)
        let full = ExperienceSession()
        let fullShell = try await AquariumTest.open(full, size: big)
        let a = try AquariumTest.picture(full)
        XCTAssertTrue(fullShell.presenter.lastCausticsDrawn, "the caustics shader draws the water and gravel")
        XCTAssertFalse(fullShell.presenter.gravel.isVisible, "the gravel rectangle is hidden under the caustics")
        assertDrawn(fullShell, a, "caustics")
        let timeA = try XCTUnwrap(fullShell.presenter.caustics).time
        try AquariumTest.frames(full, 59)
        let b = try AquariumTest.picture(full)
        let timeB = try XCTUnwrap(fullShell.presenter.caustics).time
        XCTAssertEqual(timeB - timeA, 0.4, accuracy: 1e-9, "60 steps are 0.4 of pattern time")
        let stripA = gravelStrip(a), stripB = gravelStrip(b)
        XCTAssertFalse(stripA.isEmpty)
        let changed = zip(stripA, stripB).filter { abs($0 - $1) > 3 }.count
        XCTAssertGreaterThan(changed, stripA.count / 20, "the light pattern on the gravel moves")
        full.close()

        let reduced = ExperienceSession()
        let reducedShell = try await AquariumTest.open(reduced, reduceMotion: true, size: big)
        let c = try AquariumTest.picture(reduced)
        try AquariumTest.frames(reduced, 59)
        let d = try AquariumTest.picture(reduced)
        XCTAssertEqual(try XCTUnwrap(reducedShell.presenter.caustics).time, 0, "Reduce Motion holds the pattern")
        XCTAssertGreaterThan(try AquariumTest.core(reducedShell).step, 59)
        XCTAssertEqual(gravelStrip(c), gravelStrip(d), "the gravel's light pattern holds under Reduce Motion")
        reduced.close()
    }

    func testDimCausticsAreFainterThanBright() async throws {
        XCTAssertEqual([0, 1, 2, 7].map { CausticsScene.strength(lighting: $0) }, [0.04, 0.07, 0.10, 0.07])
        let session = ExperienceSession()
        let shell = try await AquariumTest.open(session, size: CGSize(width: 320, height: 180))
        try AquariumTest.frames(session, 30)
        XCTAssertTrue(shell.handle(control: "motion.pause", values: [1]).isAccepted)
        func pattern() throws -> Double {
            let strip = gravelStrip(try AquariumTest.picture(session))
            let floor = strip.min() ?? 0
            return Double(strip.reduce(0) { $0 + $1 - floor }) / Double(max(strip.count, 1))
        }
        XCTAssertTrue(shell.handle(control: "lighting.level", values: [0]).isAccepted)
        let dim = try pattern()
        XCTAssertEqual(try XCTUnwrap(shell.presenter.caustics).strength, 0.04, accuracy: 1e-12)
        XCTAssertTrue(shell.handle(control: "lighting.level", values: [2]).isAccepted)
        let bright = try pattern()
        XCTAssertEqual(try XCTUnwrap(shell.presenter.caustics).strength, 0.10, accuracy: 1e-12)
        XCTAssertGreaterThan(dim, 0, "the pattern shows at dim lighting")
        XCTAssertLessThan(dim, bright, "dim caustics are fainter than bright ones")
        session.close()
    }

    func testABrokenCausticsShaderFallsBackAndTheFrameStillDraws() async throws {
        let session = ExperienceSession()
        let shell = try await AquariumTest.open(session, causticsFragment: "precision highp float; not glsl at all")
        try AquariumTest.frames(session, 5)
        let frame = try AquariumTest.picture(session)
        let caustics = try XCTUnwrap(shell.presenter.caustics)
        XCTAssertNotNil(caustics.errorMessage, "the broken shader reports a diagnostic")
        XCTAssertFalse(caustics.isAvailable)
        XCTAssertFalse(shell.presenter.lastCausticsDrawn, "the Phase 03 water and gravel are drawn instead")
        XCTAssertTrue(shell.presenter.water.isVisible)
        XCTAssertTrue(shell.presenter.gravel.isVisible)
        XCTAssertEqual(session.state, .running, "everything else works")
        assertDrawn(shell, frame, "fallback")
        XCTAssertGreaterThan(shell.presenter.lastFishDrawn, 0)
        XCTAssertGreaterThan(shell.presenter.lastBubblesDrawn, 0)
        session.close()
        XCTAssertEqual(session.hostsAlive, 0)
    }

    func testBubblesAndMotesAreDrawnAtLeastOnePixelWide() async throws {
        let session = ExperienceSession()
        let shell = try await AquariumTest.open(session)
        try AquariumTest.frames(session, 100)
        let presenter = shell.presenter
        let visible = presenter.bubbleNodes.filter { $0.primitive != nil }.count
        XCTAssertGreaterThan(visible, 0, "bubbles rise from the Reef's vents")
        XCTAssertLessThanOrEqual(visible, WaterEffects.maxBubbles)
        XCTAssertEqual(presenter.lastBubblesDrawn, visible)
        XCTAssertEqual(presenter.lastMotesDrawn, WaterEffects.moteCount)
        session.close()

        // A tiny canvas (1 pixel per unit): every particle keeps a radius of at least one pixel.
        let tiny = AquariumPresenter(experienceID: AquariumTest.id)
        var core = AquariumCore(seed: 7)
        for step in 0..<100 { core.update(step: step) }
        tiny.layOut(core, width: 16, height: 9)
        for node in tiny.bubbleNodes + tiny.moteNodes {
            guard case .circle(let radius)? = node.primitive else { continue }
            XCTAssertGreaterThanOrEqual(radius, 1)
        }
        XCTAssertGreaterThan(tiny.lastBubblesDrawn, 0)
    }

    func testTheDigestDoesNotDependOnReduceMotionOrTheEffects() async throws {
        let full = ExperienceSession()
        let fullShell = try await AquariumTest.open(full)
        try AquariumTest.frames(full, 100)
        let reduced = ExperienceSession()
        let reducedShell = try await AquariumTest.open(reduced, reduceMotion: true)
        try AquariumTest.frames(reduced, 100)
        XCTAssertGreaterThan(fullShell.presenter.lastBubblesDrawn, 0)
        XCTAssertEqual(try AquariumTest.core(fullShell).step, try AquariumTest.core(reducedShell).step)
        XCTAssertEqual(try AquariumTest.core(fullShell).document, try AquariumTest.core(reducedShell).document)
        XCTAssertEqual(try fullShell.engine.digest(), try reducedShell.engine.digest(),
                       "bubbles, motes, caustics and Reduce Motion never touch the state")
        full.close()
        reduced.close()
    }

    func testUnknownPlantAndDecorKindsAreSkippedWhenDrawn() throws {
        let start = AquariumCore(seed: 7).state
        var document = start.document
        let knownPlants = document.plants.count, knownDecor = document.decor.count
        document.plants.append(PlantPlacement(kindId: "no-such-plant", x: 6))
        document.decor.append(DecorPlacement(kindId: "no-such-decor", position: Vec2(7, 1.2)))
        document.habitatIndex = 99  // an unknown habitat: no vents, so no bubbles
        let state = AquariumState(document: document, step: 120, paused: false, random: start.random)
        let core = try AquariumCore(seed: 7, state: state)
        let presenter = AquariumPresenter(experienceID: AquariumTest.id)
        presenter.layOut(core, width: 640, height: 360)
        XCTAssertEqual(presenter.lastPlantsDrawn, knownPlants, "the unknown plant is skipped")
        XCTAssertEqual(presenter.lastDecorDrawn, knownDecor, "the unknown decoration is skipped")
        XCTAssertEqual(presenter.lastFishDrawn, document.fish.count)
        XCTAssertEqual(presenter.lastBubblesDrawn, 0, "an unknown habitat has no vents")
        XCTAssertEqual(presenter.lastMotesDrawn, WaterEffects.moteCount)
        XCTAssertTrue(presenter.describe(core).hasPrefix("Digital Aquarium: Aquarium, "))
    }
}
