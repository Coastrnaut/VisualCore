// EasingTests — feature 006 T-F509 (FR-F505).
import Foundation
import Testing
@testable import VisualCoreMath

@Test(arguments: EasingCurve.allCases)
func endpointsAreExact(_ curve: EasingCurve) {
    for mode in EasingMode.allCases {
        #expect(ease(0, curve, mode) == 0)
        #expect(ease(1, curve, mode) == 1)
        #expect(ease(-5, curve, mode) == 0, "clamped below")
        #expect(ease(7, curve, mode) == 1, "clamped above")
        #expect(abs(ease(0.5, curve, .inOut) - 0.5) < 1e-12, "in-out is symmetric about 0.5")
        #expect(ease(.nan, curve, mode) == 0)
    }
}

@Test(arguments: EasingCurve.allCases)
func outIsMirrorOfIn(_ curve: EasingCurve) {
    for t in stride(from: 0.05, through: 0.95, by: 0.05) {
        #expect(abs(ease(t, curve, .out) - (1 - ease(1 - t, curve, .in))) < 1e-12)
        #expect(abs(ease(t, curve, .inOut) + ease(1 - t, curve, .inOut) - 1) < 1e-12)
    }
}

@Test func knownValues() {
    #expect(ease(0.5, .linear, .in) == 0.5)
    #expect(ease(0.5, .quad, .in) == 0.25)
    #expect(ease(0.5, .cubic, .out) == 0.875)
    #expect(abs(ease(0.5, .sine, .in) - (1 - cos(.pi / 4))) < 1e-15)
    #expect(ease(0.3, .back, .in) < 0, "back undershoots at the start")
    #expect(ease(0.9, .elastic, .out) > 1 || ease(0.8, .elastic, .out) > 1, "elastic overshoots")
    #expect(abs(ease(1 / 2.75, .bounce, .out) - 1) < 1e-12, "bounce touches 1 at its first impact")
}

@Test(arguments: [EasingCurve.linear, .quad, .cubic, .sine, .expo])
func monotonicCurvesIncrease(_ curve: EasingCurve) {
    for mode in EasingMode.allCases {
        var last = 0.0
        for i in 1...100 {
            let v = ease(Double(i) / 100, curve, mode)
            #expect(v >= last)
            last = v
        }
    }
}
