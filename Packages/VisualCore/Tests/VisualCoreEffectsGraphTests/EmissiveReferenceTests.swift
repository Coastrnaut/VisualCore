// EmissiveReferenceTests — feature 207 R02-F07 T-R02F07-002 (FR-R02F07-006; research R2, R3, R4): the CPU reference
// of the emissive pass round-trips sRGB, decodes above 1 unclamped, knees continuously, tone-maps monotonically
// into 0…1 and composites with the documented formulas.
import Testing
@testable import VisualCoreEffectsGraph

@Test func srgbRoundTripsEvery8BitValue() {
    for i in 0...255 {
        let x = Double(i) / 255
        #expect(abs(EmissiveReference.srgbEncode(EmissiveReference.srgbDecode(x)) - x) <= 1.0 / 255)
    }
}

@Test func srgbDecodeContinuesAboveOneAndClampsBelowZero() {
    #expect(EmissiveReference.srgbDecode(1.1) > 1)
    #expect(EmissiveReference.srgbDecode(2) > EmissiveReference.srgbDecode(1.1))
    #expect(EmissiveReference.srgbDecode(-0.5) == 0)
    #expect(abs(EmissiveReference.srgbDecode(1) - 1) < 1e-12)
    #expect(abs(EmissiveReference.srgbEncode(4) - 1) < 1e-12 && EmissiveReference.srgbEncode(4) <= 1)
    #expect(EmissiveReference.srgbEncode(-1) == 0)
}

@Test func luminanceUsesRec709Weights() {
    #expect(abs(EmissiveReference.luminance(SIMD3(1, 1, 1)) - 1) < 1e-12)
    #expect(EmissiveReference.luminance(SIMD3(1, 0, 0)) == 0.2126)
    #expect(EmissiveReference.luminance(SIMD3(0, 1, 0)) == 0.7152)
    #expect(EmissiveReference.luminance(SIMD3(0, 0, 1)) == 0.0722)
}

@Test func prefilterIsZeroBelowTheKneeAndContinuousAtBothEnds() {
    let threshold = 1.0, knee = 0.5, k = knee * threshold
    let grey = { (l: Double) in SIMD3(l, l, l) }       // luminance of grey l is l
    for l in stride(from: 0.0, through: threshold - k, by: 0.05) {
        #expect(EmissiveReference.prefilter(grey(l), threshold: threshold, knee: knee) == .zero)
    }
    for edge in [threshold - k, threshold + k] {
        let below = EmissiveReference.prefilter(grey(edge - 1e-9), threshold: threshold, knee: knee)
        let above = EmissiveReference.prefilter(grey(edge + 1e-9), threshold: threshold, knee: knee)
        #expect(abs(below.x - above.x) < 1e-6)
    }
    // Inside the knee the curve is positive; above it, it is the linear part L − threshold.
    #expect(EmissiveReference.prefilter(grey(1), threshold: threshold, knee: knee).x > 0)
    #expect(abs(EmissiveReference.prefilter(grey(3), threshold: threshold, knee: knee).x - 2) < 1e-9)
}

@Test func prefilterWithZeroKneeIsAHardThreshold() {
    for l in stride(from: 0.0, through: 4.0, by: 0.125) {
        let rgb = SIMD3(l, l * 0.5, l * 0.25)
        let lum = EmissiveReference.luminance(rgb)
        let expected = rgb * (max(0, lum - 1) / max(lum, 1e-5))
        let got = EmissiveReference.prefilter(rgb, threshold: 1, knee: 0)
        #expect(abs(got.x - expected.x) < 1e-9 && abs(got.y - expected.y) < 1e-9 && abs(got.z - expected.z) < 1e-9)
    }
}

@Test func toneMapsAreMonotonicAndBoundedOnZeroToSixtyFour() {
    for op in ToneMapOperator.allCases {
        #expect(EmissiveReference.toneMap(0, op) == 0)
        #expect(EmissiveReference.toneMap(-3, op) == 0)
        var previous = 0.0
        for i in 0...6400 {
            let y = EmissiveReference.toneMap(Double(i) / 100, op)
            #expect(y >= previous)
            if op == .reinhard { #expect(y < 1) } else { #expect(y <= 1) }
            previous = y
        }
    }
    #expect(EmissiveReference.toneMap(1, .reinhard) == 0.5)
    #expect(EmissiveReference.toneMap(0.25, .none) == 0.25)
}

@Test func compositeWithoutGlowOrExposureIsTheClampedBase() {
    let base = SIMD3(0.2, 0.9, 1.7)
    let c = EmissiveReference.composite(base: base, glow: .zero, intensity: 1, exposure: 0, op: .none)
    #expect(c == SIMD3(0.2, 0.9, 1))
    let lifted = EmissiveReference.composite(base: SIMD3(0.1, 0.1, 0.1), glow: SIMD3(0.1, 0, 0), intensity: 2,
                                             exposure: 1, op: .none)
    #expect(abs(lifted.x - 0.6) < 1e-12 && abs(lifted.y - 0.2) < 1e-12)
}

@Test func premultipliedOverFollowsTheFormula() {
    let base = SIMD4(0.2, 0.4, 0.6, 1.0)
    let cases: [(SIMD4<Double>, Double)] = [(SIMD4(0.5, 0.25, 0, 0.5), 1), (SIMD4(0.3, 0.3, 0.3, 0.6), 0.5),
                                            (SIMD4(0, 0, 0, 0), 1), (SIMD4(1, 1, 1, 1), 0)]
    for (overlay, opacity) in cases {
        let got = EmissiveReference.premultipliedOver(overlay: overlay, base: base, opacity: opacity)
        let want = overlay * opacity + base * (1 - overlay.w * opacity)
        #expect(got == want)
    }
    #expect(EmissiveReference.premultipliedOver(overlay: SIMD4(0.5, 0.25, 0, 0.5), base: base, opacity: 1)
            == SIMD4(0.6, 0.45, 0.3, 1.0))
}
