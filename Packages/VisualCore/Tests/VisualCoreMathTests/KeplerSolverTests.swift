// KeplerSolverTests — feature 215 (R02-F15) T-R02F15-002 (FR-R02F15-001; SC-R02F15-001; research R1–R3).
// 1,000 seeded cases per conic kind meet the residual bound; non-finite input gives finite results; Barker's equation
// has known answers. Test data uses explicit types and plain loops (CI type-check rule).
import Foundation
import Testing
@testable import VisualCoreMath

@Suite struct KeplerSolverTests {
    @Test func ellipticResidualOnSeededCases() {
        var rng = KeplerSolverFixtureRandom(state: 2_015)
        for index in 0..<1_000 {
            let e: Double = rng.unit() * 0.9999
            let m: Double = (rng.unit() * 2 - 1) * Double.pi
            let bigE = KeplerSolver.eccentricAnomaly(meanAnomaly: m, eccentricity: e)
            let residual = abs(bigE - e * sin(bigE) - m)
            #expect(residual <= 1e-10 * max(1, abs(m)), "case \(index) e \(e) M \(m) residual \(residual)")
        }
    }

    @Test func ellipticNormalisesLikeKeplerOrbit() {
        let bigE = KeplerSolver.eccentricAnomaly(meanAnomaly: 1 + 8 * Double.pi, eccentricity: 0.3)
        let reference = KeplerOrbit.eccentricAnomaly(meanAnomaly: 1, eccentricity: 0.3)
        #expect(abs(bigE - reference) < 1e-12)
    }

    @Test func hyperbolicResidualOnSeededCases() {
        var rng = KeplerSolverFixtureRandom(state: 2_015)
        for index in 0..<1_000 {
            let e: Double = 1 + 1e-6 + rng.unit() * 9
            let m: Double = (rng.unit() * 2 - 1) * 100
            let h = KeplerSolver.hyperbolicAnomaly(meanAnomaly: m, eccentricity: e)
            let residual = abs(e * sinh(h) - h - m)
            #expect(residual <= 1e-10 * max(1, abs(m)), "case \(index) e \(e) M \(m) residual \(residual)")
        }
    }

    @Test func parabolicResidualOnSeededCases() {
        var rng = KeplerSolverFixtureRandom(state: 2_015)
        for index in 0..<1_000 {
            let m: Double = (rng.unit() * 2 - 1) * 100
            let nu = KeplerSolver.parabolicTrueAnomaly(barkerParameter: 1.5 * m)
            let s = tan(nu / 2)
            let residual = abs(s + s * s * s / 3 - m)
            #expect(residual <= 1e-10 * max(1, abs(m)), "case \(index) M \(m) residual \(residual)")
        }
    }

    @Test func barkerKnownAnswers() {
        #expect(KeplerSolver.parabolicTrueAnomaly(barkerParameter: 0) == 0)
        // s = 1: 1 + 1/3 = (2/3)·W → W = 2, ν = π/2.
        #expect(abs(KeplerSolver.parabolicTrueAnomaly(barkerParameter: 2) - Double.pi / 2) < 1e-14)
        #expect(abs(KeplerSolver.parabolicTrueAnomaly(barkerParameter: -2) + Double.pi / 2) < 1e-14)
        // s = √3: √3 + √3 = (2/3)·W → W = 3√3, ν = 2π/3.
        let w = 3 * 3.0.squareRoot()
        #expect(abs(KeplerSolver.parabolicTrueAnomaly(barkerParameter: w) - 2 * Double.pi / 3) < 1e-14)
        // Small W: s ≈ (2/3)·W with full relative precision.
        let tiny = KeplerSolver.parabolicTrueAnomaly(barkerParameter: 1.5e-10)
        #expect(abs(tiny - 2e-10) < 1e-24)
        #expect(KeplerSolver.parabolicTrueAnomaly(barkerParameter: 1e300) <= Double.pi, "huge W approaches ν = π")
    }

    @Test func trueAnomaliesMatchGeometry() {
        // Elliptic: cos ν = (cos E − e)/(1 − e·cos E).
        let e = 0.6
        let bigE = 1.1
        let nu = KeplerSolver.trueAnomaly(eccentricAnomaly: bigE, eccentricity: e)
        #expect(abs(cos(nu) - (cos(bigE) - e) / (1 - e * cos(bigE))) < 1e-14)
        #expect(nu > 0)
        #expect(KeplerSolver.trueAnomaly(eccentricAnomaly: 0, eccentricity: 0.9) == 0)
        // Hyperbolic: cos ν = (e − cosh H)/(e·cosh H − 1).
        let eh = 1.8
        let h = -0.7
        let nuh = KeplerSolver.trueAnomaly(hyperbolicAnomaly: h, eccentricity: eh)
        #expect(abs(cos(nuh) - (eh - cosh(h)) / (eh * cosh(h) - 1)) < 1e-14)
        #expect(nuh < 0)
        #expect(abs(KeplerSolver.trueAnomaly(hyperbolicAnomaly: 700, eccentricity: eh)) < acos(-1 / eh) + 1e-12)
    }

    @Test func nonFiniteInputGivesFiniteResult() {
        let specials: [Double] = [.nan, .infinity, -.infinity, .greatestFiniteMagnitude, -.greatestFiniteMagnitude]
        for x in specials {
            #expect(KeplerSolver.eccentricAnomaly(meanAnomaly: x, eccentricity: 0.5).isFinite, "E M \(x)")
            #expect(KeplerSolver.eccentricAnomaly(meanAnomaly: 1, eccentricity: x).isFinite, "E e \(x)")
            #expect(KeplerSolver.hyperbolicAnomaly(meanAnomaly: x, eccentricity: 2).isFinite, "H M \(x)")
            #expect(KeplerSolver.hyperbolicAnomaly(meanAnomaly: 1, eccentricity: x).isFinite, "H e \(x)")
            #expect(KeplerSolver.parabolicTrueAnomaly(barkerParameter: x).isFinite, "W \(x)")
            #expect(KeplerSolver.trueAnomaly(eccentricAnomaly: x, eccentricity: 0.5).isFinite, "ν E \(x)")
            #expect(KeplerSolver.trueAnomaly(eccentricAnomaly: 1, eccentricity: x).isFinite, "ν e \(x)")
            #expect(KeplerSolver.trueAnomaly(hyperbolicAnomaly: x, eccentricity: 2).isFinite, "ν H \(x)")
            #expect(KeplerSolver.trueAnomaly(hyperbolicAnomaly: 1, eccentricity: x).isFinite, "ν He \(x)")
        }
        #expect(KeplerSolver.eccentricAnomaly(meanAnomaly: .nan, eccentricity: 0.5) == 0)
        #expect(KeplerSolver.hyperbolicAnomaly(meanAnomaly: 0, eccentricity: 2) == 0)
    }
}

/// Deterministic SplitMix64 generator for the seeded solver cases.
fileprivate struct KeplerSolverFixtureRandom {
    var state: UInt64
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// A uniform value in [0, 1).
    mutating func unit() -> Double { Double(next() >> 11) / 9_007_199_254_740_992 }
}
