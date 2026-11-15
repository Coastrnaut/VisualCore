// PlaygroundManifestTests — feature 082 (A11-P01) T-A11-106 (FR-A11-122; SC-A11-107; research D5). The scenario
// manifest of Physics Playground: valid with the nine standard scenarios and ten fixtures (free fall, two-body
// momentum, static zero mass, replay determinism, frame pacing, time scale and single step, save/restore, resume
// without catch-up, catalog refusal, body cap), its derived digests and expected results equal to what the engine
// gives when the runner plays them, the fixtures ending in the states they name, and the committed
// `scenario-manifest.json` equal to the Swift manifest (`UPDATE_SCENARIO_MANIFEST=1`, on the simulator
// `TEST_RUNNER_UPDATE_SCENARIO_MANIFEST=1`, rewrites it).
import Foundation
import Testing
@testable import PhysicsPlaygroundExperience
import PhysicsPlaygroundCore
import VisualCoreExperience
import VisualCoreMath
import VisualCoreSimulation

private let id = ExperienceID(rawValue: PlaygroundCore.experienceID)!

/// What playing `spec` on a fresh engine gives, as the runner plays it.
private func play(_ spec: ScenarioSpec) async throws -> (initial: String, results: [String], final: String) {
    var engine = ExperienceEngine<PlaygroundCore>(id: id)
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

/// The core after `entries`, checking `check` after every host step.
private func stepped(_ entries: [ScenarioStep], seed: UInt64 = PlaygroundCore.manifestSeed,
                     check: (PlaygroundCore) -> Void) -> PlaygroundCore {
    var core = PlaygroundCore(seed: seed)
    var step = 0
    for entry in entries {
        for _ in 0..<entry.steps {
            core.update(step: step)
            step += 1
            check(core)
        }
        if let action = entry.action {
            _ = core.apply(ExperienceAction(control: action.control, values: action.values, step: step))
        }
    }
    return core
}

@Suite struct PlaygroundManifestTests {
    @Test func theManifestIsValidWithTheNineStandardScenariosAndTenFixtures() {
        let manifest = PlaygroundCore.manifest(for: id)
        let problems = ScenarioManifestValidator.problems(manifest, controls: PlaygroundCore.controls,
                                                          content: ContentRequirement(fixtures: 10))
        #expect(problems.isEmpty, "\(problems)")
        #expect(Set(manifest.scenarios.map(\.name))
                == Set(ScenarioManifest.standardNames).union((1...10).map { "fixture-\($0)" }))
        #expect(manifest.kind == .creative)
        #expect(manifest.experience == id)
    }

    @Test func derivedDigestsAndResultsAreWhatTheEngineGives() async throws {
        let manifest = PlaygroundCore.manifest(for: id)
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
        #expect(PlaygroundCore.played(seed: completion.seed, entries: completion.entries).outcome?.code
                == completion.expect.outcome)
    }

    @Test func theFixturesEndInTheStatesTheyName() throws {
        let seed = PlaygroundCore.manifestSeed
        let fixtures = PlaygroundCore.fixtureEntries
        let catalog = PlaygroundCore.catalog
        #expect(fixtures.count == 10)

        // 1. Free fall: the dropped circle falls under gravity for 1 s.
        let fall = PlaygroundCore.played(seed: seed, entries: fixtures[0])
        let start = PlaygroundCore.played(seed: seed, entries: Array(fixtures[0].prefix(1)))
        let dropped = try #require(fall.world.bodies.last)
        #expect(fall.world.tick == 120)
        #expect(dropped.id == start.world.bodies.last?.id)
        #expect(dropped.position.y < WorldSimulation.dropHeight - 1, "the circle fell more than a metre")

        // 2. Two-body momentum: two circles dropped; every number stays finite and the world valid.
        let two = PlaygroundCore.played(seed: seed, entries: fixtures[1])
        #expect(two.world.bodies.count == 9)
        #expect(two.world.validate(catalog: catalog).isEmpty)

        // 3. Static zero mass: the ledge never moves in 1,000 steps with bodies landing around it.
        let ledge = PlaygroundCore(seed: seed).world.bodies[0]
        #expect(ledge.isStatic)
        #expect(ledge.mass(in: catalog) == 0)
        let after = stepped(fixtures[2]) { core in
            #expect(core.world.bodies[0] == ledge)
        }
        #expect(after.world.tick == 1_000)

        // 4. Replay determinism: two plays give the same world.
        #expect(fixtures[3].compactMap(\.action).count == PlaygroundCore.recordedInputs.count)
        #expect(fixtures[3].reduce(0) { $0 + $1.steps } == PlaygroundCore.replaySteps)
        let replayA = PlaygroundCore.played(seed: seed, entries: fixtures[3])
        let replayB = PlaygroundCore.played(seed: seed, entries: fixtures[3])
        #expect(replayA == replayB)
        #expect(replayA.world.bodies.count == 11)

        // 5. Frame pacing: the same entries, so the same final state (the frame times are PlaygroundSessionTests').
        #expect(fixtures[4] == fixtures[3])
        #expect(PlaygroundCore.played(seed: seed, entries: fixtures[4]) == replayA)

        // 6. Time scale and single step: 10 ticks at ¼×, 80 at 2×, three single steps, then nothing while paused.
        let scaled = PlaygroundCore.played(seed: seed, entries: Array(fixtures[5].prefix(2)))
        #expect(scaled.world.tick == 10)
        let doubled = PlaygroundCore.played(seed: seed, entries: Array(fixtures[5].prefix(3)))
        #expect(doubled.world.tick == 90 && doubled.world.paused)
        let singles = PlaygroundCore.played(seed: seed, entries: Array(fixtures[5].prefix(6)))
        #expect(singles.world.tick == 93)
        #expect(PlaygroundCore.played(seed: seed, entries: fixtures[5]) == singles, "30 paused steps change nothing")

        // 7. Save/restore: the state round-trips through its payload and both continue alike.
        let saved = PlaygroundCore.played(seed: seed, entries: fixtures[6])
        var restored = try PlaygroundCore.restore(payload: saved.snapshotPayload(), seed: seed)
        #expect(restored == saved)
        var original = saved
        for step in 300..<450 {
            original.update(step: step)
            restored.update(step: step)
        }
        #expect(restored == original)

        // 8. Resume without catch-up: after the pause, 300 steps change nothing.
        let paused = PlaygroundCore.played(seed: seed, entries: Array(fixtures[7].prefix(2)))
        let later = PlaygroundCore.played(seed: seed, entries: fixtures[7])
        #expect(paused.world.paused && paused.world.tick == 60)
        #expect(later == paused, "no motion while paused")

        // 9. Catalog: the bundled catalog validates and every body names one of its materials.
        let decoded = MaterialCatalog.decode(catalog.encoded())
        #expect(decoded.refused.isEmpty && decoded.catalog == catalog)
        let materials = PlaygroundCore.played(seed: seed, entries: fixtures[8]).world
        #expect(materials.bodies.count == 11)
        for body in materials.bodies { #expect(catalog.material(id: body.materialId) != nil) }

        // 10. Body cap: 41 drops fill the world to 48 bodies, the 42nd is refused, and the world stays valid.
        let capEntries = fixtures[9]
        #expect(capEntries.compactMap(\.action).count == PlaygroundCore.capDrops + 1)
        #expect(capEntries.compactMap(\.result).last == "action.rule." + PlaygroundRule.bodyCap)
        let full = stepped(capEntries) { core in
            #expect(core.world.bodies.count <= PhysicsWorld.maxBodies)
        }
        #expect(full.world.bodies.count == PhysicsWorld.maxBodies)
        #expect(full.world.validate(catalog: catalog).isEmpty)
    }

    /// The JSON form with the control ids, named by `Catalog/registrations.json`. `UPDATE_SCENARIO_MANIFEST=1`
    /// rewrites it.
    @Test func theCommittedManifestFileMatches() throws {
        let file = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("scenario-manifest.json")
        let manifest = PlaygroundCore.manifest(for: id)
        var object = try #require(try JSONSerialization.jsonObject(with: manifest.encoded()) as? [String: Any])
        object["controls"] = PlaygroundCore.controls.map(\.id)
        let data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys, .prettyPrinted])
            + Data("\n".utf8)
        if ProcessInfo.processInfo.environment["UPDATE_SCENARIO_MANIFEST"] == "1" { try data.write(to: file) }
        #expect(try Data(contentsOf: file) == data, "run with UPDATE_SCENARIO_MANIFEST=1 and commit the file")
    }
}
