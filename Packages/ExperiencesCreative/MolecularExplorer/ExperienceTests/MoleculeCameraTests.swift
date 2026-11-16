// MoleculeCameraTests — feature 111 (A15-P02) T-A15-205 (FR-A15-220, FR-A15-221, FR-A15-230; clarifications Q3, Q4;
// SC-A15-203, SC-A15-204). The camera of Molecular Explorer drawn inside the one app's session host on the simulator
// off screen, short runs only (each test under 10 s, no wall-clock assertion): every camera step inside its limits
// changes the drawn frame, keeps the molecule's centre projected at the canvas centre within 1 pixel and keeps every
// declared probe holding; a tilt or zoom beyond its limit is refused with `a15.camera-limit` and changes nothing; Reset
// view frames the molecule again; a molecule change resets the camera and keeps the mode; a schema-1 saved state
// restores in schema 2 (ethanol, ball-and-stick, the default camera); a context recreation draws the same frame.
import Foundation
import XCTest
@testable import MolecularExplorerExperience
import MolecularExplorerCore
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreRendering
import VisualCoreSimulation

/// The camera of Molecular Explorer through the session host.
@MainActor
final class MoleculeCameraTests: XCTestCase {
    /// The view size in points of every drawn test.
    private let size = CGSize(width: 240, height: 160)

    /// Checks that the last frame of `shell` used the state's camera and drew the scene's centre at the canvas centre
    /// within 1 pixel (by the camera's own projection).
    private func assertCentred(_ shell: ExperienceShell<MoleculePresenter>, _ frame: MoleculeFrame,
                               _ name: String) throws {
        let core = try MoleculeTest.core(shell)
        let scene = try XCTUnwrap(core.state.scene)
        let canvas = Vec2(Double(frame.width), Double(frame.height))
        let camera = try XCTUnwrap(shell.presenter.lastCamera)
        XCTAssertEqual(camera, MoleculePresenter.camera(core.state, scene: scene, aspect: canvas.x / canvas.y), name)
        let p = MoleculePresenter.pixel(of: scene.centre, camera: camera, canvas: canvas)
        XCTAssertEqual(p.x, canvas.x / 2, accuracy: 1, "\(name): centre x")
        XCTAssertEqual(p.y, canvas.y / 2, accuracy: 1, "\(name): centre y")
    }

    func testEveryCameraStepChangesTheFrameAndKeepsTheCentre() async throws {
        let session = ExperienceSession()
        let shell = try await MoleculeTest.open(session, size: size)
        XCTAssertTrue(shell.handle(control: "molecule.select", values: [4]).isAccepted)
        var previous = try MoleculeTest.picture(session)
        try assertCentred(shell, previous, "default")
        // Every turn position, then the tilt from 20° up to 80° and down to −80°, then the zoom up to 4 and down to −4.
        var steps: [(String, Double)] = Array(repeating: ("camera.orbit", 1), count: CameraSettings.turnPositions)
        steps += Array(repeating: ("camera.tilt", 1), count: 6) + Array(repeating: ("camera.tilt", -1), count: 16)
        steps += Array(repeating: ("camera.zoom", 1), count: 4) + Array(repeating: ("camera.zoom", -1), count: 8)
        for (index, (control, value)) in steps.enumerated() {
            let name = "step \(index) \(control) \(value)"
            XCTAssertTrue(shell.handle(control: control, values: [value]).isAccepted, name)
            let frame = try MoleculeTest.picture(session)
            XCTAssertGreaterThan(MoleculeTest.differingPixels(previous.rgba, frame.rgba), 0,
                                 "\(name) changes the frame")
            XCTAssertTrue(FrameChecks.isNonBlank(frame.rgba, width: frame.width, height: frame.height), name)
            try assertCentred(shell, frame, name)
            for probe in shell.frameProbes {
                let found = FrameChecks.probe(probe, rgba: frame.rgba, width: frame.width, height: frame.height)
                XCTAssertEqual(found?.rawValue, probe.expected, "\(name) \(probe.name)")
            }
            previous = frame
        }
        let camera = try MoleculeTest.core(shell).camera
        XCTAssertEqual(camera, CameraSettings(turnSteps: 2, tiltSteps: -8, zoomSteps: -4))
        XCTAssertEqual(shell.presenter.mirror.cameraWords, "Turned 30°, tilted \u{2212}80°")
        XCTAssertEqual(shell.presenter.mirror.zoomWords, "Zoom step \u{2212}4 of \u{2212}4 to 4")
        session.close()
    }

    func testLimitsAreRefusedWithCameraLimitAndChangeNothing() async throws {
        let session = ExperienceSession()
        let shell = try await MoleculeTest.open(session, size: size)
        let presenter = shell.presenter
        let cases: [(control: String, value: Double, count: Int, answer: String)] = [
            ("camera.tilt", 1, 6, "The camera is tilted as far as it goes."),
            ("camera.tilt", -1, 16, "The camera is tilted as far as it goes."),
            ("camera.zoom", 1, 4, "The camera is zoomed as far as it goes."),
            ("camera.zoom", -1, 8, "The camera is zoomed as far as it goes."),
        ]
        for entry in cases {
            for _ in 0..<entry.count {
                XCTAssertTrue(presenter.send(entry.control, [entry.value], through: shell.port).isAccepted)
            }
            let core = try MoleculeTest.core(shell)
            let digest = try shell.engine.digest()
            let name = "\(entry.control) \(entry.value)"
            XCTAssertEqual(presenter.send(entry.control, [entry.value], through: shell.port).code,
                           "action.rule.a15.camera-limit", name)
            XCTAssertEqual(presenter.mirror.message, entry.answer, name)
            XCTAssertEqual(try MoleculeTest.core(shell), core, "\(name): the state is unchanged")
            XCTAssertEqual(try shell.engine.digest(), digest, name)
        }
        // A step other than ±1 is not a camera step.
        XCTAssertEqual(presenter.send("camera.orbit", [0], through: shell.port).code, "action.rule.a15.invalid-choice")
        XCTAssertEqual(presenter.send("camera.tilt", [0.5], through: shell.port).code, "action.rule.a15.invalid-choice")
        // A turn wraps and is never refused.
        for _ in 0..<(CameraSettings.turnPositions + 1) {
            XCTAssertTrue(shell.handle(control: "camera.orbit", values: [-1]).isAccepted)
        }
        XCTAssertEqual(try MoleculeTest.core(shell).camera.turnSteps, 1)
        session.close()
    }

    func testResetViewFramesTheMoleculeAgain() async throws {
        let session = ExperienceSession()
        let shell = try await MoleculeTest.open(session, size: size)
        XCTAssertTrue(shell.handle(control: "molecule.select", values: [3]).isAccepted)
        XCTAssertTrue(shell.handle(control: "display.mode", values: [1]).isAccepted)
        let framed = try MoleculeTest.picture(session)
        let actions: [(String, Double)] = [("camera.orbit", 1), ("camera.orbit", 1), ("camera.tilt", 1),
                                           ("camera.zoom", 1), ("camera.zoom", 1)]
        for (control, value) in actions {
            XCTAssertTrue(shell.handle(control: control, values: [value]).isAccepted, control)
        }
        let moved = try MoleculeTest.picture(session)
        XCTAssertNotEqual(StableHash.sha256Hex(framed.rgba), StableHash.sha256Hex(moved.rgba))
        XCTAssertTrue(shell.presenter.send("view.reset", through: shell.port).isAccepted)
        let core = try MoleculeTest.core(shell)
        XCTAssertEqual(core.camera, .default)
        XCTAssertEqual(core.mode, .spaceFilling, "the reset keeps the mode")
        XCTAssertEqual(core.selection, 3, "the reset keeps the molecule")
        let again = try MoleculeTest.picture(session)
        XCTAssertEqual(StableHash.sha256Hex(framed.rgba), StableHash.sha256Hex(again.rgba), "framed as before")
        try assertCentred(shell, again, "reset")
        XCTAssertEqual(shell.presenter.mirror.cameraWords, "Turned 30°, tilted 20°")
        XCTAssertEqual(shell.presenter.mirror.zoomWords, "Zoom step 0 of \u{2212}4 to 4")
        session.close()
    }

    func testAMoleculeChangeResetsTheCameraAndKeepsTheMode() async throws {
        let session = ExperienceSession()
        let shell = try await MoleculeTest.open(session, size: size)
        let actions: [(String, Double)] = [("display.mode", 1), ("camera.orbit", -1), ("camera.tilt", -1),
                                           ("camera.zoom", -1)]
        for (control, value) in actions {
            XCTAssertTrue(shell.handle(control: control, values: [value]).isAccepted, control)
        }
        XCTAssertNotEqual(try MoleculeTest.core(shell).camera, .default)
        XCTAssertTrue(shell.handle(control: "molecule.select", values: [2]).isAccepted)
        let core = try MoleculeTest.core(shell)
        XCTAssertEqual(core.camera, .default, "a new molecule is framed with the default camera")
        XCTAssertEqual(core.mode, .spaceFilling, "the mode stays")
        let frame = try MoleculeTest.picture(session)
        XCTAssertEqual(shell.presenter.lastMode, .spaceFilling)
        XCTAssertEqual(shell.presenter.lastSelection, 2)
        try assertCentred(shell, frame, "ethanol")
        XCTAssertTrue(shell.accessibilitySummary.hasSuffix("oxygen; space-filling."), shell.accessibilitySummary)
        XCTAssertTrue(shell.handle(control: "camera.zoom", values: [1]).isAccepted)
        XCTAssertTrue(shell.handle(control: "molecule.next").isAccepted)
        XCTAssertEqual(try MoleculeTest.core(shell).camera, .default, "next resets the camera too")
        session.close()
    }

    func testASchemaOneSavedStateRestoresInSchemaTwo() async throws {
        let first = ExperienceSession()
        let shell = try await MoleculeTest.open(first)
        let saved = try shell.snapshot()
        first.close()
        let payload = Data(#"{"schema":1,"selection":2}"#.utf8)
        let old = try moleculeEnvelope(payload, like: saved, schema: 1)

        let second = ExperienceSession()
        let opened = try await MoleculeTest.open(second, snapshot: old)
        XCTAssertNil(second.lastRestoreRefusal, "a schema-1 state is migrated, not refused")
        let core = try MoleculeTest.core(opened)
        XCTAssertEqual(core.state, MoleculeState(selection: 2, mode: .ballAndStick, camera: .default))
        XCTAssertEqual(core.molecule?.id, "ethanol")
        try MoleculeTest.frames(second, 1)
        XCTAssertEqual(opened.presenter.lastAtomsDrawn, 9)
        XCTAssertEqual(opened.presenter.lastHalvesDrawn, 16)
        let resaved = try opened.snapshot()
        XCTAssertEqual(resaved.schemaVersion, 2, "saved again in schema 2")
        XCTAssertEqual(Data(resaved.payload.utf8), MoleculeState(selection: 2).encoded())
        second.close()
    }

    func testAContextRecreationDrawsTheSameFrame() async throws {
        let session = ExperienceSession()
        let shell = try await MoleculeTest.open(session, size: size)
        let actions: [(String, Double)] = [("molecule.select", 4), ("camera.orbit", 1), ("camera.tilt", 1),
                                           ("camera.zoom", 1)]
        for (control, value) in actions {
            XCTAssertTrue(shell.handle(control: control, values: [value]).isAccepted, control)
        }
        let before = try MoleculeTest.picture(session)
        let builds = shell.presenter.rendererBuildCount
        let meshes = shell.presenter.meshBuildCount
        let digest = try shell.engine.digest()
        session.recreateContext()
        XCTAssertEqual(session.state, .running)
        let after = try MoleculeTest.picture(session)
        XCTAssertEqual(shell.presenter.rendererBuildCount, builds + 1, "both renderers are made once more, together")
        XCTAssertEqual(shell.presenter.renderers.count, 2)
        XCTAssertEqual(shell.presenter.meshBuildCount, meshes, "the unit meshes are CPU data and survive")
        XCTAssertEqual(StableHash.sha256Hex(before.rgba), StableHash.sha256Hex(after.rgba), "the drawing is the same")
        XCTAssertEqual(shell.presenter.lastItemCount, 74, "caffeine: 24 atoms and 50 halves")
        XCTAssertEqual(try shell.engine.digest(), digest)
        session.close()
        XCTAssertEqual(session.diagnostics.lastCloseCounts?.objects, 0)
    }
}
