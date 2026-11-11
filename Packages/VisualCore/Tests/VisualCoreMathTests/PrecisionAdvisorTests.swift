// PrecisionAdvisorTests — feature 027 T-A03-201 (G-PRECISION; FR-A03-205, SC-A03-203; clarification 2; research R2).
import Foundation
import Testing
@testable import VisualCoreMath

@Test func thresholdsFollowTheMantissaBits() {
    for bits in [10, 16, 23] {
        let ulp = pow(2.0, Double(-bits))   // at magnitude 1
        #expect(PrecisionAdvisor.assess(mantissaBits: bits, magnitude: 1, pixelStep: ulp * 100).level == .reliable)
        #expect(PrecisionAdvisor.assess(mantissaBits: bits, magnitude: 1, pixelStep: ulp * 16).level == .reliable, "16 steps is still reliable")
        #expect(PrecisionAdvisor.assess(mantissaBits: bits, magnitude: 1, pixelStep: ulp * 15.9).level == .nearLimit)
        #expect(PrecisionAdvisor.assess(mantissaBits: bits, magnitude: 1, pixelStep: ulp * 1).level == .nearLimit)
        #expect(PrecisionAdvisor.assess(mantissaBits: bits, magnitude: 1, pixelStep: ulp * 0.99).level == .beyondLimit)
        #expect(abs(PrecisionAdvisor.minimumPixelStep(mantissaBits: bits, magnitude: 1) - ulp) < ulp * 1e-12)
    }
}

@Test func marginIsStepsOfOneUlp() {
    let s = PrecisionAdvisor.assess(mantissaBits: 23, magnitude: 2, pixelStep: 2 * pow(2.0, -23) * 40)
    #expect(abs(s.margin - 40) < 1e-9)
    #expect(s.level == .reliable)
    #expect(abs(s.minimumPixelStep - 2 * pow(2.0, -23)) < 1e-18)
}

@Test func zeroMagnitudeIsNotBlocked() {
    // At the origin the coordinate magnitude is 0: the pixel step itself sets the scale, so it stays reliable.
    let s = PrecisionAdvisor.assess(mantissaBits: 23, magnitude: 0, pixelStep: 1e-30)
    #expect(s.level == .reliable)
    #expect(PrecisionAdvisor.minimumPixelStep(mantissaBits: 23, magnitude: 0) > 0)
}

@Test func minimumStepGrowsWithMagnitude() {
    var last = 0.0
    for m in [0.001, 0.1, 1, 2, 10, 1000] {
        let step = PrecisionAdvisor.minimumPixelStep(mantissaBits: 23, magnitude: m)
        #expect(step > last)
        last = step
    }
    #expect(PrecisionAdvisor.minimumPixelStep(mantissaBits: 23, magnitude: -4) == PrecisionAdvisor.minimumPixelStep(mantissaBits: 23, magnitude: 4))
}

@Test func invalidInputIsBeyondLimit() {
    for (bits, m, step) in [(23, Double.nan, 1e-3), (23, 1, Double.infinity), (23, 1, 0), (23, 1, -1e-3), (0, 1, 1e-3)] {
        let s = PrecisionAdvisor.assess(mantissaBits: bits, magnitude: m, pixelStep: step)
        #expect(s.level == .beyondLimit, "\(bits) \(m) \(step)")
        #expect(s.margin == 0)
    }
}

@Test func moreBitsAllowSmallerSteps() {
    #expect(PrecisionAdvisor.minimumPixelStep(mantissaBits: 23, magnitude: 1) < PrecisionAdvisor.minimumPixelStep(mantissaBits: 10, magnitude: 1))
    #expect(PrecisionAdvisor.minimumPixelStep(mantissaBits: 52, magnitude: 1) < 1e-15)
}

@Test func bitsAreClamped() {
    #expect(PrecisionAdvisor.minimumPixelStep(mantissaBits: 500, magnitude: 1) == PrecisionAdvisor.minimumPixelStep(mantissaBits: 64, magnitude: 1))
}
