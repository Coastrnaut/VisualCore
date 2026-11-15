// Ray2Tests — feature 096 (A13-P01) T-A13-102 (FR-A13-101–103; SC-A13-101, 102; gap G-RAYCAST2D; research D1–D2).
// Test data uses explicit types and plain loops (CI type-check rule).
import Foundation
import Testing
@testable import VisualCoreMath

@Suite struct Ray2Tests {
    private func ray(_ o: Vec2, _ d: Vec2) -> Ray2 { Ray2(origin: o, direction: d)! }

    private func facesAgainst(_ hit: RayHit2, _ r: Ray2) -> Bool {
        close(hit.normal.length, 1, 1e-12) && hit.normal.dot(r.direction) < 0
    }

    // MARK: Construction

    @Test func initNormalisesDirection() {
        let r = ray(Vec2(1, 2), Vec2(3, 4))
        #expect(close(r.direction, Vec2(0.6, 0.8)))
        #expect(close(r.direction.length, 1))
        #expect(r.origin == Vec2(1, 2))
        #expect(close(r.point(at: 5), Vec2(4, 6)))
    }

    @Test func initRefusesInvalidValues() {
        #expect(Ray2(origin: .zero, direction: .zero) == nil)
        #expect(Ray2(origin: Vec2(.nan, 0), direction: Vec2(1, 0)) == nil)
        #expect(Ray2(origin: Vec2(0, .infinity), direction: Vec2(1, 0)) == nil)
        #expect(Ray2(origin: .zero, direction: Vec2(.nan, 1)) == nil)
        #expect(Ray2(origin: .zero, direction: Vec2(0, -.infinity)) == nil)
        #expect(Ray2(origin: .zero, direction: Vec2(1e-320, 0)) == nil, "direction too small to normalise")
    }

    // MARK: Cast

    @Test func nearestHitAmongSeveralSegments() {
        let segments: [Segment2] = [
            Segment2(Vec2(5, -1), Vec2(5, 1)),
            Segment2(Vec2(3, 1), Vec2(3, -1)),
            Segment2(Vec2(-2, -1), Vec2(-2, 1)),
            Segment2(Vec2(4, -1), Vec2(4, 1)),
            Segment2(Vec2(1, 2), Vec2(1, 3)),
        ]
        let r = ray(Vec2(0, 0.5), Vec2(1, 0))
        let hit = r.cast(against: segments)
        #expect(hit != nil)
        guard let hit else { return }
        #expect(hit.segmentIndex == 1)
        #expect(close(hit.distance, 3))
        #expect(close(hit.point, Vec2(3, 0.5)))
        #expect(close(hit.normal, Vec2(-1, 0)))
        #expect(facesAgainst(hit, r))
        // From the other side the normal flips to face the ray.
        let back = ray(Vec2(10, 0), Vec2(-1, 0))
        let backHit = back.cast(against: segments)
        #expect(backHit?.segmentIndex == 0)
        #expect(backHit.map { close($0.normal, Vec2(1, 0)) } == true)
        if let backHit { #expect(facesAgainst(backHit, back)) }
    }

    @Test func normalFacesRayForObliqueSegments() {
        let r = ray(Vec2(0, 0), Vec2(1, 0.25))
        var count = 0
        for k in 0..<12 {
            let angle: Double = Double(k) * Double.pi / 12 + 0.1
            let c = Vec2(6, 1.5)
            let half = Vec2(cos(angle), sin(angle)) * 2
            let segments: [Segment2] = [Segment2(c - half, c + half)]
            if let hit = r.cast(against: segments) {
                count += 1
                #expect(facesAgainst(hit, r))
                #expect(close(hit.point, r.point(at: hit.distance), 1e-12))
            }
        }
        #expect(count == 12)
    }

    @Test func parallelAndCollinearSegmentsMiss() {
        let r = ray(.zero, Vec2(1, 0))
        let collinear: [Segment2] = [Segment2(Vec2(1, 0), Vec2(3, 0))]
        let parallel: [Segment2] = [Segment2(Vec2(1, 1), Vec2(3, 1))]
        let behind: [Segment2] = [Segment2(Vec2(-1, -1), Vec2(-1, 1))]
        let beside: [Segment2] = [Segment2(Vec2(2, 0.5), Vec2(2, 1))]
        #expect(r.cast(against: collinear) == nil)
        #expect(r.cast(against: parallel) == nil)
        #expect(r.cast(against: behind) == nil)
        #expect(r.cast(against: beside) == nil)
        #expect(r.cast(against: []) == nil)
    }

    @Test func endPointsHit() {
        let r = ray(.zero, Vec2(1, 0))
        let startEnd: [Segment2] = [Segment2(Vec2(2, 0), Vec2(2, 1))]   // u = 0
        let finalEnd: [Segment2] = [Segment2(Vec2(2, -1), Vec2(2, 0))]  // u = 1
        let a = r.cast(against: startEnd)
        let b = r.cast(against: finalEnd)
        #expect(a != nil)
        #expect(b != nil)
        #expect(a.map { close($0.distance, 2) && close($0.point, Vec2(2, 0)) } == true)
        #expect(b.map { close($0.distance, 2) && close($0.point, Vec2(2, 0)) } == true)
    }

    @Test func invalidSegmentsAreSkipped() {
        let r = ray(.zero, Vec2(1, 0))
        let segments: [Segment2] = [
            Segment2(Vec2(1, .nan), Vec2(1, 1)),
            Segment2(Vec2(1.5, -1), Vec2(.infinity, 1)),
            Segment2(Vec2(2, 0), Vec2(2, 0)),
            Segment2(Vec2(4, -1), Vec2(4, 1)),
        ]
        let hit = r.cast(against: segments)
        #expect(hit?.segmentIndex == 3)
        #expect(hit.map { close($0.distance, 4) } == true)
    }

    @Test func excludingIgnoresOneIndex() {
        let r = ray(.zero, Vec2(1, 0))
        let segments: [Segment2] = [
            Segment2(Vec2(2, -1), Vec2(2, 1)),
            Segment2(Vec2(3, -1), Vec2(3, 1)),
        ]
        #expect(r.cast(against: segments)?.segmentIndex == 0)
        #expect(r.cast(against: segments, excluding: 0)?.segmentIndex == 1)
        #expect(r.cast(against: segments, excluding: 1)?.segmentIndex == 0)
        #expect(r.cast(against: segments, excluding: 7)?.segmentIndex == 0)
    }

    @Test func minimumDistanceRespected() {
        let r = ray(.zero, Vec2(1, 0))
        let segments: [Segment2] = [Segment2(Vec2(2, -1), Vec2(2, 1))]
        #expect(r.cast(against: segments, minimumDistance: 2) == nil, "hit at exactly the minimum distance ignored")
        #expect(r.cast(against: segments, minimumDistance: 3) == nil)
        #expect(r.cast(against: segments, minimumDistance: 1.999)?.segmentIndex == 0)
        #expect(r.cast(against: segments, minimumDistance: .nan)?.segmentIndex == 0)
        #expect(r.cast(against: segments, minimumDistance: -5)?.segmentIndex == 0)
        // A segment through the origin is at distance 0 and never hit.
        let atOrigin: [Segment2] = [Segment2(Vec2(0, -1), Vec2(0, 1))]
        #expect(r.cast(against: atOrigin) == nil)
        #expect(r.cast(against: atOrigin, minimumDistance: 0) == nil)
    }

    @Test func equalDistancesResolveToLowerIndex() {
        let r = ray(.zero, Vec2(1, 0))
        let segments: [Segment2] = [
            Segment2(Vec2(5, -1), Vec2(5, 1)),
            Segment2(Vec2(2, -1), Vec2(2, 1)),
            Segment2(Vec2(2, 1), Vec2(2, -1)),
            Segment2(Vec2(2, -2), Vec2(2, 2)),
        ]
        #expect(r.cast(against: segments)?.segmentIndex == 1)
        #expect(r.cast(against: segments, excluding: 1)?.segmentIndex == 2)
        // Two segments meeting at the hit point (a corner).
        let corner: [Segment2] = [
            Segment2(Vec2(2, 0), Vec2(3, 1)),
            Segment2(Vec2(2, 0), Vec2(3, -1)),
        ]
        #expect(r.cast(against: corner)?.segmentIndex == 0)
    }

    @Test func reflectedRayBouncesBetweenMirrorsWithoutZeroDistance() {
        let walls: [Segment2] = [
            Segment2(Vec2(0, -100), Vec2(0, 100)),
            Segment2(Vec2(4, -100), Vec2(4, 100)),
        ]
        var current = ray(Vec2(2, 0), Vec2(1, 0.3))
        var excluded: Int? = nil
        var expectedIndex = 1
        for step in 0..<8 {
            let hit = current.cast(against: walls, excluding: excluded)
            #expect(hit != nil, "step \(step)")
            guard let hit else { return }
            #expect(hit.distance > 0, "step \(step)")
            #expect(hit.segmentIndex != excluded, "step \(step)")
            #expect(hit.segmentIndex == expectedIndex, "step \(step)")
            #expect(facesAgainst(hit, current))
            let reflected = current.direction.reflected(about: hit.normal)
            guard let next = Ray2(origin: hit.point, direction: reflected) else {
                Issue.record("reflected ray invalid at step \(step)")
                return
            }
            current = next
            excluded = hit.segmentIndex
            expectedIndex = 1 - expectedIndex
        }
        // Without excluding, the default minimum distance alone keeps the ray off its own surface.
        let start = ray(Vec2(2, 0), Vec2(1, 0.3))
        if let first = start.cast(against: walls) {
            let bounced = ray(first.point, start.direction.reflected(about: first.normal))
            let again = bounced.cast(against: walls)
            #expect(again?.segmentIndex == 0)
            #expect(again.map { $0.distance > 1 } == true)
        } else {
            Issue.record("first cast missed")
        }
    }

    // MARK: Reflection

    @Test func reflectionKeepsLengthAndAngleOver360Directions() {
        let s = 0.5.squareRoot()
        let normals: [Vec2] = [Vec2(0, 1), Vec2(1, 0), Vec2(s, s)]
        for n in normals {
            let tangent = Vec2(-n.y, n.x)
            for degree in 0..<360 {
                let angle: Double = Double(degree) * Double.pi / 180
                let d = Vec2(cos(angle), sin(angle))
                let r = d.reflected(about: n)
                let minusD = Vec2(-d.x, -d.y)
                #expect(close(r.length, d.length, 1e-12), "length at \(degree)°")
                #expect(close(minusD.dot(n), r.dot(n), 1e-12), "incidence at \(degree)°")
                #expect(close(d.dot(tangent), r.dot(tangent), 1e-12), "tangent at \(degree)°")
                #expect(close(minusD.cross(n) + r.cross(n), 0, 1e-12), "opposite sides at \(degree)°")
            }
        }
    }

    @Test func reflectionDegenerateAndNonUnitNormals() {
        let v = Vec2(3, -2)
        #expect(v.reflected(about: .zero) == v)
        #expect(v.reflected(about: Vec2(.nan, 1)) == v)
        #expect(v.reflected(about: Vec2(0, .infinity)) == v)
        let pairs: [(Vec2, Vec2)] = [
            (Vec2(0, 5), Vec2(0, 1)),
            (Vec2(-7, 0), Vec2(-1, 0)),
            (Vec2(3, 3), Vec2(0.5.squareRoot(), 0.5.squareRoot())),
            (Vec2(0.001, -0.002), Vec2(1, -2) / 5.0.squareRoot()),
        ]
        for pair in pairs {
            #expect(close(v.reflected(about: pair.0), v.reflected(about: pair.1), 1e-12))
        }
        #expect(close(Vec2(1, -1).reflected(about: Vec2(0, 1)), Vec2(1, 1)))
    }

    // MARK: Fixture

    @Test func exactFixture() {
        let r = ray(.zero, Vec2(1, 1))
        let segments: [Segment2] = [Segment2(Vec2(2, 0), Vec2(2, 4))]
        let hit = r.cast(against: segments)
        #expect(hit != nil)
        guard let hit else { return }
        #expect(hit.segmentIndex == 0)
        #expect(close(hit.distance, 2 * 2.0.squareRoot(), 1e-12))
        #expect(close(hit.point, Vec2(2, 2), 1e-12))
        #expect(close(hit.normal, Vec2(-1, 0), 1e-12))
        let reflected = r.direction.reflected(about: hit.normal)
        #expect(close(reflected, Vec2(-1, 1) / 2.0.squareRoot(), 1e-12))
    }
}
