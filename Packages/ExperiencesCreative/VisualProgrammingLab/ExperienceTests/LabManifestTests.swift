// LabManifestTests — feature 167 (A23-P02) T-A23-210 (FR-A23-207; SC-A23-201, SC-A23-202). The scenario manifest of
// Visual Programming Lab, after Shader Studio's `StudioManifestTests`: valid with the nine standard scenarios and the
// five fixtures; its derived digests, results and outcomes equal to what the engine gives when the runner plays
// them; every fixture ending in the state its actions describe; the save-restore state surviving a restore; and the
// committed `scenario-manifest.json` equal to the Swift manifest (`UPDATE_SCENARIO_MANIFEST=1`, on the simulator
// `TEST_RUNNER_UPDATE_SCENARIO_MANIFEST=1`, rewrites it).
import Foundation
import Testing
import VisualCoreExperience
@testable import VisualProgrammingLabExperience
import VisualProgrammingLabCore

private let manifestID = ExperienceID(rawValue: LabCore.experienceID)!

/// What playing `spec` on a fresh engine gives, as the runner plays it.
private func playManifest(_ spec: ScenarioSpec) async throws -> (initial: String, results: [String], final: String,
                                                                 core: LabCore?) {
    var engine = ExperienceEngine<LabCore>(id: manifestID)
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

@Suite struct LabManifestTests {
    /// The names of the fixtures.
    static let fixtureNames = ["fixture-starter-graph", "fixture-journey-graph", "fixture-refused-connection",
                               "fixture-refused-loop", "fixture-refused-second-output"]

    @Test func theManifestIsValidWithTheStandardScenariosAndFiveFixtures() {
        let manifest = LabCore.manifest(for: manifestID)
        let problems = ScenarioManifestValidator.problems(manifest, controls: LabCore.controls,
                                                          content: ContentRequirement(fixtures: 5))
        #expect(problems.isEmpty, "\(problems)")
        #expect(manifest.scenarios.map(\.name) == ScenarioManifest.standardNames + Self.fixtureNames)
        #expect(LabCore.fixtures.map(\.name) == Self.fixtureNames)
        #expect(manifest.kind == .creative)
        #expect(manifest.experience == manifestID)
        #expect(manifest.scenarios.allSatisfy { $0.seed == LabCore.manifestSeed })
    }

    @Test func derivedDigestsResultsAndOutcomesAreWhatTheEngineGives() async throws {
        let manifest = LabCore.manifest(for: manifestID)
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
        let manifest = LabCore.manifest(for: manifestID)
        let spec = try #require(manifest.scenarios.first { $0.name == "save-restore" })
        let played = try await playManifest(spec)
        let core = try #require(played.core)
        #expect(core.selection == NodeID(3))
        let restored = try LabCore.restore(payload: core.snapshotPayload(), seed: spec.seed)
        #expect(restored == core)
        #expect(try labDigest(restored) == played.final)
    }

    @Test func everyFixtureEndsInTheStateItsActionsDescribe() async throws {
        let manifest = LabCore.manifest(for: manifestID)
        for fixture in LabCore.fixtures {
            let spec = try #require(manifest.scenarios.first { $0.name == fixture.name })
            let played = try await playManifest(spec)
            let core = try #require(played.core, "\(fixture.name)")
            #expect(core.outcome?.code == LabCore.readyCode, "\(fixture.name)")
            switch fixture.name {
            case "fixture-starter-graph":
                #expect(core.graph == LabCore.starterGraph && core.selection == NodeID(1))
                #expect(played.final == played.initial, "the selection is not in the digest")
            case "fixture-journey-graph":
                #expect(core.graph.nodes.count == 5 && core.graph.edges.count == 4)
                #expect(core.graph.edges.contains(GraphEdge(from: NodeID(5), "image", to: NodeID(2), "image")))
            case "fixture-refused-connection":
                #expect(core.graph.nodes.count == 3 && core.graph.edges == LabCore.starterGraph.edges)
                #expect(core.graph.node(NodeID(3))?.kind == .constant)
            case "fixture-refused-loop":
                #expect(core.graph.nodes.count == 4 && core.graph.edges.count == 4)
                #expect(!core.graph.edges.contains(GraphEdge(from: NodeID(4), "image", to: NodeID(3), "b")))
            case "fixture-refused-second-output":
                #expect(core.graph.outputNodes == [NodeID(2)] && core.graph.node(NodeID(3))?.kind == .gradient)
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
        let manifest = LabCore.manifest(for: manifestID)
        var object = try #require(try JSONSerialization.jsonObject(with: manifest.encoded()) as? [String: Any])
        object["controls"] = LabCore.controls.map(\.id)
        let data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys, .prettyPrinted])
            + Data("\n".utf8)
        if ProcessInfo.processInfo.environment["UPDATE_SCENARIO_MANIFEST"] == "1" { try data.write(to: file) }
        #expect(try Data(contentsOf: file) == data, "run with UPDATE_SCENARIO_MANIFEST=1 and commit the file")
    }
}
