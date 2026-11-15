// SolarRenderTests — feature 103 (A14-P01) T-A14-103 (FR-A14-120, 121; clarifications Q4, Q5; SC-A14-104). Solar
// System Explorer rendered inside the one app's session host on the simulator, short runs only (each test under 10 s,
// no wall-clock assertion): a drawn frame with the Sun, Earth and Neptune selected is non-blank and not black, with
// its background and body probes holding; changing the selection changes the drawn pixels where the ring outline was
// and where it now is, and the fact card; drawing never changes the state or its digest; the display radius formula
// and the line-up of clarification Q4; the camera fits the row; the procedural two-band colours; the words of the
// controls; teardown releases every GPU object; and the experience's sources never create a graphics context of their
// own.
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

    private func assertDrawn(_ shell: ExperienceShell<SolarPresenter>, _ frame: SolarFrame, _ name: String) {
        XCTAssertGreaterThan(frame.width, 0)
        XCTAssertTrue(FrameChecks.isNonBlank(frame.rgba, width: frame.width, height: frame.height), "\(name) not blank")
        XCTAssertFalse(FrameChecks.isBlack(frame.rgba, width: frame.width, height: frame.height), "\(name) not black")
        let probes = shell.frameProbes
        XCTAssertGreaterThanOrEqual(probes.count, 1, "\(name): at least the background")
        XCTAssertEqual(probes.first?.name, "background", name)
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
        XCTAssertTrue(shell.handle(control: "body.select", values: [8]).isAccepted)
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
        // Pixels per world unit on the row's plane.
        let camera = SolarPresenter.camera(aspect: canvas.x / canvas.y)
        let scale = canvas.y / (2 * camera.distance * tan(SolarPresenter.fieldOfView / 2))
        // The ring's top point around the Sun, and around Earth.
        let sunRing = SolarPresenter.ringRadius(displayRadius: SolarPresenter.sunDisplayRadius)
        let sunTop = SolarPresenter.pixel(of: Vec3(0, sunRing, 0), canvas: canvas)
        let earthRing = SolarPresenter.ringRadius(displayRadius: SolarPresenter.displayRadius(index: 3))
        let earthTop = SolarPresenter.pixel(of: Vec3(SolarPresenter.xPosition(index: 3), earthRing, 0), canvas: canvas)
        let radius = max(1, Int((SolarPresenter.ringTubeRadius * 2 * scale).rounded(.up)))
        XCTAssertTrue(shell.handle(control: "body.select", values: [3]).isAccepted)
        let after = try SolarTest.picture(session)
        assertDrawn(shell, after, "Earth")
        XCTAssertNotEqual(StableHash.sha256Hex(before.rgba), StableHash.sha256Hex(after.rgba), "the frame changes")
        XCTAssertGreaterThan(SolarTest.differingPixels(before, after, around: sunTop, radius: radius), 0,
                             "the ring left the Sun")
        XCTAssertGreaterThan(SolarTest.differingPixels(before, after, around: earthTop, radius: radius), 0,
                             "the ring is around Earth")
        XCTAssertGreaterThan(SolarTest.pixels(near: SolarPresenter.ringColor, in: after), 0, "the ring is drawn")
        XCTAssertNotEqual(shell.presenter.mirror.facts, card, "the card changes")
        XCTAssertEqual(shell.presenter.mirror.facts,
                       try XCTUnwrap(BodyCatalog.bundled.factCard(for: 3)).facts.map(\.text))

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

    func testTheDisplayRadiusFormulaAndTheLineUpOfClarificationQ4() throws {
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

        // The Sun at x = 0, the planets to its right 2.4 apart, none touching its neighbour.
        XCTAssertEqual(SolarPresenter.xPosition(index: 0), 0)
        XCTAssertEqual(SolarPresenter.xPosition(index: 1), 2.8, accuracy: 1e-12)
        for index in 1..<9 {
            let gap = SolarPresenter.xPosition(index: index) - SolarPresenter.xPosition(index: index - 1)
            if index > 1 { XCTAssertEqual(gap, 2.4, accuracy: 1e-12, "even spacing at \(index)") }
            XCTAssertGreaterThan(gap - SolarPresenter.displayRadius(index: index)
                                 - SolarPresenter.displayRadius(index: index - 1), 0.3, "apart at \(index)")
        }

        // The meshes: nine UV spheres of 32 segments and 16 rings at the display radius, one colour per vertex.
        let meshes = SolarPresenter.meshes()
        XCTAssertEqual(meshes.count, 9)
        for (index, part) in meshes.enumerated() {
            XCTAssertEqual(part.mesh, Mesh.uvSphere(segments: 32, rings: 16,
                                                    radius: SolarPresenter.displayRadius(index: index)))
            XCTAssertEqual(part.colors.count, part.mesh.positions.count)
        }
        let ring = try SolarPresenter.ringMesh(selection: 3)
        XCTAssertGreaterThan(ring.triangleCount, 0)
        let outer = SolarPresenter.ringRadius(displayRadius: SolarPresenter.displayRadius(index: 3))
            + SolarPresenter.ringTubeRadius
        for position in ring.positions {
            XCTAssertLessThanOrEqual((position.x * position.x + position.y * position.y).squareRoot(), outer + 1e-9)
            XCTAssertGreaterThan((position.x * position.x + position.y * position.y).squareRoot(),
                                 SolarPresenter.displayRadius(index: 3), "the ring lies outside the body")
        }
    }

    func testTheCameraFitsTheRow() {
        let aspects: [Double] = [0.46, 1, 1.5, 2.16]
        let extent = SolarPresenter.rowExtent
        for aspect in aspects {
            let camera = SolarPresenter.camera(aspect: aspect)
            XCTAssertEqual(camera.yaw, 0)
            XCTAssertEqual(camera.pitch, 0)
            let left = camera.project(Vec3(extent.minX, 0, 0), aspect: aspect)
            let right = camera.project(Vec3(extent.maxX, 0, 0), aspect: aspect)
            let top = camera.project(Vec3(0, extent.halfHeight, 0), aspect: aspect)
            XCTAssertGreaterThanOrEqual(left.x, -1 / 1.1 - 1e-9, "aspect \(aspect): left inside")
            XCTAssertLessThanOrEqual(right.x, 1 / 1.1 + 1e-9, "aspect \(aspect): right inside")
            XCTAssertLessThanOrEqual(top.y, 0.8 + 1e-9, "aspect \(aspect): the top below the background probe")
            XCTAssertEqual(left.x, -right.x, accuracy: 1e-9, "aspect \(aspect): centred")
        }
        XCTAssertEqual(SolarPresenter.camera(aspect: .nan), SolarPresenter.camera(aspect: 1))
    }

    func testTheTwoBandColoursAreProceduralAndDeterministic() {
        XCTAssertEqual(SolarPresenter.palettes.count, 9)
        for (index, palette) in SolarPresenter.palettes.enumerated() {
            XCTAssertEqual(palette.bands % 2, 1, "body \(index): the equator lies in a band")
            XCTAssertNotEqual(palette.first, palette.second, "body \(index): two colours")
            let mesh = Mesh.uvSphere(segments: 32, rings: 16, radius: 1)
            let colors = SolarPresenter.colors(mesh: mesh, index: index)
            XCTAssertEqual(colors, SolarPresenter.colors(mesh: mesh, index: index), "body \(index): deterministic")
            for color in colors {
                XCTAssertTrue(color.x >= 0 && color.x <= 1 && color.y >= 0 && color.y <= 1 && color.z >= 0
                              && color.z <= 1 && color.w == 1, "body \(index): \(color)")
            }
            XCTAssertGreaterThanOrEqual(Set(colors).count, 2, "body \(index): bands")
        }
        XCTAssertEqual(SolarPresenter.band(v: 0.5, bands: 5), 2)
        XCTAssertEqual(SolarPresenter.band(v: 1, bands: 5), 4)
        XCTAssertEqual(SolarPresenter.band(v: 0, bands: 3), 0)
        let hash = SolarPresenter.unitHash(seed: 4, band: 2)
        XCTAssertEqual(hash, SolarPresenter.unitHash(seed: 4, band: 2))
        XCTAssertTrue(hash >= 0 && hash < 1)
        XCTAssertEqual(SolarPresenter.robustClass([Vec3(1, 0.62, 0.18)]), "red")
        XCTAssertNil(SolarPresenter.robustClass([]))
        XCTAssertEqual(SolarPresenter.classify(red: 5, green: 6, blue: 12), "dark")
    }

    func testTheWordsOfTheControls() async throws {
        XCTAssertEqual(SolarPresenter.answerWords(control: "body.next", result: .accepted), "")
        let refused = ActionResult.rejected(.rule(code: SolarRule.invalidChoice))
        XCTAssertEqual(SolarPresenter.answerWords(control: "body.next", result: refused), "Neptune is the last body.")
        XCTAssertEqual(SolarPresenter.answerWords(control: "body.previous", result: refused),
                       "The Sun is the first body.")
        XCTAssertEqual(SolarPresenter.answerWords(control: "body.select", result: refused), "There is no such body.")
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
        let names: [String] = ["previous-body", "next-body", "body", "fact-1", "legend", "status", "message"]
        for name in names {
            XCTAssertEqual(shell.port.identifier(name), "experience.a14.solar-system-explorer.\(name)")
        }
        XCTAssertEqual(shell.port.send("body.previous").code, "action.rule.a14.invalid-choice")
        XCTAssertTrue(shell.port.send("body.next").isAccepted)
        XCTAssertTrue(shell.accessibilitySummary.hasPrefix("Solar System Explorer: Mercury selected;"),
                      shell.accessibilitySummary)
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
        session.close()
        XCTAssertFalse(shell.presenter.isLive)
        XCTAssertTrue(shell.presenter.bodyRenderers.isEmpty)
        XCTAssertNil(shell.presenter.ringRenderer)
        XCTAssertNil(shell.presenter.depthPass)
        XCTAssertEqual(shell.presenter.lastBodiesDrawn, 0)
        XCTAssertEqual(shell.presenter.bodyMeshes.count, 9, "the CPU meshes stay")
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
