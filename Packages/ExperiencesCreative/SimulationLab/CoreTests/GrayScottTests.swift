// GrayScottTests — feature 117 (A16-P01) T-A16-103 (FR-A16-102; SC-A16-102; clarification Q2). Gray-Scott
// reaction-diffusion, host-free and short: one step on a 4 × 4 grid equals hand-computed values in every cell within
// one storage step (the patch sits on the corner, so the wrap boundary is exercised); values stay finite and within
// 0…1 over many steps and at the extreme settings; the result is already `float16`.
import Testing
import VisualCoreSimulation
@testable import SimulationLabCore

@Suite struct GrayScottTests {
    @Test func oneStepMatchesHandComputedValues() {
        // u = 1, v = 0 everywhere except cell (0, 0): u = 0.5, v = 0.25. F = 0.035, k = 0.065, Δt = 1.
        var grid = FieldGrid(width: 4, height: 4, channels: 2)
        for cell in 0..<16 { grid.values[cell * 2] = 1 }
        grid[0, 0, 0] = 0.5
        grid[0, 0, 1] = 0.25
        let next = GrayScott.step(grid, spec: .standard(.reactionDiffusion, preset: 0))
        // Cell (0, 0): ∇²u = 4 · 1 − 4 · 0.5 = 2, ∇²v = −4 · 0.25 = −1, uv² = 0.5 · 0.0625 = 0.03125;
        //   u′ = 0.5 + 0.16 · 2 − 0.03125 + 0.035 · 0.5 = 0.80625;
        //   v′ = 0.25 + 0.08 · (−1) + 0.03125 − (0.035 + 0.065) · 0.25 = 0.17625.
        // Its four wrapped neighbours (1, 0), (3, 0), (0, 1), (0, 3): ∇²u = 0.5 − 1 = −0.5, ∇²v = 0.25, uv² = 0;
        //   u′ = 1 + 0.16 · (−0.5) = 0.92;  v′ = 0.08 · 0.25 = 0.02.
        // Every other cell: u′ = 1, v′ = 0.
        let tolerance = StoragePrecision.float16.tolerance
        for y in 0..<4 {
            for x in 0..<4 {
                var expectedU: Float = 1, expectedV: Float = 0
                if x == 0 && y == 0 {
                    expectedU = 0.80625; expectedV = 0.17625
                } else if (y == 0 && (x == 1 || x == 3)) || (x == 0 && (y == 1 || y == 3)) {
                    expectedU = 0.92; expectedV = 0.02
                }
                #expect(abs(next[x, y, 0] - expectedU) <= tolerance, "u at \(x), \(y)")
                #expect(abs(next[x, y, 1] - expectedV) <= tolerance, "v at \(x), \(y)")
            }
        }
        #expect(next == next.rounded(to: .float16))
        let exact = GrayScott.step(grid, feed: 0.035, kill: 0.065, timeStep: 1, precision: .float32)
        #expect(abs(exact[0, 0, 0] - 0.80625) < 1e-6 && abs(exact[0, 0, 1] - 0.17625) < 1e-6)
        #expect(abs(exact[3, 0, 0] - 0.92) < 1e-6 && abs(exact[0, 3, 1] - 0.02) < 1e-6)
    }

    @Test func valuesStayFiniteAndWithinTheUnitRange() {
        let presets: [Int] = [0, 1]
        for preset in presets {
            var spec = SimulationSpec.standard(.reactionDiffusion, preset: preset, seed: 9)
            spec.gridSize = 16
            spec.timeStep = 1.5625
            var grid = Seeding.start(for: spec).current
            for _ in 0..<200 { grid = GrayScott.step(grid, spec: spec) }
            #expect(grid.isFinite)
            #expect(grid.values.allSatisfy { $0 >= 0 && $0 <= 1 }, "preset \(preset)")
        }
    }

    @Test func extremeValuesAreClampedIntoTheUnitRange() {
        var grid = FieldGrid(width: 4, height: 4, channels: 2)
        for cell in 0..<16 {
            grid.values[cell * 2] = cell % 2 == 0 ? 1 : 0
            grid.values[cell * 2 + 1] = cell % 3 == 0 ? 1 : 0
        }
        let settings: [(feed: Double, kill: Double)] = [(0, 0), (0.1, 0.1), (0.1, 0), (0, 0.1)]
        for setting in settings {
            var g = grid
            for _ in 0..<10 {
                g = GrayScott.step(g, feed: setting.feed, kill: setting.kill, timeStep: 1.5625)
                #expect(g.isFinite && g.values.allSatisfy { $0 >= 0 && $0 <= 1 })
            }
        }
        var nan = grid
        nan.values[0] = .nan
        #expect(GrayScott.step(nan, feed: 0.035, kill: 0.065, timeStep: 1).isFinite)
        let single = FieldGrid(width: 4, height: 4, channels: 1, fill: 0.5)
        #expect(GrayScott.step(single, feed: 0.035, kill: 0.065, timeStep: 1) == single)
    }
}
