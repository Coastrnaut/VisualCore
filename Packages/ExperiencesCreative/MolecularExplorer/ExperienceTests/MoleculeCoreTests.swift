// MoleculeCoreTests — feature 110 (A15-P01) T-A15-106 (FR-A15-131; clarification Q5; SC-A15-104), updated by feature
// 111 (A15-P02) T-A15-205 (FR-A15-210, FR-A15-220, FR-A15-221; SC-A15-204). The adapter core of Molecular Explorer
// against the experience contract, short runs only (no wall clock): the id, the eight controls, schema 2 with the step
// 1 → 2, one quality tier and the default step; conformance over three seeds; the first state (every seed opens
// with water selected among five molecules in library order); every action accepted in range; refusals by the engine
// and by the core (`a15.invalid-choice`) each leaving the state as it was; host steps changing nothing; the digest
// covering the selection, the mode and the camera, stable; the snapshot round trip into another engine; damaged and
// newer snapshots refused; the migration step 1 → 2; reset; the outcome; the information lines and the canvas
// description of clarification Q5 ending with the mode.
import Foundation
import XCTest
@testable import MolecularExplorerExperience
import MolecularExplorerCore
import VisualCoreDiagnostics
import VisualCoreExperience
import VisualCoreMath
import VisualCoreSimulation

/// The adapter core against the experience contract.
final class MoleculeCoreTests: XCTestCase {
    /// The experience id.
    private let moleculeID = ExperienceID(rawValue: MoleculeCore.experienceID)!

    /// A prepared, active engine with `seed`.
    private func makeEngine(seed: UInt64 = 1) async throws -> ExperienceEngine<MoleculeCore> {
        var engine = ExperienceEngine<MoleculeCore>(id: moleculeID)
        try await engine.prepare(seed: seed)
        try engine.activate()
        return engine
    }

    /// An action of `control` with `values` at step 0.
    private func action(_ control: String, _ values: [Double] = []) -> ExperienceAction {
        ExperienceAction(control: control, values: values, step: 0)
    }

    func testIdControlsSchemaTiersAndStep() {
        XCTAssertEqual(MoleculeCore.experienceID, "a15.molecular-explorer")
        let ids: [String] = MoleculeCore.controls.map(\.id)
        XCTAssertEqual(ids, ["molecule.select", "molecule.next", "molecule.previous", "display.mode", "camera.orbit",
                             "camera.tilt", "camera.zoom", "view.reset"])
        XCTAssertEqual(ids, MoleculeCore.actionIDs)
        XCTAssertEqual(MoleculeCore.moleculeCount, 5)
        let ranges: [[ClosedRange<Double>]] = [[0...4], [], [], [0...1], [-1...1], [-1...1], [-1...1], []]
        XCTAssertEqual(MoleculeCore.controls.map(\.ranges), ranges)
        XCTAssertEqual(MoleculeCore.migrations.currentVersion, 2)
        XCTAssertEqual(MoleculeCore.qualityTiers, 1)
        XCTAssertEqual(MoleculeCore.qualityProfile.levels.count, 1)
        XCTAssertEqual(MoleculeCore.stepDuration, 1.0 / 120, accuracy: 1e-15)
        XCTAssertEqual(MoleculeRule.invalidChoice, "a15.invalid-choice")
        XCTAssertEqual(MoleculeRule.cameraLimit, "a15.camera-limit")
    }

    func testConformancePassesOverThreeSeeds() async {
        let actions: [ScriptedAction] = [
            ScriptedAction("molecule.next"), ScriptedAction("molecule.next"), ScriptedAction("molecule.select", [4]),
            ScriptedAction("molecule.previous"), ScriptedAction("display.mode", [1]),
            ScriptedAction("camera.orbit", [1]), ScriptedAction("camera.tilt", [-1]),
            ScriptedAction("camera.zoom", [1]), ScriptedAction("view.reset"),
            ScriptedAction("molecule.select", [0]),
        ]
        let rejected: [ScriptedAction] = [
            ScriptedAction("molecule.select", [0.5]), ScriptedAction("molecule.select", [5]),
            ScriptedAction("molecule.select", [.nan]), ScriptedAction("molecule.select", []),
            ScriptedAction("molecule.next", [1]), ScriptedAction("molecule.previous", [0]),
            ScriptedAction("molecule.select", [.infinity]), ScriptedAction("bogus"),
            ScriptedAction("display.mode", [0.5]), ScriptedAction("display.mode", [2]),
            ScriptedAction("camera.orbit", [0]), ScriptedAction("camera.tilt", [0.5]),
            ScriptedAction("camera.zoom", [-2]), ScriptedAction("view.reset", [0]),
        ]
        let plan = ConformancePlan(seeds: [1, 2, 0xFFFF_FFFF_FFFF_FFFF], stepsPerSegment: 5, actions: actions,
                                   rejected: rejected)
        let report = await ExperienceConformance.run(MoleculeCore.self, id: moleculeID, plan: plan)
        for entry in report.entries { XCTAssertTrue(entry.passed, "\(entry.check): \(entry.detail)") }
    }

    func testEverySeedOpensWithWaterSelectedAmongFiveMoleculesInLibraryOrder() async throws {
        let engine = try await makeEngine(seed: 1)
        let core = try XCTUnwrap(engine.core)
        XCTAssertEqual(core.state, MoleculeState.initial)
        XCTAssertEqual(core.selection, 0)
        XCTAssertEqual(core.molecule?.id, "water")
        let titles: [String] = MoleculeCore.library.map(\.title)
        XCTAssertEqual(titles, ["Water", "Methane", "Ethanol", "Benzene", "Caffeine"])
        XCTAssertEqual(core.outcome?.code, "viewing-water")
        let seeds: [UInt64] = [0, 2, 99, .max]
        for seed in seeds {
            XCTAssertEqual(MoleculeCore(seed: seed).state, MoleculeState.initial, "seed \(seed)")
            XCTAssertEqual(try moleculeDigest(MoleculeCore(seed: seed)), try moleculeDigest(core), "seed \(seed)")
        }
    }

    func testActionsInRangeAreAccepted() async throws {
        var engine = try await makeEngine()
        let start = try engine.digest()
        XCTAssertEqual(engine.handle(control: "molecule.next"), .accepted)
        XCTAssertEqual(try XCTUnwrap(engine.core).molecule?.id, "methane")
        XCTAssertNotEqual(try engine.digest(), start, "the selection is state")
        XCTAssertEqual(engine.handle(control: "molecule.select", values: [4]), .accepted)
        XCTAssertEqual(try XCTUnwrap(engine.core).molecule?.id, "caffeine")
        XCTAssertEqual(engine.handle(control: "molecule.previous"), .accepted)
        XCTAssertEqual(try XCTUnwrap(engine.core).molecule?.id, "benzene")
        XCTAssertEqual(engine.handle(control: "molecule.select", values: [0]), .accepted)
        XCTAssertEqual(try XCTUnwrap(engine.core).state, MoleculeState.initial)
        XCTAssertEqual(try engine.digest(), start, "back to water is the first digest")
        for index in 0..<5 {
            XCTAssertEqual(engine.handle(control: "molecule.select", values: [Double(index)]), .accepted, "\(index)")
            XCTAssertEqual(try XCTUnwrap(engine.core).selection, index)
        }
    }

    func testRefusalsKeepTheStateWithTheirReasons() async throws {
        var engine = try await makeEngine()
        let invalid = ActionResult.rejected(.rule(code: MoleculeRule.invalidChoice))
        let before = try engine.digest()
        XCTAssertEqual(engine.handle(control: "molecule.select", values: [5]), .rejected(.outOfRange(index: 0)))
        XCTAssertEqual(engine.handle(control: "molecule.select", values: [-1]), .rejected(.outOfRange(index: 0)))
        XCTAssertEqual(engine.handle(control: "molecule.select", values: [.nan]), .rejected(.nonFinite(index: 0)))
        XCTAssertEqual(engine.handle(control: "molecule.select", values: [0.5]), invalid)
        XCTAssertEqual(engine.handle(control: "molecule.previous"), invalid, "no molecule before water")
        XCTAssertEqual(engine.handle(control: "molecule.next", values: [1]),
                       .rejected(.wrongValueCount(expected: 0, found: 1)))
        XCTAssertEqual(engine.handle(control: "bogus", values: []), .rejected(.unknownControl("bogus")))
        XCTAssertEqual(try engine.digest(), before)
        XCTAssertEqual(engine.handle(control: "molecule.select", values: [4]), .accepted)
        let last = try engine.digest()
        XCTAssertEqual(engine.handle(control: "molecule.next"), invalid, "no molecule after caffeine")
        XCTAssertEqual(try engine.digest(), last)

        // Called directly, the core refuses by its own rules and changes nothing.
        var core = MoleculeCore(seed: 1)
        let original = core
        XCTAssertEqual(core.apply(action("molecule.select", [5])), invalid)
        XCTAssertEqual(core.apply(action("molecule.select", [-1])), invalid)
        XCTAssertEqual(core.apply(action("molecule.select", [.infinity])), invalid)
        XCTAssertEqual(core.apply(action("molecule.select", [.nan])), invalid)
        XCTAssertEqual(core.apply(action("molecule.select", [2.5])), invalid)
        XCTAssertEqual(core.apply(action("molecule.previous")), invalid)
        XCTAssertEqual(core.apply(action("molecule.select")), .rejected(.wrongValueCount(expected: 1, found: 0)))
        XCTAssertEqual(core.apply(action("molecule.next", [0])), .rejected(.wrongValueCount(expected: 0, found: 1)))
        XCTAssertEqual(core.apply(action("bogus", [0])), .rejected(.unknownControl("bogus")))
        XCTAssertEqual(core, original, "the selection is unchanged")
        var caffeine = try moleculeCore(MoleculeState(selection: 4))
        let kept = caffeine
        XCTAssertEqual(caffeine.apply(action("molecule.next")), invalid)
        XCTAssertEqual(caffeine, kept)
    }

    func testTheViewActionsAndTheirRefusals() throws {
        var core = MoleculeCore(seed: 1)
        let invalid = ActionResult.rejected(.rule(code: MoleculeRule.invalidChoice))
        XCTAssertEqual(core.apply(action("display.mode", [1])), .accepted)
        XCTAssertEqual(core.mode, .spaceFilling)
        XCTAssertEqual(core.apply(action("camera.orbit", [-1])), .accepted)
        XCTAssertEqual(core.camera.turnSteps, 1)
        XCTAssertEqual(core.apply(action("camera.tilt", [1])), .accepted)
        XCTAssertEqual(core.camera.tiltSteps, 3)
        XCTAssertEqual(core.apply(action("camera.zoom", [-1])), .accepted)
        XCTAssertEqual(core.camera.zoomSteps, -1)
        let kept = core
        let refusedValues: [(String, [Double])] = [("display.mode", [0.5]), ("display.mode", [2]),
                                                   ("display.mode", [.nan]), ("camera.orbit", [0]),
                                                   ("camera.orbit", [0.5]), ("camera.tilt", [2]),
                                                   ("camera.zoom", [-0.5]), ("camera.zoom", [.infinity])]
        for (control, values) in refusedValues {
            XCTAssertEqual(core.apply(action(control, values)), invalid, "\(control) \(values)")
        }
        XCTAssertEqual(core.apply(action("view.reset", [1])), .rejected(.wrongValueCount(expected: 0, found: 1)))
        XCTAssertEqual(core.apply(action("camera.tilt")), .rejected(.wrongValueCount(expected: 1, found: 0)))
        XCTAssertEqual(core, kept, "a refusal changes nothing")
        XCTAssertEqual(core.apply(action("view.reset")), .accepted)
        XCTAssertEqual(core.camera, .default)
        XCTAssertEqual(core.mode, .spaceFilling, "the reset keeps the mode")
        XCTAssertEqual(core.outcome?.code, "viewing-water", "the view does not change the outcome")
        XCTAssertEqual(core.apply(action("molecule.next")), .accepted)
        XCTAssertEqual(core.mode, .spaceFilling, "a molecule change keeps the mode")
    }

    func testTheMigrationStepTurnsSchemaOneIntoSchemaTwo() throws {
        let upgraded = try MoleculeCore.migrations.migrate(["schema": 1, "selection": 3], from: 1)
        let data = try JSONSerialization.data(withJSONObject: upgraded, options: [.sortedKeys])
        XCTAssertEqual(String(decoding: data, as: UTF8.self),
                       #"{"camera":{"tilt":2,"turn":2,"zoom":0},"mode":0,"schema":2,"selection":3}"#)
        let core = try MoleculeCore.restore(payload: data, seed: 1)
        XCTAssertEqual(core.state, MoleculeState(selection: 3, mode: .ballAndStick, camera: .default))
        let refused: [[String: Any]] = [["schema": 1, "selection": 5], ["schema": 1], ["schema": 2, "selection": 1],
                                        ["schema": 1, "selection": "benzene"]]
        let reasons: [MoleculeStateRefusal] = [.outOfRange, .damaged, .damaged, .damaged]
        for (payload, reason) in zip(refused, reasons) {
            XCTAssertThrowsError(try MoleculeCore.migrations.migrate(payload, from: 1), "\(payload)") { error in
                XCTAssertEqual(error as? MoleculeRestoreError, .refused(reason), "\(payload)")
            }
        }
        // A schema-1 payload restores directly too.
        let direct = try MoleculeCore.restore(payload: Data(#"{"schema":1,"selection":4}"#.utf8), seed: 2)
        XCTAssertEqual(direct.state, MoleculeState(selection: 4))
    }

    func testHostStepsChangeNothing() async throws {
        var engine = try await makeEngine()
        XCTAssertEqual(engine.handle(control: "molecule.select", values: [2]), .accepted)
        let core = try XCTUnwrap(engine.core)
        let digest = try engine.digest()
        try engine.run(steps: 240)
        XCTAssertEqual(try XCTUnwrap(engine.core), core, "nothing animates")
        XCTAssertEqual(try engine.digest(), digest)
    }

    func testTheDigestCoversTheSelectionTheModeAndTheCameraAndIsStable() throws {
        var digests: [String] = []
        for index in 0..<5 {
            digests.append(try moleculeDigest(moleculeCore(MoleculeState(selection: index))))
        }
        XCTAssertEqual(Set(digests).count, 5, "every selection has its own digest")
        let views: [MoleculeState] = [MoleculeState(selection: 0, mode: .spaceFilling),
                                      MoleculeState(selection: 0, camera: CameraSettings(turnSteps: 3, tiltSteps: 2,
                                                                                         zoomSteps: 0)),
                                      MoleculeState(selection: 0, camera: CameraSettings(turnSteps: 2, tiltSteps: 1,
                                                                                         zoomSteps: 0)),
                                      MoleculeState(selection: 0, camera: CameraSettings(turnSteps: 2, tiltSteps: 2,
                                                                                         zoomSteps: 1))]
        for state in views {
            XCTAssertFalse(digests.contains(try moleculeDigest(moleculeCore(state))), "\(state) has its own digest")
        }
        XCTAssertEqual(try moleculeDigest(moleculeCore(MoleculeState.initial, seed: 9)), digests[0],
                       "the preparation seed is not state")
        for index in 0..<5 {
            XCTAssertEqual(try moleculeDigest(moleculeCore(MoleculeState(selection: index))), digests[index], "stable")
        }
    }

    func testTheSnapshotRestoresIdenticallyInAnotherEngine() async throws {
        var engine = try await makeEngine()
        XCTAssertEqual(engine.handle(control: "molecule.next"), .accepted)
        try engine.run(steps: 3)
        XCTAssertEqual(engine.handle(control: "molecule.select", values: [3]), .accepted)
        let snapshot = try engine.snapshot()
        XCTAssertEqual(snapshot.schemaVersion, 2)
        XCTAssertEqual(Data(snapshot.payload.utf8), try XCTUnwrap(engine.core).state.encoded())
        let saved = try XCTUnwrap(engine.core)
        var other = try await makeEngine(seed: 3)
        try other.restore(ExperienceSnapshot(data: snapshot.encoded()))
        let restored = try XCTUnwrap(other.core)
        XCTAssertEqual(restored.state, saved.state)
        XCTAssertEqual(try other.digest(), try engine.digest())
        XCTAssertEqual(engine.handle(control: "molecule.previous"), .accepted)
        XCTAssertEqual(other.handle(control: "molecule.previous"), .accepted)
        XCTAssertEqual(try XCTUnwrap(other.core).state, try XCTUnwrap(engine.core).state, "both continue alike")
    }

    func testDamagedAndNewerSnapshotsAreRefused() async throws {
        var engine = try await makeEngine()
        XCTAssertEqual(engine.handle(control: "molecule.select", values: [3]), .accepted)
        let saved = try engine.snapshot()
        let before = try engine.digest()

        // Damaged: not JSON, truncated, and JSON with a missing or invalid key.
        XCTAssertThrowsError(try engine.restore(moleculeEnvelope(Data("{not json".utf8), like: saved)))
        XCTAssertThrowsError(try engine.restore(moleculeEnvelope(Data(saved.payload.utf8.prefix(8)), like: saved)))
        let keys: [String] = ["selection", "selection", "selection", "selection", "schema"]
        let values: [Any?] = [nil, 5, -1, "caffeine", nil]
        for (key, value) in zip(keys, values) {
            let payload = try moleculePayload(saved.payload, key: key, value: value)
            XCTAssertThrowsError(try engine.restore(moleculeEnvelope(payload, like: saved)),
                                 "\(key) \(String(describing: value))")
        }
        // Newer: an envelope of schema 3, and a payload of schema 3 inside a schema-2 envelope.
        XCTAssertThrowsError(try engine.restore(moleculeEnvelope(Data(saved.payload.utf8), like: saved, schema: 3)))
        let newerPayload = try moleculePayload(saved.payload, key: "schema", value: 3)
        XCTAssertThrowsError(try engine.restore(moleculeEnvelope(newerPayload, like: saved)))
        XCTAssertEqual(try engine.digest(), before, "every refusal leaves the state as it was")

        // The core names the reason.
        XCTAssertThrowsError(try MoleculeCore.restore(payload: newerPayload, seed: 1)) { error in
            XCTAssertEqual(error as? MoleculeRestoreError, .refused(.newerVersion))
        }
        XCTAssertThrowsError(try MoleculeCore.restore(payload: Data("{not json".utf8), seed: 1)) { error in
            XCTAssertEqual(error as? MoleculeRestoreError, .refused(.damaged))
        }
        let outOfRange = try moleculePayload(saved.payload, key: "selection", value: 5)
        XCTAssertThrowsError(try MoleculeCore.restore(payload: outOfRange, seed: 1)) { error in
            XCTAssertEqual(error as? MoleculeRestoreError, .refused(.outOfRange))
        }
    }

    func testResetReturnsToWater() async throws {
        var engine = try await makeEngine(seed: 2)
        XCTAssertEqual(engine.handle(control: "molecule.select", values: [4]), .accepted)
        try engine.run(steps: 4)
        XCTAssertNotEqual(try XCTUnwrap(engine.core), MoleculeCore(seed: 2))
        try engine.reset()
        XCTAssertEqual(try XCTUnwrap(engine.core), MoleculeCore(seed: 2))
        XCTAssertEqual(engine.stepIndex, 0)
    }

    func testTheOutcomeNamesTheSelectedMolecule() throws {
        let ids: [String] = ["water", "methane", "ethanol", "benzene", "caffeine"]
        for (index, id) in ids.enumerated() {
            let core = try moleculeCore(MoleculeState(selection: index))
            XCTAssertEqual(core.outcome?.code, "viewing-" + id, "\(index)")
        }
    }

    func testTheLinesAndTheCanvasDescriptionFollowClarificationQ5() throws {
        XCTAssertEqual(try moleculeCore(MoleculeState(selection: 4)).canvasDescription,
                       "Molecular Explorer: Caffeine, C8H10N4O2; 24 atoms, 25 bonds; elements carbon, hydrogen, "
                       + "nitrogen, oxygen; ball-and-stick.")
        XCTAssertEqual(try moleculeCore(MoleculeState(selection: 4, mode: .spaceFilling)).canvasDescription,
                       "Molecular Explorer: Caffeine, C8H10N4O2; 24 atoms, 25 bonds; elements carbon, hydrogen, "
                       + "nitrogen, oxygen; space-filling.")
        XCTAssertEqual(MoleculeCore(seed: 1).canvasDescription,
                       "Molecular Explorer: Water, H2O; 3 atoms, 2 bonds; elements hydrogen, oxygen; ball-and-stick.")
        XCTAssertEqual(MoleculeCore.canvasDescription(selection: 1),
                       "Molecular Explorer: Methane, CH4; 5 atoms, 4 bonds; elements carbon, hydrogen; ball-and-stick.")
        XCTAssertEqual(MoleculeCore.canvasDescription(selection: 2, mode: .spaceFilling),
                       "Molecular Explorer: Ethanol, C2H6O; 9 atoms, 8 bonds; elements carbon, hydrogen, oxygen; "
                       + "space-filling.")
        XCTAssertEqual(MoleculeCore.canvasDescription(selection: 3),
                       "Molecular Explorer: Benzene, C6H6; 12 atoms, 12 bonds; elements carbon, hydrogen; "
                       + "ball-and-stick.")
        XCTAssertEqual(MoleculeCore.canvasDescription(selection: 9), "Molecular Explorer: no molecule.")
        XCTAssertEqual(MoleculeCore.nameLine(index: 4), "Caffeine — C8H10N4O2")
        XCTAssertEqual(MoleculeCore.countsLine(index: 4), "24 atoms, 25 bonds")
        XCTAssertEqual(MoleculeCore.sourceLine(index: 4), "PubChem Compound CID 2519, 3D conformer — public domain")
        XCTAssertEqual(MoleculeCore.sourceLine(index: 0), "PubChem Compound CID 962, 3D conformer — public domain")
        XCTAssertEqual(MoleculeCore.status(selection: 4), "Caffeine selected, molecule 5 of 5")
        XCTAssertEqual(MoleculeCore.title(index: 7), "Unknown molecule")
        XCTAssertEqual(MoleculeCore.nameLine(index: -1), "Unknown molecule")
        XCTAssertEqual(MoleculeCore.countsLine(index: 5), "")
        XCTAssertEqual(MoleculeCore.counted(1, "atom"), "1 atom")
        XCTAssertEqual(MoleculeCore.licenseWords("CC0-1.0"), "CC0 1.0")
        XCTAssertEqual(MoleculeCore.licenseWords("factual-data"), "factual data")
        XCTAssertEqual(MoleculeCore.licenseWords("other"), "other")
        let water = try XCTUnwrap(MoleculeCore.molecule(index: 0))
        XCTAssertEqual(MoleculeCore.hillSymbols(water), ["H", "O"], "no carbon: alphabetical")
        let caffeine = try XCTUnwrap(MoleculeCore.molecule(index: 4))
        XCTAssertEqual(MoleculeCore.hillSymbols(caffeine), ["C", "H", "N", "O"])
        // The description names every element of the molecule, so nothing depends on colour alone.
        for (index, molecule) in MoleculeCore.library.enumerated() {
            let text = MoleculeCore.canvasDescription(selection: index)
            XCTAssertTrue(text.contains(molecule.title) && text.contains(molecule.formula), text)
            for atom in molecule.atoms {
                let name = try XCTUnwrap(Elements.element(symbol: atom.symbol)).name.lowercased()
                XCTAssertTrue(text.contains(name), "\(text) names \(name)")
            }
        }
    }
}
