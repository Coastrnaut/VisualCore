// SolarRenderTests — feature 103 (A14-P01) T-A14-103 (FR-A14-120, 121; clarifications Q4, Q5; SC-A14-104), updated for
// the orbit view of feature 104 (A14-P02) T-A14-207 and T-A14-208 (FR-A14-220, FR-A14-221). Solar System Explorer
// rendered inside the one app's session host on the simulator, short runs only (each test under 10 s, no wall-clock
// assertion): a drawn frame with the Sun, Earth and Neptune focused is non-blank and not black, with its background
// and body probes holding; changing the focus changes the drawn pixels, puts the ring around the new body and changes
// the fact card; drawing never changes the state or its digest; the display radius formula of clarification Q4 and the
// unit 48 × 24 body spheres of feature 105 (A14-P03) T-A14-308; the procedural recipe colours; the words of the
// controls with the Scale picker; teardown releases every GPU object; and the experience's sources never create a
// graphics context of their own. A change of focus starts a 30-frame focus flight (FR-A14-320), so a test that judges
// the focused view draws the flight's frames first. The orbit view's own geometry and frames are tested in
// OrbitLayoutTests and SolarOrbitRenderTests, the bodies, ring, scale modes and flight in SolarBodiesRenderTests.
import Foundation
import XCTest
@testable import SolarSystemExplorerExperience
import SolarSystemExplorerCore
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreRendering
import VisualCoreScenes
import VisualCoreSimulation

@MainActor
final class SolarRenderTests: XCTestCase {
    private let size = CGSize(width: 240, height: 160)

    /// Draws the frames of a whole focus flight, so the drawn camera reaches the state's view.
    private func settle(_ session: ExperienceSession) throws {
        try SolarTest.frames(session, FocusFlight.frameCount)
    }

    private func assertDrawn(_ shell: ExperienceShell<SolarPresenter>, _ frame: SolarFrame, _ name: String) {
        XCTAssertGreaterThan(frame.width, 0)
        XCTAssertTrue(FrameChecks.isNonBlank(frame.rgba, width: frame.width, height: frame.height), "\(name) not blank")
        XCTAssertFalse(FrameChecks.isBlack(frame.rgba, width: frame.width, height: frame.height), "\(name) not black")
        let probes = shell.frameProbes
        XCTAssertGreaterThanOrEqual(probes.count, 1, "\(name): at least the background")
        XCTAssertEqual(probes.first?.name, "background", "\(name): the overview camera keeps the top clear")
        for probe in probes {
            let found = FrameChecks.probe(probe, rgba: frame.rgba, width: frame.width, height: frame.height)
            XCTAssertEqual(found?.rawValue, probe.expected, "\(name) \(probe.name)")
        }
    }

    func testADrawnFrameWithTheSunEarthAndNeptuneSelectedIsNonBlank() async throws {
        let session = ExperienceSession()
        let shell = try await SolarTest.open(session, size: size)
        let selections: [Int] = [0, 3, 8]
        for selection in selections {
            XCTAssertTrue(shell.handle(control: "body.select", values: [Double(selection)]).isAccepted)
            try settle(session)
            let frame = try SolarTest.picture(session)
            let name = "body \(selection)"
            assertDrawn(shell, frame, name)
            XCTAssertEqual(shell.presenter.lastBodiesDrawn, 9, name)
            XCTAssertEqual(shell.presenter.lastSelection, selection, name)
        }
        session.close()
        XCTAssertEqual(session.hostsAlive, 0)
    }

    func testTheSunAndNeptuneHaveRobustCentreProbes() async throws {
        let session = ExperienceSession()
        let shell = try await SolarTest.open(session, size: size)
        var frame = try SolarTest.picture(session)
        let sun = try XCTUnwrap(shell.frameProbes.first { $0.name == "body-0" }, "the Sun is drawn at full brightness")
        XCTAssertEqual(sun.expected, "red")
        XCTAssertEqual(FrameChecks.probe(sun, rgba: frame.rgba, width: frame.width, height: frame.height)?.rawValue,
                       "red")
        // Neptune focused and zoomed in, seen from its sunlit side (the yaw step nearest the direction to the Sun).
        XCTAssertTrue(shell.handle(control: "body.select", values: [8]).isAccepted)
        for _ in 0..<8 { XCTAssertTrue(shell.handle(control: "camera.zoom", values: [1]).isAccepted) }
        let position = OrbitLayout.scenePosition(index: 8, day: 0)
        let steps = Int((atan2(-position.x, -position.z) * 180 / Double.pi / 15).rounded())
        for _ in 0..<abs(steps) {
            XCTAssertTrue(shell.handle(control: "camera.orbit", values: [steps < 0 ? -1 : 1]).isAccepted)
        }
        try settle(session)
        frame = try SolarTest.picture(session)
        let neptune = try XCTUnwrap(shell.frameProbes.first { $0.name == "body-8" })
        XCTAssertEqual(neptune.expected, "blue")
        XCTAssertEqual(FrameChecks.probe(neptune, rgba: frame.rgba, width: frame.width,
                                         height: frame.height)?.rawValue, "blue")
        session.close()
    }

    func testChangingTheSelectionChangesTheDrawnPixelsAndTheCard() async throws {
        let session = ExperienceSession()
        let shell = try await SolarTest.open(session, size: size)
        let before = try SolarTest.picture(session)
        let card = shell.presenter.mirror.facts
        let canvas = Vec2(Double(before.width), Double(before.height))
        XCTAssertTrue(shell.handle(control: "body.select", values: [3]).isAccepted)
        try settle(session)
        let after = try SolarTest.picture(session)
        assertDrawn(shell, after, "Earth")
        XCTAssertNotEqual(StableHash.sha256Hex(before.rgba), StableHash.sha256Hex(after.rgba), "the frame changes")
        // Earth is now in the middle of the canvas, where the Sun was.
        let middle = Vec2(canvas.x / 2, canvas.y / 2)
        XCTAssertGreaterThan(SolarTest.differingPixels(before, after, around: middle, radius: 2), 0, "Earth in focus")
        // The ring surrounds Earth: the pixels around its top point (in the ring's own plane) hold the ring colour.
        let state = try SolarTest.core(shell).state
        let camera = OrbitLayout.camera(state: state)
        let ring = SolarPresenter.ringRadius(displayRadius: OrbitLayout.displayRadius(index: 3))
        XCTAssertEqual(OrbitLayout.selectionRingRadius(index: 3), ring, accuracy: 1e-12)
        let top = OrbitLayout.ringModel(center: camera.target, camera: camera).applyPoint(Vec3(0, ring, 0))
        let p = OrbitLayout.pixel(of: top, state: state, canvas: canvas)
        XCTAssertGreaterThan(SolarTest.differingPixels(before, after, around: p, radius: 3), 0, "the ring is there")
        XCTAssertGreaterThan(SolarTest.pixels(near: SolarPresenter.ringColor, in: after), 0, "the ring is drawn")
        XCTAssertEqual(shell.presenter.ringRenderer.map { ObjectIdentifier($0) },
                       ObjectIdentifier(shell.presenter.ringRenderers[3]), "Earth's ring")
        XCTAssertNotEqual(shell.presenter.mirror.facts, card, "the card changes")
        XCTAssertEqual(shell.presenter.mirror.facts,
                       try XCTUnwrap(BodyCatalog.bundled.factCard(for: 3)).facts.map(\.text))
        XCTAssertEqual(shell.presenter.mirror.distance, SolarCore.distanceWords(index: 3, dayOffset: 0))

        // The same state draws the same frame.
        let again = try SolarTest.picture(session)
        XCTAssertEqual(StableHash.sha256Hex(after.rgba), StableHash.sha256Hex(again.rgba), "a still state holds")
        session.close()
    }

    func testDrawingNeverChangesTheState() async throws {
        let session = ExperienceSession()
        let shell = try await SolarTest.open(session, size: size)
        XCTAssertTrue(shell.handle(control: "body.select", values: [6]).isAccepted)
        let core = try SolarTest.core(shell)
        let digest = try shell.engine.digest()
        try SolarTest.frames(session, 15)
        _ = shell.accessibilitySummary
        _ = shell.frameProbes
        XCTAssertEqual(try SolarTest.core(shell), core, "the presenter reads the core only")
        XCTAssertEqual(try shell.engine.digest(), digest)

        // Describing a core in a presenter of its own leaves the value as it was.
        let presenter = SolarPresenter(experienceID: SolarTest.id)
        let copy = core
        _ = presenter.describe(core)
        XCTAssertEqual(core, copy)
        XCTAssertEqual(presenter.probes(core), [], "no probe before the first frame")
        session.close()
    }

    func testTheDisplayRadiusFormulaOfClarificationQ4AndTheOrbitViewMeshes() throws {
        XCTAssertEqual(SolarPresenter.displayRadius(index: 0), 1.6, accuracy: 1e-12, "the Sun")
        XCTAssertEqual(SolarPresenter.displayRadius(index: 1), 0.25, accuracy: 1e-12, "Mercury")
        let radii: [Double] = [6_051.8, 6_371.0, 3_389.5, 69_911, 58_232, 25_362, 24_622]
        for (offset, radius) in radii.enumerated() {
            let index = offset + 2
            XCTAssertEqual(SolarPresenter.displayRadius(index: index), 0.25 + 0.15 * log2(radius / 2_439.7),
                           accuracy: 1e-12, "body \(index)")
        }
        XCTAssertEqual(SolarPresenter.displayRadius(index: 3), 0.4577, accuracy: 1e-4, "Earth")
        XCTAssertEqual(SolarPresenter.displayRadius(index: 5), 0.9761, accuracy: 1e-4, "Jupiter")
        XCTAssertEqual(SolarPresenter.displayRadius(radiusKm: 2 * 2_439.7, kind: .planet), 0.4, accuracy: 1e-12)
        XCTAssertEqual(SolarPresenter.displayRadius(radiusKm: 1, kind: .star), 1.6)
        XCTAssertEqual(SolarPresenter.displayRadius(radiusKm: .nan, kind: .planet), 0.25)
        XCTAssertEqual(SolarPresenter.displayRadius(radiusKm: 1, kind: .planet), 0.05, "at least 0.05")
        XCTAssertEqual(SolarPresenter.referenceRadiusKm, 2_439.7)

        // The meshes: nine unit UV spheres of 48 segments and 24 rings (scaled to the drawn radius by the model
        // matrix), one recipe colour per vertex.
        let meshes = SolarPresenter.meshes()
        XCTAssertEqual(meshes.count, 9)
        for part in meshes {
            XCTAssertEqual(part.mesh, Mesh.uvSphere(segments: 48, rings: 24, radius: 1))
            XCTAssertEqual(part.colors.count, part.mesh.positions.count)
        }
        let ring = try SolarPresenter.ringMesh(selection: 3)
        XCTAssertGreaterThan(ring.triangleCount, 0)
        let outer = OrbitLayout.selectionRingRadius(index: 3) + SolarPresenter.ringTubeRadius
        for position in ring.positions {
            XCTAssertLessThanOrEqual((position.x * position.x + position.y * position.y).squareRoot(), outer + 1e-9)
            XCTAssertGreaterThan((position.x * position.x + position.y * position.y).squareRoot(),
                                 OrbitLayout.displayRadius(index: 3), "the ring lies outside the body")
            XCTAssertEqual(position.z, 0, accuracy: SolarPresenter.ringTubeRadius + 1e-9, "the ring's x–y plane")
        }
        // The orbit meshes: closed tubes of radius 0.04 around each 128-point path.
        for id in OrbitLayout.orbitBodyIDs {
            let orbit = try SolarPresenter.orbitMesh(bodyID: id)
            XCTAssertGreaterThan(orbit.triangleCount, 0, id)
            let path = OrbitLayout.orbitPath(bodyID: id)
            // Every 7th vertex (a short test): each lies on the tube around the path (1 % for the joints).
            for position in stride(from: 0, to: orbit.positions.count, by: 7).map({ orbit.positions[$0] }) {
                var nearest = Double.infinity
                for k in path.indices {
                    nearest = min(nearest, OrbitLayout.segmentDistance(position, position, path[k],
                                                                       path[(k + 1) % path.count]))
                }
                XCTAssertLessThanOrEqual(nearest, SolarPresenter.orbitTubeRadius * 1.01, id)
                XCTAssertGreaterThanOrEqual(nearest, SolarPresenter.orbitTubeRadius * 0.9, id)
            }
        }
    }

    func testTheRecipeColoursAreProceduralAndDeterministic() {
        let meshes = SolarPresenter.meshes()
        var firstColours: [Vec4] = []
        for (index, part) in meshes.enumerated() {
            let recipe = SurfaceRecipe.bundled[index]
            XCTAssertEqual(recipe.bodyID, BodyCatalog.bundled.bodies[index].id)
            let expected = recipe.colors(for: part.mesh.positions).map { Vec4($0.r, $0.g, $0.b, $0.a) }
            XCTAssertEqual(part.colors, expected, "body \(index): the recipe's colours")
            XCTAssertEqual(part.colors, SolarPresenter.meshes()[index].colors, "body \(index): deterministic")
            for color in part.colors {
                XCTAssertTrue(color.x >= 0 && color.x <= 1 && color.y >= 0 && color.y <= 1 && color.z >= 0
                              && color.z <= 1 && color.w == 1, "body \(index): \(color)")
            }
            XCTAssertGreaterThanOrEqual(Set(part.colors).count, 2, "body \(index): a surface, not one colour")
            if index == 0 { firstColours = part.colors } else { XCTAssertNotEqual(part.colors, firstColours) }
        }
        XCTAssertEqual(SolarPresenter.robustClass([Vec3(1, 0.62, 0.18)]), "red")
        XCTAssertEqual(SolarPresenter.robustClass([Vec3(1, 0.78, 0.32)], scales: [1]), "red", "the Sun, ambient 1")
        XCTAssertNil(SolarPresenter.robustClass([]))
        XCTAssertNil(SolarPresenter.robustClass([Vec3(1, 0.62, 0.18), Vec3(0.2, 0.3, 0.9)]), "two classes")
        XCTAssertEqual(SolarPresenter.classify(red: 5, green: 6, blue: 12), "dark")
    }

    func testTheWordsOfTheControls() async throws {
        XCTAssertEqual(SolarPresenter.answerWords(control: "body.next", result: .accepted), "")
        let refused = ActionResult.rejected(.rule(code: SolarRule.invalidChoice))
        XCTAssertEqual(SolarPresenter.answerWords(control: "body.next", result: refused), "Neptune is the last body.")
        XCTAssertEqual(SolarPresenter.answerWords(control: "body.previous", result: refused),
                       "The Sun is the first body.")
        XCTAssertEqual(SolarPresenter.answerWords(control: "body.select", result: refused), "There is no such body.")
        let beyond = ActionResult.rejected(.rule(code: SolarRule.outOfRange))
        XCTAssertEqual(SolarPresenter.answerWords(control: "date.step", result: beyond),
                       "The date stays within 1950-01-01 to 2051-01-01.")
        XCTAssertEqual(SolarPresenter.answerWords(control: "camera.tilt", result: beyond),
                       "The view cannot tilt further.")
        XCTAssertEqual(SolarPresenter.answerWords(control: "camera.zoom", result: beyond),
                       "The view cannot zoom further.")
        XCTAssertEqual(SolarPresenter.answerWords(control: "camera.orbit", result: beyond),
                       "That is not possible here.")
        XCTAssertEqual(SolarPresenter.answerWords(control: "scale.mode", result: refused), "There is no such scale.")
        XCTAssertEqual(SolarControls.scaleWords(.enhanced), "Enhanced, Distances and sizes not to scale")
        XCTAssertEqual(SolarControls.scaleWords(.trueRelative),
                       "True relative, Distances and sizes to one scale; small bodies marked")
        XCTAssertEqual(SolarControls.legendText(.enhanced), "Distances and sizes not to scale")
        XCTAssertEqual(SolarControls.dateSteps, [-365, -30, -1, 1, 30, 365])
        XCTAssertEqual(SolarControls.dateName(-365), "date-minus-365")
        XCTAssertEqual(SolarControls.dateName(1), "date-plus-1")
        XCTAssertEqual(SolarControls.dateTitle(-1), "\u{2212}1 day")
        XCTAssertEqual(SolarControls.dateTitle(30), "+30 days")
        XCTAssertTrue(SolarControls.canStep(dayOffset: 0, by: 365))
        XCTAssertFalse(SolarControls.canStep(dayOffset: 18_627.5, by: 1), "the end of the range")
        XCTAssertFalse(SolarControls.canStep(dayOffset: -18_262.5, by: -1), "the start of the range")
        XCTAssertEqual(SolarControls.distanceLine(date: "2000-01-01", distance: "0.983 AU (147,099,000 km)"),
                       "Distance from the Sun on 2000-01-01: 0.983 AU (147,099,000 km)")
        XCTAssertEqual(SolarControls.distanceLine(date: "2000-01-01", distance: ""), "")
        XCTAssertEqual(SolarControls.yawWords(345), "Yaw 345°")
        XCTAssertEqual(SolarControls.pitchWords(35), "Pitch 35°")
        XCTAssertEqual(SolarControls.zoomWords(distance: 60, steps: 0),
                       "Distance 60.0 scene units, zoom step 0 (\u{2212}1 to 12)")
        XCTAssertEqual(SolarControls.cameraWords(yaw: 0, pitch: 35, distance: 60),
                       "Yaw 0°, pitch 35°, distance 60.0 scene units")
        XCTAssertEqual(SolarControls.bodyWords(index: 3, count: 9), "Earth, body 4 of 9")
        XCTAssertEqual(SolarControls.sentence("earth selected"), "Earth selected")
        XCTAssertEqual(SolarControls.sentence(""), "Loading")
        XCTAssertEqual(SolarControls.factName(0), "fact-1")
        let lines = SolarPresenter.factLines(BodyCatalog.bundled.factCard(for: 3))
        XCTAssertFalse(lines.isEmpty)
        XCTAssertTrue(lines.contains { $0.hasPrefix("Mean radius: 6,371 km — ") }, "\(lines)")
        XCTAssertEqual(SolarPresenter.factLines(nil), [])

        let session = ExperienceSession()
        let shell = try await SolarTest.open(session, size: size)
        let names: [String] = ["previous-body", "next-body", "body", "fact-1", "legend", "status", "message", "date",
                               "date-minus-365", "date-minus-30", "date-minus-1", "date-plus-1", "date-plus-30",
                               "date-plus-365", "orbit-left", "orbit-right", "tilt-up", "tilt-down", "zoom-in",
                               "zoom-out", "reset-view", "distance", "scale"]
        for name in names {
            XCTAssertEqual(shell.port.identifier(name), "experience.a14.solar-system-explorer.\(name)")
        }
        XCTAssertEqual(shell.port.send("body.previous").code, "action.rule.a14.invalid-choice")
        XCTAssertTrue(shell.port.send("body.next").isAccepted)
        let summary = shell.accessibilitySummary
        XCTAssertTrue(summary.hasPrefix("Solar System Explorer: Mercury in focus on 2000-01-01, "), summary)
        XCTAssertTrue(summary.hasSuffix("Distances and sizes not to scale."), summary)
        XCTAssertTrue(shell.port.send("date.step", [30]).isAccepted)
        XCTAssertEqual(shell.port.send("date.step", [2]).code, "action.rule.a14.invalid-step")
        XCTAssertTrue(shell.port.send("camera.zoom", [-1]).isAccepted)
        XCTAssertEqual(shell.port.send("camera.zoom", [-1]).code, "action.rule.a14.out-of-range",
                       "zoom step −1 is the end")
        try SolarTest.frames(session, 1)
        XCTAssertEqual(shell.presenter.mirror.dateLabel, "2000-01-31")
        XCTAssertEqual(shell.presenter.mirror.zoomSteps, -1)
        session.close()
    }

    func testTeardownReleasesEveryGPUObject() async throws {
        let session = ExperienceSession()
        let shell = try await SolarTest.open(session, size: size)
        XCTAssertTrue(shell.handle(control: "body.select", values: [5]).isAccepted)
        try SolarTest.frames(session, 2)
        XCTAssertEqual(shell.presenter.bodyRenderers.count, 9)
        XCTAssertNotNil(shell.presenter.ringRenderer)
        XCTAssertNotNil(shell.presenter.depthPass)
        XCTAssertEqual(shell.presenter.orbitRenderers.count, 8)
        XCTAssertEqual(shell.presenter.trueOrbitRenderers.count, 8)
        XCTAssertNotNil(shell.presenter.saturnRingRenderer)
        XCTAssertNotNil(shell.presenter.starRenderer)
        XCTAssertNotNil(shell.presenter.markerRenderer)
        session.close()
        XCTAssertFalse(shell.presenter.isLive)
        XCTAssertTrue(shell.presenter.bodyRenderers.isEmpty)
        XCTAssertTrue(shell.presenter.ringRenderers.isEmpty)
        XCTAssertTrue(shell.presenter.orbitRenderers.isEmpty)
        XCTAssertTrue(shell.presenter.trueOrbitRenderers.isEmpty)
        XCTAssertNil(shell.presenter.saturnRingRenderer)
        XCTAssertNil(shell.presenter.starRenderer)
        XCTAssertNil(shell.presenter.markerRenderer)
        XCTAssertNil(shell.presenter.ringRenderer)
        XCTAssertNil(shell.presenter.depthPass)
        XCTAssertEqual(shell.presenter.lastBodiesDrawn, 0)
        XCTAssertEqual(shell.presenter.bodyMeshes.count, 9, "the CPU meshes stay")
        XCTAssertEqual(shell.presenter.orbitMeshes.count, 8, "the CPU meshes stay")
        XCTAssertEqual(shell.presenter.trueOrbitMeshes.count, 8, "the CPU meshes stay")
        XCTAssertNotNil(shell.presenter.saturnRingMesh, "the CPU meshes stay")
        XCTAssertEqual(session.diagnostics.lastCloseCounts?.objects, 0)
        XCTAssertEqual(shell.state, .inactive, "closed without a GPU leak")
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
