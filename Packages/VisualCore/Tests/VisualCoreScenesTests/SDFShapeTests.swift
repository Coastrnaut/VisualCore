// SDFShapeTests — feature 211 (R02-F11) T-R02F11-002 (FR-R02F11-001, FR-R02F11-002, FR-R02F11-006; SC-R02F11-001).
// Every primitive equals its closed form at 1,000 seeded points within 1e-12; the set operations follow their
// definitions; smooth union never exceeds the hard union and equals it at radius 0; transforms move, turn and scale the
// distance as stated; normals of a sphere and a plane; every refusal with its reason code; large and small inputs stay
// finite; the fallback normal. Points come from a local 64-bit LCG with seed 2_011 (no randomness in the library).
import Foundation
import Testing
import VisualCoreMath
@testable import VisualCoreScenes

/// A deterministic 64-bit linear congruential generator for test points.
struct SDFTestRandom {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    /// The next value in 0..<1.
    mutating func next() -> Double {
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        return Double(state >> 11) / Double(1 << 53)
    }
    /// A point with components in −range…range.
    mutating func point(_ range: Double = 3) -> Vec3 {
        Vec3((next() * 2 - 1) * range, (next() * 2 - 1) * range, (next() * 2 - 1) * range)
    }
}

@Suite struct SDFShapeTests {
    static func points() -> [Vec3] {
        var random = SDFTestRandom(seed: 2_011)
        return (0..<1_000).map { _ in random.point() }
    }

    @Test func primitivesMatchTheirClosedForms() throws {
        let sphere = try SDFShape.sphere(radius: 1.25)
        let box = try SDFShape.box(halfExtents: Vec3(1, 0.5, 2))
        let plane = try SDFShape.plane(normal: Vec3(0, 2, 0), offset: 0.5)
        let capsule = try SDFShape.capsule(a: Vec3(-1, 0, 0), b: Vec3(1, 0, 0), radius: 0.3)
        let torus = try SDFShape.torus(major: 1.5, minor: 0.25)
        let roundedBox = try SDFShape.roundedBox(halfExtents: Vec3(1, 0.6, 0.8), radius: 0.2)   // T-R02F11-015
        for p in Self.points() {
            let r = Vec3(abs(p.x) - 0.8, abs(p.y) - 0.4, abs(p.z) - 0.6)
            let roundedD = Vec3(max(r.x, 0), max(r.y, 0), max(r.z, 0)).length + min(max(r.x, max(r.y, r.z)), 0) - 0.2
            #expect(abs(roundedBox.distance(at: p) - roundedD) < 1e-12)
            #expect(abs(sphere.distance(at: p) - (p.length - 1.25)) < 1e-12)
            #expect(abs(plane.distance(at: p) - (p.y - 0.5)) < 1e-12)
            let q = Vec3(abs(p.x) - 1, abs(p.y) - 0.5, abs(p.z) - 2)
            let boxD = Vec3(max(q.x, 0), max(q.y, 0), max(q.z, 0)).length + min(max(q.x, max(q.y, q.z)), 0)
            #expect(abs(box.distance(at: p) - boxD) < 1e-12)
            let cx = min(max(p.x, -1), 1)
            #expect(abs(capsule.distance(at: p) - ((p - Vec3(cx, 0, 0)).length - 0.3)) < 1e-12)
            let ring = (p.x * p.x + p.z * p.z).squareRoot() - 1.5
            #expect(abs(torus.distance(at: p) - ((ring * ring + p.y * p.y).squareRoot() - 0.25)) < 1e-12)
        }
        #expect(sphere.distance(at: .zero) == -1.25)
        #expect(sphere.contains(.zero))
        #expect(!sphere.contains(Vec3(2, 0, 0)))
        let rounded = try SDFShape.roundedBox(halfExtents: Vec3(1, 1, 1), radius: 0.25)
        #expect(abs(rounded.distance(at: Vec3(2, 0, 0)) - 1) < 1e-12)
        #expect(abs(rounded.distance(at: Vec3(1.5, 1.5, 0)) - ((0.75 * 0.75 * 2).squareRoot() - 0.25)) < 1e-12)
    }

    @Test func setOperationsFollowTheirDefinitions() throws {
        let a = try SDFShape.sphere(radius: 1)
        let b = try SDFShape.box(halfExtents: Vec3(0.6, 0.6, 0.6)).translated(by: Vec3(0.8, 0, 0))
        let u = try SDFShape.union([a, b]), i = try SDFShape.intersection([a, b])
        let s = try SDFShape.subtraction(a, b)
        let smooth = try SDFShape.smoothUnion(a, b, radius: 0.3), hard = try SDFShape.smoothUnion(a, b, radius: 0)
        for p in Self.points() {
            let da = a.distance(at: p), db = b.distance(at: p)
            #expect(abs(u.distance(at: p) - min(da, db)) < 1e-12)
            #expect(abs(i.distance(at: p) - max(da, db)) < 1e-12)
            #expect(abs(s.distance(at: p) - max(da, -db)) < 1e-12)
            #expect(smooth.distance(at: p) <= min(da, db) + 1e-12)
            #expect(hard.distance(at: p) == min(da, db))
        }
        #expect(u.nodeCount == 4 && u.depth == 3)
    }

    @Test func transformsMoveTurnAndScale() throws {
        let sphere = try SDFShape.sphere(radius: 1)
        let moved = try sphere.translated(by: Vec3(2, 0, 0))
        #expect(abs(moved.distance(at: Vec3(2, 0, 0)) + 1) < 1e-12)
        let box = try SDFShape.box(halfExtents: Vec3(2, 0.5, 0.5))
        let turned = try box.rotated(by: Quat(axis: Vec3(0, 0, 1), angle: .pi / 2))
        #expect(abs(turned.distance(at: Vec3(0, 2.5, 0)) - 0.5) < 1e-12)
        #expect(abs(turned.distance(at: Vec3(1, 0, 0)) - 0.5) < 1e-12)
        let big = try sphere.scaled(by: 3)
        for p in Self.points() { #expect(abs(big.distance(at: p) - (p.length - 3)) < 1e-12) }
    }

    @Test func normalsOfASphereAndAPlane() throws {
        let sphere = try SDFShape.sphere(radius: 1)
        for p in Self.points().prefix(200) where p.length > 0.1 {
            let n = sphere.normal(at: p), expected = p.normalized
            #expect((n - expected).length < 1e-6)
        }
        let plane = try SDFShape.plane(normal: Vec3(1, 1, 0), offset: 0)
        #expect((plane.normal(at: Vec3(3, -1, 2)) - Vec3(1, 1, 0).normalized).length < 1e-6)
        #expect(sphere.normal(at: .zero) == Vec3(0, 1, 0), "the fallback normal at a zero gradient")
    }

    @Test func refusalsCarryTheirReasonCodes() throws {
        #expect(throws: SDFError.nonPositive("radius")) { _ = try SDFShape.sphere(radius: 0) }
        #expect(throws: SDFError.nonFinite("radius")) { _ = try SDFShape.sphere(radius: .nan) }
        #expect(throws: SDFError.zeroDirection("normal")) { _ = try SDFShape.plane(normal: .zero, offset: 0) }
        #expect(throws: SDFError.zeroDirection("segment")) {
            _ = try SDFShape.capsule(a: Vec3(1, 1, 1), b: Vec3(1, 1, 1), radius: 0.1)
        }
        #expect(throws: SDFError.nonPositive("minor")) { _ = try SDFShape.torus(major: 1, minor: 1) }
        #expect(throws: SDFError.nonPositive("radius")) {
            _ = try SDFShape.roundedBox(halfExtents: Vec3(1, 0.2, 1), radius: 0.3)
        }
        let sphere = try SDFShape.sphere(radius: 1)
        #expect(throws: SDFError.notUnitRotation) { _ = try sphere.rotated(by: Quat(x: 0, y: 0, z: 0, w: 2)) }
        #expect(throws: SDFError.nonPositive("factor")) { _ = try sphere.scaled(by: -1) }
        #expect(throws: SDFError.nonPositive("radius")) { _ = try SDFShape.smoothUnion(sphere, sphere, radius: -0.1) }
        #expect(throws: SDFError.nonPositive("children")) { _ = try SDFShape.union([]) }
        var deep = sphere
        for _ in 1..<SDFShape.maxDepth { deep = try deep.translated(by: Vec3(0, 0, 0)) }
        #expect(deep.depth == 32)
        #expect(throws: SDFError.tooDeep(33)) { _ = try deep.translated(by: .zero) }
        #expect(SDFError.tooManyNodes(257).reasonCode == "r2-f11.too-many-nodes")
        #expect(SDFError.notUnitRotation.reasonCode == "r2-f11.not-unit-rotation")
        #expect(SDFError.malformed("x").reasonCode == "r2-f11.malformed")
    }

    @Test func tooManyNodesIsRefused() throws {
        let leaves = try (0..<32).map { _ in try SDFShape.sphere(radius: 1) }
        let group = try SDFShape.union(leaves)   // 33 nodes
        let groups = Array(repeating: group, count: 7)   // 231 + 1 = 232
        let seven = try SDFShape.union(groups)
        #expect(seven.nodeCount == 232)
        let extra = try SDFShape.union(Array(leaves.prefix(23)))   // 24 nodes → 232 + 24 + 1 = 257
        #expect(throws: SDFError.tooManyNodes(257)) { _ = try SDFShape.union([seven, extra]) }
    }

    @Test func largeAndSmallInputsStayFinite() throws {
        let tiny = try SDFShape.sphere(radius: 1e-6)
        let shape = try SDFShape.smoothUnion(tiny, try SDFShape.box(halfExtents: Vec3(1e-6, 1e-6, 1e-6)), radius: 1e-6)
        var random = SDFTestRandom(seed: 2_011)
        for _ in 0..<200 {
            let p = random.point(1e6)
            #expect(shape.distance(at: p).isFinite)
            let n = shape.normal(at: p)
            #expect(n.x.isFinite && n.y.isFinite && n.z.isFinite)
        }
    }
}
