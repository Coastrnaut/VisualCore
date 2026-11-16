// MoleculeManifestTests — feature 110 (A15-P01) T-A15-108 (FR-A15-132; clarification Q5). The scenario manifest of
// Molecular Explorer: valid with the nine standard scenarios and the five fixtures `fixture-water`, `fixture-methane`,
// `fixture-ethanol`, `fixture-benzene` and `fixture-caffeine`; its derived digests and expected results equal to what
// the engine gives when the runner plays them; every fixture selecting its molecule by `molecule.select` with the committed
// final digest; and the committed `scenario-manifest.json` equal to the Swift manifest (`UPDATE_SCENARIO_MANIFEST=1`,
// on the simulator `TEST_RUNNER_UPDATE_SCENARIO_MANIFEST=1`, rewrites it).
import Foundation
import Testing
@testable import MolecularExplorerExperience
import MolecularExplorerCore
import VisualCoreExperience

private let id = ExperienceID(rawValue: MoleculeCore.experienceID)!

/// What playing `spec` on a fresh engine gives, as the runner plays it.
private func play(_ spec: ScenarioSpec) async throws -> (initial: String, results: [String], final: String,
                                                         core: MoleculeCore?) {
    var engine = ExperienceEngine<MoleculeCore>(id: id)
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

@Suite struct MoleculeManifestTests {
    /// The names of the five fixtures.
    static let fixtureNames = ["fixture-water", "fixture-methane", "fixture-ethanol", "fixture-benzene",
                               "fixture-caffeine"]

    @Test func theManifestIsValidWithTheStandardScenariosAndFiveFixtures() {
        let manifest = MoleculeCore.manifest(for: id)
        let problems = ScenarioManifestValidator.problems(manifest, controls: MoleculeCore.controls,
                                                          content: ContentRequirement(fixtures: 5))
        #expect(problems.isEmpty, "\(problems)")
        #expect(manifest.scenarios.map(\.name) == ScenarioManifest.standardNames + Self.fixtureNames)
        #expect(MoleculeCore.selectedFixtures.map { MoleculeCore.fixtureName(molecule: $0.molecule) } == Self.fixtureNames)
        #expect(manifest.kind == .creative)
        #expect(manifest.experience == id)
        #expect(manifest.scenarios.allSatisfy { $0.seed == MoleculeCore.manifestSeed })
    }

    @Test func derivedDigestsAndResultsAreWhatTheEngineGives() async throws {
        let manifest = MoleculeCore.manifest(for: id)
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
        #expect(completion.expect.outcome == "viewing-caffeine")
        #expect(MoleculeCore.played(seed: completion.seed, entries: completion.entries).outcome?.code
                == completion.expect.outcome)
    }

    @Test func everyFixtureSelectsItsMoleculeWithTheCommittedDigest() async throws {
        let manifest = MoleculeCore.manifest(for: id)
        #expect(MoleculeCore.selectedFixtures.map(\.molecule) == [0, 1, 2, 3, 4])
        #expect(Set(MoleculeCore.selectedFixtures.map(\.digest)).count == 5)
        let moleculeIDs: [String] = ["water", "methane", "ethanol", "benzene", "caffeine"]
        for (fixture, moleculeID) in zip(MoleculeCore.selectedFixtures, moleculeIDs) {
            let name = MoleculeCore.fixtureName(molecule: fixture.molecule)
            let spec = try #require(manifest.scenarios.first { $0.name == name })
            #expect(spec.expect.finalDigest == fixture.digest, "\(name)")
            #expect(spec.expect.outcome == "viewing-" + moleculeID, "\(name)")
            let derived = MoleculeCore.expectedDigest(for: id, seed: MoleculeCore.manifestSeed,
                                                   entries: MoleculeCore.fixtureEntries(molecule: fixture.molecule))
            #expect(derived == fixture.digest, "\(name): derived \(derived ?? "nil")")
            let played = try await play(spec)
            #expect(played.final == fixture.digest, "\(name): \(played.final)")
            let core = try #require(played.core)
            #expect(core.selection == fixture.molecule, "\(name)")
            #expect(core.molecule?.id == moleculeID, "\(name)")
            let controls = Set(spec.entries.compactMap { $0.action?.control })
            #expect(controls == ["molecule.select"], "\(name): selected by the action")
        }
    }

    /// The JSON form with the control ids, named by `Catalog/registrations.json`. `UPDATE_SCENARIO_MANIFEST=1`
    /// (on the simulator `TEST_RUNNER_UPDATE_SCENARIO_MANIFEST=1`) rewrites it.
    @Test func theCommittedManifestFileMatches() throws {
        let file = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("scenario-manifest.json")
        let manifest = MoleculeCore.manifest(for: id)
        var object = try #require(try JSONSerialization.jsonObject(with: manifest.encoded()) as? [String: Any])
        object["controls"] = MoleculeCore.controls.map(\.id)
        let data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys, .prettyPrinted])
            + Data("\n".utf8)
        if ProcessInfo.processInfo.environment["UPDATE_SCENARIO_MANIFEST"] == "1" { try data.write(to: file) }
        #expect(try Data(contentsOf: file) == data, "run with UPDATE_SCENARIO_MANIFEST=1 and commit the file")
    }
}
