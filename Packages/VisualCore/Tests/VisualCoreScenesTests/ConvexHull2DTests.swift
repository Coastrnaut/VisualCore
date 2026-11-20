// ConvexHull2DTests — feature 213 (R02-F13) T-R02F13-002 (FR-R02F13-002, FR-R02F13-008; research R3). Andrew's monotone
// chain: a square with interior and collinear points gives its four corners counter-clockwise; 1,000 seeded points all
// lie inside or on their hull; the unit square has signed area 1 (−1 clockwise); fewer than three non-collinear points
// give the documented empty hull. Points come from the local LCG `SDFTestRandom` with seed 2_013.
import Testing
import VisualCoreMath
@testable import VisualCoreScenes

@Suite struct ConvexHull2DTests {
    @Test func squareWithInteriorAndCollinearPointsGivesFourCornersCounterClockwise() {
        let points = [Vec2(1, 1), Vec2(0.5, 0.5), Vec2(0, 0), Vec2(0.5, 0), Vec2(1, 0), Vec2(0, 1), Vec2(1, 0.5),
                      Vec2(0.25, 0.75), Vec2(0, 0.5), Vec2(0.5, 1), Vec2(1, 1)]
        let hull = ConvexHull2D.hull(points)
        #expect(hull == [Vec2(0, 0), Vec2(1, 0), Vec2(1, 1), Vec2(0, 1)])
        #expect(ConvexHull2D.area(hull) == 1)
    }

    @Test func everySeededPointIsInsideOrOnTheHull() {
        var random = SDFTestRandom(seed: 2_013)
        var points: [Vec2] = []
        for _ in 0..<1_000 { points.append(Vec2((random.next() * 2 - 1) * 5, (random.next() * 2 - 1) * 3)) }
        let hull = ConvexHull2D.hull(points)
        #expect(hull.count >= 3)
        #expect(ConvexHull2D.area(hull) > 0)
        for i in hull.indices {
            let a = hull[i], b = hull[(i + 1) % hull.count], c = hull[(i + 2) % hull.count]
            #expect((b - a).cross(c - b) > 0) // strictly convex, counter-clockwise
            for p in points { #expect((b - a).cross(p - a) >= -1e-9) }
        }
    }

    @Test func unitSquareAreaIsSigned() {
        let ccw = [Vec2(0, 0), Vec2(1, 0), Vec2(1, 1), Vec2(0, 1)]
        #expect(ConvexHull2D.area(ccw) == 1)
        #expect(ConvexHull2D.area(Array(ccw.reversed())) == -1)
        #expect(ConvexHull2D.area([Vec2(0, 0), Vec2(1, 0)]) == 0)
    }

    @Test func fewerThanThreeNonCollinearPointsGiveAnEmptyHull() {
        #expect(ConvexHull2D.hull([]).isEmpty)
        #expect(ConvexHull2D.hull([Vec2(1, 2)]).isEmpty)
        #expect(ConvexHull2D.hull([Vec2(1, 2), Vec2(3, 4)]).isEmpty)
        #expect(ConvexHull2D.hull([Vec2(1, 2), Vec2(1, 2), Vec2(1, 2)]).isEmpty)
        #expect(ConvexHull2D.hull([Vec2(0, 0), Vec2(1, 1), Vec2(2, 2), Vec2(3, 3)]).isEmpty)
        #expect(ConvexHull2D.hull([Vec2(0, 0), Vec2(1, 0), Vec2(.nan, 1)]).isEmpty)
    }
}
