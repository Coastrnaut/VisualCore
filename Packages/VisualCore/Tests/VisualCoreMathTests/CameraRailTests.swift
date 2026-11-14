// CameraRailTests — feature 054 (A07-P01) T-A07-102 (FR-A07-101, FR-A07-104; SC-A07-101; gap G-CAMERARAIL).
import Foundation
import Testing
@testable import VisualCoreMath

/// Tiny local LCG (VisualCoreMathTests cannot import VisualCoreSimulation's SeededRandom).
struct RailTestLCG {
    var state: UInt64
    init(seed: UInt64) { state = seed &* 0x9E37_79B9_7F4A_7C15 &+ 1 }
    mutating func next() -> Double {
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        return Double(state >> 11) / Double(1 << 53)
    }
    mutating func range(_ lo: Double, _ hi: Double) -> Double { lo + (hi - lo) * next() }
}

/// 12 control points on a perturbed ellipse with gentle height changes.
func seededRailPoints(seed: UInt64) -> [Vec3] {
    var rng = RailTestLCG(seed: seed)
    let a = rng.range(35, 50), b = rng.range(30, 45)
    return (0..<12).map { i in
        let t = Double(i) / 12 * 2 * .pi
        let r = 1 + rng.range(-0.06, 0.06)
        return Vec3(a * r * cos(t), rng.range(-2, 2), b * r * sin(t))
    }
}

func angleBetween(_ a: Vec3, _ b: Vec3) -> Double { acos(min(1, max(-1, a.normalized.dot(b.normalized)))) }

@Suite struct CameraRailTests {
    @Test func equalDistanceStepsGiveEqualChordsOverTenSeededRails() throws {
        for seed in UInt64(1)...10 {
            let rail = try #require(CameraRail(controlPoints: seededRailPoints(seed: seed)))
            let steps = 300, ds = rail.length / Double(steps)
            var chords: [Double] = []
            var last = rail.pose(at: 0).position
            for k in 1...steps {
                let p = rail.pose(at: Double(k) * ds).position
                chords.append((p - last).length)
                last = p
            }
            let mean = chords.reduce(0, +) / Double(chords.count)
            let spread = (chords.max()! - chords.min()!) / mean
            #expect(spread < 0.01, "seed \(seed) spread \(spread)")
        }
    }

    @Test func framesAreContinuousAcrossTheWrap() throws {
        let rail = try #require(CameraRail(controlPoints: seededRailPoints(seed: 7)))
        #expect(rail.pose(at: 0) == rail.pose(at: rail.length))
        #expect(rail.pose(at: 0) == rail.pose(at: 3 * rail.length))
        let eps = 1e-3
        let before = rail.pose(at: rail.length - eps), after = rail.pose(at: eps)
        #expect((before.position - after.position).length < 3 * eps)
        #expect(angleBetween(before.direction, after.direction) < 1e-2)
        #expect(angleBetween(before.right, after.right) < 1e-2)
        let neg = rail.pose(at: -eps), wrapped = rail.pose(at: rail.length - eps)
        #expect((neg.position - wrapped.position).length < 1e-9)
    }

    @Test func frameIsLevelAndOrthonormal() throws {
        let rail = try #require(CameraRail(controlPoints: seededRailPoints(seed: 3)))
        for k in 0..<100 {
            let p = rail.pose(at: Double(k) * rail.length / 100)
            #expect(abs(p.direction.length - 1) < 1e-9)
            #expect(abs(p.right.length - 1) < 1e-9)
            #expect(abs(p.up.length - 1) < 1e-9)
            #expect(abs(p.right.y) < 1e-12)
            #expect(abs(p.direction.dot(p.right)) < 1e-9)
            #expect(abs(p.direction.dot(p.up)) < 1e-9)
            #expect(p.up.y > 0)
        }
    }

    @Test func gentleRailTurnsWithinTheComfortTurnRate() throws {
        let limits = ComfortLimits.standard
        let rail = try #require(CameraRail(controlPoints: seededRailPoints(seed: 5)))
        #expect(rail.minimumTurnRadius() >= limits.maxSpeed / limits.maxTurnRate)
        let ds = 0.5
        var last = rail.pose(at: 0)
        for k in 1...Int(rail.length / ds) {
            let p = rail.pose(at: Double(k) * ds)
            #expect(angleBetween(last.direction, p.direction) < limits.maxTurnRate * ds / limits.maxSpeed)
            last = p
        }
    }

    @Test func minimumTurnRadiusOfACircleIsItsRadius() throws {
        let pts = (0..<48).map { i -> Vec3 in
            let t = Double(i) / 48 * 2 * .pi
            return Vec3(20 * cos(t), 0, 20 * sin(t))
        }
        let rail = try #require(CameraRail(controlPoints: pts))
        #expect(abs(rail.minimumTurnRadius() - 20) < 0.5)
        #expect(abs(rail.length - 2 * .pi * 20) < 0.1)
    }

    @Test func refusesInvalidControlPoints() {
        let good = seededRailPoints(seed: 2)
        #expect(CameraRail(controlPoints: Array(good.prefix(3))) == nil)
        #expect(CameraRail(controlPoints: []) == nil)
        var nan = good; nan[4].y = .nan
        #expect(CameraRail(controlPoints: nan) == nil)
        var inf = good; inf[0].x = .infinity
        #expect(CameraRail(controlPoints: inf) == nil)
        var dup = good; dup[5] = dup[4]
        #expect(CameraRail(controlPoints: dup) == nil)
        #expect(CameraRail(controlPoints: good + [good[0]]) == nil)
        let vertical = [Vec3(0, 0, 0), Vec3(1, 20, 0), Vec3(0, 40, 1), Vec3(-1, 20, 0)]
        #expect(CameraRail(controlPoints: vertical) == nil)
        #expect(CameraRail(controlPoints: good, samplesPerSpan: 0) == nil)
        #expect(CameraRail(controlPoints: good) != nil)
    }

    @Test func orbitCameraMatchesThePose() throws {
        let rail = try #require(CameraRail(controlPoints: seededRailPoints(seed: 9)))
        for k in 0..<50 {
            let d = Double(k) * rail.length / 50
            let pose = rail.pose(at: d)
            let cam = rail.orbitCamera(at: d, fovY: 1, near: 0.1, far: 500)
            #expect((cam.eye - pose.position).length < 1e-9)
            #expect((cam.target - cam.eye).normalized.cross(pose.direction).length < 1e-9)
            #expect((cam.target - cam.eye).dot(pose.direction) > 0)
            #expect(cam.fovY == 1 && cam.near == 0.1 && cam.far == 500)
        }
    }

    @Test func sameInputsGiveSamePoses() throws {
        let a = try #require(CameraRail(controlPoints: seededRailPoints(seed: 4)))
        let b = try #require(CameraRail(controlPoints: seededRailPoints(seed: 4)))
        #expect(a == b)
        for k in 0..<20 { #expect(a.pose(at: Double(k) * 13.7) == b.pose(at: Double(k) * 13.7)) }
        #expect(a.pose(at: .nan) == a.pose(at: 0))
    }
}
