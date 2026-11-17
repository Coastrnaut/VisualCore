// WallpaperManifestTests — feature 139 (A19-P02) T-A19-212 (FR-A19-206; clarification Q5). The scenario manifest of
// Living Wallpapers: valid with the nine standard scenarios and the five fixtures (the planning catalog's content
// count); its derived digests, results and outcomes equal to what the engine gives when the runner plays them; every
// fixture ending in the state its actions describe; and the committed `scenario-manifest.json` equal to the Swift
// manifest (`UPDATE_SCENARIO_MANIFEST=1`, on the simulator `TEST_RUNNER_UPDATE_SCENARIO_MANIFEST=1`, rewrites it).
import Foundation
import Testing
@testable import LivingWallpapersExperience
import VisualCoreExperience

private let manifestID = ExperienceID(rawValue: WallpaperCore.experienceID)!

/// What playing `spec` on a fresh engine gives, as the runner plays it.
private func playManifest(_ spec: ScenarioSpec) async throws -> (initial: String, results: [String], final: String,
                                                                 core: WallpaperCore?) {
    var engine = ExperienceEngine<WallpaperCore>(id: manifestID)
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

@Suite struct WallpaperManifestTests {
    /// The names of the five fixtures.
    static let fixtureNames = ["fixture-scene-ink-flow", "fixture-preset-third", "fixture-template-ipad-landscape",
                               "fixture-time-set", "fixture-parameter-changed"]

    @Test func theManifestIsValidWithTheStandardScenariosAndFiveFixtures() {
        let manifest = WallpaperCore.manifest(for: manifestID)
        let problems = ScenarioManifestValidator.problems(manifest, controls: WallpaperCore.controls,
                                                          content: ContentRequirement(fixtures: 5))
        #expect(problems.isEmpty, "\(problems)")
        #expect(manifest.scenarios.map(\.name) == ScenarioManifest.standardNames + Self.fixtureNames)
        #expect(WallpaperCore.fixtures.map(\.name) == Self.fixtureNames)
        #expect(manifest.kind == .creative)
        #expect(manifest.experience == manifestID)
        #expect(manifest.scenarios.allSatisfy { $0.seed == WallpaperCore.manifestSeed })
    }

    @Test func derivedDigestsResultsAndOutcomesAreWhatTheEngineGives() async throws {
        let manifest = WallpaperCore.manifest(for: manifestID)
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
        let manifest = WallpaperCore.manifest(for: manifestID)
        for fixture in WallpaperCore.fixtures {
            let spec = try #require(manifest.scenarios.first { $0.name == fixture.name })
            let played = try await playManifest(spec)
            let core = try #require(played.core, "\(fixture.name)")
            switch fixture.name {
            case "fixture-scene-ink-flow":
                #expect(core.scene == 1 && core.preset == 0 && core.parameters == [0.8, 1.5, 0.25])
            case "fixture-preset-third":
                #expect(core.scene == 0 && core.preset == 2)
            case "fixture-template-ipad-landscape":
                #expect(core.templateDefinition.id == "ipad-pro-13-m4" && core.orientationValue == .landscape)
            case "fixture-time-set":
                #expect(core.animationTime == 42.5 && core.motion)
            case "fixture-parameter-changed":
                #expect(core.parameters == [6, 0.35, 0.6])
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
        let manifest = WallpaperCore.manifest(for: manifestID)
        var object = try #require(try JSONSerialization.jsonObject(with: manifest.encoded()) as? [String: Any])
        object["controls"] = WallpaperCore.controls.map(\.id)
        let data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys, .prettyPrinted])
            + Data("\n".utf8)
        if ProcessInfo.processInfo.environment["UPDATE_SCENARIO_MANIFEST"] == "1" { try data.write(to: file) }
        #expect(try Data(contentsOf: file) == data, "run with UPDATE_SCENARIO_MANIFEST=1 and commit the file")
    }
}
