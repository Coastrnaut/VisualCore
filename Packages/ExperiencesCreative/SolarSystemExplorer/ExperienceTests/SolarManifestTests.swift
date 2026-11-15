// SolarManifestTests — feature 103 (A14-P01) T-A14-105 (FR-A14-122; clarification Q5). The scenario manifest of Solar
// System Explorer: valid with the nine standard scenarios and the five fixtures `fixture-mercury`, `fixture-earth`,
// `fixture-jupiter`, `fixture-saturn` and `fixture-neptune`; its derived digests and expected results equal to what
// the engine gives when the runner plays them; every fixture selecting its body by `body.select` with the committed
// final digest; and the committed `scenario-manifest.json` equal to the Swift manifest (`UPDATE_SCENARIO_MANIFEST=1`,
// on the simulator `TEST_RUNNER_UPDATE_SCENARIO_MANIFEST=1`, rewrites it). Feature 104 (A14-P02) T-A14-209 adds the
// dated fixture `fixture-earth-2025` (Earth, then date steps to day 9,132) with its committed digest; feature 105
// (A14-P03) T-A14-309 the true-scale fixture `fixture-earth-true-scale`; feature 106 (A14-P04) T-A14-407 the
// fixtures `fixture-play-year` and `fixture-tour-inner`.
import Foundation
import Testing
@testable import SolarSystemExplorerExperience
import SolarSystemExplorerCore
import VisualCoreExperience

private let id = ExperienceID(rawValue: SolarCore.experienceID)!

/// What playing `spec` on a fresh engine gives, as the runner plays it.
private func play(_ spec: ScenarioSpec) async throws -> (initial: String, results: [String], final: String,
                                                         core: SolarCore?) {
    var engine = ExperienceEngine<SolarCore>(id: id)
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

@Suite struct SolarManifestTests {
    /// The names of the five fixtures.
    static let fixtureNames = ["fixture-mercury", "fixture-earth", "fixture-jupiter", "fixture-saturn",
                               "fixture-neptune"]

    @Test func theManifestIsValidWithTheStandardScenariosAndFiveFixtures() {
        let manifest = SolarCore.manifest(for: id)
        let problems = ScenarioManifestValidator.problems(manifest, controls: SolarCore.controls,
                                                          content: ContentRequirement(fixtures: 9))
        #expect(problems.isEmpty, "\(problems)")
        #expect(manifest.scenarios.map(\.name)
                == ScenarioManifest.standardNames + Self.fixtureNames
                + [SolarCore.datedFixtureName, "fixture-play-year", "fixture-tour-inner",
                   SolarCore.trueScaleFixtureName])
        #expect(SolarCore.selectedFixtures.map { SolarCore.fixtureName(body: $0.body) } == Self.fixtureNames)
        #expect(manifest.kind == .creative)
        #expect(manifest.experience == id)
        #expect(manifest.scenarios.allSatisfy { $0.seed == SolarCore.manifestSeed })
    }

    @Test func derivedDigestsAndResultsAreWhatTheEngineGives() async throws {
        let manifest = SolarCore.manifest(for: id)
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
        #expect(completion.expect.outcome == "viewing-earth")
        #expect(SolarCore.played(seed: completion.seed, entries: completion.entries).outcome?.code
                == completion.expect.outcome)
    }

    @Test func everyFixtureSelectsItsBodyWithTheCommittedDigest() async throws {
        let manifest = SolarCore.manifest(for: id)
        #expect(SolarCore.selectedFixtures.map(\.body) == [1, 3, 5, 6, 8])
        #expect(Set(SolarCore.selectedFixtures.map(\.digest)).count == 5)
        let bodyIDs: [String] = ["mercury", "earth", "jupiter", "saturn", "neptune"]
        for (fixture, bodyID) in zip(SolarCore.selectedFixtures, bodyIDs) {
            let name = SolarCore.fixtureName(body: fixture.body)
            let spec = try #require(manifest.scenarios.first { $0.name == name })
            #expect(spec.expect.finalDigest == fixture.digest, "\(name)")
            #expect(spec.expect.outcome == "viewing-" + bodyID, "\(name)")
            let derived = SolarCore.expectedDigest(for: id, seed: SolarCore.manifestSeed,
                                                   entries: SolarCore.fixtureEntries(body: fixture.body))
            #expect(derived == fixture.digest, "\(name): derived \(derived ?? "nil")")
            let played = try await play(spec)
            #expect(played.final == fixture.digest, "\(name): \(played.final)")
            let core = try #require(played.core)
            #expect(core.selection == fixture.body, "\(name)")
            #expect(core.body?.id == bodyID, "\(name)")
            let controls = Set(spec.entries.compactMap { $0.action?.control })
            #expect(controls == ["body.select"], "\(name): selected by the action")
        }
    }

    @Test func theDatedFixtureStepsTheDateWithTheCommittedDigest() async throws {
        let manifest = SolarCore.manifest(for: id)
        let spec = try #require(manifest.scenarios.first { $0.name == SolarCore.datedFixtureName })
        #expect(spec.expect.finalDigest == SolarCore.datedFixtureDigest)
        let derived = SolarCore.expectedDigest(for: id, seed: SolarCore.manifestSeed,
                                               entries: SolarCore.datedFixtureEntries)
        #expect(derived == SolarCore.datedFixtureDigest, "derived \(derived ?? "nil")")
        let played = try await play(spec)
        #expect(played.final == SolarCore.datedFixtureDigest, "played \(played.final)")
        let core = try #require(played.core)
        #expect(core.selection == 3 && core.state.dayOffset == 9_132)
        #expect(core.state.date.label == "2025-01-01")
        #expect(!SolarCore.selectedFixtures.map(\.digest).contains(SolarCore.datedFixtureDigest))
    }

    @Test func theTrueScaleFixtureSwitchesTheModeWithTheCommittedDigest() async throws {
        let manifest = SolarCore.manifest(for: id)
        let spec = try #require(manifest.scenarios.first { $0.name == SolarCore.trueScaleFixtureName })
        #expect(spec.expect.finalDigest == SolarCore.trueScaleFixtureDigest)
        let derived = SolarCore.expectedDigest(for: id, seed: SolarCore.manifestSeed,
                                               entries: SolarCore.trueScaleFixtureEntries)
        #expect(derived == SolarCore.trueScaleFixtureDigest, "derived \(derived ?? "nil")")
        let played = try await play(spec)
        #expect(played.final == SolarCore.trueScaleFixtureDigest, "played \(played.final)")
        let core = try #require(played.core)
        #expect(core.selection == 3 && core.state.scaleMode == .trueRelative)
        let earth = SolarCore.selectedFixtures.first { $0.body == 3 }?.digest
        #expect(earth != SolarCore.trueScaleFixtureDigest, "the mode changes the digest")
    }

    @Test func theTimeFixturesPlayAndTourWithTheirCommittedDigests() async throws {
        let manifest = SolarCore.manifest(for: id)
        for fixture in SolarCore.timeFixtures {
            let spec = try #require(manifest.scenarios.first { $0.name == fixture.name })
            #expect(spec.expect.finalDigest == fixture.digest, "\(fixture.name)")
            let derived = SolarCore.expectedDigest(for: id, seed: SolarCore.manifestSeed,
                                                   entries: SolarCore.timeFixtureEntries(fixture.name))
            #expect(derived == fixture.digest, "\(fixture.name): derived \(derived ?? "nil")")
            let played = try await play(spec)
            #expect(played.final == fixture.digest, "\(fixture.name): played \(played.final)")
            let core = try #require(played.core)
            if fixture.name == "fixture-play-year" {
                #expect(abs(core.state.dayOffset - 365) < 1e-9 && core.state.playing)
            } else {
                #expect(core.state.tourIndex == 0 && core.state.tourStop == 1 && core.selection == 1)
            }
        }
    }

    /// The JSON form with the control ids, named by `Catalog/registrations.json`. `UPDATE_SCENARIO_MANIFEST=1`
    /// (on the simulator `TEST_RUNNER_UPDATE_SCENARIO_MANIFEST=1`) rewrites it.
    @Test func theCommittedManifestFileMatches() throws {
        let file = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("scenario-manifest.json")
        let manifest = SolarCore.manifest(for: id)
        var object = try #require(try JSONSerialization.jsonObject(with: manifest.encoded()) as? [String: Any])
        object["controls"] = SolarCore.controls.map(\.id)
        let data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys, .prettyPrinted])
            + Data("\n".utf8)
        if ProcessInfo.processInfo.environment["UPDATE_SCENARIO_MANIFEST"] == "1" { try data.write(to: file) }
        #expect(try Data(contentsOf: file) == data, "run with UPDATE_SCENARIO_MANIFEST=1 and commit the file")
    }
}
