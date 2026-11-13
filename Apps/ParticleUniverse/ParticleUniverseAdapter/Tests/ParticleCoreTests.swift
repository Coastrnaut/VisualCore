// ParticleCoreTests — feature 193 (UA-F07) T-U07-026 (FR-U07-001 to FR-U07-004; clarifications 2 and 3; SC-U07-011).
// The adapter core of Particle Universe against the experience contract, with short runs only (owner rule of
// 2026-11-13): conformance, the replay payload restoring the same checksum and digest (also across a rebase), the
// quality level capping only the drawn count, `force.place` mapping normalized positions to the scene's world, and the
// checksum equal to the standalone `SceneSimulation`'s for the same seed and commands. Host tests (`swift test`).
import Foundation
import Testing
@testable import ParticleUniverseAdapterCore
import ParticleUniverseCore
import VisualCoreExperience
import VisualCoreMath
import VisualCoreSimulation

private let id = ExperienceID(rawValue: ParticleCore.experienceID)!

private func engine(seed: UInt64 = 7) async throws -> ExperienceEngine<ParticleCore> {
    var engine = ExperienceEngine<ParticleCore>(id: id)
    try await engine.prepare(seed: seed)
    try engine.activate()
    return engine
}

private func core(_ engine: ExperienceEngine<ParticleCore>) throws -> ParticleCore {
    try #require(engine.core)
}

@Suite struct ParticleCoreTests {
    @Test func conformancePassesOverFourSeeds() async {
        let plan = ConformancePlan(
            seeds: [1, 7, 42, 0xFFFF_FFFF_FFFF_FFFF], stepsPerSegment: 12,
            actions: [ScriptedAction("emitter.add"), ScriptedAction("family", [2]), ScriptedAction("size", [12]),
                      ScriptedAction("force.place", [0.7, 0.3]), ScriptedAction("strength", [1.5]),
                      ScriptedAction("pause"), ScriptedAction("step"), ScriptedAction("play"),
                      ScriptedAction("trails", [1]), ScriptedAction("reseed")],
            rejected: [ScriptedAction("play"), ScriptedAction("emitter.remove"), ScriptedAction("force.nudge", [1, 1]),
                       ScriptedAction("family", [9]), ScriptedAction("bogus")])
        let report = await ExperienceConformance.run(ParticleCore.self, id: id, plan: plan)
        for entry in report.entries { #expect(entry.passed, "\(entry.check): \(entry.detail)") }
    }

    @Test func theReplayPayloadRestoresTheSameChecksumAndDigest() async throws {
        var engine = try await engine(seed: 11)
        for (control, values) in [("emitter.add", [Double]()), ("force.place", [0.25, 0.75]), ("family", [1]),
                                  ("pause", []), ("step", []), ("play", []), ("gradient", [2])] {
            #expect(engine.handle(control: control, values: values) == .accepted, "\(control)")
            try engine.run(steps: 30)
        }
        let digest = try engine.digest()
        let checksum = try core(engine).simulation.state.checksum()
        let snapshot = try engine.snapshot()
        #expect(try snapshot.encoded().count < 1_048_576, "the replay payload is far below 1 MiB")
        var restored = ExperienceEngine<ParticleCore>(id: id)
        try await restored.prepare(seed: 11)
        try restored.restore(try ExperienceSnapshot(data: try snapshot.encoded()))
        #expect(try restored.digest() == digest)
        #expect(try core(restored).simulation.state.checksum() == checksum)
    }

    @Test func aRebaseKeepsTheConfigurationAndBoundsTheReplay() async throws {
        var engine = try await engine(seed: 5)
        for (control, values) in [("emitter.add", [Double]()), ("force.place", [0.6, 0.6]), ("trails", [1])] {
            #expect(engine.handle(control: control, values: values) == .accepted, "\(control)")
            try engine.run(steps: 20)
        }
        var state = try core(engine)
        let emitters = state.simulation.visibleEmitters
        let force = state.placedForce
        state.rebase()
        #expect(state.log.isEmpty && state.steps == 0 && state.rebases == 1)
        #expect(state.simulation.visibleEmitters == emitters, "the emitters carry over")
        #expect(state.placedForce == force && state.trailsOn, "the force and settings carry over")
        // The rebased state, with steps and an action after it, restores to the same digest.
        state.update(step: 0)
        #expect(state.apply(ExperienceAction(control: "size", values: [20], step: 1)).isAccepted)
        for i in 0..<10 { state.update(step: i + 1) }
        let payload = try state.snapshotPayload()
        let restored = try ParticleCore.restore(payload: payload, seed: 5)
        var a = DigestBuilder(domain: "t"), b = DigestBuilder(domain: "t")
        try state.writeDigest(into: &a)
        try restored.writeDigest(into: &b)
        #expect(a.finish() == b.finish())
        #expect(ParticleCore.maxReplaySteps == 72_000, "10 simulated minutes")
    }

    @Test func theQualityLevelCapsOnlyTheDrawnCount() async throws {
        var engine = try await engine()
        try engine.run(steps: 240)
        let digest = try engine.digest()
        let state = try core(engine)
        let live = state.simulation.liveCount
        #expect(live > 0)
        for tier in 0..<ParticleCore.qualityTiers {
            try engine.setQualityTier(tier)
            #expect(try engine.digest() == digest, "tier \(tier) keeps the digest")
            let cap = Int((Double(state.simulation.scene.particleLimit) * ParticleCore.drawShare(tier: tier)).rounded())
            #expect(state.instances(tier: tier).count == min(live, cap), "tier \(tier)")
        }
        #expect(try core(engine).simulation.liveLimit == state.simulation.scene.particleLimit,
                "the simulation keeps the scene's limit")
    }

    @Test func forcePlaceMapsNormalizedPositionsToTheWorld() async throws {
        var engine = try await engine()
        #expect(engine.handle(control: "force.place", values: [0.75, 0.25]) == .accepted)
        let half = PlacedForce.worldHalfExtent
        #expect(try core(engine).placedForce?.position == Vec2(0.5 * half, -0.5 * half))
        #expect(engine.handle(control: "force.place", values: [0, 1]) == .accepted)
        #expect(try core(engine).placedForce?.position == Vec2(-half, half))
        #expect(engine.handle(control: "force.center") == .accepted)
        #expect(try core(engine).placedForce?.position == .zero)
        #expect(engine.handle(control: "force.place", values: [1.2, 0.5]) == .rejected(.outOfRange(index: 0)))
    }

    @Test func theChecksumEqualsTheStandaloneSimulationForTheSameSeedAndCommands() async throws {
        var engine = try await engine(seed: 9)
        var standalone = try SceneSimulation(scene: .single(.fountain, seed: 9))
        try engine.run(steps: 60)
        standalone.run(steps: 60)
        #expect(engine.handle(control: "emitter.add") == .accepted)
        _ = standalone.addEmitter(SceneEmitter(family: .fountain, position: SceneSimulation.placement(of: .fountain, index: 1)))
        try engine.run(steps: 60)
        standalone.run(steps: 60)
        // Exactly representable positions: 0.75 and 0.25 of the world square are 250 and −250.
        #expect(engine.handle(control: "force.place", values: [0.75, 0.25]) == .accepted)
        standalone.setPlacedForce(PlacedForce(kind: .attractor, position: Vec2(250, -250), strength: 1))
        try engine.run(steps: 120)
        standalone.run(steps: 120)
        #expect(try core(engine).simulation.state.checksum() == standalone.state.checksum())
        #expect(try core(engine).simulation.liveCount == standalone.liveCount)
    }

    @Test func pausedStepsHoldAndStepRunsOne() async throws {
        var engine = try await engine()
        #expect(engine.handle(control: "pause") == .accepted)
        let held = try core(engine).simulation.state.checksum()
        try engine.run(steps: 50)
        #expect(try core(engine).simulation.state.checksum() == held)
        #expect(engine.handle(control: "step") == .accepted)
        #expect(try core(engine).simulation.state.checksum() != held)
        #expect(engine.handle(control: "pause") == .rejected(.rule(code: "a04.already-paused")))
    }

    @Test func theOutcomeIsSceneBuiltWithThreeEmitters() async throws {
        var engine = try await engine()
        #expect(engine.outcome == nil)
        #expect(engine.handle(control: "emitter.add") == .accepted)
        #expect(engine.outcome == nil)
        #expect(engine.handle(control: "emitter.add") == .accepted)
        #expect(engine.outcome?.code == "scene-built")
    }
}

/// What playing `spec` on a fresh engine gives, as the runner plays it.
private func play(_ spec: ScenarioSpec) async throws -> (initial: String, results: [String], final: String) {
    var engine = ExperienceEngine<ParticleCore>(id: id)
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

@Suite struct ParticleManifestTests {
    @Test func theManifestIsValidWithFiveFixtures() {
        let problems = ScenarioManifestValidator.problems(ParticleCore.manifest(for: id), controls: ParticleCore.controls,
                                                          content: ContentRequirement(fixtures: 5))
        #expect(problems.isEmpty, "\(problems)")
    }

    @Test func committedDigestsAndResultsAreWhatTheEngineGives() async throws {
        for spec in ParticleCore.manifest(for: id).scenarios {
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

    /// The JSON form with the control ids, named by `Catalog/registrations.json`. `UPDATE_SCENARIO_MANIFEST=1 swift
    /// test` rewrites it.
    @Test func theCommittedManifestFileMatches() throws {
        let file = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("scenario-manifest.json")
        let manifest = ParticleCore.manifest(for: id)
        var object = try #require(try JSONSerialization.jsonObject(with: manifest.encoded()) as? [String: Any])
        object["controls"] = ParticleCore.controls.map(\.id)
        let data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys, .prettyPrinted])
            + Data("\n".utf8)
        if ProcessInfo.processInfo.environment["UPDATE_SCENARIO_MANIFEST"] == "1" { try data.write(to: file) }
        #expect(try Data(contentsOf: file) == data, "run UPDATE_SCENARIO_MANIFEST=1 swift test and commit the file")
    }
}
