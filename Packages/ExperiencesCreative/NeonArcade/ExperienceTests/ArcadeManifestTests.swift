// ArcadeManifestTests — feature 075 (A10-P01) T-A10-106 (FR-A10-123; SC-A10-106; research D5). The scenario manifest
// of Neon Arcade: valid with the nine standard scenarios and seven fixtures (replay, frame pacing, swept hit,
// save/restore, resume without catch-up, catalog, bounded objects), its derived digests and expected results equal to
// what the engine gives when the runner plays them, the fixtures ending in the states they name, and the committed
// `scenario-manifest.json` equal to the Swift manifest (`UPDATE_SCENARIO_MANIFEST=1`, on the simulator
// `TEST_RUNNER_UPDATE_SCENARIO_MANIFEST=1`, rewrites it).
// Feature 076 (A10-P02) T-A10-204 (FR-A10-221; SC-A10-206; research D5): fixtures 8–11 — wave progression through
// waves 1–4, the wall gap (rows of four with exactly one free lane, never the previous one), background/resume in wave
// 3 (the paused steps change nothing and the resume equals the unpaused run) and the Phase 01 migration (the stored
// schema-1 example restored, then 60 steps).
// Feature 077 (A10-P03) T-A10-305 (FR-A10-330; SC-A10-306; research D5): fourteen fixtures, each of 1–12 and 14
// beginning with `run.start`; 12 plays a run past its first hit (the high-speed crossings are `HighSpeedFixtureTests`'),
// 13 holds the title screen until the start, 14 plays with sound and haptics off and equals the run with them on.
// Feature 078 (A10-P04) T-A10-405 (FR-A10-401, FR-A10-402, FR-A10-412): sixteen fixtures; 15 plays a run to game over
// (score above 0, run number 1, entered into a high-score table once), 16 changes the sensitivity twice (the step saved,
// the run identical to the default step's).
// Feature 079 (A10-P05) T-A10-505 (FR-A10-522; research D5): nineteen fixtures; 17–19 play the same 600-step run (start,
// steer) for quality levels 0, 1 and 2 and record one digest, which `setQualityTier` leaves unchanged at every level
// (the per-level caps are proved by the render and session tests).
import Foundation
import Testing
@testable import NeonArcadeExperience
import NeonArcadeCore
import VisualCoreExperience
import VisualCoreMath

private let id = ExperienceID(rawValue: ArcadeCore.experienceID)!

/// What playing `spec` on a fresh engine gives, as the runner plays it.
private func play(_ spec: ScenarioSpec) async throws -> (initial: String, results: [String], final: String) {
    var engine = ExperienceEngine<ArcadeCore>(id: id)
    try await engine.prepare(seed: spec.seed)
    try engine.activate()
    let initial = try engine.digest().hex
    var results: [String] = []
    for entry in spec.entries {
        try engine.run(steps: entry.steps)
        if let action = entry.action {
            results.append(engine.handle(control: action.control, values: action.values).code)
        }
    }
    return (initial, results, try engine.digest().hex)
}

@Suite struct ArcadeManifestTests {
    @Test func theManifestIsValidWithTheNineStandardScenariosAndNineteenFixtures() {
        let manifest = ArcadeCore.manifest(for: id)
        let problems = ScenarioManifestValidator.problems(manifest, controls: ArcadeCore.controls,
                                                          content: ContentRequirement(fixtures: 19))
        #expect(problems.isEmpty, "\(problems)")
        #expect(Set(manifest.scenarios.map(\.name))
                == Set(ScenarioManifest.standardNames).union((1...19).map { "fixture-\($0)" }))
        // Every scenario with actions starts the game first, except fixture 13 and rejection (which stays on the title
        // screen to show the wrong-screen refusal).
        for spec in manifest.scenarios where spec.entries.contains(where: { $0.action != nil }) {
            guard spec.name != "fixture-13", spec.name != "rejection" else { continue }
            #expect(spec.entries.first?.action?.control == "run.start", "\(spec.name)")
        }
        #expect(manifest.kind == .creative)
        #expect(manifest.experience == id)
    }

    @Test func derivedDigestsAndResultsAreWhatTheEngineGives() async throws {
        let manifest = ArcadeCore.manifest(for: id)
        #expect(manifest.scenarios.first { $0.name == "launch-first-frame" }?.expect.initialDigest != nil)
        for spec in manifest.scenarios {
            let played = try await play(spec)
            if let initial = spec.expect.initialDigest {
                #expect(played.initial == initial, "\(spec.name) initial: \(played.initial)")
            }
            if let final = spec.expect.finalDigest {
                #expect(played.final == final, "\(spec.name) final: \(played.final)")
            }
            let expected = spec.entries.compactMap { $0.action == nil ? nil : ($0.result ?? "accepted") }
            #expect(played.results == expected, "\(spec.name)")
        }
        let completion = try #require(manifest.scenarios.first { $0.name == "completion" })
        #expect(ArcadeCore.played(seed: completion.seed, entries: completion.entries).outcome?.code
                == completion.expect.outcome)
    }

    @Test func theFixturesEndInTheStatesTheyName() throws {
        let seed = ArcadeCore.manifestSeed
        let fixtures = ArcadeCore.fixtureEntries
        #expect(fixtures.count == 19)

        // 1. Replay: the start and twelve recorded inputs over 1,200 steps; two plays give the same score, lives and
        // events.
        #expect(fixtures[0].compactMap(\.action).count == 13)
        #expect(fixtures[0].reduce(0) { $0 + $1.steps } == ArcadeCore.replaySteps)
        let replayA = ArcadeCore.played(seed: seed, entries: fixtures[0])
        let replayB = ArcadeCore.played(seed: seed, entries: fixtures[0])
        #expect(replayA.run.score == replayB.run.score && replayA.run.lives == replayB.run.lives)
        #expect(replayA.run.eventCount == replayB.run.eventCount && replayA.run.events == replayB.run.events)
        #expect(replayA.run.eventCount > 0, "the replay includes contacts")
        #expect(replayA == replayB)

        // 2. Frame pacing: the same entries, so the same final state (the frame times are ArcadeSessionTests').
        #expect(fixtures[1] == fixtures[0])
        #expect(ArcadeCore.played(seed: seed, entries: fixtures[1]) == replayA)

        // 3. Swept hit (steering half left): a falling hazard hits the player; one life is lost and invulnerability
        // started.
        let hit = ArcadeCore.played(seed: seed, entries: fixtures[2]).run
        let hits = hit.events.filter { $0.kind == .hit }
        #expect(!hits.isEmpty, "a hazard hits the player")
        #expect(hit.lives == GameRun.startLives - hits.count)
        #expect(hit.validate().isEmpty)

        // 4. Save/restore mid-run: the state round-trips through its payload and both continue alike.
        let saved = ArcadeCore.played(seed: seed, entries: fixtures[3])
        #expect(saved.run.step == 600 || saved.run.over)
        var restored = try ArcadeCore.restore(payload: saved.snapshotPayload(), seed: seed)
        #expect(restored == saved)
        var original = saved
        for step in 600..<900 {
            original.update(step: step)
            restored.update(step: step)
        }
        #expect(restored == original)

        // 5. Resume without catch-up: after the pause, 300 steps change nothing.
        let paused = ArcadeCore.played(seed: seed, entries: Array(fixtures[4].prefix(3)))
        let later = ArcadeCore.played(seed: seed, entries: fixtures[4])
        #expect(paused.run.paused && paused.run.step == 60)
        #expect(later == paused, "no motion while paused")

        // 6. Catalog: the bundled catalog validates and every spawned object names one of its items.
        let decoded = ArcadeCatalog.decode(ArcadeCore.catalog.encoded())
        #expect(decoded.refused.isEmpty && decoded.catalog == ArcadeCore.catalog)
        let spawned = ArcadeCore.played(seed: seed, entries: fixtures[5]).run
        #expect(spawned.nextObjectId > 0)
        for object in spawned.objects {
            let item = try #require(ArcadeCore.catalog.item(id: object.contentId))
            #expect(item.role.rawValue == object.kind.rawValue)
            #expect(item.radiusRange.closed.contains(object.radius))
        }

        // 7. Bounded objects: at most 24 objects and the player inside the field at every step of 2,400.
        #expect(fixtures[6].reduce(0) { $0 + $1.steps } == 2_400)
        var core = ArcadeCore(seed: seed)
        var step = 0
        for entry in fixtures[6] {
            for _ in 0..<entry.steps {
                core.update(step: step)
                step += 1
                #expect(core.run.objects.count <= GameRun.maxObjects)
                #expect(PlayerState.xRange.contains(core.run.player.x))
            }
            if let action = entry.action {
                _ = core.apply(ExperienceAction(control: action.control, values: action.values, step: step))
            }
        }
        #expect(core.run.validate().isEmpty)
        #expect(core == ArcadeCore.played(seed: seed, entries: fixtures[6]))
    }

    /// The core prepared with `seed` after `entries`, recording the pattern of every wave it reaches (wave 1 first).
    private func patterns(seed: UInt64, entries: [ScenarioStep]) -> (core: ArcadeCore, patterns: [String]) {
        var core = ArcadeCore(seed: seed)
        var patterns = [core.run.patternId]
        var step = 0
        for entry in entries {
            for _ in 0..<max(0, entry.steps) {
                core.update(step: step)
                step += 1
                if core.run.wave > patterns.count { patterns.append(core.run.patternId) }
            }
            if let action = entry.action {
                _ = core.apply(ExperienceAction(control: action.control, values: action.values, step: step))
                if action.control == "run.restart" { patterns = [core.run.patternId] }
            }
        }
        return (core, patterns)
    }

    @Test func theWaveFixturesEndInTheStatesTheyName() throws {
        let seed = ArcadeCore.manifestSeed
        let fixtures = ArcadeCore.fixtureEntries

        // 8. Wave progression: 1,900 steps alive through waves 1–4, each pattern other than the one before.
        #expect(fixtures[7].reduce(0) { $0 + $1.steps } == ArcadeCore.waveSteps)
        #expect(fixtures[7].compactMap(\.action).count == ArcadeCore.waveInputs.count + 1)
        let progression = patterns(seed: seed, entries: fixtures[7])
        let wave4 = progression.core.run
        #expect(!wave4.over && wave4.lives > 0, "the run lives through four waves")
        #expect(wave4.step == 1_900 && wave4.wave == 4 && wave4.waveStep == 100)
        #expect(progression.patterns == ["rain", "orb-trail", "wall", "rain"], "\(progression.patterns)")
        for (a, b) in zip(progression.patterns, progression.patterns.dropFirst()) { #expect(a != b) }
        #expect(wave4.validate().isEmpty)
        #expect(progression.core == ArcadeCore.played(seed: seed, entries: fixtures[7]))
        #expect(wave4.score >= wave4.step / GameSimulation.survivalInterval, "survival points at least")

        // 9. Wall gap: after the pause and restart at step 31 the new run's wave 2 is `wall`; at its end two rows of
        // four spike-balls of radius 0.5, one shared speed each, at the lane centres, each with one free lane, the
        // second's not the first's and equal to the run's.
        #expect(fixtures[8][1].action?.control == "run.pause" && fixtures[8][1].steps == ArcadeCore.wallRestartSteps)
        #expect(fixtures[8][2].action?.control == "run.restart" && fixtures[8][2].steps == 0)
        let wall = patterns(seed: seed, entries: fixtures[8])
        let wallRun = wall.core.run
        #expect(wall.patterns == ["rain", "wall"], "\(wall.patterns)")
        #expect(patterns(seed: seed, entries: [ArcadeCore.startEntry, ScenarioStep(steps: 800)]).patterns[1] != "wall",
                "without the restart wave 2 of seed 7 is not a wall")
        #expect(wallRun.step == ArcadeCore.wallSteps && wallRun.wave == 2 && wallRun.patternId == "wall")
        #expect(!wallRun.over)
        let spikes = wallRun.objects.filter { $0.contentId == "spike-ball" && $0.radius == WaveDirector.wallRadius }
        var rows: [Double: [FallingObject]] = [:]
        for object in spikes { rows[object.position.y, default: []].append(object) }
        let ordered = rows.values.filter { $0.count == Lanes.count - 1 }
            .sorted { $0[0].position.y < $1[0].position.y }   // oldest row (lowest) first
        try #require(ordered.count == 2, "two wall rows in wave 2 by step 800")
        var freeLanes: [Int] = []
        for row in ordered {
            #expect(Set(row.map(\.velocity.y)).count == 1, "one shared speed per row")
            let lanes = row.compactMap { object in Lanes.centres.firstIndex { abs($0 - object.position.x) < 1e-12 } }
            #expect(lanes.count == row.count, "every spike-ball at a lane centre")
            let free = Set(0..<Lanes.count).subtracting(lanes)
            #expect(free.count == 1, "exactly one free lane")
            freeLanes.append(contentsOf: free)
        }
        #expect(freeLanes.count == 2 && freeLanes[0] != freeLanes[1], "never the same free lane twice in a row")
        #expect(freeLanes.last == wallRun.freeLane)

        // 10. Background/resume in wave 3: the paused steps change nothing; the resume equals the unpaused run.
        let pausedAt = fixtures[9].firstIndex { $0.action?.control == "run.pause" && $0.action?.values == [1] }
        let pauseIndex = try #require(pausedAt)
        let atPause = ArcadeCore.played(seed: seed, entries: Array(fixtures[9].prefix(pauseIndex + 1)))
        #expect(atPause.run.wave == 3 && atPause.run.patternId == "wall" && atPause.run.paused)
        #expect(atPause.run.step == ArcadeCore.waveThreeSteps && !atPause.run.over)
        var beforeResume = fixtures[9].prefix(pauseIndex + 2)
        beforeResume[pauseIndex + 1] = ScenarioStep(steps: beforeResume[pauseIndex + 1].steps)
        #expect(ArcadeCore.played(seed: seed, entries: Array(beforeResume)) == atPause,
                "300 paused steps change nothing")
        let resumed = ArcadeCore.played(seed: seed, entries: fixtures[9])
        let unpaused = ArcadeCore.played(seed: seed, entries: [ArcadeCore.startEntry] + ArcadeCore.steeringEntries(
            ArcadeCore.waveInputs, steps: ArcadeCore.waveThreeSteps + 60))
        #expect(resumed == unpaused, "no catch-up: the resume continues from the paused step")
        #expect(resumed.run.wave == 3 && resumed.run.step == ArcadeCore.waveThreeSteps + 60)

        // 11. Phase 01 migration: the fixture plays the run the schema-1 example was saved from; the stored example
        // restores to that run's step, score, lives, player and objects at wave 1, wave step 0, and plays 60 steps on.
        #expect(fixtures[10].reduce(0) { $0 + $1.steps }
                == ArcadeCore.schemaOneExampleSteps + ArcadeCore.migrationSteps)
        let source = ArcadeCore.played(seed: seed, entries: [ArcadeCore.startEntry] + ArcadeCore.steeringEntries(
            ArcadeCore.schemaOneExampleInputs, steps: ArcadeCore.schemaOneExampleSteps))
        #expect(source.state == ArcadeCore.exampleSource(seed: seed).state, "the run the examples were saved from")
        let example = try #require(ArcadeCore.schemaOneExample(seed: seed))
        let snapshot = try ExperienceSnapshot(data: example.snapshot)
        let object = try #require(try JSONSerialization.jsonObject(with: Data(snapshot.payload.utf8)) as? [String: Any])
        let upgraded = try ArcadeCore.migrations.migrate(object, from: 1)
        var migrated = try ArcadeCore.restore(
            payload: JSONSerialization.data(withJSONObject: upgraded, options: [.sortedKeys]), seed: seed)
        #expect(migrated.run.schema == GameRun.currentSchema)
        #expect(migrated.run.step == source.run.step && migrated.run.score == source.run.score)
        #expect(migrated.run.lives == source.run.lives && migrated.run.player == source.run.player)
        #expect(migrated.run.objects == source.run.objects && migrated.generator == source.generator)
        #expect(migrated.run.wave == 1 && migrated.run.waveStep == 0 && migrated.run.patternId == "rain")
        for step in 0..<ArcadeCore.migrationSteps { migrated.update(step: ArcadeCore.schemaOneExampleSteps + step) }
        #expect(migrated.run.validate().isEmpty)
        #expect(migrated.run.step == ArcadeCore.schemaOneExampleSteps + ArcadeCore.migrationSteps)
        #expect(migrated.run.waveStep == ArcadeCore.migrationSteps)
        let played = ArcadeCore.played(seed: seed, entries: fixtures[10]).run
        #expect(played.step == migrated.run.step && played.validate().isEmpty)
    }

    /// T-A10-305 (FR-A10-330; SC-A10-306): fixtures 12–14 end in the states they name.
    @Test func thePhaseThreeFixturesEndInTheStatesTheyName() throws {
        let seed = ArcadeCore.manifestSeed
        let fixtures = ArcadeCore.fixtureEntries

        // 12. A run past its first hit: one life lost at the hit, the run advancing after it, not over. The high-speed
        // crossings themselves are proved by HighSpeedFixtureTests (an action cannot place a hazard).
        #expect(fixtures[11].first == ArcadeCore.startEntry)
        let hitRun = ArcadeCore.played(seed: seed, entries: fixtures[11])
        let firstHit = try #require(hitRun.run.events.first { $0.kind == .hit })
        #expect(firstHit.step < ArcadeCore.firstHitSteps - 30, "the run plays on past its first hit")
        #expect(hitRun.run.step == ArcadeCore.firstHitSteps && !hitRun.run.over && hitRun.screen == .playing)
        #expect(hitRun.run.lives == GameRun.startLives - hitRun.run.events.filter { $0.kind == .hit }.count)
        #expect(hitRun.run.validate().isEmpty)

        // 13. Title → start: the title steps change nothing; after the start the run advances.
        #expect(fixtures[12].first?.action?.control == "run.start" && fixtures[12].first?.steps == ArcadeCore.titleSteps)
        let held = ArcadeCore.played(seed: seed, entries: [ScenarioStep(steps: ArcadeCore.titleSteps)])
        #expect(held == ArcadeCore(seed: seed) && held.screen == .title, "nothing advances on the title screen")
        let started = ArcadeCore.played(seed: seed, entries: fixtures[12])
        #expect(started.screen == .playing && started.run.step == ArcadeCore.titleSteps)
        #expect(started.run == ArcadeCore.played(seed: seed, entries: [ArcadeCore.startEntry,
                                                                         ScenarioStep(steps: ArcadeCore.titleSteps)]).run)

        // 14. Settings off: both off and saved; the run and generator equal the same steps with both on.
        let off = ArcadeCore.played(seed: seed, entries: fixtures[13])
        #expect(!off.sound && !off.haptics && off.screen == .playing)
        let on = ArcadeCore.played(seed: seed, entries: [ArcadeCore.startEntry,
                                                         ScenarioStep(steps: ArcadeCore.settingsSteps)])
        #expect(off.run == on.run && off.generator == on.generator && off.run.step == ArcadeCore.settingsSteps)
        var restored = try ArcadeCore.restore(payload: off.snapshotPayload(), seed: seed)
        #expect(restored == off)
        restored.update(step: ArcadeCore.settingsSteps)
        #expect(!restored.sound && !restored.haptics)
    }

    /// T-A10-405 (FR-A10-401, FR-A10-402, FR-A10-412): fixtures 15–16 end in the states they name.
    @Test func thePhaseFourFixturesEndInTheStatesTheyName() throws {
        let seed = ArcadeCore.manifestSeed
        let fixtures = ArcadeCore.fixtureEntries

        // 15. A run to game over: the over screen, a score that enters the table, run number 1; entered once.
        #expect(fixtures[14].first == ArcadeCore.startEntry)
        let over = ArcadeCore.played(seed: seed, entries: fixtures[14])
        #expect(over.screen == .over && over.run.over && over.run.lives == 0)
        #expect(over.run.score > 0 && over.runNumber == 1)
        #expect(over.run.step < ArcadeCore.gameOverSteps, "the run ends before the fixture's last step")
        #expect(over.outcome?.code == ArcadeCore.overOutcome)
        var table = HighScoreTable()
        let entry = HighScoreEntry(score: over.run.score, wave: over.run.wave, run: over.runNumber)
        #expect(table.enter(entry) == 0)
        #expect(table.enter(entry) == nil, "the same run is entered once")
        #expect(table.entries == [entry])
        // Play again: a new run with run number 2.
        var again = over
        #expect(again.apply(ExperienceAction(control: "run.start", values: [], step: over.run.step)) == .accepted)
        #expect(again.runNumber == 2 && again.screen == .playing && again.run.score == 0)

        // 16. Sensitivity: the last step saved; the run and generator equal the default step's.
        let changed = ArcadeCore.played(seed: seed, entries: fixtures[15])
        #expect(changed.sensitivity == 0 && changed.screen == .playing)
        let plain = ArcadeCore.played(seed: seed, entries: [ArcadeCore.startEntry,
                                                            ScenarioStep(steps: 2 * ArcadeCore.sensitivitySteps)])
        #expect(plain.sensitivity == Sensitivity.defaultStep)
        #expect(changed.run == plain.run && changed.generator == plain.generator)
        let restored = try ArcadeCore.restore(payload: changed.snapshotPayload(), seed: seed)
        #expect(restored == changed && restored.sensitivity == 0)
    }

    /// T-A10-505 (FR-A10-522; research D5): fixtures 17–19, one per quality level, play the same run and record one
    /// digest; the tier is presentation only, so `setQualityTier` at every level leaves the core and its digest as
    /// they are.
    @Test func theQualityFixturesShareOneRunAndOneDigest() throws {
        let seed = ArcadeCore.manifestSeed
        let fixtures = ArcadeCore.fixtureEntries
        #expect(ArcadeCore.qualityFixtureLevels == Array(0..<ArcadeCore.qualityTiers))
        let quality = Array(fixtures[16...18])
        #expect(quality.allSatisfy { $0 == quality[0] })
        #expect(quality[0].first == ArcadeCore.startEntry)
        #expect(quality[0].compactMap(\.action).map(\.control) == ["run.start", "run.steer"])
        #expect(quality[0].reduce(0) { $0 + $1.steps } == ArcadeCore.qualitySteps)
        let manifest = ArcadeCore.manifest(for: id)
        let digests = (17...19).map { n in manifest.scenarios.first { $0.name == "fixture-\(n)" }?.expect.finalDigest }
        #expect(digests.allSatisfy { $0 != nil && $0 == digests[0] }, "\(digests)")
        let played = ArcadeCore.played(seed: seed, entries: quality[0])
        #expect(played.screen == .playing && played.run.step == ArcadeCore.qualitySteps)
        for level in ArcadeCore.qualityFixtureLevels {
            var tiered = played
            tiered.setQualityTier(level)
            #expect(tiered == played, "level \(level)")
            var builder = DigestBuilder(domain: id.rawValue)
            try tiered.writeDigest(into: &builder)
            #expect(builder.finish().hex == digests[0], "level \(level)")
        }
    }

    /// The JSON form with the control ids, named by `Catalog/registrations.json`. `UPDATE_SCENARIO_MANIFEST=1`
    /// rewrites it.
    @Test func theCommittedManifestFileMatches() throws {
        let file = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("scenario-manifest.json")
        let manifest = ArcadeCore.manifest(for: id)
        var object = try #require(try JSONSerialization.jsonObject(with: manifest.encoded()) as? [String: Any])
        object["controls"] = ArcadeCore.controls.map(\.id)
        let data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys, .prettyPrinted])
            + Data("\n".utf8)
        if ProcessInfo.processInfo.environment["UPDATE_SCENARIO_MANIFEST"] == "1" { try data.write(to: file) }
        #expect(try Data(contentsOf: file) == data, "run with UPDATE_SCENARIO_MANIFEST=1 and commit the file")
    }
}
