// SplatTests — feature 020 T-A02-207 (FR-A02-203, FR-A02-205; spec clarification 2; edge cases).
import FluidArtPlaygroundCore
import Foundation
import VisualCoreSimulation
import XCTest

final class SplatTests: XCTestCase {
    func testValidationClampsAndRejects() throws {
        XCTAssertNil(Splat(position: SIMD2(.nan, 0.5), radius: 0.1, force: .zero, color: .one))
        XCTAssertNil(Splat(position: SIMD2(0.5, 0.5), radius: .infinity, force: .zero, color: .one))
        XCTAssertNil(Splat(position: SIMD2(0.5, 0.5), radius: 0.1, force: SIMD2(.nan, 0), color: .one))
        XCTAssertNil(Splat(position: SIMD2(0.5, 0.5), radius: 0.1, force: .zero, color: SIMD4(.nan, 0, 0, 1)))
        let ok = try XCTUnwrap(Splat(position: SIMD2(0.5, 0.5), radius: 0.1, force: SIMD2(3, 4), color: SIMD4(0.5, 0.5, 0.5, 1)))
        XCTAssertFalse(ok.wasClamped)
        let c = try XCTUnwrap(Splat(position: SIMD2(-1, 2), radius: 9, force: SIMD2(30_000, 40_000), color: SIMD4(2, -1, 0.5, 1)))
        XCTAssertTrue(c.wasClamped)
        XCTAssertEqual(c.position, SIMD2(0, 1))
        XCTAssertEqual(c.radius, 0.25)
        XCTAssertEqual(c.force.x, 6000, accuracy: 0.01, "scaled to |force| = 10,000 keeping direction")
        XCTAssertEqual(c.force.y, 8000, accuracy: 0.01)
        XCTAssertEqual(c.color, SIMD4(1, 0, 0.5, 1))
        XCTAssertEqual(try XCTUnwrap(Splat(position: SIMD2(0.5, 0.5), radius: 0.0001, force: .zero, color: .one)).radius, 0.005)
    }

    func testGaussianWeight() throws {
        let s = try XCTUnwrap(Splat(position: SIMD2(0.5, 0.5), radius: 0.25, force: .zero, color: .one))
        // 16x8 grid: center (8, 4) cells, radius 0.25 * 8 = 2 cells.
        XCTAssertEqual(s.center(width: 16, height: 8), SIMD2(8, 4))
        XCTAssertEqual(s.radiusCells(width: 16, height: 8), 2)
        XCTAssertEqual(s.weight(cellX: 8, cellY: 4, width: 16, height: 8), 1)
        XCTAssertEqual(s.weight(cellX: 10, cellY: 4, width: 16, height: 8), Float(exp(-1.0)), accuracy: 1e-6)
        XCTAssertEqual(s.weight(cellX: 8, cellY: 6, width: 16, height: 8), Float(exp(-1.0)), accuracy: 1e-6, "aspect-correct: cells are square")
    }

    func testApplyAddsDyeAndForce() throws {
        let s = try XCTUnwrap(Splat(position: SIMD2(0.5, 0.5), radius: 0.2, force: SIMD2(100, -50), color: SIMD4(0.9, 0.2, 0.4, 1)))
        var velocity = FieldGrid(width: 16, height: 16, channels: 4)
        var dye = DyeSeed.uniform(width: 16, height: 16, rgba: SIMD4(0, 0, 0, 1))
        s.apply(velocity: &velocity, dye: &dye, precision: .float32)
        // Cell (7, 7) has its center at (7.5, 7.5): d² = 0.5, r = 3.2 cells.
        let w = Float(exp(-0.5 / (3.2 * 3.2)))
        XCTAssertEqual(dye[7, 7, 0], 0.9 * w, accuracy: 1e-6)
        XCTAssertEqual(dye[7, 7, 3], 1, "alpha unchanged")
        XCTAssertEqual(velocity[7, 7, 0], 100 * w, accuracy: 1e-4)
        XCTAssertEqual(velocity[7, 7, 1], -50 * w, accuracy: 1e-4)
        XCTAssertEqual(velocity[7, 7, 2], 0, "only the first two velocity channels change")
        XCTAssertLessThan(dye[0, 0, 0], 1e-4, "falls off away from the center")
    }

    func testCornerSplatStaysInGrid() throws {
        let s = try XCTUnwrap(Splat(position: SIMD2(0, 0), radius: 0.25, force: SIMD2(500, 500), color: .one))
        var velocity = FieldGrid(width: 8, height: 8, channels: 4)
        var dye = FieldGrid(width: 8, height: 8, channels: 4)
        s.apply(velocity: &velocity, dye: &dye, precision: .float16)
        XCTAssertTrue(velocity.isFinite && dye.isFinite)
        XCTAssertGreaterThan(dye[0, 0, 0], 0.5)
        XCTAssertEqual(dye.values.count, 8 * 8 * 4, "no cell outside the grid exists or is touched")
    }

    func testEncodedVelocityAndUnormClamp() throws {
        let enc = try XCTUnwrap(SignedRangeEncoding(range: 240))
        let s = try XCTUnwrap(Splat(position: SIMD2(0.5, 0.5), radius: 0.25, force: SIMD2(1000, 0), color: SIMD4(3, 3, 3, 1).clamped(lowerBound: .zero, upperBound: .one)))
        var velocity = FieldGrid(width: 8, height: 8, channels: 4, fill: 0.5).rounded(to: .unorm8)
        var dye = DyeSeed.uniform(width: 8, height: 8, rgba: SIMD4(0.8, 0.8, 0.8, 1))
        s.apply(velocity: &velocity, dye: &dye, precision: .unorm8, velocityEncoding: enc)
        XCTAssertEqual(velocity[4, 4, 0], 1, "a force above the storable range is clamped, never wrapped")
        XCTAssertEqual(dye[4, 4, 0], 1, "8-bit dye saturates at 1")
        XCTAssertEqual(enc.decode(velocity[0, 0, 1]), 0, accuracy: 2 * 240 / 255, "zero stays zero")
    }
}
