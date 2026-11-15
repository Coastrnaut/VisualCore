// WorldsManifestTests — feature 089 (A12-P01) T-A12-106 (FR-A12-112, FR-A12-122; SC-A12-101, SC-A12-106; research
// D5). The scenario manifest of Tiny Worlds: valid with the nine standard scenarios, the nine terrain fixtures
// `fixture-<preset>-<seed>` and the three refusal scenarios; its derived digests and expected results equal to what the
// engine gives when the runner plays them; every fixture's world generating its committed terrain digest (the same
// values as the core's `TerrainFixtureTests`); and the committed `scenario-manifest.json` equal to the Swift manifest
// (`UPDATE_SCENARIO_MANIFEST=1`, on the simulator `TEST_RUNNER_UPDATE_SCENARIO_MANIFEST=1`, rewrites it). Feature 091
// (A12-P03) T-A12-303 (FR-A12-302, FR-A12-323; SC-A12-301, SC-A12-302): the prop fixture `fixture-props-island-1` and
// four prop refusal scenarios follow; the fixture's props rest on the terrain and its final digest pins their exact
// transforms and the light. Feature 092 (A12-P04) T-A12-403 (FR-A12-404, FR-A12-407; SC-A12-401, SC-A12-405): the
// pack fixtures `fixture-pack-<pack>` (final digest the committed `WorldsCore.packFixtures` value) and
// `fixture-pack-reset` (edits, then the island pack again: the island pack's committed digest) follow.
import Foundation
import Testing
@testable import TinyWorldsExperience
import TinyWorldsCore
import VisualCoreExperience

private let id = ExperienceID(rawValue: WorldsCore.experienceID)!

/// What playing `spec` on a fresh engine gives, as the runner plays it.
private func play(_ spec: ScenarioSpec) async throws -> (initial: String, results: [String], final: String,
                                                         core: WorldsCore?) {
    var engine = ExperienceEngine<WorldsCore>(id: id)
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

@Suite struct WorldsManifestTests {
    /// The names of the nine fixtures.
    static let fixtureNames = WorldsCore.terrainFixtures.map { WorldsCore.fixtureName($0.preset, seed: $0.seed) }
    /// The names of the three refusal scenarios.
    static let refusalNames = ["refusal-preset-out-of-range", "refusal-preset-fractional", "refusal-zoom-out-of-range"]
    /// The prop fixture and the four prop refusal scenarios (feature 091).
    static let propNames = ["fixture-props-island-1", "refusal-prop-outside", "refusal-prop-under-water",
                            "refusal-prop-too-close", "refusal-prop-no-selection"]
    /// The three pack fixtures and the reset fixture (feature 092).
    static let packNames = ["fixture-pack-island", "fixture-pack-asteroid-garden", "fixture-pack-miniature-city",
                            "fixture-pack-reset"]

    @Test func theManifestIsValidWithTheStandardScenariosNineFixturesAndThreeRefusals() {
        let manifest = WorldsCore.manifest(for: id)
        let problems = ScenarioManifestValidator.problems(manifest, controls: WorldsCore.controls,
                                                          content: ContentRequirement(fixtures: 9))
        #expect(problems.isEmpty, "\(problems)")
        #expect(manifest.scenarios.map(\.name)
                == ScenarioManifest.standardNames + Self.fixtureNames + Self.refusalNames + Self.propNames
                + Self.packNames)
        #expect(Self.fixtureNames == [
            "fixture-island-1", "fixture-island-2", "fixture-island-3",
            "fixture-asteroid-garden-1", "fixture-asteroid-garden-2", "fixture-asteroid-garden-3",
            "fixture-miniature-city-1", "fixture-miniature-city-2", "fixture-miniature-city-3",
        ])
        #expect(manifest.kind == .creative)
        #expect(manifest.experience == id)
        #expect(manifest.scenarios.filter { ScenarioManifest.standardNames.contains($0.name) }
                .allSatisfy { $0.seed == WorldsCore.manifestSeed })
    }

    @Test func derivedDigestsAndResultsAreWhatTheEngineGives() async throws {
        let manifest = WorldsCore.manifest(for: id)
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
        #expect(completion.expect.outcome == "world-miniature-city")
        #expect(WorldsCore.played(seed: completion.seed, entries: completion.entries).outcome?.code
                == completion.expect.outcome)
        for name in Self.refusalNames + ["refusal-prop-outside", "refusal-prop-under-water",
                                         "refusal-prop-no-selection"] {
            let spec = try #require(manifest.scenarios.first { $0.name == name })
            #expect(spec.expect.finalDigest == spec.expect.initialDigest, "\(name) changes nothing")
        }
    }

    @Test func thePropFixturePinsExactTransformsOnTheTerrain() async throws {
        let manifest = WorldsCore.manifest(for: id)
        let spec = try #require(manifest.scenarios.first { $0.name == "fixture-props-island-1" })
        let played = try await play(spec)
        let core = try #require(played.core)
        #expect(core.props.map(\.kind) == [.tree, .house])
        #expect(core.props[0].x == 0.5 && core.props[0].z == -0.5)
        #expect(core.props[0].rotation == Double.pi / 4)
        #expect(core.props[1].x == 1.5 && core.props[1].z == 0.5 && core.props[1].rotation == 0)
        #expect(core.selection == -1, "the deleted rock's selection cleared")
        #expect(core.light == WorldLight(azimuth: 120, elevation: 30, ambient: 0.2))
        let field = try #require(WorldEditing.groundField(of: core.state))
        for prop in core.props {
            #expect(abs(prop.y - WorldEditing.groundHeight(field: field, x: prop.x, z: prop.z)) < 1e-3)
        }
        #expect(spec.expect.finalDigest == played.final)
        #expect(spec.expect.finalDigest != spec.expect.initialDigest)
    }

    @Test func everyFixtureGeneratesItsCommittedTerrainDigest() async throws {
        let manifest = WorldsCore.manifest(for: id)
        #expect(WorldsCore.terrainFixtures.count == 9)
        #expect(Set(WorldsCore.terrainFixtures.map(\.digest)).count == 9)
        for fixture in WorldsCore.terrainFixtures {
            let name = WorldsCore.fixtureName(fixture.preset, seed: fixture.seed)
            let spec = try #require(manifest.scenarios.first { $0.name == name })
            #expect(spec.seed == UInt64(fixture.seed), "\(name) is prepared with its seed")
            let played = try await play(spec)
            let core = try #require(played.core)
            #expect(core.preset.id == fixture.preset, "\(name)")
            #expect(core.seed == fixture.seed, "\(name)")
            #expect(core.terrainDigest == fixture.digest, "\(name): \(core.terrainDigest)")
            #expect(try TerrainGenerator.digest(preset: WorldPreset.preset(fixture.preset), seed: fixture.seed)
                    == fixture.digest, "\(name)")
            #expect(spec.expect.finalDigest == played.final, "\(name): the final digest pins the terrain")
        }
    }

    @Test func thePackFixturesPinTheCommittedDigests() async throws {
        let manifest = WorldsCore.manifest(for: id)
        for fixture in WorldsCore.packFixtures {
            let name = WorldsCore.packFixtureName(fixture.pack)
            let spec = try #require(manifest.scenarios.first { $0.name == name })
            #expect(spec.seed == WorldsCore.manifestSeed)
            #expect(spec.expect.finalDigest == fixture.digest, "\(name)")
            let played = try await play(spec)
            #expect(played.final == fixture.digest, "\(name): \(played.final)")
            let core = try #require(played.core)
            let pack = WorldPack.pack(for: fixture.pack)
            #expect(core.props.count == pack.props.count, "\(name)")
            #expect(core.selection == WorldState.noSelection)
            #expect(core.preset.id == fixture.pack)
        }
        let reset = try #require(manifest.scenarios.first { $0.name == "fixture-pack-reset" })
        #expect(reset.entries.first?.action?.control == "world.pack")
        #expect(reset.entries.last?.action?.control == "world.pack")
        let controls = Set(reset.entries.compactMap { $0.action?.control })
        #expect(controls.isSuperset(of: ["prop.move", "light.azimuth", "light.elevation", "light.ambient",
                                         "world.seed"]))
        let played = try await play(reset)
        #expect(played.final == WorldsCore.packFixtures[0].digest, "reset to pack: \(played.final)")
        #expect(reset.expect.finalDigest == WorldsCore.packFixtures[0].digest)
    }

    /// The JSON form with the control ids, named by `Catalog/registrations.json`. `UPDATE_SCENARIO_MANIFEST=1`
    /// rewrites it.
    @Test func theCommittedManifestFileMatches() throws {
        let file = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("scenario-manifest.json")
        let manifest = WorldsCore.manifest(for: id)
        var object = try #require(try JSONSerialization.jsonObject(with: manifest.encoded()) as? [String: Any])
        object["controls"] = WorldsCore.controls.map(\.id)
        let data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys, .prettyPrinted])
            + Data("\n".utf8)
        if ProcessInfo.processInfo.environment["UPDATE_SCENARIO_MANIFEST"] == "1" { try data.write(to: file) }
        #expect(try Data(contentsOf: file) == data, "run with UPDATE_SCENARIO_MANIFEST=1 and commit the file")
    }
}
