// DissipationTests — feature 019 T-A02-109 (FR-A02-102, FR-A02-104, SC-A02-103; research R1, R2).
import FluidArtPlaygroundCore
import VisualCoreSimulation
import XCTest

final class DissipationTests: XCTestCase {
    func testFactor() {
        XCTAssertEqual(Dissipation.factor(d: 0, dt: 1.0 / 60), 1)
        XCTAssertEqual(Dissipation.factor(d: 1, dt: 1.0 / 60), Float(1 / (1 + 1.0 / 60)), accuracy: 1e-7)
        XCTAssertEqual(Dissipation.factor(d: 10, dt: 1.0 / 30), Float(1 / (1 + 10.0 / 30)), accuracy: 1e-7)
    }

    func testZeroDissipationIsIdentityInEveryPrecision() {
        for p in StoragePrecision.allCases {
            var g = DyeSeed.uniform(width: 4, height: 4, rgba: SIMD4(0.8, 0.8, 0.8, 1)).rounded(to: p)
            let start = g
            for _ in 0..<60 { Dissipation.step(&g, d: 0, dt: 1.0 / 60, precision: p) }
            XCTAssertEqual(g, start, "\(p)")
        }
    }

    func testFloat32MatchesClosedForm() {
        var g = DyeSeed.uniform(width: 2, height: 2, rgba: SIMD4(0.8, 0.8, 0.8, 1))
        for _ in 0..<60 { Dissipation.step(&g, d: 1, dt: 1.0 / 60, precision: .float32) }
        let expected = 0.8 * pow(1 / (1 + 1.0 / 60), 60.0)
        XCTAssertEqual(Double(g[0, 0, 0]), expected, accuracy: 1e-5)
        XCTAssertEqual(Double(g[1, 1, 3]), pow(1 / (1 + 1.0 / 60), 60.0), accuracy: 1e-5)
    }

    func testThousandStepsAtMaximumStayFiniteAndNonNegative() {
        for p in StoragePrecision.allCases {
            var g = DyeSeed.pattern(width: 16, height: 16, seed: 3)
            for _ in 0..<1000 { Dissipation.step(&g, d: 10, dt: 1.0 / 30, precision: p) }
            XCTAssertTrue(g.isFinite, "\(p)")
            XCTAssertGreaterThanOrEqual(g.minValue, 0, "\(p)")
        }
    }

    func testUnorm8StallsAsPredicted() {
        // d = 0.1 changes 0.5 by about 0.0008 per step, below half an 8-bit step: storage keeps 128/255.
        var g = DyeSeed.uniform(width: 1, height: 1, rgba: SIMD4(0.5, 0.5, 0.5, 0.5)).rounded(to: .unorm8)
        for _ in 0..<60 { Dissipation.step(&g, d: 0.1, dt: 1.0 / 60, precision: .unorm8) }
        XCTAssertEqual(g[0, 0, 0], 128.0 / 255)
    }

    func testEncodedVelocityDecaysAroundZero() throws {
        let enc = try XCTUnwrap(SignedRangeEncoding(range: 4))
        var g = FieldGrid(width: 1, height: 1, channels: 4, fill: 0)
        g[0, 0, 0] = enc.encode(2)
        g[0, 0, 1] = enc.encode(0)
        g = g.rounded(to: .unorm8)
        for _ in 0..<30 { Dissipation.step(&g, d: 5, dt: 1.0 / 60, precision: .unorm8, encoding: enc, channels: 0..<2) }
        XCTAssertLessThan(abs(enc.decode(g[0, 0, 0])), 2 * 0.2, "decays toward zero")
        XCTAssertEqual(enc.decode(g[0, 0, 1]), 0, accuracy: 4.0 * 2 / 255, "zero stays at zero")
    }
}
