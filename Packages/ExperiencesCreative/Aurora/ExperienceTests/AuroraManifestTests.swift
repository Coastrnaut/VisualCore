// AuroraManifestTests — feature 153 (A21-P02) T-A21-208 (FR-A21-201, FR-A21-202). The scenario manifest of Aurora:
// valid with the nine standard scenarios and the five fixtures; its derived digests, results and outcomes equal to
// what the engine gives when the runner plays them; every fixture ending in the state its actions describe; and the
// committed `scenario-manifest.json` equal to the Swift manifest (`UPDATE_SCENARIO_MANIFEST=1`, on the simulator
// `TEST_RUNNER_UPDATE_SCENARIO_MANIFEST=1`, rewrites it).
import Foundation
import Testing
import AuroraCore
@testable import AuroraExperience
import VisualCoreExperience

private let manifestID = ExperienceID(rawValue: SkyCore.experienceID)!

/// What playing `spec` on a fresh engine gives, as the runner plays it.
private func playManifest(_ spec: ScenarioSpec) async throws -> (initial: String, results: [String], final: String,
                                                                 core: SkyCore?) {
    var engine = ExperienceEngine<SkyCore>(id: manifestID)
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

@Suite struct AuroraManifestTests {
    /// The names of the five fixtures.
    static let fixtureNames = ["fixture-polar-night", "fixture-violet-veil", "fixture-dawn-haze", "fixture-tuned",
                               "fixture-low-limit"]

    @Test func theManifestIsValidWithTheStandardScenariosAndFiveFixtures() {
        let manifest = SkyCore.manifest(for: manifestID)
        let problems = ScenarioManifestValidator.problems(manifest, controls: SkyCore.controls,
                                                          content: ContentRequirement(fixtures: 5))
        #expect(problems.isEmpty, "\(problems)")
        #expect(manifest.scenarios.map(\.name) == ScenarioManifest.standardNames + Self.fixtureNames)
        #expect(SkyCore.fixtures.map(\.name) == Self.fixtureNames)
        #expect(manifest.kind == .creative)
        #expect(manifest.experience == manifestID)
        #expect(manifest.scenarios.allSatisfy { $0.seed == SkyCore.manifestSeed })
    }

    @Test func derivedDigestsResultsAndOutcomesAreWhatTheEngineGives() async throws {
        let manifest = SkyCore.manifest(for: manifestID)
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

    @Test func theSaveRestoreStateSurvivesARestore() async throws {
        let manifest = SkyCore.manifest(for: manifestID)
        let spec = try #require(manifest.scenarios.first { $0.name == "save-restore" })
        let played = try await playManifest(spec)
        let core = try #require(played.core)
        let restored = try SkyCore.restore(payload: core.snapshotPayload(), seed: spec.seed)
        #expect(try skyDigest(restored) == played.final)
    }

    @Test func everyFixtureEndsInTheStateItsActionsDescribe() async throws {
        let manifest = SkyCore.manifest(for: manifestID)
        for fixture in SkyCore.fixtures {
            let spec = try #require(manifest.scenarios.first { $0.name == fixture.name })
            let played = try await playManifest(spec)
            let core = try #require(played.core, "\(fixture.name)")
            switch fixture.name {
            case "fixture-polar-night":
                #expect(core.scene == SkyPresets.polarNight.scene && core.presetIndex == 0)
                #expect(core.hue == 0 && core.limit == SkyCore.defaultLimit)
            case "fixture-violet-veil":
                #expect(core.scene == SkyPresets.violetVeil.scene && core.presetIndex == 1)
                #expect(core.hue == 0 && core.limit == SkyCore.defaultLimit)
            case "fixture-dawn-haze":
                #expect(core.scene == SkyPresets.dawnHaze.scene && core.presetIndex == 2)
                #expect(core.hue == 0 && core.limit == SkyCore.defaultLimit)
            case "fixture-tuned":
                #expect(core.scene.preset == "polar-night" && core.hue == 0.25 && core.scene.speed == 1.5)
                #expect(core.scene.ribbons == 4 && core.scene.stars == 100 && core.scene.cloudiness == 0.5)
                #expect(core.scene.turbulence == SkyPresets.polarNight.scene.turbulence)
                #expect(core.limit == SkyCore.defaultLimit)
            case "fixture-low-limit":
                #expect(core.scene == SkyPresets.polarNight.scene && core.hue == 0 && core.limit == 0.2)
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
        let manifest = SkyCore.manifest(for: manifestID)
        var object = try #require(try JSONSerialization.jsonObject(with: manifest.encoded()) as? [String: Any])
        object["controls"] = SkyCore.controls.map(\.id)
        let data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys, .prettyPrinted])
            + Data("\n".utf8)
        if ProcessInfo.processInfo.environment["UPDATE_SCENARIO_MANIFEST"] == "1" { try data.write(to: file) }
        #expect(try Data(contentsOf: file) == data, "run with UPDATE_SCENARIO_MANIFEST=1 and commit the file")
    }
}
