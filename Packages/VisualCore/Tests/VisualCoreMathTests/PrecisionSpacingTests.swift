// PrecisionSpacingTests — feature 029 T-A03-403 (FR-A03-407, SC-A03-404; Phase 04 regression fixture): the precision
// advisor's smallest pixel step rests on the real spacing of floating-point numbers. For 23 mantissa bits (32-bit
// floats) and 10 bits (16-bit floats) the advisor's step lies within [1, 2] × the true spacing at each magnitude.
import Foundation
import Testing
@testable import VisualCoreMath

@Suite struct PrecisionSpacingTests {
    /// 48 magnitudes from 2⁻²⁰ to 4: powers of two, their neighbours and values in between.
    static let magnitudes: [Double] = {
        var m: [Double] = []
        for e in stride(from: -20, through: 1, by: 3) {
            let p = pow(2.0, Double(e))
            m += [p, p * 1.000_001, p * 1.5, p * 1.999_999, p * 1.25, p * 1.75]
        }
        return Array(m.prefix(48))
    }()

    /// The true spacing of floats with `bits` mantissa bits in the binade that contains `m` (normal range):
    /// 2^(⌊log₂ m⌋ − bits). (Converting m first, as `Float16(m).ulp` does, can round up into the next binade, whose
    /// spacing is twice as large; the first run of this fixture failed on exactly that.)
    static func spacing(_ m: Double, bits: Int) -> Double { pow(2, log2(m).rounded(.down) - Double(bits)) }

    @Test func spacingFormulaMatchesTheHardwareFormats() {
        for m in Self.magnitudes {
            if Double(Float(m)) <= m { #expect(Double(Float(m).ulp) == Self.spacing(m, bits: 23), "m = \(m)") }
            #if arch(arm64)
            if m >= pow(2, -14), Double(Float16(m)) <= m { #expect(Double(Float16(m).ulp) == Self.spacing(m, bits: 10), "m = \(m)") }
            #endif
        }
    }

    @Test func twentyThreeBitsFollowFloat32Spacing() {
        #expect(Self.magnitudes.count == 48)
        for m in Self.magnitudes {
            let ulp = Self.spacing(m, bits: 23)
            let step = PrecisionAdvisor.minimumPixelStep(mantissaBits: 23, magnitude: m)
            #expect(step >= ulp * (1 - 1e-9), "m = \(m): step \(step) below the float32 spacing \(ulp)")
            #expect(step <= 2 * ulp * (1 + 1e-9), "m = \(m): step \(step) above twice the float32 spacing \(ulp)")
        }
    }

    @Test func tenBitsFollowFloat16Spacing() {
        // 16-bit floats are normal from 2⁻¹⁴; below that their spacing is fixed, so the fixture covers ≥ 2⁻¹⁴.
        for m in Self.magnitudes where m >= pow(2, -14) {
            let ulp = Self.spacing(m, bits: 10)
            let step = PrecisionAdvisor.minimumPixelStep(mantissaBits: 10, magnitude: m)
            #expect(step >= ulp * (1 - 1e-9), "m = \(m): step \(step) below the float16 spacing \(ulp)")
            #expect(step <= 2 * ulp * (1 + 1e-9), "m = \(m): step \(step) above twice the float16 spacing \(ulp)")
        }
    }

    @Test func assessmentAgreesWithTheSpacing() {
        // One pixel step equal to the float32 spacing at the magnitude is at (or just past) the limit, never "reliable".
        for m in Self.magnitudes {
            let status = PrecisionAdvisor.assess(mantissaBits: 23, magnitude: m, pixelStep: Self.spacing(m, bits: 23))
            #expect(status.level != .reliable, "m = \(m)")
        }
    }
}
