// ECManifestTests — feature 181 (A25-P02) T-A25-209 (FR-A25-207; SC-A25-206). The scenario manifest of Effects
// Composer, after Graphics Benchmark Lab's `GBLManifestTests`: valid with the nine standard scenarios and one fixture
// per effect; its derived digests, results and outcomes equal to what the engine gives when the runner plays them;
// every fixture ending in the state its actions describe; the save-restore state surviving a restore; the frame probe
// holding on the opening picture; and the committed `scenario-manifest.json` equal to the Swift manifest
// (`UPDATE_SCENARIO_MANIFEST=1`, on the simulator `TEST_RUNNER_UPDATE_SCENARIO_MANIFEST=1`, rewrites it).
import CoreGraphics
import EffectsComposerCore
import Foundation
import Testing
import UIKit
import VisualCoreExperience
import VisualCoreExperienceHost
@testable import EffectsComposerExperience

/// The experience id of the manifest.
private let manifestID = ExperienceID(rawValue: ComposerCore.experienceID)!

/// What playing `spec` on a fresh engine gives, as the runner plays it.
private func playManifest(_ spec: ScenarioSpec) async throws -> (initial: String, results: [String], final: String,
                                                                 core: ComposerCore?) {
    var engine = ExperienceEngine<ComposerCore>(id: manifestID)
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
@Suite(.serialized) struct ECManifestTests {
    /// The names of the fixtures.
    static let fixtureNames = ["fixture-grade", "fixture-blur", "fixture-distort", "fixture-vignette",
                               "fixture-posterize"]

    @Test func theManifestIsValidWithTheStandardScenariosAndAFixturePerEffect() {
        let manifest = ComposerCore.manifest(for: manifestID)
        let problems = ScenarioManifestValidator.problems(manifest, controls: ComposerCore.controls,
                                                          content: ContentRequirement(fixtures: 5))
        #expect(problems.isEmpty, "\(problems)")
        #expect(manifest.scenarios.map(\.name) == ScenarioManifest.standardNames + Self.fixtureNames)
        #expect(ComposerCore.fixtures.map(\.name) == Self.fixtureNames)
        #expect(manifest.kind == .creative)
        #expect(manifest.experience == manifestID)
        #expect(manifest.scenarios.allSatisfy { $0.seed == ComposerCore.manifestSeed })
    }

    @Test func derivedDigestsResultsAndOutcomesAreWhatTheEngineGives() async throws {
        let manifest = ComposerCore.manifest(for: manifestID)
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
        let manifest = ComposerCore.manifest(for: manifestID)
        let spec = try #require(manifest.scenarios.first { $0.name == "save-restore" })
        let played = try await playManifest(spec)
        let core = try #require(played.core)
        #expect(core.chain.nodes.map(\.effect) == [.blur, .grade])
        #expect(core.chain.nodes.filter(\.enabled).count == 2, "the disabling was undone")
        #expect(core.chain.nodes[1].values["contrast"] == 2)
        let restored = try ComposerCore.restore(payload: core.snapshotPayload(), seed: spec.seed)
        #expect(restored.chain == core.chain)
        #expect(!restored.history.canUndo)
        #expect(try ComposerTest.digest(restored) == played.final)
    }

    @Test func everyFixtureEndsInTheStateItsActionsDescribe() async throws {
        let manifest = ComposerCore.manifest(for: manifestID)
        for (index, fixture) in ComposerCore.fixtures.enumerated() {
            let spec = try #require(manifest.scenarios.first { $0.name == fixture.name })
            let played = try await playManifest(spec)
            let core = try #require(played.core, "\(fixture.name)")
            let effect = ComposerCore.effects[index]
            #expect(fixture.name == "fixture-" + effect.rawValue)
            #expect(core.outcome?.code == fixture.outcome && fixture.outcome == "effects-1", "\(fixture.name)")
            #expect(core.chain.nodes.count == 1 && core.chain.nodes[0].effect == effect && core.chain.nodes[0].enabled)
            let first = EffectLibrary.definition(effect).parameters[0]
            #expect(core.chain.nodes[0].values[first.name] == ComposerCore.value(of: first, fraction: 0.75))
            #expect(played.final != played.initial, "\(fixture.name)")
        }
    }

    @Test func theProbeHoldsOnTheOpeningPicture() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await ComposerTest.open(session, size: CGSize(width: 128, height: 96))
        let host = try #require(session.renderHost)
        var failures: [String] = []
        for frame in 0..<3 {
            try ComposerTest.draw(session)
            let pixels = host.readPixels()
            let size = host.pixelSize
            let probes = shell.frameProbes
            if probes.isEmpty { failures.append("frame \(frame): no probe") }
            if let failure = shell.presenter.renderer.presentFailure { failures.append("present: \(failure)") }
            for probe in probes {
                let found = FrameChecks.probe(probe, rgba: pixels, width: size.width, height: size.height)?.rawValue
                if found != probe.expected {
                    failures.append("frame \(frame): \(probe.name) at (\(probe.x), \(probe.y)) is \(found ?? "none")")
                }
            }
        }
        #expect(failures.isEmpty, "\(failures)")
        #expect(shell.frameProbes.map(\.expected) == ["blue"])
        ComposerTest.accept(shell, "chain.add", [0, 0])
        try ComposerTest.draw(session)
        #expect(shell.frameProbes.isEmpty, "a chain with an effect declares no probe")
    }

    /// The JSON form with the control ids, named by `Catalog/registrations.json`. `UPDATE_SCENARIO_MANIFEST=1`
    /// (on the simulator `TEST_RUNNER_UPDATE_SCENARIO_MANIFEST=1`) rewrites it.
    @Test func theCommittedManifestFileMatches() throws {
        let file = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("scenario-manifest.json")
        let manifest = ComposerCore.manifest(for: manifestID)
        var object = try #require(try JSONSerialization.jsonObject(with: manifest.encoded()) as? [String: Any])
        object["controls"] = ComposerCore.controls.map(\.id)
        let data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys, .prettyPrinted])
            + Data("\n".utf8)
        if ProcessInfo.processInfo.environment["UPDATE_SCENARIO_MANIFEST"] == "1" { try data.write(to: file) }
        #expect(try Data(contentsOf: file) == data, "run with UPDATE_SCENARIO_MANIFEST=1 and commit the file")
    }
}
