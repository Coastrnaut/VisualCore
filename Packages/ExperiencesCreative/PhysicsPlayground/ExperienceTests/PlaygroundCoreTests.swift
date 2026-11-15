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
                       ["world.pause", "world.step", "world.timeScale", "world.reset", "world.drop"])
        XCTAssertEqual(PlaygroundCore.controls.map(\.id), PlaygroundCore.actionIDs)
        XCTAssertEqual(PlaygroundCore.controls.map(\.ranges), [[0...1], [], [0...3], [], [0...1]])
        XCTAssertEqual(PlaygroundCore.migrations.currentVersion, 1)
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
                      ScriptedAction("world.timeScale", [0]), ScriptedAction("world.reset"),
                      ScriptedAction("world.drop", [0])],
            rejected: [ScriptedAction("world.pause", [0.5]), ScriptedAction("world.pause", [2]),
                       ScriptedAction("world.pause", [.nan]), ScriptedAction("world.pause", []),
                       ScriptedAction("world.step"), ScriptedAction("world.step", [1]),
                       ScriptedAction("world.timeScale", [2.5]), ScriptedAction("world.timeScale", [4]),
                       ScriptedAction("world.timeScale", [.infinity]), ScriptedAction("world.reset", [0]),
                       ScriptedAction("world.drop", [0.5]), ScriptedAction("world.drop", [-1]),
                       ScriptedAction("bogus")])
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
        XCTAssertEqual(core.world.bodies.count, 7)
        XCTAssertEqual(core.world.bodies.filter(\.isStatic).count, 1, "the ledge")
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
        XCTAssertEqual(try XCTUnwrap(engine.core).world.bodies.count, 8)
        XCTAssertNotEqual(try engine.digest(), start, "a drop changes the digest")
        XCTAssertEqual(engine.handle(control: "world.drop", values: [1]), .accepted)
        let dropped = try XCTUnwrap(engine.core).world.bodies
        XCTAssertEqual(dropped.count, 9)
        guard case .circle = dropped[7].shape, case .box = dropped[8].shape else {
            return XCTFail("a circle, then a box")
        }
        XCTAssertEqual(dropped[7].position.y, WorldSimulation.dropHeight)
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
        let digests = try [base, moved, spun, paused, scaled, remainder, ticked, advanced].map {
            try digest(PlaygroundCore.restore(payload: PlaygroundCore.encode($0), seed: 7))
        }
        XCTAssertEqual(Set(digests).count, 8, "positions, spins, the flags, the tick and the generator are digested")
    }

    func testTheSnapshotRestoresIdenticallyInAnotherEngine() async throws {
        var engine = try await makeEngine()
        for entry in PlaygroundCore.replayEntries(upTo: 300) {
            try engine.run(steps: entry.steps)
            if let action = entry.action { _ = engine.handle(control: action.control, values: action.values) }
        }
        let snapshot = try engine.snapshot()
        XCTAssertEqual(snapshot.schemaVersion, 1)
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

        func envelope(_ payload: Data, schema: Int = 1) throws -> ExperienceSnapshot {
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
        // Newer: schema 2 is not known to this build.
        XCTAssertThrowsError(try engine.restore(envelope(Data(saved.payload.utf8), schema: 2)))
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
