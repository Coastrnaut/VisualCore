// RenderCostEstimateTests — feature 029 T-A03-401 (FR-A03-401, SC-A03-401; contract capture-tour-cost).
import Testing
@testable import VisualCoreDiagnostics

@Suite struct RenderCostEstimateTests {
    let reference = RenderCostEstimate(pixels: 1_170 * 1_170, iterations: 200)

    @Test func ratioIsOneAtTheReference() {
        #expect(RenderCostEstimate(pixels: 1_170 * 1_170, iterations: 200).relative(to: reference) == 1)
    }

    @Test func doublingAnyFactorDoubles() {
        #expect(RenderCostEstimate(pixels: 1_170 * 1_170, iterations: 400).relative(to: reference) == 2)
        #expect(RenderCostEstimate(pixels: 2 * 1_170 * 1_170, iterations: 200).relative(to: reference) == 2)
        #expect(RenderCostEstimate(pixels: 1_170 * 1_170, iterations: 200, samples: 2).relative(to: reference) == 2)
    }

    @Test func monotonicInIterations() {
        var last = 0.0
        for cap in stride(from: 50, through: 10_000, by: 50) {
            let r = RenderCostEstimate(pixels: 1_170 * 1_170, iterations: Double(cap)).relative(to: reference)
            #expect(r > last)
            last = r
        }
    }

    @Test func levelsAtThresholds() {
        #expect(RenderCostEstimate.level(ratio: 1) == .light)
        #expect(RenderCostEstimate.level(ratio: 2) == .light)
        #expect(RenderCostEstimate.level(ratio: 2.01) == .moderate)
        #expect(RenderCostEstimate.level(ratio: 10) == .moderate)
        #expect(RenderCostEstimate.level(ratio: 10.5) == .heavy)
    }

    @Test func textFormats() {
        #expect(RenderCostEstimate.text(ratio: 1) == "1×")
        #expect(RenderCostEstimate.text(ratio: 2.5) == "2.5×")
        #expect(RenderCostEstimate.text(ratio: 0.25) == "0.25×")
        #expect(RenderCostEstimate.text(ratio: 63.2) == "63×")
        #expect(RenderCostEstimate.text(ratio: 1_234) == "1.2e3×")
        #expect(RenderCostEstimate.text(ratio: 9_960) == "1e4×")
        #expect(RenderCostEstimate.text(ratio: .infinity) == "—")
    }

    @Test func invalidFactorsCountAsOne() {
        let e = RenderCostEstimate(pixels: -5, iterations: .nan, samples: 0)
        #expect(e.work == 1)
    }
}
