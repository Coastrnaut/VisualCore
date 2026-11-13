// AdvectionTests — feature 020 T-A02-210 (FR-A02-206, FR-A02-207; spec clarifications 1 and 5; research R1, R8).
import FluidArtPlaygroundCore
import VisualCoreSimulation
import XCTest

final class AdvectionTests: XCTestCase {
    private func uniformVelocity(_ w: Int, _ h: Int, _ v: SIMD2<Float>) -> FieldGrid {
        var g = FieldGrid(width: w, height: h, channels: 4)
        for cell in 0..<(w * h) { g.values[cell * 4] = v.x; g.values[cell * 4 + 1] = v.y }
        return g
    }

    /// FR-A02-207: zero velocity and zero dissipation leave a pattern unchanged and bounded for 120 steps.
    func testZeroVelocityKeepsPattern() {
        for size in [8, 16] {
            let start = DyeSeed.pattern(width: size, height: size, seed: 5).rounded(to: .float16)
            var dye = start
            var velocity = FieldGrid(width: size, height: size, channels: 4)
            for _ in 0..<120 {
                Advection.step(velocity: &velocity, dye: &dye, dt: 1.0 / 60, velocityDissipation: 0, dyeDissipation: 0, precision: .float16)
            }
            XCTAssertEqual(dye, start)
            XCTAssertLessThanOrEqual(dye.values.max()!, start.values.max()!)
            XCTAssertGreaterThanOrEqual(dye.minValue, 0)
        }
    }

    /// US2 AC2: half a cell per step to the right moves a column by 2 cells after 4 steps (with bilinear blur).
    func testUniformVelocityShiftsPattern() {
        var dye = FieldGrid(width: 16, height: 4, channels: 4)
        for y in 0..<4 { for c in 0..<4 { dye[4, y, c] = 1 } }
        var velocity = uniformVelocity(16, 4, SIMD2(30, 0))   // 30 cells/s × 1/60 s = 0.5 cell per step
        for _ in 0..<4 {
            Advection.step(velocity: &velocity, dye: &dye, dt: 1.0 / 60, velocityDissipation: 0, dyeDissipation: 0, precision: .float32)
        }
        // The column's center of mass moves from x = 4 to x = 6.
        var mass: Float = 0, moment: Float = 0
        for x in 0..<16 { mass += dye[x, 1, 0]; moment += dye[x, 1, 0] * Float(x) }
        XCTAssertEqual(moment / mass, 6, accuracy: 1e-4)
        XCTAssertEqual(mass, 1, accuracy: 1e-5, "mass is conserved away from the edges")
        XCTAssertLessThan(dye[6, 1, 0], 1, "numerical diffusion spreads the column (documented)")
    }

    /// US2 AC3: a uniform velocity field advects itself unchanged.
    func testUniformVelocityStaysUniform() {
        var velocity = uniformVelocity(8, 8, SIMD2(-45, 20))
        let start = velocity
        var dye = FieldGrid(width: 8, height: 8, channels: 4)
        for _ in 0..<10 {
            Advection.step(velocity: &velocity, dye: &dye, dt: 1.0 / 60, velocityDissipation: 0, dyeDissipation: 0, precision: .float32)
        }
        XCTAssertEqual(velocity, start)
    }

    /// Clamp-to-edge: tracing back outside the grid uses edge values, never undefined data.
    func testBacktraceOutsideClampsToEdge() {
        var dye = FieldGrid(width: 4, height: 4, channels: 4)
        for y in 0..<4 { for c in 0..<4 { dye[0, y, c] = 0.75 } }
        var velocity = uniformVelocity(4, 4, SIMD2(6000, 0))   // traces 100 cells back
        Advection.step(velocity: &velocity, dye: &dye, dt: 1.0 / 60, velocityDissipation: 0, dyeDissipation: 0, precision: .float32)
        for x in 0..<4 { XCTAssertEqual(dye[x, 2, 0], 0.75, "every cell takes the left edge value") }
        XCTAssertTrue(dye.isFinite)
    }

    /// With zero velocity, advection reduces to Phase 01 dissipation, in every storage.
    func testZeroVelocityEqualsDissipation() throws {
        for precision in [StoragePrecision.float16, .float16TowardZero, .unorm8] {
            var a = DyeSeed.pattern(width: 8, height: 8, seed: 2).rounded(to: precision)
            var b = a
            var velocity = FieldGrid(width: 8, height: 8, channels: 4)
            for _ in 0..<30 {
                Advection.step(velocity: &velocity, dye: &a, dt: 1.0 / 60, velocityDissipation: 1, dyeDissipation: 1, precision: precision)
                Dissipation.step(&b, d: 1, dt: 1.0 / 60, precision: precision)
            }
            XCTAssertEqual(a, b, "\(precision)")
        }
    }

    /// RGBA8: encoded velocity is decoded for the backtrace and re-encoded after scaling; zero stays exact.
    func testEncodedVelocity() throws {
        let enc = try XCTUnwrap(SignedRangeEncoding.unorm8(range: 240))
        var velocity = FieldGrid(width: 8, height: 8, channels: 4)
        for cell in 0..<64 { velocity.values[cell * 4] = enc.encode(0); velocity.values[cell * 4 + 1] = enc.encode(0) }
        var dye = DyeSeed.pattern(width: 8, height: 8, seed: 9).rounded(to: .unorm8)
        let start = dye
        for _ in 0..<20 {
            Advection.step(velocity: &velocity, dye: &dye, dt: 1.0 / 60, velocityDissipation: 0.5, dyeDissipation: 0,
                           precision: .unorm8, velocityEncoding: enc)
        }
        XCTAssertEqual(dye, start, "encoded zero velocity moves nothing")
        XCTAssertEqual(enc.decode(velocity[3, 3, 0]), 0)
    }
}
