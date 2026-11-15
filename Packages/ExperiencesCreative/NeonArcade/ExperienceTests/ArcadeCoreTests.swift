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
// refused by the restore; a schema-2 save in wave 3 round-trips identically.
// Feature 077 (A10-P03) T-A10-304 (FR-A10-310, FR-A10-321; SC-A10-301, SC-A10-304; clarification 2): schema 3 with
// the screen and the settings, six controls; a new experience (and a reset) opens on the title screen and nothing
// advances there; the flow through actions (start, pause, resume, restart, play again) and its refusals with
// `a10.wrong-screen` on every other screen; the step that ends the run shows the game-over screen; the settings take
// 0 or 1 only, are in the digest and never change the game; the stored schema-1 and schema-2 examples restore (the
// latter on the paused screen); the migration 2 → 3 derives the screen from the run; a saved title or game-over
// screen restores to the same screen; a screen that contradicts its run is refused; schema 4 is refused as newer.
import Foundation
import XCTest
@testable import NeonArcadeExperience
import NeonArcadeCore
import VisualCoreExperience
import VisualCoreMath
import VisualCoreSimulation

final class ArcadeCoreTests: XCTestCase {
    private let arcadeID = ExperienceID(rawValue: ArcadeCore.experienceID)!

    /// An active engine prepared with `seed`, moved from the title screen to playing unless `start` is false.
    private func makeEngine(seed: UInt64 = 7, start: Bool = true) async throws -> ExperienceEngine<ArcadeCore> {
        var engine = ExperienceEngine<ArcadeCore>(id: arcadeID)
        try await engine.prepare(seed: seed)
        try engine.activate()
        if start { XCTAssertEqual(engine.handle(control: "run.start"), .accepted) }
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
        XCTAssertEqual(ArcadeCore.controls.map(\.id),
                       ["run.start", "run.steer", "run.pause", "run.restart", "settings.sound", "settings.haptics"])
        XCTAssertEqual(ArcadeCore.controls.map(\.id), ArcadeCore.actionIDs)
        XCTAssertEqual(ArcadeCore.controls.map(\.ranges), [[], [-1...1], [0...1], [], [0...1], [0...1]])
        XCTAssertEqual(ArcadeCore.migrations.currentVersion, 3)
        XCTAssertEqual(ExperienceEngine<ArcadeCore>.schemaVersion, ArcadeCore.snapshotSchema)
        XCTAssertEqual(ArcadeCore.qualityTiers, 1)
        XCTAssertEqual(ArcadeCore.stepDuration, 1.0 / 60, accuracy: 1e-12)
        XCTAssertEqual(ExperienceEngine<ArcadeCore>.stepDuration, 1.0 / 60, accuracy: 1e-12)
        XCTAssertTrue(ArcadeRule.invalidChoice.hasPrefix("a10."))
        XCTAssertTrue(ArcadeRule.invalidSteering.hasPrefix("a10."))
        XCTAssertEqual(ArcadeRule.wrongScreen, "a10.wrong-screen")
    }

    func testConformancePassesOverFourSeeds() async {
        let plan = ConformancePlan(
            seeds: [1, 7, 42, 0xFFFF_FFFF_FFFF_FFFF], stepsPerSegment: 40,
            actions: [ScriptedAction("run.start"), ScriptedAction("run.steer", [1]), ScriptedAction("run.steer", [-0.5]),
                      ScriptedAction("run.pause", [1]), ScriptedAction("run.pause", [0]),
                      ScriptedAction("settings.sound", [0]), ScriptedAction("run.pause", [1]),
                      ScriptedAction("run.restart"), ScriptedAction("settings.haptics", [0]),
                      ScriptedAction("run.steer", [0.25])],
            rejected: [ScriptedAction("run.steer", [2]), ScriptedAction("run.steer", [-1.5]),
                       ScriptedAction("run.steer", [.nan]), ScriptedAction("run.steer", []),
                       ScriptedAction("run.pause", [0.5]), ScriptedAction("run.pause", [2]),
                       ScriptedAction("run.pause", [.infinity]), ScriptedAction("run.restart", [1]),
                       ScriptedAction("run.pause", [1]), ScriptedAction("run.restart"),
                       ScriptedAction("settings.sound", [0.5]), ScriptedAction("settings.haptics", [2]),
                       ScriptedAction("run.start", [1]), ScriptedAction("bogus")])
        let report = await ExperienceConformance.run(ArcadeCore.self, id: arcadeID, plan: plan)
        for entry in report.entries { XCTAssertTrue(entry.passed, "\(entry.check): \(entry.detail)") }
    }

    func testTheFirstStateIsANewRunOnTheTitleScreen() async throws {
        var engine = try await makeEngine(seed: 99, start: false)
        let core = try XCTUnwrap(engine.core)
        XCTAssertEqual(core.screen, .title, "a new experience opens on the title screen")
        XCTAssertTrue(core.sound)
        XCTAssertTrue(core.haptics)
        XCTAssertEqual(core.outcome?.code, ArcadeCore.titleOutcome)
        try engine.run(steps: 120)
        XCTAssertEqual(try XCTUnwrap(engine.core), core, "nothing falls until the person starts")
        XCTAssertEqual(core.run, GameRun.new())
        XCTAssertEqual(core.run.score, 0)
        XCTAssertEqual(core.run.lives, 3)
        XCTAssertEqual(core.run.player.x, 4.5)
        XCTAssertEqual(core.run.player.hitRadius, 0.4)
        XCTAssertTrue(core.run.objects.isEmpty)
        XCTAssertEqual(core.generator, SeededRandom(seed: 99))
        XCTAssertEqual(core.state.random, core.generator.state)
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
        XCTAssertEqual(engine.handle(control: "run.pause", values: [1]), .accepted)
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
        XCTAssertEqual(core.apply(action("run.start", [0])), .rejected(.wrongValueCount(expected: 0, found: 1)))
        XCTAssertEqual(core.apply(action("settings.sound", [0.5])), .rejected(.rule(code: ArcadeRule.invalidChoice)))
        XCTAssertEqual(core.apply(action("settings.haptics", [-1])), .rejected(.rule(code: ArcadeRule.invalidChoice)))
        XCTAssertEqual(core.apply(action("settings.sound", [])), .rejected(.wrongValueCount(expected: 1, found: 0)))
        XCTAssertEqual(core.apply(action("run.start", [])), .rejected(.rule(code: ArcadeRule.wrongScreen)))
        XCTAssertEqual(core.apply(action("run.pause", [0])), .rejected(.rule(code: ArcadeRule.wrongScreen)))
        XCTAssertEqual(core.apply(action("run.restart", [])), .rejected(.rule(code: ArcadeRule.wrongScreen)))
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
        XCTAssertEqual(core.screen, .over)
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
        XCTAssertEqual(snapshot.schemaVersion, 3)
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

        func envelope(_ payload: Data, schema: Int = 3) throws -> ExperienceSnapshot {
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
        // A screen that contradicts the run: over while the run plays, paused while it is not paused, an unknown one.
        for screen in ["over", "paused", "credits"] {
            var bad = try XCTUnwrap(try JSONSerialization.jsonObject(with: Data(saved.payload.utf8)) as? [String: Any])
            bad["screen"] = screen
            XCTAssertThrowsError(try engine.restore(envelope(
                JSONSerialization.data(withJSONObject: bad, options: [.sortedKeys]))), screen)
        }
        // Newer: schema 4 is not known to this build.
        XCTAssertThrowsError(try engine.restore(envelope(Data(saved.payload.utf8), schema: 4)))
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
        XCTAssertEqual(core.screen, .playing, "a playing run is shown playing (clarification 2)")
        XCTAssertTrue(core.sound && core.haptics, "both settings on")
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

        // The registry's check accepts both stored examples (one per earlier schema).
        let examples = try [example, XCTUnwrap(ArcadeCore.schemaTwoExample())]
        let problems = await SnapshotMigrationCheck.problems(for: ArcadeCore.self, id: arcadeID, examples: examples)
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
        XCTAssertEqual(snapshot.schemaVersion, 3)
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

    func testTheOutcomeFollowsTheScreen() {
        var core = ArcadeCore(seed: 7)
        XCTAssertEqual(core.outcome?.code, "run-title")
        _ = core.apply(action("run.start", []))
        XCTAssertEqual(core.outcome?.code, "run-playing")
        _ = core.apply(action("run.pause", [1]))
        XCTAssertEqual(core.outcome?.code, "run-paused")
        _ = core.apply(action("run.restart", []))
        XCTAssertEqual(core.outcome?.code, "run-playing")
    }

    // MARK: Feature 077 (A10-P03): screens, settings, schema 3

    /// T-A10-304 (FR-A10-310; SC-A10-301): the flow through actions — title → playing → paused ↔ playing → over →
    /// playing — and every other flow action refused with `a10.wrong-screen`, the state unchanged.
    func testTheFlowFollowsTheAllowedTransitionsOnly() async throws {
        var engine = try await makeEngine(start: false)
        func screen() throws -> ArcadeScreen { try XCTUnwrap(engine.core).screen }
        func refused(_ control: String, _ values: [Double] = []) throws {
            let before = try engine.digest()
            let shown = try screen()
            XCTAssertEqual(engine.handle(control: control, values: values),
                           .rejected(.rule(code: ArcadeRule.wrongScreen)), "\(control) \(values) on \(shown)")
            XCTAssertEqual(try engine.digest(), before)
        }
        // Title: only start (and steering and settings) are allowed.
        try refused("run.pause", [1])
        try refused("run.pause", [0])
        try refused("run.restart")
        XCTAssertEqual(engine.handle(control: "run.steer", values: [0.5]), .accepted, "steering is stored on any screen")
        XCTAssertEqual(try XCTUnwrap(engine.core).run.step, 0)
        XCTAssertEqual(engine.handle(control: "run.start"), .accepted)
        XCTAssertEqual(try screen(), .playing)
        XCTAssertEqual(try XCTUnwrap(engine.core).run.steering, 0.5, "the held value carries into the run")
        // Playing: start, resume and restart are refused.
        try engine.run(steps: 30)
        try refused("run.start")
        try refused("run.pause", [0])
        try refused("run.restart")
        XCTAssertEqual(engine.handle(control: "run.pause", values: [1]), .accepted)
        XCTAssertEqual(try screen(), .paused)
        XCTAssertTrue(try XCTUnwrap(engine.core).run.paused, "the run mirrors the paused screen")
        // Paused: start and pause again are refused; resume continues from the same step.
        try refused("run.start")
        try refused("run.pause", [1])
        let paused = try XCTUnwrap(engine.core)
        try engine.run(steps: 50)
        XCTAssertEqual(try XCTUnwrap(engine.core), paused, "no step changes a paused game")
        XCTAssertEqual(engine.handle(control: "run.pause", values: [0]), .accepted)
        XCTAssertEqual(try screen(), .playing)
        XCTAssertFalse(try XCTUnwrap(engine.core).run.paused)
        try engine.run(steps: 1)
        XCTAssertEqual(try XCTUnwrap(engine.core).run.step, paused.run.step + 1, "resumed from the same step")
        // Paused → restart: a new run, playing; the generator continues.
        XCTAssertEqual(engine.handle(control: "run.pause", values: [1]), .accepted)
        let beforeRestart = try XCTUnwrap(engine.core)
        XCTAssertEqual(engine.handle(control: "run.restart"), .accepted)
        let restarted = try XCTUnwrap(engine.core)
        XCTAssertEqual(restarted.screen, .playing)
        XCTAssertEqual(restarted.run, GameRun.new())
        XCTAssertEqual(restarted.generator, beforeRestart.generator)
        // Play until over (steering hard left meets the hazards): the step that ends the run shows the game over.
        XCTAssertEqual(engine.handle(control: "run.steer", values: [-1]), .accepted)
        var guardSteps = 0
        while try !XCTUnwrap(engine.core).run.over, guardSteps < 3_000 {
            try engine.run(steps: 10)
            guardSteps += 10
        }
        let over = try XCTUnwrap(engine.core)
        XCTAssertTrue(over.run.over, "the run ends within 3,000 steps")
        XCTAssertEqual(over.screen, .over)
        XCTAssertEqual(over.outcome?.code, ArcadeCore.overOutcome)
        try engine.run(steps: 30)
        XCTAssertEqual(try XCTUnwrap(engine.core), over, "nothing advances on the game-over screen")
        // Over: pause is refused; play again (start) and restart each begin a new run in wave 1.
        try refused("run.pause", [1])
        try refused("run.pause", [0])
        XCTAssertEqual(engine.handle(control: "run.start"), .accepted)
        let again = try XCTUnwrap(engine.core)
        XCTAssertEqual(again.screen, .playing)
        XCTAssertEqual(again.run, GameRun.new())
        XCTAssertEqual(again.run.wave, 1)
        XCTAssertEqual(again.generator, over.generator)
    }

    /// The flow function itself over every screen and action: exactly the six allowed moves (start from title or over,
    /// pause, resume, restart from paused or over).
    func testArcadeFlowAllowsExactlySixMoves() {
        var allowed: [String] = []
        for screen in ArcadeScreen.allCases {
            for action in [ArcadeFlowAction.start, .pause(true), .pause(false), .restart] {
                if let transition = ArcadeFlow.apply(action, to: screen) {
                    allowed.append("\(screen.rawValue) \(action) → \(transition.screen.rawValue) \(transition.newRun)")
                }
            }
        }
        XCTAssertEqual(allowed.count, 6, "\(allowed)")
        XCTAssertEqual(ArcadeFlow.initialScreen, .title)
        XCTAssertEqual(ArcadeScreen.allCases.filter(\.advancesRun), [.playing])
    }

    /// T-A10-304 (FR-A10-321; SC-A10-304): the settings take 0 or 1 on every screen, are saved in the state and the
    /// digest, and never change the game: the run and the generator are identical with them on or off.
    func testTheSettingsAreSavedAndNeverChangeTheGame() async throws {
        var on = try await makeEngine()
        var off = try await makeEngine()
        XCTAssertEqual(off.handle(control: "settings.sound", values: [0]), .accepted)
        XCTAssertEqual(off.handle(control: "settings.haptics", values: [0]), .accepted)
        XCTAssertFalse(try XCTUnwrap(off.core).sound)
        XCTAssertFalse(try XCTUnwrap(off.core).haptics)
        XCTAssertNotEqual(try off.digest(), try on.digest(), "the settings are in the digest")
        for engine in [0, 1] {
            for input in ArcadeCore.recordedInputs where input.step < 600 {
                if engine == 0 {
                    try on.run(steps: input.step - on.stepIndex)
                    XCTAssertEqual(on.handle(control: "run.steer", values: [input.value]), .accepted)
                } else {
                    try off.run(steps: input.step - off.stepIndex)
                    XCTAssertEqual(off.handle(control: "run.steer", values: [input.value]), .accepted)
                }
            }
        }
        try on.run(steps: 600 - on.stepIndex)
        try off.run(steps: 600 - off.stepIndex)
        let a = try XCTUnwrap(on.core), b = try XCTUnwrap(off.core)
        XCTAssertGreaterThan(a.run.eventCount, 0, "events happened")
        XCTAssertEqual(a.run, b.run, "the run does not depend on the settings")
        XCTAssertEqual(a.generator, b.generator)
        XCTAssertEqual(a.screen, b.screen)
        // Switched back on, the states and digests agree again.
        XCTAssertEqual(off.handle(control: "settings.sound", values: [1]), .accepted)
        XCTAssertEqual(off.handle(control: "settings.haptics", values: [1]), .accepted)
        XCTAssertEqual(try off.digest(), try on.digest())
        // Settings work on the title screen and survive a snapshot.
        var title = try await makeEngine(start: false)
        XCTAssertEqual(title.handle(control: "settings.sound", values: [0]), .accepted)
        XCTAssertEqual(title.handle(control: "settings.haptics", values: [0.5]),
                       .rejected(.rule(code: ArcadeRule.invalidChoice)))
        let snapshot = try title.snapshot()
        var other = try await makeEngine(seed: 2)
        try other.restore(snapshot)
        XCTAssertFalse(try XCTUnwrap(other.core).sound)
        XCTAssertTrue(try XCTUnwrap(other.core).haptics)
        XCTAssertEqual(try XCTUnwrap(other.core).screen, .title)
    }

    /// T-A10-304 (edge case "restoring a saved game in the title or game-over screen"): a saved title or game-over
    /// screen restores to the same screen in another engine, as does a paused one.
    func testASavedTitleOrGameOverScreenRestoresToTheSameScreen() async throws {
        var title = try await makeEngine(start: false)
        var over = GameRun.new()
        over.lives = 0
        over.over = true
        over.step = 640
        over.score = 88
        let overCore = try ArcadeCore.restore(payload: ArcadeCore.encode(ArcadeState(
            run: over, random: SeededRandom(seed: 7).state, screen: .over, sound: false, haptics: true)), seed: 7)
        var paused = try await makeEngine()
        try paused.run(steps: 40)
        XCTAssertEqual(paused.handle(control: "run.pause", values: [1]), .accepted)

        let titleSnapshot = try title.snapshot()
        let pausedSnapshot = try paused.snapshot()
        var builder = DigestBuilder(domain: arcadeID.rawValue)
        try overCore.writeDigest(into: &builder)
        let overSnapshot = try ExperienceSnapshot(experience: arcadeID, schemaVersion: 3, seed: 7, stepIndex: 640,
                                                  digest: builder.finish(), payload: overCore.snapshotPayload())
        let cases = [(titleSnapshot, ArcadeScreen.title), (pausedSnapshot, .paused), (overSnapshot, .over)]
        for (snapshot, screen) in cases {
            var other = try await makeEngine(seed: 11)
            try other.restore(ExperienceSnapshot(data: snapshot.encoded()))
            let restored = try XCTUnwrap(other.core)
            XCTAssertEqual(restored.screen, screen)
            try other.run(steps: 20)
            XCTAssertEqual(try XCTUnwrap(other.core), restored, "\(screen): nothing advances off the playing screen")
        }
        XCTAssertEqual(try ArcadeCore.restore(payload: overCore.snapshotPayload(), seed: 7).state, overCore.state)
        XCTAssertFalse(overCore.sound)
    }

    /// T-A10-304 (clarification 2): the stored schema-2 example (a paused run without screen or settings) restores in
    /// a new engine on the paused screen with the run and generator kept and both settings on; the migration 2 → 3
    /// derives over, paused and playing from the run.
    func testASchemaTwoSnapshotRestoresWithTheScreenDerived() async throws {
        let example = try XCTUnwrap(ArcadeCore.schemaTwoExample())
        XCTAssertEqual(example.version, 2)
        let snapshot = try ExperienceSnapshot(data: example.snapshot)
        XCTAssertEqual(snapshot.schemaVersion, 2)
        let payload = try XCTUnwrap(try JSONSerialization.jsonObject(with: Data(snapshot.payload.utf8)) as? [String: Any])
        for key in ["screen", "sound", "haptics"] { XCTAssertNil(payload[key], "a schema-2 payload has no \(key)") }
        let stored = try JSONDecoder().decode(ArcadeState.self, from: Data(snapshot.payload.utf8))
        XCTAssertTrue(stored.run.paused)

        var engine = try await makeEngine(seed: 3, start: false)
        try engine.restore(snapshot)
        XCTAssertEqual(try engine.digest().hex, example.expectedDigest)
        let core = try XCTUnwrap(engine.core)
        XCTAssertEqual(core.screen, .paused)
        XCTAssertTrue(core.sound && core.haptics)
        XCTAssertEqual(core.run, stored.run)
        XCTAssertEqual(core.state.random, stored.random)
        XCTAssertEqual(engine.handle(control: "run.pause", values: [0]), .accepted, "the restored game resumes")
        try engine.run(steps: 10)
        XCTAssertEqual(try XCTUnwrap(engine.core).run.step, stored.run.step + 10)

        var run = GameRun.new()
        run.step = 50
        let random = SeededRandom(seed: 7).state
        func migratedScreen(_ run: GameRun) throws -> ArcadeState {
            var object = try XCTUnwrap(try JSONSerialization.jsonObject(
                with: ArcadeCore.encode(ArcadeState(run: run, random: random))) as? [String: Any])
            for key in ["screen", "sound", "haptics"] { object[key] = nil }
            let upgraded = try ArcadeCore.migrations.migrate(object, from: 2)
            return try JSONDecoder().decode(ArcadeState.self,
                                            from: JSONSerialization.data(withJSONObject: upgraded))
        }
        XCTAssertEqual(try migratedScreen(run).screen, .playing)
        run.paused = true
        XCTAssertEqual(try migratedScreen(run).screen, .paused)
        run.lives = 0
        run.over = true
        XCTAssertEqual(try migratedScreen(run).screen, .over, "over wins over paused")
        XCTAssertTrue(try migratedScreen(run).sound && migratedScreen(run).haptics)
        XCTAssertThrowsError(try ArcadeCore.migrations.migrate(["run": 1], from: 2), "a payload that does not decode")
    }

    /// T-A10-304: reset returns to the title screen with the settings on.
    func testResetReturnsToTheTitleScreen() async throws {
        var engine = try await makeEngine()
        XCTAssertEqual(engine.handle(control: "settings.sound", values: [0]), .accepted)
        try engine.run(steps: 50)
        try engine.reset()
        let core = try XCTUnwrap(engine.core)
        XCTAssertEqual(core.screen, .title)
        XCTAssertTrue(core.sound)
        XCTAssertEqual(core.run, GameRun.new())
    }
}
