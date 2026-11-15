// SolarCoreTests — feature 103 (A14-P01) T-A14-103 (FR-A14-120…122; clarifications Q4, Q5; SC-A14-104). The adapter
// core of Solar System Explorer against the experience contract, short runs only (no wall clock): the id, the three
// controls, schema 1, one quality tier and the default step; conformance over three seeds; the first state (every seed
// opens with the Sun selected among nine bodies in catalog order); every action accepted in range; refusals by the
// engine and by the core (`a14.invalid-choice`) each leaving the state as it was; host steps changing nothing; the
// digest covering the selection, stable; the snapshot round trip into another engine; damaged and newer snapshots
// refused; reset; the outcome; the canvas description of clarifications Q4 and Q5.
import Foundation
import XCTest
@testable import SolarSystemExplorerExperience
import SolarSystemExplorerCore
import VisualCoreDiagnostics
import VisualCoreExperience
import VisualCoreMath
import VisualCoreSimulation

final class SolarCoreTests: XCTestCase {
    private let solarID = ExperienceID(rawValue: SolarCore.experienceID)!

    private func makeEngine(seed: UInt64 = 1) async throws -> ExperienceEngine<SolarCore> {
        var engine = ExperienceEngine<SolarCore>(id: solarID)
        try await engine.prepare(seed: seed)
        try engine.activate()
        return engine
    }

    private func action(_ control: String, _ values: [Double] = []) -> ExperienceAction {
        ExperienceAction(control: control, values: values, step: 0)
    }

    func testIdControlsSchemaTiersAndStep() {
        XCTAssertEqual(SolarCore.experienceID, "a14.solar-system-explorer")
        let ids: [String] = SolarCore.controls.map(\.id)
        XCTAssertEqual(ids, ["body.select", "body.next", "body.previous", "date.step", "camera.orbit", "camera.tilt",
                             "camera.zoom", "view.reset", "scale.mode"])
        XCTAssertEqual(ids, SolarCore.actionIDs)
        XCTAssertEqual(SolarCore.bodyCount, 9)
        let ranges: [[ClosedRange<Double>]] = [[0...8], [], [], [-365...365], [-1...1], [-1...1], [-1...1], [],
                                               [0...1]]
        XCTAssertEqual(SolarCore.controls.map(\.ranges), ranges)
        XCTAssertEqual(SolarCore.migrations.currentVersion, 3)
        XCTAssertEqual(SolarRule.invalidStep, "a14.invalid-step")
        XCTAssertEqual(SolarRule.outOfRange, "a14.out-of-range")
        XCTAssertEqual(SolarCore.qualityTiers, 1)
        XCTAssertEqual(SolarCore.qualityProfile.levels.count, 1)
        XCTAssertEqual(SolarCore.stepDuration, 1.0 / 120, accuracy: 1e-15)
        XCTAssertEqual(SolarRule.invalidChoice, "a14.invalid-choice")
    }

    func testConformancePassesOverThreeSeeds() async {
        let actions: [ScriptedAction] = [
            ScriptedAction("body.next"), ScriptedAction("body.next"), ScriptedAction("body.select", [5]),
            ScriptedAction("body.previous"), ScriptedAction("body.select", [8]), ScriptedAction("body.select", [0]),
            ScriptedAction("date.step", [30]), ScriptedAction("camera.orbit", [1]), ScriptedAction("camera.tilt", [-1]),
            ScriptedAction("camera.zoom", [1]), ScriptedAction("view.reset"), ScriptedAction("date.step", [-30]),
            ScriptedAction("scale.mode", [1]), ScriptedAction("scale.mode", [0]),
        ]
        let rejected: [ScriptedAction] = [
            ScriptedAction("body.select", [0.5]), ScriptedAction("body.select", [9]),
            ScriptedAction("body.select", [.nan]), ScriptedAction("body.select", []),
            ScriptedAction("body.next", [1]), ScriptedAction("body.previous", [0]),
            ScriptedAction("body.select", [.infinity]), ScriptedAction("bogus"),
            ScriptedAction("date.step", [7]), ScriptedAction("date.step", [400]), ScriptedAction("camera.zoom", [0]),
            ScriptedAction("view.reset", [1]), ScriptedAction("scale.mode", [0.5]), ScriptedAction("scale.mode", [2]),
        ]
        let plan = ConformancePlan(seeds: [1, 2, 0xFFFF_FFFF_FFFF_FFFF], stepsPerSegment: 5, actions: actions,
                                   rejected: rejected)
        let report = await ExperienceConformance.run(SolarCore.self, id: solarID, plan: plan)
        for entry in report.entries { XCTAssertTrue(entry.passed, "\(entry.check): \(entry.detail)") }
    }

    func testEverySeedOpensWithTheSunSelectedAmongNineBodiesInCatalogOrder() async throws {
        let engine = try await makeEngine(seed: 1)
        let core = try XCTUnwrap(engine.core)
        XCTAssertEqual(core.state, SolarState.initial)
        XCTAssertEqual(core.selection, 0)
        XCTAssertEqual(core.body?.id, "sun")
        let names: [String] = SolarCore.catalog.bodies.map(\.name)
        XCTAssertEqual(names, ["Sun", "Mercury", "Venus", "Earth", "Mars", "Jupiter", "Saturn", "Uranus", "Neptune"])
        XCTAssertEqual(core.factCard, BodyCatalog.bundled.factCard(for: 0))
        XCTAssertEqual(core.outcome?.code, "viewing-sun")
        let seeds: [UInt64] = [0, 2, 99, .max]
        for seed in seeds {
            XCTAssertEqual(SolarCore(seed: seed).state, SolarState.initial, "seed \(seed)")
            XCTAssertEqual(try solarDigest(SolarCore(seed: seed)), try solarDigest(core), "seed \(seed)")
        }
    }

    func testActionsInRangeAreAccepted() async throws {
        var engine = try await makeEngine()
        let start = try engine.digest()
        XCTAssertEqual(engine.handle(control: "body.next"), .accepted)
        XCTAssertEqual(try XCTUnwrap(engine.core).selection, 1)
        XCTAssertEqual(try XCTUnwrap(engine.core).body?.id, "mercury")
        XCTAssertNotEqual(try engine.digest(), start, "the selection is state")
        XCTAssertEqual(engine.handle(control: "body.select", values: [3]), .accepted)
        XCTAssertEqual(try XCTUnwrap(engine.core).body?.id, "earth")
        XCTAssertEqual(try XCTUnwrap(engine.core).factCard, BodyCatalog.bundled.factCard(for: 3))
        XCTAssertEqual(engine.handle(control: "body.previous"), .accepted)
        XCTAssertEqual(try XCTUnwrap(engine.core).body?.id, "venus")
        XCTAssertEqual(engine.handle(control: "body.select", values: [8]), .accepted)
        XCTAssertEqual(try XCTUnwrap(engine.core).body?.id, "neptune")
        XCTAssertEqual(engine.handle(control: "body.select", values: [0]), .accepted)
        XCTAssertEqual(try XCTUnwrap(engine.core).state, SolarState.initial)
        XCTAssertEqual(try engine.digest(), start, "back to the Sun is the first digest")
        for index in 0..<9 {
            XCTAssertEqual(engine.handle(control: "body.select", values: [Double(index)]), .accepted, "\(index)")
            XCTAssertEqual(try XCTUnwrap(engine.core).selection, index)
        }
    }

    func testRefusalsKeepTheStateWithTheirReasons() async throws {
        var engine = try await makeEngine()
        let invalid = ActionResult.rejected(.rule(code: SolarRule.invalidChoice))
        let before = try engine.digest()
        XCTAssertEqual(engine.handle(control: "body.select", values: [9]), .rejected(.outOfRange(index: 0)))
        XCTAssertEqual(engine.handle(control: "body.select", values: [-1]), .rejected(.outOfRange(index: 0)))
        XCTAssertEqual(engine.handle(control: "body.select", values: [.nan]), .rejected(.nonFinite(index: 0)))
        XCTAssertEqual(engine.handle(control: "body.select", values: [0.5]), invalid)
        XCTAssertEqual(engine.handle(control: "body.previous"), invalid, "no body before the Sun")
        XCTAssertEqual(engine.handle(control: "body.next", values: [1]),
                       .rejected(.wrongValueCount(expected: 0, found: 1)))
        XCTAssertEqual(engine.handle(control: "bogus", values: []), .rejected(.unknownControl("bogus")))
        XCTAssertEqual(try engine.digest(), before)
        XCTAssertEqual(engine.handle(control: "body.select", values: [8]), .accepted)
        let last = try engine.digest()
        XCTAssertEqual(engine.handle(control: "body.next"), invalid, "no body after Neptune")
        XCTAssertEqual(try engine.digest(), last)

        // Called directly, the core refuses by its own rules and changes nothing.
        var core = SolarCore(seed: 1)
        let original = core
        XCTAssertEqual(core.apply(action("body.select", [9])), invalid)
        XCTAssertEqual(core.apply(action("body.select", [-1])), invalid)
        XCTAssertEqual(core.apply(action("body.select", [.infinity])), invalid)
        XCTAssertEqual(core.apply(action("body.select", [.nan])), invalid)
        XCTAssertEqual(core.apply(action("body.select", [2.5])), invalid)
        XCTAssertEqual(core.apply(action("body.previous")), invalid)
        XCTAssertEqual(core.apply(action("body.select")), .rejected(.wrongValueCount(expected: 1, found: 0)))
        XCTAssertEqual(core.apply(action("body.next", [0])), .rejected(.wrongValueCount(expected: 0, found: 1)))
        XCTAssertEqual(core.apply(action("bogus", [0])), .rejected(.unknownControl("bogus")))
        XCTAssertEqual(core, original, "the selection is unchanged")
        var last8 = try solarCore(SolarState(selection: 8))
        let neptune = last8
        XCTAssertEqual(last8.apply(action("body.next")), invalid)
        XCTAssertEqual(last8, neptune)
    }

    func testHostStepsChangeNothing() async throws {
        var engine = try await makeEngine()
        XCTAssertEqual(engine.handle(control: "body.select", values: [4]), .accepted)
        let core = try XCTUnwrap(engine.core)
        let digest = try engine.digest()
        try engine.run(steps: 240)
        XCTAssertEqual(try XCTUnwrap(engine.core), core, "nothing animates")
        XCTAssertEqual(try engine.digest(), digest)
    }

    func testTheDigestCoversTheSelectionAndIsStable() throws {
        var digests: [String] = []
        for index in 0..<9 {
            digests.append(try solarDigest(solarCore(SolarState(selection: index))))
        }
        XCTAssertEqual(Set(digests).count, 9, "every selection has its own digest")
        XCTAssertEqual(try solarDigest(solarCore(SolarState.initial, seed: 9)), digests[0],
                       "the preparation seed is not state")
        for index in 0..<9 {
            XCTAssertEqual(try solarDigest(solarCore(SolarState(selection: index))), digests[index], "stable")
        }
    }

    func testTheSnapshotRestoresIdenticallyInAnotherEngine() async throws {
        var engine = try await makeEngine()
        for entry in SolarCore.inputEntries {
            try engine.run(steps: entry.steps)
            if let action = entry.action {
                XCTAssertEqual(engine.handle(control: action.control, values: action.values), .accepted)
            }
        }
        let snapshot = try engine.snapshot()
        XCTAssertEqual(snapshot.schemaVersion, 3)
        XCTAssertEqual(Data(snapshot.payload.utf8), try XCTUnwrap(engine.core).state.encoded())
        let saved = try XCTUnwrap(engine.core)
        var other = try await makeEngine(seed: 3)
        try other.restore(ExperienceSnapshot(data: snapshot.encoded()))
        let restored = try XCTUnwrap(other.core)
        XCTAssertEqual(restored.state, saved.state)
        XCTAssertEqual(try other.digest(), try engine.digest())
        XCTAssertEqual(engine.handle(control: "body.previous"), .accepted)
        XCTAssertEqual(other.handle(control: "body.previous"), .accepted)
        XCTAssertEqual(try XCTUnwrap(other.core).state, try XCTUnwrap(engine.core).state, "both continue alike")
    }

    func testDamagedAndNewerSnapshotsAreRefused() async throws {
        var engine = try await makeEngine()
        XCTAssertEqual(engine.handle(control: "body.select", values: [5]), .accepted)
        let saved = try engine.snapshot()
        let before = try engine.digest()

        // Damaged: not JSON, truncated, and JSON with a missing or invalid key.
        XCTAssertThrowsError(try engine.restore(solarEnvelope(Data("{not json".utf8), like: saved)))
        XCTAssertThrowsError(try engine.restore(solarEnvelope(Data(saved.payload.utf8.prefix(8)), like: saved)))
        let damaged: [(String, (inout [String: Any]) -> Void)] = [
            ("no selection", { $0["selection"] = nil }),
            ("selection 9", { $0["selection"] = 9 }),
            ("selection -1", { $0["selection"] = -1 }),
            ("selection text", { $0["selection"] = "earth" }),
            ("no schema", { $0["schema"] = nil }),
            ("pitch 40", { $0["pitchDegrees"] = 40 }),
            ("zoom 13", { $0["zoomSteps"] = 13 }),
            ("day 20000", { $0["dayOffset"] = 20_000.0 }),
            ("no date", { $0["dayOffset"] = nil }),
            ("scale 2", { $0["scaleMode"] = 2 }),
            ("no scale", { $0["scaleMode"] = nil }),
        ]
        for (name, change) in damaged {
            XCTAssertThrowsError(try engine.restore(solarEnvelope(solarPayload(saved.payload, change), like: saved)),
                                 name)
        }
        // Newer: an envelope of schema 4, and a payload of schema 4 inside a schema-3 envelope.
        XCTAssertThrowsError(try engine.restore(solarEnvelope(Data(saved.payload.utf8), like: saved, schema: 4)))
        let newerPayload = try solarPayload(saved.payload) { $0["schema"] = 4 }
        XCTAssertThrowsError(try engine.restore(solarEnvelope(newerPayload, like: saved)))
        XCTAssertEqual(try engine.digest(), before, "every refusal leaves the state as it was")

        // The core names the reason.
        XCTAssertThrowsError(try SolarCore.restore(payload: newerPayload, seed: 1)) { error in
            XCTAssertEqual(error as? SolarRestoreError, .refused(.newerVersion))
        }
        XCTAssertThrowsError(try SolarCore.restore(payload: Data("{not json".utf8), seed: 1)) { error in
            XCTAssertEqual(error as? SolarRestoreError, .refused(.damaged))
        }
        let outOfRange = try solarPayload(saved.payload) { $0["selection"] = 9 }
        XCTAssertThrowsError(try SolarCore.restore(payload: outOfRange, seed: 1)) { error in
            XCTAssertEqual(error as? SolarRestoreError, .refused(.outOfRange))
        }
    }

    func testResetReturnsToTheSun() async throws {
        var engine = try await makeEngine(seed: 2)
        for entry in SolarCore.inputEntries {
            try engine.run(steps: entry.steps)
            if let action = entry.action { _ = engine.handle(control: action.control, values: action.values) }
        }
        XCTAssertNotEqual(try XCTUnwrap(engine.core), SolarCore(seed: 2))
        try engine.reset()
        XCTAssertEqual(try XCTUnwrap(engine.core), SolarCore(seed: 2))
        XCTAssertEqual(engine.stepIndex, 0)
    }

    func testTheOutcomeNamesTheSelectedBody() throws {
        let ids: [String] = ["sun", "mercury", "venus", "earth", "mars", "jupiter", "saturn", "uranus", "neptune"]
        for (index, id) in ids.enumerated() {
            let core = try solarCore(SolarState(selection: index))
            XCTAssertEqual(core.outcome?.code, "viewing-" + id, "\(index)")
        }
    }

    func testTheCanvasDescriptionFollowsClarificationsQ4AndQ5() throws {
        XCTAssertEqual(SolarCore(seed: 1).canvasDescription,
                       "Solar System Explorer: Sun in focus on 2000-01-01; 9 bodies. Distances and sizes not to scale.")
        let earth = try solarCore(SolarState(selection: 3)).canvasDescription
        XCTAssertTrue(earth.hasPrefix("Solar System Explorer: Earth in focus on 2000-01-01, 0.983 AU ("), earth)
        XCTAssertTrue(earth.hasSuffix(" km) from the Sun; 9 bodies. Distances and sizes not to scale."), earth)
        XCTAssertEqual(SolarCore.distanceWords(index: 3, dayOffset: 0), "0.983 AU (147,101,000 km)",
                       "the example of the header (T-A14-216)")
        let neptune = SolarCore.canvasDescription(selection: 8, dayOffset: 9_132)
        XCTAssertTrue(neptune.hasPrefix("Solar System Explorer: Neptune in focus on 2025-01-01, "), neptune)
        XCTAssertEqual(SolarCore.status(selection: 3), "Earth selected, body 4 of 9")
        XCTAssertEqual(SolarCore.name(index: 9), "Unknown body")
        XCTAssertEqual(SolarCore.notToScale, "Distances and sizes not to scale")
    }

    /// The distance words agree in AU and km through 1 AU = 149,597,870.7 km (story 4).
    func testDistanceWordsAgreeInAUAndKm() throws {
        XCTAssertNil(SolarCore.distanceWords(index: 0, dayOffset: 0), "the Sun has no distance from itself")
        for index in 1..<9 {
            let words = try XCTUnwrap(SolarCore.distanceWords(index: index, dayOffset: 365))
            let id = try XCTUnwrap(SolarCore.catalog.body(at: index)).id
            let au = try XCTUnwrap(SolarCore.model.distanceAU(bodyID: id, day: 365))
            let km = au * 149_597_870.7
            XCTAssertTrue(words.hasPrefix(String(format: "%.3f AU (", au)), words)
            let kmText = words.split(separator: "(").last.map { String($0.dropLast(4)) } ?? ""
            let parsed = try XCTUnwrap(Double(kmText.replacingOccurrences(of: ",", with: "")), words)
            XCTAssertEqual(parsed, km, accuracy: 500.0001, "\(id): km rounded to the thousand")
        }
    }

    /// Date and camera actions (A14-P02 T-A14-208): accepted within their ranges, refused with their codes beyond.
    func testDateAndCameraActions() async throws {
        var engine = try await makeEngine()
        let invalidStep = ActionResult.rejected(.rule(code: SolarRule.invalidStep))
        let outOfRange = ActionResult.rejected(.rule(code: SolarRule.outOfRange))
        XCTAssertEqual(engine.handle(control: "date.step", values: [365]), .accepted)
        XCTAssertEqual(try XCTUnwrap(engine.core).state.dayOffset, 365)
        XCTAssertEqual(engine.handle(control: "date.step", values: [7]), invalidStep)
        XCTAssertEqual(engine.handle(control: "date.step", values: [400]), .rejected(.outOfRange(index: 0)))
        XCTAssertEqual(engine.handle(control: "date.step", values: [0.5]), invalidStep)
        XCTAssertEqual(engine.handle(control: "camera.orbit", values: [1]), .accepted)
        XCTAssertEqual(engine.handle(control: "camera.orbit", values: [0]), invalidStep)
        for _ in 0..<5 { XCTAssertEqual(engine.handle(control: "camera.tilt", values: [1]), .accepted) }
        XCTAssertEqual(engine.handle(control: "camera.tilt", values: [1]), outOfRange)
        XCTAssertEqual(engine.handle(control: "camera.zoom", values: [-1]), .accepted)
        XCTAssertEqual(engine.handle(control: "camera.zoom", values: [-1]), outOfRange)
        let before = try XCTUnwrap(engine.core).state
        XCTAssertEqual(before.yawSteps, 1)
        XCTAssertEqual(before.pitchDegrees, 85)
        XCTAssertEqual(before.zoomSteps, -1)
        XCTAssertEqual(engine.handle(control: "view.reset"), .accepted)
        let after = try XCTUnwrap(engine.core).state
        XCTAssertEqual(after, SolarState(selection: 0, dayOffset: 365, yawSteps: 0, pitchDegrees: 35, zoomSteps: 0))
        var end = try solarCore(try XCTUnwrap(SolarState(selection: 3, dayOffset: 18_627.5, yawSteps: 0,
                                                         pitchDegrees: 35, zoomSteps: 0)))
        XCTAssertEqual(end.apply(action("date.step", [1])), outOfRange)
    }

    /// The scale-mode action (A14-P03 T-A14-306): accepted for 0 and 1, refused otherwise; the description follows.
    func testTheScaleModeAction() async throws {
        var engine = try await makeEngine()
        let invalid = ActionResult.rejected(.rule(code: SolarRule.invalidChoice))
        XCTAssertEqual(engine.handle(control: "scale.mode", values: [1]), .accepted)
        XCTAssertEqual(try XCTUnwrap(engine.core).state.scaleMode, .trueRelative)
        XCTAssertTrue(try XCTUnwrap(engine.core).canvasDescription
            .hasSuffix("Distances and sizes to one scale; small bodies marked."))
        XCTAssertEqual(engine.handle(control: "scale.mode", values: [0.5]), invalid)
        XCTAssertEqual(engine.handle(control: "scale.mode", values: [2]), .rejected(.outOfRange(index: 0)))
        XCTAssertEqual(engine.handle(control: "view.reset"), .accepted)
        XCTAssertEqual(try XCTUnwrap(engine.core).state.scaleMode, .trueRelative, "reset keeps the scale")
        XCTAssertEqual(engine.handle(control: "scale.mode", values: [0]), .accepted)
        XCTAssertTrue(try XCTUnwrap(engine.core).canvasDescription.hasSuffix("Distances and sizes not to scale."))
    }

    /// A schema-2 envelope (A14-P02) opens with the enhanced scale mode (T-A14-306).
    func testASchema2EnvelopeMigrates() async throws {
        var engine = try await makeEngine()
        let saved = try engine.snapshot()
        let old = Data(#"{"dayOffset":30,"pitchDegrees":45,"schema":2,"selection":4,"yawSteps":1,"zoomSteps":2}"#.utf8)
        try engine.restore(solarEnvelope(old, like: saved, schema: 2))
        XCTAssertEqual(try XCTUnwrap(engine.core).state,
                       SolarState(selection: 4, dayOffset: 30, yawSteps: 1, pitchDegrees: 45, zoomSteps: 2))
    }

    /// A schema-1 envelope (A14-P01) opens at its selection with J2000.0 and the overview camera (T-A14-208).
    func testASchema1EnvelopeMigrates() async throws {
        var engine = try await makeEngine()
        XCTAssertEqual(engine.handle(control: "date.step", values: [30]), .accepted)
        let saved = try engine.snapshot()
        let old = Data(#"{"schema":1,"selection":4}"#.utf8)
        try engine.restore(solarEnvelope(old, like: saved, schema: 1))
        XCTAssertEqual(try XCTUnwrap(engine.core).state, SolarState(selection: 4))
    }
}
