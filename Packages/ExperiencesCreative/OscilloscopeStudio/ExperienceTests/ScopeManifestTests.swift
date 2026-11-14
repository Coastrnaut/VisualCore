// ScopeManifestTests — feature 061 (A08-P01) T-A08-107 (FR-A08-120; SC-A08-105). The scenario manifest of Oscilloscope
// Studio: valid with the nine standard scenarios and the five fixtures of this phase (display periods, spectrum bin,
// no trigger, clipping, falling-slope sweep), its derived digests and expected results equal to what the engine gives when the runner plays them, the
// fixtures ending in the states they name, and the committed `scenario-manifest.json` equal to the Swift manifest
// (`UPDATE_SCENARIO_MANIFEST=1`, on the simulator `TEST_RUNNER_UPDATE_SCENARIO_MANIFEST=1`, rewrites it).
import Foundation
import Testing
@testable import OscilloscopeStudioExperience
import OscilloscopeStudioCore
import VisualCoreAudioDSP
import VisualCoreExperience

private let id = ExperienceID(rawValue: ScopeCore.experienceID)!

/// What playing `spec` on a fresh engine gives, as the runner plays it.
private func play(_ spec: ScenarioSpec) async throws -> (initial: String, results: [String], final: String) {
    var engine = ExperienceEngine<ScopeCore>(id: id)
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

@Suite struct ScopeManifestTests {
    @Test func theManifestIsValidWithTheNineStandardScenariosAndSevenFixtures() {
        let manifest = ScopeCore.manifest(for: id)
        let problems = ScenarioManifestValidator.problems(manifest, controls: ScopeCore.controls,
                                                          content: ContentRequirement(fixtures: 7))
        #expect(problems.isEmpty, "\(problems)")
        #expect(Set(manifest.scenarios.map(\.name))
                == Set(ScenarioManifest.standardNames).union((1...7).map { "fixture-\($0)" }))
    }

    @Test func derivedDigestsAndResultsAreWhatTheEngineGives() async throws {
        let manifest = ScopeCore.manifest(for: id)
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
        let seed = ScopeCore.manifestSeed
        let periods = ScopeCore.played(seed: seed, entries: ScopeCore.fixtureEntries[0]).state
        #expect(periods.source == .testSignal && periods.waveform == .sine)
        #expect(periods.frequency == 1_000 && periods.timebaseMilliseconds == 1)
        #expect(TestSignal.periods(frequency: periods.frequency, sampleCount: 480, sampleRate: 48_000) == 10)
        let bin = ScopeCore.played(seed: seed, entries: ScopeCore.fixtureEntries[1]).state
        #expect(bin.frequency == 1_000 && bin.timebaseMilliseconds == 5)
        #expect(SpectrumAnalyzer.expectedBin(frequency: 1_000, sampleRate: 48_000, size: 4_096) == 85)
        let none = ScopeCore.played(seed: seed, entries: ScopeCore.fixtureEntries[2]).state
        #expect(none.triggerMode == .normal && none.triggerLevel == 0.9)
        let clipping = ScopeCore.played(seed: seed, entries: ScopeCore.fixtureEntries[3]).state
        #expect(clipping.gain == 10 && clipping.waveform == .sine)
        let sweep = ScopeCore.played(seed: seed, entries: ScopeCore.fixtureEntries[4]).state
        #expect(sweep.waveform == .sweep && sweep.triggerSlope == .falling && sweep.timebaseMilliseconds == 2)
        let missing = ScopeCore.played(seed: seed, entries: ScopeCore.fixtureEntries[5]).state
        #expect(missing.triggerMode == .auto && missing.triggerLevel == 0.9)
        let xy = ScopeCore.played(seed: seed, entries: ScopeCore.fixtureEntries[6]).state
        #expect(xy.display == .xy && xy.source == .testSignal)
    }

    /// The JSON form with the control ids, named by `Catalog/registrations.json`. `UPDATE_SCENARIO_MANIFEST=1`
    /// rewrites it.
    @Test func theCommittedManifestFileMatches() throws {
        let file = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("scenario-manifest.json")
        let manifest = ScopeCore.manifest(for: id)
        var object = try #require(try JSONSerialization.jsonObject(with: manifest.encoded()) as? [String: Any])
        object["controls"] = ScopeCore.controls.map(\.id)
        let data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys, .prettyPrinted])
            + Data("\n".utf8)
        if ProcessInfo.processInfo.environment["UPDATE_SCENARIO_MANIFEST"] == "1" { try data.write(to: file) }
        #expect(try Data(contentsOf: file) == data, "run with UPDATE_SCENARIO_MANIFEST=1 and commit the file")
    }
}
