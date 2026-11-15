// WorldsCoreTests — feature 089 (A12-P01) T-A12-104 (FR-A12-111, FR-A12-121, FR-A12-122; clarifications 4 and 5;
// research D4; SC-A12-103). The adapter core of Tiny Worlds against the experience contract, short runs only (no wall
// clock): the id, the five controls, schema 1, three quality tiers and the default step; conformance over four seeds;
// the first state (the preparation seed naming the world's seed, the default world otherwise); every action accepted
// in range; refusals by the engine and by the core (`a12.invalid-choice`) each leaving the state as it was; new seeds
// from the generator; host steps changing nothing; the digest covering the state and its terrain; the snapshot round
// trip into another engine; damaged and newer snapshots refused; reset; the outcome. Feature 090 (A12-P02) T-A12-205
// (FR-A12-210; SC-A12-201; edge case "Damaged or newer saved state"): every restored and every acted view keeps the
// camera policy (limits and the 0.5 m clearance over the level-0 terrain), a restored view equals its policy clamp,
// and a view that keeps the clearance restores unchanged.
import Foundation
import XCTest
@testable import TinyWorldsExperience
import TinyWorldsCore
import VisualCoreExperience
import VisualCoreMath
import VisualCoreSimulation

final class WorldsCoreTests: XCTestCase {
    private let worldsID = ExperienceID(rawValue: WorldsCore.experienceID)!

    private func makeEngine(seed: UInt64 = 1) async throws -> ExperienceEngine<WorldsCore> {
        var engine = ExperienceEngine<WorldsCore>(id: worldsID)
        try await engine.prepare(seed: seed)
        try engine.activate()
        return engine
    }

    private func action(_ control: String, _ values: [Double] = []) -> ExperienceAction {
        ExperienceAction(control: control, values: values, step: 0)
    }

    func testIdControlsSchemaTiersAndStep() {
        XCTAssertEqual(WorldsCore.experienceID, "a12.tiny-worlds")
        XCTAssertEqual(WorldsCore.controls.map(\.id),
                       ["world.preset", "world.seed", "view.orbit", "view.zoom", "view.reset"])
        XCTAssertEqual(WorldsCore.controls.map(\.id), WorldsCore.actionIDs)
        XCTAssertEqual(WorldsCore.controls.map(\.ranges), [[0...2], [], [-180...180, -180...180], [0.5...2], []])
        XCTAssertEqual(WorldsCore.migrations.currentVersion, 1)
        XCTAssertEqual(WorldsCore.qualityTiers, 3, "level-0…level-2 (feature 090)")
        XCTAssertEqual(WorldsCore.stepDuration, 1.0 / 120, accuracy: 1e-15)
        XCTAssertEqual(WorldsRule.invalidChoice, "a12.invalid-choice")
    }

    func testConformancePassesOverFourSeeds() async {
        let plan = ConformancePlan(
            seeds: [1, 2, 7, 0xFFFF_FFFF_FFFF_FFFF], stepsPerSegment: 5,
            actions: [ScriptedAction("world.preset", [1]), ScriptedAction("world.seed"),
                      ScriptedAction("view.orbit", [20, -5]), ScriptedAction("view.zoom", [1.5]),
                      ScriptedAction("view.reset"), ScriptedAction("world.preset", [2]),
                      ScriptedAction("world.seed")],
            rejected: [ScriptedAction("world.preset", [0.5]), ScriptedAction("world.preset", [3]),
                       ScriptedAction("world.preset", [.nan]), ScriptedAction("world.preset", []),
                       ScriptedAction("world.seed", [1]), ScriptedAction("view.orbit", [200, 0]),
                       ScriptedAction("view.orbit", [10]), ScriptedAction("view.zoom", [0.25]),
                       ScriptedAction("view.zoom", [.infinity]), ScriptedAction("view.reset", [0]),
                       ScriptedAction("bogus")])
        let report = await ExperienceConformance.run(WorldsCore.self, id: worldsID, plan: plan)
        for entry in report.entries { XCTAssertTrue(entry.passed, "\(entry.check): \(entry.detail)") }
    }

    func testThePreparationSeedNamesTheWorldsSeed() async throws {
        let engine = try await makeEngine(seed: 1)
        let core = try XCTUnwrap(engine.core)
        XCTAssertEqual(core.state, WorldState.initial, "seed 1 opens the default world")
        XCTAssertEqual(core.preset, .island)
        XCTAssertEqual(core.view, .default)
        XCTAssertEqual(core.terrainDigest, try TerrainGenerator.digest(preset: .island, seed: 1))
        XCTAssertEqual(core.outcome?.code, "world-island")

        XCTAssertEqual(WorldsCore(seed: 2).seed, 2)
        XCTAssertEqual(WorldsCore(seed: 3).seed, 3)
        XCTAssertEqual(WorldsCore(seed: UInt64(UInt32.max)).seed, UInt32.max)
        // Outside 1…UInt32.max (zero, or the one app's per-experience seed of more than 32 bits) the default world.
        let appSeed = "a12.tiny-worlds".utf8.prefix(8).reduce(UInt64(0)) { ($0 << 8) | UInt64($1) }
        for seed: UInt64 in [0, UInt64(UInt32.max) + 1, appSeed, .max] {
            XCTAssertEqual(WorldsCore(seed: seed).state, WorldState.initial, "seed \(seed)")
        }
        XCTAssertEqual(WorldsCore(seed: 2).state.random, WorldState.initial.random, "the same fresh generator")
    }

    func testActionsInRangeAreAccepted() async throws {
        var engine = try await makeEngine()
        let start = try engine.digest()
        XCTAssertEqual(engine.handle(control: "world.preset", values: [1]), .accepted)
        var core = try XCTUnwrap(engine.core)
        XCTAssertEqual(core.preset, .asteroidGarden)
        XCTAssertEqual(core.terrainDigest, try TerrainGenerator.digest(preset: .asteroidGarden, seed: 1))
        XCTAssertNotEqual(try engine.digest(), start, "a preset changes the digest")
        XCTAssertEqual(engine.handle(control: "world.preset", values: [2]), .accepted)
        XCTAssertEqual(try XCTUnwrap(engine.core).preset, .miniatureCity)

        XCTAssertEqual(engine.handle(control: "view.orbit", values: [-30, 15]), .accepted)
        core = try XCTUnwrap(engine.core)
        XCTAssertEqual(core.view.yawDegrees, 15, accuracy: 1e-9)
        XCTAssertEqual(core.view.pitchDegrees, 50, accuracy: 1e-9)
        XCTAssertEqual(engine.handle(control: "view.orbit", values: [0, 180]), .accepted)
        XCTAssertEqual(try XCTUnwrap(engine.core).view.pitchDegrees, 75, accuracy: 1e-9, "pitch clamped to 75°")
        XCTAssertEqual(engine.handle(control: "view.zoom", values: [2]), .accepted)
        XCTAssertEqual(try XCTUnwrap(engine.core).view.distance, 10, accuracy: 1e-12, "18 / 2 clamped to 10 m")
        XCTAssertEqual(engine.handle(control: "view.zoom", values: [0.5]), .accepted)
        XCTAssertEqual(try XCTUnwrap(engine.core).view.distance, 20, accuracy: 1e-12)
        let terrain = try XCTUnwrap(engine.core).terrainDigest
        XCTAssertEqual(engine.handle(control: "view.reset"), .accepted)
        core = try XCTUnwrap(engine.core)
        XCTAssertEqual(core.view, .default)
        XCTAssertEqual(core.terrainDigest, terrain, "the view never changes the terrain")
        XCTAssertEqual(core.preset, .miniatureCity)
    }

    func testRefusalsKeepTheStateWithTheirReasons() async throws {
        var engine = try await makeEngine()
        XCTAssertEqual(engine.handle(control: "world.preset", values: [1]), .accepted)
        let before = try engine.digest()
        XCTAssertEqual(engine.handle(control: "world.preset", values: [3]), .rejected(.outOfRange(index: 0)))
        XCTAssertEqual(engine.handle(control: "world.preset", values: [.nan]), .rejected(.nonFinite(index: 0)))
        XCTAssertEqual(engine.handle(control: "world.preset", values: [0.5]),
                       .rejected(.rule(code: WorldsRule.invalidChoice)))
        XCTAssertEqual(engine.handle(control: "view.orbit", values: [181, 0]), .rejected(.outOfRange(index: 0)))
        XCTAssertEqual(engine.handle(control: "view.orbit", values: [0, -.infinity]),
                       .rejected(.nonFinite(index: 1)))
        XCTAssertEqual(engine.handle(control: "view.zoom", values: [0.25]), .rejected(.outOfRange(index: 0)))
        XCTAssertEqual(engine.handle(control: "world.seed", values: [1]),
                       .rejected(.wrongValueCount(expected: 0, found: 1)))
        XCTAssertEqual(engine.handle(control: "bogus", values: []), .rejected(.unknownControl("bogus")))
        XCTAssertEqual(try engine.digest(), before)

        // Called directly, the core refuses by its own rules and changes nothing.
        var core = try XCTUnwrap(engine.core)
        let original = core
        let invalid = ActionResult.rejected(.rule(code: WorldsRule.invalidChoice))
        XCTAssertEqual(core.apply(action("world.preset", [3])), invalid)
        XCTAssertEqual(core.apply(action("world.preset", [-1])), invalid)
        XCTAssertEqual(core.apply(action("world.preset", [1.5])), invalid)
        XCTAssertEqual(core.apply(action("world.preset", [.nan])), invalid)
        XCTAssertEqual(core.apply(action("view.orbit", [200, 0])), invalid)
        XCTAssertEqual(core.apply(action("view.orbit", [0, .nan])), invalid)
        XCTAssertEqual(core.apply(action("view.zoom", [2.5])), invalid)
        XCTAssertEqual(core.apply(action("view.zoom", [0.1])), invalid)
        XCTAssertEqual(core.apply(action("view.zoom", [.infinity])), invalid)
        XCTAssertEqual(core.apply(action("world.preset")), .rejected(.wrongValueCount(expected: 1, found: 0)))
        XCTAssertEqual(core.apply(action("view.orbit", [1])), .rejected(.wrongValueCount(expected: 2, found: 1)))
        XCTAssertEqual(core.apply(action("view.reset", [0])), .rejected(.wrongValueCount(expected: 0, found: 1)))
        XCTAssertEqual(core.apply(action("bogus", [0])), .rejected(.unknownControl("bogus")))
        XCTAssertEqual(core, original, "the preset, seed, view, generator and terrain are unchanged")
    }

    func testNewSeedsComeFromTheGenerator() throws {
        var core = WorldsCore(seed: 1)
        var expected = core.state
        let next = expected.newSeed()
        XCTAssertEqual(core.apply(action("world.seed")), .accepted)
        XCTAssertEqual(core.state, expected)
        XCTAssertEqual(core.seed, next)
        XCTAssertNotEqual(core.seed, 1, "a new seed changes the world")
        XCTAssertEqual(core.terrainDigest, try TerrainGenerator.digest(preset: .island, seed: next))
        XCTAssertNotEqual(core.terrainDigest, WorldsCore(seed: 1).terrainDigest)

        var again = WorldsCore(seed: 1)
        _ = again.apply(action("world.seed"))
        XCTAssertEqual(again, core, "the same actions give the same seeds")
        _ = core.apply(action("world.seed"))
        XCTAssertNotEqual(core.seed, next, "the generator moves on")
    }

    func testHostStepsChangeNothing() async throws {
        var engine = try await makeEngine()
        XCTAssertEqual(engine.handle(control: "view.orbit", values: [10, 5]), .accepted)
        let core = try XCTUnwrap(engine.core)
        let digest = try engine.digest()
        try engine.run(steps: 240)
        XCTAssertEqual(try XCTUnwrap(engine.core), core, "nothing animates")
        XCTAssertEqual(try engine.digest(), digest)
    }

    func testTheDigestCoversTheStateAndItsTerrain() throws {
        let base = WorldState.initial
        var generator = try SeededRandom(restoring: base.random)
        _ = generator.next()
        var turned = base.view
        XCTAssertTrue(turned.orbit(yawDegrees: 1, pitchDegrees: 0))
        var zoomed = base.view
        XCTAssertTrue(zoomed.zoom(1.1))
        let states = [
            base,
            WorldState(presetIndex: 1, seed: base.seed, view: base.view, random: base.random),
            WorldState(presetIndex: 0, seed: 2, view: base.view, random: base.random),
            WorldState(presetIndex: 0, seed: base.seed, view: turned, random: base.random),
            WorldState(presetIndex: 0, seed: base.seed, view: zoomed, random: base.random),
            WorldState(presetIndex: 0, seed: base.seed, view: base.view, random: generator.state),
        ]
        let digests = try states.map { try worldsDigest(worldsCore($0)) }
        XCTAssertEqual(Set(digests).count, states.count, "preset, seed, view and generator are digested")
        XCTAssertEqual(try worldsDigest(worldsCore(base, seed: 9)), digests[0], "the preparation seed is not state")

        // The terrain digest is part of the digested text: a core whose cached terrain differed would digest
        // differently.
        var builder = DigestBuilder(domain: WorldsCore.experienceID)
        let text = String(data: base.encoded(), encoding: .utf8) ?? ""
        let terrain = try TerrainGenerator.digest(preset: .island, seed: 1)
        builder.add("a12.worlds.v1|" + text + "|terrain:" + terrain)
        XCTAssertEqual(builder.finish().hex, digests[0])
    }

    func testTheSnapshotRestoresIdenticallyInAnotherEngine() async throws {
        var engine = try await makeEngine()
        for entry in WorldsCore.inputEntries {
            try engine.run(steps: entry.steps)
            if let action = entry.action {
                XCTAssertEqual(engine.handle(control: action.control, values: action.values), .accepted)
            }
        }
        let snapshot = try engine.snapshot()
        XCTAssertEqual(snapshot.schemaVersion, 1)
        XCTAssertEqual(Data(snapshot.payload.utf8), try XCTUnwrap(engine.core).state.encoded())
        let saved = try XCTUnwrap(engine.core)
        var other = try await makeEngine(seed: 3)
        try other.restore(ExperienceSnapshot(data: snapshot.encoded()))
        let restored = try XCTUnwrap(other.core)
        XCTAssertEqual(restored.state, saved.state)
        XCTAssertEqual(restored.terrainDigest, saved.terrainDigest)
        XCTAssertEqual(try other.digest(), try engine.digest())
        XCTAssertEqual(engine.handle(control: "world.seed"), .accepted)
        XCTAssertEqual(other.handle(control: "world.seed"), .accepted)
        XCTAssertEqual(try XCTUnwrap(other.core).state, try XCTUnwrap(engine.core).state, "both continue alike")
    }

    func testDamagedAndNewerSnapshotsAreRefused() async throws {
        var engine = try await makeEngine()
        XCTAssertEqual(engine.handle(control: "world.preset", values: [2]), .accepted)
        let saved = try engine.snapshot()
        let before = try engine.digest()

        // Damaged: not JSON, truncated, and JSON with a missing or invalid key.
        XCTAssertThrowsError(try engine.restore(worldsEnvelope(Data("{not json".utf8), like: saved)))
        XCTAssertThrowsError(try engine.restore(worldsEnvelope(Data(saved.payload.utf8.prefix(20)), like: saved)))
        let damaged: [(String, (inout [String: Any]) -> Void)] = [
            ("no seed", { $0["seed"] = nil }),
            ("preset 7", { $0["presetIndex"] = 7 }),
            ("seed above 32 bits", { $0["seed"] = 5_000_000_000 }),
            ("pitch 80°", { object in
                var view = object["view"] as? [String: Any] ?? [:]
                view["pitch"] = 80 * Double.pi / 180
                object["view"] = view
            }),
            ("distance 40 m", { object in
                var view = object["view"] as? [String: Any] ?? [:]
                view["distance"] = 40.0
                object["view"] = view
            }),
            ("generator", { object in
                var random = object["random"] as? [String: Any] ?? [:]
                random["words"] = ["0"]
                object["random"] = random
            }),
        ]
        for (name, change) in damaged {
            XCTAssertThrowsError(try engine.restore(worldsEnvelope(worldsPayload(saved.payload, change), like: saved)),
                                 name)
        }
        // Newer: an envelope of schema 2, and a payload of schema 2 inside a schema-1 envelope.
        XCTAssertThrowsError(try engine.restore(worldsEnvelope(Data(saved.payload.utf8), like: saved, schema: 2)))
        let newerPayload = try worldsPayload(saved.payload) { $0["schema"] = 2 }
        XCTAssertThrowsError(try engine.restore(worldsEnvelope(newerPayload, like: saved)))
        XCTAssertEqual(try engine.digest(), before, "every refusal leaves the state as it was")

        // The core names the reason.
        XCTAssertThrowsError(try WorldsCore.restore(payload: newerPayload, seed: 1)) { error in
            XCTAssertEqual(error as? WorldsRestoreError, .refused(.newerVersion))
        }
        XCTAssertThrowsError(try WorldsCore.restore(payload: Data("{not json".utf8), seed: 1)) { error in
            XCTAssertEqual(error as? WorldsRestoreError, .refused(.damaged))
        }
    }

    func testResetReturnsToThePreparedWorld() async throws {
        var engine = try await makeEngine(seed: 2)
        for entry in WorldsCore.inputEntries {
            try engine.run(steps: entry.steps)
            if let action = entry.action { _ = engine.handle(control: action.control, values: action.values) }
        }
        XCTAssertNotEqual(try XCTUnwrap(engine.core), WorldsCore(seed: 2))
        try engine.reset()
        XCTAssertEqual(try XCTUnwrap(engine.core), WorldsCore(seed: 2))
        XCTAssertEqual(try XCTUnwrap(engine.core).seed, 2)
        XCTAssertEqual(engine.stepIndex, 0)
    }

    func testTheOutcomeNamesTheWorld() {
        var core = WorldsCore(seed: 1)
        XCTAssertEqual(core.outcome?.code, "world-island")
        _ = core.apply(action("world.preset", [1]))
        XCTAssertEqual(core.outcome?.code, "world-asteroid-garden")
        _ = core.apply(action("world.preset", [2]))
        XCTAssertEqual(core.outcome?.code, "world-miniature-city")
        _ = core.apply(action("view.orbit", [90, 0]))
        XCTAssertEqual(core.outcome?.code, "world-miniature-city", "the view does not change the outcome")
        core.reset()
        XCTAssertEqual(core.outcome?.code, "world-island")
    }

    // MARK: Feature 090

    func testRestoredAndActedViewsKeepTheCameraPolicy() async throws {
        for preset in WorldPreset.all {
            let field = try TerrainGenerator.heightField(preset: preset, seed: 1)
            for yaw in stride(from: -180.0, to: 180, by: 30) {
                for (pitch, distance) in [(10.0, 10.0), (10.0, 30.0), (40.0, 10.0), (75.0, 30.0)] {
                    let view = WorldView(yaw: yaw * WorldView.radiansPerDegree,
                                         pitch: pitch * WorldView.radiansPerDegree, distance: distance)
                    let state = WorldState(presetIndex: preset.id.rawValue, seed: 1, view: view,
                                           random: WorldState.initial.random)
                    let restored = try worldsCore(state).view
                    XCTAssertTrue(CameraPolicy.keepsClearance(restored, field: field), "\(preset.name) \(view)")
                    XCTAssertEqual(restored, CameraPolicy.clamp(view, field: field))
                    if CameraPolicy.keepsClearance(view, field: field) {
                        XCTAssertEqual(restored, view, "a valid view restores unchanged")
                    }
                    XCTAssertEqual(restored.yaw, view.yaw, "the policy never turns the view")
                    XCTAssertEqual(restored.distance, view.distance, "nor moves it in or out")
                }
            }
        }

        var engine = try await makeEngine()
        let actions: [(String, [Double])] = [
            ("view.orbit", [0, -180]), ("view.zoom", [2]), ("view.zoom", [2]), ("view.orbit", [180, -180]),
            ("world.preset", [1]), ("view.orbit", [-90, -30]), ("world.preset", [2]), ("world.seed", []),
            ("view.zoom", [0.5]), ("view.orbit", [45, 180]), ("view.reset", []), ("view.orbit", [-170, -90]),
        ]
        for (control, values) in actions {
            XCTAssertEqual(engine.handle(control: control, values: values), .accepted, control)
            let core = try XCTUnwrap(engine.core)
            let field = try TerrainGenerator.heightField(preset: core.preset, seed: core.seed)
            XCTAssertTrue(CameraPolicy.keepsClearance(core.view, field: field), "\(control) \(values)")
            XCTAssertEqual(CameraPolicy.clamp(core.view, field: field), core.view, "acted views are already clamped")
        }
        XCTAssertEqual(WorldsCore(seed: 1).view, .default, "the default view keeps the policy unchanged")
        XCTAssertEqual(WorldsCore.qualityTiers, 3)
    }
}
