// ConicOrbit — feature 215 (R02-F15) T-R02F15-003, T-R02F15-006 (FR-R02F15-001 … FR-R02F15-003, FR-R02F15-007;
// SC-R02F15-001, SC-R02F15-002, SC-R02F15-006; clarifications Q1, Q2, Q5; research R1–R4). A two-body orbit of any
// conic kind from periapsis distance q, eccentricity e, the angles i, Ω, ω of `KeplerOrbit`'s frame, time of periapsis
// tₚ and gravitational parameter μ. The kind is parabolic when |e − 1| ≤ `KeplerSolver.parabolicBand`, elliptic below
// and hyperbolic above. Mean motion n = √(μ/|a|³) with a = q/(1 − e) (negative for the hyperbola), and n = √(μ/(2q³))
// for the parabola; the mean anomaly is M = n·(t − tₚ). The true anomaly ν comes from `KeplerSolver` (Barker's
// parameter W = (3/2)·n·(t − tₚ) for the parabola). With the semi-latus rectum p = q(1 + e) (2q for the parabola) the
// radius is r = p/(1 + e·cos ν) (evaluated as a(1 − e·cos E), |a|(e·cosh H − 1) or q(1 + tan²(ν/2)) for accuracy),
// the perifocal position r(cos ν, sin ν) and velocity √(μ/p)(−sin ν, e + cos ν); both are rotated by ω, i and Ω
// exactly as `KeplerOrbit.position(at:)`. Invariants: specific energy −μ/(2a) (0 for the parabola) and specific
// angular momentum √(μ·p). Stored as JSON schema 1 with sorted keys.
import Foundation

/// The kind of a conic orbit, from its eccentricity.
public enum ConicKind: String, Sendable, Codable, CaseIterable {
    /// 0 ≤ e < 1 − ``KeplerSolver/parabolicBand``: a closed ellipse (a circle for e = 0).
    case elliptic
    /// |e − 1| ≤ ``KeplerSolver/parabolicBand``: an open parabola.
    case parabolic
    /// e > 1 + ``KeplerSolver/parabolicBand``: an open hyperbola branch.
    case hyperbolic
}

/// The state of a body on a conic orbit at one time.
public struct OrbitState: Sendable, Equatable {
    /// The position in the reference frame, in the unit of the periapsis distance.
    public let position: Vec3
    /// The velocity in the reference frame, in position units per time unit.
    public let velocity: Vec3
    /// The true anomaly ν, radians, measured in the orbital plane from periapsis.
    public let trueAnomaly: Double
    /// The distance from the focus, the length of ``position``.
    public var radius: Double { position.length }
}

/// A two-body orbit of any conic kind (ellipse, parabola, hyperbola) given by periapsis elements.
///
/// Angles are radians in the frame of ``KeplerOrbit``; times are in the caller's unit, the gravitational parameter in
/// length³ per time². ``state(at:)`` is finite for every time; a non-finite time is treated as ``timeOfPeriapsis``.
public struct ConicOrbit: Sendable, Equatable, Codable {
    /// The stored JSON schema written by ``encoded()``; ``decode(_:)`` refuses a newer one.
    public static let schema = 1

    /// Periapsis distance q, positive.
    public let periapsisDistance: Double
    /// Eccentricity e, 0 or more.
    public let eccentricity: Double
    /// Inclination i of the orbital plane to the reference plane, radians.
    public let inclination: Double
    /// Longitude of the ascending node Ω, radians.
    public let ascendingNode: Double
    /// Argument of periapsis ω, radians.
    public let argumentOfPeriapsis: Double
    /// Time of periapsis passage tₚ.
    public let timeOfPeriapsis: Double
    /// Gravitational parameter μ = G·M, positive.
    public let gravitationalParameter: Double

    /// Creates the orbit, or throws ``OrbitError/invalidElements(_:)`` naming the first element that is not finite,
    /// or when q ≤ 0, e < 0 or μ ≤ 0.
    public init(periapsisDistance: Double, eccentricity: Double, inclination: Double, ascendingNode: Double,
                argumentOfPeriapsis: Double, timeOfPeriapsis: Double,
                gravitationalParameter: Double) throws(OrbitError) {
        let named: [(String, Double)] = [
            ("periapsisDistance", periapsisDistance), ("eccentricity", eccentricity), ("inclination", inclination),
            ("ascendingNode", ascendingNode), ("argumentOfPeriapsis", argumentOfPeriapsis),
            ("timeOfPeriapsis", timeOfPeriapsis), ("gravitationalParameter", gravitationalParameter),
        ]
        for (name, value) in named where !value.isFinite { throw .invalidElements(name) }
        guard periapsisDistance > 0 else { throw .invalidElements("periapsisDistance") }
        guard eccentricity >= 0 else { throw .invalidElements("eccentricity") }
        guard gravitationalParameter > 0 else { throw .invalidElements("gravitationalParameter") }
        self.periapsisDistance = periapsisDistance
        self.eccentricity = eccentricity
        self.inclination = inclination
        self.ascendingNode = ascendingNode
        self.argumentOfPeriapsis = argumentOfPeriapsis
        self.timeOfPeriapsis = timeOfPeriapsis
        self.gravitationalParameter = gravitationalParameter
    }

    /// Creates the conic orbit of an elliptical ``KeplerOrbit`` under the gravitational parameter μ: q = a(1 − e),
    /// tₚ = −M₀/n, the same angles.
    ///
    /// A ``KeplerOrbit`` carries its own mean motion n, while a conic orbit derives n = √(μ/a³). The two agree only
    /// when μ = n²·a³, so this throws ``OrbitError/invalidElements(_:)`` with `"gravitationalParameter"` when μ is
    /// not finite and positive or |√(μ/a³) − n| > 1e-12·n.
    public init(_ orbit: KeplerOrbit, gravitationalParameter mu: Double) throws(OrbitError) {
        guard mu.isFinite, mu > 0 else { throw .invalidElements("gravitationalParameter") }
        let a = orbit.semiMajorAxis
        let n = orbit.meanMotion
        let derived = (mu / a).squareRoot() / a
        guard derived.isFinite, abs(derived - n) <= 1e-12 * n else { throw .invalidElements("gravitationalParameter") }
        try self.init(periapsisDistance: a * (1 - orbit.eccentricity), eccentricity: orbit.eccentricity,
                      inclination: orbit.inclination, ascendingNode: orbit.ascendingNode,
                      argumentOfPeriapsis: orbit.argumentOfPeriapsis,
                      timeOfPeriapsis: -orbit.meanAnomalyAtEpoch / n, gravitationalParameter: mu)
    }

    // MARK: Derived elements

    /// The conic kind: parabolic when |e − 1| ≤ ``KeplerSolver/parabolicBand``.
    public var kind: ConicKind {
        if abs(eccentricity - 1) <= KeplerSolver.parabolicBand { return .parabolic }
        return eccentricity < 1 ? .elliptic : .hyperbolic
    }

    /// The mean motion n, radians per time unit: √(μ/|a|³), or √(μ/(2q³)) for the parabola.
    public var meanMotion: Double {
        let mu = gravitationalParameter
        guard let a = semiMajorAxis else {
            let q = periapsisDistance
            return (mu / (2 * q)).squareRoot() / q
        }
        let size = abs(a)
        return (mu / size).squareRoot() / size
    }

    /// The semi-major axis a = q/(1 − e): positive for the ellipse, negative for the hyperbola, nil for the parabola.
    public var semiMajorAxis: Double? {
        kind == .parabolic ? nil : periapsisDistance / (1 - eccentricity)
    }

    /// The period 2π/n of a closed (elliptic) orbit; nil for the parabola and the hyperbola.
    public var period: Double? {
        kind == .elliptic ? 2 * Double.pi / meanMotion : nil
    }

    /// The semi-latus rectum p = q(1 + e), 2q for the parabola.
    var semiLatusRectum: Double {
        kind == .parabolic ? 2 * periapsisDistance : periapsisDistance * (1 + eccentricity)
    }

    /// The specific orbital energy v²/2 − μ/r = −μ/(2a); 0 for the parabola.
    public var specificEnergy: Double {
        guard let a = semiMajorAxis else { return 0 }
        return -gravitationalParameter / (2 * a)
    }

    /// The specific angular momentum |r × v| = √(μ·p).
    public var specificAngularMomentum: Double {
        (gravitationalParameter * semiLatusRectum).squareRoot()
    }

    /// The same orbit as a ``KeplerOrbit`` (a, e, i, Ω, ω, M₀ = −n·tₚ, n) when it is elliptic; nil otherwise.
    public var keplerOrbit: KeplerOrbit? {
        guard kind == .elliptic, let a = semiMajorAxis else { return nil }
        let n = meanMotion
        return KeplerOrbit(semiMajorAxis: a, eccentricity: eccentricity, inclination: inclination,
                           ascendingNode: ascendingNode, argumentOfPeriapsis: argumentOfPeriapsis,
                           meanAnomalyAtEpoch: -n * timeOfPeriapsis, meanMotion: n)
    }

    // MARK: Propagation

    /// The state at `time`; a non-finite time is treated as ``timeOfPeriapsis``. If an intermediate value overflows
    /// (extreme elements or times) the periapsis state is returned, so the result is always finite.
    public func state(at time: Double) -> OrbitState {
        let dt = time.isFinite ? time - timeOfPeriapsis : 0
        if let state = propagated(dt: dt.isFinite ? dt : 0) { return state }
        return propagated(dt: 0) ?? OrbitState(position: .zero, velocity: .zero, trueAnomaly: 0)
    }

    /// The position at `time`, ``state(at:)``'s position.
    public func position(at time: Double) -> Vec3 { state(at: time).position }

    /// The state `dt` after periapsis, or nil when a component is not finite.
    private func propagated(dt: Double) -> OrbitState? {
        let e = eccentricity
        let q = periapsisDistance
        let n = meanMotion
        let nu: Double
        let r: Double
        switch kind {
        case .elliptic:
            let a = q / (1 - e)
            let bigE = KeplerSolver.eccentricAnomaly(meanAnomaly: n * dt, eccentricity: e)
            nu = KeplerSolver.trueAnomaly(eccentricAnomaly: bigE, eccentricity: e)
            r = a * (1 - e * cos(bigE))
        case .hyperbolic:
            let size = q / (e - 1)
            let h = KeplerSolver.hyperbolicAnomaly(meanAnomaly: n * dt, eccentricity: e)
            nu = KeplerSolver.trueAnomaly(hyperbolicAnomaly: h, eccentricity: e)
            r = size * (e * cosh(h) - 1)
        case .parabolic:
            nu = KeplerSolver.parabolicTrueAnomaly(barkerParameter: 1.5 * n * dt)
            let s = tan(nu / 2)
            r = q * (1 + s * s)
        }
        let (sv, cv) = (sin(nu), cos(nu))
        let speed = (gravitationalParameter / semiLatusRectum).squareRoot()
        let position = rotated(r * cv, r * sv)
        let velocity = rotated(-speed * sv, speed * (e + cv))
        let values = [position.x, position.y, position.z, velocity.x, velocity.y, velocity.z, nu]
        guard values.allSatisfy(\.isFinite) else { return nil }
        return OrbitState(position: position, velocity: velocity, trueAnomaly: nu)
    }

    /// Rotates the perifocal vector (xp, yp, 0) by ω, i and Ω as ``KeplerOrbit/position(at:)`` does.
    private func rotated(_ xp: Double, _ yp: Double) -> Vec3 {
        let (sw, cw) = (sin(argumentOfPeriapsis), cos(argumentOfPeriapsis))
        let (si, ci) = (sin(inclination), cos(inclination))
        let (sn, cn) = (sin(ascendingNode), cos(ascendingNode))
        let x1 = cw * xp - sw * yp
        let y1 = sw * xp + cw * yp
        let y2 = ci * y1
        let z2 = si * y1
        return Vec3(cn * x1 - sn * y2, sn * x1 + cn * y2, z2)
    }

    // MARK: Stored form (schema 1)

    /// The JSON keys of the stored form.
    private enum CodingKeys: String, CodingKey {
        case schema, periapsisDistance, eccentricity, inclination, ascendingNode, argumentOfPeriapsis,
             timeOfPeriapsis, gravitationalParameter
    }

    /// Decodes a schema-1 orbit. Throws ``OrbitError/newerSchema(_:)`` for a schema above ``schema``,
    /// ``OrbitError/malformed(_:)`` for a missing or mistyped key or a schema below 1, and
    /// ``OrbitError/invalidElements(_:)`` for values the initialiser refuses.
    public init(from decoder: any Decoder) throws {
        let values: [Double]
        do {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let stored = try container.decode(Int.self, forKey: .schema)
            if stored > Self.schema { throw OrbitError.newerSchema(stored) }
            if stored < 1 { throw OrbitError.malformed("schema \(stored)") }
            let keys: [CodingKeys] = [.periapsisDistance, .eccentricity, .inclination, .ascendingNode,
                                      .argumentOfPeriapsis, .timeOfPeriapsis, .gravitationalParameter]
            var read: [Double] = []
            for key in keys { read.append(try container.decode(Double.self, forKey: key)) }
            values = read
        } catch let error as OrbitError {
            throw error
        } catch {
            throw OrbitError.malformed(String(describing: error))
        }
        try self.init(periapsisDistance: values[0], eccentricity: values[1], inclination: values[2],
                      ascendingNode: values[3], argumentOfPeriapsis: values[4], timeOfPeriapsis: values[5],
                      gravitationalParameter: values[6])
    }

    /// Encodes the schema-1 stored form: `schema` and the seven elements.
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(Self.schema, forKey: .schema)
        try container.encode(periapsisDistance, forKey: .periapsisDistance)
        try container.encode(eccentricity, forKey: .eccentricity)
        try container.encode(inclination, forKey: .inclination)
        try container.encode(ascendingNode, forKey: .ascendingNode)
        try container.encode(argumentOfPeriapsis, forKey: .argumentOfPeriapsis)
        try container.encode(timeOfPeriapsis, forKey: .timeOfPeriapsis)
        try container.encode(gravitationalParameter, forKey: .gravitationalParameter)
    }

    /// The stored JSON with sorted keys; byte-identical for equal orbits. (The elements are finite by construction,
    /// so encoding cannot fail.)
    public func encoded() -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return (try? encoder.encode(self)) ?? Data()
    }

    /// Decodes stored JSON: ``OrbitError/newerSchema(_:)`` for a newer schema, ``OrbitError/malformed(_:)`` for
    /// damaged or incomplete JSON, ``OrbitError/invalidElements(_:)`` for refused values.
    public static func decode(_ data: Data) throws(OrbitError) -> ConicOrbit {
        do {
            return try JSONDecoder().decode(ConicOrbit.self, from: data)
        } catch let error as OrbitError {
            throw error
        } catch {
            throw .malformed(String(describing: error))
        }
    }
}
