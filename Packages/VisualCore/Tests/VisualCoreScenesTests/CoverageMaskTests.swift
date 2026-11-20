// CoverageMaskTests — feature 213 (R02-F13) T-R02F13-003 (FR-R02F13-003, FR-R02F13-004, FR-R02F13-007, FR-R02F13-008;
// SC-R02F13-002, SC-R02F13-004, SC-R02F13-005; research R4, R6). Identical, disjoint and half-overlapping aligned squares
// give IoU 1, 0 and 1/3 exactly; polygons sharing an edge (vertical, horizontal, diagonal through cell centres) cover
// each cell once; a seeded convex polygon's area is within 1% at 256² and its error at 256² is at most half that at 128²
// (mean over 100 seeded polygons: single polygons and a
// 10-polygon mean (ratio 0.63) are dominated by edge luck, the 100-polygon mean ratio is 0.29); a polygon partly outside the region is clipped; sizes 0 and 2,049 and mismatched masks
// are refused; two runs of 100 seeded scenes give identical digests; the stored form round-trips byte for byte, and
// schema 2 and set padding bits are refused. Points come from `SDFTestRandom` with seed 2_013. Masks are at most 256².
import Foundation
import Testing
import VisualCoreMath
@testable import VisualCoreScenes

@Suite struct CoverageMaskTests {
    static let low = Vec2(0, 0), high = Vec2(4, 4)

    static func square(_ x0: Double, _ y0: Double, _ x1: Double, _ y1: Double) -> [Vec2] {
        [Vec2(x0, y0), Vec2(x1, y0), Vec2(x1, y1), Vec2(x0, y1)]
    }

    static func mask(_ side: Int, _ polygons: [[Vec2]]) throws -> CoverageMask {
        var mask = try CoverageMask(min: low, max: high, width: side, height: side)
        mask.fill(polygons)
        return mask
    }

    /// The convex hull of `points` (monotone chain, counter-clockwise), local to the test.
    static func hull(_ points: [Vec2]) -> [Vec2] {
        let sorted = points.sorted { $0.x != $1.x ? $0.x < $1.x : $0.y < $1.y }
        var lower: [Vec2] = [], upper: [Vec2] = []
        for p in sorted {
            while lower.count >= 2, (lower[lower.count - 1] - lower[lower.count - 2]).cross(p - lower[lower.count - 2]) <= 0 {
                lower.removeLast()
            }
            lower.append(p)
        }
        for p in sorted.reversed() {
            while upper.count >= 2, (upper[upper.count - 1] - upper[upper.count - 2]).cross(p - upper[upper.count - 2]) <= 0 {
                upper.removeLast()
            }
            upper.append(p)
        }
        return Array(lower.dropLast() + upper.dropLast())
    }

    /// The shoelace area of a simple polygon.
    static func shoelace(_ polygon: [Vec2]) -> Double {
        var sum = 0.0
        for i in polygon.indices { sum += polygon[i].cross(polygon[(i + 1) % polygon.count]) }
        return abs(sum) / 2
    }

    @Test func alignedSquaresGiveExactIoU() throws {
        let a = try Self.mask(64, [Self.square(0, 0, 2, 2)])
        let same = try Self.mask(64, [Self.square(0, 0, 2, 2)])
        let disjoint = try Self.mask(64, [Self.square(2, 2, 4, 4)])
        let half = try Self.mask(64, [Self.square(1, 0, 3, 2)])
        #expect(a.count == 32 * 32)
        #expect(a.area == 4)
        #expect(try MaskComparison(a, same).iou == 1)
        #expect(try MaskComparison(a, disjoint).iou == 0)
        let overlap = try MaskComparison(a, half)
        #expect(overlap.intersection == 16 * 32)
        #expect(overlap.union == 48 * 32)
        #expect(overlap.iou == 1.0 / 3.0)
        let empty = try Self.mask(64, [])
        #expect(try MaskComparison(empty, empty).iou == 1)
    }

    @Test func sharedEdgesCoverEachCellOnce() throws {
        // Region [0,4]² at 8×8: cell centres at 0.25, 0.75, …; every shared edge below passes through cell centres.
        let pairs: [([Vec2], [Vec2])] = [
            (Self.square(0, 0, 2.25, 2), Self.square(2.25, 0, 4, 2)),
            (Self.square(0, 0, 4, 2.25), Self.square(0, 2.25, 4, 4)),
            ([Vec2(0, 0), Vec2(4, 0), Vec2(4, 4)], [Vec2(0, 0), Vec2(4, 4), Vec2(0, 4)]),
        ]
        for (first, second) in pairs {
            let a = try Self.mask(8, [first]), b = try Self.mask(8, [second])
            let both = try Self.mask(8, [first, second])
            let comparison = try MaskComparison(a, b)
            #expect(comparison.intersection == 0)
            #expect(both.count == a.count + b.count)
        }
        let diagonal = try Self.mask(8, [pairs[2].0, pairs[2].1])
        #expect(diagonal.count == 64)
        #expect(diagonal.cellCentre(x: 3, y: 5) == Vec2(1.75, 2.75))
    }

    @Test func seededConvexPolygonAreaConverges() throws {
        var random = SDFTestRandom(seed: 2_013)
        var sum128 = 0.0, sum256 = 0.0, worst256 = 0.0
        for _ in 0..<100 {
            let points = (0..<12).map { _ in Vec2(0.3 + random.next() * 3.4, 0.3 + random.next() * 3.4) }
            let polygon = Self.hull(points)
            let exact = Self.shoelace(polygon)
            let err128 = abs(try Self.mask(128, [polygon]).area - exact)
            let err256 = abs(try Self.mask(256, [polygon]).area - exact)
            #expect(err256 / exact < 0.01)
            worst256 = max(worst256, err256 / exact)
            sum128 += err128
            sum256 += err256
        }
        print("CoverageMask area: mean |err| 128² \(sum128 / 100), 256² \(sum256 / 100), worst relative 256² \(worst256)")
        #expect(sum256 <= 0.5 * sum128, "mean error 128² \(sum128 / 100), 256² \(sum256 / 100)")
    }

    @Test func polygonOutsideTheRegionIsClipped() throws {
        let mask = try Self.mask(64, [Self.square(-2, -2, 2, 2)])
        #expect(mask.count == 32 * 32)
        #expect(mask[0, 0] && mask[31, 31] && !mask[32, 0] && !mask[-1, 0])
        let outside = try Self.mask(64, [Self.square(5, 5, 6, 6), [Vec2(0, 0), Vec2(1, 1)]])
        #expect(outside.count == 0)
        let nonFinite = try Self.mask(64, [[Vec2(0, 0), Vec2(.nan, 1), Vec2(1, 0)]])
        #expect(nonFinite.count == 0)
    }

    @Test func invalidSizesAndRegionsAreRefused() throws {
        #expect(throws: ShadowError.maskSize(width: 0, height: 4)) {
            try CoverageMask(min: Self.low, max: Self.high, width: 0, height: 4)
        }
        #expect(throws: ShadowError.maskSize(width: 4, height: 2_049)) {
            try CoverageMask(min: Self.low, max: Self.high, width: 4, height: 2_049)
        }
        #expect(throws: ShadowError.malformed("region")) {
            try CoverageMask(min: Self.high, max: Self.low, width: 4, height: 4)
        }
        #expect(throws: ShadowError.nonFinite("region")) {
            try CoverageMask(min: Vec2(.infinity, 0), max: Self.high, width: 4, height: 4)
        }
        #expect(ShadowError.maskSize(width: 0, height: 4).reasonCode == "r2-f13.mask-size")
        #expect(try CoverageMask(min: Self.low, max: Self.high, width: 1, height: 1).words.count == 1)
    }

    @Test func mismatchedMasksAreRefused() throws {
        let a = try Self.mask(64, [])
        let b = try Self.mask(32, [])
        let c = try CoverageMask(min: Vec2(0, 0), max: Vec2(4, 5), width: 64, height: 64)
        #expect(throws: ShadowError.mismatchedMasks) { try MaskComparison(a, b) }
        #expect(throws: ShadowError.mismatchedMasks) { try MaskComparison(a, c) }
    }

    static func seededDigests() throws -> [UInt64] {
        var random = SDFTestRandom(seed: 2_013)
        var digests: [UInt64] = []
        for _ in 0..<100 {
            var polygons: [[Vec2]] = []
            for _ in 0..<3 {
                polygons.append((0..<5).map { _ in Vec2(random.next() * 5 - 0.5, random.next() * 5 - 0.5) })
            }
            digests.append(try Self.mask(96, polygons).digest)
        }
        return digests
    }

    @Test func seededScenesAreDeterministic() throws {
        let first = try Self.seededDigests(), second = try Self.seededDigests()
        #expect(first == second)
        #expect(Set(first).count > 90)
        let empty = try Self.mask(1, [])
        #expect(empty.digest == 0xa8c7_f832_281a_39c5)  // FNV-1a 64 of eight zero bytes.
    }

    static func storedObject(_ mask: CoverageMask) throws -> [String: Any] {
        let data = try CoverageMaskDocument(mask: mask).encoded()
        return try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    @Test func storedFormRoundTripsAndRefusesBadInput() throws {
        var mask = try CoverageMask(min: Vec2(-1.25, 0.1), max: Vec2(3, 2.7), width: 100, height: 37)
        mask.fill([Vec2(-1, 0.2), Vec2(2.9, 0.5), Vec2(0.4, 2.6)])
        let data = try CoverageMaskDocument(mask: mask).encoded()
        let decoded = try CoverageMaskDocument.decode(data)
        #expect(decoded.mask == mask)
        #expect(try decoded.encoded() == data)
        let text = try #require(String(data: data, encoding: .utf8))
        #expect(text.hasPrefix("{\"height\":37,\"max\":{"))

        var newer = try Self.storedObject(mask)
        newer["schema"] = 2
        #expect(throws: ShadowError.newerSchema(2)) {
            try CoverageMaskDocument.decode(try JSONSerialization.data(withJSONObject: newer))
        }

        let words = try #require(newer["words"] as? String)
        var bytes = [UInt8](try #require(Data(base64Encoded: words)))
        bytes[15] |= 0x80  // bit 63 of row 0's second word; columns 100…127 are padding.
        var padded = try Self.storedObject(mask)
        padded["words"] = Data(bytes).base64EncodedString()
        #expect(throws: ShadowError.malformed("padding")) {
            try CoverageMaskDocument.decode(try JSONSerialization.data(withJSONObject: padded))
        }

        var short = try Self.storedObject(mask)
        short["words"] = Data(bytes.dropLast(8)).base64EncodedString()
        #expect(throws: ShadowError.malformed("words")) {
            try CoverageMaskDocument.decode(try JSONSerialization.data(withJSONObject: short))
        }
        var notBase64 = try Self.storedObject(mask)
        notBase64["words"] = "***"
        #expect(throws: ShadowError.malformed("words")) {
            try CoverageMaskDocument.decode(try JSONSerialization.data(withJSONObject: notBase64))
        }
        var tooWide = try Self.storedObject(mask)
        tooWide["width"] = 2_049
        #expect(throws: ShadowError.maskSize(width: 2_049, height: 37)) {
            try CoverageMaskDocument.decode(try JSONSerialization.data(withJSONObject: tooWide))
        }
        #expect(throws: ShadowError.malformed("json")) { try CoverageMaskDocument.decode(Data("[]".utf8)) }
    }
}
