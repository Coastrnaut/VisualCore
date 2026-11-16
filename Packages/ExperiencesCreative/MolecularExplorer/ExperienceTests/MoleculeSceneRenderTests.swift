// MoleculeSceneRenderTests — feature 111 (A15-P02) T-A15-205 (FR-A15-202, FR-A15-210; clarifications Q2, Q5;
// SC-A15-202). Both display modes of Molecular Explorer drawn inside the one app's session host on the simulator off
// screen, short runs only (each test under 10 s, no wall-clock assertion): for every library molecule ball-and-stick
// and space-filling each draw a non-blank, non-black frame with their probes holding, and the two frames differ; the
// items drawn are exactly the scene's (water in ball-and-stick: 3 atoms and 4 bond halves; space-filling draws no
// half), within the draw budget; the mode changes the description and the legend and keeps the molecule and camera.
import Foundation
import XCTest
@testable import MolecularExplorerExperience
import MolecularExplorerCore
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreRendering
import VisualCoreSimulation

/// Ball-and-stick and space-filling drawn through the session host.
@MainActor
final class MoleculeSceneRenderTests: XCTestCase {
    /// The view size in points of every drawn test.
    private let size = CGSize(width: 240, height: 160)

    /// Checks that `frame` is non-blank, not black and that every probe of `shell` holds on it.
    private func assertDrawn(_ shell: ExperienceShell<MoleculePresenter>, _ frame: MoleculeFrame, _ name: String) {
        XCTAssertTrue(FrameChecks.isNonBlank(frame.rgba, width: frame.width, height: frame.height), "\(name) not blank")
        XCTAssertFalse(FrameChecks.isBlack(frame.rgba, width: frame.width, height: frame.height), "\(name) not black")
        for probe in shell.frameProbes {
            let found = FrameChecks.probe(probe, rgba: frame.rgba, width: frame.width, height: frame.height)
            XCTAssertEqual(found?.rawValue, probe.expected, "\(name) \(probe.name)")
        }
    }

    /// Checks that the last frame of `shell` drew exactly the items of `scene`.
    private func assertCounts(_ shell: ExperienceShell<MoleculePresenter>, _ scene: MoleculeScene, _ name: String) {
        XCTAssertEqual(shell.presenter.lastAtomsDrawn, scene.atoms.count, "\(name) atoms")
        XCTAssertEqual(shell.presenter.lastHalvesDrawn, scene.bondHalves.count, "\(name) halves")
        XCTAssertEqual(shell.presenter.lastItemCount, scene.itemCount, "\(name) items")
        XCTAssertLessThanOrEqual(shell.presenter.lastItemCount, MoleculeScene.drawBudget, "\(name) budget")
    }

    func testBothModesDrawEveryMoleculeAndDiffer() async throws {
        let session = ExperienceSession()
        let shell = try await MoleculeTest.open(session, size: size)
        for (index, molecule) in MoleculeCore.library.enumerated() {
            XCTAssertTrue(shell.handle(control: "molecule.select", values: [Double(index)]).isAccepted)
            XCTAssertTrue(shell.handle(control: "display.mode", values: [0]).isAccepted)
            let ball = try MoleculeTest.picture(session)
            assertDrawn(shell, ball, "\(molecule.id) ball-and-stick")
            assertCounts(shell, MoleculeScene(molecule: molecule, mode: .ballAndStick), "\(molecule.id) ball")
            XCTAssertEqual(shell.presenter.lastMode, .ballAndStick)
            XCTAssertEqual(shell.presenter.lastHalvesDrawn, molecule.bonds.count * 2, molecule.id)

            XCTAssertTrue(shell.handle(control: "display.mode", values: [1]).isAccepted)
            let space = try MoleculeTest.picture(session)
            assertDrawn(shell, space, "\(molecule.id) space-filling")
            assertCounts(shell, MoleculeScene(molecule: molecule, mode: .spaceFilling), "\(molecule.id) space")
            XCTAssertEqual(shell.presenter.lastMode, .spaceFilling)
            XCTAssertEqual(shell.presenter.lastHalvesDrawn, 0, "\(molecule.id): space-filling draws no half")
            XCTAssertNotEqual(StableHash.sha256Hex(ball.rgba), StableHash.sha256Hex(space.rgba), molecule.id)
            XCTAssertGreaterThan(MoleculeTest.differingPixels(ball.rgba, space.rgba), 100,
                                 "\(molecule.id): the modes differ in many pixels")
        }
        session.close()
        XCTAssertEqual(session.hostsAlive, 0)
    }

    func testWaterInBallAndStickDrawsThreeAtomsAndFourHalves() async throws {
        let session = ExperienceSession()
        let shell = try await MoleculeTest.open(session, size: size)
        try MoleculeTest.frames(session, 1)
        XCTAssertEqual(shell.presenter.lastAtomsDrawn, 3)
        XCTAssertEqual(shell.presenter.lastHalvesDrawn, 4)
        XCTAssertEqual(shell.presenter.lastItemCount, 7)
        XCTAssertTrue(shell.handle(control: "display.mode", values: [1]).isAccepted)
        try MoleculeTest.frames(session, 1)
        XCTAssertEqual(shell.presenter.lastAtomsDrawn, 3)
        XCTAssertEqual(shell.presenter.lastHalvesDrawn, 0)
        XCTAssertEqual(shell.presenter.lastItemCount, 3)
        XCTAssertEqual(shell.presenter.rendererBuildCount, 1, "a mode change never remakes the renderers")
        session.close()
    }

    func testTheModeChangesTheWordsAndKeepsTheMoleculeAndTheCamera() async throws {
        let session = ExperienceSession()
        let shell = try await MoleculeTest.open(session, size: size)
        let presenter = shell.presenter
        XCTAssertTrue(shell.handle(control: "molecule.select", values: [4]).isAccepted)
        XCTAssertTrue(shell.handle(control: "camera.orbit", values: [1]).isAccepted)
        let camera = try MoleculeTest.core(shell).camera
        XCTAssertTrue(presenter.mirror.legend.hasPrefix("Ball and stick:"), presenter.mirror.legend)
        XCTAssertTrue(presenter.send("display.mode", [1], through: shell.port).isAccepted)
        XCTAssertEqual(presenter.mirror.message, "")
        XCTAssertTrue(shell.accessibilitySummary.hasSuffix("; space-filling."), shell.accessibilitySummary)
        XCTAssertEqual(presenter.mirror.mode, .spaceFilling)
        XCTAssertEqual(presenter.mirror.legend,
                       "Space filling: atoms at their van der Waals radius, no bonds. "
                       + "Display radii, not measured sizes.")
        let core = try MoleculeTest.core(shell)
        XCTAssertEqual(core.selection, 4, "the molecule stays")
        XCTAssertEqual(core.camera, camera, "the camera stays")
        XCTAssertEqual(presenter.send("display.mode", [0.5], through: shell.port).code,
                       "action.rule.a15.invalid-choice")
        XCTAssertEqual(presenter.mirror.message, "There is no such display mode.")
        XCTAssertEqual(try MoleculeTest.core(shell), core, "a refused mode changes nothing")
        session.close()
    }
}
