// AquariumManifestTests — feature 068 (A09-P01) T-A09-105 (FR-A09-122; SC-A09-105); fixtures 6 and 7 feature 069
// (A09-P02) T-A09-207 (FR-A09-213); fixtures 8–10 feature 070 (A09-P03) T-A09-308 (FR-A09-322); fixture 11 feature
// 071 (A09-P04) T-A09-407; fixtures 12 and 13 feature 072 (A09-P05) T-A09-507. The scenario manifest of Digital
// Aquarium: valid with the nine standard scenarios and thirteen
// fixtures (A09-P01's five, schooling and save/load, feeding, decor editing, no fast-forward with food and water
// effects) (swim bounds, save/restore, no
// fast-forward while paused, both validated habitats, bounded counts), its derived digests and expected results equal
// to what the engine gives when the runner plays them, the fixtures ending in the states they name, and the committed
// `scenario-manifest.json` equal to the Swift manifest (`UPDATE_SCENARIO_MANIFEST=1`, on the simulator
// `TEST_RUNNER_UPDATE_SCENARIO_MANIFEST=1`, rewrites it).
import Foundation
import Testing
@testable import DigitalAquariumExperience
import DigitalAquariumCore
import VisualCoreExperience
import VisualCoreMath

private let id = ExperienceID(rawValue: AquariumCore.experienceID)!

/// What playing `spec` on a fresh engine gives, as the runner plays it.
private func play(_ spec: ScenarioSpec) async throws -> (initial: String, results: [String], final: String) {
    var engine = ExperienceEngine<AquariumCore>(id: id)
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

@Suite struct AquariumManifestTests {
    @Test func theManifestIsValidWithTheNineStandardScenariosAndThirteenFixtures() {
        let manifest = AquariumCore.manifest(for: id)
        let problems = ScenarioManifestValidator.problems(manifest, controls: AquariumCore.controls,
                                                          content: ContentRequirement(fixtures: 13))
        #expect(problems.isEmpty, "\(problems)")
        #expect(Set(manifest.scenarios.map(\.name))
                == Set(ScenarioManifest.standardNames).union((1...13).map { "fixture-\($0)" }))
    }

    @Test func derivedDigestsAndResultsAreWhatTheEngineGives() async throws {
        let manifest = AquariumCore.manifest(for: id)
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
    }

    @Test func theFixturesEndInTheStatesTheyName() {
        let seed = AquariumCore.manifestSeed
        let fixtures = AquariumCore.fixtureEntries
        let catalog = SpeciesCatalog.bundled

        // 1. Swim bounds: every fish inside after 600 steps.
        let bounds = AquariumCore.played(seed: seed, entries: fixtures[0]).state.document
        #expect(bounds.habitatIndex == 0)
        for fish in bounds.fish {
            #expect(fish.position.x >= bounds.bounds.minX && fish.position.x <= bounds.bounds.maxX)
            #expect(fish.position.y >= bounds.bounds.minY && fish.position.y <= bounds.bounds.maxY)
        }

        // 2. Kelp at bright lighting.
        let kelp = AquariumCore.played(seed: seed, entries: fixtures[1]).state
        #expect(kelp.document.habitatIndex == 1 && kelp.document.lighting == 2)

        // 3. Paused: 300 more steps leave the fish where they were.
        let paused = AquariumCore.played(seed: seed, entries: Array(fixtures[2].prefix(1))).state
        let later = AquariumCore.played(seed: seed, entries: fixtures[2]).state
        #expect(later.paused)
        #expect(later.document.fish == paused.document.fish, "no motion while paused")

        // 4. Both habitats come from the validated catalog.
        #expect(LicenseAudit.problems(catalog).isEmpty)
        #expect(AquariumCore.played(seed: seed, entries: fixtures[3]).state.document.habitatIndex == 0)

        // 5. Bounded counts after five switches: the Kelp habitat's own fish and plant counts.
        let switched = AquariumCore.played(seed: seed, entries: fixtures[4]).state.document
        let kelpHabitat = catalog.habitats[1]
        #expect(switched.fish.count == kelpHabitat.species.reduce(0) { $0 + $1.count })
        #expect(switched.plants.count == kelpHabitat.plants.count)
        #expect(switched.fish.count <= 24 && switched.plants.count <= 12)

        // 6. Schooling: after 30 s same-species fish are closer than at the start and than other species, heading
        //    alike (SC-A09-201, 202 for this seed; the 20-seed counts are proved by `SchoolingTests`).
        let start = AquariumCore.played(seed: seed, entries: Array(fixtures[5].prefix(1))).state.document
        let schooled = AquariumCore.played(seed: seed, entries: fixtures[5]).state.document
        let same0 = try? #require(SchoolMetrics.meanSameSpeciesDistance(start))
        let same = SchoolMetrics.meanSameSpeciesDistance(schooled) ?? .infinity
        let cross = SchoolMetrics.meanCrossSpeciesDistance(schooled) ?? 0
        #expect(same <= 0.6 * (same0 ?? 0) && same < cross, "same \(same) from \(same0 ?? 0), cross \(cross)")
        #expect((SchoolMetrics.headingAgreement(schooled) ?? 0) >= 0.7)

        // 7. Save/load: the Kelp habitat at bright lighting with its starter decor survives a snapshot round trip.
        let saved = AquariumCore.played(seed: seed, entries: fixtures[6])
        #expect(saved.document.habitatIndex == 1 && saved.document.lighting == 2)
        #expect(saved.document.decor == catalog.habitats[1].decor.map(DecorPlacement.init))
        let restored = try? AquariumCore.restore(payload: saved.snapshotPayload(), seed: seed)
        #expect(restored?.state == saved.state)

        // 8. Feeding: after the feed, at least one pellet is eaten (removed while still above the floor).
        let feedIndex = 2
        var fed = AquariumCore.played(seed: seed, entries: Array(fixtures[7].prefix(feedIndex + 1)))
        #expect(fed.document.food.count == Feeding.pelletsPerFeed)
        var eaten = 0
        for s in 0..<600 {
            let before = fed.document.food
            let floor = fed.document.bounds.minY
            fed.update(step: 305 + s)
            let floored = before.filter { $0.position.y - Feeding.sinkSpeed * AquariumSimulation.step <= floor }.count
            eaten += max(0, before.count - fed.document.food.count - floored)
        }
        #expect(eaten >= 1, "no pellet was eaten")
        #expect(fed.document.food.allSatisfy { $0.position.y > fed.document.bounds.minY })

        // 9. Decor editing: the Reef's starter decor with piece 0 moved, piece 1 removed and a piece of kind 1 placed.
        let edited = AquariumCore.played(seed: seed, entries: fixtures[8]).state
        var expected = catalog.habitats[0].decor.map(DecorPlacement.init)
        expected.append(DecorPlacement(kindId: catalog.decor[1].id, position: Vec2(4, 1.8)))
        expected[0].position = Vec2(12, 0.3 * 9)
        expected.remove(at: 1)
        #expect(edited.decorKind == 1)
        #expect(edited.document.decor.map(\.kindId) == expected.map(\.kindId))
        for (a, b) in zip(edited.document.decor, expected) {
            #expect(abs(a.position.x - b.position.x) < 1e-9 && abs(a.position.y - b.position.y) < 1e-9)
        }

        // 10. No fast-forward with food: 5 steps, a feed, 60 steps; uneaten pellets have sunk by exactly one second of
        //     motion (60 steps × 1/60 s × 0.5 units/s), no more.
        let dropped = AquariumCore.played(seed: seed, entries: Array(fixtures[9].prefix(1))).state
        let early = AquariumCore.played(seed: seed, entries: fixtures[9]).state
        #expect(early.step == 65)

        // 11. Water effects: at the final step the Reef's vents give at most 48 bubbles, between the vents and the
        //     surface (drawn from the step count; the state never holds them).
        let watered = AquariumCore.played(seed: seed, entries: fixtures[10]).state
        let bubbles = WaterEffects.bubbles(step: watered.step, vents: catalog.habitats[0].vents, reduceMotion: false)
        #expect(!bubbles.isEmpty && bubbles.count <= WaterEffects.maxBubbles)
        #expect(bubbles.allSatisfy { $0.y >= WaterEffects.ventY && $0.y < WaterEffects.surface })

        // 12. Ambient: the state holds ambient on, and the fish are slower than the same run without it.
        let calm = AquariumCore.played(seed: seed, entries: fixtures[11])
        let plain = AquariumCore.played(seed: seed, entries: [ScenarioStep(steps: 5), ScenarioStep(steps: 600)])
        func mean(_ core: AquariumCore) -> Double {
            core.document.fish.map(\.velocity.length).reduce(0, +) / Double(max(core.document.fish.count, 1))
        }
        #expect(calm.ambient && !plain.ambient)
        #expect(mean(calm) < mean(plain))

        // 13. Long run: 2,000 steps with a feed every 100 keep the fish count and every limit.
        let long = AquariumCore.played(seed: seed, entries: fixtures[12])
        #expect(long.step == 2_000)
        #expect(long.document.fish.count == AquariumCore(seed: seed).document.fish.count)
        #expect(long.document.food.count <= Feeding.maxPellets)
        #expect(long.document.validate(catalog: catalog).isEmpty)
        #expect(dropped.document.food.count == Feeding.pelletsPerFeed)
        for pellet in early.document.food {
            #expect(dropped.document.food.contains { abs($0.position.x - pellet.position.x) < 1e-12
                && abs($0.position.y - Feeding.sinkSpeed - pellet.position.y) < 1e-9 })
        }
    }

    /// The JSON form with the control ids, named by `Catalog/registrations.json`. `UPDATE_SCENARIO_MANIFEST=1`
    /// rewrites it.
    @Test func theCommittedManifestFileMatches() throws {
        let file = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("scenario-manifest.json")
        let manifest = AquariumCore.manifest(for: id)
        var object = try #require(try JSONSerialization.jsonObject(with: manifest.encoded()) as? [String: Any])
        object["controls"] = AquariumCore.controls.map(\.id)
        let data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys, .prettyPrinted])
            + Data("\n".utf8)
        if ProcessInfo.processInfo.environment["UPDATE_SCENARIO_MANIFEST"] == "1" { try data.write(to: file) }
        #expect(try Data(contentsOf: file) == data, "run with UPDATE_SCENARIO_MANIFEST=1 and commit the file")
    }
}
