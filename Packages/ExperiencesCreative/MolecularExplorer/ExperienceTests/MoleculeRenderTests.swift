// MoleculeRenderTests — feature 110 (A15-P01) T-A15-106 (FR-A15-131; clarification Q5; SC-A15-104). Molecular
// Explorer rendered inside the one app's session host on the simulator off screen, short runs only (each test under
// 10 s, no wall-clock assertion): every library molecule draws a non-blank, non-black frame with its background and
// atom probes holding; changing the molecule changes the drawn pixels, the mirror's lines and the description, and a
// still state draws the same frame; drawing never changes the state or its digest; the display radius of
// clarification Q5, the element meshes and colours; the camera centred on the molecule with every atom in view at
// every aspect; the words of the controls; teardown releases every GPU object together; and the experience's sources
// never create a graphics context of their own.
import Foundation
import XCTest
@testable import MolecularExplorerExperience
import MolecularExplorerCore
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreRendering
import VisualCoreScenes
import VisualCoreSimulation

/// Molecular Explorer drawn through the session host.
@MainActor
final class MoleculeRenderTests: XCTestCase {
    /// The view size in points of every drawn test.
    private let size = CGSize(width: 240, height: 160)

    /// Checks that `frame` is non-blank, not black and that every probe of `shell` holds on it.
    private func assertDrawn(_ shell: ExperienceShell<MoleculePresenter>, _ frame: MoleculeFrame, _ name: String) {
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

    func testEveryMoleculeDrawsANonBlankFrame() async throws {
        let session = ExperienceSession()
        let shell = try await MoleculeTest.open(session, size: size)
        var hashes: Set<String> = []
        for (index, molecule) in MoleculeCore.library.enumerated() {
            XCTAssertTrue(shell.handle(control: "molecule.select", values: [Double(index)]).isAccepted)
            let frame = try MoleculeTest.picture(session)
            assertDrawn(shell, frame, molecule.id)
            XCTAssertEqual(shell.presenter.lastAtomsDrawn, molecule.atoms.count, molecule.id)
            XCTAssertEqual(shell.presenter.lastSelection, index, molecule.id)
            let center = try XCTUnwrap(shell.presenter.lastCenter)
            XCTAssertLessThan((center - MoleculePresenter.center(of: molecule)).length, 1e-12, molecule.id)
            let canvas = Vec2(Double(frame.width), Double(frame.height))
            XCTAssertEqual(try XCTUnwrap(shell.presenter.lastCameraDistance),
                           MoleculePresenter.camera(for: molecule, aspect: canvas.x / canvas.y).distance,
                           accuracy: 1e-12, molecule.id)
            hashes.insert(StableHash.sha256Hex(frame.rgba))
        }
        XCTAssertEqual(hashes.count, 5, "every molecule draws its own frame")
        session.close()
        XCTAssertEqual(session.hostsAlive, 0)
    }

    func testChangingTheMoleculeChangesTheDrawnPixelsTheLinesAndTheDescription() async throws {
        let session = ExperienceSession()
        let shell = try await MoleculeTest.open(session, size: size)
        let before = try MoleculeTest.picture(session)
        let lines = [shell.presenter.mirror.nameLine, shell.presenter.mirror.countsLine,
                     shell.presenter.mirror.sourceLine]
        let description = shell.accessibilitySummary
        XCTAssertTrue(shell.handle(control: "molecule.select", values: [4]).isAccepted)
        let after = try MoleculeTest.picture(session)
        assertDrawn(shell, after, "caffeine")
        XCTAssertNotEqual(StableHash.sha256Hex(before.rgba), StableHash.sha256Hex(after.rgba), "the frame changes")
        XCTAssertGreaterThan(MoleculeTest.differingPixels(before.rgba, after.rgba), 100, "many pixels change")
        let nowLines = [shell.presenter.mirror.nameLine, shell.presenter.mirror.countsLine,
                        shell.presenter.mirror.sourceLine]
        XCTAssertEqual(nowLines, ["Caffeine — C8H10N4O2", "24 atoms, 25 bonds",
                                  "PubChem Compound CID 2519, 3D conformer — public domain"])
        for (old, new) in zip(lines, nowLines) { XCTAssertNotEqual(old, new, "the line changes") }
        XCTAssertNotEqual(shell.accessibilitySummary, description, "the description changes")
        XCTAssertEqual(shell.accessibilitySummary,
                       "Molecular Explorer: Caffeine, C8H10N4O2; 24 atoms, 25 bonds; elements carbon, hydrogen, "
                       + "nitrogen, oxygen.")
        // Nitrogen's blue is drawn somewhere on the canvas (lit at least at the ambient fraction).
        let nitrogen = MoleculePresenter.color(hex: "3050F8")
        let lit = Vec4(nitrogen.x * 0.8, nitrogen.y * 0.8, nitrogen.z * 0.8, 1)
        XCTAssertGreaterThan(MoleculeTest.pixels(near: lit, in: after, tolerance: 60), 0, "nitrogen is drawn")

        // The same state draws the same frame.
        let again = try MoleculeTest.picture(session)
        XCTAssertEqual(StableHash.sha256Hex(after.rgba), StableHash.sha256Hex(again.rgba), "a still state holds")
        session.close()
    }

    func testDrawingNeverChangesTheState() async throws {
        let session = ExperienceSession()
        let shell = try await MoleculeTest.open(session, size: size)
        XCTAssertTrue(shell.handle(control: "molecule.select", values: [3]).isAccepted)
        let core = try MoleculeTest.core(shell)
        let digest = try shell.engine.digest()
        try MoleculeTest.frames(session, 10)
        _ = shell.accessibilitySummary
        _ = shell.frameProbes
        XCTAssertEqual(try MoleculeTest.core(shell), core, "the presenter reads the core only")
        XCTAssertEqual(try shell.engine.digest(), digest)

        // Describing a core in a presenter of its own leaves the value as it was.
        let presenter = MoleculePresenter(experienceID: MoleculeTest.id)
        let copy = core
        _ = presenter.describe(core)
        XCTAssertEqual(core, copy)
        XCTAssertEqual(presenter.probes(core), [], "no probe before the first frame")
        XCTAssertEqual(presenter.mirror.nameLine, "Benzene — C6H6", "describing syncs the mirror")
        session.close()
    }

    func testTheDisplayRadiusTheMeshesAndTheColours() {
        XCTAssertEqual(MoleculePresenter.displayScale, 0.35)
        XCTAssertEqual(MoleculePresenter.displayRadius(symbol: "H"), 0.35 * 1.20, accuracy: 1e-12)
        XCTAssertEqual(MoleculePresenter.displayRadius(symbol: "C"), 0.35 * 1.70, accuracy: 1e-12)
        XCTAssertEqual(MoleculePresenter.displayRadius(symbol: "cl"), 0.35 * 1.75, accuracy: 1e-12)
        XCTAssertEqual(MoleculePresenter.displayRadius(symbol: "Xx"), 0.35 * 1.5, accuracy: 1e-12)
        XCTAssertLessThanOrEqual(MoleculePresenter.sphereSegments, 32)
        XCTAssertLessThanOrEqual(MoleculePresenter.sphereRings, 16)
        let meshes = MoleculePresenter.meshes()
        XCTAssertEqual(meshes.count, Elements.all.count)
        for (index, element) in Elements.all.enumerated() {
            XCTAssertEqual(meshes[index], Mesh.uvSphere(segments: 32, rings: 16,
                                                        radius: 0.35 * element.vanDerWaalsRadius), element.symbol)
            XCTAssertEqual(MoleculePresenter.elementIndex(symbol: element.symbol), index)
            let color = MoleculePresenter.color(hex: element.colorHex)
            XCTAssertTrue(color.x >= 0 && color.x <= 1 && color.y >= 0 && color.y <= 1 && color.z >= 0
                          && color.z <= 1 && color.w == 1, "\(element.symbol): \(color)")
        }
        XCTAssertNil(MoleculePresenter.elementIndex(symbol: "Xx"))
        XCTAssertEqual(MoleculePresenter.color(hex: "FF0D0D"), Vec4(1, 13.0 / 255, 13.0 / 255, 1))
        XCTAssertEqual(MoleculePresenter.color(hex: "FFFFFF"), Vec4(1, 1, 1, 1))
        XCTAssertEqual(MoleculePresenter.color(hex: "zz"), Vec4(0.5, 0.5, 0.5, 1))
        XCTAssertEqual(MoleculePresenter.robustClass(Vec3(1, 0.05, 0.05)), "red", "oxygen")
        XCTAssertEqual(MoleculePresenter.robustClass(Vec3(0.19, 0.31, 0.97)), "blue", "nitrogen")
        XCTAssertNil(MoleculePresenter.robustClass(Vec3(0.92, 0.92, 0.92)), "lit hydrogen is not robust")
        XCTAssertEqual(MoleculePresenter.classify(red: 5, green: 6, blue: 12), "dark")
        XCTAssertGreaterThan(MoleculePresenter.lightDirection.dot(MoleculePresenter.camera(
            for: MoleculeCore.library[0], aspect: 1.5).eye - MoleculePresenter.center(of: MoleculeCore.library[0])),
                             0, "the light comes from the camera's side")
    }

    func testTheCameraIsCentredOnTheMoleculeWithEveryAtomInView() {
        let aspects: [Double] = [0.46, 1, 1.5, 2.16]
        for molecule in MoleculeCore.library {
            let center = MoleculePresenter.center(of: molecule)
            var sum = Vec3(0, 0, 0)
            for atom in molecule.atoms { sum = sum + Vec3(atom.x, atom.y, atom.z) }
            XCTAssertLessThan((center - sum * (1 / Double(molecule.atoms.count))).length, 1e-12, molecule.id)
            let radius = MoleculePresenter.boundingRadius(of: molecule)
            for atom in molecule.atoms {
                let reach = (MoleculePresenter.position(atom) - center).length
                    + MoleculePresenter.displayRadius(symbol: atom.symbol)
                XCTAssertLessThanOrEqual(reach, radius + 1e-12, "\(molecule.id): inside the bounding sphere")
            }
            for aspect in aspects {
                let camera = MoleculePresenter.camera(for: molecule, aspect: aspect)
                XCTAssertEqual(camera.target, center)
                XCTAssertGreaterThan(camera.distance, radius, "\(molecule.id): the eye is outside the molecule")
                let name = "\(molecule.id) aspect \(aspect)"
                // Every atom's sphere lies inside the view: its centre ± its radius along the screen axes.
                for atom in molecule.atoms {
                    let p = MoleculePresenter.position(atom)
                    let r = MoleculePresenter.displayRadius(symbol: atom.symbol)
                    let ndc = camera.project(p, aspect: aspect)
                    XCTAssertTrue(abs(ndc.x) < 1 && abs(ndc.y) < 1, "\(name): atom in view \(ndc)")
                    let forward = (camera.target - camera.eye).normalized
                    let viewZ = (p - camera.eye).dot(forward)
                    let halfV = tan(MoleculePresenter.fieldOfView / 2)
                    let extentY = r / (viewZ * halfV), extentX = r / (viewZ * halfV * aspect)
                    XCTAssertLessThan(abs(ndc.x) + extentX, 1, "\(name): sphere inside horizontally")
                    XCTAssertLessThan(abs(ndc.y) + extentY, 0.92, "\(name): sphere below the background probe")
                }
            }
        }
        XCTAssertEqual(MoleculePresenter.camera(for: MoleculeCore.library[4], aspect: .nan),
                       MoleculePresenter.camera(for: MoleculeCore.library[4], aspect: 1))
    }

    func testTheWordsOfTheControls() async throws {
        XCTAssertEqual(MoleculePresenter.answerWords(control: "molecule.next", result: .accepted), "")
        let refused = ActionResult.rejected(.rule(code: MoleculeRule.invalidChoice))
        XCTAssertEqual(MoleculePresenter.answerWords(control: "molecule.next", result: refused),
                       "Caffeine is the last molecule.")
        XCTAssertEqual(MoleculePresenter.answerWords(control: "molecule.previous", result: refused),
                       "Water is the first molecule.")
        XCTAssertEqual(MoleculePresenter.answerWords(control: "molecule.select", result: refused),
                       "There is no such molecule.")
        XCTAssertEqual(MoleculePresenter.answerWords(control: "bogus", result: refused), "That is not possible here.")
        XCTAssertEqual(MoleculeControls.moleculeWords(index: 4, count: 5), "Caffeine, molecule 5 of 5")
        XCTAssertEqual(MoleculeControls.sentence("water selected"), "Water selected")
        XCTAssertEqual(MoleculeControls.sentence(""), "Loading")

        let session = ExperienceSession()
        let shell = try await MoleculeTest.open(session, size: size)
        let names: [String] = ["previous-molecule", "next-molecule", "molecule", "name", "counts", "source", "status",
                               "message"]
        for name in names {
            XCTAssertEqual(shell.port.identifier(name), "experience.a15.molecular-explorer.\(name)")
        }
        XCTAssertEqual(shell.port.send("molecule.previous").code, "action.rule.a15.invalid-choice")
        XCTAssertTrue(shell.port.send("molecule.next").isAccepted)
        XCTAssertTrue(shell.accessibilitySummary.hasPrefix("Molecular Explorer: Methane, CH4;"),
                      shell.accessibilitySummary)
        session.close()
    }

    func testTeardownReleasesEveryGPUObjectTogether() async throws {
        let session = ExperienceSession()
        let shell = try await MoleculeTest.open(session, size: size)
        XCTAssertTrue(shell.handle(control: "molecule.select", values: [2]).isAccepted)
        try MoleculeTest.frames(session, 2)
        XCTAssertEqual(shell.presenter.elementRenderers.count, Elements.all.count)
        XCTAssertNotNil(shell.presenter.depthPass)
        session.close()
        XCTAssertFalse(shell.presenter.isLive)
        XCTAssertTrue(shell.presenter.elementRenderers.isEmpty)
        XCTAssertNil(shell.presenter.depthPass)
        XCTAssertEqual(shell.presenter.lastAtomsDrawn, 0)
        XCTAssertEqual(shell.presenter.elementMeshes.count, Elements.all.count, "the CPU meshes stay")
        XCTAssertEqual(session.diagnostics.lastCloseCounts?.objects, 0)
        XCTAssertEqual(shell.state, .inactive, "closed without a GPU leak")
    }

    func testTheExperienceNeverCreatesAGraphicsContextOfItsOwn() throws {
        let directory = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Experience")
        let files = try XCTUnwrap(FileManager.default.enumerator(at: directory, includingPropertiesForKeys: nil))
            .compactMap { $0 as? URL }.filter { $0.pathExtension == "swift" }
        XCTAssertGreaterThanOrEqual(files.count, 4)
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
