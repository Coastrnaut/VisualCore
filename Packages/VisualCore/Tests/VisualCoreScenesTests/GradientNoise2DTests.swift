// GradientNoise2DTests — feature 089 (A12-P01) T-A12-102 (FR-A12-101, FR-A12-102; SC-A12-102).
import Testing
@testable import VisualCoreScenes

@Suite struct GradientNoise2DTests {
    /// The 64 × 64 sample of points used for the range checks (spans several lattice cells, both signs).
    static let grid: [(Double, Double)] = (0..<64).flatMap { j in
        (0..<64).map { i in (Double(i) * 0.173 - 5.3, Double(j) * 0.211 - 6.7) }
    }

    @Test func sameSeedAndPointGiveTheSameValue() {
        let a = GradientNoise2D(seed: 42), b = GradientNoise2D(seed: 42)
        #expect(a == b)
        for (x, y) in Self.grid.prefix(200) {
            #expect(a.value(x: x, y: y).bitPattern == b.value(x: x, y: y).bitPattern)
        }
    }

    @Test func valuesStayWithinMinusOneToOne() {
        let noise = GradientNoise2D(seed: 7)
        var low = 0.0, high = 0.0
        for (x, y) in Self.grid {
            let v = noise.value(x: x, y: y)
            #expect(v >= -1 && v <= 1)
            low = min(low, v); high = max(high, v)
        }
        #expect(low < -0.2 && high > 0.2) // not degenerate
    }

    @Test func differentSeedsDiffer() {
        let a = GradientNoise2D(seed: 1), b = GradientNoise2D(seed: 2)
        let differing = Self.grid.filter { a.value(x: $0.0, y: $0.1) != b.value(x: $0.0, y: $0.1) }.count
        #expect(differing > Self.grid.count / 2)
    }

    @Test func zeroAtLatticePoints() {
        let noise = GradientNoise2D(seed: 99)
        for j in -5...5 {
            for i in -5...5 { #expect(noise.value(x: Double(i), y: Double(j)) == 0) }
        }
    }

    @Test func continuousForASmallStep() {
        let noise = GradientNoise2D(seed: 3)
        for (x, y) in Self.grid {
            #expect(abs(noise.value(x: x + 1e-6, y: y) - noise.value(x: x, y: y)) < 1e-4)
            #expect(abs(noise.value(x: x, y: y + 1e-6) - noise.value(x: x, y: y)) < 1e-4)
        }
        // Across a lattice line as well.
        #expect(abs(noise.value(x: 2 - 1e-9, y: 0.5) - noise.value(x: 2, y: 0.5)) < 1e-6)
    }

    @Test func nonFiniteInputGivesZero() {
        let noise = GradientNoise2D(seed: 5)
        #expect(noise.value(x: .nan, y: 0.5) == 0)
        #expect(noise.value(x: 0.5, y: .infinity) == 0)
        #expect(noise.value(x: -.infinity, y: .nan) == 0)
    }

    @Test func fractalRefusesInvalidSettings() {
        #expect(FractalNoise2D(seed: 1, octaves: 0, frequency: 1) == nil)
        #expect(FractalNoise2D(seed: 1, octaves: 9, frequency: 1) == nil)
        #expect(FractalNoise2D(seed: 1, octaves: 4, frequency: 0) == nil)
        #expect(FractalNoise2D(seed: 1, octaves: 4, frequency: -1) == nil)
        #expect(FractalNoise2D(seed: 1, octaves: 4, frequency: .infinity) == nil)
        #expect(FractalNoise2D(seed: 1, octaves: 4, frequency: .nan) == nil)
        #expect(FractalNoise2D(seed: 1, octaves: 4, frequency: 1, lacunarity: 0.5) == nil)
        #expect(FractalNoise2D(seed: 1, octaves: 4, frequency: 1, lacunarity: 5) == nil)
        #expect(FractalNoise2D(seed: 1, octaves: 4, frequency: 1, lacunarity: .nan) == nil)
        #expect(FractalNoise2D(seed: 1, octaves: 4, frequency: 1, gain: -0.1) == nil)
        #expect(FractalNoise2D(seed: 1, octaves: 4, frequency: 1, gain: 1.1) == nil)
        #expect(FractalNoise2D(seed: 1, octaves: 4, frequency: 1, gain: .nan) == nil)
        let edge = FractalNoise2D(seed: 1, octaves: 8, frequency: 0.5, lacunarity: 4, gain: 1)
        #expect(edge?.octaves == 8 && edge?.lacunarity == 4 && edge?.gain == 1)
        #expect(FractalNoise2D(seed: 1, octaves: 1, frequency: 1e-3, lacunarity: 1, gain: 0) != nil)
    }

    @Test func fractalStaysWithinMinusOneToOne() throws {
        let fractal = try #require(FractalNoise2D(seed: 11, octaves: 6, frequency: 0.8, lacunarity: 2.1, gain: 0.55))
        for (x, y) in Self.grid {
            let v = fractal.value(x: x, y: y)
            #expect(v >= -1 && v <= 1)
        }
        #expect(fractal.value(x: .nan, y: 1) == 0)
    }

    @Test func singleOctaveEqualsScaledNoise() throws {
        let fractal = try #require(FractalNoise2D(seed: 8, octaves: 1, frequency: 0.25))
        let noise = GradientNoise2D(seed: 8)
        for (x, y) in Self.grid.prefix(100) {
            #expect(fractal.value(x: x, y: y) == noise.value(x: x * 0.25, y: y * 0.25))
        }
    }

    /// Committed bit patterns: 3 points × 2 seeds for the noise and for a 5-octave fractal (frequency 0.37, defaults).
    @Test func valuesMatchCommittedFixtures() throws {
        let points: [(Double, Double)] = [(0.3, 0.7), (-12.25, 5.5), (101.125, -73.875)]
        let fixtures: [UInt64: (noise: [UInt64], fractal: [UInt64])] = [
            1: ([0x3FD1_61DC_EEDF_4758, 0xBFDB_74FE_00E3_101C, 0x3FD0_65FF_3E98_260F],
                [0x3FD0_17AB_19B9_C375, 0xBFB8_6952_6D58_AC85, 0xBFCA_56BB_5E23_6326]),
            0xDEAD_BEEF: ([0x3FBB_5A53_2A06_DAEC, 0x3FC1_C4E5_2F0E_62DB, 0xBFCE_4420_839F_67C7],
                          [0x3FB8_BBD1_988D_8C9F, 0x3FD7_D4AA_42F8_7007, 0xBFDA_EDB5_DF7A_3A78]),
        ]
        for (seed, expected) in fixtures {
            let noise = GradientNoise2D(seed: seed)
            let fractal = try #require(FractalNoise2D(seed: seed, octaves: 5, frequency: 0.37))
            for (k, (x, y)) in points.enumerated() {
                #expect(noise.value(x: x, y: y).bitPattern == expected.noise[k])
                #expect(fractal.value(x: x, y: y).bitPattern == expected.fractal[k])
            }
        }
    }
}
