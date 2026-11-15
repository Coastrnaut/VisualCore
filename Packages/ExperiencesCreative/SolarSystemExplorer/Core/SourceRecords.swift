// SourceRecords — feature 103 (A14-P01) T-A14-102 (FR-A14-110; clarification Q1; data-model "SourceRecord"; research
// "one record per value"; SC-A14-103). Where every stored catalog value came from: one `SourceRecord` per (body,
// quantity) value, with the source's title, publisher and link text, the epoch, the units and the license.
//
// The bundled records (`SourceRecord.bundled`), 34 in catalog order — the Sun: mean radius, axial tilt; each planet:
// mean radius, semi-major axis, sidereal period, axial tilt:
// - the planets' values: "Planetary Fact Sheet — Metric", NASA Space Science Data Coordinated Archive (D. R. Williams,
//   NASA Goddard Space Flight Center), nssdc.gsfc.nasa.gov/planetary/factsheet, epoch J2000.0, a work of the US
//   government in the public domain;
// - the Sun's mean radius: the IAU 2015 Resolution B3 nominal solar radius (695,700 km), epoch "nominal", public domain
//   (a defined constant);
// - the Sun's axial tilt (7.25°, to the ecliptic): the NSSDCA "Sun Fact Sheet",
//   nssdc.gsfc.nasa.gov/planetary/factsheet/sunfact.html, epoch J2000.0, public domain.
// Units are "km" for radii and semi-major axes, "days" for sidereal periods and "degrees" for axial tilts.
//
// Feature 104 (A14-P02) T-A14-205 (FR-A14-210; clarification Q2; research D2) adds `SourceRecord.orbitalElements`: one
// record per planet for quantity `orbital-elements` (its `OrbitElements.bundled` set): E. M. Standish, "Keplerian
// Elements for Approximate Positions of the Major Planets", Table 1, NASA Jet Propulsion Laboratory Solar System
// Dynamics, ssd.jpl.nasa.gov/planets/approx_pos.html, epoch J2000.0, units "AU, degrees", `public-domain` (numerical
// facts published by a NASA laboratory). They are kept apart from `bundled`, which holds the catalog's values.
import Foundation

/// A stored quantity of a body, with its key in source records and the units it is stored in.
public enum BodyQuantity: String, CaseIterable, Codable, Sendable {
    /// The mean (volumetric) radius, in km.
    case meanRadius = "mean-radius"
    /// The orbit's semi-major axis, in km (planets only).
    case semiMajorAxis = "semi-major-axis"
    /// The sidereal orbital period, in days (planets only).
    case siderealPeriod = "sidereal-period"
    /// The axial tilt (obliquity to the orbit; for the Sun, to the ecliptic), in degrees; above 90° is retrograde.
    case axialTilt = "axial-tilt"

    /// The units the quantity is stored in: "km", "km", "days" or "degrees".
    public var units: String {
        switch self {
        case .meanRadius, .semiMajorAxis: return "km"
        case .siderealPeriod: return "days"
        case .axialTilt: return "degrees"
        }
    }

    /// The display label: "Mean radius", "Semi-major axis", "Sidereal period" or "Axial tilt".
    public var label: String {
        switch self {
        case .meanRadius: return "Mean radius"
        case .semiMajorAxis: return "Semi-major axis"
        case .siderealPeriod: return "Sidereal period"
        case .axialTilt: return "Axial tilt"
        }
    }
}

/// The provenance of one stored catalog value.
public struct SourceRecord: Codable, Equatable, Sendable {
    /// The body's id (`sun`, `mercury` … `neptune`).
    public let bodyID: String
    /// The quantity key (a ``BodyQuantity`` raw value: `mean-radius`, `semi-major-axis`, `sidereal-period`,
    /// `axial-tilt`).
    public let quantity: String
    /// The source's title ("Planetary Fact Sheet — Metric").
    public let title: String
    /// The source's publisher.
    public let publisher: String
    /// The link text (a host and path, no scheme).
    public let link: String
    /// The epoch of the value ("J2000.0", or "nominal" for a defined constant).
    public let epoch: String
    /// The units of the value ("km", "days", "degrees").
    public let units: String
    /// The license, one of ``CitationAudit/allowedLicenses``.
    public let license: String

    /// Creates a record from all of its fields (no validation; ``CitationAudit/problems(_:)`` audits).
    public init(bodyID: String, quantity: String, title: String, publisher: String, link: String, epoch: String,
                units: String, license: String) {
        self.bodyID = bodyID; self.quantity = quantity; self.title = title; self.publisher = publisher
        self.link = link; self.epoch = epoch; self.units = units; self.license = license
    }

    /// The NSSDCA Planetary Fact Sheet title.
    public static let factSheetTitle = "Planetary Fact Sheet — Metric"
    /// The NSSDCA publisher line.
    public static let nssdcaPublisher =
        "NASA Space Science Data Coordinated Archive (D. R. Williams, NASA Goddard Space Flight Center)"
    /// The Planetary Fact Sheet link text.
    public static let factSheetLink = "nssdc.gsfc.nasa.gov/planetary/factsheet"
    /// The IAU 2015 Resolution B3 title.
    public static let iauTitle = "Resolution B3 on recommended nominal conversion constants"
    /// The IAU publisher line.
    public static let iauPublisher = "International Astronomical Union (2015)"
    /// The IAU 2015 resolutions link text.
    public static let iauLink = "iau.org/static/resolutions/IAU2015_English.pdf"
    /// The NSSDCA Sun Fact Sheet title.
    public static let sunFactSheetTitle = "Sun Fact Sheet"
    /// The Sun Fact Sheet link text.
    public static let sunFactSheetLink = "nssdc.gsfc.nasa.gov/planetary/factsheet/sunfact.html"
    /// The epoch of the orbital elements.
    public static let j2000 = "J2000.0"
    /// The license of every bundled record.
    public static let publicDomain = "public-domain"

    /// The quantity key of an orbital-element set.
    public static let orbitalElementsQuantity = "orbital-elements"
    /// The units of an orbital-element set.
    public static let orbitalElementsUnits = "AU, degrees"
    /// The title of the orbital elements' source.
    public static let standishTitle = "Keplerian Elements for Approximate Positions of the Major Planets, Table 1"
    /// The publisher line of the orbital elements' source.
    public static let standishPublisher =
        "E. M. Standish, NASA Jet Propulsion Laboratory Solar System Dynamics (numerical facts, public domain)"
    /// The orbital elements' link text.
    public static let standishLink = "ssd.jpl.nasa.gov/planets/approx_pos.html"

    /// The eight orbital-element records, one per planet in catalog order (see the file header).
    public static let orbitalElements: [SourceRecord] = {
        let planets: [String] = ["mercury", "venus", "earth", "mars", "jupiter", "saturn", "uranus", "neptune"]
        var records: [SourceRecord] = []
        for planet in planets {
            records.append(SourceRecord(bodyID: planet, quantity: orbitalElementsQuantity, title: standishTitle,
                                        publisher: standishPublisher, link: standishLink, epoch: j2000,
                                        units: orbitalElementsUnits, license: publicDomain))
        }
        return records
    }()

    /// A Planetary Fact Sheet record for `bodyID`'s `quantity`.
    private static func factSheet(_ bodyID: String, _ quantity: BodyQuantity) -> SourceRecord {
        SourceRecord(bodyID: bodyID, quantity: quantity.rawValue, title: factSheetTitle, publisher: nssdcaPublisher,
                     link: factSheetLink, epoch: j2000, units: quantity.units, license: publicDomain)
    }

    /// The 34 bundled records in catalog order (see the file header).
    public static let bundled: [SourceRecord] = {
        var records: [SourceRecord] = [
            SourceRecord(bodyID: "sun", quantity: BodyQuantity.meanRadius.rawValue, title: iauTitle,
                         publisher: iauPublisher, link: iauLink, epoch: "nominal", units: "km",
                         license: publicDomain),
            SourceRecord(bodyID: "sun", quantity: BodyQuantity.axialTilt.rawValue, title: sunFactSheetTitle,
                         publisher: nssdcaPublisher, link: sunFactSheetLink, epoch: j2000, units: "degrees",
                         license: publicDomain),
        ]
        let planets: [String] = ["mercury", "venus", "earth", "mars", "jupiter", "saturn", "uranus", "neptune"]
        for planet in planets {
            for quantity in BodyQuantity.allCases {
                records.append(factSheet(planet, quantity))
            }
        }
        return records
    }()
}
