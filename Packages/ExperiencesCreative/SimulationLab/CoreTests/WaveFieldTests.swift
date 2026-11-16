// WaveFieldTests — feature 117 (A16-P01) T-A16-103 (FR-A16-103; SC-A16-103; clarification Q3). The leapfrog wave,
// host-free and short: a centred pulse at C = 0.5 stays mirror-symmetric for 100 steps and is zero on the border; with
// γ = 0 in float32 the discrete energy Σ(uⁿ⁺¹ − uⁿ)² + C² Σ_pairs (uⁿ⁺¹ᵢ − uⁿ⁺¹ⱼ)(uⁿᵢ − uⁿⱼ) stays within 10⁻³ of its
// start; with γ > 0 the damped energy (1 − γ)E + γΣ(uⁿ⁺¹)² never increases (it falls by 1 − γ per step; the undamped
// form alone oscillates under damping, see WaveField.swift). The Courant limit is refused just above.
import Testing
import VisualCoreSimulation
@testable import SimulationLabCore

@Suite struct WaveFieldTests {
    /// The largest difference between `grid` and its mirror images in x and in y.
    private func asymmetry(_ grid: FieldGrid) -> Float {
        var worst: Float = 0
        let n = grid.width
        for y in 0..<n {
            for x in 0..<n {
                worst = max(worst, abs(grid[x, y, 0] - grid[n - 1 - x, y, 0]), abs(grid[x, y, 0] - grid[x, n - 1 - y, 0]))
            }
        }
        return worst
    }

    /// The largest absolute value on the border of `grid`.
    private func borderMagnitude(_ grid: FieldGrid) -> Float {
        var worst: Float = 0
        let n = grid.width
        for i in 0..<n {
            worst = max(worst, abs(grid[i, 0, 0]), abs(grid[i, n - 1, 0]), abs(grid[0, i, 0]), abs(grid[n - 1, i, 0]))
        }
        return worst
    }

    @Test func aCentredPulseStaysSymmetricAndZeroOnTheBorder() {
        let precisions: [StoragePrecision] = [.float32, .float16]
        for precision in precisions {
            var current = Seeding.centredPulse(gridSize: 32, precision: precision)
            var previous = current
            for _ in 0..<100 {
                let next = WaveField.step(current: current, previous: previous, courant: 0.5, damping: 0,
                                          precision: precision)
                previous = current
                current = next
                #expect(asymmetry(current) == 0 && borderMagnitude(current) == 0)
            }
            #expect(current.isFinite && current != previous)
        }
    }

    @Test func theUndampedEnergyIsConservedInFloat32() {
        var current = Seeding.centredPulse(gridSize: 32, precision: .float32)
        var previous = current
        let start = WaveField.energy(current: current, previous: previous, courant: 0.5)
        #expect(start > 0)
        var worst = 0.0
        for _ in 0..<100 {
            let next = WaveField.step(current: current, previous: previous, courant: 0.5, damping: 0, precision: .float32)
            previous = current
            current = next
            let e = WaveField.energy(current: current, previous: previous, courant: 0.5)
            worst = max(worst, abs(e - start) / start)
        }
        #expect(worst < 1e-3)
    }

    @Test func theDampedEnergyNeverIncreases() {
        let dampings: [Double] = [0.002, 0.05]
        for gamma in dampings {
            var current = Seeding.centredPulse(gridSize: 32, precision: .float32)
            var previous = current
            let start = WaveField.energy(current: current, previous: previous, courant: 0.5, damping: gamma)
            var last = start
            for _ in 0..<100 {
                let next = WaveField.step(current: current, previous: previous, courant: 0.5, damping: gamma,
                                          precision: .float32)
                previous = current
                current = next
                let e = WaveField.energy(current: current, previous: previous, courant: 0.5, damping: gamma)
                #expect(e <= last, "γ \(gamma)")
                #expect(abs(e / last - (1 - gamma)) < 1e-4, "γ \(gamma)")
                last = e
            }
            #expect(last < start && last > 0)
        }
        let a = Seeding.centredPulse(gridSize: 16, precision: .float32)
        #expect(WaveField.energy(current: a, previous: a, courant: 0.5, damping: 0)
                == WaveField.energy(current: a, previous: a, courant: 0.5))
    }

    @Test func theSpecStepUsesItsCourantNumberAndDamping() {
        var spec = SimulationSpec.standard(.wave)
        spec.gridSize = 16
        let start = Seeding.centredPulse(gridSize: 16)
        let viaSpec = WaveField.step(current: start, previous: start, spec: spec)
        let direct = WaveField.step(current: start, previous: start, courant: 0.5, damping: 0.002)
        #expect(viaSpec == direct && viaSpec == viaSpec.rounded(to: .float16))
        let small = FieldGrid(width: 8, height: 8, channels: 1)
        #expect(WaveField.step(current: start, previous: small, spec: spec) == start)
        #expect(WaveField.energy(current: start, previous: small, courant: 0.5).isNaN)
    }

    @Test func aCourantNumberJustAboveTheLimitIsRefused() {
        var spec = SimulationSpec.standard(.wave)
        spec.timeStep = 0.7071 * 1.01
        #expect(spec.refusal() == .courant)
        spec.timeStep = 0.7071
        #expect(spec.refusal() == nil)
        #expect(abs(SimulationSpec.courantLimit - 0.70710678) < 1e-8)
    }
}
