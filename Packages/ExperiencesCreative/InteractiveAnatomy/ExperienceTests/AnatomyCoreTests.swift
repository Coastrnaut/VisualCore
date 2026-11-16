// AnatomyCoreTests — feature 125 (A17-P02) T-A17-205 (FR-A17-203, FR-A17-205, FR-A17-206, FR-A17-208, FR-A17-209,
// FR-A17-210; clarifications Q1, Q3, Q4, Q5; SC-A17-205). The adapter core of Interactive Anatomy against the
// experience contract, short runs only (no wall clock): the id, the seven actions and their ranges, two quality tiers
// with a two-level profile; conformance over three seeds; the opening state; every action accepted; every refusal —
// the contract's own (out of range, wrong value count, unknown control), the camera limits (`a17.camera-limit`), a
// hidden part (`a17.hidden-structure`) and a choice that is not one (`a17.invalid-choice`) — leaving the state as it
// was; hiding the selected part's layer clears the selection; Reset view restores the opening camera and keeps the
// selection and layers; the canvas description with every layer shown, none shown and a selection; a tier change
// keeps the digest; the snapshot payload round trip; damaged, newer and unknown-id saved states refused.
import Foundation
import XCTest
@testable import InteractiveAnatomyExperience
import InteractiveAnatomyCore
import VisualCoreExperience
import VisualCoreMath

/// The adapter core against the experience contract.
final class AnatomyCoreTests: XCTestCase {
    /// The experience id.
    private let anatomyID = ExperienceID(rawValue: "a17.interactive-anatomy")!
    /// The three rule refusals.
    private let limit = ActionResult.rejected(.rule(code: "a17.camera-limit"))
    private let hidden = ActionResult.rejected(.rule(code: "a17.hidden-structure"))
    private let invalid = ActionResult.rejected(.rule(code: "a17.invalid-choice"))

    /// A prepared, active engine with `seed`.
    private func makeEngine(seed: UInt64 = 1) async throws -> ExperienceEngine<AnatomyCore> {
        var engine = ExperienceEngine<AnatomyCore>(id: anatomyID)
        try await engine.prepare(seed: seed)
        try engine.activate()
        return engine
    }

    /// A prepared core with `seed`.
    private func makeCore(seed: UInt64 = 1) async throws -> AnatomyCore {
        try await AnatomyCore.prepare(seed: seed)
    }

    func testIdActionsRangesAndTiers() {
        XCTAssertEqual(AnatomyCore.experienceID, "a17.interactive-anatomy")
        var ranges: [String: [ClosedRange<Double>]] = [:]
        for control in AnatomyCore.controls { ranges[control.id] = control.ranges }
        let expected: [String: [ClosedRange<Double>]] = [
            "structure.select": [0...13], "structure.clear": [], "layer.show": [0...2, 0...1],
            "camera.turn": [-1...1], "camera.tilt": [-1...1], "camera.zoom": [-1...1], "view.reset": [],
        ]
        XCTAssertEqual(ranges, expected)
        XCTAssertEqual(AnatomyCore.controls.count, 7)
        XCTAssertEqual(AnatomyCore.qualityTiers, 2)
        XCTAssertEqual(AnatomyCore.qualityProfile.count, 2)
        XCTAssertEqual(AnatomyQuality.levels.count, AnatomyCore.qualityTiers)
        XCTAssertEqual(AnatomyCore.migrations.currentVersion, AnatomyViewState.schemaVersion)
    }

    func testConformancePassesOverThreeSeeds() async {
        let actions: [ScriptedAction] = [
            ScriptedAction("structure.select", [0]), ScriptedAction("camera.turn", [1]),
            ScriptedAction("camera.tilt", [-1]), ScriptedAction("camera.zoom", [1]),
            ScriptedAction("layer.show", [2, 0]), ScriptedAction("structure.select", [5]),
            ScriptedAction("structure.clear"), ScriptedAction("layer.show", [2, 1]),
            ScriptedAction("structure.select", [13]), ScriptedAction("view.reset"),
        ]
        let rejected: [ScriptedAction] = [
            ScriptedAction("structure.select", [14]), ScriptedAction("structure.select", [0.5]),
            ScriptedAction("structure.select", [.nan]), ScriptedAction("structure.select", []),
            ScriptedAction("structure.clear", [1]), ScriptedAction("layer.show", [3, 1]),
            ScriptedAction("layer.show", [0, 0.5]), ScriptedAction("layer.show", [0]),
            ScriptedAction("camera.turn", [2]), ScriptedAction("camera.tilt", [0.5]),
            ScriptedAction("camera.zoom", [-2]), ScriptedAction("view.reset", [0]), ScriptedAction("bogus"),
        ]
        let plan = ConformancePlan(seeds: [1, 2, 0xFFFF_FFFF_FFFF_FFFF], stepsPerSegment: 5, actions: actions,
                                   rejected: rejected)
        let report = await ExperienceConformance.run(AnatomyCore.self, id: anatomyID, plan: plan)
        for entry in report.entries { XCTAssertTrue(entry.passed, "\(entry.check): \(entry.detail)") }
    }

    func testTheOpeningStateShowsEveryLayerWithNothingSelected() async throws {
        let core = try await makeCore()
        XCTAssertEqual(core.view, AnatomyViewState.opening)
        XCTAssertEqual(core.visibleLayers, Set(AnatomyLayer.allCases))
        XCTAssertNil(core.selectedIndex)
        XCTAssertEqual(core.scene.parts.count, 14)
        XCTAssertEqual(core.scenes.count, 2)
        XCTAssertEqual(core.tier, 0)
        XCTAssertEqual(core.scene.quality.level, 0)
        let other = try await makeCore(seed: 99)
        let first = try anatomyDigest(core)
        let second = try anatomyDigest(other)
        XCTAssertEqual(first, second, "the seed is not state")
    }

    func testEveryActionIsAccepted() async throws {
        var engine = try await makeEngine()
        let start = try engine.digest()
        for index in 0..<14 {
            let result = engine.handle(control: "structure.select", values: [Double(index)])
            XCTAssertEqual(result, .accepted, "select \(index)")
            let core = try XCTUnwrap(engine.core)
            XCTAssertEqual(core.selectedIndex, index)
            XCTAssertEqual(core.view.selection, core.scene.parts[index].id)
            XCTAssertEqual(core.view.framed, core.scene.parts[index].id, "a selection frames its part")
        }
        let cleared = engine.handle(control: "structure.clear")
        XCTAssertEqual(cleared, .accepted)
        XCTAssertNil(try XCTUnwrap(engine.core).view.selection)
        XCTAssertNotNil(try XCTUnwrap(engine.core).view.framed, "the frame stays until Reset view")
        for layer in 0..<3 {
            let off = engine.handle(control: "layer.show", values: [Double(layer), 0])
            XCTAssertEqual(off, .accepted, "hide \(layer)")
            XCTAssertFalse(try XCTUnwrap(engine.core).view.visibleLayers[layer])
            let on = engine.handle(control: "layer.show", values: [Double(layer), 1])
            XCTAssertEqual(on, .accepted, "show \(layer)")
            XCTAssertTrue(try XCTUnwrap(engine.core).view.visibleLayers[layer])
        }
        for control in ["camera.turn", "camera.tilt", "camera.zoom"] {
            for step in [1.0, -1.0] {
                let result = engine.handle(control: control, values: [step])
                XCTAssertEqual(result, .accepted, "\(control) \(step)")
            }
        }
        let turned = engine.handle(control: "camera.turn", values: [1])
        XCTAssertEqual(turned, .accepted)
        XCTAssertEqual(try XCTUnwrap(engine.core).view.camera.turn, 3)
        let reset = engine.handle(control: "view.reset")
        XCTAssertEqual(reset, .accepted)
        let core = try XCTUnwrap(engine.core)
        XCTAssertEqual(core.view.camera, AnatomyCameraState.opening)
        XCTAssertNil(core.view.framed, "Reset view clears the frame")
        let end = try engine.digest()
        XCTAssertEqual(end, start, "back to the opening state")
    }

    func testTheContractRefusesMalformedActionsAndKeepsTheState() async throws {
        var engine = try await makeEngine()
        let before = try engine.digest()
        let cases: [(String, [Double], ActionResult)] = [
            ("structure.select", [14], .rejected(.outOfRange(index: 0))),
            ("structure.select", [-1], .rejected(.outOfRange(index: 0))),
            ("structure.select", [.nan], .rejected(.nonFinite(index: 0))),
            ("structure.select", [], .rejected(.wrongValueCount(expected: 1, found: 0))),
            ("structure.clear", [1], .rejected(.wrongValueCount(expected: 0, found: 1))),
            ("layer.show", [3, 1], .rejected(.outOfRange(index: 0))),
            ("layer.show", [0, 2], .rejected(.outOfRange(index: 1))),
            ("layer.show", [0], .rejected(.wrongValueCount(expected: 2, found: 1))),
            ("camera.turn", [2], .rejected(.outOfRange(index: 0))),
            ("camera.tilt", [], .rejected(.wrongValueCount(expected: 1, found: 0))),
            ("camera.zoom", [.infinity], .rejected(.nonFinite(index: 0))),
            ("view.reset", [1], .rejected(.wrongValueCount(expected: 0, found: 1))),
            ("bogus", [], .rejected(.unknownControl("bogus"))),
        ]
        for (control, values, expected) in cases {
            let result = engine.handle(control: control, values: values)
            XCTAssertEqual(result, expected, "\(control) \(values)")
        }
        let after = try engine.digest()
        XCTAssertEqual(after, before, "every refusal leaves the state as it was")
    }

    func testTheCoreRefusesAChoiceThatIsNotOne() async throws {
        let core = try await makeCore()
        let cases: [(String, [Double])] = [
            ("structure.select", [14]), ("structure.select", [-1]), ("structure.select", [2.5]),
            ("structure.select", [.nan]), ("layer.show", [3, 1]), ("layer.show", [1.5, 1]), ("layer.show", [0, 0.5]),
        ]
        for (control, values) in cases {
            let (next, result) = anatomyApplied(core, control, values)
            XCTAssertEqual(result, invalid, "\(control) \(values)")
            XCTAssertEqual(next.view, core.view, "\(control) \(values) changes nothing")
        }
        // A step other than −1 or +1 is never accepted and changes nothing.
        for control in ["camera.turn", "camera.tilt", "camera.zoom"] {
            for step in [0.0, 0.5, -0.5] {
                let (next, result) = anatomyApplied(core, control, [step])
                XCTAssertFalse(result.isAccepted, "\(control) \(step)")
                XCTAssertEqual(next.view, core.view, "\(control) \(step) changes nothing")
            }
        }
    }

    func testTheCameraLimitsAreRefusedAndTheTurnWraps() async throws {
        var core = try await makeCore()
        XCTAssertEqual(core.view.camera, AnatomyCameraState(turn: 2, tilt: 1, zoom: 0))
        for _ in 0..<5 {
            let (next, result) = anatomyApplied(core, "camera.tilt", [1])
            XCTAssertEqual(result, .accepted)
            core = next
        }
        XCTAssertEqual(core.view.camera.tilt, 6)
        let (aboveTilt, aboveResult) = anatomyApplied(core, "camera.tilt", [1])
        XCTAssertEqual(aboveResult, limit, "tilt 7 is beyond the limit")
        XCTAssertEqual(aboveTilt.view, core.view)
        for _ in 0..<12 { core = anatomyApplied(core, "camera.tilt", [-1]).0 }
        XCTAssertEqual(core.view.camera.tilt, -6)
        let (belowTilt, belowResult) = anatomyApplied(core, "camera.tilt", [-1])
        XCTAssertEqual(belowResult, limit, "tilt −7 is beyond the limit")
        XCTAssertEqual(belowTilt.view, core.view)
        for _ in 0..<6 { core = anatomyApplied(core, "camera.zoom", [1]).0 }
        XCTAssertEqual(core.view.camera.zoom, 6)
        let (inZoom, inResult) = anatomyApplied(core, "camera.zoom", [1])
        XCTAssertEqual(inResult, limit, "zoom 7 is beyond the limit")
        XCTAssertEqual(inZoom.view, core.view)
        for _ in 0..<10 { core = anatomyApplied(core, "camera.zoom", [-1]).0 }
        XCTAssertEqual(core.view.camera.zoom, -4)
        let (outZoom, outResult) = anatomyApplied(core, "camera.zoom", [-1])
        XCTAssertEqual(outResult, limit, "zoom −5 is beyond the limit")
        XCTAssertEqual(outZoom.view, core.view)
        // The turn wraps: 24 steps return to the same turn, and 0 − 1 is 23.
        let turn = core.view.camera.turn
        for _ in 0..<24 {
            let (next, result) = anatomyApplied(core, "camera.turn", [1])
            XCTAssertEqual(result, .accepted)
            core = next
        }
        XCTAssertEqual(core.view.camera.turn, turn)
        for _ in 0..<3 { core = anatomyApplied(core, "camera.turn", [-1]).0 }
        XCTAssertEqual(core.view.camera.turn, 23)
        let (reset, resetResult) = anatomyApplied(core, "view.reset")
        XCTAssertEqual(resetResult, .accepted)
        XCTAssertEqual(reset.view.camera, AnatomyCameraState.opening)
    }

    func testAHiddenPartIsRefusedAndHidingTheSelectedLayerClearsTheSelection() async throws {
        var core = try await makeCore()
        let layers = core.scene.parts.map { $0.layer ?? .bones }
        for (layerIndex, layer) in AnatomyLayer.allCases.enumerated() {
            let hiddenCore = anatomyApplied(core, "layer.show", [Double(layerIndex), 0]).0
            XCTAssertFalse(hiddenCore.visibleLayers.contains(layer))
            for index in 0..<14 {
                let (next, result) = anatomyApplied(hiddenCore, "structure.select", [Double(index)])
                if layers[index] == layer {
                    XCTAssertEqual(result, hidden, "part \(index) is on the hidden \(layer)")
                    XCTAssertEqual(next.view, hiddenCore.view)
                } else {
                    XCTAssertEqual(result, .accepted, "part \(index) is shown")
                }
            }
        }
        // Hiding the selected part's layer clears the selection; hiding another layer keeps it.
        let acl = 8
        XCTAssertEqual(layers[acl], .ligaments)
        core = anatomyApplied(core, "structure.select", [Double(acl)]).0
        XCTAssertEqual(core.selectedIndex, acl)
        let (keep, keepResult) = anatomyApplied(core, "layer.show", [1, 0])
        XCTAssertEqual(keepResult, .accepted)
        XCTAssertEqual(keep.selectedIndex, acl, "hiding cartilage keeps a ligament")
        let (cleared, clearedResult) = anatomyApplied(keep, "layer.show", [2, 0])
        XCTAssertEqual(clearedResult, .accepted)
        XCTAssertNil(cleared.selectedIndex, "hiding ligaments clears the ligament")
        XCTAssertNil(cleared.view.selection)
    }

    func testResetViewKeepsTheSelectionAndLayers() async throws {
        var core = try await makeCore()
        core = anatomyApplied(core, "structure.select", [3]).0
        core = anatomyApplied(core, "layer.show", [1, 0]).0
        core = anatomyApplied(core, "camera.turn", [1]).0
        core = anatomyApplied(core, "camera.zoom", [1]).0
        let (reset, result) = anatomyApplied(core, "view.reset")
        XCTAssertEqual(result, .accepted)
        XCTAssertEqual(reset.view.camera, AnatomyCameraState.opening)
        XCTAssertNil(reset.view.framed)
        XCTAssertEqual(reset.selectedIndex, 3)
        XCTAssertEqual(reset.view.visibleLayers, [true, false, true])
    }

    func testTheCanvasDescription() async throws {
        let core = try await makeCore()
        let all = Set(AnatomyLayer.allCases)
        XCTAssertEqual(core.describe(), anatomyDescription(shown: all, selected: nil))
        XCTAssertEqual(core.describe(),
                       "Right knee, bones, cartilage and menisci, ligaments and tendons; selected: nothing selected.")
        var none = core
        for layer in 0..<3 { none = anatomyApplied(none, "layer.show", [Double(layer), 0]).0 }
        XCTAssertEqual(none.describe(), anatomyDescription(shown: [], selected: nil))
        XCTAssertTrue(none.describe().contains("no layer shown"))
        for index in 0..<14 {
            let selected = anatomyApplied(core, "structure.select", [Double(index)]).0
            let name = core.scene.parts[index].englishName
            XCTAssertEqual(selected.describe(), anatomyDescription(shown: all, selected: name), "part \(index)")
        }
        let femurOnlyBones = anatomyApplied(anatomyApplied(core, "layer.show", [1, 0]).0, "structure.select", [0]).0
        XCTAssertEqual(femurOnlyBones.describe(), anatomyDescription(shown: [.bones, .ligaments], selected: "Femur"))
    }

    func testATierChangeKeepsTheDigestAndTakesTheOtherScene() async throws {
        var core = try await makeCore()
        core = anatomyApplied(core, "structure.select", [4]).0
        let digest = try anatomyDigest(core)
        let view = core.view
        core.setQualityTier(1)
        XCTAssertEqual(core.tier, 1)
        XCTAssertEqual(core.scene.quality.level, 1)
        XCTAssertEqual(core.view, view)
        let after = try anatomyDigest(core)
        XCTAssertEqual(after, digest, "the tier is not state")
        core.setQualityTier(0)
        XCTAssertEqual(core.scene.quality.level, 0)
    }

    func testTheSnapshotPayloadRoundTrips() async throws {
        var engine = try await makeEngine()
        let actions: [(String, [Double])] = [("structure.select", [6]), ("layer.show", [2, 0]),
                                             ("camera.turn", [-1]), ("camera.tilt", [1]), ("camera.zoom", [1])]
        for (control, values) in actions {
            let result = engine.handle(control: control, values: values)
            XCTAssertEqual(result, .accepted, control)
        }
        let saved = try XCTUnwrap(engine.core)
        let snapshot = try engine.snapshot()
        XCTAssertEqual(snapshot.schemaVersion, 1)
        let decoded = try AnatomyViewState.decode(Data(snapshot.payload.utf8),
                                                  parts: saved.scene.parts.map(\.id)).get()
        XCTAssertEqual(decoded, saved.view)
        let direct = try AnatomyCore.restore(payload: saved.snapshotPayload(), seed: 1)
        XCTAssertEqual(direct.view, saved.view)
        var other = try await makeEngine(seed: 3)
        try other.restore(ExperienceSnapshot(data: snapshot.encoded()))
        let restored = try XCTUnwrap(other.core)
        XCTAssertEqual(restored.view, saved.view)
        let first = try engine.digest()
        let second = try other.digest()
        XCTAssertEqual(second, first)
    }

    func testDamagedNewerAndUnknownIdSavedStatesAreRefused() async throws {
        var engine = try await makeEngine()
        let selected = engine.handle(control: "structure.select", values: [2])
        XCTAssertEqual(selected, .accepted)
        let saved = try engine.snapshot()
        let before = try engine.digest()

        let payloads: [(String, Data, ContentRefusal.Reason)] = [
            ("not json", Data("{not json".utf8), .damaged),
            ("truncated", Data(saved.payload.utf8.prefix(8)), .damaged),
            ("no camera", try anatomyPayload(saved.payload, key: "camera", value: nil), .damaged),
            ("two layers", try anatomyPayload(saved.payload, key: "visibleLayers", value: [true, true]), .damaged),
            ("tilt 9", try anatomyPayload(saved.payload, key: "camera", value: ["turn": 2, "tilt": 9, "zoom": 0]),
             .damaged),
            ("no schema", try anatomyPayload(saved.payload, key: "schema", value: nil), .damaged),
            ("unknown selection", try anatomyPayload(saved.payload, key: "selection", value: "knee.bogus"),
             .missingReference),
            ("unknown frame", try anatomyPayload(saved.payload, key: "framed", value: "knee.joint"),
             .missingReference),
            ("newer payload", try anatomyPayload(saved.payload, key: "schema", value: 2), .newerVersion),
        ]
        for (name, payload, reason) in payloads {
            // A payload that is not one JSON object is already refused by the snapshot envelope itself.
            if let envelope = try? anatomyEnvelope(payload, like: saved) {
                do {
                    try engine.restore(envelope)
                    XCTFail("\(name) was restored")
                } catch {}
            }
            XCTAssertThrowsError(try AnatomyCore.restore(payload: payload, seed: 1), name) { error in
                guard case let .refused(refusal)? = error as? AnatomyRestoreError else {
                    return XCTFail("\(name): \(error)")
                }
                XCTAssertEqual(refusal.reason, reason, name)
            }
        }
        let newer = try anatomyEnvelope(Data(saved.payload.utf8), like: saved, schema: 2)
        do {
            try engine.restore(newer)
            XCTFail("a newer envelope was restored")
        } catch {}
        let after = try engine.digest()
        XCTAssertEqual(after, before, "every refusal leaves the state as it was")
    }

    func testHostStepsAndResetChangeNothingUnexpected() async throws {
        var engine = try await makeEngine(seed: 2)
        let opening = try engine.digest()
        let selected = engine.handle(control: "structure.select", values: [1])
        XCTAssertEqual(selected, .accepted)
        let digest = try engine.digest()
        try engine.run(steps: 120)
        let stepped = try engine.digest()
        XCTAssertEqual(stepped, digest, "nothing animates")
        try engine.reset()
        let reset = try engine.digest()
        XCTAssertEqual(reset, opening)
        XCTAssertEqual(try XCTUnwrap(engine.core).view, AnatomyViewState.opening)
    }
}
