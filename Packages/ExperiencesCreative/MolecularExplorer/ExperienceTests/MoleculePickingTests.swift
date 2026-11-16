// MoleculePickingTests — feature 112 (A15-P03) T-A15-305 (FR-A15-302, FR-A15-310, FR-A15-311, FR-A15-330;
// clarifications Q2, Q3, Q5; SC-A15-301; edge cases "A tap that hits nothing", "Changing the mode", "Panning at a
// limit", "A state saved under schema 2"). Picking through the one app's session host on the simulator, short runs only
// (each test well under 10 s, no wall-clock assertion): a tap on the projected centre of caffeine's atom 3 (index 2,
// a nitrogen) selects it; a tap on an empty corner clears the selection; after turns and pans the drawn camera is
// used (the atom's point moved and still picks it); the selection survives a mode change and space-filling picks with
// its own radii; `camera.pan` refuses (0, 0) and values other than −1, 0, 1, and a step beyond 10 with
// `a15.camera-limit`; schema-1 and schema-2 saved states open in schema 3 with no selection and no pan.
import Foundation
import XCTest
@testable import MolecularExplorerExperience
import MolecularExplorerCore
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreScenes

/// Picking atoms through the session host.
@MainActor
final class MoleculePickingTests: XCTestCase {
    /// The view size in points of every drawn test.
    private let size = CGSize(width: 240, height: 160)
    /// The same size as a vector.
    private var viewSize: Vec2 { Vec2(Double(size.width), Double(size.height)) }
    /// The clock of the synthetic taps (each tap later than the one before).
    private var clock = 0.0

    /// Taps the view point `point` through the shell.
    private func tap(_ shell: ExperienceShell<MoleculePresenter>, at point: Vec2) {
        clock += 1
        shell.handlePointer(PointerEvent(id: 1, phase: .began, location: point, timestamp: clock), viewSize: viewSize)
        shell.handlePointer(PointerEvent(id: 1, phase: .ended, location: point, timestamp: clock + 0.05),
                            viewSize: viewSize)
    }

    /// The view point (points, top-left origin) where atom `index` of the last drawn frame's scene is projected.
    private func viewPoint(_ shell: ExperienceShell<MoleculePresenter>, atom index: Int) throws -> Vec2 {
        let camera = try XCTUnwrap(shell.presenter.lastCamera)
        let scene = try XCTUnwrap(shell.presenter.lastScene)
        let canvas = try XCTUnwrap(shell.presenter.lastCanvas)
        let ndc = camera.project(scene.atoms[index].position, aspect: canvas.x / canvas.y)
        return Vec2((ndc.x + 1) / 2 * viewSize.x, (1 - ndc.y) / 2 * viewSize.y)
    }

    /// The atom the last drawn frame shows under the view point `point` (the expected pick).
    private func expectedPick(_ shell: ExperienceShell<MoleculePresenter>, at point: Vec2) throws -> Int? {
        let camera = try XCTUnwrap(shell.presenter.lastCamera)
        let scene = try XCTUnwrap(shell.presenter.lastScene)
        let canvas = try XCTUnwrap(shell.presenter.lastCanvas)
        let ndc = try XCTUnwrap(MoleculePresenter.ndc(of: point, viewSize: viewSize))
        return AtomPicker.pick(ndc: ndc, camera: camera, aspect: canvas.x / canvas.y, scene: scene)
    }

    func testATapOnCaffeinesThirdAtomSelectsItAndATapOnACornerClears() async throws {
        let session = ExperienceSession()
        let shell = try await MoleculeTest.open(session, size: size)
        XCTAssertTrue(shell.handle(control: "molecule.select", values: [4]).isAccepted)
        try MoleculeTest.frames(session, 1)
        let point = try viewPoint(shell, atom: 2)
        XCTAssertEqual(try expectedPick(shell, at: point), 2, "no nearer atom covers the nitrogen's centre")
        tap(shell, at: point)
        XCTAssertEqual(try MoleculeTest.core(shell).selectedAtom, 2)
        try MoleculeTest.frames(session, 1)
        XCTAssertTrue(shell.accessibilitySummary.hasSuffix("; selected nitrogen, atom 3."), shell.accessibilitySummary)
        tap(shell, at: Vec2(2, 2))
        XCTAssertNil(try MoleculeTest.core(shell).selectedAtom, "a tap on empty space clears the selection")
        // Every atom's projected centre picks the atom nearest the viewer along that line of sight.
        try MoleculeTest.frames(session, 1)
        for index in 0..<24 {
            let p = try viewPoint(shell, atom: index)
            let expected = try XCTUnwrap(try expectedPick(shell, at: p), "atom \(index) is under its own centre")
            tap(shell, at: p)
            XCTAssertEqual(try MoleculeTest.core(shell).selectedAtom, expected, "atom \(index)")
        }
        session.close()
    }

    func testPickingUsesTheDrawnCameraAfterTurnsAndPans() async throws {
        let session = ExperienceSession()
        let shell = try await MoleculeTest.open(session, size: size)
        XCTAssertTrue(shell.handle(control: "molecule.select", values: [4]).isAccepted)
        try MoleculeTest.frames(session, 1)
        let before = try viewPoint(shell, atom: 2)
        let actions: [(String, [Double])] = [("camera.orbit", [1]), ("camera.orbit", [1]), ("camera.pan", [1, 0]),
                                             ("camera.pan", [1, 1])]
        for (control, values) in actions {
            XCTAssertTrue(shell.handle(control: control, values: values).isAccepted, control)
        }
        try MoleculeTest.frames(session, 1)
        let after = try viewPoint(shell, atom: 2)
        XCTAssertGreaterThan((after - before).length, 5, "the atom is drawn elsewhere")
        let expected = try expectedPick(shell, at: after)
        XCTAssertNotNil(expected)
        tap(shell, at: after)
        XCTAssertEqual(try MoleculeTest.core(shell).selectedAtom, expected, "picked where it is drawn now")
        session.close()
    }

    func testTheSelectionSurvivesAModeChangeAndSpaceFillingPicksWithItsRadii() async throws {
        let session = ExperienceSession()
        let shell = try await MoleculeTest.open(session, size: size)
        XCTAssertTrue(shell.handle(control: "molecule.select", values: [4]).isAccepted)
        XCTAssertTrue(shell.handle(control: "atom.select", values: [2]).isAccepted)
        XCTAssertTrue(shell.handle(control: "display.mode", values: [1]).isAccepted)
        XCTAssertEqual(try MoleculeTest.core(shell).selectedAtom, 2, "the mode keeps the selection")
        try MoleculeTest.frames(session, 1)
        XCTAssertEqual(shell.presenter.lastScene?.mode, .spaceFilling)
        for index in [0, 5, 13] {
            let p = try viewPoint(shell, atom: index)
            let expected = try XCTUnwrap(try expectedPick(shell, at: p))
            tap(shell, at: p)
            XCTAssertEqual(try MoleculeTest.core(shell).selectedAtom, expected, "atom \(index)")
        }
        XCTAssertFalse(shell.handle(control: "molecule.next").isAccepted, "caffeine is the last")
        XCTAssertTrue(shell.handle(control: "molecule.previous").isAccepted)
        XCTAssertNil(try MoleculeTest.core(shell).selectedAtom, "a molecule change clears the selection")
        session.close()
    }

    func testPanRefusalsAndLimits() async throws {
        let session = ExperienceSession()
        let shell = try await MoleculeTest.open(session, size: size)
        let presenter = shell.presenter
        let before = try shell.engine.digest()
        XCTAssertEqual(presenter.send("camera.pan", [0, 0], through: shell.port).code, "action.rule.a15.invalid-choice")
        XCTAssertEqual(presenter.mirror.message, "The view pans one step at a time.")
        XCTAssertEqual(presenter.send("camera.pan", [0.5, 1], through: shell.port).code,
                       "action.rule.a15.invalid-choice")
        // Outside the declared range −1…1 the engine refuses before the core.
        XCTAssertEqual(shell.handle(control: "camera.pan", values: [2, 0]), .rejected(.outOfRange(index: 0)))
        var core = MoleculeCore(seed: 1)
        XCTAssertEqual(core.apply(ExperienceAction(control: "camera.pan", values: [2, 0], step: 0)),
                       .rejected(.rule(code: MoleculeRule.invalidChoice)), "the core alone refuses 2 by its rule")
        XCTAssertEqual(try shell.engine.digest(), before, "refusals change nothing")
        for _ in 0..<10 { XCTAssertTrue(presenter.send("camera.pan", [1, 0], through: shell.port).isAccepted) }
        XCTAssertEqual(presenter.send("camera.pan", [1, 0], through: shell.port).code, "action.rule.a15.camera-limit")
        XCTAssertEqual(presenter.mirror.message, "The view is panned as far as it goes.")
        XCTAssertEqual(try MoleculeTest.core(shell).camera.panX, 10)
        try MoleculeTest.frames(session, 1)
        XCTAssertEqual(presenter.mirror.panWords, "View panned 10 right")
        XCTAssertTrue(presenter.send("view.reset", through: shell.port).isAccepted)
        XCTAssertEqual(try MoleculeTest.core(shell).camera, .default, "reset view returns the pan to zero")
        session.close()
    }

    func testSchemaOneAndSchemaTwoStatesOpenInSchemaThreeWithNoSelectionAndNoPan() async throws {
        let first = ExperienceSession()
        let shell = try await MoleculeTest.open(first)
        let saved = try shell.snapshot()
        first.close()
        let old: [(Int, String, MoleculeState)] = [
            (1, #"{"schema":1,"selection":4}"#, MoleculeState(selection: 4)),
            (2, #"{"camera":{"tilt":-1,"turn":5,"zoom":2},"mode":1,"schema":2,"selection":3}"#,
             MoleculeState(selection: 3, mode: .spaceFilling,
                           camera: CameraSettings(turnSteps: 5, tiltSteps: -1, zoomSteps: 2))),
        ]
        for (schema, payload, expected) in old {
            let envelope = try moleculeEnvelope(Data(payload.utf8), like: saved, schema: schema)
            let session = ExperienceSession()
            let opened = try await MoleculeTest.open(session, snapshot: envelope)
            XCTAssertNil(session.lastRestoreRefusal, "schema \(schema) is migrated, not refused")
            let core = try MoleculeTest.core(opened)
            XCTAssertEqual(core.state, expected, "schema \(schema)")
            XCTAssertNil(core.selectedAtom, "schema \(schema): no selection")
            XCTAssertEqual(core.camera.panX, 0, "schema \(schema): no pan")
            XCTAssertEqual(core.camera.panY, 0, "schema \(schema): no pan")
            let resaved = try opened.snapshot()
            XCTAssertEqual(resaved.schemaVersion, 3, "schema \(schema): saved again in schema 3")
            session.close()
        }
    }
}
