// AmbientManifestTests — feature 132 (A18-P02) T-A18-208 (FR-A18-210; research D6). The scenario manifest of Ambient
// Clock: valid with the nine standard scenarios and the five fixtures (the planning catalog's content count); its
// derived digests, results and outcomes equal to what the engine gives when the runner plays them; every fixture
// ending in the format and theme its actions describe; and the committed `scenario-manifest.json` equal to the Swift
// manifest (`UPDATE_SCENARIO_MANIFEST=1`, on the simulator `TEST_RUNNER_UPDATE_SCENARIO_MANIFEST=1`, rewrites it).
import Foundation
import Testing
@testable import AmbientClockExperience
import VisualCoreExperience

private let manifestID = ExperienceID(rawValue: AmbientCore.experienceID)!

/// What playing `spec` on a fresh engine gives, as the runner plays it.
private func playManifest(_ spec: ScenarioSpec) async throws -> (initial: String, results: [String], final: String,
                                                                 core: AmbientCore?) {
    var engine = ExperienceEngine<AmbientCore>(id: manifestID)
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

@Suite struct AmbientManifestTests {
    /// The names of the seven fixtures (five of A18-P02, two themes of A18-P03).
    static let fixtureNames = ["fixture-time-zone-changed", "fixture-motion-off", "fixture-twenty-four-hour",
                               "fixture-seconds-shown", "fixture-slow-motion", "fixture-theme-waves",
                               "fixture-theme-shapes-palette"]

    @Test func theManifestIsValidWithTheStandardScenariosAndSevenFixtures() {
        let manifest = AmbientCore.manifest(for: manifestID)
        let problems = ScenarioManifestValidator.problems(manifest, controls: AmbientCore.controls,
                                                          content: ContentRequirement(fixtures: 7))
        #expect(problems.isEmpty, "\(problems)")
        #expect(manifest.scenarios.map(\.name) == ScenarioManifest.standardNames + Self.fixtureNames)
        #expect(AmbientCore.fixtures.map(\.name) == Self.fixtureNames)
        #expect(manifest.kind == .creative)
        #expect(manifest.experience == manifestID)
        #expect(manifest.scenarios.allSatisfy { $0.seed == AmbientCore.manifestSeed })
    }

    @Test func derivedDigestsResultsAndOutcomesAreWhatTheEngineGives() async throws {
        let manifest = AmbientCore.manifest(for: manifestID)
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

    @Test func everyFixtureEndsInTheStateItsActionsDescribe() async throws {
        let manifest = AmbientCore.manifest(for: manifestID)
        for fixture in AmbientCore.fixtures {
            let spec = try #require(manifest.scenarios.first { $0.name == fixture.name })
            let played = try await playManifest(spec)
            let core = try #require(played.core, "\(fixture.name)")
            switch fixture.name {
            case "fixture-time-zone-changed":
                #expect(core.instant == AmbientCore.fixtureInstant && core.revision == 1)
            case "fixture-motion-off":
                #expect(!core.motion)
            case "fixture-twenty-four-hour":
                #expect(core.hourCycle == 2 && !core.showSeconds && core.showDate)
            case "fixture-seconds-shown":
                #expect(core.hourCycle == 0 && core.showSeconds && core.showDate)
            case "fixture-slow-motion":
                #expect(core.speed == 0.25 && core.motion)
            case "fixture-theme-waves":
                #expect(core.theme == 2 && core.palette == 0)
            case "fixture-theme-shapes-palette":
                #expect(core.theme == 3 && core.palette == 2)
            default:
                Issue.record("unexpected fixture \(fixture.name)")
            }
        }
    }

    /// The JSON form with the control ids, named by `Catalog/registrations.json`. `UPDATE_SCENARIO_MANIFEST=1`
    /// (on the simulator `TEST_RUNNER_UPDATE_SCENARIO_MANIFEST=1`) rewrites it.
    @Test func theCommittedManifestFileMatches() throws {
        let file = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("scenario-manifest.json")
        let manifest = AmbientCore.manifest(for: manifestID)
        var object = try #require(try JSONSerialization.jsonObject(with: manifest.encoded()) as? [String: Any])
        object["controls"] = AmbientCore.controls.map(\.id)
        let data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys, .prettyPrinted])
            + Data("\n".utf8)
        if ProcessInfo.processInfo.environment["UPDATE_SCENARIO_MANIFEST"] == "1" { try data.write(to: file) }
        #expect(try Data(contentsOf: file) == data, "run with UPDATE_SCENARIO_MANIFEST=1 and commit the file")
    }
}
