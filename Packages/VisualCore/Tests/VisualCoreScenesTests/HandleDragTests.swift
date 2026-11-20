// HandleDragTests — feature 222 (R02-F22) T-R02F22-004 (FR-R02F22-003; SC-R02F22-003; clarification Q3; research R4).
import Foundation
import Testing
import VisualCoreMath
@testable import VisualCoreScenes

/// A small deterministic generator (SplitMix64) for seeded starts, constraints and rays.
fileprivate struct SplitMix {
    var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z: UInt64 = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
    /// A double in lower ..< upper.
    mutating func double(_ lower: Double, _ upper: Double) -> Double {
        let unit: Double = Double(next() >> 11) / Double(UInt64(1) << 53)
        return lower + (upper - lower) * unit
    }
    /// A point in the cube [−r, r]³.
    mutating func point(_ r: Double) -> Vec3 { Vec3(double(-r, r), double(-r, r), double(-r, r)) }
    /// A unit vector (rejection-sampled in the unit ball).
    mutating func unit() -> Vec3 {
        while true {
            let v: Vec3 = point(1)
            let l: Double = v.length
            if l > 0.1 && l <= 1 { return v / l }
        }
    }
}

@Suite struct HandleDragTests {
    /// A unit vector perpendicular to the unit vector `n`.
    static func perpendicular(_ n: Vec3) -> Vec3 {
        let helper: Vec3 = abs(n.x) < 0.9 ? Vec3(1, 0, 0) : Vec3(0, 1, 0)
        return n.cross(helper).normalized
    }

    /// The unit vector `cosine · n + sine · tangent` for a unit `n` and a unit `tangent` perpendicular to it.
    static func tilted(_ n: Vec3, _ tangent: Vec3, cosine: Double) -> Vec3 {
        let sine: Double = (1 - cosine * cosine).squareRoot()
        return n * cosine + tangent * sine
    }

    /// A seeded ray aimed at `target` from the normal's side of the plane with |d · n| ≥ 0.3.
    fileprivate static func planeRay(to target: Vec3, normal n: Vec3, _ rng: inout SplitMix) -> Ray3 {
        let tangent: Vec3 = perpendicular(n)
        let spin: Double = rng.double(0, 2 * Double.pi)
        let other: Vec3 = n.cross(tangent)
        let t: Vec3 = tangent * cos(spin) + other * sin(spin)
        let d: Vec3 = tilted(-n, t, cosine: rng.double(0.3, 1))
        let distance: Double = rng.double(1, 20)
        return Ray3(origin: target - d * distance, direction: d)!
    }

    /// A seeded ray passing `offset` away from `target` (on the axis) with |d · a| ≤ 0.9, the closest point ahead.
    fileprivate static func axisRay(to target: Vec3, axis a: Vec3, _ rng: inout SplitMix) -> Ray3 {
        let tangent: Vec3 = perpendicular(a)
        let spin: Double = rng.double(0, 2 * Double.pi)
        let other: Vec3 = a.cross(tangent)
        let t: Vec3 = tangent * cos(spin) + other * sin(spin)
        let d: Vec3 = tilted(a, t, cosine: rng.double(-0.9, 0.9))
        // Offset the passing point perpendicular to both the axis and the ray so the axis point stays `target`.
        let side: Vec3 = a.cross(d).normalized * rng.double(-0.5, 0.5)
        let distance: Double = rng.double(1, 20)
        return Ray3(origin: target + side - d * distance, direction: d)!
    }

    /// The distance of `p` from the line through `start` along the unit `a`.
    static func lineDistance(_ p: Vec3, _ start: Vec3, _ a: Vec3) -> Double { (p - start).cross(a).length }

    @Test func seededPlaneDragsFollowTheHitAndReturnExactly() {
        var rng: SplitMix = SplitMix(seed: 2_022)
        for _ in 0..<200 {
            let start: Vec3 = rng.point(5)
            let n: Vec3 = rng.unit()
            let scale: Double = rng.double(0.5, 3)
            let grab: Vec3 = start + Self.perpendicular(n) * rng.double(-0.3, 0.3)
            let startRay: Ray3 = Self.planeRay(to: grab, normal: n, &rng)
            guard var drag: HandleDrag = HandleDrag(start: start, ray: startRay, constraint: .plane(n * scale)) else {
                Issue.record("plane drag refused"); return
            }
            #expect(drag.position == start)
            let plane: Plane3 = Plane3(point: start, normal: n)!
            let h0: Vec3 = startRay.intersect(plane: plane)!.point
            for _ in 0..<5 {
                let target: Vec3 = start + rng.point(3)
                let projected: Vec3 = target - n * n.dot(target - start)
                let ray: Ray3 = Self.planeRay(to: projected, normal: n, &rng)
                let p: Vec3 = drag.update(ray: ray)
                #expect(!drag.isHeld)
                let hit: Vec3 = ray.intersect(plane: plane)!.point
                let expected: Vec3 = hit - (h0 - start)
                #expect((p - expected).length < 1e-9)
                #expect(abs((p - start).dot(n)) < 1e-9)
            }
            let back: Vec3 = drag.update(ray: startRay)
            #expect(back == start)
            #expect(drag.position == start)
        }
    }

    @Test func seededAxisDragsStayOnTheLineAndReturnExactly() {
        var rng: SplitMix = SplitMix(seed: 2_022)
        for _ in 0..<200 {
            let start: Vec3 = rng.point(5)
            let a: Vec3 = rng.unit()
            let grab: Vec3 = start + a * rng.double(-0.3, 0.3)
            let startRay: Ray3 = Self.axisRay(to: grab, axis: a, &rng)
            guard var drag: HandleDrag = HandleDrag(start: start, ray: startRay, constraint: .axis(a * 2)) else {
                Issue.record("axis drag refused"); return
            }
            #expect(drag.position == start)
            for _ in 0..<5 {
                let s: Double = rng.double(-4, 4)
                let target: Vec3 = grab + a * s
                let ray: Ray3 = Self.axisRay(to: target, axis: a, &rng)
                let p: Vec3 = drag.update(ray: ray)
                #expect(!drag.isHeld)
                #expect(Self.lineDistance(p, start, a) < 1e-9)
                // The grab offset is kept: the handle moved by the distance the grab point moved along the axis.
                #expect(abs((p - start).dot(a) - s) < 1e-9)
            }
            let back: Vec3 = drag.update(ray: startRay)
            #expect(back == start)
        }
    }

    @Test func grazingPlaneRaysHoldAndAGoodRayResumes() {
        var rng: SplitMix = SplitMix(seed: 2_022)
        for _ in 0..<50 {
            let start: Vec3 = rng.point(5)
            let n: Vec3 = rng.unit()
            let startRay: Ray3 = Self.planeRay(to: start, normal: n, &rng)
            var drag: HandleDrag = HandleDrag(start: start, ray: startRay, constraint: .plane(n))!
            let moved: Vec3 = drag.update(ray: Self.planeRay(to: start + Self.perpendicular(n), normal: n, &rng))
            #expect(!drag.isHeld)
            let tangent: Vec3 = Self.perpendicular(n)
            let d: Vec3 = Self.tilted(-n, tangent, cosine: 0.0999)
            let grazing: Ray3 = Ray3(origin: start - d * 10, direction: d)!
            #expect(abs(grazing.direction.dot(n)) < HandleDrag.planeGrazing)
            let held: Vec3 = drag.update(ray: grazing)
            #expect(drag.isHeld)
            #expect(held == moved)
            #expect(drag.position == moved)
            let back: Vec3 = drag.update(ray: startRay)
            #expect(!drag.isHeld)
            #expect(back == start)
        }
    }

    @Test func grazingAxisRaysHoldAndAGoodRayResumes() {
        var rng: SplitMix = SplitMix(seed: 2_022)
        for _ in 0..<50 {
            let start: Vec3 = rng.point(5)
            let a: Vec3 = rng.unit()
            let startRay: Ray3 = Self.axisRay(to: start, axis: a, &rng)
            var drag: HandleDrag = HandleDrag(start: start, ray: startRay, constraint: .axis(a))!
            let moved: Vec3 = drag.update(ray: Self.axisRay(to: start + a, axis: a, &rng))
            #expect(!drag.isHeld)
            let d: Vec3 = Self.tilted(a, Self.perpendicular(a), cosine: 0.9951)
            let grazing: Ray3 = Ray3(origin: start - d * 10, direction: d)!
            #expect(abs(grazing.direction.dot(a)) > HandleDrag.axisGrazing)
            let held: Vec3 = drag.update(ray: grazing)
            #expect(drag.isHeld)
            #expect(held == moved)
            let back: Vec3 = drag.update(ray: startRay)
            #expect(!drag.isHeld)
            #expect(back == start)
        }
    }

    @Test func aPlaneBehindTheRayHolds() {
        let start: Vec3 = Vec3(0, 0, 0)
        let startRay: Ray3 = Ray3(origin: Vec3(0, 0, 5), direction: Vec3(0, 0, -1))!
        var drag: HandleDrag = HandleDrag(start: start, ray: startRay, constraint: .plane(Vec3(0, 0, 1)))!
        let away: Ray3 = Ray3(origin: Vec3(0, 0, 5), direction: Vec3(0, 0.2, 1))!
        #expect(drag.update(ray: away) == start)
        #expect(drag.isHeld)
    }

    @Test func grazingOrMissingStartRaysAreRefused() {
        let start: Vec3 = Vec3(1, 2, 3)
        let n: Vec3 = Vec3(0, 1, 0)
        let dPlane: Vec3 = Self.tilted(-n, Vec3(1, 0, 0), cosine: 0.0999)
        let planeGrazing: Ray3 = Ray3(origin: start - dPlane * 10, direction: dPlane)!
        #expect(HandleDrag(start: start, ray: planeGrazing, constraint: .plane(n)) == nil)
        let dAxis: Vec3 = Self.tilted(n, Vec3(1, 0, 0), cosine: 0.9951)
        let axisGrazing: Ray3 = Ray3(origin: start - dAxis * 10, direction: dAxis)!
        #expect(HandleDrag(start: start, ray: axisGrazing, constraint: .axis(n)) == nil)
        let behind: Ray3 = Ray3(origin: start + n * 5, direction: n)!
        #expect(HandleDrag(start: start, ray: behind, constraint: .plane(n)) == nil)
        let axisBehind: Ray3 = Ray3(origin: start + Vec3(0, 0, 5), direction: Vec3(0, 0, 1))!
        #expect(HandleDrag(start: start, ray: axisBehind, constraint: .axis(n)) == nil)
    }

    @Test func invalidInputsAreRefused() {
        let start: Vec3 = Vec3(0, 0, 0)
        let ray: Ray3 = Ray3(origin: Vec3(0, 0, 5), direction: Vec3(0, 0, -1))!
        let bad: [Vec3] = [Vec3.zero, Vec3(.nan, 0, 1), Vec3(0, .infinity, 1), Vec3(-.infinity, 0, 0)]
        for v in bad {
            #expect(HandleDrag(start: start, ray: ray, constraint: .plane(v)) == nil)
            #expect(HandleDrag(start: start, ray: ray, constraint: .axis(v)) == nil)
        }
        #expect(HandleDrag(start: Vec3(.nan, 0, 0), ray: ray, constraint: .plane(Vec3(0, 0, 1))) == nil)
        #expect(HandleDrag(start: Vec3(0, .infinity, 0), ray: ray, constraint: .axis(Vec3(1, 0, 0))) == nil)
        let inverted: (min: Vec3, max: Vec3) = (min: Vec3(-1, 1, -1), max: Vec3(1, 0, 1))
        #expect(HandleDrag(start: start, ray: ray, constraint: .plane(Vec3(0, 0, 1)), bounds: inverted) == nil)
        let nanBounds: (min: Vec3, max: Vec3) = (min: Vec3(-1, -1, -1), max: Vec3(1, .nan, 1))
        #expect(HandleDrag(start: start, ray: ray, constraint: .plane(Vec3(0, 0, 1)), bounds: nanBounds) == nil)
        let drag: HandleDrag = HandleDrag(start: start, ray: ray, constraint: .plane(Vec3(0, 0, 4)))!
        #expect(drag.constraint == .plane(Vec3(0, 0, 1)))
    }

    @Test func boundsClampEachAxis() {
        var rng: SplitMix = SplitMix(seed: 2_022)
        let lo: Vec3 = Vec3(-1, -1, -1)
        let hi: Vec3 = Vec3(1, 1, 1)
        var clampedCount: Int = 0
        for _ in 0..<200 {
            let start: Vec3 = rng.point(0.9)
            let n: Vec3 = rng.unit()
            let startRay: Ray3 = Self.planeRay(to: start, normal: n, &rng)
            var free: HandleDrag = HandleDrag(start: start, ray: startRay, constraint: .plane(n))!
            var boxed: HandleDrag = HandleDrag(start: start, ray: startRay, constraint: .plane(n), bounds: (lo, hi))!
            #expect(boxed.position == start)
            let target: Vec3 = start + rng.point(4)
            let ray: Ray3 = Self.planeRay(to: target - n * n.dot(target - start), normal: n, &rng)
            let p: Vec3 = free.update(ray: ray)
            let q: Vec3 = boxed.update(ray: ray)
            let expected: Vec3 = Vec3(min(max(p.x, lo.x), hi.x), min(max(p.y, lo.y), hi.y), min(max(p.z, lo.z), hi.z))
            #expect(q == expected)
            if q != p { clampedCount += 1 }
            #expect(boxed.update(ray: startRay) == start)
        }
        #expect(clampedCount > 50)
    }

    @Test func rotationAngleForQuarterAndHalfTurns() {
        var rng: SplitMix = SplitMix(seed: 2_022)
        for _ in 0..<100 {
            let center: Vec3 = rng.point(5)
            let n: Vec3 = rng.unit()
            let e1: Vec3 = Self.perpendicular(n)
            let e2: Vec3 = n.cross(e1)
            let r: Double = rng.double(0.5, 3)
            let start: Vec3 = center + e1 * r
            let startRay: Ray3 = Self.planeRay(to: start, normal: n, &rng)
            var drag: HandleDrag = HandleDrag(start: start, ray: startRay, constraint: .plane(n))!
            #expect(drag.angle(around: center) == 0)
            drag.update(ray: Self.planeRay(to: center + e2 * r, normal: n, &rng))
            #expect(abs(drag.angle(around: center) - Double.pi / 2) < 1e-12)
            drag.update(ray: Self.planeRay(to: center - e2 * r, normal: n, &rng))
            #expect(abs(drag.angle(around: center) + Double.pi / 2) < 1e-12)
            drag.update(ray: Self.planeRay(to: center - e1 * r, normal: n, &rng))
            #expect(abs(abs(drag.angle(around: center)) - Double.pi) < 1e-12)
            // A center off the plane is projected onto it: the same angle.
            #expect(abs(abs(drag.angle(around: center + n * 2)) - Double.pi) < 1e-12)
            // The center at a hit gives 0.
            #expect(drag.angle(around: start) == 0 || abs(drag.angle(around: start)) < 1e-12)
        }
    }

    @Test func angleIsZeroForAxisDragsAndDegenerateCenters() {
        let start: Vec3 = Vec3(0, 0, 0)
        let ray: Ray3 = Ray3(origin: Vec3(0, 5, 5), direction: Vec3(0, -1, -1))!
        var axis: HandleDrag = HandleDrag(start: start, ray: ray, constraint: .axis(Vec3(1, 0, 0)))!
        axis.update(ray: Ray3(origin: Vec3(2, 5, 5), direction: Vec3(0, -1, -1))!)
        #expect(axis.angle(around: Vec3(0, 0, 0)) == 0)
        let plane: HandleDrag = HandleDrag(start: start, ray: ray, constraint: .plane(Vec3(0, 0, 1)))!
        #expect(plane.angle(around: start) == 0)
        #expect(plane.angle(around: Vec3(.nan, 0, 0)) == 0)
    }
}
