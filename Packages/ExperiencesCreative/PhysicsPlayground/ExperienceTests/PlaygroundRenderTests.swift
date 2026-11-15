// PlaygroundRenderTests — feature 082 (A11-P01) T-A11-104 (FR-A11-120, FR-A11-121; clarification 5; SC-A11-101).
// Physics Playground rendered inside the one app's session host on the simulator, short runs only (each test under
// 10 s, no wall-clock assertion): the first frame is non-blank and not black with its stage probe holding; frames
// differ while bodies fall and a paused world draws the same frame; drawing never changes the digest (a drawn session
// equals the bare replay of the same actions at the same steps); circles, boxes and the static ledge are drawn at their
// physics size and pose (the radius line at the body's angle, the box corners rotated, the static body darker and
// hatched); the stage and walls are letterboxed into the canvas; a body drawn in a frame shows its colour at its centre
// pixel; the description names the body count, running or paused and the time scale; the probe steps aside for
// bodies near it; a failed draw reaches the session; and the experience's sources never create a graphics context of
// their own.
//
// Feature 083 (A11-P02) T-A11-204 (FR-A11-220; clarification 5): springs are drawn under the bodies as 8-coil zigzags
// 0.03 m wide from anchor to anchor at the physics anchors (a body anchor through the body's pose, a world anchor
// fixed), with anchor dots; the description adds the springs, stiffness, gravity and drag; the probe also steps aside
// for a spring passing near it.
import Foundation
import XCTest
@testable import PhysicsPlaygroundExperience
import PhysicsPlaygroundCore
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreRendering
import VisualCoreScenes
import VisualCoreSimulation

@MainActor
final class PlaygroundRenderTests: XCTestCase {
    /// 120 × 100 points: 10 points per metre for the 12 × 10 m view.
    private let size = CGSize(width: 120, height: 100)

    private func assertDrawn(_ shell: ExperienceShell<PlaygroundPresenter>,
                             _ frame: (rgba: [UInt8], width: Int, height: Int), _ name: String) {
        XCTAssertGreaterThan(frame.width, 0)
        XCTAssertTrue(FrameChecks.isNonBlank(frame.rgba, width: frame.width, height: frame.height), "\(name) not blank")
        XCTAssertFalse(FrameChecks.isBlack(frame.rgba, width: frame.width, height: frame.height), "\(name) not black")
        for probe in shell.frameProbes {
            let found = FrameChecks.probe(probe, rgba: frame.rgba, width: frame.width, height: frame.height)
            XCTAssertEqual(found?.rawValue, probe.expected, "\(name) \(probe.name)")
        }
    }

    func testTheFirstFrameIsNonBlankWithItsStageProbe() async throws {
        let session = ExperienceSession()
        let shell = try await PlaygroundTest.open(session, size: size)
        let first = try PlaygroundTest.picture(session)
        XCTAssertFalse(shell.frameProbes.isEmpty, "the stage near the floor is clear of the starting bodies")
        assertDrawn(shell, first, "first frame")
        session.close()
        XCTAssertEqual(session.hostsAlive, 0)
    }

    func testFramesDifferWhileBodiesFallAndAPausedWorldHolds() async throws {
        let session = ExperienceSession()
        let shell = try await PlaygroundTest.open(session, size: size)
        let start = try PlaygroundTest.picture(session)
        try PlaygroundTest.frames(session, 40)
        let later = try PlaygroundTest.picture(session)
        assertDrawn(shell, later, "later")
        XCTAssertNotEqual(StableHash.sha256Hex(start.rgba), StableHash.sha256Hex(later.rgba), "bodies fall")
        XCTAssertGreaterThan(PlaygroundTest.differingPixels(start.rgba, later.rgba), 0)

        XCTAssertTrue(shell.handle(control: "world.pause", values: [1]).isAccepted)
        let held = try PlaygroundTest.picture(session)
        try PlaygroundTest.frames(session, 10)
        let stillHeld = try PlaygroundTest.picture(session)
        XCTAssertEqual(StableHash.sha256Hex(held.rgba), StableHash.sha256Hex(stillHeld.rgba), "a paused frame holds")
        session.close()
    }

    func testDrawingNeverChangesTheDigest() async throws {
        let session = ExperienceSession()
        let shell = try await PlaygroundTest.open(session, size: size)
        var entries: [ScenarioStep] = []
        var last = 0
        func send(_ control: String, _ values: [Double]) {
            let step = shell.engine.stepIndex
            XCTAssertTrue(shell.handle(control: control, values: values).isAccepted)
            entries.append(ScenarioStep(steps: step - last, action: ScriptedAction(control, values)))
            last = step
        }
        send("world.drop", [0])
        try PlaygroundTest.frames(session, 25)
        send("world.timeScale", [3])
        try PlaygroundTest.frames(session, 20)
        send("world.drop", [1])
        try PlaygroundTest.frames(session, 25)
        let drawnSteps = shell.engine.stepIndex
        entries.append(ScenarioStep(steps: drawnSteps - last))
        let bare = PlaygroundCore.played(seed: 7, entries: entries)
        XCTAssertEqual(try PlaygroundTest.core(shell), bare, "the drawn session equals the undrawn replay")

        // Drawing a paused world again and again changes nothing.
        XCTAssertTrue(shell.handle(control: "world.pause", values: [1]).isAccepted)
        let digest = try shell.engine.digest()
        try PlaygroundTest.frames(session, 15)
        _ = shell.accessibilitySummary
        _ = shell.frameProbes
        XCTAssertEqual(try shell.engine.digest(), digest)
        session.close()
    }

    func testBodiesAreDrawnAtTheirPhysicsSizeAndPose() throws {
        let presenter = PlaygroundPresenter(experienceID: PlaygroundTest.id)
        let core = try playgroundCore(playgroundSampleWorld())
        let copy = core
        presenter.layOut(core, width: 120, height: 100)
        XCTAssertEqual(core, copy, "drawing reads the core only")
        let s = presenter.lastScale
        XCTAssertEqual(s, 10, accuracy: 1e-12, "the 12 × 10 m view fills a 120 × 100 canvas")
        XCTAssertEqual(presenter.lastBodiesDrawn, 3)
        XCTAssertEqual(presenter.lastStaticDrawn, 1)
        let world = { (p: Vec2) in PlaygroundPresenter.world(p, scale: s) }
        func close(_ a: Vec2, _ b: Vec2, _ message: String) {
            XCTAssertEqual(a.x, b.x, accuracy: 1e-9, message)
            XCTAssertEqual(a.y, b.y, accuracy: 1e-9, message)
        }

        // The stage and the walls: 10 × 8 m and four 1 m walls around it.
        XCTAssertEqual(presenter.stage.primitive, .rect(Vec2(100, 80)))
        close(presenter.stage.position, .zero, "the stage centred")
        XCTAssertEqual(presenter.wallNodes[0].primitive, .rect(Vec2(120, 10)), "the floor")
        close(presenter.wallNodes[0].position, Vec2(0, -45), "the floor below the stage")
        XCTAssertEqual(presenter.wallNodes[2].primitive, .rect(Vec2(10, 100)), "the left wall")
        close(presenter.wallNodes[2].position, Vec2(-55, 0), "the left wall")

        // The wood circle: radius 0.5 m, its ring at the radius, its radius line at the body's angle.
        XCTAssertEqual(presenter.fillNodes[1].primitive, .circle(0.5 * s), "the circle at its radius")
        close(presenter.fillNodes[1].position, world(Vec2(3, 5)), "the circle at its centre")
        guard case .polyline(let ring, _)? = presenter.edgeNodes[1].primitive else { return XCTFail("no ring") }
        XCTAssertEqual(ring.count, PlaygroundPresenter.ringPoints)
        for point in ring { XCTAssertEqual((point - world(Vec2(3, 5))).length, 0.5 * s, accuracy: 1e-9) }
        guard case .line(let from, let to, _)? = presenter.markNodes[1].primitive else { return XCTFail("no mark") }
        close(from, world(Vec2(3, 5)), "the radius line starts at the centre")
        close(to, world(Vec2(3 + 0.5 * cos(0.6), 5 + 0.5 * sin(0.6))), "and ends on the rim at the body's angle")
        let wood = try XCTUnwrap(PlaygroundCore.catalog.material(id: "wood"))
        XCTAssertEqual(presenter.fillNodes[1].color, PlaygroundPresenter.vector(wood.fill))
        XCTAssertEqual(presenter.edgeNodes[1].color, PlaygroundPresenter.vector(wood.edge))
        XCTAssertNil(presenter.hatchNodes[1].primitive, "a dynamic body is not hatched")

        // The steel box: half-extents 0.6 × 0.3 m rotated by 0.4 rad.
        guard case .polygon(let corners)? = presenter.fillNodes[2].primitive else { return XCTFail("no box") }
        XCTAssertEqual(corners.count, 4)
        let c = cos(0.4), sn = sin(0.4)
        let expected = [Vec2(-0.6, -0.3), Vec2(0.6, -0.3), Vec2(0.6, 0.3), Vec2(-0.6, 0.3)].map {
            world(Vec2(7 + $0.x * c - $0.y * sn, 3 + $0.x * sn + $0.y * c))
        }
        for (corner, want) in zip(corners, expected) { close(corner, want, "a rotated corner") }
        XCTAssertEqual((corners[1] - corners[0]).length, 1.2 * s, accuracy: 1e-9, "the box is 1.2 m wide")
        XCTAssertEqual((corners[2] - corners[1]).length, 0.6 * s, accuracy: 1e-9, "and 0.6 m high")
        guard case .polyline(let outline, _)? = presenter.edgeNodes[2].primitive else { return XCTFail("no outline") }
        XCTAssertEqual(outline.count, 5, "a closed outline")
        XCTAssertNil(presenter.markNodes[2].primitive)

        // The static ledge: darker than the same material dynamic, and hatched inside its shape.
        let steel = try XCTUnwrap(PlaygroundCore.catalog.material(id: "steel"))
        XCTAssertEqual(presenter.fillNodes[2].color, PlaygroundPresenter.vector(steel.fill))
        XCTAssertEqual(presenter.fillNodes[0].color,
                       PlaygroundPresenter.darkened(PlaygroundPresenter.vector(steel.fill),
                                                    PlaygroundPresenter.staticFillFactor))
        XCTAssertLessThan(presenter.fillNodes[0].color.x, presenter.fillNodes[2].color.x)
        guard case .polyline(let hatch, _)? = presenter.hatchNodes[0].primitive else { return XCTFail("no hatch") }
        XCTAssertGreaterThanOrEqual(hatch.count, 4)
        let half = StartingScene.ledgeHalfExtents, center = world(StartingScene.ledgeCenter)
        for point in hatch {
            XCTAssertLessThanOrEqual(abs(point.x - center.x), half.x * s + 1e-9, "the hatch stays inside")
            XCTAssertLessThanOrEqual(abs(point.y - center.y), half.y * s + 1e-9, "the hatch stays inside")
        }

        // Unused slots draw nothing; masks cover outside the view.
        XCTAssertNil(presenter.fillNodes[3].primitive)
        XCTAssertNil(presenter.edgeNodes[47].primitive)
    }

    func testTheViewIsLetterboxedIntoAnyCanvas() throws {
        let presenter = PlaygroundPresenter(experienceID: PlaygroundTest.id)
        let core = try playgroundCore(playgroundSampleWorld())
        presenter.layOut(core, width: 390, height: 844)
        XCTAssertEqual(presenter.lastScale, 32.5, accuracy: 1e-12, "a portrait canvas fits the 12 m width")
        presenter.layOut(core, width: 1000, height: 300)
        XCTAssertEqual(presenter.lastScale, 30, accuracy: 1e-12, "a wide canvas fits the 10 m height")
        XCTAssertEqual(presenter.fillNodes[1].primitive, .circle(0.5 * 30), "the same physics size at any scale")
        XCTAssertEqual(PlaygroundPresenter.scale(width: 120, height: 100), 10, accuracy: 1e-12)
    }

    func testADrawnBodyShowsItsColourAtItsCentre() async throws {
        let session = ExperienceSession()
        let shell = try await PlaygroundTest.open(session, size: size)
        XCTAssertTrue(shell.handle(control: "world.pause", values: [1]).isAccepted)
        let core = try PlaygroundTest.core(shell)
        let frame = try PlaygroundTest.picture(session)
        assertDrawn(shell, frame, "paused frame")
        let scale = Double(frame.width) / PlaygroundPresenter.viewWidth
        // The ledge (static, never moves) and every dynamic body: the pixel at its centre has its fill colour.
        for body in core.world.bodies {
            let x = Int(((body.position.x - PlaygroundPresenter.viewCenter.x) * scale + Double(frame.width) / 2)
                .rounded(.down))
            let y = Int((Double(frame.height) / 2 - (body.position.y - PlaygroundPresenter.viewCenter.y) * scale)
                .rounded(.down))
            let pixel = PlaygroundTest.pixel(frame, x: x, y: y)
            XCTAssertEqual(pixel.count, 4)
            let fill = PlaygroundPresenter.colors(body).fill
            let want = [fill.x, fill.y, fill.z].map { Int(($0 * 255).rounded()) }
            // A static body's hatch line or a radius line may pass the centre; then the edge colour is there.
            let edge = PlaygroundPresenter.colors(body).edge
            let wantEdge = [edge.x, edge.y, edge.z].map { Int(($0 * 255).rounded()) }
            let got = pixel.prefix(3).map(Int.init)
            let near = { (a: [Int], b: [Int]) in zip(a, b).allSatisfy { abs($0 - $1) <= 24 } }
            XCTAssertTrue(near(got, want) || near(got, wantEdge), "body \(body.id) at (\(x), \(y)): \(got)")
        }
        session.close()
    }

    func testTheDescriptionNamesBodiesStateAndTimeScale() async throws {
        var world = playgroundSampleWorld()
        XCTAssertEqual(PlaygroundPresenter.description(world),
                       "Physics Playground: 3 bodies, running, normal speed (time scale 1×); "
                       + "no springs, stiffness medium, gravity Earth, drag low.")
        world.paused = true
        world.timeScaleIndex = 0
        XCTAssertTrue(WorldSimulation.setGravityLevel(&world, 1))
        XCTAssertTrue(WorldSimulation.setDragLevel(&world, 2))
        XCTAssertTrue(WorldSimulation.setStiffnessLevel(&world, 3))
        world.springs = [WorldSpring(id: 0, a: .world(Vec2(5, 7.5)), b: .body(1), restLength: 1)]
        XCTAssertEqual(PlaygroundPresenter.description(world),
                       "Physics Playground: 3 bodies, paused, quarter speed (time scale ¼×); "
                       + "1 spring, stiffness very stiff, gravity Moon, drag high.")
        world.springs = []
        world.bodies = [world.bodies[0]]
        world.timeScaleIndex = 1
        XCTAssertTrue(WorldSimulation.setGravityLevel(&world, 0))
        XCTAssertTrue(WorldSimulation.setDragLevel(&world, 0))
        XCTAssertTrue(WorldSimulation.setStiffnessLevel(&world, 0))
        XCTAssertEqual(PlaygroundPresenter.description(world),
                       "Physics Playground: 1 body, paused, half speed (time scale ½×); "
                       + "no springs, stiffness soft, gravity off, drag none.")
        XCTAssertEqual(PlaygroundPresenter.description(PlaygroundCore(seed: 7).world),
                       "Physics Playground: 10 bodies, running, normal speed (time scale 1×); "
                       + "2 springs, stiffness medium, gravity Earth, drag low.")
        XCTAssertEqual(PlaygroundPresenter.bodyWords(0), "no bodies")
        XCTAssertEqual(PlaygroundPresenter.springWords(0), "no springs")
        XCTAssertEqual(PlaygroundPresenter.springWords(2), "2 springs")
        XCTAssertEqual(PlaygroundPresenter.stiffnessWord(2), "stiff")

        // The pickers' titles and spoken values.
        XCTAssertEqual(PlaygroundPresenter.gravityTitles, ["Off", "Moon", "Earth"])
        XCTAssertEqual(PlaygroundPresenter.dragTitles, ["None", "Low", "High"])
        XCTAssertEqual(PlaygroundPresenter.stiffnessTitles, ["Soft", "Medium", "Stiff", "Very stiff"])
        XCTAssertEqual((0...2).map(PlaygroundPresenter.gravityValue),
                       ["Off", "Moon, 1.62 metres per second squared", "Earth, 9.81 metres per second squared"])
        XCTAssertEqual((0...2).map(PlaygroundPresenter.dragValue),
                       ["None", "Low, 0.05 per second", "High, 1 per second"])
        XCTAssertEqual((0...3).map(PlaygroundPresenter.stiffnessValue),
                       ["Soft, 20 newtons per metre", "Medium, 60 newtons per metre", "Stiff, 150 newtons per metre",
                        "Very stiff, 400 newtons per metre"])
        XCTAssertEqual(PlaygroundPresenter.gravityValue(3), "Unknown")
        XCTAssertEqual(PlaygroundControls.sentence("7 bodies, running, normal speed"),
                       "7 bodies, running, normal speed")
        XCTAssertEqual(PlaygroundControls.sentence(""), "Loading")
        XCTAssertTrue(PlaygroundControls.note.contains("educational approximation"))
        XCTAssertTrue(PlaygroundControls.canDrop(bodyCount: 47))
        XCTAssertFalse(PlaygroundControls.canDrop(bodyCount: 48))

        let session = ExperienceSession()
        let shell = try await PlaygroundTest.open(session, size: size)
        XCTAssertTrue(shell.accessibilitySummary.contains("10 bodies"))
        XCTAssertTrue(shell.accessibilitySummary.contains("2 springs, stiffness medium, gravity Earth, drag low"))
        XCTAssertTrue(shell.handle(control: "world.pause", values: [1]).isAccepted)
        XCTAssertTrue(shell.accessibilitySummary.contains("paused"))
        XCTAssertTrue(shell.handle(control: "world.stiffness", values: [0]).isAccepted)
        XCTAssertTrue(shell.handle(control: "world.gravity", values: [1]).isAccepted)
        XCTAssertTrue(shell.handle(control: "world.drag", values: [2]).isAccepted)
        XCTAssertTrue(shell.accessibilitySummary.contains("stiffness soft, gravity Moon, drag high"),
                      shell.accessibilitySummary)
        XCTAssertEqual(shell.presenter.mirror.stiffnessLevel, 0)
        XCTAssertEqual(shell.presenter.mirror.gravityLevel, 1)
        XCTAssertEqual(shell.presenter.mirror.dragLevel, 2)
        XCTAssertEqual(shell.presenter.mirror.forces, "2 springs, stiffness soft, gravity Moon, drag high")
        XCTAssertTrue(shell.handle(control: "world.reset").isAccepted)
        XCTAssertTrue(shell.accessibilitySummary.contains("running"))
        XCTAssertTrue(shell.accessibilitySummary.contains("stiffness medium, gravity Earth, drag low"))
        XCTAssertEqual(shell.port.identifier("drop-circle"), "experience.a11.physics-playground.drop-circle")
        XCTAssertEqual(shell.port.identifier("gravity"), "experience.a11.physics-playground.gravity")
        XCTAssertEqual(shell.port.identifier("drag"), "experience.a11.physics-playground.drag")
        XCTAssertEqual(shell.port.identifier("stiffness"), "experience.a11.physics-playground.stiffness")
        session.close()
    }

    /// T-A11-204 (FR-A11-220): each spring is an 8-coil zigzag from its world anchor A to its world anchor B at the
    /// physics positions — a body anchor through the body's pose, a world anchor fixed — 0.03 m wide (at least a
    /// pixel), under the bodies, with a dot at each anchor; unused slots draw nothing.
    func testSpringsAreDrawnAtTheirPhysicsAnchors() throws {
        let presenter = PlaygroundPresenter(experienceID: PlaygroundTest.id)
        var world = playgroundSampleWorld()
        // A world anchor to a point off the rotated wood circle's centre, and a spring between the circle and the box.
        world.springs = [
            WorldSpring(id: 0, a: .world(Vec2(5, 7.5)), b: .body(1, local: Vec2(0, 0.5)), restLength: 1.5),
            WorldSpring(id: 1, a: .body(1), b: .body(2, local: Vec2(0.6, 0)), restLength: 2),
        ]
        world.nextSpringId = 2
        XCTAssertEqual(world.validate(), [])
        let core = try playgroundCore(world)
        presenter.layOut(core, width: 1200, height: 1000)
        let s = presenter.lastScale
        XCTAssertEqual(s, 100, accuracy: 1e-12)
        XCTAssertEqual(presenter.lastSpringsDrawn, 2)
        let map = { (p: Vec2) in PlaygroundPresenter.world(p, scale: s) }
        func close(_ a: Vec2, _ b: Vec2, _ message: String) {
            XCTAssertEqual(a.x, b.x, accuracy: 1e-9, message)
            XCTAssertEqual(a.y, b.y, accuracy: 1e-9, message)
        }
        // The physics anchors: the circle's local (0, 0.5) turned by its angle 0.6; the box's local (0.6, 0) by 0.4.
        let circleTop = Vec2(3 - 0.5 * sin(0.6), 5 + 0.5 * cos(0.6))
        let boxSide = Vec2(7 + 0.6 * cos(0.4), 3 + 0.6 * sin(0.4))
        let ends = [(Vec2(5, 7.5), circleTop), (Vec2(3, 5), boxSide)]
        for (slot, (a, b)) in ends.enumerated() {
            let anchors = try XCTUnwrap(PlaygroundPresenter.anchors(world.springs[slot], in: world))
            close(anchors.a, a, "spring \(slot) anchor a")
            close(anchors.b, b, "spring \(slot) anchor b")
            guard case .polyline(let points, let width)? = presenter.springNodes[slot].primitive else {
                return XCTFail("spring \(slot) has no zigzag")
            }
            XCTAssertEqual(points.count, PlaygroundPresenter.springPoints)
            XCTAssertEqual(points.count, 20, "two leads and 8 coils of two peaks")
            close(points[0], map(a), "spring \(slot) starts at anchor a")
            close(points[points.count - 1], map(b), "spring \(slot) ends at anchor b")
            XCTAssertEqual(width, 0.03 * s, accuracy: 1e-9, "0.03 m wide")
            // Every peak lies the coil amplitude from the axis, alternately on either side.
            let axis = (map(b) - map(a)) * (1 / (map(b) - map(a)).length)
            var sides: [Double] = []
            for point in points[2..<(points.count - 2)] {
                let offset = point - map(a)
                let across = offset.x * -axis.y + offset.y * axis.x
                XCTAssertEqual(abs(across), PlaygroundPresenter.springAmplitude * s, accuracy: 1e-9)
                sides.append(across > 0 ? 1 : -1)
            }
            XCTAssertEqual(sides, (0..<16).map { $0 % 2 == 0 ? 1 : -1 })
            XCTAssertEqual(presenter.springNodes[slot].color, PlaygroundPresenter.springColor)
            let dots = presenter.anchorNodes[slot]
            XCTAssertEqual(dots.a.primitive, .circle(PlaygroundPresenter.anchorDotRadius * s))
            close(dots.a.position, map(a), "spring \(slot) dot a")
            close(dots.b.position, map(b), "spring \(slot) dot b")
        }
        XCTAssertLessThan(PlaygroundPresenter.springZ, PlaygroundPresenter.fillZ, "springs under the bodies")
        XCTAssertGreaterThan(PlaygroundPresenter.springZ, PlaygroundPresenter.wallZ)
        XCTAssertNil(presenter.springNodes[2].primitive)
        XCTAssertNil(presenter.anchorNodes[15].a.primitive)

        // At a small canvas the zigzag is still a pixel wide; the starting scene draws its two springs.
        presenter.layOut(PlaygroundCore(seed: 7), width: 120, height: 100)
        XCTAssertEqual(presenter.lastSpringsDrawn, 2)
        guard case .polyline(let hanging, let thin)? = presenter.springNodes[0].primitive else {
            return XCTFail("no hanging spring")
        }
        XCTAssertEqual(thin, 1, "at least one pixel")
        close(hanging[0], PlaygroundPresenter.world(StartingScene.hangingAnchor, scale: 10), "the ceiling anchor")
        XCTAssertEqual(PlaygroundPresenter.zigzag(from: Vec2(1, 1), to: Vec2(1, 1)), [Vec2(1, 1), Vec2(1, 1)])
    }

    func testTheProbeStepsAsideForBodiesNearIt() throws {
        let presenter = PlaygroundPresenter(experienceID: PlaygroundTest.id)
        var world = playgroundSampleWorld()
        presenter.layOut(try playgroundCore(world), width: 120, height: 100)
        let probes = presenter.probes(try playgroundCore(world))
        XCTAssertEqual(probes.map(\.expected), ["dark"])
        XCTAssertEqual(probes.first?.x ?? 0, 0.5, accuracy: 1e-12)
        XCTAssertEqual(probes.first?.y ?? 0, 0.5 + (4 - 0.75) / 10, accuracy: 1e-12, "0.75 m above the floor")
        world.bodies.append(PhysicsBody(id: 3, shape: .circle(radius: 0.3), materialId: "ice",
                                        position: Vec2(5.2, 0.5)))
        world.nextId = max(world.nextId, 4)
        XCTAssertEqual(presenter.probes(try playgroundCore(world)), [], "a body over the probe point")
        world.bodies.removeLast()
        XCTAssertEqual(presenter.probes(try playgroundCore(world)).count, 1)
        world.springs = [WorldSpring(id: 0, a: .world(Vec2(5, 0.8)), b: .body(2), restLength: 2)]
        world.nextSpringId = max(world.nextSpringId, 1)
        XCTAssertEqual(world.validate(), [])
        XCTAssertEqual(presenter.probes(try playgroundCore(world)), [], "a spring over the probe point")
        XCTAssertEqual(presenter.probes(PlaygroundCore(seed: 7)).count, 1, "the starting scene leaves the probe clear")
        XCTAssertEqual(PlaygroundPresenter.colorClassOfStage, FrameColorClass.dark.rawValue)
        XCTAssertEqual(PlaygroundPresenter.colorClass(red: PlaygroundPresenter.letterboxColor.x,
                                                      green: PlaygroundPresenter.letterboxColor.y,
                                                      blue: PlaygroundPresenter.letterboxColor.z),
                       FrameColorClass.dark.rawValue)
    }

    func testAFailedDrawReachesTheSession() async throws {
        let session = ExperienceSession()
        let shell = try await PlaygroundTest.open(session, size: size)
        try PlaygroundTest.frames(session, 1)
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
        let forbidden = ["egl" + "CreateContext", "egl" + "GetDisplay", "egl" + "GetPlatformDisplay",
                         "EAGL" + "Context", "MTL" + "CreateSystemDefaultDevice", "RenderHost" + "(",
                         "CVisualCore" + "GL", "vc" + "gl", "AV" + "AudioEngine", "AV" + "AudioPlayer"]
        for file in files {
            let text = try String(contentsOf: file, encoding: .utf8)
            for word in forbidden {
                XCTAssertFalse(text.contains(word), "\(file.lastPathComponent) mentions \(word)")
            }
        }
    }
}
