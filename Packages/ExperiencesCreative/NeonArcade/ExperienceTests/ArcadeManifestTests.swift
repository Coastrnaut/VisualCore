// ArcadeManifestTests — feature 075 (A10-P01) T-A10-106 (FR-A10-123; SC-A10-106; research D5). The scenario manifest
// of Neon Arcade: valid with the nine standard scenarios and seven fixtures (replay, frame pacing, swept hit,
// save/restore, resume without catch-up, catalog, bounded objects), its derived digests and expected results equal to
// what the engine gives when the runner plays them, the fixtures ending in the states they name, and the committed
// `scenario-manifest.json` equal to the Swift manifest (`UPDATE_SCENARIO_MANIFEST=1`, on the simulator
// `TEST_RUNNER_UPDATE_SCENARIO_MANIFEST=1`, rewrites it).
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
    @Test func theManifestIsValidWithTheNineStandardScenariosAndSevenFixtures() {
        let manifest = ArcadeCore.manifest(for: id)
        let problems = ScenarioManifestValidator.problems(manifest, controls: ArcadeCore.controls,
                                                          content: ContentRequirement(fixtures: 7))
        #expect(problems.isEmpty, "\(problems)")
        #expect(Set(manifest.scenarios.map(\.name))
                == Set(ScenarioManifest.standardNames).union((1...7).map { "fixture-\($0)" }))
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
        #expect(fixtures.count == 7)

        // 1. Replay: twelve recorded inputs over 1,200 steps; two plays give the same score, lives and events.
        #expect(fixtures[0].compactMap(\.action).count == 12)
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

        // 3. Swept hit: a falling hazard hits the player; one life is lost and invulnerability started.
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
        let paused = ArcadeCore.played(seed: seed, entries: Array(fixtures[4].prefix(2)))
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
