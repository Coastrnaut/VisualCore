// FieldGridTests — feature 019 T-A02-102 (G-CPUFIELD; FR-A02-102, FR-A02-104; research R2).
import XCTest
@testable import VisualCoreSimulation

final class FieldGridTests: XCTestCase {
    func testShapeAndSubscript() throws {
        var g = FieldGrid(width: 3, height: 2, channels: 4, fill: 0.25)
        XCTAssertEqual(g.values.count, 24)
        g[2, 1, 3] = 0.5
        XCTAssertEqual(g[2, 1, 3], 0.5)
        XCTAssertEqual(g.values[(1 * 3 + 2) * 4 + 3], 0.5, "row-major, bottom row first")
        XCTAssertNil(FieldGrid(width: 2, height: 2, channels: 4, values: [0, 1]))
        XCTAssertNil(FieldGrid(width: 2, height: 2, channels: 5, values: Array(repeating: 0, count: 20)))
        XCTAssertNotNil(FieldGrid(width: 2, height: 2, channels: 2, values: Array(repeating: 0, count: 8)))
    }

    func testInvalidShapeIsClampedToOne() {
        let g = FieldGrid(width: 0, height: -3, channels: 9)
        XCTAssertEqual([g.width, g.height, g.channels], [1, 1, 4])
    }

    func testDifferenceFinitenessAndMinimum() throws {
        let a = FieldGrid(width: 2, height: 2, channels: 1, fill: 1)
        var b = a
        b[1, 1, 0] = 0.75
        XCTAssertEqual(a.maxAbsDifference(b), 0.25)
        XCTAssertNil(a.maxAbsDifference(FieldGrid(width: 2, height: 1, channels: 1)))
        XCTAssertTrue(b.isFinite)
        XCTAssertEqual(b.minValue, 0.75)
        b[0, 0, 0] = .nan
        XCTAssertFalse(b.isFinite)
    }

    func testPaddingToRGBA() throws {
        let v = try XCTUnwrap(FieldGrid(width: 1, height: 2, channels: 2, values: [1, 2, 3, 4]))
        let p = v.padded(toChannels: 4, fill: 0)
        XCTAssertEqual(p.values, [1, 2, 0, 0, 3, 4, 0, 0])
        XCTAssertEqual(v.padded(toChannels: 2), v)
    }

    func testFloat32RoundingIsIdentity() {
        for x: Float in [0, 0.1, 0.123456789, -3.75, 1e-9] { XCTAssertEqual(StoragePrecision.float32.round(x), x) }
    }

    func testFloat16RoundingMatchesHalfPrecision() {
        // Values exactly representable in half stay; others snap to the nearest half value.
        XCTAssertEqual(StoragePrecision.float16.round(0.5), 0.5)
        XCTAssertEqual(StoragePrecision.float16.round(1 + 0x1p-11), 1, "tie rounds to even (1.0)")
        XCTAssertEqual(StoragePrecision.float16.round(1 + 3 * 0x1p-11), 1 + 0x1p-9, "tie rounds to even")
        XCTAssertEqual(StoragePrecision.float16.round(70000), .infinity)
        XCTAssertEqual(StoragePrecision.float16.round(0x1p-26), 0, "below half the smallest subnormal")
        #if !(os(macOS) && arch(x86_64))
        var rng = SeededRandom(seed: 19)
        for _ in 0..<5000 {
            let x = Float(rng.double() * 4 - 2) * (rng.double() < 0.2 ? 1e-4 : 1)
            XCTAssertEqual(StoragePrecision.float16.round(x), Float(Float16(x)), "x=\(x)")
        }
        #endif
    }

    func testFloat16TowardZeroTruncates() {
        let p = StoragePrecision.float16TowardZero
        XCTAssertEqual(p.round(0.5), 0.5)
        XCTAssertEqual(p.round(1 + 0x1p-10 * 0.99), 1, "below the next half value truncates down")
        XCTAssertEqual(p.round(-(1 + 0x1p-10 * 0.99)), -1, "toward zero for negatives")
        XCTAssertEqual(p.round(0.8), 0.7998046875)
        XCTAssertEqual(p.round(1e6), 65504, "saturates")
        XCTAssertEqual(p.tolerance, 1e-3)
        var rng = SeededRandom(seed: 5)
        for _ in 0..<2000 {
            let x = Float(rng.double() * 2)
            let t = p.round(x), n = StoragePrecision.float16.round(x)
            XCTAssertLessThanOrEqual(t, x)
            XCTAssertLessThanOrEqual(abs(t - n), x < 1 ? 0x1p-11 : 0x1p-10, "at most one half step apart")
        }
    }

    // Feature 020 T-A02-203: exact bilinear sampling with clamp-to-edge (FR-A02-202; research R1).
    private func ramp() -> FieldGrid {
        var g = FieldGrid(width: 4, height: 3, channels: 2)
        for y in 0..<3 { for x in 0..<4 { g[x, y, 0] = Float(x); g[x, y, 1] = Float(10 * y) } }
        return g
    }

    func testBilinearAtCentersIsExact() {
        let g = ramp()
        for y in 0..<3 { for x in 0..<4 {
            XCTAssertEqual(g.sampleBilinear(cellX: Float(x) + 0.5, cellY: Float(y) + 0.5), [Float(x), Float(10 * y)])
        } }
    }

    func testBilinearInterpolatesLinearly() {
        let g = ramp()
        XCTAssertEqual(g.sampleBilinear(cellX: 1.0, cellY: 0.5, channel: 0), 0.5, "midpoint between cells 0 and 1")
        XCTAssertEqual(g.sampleBilinear(cellX: 2.25, cellY: 1.5, channel: 0), 1.75, accuracy: 1e-6)
        XCTAssertEqual(g.sampleBilinear(cellX: 1.5, cellY: 1.25, channel: 1), 7.5, accuracy: 1e-6)
    }

    func testBilinearClampsToEdge() {
        let g = ramp()
        XCTAssertEqual(g.sampleBilinear(cellX: -5, cellY: 0.5, channel: 0), 0)
        XCTAssertEqual(g.sampleBilinear(cellX: 0.2, cellY: 0.5, channel: 0), 0, "inside the first half cell")
        XCTAssertEqual(g.sampleBilinear(cellX: 99, cellY: 99), [3, 20])
        XCTAssertEqual(g.sampleBilinear(cellX: 3.75, cellY: -1, channel: 1), 0)
    }

    func testBilinearUsesTheDocumentedFormula() {
        // a + (b − a)·t in x, then in y: the same arithmetic order as vc_fieldBilinear on the GPU.
        var g = FieldGrid(width: 2, height: 2, channels: 1)
        g.values = [0.1, 0.7, 0.3, 0.9]
        let tx: Float = 0.3, ty: Float = 0.6
        let bottom = Float(0.1) + (Float(0.7) - Float(0.1)) * tx
        let top = Float(0.3) + (Float(0.9) - Float(0.3)) * tx
        XCTAssertEqual(g.sampleBilinear(cellX: 0.5 + tx, cellY: 0.5 + ty, channel: 0), bottom + (top - bottom) * ty)
    }

    func testUnorm8RoundingAndStall() {
        XCTAssertEqual(StoragePrecision.unorm8.round(-0.2), 0)
        XCTAssertEqual(StoragePrecision.unorm8.round(1.7), 1)
        XCTAssertEqual(StoragePrecision.unorm8.round(0.5), 128.0 / 255)
        // A per-step change below 1/510 stalls in 8-bit storage (research R2).
        var x = StoragePrecision.unorm8.round(0.5)
        for _ in 0..<100 { x = StoragePrecision.unorm8.round(x * 0.9983) }
        XCTAssertEqual(x, 128.0 / 255)
        XCTAssertEqual(StoragePrecision.unorm8.tolerance, 1.5 / 255)
        XCTAssertEqual(StoragePrecision.float16.tolerance, 1e-3)
    }

    func testRoundedGridAppliesPrecisionToEveryValue() {
        var g = FieldGrid(width: 2, height: 1, channels: 2)
        g.values = [0.1, 0.2, 0.3, 0.4]
        XCTAssertEqual(g.rounded(to: .unorm8).values, g.values.map { StoragePrecision.unorm8.round($0) })
    }
}
