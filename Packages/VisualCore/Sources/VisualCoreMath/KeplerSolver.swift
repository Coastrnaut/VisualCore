// KeplerSolver — feature 215 (R02-F15) T-R02F15-002 (FR-R02F15-001; SC-R02F15-001; research R1–R3). The anomaly
// solvers of the three conic kinds. Elliptic (0 ≤ e < 1): Kepler's equation E − e·sin E = M is solved by
// `KeplerOrbit.eccentricAnomaly` (no duplicate solver) and then polished by at most 8 Newton steps while the residual
// |E − e·sin E − M| exceeds 1e-12, M normalised to (−π, π] as `KeplerOrbit` does. Hyperbolic (e > 1): the equation
// e·sinh H − H = M is solved by Newton's method from H₀ = sign(M)·ln(2|M|/e + 1.8) for at most 64 steps, stopping when
// the step falls below 1e-12·max(1, |H|). Parabolic (|e − 1| ≤ 1e-9): Barker's equation s + s³/3 = n·(t − tₚ) with
// s = tan(ν/2) has the closed form s = y − 1/y, y = ∛(W + √(W² + 1)), W = (3/2)·n·(t − tₚ), polished by one Newton
// step. True anomalies: ν = 2·atan2(√(1 + e)·sin(E/2), √(1 − e)·cos(E/2)) and ν = 2·atan(√((e + 1)/(e − 1))·tanh(H/2)).
// Every function returns a finite value for any input (see each function for its fallback).
import Foundation

/// Solvers of the Kepler, hyperbolic Kepler and Barker equations, and the true anomalies they give.
public enum KeplerSolver {
    /// The band around e = 1 treated as parabolic: an orbit is parabolic when |e − 1| ≤ this value.
    public static let parabolicBand = 1e-9

    /// The most polishing Newton steps after `KeplerOrbit.eccentricAnomaly`.
    static let maxPolishSteps = 8
    /// The residual |E − e·sin E − M| below which no more polishing is done.
    static let polishResidual = 1e-12
    /// The most Newton steps of the hyperbolic solver.
    static let maxHyperbolicSteps = 64

    /// Solves Kepler's equation E − e·sin E = M for the eccentric anomaly E (radians), 0 ≤ e < 1.
    ///
    /// The mean anomaly is normalised to (−π, π] and E is returned in the same branch. A non-finite mean anomaly gives
    /// 0; an eccentricity outside 0 ≤ e < 1 (or not finite) gives the normalised mean anomaly.
    public static func eccentricAnomaly(meanAnomaly: Double, eccentricity e: Double) -> Double {
        guard meanAnomaly.isFinite else { return 0 }
        let m = KeplerOrbit.normalised(meanAnomaly)
        var bigE = KeplerOrbit.eccentricAnomaly(meanAnomaly: m, eccentricity: e)
        guard e.isFinite, e >= 0, e < 1 else { return m }
        for _ in 0..<maxPolishSteps {
            let f = bigE - e * sin(bigE) - m
            if abs(f) <= polishResidual { break }
            let slope = 1 - e * cos(bigE)
            guard slope > 0 else { break }
            let next = bigE - f / slope
            guard next.isFinite else { break }
            bigE = next
        }
        return bigE.isFinite ? bigE : m
    }

    /// Solves the hyperbolic Kepler equation e·sinh H − H = M for the hyperbolic anomaly H, e > 1.
    ///
    /// Newton's method from H₀ = sign(M)·ln(2|M|/e + 1.8), at most 64 steps. A non-finite mean anomaly gives 0; an
    /// eccentricity that is not finite or not above 1 gives the mean anomaly itself; if an iterate stops being finite
    /// (|M| near the largest Double) the finite start H₀ is returned.
    public static func hyperbolicAnomaly(meanAnomaly m: Double, eccentricity e: Double) -> Double {
        guard m.isFinite else { return 0 }
        guard e.isFinite, e > 1 else { return m }
        if m == 0 { return 0 }
        let ratio = abs(m) / e
        // ln(2|M|/e + 1.8) without overflow of 2|M|/e.
        let start = ratio > 1e300 ? log(2.0) + log(ratio) : log(2 * ratio + 1.8)
        let h0 = m < 0 ? -start : start
        var h = h0
        for _ in 0..<maxHyperbolicSteps {
            let f = e * sinh(h) - h - m
            let slope = e * cosh(h) - 1
            let step = f / slope
            let next = h - step
            guard next.isFinite else { return h0 }
            h = next
            if abs(step) < 1e-12 * max(1, abs(h)) { break }
        }
        return h.isFinite ? h : h0
    }

    /// The true anomaly ν (radians, in (−π, π)) of a parabolic orbit from Barker's parameter W = (3/2)·n·(t − tₚ),
    /// n = √(μ/(2q³)): s = tan(ν/2) solves s + s³/3 = (2/3)·W.
    ///
    /// The closed form s = y − 1/y, y = ∛(W + √(W² + 1)) is evaluated for |W| (odd symmetry avoids cancellation for
    /// negative W) and polished by one Newton step. A non-finite W gives 0.
    public static func parabolicTrueAnomaly(barkerParameter w: Double) -> Double {
        guard w.isFinite else { return 0 }
        let aw = abs(w)
        let y = cbrt(aw + hypot(aw, 1))
        var s = y - 1 / y
        let target = 2 * aw / 3
        let f = s + s * s * s / 3 - target
        let polished = s - f / (1 + s * s)
        if polished.isFinite { s = polished }
        let nu = 2 * atan(s)
        guard nu.isFinite else { return 0 }
        return w < 0 ? -nu : nu
    }

    /// The true anomaly ν (radians) of an elliptic orbit from the eccentric anomaly E:
    /// 2·atan2(√(1 + e)·sin(E/2), √(1 − e)·cos(E/2)), in the branch of E for E in (−π, π].
    ///
    /// A non-finite E gives 0; an eccentricity outside 0 ≤ e < 1 (or not finite) gives E itself.
    public static func trueAnomaly(eccentricAnomaly bigE: Double, eccentricity e: Double) -> Double {
        guard bigE.isFinite else { return 0 }
        guard e.isFinite, e >= 0, e < 1 else { return bigE }
        let half = bigE / 2
        let nu = 2 * atan2((1 + e).squareRoot() * sin(half), (1 - e).squareRoot() * cos(half))
        return nu.isFinite ? nu : bigE
    }

    /// The true anomaly ν (radians, inside the asymptotes ±acos(−1/e)) of a hyperbolic orbit from the hyperbolic
    /// anomaly H: 2·atan(√((e + 1)/(e − 1))·tanh(H/2)).
    ///
    /// A non-finite H gives 0; an eccentricity that is not finite or not above 1 gives 0.
    public static func trueAnomaly(hyperbolicAnomaly h: Double, eccentricity e: Double) -> Double {
        guard h.isFinite, e.isFinite, e > 1 else { return 0 }
        let nu = 2 * atan(((e + 1) / (e - 1)).squareRoot() * tanh(h / 2))
        return nu.isFinite ? nu : 0
    }
}
