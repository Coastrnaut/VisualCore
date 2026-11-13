// GenerativeArtCoreTests — feature 193 (UA-F07) T-U07-007 (FR-U07-001 to FR-U07-004; data-model section 2). The
// adapter core of Generative Art Studio against the experience contract: conformance over four seeds, every control,
// the clock, the deterministic shuffle, the snapshot round trip and the outcome. Host tests (`swift test`).
import Foundation
import Testing
@testable import GenerativeArtStudioExperience
import GenerativeArtStudioCore
import VisualCoreExperience
import VisualCoreParameters
import VisualCoreSimulation

private let id = ExperienceID(rawValue: GenerativeArtCore.experienceID)!

/// An active engine prepared with `seed`.
private func engine(seed: UInt64 = 7) async throws -> ExperienceEngine<GenerativeArtCore> {
    var engine = ExperienceEngine<GenerativeArtCore>(id: id)
    try await engine.prepare(seed: seed)
    try engine.activate()
    return engine
}

private func core(_ engine: ExperienceEngine<GenerativeArtCore>) throws -> GenerativeArtCore {
    try #require(engine.core)
}

@Suite struct GenerativeArtCoreTests {
    @Test func conformancePassesOverFourSeeds() async {
        let plan = ConformancePlan(
            seeds: [1, 7, 42, 0xFFFF_FFFF_FFFF_FFFF], stepsPerSegment: 30,
            actions: [ScriptedAction("palette", [3]), ScriptedAction("parameter.gravity", [0.75]),
                      ScriptedAction("seed.shuffle"), ScriptedAction("family", [3]), ScriptedAction("parameter.count", [0.2]),
                      ScriptedAction("pause"), ScriptedAction("scrub", [12.5]), ScriptedAction("save")],
            rejected: [ScriptedAction("preset", [7]), ScriptedAction("parameter.cells", [0.5]),
                       ScriptedAction("bogus"), ScriptedAction("rate", [9])])
        let report = await ExperienceConformance.run(GenerativeArtCore.self, id: id, plan: plan)
        for entry in report.entries { #expect(entry.passed, "\(entry.check): \(entry.detail)") }
    }

    @Test func aFreshPreparationIsTheParticlesFamilyAtItsDefaultPreset() async throws {
        let state = try core(try await engine(seed: 42))
        let family = FamilyCatalog.family(.particles)
        #expect(state.family.id == family.id)
        #expect(state.presetID == family.defaultPreset.id)
        #expect(state.document.seed == family.defaultPreset.seed)
        #expect(state.time == 0 && state.playing && state.rate == 1 && state.saves == 0)
        #expect(state.document.id == GenerativeArtCore.documentID(seed: 42))
        #expect(GenerativeArtCore.documentID(seed: 42) != GenerativeArtCore.documentID(seed: 43))
    }

    @Test func everyControlChangesTheDigestAsSpecified() async throws {
        let base = try await engine()
        let start = try base.digest()
        let changing: [(String, [Double])] = [
            ("family", [2]), ("preset", [1]), ("palette", [4]), ("parameter.size", [0.9]), ("value.drag", [1.7]),
            ("seed.shuffle", []), ("seed.set", [1, 2]), ("pause", []), ("scrub", [30]), ("rate", [0.5]), ("save", []),
            ("open", [3, 2, 0, 99, 10]),
        ]
        for (control, values) in changing {
            var engine = base
            #expect(engine.handle(control: control, values: values) == .accepted, "\(control)")
            #expect(try engine.digest() != start, "\(control) changes the digest")
        }
        // Controls that change nothing on a fresh state: values already at the baseline, playing already.
        for control in ["resetAll", "reset.size", "play", "rebase"] {
            var engine = base
            #expect(engine.handle(control: control) == .accepted, "\(control)")
            #expect(try engine.digest() == start, "\(control) keeps a fresh state")
        }
    }

    @Test func invalidValuesAreRejectedAndKeepTheState() async throws {
        let base = try await engine()
        let start = try base.digest()
        let rejected: [(String, [Double], String)] = [
            ("family", [4], "action.out-of-range"), ("family", [], "action.wrong-value-count"),
            ("preset", [2], "action.out-of-range"), ("palette", [-1], "action.out-of-range"),
            ("parameter.scale", [1.5], "action.out-of-range"), ("parameter.scale", [.nan], "action.non-finite"),
            ("parameter.cells", [0.5], "action.rule.a01.no-parameter"), ("reset.warp", [], "action.rule.a01.no-parameter"),
            ("scrub", [121], "action.out-of-range"), ("rate", [5], "action.out-of-range"),
            ("seed.set", [1], "action.wrong-value-count"), ("tour", [], "action.unknown-control"),
        ]
        for (control, values, code) in rejected {
            var engine = base
            let result = engine.handle(control: control, values: values)
            guard case .rejected(let reason) = result else {
                Issue.record("\(control) \(values) was accepted")
                continue
            }
            #expect(reason.code == code, "\(control) \(values)")
            #expect(try engine.digest() == start)
        }
    }

    @Test func parameterEditsUseTheAppsEditor() async throws {
        var engine = try await engine()
        #expect(engine.handle(control: "family", values: [0]) == .accepted)
        let family = FamilyCatalog.all[0]
        var reference = CompositionEditor(family: family)
        #expect(engine.handle(control: "parameter.scale", values: [0.25]) == .accepted)
        reference.setParameter("scale", normalized: 0.25)
        #expect(try core(engine).document.parameters == reference.composition.parameters)
        #expect(engine.handle(control: "reset.scale") == .accepted)
        reference.resetParameter("scale")
        #expect(try core(engine).document.parameters == reference.composition.parameters)
        #expect(engine.handle(control: "preset", values: [1]) == .accepted)
        reference.choosePreset(family.presets[1].id)
        #expect(engine.handle(control: "parameter.warp", values: [0.1]) == .accepted)
        reference.setParameter("warp", normalized: 0.1)
        #expect(engine.handle(control: "resetAll") == .accepted)
        reference.resetAll()
        let state = try core(engine)
        #expect(state.document.parameters == reference.composition.parameters)
        #expect(state.document.seed == reference.composition.seed)
        #expect(state.document.paletteID == reference.composition.paletteID)
        #expect(state.presetID == family.presets[1].id)
    }

    @Test func timeAdvancesOnlyInStepsAndWrapsLikeTheSceneClock() async throws {
        var engine = try await engine()
        let before = try core(engine).time
        #expect(engine.handle(control: "palette", values: [1]) == .accepted)
        #expect(try core(engine).time == before, "an action does not move the time")
        try engine.run(steps: 120)
        #expect(abs(try core(engine).time - 1) < 1e-9, "120 steps of 1/120 s at rate 1")
        #expect(engine.handle(control: "rate", values: [0.5]) == .accepted)
        try engine.run(steps: 120)
        #expect(abs(try core(engine).time - 1.5) < 1e-9)
        #expect(engine.handle(control: "pause") == .accepted)
        try engine.run(steps: 50)
        #expect(abs(try core(engine).time - 1.5) < 1e-9, "paused time stays")
        #expect(engine.handle(control: "play") == .accepted)
        #expect(engine.handle(control: "scrub", values: [GenerativeArtCore.duration]) == .accepted)
        #expect(try core(engine).time == GenerativeArtCore.duration.nextDown, "the end maps to just before 120 s")
        #expect(engine.handle(control: "rate", values: [1]) == .accepted)
        try engine.run(steps: 2)
        #expect(try core(engine).time < 0.1, "the time wraps at 120 s")
    }

    @Test func shuffleIsADeterministicDerivationOfTheCurrentSeed() async throws {
        var first = try await engine(seed: 1)
        var second = try await engine(seed: 1)
        let seed = try core(first).document.seed
        #expect(first.handle(control: "seed.shuffle") == .accepted)
        #expect(second.handle(control: "seed.shuffle") == .accepted)
        let shuffled = try core(first).document.seed
        #expect(shuffled != seed)
        #expect(try core(second).document.seed == shuffled)
        var random = SeededRandom(seed: seed)
        var editor = CompositionEditor(family: FamilyCatalog.family(.particles))
        editor.shuffleSeed(using: &random)
        #expect(editor.composition.seed == shuffled, "the app's shuffle with SeededRandom(current seed)")
    }

    @Test func openRebaseAndTheSeedHalvesRestoreASavedComposition() async throws {
        var engine = try await engine()
        let seed: UInt64 = 0xDEAD_BEEF_0123_4567
        let halves = GenerativeArtCore.halves(of: seed)
        #expect(GenerativeArtCore.seed(high: halves.high, low: halves.low) == seed)
        #expect(engine.handle(control: "open", values: [2, 5, halves.high, halves.low, 33]) == .accepted)
        #expect(engine.handle(control: "value.cells", values: [10]) == .accepted)
        #expect(engine.handle(control: "rebase") == .accepted)
        #expect(engine.handle(control: "value.cells", values: [12]) == .accepted)
        #expect(engine.handle(control: "reset.cells") == .accepted)
        let state = try core(engine)
        #expect(state.family.id == .geometricTiling)
        #expect(state.document.seed == seed)
        #expect(state.document.paletteID == FamilyCatalog.palettes[5].id)
        #expect(state.document.parameters["cells"] == 10, "reset returns to the opened values")
        #expect(state.presetID == nil)
        #expect(state.time == 33)
    }

    @Test func theSnapshotRoundTripGivesTheSameDigest() async throws {
        var engine = try await engine(seed: 99)
        for (control, values) in [("family", [3.0]), ("parameter.size", [0.8]), ("save", []), ("rate", [2])] {
            #expect(engine.handle(control: control, values: values) == .accepted)
            try engine.run(steps: 17)
        }
        let snapshot = try engine.snapshot()
        let digest = try engine.digest()
        var restored = ExperienceEngine<GenerativeArtCore>(id: id)
        try await restored.prepare(seed: 99)
        try restored.restore(try ExperienceSnapshot(data: try snapshot.encoded()))
        #expect(try restored.digest() == digest)
        #expect(try core(restored) == core(engine))
    }

    @Test func theOutcomeIsWorkSavedAfterASave() async throws {
        var engine = try await engine()
        #expect(engine.outcome == nil)
        #expect(engine.handle(control: "save") == .accepted)
        #expect(engine.outcome?.code == "work-saved")
        try engine.reset()
        #expect(engine.outcome == nil, "a reset starts unsaved")
    }

    @Test func everyParameterHasItsThreeControls() {
        let ids = Set(GenerativeArtCore.controls.map(\.id))
        for definition in FamilyCatalog.all.flatMap(\.schema.definitions) {
            for prefix in ["parameter.", "value.", "reset."] {
                #expect(ids.contains(prefix + definition.name))
            }
        }
        #expect(GenerativeArtCore.controls.count == ids.count, "no control twice")
    }
}
