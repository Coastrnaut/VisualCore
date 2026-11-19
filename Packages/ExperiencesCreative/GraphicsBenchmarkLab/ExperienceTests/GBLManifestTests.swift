// GBLManifestTests — feature 174 (A24-P02) T-A24-211 (FR-A24-207; SC-A24-205). The scenario manifest of Graphics
// Benchmark Lab, after Visual Programming Lab's `LabManifestTests`: valid with the nine standard scenarios and the
// five fixtures; its derived digests, results and outcomes equal to what the engine gives when the runner plays them;
// every fixture ending in the state its actions describe; the save-restore state surviving a restore; the frame probe
// holding at every turn of the opening picture; and the committed `scenario-manifest.json` equal to the Swift manifest
// (`UPDATE_SCENARIO_MANIFEST=1`, on the simulator `TEST_RUNNER_UPDATE_SCENARIO_MANIFEST=1`, rewrites it).
import CoreGraphics
import Foundation
import Testing
import UIKit
import VisualCoreExperience
import VisualCoreExperienceHost
@testable import GraphicsBenchmarkLabExperience
import GraphicsBenchmarkLabCore

/// The experience id of the manifest.
private let manifestID = ExperienceID(rawValue: BenchCore.experienceID)!

/// What playing `spec` on a fresh engine gives, as the runner plays it.
private func playManifest(_ spec: ScenarioSpec) async throws -> (initial: String, results: [String], final: String,
                                                                 core: BenchCore?) {
    var engine = ExperienceEngine<BenchCore>(id: manifestID)
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

@MainActor
@Suite(.serialized) struct GBLManifestTests {
    /// The names of the fixtures.
    static let fixtureNames = ["fixture-case-quads", "fixture-case-alu", "fixture-case-particles",
                               "fixture-run-start-stop", "fixture-refused-fraction"]

    @Test func theManifestIsValidWithTheStandardScenariosAndFiveFixtures() {
        let manifest = BenchCore.manifest(for: manifestID)
        let problems = ScenarioManifestValidator.problems(manifest, controls: BenchCore.controls,
                                                          content: ContentRequirement(fixtures: 5))
        #expect(problems.isEmpty, "\(problems)")
        #expect(manifest.scenarios.map(\.name) == ScenarioManifest.standardNames + Self.fixtureNames)
        #expect(BenchCore.fixtures.map(\.name) == Self.fixtureNames)
        #expect(manifest.kind == .creative)
        #expect(manifest.experience == manifestID)
        #expect(manifest.scenarios.allSatisfy { $0.seed == BenchCore.manifestSeed })
    }

    @Test func derivedDigestsResultsAndOutcomesAreWhatTheEngineGives() async throws {
        let manifest = BenchCore.manifest(for: manifestID)
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
        let manifest = BenchCore.manifest(for: manifestID)
        let spec = try #require(manifest.scenarios.first { $0.name == "save-restore" })
        let played = try await playManifest(spec)
        let core = try #require(played.core)
        #expect(core.selectedCase == 1 && core.startRequests == 1 && core.stopRequests == 1)
        let restored = try BenchCore.restore(payload: core.snapshotPayload(), seed: spec.seed)
        #expect(restored == core)
        #expect(try BenchTest.digest(restored) == played.final)
    }

    @Test func everyFixtureEndsInTheStateItsActionsDescribe() async throws {
        let manifest = BenchCore.manifest(for: manifestID)
        for fixture in BenchCore.fixtures {
            let spec = try #require(manifest.scenarios.first { $0.name == fixture.name })
            let played = try await playManifest(spec)
            let core = try #require(played.core, "\(fixture.name)")
            #expect(core.outcome?.code == fixture.outcome, "\(fixture.name)")
            switch fixture.name {
            case "fixture-case-quads":
                #expect(core.selectedCase == 0)
                #expect(played.final == played.initial, "quads again is the opening digest")
            case "fixture-case-alu":
                #expect(core.selectedCase == 1 && played.final != played.initial)
            case "fixture-case-particles":
                #expect(core.selectedCase == 2 && played.final != played.initial)
            case "fixture-run-start-stop":
                #expect(core.selectedCase == 1 && core.startRequests == 1 && core.stopRequests == 1)
                let alu = try BenchTest.digest(BenchCore(selectedCase: 1))
                #expect(played.final == alu, "the request counters are not in the digest")
            case "fixture-refused-fraction":
                #expect(core.selectedCase == 2)
                #expect(played.results.first == "action.rule.a24.not-whole")
            default:
                Issue.record("unexpected fixture \(fixture.name)")
            }
        }
    }

    @Test func theProbeHoldsAtEveryTurnOfTheOpeningPicture() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await BenchTest.open(session, size: CGSize(width: 128, height: 96))
        let host = try #require(session.renderHost)
        var failures: [String] = []
        // 64 turn steps, so 66 frames pass every turn of the last layer.
        for frame in 0..<66 {
            try BenchTest.draw(session, shell, at: Double(frame) / 60)
            let pixels = host.readPixels()
            let size = host.pixelSize
            let probes = shell.frameProbes
            if probes.isEmpty { failures.append("frame \(frame): no probe") }
            for probe in probes {
                let found = FrameChecks.probe(probe, rgba: pixels, width: size.width, height: size.height)?.rawValue
                if found != probe.expected {
                    failures.append("frame \(frame): \(probe.name) at (\(probe.x), \(probe.y)) is \(found ?? "none")")
                }
            }
        }
        #expect(failures.isEmpty, "\(failures)")
        let probes = shell.frameProbes
        #expect(probes.map(\.expected) == ["red"])
    }

    /// The JSON form with the control ids, named by `Catalog/registrations.json`. `UPDATE_SCENARIO_MANIFEST=1`
    /// (on the simulator `TEST_RUNNER_UPDATE_SCENARIO_MANIFEST=1`) rewrites it.
    @Test func theCommittedManifestFileMatches() throws {
        let file = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("scenario-manifest.json")
        let manifest = BenchCore.manifest(for: manifestID)
        var object = try #require(try JSONSerialization.jsonObject(with: manifest.encoded()) as? [String: Any])
        object["controls"] = BenchCore.controls.map(\.id)
        let data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys, .prettyPrinted])
            + Data("\n".utf8)
        if ProcessInfo.processInfo.environment["UPDATE_SCENARIO_MANIFEST"] == "1" { try data.write(to: file) }
        #expect(try Data(contentsOf: file) == data, "run with UPDATE_SCENARIO_MANIFEST=1 and commit the file")
    }
}
