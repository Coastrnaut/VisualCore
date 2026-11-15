// Collision2DTests — feature 075 (A10-P01) T-A10-102 (FR-A10-101, 102; SC-A10-103; contract specs/075-na-p01-engine/
// contracts/api.md; research D1, D3). Circle–circle and circle–capsule overlap, closest point on a capsule, swept
// circles with tunnelling at high speed, invalid input and determinism.
import Foundation
import Testing
import VisualCoreMath
@testable import VisualCoreSimulation

private func circle(_ x: Double, _ y: Double, _ r: Double) -> CollisionCircle {
    CollisionCircle(center: Vec2(x, y), radius: r)
}

private func near(_ a: Double, _ b: Double, _ tolerance: Double = 1e-12) -> Bool { abs(a - b) <= tolerance }

struct CircleOverlapTests {
    @Test func touchingCountsAndOneUnitApartDoesNot() {
        #expect(Collision2D.overlaps(circle(0, 0, 0.5), circle(1, 0, 0.5)))
        #expect(Collision2D.overlaps(circle(0, 0, 0.5), circle(0, -1, 0.5)))
        // Gap of one unit between the surfaces.
        #expect(!Collision2D.overlaps(circle(0, 0, 0.5), circle(2, 0, 0.5)))
        #expect(Collision2D.overlaps(circle(0, 0, 0.5), circle(0.9, 0, 0.5)))
    }

    @Test func oneInsideTheOther() {
        #expect(Collision2D.overlaps(circle(0, 0, 3), circle(0.5, 0.5, 0.1)))
        #expect(Collision2D.overlaps(circle(0.5, 0.5, 0.1), circle(0, 0, 3)))
        #expect(Collision2D.overlaps(circle(2, 2, 1), circle(2, 2, 1)))
    }
}

struct CapsuleTests {
    /// A horizontal bar from (−1, 0) to (1, 0) with radius 0.25.
    private let bar = CollisionCapsule(a: Vec2(-1, 0), b: Vec2(1, 0), radius: 0.25)

    @Test func closestPointClampsToTheSegment() {
        #expect(Collision2D.closestPoint(on: bar, to: Vec2(0.3, 5)).distance(to: Vec2(0.3, 0)) <= 1e-12)
        #expect(Collision2D.closestPoint(on: bar, to: Vec2(-4, 1)) == Vec2(-1, 0))
        #expect(Collision2D.closestPoint(on: bar, to: Vec2(4, -1)) == Vec2(1, 0))
        let point = CollisionCapsule(a: Vec2(2, 3), b: Vec2(2, 3), radius: 1)
        #expect(Collision2D.closestPoint(on: point, to: Vec2(7, 7)) == Vec2(2, 3))
    }

    @Test func sideContactAndMiss() {
        // Touching the flat side: 0.25 + 0.5 = 0.75.
        #expect(Collision2D.overlaps(circle(0.4, 0.75, 0.5), bar))
        #expect(Collision2D.overlaps(circle(-0.4, -0.7, 0.5), bar))
        #expect(!Collision2D.overlaps(circle(0, 0.8, 0.5), bar))
        #expect(!Collision2D.overlaps(circle(0, 1.75, 0.5), bar))
    }

    @Test func bothRoundedEnds() {
        // Diagonal from each end: distance 0.7 < 0.75 hits; 0.8 misses.
        let d = 0.7 / 2.0.squareRoot()
        #expect(Collision2D.overlaps(circle(1 + d, d, 0.5), bar))
        #expect(Collision2D.overlaps(circle(-1 - d, -d, 0.5), bar))
        #expect(Collision2D.overlaps(circle(1.75, 0, 0.5), bar))
        #expect(Collision2D.overlaps(circle(-1.75, 0, 0.5), bar))
        #expect(!Collision2D.overlaps(circle(1.8, 0, 0.5), bar))
        #expect(!Collision2D.overlaps(circle(-1.8, 0, 0.5), bar))
        let e = 0.8 / 2.0.squareRoot()
        #expect(!Collision2D.overlaps(circle(1 + e, e, 0.5), bar))
        #expect(!Collision2D.overlaps(circle(-1 - e, -e, 0.5), bar))
    }

    @Test func degenerateSegmentActsAsACircle() {
        let dot = CollisionCapsule(a: Vec2(3, 3), b: Vec2(3, 3), radius: 0.5)
        for (x, y) in [(4.0, 3.0), (3.0, 2.0), (3.6, 3.6), (5.0, 3.0), (4.1, 3.0)] {
            #expect(Collision2D.overlaps(circle(x, y, 0.5), dot)
                    == Collision2D.overlaps(circle(x, y, 0.5), circle(3, 3, 0.5)))
        }
        #expect(Collision2D.overlaps(circle(4, 3, 0.5), dot))
        #expect(!Collision2D.overlaps(circle(4.1, 3, 0.5), dot))
    }
}

struct SweepTests {
    @Test func zeroWhenAlreadyTouching() {
        #expect(Collision2D.sweep(circle(0, 0, 0.5), moving: Vec2(5, 0), circle(1, 0, 0.5), moving: .zero) == 0)
        #expect(Collision2D.sweep(circle(0, 0, 0.5), moving: .zero, circle(0.2, 0, 0.5), moving: .zero) == 0)
        // Touching and moving apart still reports contact at the start.
        #expect(Collision2D.sweep(circle(0, 0, 0.5), moving: Vec2(-5, 0), circle(0.5, 0, 0.5), moving: .zero) == 0)
    }

    @Test func earliestFractionForAHeadOnCrossing() {
        // p = (−10, 0), d = (20, 0), R = 1: |−10 + 20 t| = 1 → t = 9/20.
        let onlyA = Collision2D.sweep(circle(-10, 0, 0.5), moving: Vec2(20, 0), circle(0, 0, 0.5), moving: .zero)
        #expect(onlyA.map { near($0, 0.45) } == true)
        let both = Collision2D.sweep(circle(-10, 0, 0.5), moving: Vec2(10, 0), circle(0, 0, 0.5), moving: Vec2(-10, 0))
        #expect(both.map { near($0, 0.45) } == true)
        // Off-centre: p = (−4, 0.6), d = (8, 0), R = 1: (−4 + 8 t)² = 1 − 0.36 → t = (4 − 0.8) / 8 = 0.4.
        let offset = Collision2D.sweep(circle(-4, 0.6, 0.6), moving: Vec2(8, 0), circle(0, 0, 0.4), moving: .zero)
        #expect(offset.map { near($0, 0.4) } == true)
        // Grazing contact (discriminant 0) at t = 0.5.
        let graze = Collision2D.sweep(circle(-10, 1, 0.5), moving: Vec2(20, 0), circle(0, 0, 0.5), moving: .zero)
        #expect(graze.map { near($0, 0.5, 1e-9) } == true)
        // Contact exactly at the end of the step counts.
        let end = Collision2D.sweep(circle(-3, 0, 0.5), moving: Vec2(2, 0), circle(0, 0, 0.5), moving: .zero)
        #expect(end.map { near($0, 1) } == true)
    }

    @Test func noHitWhenWideApartStillOrBeyondTheStep() {
        // Passing wide.
        #expect(Collision2D.sweep(circle(-10, 2, 0.5), moving: Vec2(20, 0), circle(0, 0, 0.5), moving: .zero) == nil)
        // Moving apart.
        #expect(Collision2D.sweep(circle(-2, 0, 0.5), moving: Vec2(-5, 0), circle(0, 0, 0.5), moving: .zero) == nil)
        #expect(Collision2D.sweep(circle(-2, 0, 0.5), moving: Vec2(-1, 0), circle(0, 0, 0.5), moving: Vec2(1, 0)) == nil)
        // Zero relative motion, including both moving together.
        #expect(Collision2D.sweep(circle(-2, 0, 0.5), moving: .zero, circle(0, 0, 0.5), moving: .zero) == nil)
        #expect(Collision2D.sweep(circle(-2, 0, 0.5), moving: Vec2(3, 1), circle(0, 0, 0.5), moving: Vec2(3, 1)) == nil)
        // Approaching but contact after the step (t > 1).
        #expect(Collision2D.sweep(circle(-10, 0, 0.5), moving: Vec2(4, 0), circle(0, 0, 0.5), moving: .zero) == nil)
    }

    @Test(arguments: [4.0, 10.0, 50.0])
    func tunnellingIsCaught(multiple: Double) {
        // Summed radii R = 1; travel per step = multiple × R; the start and end positions both miss.
        let travel = multiple
        let start = -travel / 2
        let expected = (travel / 2 - 1) / travel
        let a = circle(start, 0, 0.5)
        let b = circle(0, 0, 0.5)
        #expect(!Collision2D.overlaps(a, b))
        #expect(!Collision2D.overlaps(circle(start + travel, 0, 0.5), b))
        let onlyA = Collision2D.sweep(a, moving: Vec2(travel, 0), b, moving: .zero)
        #expect(onlyA.map { near($0, expected) } == true)
        let both = Collision2D.sweep(a, moving: Vec2(travel / 2, 0), b, moving: Vec2(-travel / 2, 0))
        #expect(both.map { near($0, expected) } == true)
        // A diagonal pass works too: the same travel rotated by 30°.
        let c = cos(Double.pi / 6), s = sin(Double.pi / 6)
        let diagonal = Collision2D.sweep(circle(start * c, start * s, 0.5), moving: Vec2(travel * c, travel * s),
                                         b, moving: .zero)
        #expect(diagonal.map { near($0, expected, 1e-9) } == true)
    }
}

struct CollisionInvalidInputTests {
    @Test func nonFiniteAndNegativeRadiusGiveFalseOrNil() {
        let bad: [Double] = [.nan, .infinity, -.infinity]
        let good = circle(0, 0, 0.5)
        let bar = CollisionCapsule(a: Vec2(-1, 0), b: Vec2(1, 0), radius: 0.25)
        for v in bad {
            #expect(!Collision2D.overlaps(circle(v, 0, 0.5), good))
            #expect(!Collision2D.overlaps(good, circle(0, v, 0.5)))
            #expect(!Collision2D.overlaps(circle(0, 0, v), good))
            #expect(!Collision2D.overlaps(circle(v, 0, 0.5), bar))
            #expect(!Collision2D.overlaps(good, CollisionCapsule(a: Vec2(v, 0), b: Vec2(1, 0), radius: 0.25)))
            #expect(!Collision2D.overlaps(good, CollisionCapsule(a: Vec2(-1, 0), b: Vec2(1, v), radius: 0.25)))
            #expect(!Collision2D.overlaps(good, CollisionCapsule(a: Vec2(-1, 0), b: Vec2(1, 0), radius: v)))
            #expect(Collision2D.sweep(circle(v, 0, 0.5), moving: Vec2(1, 0), good, moving: .zero) == nil)
            #expect(Collision2D.sweep(circle(-3, 0, 0.5), moving: Vec2(v, 0), good, moving: .zero) == nil)
            #expect(Collision2D.sweep(circle(-3, 0, 0.5), moving: Vec2(6, 0), good, moving: Vec2(0, v)) == nil)
            #expect(Collision2D.sweep(circle(-3, 0, v), moving: Vec2(6, 0), good, moving: .zero) == nil)
        }
        // A NaN query point is returned unchanged (as documented).
        let q = Collision2D.closestPoint(on: bar, to: Vec2(.nan, 1))
        #expect(q.x.isNaN && q.y == 1)
        #expect(!Collision2D.overlaps(circle(0, 0, -0.1), circle(0, 0, 0.5)))
        #expect(!Collision2D.overlaps(circle(0, 0, 0.5), CollisionCapsule(a: Vec2(0, 0), b: Vec2(1, 0), radius: -1)))
        #expect(Collision2D.sweep(circle(-3, 0, -0.5), moving: Vec2(6, 0), good, moving: .zero) == nil)
        #expect(Collision2D.sweep(good, moving: .zero, circle(0, 0, -0.5), moving: .zero) == nil)
    }

    @Test func toleranceIsDocumentedValue() {
        #expect(Collision2D.tolerance == 1e-9)
    }
}

struct CollisionDeterminismTests {
    @Test func identicalInputGivesIdenticalOutput() {
        var results: [[Double?]] = []
        for _ in 0..<2 {
            var row: [Double?] = []
            for i in 0..<200 {
                let x = Double(i) * 0.137 - 13
                let a = circle(x, sin(Double(i)) * 2, 0.3 + Double(i % 5) * 0.1)
                let b = circle(0.25, 0.5, 0.4)
                row.append(Collision2D.sweep(a, moving: Vec2(7.3, -0.9), b, moving: Vec2(-1.1, 0.4)))
                row.append(Collision2D.overlaps(a, b) ? 1 : 0)
                let cap = CollisionCapsule(a: Vec2(-1, 0.5), b: Vec2(1.5, -0.25), radius: 0.2)
                row.append(Collision2D.overlaps(a, cap) ? 1 : 0)
                row.append(Collision2D.closestPoint(on: cap, to: a.center).x)
            }
            results.append(row)
        }
        #expect(results[0] == results[1])
    }
}
