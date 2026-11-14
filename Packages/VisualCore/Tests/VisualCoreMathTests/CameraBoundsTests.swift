// CameraBoundsTests — feature 041 (A05-P02) T-A05-202 (FR-A05-210/221; SC-A05-203; G-ORBITBOUNDS).
import Foundation
import Testing
@testable import VisualCoreMath

/// Deterministic 64-bit LCG (Knuth MMIX constants) for seeded action sequences.
private struct CameraBoundsLCG {
    var state: UInt64
    init(seed: UInt64) { state = seed &* 0x9E37_79B9_7F4A_7C15 &+ 1 }
    /// Uniform in 0..<1.
    mutating func unit() -> Double {
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        return Double(state >> 11) / Double(UInt64(1) << 53)
    }
    /// Uniform in lo..<hi.
    mutating func range(_ lo: Double, _ hi: Double) -> Double { lo + (hi - lo) * unit() }
}

private let view2D = ViewBounds2D(zoomRange: 0.5...8, extent: 1.25)
private let orbit3D = OrbitBounds(pitchLimit: 80 * .pi / 180, distanceRange: 3...12)

private func inside(_ c: Camera2D, _ b: ViewBounds2D) -> Bool {
    b.zoomRange.contains(c.zoom) && abs(c.center.x) <= b.extent && abs(c.center.y) <= b.extent
}

private func inside(_ c: OrbitCamera, _ b: OrbitBounds) -> Bool {
    abs(c.pitch) <= b.pitchLimit && b.distanceRange.contains(c.distance) && abs(c.yaw) <= .pi
}

@Test func seededPanZoomSequencesStayInside2DBounds() {
    let reset = view2D.clamp(Camera2D())
    for seed in 0..<200 {
        var rng = CameraBoundsLCG(seed: UInt64(seed))
        var cam = reset
        for _ in 0..<60 {
            if rng.unit() < 0.5 {
                cam = cam.panned(by: Vec2(rng.range(-3, 3), rng.range(-3, 3)), within: view2D)
            } else {
                cam = cam.zoomed(by: exp(rng.range(-2, 2)), within: view2D)
            }
            #expect(inside(cam, view2D), "seed \(seed)")
        }
        cam = reset
        #expect(cam == Camera2D(), "reset restores the default exactly (seed \(seed))")
    }
}

@Test func seededOrbitZoomSequencesStayInsideOrbitBounds() {
    let reset = orbit3D.clamp(OrbitCamera(distance: 6, yaw: 0, pitch: 0.5))
    for seed in 0..<200 {
        var rng = CameraBoundsLCG(seed: 1_000 + UInt64(seed))
        var cam = reset
        for _ in 0..<60 {
            if rng.unit() < 0.5 {
                cam = cam.orbited(yaw: rng.range(-4, 4), pitch: rng.range(-2, 2), within: orbit3D)
            } else {
                cam = cam.zoomed(by: exp(rng.range(-1.5, 1.5)), within: orbit3D)
            }
            #expect(inside(cam, orbit3D), "seed \(seed)")
        }
        cam = reset
        #expect(cam == OrbitCamera(distance: 6, yaw: 0, pitch: 0.5), "reset restores the default exactly (seed \(seed))")
    }
}

@Test func nonFiniteAndNonPositiveInputsLeaveCamerasUnchanged() {
    let cam2 = view2D.clamp(Camera2D(center: Vec2(0.3, -0.2), zoom: 2, rotation: 0.4))
    for d in [Vec2(.nan, 0), Vec2(0, .infinity), Vec2(-.infinity, .nan)] {
        #expect(cam2.panned(by: d, within: view2D) == cam2)
    }
    for f in [Double.nan, .infinity, -.infinity, 0, -1, -0.0] {
        #expect(cam2.zoomed(by: f, within: view2D) == cam2)
    }
    let cam3 = orbit3D.clamp(OrbitCamera(distance: 6, yaw: 1, pitch: 0.5))
    for (y, p) in [(Double.nan, 0.0), (0, .infinity), (-.infinity, .nan)] {
        #expect(cam3.orbited(yaw: y, pitch: p, within: orbit3D) == cam3)
    }
    for f in [Double.nan, .infinity, -.infinity, 0, -2] {
        #expect(cam3.zoomed(by: f, within: orbit3D) == cam3)
    }
}

@Test func boundsSaturateAtTheLimits() {
    let far2 = Camera2D().panned(by: Vec2(-1e300, 1e300), within: view2D)
    #expect(far2.center == Vec2(1.25, -1.25), "pans stop at the extent")
    #expect(Camera2D().zoomed(by: 1e300, within: view2D).zoom == 8)
    #expect(Camera2D().zoomed(by: 1e-300, within: view2D).zoom == 0.5)
    let limit = 80 * Double.pi / 180
    let cam3 = OrbitCamera(distance: 6)
    #expect(cam3.orbited(yaw: 0, pitch: 10, within: orbit3D).pitch == limit)
    #expect(cam3.orbited(yaw: 0, pitch: -10, within: orbit3D).pitch == -limit)
    #expect(cam3.zoomed(by: 1e300, within: orbit3D).distance == 3, "pinch in moves closer, down to the near bound")
    #expect(cam3.zoomed(by: 1e-300, within: orbit3D).distance == 12)
    #expect(cam3.zoomed(by: 2, within: orbit3D).distance == 3)
    #expect(cam3.zoomed(by: 0.75, within: orbit3D).distance == 8)
    // A pitch limit beyond the camera's own ±89° is capped by it.
    let loose = OrbitBounds(pitchLimit: 3, distanceRange: 0...1e9)
    #expect(cam3.orbited(yaw: 0, pitch: 3, within: loose).pitch == OrbitCamera.pitchLimit)
}

@Test func clampIsIdempotentAndRepairsOutOfBoundsState() {
    var rng = CameraBoundsLCG(seed: 7)
    for _ in 0..<200 {
        let c2 = Camera2D(center: Vec2(rng.range(-50, 50), rng.range(-50, 50)), zoom: rng.range(0.1, 100),
                          rotation: rng.range(-7, 7))
        let once2 = view2D.clamp(c2)
        #expect(inside(once2, view2D))
        #expect(view2D.clamp(once2) == once2)
        let c3 = OrbitCamera(distance: rng.range(0.01, 100), yaw: rng.range(-100, 100), pitch: rng.range(-2, 2))
        let once3 = orbit3D.clamp(c3)
        #expect(inside(once3, orbit3D))
        #expect(orbit3D.clamp(once3) == once3)
    }
    let nan2 = view2D.clamp(Camera2D(center: Vec2(.nan, .nan), zoom: .nan, rotation: .nan))
    #expect(nan2 == Camera2D(), "NaN centre and rotation fall back to 0, zoom to 1")
}

@Test func yawWrapsIntoMinusPiToPi() {
    let cam = OrbitCamera(distance: 6)
    let wrapped = orbit3D.clamp(OrbitCamera(distance: 6, yaw: 3 * .pi + 0.25))
    #expect(close(wrapped.yaw, -.pi + 0.25, 1e-12))
    var spun = cam
    for _ in 0..<1_000 { spun = spun.orbited(yaw: 0.9, pitch: 0, within: orbit3D) }
    #expect(abs(spun.yaw) <= .pi)
    #expect(close(spun.yaw, remainder(900, 2 * .pi), 1e-9), "wrapped yaw tracks the total turn")
    #expect(orbit3D.clamp(OrbitCamera(yaw: .pi)).yaw == .pi)
    #expect(orbit3D.clamp(OrbitCamera(yaw: .nan)).yaw == 0)
}

@Test func boundsAreCodable() throws {
    let data2 = try JSONEncoder().encode(view2D)
    #expect(try JSONDecoder().decode(ViewBounds2D.self, from: data2) == view2D)
    let data3 = try JSONEncoder().encode(orbit3D)
    #expect(try JSONDecoder().decode(OrbitBounds.self, from: data3) == orbit3D)
}
