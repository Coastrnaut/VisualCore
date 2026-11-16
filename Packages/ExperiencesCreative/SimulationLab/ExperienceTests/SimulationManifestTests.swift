// SimulationManifestTests — feature 117 (A16-P01) T-A16-107 (FR-A16-131). The scenario manifest of Simulation Lab:
// valid with the nine standard scenarios and the three family fixtures `fixture-automaton`,
// `fixture-reaction-diffusion` and `fixture-wave`; its derived digests and expected results equal to what the engine gives when the runner plays them;
// every fixture choosing its family by `sim.family` and ending paused with the committed final digest (a mismatch
// prints `derived <hex>`, the value to pin in ``SimulationCore/familyFixtures``); and the committed
// `scenario-manifest.json` equal to the Swift manifest (`UPDATE_SCENARIO_MANIFEST=1`, on the simulator
// `TEST_RUNNER_UPDATE_SCENARIO_MANIFEST=1`, rewrites it).
import Foundation
import Testing
@testable import SimulationLabExperience
import SimulationLabCore
import VisualCoreExperience

private let id = ExperienceID(rawValue: SimulationCore.experienceID)!

/// What playing `spec` on a fresh engine gives, as the runner plays it.
private func play(_ spec: ScenarioSpec) async throws -> (initial: String, results: [String], final: String,
                                                         core: SimulationCore?) {
    var engine = ExperienceEngine<SimulationCore>(id: id)
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
    return (initial, results, try engine.digest().hex, engine.core)
}

@Suite struct SimulationManifestTests {
    /// The names of the three fixtures.
    static let fixtureNames = ["fixture-automaton", "fixture-reaction-diffusion", "fixture-wave",
                               "fixture-automaton-highlife", "fixture-reaction-mazes"]

    @Test func theManifestIsValidWithTheStandardScenariosAndFiveFixtures() {
        let manifest = SimulationCore.manifest(for: id)
        let problems = ScenarioManifestValidator.problems(manifest, controls: SimulationCore.controls,
                                                          content: ContentRequirement(fixtures: 5))
        #expect(problems.isEmpty, "\(problems)")
        #expect(manifest.scenarios.map(\.name) == ScenarioManifest.standardNames + Self.fixtureNames)
        #expect(SimulationCore.familyFixtures.map(\.name) == Self.fixtureNames)
        #expect(manifest.kind == .creative)
        #expect(manifest.experience == id)
        #expect(manifest.scenarios.allSatisfy { $0.seed == SimulationCore.manifestSeed })
    }

    @Test func derivedDigestsAndResultsAreWhatTheEngineGives() async throws {
        let manifest = SimulationCore.manifest(for: id)
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
            if let outcome = spec.expect.outcome {
                #expect(played.core?.outcome?.code == outcome, "\(spec.name)")
            }
        }
        let completion = try #require(manifest.scenarios.first { $0.name == "completion" })
        #expect(completion.expect.outcome == "simulating-wave")
        #expect(SimulationCore.played(seed: completion.seed, entries: completion.entries).outcome?.code
                == completion.expect.outcome)
        let input = SimulationCore.played(seed: SimulationCore.manifestSeed, entries: SimulationCore.inputEntries)
        #expect(input.kind == .reactionDiffusion && input.preset == 1 && input.speedIndex == 3)
        #expect(!input.isRunning, "the input ends paused")
        #expect(input.stepCount == 121, "40 iterations at ×1, 80 at ×2 and one step by hand")
    }

    @Test func everyFixtureChoosesItsFamilyWithTheCommittedDigest() async throws {
        let manifest = SimulationCore.manifest(for: id)
        let kinds: [SimulationKind] = [.automaton, .reactionDiffusion, .wave, .automaton, .reactionDiffusion]
        let stepCounts = [21, 121, 61, 21, 121]
        #expect(SimulationCore.familyFixtures.map(\.family) == [0, 1, 2, 0, 1])
        #expect(Set(SimulationCore.familyFixtures.map(\.digest)).count == 5)
        for (index, fixture) in SimulationCore.familyFixtures.enumerated() {
            let spec = try #require(manifest.scenarios.first { $0.name == fixture.name })
            #expect(spec.expect.finalDigest == fixture.digest, "\(fixture.name)")
            #expect(spec.expect.outcome == SimulationCore.outcomeCode(kinds[index]), "\(fixture.name)")
            let derived = SimulationCore.expectedDigest(for: id, seed: SimulationCore.manifestSeed,
                                                        entries: fixture.entries)
            #expect(derived == fixture.digest, "\(fixture.name): derived \(derived ?? "nil")")
            let played = try await play(spec)
            #expect(played.final == fixture.digest, "\(fixture.name): derived \(played.final)")
            let core = try #require(played.core)
            #expect(core.kind == kinds[index], "\(fixture.name)")
            #expect(!core.isRunning, "\(fixture.name) ends paused")
            #expect(core.stepCount == stepCounts[index], "\(fixture.name)")
            let controls = spec.entries.compactMap { $0.action?.control }
            #expect(controls.first == "sim.family", "\(fixture.name): chosen by the action")
        }
    }

    /// The JSON form with the control ids, named by `Catalog/registrations.json`. `UPDATE_SCENARIO_MANIFEST=1`
    /// (on the simulator `TEST_RUNNER_UPDATE_SCENARIO_MANIFEST=1`) rewrites it.
    @Test func theCommittedManifestFileMatches() throws {
        let file = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("scenario-manifest.json")
        let manifest = SimulationCore.manifest(for: id)
        var object = try #require(try JSONSerialization.jsonObject(with: manifest.encoded()) as? [String: Any])
        object["controls"] = SimulationCore.controls.map(\.id)
        let data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys, .prettyPrinted])
            + Data("\n".utf8)
        if ProcessInfo.processInfo.environment["UPDATE_SCENARIO_MANIFEST"] == "1" { try data.write(to: file) }
        #expect(try Data(contentsOf: file) == data, "run with UPDATE_SCENARIO_MANIFEST=1 and commit the file")
    }
}
