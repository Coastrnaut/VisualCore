// OrbitModel — feature 104 (A14-P02) T-A14-204 (FR-A14-210, 211; clarifications Q2, Q3; research D2; data-model
// "OrbitModel"; SC-A14-201). The orbits of the eight planets: each planet's `OrbitElements` with the catalog's sidereal
// period as `VisualCoreMath.KeplerOrbit` (time in days since J2000.0). `position(bodyID:day:)` is the heliocentric
// ecliptic position in AU (x toward the J2000.0 equinox, y 90° ahead in the ecliptic, z toward ecliptic north; the Sun
// is at the origin), `distanceAU` its length and `distanceKm` that length through `Units.kmPerAU`. An unknown id, a
// planet without valid elements or a non-finite day gives nil.
import Foundation
import VisualCoreMath

/// The heliocentric orbits of the catalog's planets.
public struct OrbitModel: Sendable {
    /// The model of the bundled catalog and elements.
    public static let bundled = OrbitModel(catalog: .bundled, elements: OrbitElements.bundled)

    /// The id of the body at the origin.
    public let sunID: String
    /// The Kepler orbit of each planet id (time in days since J2000.0, lengths in AU).
    public let orbits: [String: KeplerOrbit]

    /// The model of every planet of `catalog` that has valid `elements` and a sidereal period; the catalog's star is
    /// the origin.
    public init(catalog: BodyCatalog, elements: [OrbitElements]) {
        var orbits: [String: KeplerOrbit] = [:]
        for body in catalog.bodies where body.kind == .planet {
            guard let period = body.siderealPeriodDays,
                  let element = elements.first(where: { $0.bodyID == body.id }),
                  let orbit = element.kepler(periodDays: period) else { continue }
            orbits[body.id] = orbit
        }
        self.orbits = orbits
        self.sunID = catalog.bodies.first(where: { $0.kind == .star })?.id ?? "sun"
    }

    /// The orbit of `bodyID`, or nil (the Sun, an unknown id).
    public func orbit(bodyID: String) -> KeplerOrbit? { orbits[bodyID] }

    /// The heliocentric ecliptic position of `bodyID` in AU at `day` (days since J2000.0); `.zero` for the Sun; nil
    /// for an unknown id or a non-finite day.
    public func position(bodyID: String, day: Double) -> Vec3? {
        guard day.isFinite else { return nil }
        if bodyID == sunID { return .zero }
        return orbits[bodyID]?.position(at: day)
    }

    /// The distance of `bodyID` from the Sun in AU at `day`; nil as for ``position(bodyID:day:)``.
    public func distanceAU(bodyID: String, day: Double) -> Double? { position(bodyID: bodyID, day: day)?.length }

    /// The distance of `bodyID` from the Sun in km at `day` (AU × ``Units/kmPerAU``); nil as for
    /// ``position(bodyID:day:)``.
    public func distanceKm(bodyID: String, day: Double) -> Double? {
        distanceAU(bodyID: bodyID, day: day).flatMap { Units.km(fromAU: $0) }
    }
}
