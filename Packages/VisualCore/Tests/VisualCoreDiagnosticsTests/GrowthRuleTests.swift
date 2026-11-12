// GrowthRuleTests — feature 192 T-U06-009 (UA-F06; FR-U06-051; data-model section 4).
import Testing
@testable import VisualCoreDiagnostics

private let mib = 1024 * 1024

/// `count` samples with the same footprint and graphics bytes.
private func constantSamples(_ count: Int, footprint: Int? = 100 * mib, gpu: Int = 4 * mib) -> [ResourceSample] {
    Array(repeating: ResourceSample(footprintBytes: footprint, gpuBytes: gpu), count: count)
}

/// 60 samples: warm-up = 6, rest = 54, quarter = 13. Samples 0…18 (the warm-up and the first quarter of the rest)
/// have the footprint `base`; samples 19…59 (which include the last quarter, 47…59) have `base + rise`.
private func risingFootprintSamples(base: Int, rise: Int, gpu: Int = 4 * mib) -> [ResourceSample] {
    (0..<60).map { ResourceSample(footprintBytes: $0 < 19 ? base : base + rise, gpuBytes: gpu) }
}

@Test func growthRuleConstants() {
    #expect(GrowthRule.minimumSamples == 60)
    #expect(GrowthRule.footprintMarginBytes == 8_388_608)
    #expect(GrowthRule.footprintMarginShare == 0.05)
    #expect(GrowthRule.gpuQuantity == "gpu_bytes")
    #expect(GrowthRule.footprintQuantity == "memory_footprint_bytes")
}

@Test func growthRuleRefusesFewerThanSixtySamples() {
    let verdict = GrowthRule.judge(constantSamples(59))
    #expect(verdict == .tooFewSamples(59))
    #expect(!verdict.passes)
    #expect(GrowthRule.judge([]) == .tooFewSamples(0))
}

@Test func growthRuleSixtyIdenticalSamplesAreFlat() {
    let verdict = GrowthRule.judge(constantSamples(60))
    #expect(verdict == .flat(footprintChecked: true))
    #expect(verdict.passes)
}

@Test func growthRuleGraphicsGrowthAfterWarmUp() {
    // Warm-up maximum 4 MiB; sample 30 holds 4 MiB + 4,096 → grew by 4,096.
    var samples = constantSamples(60)
    samples[30].gpuBytes = 4 * mib + 4_096
    let verdict = GrowthRule.judge(samples)
    #expect(verdict == .grew(quantity: "gpu_bytes", by: 4_096))
    #expect(!verdict.passes)
    // The first sample after the warm-up (index 6) is already judged.
    var edge = constantSamples(60)
    edge[6].gpuBytes = 4 * mib + 1
    #expect(GrowthRule.judge(edge) == .grew(quantity: "gpu_bytes", by: 1))
}

@Test func growthRuleGraphicsGrowthInsideWarmUpIsAllowed() {
    // Samples 0…5 rise 1,000 … 6,000 (warm-up maximum 6,000); afterwards constant at 6,000.
    let atMaximum = (0..<60).map { ResourceSample(footprintBytes: 100 * mib, gpuBytes: $0 < 6 ? ($0 + 1) * 1_000 : 6_000) }
    #expect(GrowthRule.judge(atMaximum) == .flat(footprintChecked: true))
    // Afterwards below the warm-up maximum.
    let below = (0..<60).map { ResourceSample(footprintBytes: 100 * mib, gpuBytes: $0 < 6 ? ($0 + 1) * 1_000 : 5_000) }
    #expect(GrowthRule.judge(below) == .flat(footprintChecked: true))
    // The last warm-up sample (index 5) may hold the peak.
    var peak = constantSamples(60)
    peak[5].gpuBytes = 64 * mib
    #expect(GrowthRule.judge(peak) == .flat(footprintChecked: true))
}

@Test func growthRuleFootprintAbsoluteMargin() {
    // Base 100 MiB: 5 % = 5 MiB < 8 MiB, so the margin is 8 MiB = 8,388,608.
    // First median = 100 MiB, last median = 100 MiB + rise.
    let grew = GrowthRule.judge(risingFootprintSamples(base: 100 * mib, rise: 8 * mib + 1))
    #expect(grew == .grew(quantity: "memory_footprint_bytes", by: 8_388_609))
    #expect(!grew.passes)
    let inside = GrowthRule.judge(risingFootprintSamples(base: 100 * mib, rise: 8 * mib))
    #expect(inside == .flat(footprintChecked: true), "exactly the margin is not more than the margin")
    // A footprint that falls is flat.
    #expect(GrowthRule.judge(risingFootprintSamples(base: 100 * mib, rise: -50 * mib)) == .flat(footprintChecked: true))
}

@Test func growthRuleFootprintRelativeMargin() {
    // Base 400 MiB = 419,430,400: 5 % = 20,971,520 = 20 MiB > 8 MiB, so the margin is 20 MiB.
    let inside = GrowthRule.judge(risingFootprintSamples(base: 400 * mib, rise: 20 * mib))
    #expect(inside == .flat(footprintChecked: true))
    let grew = GrowthRule.judge(risingFootprintSamples(base: 400 * mib, rise: 20 * mib + 1_024))
    #expect(grew == .grew(quantity: "memory_footprint_bytes", by: 20_972_544))
}

@Test func growthRuleFootprintGrowthInsideWarmUpIsAllowed() {
    // Samples 0…5 rise from 10 MiB to 60 MiB, afterwards constant at 100 MiB: both medians are 100 MiB.
    let samples = (0..<60).map { ResourceSample(footprintBytes: $0 < 6 ? ($0 + 1) * 10 * mib : 100 * mib, gpuBytes: 4 * mib) }
    #expect(GrowthRule.judge(samples) == .flat(footprintChecked: true))
}

@Test func growthRuleMedianOfEvenCountIsTheLowerMiddle() {
    // 80 samples: warm-up = 8, rest = 72, quarter = 18 (even). Base 100 MiB, margin 8 MiB.
    // First quarter (indices 8…25): 9 × 100 MiB and 9 × 101 MiB → lower middle = 100 MiB.
    // Last quarter (indices 62…79): 9 × 108 MiB and 9 × 200 MiB → lower middle = 108 MiB.
    // 108 MiB − 100 MiB = 8 MiB = the margin → flat. (The upper middles would give 200 − 101 = 99 MiB.)
    let samples = (0..<80).map { index -> ResourceSample in
        let footprint: Int
        switch index {
        case 8..<17: footprint = 100 * mib
        case 17..<26: footprint = 101 * mib
        case 62..<71: footprint = 108 * mib
        case 71..<80: footprint = 200 * mib
        default: footprint = 100 * mib
        }
        return ResourceSample(footprintBytes: footprint, gpuBytes: 4 * mib)
    }
    #expect(GrowthRule.judge(samples) == .flat(footprintChecked: true))
}

@Test func growthRuleWithoutEveryFootprintChecksGraphicsOnly() {
    // The footprint rises by 300 MiB, but one sample has none: only the graphics bytes are judged.
    var samples = risingFootprintSamples(base: 100 * mib, rise: 300 * mib)
    samples[40].footprintBytes = nil
    let verdict = GrowthRule.judge(samples)
    #expect(verdict == .flat(footprintChecked: false))
    #expect(verdict.passes)
    // A missing footprint inside the warm-up counts as well.
    var warm = risingFootprintSamples(base: 100 * mib, rise: 300 * mib)
    warm[0].footprintBytes = nil
    #expect(GrowthRule.judge(warm) == .flat(footprintChecked: false))
    // No footprint at all.
    #expect(GrowthRule.judge(constantSamples(60, footprint: nil)) == .flat(footprintChecked: false))
    // Graphics growth is still found.
    samples[59].gpuBytes = 4 * mib + 7
    #expect(GrowthRule.judge(samples) == .grew(quantity: "gpu_bytes", by: 7))
}

@Test func growthRuleChecksGraphicsBeforeFootprint() {
    // Both grow: the footprint by 300 MiB and the graphics bytes by 2,048; the graphics verdict comes first.
    var samples = risingFootprintSamples(base: 100 * mib, rise: 300 * mib)
    samples[45].gpuBytes = 4 * mib + 2_048
    #expect(GrowthRule.judge(samples) == .grew(quantity: "gpu_bytes", by: 2_048))
}

@Test func growthVerdictPasses() {
    #expect(GrowthVerdict.flat(footprintChecked: true).passes)
    #expect(GrowthVerdict.flat(footprintChecked: false).passes)
    #expect(!GrowthVerdict.grew(quantity: "gpu_bytes", by: 1).passes)
    #expect(!GrowthVerdict.tooFewSamples(0).passes)
}
