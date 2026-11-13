// FluidArtCoreTests — feature 193 (UA-F07) T-U07-020 (FR-U07-001 to FR-U07-004; clarifications 1 and 2; ADR-0011).
// The CPU state of Fluid Art Playground against the experience contract: conformance, every control as an action,
// pending splats bounded by `SplatQueue.maxPending`, a digest of CPU state only, quality levels that never change the
// digest, parity with `SplatQueue` for the same samples, and the manifest. Host tests (`swift test`).
import Foundation
import Testing
@testable import FluidArtPlaygroundExperience
import FluidArtPlaygroundCore
import VisualCoreExperience
import VisualCoreMath
import VisualCoreScenes

private let id = ExperienceID(rawValue: FluidArtCore.experienceID)!

private func engine(seed: UInt64 = 7) async throws -> ExperienceEngine<FluidArtCore> {
    var engine = ExperienceEngine<FluidArtCore>(id: id)
    try await engine.prepare(seed: seed)
    try engine.activate()
    return engine
}

private func core(_ engine: ExperienceEngine<FluidArtCore>) throws -> FluidArtCore {
    try #require(engine.core)
}

@Suite struct FluidArtCoreTests {
    @Test func conformancePassesOverFourSeeds() async {
        let plan = ConformancePlan(
            seeds: [1, 7, 42, 0xFFFF_FFFF_FFFF_FFFF], stepsPerSegment: 20,
            actions: [ScriptedAction("stroke", [0.3, 0.3, 0, 0, 0, 1]), ScriptedAction("stroke", [0.5, 0.4, 2, 1, 1, 1]),
                      ScriptedAction("stroke", [0.6, 0.5, 2, 1, 2, 1]), ScriptedAction("splash"),
                      ScriptedAction("palette", [1]), ScriptedAction("pause"), ScriptedAction("step"),
                      ScriptedAction("resume"), ScriptedAction("detail", [0]), ScriptedAction("dyeFade", [3])],
            rejected: [ScriptedAction("step"), ScriptedAction("resume"), ScriptedAction("detail", [1]),
                       ScriptedAction("palette", [9]), ScriptedAction("bogus")])
        let report = await ExperienceConformance.run(FluidArtCore.self, id: id, plan: plan)
        for entry in report.entries { #expect(entry.passed, "\(entry.check): \(entry.detail)") }
    }

    @Test func aPreparationUsesTheSeedForTheDyePattern() async throws {
        let state = try core(try await engine(seed: 42))
        #expect(state.configuration.seed == 42)
        #expect(state.configuration == {
            var c = FluidConfiguration()
            c.seed = 42
            return c.validated().0
        }())
        #expect(!state.paused && state.pending.isEmpty && state.fluidSteps == 0 && state.untouched)
        #expect(state.outcome == nil)
    }

    @Test func everyControlIsAnAction() async throws {
        let base = try await engine()
        let start = try base.digest()
        let changing: [(String, [Double])] = [
            ("stroke", [0.5, 0.5, 1, 0, 0, 3]), ("pinch", [0.1]), ("brush", [0.2]), ("splash", []), ("pause", []),
            ("reset", []), ("palette", [0]), ("edges", [1]), ("detail", [2]), ("viscosity", [0.5]),
            ("dyeFade", [4]), ("motionFade", [3]), ("quality", [40]),
        ]
        for (control, values) in changing {
            var engine = base
            #expect(engine.handle(control: control, values: values) == .accepted, "\(control)")
            #expect(try engine.digest() != start, "\(control) changes the digest")
        }
        var engine = base
        #expect(engine.handle(control: "tuningReset") == .accepted)
        #expect(try engine.digest() == start, "the defaults are the fresh state")
    }

    @Test func pauseStepAndResumeRunExactlyTheAskedSteps() async throws {
        var engine = try await engine()
        try engine.run(steps: 10)
        #expect(try core(engine).fluidSteps == 10)
        #expect(engine.handle(control: "pause") == .accepted)
        try engine.run(steps: 50)
        #expect(try core(engine).fluidSteps == 10, "paused: no fluid step")
        #expect(engine.handle(control: "step") == .accepted)
        try engine.run(steps: 50)
        #expect(try core(engine).fluidSteps == 11, "one step after `step`")
        #expect(engine.handle(control: "resume") == .accepted)
        try engine.run(steps: 5)
        #expect(try core(engine).fluidSteps == 16)
        #expect(engine.handle(control: "step") == .rejected(.rule(code: "a02.not-paused")))
    }

    @Test func strokesBecomeSplatsAsTheSplatQueueMakesThem() async throws {
        // The same tracker samples through SplatQueue and through stroke actions (as the presenter sends them) give
        // the same splats.
        var engine = try await engine()
        let viewSize = SIMD2(300.0, 600.0)
        var queue = SplatQueue(configuration: try core(engine).configuration)
        var tracker = PointerVelocityTracker(spacing: 6)
        let events = [PointerEvent(id: 1, phase: .began, location: Vec2(60, 300), timestamp: 1.0),
                      PointerEvent(id: 1, phase: .moved, location: Vec2(90, 280), timestamp: 1.05),
                      PointerEvent(id: 1, phase: .ended, location: Vec2(120, 260), timestamp: 1.1),
                      PointerEvent(id: 2, phase: .began, location: Vec2(200, 100), timestamp: 1.2),
                      PointerEvent(id: 2, phase: .ended, location: Vec2(210, 120), timestamp: 1.3)]
        var samples: [PointerVelocityTracker.Sample] = []
        for event in events { samples += tracker.handle(event) }
        #expect(samples.count >= 5)
        for s in samples {
            let phase: Double = s.phase == .began ? 0 : s.phase == .ended ? 2 : 1
            let action = [s.position.x / viewSize.x, s.position.y / viewSize.y, s.velocity.x / viewSize.x,
                          s.velocity.y / viewSize.y, phase, Double(s.id)]
            #expect(engine.handle(control: "stroke", values: action) == .accepted)
        }
        queue.add(samples, viewSize: viewSize)
        let expected = queue.drain(max: 1024).map(FluidSplat.init)
        let pending = try core(engine).pending
        #expect(pending.count == expected.count)
        for (a, b) in zip(pending, expected) {
            #expect(abs(a.x - b.x) < 1e-5 && abs(a.y - b.y) < 1e-5 && a.radius == b.radius)
            #expect(abs(a.forceX - b.forceX) < 1e-2 && abs(a.forceY - b.forceY) < 1e-2)
            #expect(a.red == b.red && a.green == b.green && a.blue == b.blue)
        }
        #expect(try core(engine).colorSlots.isEmpty, "ended pointers release their colours")
    }

    @Test func pendingSplatsAreBoundedAndDrainedUnderTheCap() async throws {
        var engine = try await engine()
        #expect(engine.handle(control: "pause") == .accepted)
        for _ in 0..<(SplatQueue.maxPending + 50) {
            #expect(engine.handle(control: "splash") == .accepted)
        }
        var state = try core(engine)
        #expect(state.pending.count == SplatQueue.maxPending)
        #expect(state.dropped == 50)
        #expect(engine.handle(control: "step") == .accepted)
        try engine.run(steps: 1)
        state = try core(engine)
        #expect(state.pending.isEmpty)
        #expect(state.recent.last?.splats.count == state.configuration.maxSplatsPerFrame)
        #expect(state.released == state.configuration.maxSplatsPerFrame)
        #expect(state.outcome?.code == "canvas-painted")
        #expect(state.batches(from: 0).count == 1)
    }

    @Test func theDigestCoversOnlyCPUStateAndLevelsNeverChangeIt() async throws {
        var engine = try await engine()
        #expect(engine.handle(control: "splash") == .accepted)
        try engine.run(steps: 3)
        let digest = try engine.digest()
        for tier in [2, 1, 0, 2] {
            try engine.setQualityTier(tier)
            #expect(try engine.digest() == digest, "tier \(tier)")
        }
        try engine.shedCaches()
        #expect(try engine.digest() == digest)
        #expect(FluidArtCore.qualityProfile.count == FluidQuality.tierCount)
    }

    @Test func resetAndDetailRestartTheFieldsAndDropInput() async throws {
        var engine = try await engine()
        #expect(engine.handle(control: "stroke", values: [0.5, 0.5, 1, 1, 0, 4]) == .accepted)
        try engine.run(steps: 4)
        #expect(engine.handle(control: "stroke", values: [0.6, 0.5, 1, 1, 1, 4]) == .accepted)
        #expect(engine.handle(control: "reset") == .accepted)
        var state = try core(engine)
        #expect(state.pending.isEmpty && state.colorSlots.isEmpty && state.fluidSteps == 0 && state.untouched)
        #expect(state.resets == 1)
        #expect(engine.handle(control: "detail", values: [1]) == .rejected(.rule(code: "a02.same-detail")))
        #expect(engine.handle(control: "detail", values: [2]) == .accepted)
        state = try core(engine)
        #expect(state.configuration.gridWidth == 256 && state.rebuilds == 1)
    }

    @Test func theSnapshotRoundTripGivesTheSameDigest() async throws {
        var engine = try await engine(seed: 99)
        for (control, values) in [("stroke", [0.2, 0.2, 0, 0, 0, 1]), ("stroke", [0.3, 0.3, 2, 2, 1, 1]),
                                  ("splash", []), ("palette", [1]), ("edges", [1])] {
            #expect(engine.handle(control: control, values: values) == .accepted)
            try engine.run(steps: 3)
        }
        let digest = try engine.digest()
        let snapshot = try engine.snapshot()
        var restored = ExperienceEngine<FluidArtCore>(id: id)
        try await restored.prepare(seed: 99)
        try restored.restore(try ExperienceSnapshot(data: try snapshot.encoded()))
        #expect(try restored.digest() == digest)
        #expect(try core(restored) == core(engine))
    }
}

/// What playing `spec` on a fresh engine gives, as the runner plays it.
private func play(_ spec: ScenarioSpec) async throws -> (initial: String, results: [String], final: String) {
    var engine = ExperienceEngine<FluidArtCore>(id: id)
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

@Suite struct FluidArtManifestTests {
    @Test func theManifestIsValidWithFiveFixtures() {
        let manifest = FluidArtCore.manifest(for: id)
        let problems = ScenarioManifestValidator.problems(manifest, controls: FluidArtCore.controls,
                                                          content: ContentRequirement(fixtures: 5))
        #expect(problems.isEmpty, "\(problems)")
    }

    @Test func committedDigestsAndResultsAreWhatTheEngineGives() async throws {
        for spec in FluidArtCore.manifest(for: id).scenarios {
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
        let manifest = FluidArtCore.manifest(for: id)
        var object = try #require(try JSONSerialization.jsonObject(with: manifest.encoded()) as? [String: Any])
        object["controls"] = FluidArtCore.controls.map(\.id)
        let data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys, .prettyPrinted])
            + Data("\n".utf8)
        if ProcessInfo.processInfo.environment["UPDATE_SCENARIO_MANIFEST"] == "1" { try data.write(to: file) }
        #expect(try Data(contentsOf: file) == data, "run UPDATE_SCENARIO_MANIFEST=1 swift test and commit the file")
    }
}
