// ColorVisionTests — feature 210 (R02-F10) T-R02F10-003 (FR-R02F10-004, FR-R02F10-005, FR-R02F10-006). Fixtures are
// literal; the target cannot import VisualCoreSimulation (see PerceptualColorTests).
import Foundation
import Testing
@testable import VisualCoreParameters

@Test func matrixRowsSumToOne() {
    for condition in ColorVisionCondition.allCases {
        for row in condition.matrix {
            #expect(abs(row.sum() - 1) < 1e-5)
        }
    }
    for row in ColorVisionCondition.achromatopsia.matrix { #expect(row.sum() == 1) }
}

@Test func greysUnderSimulation() {
    // The published Machado rows sum to 1 only within about 1e-6 (protanopia row 0 sums to 1.000001), so a grey
    // moves by up to about 1e-6 in sRGB; it is checked within 1e-6 (SC-R02F10-002; measured 4.4e-7).
    var worst = 0.0
    for condition in ColorVisionCondition.allCases {
        for g in [0.0, 0.18, 0.5, 1.0] {
            let c = SIMD3(g, g, g)
            let s = condition.simulate(sRGB: c)
            worst = max(worst, abs(s.x - c.x), abs(s.y - c.y), abs(s.z - c.z))
        }
    }
    print("R02-F10 grey error under simulation: \(worst)")
    #expect(worst < 1e-6)
    for g in [0.0, 0.18, 0.5, 1.0] {
        let s = ColorVisionCondition.normal.simulate(sRGB: SIMD3(g, g, g))
        #expect(max(abs(s.x - g), abs(s.y - g), abs(s.z - g)) < 1e-12)
    }
}

@Test func spotValuesByHand() {
    let srgb = SIMD3<Double>(0.6, 0.3, 0.2)
    let l = SIMD3(Palette.linear(fromSRGB: 0.6), Palette.linear(fromSRGB: 0.3), Palette.linear(fromSRGB: 0.2))
    let rows: [(ColorVisionCondition, [[Double]])] = [
        (.protanopia, [[0.152286, 1.052583, -0.204868], [0.114503, 0.786281, 0.099216], [-0.003882, -0.048116, 1.051998]]),
        (.deuteranopia, [[0.367322, 0.860646, -0.227968], [0.280085, 0.672501, 0.047413], [-0.011820, 0.042940, 0.968881]]),
        (.tritanopia, [[1.255528, -0.076749, -0.178779], [-0.078411, 0.930809, 0.147602], [0.004733, 0.691367, 0.303900]]),
        (.achromatopsia, [[0.2126, 0.7152, 0.0722], [0.2126, 0.7152, 0.0722], [0.2126, 0.7152, 0.0722]]),
    ]
    for (condition, m) in rows {
        let got = condition.simulate(sRGB: srgb)
        for i in 0..<3 {
            let lin = min(max(m[i][0] * l.x + m[i][1] * l.y + m[i][2] * l.z, 0), 1)
            #expect(abs(got[i] - Palette.sRGB(fromLinear: lin)) < 1e-6)
        }
    }
}

@Test func presetsSeparateUnderEveryCondition() {
    #expect(ColorVisionPresets.all.map(\.id) == ["cvd-warm-cool", "cvd-red-cyan", "cvd-lightness"])
    #expect(ColorVisionPresets.all.map(\.name) == ["Warm and cool", "Red and cyan", "Lightness"])
    for palette in ColorVisionPresets.all {
        #expect(palette.stops.count == 6)
        #expect(PaletteSeparation.issues(palette.stops) == [])
        for stop in palette.stops {
            let outline = PerceptualColor.outline(for: stop, on: stop)
            #expect(PerceptualColor.contrastRatio(stop, outline) >= 3)
        }
    }
}

@Test func redGreenPairIsReported() {
    // Orange-red and green with matching protan/deutan appearance: ΔE_OK ≈ 0.27 normal, ≈ 0.064 protan, ≈ 0.063 deutan.
    let pair: [SIMD3<Double>] = [SIMD3(0.85, 0.4, 0.2), SIMD3(0.0, 0.6, 0.2)]
    let issues = PaletteSeparation.issues(pair)
    let conditions = issues.map(\.condition)
    #expect(conditions.contains(.protanopia))
    #expect(conditions.contains(.deuteranopia))
    #expect(!conditions.contains(.normal))
    for issue in issues {
        #expect(issue.first == 0 && issue.second == 1 && issue.distance < PaletteSeparation.threshold)
    }
    #expect(PaletteSeparation.issues([SIMD3(0.5, 0.5, 0.5), SIMD3(0.5, 0.5, 0.5)]).count == 5)
}
