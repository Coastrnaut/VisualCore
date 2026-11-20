// SDFMarchTests — feature 211 (R02-F11) T-R02F11-004 (FR-R02F11-004; SC-R02F11-002). 1,000 seeded rays from a
// radius-5 shell aimed inside half the shape hit a sphere and a box at the analytic `Ray3` distance within 1e-6 and
// normal within 1e-4 in both modes; a 1e-3 thin shell is hit by both modes on 100 seeded rays while an ω = 1.6 march
// without the overlap fallback skips it; a too-small budget reports `budgetExhausted`; a ray pointing away misses; a
// start inside hits at 0; the fast mode takes fewer steps in total over 1,000 grazing rays; the options refuse invalid values. Rays come from
// the seeded `SDFTestRandom` (SDFShapeTests.swift).
import Foundation
import Testing
import VisualCoreMath
@testable import VisualCoreScenes

@Suite struct SDFMarchTests {
    static let conservative = try! SDFMarchOptions(mode: .conservative)
    static let fast = try! SDFMarchOptions(mode: .fast)

    /// `count` rays from a radius-5 shell, each aimed at a random point of the box ±`aim`.
    static func rays(seed: UInt64, count: Int, aim: Vec3) -> [Ray3] {
        var random = SDFTestRandom(seed: seed)
        var rays: [Ray3] = []
        while rays.count < count {
            let u = random.point(1)
            let target = random.point(1)
            guard u.length > 0.1, u.length <= 1 else { continue }
            let origin = u.normalized * 5
            let point = Vec3(target.x * aim.x, target.y * aim.y, target.z * aim.z)
            if let ray = Ray3(origin: origin, direction: point - origin) { rays.append(ray) }
        }
        return rays
    }

    /// An ω = 1.6 march without the overlap fallback (test only): true when it reports a hit.
    static func naiveHit(_ shape: SDFShape, _ ray: Ray3) -> Bool {
        var t = 0.0
        for _ in 0..<256 {
            let d = shape.distance(at: ray.origin + ray.direction * t)
            if abs(d) < 1e-7 * max(1, t) || d < 0 { return true }
            t += 1.6 * d
            if t > 100 { return false }
        }
        return false
    }

    /// `count` rays from a radius-5 shell passing the origin at an impact parameter in 0.97…0.999: grazing hits of the
    /// unit sphere, where the surface is nearly parallel to the ray and over-relaxation pays.
    static func grazingRays(seed: UInt64, count: Int) -> [Ray3] {
        var random = SDFTestRandom(seed: seed)
        var rays: [Ray3] = []
        while rays.count < count {
            let u = random.point(1), v = random.point(1)
            guard u.length > 0.1, u.length <= 1 else { continue }
            let origin = u.normalized * 5
            let side = origin.cross(v).normalized
            guard side.length > 0.5 else { continue }
            let impact = 0.97 + 0.029 * random.next()
            let reach = 5 * impact / (25 - impact * impact).squareRoot()
            if let ray = Ray3(origin: origin, direction: side * reach - origin) { rays.append(ray) }
        }
        return rays
    }

    @Test func sphereHitsEqualTheAnalyticHitInBothModes() throws {
        let sphere = try SDFShape.sphere(radius: 1)
        for ray in Self.rays(seed: 4_001, count: 1_000, aim: Vec3(0.5, 0.5, 0.5)) {
            let expected = try #require(ray.intersect(sphereCenter: .zero, radius: 1))
            for options in [Self.conservative, Self.fast] {
                let result = SDFMarch.march(sphere, ray: ray, options: options)
                #expect(result.outcome == .hit)
                #expect(!result.startedInside)
                #expect(abs(result.distance - expected.distance) < 1e-6)
                #expect((result.normal - expected.normal).length < 1e-4)
            }
        }
    }

    /// The default tolerance stops within 1e-7 · t of the surface measured along its normal, i.e. up to
    /// 1e-7 · t / cos θ along an oblique ray (cos θ ≥ 0.32 here, about 1.4e-6); a tolerance of 1e-8 keeps every one
    /// of the 1,000 hits within 1e-6, and the default stays within its provable bound.
    @Test func boxHitsEqualTheAnalyticHitInBothModes() throws {
        let h = Vec3(0.8, 0.5, 0.6)
        let box = try SDFShape.box(halfExtents: h)
        let tight = [try SDFMarchOptions(mode: .conservative, tolerance: 1e-8),
                     try SDFMarchOptions(mode: .fast, tolerance: 1e-8)]
        for ray in Self.rays(seed: 4_002, count: 1_000, aim: h * 0.5) {
            let expected = try #require(ray.intersect(boxMin: -h, boxMax: h))
            let cosine = -expected.normal.dot(ray.direction)
            for options in tight {
                let result = SDFMarch.march(box, ray: ray, options: options)
                #expect(result.outcome == .hit)
                #expect(abs(result.distance - expected.distance) < 1e-6)
                #expect((result.normal - expected.normal).length < 1e-4)
            }
            for options in [Self.conservative, Self.fast] {
                let result = SDFMarch.march(box, ray: ray, options: options)
                #expect(result.outcome == .hit)
                #expect(result.distance <= expected.distance + 1e-12)
                #expect(expected.distance - result.distance <= 1e-7 * expected.distance / cosine + 1e-12)
                #expect((result.normal - expected.normal).length < 1e-4)
            }
        }
    }

    /// Near-normal incidence (cos θ > (2 − ω)/ω = 0.25) makes every over-relaxed step fail the overlap test, so the
    /// fast mode pays off where the surface runs nearly along the ray: 1,000 grazing rays (budget 4,096,
    /// since a conservative march at cos θ ≈ 0.04 contracts by only 4% per step).
    @Test func fastModeTakesFewerStepsOnGrazingRays() throws {
        let sphere = try SDFShape.sphere(radius: 1)
        let long = [try SDFMarchOptions(mode: .conservative, maxSteps: 4_096),
                    try SDFMarchOptions(mode: .fast, maxSteps: 4_096)]
        var conservativeSteps = 0, fastSteps = 0
        for ray in Self.grazingRays(seed: 4_004, count: 1_000) {
            let expected = try #require(ray.intersect(sphereCenter: .zero, radius: 1))
            let cosine = -expected.normal.dot(ray.direction)
            for options in long {
                let result = SDFMarch.march(sphere, ray: ray, options: options)
                #expect(result.outcome == .hit)
                #expect(result.distance <= expected.distance + 1e-12)
                #expect(expected.distance - result.distance <= 1e-7 * expected.distance / cosine + 1e-9)
                if options.mode == .fast { fastSteps += result.steps } else { conservativeSteps += result.steps }
            }
        }
        print("SDFMarch grazing sphere steps: conservative \(conservativeSteps), fast \(fastSteps)")
        #expect(fastSteps < conservativeSteps)
    }

    @Test func thinShellIsHitByBothModesButSkippedWithoutTheFallback() throws {
        let shell = try SDFShape.subtraction(SDFShape.sphere(radius: 1), SDFShape.sphere(radius: 0.999))
        var skips = 0
        for ray in Self.rays(seed: 4_003, count: 100, aim: Vec3(0.5, 0.5, 0.5)) {
            let expected = try #require(ray.intersect(sphereCenter: .zero, radius: 1))
            for options in [Self.conservative, Self.fast] {
                let result = SDFMarch.march(shell, ray: ray, options: options)
                #expect(result.outcome == .hit)
                #expect(abs(result.distance - expected.distance) < 1e-6)
            }
            if !Self.naiveHit(shell, ray) { skips += 1 }
        }
        print("SDFMarch thin shell: naive ω = 1.6 skips \(skips) of 100")
        #expect(skips >= 1)
        // The radial ray from (5, 0, 0): the naive first step 1.6 · 4 = 6.4 lands at x = −1.4, beyond the far side.
        let radial = try #require(Ray3(origin: Vec3(5, 0, 0), direction: Vec3(-1, 0, 0)))
        #expect(!Self.naiveHit(shell, radial))
        let result = SDFMarch.march(shell, ray: radial, options: Self.fast)
        #expect(result.outcome == .hit)
        #expect(abs(result.distance - 4) < 1e-6)
    }

    @Test func tooSmallBudgetIsExhaustedNotMissed() throws {
        let far = try SDFShape.sphere(radius: 1).translated(by: Vec3(0, 0, 50))
        let ray = try #require(Ray3(origin: .zero, direction: Vec3(0.9, 0, 50)))
        let short = SDFMarch.march(far, ray: ray, options: try SDFMarchOptions(maxSteps: 3))
        #expect(short.outcome == .budgetExhausted)
        #expect(short.steps == 3)
        #expect(SDFMarch.march(far, ray: ray).outcome == .hit)
    }

    @Test func rayPointingAwayMisses() throws {
        let sphere = try SDFShape.sphere(radius: 1)
        let ray = try #require(Ray3(origin: Vec3(0, 0, 5), direction: Vec3(0, 0, 1)))
        for options in [Self.conservative, Self.fast] {
            let result = SDFMarch.march(sphere, ray: ray, options: options)
            #expect(result.outcome == .miss)
            #expect(result.distance > options.maxDistance)
        }
    }

    @Test func startInsideHitsAtZero() throws {
        let sphere = try SDFShape.sphere(radius: 1)
        let ray = try #require(Ray3(origin: Vec3(0.2, 0, 0), direction: Vec3(0, 1, 0)))
        let result = SDFMarch.march(sphere, ray: ray, options: Self.fast)
        #expect(result.outcome == .hit)
        #expect(result.distance == 0)
        #expect(result.startedInside)
        #expect(result.steps == 0)
        #expect(result.point == ray.origin)
        #expect((result.normal - Vec3(1, 0, 0)).length < 1e-6)
    }

    @Test func optionsRefuseInvalidValues() throws {
        #expect(SDFMarchOptions.standard == (try SDFMarchOptions()))
        #expect(SDFMarchOptions.standard.mode == .conservative)
        #expect(SDFMarchOptions.standard.maxSteps == 128)
        #expect(SDFMarchOptions.standard.maxDistance == 100)
        #expect(SDFMarchOptions.standard.tolerance == 1e-7)
        _ = try SDFMarchOptions(maxSteps: 1)
        _ = try SDFMarchOptions(maxSteps: 4_096)
        #expect(throws: SDFError.nonPositive("maxSteps")) { try SDFMarchOptions(maxSteps: 0) }
        #expect(throws: SDFError.nonPositive("maxSteps")) { try SDFMarchOptions(maxSteps: 4_097) }
        #expect(throws: SDFError.nonPositive("maxDistance")) { try SDFMarchOptions(maxDistance: 0) }
        #expect(throws: SDFError.nonFinite("maxDistance")) { try SDFMarchOptions(maxDistance: .infinity) }
        #expect(throws: SDFError.nonPositive("tolerance")) { try SDFMarchOptions(tolerance: -1) }
        #expect(throws: SDFError.nonFinite("tolerance")) { try SDFMarchOptions(tolerance: .nan) }
        #expect(SDFError.nonPositive("maxSteps").reasonCode == "r2-f11.non-positive")
    }
}
