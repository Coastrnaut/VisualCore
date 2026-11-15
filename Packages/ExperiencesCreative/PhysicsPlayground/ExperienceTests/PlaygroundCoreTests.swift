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
//
// Feature 084 (A11-P03) T-A11-303 (FR-A11-301, FR-A11-320; SC-A11-305; clarifications 1, 5; contract
// contracts/actions.md): eighteen controls and schema 3; the edit and overlay actions applied through `WorldEditing`
// (the same world as the core function) with their refusals (each code of the contract, fractional ids, kinds and
// overlay values, ranges) leaving the state unchanged; the digest covering pins, selection, grab and overlay flags;
// the measured forces kept by host steps and single steps, but neither digested nor compared and cleared by reset and
// restore; the stored schema-1 example restoring through 1 → 2 → 3 and the stored schema-2 example through 2 → 3 (no
// pins, selection, grab or overlays; everything else kept), both accepted by the registry's `SnapshotMigrationCheck`;
// replays of editing sessions identical.
//
// Feature 085 (A11-P04) T-A11-403 (FR-A11-402, FR-A11-410, FR-A11-430; SC-A11-401, SC-A11-403; clarifications 2, 4, 5;
// contract contracts/experiments.md): twenty-one controls and schema 4; `world.reset` restores the starting world
// (the generator keeps going); `experiment.preset` opens each preset as the starting world and reset after edits and
// time controls returns to it exactly; `tutorial.start` and `tutorial.stop` with their refusals; both tutorials
// completed through actions and host steps; a tutorial that stays on its step when a preset or a slot opens; opening a
// saved document keeps the generator and becomes the starting world; the digest covering the origin, the starting
// world and the tutorial; the stored schema-3 example restoring through the step 3 → 4 (and the examples of schemas 1
// and 2 through the whole chain); a schema-4 state with a bad starting world or tutorial refused.
//
// Feature 086 (A11-P05) T-A11-504 (FR-A11-502, FR-A11-520; clarifications 1, 4; research D1, D3): snapshot schema 5
// with the world at world schema 4 and three quality tiers; the older examples restore through the chain ending in the
// step 4 → 5 (their worlds at world schema 4, every body awake with 0 rest ticks); a newer payload is schema 6; a
// current payload sent as an older schema is refused by the step it reaches. The schema-4 example and the tiers are
// covered by `PlaygroundQualityTests`.
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
                        "world.drag", "world.stiffness", "edit.add", "edit.select", "edit.grab", "edit.move",
                        "edit.release", "edit.pin", "edit.delete", "edit.nudge", "overlay.velocity", "overlay.forces",
                        "experiment.preset", "tutorial.start", "tutorial.stop"])
        XCTAssertEqual(PlaygroundCore.controls.map(\.id), PlaygroundCore.actionIDs)
        XCTAssertEqual(PlaygroundCore.controls.map(\.ranges),
                       [[0...1], [], [0...3], [], [0...1], [0...2], [0...2], [0...3],
                        [0...10, 0...8, 0...1], [-1...10_000], [0...10_000, 0...10, 0...8], [-1...11, -1...9], [],
                        [0...10_000], [0...10_000], [-1...1, -1...1], [0...1], [0...1], [0...3], [0...1], []])
        XCTAssertEqual(PlaygroundCore.gestureActionIDs,
                       ["edit.add", "edit.select", "edit.grab", "edit.move", "edit.release", "edit.pin", "edit.delete"])
        XCTAssertTrue(PlaygroundCore.gestureActionIDs.isSubset(of: Set(PlaygroundCore.actionIDs)))
        XCTAssertEqual(PlaygroundCore.migrations.currentVersion, 5)
        XCTAssertEqual(PlaygroundCore.snapshotSchema, 5)
        XCTAssertEqual(PlaygroundRule.noTutorial, "a11.no-tutorial")
        XCTAssertEqual(PlaygroundCore.qualityTiers, 3)
        XCTAssertEqual(PlaygroundCore.stepDuration, 1.0 / 120, accuracy: 1e-15)
        XCTAssertEqual(ExperienceEngine<PlaygroundCore>.stepDuration, 1.0 / 120, accuracy: 1e-15)
        XCTAssertEqual(PlaygroundRule.invalidChoice, "a11.invalid-choice")
        XCTAssertEqual(PlaygroundRule.notPaused, "a11.not-paused")
        XCTAssertEqual(PlaygroundRule.bodyCap, "a11.body-cap")
        XCTAssertEqual([PlaygroundRule.noRoom, PlaygroundRule.unknownBody, PlaygroundRule.notGrabbable,
                        PlaygroundRule.noGrab, PlaygroundRule.staticBody, PlaygroundRule.noSelection],
                       ["a11.no-room", "a11.unknown-body", "a11.not-grabbable", "a11.no-grab", "a11.static-body",
                        "a11.no-selection"])
        XCTAssertEqual(EditRefusal.bodyCap.code, PlaygroundRule.bodyCap)
    }

    func testConformancePassesOverFourSeeds() async {
        let plan = ConformancePlan(
            seeds: [1, 7, 42, 0xFFFF_FFFF_FFFF_FFFF], stepsPerSegment: 30,
            actions: [ScriptedAction("world.drop", [0]), ScriptedAction("world.timeScale", [3]),
                      ScriptedAction("world.pause", [1]), ScriptedAction("world.step"),
                      ScriptedAction("world.pause", [0]), ScriptedAction("world.drop", [1]),
                      ScriptedAction("world.timeScale", [0]), ScriptedAction("world.gravity", [1]),
                      ScriptedAction("world.drag", [2]), ScriptedAction("world.stiffness", [3]),
                      ScriptedAction("world.reset"), ScriptedAction("world.drop", [0]),
                      ScriptedAction("edit.select", [9]), ScriptedAction("edit.nudge", [1, 0.5]),
                      ScriptedAction("edit.pin", [8]), ScriptedAction("edit.grab", [9, 8, 1.5]),
                      ScriptedAction("edit.move", [6, 4]), ScriptedAction("edit.release"),
                      ScriptedAction("overlay.velocity", [1]), ScriptedAction("overlay.forces", [1]),
                      ScriptedAction("edit.pin", [8]), ScriptedAction("edit.delete", [7]),
                      ScriptedAction("tutorial.start", [0]), ScriptedAction("experiment.preset", [1]),
                      ScriptedAction("world.reset"), ScriptedAction("tutorial.stop"),
                      ScriptedAction("experiment.preset", [0])],
            rejected: [ScriptedAction("world.pause", [0.5]), ScriptedAction("world.pause", [2]),
                       ScriptedAction("world.pause", [.nan]), ScriptedAction("world.pause", []),
                       ScriptedAction("world.step"), ScriptedAction("world.step", [1]),
                       ScriptedAction("world.timeScale", [2.5]), ScriptedAction("world.timeScale", [4]),
                       ScriptedAction("world.timeScale", [.infinity]), ScriptedAction("world.reset", [0]),
                       ScriptedAction("world.drop", [0.5]), ScriptedAction("world.drop", [-1]),
                       ScriptedAction("world.gravity", [0.5]), ScriptedAction("world.gravity", [3]),
                       ScriptedAction("world.drag", [1.5]), ScriptedAction("world.drag", [.nan]),
                       ScriptedAction("world.stiffness", [2.5]), ScriptedAction("world.stiffness", [4]),
                       ScriptedAction("world.stiffness", []), ScriptedAction("bogus"),
                       ScriptedAction("edit.add", [0.2, 0.2, 0]), ScriptedAction("edit.add", [5, 4, 0.5]),
                       ScriptedAction("edit.add", [11, 4, 0]), ScriptedAction("edit.select", [99]),
                       ScriptedAction("edit.select", [2.5]), ScriptedAction("edit.grab", [0, 2, 2.5]),
                       ScriptedAction("edit.move", [5, 4]), ScriptedAction("edit.release"),
                       ScriptedAction("edit.pin", [0]), ScriptedAction("edit.delete", [99]),
                       ScriptedAction("edit.nudge", [1, 0]), ScriptedAction("overlay.forces", [0.5]),
                       ScriptedAction("overlay.velocity", [2]), ScriptedAction("experiment.preset", [1.5]),
                       ScriptedAction("experiment.preset", [4]), ScriptedAction("tutorial.start", [0.5]),
                       ScriptedAction("tutorial.start", [2]), ScriptedAction("tutorial.stop"),
                       ScriptedAction("tutorial.stop", [0])])
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
        XCTAssertEqual(core.world.schema, 4)
        XCTAssertFalse(core.world.bodies.contains(where: \.asleep), "every body starts awake")
        XCTAssertFalse(core.world.bodies.contains(where: \.pinned), "no pins")
        XCTAssertNil(core.world.selectedId)
        XCTAssertNil(core.world.grab)
        XCTAssertFalse(core.world.showVelocity || core.world.showForces, "overlays off")
        XCTAssertEqual(core.forces, ForceMeasurement(), "nothing measured before a tick")
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
        XCTAssertEqual(try XCTUnwrap(engine.core).world, PlaygroundCore(seed: 7).world,
                       "world.reset: the starting scene (the generator keeps going)")
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
        var pinned = base
        pinned.world.bodies[8].pinned = true
        var selected = base
        selected.world.selectedId = 8
        var grabbed = base
        grabbed.world.grab = Grab(bodyId: 8, localAnchor: .zero, target: Vec2(6, 3))
        var arrows = base
        arrows.world.showVelocity = true
        var forced = base
        forced.world.showForces = true
        let states = [base, moved, spun, paused, scaled, remainder, ticked, advanced, rest, anchored, moon, draggy,
                      stiff, cached, pinned, selected, grabbed, arrows, forced]
        let digests = try states.map {
            try digest(PlaygroundCore.restore(payload: PlaygroundCore.encode($0), seed: 7))
        }
        XCTAssertEqual(Set(digests).count, states.count,
                       "positions, spins, the flags, the tick, the generator, springs, levels, cache, pins, selection, "
                       + "grab and overlays are digested")
    }

    func testTheSnapshotRestoresIdenticallyInAnotherEngine() async throws {
        var engine = try await makeEngine()
        for entry in PlaygroundCore.replayEntries(upTo: 300) {
            try engine.run(steps: entry.steps)
            if let action = entry.action { _ = engine.handle(control: action.control, values: action.values) }
        }
        XCTAssertEqual(engine.handle(control: "edit.pin", values: [8]), .accepted)
        XCTAssertEqual(engine.handle(control: "edit.select", values: [9]), .accepted)
        XCTAssertEqual(engine.handle(control: "edit.grab", values: [7, 7.5, 6.2]), .accepted)
        XCTAssertEqual(engine.handle(control: "overlay.forces", values: [1]), .accepted)
        try engine.run(steps: 3)
        let snapshot = try engine.snapshot()
        XCTAssertEqual(snapshot.schemaVersion, 5)
        let saved = try XCTUnwrap(engine.core)
        var other = try await makeEngine(seed: 3)
        try other.restore(ExperienceSnapshot(data: snapshot.encoded()))
        let restored = try XCTUnwrap(other.core)
        XCTAssertEqual(restored.state, saved.state)
        XCTAssertTrue(restored.world.bodies[8].pinned && restored.world.selectedId == 9)
        XCTAssertEqual(restored.world.grab?.bodyId, 7)
        XCTAssertTrue(restored.world.showForces)
        XCTAssertEqual(restored.forces, ForceMeasurement(), "the measurement is not saved")
        XCTAssertFalse(saved.forces.springForces.isEmpty, "the saved core had measured its springs")
        XCTAssertEqual(restored, saved, "the measurement is not part of the equality")
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

        func envelope(_ payload: Data, schema: Int = PlaygroundCore.snapshotSchema) throws -> ExperienceSnapshot {
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
            ("no overlay key", { $0["showVelocity"] = nil }),
            ("selection of a missing body", { $0["selectedId"] = 99 }),
            ("grab of the static ledge", { $0["grab"] = ["bodyId": 0, "localAnchor": ["x": 0.0, "y": 0.0],
                                                         "target": ["x": 2.0, "y": 2.5]] }),
            ("pinned static ledge", { world in
                var bodies = world["bodies"] as? [[String: Any]] ?? []
                bodies[0]["pinned"] = true
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
        // Newer: schema 6 is not known to this build.
        XCTAssertThrowsError(try engine.restore(envelope(Data(saved.payload.utf8), schema: 6)))
        // A schema-5 payload sent as schema 1, 2, 3 or 4 runs the step it names, which refuses it (its world is at
        // world schema 4, not the schema the step reads).
        for older in 1...4 {
            XCTAssertThrowsError(try engine.restore(envelope(Data(saved.payload.utf8), schema: older)), "\(older)")
        }
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

        // `world.reset` from a paused, slowed, fuller world: the starting scene at 1×, running; the generator keeps
        // the drop's draws (feature 085).
        var core = PlaygroundCore(seed: 7)
        _ = core.apply(action("world.drop", [0]))
        _ = core.apply(action("world.timeScale", [0]))
        _ = core.apply(action("world.pause", [1]))
        let drawn = core.generator
        XCTAssertEqual(core.apply(action("world.reset")), .accepted)
        XCTAssertEqual(core.world, PlaygroundCore(seed: 7).world)
        XCTAssertEqual(core.generator, drawn)
        XCTAssertEqual(core.origin, .freePlay)
        XCTAssertEqual(core.world.timeScaleIndex, 2)
        XCTAssertFalse(core.world.paused)

        // From changed levels and a filled cache: the default levels, the starting springs and an empty cache.
        for step in 0..<240 { core.update(step: step) }
        XCTAssertFalse(core.world.contactCache.isEmpty, "landed bodies leave impulses in the cache")
        XCTAssertEqual(core.apply(action("world.gravity", [0])), .accepted)
        XCTAssertEqual(core.apply(action("world.drag", [2])), .accepted)
        XCTAssertEqual(core.apply(action("world.stiffness", [3])), .accepted)
        XCTAssertEqual(core.apply(action("world.reset")), .accepted)
        XCTAssertEqual(core.world, PlaygroundCore(seed: 7).world)
        XCTAssertEqual(core.world.gravityLevel, ForceLevels.defaultGravityLevel)
        XCTAssertEqual(core.world.dragLevel, ForceLevels.defaultDragLevel)
        XCTAssertEqual(core.world.stiffnessLevel, ForceLevels.defaultStiffnessLevel)
        XCTAssertEqual(core.world.settings, WorldSettings())
        XCTAssertEqual(core.world.springs.count, 2)
        XCTAssertEqual(core.world.contactCache, [])

        // Feature 084: from pins, a selection, a grab and overlays on: none of them, and no measurement.
        for step in 0..<10 { core.update(step: step) }
        for (control, values) in [("edit.pin", [8.0]), ("edit.select", [9.0]), ("edit.grab", [7.0, 7.5, 6.2]),
                                  ("overlay.velocity", [1.0]), ("overlay.forces", [1.0])] {
            XCTAssertEqual(core.apply(action(control, values)), .accepted, control)
        }
        XCTAssertFalse(core.forces.springForces.isEmpty)
        XCTAssertEqual(core.apply(action("world.reset")), .accepted)
        XCTAssertEqual(core.world, PlaygroundCore(seed: 7).world)
        XCTAssertFalse(core.world.bodies.contains(where: \.pinned))
        XCTAssertNil(core.world.selectedId)
        XCTAssertNil(core.world.grab)
        XCTAssertFalse(core.world.showVelocity || core.world.showForces)
        XCTAssertEqual(core.forces, ForceMeasurement())
        _ = core.apply(action("edit.pin", [8]))
        core.reset()
        XCTAssertEqual(core, PlaygroundCore(seed: 7), "reset() too")
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
        for key in ["springs", "nextSpringId", "gravityLevel", "dragLevel", "stiffnessLevel", "contactCache",
                    "selectedId", "grab", "showVelocity", "showForces"] {
            XCTAssertNil(storedWorld[key], "a Phase 01 world has no \(key)")
        }
        for body in try XCTUnwrap(storedWorld["bodies"] as? [[String: Any]]) {
            XCTAssertNil(body["pinned"], "a Phase 01 body has no pinned key")
            XCTAssertNil(body["asleep"], "a Phase 01 body has no asleep key")
            XCTAssertNil(body["restTicks"], "a Phase 01 body has no restTicks key")
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
        XCTAssertEqual(world.schema, 4)
        XCTAssertEqual(world.validate(), [])
        XCTAssertFalse(world.bodies.contains(where: \.asleep), "every body awake")
        XCTAssertFalse(world.bodies.contains(where: \.pinned))
        XCTAssertNil(world.selectedId)
        XCTAssertNil(world.grab)
        XCTAssertFalse(world.showVelocity || world.showForces)
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
        XCTAssertTrue(continued.forces.springForces.values.allSatisfy { $0 == .zero },
                      "no springs, so no spring force is measured")
        XCTAssertEqual(continued, try XCTUnwrap(other.core), "the migrated world plays on identically")

        let two = try XCTUnwrap(PlaygroundCore.schemaTwoExample())
        let three = try XCTUnwrap(PlaygroundCore.schemaThreeExample())
        let four = try XCTUnwrap(PlaygroundCore.schemaFourExample())
        let problems = await SnapshotMigrationCheck.problems(for: PlaygroundCore.self, id: playgroundID,
                                                              examples: [example, two, three, four])
        XCTAssertEqual(problems, [])
    }

    /// T-A11-204, T-A11-303: a schema-1 payload handed to the restore without the migration is refused (it lacks the
    /// schema-2 and schema-3 keys), the step 1 → 2 refuses a payload whose world is not schema 1 or does not decode and
    /// writes a Phase 02 payload (bodies without `pinned`).
    func testASchemaOnePayloadNeedsTheMigration() throws {
        let example = try XCTUnwrap(PlaygroundCore.schemaOneExample())
        let snapshot = try ExperienceSnapshot(data: example.snapshot)
        XCTAssertThrowsError(try PlaygroundCore.restore(payload: Data(snapshot.payload.utf8), seed: 7))

        let current = try XCTUnwrap(try JSONSerialization.jsonObject(with: PlaygroundCore(seed: 7).snapshotPayload())
                                    as? [String: Any])
        XCTAssertThrowsError(try PlaygroundCore.migrations.migrate(current, from: 1)) { error in
            XCTAssertEqual(error as? PlaygroundRestoreError, .notSchemaOne(4))
        }
        XCTAssertThrowsError(try PlaygroundCore.migrations.migrate(current, from: 2)) { error in
            XCTAssertEqual(error as? PlaygroundRestoreError, .notSchemaTwo(4))
        }
        XCTAssertThrowsError(try PlaygroundCore.migrations.migrate(current, from: 4)) { error in
            XCTAssertEqual(error as? PlaygroundRestoreError, .notSchemaFour(4))
        }
        XCTAssertThrowsError(try PlaygroundCore.migrations.migrate(["world": 1], from: 1))
        let object = try XCTUnwrap(try JSONSerialization.jsonObject(with: Data(snapshot.payload.utf8))
                                   as? [String: Any])
        let upgraded = try PlaygroundCore.migrations.migrate(object, from: 1)
        let restored = try PlaygroundCore.restore(
            payload: JSONSerialization.data(withJSONObject: upgraded, options: [.sortedKeys]), seed: 7)
        XCTAssertEqual(restored.world,
                       PhysicsWorld.migrated(fromSchemaOne: PlaygroundCore.schemaOneExampleState().world))
        XCTAssertEqual(try PlaygroundCore.migrations.migrate(current, from: 5) as NSDictionary,
                       current as NSDictionary, "a schema-5 payload needs no step")
        // The step 1 → 2 alone writes a faithful Phase 02 payload.
        let phaseTwo = try PlaygroundCore.migratedToSchemaTwo(object)
        let phaseTwoWorld = try XCTUnwrap(phaseTwo["world"] as? [String: Any])
        XCTAssertEqual(phaseTwoWorld["schema"] as? Int, 2)
        XCTAssertNil(phaseTwoWorld["showForces"])
        for body in try XCTUnwrap(phaseTwoWorld["bodies"] as? [[String: Any]]) {
            XCTAssertNil(body["pinned"])
            XCTAssertNil(body["asleep"])
        }
        XCTAssertThrowsError(try PlaygroundCore.restore(
            payload: JSONSerialization.data(withJSONObject: phaseTwo, options: [.sortedKeys]), seed: 7),
                             "a schema-2 payload needs the step 2 → 3")
    }

    /// T-A11-303 (SC-A11-305): the stored Phase 02 payload restores in a new engine through the step 2 → 3 — every
    /// schema-2 field and the generator kept; no pins, no selection, no grab, overlays off — with the digest the
    /// example names; it then plays on identically in two engines, and the registry's check accepts both examples.
    func testTheSchemaTwoExampleRestoresThroughTheMigration() async throws {
        let example = try XCTUnwrap(PlaygroundCore.schemaTwoExample())
        XCTAssertEqual(example.version, 2)
        let snapshot = try ExperienceSnapshot(data: example.snapshot)
        XCTAssertEqual(snapshot.schemaVersion, 2)
        XCTAssertEqual(snapshot.stepIndex, 0)
        let payload = try XCTUnwrap(try JSONSerialization.jsonObject(with: Data(snapshot.payload.utf8))
                                    as? [String: Any])
        let storedWorld = try XCTUnwrap(payload["world"] as? [String: Any])
        XCTAssertEqual(storedWorld["schema"] as? Int, 2)
        for key in ["selectedId", "grab", "showVelocity", "showForces"] {
            XCTAssertNil(storedWorld[key], "a Phase 02 world has no \(key)")
        }
        for body in try XCTUnwrap(storedWorld["bodies"] as? [[String: Any]]) { XCTAssertNil(body["pinned"]) }
        let phaseTwo = try JSONDecoder().decode(PlaygroundStateSchemaTwo.self, from: Data(snapshot.payload.utf8))
        XCTAssertEqual(phaseTwo, PlaygroundCore.schemaTwoExampleState())
        XCTAssertEqual(phaseTwo.world.bodies.count, 12, "the ten-body scene and two drops")
        XCTAssertEqual(phaseTwo.world.springs.count, 2)
        XCTAssertEqual(phaseTwo.world.stiffnessLevel, 2)
        XCTAssertEqual(phaseTwo.world.gravityLevel, 1)
        XCTAssertEqual(phaseTwo.world.dragLevel, 2)

        var engine = ExperienceEngine<PlaygroundCore>(id: playgroundID)
        try await engine.prepare(seed: 3)
        try engine.activate()
        try engine.restore(snapshot)
        XCTAssertEqual(try engine.digest().hex, example.expectedDigest)
        let core = try XCTUnwrap(engine.core)
        XCTAssertEqual(core.world, PhysicsWorld.migrated(fromSchemaTwo: phaseTwo.world))
        XCTAssertEqual(core.world.schema, 4)
        XCTAssertEqual(core.world.validate(), [])
        XCTAssertFalse(core.world.bodies.contains(where: \.pinned))
        XCTAssertNil(core.world.selectedId)
        XCTAssertNil(core.world.grab)
        XCTAssertFalse(core.world.showVelocity || core.world.showForces)
        XCTAssertEqual(core.state.random, phaseTwo.random)
        XCTAssertEqual(core.preparationSeed, snapshot.seed)
        var expected = PlaygroundCore(seed: 7)
        for item in PlaygroundCore.schemaTwoExampleActions {
            _ = expected.apply(action(item.control, item.values))
        }
        XCTAssertEqual(core.world, expected.world, "the same world the A11-P02 actions give")
        XCTAssertEqual(core.generator, expected.generator)
        XCTAssertEqual(core.origin, .freePlay)
        XCTAssertEqual(core.startingWorld, core.world, "nothing grabbed or selected, so the world itself")

        var other = ExperienceEngine<PlaygroundCore>(id: playgroundID)
        try await other.prepare(seed: 11)
        try other.activate()
        try other.restore(ExperienceSnapshot(data: example.snapshot))
        XCTAssertEqual(engine.handle(control: "world.pause", values: [0]), .accepted)
        XCTAssertEqual(other.handle(control: "world.pause", values: [0]), .accepted)
        try engine.run(steps: 120)
        try other.run(steps: 120)
        XCTAssertEqual(try XCTUnwrap(engine.core).world.tick, 60)
        XCTAssertEqual(try XCTUnwrap(engine.core), try XCTUnwrap(other.core), "the migrated world plays on identically")

        let one = try XCTUnwrap(PlaygroundCore.schemaOneExample())
        let three = try XCTUnwrap(PlaygroundCore.schemaThreeExample())
        let four = try XCTUnwrap(PlaygroundCore.schemaFourExample())
        let problems = await SnapshotMigrationCheck.problems(for: PlaygroundCore.self, id: playgroundID,
                                                              examples: [one, example, three, four])
        XCTAssertEqual(problems, [])
    }

    /// T-A11-303 (FR-A11-301; contract contracts/actions.md): each edit and overlay action gives exactly the world the
    /// core's `WorldEditing` function gives (the add drawing from the generator as `WorldEditing.add` does).
    func testTheEditActionsApplyThroughWorldEditing() throws {
        var core = PlaygroundCore(seed: 7)
        var world = core.world
        var random = core.generator
        XCTAssertNil(WorldEditing.add(&world, kind: .box, at: Vec2(4.5, 1.5), random: &random, catalog: .bundled))
        XCTAssertEqual(core.apply(action("edit.add", [4.5, 1.5, 1])), .accepted)
        XCTAssertEqual(core.world, world)
        XCTAssertEqual(core.generator, random, "the add draws from the generator")
        let added = try XCTUnwrap(core.world.bodies.last)
        XCTAssertEqual(added.id, 10)
        XCTAssertEqual(added.position, Vec2(4.5, 1.5))
        guard case .box = added.shape else { return XCTFail("a box") }

        let steps: [(String, [Double], (inout PhysicsWorld) -> EditRefusal?)] = [
            ("edit.select", [9], { WorldEditing.select(&$0, id: 9) }),
            ("edit.nudge", [1, -0.5], { WorldEditing.nudge(&$0, dx: 1, dy: -0.5) }),
            ("edit.select", [-1], { WorldEditing.select(&$0, id: -1) }),
            ("edit.grab", [8, 7.1, 1.5], { WorldEditing.grab(&$0, id: 8, at: Vec2(7.1, 1.5)) }),
            ("edit.move", [11, -1], { WorldEditing.move(&$0, to: Vec2(11, -1)) }),
            ("edit.release", [], { WorldEditing.release(&$0) }),
            ("edit.pin", [7], { WorldEditing.togglePin(&$0, id: 7) }),
            ("edit.pin", [7], { WorldEditing.togglePin(&$0, id: 7) }),
            ("edit.delete", [9], { WorldEditing.delete(&$0, id: 9) }),
        ]
        for (control, values, edit) in steps {
            var expected = core.world
            XCTAssertNil(edit(&expected), control)
            XCTAssertEqual(core.apply(action(control, values)), .accepted, control)
            XCTAssertEqual(core.world, expected, control)
            if control == "edit.move" {
                XCTAssertEqual(core.world.grab?.target, Vec2(10, 0), "a target outside the stage is clamped")
            }
        }
        XCTAssertFalse(core.world.springs.contains { $0.a.bodyId == 9 || $0.b.bodyId == 9 }, "its spring went too")
        XCTAssertEqual(core.apply(action("overlay.velocity", [1])), .accepted)
        XCTAssertTrue(core.world.showVelocity)
        XCTAssertEqual(core.apply(action("overlay.forces", [1])), .accepted)
        XCTAssertTrue(core.world.showForces)
        XCTAssertEqual(core.apply(action("overlay.velocity", [0])), .accepted)
        XCTAssertFalse(core.world.showVelocity)
        XCTAssertEqual(core.world.validate(), [])
        XCTAssertEqual(core.generator, random, "no edit but the add draws")
    }

    /// T-A11-303 (contract contracts/actions.md): every refusal of the edit and overlay actions with its code, through
    /// the engine (ranges) and the core (rules), leaves the world and the generator as they were.
    func testEditRefusalsKeepTheStateWithTheirCodes() async throws {
        var engine = try await makeEngine()
        let before = try engine.digest()
        func rule(_ code: String) -> ActionResult { .rejected(.rule(code: code)) }
        XCTAssertEqual(engine.handle(control: "edit.add", values: [0.2, 0.2, 0]), rule(PlaygroundRule.noRoom))
        XCTAssertEqual(engine.handle(control: "edit.add", values: [5, 4, 0.5]), rule(PlaygroundRule.invalidChoice))
        XCTAssertEqual(engine.handle(control: "edit.add", values: [10.5, 4, 0]), .rejected(.outOfRange(index: 0)))
        XCTAssertEqual(engine.handle(control: "edit.add", values: [5, 4]),
                       .rejected(.wrongValueCount(expected: 3, found: 2)))
        XCTAssertEqual(engine.handle(control: "edit.select", values: [42]), rule(PlaygroundRule.unknownBody))
        XCTAssertEqual(engine.handle(control: "edit.select", values: [3.5]), rule(PlaygroundRule.invalidChoice))
        XCTAssertEqual(engine.handle(control: "edit.select", values: [-2]), .rejected(.outOfRange(index: 0)))
        XCTAssertEqual(engine.handle(control: "edit.grab", values: [0, 2, 2.5]), rule(PlaygroundRule.notGrabbable))
        XCTAssertEqual(engine.handle(control: "edit.grab", values: [42, 2, 2.5]), rule(PlaygroundRule.unknownBody))
        XCTAssertEqual(engine.handle(control: "edit.grab", values: [8.5, 7, 1.5]), rule(PlaygroundRule.invalidChoice))
        XCTAssertEqual(engine.handle(control: "edit.move", values: [5, 4]), rule(PlaygroundRule.noGrab))
        XCTAssertEqual(engine.handle(control: "edit.move", values: [12, 4]), .rejected(.outOfRange(index: 0)))
        XCTAssertEqual(engine.handle(control: "edit.release"), rule(PlaygroundRule.noGrab))
        XCTAssertEqual(engine.handle(control: "edit.pin", values: [0]), rule(PlaygroundRule.staticBody))
        XCTAssertEqual(engine.handle(control: "edit.pin", values: [42]), rule(PlaygroundRule.unknownBody))
        XCTAssertEqual(engine.handle(control: "edit.pin", values: [1.25]), rule(PlaygroundRule.invalidChoice))
        XCTAssertEqual(engine.handle(control: "edit.delete", values: [42]), rule(PlaygroundRule.unknownBody))
        XCTAssertEqual(engine.handle(control: "edit.delete", values: [0.5]), rule(PlaygroundRule.invalidChoice))
        XCTAssertEqual(engine.handle(control: "edit.nudge", values: [1, 0]), rule(PlaygroundRule.noSelection))
        XCTAssertEqual(engine.handle(control: "edit.nudge", values: [1.5, 0]), .rejected(.outOfRange(index: 0)))
        XCTAssertEqual(engine.handle(control: "overlay.velocity", values: [0.5]), rule(PlaygroundRule.invalidChoice))
        XCTAssertEqual(engine.handle(control: "overlay.forces", values: [2]), .rejected(.outOfRange(index: 0)))
        XCTAssertEqual(try engine.digest(), before, "every refusal leaves the state as it was")

        // A static selection or a pinned one cannot be nudged or grabbed; at the cap an add is refused.
        XCTAssertEqual(engine.handle(control: "edit.select", values: [0]), .accepted)
        XCTAssertEqual(engine.handle(control: "edit.nudge", values: [1, 0]), rule(PlaygroundRule.notGrabbable))
        XCTAssertEqual(engine.handle(control: "edit.pin", values: [8]), .accepted)
        XCTAssertEqual(engine.handle(control: "edit.grab", values: [8, 7, 1.5]), rule(PlaygroundRule.notGrabbable))
        var core = PlaygroundCore(seed: 7)
        while core.world.bodies.count < PhysicsWorld.maxBodies {
            XCTAssertEqual(core.apply(action("world.drop", [0])), .accepted)
        }
        let full = core
        XCTAssertEqual(core.apply(action("edit.add", [5, 4, 0])), rule(PlaygroundRule.bodyCap))
        XCTAssertEqual(core, full, "a refused add draws nothing")
    }

    /// T-A11-303 (FR-A11-310 inputs; research D3): host steps and single steps keep the measured spring forces of the
    /// last tick; they are not digested, and a core without them is equal to one with them.
    func testHostStepsKeepTheMeasuredForcesOutsideTheDigest() throws {
        var core = PlaygroundCore(seed: 7)
        let start = try digest(core)
        var bare = core.world
        for step in 0..<30 {
            core.update(step: step)
            XCTAssertGreaterThan(WorldSimulation.advanceHostStep(&bare, catalog: .bundled), 0)
        }
        XCTAssertEqual(core.world, bare, "the measured advance gives the same world")
        XCTAssertNotEqual(try digest(core), start)
        XCTAssertTrue(core.forces.isCurrent(for: core.world))
        XCTAssertGreaterThan(core.forces.springForce(on: 7).y, 0, "the hanging box's spring pulls it up")
        let restored = try PlaygroundCore.restore(payload: core.snapshotPayload(), seed: 7)
        XCTAssertEqual(restored.forces, ForceMeasurement())
        XCTAssertEqual(restored, core)
        XCTAssertEqual(try digest(restored), try digest(core), "the measurement is not digested")

        XCTAssertEqual(core.apply(action("world.pause", [1])), .accepted)
        let measured = core.forces
        core.update(step: 30)
        XCTAssertEqual(core.forces, measured, "a paused host step runs no tick and keeps the measurement")
        XCTAssertEqual(core.apply(action("world.step")), .accepted)
        XCTAssertEqual(core.forces.tick, core.world.tick, "the single step measures its tick")
    }

    /// T-A11-303 (SC-A11-305): a recorded editing session (actions at their steps) replays to the identical world.
    func testEditingSessionsReplayIdentically() throws {
        let entries = [
            ScenarioStep(steps: 0, action: ScriptedAction("edit.add", [4.5, 1.5, 0])),
            ScenarioStep(steps: 20, action: ScriptedAction("edit.grab", [8, 7, 1.5])),
            ScenarioStep(steps: 10, action: ScriptedAction("edit.move", [5, 4])),
            ScenarioStep(steps: 40, action: ScriptedAction("edit.release")),
            ScenarioStep(steps: 5, action: ScriptedAction("edit.pin", [10])),
            ScenarioStep(steps: 5, action: ScriptedAction("edit.select", [9])),
            ScenarioStep(steps: 0, action: ScriptedAction("edit.nudge", [-1, 1])),
            ScenarioStep(steps: 30, action: ScriptedAction("edit.delete", [7])),
            ScenarioStep(steps: 60),
        ]
        let a = PlaygroundCore.played(seed: 7, entries: entries)
        let b = PlaygroundCore.played(seed: 7, entries: entries)
        XCTAssertEqual(a, b)
        XCTAssertEqual(try digest(a), try digest(b))
        XCTAssertEqual(a.world.bodies.count, 10, "one added, one deleted")
        XCTAssertTrue(try XCTUnwrap(a.world.bodies.first { $0.id == 10 }).pinned)
        XCTAssertEqual(a.world.selectedId, 9)
        XCTAssertNil(a.world.grab)
        XCTAssertEqual(a.world.springs.count, 1, "the hanging box's spring went with it")
        XCTAssertEqual(a.world.validate(), [])
    }

    func testTheOutcomeFollowsThePause() {
        var core = PlaygroundCore(seed: 7)
        XCTAssertEqual(core.outcome?.code, "world-running")
        _ = core.apply(action("world.pause", [1]))
        XCTAssertEqual(core.outcome?.code, "world-paused")
        _ = core.apply(action("world.reset"))
        XCTAssertEqual(core.outcome?.code, "world-running")
    }

    // MARK: Feature 085 (A11-P04)

    /// The preset `id` as `Presets.make` builds it from `generator`, with the generator after it.
    private func preset(_ id: PresetID, from generator: SeededRandom) -> (world: PhysicsWorld, random: SeededRandom) {
        var random = generator
        let world = Presets.make(id, random: &random, catalog: PlaygroundCore.catalog)
        return (world, random)
    }

    /// T-A11-403 (FR-A11-401, FR-A11-402; SC-A11-401): each preset opens as the world and the starting world with its
    /// origin (only free play draws from the generator), and reset after edits and time controls returns to it exactly.
    func testPresetsOpenAsTheStartingWorldAndResetReturnsToThem() {
        for id in PresetID.allCases {
            var core = PlaygroundCore(seed: 7)
            for step in 0..<20 { core.update(step: step) }
            let expected = preset(id, from: core.generator)
            XCTAssertEqual(core.apply(action("experiment.preset", [Double(id.rawValue)])), .accepted, id.name)
            XCTAssertEqual(core.world, expected.world, id.name)
            XCTAssertEqual(core.startingWorld, expected.world, id.name)
            XCTAssertEqual(core.origin, .preset(id.rawValue), id.name)
            XCTAssertEqual(core.generator, expected.random, id.name)
            XCTAssertEqual(core.generator == PlaygroundCore(seed: 7).generator, id != .freePlay,
                           "\(id.name): only free play draws")
            XCTAssertEqual(core.forces, ForceMeasurement())
            XCTAssertEqual(core.world.validate(), [], id.name)

            for step in 0..<50 { core.update(step: step) }
            let dynamic = core.world.bodies.first { !$0.isFixed }?.id ?? 0
            for (control, values) in [("world.drop", [0.0]), ("edit.select", [Double(dynamic)]),
                                      ("edit.nudge", [1.0, 0.5]), ("world.timeScale", [0.0]), ("world.pause", [1.0]),
                                      ("world.step", []), ("world.gravity", [1.0]), ("world.stiffness", [0.0]),
                                      ("edit.grab", [Double(dynamic), 5.0, 4.0])] {
                XCTAssertEqual(core.apply(action(control, values)), .accepted, "\(id.name) \(control)")
            }
            XCTAssertEqual(core.apply(action("world.reset")), .accepted)
            XCTAssertEqual(core.world, expected.world, "\(id.name): reset returns to the preset exactly")
            XCTAssertFalse(core.world.paused)
            XCTAssertEqual(core.world.timeScaleIndex, PhysicsWorld.normalTimeScaleIndex)
            XCTAssertNil(core.world.grab)
            XCTAssertNil(core.world.selectedId)
            XCTAssertEqual(core.origin, .preset(id.rawValue))
        }
        var core = PlaygroundCore(seed: 7)
        let before = core
        XCTAssertEqual(core.apply(action("experiment.preset", [1.5])),
                       .rejected(.rule(code: PlaygroundRule.invalidChoice)))
        XCTAssertEqual(core.apply(action("experiment.preset", [4])),
                       .rejected(.rule(code: PlaygroundRule.invalidChoice)))
        XCTAssertEqual(core, before)
    }

    /// T-A11-403 (FR-A11-410; SC-A11-403): `tutorial.start` and `tutorial.stop`, their refusals, and a stop that
    /// leaves the world unchanged.
    func testTutorialStartAndStop() {
        var core = PlaygroundCore(seed: 7)
        for step in 0..<12 { core.update(step: step) }
        let before = core
        XCTAssertEqual(core.apply(action("tutorial.stop")), .rejected(.rule(code: PlaygroundRule.noTutorial)))
        XCTAssertEqual(core.apply(action("tutorial.start", [0.5])),
                       .rejected(.rule(code: PlaygroundRule.invalidChoice)))
        XCTAssertEqual(core.apply(action("tutorial.start", [2])),
                       .rejected(.rule(code: PlaygroundRule.invalidChoice)))
        XCTAssertEqual(core, before)
        XCTAssertEqual(core.apply(action("tutorial.start", [0])), .accepted)
        XCTAssertEqual(core.tutorial, TutorialProgress(tutorial: 0, step: 0, startTick: 12))
        XCTAssertEqual(core.apply(action("tutorial.start", [1])), .accepted)
        XCTAssertEqual(core.tutorial, TutorialProgress(tutorial: 1, step: 0, startTick: 12), "a start replaces")
        XCTAssertEqual(core.apply(action("tutorial.stop")), .accepted)
        XCTAssertNil(core.tutorial)
        XCTAssertEqual(core, before, "stopping leaves the world unchanged")
    }

    /// T-A11-403 (FR-A11-410; SC-A11-403; story 3 scenario 1): "Controlling time" completes through its actions, step
    /// by step in order, and ends.
    func testControllingTimeCompletesThroughItsActions() {
        var core = PlaygroundCore(seed: 7)
        XCTAssertEqual(core.apply(action("tutorial.start", [0])), .accepted)
        XCTAssertEqual(Tutorials.text(core.tutorial), "Pause the world.")
        for step in 0..<10 { core.update(step: step) }
        XCTAssertEqual(core.tutorial?.step, 0, "running: the first step waits")
        XCTAssertEqual(core.apply(action("world.timeScale", [1])), .accepted)
        XCTAssertEqual(core.tutorial?.step, 0, "half speed before the pause does not skip a step")
        XCTAssertEqual(core.apply(action("world.timeScale", [2])), .accepted)
        XCTAssertEqual(core.apply(action("world.pause", [1])), .accepted)
        XCTAssertEqual(core.tutorial, TutorialProgress(tutorial: 0, step: 1, startTick: 10))
        for step in 0..<20 { core.update(step: step) }
        XCTAssertEqual(core.tutorial?.step, 1, "paused host steps change nothing")
        XCTAssertEqual(core.apply(action("world.step")), .accepted)
        XCTAssertEqual(core.tutorial, TutorialProgress(tutorial: 0, step: 2, startTick: 11))
        XCTAssertEqual(core.apply(action("world.timeScale", [1])), .accepted)
        XCTAssertEqual(core.tutorial?.step, 3)
        XCTAssertEqual(Tutorials.text(core.tutorial), "Press Reset.")
        XCTAssertEqual(core.apply(action("world.reset")), .accepted)
        XCTAssertNil(core.tutorial, "the last step completes and the tutorial ends")
        XCTAssertEqual(core.world, PlaygroundCore(seed: 7).world)
    }

    /// T-A11-403 (FR-A11-410; SC-A11-403; story 3 scenario 2; edge case "Opening a preset or a slot during a
    /// tutorial"): "Springs and energy" stays on its step when another preset opens, completes when the spring chain
    /// opens, the force arrows show and 360 running ticks pass, and ends.
    func testSpringsAndEnergyCompletesAndStaysOnItsStep() {
        var core = PlaygroundCore(seed: 7)
        XCTAssertEqual(core.apply(action("tutorial.start", [1])), .accepted)
        XCTAssertEqual(core.apply(action("experiment.preset", [3])), .accepted)
        XCTAssertEqual(core.tutorial?.step, 0, "the stack is not the spring chain")
        XCTAssertEqual(core.apply(action("experiment.preset", [2])), .accepted)
        XCTAssertEqual(core.tutorial?.step, 1)
        XCTAssertEqual(core.apply(action("overlay.forces", [1])), .accepted)
        XCTAssertEqual(core.tutorial, TutorialProgress(tutorial: 1, step: 2, startTick: 0))
        for step in 0..<100 { core.update(step: step) }
        XCTAssertEqual(core.apply(action("world.reset")), .accepted)
        XCTAssertEqual(core.tutorial, TutorialProgress(tutorial: 1, step: 2, startTick: 0),
                       "a reset begins the step again at the restored tick")
        for step in 0..<(Tutorials.runTicks - 1) { core.update(step: step) }
        XCTAssertEqual(core.tutorial?.step, 2)
        core.update(step: Tutorials.runTicks)
        XCTAssertNil(core.tutorial)
        XCTAssertEqual(core.world.tick, Tutorials.runTicks)
    }

    /// T-A11-403 (FR-A11-402, FR-A11-403; research D3): opening a saved document keeps the seed and the generator,
    /// makes the document's world (without grab and selection) the world and the starting world with origin the slot,
    /// keeps a running tutorial on its step, and restores through the snapshot the presenter builds.
    func testOpeningADocumentKeepsTheGeneratorAndBecomesTheStartingWorld() async throws {
        var current = PlaygroundCore(seed: 7)
        _ = current.apply(action("world.drop", [0]))
        _ = current.apply(action("tutorial.start", [1]))
        for step in 0..<30 { current.update(step: step) }
        var world = preset(.pendulum, from: current.generator).world
        world.selectedId = 1
        world.grab = Grab(bodyId: 1, localAnchor: .zero, target: Vec2(6, 4))
        let document = ExperimentDocument(name: "Swing", origin: .preset(1), world: world, slot: 2)
        let opened = PlaygroundCore.opening(document: document, slot: 2, from: current)
        XCTAssertEqual(opened.world, ExperimentDocument.withoutEditing(world))
        XCTAssertEqual(opened.startingWorld, opened.world)
        XCTAssertEqual(opened.origin, .slot(2))
        XCTAssertEqual(opened.generator, current.generator)
        XCTAssertEqual(opened.preparationSeed, current.preparationSeed)
        XCTAssertEqual(opened.tutorial, TutorialProgress(tutorial: 1, step: 0, startTick: 0), "it stays on its step")
        XCTAssertEqual(PlaygroundCore.opening(document: document, slot: 4, from: current), current)

        var reset = opened
        for step in 0..<40 { reset.update(step: step) }
        _ = reset.apply(action("world.drop", [1]))
        XCTAssertEqual(reset.apply(action("world.reset")), .accepted)
        XCTAssertEqual(reset.world, opened.world, "reset returns to the opened document")

        var engine = try await makeEngine()
        try engine.run(steps: 5)
        let snapshot = try PlaygroundCore.openingSnapshot(of: opened, experience: playgroundID, stepIndex: 5)
        XCTAssertEqual(snapshot.schemaVersion, 5)
        try engine.restore(snapshot)
        XCTAssertEqual(try XCTUnwrap(engine.core), opened)
        XCTAssertEqual(engine.stepIndex, 5)
    }

    /// T-A11-403 (FR-A11-430): the digest covers the origin, the starting world and the tutorial progress.
    func testTheDigestCoversTheExperimentAndTheTutorial() throws {
        let base = PlaygroundCore(seed: 7)
        var tutorial = base
        XCTAssertEqual(tutorial.apply(action("tutorial.start", [0])), .accepted)
        XCTAssertEqual(tutorial.world, base.world)
        XCTAssertNotEqual(try digest(tutorial), try digest(base))
        var state = base.state
        state.origin = .slot(1)
        let slot = try PlaygroundCore.restore(payload: PlaygroundCore.encode(state), seed: 7)
        XCTAssertNotEqual(try digest(slot), try digest(base))
        state = base.state
        state.startingWorld.tick = 5
        let starting = try PlaygroundCore.restore(payload: PlaygroundCore.encode(state), seed: 7)
        XCTAssertNotEqual(try digest(starting), try digest(base))
        XCTAssertNotEqual(starting, base)
        let payload = try XCTUnwrap(String(data: base.snapshotPayload(), encoding: .utf8))
        XCTAssertFalse(payload.contains("\"tutorial\""), "no tutorial key when none runs")
        XCTAssertTrue(payload.contains("\"startingWorld\""))
    }

    /// T-A11-403 (FR-A11-430): the stored Phase 03 payload restores through the step 3 → 4 with the digest the example
    /// names: the same world (its grab and selection kept) and generator, origin free play, the world without grab and
    /// selection as the starting world, no tutorial; the registry's check accepts all three examples.
    func testTheSchemaThreeExampleRestoresThroughTheMigration() async throws {
        let example = try XCTUnwrap(PlaygroundCore.schemaThreeExample())
        XCTAssertEqual(example.version, 3)
        let snapshot = try ExperienceSnapshot(data: example.snapshot)
        XCTAssertEqual(snapshot.schemaVersion, 3)
        let payload = try XCTUnwrap(try JSONSerialization.jsonObject(with: Data(snapshot.payload.utf8))
                                    as? [String: Any])
        XCTAssertEqual(Set(payload.keys), ["random", "world"], "exactly the A11-P03 keys")
        let storedWorld = try XCTUnwrap(payload["world"] as? [String: Any])
        XCTAssertEqual(storedWorld["schema"] as? Int, 3)
        for body in try XCTUnwrap(storedWorld["bodies"] as? [[String: Any]]) {
            XCTAssertNil(body["asleep"], "a Phase 03 body has no asleep key")
            XCTAssertNotNil(body["pinned"])
        }
        let phaseThree = try JSONDecoder().decode(PlaygroundStateSchemaThree.self, from: Data(snapshot.payload.utf8))
        XCTAssertEqual(phaseThree, PlaygroundCore.schemaThreeExampleState())
        XCTAssertEqual(phaseThree.world.selectedId, 9)
        XCTAssertEqual(phaseThree.world.grab?.bodyId, 7)

        var engine = ExperienceEngine<PlaygroundCore>(id: playgroundID)
        try await engine.prepare(seed: 3)
        try engine.activate()
        try engine.restore(snapshot)
        XCTAssertEqual(try engine.digest().hex, example.expectedDigest)
        let core = try XCTUnwrap(engine.core)
        let migratedWorld = PhysicsWorld.migrated(fromSchemaThree: phaseThree.world)
        XCTAssertEqual(core.world, migratedWorld)
        XCTAssertEqual(core.world.schema, 4)
        XCTAssertEqual(core.state.random, phaseThree.random)
        XCTAssertEqual(core.origin, .freePlay)
        XCTAssertEqual(core.startingWorld, ExperimentDocument.withoutEditing(migratedWorld))
        XCTAssertNil(core.tutorial)
        XCTAssertEqual(engine.handle(control: "world.reset"), .accepted)
        XCTAssertEqual(try XCTUnwrap(engine.core).world.selectedId, nil)

        let one = try XCTUnwrap(PlaygroundCore.schemaOneExample())
        let two = try XCTUnwrap(PlaygroundCore.schemaTwoExample())
        let twoSnapshot = try ExperienceSnapshot(data: two.snapshot)
        let twoPayload = try XCTUnwrap(try JSONSerialization.jsonObject(with: Data(twoSnapshot.payload.utf8))
                                       as? [String: Any])
        XCTAssertThrowsError(try PlaygroundCore.migratedToSchemaFour(twoPayload), "a Phase 02 payload needs 2 → 3")
        let four = try XCTUnwrap(PlaygroundCore.schemaFourExample())
        let problems = await SnapshotMigrationCheck.problems(for: PlaygroundCore.self, id: playgroundID,
                                                              examples: [one, two, example, four])
        XCTAssertEqual(problems, [])
    }

    /// T-A11-403 (FR-A11-430): a schema-4 state whose starting world does not validate or whose tutorial names no
    /// tutorial or step is refused, and a schema-3 payload needs the step 3 → 4.
    func testAStateWithABadStartingWorldOrTutorialIsRefused() throws {
        var state = PlaygroundCore(seed: 7).state
        state.startingWorld.remainder = 12
        XCTAssertThrowsError(try PlaygroundCore.restore(payload: PlaygroundCore.encode(state), seed: 7)) { error in
            guard case PlaygroundRestoreError.invalidStartingWorld(let problems)? = error as? PlaygroundRestoreError
            else { return XCTFail("\(error)") }
            XCTAssertFalse(problems.isEmpty)
        }
        for progress in [TutorialProgress(tutorial: 2, step: 0, startTick: 0),
                         TutorialProgress(tutorial: 0, step: 4, startTick: 0),
                         TutorialProgress(tutorial: 1, step: 0, startTick: -1)] {
            state = PlaygroundCore(seed: 7).state
            state.tutorial = progress
            XCTAssertThrowsError(try PlaygroundCore.restore(payload: PlaygroundCore.encode(state), seed: 7)) { error in
                XCTAssertEqual(error as? PlaygroundRestoreError, .invalidTutorial)
            }
        }
        let example = try XCTUnwrap(PlaygroundCore.schemaThreeExample())
        let snapshot = try ExperienceSnapshot(data: example.snapshot)
        XCTAssertThrowsError(try PlaygroundCore.restore(payload: Data(snapshot.payload.utf8), seed: 7),
                             "a schema-3 payload lacks the schema-4 keys")
    }
}
