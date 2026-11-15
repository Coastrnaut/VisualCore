// Contacts2DTests — feature 082 (A11-P01) T-A11-102 (FR-A11-101; SC-A11-102, 105; contract specs/082-pp-p01-model/
// contracts/api.md; research D1). Shape area and inertia, pose transforms, circle–circle, circle–box and box–box
// contacts (separated, touching, overlapping, inside, face, corner, resting flat, 45° corner), swapped arguments,
// invalid input and determinism.
import Foundation
import Testing
import VisualCoreMath
@testable import VisualCoreSimulation

private func near(_ a: Double, _ b: Double, _ tolerance: Double = 1e-9) -> Bool { abs(a - b) <= tolerance }
private func near(_ a: Vec2, _ b: Vec2, _ tolerance: Double = 1e-9) -> Bool { a.distance(to: b) <= tolerance }
private func pose(_ x: Double, _ y: Double, _ angle: Double = 0) -> Pose2D { Pose2D(position: Vec2(x, y), angle: angle) }

struct ShapeAndPoseTests {
    @Test func areaAndInertia() {
        #expect(near(Shape2D.circle(radius: 2).area, 4 * Double.pi, 1e-12))
        #expect(near(Shape2D.box(halfExtents: Vec2(1, 0.5)).area, 2, 1e-12))
        #expect(near(Shape2D.circle(radius: 2).inertia(mass: 3), 6, 1e-12))
        // w = 2, h = 1: m·(4 + 1)/12.
        #expect(near(Shape2D.box(halfExtents: Vec2(1, 0.5)).inertia(mass: 12), 5, 1e-12))
    }

    @Test func poseRoundTrip() {
        let p = pose(1, 2, Double.pi / 2)
        #expect(near(p.toWorld(Vec2(1, 0)), Vec2(1, 3), 1e-12))
        #expect(near(p.toLocal(Vec2(1, 3)), Vec2(1, 0), 1e-12))
        let q = pose(-3.5, 0.25, 0.7)
        let w = Vec2(4.2, -1.1)
        #expect(near(q.toWorld(q.toLocal(w)), w, 1e-12))
    }

    @Test func shapeIsCodable() throws {
        let shapes: [Shape2D] = [.circle(radius: 0.5), .box(halfExtents: Vec2(0.3, 0.4))]
        let data = try JSONEncoder().encode(shapes)
        #expect(try JSONDecoder().decode([Shape2D].self, from: data) == shapes)
    }
}

struct CircleContactTests {
    private let unit = Shape2D.circle(radius: 0.5)

    @Test func separatedTouchingOverlapping() {
        #expect(Contacts2D.collide(unit, pose(0, 0), unit, pose(1.5, 0)) == nil)
        let touching = Contacts2D.collide(unit, pose(0, 0), unit, pose(1, 0))
        #expect(touching != nil)
        #expect(near(touching?.depth ?? -1, 0))
        let overlap = Contacts2D.collide(unit, pose(0, 0), unit, pose(0.6, 0))
        #expect(near(overlap?.depth ?? -1, 0.4))
        #expect(near(overlap?.normal ?? .zero, Vec2(1, 0)))
        #expect(overlap?.points.count == 1)
        let diagonal = Contacts2D.collide(unit, pose(0, 0), unit, pose(0.3, 0.4))
        #expect(near(diagonal?.normal ?? .zero, Vec2(0.6, 0.8)))
        #expect(near(diagonal?.depth ?? -1, 0.5))
    }

    @Test func coincidentCentresUseUpNormal() {
        let m = Contacts2D.collide(unit, pose(2, 2), unit, pose(2, 2))
        #expect(m?.normal == Vec2(0, 1))
        #expect(near(m?.depth ?? -1, 1))
    }

    @Test func circleInsideBox() {
        let box = Shape2D.box(halfExtents: Vec2(2, 1))
        // Centre 0.2 below the top face: least penetration through the top.
        let m = Contacts2D.collide(box, pose(0, 0), .circle(radius: 0.1), pose(0.5, 0.8))
        #expect(near(m?.normal ?? .zero, Vec2(0, 1)))
        #expect(near(m?.depth ?? -1, 0.3))
        #expect(near(m?.points.first ?? .zero, Vec2(0.5, 1)))
    }

    @Test func circleAgainstBoxFaceAndCorner() {
        let box = Shape2D.box(halfExtents: Vec2(1, 1))
        let face = Contacts2D.collide(box, pose(0, 0), .circle(radius: 0.5), pose(1.4, 0.2))
        #expect(near(face?.normal ?? .zero, Vec2(1, 0)))
        #expect(near(face?.depth ?? -1, 0.1))
        #expect(near(face?.points.first ?? .zero, Vec2(1, 0.2)))
        let corner = Contacts2D.collide(box, pose(0, 0), .circle(radius: 0.5), pose(1.3, 1.4))
        #expect(near(corner?.normal ?? .zero, Vec2(0.6, 0.8)))
        #expect(near(corner?.depth ?? -1, 0))
        #expect(near(corner?.points.first ?? .zero, Vec2(1, 1)))
        #expect(Contacts2D.collide(box, pose(0, 0), .circle(radius: 0.5), pose(1.4, 1.4)) == nil)
        // A rotated box: 45° puts its corner at (√2, 0).
        let rotated = Contacts2D.collide(box, pose(0, 0, Double.pi / 4), .circle(radius: 0.5), pose(1.8, 0))
        #expect(near(rotated?.normal ?? .zero, Vec2(1, 0)))
        #expect(near(rotated?.depth ?? -1, 0.5 - (1.8 - 2.0.squareRoot())))
    }

    @Test func circleFirstFlipsTheNormal() {
        let box = Shape2D.box(halfExtents: Vec2(1, 1))
        let boxFirst = Contacts2D.collide(box, pose(0, 0), .circle(radius: 0.5), pose(1.4, 0.2))
        let circleFirst = Contacts2D.collide(.circle(radius: 0.5), pose(1.4, 0.2), box, pose(0, 0))
        #expect(near(circleFirst?.normal ?? .zero, -(boxFirst?.normal ?? .zero)))
        #expect(circleFirst?.depth == boxFirst?.depth)
        #expect(circleFirst?.points == boxFirst?.points)
    }
}

struct BoxContactTests {
    private let floor = Shape2D.box(halfExtents: Vec2(2.5, 0.5))
    private let crate = Shape2D.box(halfExtents: Vec2(0.5, 0.5))

    @Test func separatedAndTouching() {
        #expect(Contacts2D.collide(floor, pose(0, 0), crate, pose(0, 1.2)) == nil)
        let touching = Contacts2D.collide(floor, pose(0, 0), crate, pose(0, 1))
        #expect(touching != nil)
        #expect(near(touching?.depth ?? -1, 0))
    }

    @Test func restingFlatGivesTwoPoints() throws {
        let m = try #require(Contacts2D.collide(floor, pose(0, 0), crate, pose(0.3, 0.99)))
        #expect(m.points.count == 2)
        #expect(near(m.normal, Vec2(0, 1)))
        #expect(near(m.depth, 0.01))
        let xs = m.points.map(\.x).sorted()
        #expect(near(xs[0], -0.2) && near(xs[1], 0.8))
    }

    @Test func rotatedCornerOnFaceGivesOnePoint() throws {
        let corner = 0.5 * 2.0.squareRoot()
        let m = try #require(Contacts2D.collide(floor, pose(0, 0), crate, pose(0, 0.5 + corner - 0.02, Double.pi / 4)))
        #expect(m.points.count == 1)
        #expect(near(m.normal, Vec2(0, 1)))
        #expect(near(m.depth, 0.02))
        #expect(near(m.points[0], Vec2(0, 0.48)))
    }

    @Test func rotatedBoxesFaceToFace() throws {
        // Both boxes rotated by 45°, stacked along their shared face normal (cos 45°, sin 45°).
        let a = Double.pi / 4
        let n = Vec2(cos(a), sin(a))
        let centre = n * 0.99
        let m = try #require(Contacts2D.collide(crate, pose(0, 0, a), crate, Pose2D(position: centre, angle: a)))
        #expect(m.points.count == 2)
        #expect(near(m.normal, n))
        #expect(near(m.depth, 0.01))
    }

    @Test func swappedArgumentsFlipTheNormal() throws {
        let ab = try #require(Contacts2D.collide(floor, pose(0, 0), crate, pose(0.3, 0.99)))
        let ba = try #require(Contacts2D.collide(crate, pose(0.3, 0.99), floor, pose(0, 0)))
        #expect(near(ba.normal, -ab.normal))
        #expect(near(ba.depth, ab.depth))
        #expect(ba.points.count == 2)
        let corner = 0.5 * 2.0.squareRoot()
        let tilted = pose(0, 0.5 + corner - 0.02, Double.pi / 4)
        let one = try #require(Contacts2D.collide(crate, tilted, floor, pose(0, 0)))
        #expect(near(one.normal, Vec2(0, -1)))
        #expect(near(one.depth, 0.02))
        #expect(one.points.count == 1)
    }

    @Test func invalidInputGivesNil() {
        let unit = Shape2D.circle(radius: 0.5)
        #expect(Contacts2D.collide(unit, pose(.nan, 0), unit, pose(0, 0)) == nil)
        #expect(Contacts2D.collide(unit, pose(0, 0), unit, pose(0, .infinity)) == nil)
        #expect(Contacts2D.collide(crate, pose(0, 0, .nan), crate, pose(0, 0)) == nil)
        #expect(Contacts2D.collide(.circle(radius: 0), pose(0, 0), unit, pose(0, 0)) == nil)
        #expect(Contacts2D.collide(.circle(radius: -1), pose(0, 0), unit, pose(0, 0)) == nil)
        #expect(Contacts2D.collide(.box(halfExtents: Vec2(0, 1)), pose(0, 0), unit, pose(0, 0)) == nil)
        #expect(Contacts2D.collide(crate, pose(0, 0), .box(halfExtents: Vec2(1, -1)), pose(0, 0)) == nil)
        #expect(Contacts2D.collide(.circle(radius: .infinity), pose(0, 0), unit, pose(0, 0)) == nil)
    }

    @Test func deterministicAndWellFormed() {
        var seed: UInt64 = 0x9E37_79B9_7F4A_7C15
        func next() -> Double {
            seed = seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            return Double(seed >> 11) / Double(1 << 53)
        }
        for _ in 0..<400 {
            let a: Shape2D = next() < 0.5 ? .circle(radius: 0.2 + next()) : .box(halfExtents: Vec2(0.2 + next(), 0.2 + next()))
            let b: Shape2D = next() < 0.5 ? .circle(radius: 0.2 + next()) : .box(halfExtents: Vec2(0.2 + next(), 0.2 + next()))
            let pa = pose(next() * 2, next() * 2, next() * 6.3)
            let pb = pose(next() * 2, next() * 2, next() * 6.3)
            let m1 = Contacts2D.collide(a, pa, b, pb)
            #expect(m1 == Contacts2D.collide(a, pa, b, pb))
            if let m = m1 {
                #expect(near(m.normal.length, 1, 1e-9))
                #expect(m.depth >= 0 && m.depth.isFinite)
                #expect((1...2).contains(m.points.count))
                #expect(m.points.allSatisfy { $0.isFinite })
            }
        }
    }
}
