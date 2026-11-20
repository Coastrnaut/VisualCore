// PerceptualColorTests — feature 210 (R02-F10) T-R02F10-002 (FR-R02F10-001, FR-R02F10-002, FR-R02F10-003,
// FR-R02F10-011, FR-R02F10-013). The VisualCoreParametersTests target depends only on VisualCoreParameters, so it
// cannot use VisualCoreSimulation's SeededRandom; the fixtures come from the local 64-bit LCG below (seed 2010).
import Foundation
import Testing
@testable import VisualCoreParameters

/// A deterministic 64-bit LCG (Knuth's MMIX constants) for colour fixtures.
struct ColorFixtureLCG {
    private var state: UInt64
    init(seed: UInt64 = 2010) { state = seed }
    /// The next value in 0…1 (53 random bits).
    mutating func next() -> Double {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return Double(state >> 11) / Double((UInt64(1) << 53) - 1)
    }
    mutating func color() -> SIMD3<Double> { SIMD3(next(), next(), next()) }
}

private func maxAbs(_ a: SIMD3<Double>, _ b: SIMD3<Double>) -> Double {
    max(abs(a.x - b.x), abs(a.y - b.y), abs(a.z - b.z))
}

private func hueDistance(_ a: Double, _ b: Double) -> Double {
    let d = abs(a - b).truncatingRemainder(dividingBy: 2 * Double.pi)
    return min(d, 2 * Double.pi - d)
}

@Test func roundTripThousandColors() {
    var rng = ColorFixtureLCG()
    var worst = 0.0
    for _ in 0..<1000 {
        let c = rng.color()
        let lab = PerceptualColor.oklab(fromLinear: PerceptualColor.linear(fromSRGB: c))
        let lch = PerceptualColor.oklch(fromOklab: lab)
        let back = PerceptualColor.sRGB(fromLinear: PerceptualColor.linear(fromOklab: PerceptualColor.oklab(fromOklch: lch)))
        worst = max(worst, maxAbs(back, c))
    }
    #expect(worst < 1e-9)
}

@Test func referencePoints() {
    let white = PerceptualColor.oklab(fromLinear: PerceptualColor.linear(fromSRGB: SIMD3(1, 1, 1)))
    #expect(maxAbs(white, SIMD3(1, 0, 0)) < 1e-4)
    // Ottosson (2020): linear sRGB red (1, 0, 0) → OKLab (0.6279554, 0.2248631, 0.1258463).
    let red = PerceptualColor.oklab(fromLinear: SIMD3(1, 0, 0))
    #expect(maxAbs(red, SIMD3(0.6279554, 0.2248631, 0.1258463)) < 1e-6)
    let black = PerceptualColor.oklab(fromLinear: SIMD3(0, 0, 0))
    #expect(maxAbs(black, SIMD3(0, 0, 0)) < 1e-12)
    #expect(abs(PerceptualColor.lightness(sRGB: SIMD3(1, 1, 1)) - 1) < 1e-4)
    #expect(abs(PerceptualColor.relativeLuminance(sRGB: SIMD3(1, 1, 1)) - 1) < 1e-12)
}

@Test func fullTurnReturnsColor() throws {
    var rng = ColorFixtureLCG()
    for _ in 0..<200 {
        let c = rng.color()
        let r = try PerceptualColor.rotateHue(sRGB: c, by: 2 * Double.pi)
        #expect(maxAbs(r, c) < 1e-9)
    }
}

@Test func rotationKeepsLightnessInGamut() throws {
    var rng = ColorFixtureLCG()
    var checked = 0
    for _ in 0..<500 {
        let c = rng.color()
        let angle = rng.next() * 2 * Double.pi
        let lch = PerceptualColor.oklch(fromOklab: PerceptualColor.oklab(fromLinear: PerceptualColor.linear(fromSRGB: c)))
        let target = SIMD3(lch.x, lch.y, lch.z + angle)
        let lin = PerceptualColor.linear(fromOklab: PerceptualColor.oklab(fromOklch: target))
        let inGamut = (0..<3).allSatisfy { lin[$0] >= 0 && lin[$0] <= 1 }
        guard inGamut else { continue }
        checked += 1
        let r = try PerceptualColor.rotateHue(sRGB: c, by: angle)
        #expect(abs(PerceptualColor.lightness(sRGB: r) - lch.x) < 1e-9)
    }
    #expect(checked > 50)
}

@Test func greysUnchanged() throws {
    for g in [0.0, 0.18, 0.5, 1.0] {
        let c = SIMD3(g, g, g)
        #expect(try PerceptualColor.rotateHue(sRGB: c, by: 1.3) == c)
    }
}

@Test func greyChromaFromPublishedCoefficients() {
    // Measured: the published M2 leaves sRGB white at OKLab b ≈ 3.7e-8, so grey chroma is far above 1e-12.
    let white = PerceptualColor.oklch(fromOklab: PerceptualColor.oklab(fromLinear: SIMD3(1, 1, 1)))
    print("R02-F10 white OKLCh chroma: \(white.y)")
    #expect(white.y < 1e-7)
}

@Test func outOfGamutRotationIsMapped() throws {
    let cyan = SIMD3<Double>(0, 1, 1)
    let angle = 120 * Double.pi / 180
    let lch = PerceptualColor.oklch(fromOklab: PerceptualColor.oklab(fromLinear: PerceptualColor.linear(fromSRGB: cyan)))
    let wanted = SIMD3(lch.x, lch.y, (lch.z + angle).truncatingRemainder(dividingBy: 2 * Double.pi))
    let raw = PerceptualColor.linear(fromOklab: PerceptualColor.oklab(fromOklch: wanted))
    #expect(!(0..<3).allSatisfy { raw[$0] >= 0 && raw[$0] <= 1 })
    let r = try PerceptualColor.rotateHue(sRGB: cyan, by: angle)
    #expect((0..<3).allSatisfy { r[$0] >= 0 && r[$0] <= 1 })
    let out = PerceptualColor.oklch(fromOklab: PerceptualColor.oklab(fromLinear: PerceptualColor.linear(fromSRGB: r)))
    #expect(abs(out.x - lch.x) < 1e-9)
    #expect(hueDistance(out.z, wanted.z) < 1e-6)
    #expect(out.y < lch.y)
    let mapped = PerceptualColor.intoGamut(oklch: wanted)
    #expect(mapped.x == wanted.x && mapped.z == wanted.z && mapped.y < wanted.y)
    #expect(PerceptualColor.intoGamut(oklch: lch) == lch)
}

@Test func contrastAndOutline() {
    let black = SIMD3<Double>(0, 0, 0), white = SIMD3<Double>(1, 1, 1)
    #expect(abs(PerceptualColor.contrastRatio(black, white) - 21) < 1e-12)
    #expect(abs(PerceptualColor.contrastRatio(white, black) - 21) < 1e-12)
    let c = SIMD3<Double>(0.3, 0.6, 0.2)
    #expect(PerceptualColor.contrastRatio(c, c) == 1)
    #expect(PerceptualColor.difference(c, c) == 0)
    #expect(PerceptualColor.outline(for: white, on: white) == black)
    #expect(PerceptualColor.outline(for: black, on: black) == white)
}

@Test func refusesInvalidInput() {
    #expect(throws: ColorAccessError.nonFinite(index: 0)) { try PerceptualColor.rotateHue(sRGB: SIMD3(.nan, 0, 0), by: 1) }
    #expect(throws: ColorAccessError.outOfRange(index: 0)) { try PerceptualColor.rotateHue(sRGB: SIMD3(1.2, 0, 0), by: 1) }
    #expect(ColorAccessError.nonFinite(index: 0).reasonCode == "r2-f10.non-finite")
    #expect(ColorAccessError.outOfRange(index: 0).reasonCode == "r2-f10.out-of-range")
}

/// T-R02F10-017 (FR-R02F10-013): over a 9 × 9 × 9 sRGB sweep on black and white backgrounds, the inner ring is at least
/// 3:1 against the colour and the outermost ring at least 3:1 against the background.
@Test func outlineRingsReachThreeToOneEverywhere() {
    var worstInner = Double.infinity, worstOuter = Double.infinity
    for background in [SIMD3<Double>(0, 0, 0), SIMD3<Double>(1, 1, 1)] {
        for r in 0...8 {
            for g in 0...8 {
                for b in 0...8 {
                    let color = SIMD3(Double(r) / 8, Double(g) / 8, Double(b) / 8)
                    let rings = PerceptualColor.outlineRings(for: color, on: background)
                    worstInner = min(worstInner, PerceptualColor.contrastRatio(rings.inner, color))
                    worstOuter = min(worstOuter, PerceptualColor.contrastRatio(rings.outer ?? rings.inner, background))
                }
            }
        }
    }
    print("R02-F10 outline rings: worst inner \(worstInner), worst outermost \(worstOuter)")
    #expect(worstInner >= 3)
    #expect(worstOuter >= 3)
    let yellowOnBlack = PerceptualColor.outlineRings(for: SIMD3(1, 1, 0), on: SIMD3(0, 0, 0))
    #expect(yellowOnBlack.inner == SIMD3(0, 0, 0) && yellowOnBlack.outer == SIMD3(1, 1, 1))
    #expect(PerceptualColor.outlineRings(for: SIMD3(1, 1, 0), on: SIMD3(1, 1, 1)).outer == nil)
}
