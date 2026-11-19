// CaseTests — feature 173 (A24-P01) T-A24-105 (FR-A24-101, FR-A24-102; SC-A24-102; clarification Q1). The three
// built-in cases validate with three distinct, stable fingerprints; one changed value (id, version, configuration,
// resolution scale, plan) changes the fingerprint; each cap is accepted at its bounds and refused one past them; a
// field of the wrong workload, or a missing one, is refused naming the field; a NaN resolution scale is refused as
// not finite. Synthetic data only.
import Foundation
import Testing
import VisualCoreExperience
@testable import GraphicsBenchmarkLabCore

@Suite struct CaseTests {
    /// The refusal of `benchmarkCase`, or nil when it validates.
    private static func refusal(_ benchmarkCase: BenchmarkCase) -> CaseError? {
        do {
            try benchmarkCase.validate()
            return nil
        } catch {
            return error
        }
    }

    /// The fingerprint hex of `benchmarkCase`, or nil when it is refused.
    private static func hex(_ benchmarkCase: BenchmarkCase) -> String? {
        try? benchmarkCase.fingerprint().hex
    }

    @Test func builtInsValidateWithDistinctStableFingerprints() throws {
        let cases = BenchmarkCase.builtIn
        let ids = cases.map { $0.id }
        #expect(ids == ["quads", "alu", "particles"])
        var seen: Set<String> = []
        for benchmarkCase in cases {
            let error = Self.refusal(benchmarkCase)
            #expect(error == nil)
            let first = try benchmarkCase.fingerprint()
            let second = try benchmarkCase.fingerprint()
            #expect(first == second)
            seen.insert(first.hex)
            #expect(benchmarkCase.version == 1)
            #expect(benchmarkCase.config.resolutionScale == 1.0)
            #expect(benchmarkCase.plan == RunPlan(warmUpSeconds: 3, measureSeconds: 10, coolDownSeconds: 5))
        }
        #expect(seen.count == 3)
        let total = BenchmarkCase.quads.plan.totalSeconds
        #expect(total == 18)
        let longest = RunPlan(warmUpSeconds: 30, measureSeconds: 60, coolDownSeconds: 120).totalSeconds
        #expect(longest == 210)
    }

    @Test func builtInValues() {
        let quads = BenchmarkCase.quads.config
        #expect(quads == WorkloadConfig(layers: 8, textureSize: 256, resolutionScale: 1.0))
        let alu = BenchmarkCase.alu.config
        #expect(alu == WorkloadConfig(iterations: 64, resolutionScale: 1.0))
        let particles = BenchmarkCase.particles.config
        #expect(particles == WorkloadConfig(particles: 5_000, resolutionScale: 1.0))
    }

    @Test func oneChangedValueChangesTheFingerprint() {
        let base = Self.hex(.quads)
        #expect(base != nil)
        var variants: [BenchmarkCase] = []
        var changed = BenchmarkCase.quads
        changed.id = "quads-b"
        variants.append(changed)
        changed = .quads
        changed.version = 2
        variants.append(changed)
        changed = .quads
        changed.config.layers = 9
        variants.append(changed)
        changed = .quads
        changed.config.textureSize = 512
        variants.append(changed)
        changed = .quads
        changed.config.resolutionScale = 0.5
        variants.append(changed)
        changed = .quads
        changed.plan.warmUpSeconds = 4
        variants.append(changed)
        changed = .quads
        changed.plan.measureSeconds = 11
        variants.append(changed)
        changed = .quads
        changed.plan.coolDownSeconds = 6
        variants.append(changed)
        var hexes: Set<String> = []
        for variant in variants {
            let variantHex = Self.hex(variant)
            #expect(variantHex != nil)
            #expect(variantHex != base)
            if let variantHex { hexes.insert(variantHex) }
        }
        #expect(hexes.count == variants.count)
    }

    @Test func quadsCapsAtAndPastTheirBounds() {
        var value = BenchmarkCase.quads
        for layers in [1, 64] {
            value.config.layers = layers
            let error = Self.refusal(value)
            #expect(error == nil)
        }
        for layers in [0, 65] {
            value.config.layers = layers
            let error = Self.refusal(value)
            #expect(error == .outOfRange(field: "layers"))
        }
        value = .quads
        for size in [64, 1_024] {
            value.config.textureSize = size
            let error = Self.refusal(value)
            #expect(error == nil)
        }
        for size in [32, 2_048, 96] {
            value.config.textureSize = size
            let error = Self.refusal(value)
            #expect(error == .outOfRange(field: "textureSize"))
        }
    }

    @Test func aluAndParticlesCapsAtAndPastTheirBounds() {
        var alu = BenchmarkCase.alu
        for iterations in [1, 1_024] {
            alu.config.iterations = iterations
            let error = Self.refusal(alu)
            #expect(error == nil)
        }
        for iterations in [0, 1_025] {
            alu.config.iterations = iterations
            let error = Self.refusal(alu)
            #expect(error == .outOfRange(field: "iterations"))
        }
        var particles = BenchmarkCase.particles
        for count in [1, 100_000] {
            particles.config.particles = count
            let error = Self.refusal(particles)
            #expect(error == nil)
        }
        for count in [0, 100_001] {
            particles.config.particles = count
            let error = Self.refusal(particles)
            #expect(error == .outOfRange(field: "particles"))
        }
    }

    @Test func resolutionScaleCaps() {
        var value = BenchmarkCase.alu
        for scale in [0.25, 1.0] {
            value.config.resolutionScale = scale
            let error = Self.refusal(value)
            #expect(error == nil)
        }
        for scale in [0.24, 1.01] {
            value.config.resolutionScale = scale
            let error = Self.refusal(value)
            #expect(error == .outOfRange(field: "resolutionScale"))
        }
        for scale in [Double.nan, Double.infinity] {
            value.config.resolutionScale = scale
            let error = Self.refusal(value)
            #expect(error == .notFinite(field: "resolutionScale"))
            let digest = Self.hex(value)
            #expect(digest == nil)
        }
    }

    @Test func planCapsAtAndPastTheirBounds() {
        var value = BenchmarkCase.particles
        for seconds in [1, 30] {
            value.plan.warmUpSeconds = seconds
            let error = Self.refusal(value)
            #expect(error == nil)
        }
        for seconds in [0, 31] {
            value.plan.warmUpSeconds = seconds
            let error = Self.refusal(value)
            #expect(error == .outOfRange(field: "warmUpSeconds"))
        }
        value = .particles
        for seconds in [1, 60] {
            value.plan.measureSeconds = seconds
            let error = Self.refusal(value)
            #expect(error == nil)
        }
        for seconds in [0, 61] {
            value.plan.measureSeconds = seconds
            let error = Self.refusal(value)
            #expect(error == .outOfRange(field: "measureSeconds"))
        }
        value = .particles
        for seconds in [0, 120] {
            value.plan.coolDownSeconds = seconds
            let error = Self.refusal(value)
            #expect(error == nil)
        }
        for seconds in [-1, 121] {
            value.plan.coolDownSeconds = seconds
            let error = Self.refusal(value)
            #expect(error == .outOfRange(field: "coolDownSeconds"))
        }
    }

    @Test func wrongWorkloadFieldsRefused() {
        var quads = BenchmarkCase.quads
        quads.config.iterations = 64
        let extra = Self.refusal(quads)
        #expect(extra == .wrongWorkloadFields(field: "iterations"))
        quads = .quads
        quads.config.textureSize = nil
        let missing = Self.refusal(quads)
        #expect(missing == .wrongWorkloadFields(field: "textureSize"))
        var alu = BenchmarkCase.alu
        alu.config.layers = 8
        let aluExtra = Self.refusal(alu)
        #expect(aluExtra == .wrongWorkloadFields(field: "layers"))
        var particles = BenchmarkCase.particles
        particles.config.particles = nil
        let particlesMissing = Self.refusal(particles)
        #expect(particlesMissing == .wrongWorkloadFields(field: "particles"))
        particles = .particles
        particles.workload = .alu
        let switched = Self.refusal(particles)
        #expect(switched == .wrongWorkloadFields(field: "iterations"))
    }

    @Test func idAndVersionRefused() {
        var value = BenchmarkCase.quads
        for id in ["", "Quads", "quads case", "quads_1"] {
            value.id = id
            let error = Self.refusal(value)
            #expect(error == .outOfRange(field: "id"))
        }
        value.id = "quads-2"
        let accepted = Self.refusal(value)
        #expect(accepted == nil)
        value = .quads
        value.version = 0
        let error = Self.refusal(value)
        #expect(error == .outOfRange(field: "version"))
    }

    @Test func caseRoundTripsThroughJSON() throws {
        let data = try JSONEncoder().encode(BenchmarkCase.builtIn)
        let decoded = try JSONDecoder().decode([BenchmarkCase].self, from: data)
        #expect(decoded == BenchmarkCase.builtIn)
    }
}
