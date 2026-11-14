// AquariumManifestTests — feature 068 (A09-P01) T-A09-105 (FR-A09-122; SC-A09-105). The scenario manifest of Digital
// Aquarium: valid with the nine standard scenarios and the five fixtures of this phase (swim bounds, save/restore, no
// fast-forward while paused, both validated habitats, bounded counts), its derived digests and expected results equal
// to what the engine gives when the runner plays them, the fixtures ending in the states they name, and the committed
// `scenario-manifest.json` equal to the Swift manifest (`UPDATE_SCENARIO_MANIFEST=1`, on the simulator
// `TEST_RUNNER_UPDATE_SCENARIO_MANIFEST=1`, rewrites it).
import Foundation
import Testing
@testable import DigitalAquariumExperience
import DigitalAquariumCore
import VisualCoreExperience

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
    @Test func theManifestIsValidWithTheNineStandardScenariosAndFiveFixtures() {
        let manifest = AquariumCore.manifest(for: id)
        let problems = ScenarioManifestValidator.problems(manifest, controls: AquariumCore.controls,
                                                          content: ContentRequirement(fixtures: 5))
        #expect(problems.isEmpty, "\(problems)")
        #expect(Set(manifest.scenarios.map(\.name))
                == Set(ScenarioManifest.standardNames).union((1...5).map { "fixture-\($0)" }))
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
