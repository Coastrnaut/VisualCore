// FractalMathTests — feature 026 T-A03-102 (FR-A03-102, FR-A03-103, SC-A03-101; clarification 1; manual Phase 01 and
// §11 fixture 1: known points).
import FractalExplorerCore
import Foundation
import VisualCoreMath
import XCTest

final class FractalMathTests: XCTestCase {
    private let cap = 1_000

    func testMandelbrotInteriorPoints() {
        for c in [Vec2(0, 0), Vec2(-1, 0), Vec2(-0.1, 0.1)] {
            let r = FractalMath.mandelbrot(c, cap: cap, radius: 2)
            XCTAssertTrue(r.interior, "\(c)")
            XCTAssertEqual(r.count, cap)
        }
    }

    func testMandelbrotExteriorPointsWithExactCounts() {
        let cases: [(Vec2, Int)] = [(Vec2(2, 0), 2), (Vec2(1, 1), 2), (Vec2(-2.1, 0), 1)]
        for (c, n) in cases {
            let r = FractalMath.mandelbrot(c, cap: cap, radius: 2)
            XCTAssertFalse(r.interior, "\(c)")
            XCTAssertEqual(r.count, n, "\(c)")
        }
    }

    func testJuliaSamples() {
        XCTAssertTrue(FractalMath.julia(Vec2(0.5, 0), seed: .zero, cap: cap, radius: 2).interior)
        let out = FractalMath.julia(Vec2(1.5, 0), seed: .zero, cap: cap, radius: 2)
        XCTAssertFalse(out.interior)
        XCTAssertEqual(out.count, 1, "z1 = 2.25, |z1|^2 = 5.06 > 4")
        XCTAssertTrue(FractalMath.julia(.zero, seed: Vec2(-1, 0), cap: cap, radius: 2).interior, "period 2: 0, -1, 0, ...")
        let far = FractalMath.julia(Vec2(2, 0), seed: Vec2(-0.8, 0.156), cap: cap, radius: 2)
        XCTAssertFalse(far.interior)
        XCTAssertEqual(far.count, 1)
    }

    func testSmoothValueIsFiniteAndNearTheCount() {
        var checked = 0
        for i in 0..<200 {
            let c = Vec2(-2.5 + Double(i) * 0.02, 0.6)
            let r = FractalMath.mandelbrot(c, cap: 500, radius: 2)
            guard !r.interior else { continue }
            XCTAssertTrue(r.smooth.isFinite, "\(c)")
            // log|z_n| lies in (ln 2, ln 6.41] for R = 2 and |c| <= 2.1, so smooth is in [n, n + 1 + log2(1/ln 2)].
            XCTAssertGreaterThanOrEqual(r.smooth, Double(r.count), "\(c)")
            XCTAssertLessThanOrEqual(r.smooth, Double(r.count) + 1 + log2(1 / log(2.0)), "\(c)")
            checked += 1
        }
        XCTAssertGreaterThan(checked, 50)
    }

    func testNonFiniteInputsNeverProduceNaN() {
        for bad in [Vec2(.nan, 0), Vec2(0, .infinity), Vec2(-.infinity, .nan)] {
            let m = FractalMath.mandelbrot(bad, cap: cap, radius: 2)
            XCTAssertFalse(m.interior)
            XCTAssertEqual(m.count, 0)
            XCTAssertEqual(m.smooth, 0)
            let j = FractalMath.julia(.zero, seed: bad, cap: cap, radius: 2)
            XCTAssertEqual(j.count, 0)
            XCTAssertFalse(j.smooth.isNaN)
        }
        XCTAssertEqual(FractalMath.mandelbrot(.zero, cap: cap, radius: .nan).count, cap, "invalid radius falls back to 2")
    }

    func testCapAndRadiusAreValidated() {
        XCTAssertEqual(FractalMath.mandelbrot(.zero, cap: 0, radius: 2).count, 1, "cap below 1 becomes 1")
        XCTAssertEqual(FractalMath.mandelbrot(.zero, cap: 50_000, radius: 2).count, FractalMath.capRange.upperBound)
        XCTAssertEqual(FractalMath.mandelbrot(Vec2(2, 0), cap: cap, radius: 1).count, 2, "radius below 2 becomes 2")
        XCTAssertEqual(FractalMath.mandelbrot(Vec2(2, 0), cap: cap, radius: 100).count, 4, "a larger radius escapes later")
    }
}
