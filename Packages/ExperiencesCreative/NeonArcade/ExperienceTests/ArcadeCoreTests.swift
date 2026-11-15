// ArcadeCoreTests — feature 075 (A10-P01) T-A10-104 (FR-A10-112, FR-A10-121; SC-A10-101, SC-A10-102, SC-A10-105;
// contract "Experience actions"). The adapter core of Neon Arcade against the experience contract, short runs only
// (simulated steps, no wall clock): the id, the three controls, the schema (2 since A10-P02), one quality tier and the
// 1/60 s step; conformance over four seeds; the first state (a new run); every action accepted in range; values outside
// the range refused by the engine, a fractional pause refused by the core with `a10.invalid-choice` and a non-finite or
// too-large steering value with `a10.invalid-steering` (called directly), a refusal leaving the digest as it was; host
// steps advancing the run unless paused or over; the same seed and recorded inputs giving the same run and digest; the
// digest covering the events and the event count; the snapshot round trip into another engine; damaged, invalid and
// newer snapshots refused; reset, restart and the outcome.
// Feature 076 (A10-P02) T-A10-203 (FR-A10-210, FR-A10-211; SC-A10-204; clarification 4; research D4): schema 2; the
// stored schema-1 example restores through the engine's migration in a new engine with step, score, lives, player,
// objects, events and generator kept and the run at the start of wave 1; a schema-1 payload that skips the migration is
// refused by the restore; a schema-2 save in wave 3 round-trips identically; schema 3 is refused as newer.
import Foundation
import XCTest
@testable import NeonArcadeExperience
import NeonArcadeCore
import VisualCoreExperience
import VisualCoreMath
import VisualCoreSimulation

final class ArcadeCoreTests: XCTestCase {
    private let arcadeID = ExperienceID(rawValue: ArcadeCore.experienceID)!

    private func makeEngine(seed: UInt64 = 7) async throws -> ExperienceEngine<ArcadeCore> {
        var engine = ExperienceEngine<ArcadeCore>(id: arcadeID)
        try await engine.prepare(seed: seed)
        try engine.activate()
        return engine
    }

    private func action(_ control: String, _ values: [Double]) -> ExperienceAction {
        ExperienceAction(control: control, values: values, step: 0)
    }

    private func digest(_ core: ArcadeCore) throws -> String {
        var builder = DigestBuilder(domain: arcadeID.rawValue)
        try core.writeDigest(into: &builder)
        return builder.finish().hex
    }

    /// The engine after playing the recorded inputs for `steps` steps (each input applied at its step).
    private func replayed(seed: UInt64 = 7, steps: Int = 1_200) async throws -> ExperienceEngine<ArcadeCore> {
        var engine = try await makeEngine(seed: seed)
        for step in 0..<steps {
            for input in ArcadeCore.recordedInputs where input.step == step {
                XCTAssertEqual(engine.handle(control: "run.steer", values: [input.value]), .accepted)
            }
            try engine.run(steps: 1)
        }
        return engine
    }

    func testIdControlsSchemaTiersAndStep() {
        XCTAssertEqual(ArcadeCore.experienceID, "a10.neon-arcade")
        XCTAssertEqual(ArcadeCore.controls.map(\.id), ["run.steer", "run.pause", "run.restart"])
        XCTAssertEqual(ArcadeCore.controls.map(\.id), ArcadeCore.actionIDs)
        XCTAssertEqual(ArcadeCore.controls.map(\.ranges), [[-1...1], [0...1], []])
        XCTAssertEqual(ArcadeCore.migrations.currentVersion, 2)
        XCTAssertEqual(ExperienceEngine<ArcadeCore>.schemaVersion, GameRun.currentSchema)
        XCTAssertEqual(ArcadeCore.qualityTiers, 1)
        XCTAssertEqual(ArcadeCore.stepDuration, 1.0 / 60, accuracy: 1e-12)
        XCTAssertEqual(ExperienceEngine<ArcadeCore>.stepDuration, 1.0 / 60, accuracy: 1e-12)
        XCTAssertTrue(ArcadeRule.invalidChoice.hasPrefix("a10."))
        XCTAssertTrue(ArcadeRule.invalidSteering.hasPrefix("a10."))
    }

    func testConformancePassesOverFourSeeds() async {
        let plan = ConformancePlan(
            seeds: [1, 7, 42, 0xFFFF_FFFF_FFFF_FFFF], stepsPerSegment: 40,
            actions: [ScriptedAction("run.steer", [1]), ScriptedAction("run.steer", [-0.5]),
                      ScriptedAction("run.pause", [1]), ScriptedAction("run.pause", [0]),
                      ScriptedAction("run.restart"), ScriptedAction("run.steer", [0.25])],
            rejected: [ScriptedAction("run.steer", [2]), ScriptedAction("run.steer", [-1.5]),
                       ScriptedAction("run.steer", [.nan]), ScriptedAction("run.steer", []),
                       ScriptedAction("run.pause", [0.5]), ScriptedAction("run.pause", [2]),
                       ScriptedAction("run.pause", [.infinity]), ScriptedAction("run.restart", [1]),
                       ScriptedAction("bogus")])
        let report = await ExperienceConformance.run(ArcadeCore.self, id: arcadeID, plan: plan)
        for entry in report.entries { XCTAssertTrue(entry.passed, "\(entry.check): \(entry.detail)") }
    }

    func testTheFirstStateIsANewRun() async throws {
        let engine = try await makeEngine(seed: 99)
        let core = try XCTUnwrap(engine.core)
        XCTAssertEqual(core.run, GameRun.new())
        XCTAssertEqual(core.run.score, 0)
        XCTAssertEqual(core.run.lives, 3)
        XCTAssertEqual(core.run.player.x, 4.5)
        XCTAssertEqual(core.run.player.hitRadius, 0.4)
        XCTAssertTrue(core.run.objects.isEmpty)
        XCTAssertEqual(core.generator, SeededRandom(seed: 99))
        XCTAssertEqual(core.state.random, core.generator.state)
        XCTAssertEqual(core.outcome?.code, ArcadeCore.playingOutcome)
        XCTAssertEqual(core.run.validate(), [])
    }

    func testTheBundledCatalogValidates() {
        let decoded = ArcadeCatalog.decode(ArcadeCore.catalog.encoded())
        XCTAssertEqual(decoded.refused, [])
        XCTAssertEqual(decoded.catalog, ArcadeCore.catalog)
        XCTAssertEqual(LicenseAudit.problems(ArcadeCore.catalog), [])
    }

    func testActionsInRangeAreAccepted() async throws {
        var engine = try await makeEngine()
        let start = try engine.digest()
        XCTAssertEqual(engine.handle(control: "run.steer", values: [1]), .accepted)
        XCTAssertEqual(try XCTUnwrap(engine.core).run.steering, 1)
        XCTAssertNotEqual(try engine.digest(), start, "steering changes the digest")
        XCTAssertEqual(engine.handle(control: "run.steer", values: [-0.25]), .accepted)
        XCTAssertEqual(try XCTUnwrap(engine.core).run.steering, -0.25)
        XCTAssertEqual(engine.handle(control: "run.pause", values: [1]), .accepted)
        XCTAssertTrue(try XCTUnwrap(engine.core).run.paused)
        XCTAssertEqual(try XCTUnwrap(engine.core).outcome?.code, ArcadeCore.pausedOutcome)
        XCTAssertEqual(engine.handle(control: "run.pause", values: [0]), .accepted)
        XCTAssertFalse(try XCTUnwrap(engine.core).run.paused)
        try engine.run(steps: 90)
        let moved = try XCTUnwrap(engine.core)
        XCTAssertLessThan(moved.run.player.x, 4.5, "steering left moves the player left")
        XCTAssertEqual(engine.handle(control: "run.restart"), .accepted)
        let restarted = try XCTUnwrap(engine.core)
        XCTAssertEqual(restarted.run, GameRun.new(), "a restart begins a new run")
        XCTAssertEqual(restarted.generator, moved.generator, "the generator continues into the new run")
    }

    func testRefusedValuesKeepTheDigestWithTheirReasons() async throws {
        var engine = try await makeEngine()
        try engine.run(steps: 40)
        let before = try engine.digest()
        XCTAssertEqual(engine.handle(control: "run.steer", values: [1.5]), .rejected(.outOfRange(index: 0)))
        XCTAssertEqual(engine.handle(control: "run.steer", values: [-2]), .rejected(.outOfRange(index: 0)))
        XCTAssertEqual(engine.handle(control: "run.steer", values: [.nan]), .rejected(.nonFinite(index: 0)))
        XCTAssertEqual(engine.handle(control: "run.pause", values: [2]), .rejected(.outOfRange(index: 0)))
        XCTAssertEqual(engine.handle(control: "run.pause", values: [0.5]),
                       .rejected(.rule(code: ArcadeRule.invalidChoice)))
        XCTAssertEqual(engine.handle(control: "run.restart", values: [1]),
                       .rejected(.wrongValueCount(expected: 0, found: 1)))
        XCTAssertEqual(engine.handle(control: "bogus", values: []), .rejected(.unknownControl("bogus")))
        XCTAssertEqual(try engine.digest(), before)

        // Called directly, the core refuses by its own rules and changes nothing.
        var core = try XCTUnwrap(engine.core)
        let original = core
        XCTAssertEqual(core.apply(action("run.steer", [.nan])), .rejected(.rule(code: ArcadeRule.invalidSteering)))
        XCTAssertEqual(core.apply(action("run.steer", [.infinity])),
                       .rejected(.rule(code: ArcadeRule.invalidSteering)))
        XCTAssertEqual(core.apply(action("run.steer", [1.01])), .rejected(.rule(code: ArcadeRule.invalidSteering)))
        XCTAssertEqual(core.apply(action("run.pause", [2])), .rejected(.rule(code: ArcadeRule.invalidChoice)))
        XCTAssertEqual(core.apply(action("run.pause", [-1])), .rejected(.rule(code: ArcadeRule.invalidChoice)))
        XCTAssertEqual(core.apply(action("run.pause", [])), .rejected(.wrongValueCount(expected: 1, found: 0)))
        XCTAssertEqual(core.apply(action("run.steer", [0, 1])), .rejected(.wrongValueCount(expected: 1, found: 2)))
        XCTAssertEqual(core.apply(action("run.restart", [0])), .rejected(.wrongValueCount(expected: 0, found: 1)))
        XCTAssertEqual(core.apply(action("bogus", [0])), .rejected(.unknownControl("bogus")))
        XCTAssertEqual(core, original)
    }

    func testHostStepsAdvanceTheRunUnlessPausedOrOver() async throws {
        var engine = try await makeEngine()
        try engine.run(steps: 60)
        let running = try XCTUnwrap(engine.core)
        XCTAssertEqual(running.run.step, 60)
        XCTAssertFalse(running.run.objects.isEmpty, "the first object spawns at step 30")

        XCTAssertEqual(engine.handle(control: "run.pause", values: [1]), .accepted)
        let paused = try XCTUnwrap(engine.core)
        try engine.run(steps: 120)
        XCTAssertEqual(try XCTUnwrap(engine.core), paused, "nothing moves while paused")

        XCTAssertEqual(engine.handle(control: "run.pause", values: [0]), .accepted)
        try engine.run(steps: 10)
        XCTAssertEqual(try XCTUnwrap(engine.core).run.step, 70)

        // An over run holds still: a stored over state advances nowhere.
        var over = GameRun.new()
        over.lives = 0
        over.over = true
        over.step = 500
        let payload = try ArcadeCore.encode(ArcadeState(run: over, random: SeededRandom(seed: 7).state))
        var core = try ArcadeCore.restore(payload: payload, seed: 7)
        XCTAssertEqual(core.outcome?.code, ArcadeCore.overOutcome)
        let held = core
        for step in 0..<60 { core.update(step: step) }
        XCTAssertEqual(core, held)
    }

    func testTheSameSeedAndRecordedInputsGiveTheSameRun() async throws {
        let a = try await replayed()
        let b = try await replayed()
        let runA = try XCTUnwrap(a.core).run, runB = try XCTUnwrap(b.core).run
        XCTAssertEqual(runA.score, runB.score)
        XCTAssertEqual(runA.lives, runB.lives)
        XCTAssertEqual(runA.eventCount, runB.eventCount)
        XCTAssertEqual(runA.events, runB.events)
        XCTAssertGreaterThan(runA.eventCount, 0, "the replay includes contacts")
        XCTAssertEqual(try a.digest(), try b.digest())
        let other = try await replayed(seed: 8)
        XCTAssertNotEqual(try other.digest(), try a.digest(), "another seed gives another run")
    }

    func testTheDigestCoversTheEventsAndTheEventCount() throws {
        let core = ArcadeCore(seed: 7)
        var withEvent = core.state
        withEvent.run.step = 10
        withEvent.run.events = [CollisionEvent(step: 3, objectId: 0, kind: .hit)]
        withEvent.run.eventCount = 1
        withEvent.run.nextObjectId = 1
        var otherKind = withEvent
        otherKind.run.events = [CollisionEvent(step: 3, objectId: 0, kind: .pickup)]
        var moreCounted = withEvent
        moreCounted.run.eventCount = 2
        var stepOnly = withEvent
        stepOnly.run.events = []
        stepOnly.run.eventCount = 0
        let digests = try [withEvent, otherKind, moreCounted, stepOnly].map {
            try digest(ArcadeCore.restore(payload: ArcadeCore.encode($0), seed: 7))
        }
        XCTAssertEqual(Set(digests).count, 4, "events, their kinds and the event count are all in the digest")
    }

    func testTheSnapshotRestoresIdenticallyInAnotherEngine() async throws {
        var engine = try await replayed(steps: 400)
        let snapshot = try engine.snapshot()
        XCTAssertEqual(snapshot.schemaVersion, 2)
        let saved = try XCTUnwrap(engine.core)
        var other = try await makeEngine(seed: 3)
        try other.restore(ExperienceSnapshot(data: snapshot.encoded()))
        let restored = try XCTUnwrap(other.core)
        XCTAssertEqual(restored.state, saved.state)
        XCTAssertEqual(try other.digest(), try engine.digest())
        try engine.run(steps: 200)
        try other.run(steps: 200)
        XCTAssertEqual(try XCTUnwrap(other.core).state, try XCTUnwrap(engine.core).state, "both runs continue alike")
    }

    func testDamagedInvalidAndNewerSnapshotsAreRefused() async throws {
        var engine = try await makeEngine()
        try engine.run(steps: 100)
        let saved = try engine.snapshot()
        let before = try engine.digest()

        func envelope(_ payload: Data, schema: Int = 2) throws -> ExperienceSnapshot {
            try ExperienceSnapshot(experience: arcadeID, schemaVersion: schema, seed: saved.seed,
                                   stepIndex: saved.stepIndex, digest: saved.digest, payload: payload)
        }
        var object = try XCTUnwrap(try JSONSerialization.jsonObject(with: Data(saved.payload.utf8)) as? [String: Any])
        var run = try XCTUnwrap(object["run"] as? [String: Any])
        let originalRun = run

        // Damaged: not JSON, and JSON without the run.
        XCTAssertThrowsError(try engine.restore(envelope(Data("{not json".utf8))))
        XCTAssertThrowsError(try engine.restore(envelope(Data("{\"random\":{}}".utf8))))
        // Invalid: five lives, a negative score, a player outside the field.
        for (key, value) in [("lives", 5), ("score", -1)] as [(String, Any)] {
            var bad = run
            bad[key] = value
            object["run"] = bad
            XCTAssertThrowsError(try engine.restore(envelope(
                JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]))), key)
        }
        var player = try XCTUnwrap(run["player"] as? [String: Any])
        player["x"] = 12.0
        run["player"] = player
        object["run"] = run
        XCTAssertThrowsError(try engine.restore(envelope(
            JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]))))
        // A malformed generator state (with the valid run).
        object["run"] = originalRun
        var random = try XCTUnwrap(object["random"] as? [String: Any])
        random["words"] = ["0"]
        object["random"] = random
        XCTAssertThrowsError(try engine.restore(envelope(
            JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]))))
        // Invalid wave state: a wave below 1, an unknown pattern.
        for (key, value) in [("wave", 0), ("patternId", "spiral")] as [(String, Any)] {
            var bad = originalRun
            bad[key] = value
            object["run"] = bad
            object["random"] = try XCTUnwrap(
                try JSONSerialization.jsonObject(with: Data(saved.payload.utf8)) as? [String: Any])["random"]
            XCTAssertThrowsError(try engine.restore(envelope(
                JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]))), key)
        }
        // Newer: schema 3 is not known to this build.
        XCTAssertThrowsError(try engine.restore(envelope(Data(saved.payload.utf8), schema: 3)))
        XCTAssertEqual(try engine.digest(), before, "every refusal leaves the state as it was")

        // The core names the reason.
        var invalid = ArcadeCore(seed: 7).state
        invalid.run.lives = 9
        XCTAssertThrowsError(try ArcadeCore.restore(payload: ArcadeCore.encode(invalid), seed: 7)) { error in
            guard case ArcadeRestoreError.invalidRun(let problems)? = error as? ArcadeRestoreError else {
                return XCTFail("\(error)")
            }
            XCTAssertFalse(problems.isEmpty)
        }
    }

    /// T-A10-203 (SC-A10-204): the stored Phase 01 payload restores in a new engine through the migration 1 → 2: step,
    /// score, lives, player, objects, events and generator kept, the run at schema 2 at the start of wave 1, the digest
    /// the example names; the run then plays on validly and identically in two engines.
    func testASchemaOneSnapshotRestoresInANewEngineWithTheRunKept() async throws {
        let example = try XCTUnwrap(ArcadeCore.schemaOneExample())
        XCTAssertEqual(example.version, 1)
        let snapshot = try ExperienceSnapshot(data: example.snapshot)
        XCTAssertEqual(snapshot.schemaVersion, 1)
        XCTAssertEqual(snapshot.stepIndex, ArcadeCore.schemaOneExampleSteps)
        let payload = try XCTUnwrap(try JSONSerialization.jsonObject(with: Data(snapshot.payload.utf8)) as? [String: Any])
        let storedRun = try XCTUnwrap(payload["run"] as? [String: Any])
        XCTAssertEqual(storedRun["schema"] as? Int, 1)
        for key in ["wave", "waveStep", "patternId", "freeLane", "patternCursor"] {
            XCTAssertNil(storedRun[key], "a Phase 01 run has no \(key)")
        }
        let phaseOne = try JSONDecoder().decode(ArcadeState.self, from: Data(snapshot.payload.utf8))
        XCTAssertEqual(phaseOne.run.schema, 1)
        XCTAssertFalse(phaseOne.run.objects.isEmpty, "a mid-run state with falling objects")

        var engine = try await makeEngine(seed: 3)
        try engine.restore(snapshot)
        XCTAssertEqual(try engine.digest().hex, example.expectedDigest)
        XCTAssertEqual(engine.stepIndex, ArcadeCore.schemaOneExampleSteps)
        let core = try XCTUnwrap(engine.core)
        let run = core.run
        XCTAssertEqual(run.schema, 2)
        XCTAssertEqual(run.validate(), [])
        XCTAssertEqual(run.step, phaseOne.run.step)
        XCTAssertEqual(run.score, phaseOne.run.score)
        XCTAssertEqual(run.lives, phaseOne.run.lives)
        XCTAssertEqual(run.player, phaseOne.run.player)
        XCTAssertEqual(run.objects, phaseOne.run.objects)
        XCTAssertEqual(run.events, phaseOne.run.events)
        XCTAssertEqual(run.eventCount, phaseOne.run.eventCount)
        XCTAssertEqual(run.steering, phaseOne.run.steering)
        XCTAssertEqual(run.nextObjectId, phaseOne.run.nextObjectId)
        XCTAssertEqual(run.wave, 1)
        XCTAssertEqual(run.waveStep, 0)
        XCTAssertEqual(run.patternId, PatternTable.firstPatternId)
        XCTAssertEqual(run.freeLane, -1)
        XCTAssertEqual(run.patternCursor, 0)
        XCTAssertEqual(core.state.random, phaseOne.random, "the generator state is kept")
        XCTAssertEqual(core.preparationSeed, snapshot.seed)

        var other = try await makeEngine(seed: 11)
        try other.restore(ExperienceSnapshot(data: example.snapshot))
        try engine.run(steps: ArcadeCore.migrationSteps)
        try other.run(steps: ArcadeCore.migrationSteps)
        let continued = try XCTUnwrap(engine.core)
        XCTAssertEqual(continued.run.validate(), [])
        XCTAssertEqual(continued.run.waveStep, ArcadeCore.migrationSteps)
        XCTAssertEqual(continued, try XCTUnwrap(other.core), "the migrated run plays on identically")

        // The registry's check accepts the example.
        let problems = await SnapshotMigrationCheck.problems(for: ArcadeCore.self, id: arcadeID, examples: [example])
        XCTAssertEqual(problems, [])
    }

    /// T-A10-203: a schema-1 payload handed to the restore without the migration is refused (the run must be schema 2),
    /// and the migration step itself keeps a schema-2 run unchanged.
    func testTheRestoreValidatesTheMigratedRun() throws {
        let example = try XCTUnwrap(ArcadeCore.schemaOneExample())
        let snapshot = try ExperienceSnapshot(data: example.snapshot)
        XCTAssertThrowsError(try ArcadeCore.restore(payload: Data(snapshot.payload.utf8), seed: 7)) { error in
            guard case ArcadeRestoreError.invalidRun(let problems)? = error as? ArcadeRestoreError else {
                return XCTFail("\(error)")
            }
            XCTAssertTrue(problems.contains("schema 1 is not 2"), "\(problems)")
        }
        let object = try XCTUnwrap(try JSONSerialization.jsonObject(with: Data(snapshot.payload.utf8)) as? [String: Any])
        let upgraded = try ArcadeCore.migrations.migrate(object, from: 1)
        let migrated = try ArcadeCore.restore(
            payload: JSONSerialization.data(withJSONObject: upgraded, options: [.sortedKeys]), seed: 7)
        XCTAssertEqual(migrated.run.schema, 2)
        XCTAssertThrowsError(try ArcadeCore.migrations.migrate(["run": 1], from: 1), "a payload that does not decode")

        let current = try XCTUnwrap(try JSONSerialization.jsonObject(with: ArcadeCore.encode(migrated.state))
                                    as? [String: Any])
        let again = try ArcadeCore.migratedToSchemaTwo(current)
        XCTAssertEqual(try JSONDecoder().decode(ArcadeState.self,
                                                from: JSONSerialization.data(withJSONObject: again)), migrated.state)
    }

    /// T-A10-203: a schema-2 save in wave 3 (wave, wave step, pattern, free lane and cursor) round-trips identically
    /// in another engine and both continue alike.
    func testASchemaTwoSaveInWaveThreeRoundTrips() async throws {
        var engine = try await makeEngine()
        for input in ArcadeCore.waveInputs where input.step < 1_300 {
            try engine.run(steps: input.step - engine.stepIndex)
            XCTAssertEqual(engine.handle(control: "run.steer", values: [input.value]), .accepted)
        }
        try engine.run(steps: 1_300 - engine.stepIndex)
        let saved = try XCTUnwrap(engine.core)
        XCTAssertEqual(saved.run.wave, 3)
        XCTAssertEqual(saved.run.patternId, "wall")
        XCTAssertGreaterThanOrEqual(saved.run.freeLane, 0)
        let snapshot = try engine.snapshot()
        XCTAssertEqual(snapshot.schemaVersion, 2)
        var other = try await makeEngine(seed: 5)
        try other.restore(ExperienceSnapshot(data: snapshot.encoded()))
        XCTAssertEqual(try XCTUnwrap(other.core).state, saved.state)
        XCTAssertEqual(try other.digest(), try engine.digest())
        try engine.run(steps: 120)
        try other.run(steps: 120)
        XCTAssertEqual(try XCTUnwrap(other.core).state, try XCTUnwrap(engine.core).state)
    }

    func testResetReturnsToThePreparedRun() async throws {
        var engine = try await replayed(steps: 300)
        XCTAssertEqual(engine.handle(control: "run.pause", values: [1]), .accepted)
        try engine.reset()
        let core = try XCTUnwrap(engine.core)
        XCTAssertEqual(core, ArcadeCore(seed: 7))
        XCTAssertEqual(engine.stepIndex, 0)
    }

    func testTheOutcomeFollowsTheRun() {
        var core = ArcadeCore(seed: 7)
        XCTAssertEqual(core.outcome?.code, "run-playing")
        _ = core.apply(action("run.pause", [1]))
        XCTAssertEqual(core.outcome?.code, "run-paused")
        _ = core.apply(action("run.restart", []))
        XCTAssertEqual(core.outcome?.code, "run-playing")
    }
}
