// FluidSolverTests — feature 021 T-A02-304 (FR-A02-301–FR-A02-304; SC-A02-302, SC-A02-303; clarifications 1–5).
import FluidArtPlaygroundCore
import VisualCoreSimulation
import XCTest

final class FluidSolverTests: XCTestCase {
    private func field(_ w: Int, _ h: Int, _ f: (Int, Int) -> SIMD2<Float>) -> FieldGrid {
        var g = FieldGrid(width: w, height: h, channels: 4)
        for y in 0..<h { for x in 0..<w { let v = f(x, y); g[x, y, 0] = v.x; g[x, y, 1] = v.y } }
        return g
    }

    private func interiorDivergence(_ v: FieldGrid, _ mode: BoundaryMode) -> Float {
        var log = FluidSolver.AccessLog()
        let d = FluidSolver.divergence(velocity: v, mode: mode, precision: .float32, encodings: .none, log: &log)
        var sum: Float = 0
        for y in 1..<(v.height - 1) { for x in 1..<(v.width - 1) { sum += abs(d[x, y, 0]) } }
        return sum
    }

    func testDivergenceOfARamp() {
        let v = field(6, 4) { x, _ in SIMD2(Float(x), 0) }
        var log = FluidSolver.AccessLog()
        let d = FluidSolver.divergence(velocity: v, mode: .open, precision: .float32, encodings: .none, log: &log)
        XCTAssertEqual(d[2, 1, 0], 1, "interior: 0.5·((x+1) − (x−1))")
        XCTAssertEqual(d[0, 1, 0], 0.5, "open edge: the outside neighbor repeats the center")
        let walls = FluidSolver.divergence(velocity: v, mode: .walls, precision: .float32, encodings: .none, log: &log)
        XCTAssertEqual(walls[5, 1, 0], 0.5 * (-5 - 4), "walls: the outside neighbor has its normal component negated")
        XCTAssertEqual(log.outOfGrid, 0)
    }

    func testJacobiPointSource() {
        var d = FieldGrid(width: 9, height: 9, channels: 4)
        d[4, 4, 0] = 1
        var log = FluidSolver.AccessLog()
        let p = FluidSolver.jacobiPressure(divergence: d, iterations: 20, precision: .float32, encodings: .none, log: &log)
        XCTAssertLessThan(p[4, 4, 0], 0, "a source gives a pressure well")
        XCTAssertEqual(p[3, 4, 0], p[5, 4, 0], accuracy: 1e-6)
        XCTAssertEqual(p[4, 3, 0], p[4, 5, 0], accuracy: 1e-6)
        XCTAssertGreaterThan(p[3, 4, 0], p[4, 4, 0])
    }

    /// SC-A02-302 (clarification 6): projection removes at least 40% of the divergence at the default 20 iterations
    /// (measured 45.6%) and strictly improves with more iterations.
    func testProjectionReducesDivergenceMonotonically() throws {
        var v = FieldGrid(width: 16, height: 16, channels: 4)
        var dye = FieldGrid(width: 16, height: 16, channels: 4)
        try XCTUnwrap(Splat(position: SIMD2(0.5, 0.5), radius: 0.2, force: SIMD2(300, 120), color: .one))
            .apply(velocity: &v, dye: &dye, precision: .float32)
        let before = interiorDivergence(v, .walls)
        var previous = Float.infinity
        for iterations in [5, 10, 20, 40] {
            var log = FluidSolver.AccessLog()
            let projected = FluidSolver.project(velocity: v, iterations: iterations, mode: .walls, precision: .float32,
                                                encodings: .none, log: &log)
            let after = interiorDivergence(projected, .walls)
            XCTAssertLessThan(after, previous, "\(iterations) iterations")
            if iterations == 20 { XCTAssertLessThanOrEqual(after, before * 0.6, "≥ 40% reduction at 20 iterations") }
            previous = after
            print("projection \(iterations) iterations: interior |div| \(before) -> \(after)")
        }
    }

    func testDivergenceFreeFieldIsUnchangedWithOpenEdges() {
        let v = field(8, 8) { _, _ in SIMD2(37, -12) }
        var log = FluidSolver.AccessLog()
        let projected = FluidSolver.project(velocity: v, iterations: 20, mode: .open, precision: .float32, encodings: .none, log: &log)
        XCTAssertEqual(projected, v)
    }

    func testWallsStopFlowThroughTheEdges() {
        let v = field(8, 8) { _, _ in SIMD2(-40, 25) }
        var log = FluidSolver.AccessLog()
        let projected = FluidSolver.project(velocity: v, iterations: 20, mode: .walls, precision: .float32, encodings: .none, log: &log)
        for y in 0..<8 {
            XCTAssertEqual(projected[0, y, 0], 0)
            XCTAssertEqual(projected[7, y, 0], 0)
        }
        for x in 0..<8 {
            XCTAssertEqual(projected[x, 0, 1], 0)
            XCTAssertEqual(projected[x, 7, 1], 0)
        }
        let open = FluidSolver.project(velocity: v, iterations: 20, mode: .open, precision: .float32, encodings: .none, log: &log)
        XCTAssertEqual(open[0, 3, 0], -40, "open edges keep the outward flow")
    }

    /// SC-A02-303: no read ever leaves the grid, in either mode, on the smallest grid.
    func testNoOutOfGridReads() throws {
        for mode in BoundaryMode.allCases {
            var c = FluidConfiguration()
            c.gridWidth = 8
            c.gridHeight = 8
            c.boundaryMode = mode
            c.viscosity = 0.5
            c = c.validated().0
            var v = FieldGrid(width: 8, height: 8, channels: 4)
            var dye = DyeSeed.pattern(width: 8, height: 8, seed: 1)
            let splat = try XCTUnwrap(Splat(position: SIMD2(0, 1), radius: 0.25, force: SIMD2(-500, 500), color: .one))
            var log = FluidSolver.AccessLog()
            FluidSolver.step(velocity: &v, dye: &dye, splats: [splat], configuration: c, pressureIterations: 20,
                             dt: 1.0 / 60, precision: .float16, encodings: .none, log: &log)
            XCTAssertGreaterThan(log.reads, 1000)
            XCTAssertEqual(log.outOfGrid, 0, "\(mode)")
            XCTAssertTrue(v.isFinite && dye.isFinite)
        }
    }

    func testViscosity() {
        let v = field(8, 8) { x, _ in SIMD2(x == 4 ? 100 : 0, 0) }
        var log = FluidSolver.AccessLog()
        XCTAssertEqual(FluidSolver.diffuse(velocity: v, viscosity: 0, dt: 1.0 / 60, mode: .walls, precision: .float32,
                                           encodings: .none, log: &log), v, "viscosity 0 is skipped")
        let blurred = FluidSolver.diffuse(velocity: v, viscosity: 1, dt: 1.0 / 60, mode: .walls, precision: .float32,
                                          encodings: .none, log: &log)
        XCTAssertLessThan(blurred[4, 3, 0], 100)
        XCTAssertGreaterThan(blurred[3, 3, 0], 0, "momentum spreads to neighbors")
    }

    /// With no splats and zero velocity the full step reduces to Phase 02's advection (and Phase 01's dissipation).
    func testStepMatchesAdvectionAtRest() {
        var c = FluidConfiguration()
        c.gridWidth = 8
        c.gridHeight = 8
        c = c.validated().0
        for precision in [StoragePrecision.float16, .float16TowardZero] {
            var v1 = FieldGrid(width: 8, height: 8, channels: 4), v2 = v1
            var d1 = DyeSeed.pattern(width: 8, height: 8, seed: 4).rounded(to: precision), d2 = d1
            var log = FluidSolver.AccessLog()
            FluidSolver.step(velocity: &v1, dye: &d1, splats: [], configuration: c, pressureIterations: 20, dt: 1.0 / 60,
                             precision: precision, encodings: .none, log: &log)
            Advection.step(velocity: &v2, dye: &d2, dt: 1.0 / 60, velocityDissipation: c.velocityDissipation,
                           dyeDissipation: c.dyeDissipation, precision: precision)
            XCTAssertEqual(d1, d2)
            XCTAssertEqual(v1, v2)
        }
    }

    /// 8-bit storage: the scalar fields use their own ranges and zero stays exact.
    func testEncodingsForUnorm8() throws {
        let e = try XCTUnwrap(FluidEncodings.unorm8(velocityRange: 240))
        XCTAssertEqual(e.velocity?.range, 240)
        XCTAssertEqual(e.divergence?.range, 480)
        XCTAssertEqual(e.pressure?.range, 960)
        var v = FieldGrid(width: 8, height: 8, channels: 4)
        for i in 0..<64 { v.values[i * 4] = e.velocity!.encode(0); v.values[i * 4 + 1] = e.velocity!.encode(0) }
        var log = FluidSolver.AccessLog()
        let projected = FluidSolver.project(velocity: v, iterations: 10, mode: .walls, precision: .unorm8, encodings: e, log: &log)
        XCTAssertEqual(projected, v, "an encoded field at rest stays exactly at rest")
    }
}
