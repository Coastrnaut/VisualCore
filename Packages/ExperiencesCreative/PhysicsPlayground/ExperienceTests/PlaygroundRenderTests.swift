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
//
// Feature 084 (A11-P03) T-A11-303 (FR-A11-310, FR-A11-311; SC-A11-304; clarification 4): velocity arrows (0.25 s ×
// |v|, capped at 2 m) and force arrows (weight and the measured net spring force, 0.05 m per newton, capped at 2 m)
// with 0.12 m triangular heads, drawn at the stated lengths within one pixel when the overlays are on and none when
// they are off, the spring force only while the measurement belongs to the drawn tick; the grab line, the selection
// ring and the pin dots; drawing never changes the world or the digest; the state panel's values equal
// `WorldDiagnostics` to display precision; the description names pins, selection, grab and overlays; the controls'
// selection walk and hold moves; the probe steps aside for the overlays.
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
        let none = "; none pinned, no selection, arrows off."
        XCTAssertEqual(PlaygroundPresenter.description(world),
                       "Physics Playground: 3 bodies, running, normal speed (time scale 1×); "
                       + "no springs, stiffness medium, gravity Earth, drag low" + none)
        world.paused = true
        world.timeScaleIndex = 0
        XCTAssertTrue(WorldSimulation.setGravityLevel(&world, 1))
        XCTAssertTrue(WorldSimulation.setDragLevel(&world, 2))
        XCTAssertTrue(WorldSimulation.setStiffnessLevel(&world, 3))
        world.springs = [WorldSpring(id: 0, a: .world(Vec2(5, 7.5)), b: .body(1), restLength: 1)]
        XCTAssertEqual(PlaygroundPresenter.description(world),
                       "Physics Playground: 3 bodies, paused, quarter speed (time scale ¼×); "
                       + "1 spring, stiffness very stiff, gravity Moon, drag high" + none)
        world.springs = []
        world.bodies = [world.bodies[0]]
        world.timeScaleIndex = 1
        XCTAssertTrue(WorldSimulation.setGravityLevel(&world, 0))
        XCTAssertTrue(WorldSimulation.setDragLevel(&world, 0))
        XCTAssertTrue(WorldSimulation.setStiffnessLevel(&world, 0))
        XCTAssertEqual(PlaygroundPresenter.description(world),
                       "Physics Playground: 1 body, paused, half speed (time scale ½×); "
                       + "no springs, stiffness soft, gravity off, drag none" + none)
        XCTAssertEqual(PlaygroundPresenter.description(PlaygroundCore(seed: 7).world),
                       "Physics Playground: 10 bodies, running, normal speed (time scale 1×); "
                       + "2 springs, stiffness medium, gravity Earth, drag low" + none)
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

    // MARK: Feature 084 overlays, panel and controls

    /// The sample world with velocities on its two dynamic bodies (the box's capped) and the overlays `velocity` and
    /// `forces`.
    private func movingWorld(velocity: Bool, forces: Bool) -> PhysicsWorld {
        var world = playgroundSampleWorld()
        world.bodies[1].velocity = Vec2(1.2, -1.6)   // |v| = 2 m/s → 0.5 m
        world.bodies[2].velocity = Vec2(-30, 0)      // 7.5 m → capped at 2 m
        world.showVelocity = velocity
        world.showForces = forces
        return world
    }

    /// Checks that the shaft and head of `kind` at `slot` draw `arrow` (metres) at `s` pixels per metre: the shaft from
    /// the start to the head's base, the head's tip at the arrow's end, the tip `length` metres from the start within
    /// one pixel.
    private func assertArrow(_ presenter: PlaygroundPresenter, slot: Int, kind: PlaygroundArrow.Kind,
                             from start: Vec2, vector: Vec2, length: Double, s: Double, line: UInt = #line) {
        let map = { (p: Vec2) in PlaygroundPresenter.world(p, scale: s) }
        guard case .polygon(let head)? = presenter.headNodes[slot][kind.rawValue].primitive else {
            return XCTFail("no head for slot \(slot) \(kind)", line: line)
        }
        XCTAssertEqual(head.count, 3, line: line)
        let tip = head[0], origin = map(start)
        XCTAssertEqual((tip - origin).length, length * s, accuracy: 1, "the stated length within a pixel", line: line)
        let want = origin + vector * (length * s / vector.length)
        XCTAssertEqual((tip - want).length, 0, accuracy: 1, "along the vector", line: line)
        let base = (head[1] + head[2]) / 2
        XCTAssertEqual((tip - base).length, PlaygroundPresenter.arrowHeadLength * s, accuracy: 1e-6, line: line)
        XCTAssertEqual((head[1] - head[2]).length, PlaygroundPresenter.arrowHeadWidth * s, accuracy: 1e-6, line: line)
        guard case .line(let from, let to, let width)? = presenter.shaftNodes[slot][kind.rawValue].primitive else {
            return XCTFail("no shaft for slot \(slot) \(kind)", line: line)
        }
        XCTAssertEqual((from - origin).length, 0, accuracy: 1e-6, line: line)
        XCTAssertEqual((to - base).length, 0, accuracy: 1e-6, "the shaft ends at the head's base", line: line)
        XCTAssertEqual(width, max(PlaygroundPresenter.arrowShaftWidth * s, 1), accuracy: 1e-9, line: line)
        XCTAssertEqual(presenter.shaftNodes[slot][kind.rawValue].color, PlaygroundPresenter.arrowColors[kind],
                       line: line)
    }

    /// T-A11-303 (FR-A11-310; SC-A11-304): velocity arrows from each dynamic body's centre along v, 0.25 s × |v| m long
    /// and capped at 2 m; none on the static ledge; none at all when the overlay is off.
    func testVelocityArrowsHaveTheStatedLengthsAndOnlyWhenOn() throws {
        let presenter = PlaygroundPresenter(experienceID: PlaygroundTest.id)
        let world = movingWorld(velocity: true, forces: false)
        let core = try playgroundCore(world)
        let copy = core
        presenter.layOut(core, width: 1200, height: 1000)
        XCTAssertEqual(core, copy, "drawing reads the core only")
        let s = presenter.lastScale
        XCTAssertEqual(s, 100, accuracy: 1e-12)
        XCTAssertEqual(presenter.lastArrowsDrawn, [.velocity: 2])
        assertArrow(presenter, slot: 1, kind: .velocity, from: Vec2(3, 5), vector: Vec2(1.2, -1.6), length: 0.5, s: s)
        assertArrow(presenter, slot: 2, kind: .velocity, from: Vec2(7, 3), vector: Vec2(-1, 0), length: 2, s: s)
        XCTAssertNil(presenter.headNodes[0][0].primitive, "no arrow on the static ledge")
        XCTAssertNil(presenter.headNodes[1][PlaygroundArrow.Kind.weight.rawValue].primitive, "force arrows are off")
        XCTAssertGreaterThan(PlaygroundPresenter.overlayZ, PlaygroundPresenter.hatchZ, "above the bodies")
        XCTAssertLessThan(PlaygroundPresenter.overlayZ, PlaygroundPresenter.maskZ)

        // At a small canvas the stated length still holds within a pixel.
        presenter.layOut(core, width: 120, height: 100)
        assertArrow(presenter, slot: 1, kind: .velocity, from: Vec2(3, 5), vector: Vec2(1.2, -1.6), length: 0.5,
                    s: presenter.lastScale)

        // Off: nothing drawn, the world unchanged.
        let off = try playgroundCore(movingWorld(velocity: false, forces: false))
        presenter.layOut(off, width: 1200, height: 1000)
        XCTAssertEqual(presenter.lastArrowsDrawn, [:])
        for slot in 0..<PhysicsWorld.maxBodies {
            for node in presenter.shaftNodes[slot] + presenter.headNodes[slot] { XCTAssertNil(node.primitive) }
        }
        XCTAssertEqual(PlaygroundPresenter.arrows(off.world, forces: off.forces).count, 0)
    }

    /// T-A11-303 (FR-A11-310; SC-A11-304): force arrows show each dynamic body's weight m·g and its measured net spring
    /// force at 0.05 m per newton, capped at 2 m; the spring force only while the measurement belongs to the drawn
    /// tick.
    func testForceArrowsShowWeightAndTheMeasuredSpringForce() throws {
        let presenter = PlaygroundPresenter(experienceID: PlaygroundTest.id)
        var world = movingWorld(velocity: false, forces: true)
        world.springs = [WorldSpring(id: 0, a: .world(Vec2(3, 7.5)), b: .body(1), restLength: 1)]
        world.nextSpringId = 1
        XCTAssertEqual(world.validate(), [])
        var core = try playgroundCore(world)
        presenter.layOut(core, width: 1200, height: 1000)
        let s = presenter.lastScale
        XCTAssertEqual(presenter.lastArrowsDrawn, [.weight: 2], "a restored world shows no spring force before a tick")
        let catalog = PlaygroundCore.catalog
        for slot in [1, 2] {
            let body = world.bodies[slot]
            let weight = ForceMeasurement.weight(of: body, in: world, catalog: catalog)
            XCTAssertEqual(weight.y, -(body.mass(in: catalog) ?? 0) * 9.81, accuracy: 1e-9)
            assertArrow(presenter, slot: slot, kind: .weight, from: body.position, vector: weight,
                        length: min(weight.length * 0.05, 2), s: s)
        }

        core.update(step: 0)
        XCTAssertTrue(core.forces.isCurrent(for: core.world))
        let pull = core.forces.springForce(on: 1)
        XCTAssertGreaterThan(pull.length, 0, "the stretched spring pulls the circle")
        presenter.layOut(core, width: 1200, height: 1000)
        XCTAssertEqual(presenter.lastArrowsDrawn, [.weight: 2, .spring: 1])
        assertArrow(presenter, slot: 1, kind: .spring, from: core.world.bodies[1].position, vector: pull,
                    length: min(pull.length * 0.05, 2), s: s)
        XCTAssertNil(presenter.headNodes[2][PlaygroundArrow.Kind.spring.rawValue].primitive, "no spring on the box")

        // The arrow's own geometry: capped, a zero vector gives none, a short arrow is all head.
        let capped = try XCTUnwrap(PlaygroundArrow.make(from: .zero, vector: Vec2(0, -500), scale: 0.05, maxLength: 2))
        XCTAssertEqual(capped.to, Vec2(0, -2))
        XCTAssertNil(PlaygroundArrow.make(from: .zero, vector: .zero, scale: 0.05, maxLength: 2))
        XCTAssertNil(PlaygroundArrow.make(from: .zero, vector: Vec2(.nan, 0), scale: 0.05, maxLength: 2))
        let short = PlaygroundArrow(from: .zero, to: Vec2(0.05, 0))
        XCTAssertEqual(short.shaftEnd(headLength: 0.12), .zero)
    }

    /// T-A11-303: the grab line from the grabbed body's anchor to the target, the selection ring and the pin dots; all
    /// gone when there is nothing to show.
    func testTheGrabLineSelectionRingAndPinDots() throws {
        let presenter = PlaygroundPresenter(experienceID: PlaygroundTest.id)
        var world = playgroundSampleWorld()
        world.grab = Grab(bodyId: 1, localAnchor: Vec2(0.2, 0), target: Vec2(6, 6))
        world.selectedId = 1
        world.bodies[2].pinned = true
        XCTAssertEqual(world.validate(), [])
        presenter.layOut(try playgroundCore(world), width: 1200, height: 1000)
        let map = { (p: Vec2) in PlaygroundPresenter.world(p, scale: 100) }
        guard case .line(let from, let to, let width)? = presenter.grabNode.primitive else {
            return XCTFail("no grab line")
        }
        let anchor = Vec2(3 + 0.2 * cos(0.6), 5 + 0.2 * sin(0.6))
        XCTAssertEqual((from - map(anchor)).length, 0, accuracy: 1e-6, "from the anchor through the body's pose")
        XCTAssertEqual((to - map(Vec2(6, 6))).length, 0, accuracy: 1e-6, "to the target")
        XCTAssertEqual(width, 2, accuracy: 1e-9, "0.02 m")
        guard case .polyline(let ring, _)? = presenter.selectionNode.primitive else { return XCTFail("no ring") }
        for point in ring { XCTAssertEqual((point - map(Vec2(3, 5))).length, 60, accuracy: 1e-6) }
        XCTAssertEqual(presenter.pinNodes[2].primitive, .circle(8))
        XCTAssertEqual(presenter.pinNodes[2].position, map(Vec2(7, 3)))
        XCTAssertNil(presenter.pinNodes[1].primitive)

        presenter.layOut(try playgroundCore(playgroundSampleWorld()), width: 1200, height: 1000)
        XCTAssertNil(presenter.grabNode.primitive)
        XCTAssertNil(presenter.selectionNode.primitive)
        XCTAssertNil(presenter.pinNodes[2].primitive)
    }

    /// T-A11-303 (FR-A11-311; SC-A11-304): the panel's values are `WorldDiagnostics`' to display precision, the
    /// selected speed is the selected body's, drawing frames with every overlay on changes neither the world nor the
    /// digest, and the description names pins, selection, grab and overlays.
    func testThePanelEqualsTheDiagnosticsAndOverlaysNeverWriteTheWorld() async throws {
        let catalog = PlaygroundCore.catalog
        var world = movingWorld(velocity: true, forces: true)
        world.selectedId = 1
        let panel = PlaygroundPanel.measure(world)
        XCTAssertEqual(panel.kinetic, WorldDiagnostics.kineticEnergy(world, catalog: catalog))
        XCTAssertEqual(panel.potential, WorldDiagnostics.potentialEnergy(world, catalog: catalog))
        XCTAssertEqual(panel.spring, WorldDiagnostics.springPotentialEnergy(world, catalog: catalog))
        XCTAssertEqual(panel.total, WorldDiagnostics.totalEnergy(world, catalog: catalog))
        XCTAssertEqual(panel.momentum, WorldDiagnostics.momentum(world, catalog: catalog).length)
        XCTAssertEqual(panel.speed, 2)
        XCTAssertEqual(panel.rows.map { $0.label }, ["Kinetic energy", "Potential energy", "Spring energy",
                                                 "Total energy", "Momentum", "Selected speed"])
        XCTAssertEqual(panel.rows[0].value, String(format: "%.2f J", panel.kinetic))
        XCTAssertEqual(panel.rows[4].value, String(format: "%.2f kg·m/s", panel.momentum))
        XCTAssertEqual(panel.rows[5].value, "2.00 m/s")
        XCTAssertEqual(PlaygroundPanel.text(-0.001), "0.00", "never -0.00")
        XCTAssertEqual(PlaygroundPanel.text(1.236), "1.24")
        XCTAssertEqual(PlaygroundPanel.text(.infinity), "—")
        XCTAssertEqual(PlaygroundPanel.note, "Educational approximation")
        XCTAssertTrue(PlaygroundPanel.arrowNote.contains("contact and drag forces are not drawn"))
        world.selectedId = nil
        XCTAssertEqual(PlaygroundPanel.measure(world).rows[5].value, "no selection")

        world.selectedId = 1
        world.bodies[2].pinned = true
        world.bodies[2].velocity = .zero
        world.grab = Grab(bodyId: 1, localAnchor: .zero, target: Vec2(4, 4))
        XCTAssertEqual(world.validate(), [])
        XCTAssertTrue(PlaygroundPresenter.description(world).hasSuffix(
            "; 1 pinned, body 1 selected (a circle), body 1 held, velocity and force arrows on."))
        world.showVelocity = false
        world.selectedId = 2
        world.grab = nil
        XCTAssertTrue(PlaygroundPresenter.description(world).hasSuffix("; 1 pinned, body 2 selected (a box, pinned), "
                                                                       + "force arrows on."))
        world.selectedId = 0
        XCTAssertTrue(PlaygroundPresenter.selectionWords(world) == "body 0 selected (a box, static)")

        // In a session: every overlay on, frames drawn; the world equals the bare replay and the mirror's panel the
        // diagnostics of the drawn world.
        let session = ExperienceSession()
        let shell = try await PlaygroundTest.open(session, size: size)
        let step = shell.engine.stepIndex
        for (control, values) in [("overlay.velocity", [1.0]), ("overlay.forces", [1.0]), ("edit.select", [9.0]),
                                  ("edit.pin", [8.0]), ("edit.grab", [7.0, 7.5, 6.2])] {
            XCTAssertTrue(shell.handle(control: control, values: values).isAccepted, control)
        }
        try PlaygroundTest.frames(session, 30)
        XCTAssertGreaterThan(shell.presenter.lastArrowsDrawn[.velocity] ?? 0, 0)
        XCTAssertGreaterThan(shell.presenter.lastArrowsDrawn[.spring] ?? 0, 0)
        XCTAssertNotNil(shell.presenter.grabNode.primitive)
        let drawn = try PlaygroundTest.core(shell)
        let edits: [(String, [Double])] = [("overlay.velocity", [1]), ("overlay.forces", [1]), ("edit.select", [9]),
                                           ("edit.pin", [8]), ("edit.grab", [7, 7.5, 6.2])]
        let entries = edits.enumerated().map { index, edit in
            ScenarioStep(steps: index == 0 ? step : 0, action: ScriptedAction(edit.0, edit.1))
        } + [ScenarioStep(steps: shell.engine.stepIndex - step)]
        XCTAssertEqual(drawn, PlaygroundCore.played(seed: 7, entries: entries),
                       "the drawn session with every overlay equals the undrawn replay")
        XCTAssertEqual(shell.presenter.mirror.panel, PlaygroundPanel.measure(drawn.world),
                       "the panel shows the drawn world's diagnostics")
        XCTAssertEqual(shell.presenter.mirror.panel.speed,
                       drawn.world.bodies.first { $0.id == 9 }?.velocity.length)
        session.close()
    }

    func testTheControlsWalkTheSelectionAndMoveAHeldBody() {
        let ids = [0, 1, 2, 7]
        XCTAssertEqual(PlaygroundControls.neighbour(of: nil, in: ids, forward: true), 0)
        XCTAssertEqual(PlaygroundControls.neighbour(of: nil, in: ids, forward: false), 7)
        XCTAssertEqual(PlaygroundControls.neighbour(of: 1, in: ids, forward: true), 2)
        XCTAssertEqual(PlaygroundControls.neighbour(of: 7, in: ids, forward: true), 0, "wraps")
        XCTAssertEqual(PlaygroundControls.neighbour(of: 0, in: ids, forward: false), 7, "wraps")
        XCTAssertEqual(PlaygroundControls.neighbour(of: 5, in: ids, forward: true), 0, "a missing selection")
        XCTAssertNil(PlaygroundControls.neighbour(of: nil, in: [], forward: true))
        XCTAssertEqual(PlaygroundControls.movedTarget(Vec2(5, 4), dx: 1, dy: 0), Vec2(5.5, 4))
        XCTAssertEqual(PlaygroundControls.movedTarget(Vec2(9.8, 0.2), dx: 1, dy: -1), Vec2(10, 0), "clamped")
        XCTAssertEqual(PlaygroundControls.addPoint, Vec2(5, 4))
        XCTAssertEqual(PlaygroundControls.shapeTitles, ["Circle", "Box"])
        XCTAssertEqual(PlaygroundControls.directions.map { $0.name },
                       ["nudge-up", "nudge-down", "nudge-left", "nudge-right"])
        XCTAssertEqual(PlaygroundControls.selectionValue(nil), "No body selected")
        XCTAssertEqual(PlaygroundControls.selectionValue(7), "Body 7 selected")
        let presenter = PlaygroundPresenter(experienceID: PlaygroundTest.id)
        XCTAssertTrue(Set(PlaygroundCore.actionIDs).isSubset(of: presenter.nativeActions))
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
        // Feature 084: an arrow or a grab line over the probe point moves the probe aside too.
        world.springs = []
        world.bodies[2].velocity = Vec2(-8, -8)   // the box at (7, 3): a 2 m arrow toward (5.6, 1.6)
        world.bodies[2].position = Vec2(6.2, 2.2)
        XCTAssertEqual(presenter.probes(try playgroundCore(world)).count, 1, "overlays off: the probe holds")
        world.showVelocity = true
        XCTAssertEqual(presenter.probes(try playgroundCore(world)), [], "a velocity arrow over the probe point")
        world.showVelocity = false
        world.grab = Grab(bodyId: 1, localAnchor: .zero, target: Vec2(5, 0.5))
        XCTAssertEqual(presenter.probes(try playgroundCore(world)), [], "the grab line over the probe point")
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
