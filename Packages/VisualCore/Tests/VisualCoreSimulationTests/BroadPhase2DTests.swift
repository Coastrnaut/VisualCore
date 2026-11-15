// BroadPhase2DTests — feature 083 (A11-P02) T-A11-202 (FR-A11-202; SC-A11-203; contract specs/083-pp-p02-springs/
// contracts/api.md; research D2). Shape bounds, inclusive overlap, sweep and prune equal to brute force on 50 seeded
// scenes, touching boxes, empty and single inputs, sorted output and non-finite boxes.
import Foundation
import Testing
import VisualCoreMath
@testable import VisualCoreSimulation

private func box(_ x0: Double, _ y0: Double, _ x1: Double, _ y1: Double) -> AABB2D {
    AABB2D(min: Vec2(x0, y0), max: Vec2(x1, y1))
}

private func bruteForce(_ boxes: [AABB2D]) -> [BroadPhasePair2D] {
    var pairs: [BroadPhasePair2D] = []
    for a in boxes.indices {
        for b in boxes.indices where b > a && boxes[a].overlaps(boxes[b]) { pairs.append(BroadPhasePair2D(a: a, b: b)) }
    }
    return pairs
}

struct BroadPhase2DTests {
    @Test func shapeBounds() {
        let circle = Shape2D.circle(radius: 0.5).bounds(at: Pose2D(position: Vec2(1, 2)))
        #expect(circle == box(0.5, 1.5, 1.5, 2.5))
        let flat = Shape2D.box(halfExtents: Vec2(1, 0.5)).bounds(at: Pose2D(position: Vec2(0, 0)))
        #expect(flat == box(-1, -0.5, 1, 0.5))
        // Rotated 90°: the extents swap.
        let turned = Shape2D.box(halfExtents: Vec2(1, 0.5)).bounds(at: Pose2D(position: Vec2(0, 0), angle: .pi / 2))
        #expect(abs(turned.max.x - 0.5) <= 1e-12 && abs(turned.max.y - 1) <= 1e-12)
        // Rotated 45°: a unit square's half extent becomes √2/2·2 = √2.
        let diamond = Shape2D.box(halfExtents: Vec2(1, 1)).bounds(at: Pose2D(position: Vec2(3, 0), angle: .pi / 4))
        #expect(abs(diamond.max.x - (3 + 2.0.squareRoot())) <= 1e-12)
        #expect(abs(diamond.min.y + 2.0.squareRoot()) <= 1e-12)
        // The bounds contain every rotated corner.
        let pose = Pose2D(position: Vec2(-1, 4), angle: 0.37)
        let b = Shape2D.box(halfExtents: Vec2(0.7, 0.2)).bounds(at: pose)
        for c in [Vec2(-0.7, -0.2), Vec2(0.7, -0.2), Vec2(0.7, 0.2), Vec2(-0.7, 0.2)].map(pose.toWorld) {
            #expect(c.x >= b.min.x - 1e-12 && c.x <= b.max.x + 1e-12 && c.y >= b.min.y - 1e-12 && c.y <= b.max.y + 1e-12)
        }
    }

    @Test func overlapIsInclusiveWithinTolerance() {
        let a = box(0, 0, 1, 1)
        #expect(a.overlaps(box(1, 0, 2, 1)))
        #expect(a.overlaps(box(1 + 5e-10, 0, 2, 1)))
        #expect(!a.overlaps(box(1 + 1e-8, 0, 2, 1)))
        #expect(a.overlaps(box(0.2, 1, 0.4, 3)))
        #expect(!a.overlaps(box(0.2, 1.1, 0.4, 3)))
        #expect(!a.overlaps(box(.nan, 0, 1, 1)))
    }

    @Test func equalsBruteForceOnFiftySeededScenes() {
        var random = SeededRandom(seed: 0xA11_202)
        for _ in 0..<50 {
            let count = random.int(0...60)
            var boxes: [AABB2D] = []
            for _ in 0..<count {
                let x = random.range(0...15), y = random.range(0...10)
                let w = random.range(0.05...2), h = random.range(0.05...2)
                boxes.append(box(x, y, x + w, y + h))
            }
            // Some exact duplicates and touching neighbours.
            if count > 2 {
                boxes.append(boxes[0])
                let t = boxes[1]
                boxes.append(box(t.max.x, t.min.y, t.max.x + 1, t.max.y))
            }
            #expect(BroadPhase2D.pairs(boxes) == bruteForce(boxes))
        }
    }

    @Test func touchingBoxesCount() {
        // A row of four unit boxes edge to edge, a fifth touching only at a corner and a sixth apart.
        let boxes = [box(0, 0, 1, 1), box(1, 0, 2, 1), box(2, 0, 3, 1), box(3, 0, 4, 1), box(4, 1, 5, 2),
                     box(10, 10, 11, 11)]
        let pairs = BroadPhase2D.pairs(boxes)
        #expect(pairs == [BroadPhasePair2D(a: 0, b: 1), BroadPhasePair2D(a: 1, b: 2), BroadPhasePair2D(a: 2, b: 3),
                          BroadPhasePair2D(a: 3, b: 4)])
    }

    @Test func emptyAndSingleInputs() {
        #expect(BroadPhase2D.pairs([]).isEmpty)
        #expect(BroadPhase2D.pairs([box(0, 0, 1, 1)]).isEmpty)
    }

    @Test func outputIsSortedAndIndexOrdered() {
        // Given in descending x so the sweep order differs from the index order.
        let boxes = (0..<8).map { i -> AABB2D in
            let x = Double(7 - i) * 0.5
            return box(x, 0, x + 1.2, 1)
        }
        let pairs = BroadPhase2D.pairs(boxes)
        #expect(!pairs.isEmpty)
        #expect(pairs.allSatisfy { $0.a < $0.b })
        let sorted = pairs.sorted { $0.a != $1.a ? $0.a < $1.a : $0.b < $1.b }
        #expect(pairs == sorted)
        #expect(Set(pairs).count == pairs.count)
        #expect(pairs == bruteForce(boxes))
    }

    @Test func nonFiniteBoxesNeverPair() {
        let boxes = [box(0, 0, 1, 1), box(.nan, 0, 1, 1), box(0, 0, .infinity, 1), box(0.5, 0.5, 2, 2)]
        #expect(BroadPhase2D.pairs(boxes) == [BroadPhasePair2D(a: 0, b: 3)])
    }
}
