// AquariumCoreTests — feature 068 (A09-P01) T-A09-103 (FR-A09-111, FR-A09-121; SC-A09-101, SC-A09-104; contract
// "Experience actions"). The adapter core of Digital Aquarium against the experience contract, short runs only
// (simulated steps, no wall clock): the id, the three controls, schema 1 and one quality tier; conformance over four
// seeds; the first state (Reef: two species, 6 to 10 fish, 4 to 6 plants, soft light, swimming); every action accepted
// in range and changing the digest; values outside the range refused by the engine and fractional choices refused by
// the core with `a09.invalid-choice`, a refusal leaving the digest as it was; host steps moving the fish unless paused;
// the same seed and steps giving the same state; the snapshot round trip into another engine; damaged and newer
// snapshots refused; and reset.
import Foundation
import XCTest
@testable import DigitalAquariumExperience
import DigitalAquariumCore
import VisualCoreExperience
import VisualCoreMath
import VisualCoreSimulation

final class AquariumCoreTests: XCTestCase {
    private let aquariumID = ExperienceID(rawValue: AquariumCore.experienceID)!

    private func makeEngine(seed: UInt64 = 7) async throws -> ExperienceEngine<AquariumCore> {
        var engine = ExperienceEngine<AquariumCore>(id: aquariumID)
        try await engine.prepare(seed: seed)
        try engine.activate()
        return engine
    }

    private func action(_ control: String, _ values: [Double]) -> ExperienceAction {
        ExperienceAction(control: control, values: values, step: 0)
    }

    func testIdControlsSchemaAndTiers() {
        XCTAssertEqual(AquariumCore.experienceID, "a09.digital-aquarium")
        XCTAssertEqual(DigitalAquariumExperience.id?.rawValue, "a09.digital-aquarium")
        XCTAssertEqual(AquariumCore.controls.map(\.id), ["habitat.select", "lighting.level", "motion.pause",
                                                         "food.drop", "decor.kind", "decor.place", "decor.move",
                                                         "decor.remove"])
        XCTAssertEqual(AquariumCore.controls.map(\.id), AquariumCore.actionIDs)
        XCTAssertEqual(AquariumCore.controls.map { $0.ranges },
                       [[0...1], [0...2], [0...1], [0...1, 0...1], [0...2], [0...1, 0...1], [0...11, 0...1, 0...1],
                        [0...11]])
        XCTAssertEqual(AquariumCore.migrations.currentVersion, 3)
        XCTAssertEqual(AquariumCore.qualityTiers, 1)
        XCTAssertEqual(AquariumCore.stepDuration, 1.0 / 60, accuracy: 1e-12)
        XCTAssertTrue(AquariumRule.invalidChoice.hasPrefix("a09."))
    }

    func testConformancePassesOverFourSeeds() async {
        let plan = ConformancePlan(
            seeds: [1, 7, 42, 0xFFFF_FFFF_FFFF_FFFF], stepsPerSegment: 12,
            actions: [ScriptedAction("habitat.select", [1]), ScriptedAction("lighting.level", [2]),
                      ScriptedAction("motion.pause", [1]), ScriptedAction("lighting.level", [0]),
                      ScriptedAction("motion.pause", [0]), ScriptedAction("habitat.select", [0])],
            rejected: [ScriptedAction("habitat.select", [2]), ScriptedAction("habitat.select", [0.5]),
                       ScriptedAction("lighting.level", [3]), ScriptedAction("lighting.level", [-1]),
                       ScriptedAction("lighting.level", [1.5]), ScriptedAction("motion.pause", [.nan]),
                       ScriptedAction("motion.pause", [0.5]), ScriptedAction("motion.pause", []),
                       ScriptedAction("bogus")])
        let report = await ExperienceConformance.run(AquariumCore.self, id: aquariumID, plan: plan)
        for entry in report.entries { XCTAssertTrue(entry.passed, "\(entry.check): \(entry.detail)") }
    }

    func testTheFirstStateIsTheReefSwimmingInSoftLight() async throws {
        let engine = try await makeEngine(seed: 99)
        let core = try XCTUnwrap(engine.core)
        let document = core.document
        XCTAssertEqual(document.habitatIndex, 0)
        XCTAssertEqual(document.habitatId, "reef")
        XCTAssertEqual(Set(document.fish.map(\.speciesId)).count, 2, "two species")
        XCTAssertTrue((6...10).contains(document.fish.count), "\(document.fish.count) fish")
        XCTAssertTrue((4...6).contains(document.plants.count), "\(document.plants.count) plants")
        XCTAssertEqual(document.lighting, 1)
        XCTAssertFalse(core.paused)
        XCTAssertEqual(core.step, 0)
        XCTAssertEqual(document.validate(catalog: AquariumCore.catalog), [])
        XCTAssertEqual(core.outcome?.code, AquariumCore.outcomeCode)
        XCTAssertEqual(core.state.document, document)
        XCTAssertEqual(core.state.random, core.generator.state)
    }

    func testEveryActionIsAcceptedInRangeAndChangesTheDigest() async throws {
        var engine = try await makeEngine()
        let script: [(String, Double)] = [("habitat.select", 1), ("lighting.level", 2), ("motion.pause", 1),
                                          ("lighting.level", 0), ("motion.pause", 0), ("habitat.select", 0)]
        for (control, value) in script {
            let before = try engine.digest()
            XCTAssertEqual(engine.handle(control: control, values: [value]), .accepted, "\(control) \(value)")
            XCTAssertNotEqual(try engine.digest(), before, "\(control) \(value) changes the digest")
        }
        let core = try XCTUnwrap(engine.core)
        XCTAssertEqual(core.document.habitatIndex, 0)
        XCTAssertEqual(core.document.lighting, 0, "the lighting stays across a habitat change")
        XCTAssertFalse(core.paused)
    }

    func testTheOtherHabitatChangesFishPlantsAndWater() async throws {
        var engine = try await makeEngine()
        let reef = try XCTUnwrap(engine.core).document
        XCTAssertEqual(engine.handle(control: "habitat.select", values: [1]), .accepted)
        let kelp = try XCTUnwrap(engine.core).document
        XCTAssertEqual(kelp.habitatId, "kelp")
        XCTAssertNotEqual(kelp.waterColor, reef.waterColor)
        XCTAssertTrue(Set(kelp.fish.map(\.speciesId)).isDisjoint(with: Set(reef.fish.map(\.speciesId))))
        XCTAssertEqual(Set(kelp.fish.map(\.speciesId)).count, 2)
        XCTAssertTrue((6...10).contains(kelp.fish.count))
        XCTAssertTrue((4...6).contains(kelp.plants.count))
        XCTAssertNotEqual(kelp.plants, reef.plants)
    }

    func testRefusedValuesKeepTheDigestWithTheirReasons() async throws {
        var engine = try await makeEngine()
        let before = try engine.digest()
        XCTAssertEqual(engine.handle(control: "habitat.select", values: [2]), .rejected(.outOfRange(index: 0)))
        XCTAssertEqual(engine.handle(control: "lighting.level", values: [3]), .rejected(.outOfRange(index: 0)))
        XCTAssertEqual(engine.handle(control: "lighting.level", values: [-1]), .rejected(.outOfRange(index: 0)))
        XCTAssertEqual(engine.handle(control: "motion.pause", values: [0.5]),
                       .rejected(.rule(code: AquariumRule.invalidChoice)))
        XCTAssertEqual(engine.handle(control: "habitat.select", values: [0.25]),
                       .rejected(.rule(code: AquariumRule.invalidChoice)))
        XCTAssertEqual(engine.handle(control: "lighting.level", values: [1.5]),
                       .rejected(.rule(code: AquariumRule.invalidChoice)))
        XCTAssertEqual(engine.handle(control: "motion.pause", values: [.nan]), .rejected(.nonFinite(index: 0)))
        XCTAssertEqual(try engine.digest(), before)

        // Called directly, the core refuses by its own rules and changes nothing.
        var core = try XCTUnwrap(engine.core)
        let original = core
        XCTAssertEqual(core.apply(action("habitat.select", [2])), .rejected(.rule(code: AquariumRule.invalidChoice)))
        XCTAssertEqual(core.apply(action("habitat.select", [-1])), .rejected(.rule(code: AquariumRule.invalidChoice)))
        XCTAssertEqual(core.apply(action("lighting.level", [.infinity])),
                       .rejected(.rule(code: AquariumRule.invalidChoice)))
        XCTAssertEqual(core.apply(action("motion.pause", [2])), .rejected(.rule(code: AquariumRule.invalidChoice)))
        XCTAssertEqual(core.apply(action("motion.pause", [])), .rejected(.wrongValueCount(expected: 1, found: 0)))
        XCTAssertEqual(core.apply(action("bogus", [0])), .rejected(.unknownControl("bogus")))
        XCTAssertEqual(core, original)
    }

    func testHostStepsMoveTheFishUnlessPaused() async throws {
        var engine = try await makeEngine()
        let start = try XCTUnwrap(engine.core)
        try engine.run(steps: 60)
        let moved = try XCTUnwrap(engine.core)
        XCTAssertEqual(moved.step, 60)
        XCTAssertNotEqual(moved.document.fish.map(\.position), start.document.fish.map(\.position))
        for fish in moved.document.fish { XCTAssertTrue(moved.document.bounds.contains(fish.position)) }

        XCTAssertEqual(engine.handle(control: "motion.pause", values: [1]), .accepted)
        let paused = try XCTUnwrap(engine.core)
        let digest = try engine.digest()
        try engine.run(steps: 120)
        XCTAssertEqual(try XCTUnwrap(engine.core), paused, "nothing moves while paused")
        XCTAssertEqual(try engine.digest(), digest)

        XCTAssertEqual(engine.handle(control: "motion.pause", values: [0]), .accepted)
        try engine.run(steps: 1)
        XCTAssertEqual(try XCTUnwrap(engine.core).step, 61, "the fish continue from where they were")
    }

    func testTheSameSeedAndStepsGiveTheSameState() async throws {
        var a = try await makeEngine(seed: 42)
        var b = try await makeEngine(seed: 42)
        try a.run(steps: 90)
        XCTAssertEqual(a.handle(control: "habitat.select", values: [1]), .accepted)
        try a.run(steps: 90)
        try b.run(steps: 90)
        XCTAssertEqual(b.handle(control: "habitat.select", values: [1]), .accepted)
        try b.run(steps: 90)
        XCTAssertEqual(a.core, b.core)
        XCTAssertEqual(try a.digest(), try b.digest())
        var c = try await makeEngine(seed: 43)
        try c.run(steps: 90)
        XCTAssertNotEqual(c.core?.document.fish, a.core?.document.fish, "another seed gives another aquarium")
    }

    func testTheSnapshotRoundTripsIntoAnotherEngine() async throws {
        var first = try await makeEngine(seed: 7)
        try first.run(steps: 30)
        XCTAssertTrue(first.handle(control: "habitat.select", values: [1]).isAccepted)
        XCTAssertTrue(first.handle(control: "lighting.level", values: [2]).isAccepted)
        try first.run(steps: 45)
        let snapshot = try first.snapshot()
        XCTAssertEqual(snapshot.schemaVersion, 3)
        XCTAssertEqual(snapshot.stepIndex, 75)
        let decoded = try ExperienceSnapshot(data: snapshot.encoded())
        var second = try await makeEngine(seed: 3)
        try second.restore(decoded)
        XCTAssertEqual(try second.digest(), try first.digest())
        XCTAssertEqual(second.core, first.core)
        XCTAssertEqual(second.core?.document.habitatId, "kelp")
        XCTAssertEqual(second.core?.document.lighting, 2)

        // Both continue identically: the generator state travelled with the snapshot.
        try first.run(steps: 60)
        try second.run(steps: 60)
        XCTAssertEqual(second.core, first.core)
        XCTAssertEqual(try second.digest(), try first.digest())
    }

    func testDamagedPayloadsAreRefused() async throws {
        let engine = try await makeEngine()
        let good = try XCTUnwrap(engine.core).state
        XCTAssertNoThrow(try AquariumCore.restore(payload: AquariumCore.encode(good), seed: 7))
        var damaged: [(String, AquariumState)] = []
        var outside = good
        outside.document.fish[0].position = Vec2(99, 99)
        damaged.append(("fish outside the bounds", outside))
        var lighting = good
        lighting.document.lighting = 5
        damaged.append(("lighting 5", lighting))
        var habitat = good
        habitat.document.habitatIndex = 9
        damaged.append(("habitat 9", habitat))
        var species = good
        species.document.fish[0].speciesId = "unknown-fish"
        damaged.append(("unknown species", species))
        var crowded = good
        crowded.document.fish = Array(repeating: good.document.fish[0], count: HabitatDocument.maxFish + 1)
        damaged.append(("too many fish", crowded))
        var step = good
        step.step = -1
        damaged.append(("negative step", step))
        var zero = good
        zero.random = SeededRandom.State(version: 1, seed: good.random.seed,
                                         words: Array(repeating: String(repeating: "0", count: 16), count: 4))
        damaged.append(("all-zero generator", zero))
        var words = good
        words.random = SeededRandom.State(version: 1, seed: good.random.seed, words: ["xyz"])
        damaged.append(("malformed generator", words))
        for (name, state) in damaged {
            XCTAssertThrowsError(try AquariumCore.restore(payload: AquariumCore.encode(state), seed: 7), name)
        }
        for text in ["{}", "[]", "not json", #"{"paused":false,"step":0}"#] {
            XCTAssertThrowsError(try AquariumCore.restore(payload: Data(text.utf8), seed: 7), text)
        }
        let nonFinite = #"{"document":{"fish":[],"plants":[],"decor":[],"lighting":1,"habitatIndex":0,"#
            + #""habitatId":"reef","schema":1,"waterColor":{"r":"nan","g":0,"b":0,"a":1},"#
            + #""bounds":{"minX":0.5,"maxX":15.5,"minY":1.5,"maxY":8.5}},"paused":false,"step":0,"#
            + #""random":{"version":1,"seed":"0000000000000007","words":["0000000000000001","0","0","0"]}}"#
        XCTAssertThrowsError(try AquariumCore.restore(payload: Data(nonFinite.utf8), seed: 7))
    }

    func testDamagedAndNewerSnapshotsAreRefusedByTheEngine() async throws {
        var engine = try await makeEngine()
        try engine.run(steps: 10)
        let digest = try engine.digest()
        let state = try XCTUnwrap(engine.core).state
        let newer = try ExperienceSnapshot(experience: aquariumID, schemaVersion: 4, seed: 7, stepIndex: 10,
                                           digest: digest, payload: AquariumCore.encode(state))
        XCTAssertThrowsError(try engine.restore(newer)) { error in
            XCTAssertEqual(error as? ExperienceError, .snapshot(.newerSchema(found: 4, current: 3)))
        }
        var broken = state
        broken.document.lighting = 7
        let damaged = try ExperienceSnapshot(experience: aquariumID, schemaVersion: 2, seed: 7, stepIndex: 10,
                                             digest: digest, payload: AquariumCore.encode(broken))
        XCTAssertThrowsError(try engine.restore(damaged)) { error in
            guard case .snapshot(.corrupt)? = error as? ExperienceError else {
                return XCTFail("expected a corrupt snapshot, got \(error)")
            }
        }
        XCTAssertEqual(try engine.digest(), digest, "a refused snapshot changes nothing")
    }

    func testResetReturnsToTheFirstState() async throws {
        var engine = try await makeEngine(seed: 11)
        let first = try engine.digest()
        try engine.run(steps: 40)
        XCTAssertTrue(engine.handle(control: "habitat.select", values: [1]).isAccepted)
        XCTAssertTrue(engine.handle(control: "motion.pause", values: [1]).isAccepted)
        try engine.reset()
        XCTAssertEqual(try engine.digest(), first)
        XCTAssertEqual(engine.core, AquariumCore(seed: 11))
    }

    /// Feature 069 (A09-P02) T-A09-206 (FR-A09-212; SC-A09-204): the stored schema-1 payload restores through the
    /// engine's migration with the Kelp starter decor added, its fish, plants and lighting kept, and the digest the
    /// example names; a schema-2 save of decor with transforms round-trips identically.
    func testASchemaOneSnapshotMigratesWithTheStarterDecor() async throws {
        let example = try XCTUnwrap(AquariumCore.schemaOneExample())
        XCTAssertEqual(example.version, 1)
        let snapshot = try ExperienceSnapshot(data: example.snapshot)
        let payload = try XCTUnwrap(try JSONSerialization.jsonObject(with: Data(snapshot.payload.utf8)) as? [String: Any])
        let document = try XCTUnwrap(payload["document"] as? [String: Any])
        XCTAssertEqual(document["schema"] as? Int, 1)
        XCTAssertEqual((document["decor"] as? [Any])?.count, 0)
        var engine = try await makeEngine(seed: 3)
        try engine.restore(snapshot)
        XCTAssertEqual(try engine.digest().hex, example.expectedDigest)
        let core = try XCTUnwrap(engine.core)
        let kelp = AquariumCore.catalog.habitats[1]
        XCTAssertEqual(core.document.schema, HabitatDocument.currentSchema)
        XCTAssertEqual(core.document.habitatId, kelp.id)
        XCTAssertEqual(core.document.lighting, 2)
        XCTAssertEqual(core.document.decor, kelp.decor.map(DecorPlacement.init))
        XCTAssertEqual(core.document.fish.count, kelp.fishCount)
        XCTAssertTrue(core.document.fish.allSatisfy { $0.turn == 0 })
        XCTAssertEqual(core.document.plants.count, kelp.plants.count)
    }

    func testDecorTransformsSpeciesAndLightingSurviveASaveAndRestore() async throws {
        var engine = try await makeEngine(seed: 7)
        XCTAssertTrue(engine.handle(control: "habitat.select", values: [1]).isAccepted)
        XCTAssertTrue(engine.handle(control: "lighting.level", values: [0]).isAccepted)
        try engine.run(steps: 90)
        let before = try XCTUnwrap(engine.core).document
        XCTAssertFalse(before.decor.isEmpty)
        XCTAssertTrue(before.decor.contains { $0.rotation != 0 || $0.scale != 1 }, "transforms are not the defaults")
        let snapshot = try ExperienceSnapshot(data: engine.snapshot().encoded())
        var other = try await makeEngine(seed: 3)
        try other.restore(snapshot)
        let after = try XCTUnwrap(other.core).document
        XCTAssertEqual(after.fish.map(\.speciesId), before.fish.map(\.speciesId))
        XCTAssertEqual(after.decor, before.decor)
        XCTAssertEqual(after.lighting, before.lighting)
        XCTAssertEqual(after, before)
    }

    // MARK: Feature 070 (A09-P03) T-A09-306 — feeding and decor editing actions (FR-A09-301, 310, 320)

    func testFeedingAddsThreePelletsAndRefusesBeyondTwelve() async throws {
        var engine = try await makeEngine()
        for n in 1...4 {
            XCTAssertTrue(engine.handle(control: "food.drop", values: [0.5, 0.8]).isAccepted, "feed \(n)")
            XCTAssertEqual(try XCTUnwrap(engine.core).document.food.count, 3 * n)
        }
        let before = try XCTUnwrap(engine.core).state
        XCTAssertEqual(engine.handle(control: "food.drop", values: [0.5, 0.8]).code,
                       "action.rule." + AquariumRule.foodFull)
        XCTAssertEqual(try XCTUnwrap(engine.core).state, before, "a refused feed changes nothing")
        let x = try XCTUnwrap(engine.core).document.food.map(\.position.x)
        XCTAssertEqual(Array(x.prefix(3)), [7.75, 8.0, 8.25])
    }

    func testAFeedWhilePausedWaitsForTheMotion() async throws {
        var engine = try await makeEngine()
        XCTAssertTrue(engine.handle(control: "motion.pause", values: [1]).isAccepted)
        XCTAssertTrue(engine.handle(control: "food.drop", values: [0.5, 0.8]).isAccepted)
        let held = try XCTUnwrap(engine.core).document.food
        try engine.run(steps: 60)
        XCTAssertEqual(try XCTUnwrap(engine.core).document.food, held, "pellets do not sink while paused")
        XCTAssertTrue(engine.handle(control: "motion.pause", values: [0]).isAccepted)
        try engine.run(steps: 60)
        let sunk = try XCTUnwrap(engine.core).document.food
        XCTAssertTrue(zip(sunk, held).allSatisfy { $0.position.y < $1.position.y } || sunk.count < held.count)
    }

    func testDecorKindPlaceMoveAndRemove() async throws {
        var engine = try await makeEngine()
        let starter = try XCTUnwrap(engine.core).document.decor
        XCTAssertTrue(engine.handle(control: "decor.kind", values: [2]).isAccepted)
        XCTAssertTrue(engine.handle(control: "decor.place", values: [0.25, 0.2]).isAccepted)
        var decor = try XCTUnwrap(engine.core).document.decor
        XCTAssertEqual(decor.count, starter.count + 1)
        XCTAssertEqual(decor.last?.kindId, AquariumCore.catalog.decor[2].id)
        XCTAssertEqual(decor.last?.position, Vec2(4, 1.8))
        XCTAssertEqual(decor.last?.rotation, 0)
        XCTAssertEqual(decor.last?.scale, 1)
        XCTAssertTrue(engine.handle(control: "decor.move", values: [0, 0.75, 0.3]).isAccepted)
        decor = try XCTUnwrap(engine.core).document.decor
        XCTAssertEqual(decor[0].position.x, 12, accuracy: 1e-9)
        XCTAssertEqual(decor[0].position.y, 2.7, accuracy: 1e-9)
        XCTAssertTrue(engine.handle(control: "decor.remove", values: [0]).isAccepted)
        XCTAssertEqual(try XCTUnwrap(engine.core).document.decor.count, starter.count)
        let last = Double(starter.count)        // the index that no longer exists
        XCTAssertEqual(engine.handle(control: "decor.move", values: [last, 0.5, 0.5]).code,
                       "action.rule." + AquariumRule.noSuchDecor, "a just-removed index is refused")
        XCTAssertEqual(engine.handle(control: "decor.remove", values: [11]).code,
                       "action.rule." + AquariumRule.noSuchDecor)
        XCTAssertEqual(engine.handle(control: "decor.kind", values: [1.5]).code,
                       "action.rule." + AquariumRule.invalidChoice)
        while try XCTUnwrap(engine.core).document.decor.count < HabitatDocument.maxDecor {
            XCTAssertTrue(engine.handle(control: "decor.place", values: [0.5, 0.5]).isAccepted)
        }
        XCTAssertEqual(engine.handle(control: "decor.place", values: [0.5, 0.5]).code,
                       "action.rule." + AquariumRule.decorFull)
    }

    func testAHabitatChangeClearsFoodAndKeepsTheChosenKind() async throws {
        var engine = try await makeEngine()
        XCTAssertTrue(engine.handle(control: "decor.kind", values: [1]).isAccepted)
        XCTAssertTrue(engine.handle(control: "food.drop", values: [0.5, 0.8]).isAccepted)
        XCTAssertTrue(engine.handle(control: "decor.remove", values: [0]).isAccepted)
        XCTAssertTrue(engine.handle(control: "habitat.select", values: [1]).isAccepted)
        let core = try XCTUnwrap(engine.core)
        XCTAssertTrue(core.document.food.isEmpty)
        XCTAssertEqual(core.document.decor, AquariumCore.catalog.habitats[1].decor.map(DecorPlacement.init))
        XCTAssertEqual(core.decorKind, 1)
    }

    func testSchemaTwoSnapshotsMigrateAndADamagedKindIsRefused() async throws {
        let example = try XCTUnwrap(AquariumCore.schemaTwoExample())
        XCTAssertEqual(example.version, 2)
        var engine = try await makeEngine(seed: 3)
        try engine.restore(ExperienceSnapshot(data: example.snapshot))
        XCTAssertEqual(try engine.digest().hex, example.expectedDigest)
        let core = try XCTUnwrap(engine.core)
        XCTAssertEqual(core.document.schema, HabitatDocument.currentSchema)
        XCTAssertTrue(core.document.food.isEmpty)
        XCTAssertEqual(core.decorKind, 0)
        XCTAssertEqual(core.document.lighting, 0)
        var damaged = core.state
        damaged.decorKind = 5
        XCTAssertThrowsError(try AquariumCore.restore(payload: AquariumCore.encode(damaged), seed: 7)) { error in
            XCTAssertEqual(error as? AquariumRestoreError, .invalidDecorKind(5))
        }
    }
}
