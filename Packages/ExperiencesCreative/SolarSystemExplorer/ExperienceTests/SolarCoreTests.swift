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
                             "camera.zoom", "view.reset", "scale.mode", "time.play", "time.rate", "date.set",
                             "tour.start", "tour.next", "tour.pause", "tour.stop", "view.apply"])
        XCTAssertEqual(ids, SolarCore.actionIDs)
        XCTAssertEqual(SolarCore.bodyCount, 9)
        var ranges: [[ClosedRange<Double>]] = [[0...8], [], [], [-365...365], [-1...1], [-1...1], [-1...1], [],
                                               [0...1], [0...1], [0...3], [-18_262.5...18_627.5], [0...1], [], [0...1],
                                               []]
        ranges.append([0...8, -18_262.5...18_627.5, 0...3, -1_000_000...1_000_000, 5...85, -1...12, 0...1])
        XCTAssertEqual(SolarCore.controls.map(\.ranges), ranges)
        XCTAssertEqual(SolarCore.migrations.currentVersion, 4)
        XCTAssertEqual(SolarRule.invalidStep, "a14.invalid-step")
        XCTAssertEqual(SolarRule.outOfRange, "a14.out-of-range")
        XCTAssertEqual(SolarCore.qualityTiers, 2)
        XCTAssertEqual(SolarCore.qualityProfile.levels.count, 2)
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
            ScriptedAction("time.rate", [2]), ScriptedAction("time.play", [1]), ScriptedAction("time.play", [0]),
            ScriptedAction("date.set", [100]), ScriptedAction("tour.start", [1]), ScriptedAction("tour.pause", [1]),
            ScriptedAction("tour.next"), ScriptedAction("tour.stop"),
            ScriptedAction("view.apply", [3, 10, 1, 2, 45, 3, 0]),
        ]
        let rejected: [ScriptedAction] = [
            ScriptedAction("body.select", [0.5]), ScriptedAction("body.select", [9]),
            ScriptedAction("body.select", [.nan]), ScriptedAction("body.select", []),
            ScriptedAction("body.next", [1]), ScriptedAction("body.previous", [0]),
            ScriptedAction("body.select", [.infinity]), ScriptedAction("bogus"),
            ScriptedAction("date.step", [7]), ScriptedAction("date.step", [400]), ScriptedAction("camera.zoom", [0]),
            ScriptedAction("view.reset", [1]), ScriptedAction("scale.mode", [0.5]), ScriptedAction("scale.mode", [2]),
            ScriptedAction("time.play", [0.5]), ScriptedAction("time.rate", [4]), ScriptedAction("date.set", [20_000]),
            ScriptedAction("tour.next"), ScriptedAction("tour.stop"), ScriptedAction("tour.pause", [1]),
            ScriptedAction("view.apply", [3, 10, 1, 2, 40, 3, 0]), ScriptedAction("view.apply", [3]),
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
        XCTAssertEqual(snapshot.schemaVersion, 4)
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
            ("rate 4", { $0["rateIndex"] = 4 }),
            ("tour 2", { $0["tourIndex"] = 2 }),
            ("no playing", { $0["playing"] = nil }),
        ]
        for (name, change) in damaged {
            XCTAssertThrowsError(try engine.restore(solarEnvelope(solarPayload(saved.payload, change), like: saved)),
                                 name)
        }
        // Newer: an envelope of schema 5, and a payload of schema 5 inside a schema-4 envelope.
        XCTAssertThrowsError(try engine.restore(solarEnvelope(Data(saved.payload.utf8), like: saved, schema: 5)))
        let newerPayload = try solarPayload(saved.payload) { $0["schema"] = 5 }
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
                       "Solar System Explorer: Sun in focus on 2000-01-01; 9 bodies. Distances and sizes not to scale. "
                       + "Date 2000-01-01 12:00 UTC, time paused.")
        let earth = try solarCore(SolarState(selection: 3)).canvasDescription
        XCTAssertTrue(earth.hasPrefix("Solar System Explorer: Earth in focus on 2000-01-01, 0.983 AU ("), earth)
        XCTAssertTrue(earth.contains(" km) from the Sun; 9 bodies. Distances and sizes not to scale."), earth)
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
            .contains("Distances and sizes to one scale; small bodies marked."))
        XCTAssertEqual(engine.handle(control: "scale.mode", values: [0.5]), invalid)
        XCTAssertEqual(engine.handle(control: "scale.mode", values: [2]), .rejected(.outOfRange(index: 0)))
        XCTAssertEqual(engine.handle(control: "view.reset"), .accepted)
        XCTAssertEqual(try XCTUnwrap(engine.core).state.scaleMode, .trueRelative, "reset keeps the scale")
        XCTAssertEqual(engine.handle(control: "scale.mode", values: [0]), .accepted)
        XCTAssertTrue(try XCTUnwrap(engine.core).canvasDescription.contains("Distances and sizes not to scale."))
    }

    /// Time, tour and saved-view actions (A14-P04 T-A14-406): accepted within their ranges, refused with their codes.
    func testTimeTourAndViewActions() async throws {
        var engine = try await makeEngine()
        let noTour = ActionResult.rejected(.rule(code: SolarRule.noTour))
        let invalid = ActionResult.rejected(.rule(code: SolarRule.invalidChoice))
        XCTAssertEqual(SolarRule.noTour, "a14.no-tour")
        XCTAssertEqual(engine.handle(control: "tour.next"), noTour)
        XCTAssertEqual(engine.handle(control: "tour.pause", values: [1]), noTour)
        XCTAssertEqual(engine.handle(control: "tour.stop"), noTour)
        XCTAssertEqual(engine.handle(control: "time.rate", values: [3]), .accepted)
        XCTAssertEqual(engine.handle(control: "time.play", values: [0.5]), invalid)
        XCTAssertEqual(engine.handle(control: "time.play", values: [1]), .accepted)
        try engine.run(steps: 120)
        XCTAssertEqual(try XCTUnwrap(engine.core).state.dayOffset, 365, accuracy: 1e-9, "a year per second")
        XCTAssertEqual(engine.handle(control: "date.set", values: [20_000]), .rejected(.outOfRange(index: 0)))
        XCTAssertEqual(engine.handle(control: "date.set", values: [9_132]), .accepted)
        XCTAssertEqual(engine.handle(control: "tour.start", values: [0]), .accepted)
        XCTAssertEqual(try XCTUnwrap(engine.core).state.selection, 0)
        try engine.run(steps: 600)
        XCTAssertEqual(try XCTUnwrap(engine.core).state.selection, 1, "the tour moved on to Mercury")
        XCTAssertTrue(try XCTUnwrap(engine.core).canvasDescription.contains("Tour Inner planets, stop 2 of 5: Mercury"))
        XCTAssertEqual(engine.handle(control: "body.select", values: [5]), .accepted)
        XCTAssertEqual(try XCTUnwrap(engine.core).state.tourIndex, -1, "a body choice ends the tour")
        XCTAssertEqual(engine.handle(control: "view.apply", values: [6, 400, 2, 3, 40, 4, 1]),
                       .rejected(.rule(code: SolarRule.outOfRange)), "pitch off its grid")
        XCTAssertEqual(engine.handle(control: "view.apply", values: [6, 400, 2, 3, 55, 4, 1]), .accepted)
        let state = try XCTUnwrap(engine.core).state
        XCTAssertEqual(state.selection, 6)
        XCTAssertFalse(state.playing, "applying a view pauses time")
        XCTAssertEqual(state.scaleMode, .trueRelative)
    }

    /// The same command stream played twice gives the same digest (SC-A14-401).
    func testTheSameCommandsGiveTheSameDigest() async throws {
        var digests: [String] = []
        for _ in 0..<2 {
            var engine = try await makeEngine()
            XCTAssertEqual(engine.handle(control: "time.rate", values: [1]), .accepted)
            XCTAssertEqual(engine.handle(control: "time.play", values: [1]), .accepted)
            XCTAssertEqual(engine.handle(control: "tour.start", values: [1]), .accepted)
            try engine.run(steps: 777)
            XCTAssertEqual(engine.handle(control: "date.step", values: [30]), .accepted)
            try engine.run(steps: 33)
            digests.append(try engine.digest().hex)
        }
        XCTAssertEqual(digests[0], digests[1])
    }

    /// Truthful labels through the real adapter text (A14-P05, T-A14-502; FR-A14-504; SC-A14-503): 9 bodies × 2 scale
    /// modes × 3 tour states × 2 play states × 2 stop reasons; every enhanced description says "not to scale" and no
    /// true-relative description does.
    func testTheCanvasDescriptionIsTruthfulInAllSampledStates() throws {
        var enhanced = 0
        var trueRelative = 0
        let tours: [Int] = [-1, 0, 1]
        let flags: [Bool] = [false, true]
        let reasons: [String] = ["", "end-of-range"]
        for body in 0..<9 {
            for mode in ScaleMode.allCases {
                for tour in tours {
                    for playing in flags {
                        for reason in reasons {
                            let json = "{\"dayOffset\":365,\"pitchDegrees\":35,\"playing\":\(playing),\"rateIndex\":1,"
                                + "\"scaleMode\":\(mode.rawValue),\"schema\":4,\"selection\":\(body),"
                                + "\"stopReason\":\"\(reason)\",\"tourIndex\":\(tour),\"tourPaused\":false,"
                                + "\"tourStep\":0,\"tourStop\":0,\"yawSteps\":0,\"zoomSteps\":0}"
                            let core = try SolarCore.restore(payload: Data(json.utf8), seed: 1)
                            let text = core.canvasDescription
                            if mode == .enhanced {
                                enhanced += 1
                                XCTAssertTrue(text.contains("not to scale"), text)
                            } else {
                                trueRelative += 1
                                XCTAssertFalse(text.contains("not to scale"), text)
                            }
                        }
                    }
                }
            }
        }
        XCTAssertEqual(enhanced, 108)
        XCTAssertEqual(trueRelative, 108)
    }

    /// A schema-3 envelope (A14-P03) opens paused with no tour (T-A14-406).
    func testASchema3EnvelopeMigrates() async throws {
        var engine = try await makeEngine()
        let saved = try engine.snapshot()
        let old = Data(#"{"dayOffset":30,"pitchDegrees":45,"scaleMode":1,"schema":3,"selection":4,"yawSteps":1,"zoomSteps":2}"#.utf8)
        try engine.restore(solarEnvelope(old, like: saved, schema: 3))
        XCTAssertEqual(try XCTUnwrap(engine.core).state,
                       SolarState(selection: 4, dayOffset: 30, yawSteps: 1, pitchDegrees: 45, zoomSteps: 2,
                                  scaleMode: .trueRelative))
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
