// OrbitViewBoundsTests — feature 042 (A05-P03) T-A05-302 (FR-A05-310–313, 321; SC-A05-304; G-ORBITBOUNDS remainder).
import Foundation
import Testing
@testable import VisualCoreMath

/// Deterministic 64-bit LCG (Knuth MMIX constants) for seeded action sequences.
private struct OrbitViewLCG {
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

private let deg = Double.pi / 180
private let viewBounds = OrbitViewBounds(orbit: OrbitBounds(pitchLimit: 80 * deg, distanceRange: 2...12),
                                         targetRadius: 1, fovRange: (30 * deg)...(75 * deg), clearance: 1.5)
private let defaultCamera = OrbitCamera(distance: 6, yaw: 0, pitch: 0.3, fovY: 60 * deg, near: 0.1)

/// Every bound of `b`, including the bounding-sphere rule and eye clearance about the origin.
private func insideView(_ c: OrbitCamera, _ b: OrbitViewBounds) -> Bool {
    let eps = 1e-9
    return abs(c.pitch) <= b.orbit.pitchLimit && abs(c.yaw) <= .pi
        && c.distance <= b.orbit.distanceRange.upperBound && c.distance >= b.orbit.distanceRange.lowerBound
        && c.target.length <= b.targetRadius + eps
        && b.fovRange.contains(c.fovY)
        && c.distance >= c.target.length + b.clearance + 2 * c.near - eps
        && c.eye.length >= b.clearance + c.near - eps
}

@Test func orbitViewBasisIsOrthonormalAndMatchesTheViewConvention() {
    let front = OrbitCamera(distance: 6)
    #expect(close(front.forward, Vec3(0, 0, -1)))
    #expect(close(front.right, Vec3(1, 0, 0)), "yaw 0 / pitch 0: right is +x")
    #expect(close(front.up, Vec3(0, 1, 0)))
    let tilted = OrbitCamera(target: Vec3(0.2, -0.1, 0.3), distance: 4, yaw: 0.7, pitch: 0.4)
    #expect(close(tilted.forward.length, 1, 1e-12) && close(tilted.right.length, 1, 1e-12)
            && close(tilted.up.length, 1, 1e-12))
    #expect(close(tilted.forward.dot(tilted.right), 0, 1e-12) && close(tilted.forward.dot(tilted.up), 0, 1e-12)
            && close(tilted.right.dot(tilted.up), 0, 1e-12))
    // The view matrix maps right to +x and up to +y in view space.
    let v = tilted.view()
    let r = v.applyPoint(tilted.target + tilted.right) - v.applyPoint(tilted.target)
    let u = v.applyPoint(tilted.target + tilted.up) - v.applyPoint(tilted.target)
    #expect(close(r, Vec3(1, 0, 0), 1e-9))
    #expect(close(u, Vec3(0, 1, 0), 1e-9))
}

@Test func orbitViewPanMovesTheTargetAlongRightAndUp() {
    let cam = viewBounds.clamp(defaultCamera)
    let moved = cam.panned(by: Vec2(0.3, 0.2), within: viewBounds)
    #expect(close(moved.target - cam.target, cam.right * 0.3 + cam.up * 0.2, 1e-12))
    #expect(moved.right.x > 0.99, "yaw 0: +dx moves the target toward +x")
    let tilted = viewBounds.clamp(OrbitCamera(distance: 5, yaw: 0.7, pitch: -0.4, fovY: 50 * deg))
    let step = tilted.panned(by: Vec2(-0.25, 0.4), within: viewBounds)
    #expect(close(step.target - tilted.target, tilted.right * -0.25 + tilted.up * 0.4, 1e-12))
    #expect(step.yaw == tilted.yaw && step.pitch == tilted.pitch && step.distance == tilted.distance
            && step.fovY == tilted.fovY, "a pan inside the bounds changes only the target")
}

@Test func orbitViewPanStopsAtTheTargetRadiusAndRaisesTheDistance() {
    let near = viewBounds.clamp(OrbitCamera(distance: 2, fovY: 60 * deg, near: 0.1))
    #expect(near.distance == 2)
    let far = near.panned(by: Vec2(100, 0), within: viewBounds)
    #expect(close(far.target, Vec3(1, 0, 0), 1e-12), "scaled back toward the origin along the pan")
    #expect(close(far.distance, 1 + 1.5 + 0.2, 1e-12), "minimum distance follows |t| + clearance + 2·near")
    let huge = near.panned(by: Vec2(-1e300, 1e300), within: viewBounds)
    #expect(huge.target.length <= 1 + 1e-9 && huge.target.x < 0 && huge.target.y > 0)
    #expect(insideView(huge, viewBounds))
}

@Test func orbitViewFieldOfViewIsClampedIntoItsRange() {
    let cam = viewBounds.clamp(defaultCamera)
    #expect(cam.withFieldOfView(50 * deg, within: viewBounds).fovY == 50 * deg)
    #expect(cam.withFieldOfView(10 * deg, within: viewBounds).fovY == 30 * deg)
    #expect(cam.withFieldOfView(100 * deg, within: viewBounds).fovY == 75 * deg)
    for bad in [(4.0)...(5.0), (-1.0)...(0.0)] {
        let b = OrbitViewBounds(orbit: viewBounds.orbit, targetRadius: 1, fovRange: bad)
        #expect(cam.withFieldOfView(1, within: b).fovY == .pi / 3, "unusable range falls back to π/3")
    }
    var nanFov = cam
    nanFov.fovY = .nan
    #expect(viewBounds.clamp(nanFov).fovY == .pi / 3)
}

@Test func orbitViewMinimumDistanceFollowsTheBoundingSphereRule() {
    let cam = OrbitCamera(target: Vec3(0.6, 0, 0.8), distance: 6, near: 0.1)
    #expect(close(viewBounds.minimumDistance(for: cam), 2.7, 1e-12))
    var b = viewBounds
    b.orbit.distanceRange = 3...12
    #expect(b.minimumDistance(for: cam) == 3, "lower distance bound wins")
    b.orbit.distanceRange = 1...2.5
    #expect(b.minimumDistance(for: cam) == 2.5, "never above the upper bound")
    b.orbit.distanceRange = 1...12
    b.clearance = .nan
    #expect(close(b.minimumDistance(for: cam), 1.2, 1e-12), "non-finite clearance acts as 0")
    b.clearance = .infinity
    #expect(close(b.minimumDistance(for: cam), 1.2, 1e-12), "infinite clearance acts as 0 too")
    b.clearance = 20
    #expect(b.minimumDistance(for: cam) == 12, "a rule above the upper bound returns the upper bound")
    b.clearance = -3
    #expect(close(b.minimumDistance(for: cam), 1.2, 1e-12), "negative clearance acts as 0")
}

@Test func orbitViewNonFiniteAndNonPositiveInputsLeaveTheCameraUnchanged() {
    let cam = viewBounds.clamp(OrbitCamera(target: Vec3(0.2, 0.1, 0), distance: 6, yaw: 1, pitch: 0.5))
    for d in [Vec2(.nan, 0), Vec2(0, .infinity), Vec2(-.infinity, .nan)] {
        #expect(cam.panned(by: d, within: viewBounds) == cam)
    }
    for f in [Double.nan, .infinity, -.infinity] {
        #expect(cam.withFieldOfView(f, within: viewBounds) == cam)
    }
    for (y, p) in [(Double.nan, 0.0), (0, .infinity), (-.infinity, .nan)] {
        #expect(cam.orbited(yaw: y, pitch: p, within: viewBounds) == cam)
    }
    for f in [Double.nan, .infinity, -.infinity, 0, -2, -0.0] {
        #expect(cam.zoomed(by: f, within: viewBounds) == cam)
    }
}

@Test func orbitViewSeededSequencesStayWithinEveryBound() {
    let reset = viewBounds.clamp(defaultCamera)
    #expect(reset == defaultCamera, "the default is inside the bounds")
    for seed in 0..<200 {
        var rng = OrbitViewLCG(seed: 2_000 + UInt64(seed))
        var cam = reset
        for _ in 0..<60 {
            let pick = rng.unit()
            if pick < 0.25 {
                cam = cam.panned(by: Vec2(rng.range(-2, 2), rng.range(-2, 2)), within: viewBounds)
            } else if pick < 0.5 {
                cam = cam.zoomed(by: exp(rng.range(-2, 2)), within: viewBounds)
            } else if pick < 0.75 {
                cam = cam.withFieldOfView(rng.range(0, 120) * deg, within: viewBounds)
            } else {
                cam = cam.orbited(yaw: rng.range(-4, 4), pitch: rng.range(-2, 2), within: viewBounds)
            }
            #expect(insideView(cam, viewBounds), "seed \(seed)")
        }
        cam = reset
        #expect(cam == defaultCamera, "reset restores the default exactly (seed \(seed))")
    }
}

@Test func orbitViewClampIsIdempotentAndRepairsOutOfBoundsState() {
    var rng = OrbitViewLCG(seed: 11)
    for _ in 0..<200 {
        let c = OrbitCamera(target: Vec3(rng.range(-5, 5), rng.range(-5, 5), rng.range(-5, 5)),
                            distance: rng.range(0.01, 50), yaw: rng.range(-100, 100), pitch: rng.range(-2, 2),
                            fovY: rng.range(0.01, 3.1), near: rng.range(0.01, 0.3))
        let once = viewBounds.clamp(c)
        #expect(insideView(once, viewBounds))
        #expect(viewBounds.clamp(once) == once)
    }
    var broken = defaultCamera
    broken.target = Vec3(.nan, .infinity, -.infinity)
    let repaired = viewBounds.clamp(broken)
    #expect(insideView(repaired, viewBounds))
    #expect(repaired.target.x == 0 && repaired.target.y > 0 && repaired.target.z < 0)
    #expect(viewBounds.clamp(repaired) == repaired)
}

@Test func orbitViewBoundsAreCodable() throws {
    let data = try JSONEncoder().encode(viewBounds)
    #expect(try JSONDecoder().decode(OrbitViewBounds.self, from: data) == viewBounds)
}
