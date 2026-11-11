// PlaneViewportTests — feature 026 T-A03-101 (G-VIEWPORT; FR-A03-104, SC-A03-102; research R1–R2).
import Foundation
import Testing
@testable import VisualCoreMath

private let size = Vec2(390, 844)

@Test func roundTripsScreenAndPlane() {
    let v = PlaneViewport(center: Vec2(-0.5, 0.25), unitsPerPoint: 0.01, size: size)
    for p in [Vec2(0, 0), Vec2(195, 422), Vec2(390, 844), Vec2(17.5, 600.25)] {
        #expect(v.screen(fromPlane: v.plane(fromScreen: p)).distance(to: p) < 1e-9)
    }
    #expect(v.plane(fromScreen: Vec2(195, 422)) == Vec2(-0.5, 0.25), "the view's middle is the center")
}

@Test func yIsUpInThePlane() {
    let v = PlaneViewport(center: .zero, unitsPerPoint: 1, size: Vec2(100, 100))
    #expect(v.plane(fromScreen: Vec2(50, 0)).y == 50, "the top of the screen is +y")
    #expect(v.plane(fromScreen: Vec2(100, 50)).x == 50, "the right edge is +x")
}

@Test func anchoredPinchKeepsTheAnchorFixed() {
    let anchor = Vec2(120, 300)
    for scale in [1e-6, 0.37, 1, 2.5, 1e3, 1e6] {
        let v = PlaneViewport(center: Vec2(-0.743643887037151, 0.131825904205330), unitsPerPoint: 1e-4, size: size)
        let before = v.plane(fromScreen: anchor)
        let w = v.pinched(by: scale, anchor: anchor)
        let after = w.plane(fromScreen: anchor)
        let rel = after.distance(to: before) / max(before.length, 1e-300)
        #expect(rel < 1e-12, "scale \(scale): drift \(rel)")
        #expect(abs(w.unitsPerPoint - 1e-4 / scale) <= 1e-4 / scale * 1e-12 || w.wasClamped)
    }
}

@Test func clampsReportWasClamped() {
    let v = PlaneViewport(center: .zero, unitsPerPoint: 1e-14, size: size)
    let deep = v.pinched(by: 1e6, anchor: Vec2(195, 422))
    #expect(deep.unitsPerPoint == PlaneViewport.minUnitsPerPoint)
    #expect(deep.wasClamped)
    let wide = v.pinched(by: 1e-30, anchor: Vec2(195, 422))
    #expect(wide.unitsPerPoint == PlaneViewport.maxUnitsPerPoint && wide.wasClamped)
    #expect(!PlaneViewport(center: .zero, unitsPerPoint: 0.01, size: size).wasClamped)
}

@Test func panFollowsTheFinger() {
    let v = PlaneViewport(center: Vec2(1, 2), unitsPerPoint: 0.5, size: size)
    let finger = Vec2(100, 100)
    let grabbed = v.plane(fromScreen: finger)
    let w = v.panned(by: Vec2(30, -12))
    #expect(w.plane(fromScreen: finger + Vec2(30, -12)).distance(to: grabbed) < 1e-12)
}

@Test func resizeKeepsCenterAndSquarePixels() {
    var v = PlaneViewport(center: Vec2(0.3, -0.2), unitsPerPoint: 0.004, size: size)
    // Seeded (feature 033 T-A04-104): the earlier SystemRandomNumberGenerator made the tolerance check flaky.
    var rng = SplitMix64Test(state: 0x5EED)
    for _ in 0..<100 {
        let s = Vec2(Double.random(in: 1...3000, using: &rng), Double.random(in: 1...3000, using: &rng))
        v = v.resized(to: s)
        #expect(v.plane(fromScreen: s / 2).distance(to: Vec2(0.3, -0.2)) < 1e-12)
        let dx = v.plane(fromScreen: Vec2(10, 0)) - v.plane(fromScreen: .zero)
        let dy = v.plane(fromScreen: .zero) - v.plane(fromScreen: Vec2(0, 10))
        // Square pixels up to rounding: the points' plane coordinates reach about ±12, whose spacing is ~1.8e-15, so
        // compare relative to the step (|dx.x| = 0.04) with a 1e-12 bound instead of an absolute 1e-15.
        #expect(abs(dx.x - dy.y) <= 1e-12 * abs(dx.x), "square pixels")
    }
}

@Test func invalidInputsFallBack() {
    let v = PlaneViewport(center: Vec2(.nan, 1), unitsPerPoint: .infinity, size: Vec2(0, -3))
    #expect(v.center == .zero)
    #expect(v.size == Vec2(1, 1))
    #expect(v.unitsPerPoint.isFinite && v.wasClamped)
    let ok = PlaneViewport(center: .zero, unitsPerPoint: 0.1, size: size)
    #expect(ok.resized(to: Vec2(0, 0)).size == size, "a zero size keeps the last valid size")
    #expect(ok.resized(to: Vec2(.nan, 10)).size == size)
    #expect(ok.pinched(by: .nan, anchor: Vec2(1, 1)) == ok)
    #expect(ok.pinched(by: 2, anchor: Vec2(.infinity, 1)) == ok)
    #expect(ok.panned(by: Vec2(.nan, 0)) == ok)
}

@Test func framingFitsTheShorterSide() {
    let portrait = PlaneViewport.framing(width: 4, center: Vec2(-0.5, 0), size: Vec2(400, 800))
    #expect(abs(portrait.unitsPerPoint - 0.01) < 1e-15)
    #expect(portrait.plane(fromScreen: Vec2(0, 400)).x == -2.5)
    let landscape = PlaneViewport.framing(width: 4, center: .zero, size: Vec2(800, 400))
    #expect(abs(landscape.unitsPerPoint - 0.01) < 1e-15, "the shorter side (height) spans the width")
}

/// Deterministic generator for the resize test (SplitMix64).
private struct SplitMix64Test: RandomNumberGenerator {
    var state: UInt64
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
