// GenerativeArtManifestTests — feature 193 (UA-F07) T-U07-009 (FR-U07-012; data-model section 3). The scenario
// manifest of Generative Art Studio is valid, has one fixture scenario per fixture of the A01 card, and its committed
// digests and result codes are what the engine gives. Host tests (`swift test`).
import Foundation
import Testing
import GenerativeArtStudioAdapterCore
import VisualCoreExperience

private let id = ExperienceID(rawValue: GenerativeArtCore.experienceID)!

/// What playing `spec` on a fresh engine gives: the initial digest, the result code of each action and the final
/// digest. Each entry runs its steps, then its action, as the runner does.
private func play(_ spec: ScenarioSpec) async throws -> (initial: String, results: [String], final: String) {
    var engine = ExperienceEngine<GenerativeArtCore>(id: id)
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

@Suite struct GenerativeArtManifestTests {
    @Test func theManifestIsValidWithFiveFixtures() {
        let manifest = GenerativeArtCore.manifest(for: id)
        let problems = ScenarioManifestValidator.problems(manifest, controls: GenerativeArtCore.controls,
                                                          content: ContentRequirement(fixtures: 5))
        #expect(problems.isEmpty, "\(problems)")
        #expect(manifest.scenarios.filter { $0.name.hasPrefix("fixture-") }.count == 5)
        #expect(manifest.kind == .creative)
    }

    @Test func committedDigestsAndResultsAreWhatTheEngineGives() async throws {
        for spec in GenerativeArtCore.manifest(for: id).scenarios {
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

    /// The manifest in its JSON form with the control ids, as `Catalog/registrations.json` names it for the
    /// verification runner's audits. `UPDATE_SCENARIO_MANIFEST=1 swift test` rewrites the file.
    @Test func theCommittedManifestFileMatches() throws {
        let file = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("scenario-manifest.json")
        let manifest = GenerativeArtCore.manifest(for: id)
        var object = try #require(try JSONSerialization.jsonObject(with: manifest.encoded()) as? [String: Any])
        object["controls"] = GenerativeArtCore.controls.map(\.id)
        let data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys, .prettyPrinted])
            + Data("\n".utf8)
        if ProcessInfo.processInfo.environment["UPDATE_SCENARIO_MANIFEST"] == "1" {
            try data.write(to: file)
        }
        let committed = try Data(contentsOf: file)
        #expect(committed == data, "run UPDATE_SCENARIO_MANIFEST=1 swift test and commit the file")
        #expect(try ScenarioManifest(data: manifest.encoded()) == manifest, "the JSON form round-trips")
    }

    @Test func anotherSeedCommitsNoDigest() {
        for spec in GenerativeArtCore.manifest(for: id, seed: 8).scenarios {
            #expect(spec.expect.initialDigest == nil && spec.expect.finalDigest == nil, "\(spec.name)")
        }
    }
}
