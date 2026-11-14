// OdysseyManifestTests — feature 054 (A07-P01) T-A07-106 (FR-A07-120). The scenario manifest of Audio Odyssey: valid
// with the nine standard scenarios and the two fixtures of this phase (watertight joins, comfort limits), its derived
// digests and expected results equal to what the engine gives when the runner plays them, and the committed
// `scenario-manifest.json` equal to the Swift manifest (`UPDATE_SCENARIO_MANIFEST=1`, on the simulator
// `TEST_RUNNER_UPDATE_SCENARIO_MANIFEST=1`, rewrites it, as for Music Lab).
// Feature 055 (A07-P02) T-A07-207: fixture 3 switches sources (permission mirrored as denied, microphone refused by
// the rule, demo again) while flying; the switches change neither distance nor speed.
import Foundation
import Testing
@testable import AudioOdysseyExperience
import AudioOdysseyCore
import VisualCoreExperience

private let id = ExperienceID(rawValue: OdysseyCore.experienceID)!

/// What playing `spec` on a fresh engine gives, as the runner plays it.
private func play(_ spec: ScenarioSpec) async throws -> (initial: String, results: [String], final: String) {
    var engine = ExperienceEngine<OdysseyCore>(id: id)
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

@Suite struct OdysseyManifestTests {
    @Test func theManifestIsValidWithTheNineStandardScenariosAndFiveFixtures() {
        let manifest = OdysseyCore.manifest(for: id)
        let problems = ScenarioManifestValidator.problems(manifest, controls: OdysseyCore.controls,
                                                          content: ContentRequirement(fixtures: 5))
        #expect(problems.isEmpty, "\(problems)")
        #expect(Set(manifest.scenarios.map(\.name))
                == Set(ScenarioManifest.standardNames).union((1...5).map { "fixture-\($0)" }))
    }

    @Test func derivedDigestsAndResultsAreWhatTheEngineGives() async throws {
        let manifest = OdysseyCore.manifest(for: id)
        #expect(manifest.scenarios.first { $0.name == "launch-first-frame" }?.expect.initialDigest != nil,
                "the manifest seed prepares and gives a digest")
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

    @Test func theFixturesEndWhereTheirRulesSay() {
        // Fixture 1: the world switches and the new journey kept the flight going (distance grows, speed is medium).
        let joins = OdysseyCore.played(seed: OdysseyCore.manifestSeed, entries: OdysseyCore.fixtureEntries[0])
        #expect(joins.state.world == .tunnel)
        #expect(joins.state.seed == OdysseyCore.manifestSeed &+ JourneyState.seedStep)
        #expect(joins.state.distance > 3 * 8, "the flight crossed several piece boundaries: \(joins.state.distance)")
        #expect(abs(joins.state.speed - 4) < 1e-9)
        // Fixture 2: after slow, a pause and a resume, the speed is back on its way to slow and within the limits.
        let comfort = OdysseyCore.played(seed: OdysseyCore.manifestSeed, entries: OdysseyCore.fixtureEntries[1])
        #expect(comfort.state.speedChoice == .slow)
        #expect(!comfort.state.paused)
        #expect(comfort.state.speed > 0 && comfort.state.speed <= 2)
        // Fixture 3: the microphone was refused, the demo plays, the last world switch wins; the flight never stopped.
        let switches = OdysseyCore.played(seed: OdysseyCore.manifestSeed, entries: OdysseyCore.fixtureEntries[2])
        #expect(switches.state.world == .starCorridor)
        #expect(switches.state.source == .demo)
        #expect(switches.permission == .denied)
        #expect(switches.state.distance > 0)
        let fixture3 = OdysseyCore.fixtureEntries[2]
        #expect(fixture3.contains { $0.action?.control == "source.microphone"
                                    && $0.result == "action.rule." + OdysseyRule.permissionDenied })
        // The switches change neither distance nor speed: the same steps without any action give the same flight.
        let stepsOnly = fixture3.map { ScenarioStep(steps: $0.steps) }
        let unswitched = OdysseyCore.played(seed: OdysseyCore.manifestSeed, entries: stepsOnly)
        #expect(unswitched.state.distance == switches.state.distance)
        #expect(unswitched.state.speed == switches.state.speed)
        // Fixture 4: the same steady flight played twice gives the same distance (a stable, measurable response).
        let steady = OdysseyCore.played(seed: OdysseyCore.manifestSeed, entries: OdysseyCore.fixtureEntries[3])
        let again = OdysseyCore.played(seed: OdysseyCore.manifestSeed, entries: OdysseyCore.fixtureEntries[3])
        #expect(steady.state.distance == again.state.distance)
        #expect(steady.state.distance > 8)
        // Fixture 5: a fast flight crosses many pieces and stays within the speed limit.
        let long = OdysseyCore.played(seed: OdysseyCore.manifestSeed, entries: OdysseyCore.fixtureEntries[4])
        #expect(long.state.distance > 10 * 8)
        #expect(long.state.speed <= 7 + 1e-9)
    }

    /// The JSON form with the control ids, named by `Catalog/registrations.json`. `UPDATE_SCENARIO_MANIFEST=1`
    /// rewrites it.
    @Test func theCommittedManifestFileMatches() throws {
        let file = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("scenario-manifest.json")
        let manifest = OdysseyCore.manifest(for: id)
        var object = try #require(try JSONSerialization.jsonObject(with: manifest.encoded()) as? [String: Any])
        object["controls"] = OdysseyCore.controls.map(\.id)
        let data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys, .prettyPrinted])
            + Data("\n".utf8)
        if ProcessInfo.processInfo.environment["UPDATE_SCENARIO_MANIFEST"] == "1" { try data.write(to: file) }
        #expect(try Data(contentsOf: file) == data, "run with UPDATE_SCENARIO_MANIFEST=1 and commit the file")
    }
}
