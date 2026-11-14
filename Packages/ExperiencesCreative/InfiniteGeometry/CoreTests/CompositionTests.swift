// CompositionTests.swift — feature 040 (A05-P01) T-A05-103 (FR-A05-112, FR-A05-113).
import Foundation
import Testing
import VisualCoreMath
import VisualCoreScenes
@testable import InfiniteGeometryCore

private func preset(_ kind: GeometryPreset.Kind, order: Int = 4, repeats: Int = 3, scale: Double = 1,
                    seed: UInt64 = 7) -> GeometryPreset {
    GeometryPreset(kind: kind, order: order, repeats: repeats, scale: scale, palette: 0, seed: seed)
}

private func polygons(_ c: Composition) -> [Polygon2D] {
    if case .plane(let p) = c { return p }
    Issue.record("expected a plane composition")
    return []
}

private func mesh(_ c: Composition) -> Mesh? {
    if case .solid(let m) = c { return m }
    Issue.record("expected a solid composition")
    return nil
}

@Test func curatedPresetsBuildNonEmptyWithinBudget() throws {
    for p in GeometryPreset.curated {
        let c = try Composition.build(p)
        #expect(c.elementCount > 0, "\(p.kind)")
        if p.kind != .solid {
            #expect(c.elementCount <= Composition.maxPolygons)
            #expect(try Composition.polygonCount(p) == c.elementCount, "count before building matches the build")
        }
    }
}

@Test func buildsAreDeterministicAndSeedDependent() throws {
    for p in GeometryPreset.curated {
        #expect(try Composition.build(p).digest == Composition.build(p).digest)
        #expect(try Composition.build(p) == Composition.build(p))
        var other = p
        other.seed &+= 1
        #expect(try Composition.build(other).digest != Composition.build(p).digest, "\(p.kind)")
    }
    #expect(try Composition.build(GeometryPreset.curated[0]).digest.count == 64)
}

@Test func planePolygonsAreInViewCounterClockwiseAndColoured() throws {
    for kind in [GeometryPreset.Kind.squareTiling, .hexTiling, .kaleidoscope] {
        for scale in [0.5, 1, 4] {
            let p = preset(kind, repeats: 4, scale: scale)
            for polygon in polygons(try Composition.build(p)) {
                let c = polygon.points.reduce(Vec2.zero, +) / Double(polygon.points.count)
                #expect(abs(c.x) <= 1 / scale + 1e-12 && abs(c.y) <= 1 / scale + 1e-12)
                var area = 0.0
                for k in polygon.points.indices {
                    area += polygon.points[k].cross(polygon.points[(k + 1) % polygon.points.count])
                }
                #expect(area > 0)
                #expect((0...5).contains(polygon.colorIndex))
            }
        }
    }
}

@Test func smallerScaleShowsMoreTiles() throws {
    for kind in [GeometryPreset.Kind.squareTiling, .hexTiling] {
        let near = try Composition.build(preset(kind, repeats: 6, scale: 2)).elementCount
        let far = try Composition.build(preset(kind, repeats: 6, scale: 1)).elementCount
        #expect(far > near, "\(kind)")
    }
}

@Test func kaleidoscopeHoldsTwoOrderImagesPerRing() throws {
    // Construction: dihedral(n) has 2n images; `repeats` rings; at scale ≤ 1 every image is in view.
    for order in [1, 2, 5, 24] {
        for repeats in [1, 3, 12] {
            let c = try Composition.build(preset(.kaleidoscope, order: order, repeats: repeats))
            #expect(c.elementCount == 2 * order * repeats, "order \(order) repeats \(repeats)")
        }
    }
}

@Test func solidIsClosedValidAndHasVolume() throws {
    for order in [1, 6, 24] {
        let m = try #require(mesh(try Composition.build(preset(.solid, order: order))))
        let report = m.validate(requireClosed: true)
        #expect(report.problems.isEmpty && report.moreProblems == 0, "order \(order): \(report)")
        #expect(report.summary.isClosed)
        #expect((report.summary.volume ?? 0) > 0)
        #expect(m.triangleCount % order == 0)
    }
}

@Test func oversizedPlaneIsRefusedBeforeBuilding() throws {
    let big = preset(.hexTiling, repeats: 12, scale: 0.25)
    let count = try Composition.polygonCount(big)
    #expect(count > Composition.maxPolygons)
    #expect(throws: CompositionError.budget(count)) { try Composition.build(big) }
    #expect(CompositionError.budget(count).code == "a05.budget")
}

@Test func refusedPresetsMapToInvalid() {
    var bad = GeometryPreset.curated[0]
    bad.repeats = 0
    let refused = bad
    #expect(throws: CompositionError.invalid("a05.out-of-range")) { try Composition.build(refused) }
    #expect(CompositionError.invalid("x").code == "a05.invalid")
}

@Test func planeDigestWritesNegativeZeroAsPositiveZero() {
    let negative = Composition.plane([Polygon2D(points: [Vec2(-0.0, 1), Vec2(1, -0.0), Vec2(0, 0)], colorIndex: 2)])
    let positive = Composition.plane([Polygon2D(points: [Vec2(0, 1), Vec2(1, 0), Vec2(0, 0)], colorIndex: 2)])
    #expect(negative.digest == positive.digest)
    #expect(Composition.plane([]).digest != positive.digest)
}
