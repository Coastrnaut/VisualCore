// PlaygroundCoreTests — feature 082 (A11-P01) T-A11-104 (FR-A11-112, FR-A11-121; clarifications 4 and 5; research
// D4; SC-A11-101, SC-A11-104; contract "Experience actions"). The adapter core of Physics Playground against the
// experience contract, short runs only (simulated steps, no wall clock): the id, the five controls, schema 1, one
// quality tier and the 1/120 s step; conformance over four seeds; the first state (the seeded starting scene); every
// action accepted in range; values outside the range refused by the engine and the core's own refusals
// (`a11.invalid-choice`, `a11.not-paused`, `a11.body-cap`) each leaving the state (world and generator) as it was; a
// single step running exactly one tick; every time scale reaching the same world after the same ticks; reset and
// `world.reset`; drops and the cap; the same seed and actions giving the same world and digest; the digest covering the
// world and the generator; the snapshot round trip into another engine; damaged, invalid and newer snapshots refused;
// the outcome.
//
// Feature 083 (A11-P02) T-A11-204 (FR-A11-210, FR-A11-221; clarification 4; research D4; SC-A11-206): eight
// controls and schema 2; the starting scene's ten bodies, two springs, default levels and empty cache; the level
// actions `world.gravity`, `world.drag` and `world.stiffness` applied through the core's helpers (settings follow the
// levels) and their refusals (`a11.invalid-choice`, out of range); reset restoring the default levels; the digest
// covering the springs, levels and cache; the stored schema-1 example restoring through the migration 1 → 2 (no
// springs, default levels, bodies and generator kept) and accepted by the registry's `SnapshotMigrationCheck`; a
// schema-1 payload refused without the migration.
import Foundation
import XCTest
@testable import PhysicsPlaygroundExperience
import PhysicsPlaygroundCore
import VisualCoreExperience
import VisualCoreMath
import VisualCoreSimulation

final class PlaygroundCoreTests: XCTestCase {
    private let playgroundID = ExperienceID(rawValue: PlaygroundCore.experienceID)!

    private func makeEngine(seed: UInt64 = 7) async throws -> ExperienceEngine<PlaygroundCore> {
        var engine = ExperienceEngine<PlaygroundCore>(id: playgroundID)
        try await engine.prepare(seed: seed)
        try engine.activate()
        return engine
    }

    private func action(_ control: String, _ values: [Double] = []) -> ExperienceAction {
        ExperienceAction(control: control, values: values, step: 0)
    }

    private func digest(_ core: PlaygroundCore) throws -> String {
        var builder = DigestBuilder(domain: playgroundID.rawValue)
        try core.writeDigest(into: &builder)
        return builder.finish().hex
    }

    func testIdControlsSchemaTiersAndStep() {
        XCTAssertEqual(PlaygroundCore.experienceID, "a11.physics-playground")
        XCTAssertEqual(PlaygroundCore.controls.map(\.id),
                       ["world.pause", "world.step", "world.timeScale", "world.reset", "world.drop", "world.gravity",
                        "world.drag", "world.stiffness"])
        XCTAssertEqual(PlaygroundCore.controls.map(\.id), PlaygroundCore.actionIDs)
        XCTAssertEqual(PlaygroundCore.controls.map(\.ranges),
                       [[0...1], [], [0...3], [], [0...1], [0...2], [0...2], [0...3]])
        XCTAssertEqual(PlaygroundCore.migrations.currentVersion, 2)
        XCTAssertEqual(PlaygroundCore.snapshotSchema, 2)
        XCTAssertEqual(PlaygroundCore.qualityTiers, 1)
        XCTAssertEqual(PlaygroundCore.stepDuration, 1.0 / 120, accuracy: 1e-15)
        XCTAssertEqual(ExperienceEngine<PlaygroundCore>.stepDuration, 1.0 / 120, accuracy: 1e-15)
        XCTAssertEqual(PlaygroundRule.invalidChoice, "a11.invalid-choice")
        XCTAssertEqual(PlaygroundRule.notPaused, "a11.not-paused")
        XCTAssertEqual(PlaygroundRule.bodyCap, "a11.body-cap")
    }

    func testConformancePassesOverFourSeeds() async {
        let plan = ConformancePlan(
            seeds: [1, 7, 42, 0xFFFF_FFFF_FFFF_FFFF], stepsPerSegment: 30,
            actions: [ScriptedAction("world.drop", [0]), ScriptedAction("world.timeScale", [3]),
                      ScriptedAction("world.pause", [1]), ScriptedAction("world.step"),
                      ScriptedAction("world.pause", [0]), ScriptedAction("world.drop", [1]),
                      ScriptedAction("world.timeScale", [0]), ScriptedAction("world.gravity", [1]),
                      ScriptedAction("world.drag", [2]), ScriptedAction("world.stiffness", [3]),
                      ScriptedAction("world.reset"), ScriptedAction("world.drop", [0])],
            rejected: [ScriptedAction("world.pause", [0.5]), ScriptedAction("world.pause", [2]),
                       ScriptedAction("world.pause", [.nan]), ScriptedAction("world.pause", []),
                       ScriptedAction("world.step"), ScriptedAction("world.step", [1]),
                       ScriptedAction("world.timeScale", [2.5]), ScriptedAction("world.timeScale", [4]),
                       ScriptedAction("world.timeScale", [.infinity]), ScriptedAction("world.reset", [0]),
                       ScriptedAction("world.drop", [0.5]), ScriptedAction("world.drop", [-1]),
                       ScriptedAction("world.gravity", [0.5]), ScriptedAction("world.gravity", [3]),
                       ScriptedAction("world.drag", [1.5]), ScriptedAction("world.drag", [.nan]),
                       ScriptedAction("world.stiffness", [2.5]), ScriptedAction("world.stiffness", [4]),
                       ScriptedAction("world.stiffness", []), ScriptedAction("bogus")])
        let report = await ExperienceConformance.run(PlaygroundCore.self, id: playgroundID, plan: plan)
        for entry in report.entries { XCTAssertTrue(entry.passed, "\(entry.check): \(entry.detail)") }
    }

    func testTheFirstStateIsTheSeededStartingScene() async throws {
        let engine = try await makeEngine(seed: 99)
        let core = try XCTUnwrap(engine.core)
        var random = SeededRandom(seed: 99)
        let expected = StartingScene.make(random: &random, catalog: .bundled)
        XCTAssertEqual(core.world, expected)
        XCTAssertEqual(core.generator, random, "the generator continues after the starting scene's draws")
        XCTAssertEqual(core.world.bodies.count, 10)
        XCTAssertEqual(core.world.bodies.filter(\.isStatic).count, 1, "the ledge")
        XCTAssertEqual(core.world.springs.count, 2, "the hanging box and the joined circles")
        XCTAssertEqual(core.world.gravityLevel, ForceLevels.defaultGravityLevel)
        XCTAssertEqual(core.world.dragLevel, ForceLevels.defaultDragLevel)
        XCTAssertEqual(core.world.stiffnessLevel, ForceLevels.defaultStiffnessLevel)
        XCTAssertEqual(core.world.contactCache, [])
        XCTAssertEqual(core.world.tick, 0)
        XCTAssertFalse(core.world.paused)
        XCTAssertEqual(core.world.timeScaleIndex, PhysicsWorld.normalTimeScaleIndex)
        XCTAssertEqual(core.state.random, core.generator.state)
        XCTAssertEqual(core.outcome?.code, PlaygroundCore.runningOutcome)
        XCTAssertEqual(core.world.validate(), [])
    }

    func testTheBundledCatalogValidates() {
        let decoded = MaterialCatalog.decode(PlaygroundCore.catalog.encoded())
        XCTAssertEqual(decoded.refused, [])
        XCTAssertEqual(decoded.catalog, PlaygroundCore.catalog)
        XCTAssertEqual(LicenseAudit.problems(PlaygroundCore.catalog), [])
    }

    func testActionsInRangeAreAccepted() async throws {
        var engine = try await makeEngine()
        let start = try engine.digest()
        XCTAssertEqual(engine.handle(control: "world.drop", values: [0]), .accepted)
        XCTAssertEqual(try XCTUnwrap(engine.core).world.bodies.count, 11)
        XCTAssertNotEqual(try engine.digest(), start, "a drop changes the digest")
        XCTAssertEqual(engine.handle(control: "world.drop", values: [1]), .accepted)
        let dropped = try XCTUnwrap(engine.core).world.bodies
        XCTAssertEqual(dropped.count, 12)
        guard case .circle = dropped[10].shape, case .box = dropped[11].shape else {
            return XCTFail("a circle, then a box")
        }
        XCTAssertEqual(dropped[10].position.y, WorldSimulation.dropHeight)
        XCTAssertEqual(engine.handle(control: "world.gravity", values: [1]), .accepted)
        XCTAssertEqual(try XCTUnwrap(engine.core).world.gravityLevel, 1)
        XCTAssertEqual(engine.handle(control: "world.drag", values: [0]), .accepted)
        XCTAssertEqual(try XCTUnwrap(engine.core).world.dragLevel, 0)
        XCTAssertEqual(engine.handle(control: "world.stiffness", values: [3]), .accepted)
        XCTAssertEqual(try XCTUnwrap(engine.core).world.stiffnessLevel, 3)
        XCTAssertEqual(engine.handle(control: "world.timeScale", values: [0]), .accepted)
        XCTAssertEqual(try XCTUnwrap(engine.core).world.timeScaleIndex, 0)
        XCTAssertEqual(engine.handle(control: "world.pause", values: [1]), .accepted)
        XCTAssertTrue(try XCTUnwrap(engine.core).world.paused)
        XCTAssertEqual(try XCTUnwrap(engine.core).outcome?.code, PlaygroundCore.pausedOutcome)
        XCTAssertEqual(engine.handle(control: "world.step"), .accepted)
        XCTAssertEqual(try XCTUnwrap(engine.core).world.tick, 1, "one tick whatever the time scale")
        XCTAssertEqual(engine.handle(control: "world.pause", values: [0]), .accepted)
        XCTAssertFalse(try XCTUnwrap(engine.core).world.paused)
        XCTAssertEqual(engine.handle(control: "world.reset"), .accepted)
        XCTAssertEqual(try XCTUnwrap(engine.core), PlaygroundCore(seed: 7), "world.reset: the starting scene")
    }

    func testRefusalsKeepTheStateWithTheirReasons() async throws {
        var engine = try await makeEngine()
        try engine.run(steps: 40)
        let before = try engine.digest()
        XCTAssertEqual(engine.handle(control: "world.pause", values: [2]), .rejected(.outOfRange(index: 0)))
        XCTAssertEqual(engine.handle(control: "world.pause", values: [.nan]), .rejected(.nonFinite(index: 0)))
        XCTAssertEqual(engine.handle(control: "world.pause", values: [0.5]),
                       .rejected(.rule(code: PlaygroundRule.invalidChoice)))
        XCTAssertEqual(engine.handle(control: "world.timeScale", values: [4]), .rejected(.outOfRange(index: 0)))
        XCTAssertEqual(engine.handle(control: "world.timeScale", values: [1.25]),
                       .rejected(.rule(code: PlaygroundRule.invalidChoice)))
        XCTAssertEqual(engine.handle(control: "world.step"), .rejected(.rule(code: PlaygroundRule.notPaused)))
        XCTAssertEqual(engine.handle(control: "world.drop", values: [0.5]),
                       .rejected(.rule(code: PlaygroundRule.invalidChoice)))
        XCTAssertEqual(engine.handle(control: "world.drop", values: [-1]), .rejected(.outOfRange(index: 0)))
        XCTAssertEqual(engine.handle(control: "world.gravity", values: [0.5]),
                       .rejected(.rule(code: PlaygroundRule.invalidChoice)))
        XCTAssertEqual(engine.handle(control: "world.gravity", values: [3]), .rejected(.outOfRange(index: 0)))
        XCTAssertEqual(engine.handle(control: "world.drag", values: [1.75]),
                       .rejected(.rule(code: PlaygroundRule.invalidChoice)))
        XCTAssertEqual(engine.handle(control: "world.drag", values: [-1]), .rejected(.outOfRange(index: 0)))
        XCTAssertEqual(engine.handle(control: "world.stiffness", values: [2.5]),
                       .rejected(.rule(code: PlaygroundRule.invalidChoice)))
        XCTAssertEqual(engine.handle(control: "world.stiffness", values: [4]), .rejected(.outOfRange(index: 0)))
        XCTAssertEqual(engine.handle(control: "world.stiffness", values: [.infinity]),
                       .rejected(.nonFinite(index: 0)))
        XCTAssertEqual(engine.handle(control: "world.reset", values: [1]),
                       .rejected(.wrongValueCount(expected: 0, found: 1)))
        XCTAssertEqual(engine.handle(control: "bogus", values: []), .rejected(.unknownControl("bogus")))
        XCTAssertEqual(try engine.digest(), before)

        // Called directly, the core refuses by its own rules and changes nothing.
        var core = try XCTUnwrap(engine.core)
        let original = core
        XCTAssertEqual(core.apply(action("world.pause", [2])), .rejected(.rule(code: PlaygroundRule.invalidChoice)))
        XCTAssertEqual(core.apply(action("world.pause", [-1])), .rejected(.rule(code: PlaygroundRule.invalidChoice)))
        XCTAssertEqual(core.apply(action("world.timeScale", [.nan])),
                       .rejected(.rule(code: PlaygroundRule.invalidChoice)))
        XCTAssertEqual(core.apply(action("world.timeScale", [3.5])),
                       .rejected(.rule(code: PlaygroundRule.invalidChoice)))
        XCTAssertEqual(core.apply(action("world.drop", [2])), .rejected(.rule(code: PlaygroundRule.invalidChoice)))
        XCTAssertEqual(core.apply(action("world.gravity", [3])), .rejected(.rule(code: PlaygroundRule.invalidChoice)))
        XCTAssertEqual(core.apply(action("world.gravity", [.nan])),
                       .rejected(.rule(code: PlaygroundRule.invalidChoice)))
        XCTAssertEqual(core.apply(action("world.drag", [-1])), .rejected(.rule(code: PlaygroundRule.invalidChoice)))
        XCTAssertEqual(core.apply(action("world.stiffness", [4])),
                       .rejected(.rule(code: PlaygroundRule.invalidChoice)))
        XCTAssertEqual(core.apply(action("world.stiffness", [0.5])),
                       .rejected(.rule(code: PlaygroundRule.invalidChoice)))
        XCTAssertEqual(core.apply(action("world.gravity")), .rejected(.wrongValueCount(expected: 1, found: 0)))
        XCTAssertEqual(core.apply(action("world.drag", [0, 1])), .rejected(.wrongValueCount(expected: 1, found: 2)))
        XCTAssertEqual(core.apply(action("world.step")), .rejected(.rule(code: PlaygroundRule.notPaused)))
        XCTAssertEqual(core.apply(action("world.pause")), .rejected(.wrongValueCount(expected: 1, found: 0)))
        XCTAssertEqual(core.apply(action("world.drop", [0, 1])), .rejected(.wrongValueCount(expected: 1, found: 2)))
        XCTAssertEqual(core.apply(action("world.step", [0])), .rejected(.wrongValueCount(expected: 0, found: 1)))
        XCTAssertEqual(core.apply(action("bogus", [0])), .rejected(.unknownControl("bogus")))
        XCTAssertEqual(core, original, "the world and the generator are unchanged")
    }

    func testASingleStepRunsExactlyOneTickOnlyWhilePaused() async throws {
        var engine = try await makeEngine()
        try engine.run(steps: 30)
        XCTAssertEqual(engine.handle(control: "world.pause", values: [1]), .accepted)
        let paused = try XCTUnwrap(engine.core)
        try engine.run(steps: 50)
        XCTAssertEqual(try XCTUnwrap(engine.core), paused, "host steps do nothing while paused")

        XCTAssertEqual(engine.handle(control: "world.step"), .accepted)
        let stepped = try XCTUnwrap(engine.core)
        var expected = paused.world
        XCTAssertTrue(WorldSimulation.tick(&expected, catalog: .bundled))
        XCTAssertEqual(stepped.world, expected, "exactly one tick")
        XCTAssertEqual(stepped.world.tick, paused.world.tick + 1)
        XCTAssertEqual(stepped.generator, paused.generator)

        // At ¼× a single step is still one whole tick and the remainder is kept.
        XCTAssertEqual(engine.handle(control: "world.timeScale", values: [0]), .accepted)
        let remainder = try XCTUnwrap(engine.core).world.remainder
        XCTAssertEqual(engine.handle(control: "world.step"), .accepted)
        XCTAssertEqual(try XCTUnwrap(engine.core).world.tick, paused.world.tick + 2)
        XCTAssertEqual(try XCTUnwrap(engine.core).world.remainder, remainder)

        XCTAssertEqual(engine.handle(control: "world.pause", values: [0]), .accepted)
        let running = try XCTUnwrap(engine.core)
        XCTAssertEqual(engine.handle(control: "world.step"), .rejected(.rule(code: PlaygroundRule.notPaused)))
        XCTAssertEqual(try XCTUnwrap(engine.core), running)
    }

    func testEveryTimeScaleReachesTheSameWorldAfterTheSameTicks() async throws {
        // 40 ticks: ¼× takes 160 host steps, ½× 80, 1× 40 and 2× 20.
        let hostSteps = [160, 80, 40, 20]
        var worlds: [PhysicsWorld] = []
        for (index, steps) in hostSteps.enumerated() {
            var engine = try await makeEngine()
            XCTAssertEqual(engine.handle(control: "world.drop", values: [1]), .accepted)
            XCTAssertEqual(engine.handle(control: "world.timeScale", values: [Double(index)]), .accepted)
            try engine.run(steps: steps)
            var world = try XCTUnwrap(engine.core).world
            XCTAssertEqual(world.tick, 40, "time scale \(index)")
            XCTAssertEqual(world.remainder, 0, "time scale \(index)")
            world.timeScaleIndex = PhysicsWorld.normalTimeScaleIndex
            worlds.append(world)
        }
        for world in worlds.dropFirst() { XCTAssertEqual(world, worlds[0]) }

        // ¼× runs one tick every fourth host step.
        var engine = try await makeEngine()
        XCTAssertEqual(engine.handle(control: "world.timeScale", values: [0]), .accepted)
        let ticks = try (0..<8).map { _ -> Int in
            try engine.run(steps: 1)
            return try XCTUnwrap(engine.core).world.tick
        }
        XCTAssertEqual(ticks, [0, 0, 0, 1, 1, 1, 1, 2])
    }

    func testDropsUseTheGeneratorAndStopAtTheCap() async throws {
        var core = PlaygroundCore(seed: 7)
        var expected = core.world
        var random = core.generator
        XCTAssertTrue(WorldSimulation.drop(&expected, kind: .box, random: &random, catalog: .bundled))
        XCTAssertEqual(core.apply(action("world.drop", [1])), .accepted)
        XCTAssertEqual(core.world, expected)
        XCTAssertEqual(core.generator, random)

        while core.world.bodies.count < PhysicsWorld.maxBodies {
            XCTAssertEqual(core.apply(action("world.drop", [Double(core.world.bodies.count % 2)])), .accepted)
        }
        XCTAssertEqual(core.world.bodies.count, 48)
        let full = core
        XCTAssertEqual(core.apply(action("world.drop", [0])), .rejected(.rule(code: PlaygroundRule.bodyCap)))
        XCTAssertEqual(core.apply(action("world.drop", [1])), .rejected(.rule(code: PlaygroundRule.bodyCap)))
        XCTAssertEqual(core, full, "a refused drop draws nothing from the generator")
        XCTAssertEqual(core.world.validate(), [])
    }

    func testTheSameSeedAndActionsGiveTheSameWorld() async throws {
        let entries = PlaygroundCore.replayEntries()
        let a = PlaygroundCore.played(seed: 7, entries: entries)
        let b = PlaygroundCore.played(seed: 7, entries: entries)
        XCTAssertEqual(a, b)
        XCTAssertEqual(try digest(a), try digest(b))
        XCTAssertGreaterThan(a.world.bodies.count, 7)
        let other = PlaygroundCore.played(seed: 8, entries: entries)
        XCTAssertNotEqual(try digest(other), try digest(a), "another seed gives another world")

        // The engine plays the same entries to the same state.
        var engine = try await makeEngine()
        for entry in entries {
            try engine.run(steps: entry.steps)
            if let action = entry.action {
                XCTAssertEqual(engine.handle(control: action.control, values: action.values), .accepted)
            }
        }
        XCTAssertEqual(try XCTUnwrap(engine.core), a)
    }

    func testTheDigestCoversTheWorldAndTheGenerator() throws {
        let core = PlaygroundCore(seed: 7)
        let base = core.state
        var moved = base
        moved.world.bodies[1].position.x += 0.001
        var spun = base
        spun.world.bodies[1].angularVelocity = 0.5
        var paused = base
        paused.world.paused = true
        var scaled = base
        scaled.world.timeScaleIndex = 3
        var remainder = base
        remainder.world.remainder = 2
        var ticked = base
        ticked.world.tick = 5
        var advanced = base
        var random = core.generator
        _ = random.next()
        advanced.random = random.state
        var rest = base
        rest.world.springs[0].restLength += 0.01
        var anchored = base
        anchored.world.springs[0].a = .world(Vec2(7.4, 8.0))
        var moon = base
        XCTAssertTrue(WorldSimulation.setGravityLevel(&moon.world, 1))
        var draggy = base
        XCTAssertTrue(WorldSimulation.setDragLevel(&draggy.world, 2))
        var stiff = base
        stiff.world.stiffnessLevel = 0
        var cached = base
        cached.world.contactCache = [ContactCacheEntry(bodyA: 8, bodyB: ContactCacheEntry.wallMarker(0),
                                                       pointIndex: 0, normalImpulse: 0.01, tangentImpulse: 0)]
        let states = [base, moved, spun, paused, scaled, remainder, ticked, advanced, rest, anchored, moon, draggy,
                      stiff, cached]
        let digests = try states.map {
            try digest(PlaygroundCore.restore(payload: PlaygroundCore.encode($0), seed: 7))
        }
        XCTAssertEqual(Set(digests).count, states.count,
                       "positions, spins, the flags, the tick, the generator, springs, levels and cache are digested")
    }

    func testTheSnapshotRestoresIdenticallyInAnotherEngine() async throws {
        var engine = try await makeEngine()
        for entry in PlaygroundCore.replayEntries(upTo: 300) {
            try engine.run(steps: entry.steps)
            if let action = entry.action { _ = engine.handle(control: action.control, values: action.values) }
        }
        let snapshot = try engine.snapshot()
        XCTAssertEqual(snapshot.schemaVersion, 2)
        let saved = try XCTUnwrap(engine.core)
        var other = try await makeEngine(seed: 3)
        try other.restore(ExperienceSnapshot(data: snapshot.encoded()))
        let restored = try XCTUnwrap(other.core)
        XCTAssertEqual(restored.state, saved.state)
        XCTAssertEqual(try other.digest(), try engine.digest())
        try engine.run(steps: 150)
        try other.run(steps: 150)
        XCTAssertEqual(try XCTUnwrap(other.core).state, try XCTUnwrap(engine.core).state, "both continue alike")
    }

    func testDamagedInvalidAndNewerSnapshotsAreRefused() async throws {
        var engine = try await makeEngine()
        try engine.run(steps: 60)
        let saved = try engine.snapshot()
        let before = try engine.digest()

        func envelope(_ payload: Data, schema: Int = 2) throws -> ExperienceSnapshot {
            try ExperienceSnapshot(experience: playgroundID, schemaVersion: schema, seed: saved.seed,
                                   stepIndex: saved.stepIndex, digest: saved.digest, payload: payload)
        }
        func with(_ change: (inout [String: Any]) -> Void) throws -> Data {
            var object = try XCTUnwrap(try JSONSerialization.jsonObject(with: Data(saved.payload.utf8))
                                       as? [String: Any])
            var world = try XCTUnwrap(object["world"] as? [String: Any])
            change(&world)
            object["world"] = world
            return try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        }

        // Damaged: not JSON, and JSON without the world.
        XCTAssertThrowsError(try engine.restore(envelope(Data("{not json".utf8))))
        XCTAssertThrowsError(try engine.restore(envelope(Data("{\"random\":{}}".utf8))))
        // Invalid worlds: a time scale outside 0…3, a negative tick, an unknown material, a body outside the stage.
        let invalid: [(String, (inout [String: Any]) -> Void)] = [
            ("time scale", { $0["timeScaleIndex"] = 9 }),
            ("tick", { $0["tick"] = -1 }),
            ("material", { world in
                var bodies = world["bodies"] as? [[String: Any]] ?? []
                bodies[1]["materialId"] = "unobtanium"
                world["bodies"] = bodies
            }),
            ("position", { world in
                var bodies = world["bodies"] as? [[String: Any]] ?? []
                bodies[1]["position"] = ["x": 30.0, "y": 4.0]
                world["bodies"] = bodies
            }),
            ("gravity level", { $0["gravityLevel"] = 7 }),
            ("stiffness level", { $0["stiffnessLevel"] = -1 }),
            ("level and settings disagree", { $0["dragLevel"] = 2 }),
            ("spring to a missing body", { world in
                var springs = world["springs"] as? [[String: Any]] ?? []
                springs[1]["b"] = ["bodyId": 99, "point": ["x": 0.0, "y": 0.0]]
                world["springs"] = springs
            }),
            ("spring rest length", { world in
                var springs = world["springs"] as? [[String: Any]] ?? []
                springs[0]["restLength"] = 0.0
                world["springs"] = springs
            }),
            ("contact cache", { $0["contactCache"] = [["bodyA": -1, "bodyB": 0, "pointIndex": 0,
                                                       "normalImpulse": 0.0, "tangentImpulse": 0.0]] }),
            ("no springs key", { $0["springs"] = nil }),
        ]
        for (name, change) in invalid {
            XCTAssertThrowsError(try engine.restore(envelope(with(change))), name)
        }
        // A malformed generator state (with the valid world).
        var object = try XCTUnwrap(try JSONSerialization.jsonObject(with: Data(saved.payload.utf8)) as? [String: Any])
        var random = try XCTUnwrap(object["random"] as? [String: Any])
        random["words"] = ["0"]
        object["random"] = random
        XCTAssertThrowsError(try engine.restore(envelope(
            JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]))))
        // Newer: schema 3 is not known to this build.
        XCTAssertThrowsError(try engine.restore(envelope(Data(saved.payload.utf8), schema: 3)))
        // A schema-2 payload sent as schema 1 runs the step 1 → 2, which refuses it (its world is not schema 1).
        XCTAssertThrowsError(try engine.restore(envelope(Data(saved.payload.utf8), schema: 1)))
        XCTAssertEqual(try engine.digest(), before, "every refusal leaves the state as it was")

        // The core names the reason.
        var bad = PlaygroundCore(seed: 7).state
        bad.world.remainder = 12
        XCTAssertThrowsError(try PlaygroundCore.restore(payload: PlaygroundCore.encode(bad), seed: 7)) { error in
            guard case PlaygroundRestoreError.invalidWorld(let problems)? = error as? PlaygroundRestoreError else {
                return XCTFail("\(error)")
            }
            XCTAssertFalse(problems.isEmpty)
        }
    }

    func testResetReturnsToThePreparedWorld() async throws {
        var engine = try await makeEngine()
        for entry in PlaygroundCore.replayEntries(upTo: 200) {
            try engine.run(steps: entry.steps)
            if let action = entry.action { _ = engine.handle(control: action.control, values: action.values) }
        }
        XCTAssertEqual(engine.handle(control: "world.pause", values: [1]), .accepted)
        try engine.reset()
        XCTAssertEqual(try XCTUnwrap(engine.core), PlaygroundCore(seed: 7))
        XCTAssertEqual(engine.stepIndex, 0)

        // `world.reset` from a paused, slowed, fuller world: the starting scene at 1×, running, generator restarted.
        var core = PlaygroundCore(seed: 7)
        _ = core.apply(action("world.drop", [0]))
        _ = core.apply(action("world.timeScale", [0]))
        _ = core.apply(action("world.pause", [1]))
        XCTAssertEqual(core.apply(action("world.reset")), .accepted)
        XCTAssertEqual(core, PlaygroundCore(seed: 7))
        XCTAssertEqual(core.world.timeScaleIndex, 2)
        XCTAssertFalse(core.world.paused)

        // From changed levels and a filled cache: the default levels, the starting springs and an empty cache.
        for step in 0..<240 { core.update(step: step) }
        XCTAssertFalse(core.world.contactCache.isEmpty, "landed bodies leave impulses in the cache")
        XCTAssertEqual(core.apply(action("world.gravity", [0])), .accepted)
        XCTAssertEqual(core.apply(action("world.drag", [2])), .accepted)
        XCTAssertEqual(core.apply(action("world.stiffness", [3])), .accepted)
        XCTAssertEqual(core.apply(action("world.reset")), .accepted)
        XCTAssertEqual(core, PlaygroundCore(seed: 7))
        XCTAssertEqual(core.world.gravityLevel, ForceLevels.defaultGravityLevel)
        XCTAssertEqual(core.world.dragLevel, ForceLevels.defaultDragLevel)
        XCTAssertEqual(core.world.stiffnessLevel, ForceLevels.defaultStiffnessLevel)
        XCTAssertEqual(core.world.settings, WorldSettings())
        XCTAssertEqual(core.world.springs.count, 2)
        XCTAssertEqual(core.world.contactCache, [])
    }

    /// T-A11-204 (FR-A11-221): each level action applies through the core's helper, the settings follow the level,
    /// and nothing else changes (the generator included).
    func testTheLevelActionsSetTheLevelsAndTheSettings() {
        var core = PlaygroundCore(seed: 7)
        for level in 0...2 {
            var expected = core.world
            XCTAssertTrue(WorldSimulation.setGravityLevel(&expected, level))
            XCTAssertEqual(core.apply(action("world.gravity", [Double(level)])), .accepted)
            XCTAssertEqual(core.world, expected)
            XCTAssertEqual(core.world.settings.gravity, Vec2(0, -ForceLevels.gravity[level]))
        }
        for level in 0...2 {
            XCTAssertEqual(core.apply(action("world.drag", [Double(level)])), .accepted)
            XCTAssertEqual(core.world.dragLevel, level)
            XCTAssertEqual(core.world.settings.linearDrag, ForceLevels.drag[level])
            XCTAssertEqual(core.world.settings.angularDrag, ForceLevels.drag[level])
        }
        for level in 0...3 {
            XCTAssertEqual(core.apply(action("world.stiffness", [Double(level)])), .accepted)
            XCTAssertEqual(core.world.stiffnessLevel, level)
            XCTAssertEqual(WorldSimulation.springStiffness(core.world), ForceLevels.stiffness[level])
        }
        XCTAssertEqual(core.world.validate(), [], "levels and settings agree")
        XCTAssertEqual(core.generator, PlaygroundCore(seed: 7).generator, "no draw from the generator")
        XCTAssertEqual(core.world.bodies, PlaygroundCore(seed: 7).world.bodies, "no tick ran")
    }

    /// T-A11-204 (SC-A11-206): the stored Phase 01 payload restores in a new engine through the migration 1 → 2 — the
    /// bodies, tick, ids, pause, time scale and generator kept; no springs, Earth gravity, low drag, stiffness level 1
    /// and an empty cache — with the digest the example names; it then plays on validly and identically in two
    /// engines, and the registry's check accepts it.
    func testTheSchemaOneExampleRestoresThroughTheMigration() async throws {
        let example = try XCTUnwrap(PlaygroundCore.schemaOneExample())
        XCTAssertEqual(example.version, 1)
        let snapshot = try ExperienceSnapshot(data: example.snapshot)
        XCTAssertEqual(snapshot.schemaVersion, 1)
        XCTAssertEqual(snapshot.experience, playgroundID)
        let payload = try XCTUnwrap(try JSONSerialization.jsonObject(with: Data(snapshot.payload.utf8))
                                    as? [String: Any])
        let storedWorld = try XCTUnwrap(payload["world"] as? [String: Any])
        XCTAssertEqual(storedWorld["schema"] as? Int, 1)
        for key in ["springs", "nextSpringId", "gravityLevel", "dragLevel", "stiffnessLevel", "contactCache"] {
            XCTAssertNil(storedWorld[key], "a Phase 01 world has no \(key)")
        }
        let phaseOne = try JSONDecoder().decode(PlaygroundStateSchemaOne.self, from: Data(snapshot.payload.utf8))
        XCTAssertEqual(phaseOne, PlaygroundCore.schemaOneExampleState())
        XCTAssertEqual(phaseOne.world.bodies.count, 9, "the Phase 01 scene of seven bodies and two dropped bodies")

        var engine = ExperienceEngine<PlaygroundCore>(id: playgroundID)
        try await engine.prepare(seed: 3)
        try engine.activate()
        try engine.restore(snapshot)
        XCTAssertEqual(try engine.digest().hex, example.expectedDigest)
        let core = try XCTUnwrap(engine.core)
        let world = core.world
        XCTAssertEqual(world.schema, 2)
        XCTAssertEqual(world.validate(), [])
        XCTAssertEqual(world.springs, [])
        XCTAssertEqual(world.nextSpringId, 0)
        XCTAssertEqual(world.gravityLevel, ForceLevels.defaultGravityLevel)
        XCTAssertEqual(world.dragLevel, ForceLevels.defaultDragLevel)
        XCTAssertEqual(world.stiffnessLevel, ForceLevels.defaultStiffnessLevel)
        XCTAssertEqual(world.contactCache, [])
        XCTAssertEqual(world.bodies, phaseOne.world.bodies)
        XCTAssertEqual(world.tick, phaseOne.world.tick)
        XCTAssertEqual(world.nextId, phaseOne.world.nextId)
        XCTAssertEqual(world.paused, phaseOne.world.paused)
        XCTAssertEqual(world.timeScaleIndex, phaseOne.world.timeScaleIndex)
        XCTAssertEqual(world.remainder, phaseOne.world.remainder)
        XCTAssertEqual(world.settings, WorldSettings(), "the Phase 01 defaults are Earth and low drag")
        XCTAssertEqual(core.state.random, phaseOne.random, "the generator state is kept")
        XCTAssertEqual(core.preparationSeed, snapshot.seed)

        var other = ExperienceEngine<PlaygroundCore>(id: playgroundID)
        try await other.prepare(seed: 11)
        try other.activate()
        try other.restore(ExperienceSnapshot(data: example.snapshot))
        XCTAssertTrue(try XCTUnwrap(other.core).world.paused)
        XCTAssertTrue(world.paused)
        XCTAssertEqual(engine.handle(control: "world.pause", values: [0]), .accepted)
        XCTAssertEqual(other.handle(control: "world.pause", values: [0]), .accepted)
        try engine.run(steps: 120)
        try other.run(steps: 120)
        let continued = try XCTUnwrap(engine.core)
        XCTAssertEqual(continued.world.validate(), [])
        XCTAssertEqual(continued.world.tick, 60, "120 host steps at ½× are 60 ticks")
        XCTAssertEqual(continued, try XCTUnwrap(other.core), "the migrated world plays on identically")

        let problems = await SnapshotMigrationCheck.problems(for: PlaygroundCore.self, id: playgroundID,
                                                              examples: [example])
        XCTAssertEqual(problems, [])
    }

    /// T-A11-204: a schema-1 payload handed to the restore without the migration is refused (it lacks the schema-2
    /// keys), and the step 1 → 2 refuses a payload whose world is not schema 1 or does not decode.
    func testASchemaOnePayloadNeedsTheMigration() throws {
        let example = try XCTUnwrap(PlaygroundCore.schemaOneExample())
        let snapshot = try ExperienceSnapshot(data: example.snapshot)
        XCTAssertThrowsError(try PlaygroundCore.restore(payload: Data(snapshot.payload.utf8), seed: 7))

        let current = try XCTUnwrap(try JSONSerialization.jsonObject(with: PlaygroundCore(seed: 7).snapshotPayload())
                                    as? [String: Any])
        XCTAssertThrowsError(try PlaygroundCore.migrations.migrate(current, from: 1)) { error in
            XCTAssertEqual(error as? PlaygroundRestoreError, .notSchemaOne(2))
        }
        XCTAssertThrowsError(try PlaygroundCore.migrations.migrate(["world": 1], from: 1))
        let object = try XCTUnwrap(try JSONSerialization.jsonObject(with: Data(snapshot.payload.utf8))
                                   as? [String: Any])
        let upgraded = try PlaygroundCore.migrations.migrate(object, from: 1)
        let restored = try PlaygroundCore.restore(
            payload: JSONSerialization.data(withJSONObject: upgraded, options: [.sortedKeys]), seed: 7)
        XCTAssertEqual(restored.world,
                       PhysicsWorld.migrated(fromSchemaOne: PlaygroundCore.schemaOneExampleState().world))
        XCTAssertEqual(try PlaygroundCore.migrations.migrate(current, from: 2) as NSDictionary,
                       current as NSDictionary, "a schema-2 payload needs no step")
    }

    func testTheOutcomeFollowsThePause() {
        var core = PlaygroundCore(seed: 7)
        XCTAssertEqual(core.outcome?.code, "world-running")
        _ = core.apply(action("world.pause", [1]))
        XCTAssertEqual(core.outcome?.code, "world-paused")
        _ = core.apply(action("world.reset"))
        XCTAssertEqual(core.outcome?.code, "world-running")
    }
}
