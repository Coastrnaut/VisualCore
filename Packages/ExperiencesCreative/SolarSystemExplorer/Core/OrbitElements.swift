// OrbitElements — feature 104 (A14-P02) T-A14-204 (FR-A14-210; clarification Q2; research D2; data-model
// "OrbitElements"; SC-A14-201). The mean J2000.0 orbital elements of the eight major planets from E. M. Standish,
// "Keplerian Elements for Approximate Positions of the Major Planets" (JPL Solar System Dynamics, Table 1, valid
// 1800–2050): semi-major axis a (AU), eccentricity e, inclination i, mean longitude L, longitude of perihelion ϖ and
// longitude of the ascending node Ω (degrees, to the ecliptic and equinox of J2000.0). The values are exactly those of
// spec clarification Q2; Standish's "Earth" row is the Earth–Moon barycentre. The secular rates of the table are not
// used: the mean motion comes from the catalog's sidereal period, so the catalog and the orbits agree on periods.
//
// `kepler(periodDays:)` converts to the classical elements of `VisualCoreMath.KeplerOrbit`: argument of perihelion
// ω = ϖ − Ω, mean anomaly at the epoch M₀ = L − ϖ (both normalised to 0…360° first, so a negative mean longitude, as
// stored for Mars and Neptune, gives the same orbit as the value + 360°), angles in radians and mean motion
// n = 2π / period in radians per day. The validation is "e in [0, 1); a > 0; every value finite", with ids unique and
// exactly the catalog's planets.
import Foundation
import VisualCoreMath

/// The mean J2000.0 Keplerian elements of one planet (Standish, JPL SSD, Table 1).
public struct OrbitElements: Codable, Equatable, Sendable {
    /// The epoch of every bundled element set.
    public static let j2000Epoch = "J2000.0"

    /// The catalog id of the planet (`mercury` … `neptune`).
    public let bodyID: String
    /// The semi-major axis a in AU.
    public let semiMajorAxisAU: Double
    /// The eccentricity e (0 ≤ e < 1).
    public let eccentricity: Double
    /// The inclination i to the ecliptic in degrees.
    public let inclinationDeg: Double
    /// The mean longitude L at the epoch in degrees (may be negative, as stored by the source).
    public let meanLongitudeDeg: Double
    /// The longitude of perihelion ϖ in degrees (may be negative, as stored by the source).
    public let perihelionLongitudeDeg: Double
    /// The longitude of the ascending node Ω in degrees.
    public let ascendingNodeDeg: Double
    /// The epoch of the elements ("J2000.0").
    public let epoch: String

    /// Creates an element set from all of its fields (no validation; ``problems`` validates).
    public init(bodyID: String, semiMajorAxisAU: Double, eccentricity: Double, inclinationDeg: Double,
                meanLongitudeDeg: Double, perihelionLongitudeDeg: Double, ascendingNodeDeg: Double,
                epoch: String = OrbitElements.j2000Epoch) {
        self.bodyID = bodyID; self.semiMajorAxisAU = semiMajorAxisAU; self.eccentricity = eccentricity
        self.inclinationDeg = inclinationDeg; self.meanLongitudeDeg = meanLongitudeDeg
        self.perihelionLongitudeDeg = perihelionLongitudeDeg; self.ascendingNodeDeg = ascendingNodeDeg
        self.epoch = epoch
    }

    /// The eight planets' elements, exactly as in spec clarification Q2, in catalog order.
    public static let bundled: [OrbitElements] = [
        OrbitElements(bodyID: "mercury", semiMajorAxisAU: 0.38709927, eccentricity: 0.20563593,
                      inclinationDeg: 7.00497902, meanLongitudeDeg: 252.25032350,
                      perihelionLongitudeDeg: 77.45779628, ascendingNodeDeg: 48.33076593),
        OrbitElements(bodyID: "venus", semiMajorAxisAU: 0.72333566, eccentricity: 0.00677672,
                      inclinationDeg: 3.39467605, meanLongitudeDeg: 181.97909950,
                      perihelionLongitudeDeg: 131.60246718, ascendingNodeDeg: 76.67984255),
        OrbitElements(bodyID: "earth", semiMajorAxisAU: 1.00000261, eccentricity: 0.01671123,
                      inclinationDeg: -0.00001531, meanLongitudeDeg: 100.46457166,
                      perihelionLongitudeDeg: 102.93768193, ascendingNodeDeg: 0.0),
        OrbitElements(bodyID: "mars", semiMajorAxisAU: 1.52371034, eccentricity: 0.09339410,
                      inclinationDeg: 1.84969142, meanLongitudeDeg: -4.55343205,
                      perihelionLongitudeDeg: -23.94362959, ascendingNodeDeg: 49.55953891),
        OrbitElements(bodyID: "jupiter", semiMajorAxisAU: 5.20288700, eccentricity: 0.04838624,
                      inclinationDeg: 1.30439695, meanLongitudeDeg: 34.39644051,
                      perihelionLongitudeDeg: 14.72847983, ascendingNodeDeg: 100.47390909),
        OrbitElements(bodyID: "saturn", semiMajorAxisAU: 9.53667594, eccentricity: 0.05386179,
                      inclinationDeg: 2.48599187, meanLongitudeDeg: 49.95424423,
                      perihelionLongitudeDeg: 92.59887831, ascendingNodeDeg: 113.66242448),
        OrbitElements(bodyID: "uranus", semiMajorAxisAU: 19.18916464, eccentricity: 0.04725744,
                      inclinationDeg: 0.77263783, meanLongitudeDeg: 313.23810451,
                      perihelionLongitudeDeg: 170.95427630, ascendingNodeDeg: 74.01692503),
        OrbitElements(bodyID: "neptune", semiMajorAxisAU: 30.06992276, eccentricity: 0.00859048,
                      inclinationDeg: 1.77004347, meanLongitudeDeg: -55.12002969,
                      perihelionLongitudeDeg: 44.96476227, ascendingNodeDeg: 131.78422574),
    ]

    /// The bundled element set of planet `bodyID`, or nil.
    public static func bundled(bodyID: String) -> OrbitElements? { bundled.first { $0.bodyID == bodyID } }

    /// The problems of this element set against "e in [0, 1); a > 0; every value finite" and a non-empty id and
    /// epoch; empty when valid.
    public var problems: [String] {
        var found: [String] = []
        if bodyID.isEmpty { found.append("empty id") }
        if epoch.isEmpty { found.append("\(bodyID): empty epoch") }
        let values: [Double] = [semiMajorAxisAU, eccentricity, inclinationDeg, meanLongitudeDeg,
                                perihelionLongitudeDeg, ascendingNodeDeg]
        var finite = true
        for value in values where !value.isFinite { finite = false }
        if !finite { found.append("\(bodyID): non-finite value") }
        if semiMajorAxisAU.isFinite, !(semiMajorAxisAU > 0) { found.append("\(bodyID): a not > 0") }
        if eccentricity.isFinite, !(eccentricity >= 0 && eccentricity < 1) {
            found.append("\(bodyID): e not in [0, 1)")
        }
        return found
    }

    /// The problems of a whole element list: each set's ``problems``, duplicate ids, and ids that are not exactly the
    /// planets of `catalog` (a missing planet or an unknown id); empty when valid.
    public static func problems(_ elements: [OrbitElements], catalog: BodyCatalog = .bundled) -> [String] {
        var found: [String] = []
        var seen: Set<String> = []
        for element in elements {
            found.append(contentsOf: element.problems)
            if !seen.insert(element.bodyID).inserted { found.append("\(element.bodyID): duplicate id") }
        }
        var planetIDs: Set<String> = []
        for body in catalog.bodies where body.kind == .planet { planetIDs.insert(body.id) }
        for id in seen.subtracting(planetIDs).sorted() { found.append("\(id): not a catalog planet") }
        for id in planetIDs.subtracting(seen).sorted() { found.append("\(id): no elements") }
        return found
    }

    /// `degrees` normalised to 0 ≤ value < 360.
    public static func normalizedDegrees(_ degrees: Double) -> Double {
        let wrapped = degrees.truncatingRemainder(dividingBy: 360)
        let positive = wrapped < 0 ? wrapped + 360 : wrapped
        return positive >= 360 ? 0 : positive
    }

    /// The argument of perihelion ω = ϖ − Ω in degrees, normalised to 0…360°.
    public var argumentOfPerihelionDeg: Double {
        Self.normalizedDegrees(perihelionLongitudeDeg - ascendingNodeDeg)
    }

    /// The mean anomaly at the epoch M₀ = L − ϖ in degrees, normalised to 0…360°.
    public var meanAnomalyAtEpochDeg: Double { Self.normalizedDegrees(meanLongitudeDeg - perihelionLongitudeDeg) }

    /// The Kepler orbit of these elements with mean motion n = 2π / `periodDays` (radians per day, time 0 = the
    /// epoch); nil for an invalid element set or a non-finite or non-positive period.
    public func kepler(periodDays: Double) -> KeplerOrbit? {
        guard problems.isEmpty, periodDays.isFinite, periodDays > 0 else { return nil }
        let radiansPerDegree = Double.pi / 180
        return KeplerOrbit(semiMajorAxis: semiMajorAxisAU, eccentricity: eccentricity,
                           inclination: inclinationDeg * radiansPerDegree,
                           ascendingNode: Self.normalizedDegrees(ascendingNodeDeg) * radiansPerDegree,
                           argumentOfPeriapsis: argumentOfPerihelionDeg * radiansPerDegree,
                           meanAnomalyAtEpoch: meanAnomalyAtEpochDeg * radiansPerDegree,
                           meanMotion: 2 * Double.pi / periodDays)
    }
}
