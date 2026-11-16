// MoleculeSessionTests — feature 110 (A15-P01) T-A15-106 (FR-A15-131; clarification Q5; SC-A15-104), updated by feature
// 111 (A15-P02) T-A15-205 (two renderers, schema 2, the mode in the description; FR-A15-202, FR-A15-221) and feature
// 112 (A15-P03) T-A15-305 (thirteen actions, the gesture actions, schema 3 so "newer" is 4; FR-A15-301). The A15
// adapter inside the one app's session host on the simulator, short runs only (each test well under 10 s, no wall-clock
// assertion): the session opens with five molecules in library order and water selected, draws it through the host and
// describes it in words; next and previous step through the library and a step past an end is refused with the answer
// in the mirror; a suspension changes nothing; the state saved by the shell restores identically in a new session;
// newer and damaged saved states are refused and water opens; a context recreation makes all renderers once more and
// keeps the meshes and the digest; reopening keeps the drawing resources steady and closing leaves no GPU object
// behind.
import Foundation
import XCTest
import VisualCoreDiagnostics
@testable import MolecularExplorerExperience
import MolecularExplorerCore
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath

/// Molecular Explorer inside the session host.
@MainActor
final class MoleculeSessionTests: XCTestCase {
    func testTheSessionOpensWithWaterSelectedAndFiveMolecules() async throws {
        XCTAssertEqual(MolecularExplorerExperience.id?.rawValue, "a15.molecular-explorer")
        let session = ExperienceSession()
        let shell = try await MoleculeTest.open(session)
        let presenter = shell.presenter
        XCTAssertEqual(session.hostsAlive, 1, "the session's one render host")
        XCTAssertTrue(presenter.isLive)
        XCTAssertGreaterThan(shell.diagnostics.gpu?.objects ?? 0, 0, "drawn through the host's registry")
        let core = try MoleculeTest.core(shell)
        XCTAssertEqual(core.state, MoleculeState.initial)
        XCTAssertEqual(MoleculeCore.moleculeCount, 5)
        XCTAssertEqual(MoleculeControls.moleculeTitles, ["Water", "Methane", "Ethanol", "Benzene", "Caffeine"])
        XCTAssertEqual(presenter.lastAtomsDrawn, 3)
        XCTAssertEqual(presenter.lastSelection, 0)
        XCTAssertEqual(presenter.renderers.count, 2, "the sphere and the stick renderer made together")
        XCTAssertNotNil(presenter.sphereMesh)
        XCTAssertNotNil(presenter.stickMesh)
        XCTAssertEqual(presenter.meshBuildCount, 1)
        XCTAssertEqual(presenter.rendererBuildCount, 1)
        XCTAssertEqual(shell.accessibilitySummary,
                       "Molecular Explorer: Water, H2O; 3 atoms, 2 bonds; elements hydrogen, oxygen; ball-and-stick.")
        XCTAssertTrue(presenter.mirror.ready)
        XCTAssertEqual(presenter.mirror.selection, 0)
        XCTAssertEqual(presenter.mirror.moleculeCount, 5)
        XCTAssertEqual(presenter.mirror.nameLine, "Water — H2O")
        XCTAssertEqual(presenter.mirror.countsLine, "3 atoms, 2 bonds")
        XCTAssertEqual(presenter.mirror.sourceLine, "PubChem Compound CID 962, 3D conformer — public domain")
        XCTAssertEqual(presenter.mirror.status, "Water selected, molecule 1 of 5")
        XCTAssertEqual(presenter.nativeActions, ["molecule.select", "molecule.next", "molecule.previous",
                                                 "display.mode", "camera.orbit", "camera.tilt", "camera.zoom",
                                                 "view.reset", "camera.pan", "atom.select", "atom.next",
                                                 "atom.previous", "atom.clear", "import.begin", "import.atom",
                                                 "import.end"])
        XCTAssertEqual(presenter.nativeActions, Set(MoleculeCore.actionIDs), "every action has a native control")
        XCTAssertEqual(presenter.gestureActions, ["camera.orbit", "camera.tilt", "camera.zoom", "camera.pan",
                                                  "atom.select", "atom.clear"])
        XCTAssertEqual(GestureAlternatives.missing(gesture: presenter.gestureActions, native: presenter.nativeActions),
                       [])

        session.close()
        XCTAssertEqual(session.hostsAlive, 0)
        XCTAssertFalse(presenter.isLive)
        XCTAssertTrue(presenter.renderers.isEmpty, "the renderers are released together in teardown")
        XCTAssertNil(presenter.depthPass)
        XCTAssertEqual(shell.state, .inactive, "closed without a GPU leak")
    }

    func testNextAndPreviousStepThroughTheLibraryAndARefusedStepIsAnswered() async throws {
        let session = ExperienceSession()
        let shell = try await MoleculeTest.open(session)
        let presenter = shell.presenter
        let titles: [String] = ["Water", "Methane", "Ethanol", "Benzene", "Caffeine"]
        for index in 1..<5 {
            XCTAssertTrue(presenter.send("molecule.next", through: shell.port).isAccepted, "next to \(index)")
            try MoleculeTest.frames(session, 1)
            XCTAssertEqual(try MoleculeTest.core(shell).selection, index)
            XCTAssertEqual(presenter.lastSelection, index)
            XCTAssertEqual(presenter.lastAtomsDrawn, MoleculeCore.library[index].atoms.count)
            XCTAssertTrue(presenter.mirror.nameLine.hasPrefix(titles[index] + " — "), presenter.mirror.nameLine)
            XCTAssertEqual(presenter.mirror.message, "")
        }
        let refused = presenter.send("molecule.next", through: shell.port)
        XCTAssertEqual(refused.code, "action.rule.a15.invalid-choice")
        XCTAssertEqual(presenter.mirror.message, "Caffeine is the last molecule.")
        XCTAssertEqual(try MoleculeTest.core(shell).selection, 4, "a refused step changes nothing")
        XCTAssertEqual(presenter.mirror.nameLine, "Caffeine — C8H10N4O2")
        XCTAssertEqual(presenter.mirror.countsLine, "24 atoms, 25 bonds")
        for index in stride(from: 3, through: 0, by: -1) {
            XCTAssertTrue(presenter.send("molecule.previous", through: shell.port).isAccepted, "previous to \(index)")
            XCTAssertEqual(try MoleculeTest.core(shell).selection, index)
        }
        XCTAssertEqual(presenter.mirror.message, "", "an accepted action clears the answer")
        XCTAssertEqual(presenter.send("molecule.previous", through: shell.port).code,
                       "action.rule.a15.invalid-choice")
        XCTAssertEqual(presenter.mirror.message, "Water is the first molecule.")
        XCTAssertEqual(presenter.send("molecule.select", [2.5], through: shell.port).code,
                       "action.rule.a15.invalid-choice")
        XCTAssertEqual(presenter.mirror.message, "There is no such molecule.")
        XCTAssertTrue(presenter.send("molecule.select", [2], through: shell.port).isAccepted)
        XCTAssertEqual(shell.accessibilitySummary,
                       "Molecular Explorer: Ethanol, C2H6O; 9 atoms, 8 bonds; elements carbon, hydrogen, oxygen; "
                       + "ball-and-stick.")
        try MoleculeTest.frames(session, 3)
        XCTAssertEqual(presenter.rendererBuildCount, 1, "changing the molecule never remakes the renderers")
        session.close()
    }

    func testASuspensionChangesNothing() async throws {
        let session = ExperienceSession()
        let shell = try await MoleculeTest.open(session)
        XCTAssertTrue(shell.handle(control: "molecule.select", values: [3]).isAccepted)
        try MoleculeTest.frames(session, 10)
        let before = try MoleculeTest.core(shell)
        let digest = try shell.engine.digest()
        let stepIndex = shell.engine.stepIndex
        session.setScenePhase(.background)
        XCTAssertEqual(shell.state, .suspended)
        for _ in 0..<10 { _ = session.renderHost?.renderOneFrame(present: false) }
        try await Task.sleep(for: .milliseconds(150))
        XCTAssertEqual(try MoleculeTest.core(shell), before, "nothing changes while suspended")
        XCTAssertEqual(shell.engine.stepIndex, stepIndex)

        session.setScenePhase(.active)
        XCTAssertEqual(shell.state, .active)
        XCTAssertEqual(try MoleculeTest.core(shell), before, "the resume continues from the same state")
        try MoleculeTest.frames(session, 5)
        XCTAssertEqual(try shell.engine.digest(), digest, "host steps change nothing")
        session.close()
    }

    func testTheSavedStateRestoresIdenticallyInANewSession() async throws {
        let first = ExperienceSession()
        let shell = try await MoleculeTest.open(first)
        XCTAssertTrue(shell.handle(control: "molecule.select", values: [4]).isAccepted)
        try MoleculeTest.frames(first, 3)
        let snapshot = try shell.snapshot()
        let saved = try MoleculeTest.core(shell)
        first.close()

        let second = ExperienceSession()
        let restored = try await MoleculeTest.open(second, seed: 3)
        try restored.restore(ExperienceSnapshot(data: snapshot.encoded()))
        let core = try MoleculeTest.core(restored)
        XCTAssertEqual(core.state, saved.state, "the selection is identical")
        try MoleculeTest.frames(second, 1)
        XCTAssertEqual(restored.presenter.lastSelection, 4)
        XCTAssertEqual(restored.presenter.lastAtomsDrawn, 24)
        XCTAssertEqual(restored.accessibilitySummary, saved.canvasDescription)
        second.close()
    }

    func testANewerSavedStateIsRefusedAndWaterOpens() async throws {
        let first = ExperienceSession()
        let shell = try await MoleculeTest.open(first)
        XCTAssertTrue(shell.handle(control: "molecule.select", values: [2]).isAccepted)
        let saved = try shell.snapshot()
        first.close()
        let newerEnvelope = try moleculeEnvelope(Data(saved.payload.utf8), like: saved, schema: 5)
        let newerPayload = try moleculeEnvelope(moleculePayload(saved.payload, key: "schema", value: 5), like: saved)

        let cases: [(String, ExperienceSnapshot)] = [("envelope", newerEnvelope), ("payload", newerPayload)]
        for (name, newer) in cases {
            let second = ExperienceSession()
            let opened = try await MoleculeTest.open(second, snapshot: newer)
            XCTAssertNotNil(second.lastRestoreRefusal, "the newer \(name) is refused")
            XCTAssertEqual(try MoleculeTest.core(opened).state, MoleculeState.initial, "\(name): water opens")
            XCTAssertThrowsError(try opened.restore(newer), name)
            second.close()
        }
    }

    func testADamagedSavedStateIsRefusedAndWaterOpens() async throws {
        let first = ExperienceSession()
        let shell = try await MoleculeTest.open(first)
        XCTAssertTrue(shell.handle(control: "molecule.select", values: [1]).isAccepted)
        let saved = try shell.snapshot()
        first.close()
        let damaged = try moleculeEnvelope(moleculePayload(saved.payload, key: "selection", value: 25), like: saved)

        let second = ExperienceSession()
        let opened = try await MoleculeTest.open(second, snapshot: damaged)
        XCTAssertNotNil(second.lastRestoreRefusal, "a selection outside 0…4 is refused")
        XCTAssertEqual(try MoleculeTest.core(opened).state, MoleculeState.initial, "water opens")
        XCTAssertThrowsError(try opened.restore(damaged))
        second.close()
    }

    func testAContextRecreationMakesAllRenderersOnceMoreAndKeepsTheDigest() async throws {
        let session = ExperienceSession()
        let shell = try await MoleculeTest.open(session)
        XCTAssertTrue(shell.handle(control: "molecule.select", values: [4]).isAccepted)
        try MoleculeTest.frames(session, 1)
        let presenter = shell.presenter
        let renderers = presenter.rendererBuildCount
        let meshes = presenter.meshBuildCount
        let digest = try shell.engine.digest()
        session.recreateContext()
        XCTAssertEqual(session.state, .running)
        XCTAssertEqual(try shell.engine.digest(), digest)
        try MoleculeTest.frames(session, 2)
        XCTAssertEqual(presenter.rendererBuildCount, renderers + 1, "the renderers are made once on the new context")
        XCTAssertEqual(presenter.renderers.count, 2)
        XCTAssertEqual(presenter.meshBuildCount, meshes, "the meshes are CPU data and survive")
        XCTAssertEqual(presenter.lastAtomsDrawn, 24)
        XCTAssertEqual(presenter.lastSelection, 4)
        XCTAssertTrue(presenter.isLive)
        XCTAssertEqual(try shell.engine.digest(), digest)
        session.close()
        XCTAssertEqual(session.diagnostics.lastCloseCounts?.objects, 0)
    }

    func testReopeningThreeTimesKeepsTheDrawingResourcesSteady() async throws {
        var reference: ResourceLedger.Snapshot?
        for cycle in 1...3 {
            let session = ExperienceSession()
            let shell = try await MoleculeTest.open(session)
            XCTAssertTrue(shell.handle(control: "molecule.select", values: [3]).isAccepted)
            try MoleculeTest.frames(session, 3)
            let stats = try XCTUnwrap(session.renderHost).resources.stats
            XCTAssertEqual(stats.leaked, 0, "cycle \(cycle)")
            if let reference {
                XCTAssertEqual(stats.liveCount, reference.liveCount, "cycle \(cycle): the same live objects per kind")
                XCTAssertEqual(stats.liveBytes, reference.liveBytes, "cycle \(cycle): the same live bytes per kind")
            } else {
                reference = stats
            }
            session.close()
            XCTAssertEqual(session.diagnostics.lastCloseCounts?.objects, 0, "cycle \(cycle)")
        }
    }
}
