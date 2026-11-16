// MoleculeRenderTests — feature 110 (A15-P01) T-A15-106 (FR-A15-131; clarification Q5; SC-A15-104), updated by feature
// 111 (A15-P02) T-A15-205 (FR-A15-202, FR-A15-210, FR-A15-230; clarifications Q2, Q5). Molecular Explorer rendered
// inside the one app's session host on the simulator off screen, short runs only (each test under 10 s, no wall-clock
// assertion): every library molecule draws a non-blank, non-black frame with its background and atom probes holding;
// changing the molecule changes the drawn pixels, the mirror's lines and the description, and a still state draws the
// same frame; drawing never changes the state or its digest; the unit sphere and stick meshes, their model matrices
// and the colours; the default camera centred on the scene with every atom in view at every aspect in both modes; the
// words of the controls; teardown releases both renderers together; and the experience's sources never create a
// graphics context of their own.
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
            let state = MoleculeState(selection: index)
            let scene = try XCTUnwrap(state.scene)
            XCTAssertEqual(shell.presenter.lastAtomsDrawn, molecule.atoms.count, molecule.id)
            XCTAssertEqual(shell.presenter.lastHalvesDrawn, scene.bondHalves.count, molecule.id)
            XCTAssertEqual(shell.presenter.lastSelection, index, molecule.id)
            let center = try XCTUnwrap(shell.presenter.lastCenter)
            XCTAssertLessThan((center - scene.centre).length, 1e-12, molecule.id)
            let canvas = Vec2(Double(frame.width), Double(frame.height))
            XCTAssertEqual(shell.presenter.lastCamera,
                           MoleculePresenter.camera(state, scene: scene, aspect: canvas.x / canvas.y), molecule.id)
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
                       + "nitrogen, oxygen; ball-and-stick.")
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

    func testTheUnitMeshesTheModelMatricesAndTheColours() throws {
        XCTAssertEqual(MoleculePresenter.unitSphere(), Mesh.uvSphere(segments: 32, rings: 16, radius: 1))
        XCTAssertEqual(try MoleculePresenter.unitStick(),
                       try Mesh.tube(path: [Vec3(0, 0, 0), Vec3(0, 1, 0)], radius: 0.12, sides: 16, caps: false,
                                     closed: false))
        // The shortest-arc turn from +y, including the parallel and antiparallel cases.
        let directions: [Vec3] = [Vec3(0, 1, 0), Vec3(0, -1, 0), Vec3(1, 0, 0), Vec3(0.6, -0.8, 0), Vec3(0, 0, -1)]
        for direction in directions {
            let turned = MoleculePresenter.rotationFromUp(to: direction).rotate(Vec3(0, 1, 0))
            XCTAssertLessThan((turned - direction).length, 1e-12, "\(direction)")
        }
        // Every atom model puts the unit sphere's surface at the display radius; every half model puts the stick's
        // ends on the half's ends.
        for molecule in MoleculeCore.library {
            for mode in DisplayMode.allCases {
                let scene = MoleculeScene(molecule: molecule, mode: mode)
                for atom in scene.atoms {
                    let model = MoleculePresenter.atomModel(atom)
                    XCTAssertLessThan((model.applyPoint(Vec3(0, 0, 0)) - atom.position).length, 1e-12)
                    XCTAssertEqual((model.applyPoint(Vec3(0, 0, 1)) - atom.position).length, atom.radius,
                                   accuracy: 1e-12, "\(molecule.id) \(atom.symbol)")
                }
                for half in scene.bondHalves {
                    let model = try XCTUnwrap(MoleculePresenter.halfModel(half))
                    XCTAssertLessThan((model.applyPoint(Vec3(0, 0, 0)) - half.from).length, 1e-12, molecule.id)
                    XCTAssertLessThan((model.applyPoint(Vec3(0, 1, 0)) - half.to).length, 1e-12, molecule.id)
                    // The stick's radius is not stretched: a side point stays 0.12 from the axis.
                    let side = model.applyPoint(Vec3(DisplayMode.stickRadius, 0.5, 0))
                    let axis = (half.from + half.to) * 0.5
                    XCTAssertEqual((side - axis).length, DisplayMode.stickRadius, accuracy: 1e-12, molecule.id)
                }
            }
        }
        XCTAssertNil(MoleculePresenter.halfModel(MoleculeScene.BondHalf(from: Vec3(1, 1, 1), to: Vec3(1, 1, 1),
                                                                          symbol: "C", radius: 0.12)))
        XCTAssertEqual(MoleculePresenter.color(symbol: "O"), MoleculePresenter.color(hex: "FF0D0D"))
        XCTAssertEqual(MoleculePresenter.color(symbol: "Xx"), Vec4(0.5, 0.5, 0.5, 1))
        for element in Elements.all {
            let color = MoleculePresenter.color(hex: element.colorHex)
            XCTAssertTrue(color.x >= 0 && color.x <= 1 && color.y >= 0 && color.y <= 1 && color.z >= 0
                          && color.z <= 1 && color.w == 1, "\(element.symbol): \(color)")
        }
        XCTAssertEqual(MoleculePresenter.color(hex: "FF0D0D"), Vec4(1, 13.0 / 255, 13.0 / 255, 1))
        XCTAssertEqual(MoleculePresenter.color(hex: "FFFFFF"), Vec4(1, 1, 1, 1))
        XCTAssertEqual(MoleculePresenter.color(hex: "zz"), Vec4(0.5, 0.5, 0.5, 1))
        XCTAssertEqual(MoleculePresenter.robustClass(Vec3(1, 0.05, 0.05)), "red", "oxygen")
        XCTAssertEqual(MoleculePresenter.robustClass(Vec3(0.19, 0.31, 0.97)), "blue", "nitrogen")
        XCTAssertNil(MoleculePresenter.robustClass(Vec3(0.92, 0.92, 0.92)), "lit hydrogen is not robust")
        XCTAssertEqual(MoleculePresenter.classify(red: 5, green: 6, blue: 12), "dark")
        // The light comes from the camera's side at every tilt.
        let scene = try XCTUnwrap(MoleculeState.initial.scene)
        for tilt in CameraSettings.tiltRange {
            let state = MoleculeState(selection: 0, camera: CameraSettings(turnSteps: 5, tiltSteps: tilt, zoomSteps: 0))
            let camera = MoleculePresenter.camera(state, scene: scene, aspect: 1.5)
            XCTAssertGreaterThan(MoleculePresenter.lightDirection(for: camera).dot(camera.eye - camera.target), 0,
                                 "tilt \(tilt)")
        }
    }

    func testTheDefaultCameraIsCentredOnTheSceneWithEveryAtomInView() {
        let aspects: [Double] = [0.46, 1, 1.5, 2.16]
        for (index, molecule) in MoleculeCore.library.enumerated() {
            for mode in DisplayMode.allCases {
                let state = MoleculeState(selection: index, mode: mode)
                let scene = MoleculeScene(molecule: molecule, mode: mode)
                for aspect in aspects {
                    let camera = MoleculePresenter.camera(state, scene: scene, aspect: aspect)
                    let name = "\(molecule.id) \(mode.name) aspect \(aspect)"
                    XCTAssertEqual(camera.target, scene.centre, name)
                    XCTAssertGreaterThan(camera.distance, scene.boundingRadius, "\(name): the eye is outside")
                    let forward = (camera.target - camera.eye).normalized
                    let halfV = tan(CameraSettings.verticalFieldOfViewDegrees * .pi / 360)
                    // Every atom's sphere lies inside the view: its centre ± its radius along the screen axes.
                    for atom in scene.atoms {
                        let ndc = camera.project(atom.position, aspect: aspect)
                        let viewZ = (atom.position - camera.eye).dot(forward)
                        let extentY = atom.radius / (viewZ * halfV), extentX = atom.radius / (viewZ * halfV * aspect)
                        XCTAssertLessThan(abs(ndc.x) + extentX, 1, "\(name): sphere inside horizontally")
                        XCTAssertLessThan(abs(ndc.y) + extentY, 0.92, "\(name): sphere below the background probe")
                    }
                }
            }
        }
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
        let limit = ActionResult.rejected(.rule(code: MoleculeRule.cameraLimit))
        XCTAssertEqual(MoleculePresenter.answerWords(control: "camera.tilt", result: limit),
                       "The camera is tilted as far as it goes.")
        XCTAssertEqual(MoleculePresenter.answerWords(control: "camera.zoom", result: limit),
                       "The camera is zoomed as far as it goes.")
        XCTAssertEqual(MoleculePresenter.answerWords(control: "display.mode", result: refused),
                       "There is no such display mode.")
        XCTAssertEqual(MoleculePresenter.cameraWords(.default), "Turned 30°, tilted 20°")
        XCTAssertEqual(MoleculePresenter.cameraWords(CameraSettings(turnSteps: 23, tiltSteps: -8, zoomSteps: 0)),
                       "Turned 345°, tilted \u{2212}80°")
        XCTAssertEqual(MoleculePresenter.zoomWords(.default), "Zoom step 0 of \u{2212}4 to 4")
        XCTAssertEqual(MoleculePresenter.zoomWords(CameraSettings(turnSteps: 0, tiltSteps: 0, zoomSteps: -3)),
                       "Zoom step \u{2212}3 of \u{2212}4 to 4")
        XCTAssertEqual(MoleculePresenter.modeTitle(.ballAndStick), "Ball and stick")
        XCTAssertEqual(MoleculePresenter.modeTitle(.spaceFilling), "Space filling")
        for mode in DisplayMode.allCases {
            XCTAssertTrue(MoleculePresenter.legend(mode).hasSuffix("Display radii, not measured sizes."), mode.name)
        }
        XCTAssertEqual(MoleculeControls.moleculeWords(index: 4, count: 5), "Caffeine, molecule 5 of 5")
        XCTAssertEqual(MoleculeControls.sentence("water selected"), "Water selected")
        XCTAssertEqual(MoleculeControls.sentence(""), "Loading")

        let session = ExperienceSession()
        let shell = try await MoleculeTest.open(session, size: size)
        let names: [String] = ["previous-molecule", "next-molecule", "molecule", "name", "counts", "source", "status",
                               "message", "display-mode", "turn-left", "turn-right", "tilt-up", "tilt-down", "zoom-in",
                               "zoom-out", "reset-view", "legend"]
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
        XCTAssertEqual(shell.presenter.renderers.count, 2)
        XCTAssertNotNil(shell.presenter.depthPass)
        session.close()
        XCTAssertFalse(shell.presenter.isLive)
        XCTAssertTrue(shell.presenter.renderers.isEmpty)
        XCTAssertNil(shell.presenter.depthPass)
        XCTAssertEqual(shell.presenter.lastAtomsDrawn, 0)
        XCTAssertEqual(shell.presenter.lastHalvesDrawn, 0)
        XCTAssertNotNil(shell.presenter.sphereMesh, "the CPU meshes stay")
        XCTAssertNotNil(shell.presenter.stickMesh, "the CPU meshes stay")
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
