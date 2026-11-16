// AnatomyManifestTests — feature 125 (A17-P02) T-A17-207 (FR-A17-210). The scenario manifest of Interactive Anatomy:
// valid with the nine standard scenarios and the five fixtures (the planning catalog's content count)
// `fixture-femur-selected`, `fixture-ligaments-hidden`, `fixture-turned`, `fixture-bones-only` and
// `fixture-acl-zoomed`; its derived digests, results and outcomes equal to what the engine gives when the runner plays
// them; every fixture ending in the view state its actions describe; and the committed `scenario-manifest.json` equal
// to the Swift manifest (`UPDATE_SCENARIO_MANIFEST=1`, on the simulator `TEST_RUNNER_UPDATE_SCENARIO_MANIFEST=1`,
// rewrites it).
import Foundation
import Testing
@testable import InteractiveAnatomyExperience
import InteractiveAnatomyCore
import VisualCoreExperience

private let manifestID = ExperienceID(rawValue: AnatomyCore.experienceID)!

/// What playing `spec` on a fresh engine gives, as the runner plays it.
private func playManifest(_ spec: ScenarioSpec) async throws -> (initial: String, results: [String], final: String,
                                                                 core: AnatomyCore?) {
    var engine = ExperienceEngine<AnatomyCore>(id: manifestID)
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

@Suite struct AnatomyManifestTests {
    /// The names of the five fixtures.
    static let fixtureNames = ["fixture-femur-selected", "fixture-ligaments-hidden", "fixture-turned",
                               "fixture-bones-only", "fixture-acl-zoomed"]

    @Test func theManifestIsValidWithTheStandardScenariosAndFiveFixtures() {
        let manifest = AnatomyCore.manifest(for: manifestID)
        let problems = ScenarioManifestValidator.problems(manifest, controls: AnatomyCore.controls,
                                                          content: ContentRequirement(fixtures: 5))
        #expect(problems.isEmpty, "\(problems)")
        #expect(manifest.scenarios.map(\.name) == ScenarioManifest.standardNames + Self.fixtureNames)
        #expect(AnatomyCore.fixtures.map(\.name) == Self.fixtureNames)
        #expect(manifest.kind == .creative)
        #expect(manifest.experience == manifestID)
        #expect(manifest.scenarios.allSatisfy { $0.seed == AnatomyCore.manifestSeed })
    }

    @Test func derivedDigestsResultsAndOutcomesAreWhatTheEngineGives() async throws {
        let manifest = AnatomyCore.manifest(for: manifestID)
        #expect(manifest.scenarios.first { $0.name == "launch-first-frame" }?.expect.initialDigest != nil)
        for spec in manifest.scenarios {
            let played = try await playManifest(spec)
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
    }

    @Test func everyFixtureEndsInTheViewItsActionsDescribe() async throws {
        let manifest = AnatomyCore.manifest(for: manifestID)
        var digests: Set<String> = []
        for fixture in AnatomyCore.fixtures {
            let spec = try #require(manifest.scenarios.first { $0.name == fixture.name })
            let played = try await playManifest(spec)
            digests.insert(played.final)
            let view = try #require(played.core?.view, "\(fixture.name)")
            switch fixture.name {
            case "fixture-femur-selected":
                #expect(view.selection == "knee.femur" && view.framed == "knee.femur")
            case "fixture-ligaments-hidden":
                #expect(view.visibleLayers == [true, true, false] && view.selection == nil)
            case "fixture-turned":
                #expect(view.camera.turn == 5 && view.camera.tilt == 2 && view.camera.zoom == 0)
            case "fixture-bones-only":
                #expect(view.visibleLayers == [true, false, false])
            default:
                #expect(view.selection == "knee.acl" && view.framed == "knee.acl" && view.camera.zoom == 2)
            }
        }
        #expect(digests.count == 5, "the fixtures end in five different states")
    }

    /// The JSON form with the control ids, named by `Catalog/registrations.json`. `UPDATE_SCENARIO_MANIFEST=1`
    /// (on the simulator `TEST_RUNNER_UPDATE_SCENARIO_MANIFEST=1`) rewrites it.
    @Test func theCommittedManifestFileMatches() throws {
        let file = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("scenario-manifest.json")
        let manifest = AnatomyCore.manifest(for: manifestID)
        var object = try #require(try JSONSerialization.jsonObject(with: manifest.encoded()) as? [String: Any])
        object["controls"] = AnatomyCore.controls.map(\.id)
        let data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys, .prettyPrinted])
            + Data("\n".utf8)
        if ProcessInfo.processInfo.environment["UPDATE_SCENARIO_MANIFEST"] == "1" { try data.write(to: file) }
        #expect(try Data(contentsOf: file) == data, "run with UPDATE_SCENARIO_MANIFEST=1 and commit the file")
    }
}
