// KeplerOrbit — feature 104 (A14-P02) T-A14-202 (FR-A14-201, FR-A14-202; SC-A14-202; gap G-ORBIT; research D1).
// An elliptical two-body orbit from classical elements, propagated approximately with Kepler's equation. The mean
// anomaly at a time t is M = M₀ + n·t, normalised to (−π, π]. Kepler's equation E − e·sin E = M is solved by Newton's
// method from E₀ = M for e < 0.8 and from E₀ = π (with the sign of M) otherwise, for at most `maxIterations` steps,
// stopping when the step falls below `tolerance`; the result is always finite. In the orbital plane the position is
// x′ = a(cos E − e), y′ = a·√(1 − e²)·sin E (periapsis along +x′); it is rotated by the argument of periapsis ω about
// the plane's normal, by the inclination i about the line of nodes and by the longitude of the ascending node Ω about
// the reference frame's z axis. The frame is right-handed: x toward the reference direction, y 90° ahead of it in the
// reference plane, z toward the reference plane's north. Units are the caller's: the position is in the unit of the
// semi-major axis and the time in the unit whose reciprocal measures the mean motion. Generic: no body data.
import Foundation

/// An elliptical Kepler orbit (0 ≤ e < 1) described by classical elements.
///
/// Angles are radians; the mean motion is radians per time unit, so ``position(at:)`` takes a time in that unit
/// since the epoch of ``meanAnomalyAtEpoch``. The returned position is in the unit of ``semiMajorAxis``.
public struct KeplerOrbit: Sendable, Equatable {
    /// The most Newton steps taken when solving Kepler's equation.
    public static let maxIterations = 32
    /// The Newton step (radians) below which the solution of Kepler's equation is accepted.
    public static let tolerance = 1e-12

    /// Semi-major axis, positive; the position's length unit.
    public let semiMajorAxis: Double
    /// Eccentricity, 0 ≤ e < 1.
    public let eccentricity: Double
    /// Inclination of the orbital plane to the reference plane, radians.
    public let inclination: Double
    /// Longitude of the ascending node Ω, measured in the reference plane from the reference direction, radians.
    public let ascendingNode: Double
    /// Argument of periapsis ω, measured in the orbital plane from the ascending node, radians.
    public let argumentOfPeriapsis: Double
    /// Mean anomaly M₀ at the epoch (time 0), radians.
    public let meanAnomalyAtEpoch: Double
    /// Mean motion n, positive, radians per time unit.
    public let meanMotion: Double

    /// Creates the orbit, or nil when a value is not finite, the eccentricity lies outside 0 ≤ e < 1, or the
    /// semi-major axis or the mean motion is not positive.
    public init?(semiMajorAxis: Double, eccentricity: Double, inclination: Double, ascendingNode: Double,
                 argumentOfPeriapsis: Double, meanAnomalyAtEpoch: Double, meanMotion: Double) {
        let values = [semiMajorAxis, eccentricity, inclination, ascendingNode, argumentOfPeriapsis,
                      meanAnomalyAtEpoch, meanMotion]
        guard values.allSatisfy(\.isFinite) else { return nil }
        guard eccentricity >= 0, eccentricity < 1, semiMajorAxis > 0, meanMotion > 0 else { return nil }
        self.semiMajorAxis = semiMajorAxis
        self.eccentricity = eccentricity
        self.inclination = inclination
        self.ascendingNode = ascendingNode
        self.argumentOfPeriapsis = argumentOfPeriapsis
        self.meanAnomalyAtEpoch = meanAnomalyAtEpoch
        self.meanMotion = meanMotion
    }

    /// The orbital period, 2π / ``meanMotion``, in the time unit of the mean motion.
    public var period: Double { 2 * Double.pi / meanMotion }

    /// The mean anomaly at `time` since the epoch, normalised to (−π, π]; a non-finite time is treated as the epoch.
    public func meanAnomaly(at time: Double) -> Double {
        let t = time.isFinite ? time : 0
        return Self.normalised(meanAnomalyAtEpoch + meanMotion * t)
    }

    /// The position at `time` since the epoch in the reference frame (x toward the reference direction, z toward the
    /// reference plane's north); a non-finite time is treated as the epoch, so the result is always finite.
    public func position(at time: Double) -> Vec3 {
        let e = eccentricity
        let bigE = Self.eccentricAnomaly(meanAnomaly: meanAnomaly(at: time), eccentricity: e)
        let xp = semiMajorAxis * (cos(bigE) - e)
        let yp = semiMajorAxis * (1 - e * e).squareRoot() * sin(bigE)
        let (sw, cw) = (sin(argumentOfPeriapsis), cos(argumentOfPeriapsis))
        let (si, ci) = (sin(inclination), cos(inclination))
        let (sn, cn) = (sin(ascendingNode), cos(ascendingNode))
        // Rotate by ω in the plane, then i about the node line, then Ω about z.
        let x1 = cw * xp - sw * yp
        let y1 = sw * xp + cw * yp
        let y2 = ci * y1
        let z2 = si * y1
        return Vec3(cn * x1 - sn * y2, sn * x1 + cn * y2, z2)
    }

    /// Solves Kepler's equation E − e·sin E = M for the eccentric anomaly E (radians) by Newton's method (see the
    /// file header). The mean anomaly is normalised to (−π, π] first and E is returned in the same branch; for a
    /// non-finite mean anomaly 0 is returned, and for an eccentricity outside 0 ≤ e < 1 the normalised mean anomaly.
    public static func eccentricAnomaly(meanAnomaly: Double, eccentricity e: Double) -> Double {
        guard meanAnomaly.isFinite else { return 0 }
        guard e.isFinite, e >= 0, e < 1 else { return normalised(meanAnomaly) }
        let m = normalised(meanAnomaly)
        var bigE = e < 0.8 ? m : (m < 0 ? -Double.pi : Double.pi)
        for _ in 0..<maxIterations {
            let f = bigE - e * sin(bigE) - m
            let step = f / (1 - e * cos(bigE))
            bigE -= step
            if abs(step) < tolerance { break }
        }
        return bigE.isFinite ? bigE : m
    }

    /// `angle` reduced to (−π, π].
    static func normalised(_ angle: Double) -> Double {
        var a = angle.truncatingRemainder(dividingBy: 2 * Double.pi)
        if a <= -Double.pi { a += 2 * Double.pi }
        if a > Double.pi { a -= 2 * Double.pi }
        return a
    }
}
