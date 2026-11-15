// BodyCatalog — feature 103 (A14-P01) T-A14-102 (FR-A14-101, 102, 104, 121; clarifications Q1, Q2; data-model
// "BodyKind", "CelestialBody", "BodyCatalog", "FactCard"; contracts/catalog.md; gap G-CATALOG). The scientific catalog
// of Solar System Explorer: the Sun and the eight major planets in increasing distance from the Sun, with the mean
// (volumetric) radius in km, the semi-major axis in km and the sidereal orbital period in days (both absent for the
// Sun, never zero) and the axial tilt in degrees (obliquity to the orbit; the Sun's to the ecliptic; above 90° means
// retrograde rotation, stored as given). The values are exactly those of spec clarification Q2, from the NASA NSSDCA
// Planetary Fact Sheet (epoch J2000.0, public domain) and, for the Sun's radius, the IAU 2015 Resolution B3 nominal
// value; every value has one `SourceRecord` (SourceRecords.swift). Distances in AU and periods in years are derived
// through `Units`, never stored.
//
// The JSON codec writes the catalog with sorted keys: `{"bodies": [{"axialTiltDegrees", "id", "kind", "meanRadiusKm",
// "name", "semiMajorAxisKm"?, "siderealPeriodDays"?}, …], "schema": 1, "sources": [{"bodyID", "epoch", "license",
// "link", "publisher", "quantity", "title", "units"}, …]}` (an absent axis or period has no key). `decode(_:)` reads
// the schema first and refuses the whole document, in this order:
// - `damaged`: not JSON, truncated, no integer `schema`, a schema below 1, or a missing or malformed key (an unknown
//   `kind`, a string where a number belongs, a number JSON cannot hold as a finite `Double`);
// - `newer-version`: a schema above 1 (whatever else the document holds);
// - `out-of-range`: outside the ranges "1…16 bodies, ids non-empty and unique, names non-empty, radius 1…1,000,000 km,
//   axis 1e6…1e10 km, period 1…1,000,000 days, tilt 0…180°, every value finite", a star with an axis or a period, a
//   planet without both, a star after a planet, or planets not in strictly increasing semi-major axis.
// The decoder does not audit the source records (that is `CitationAudit.problems(_:)`). A refused document changes
// nothing; the caller keeps `BodyCatalog.bundled`.
//
// `factCard(for:)` gives the fact card of a body: for a planet "Mean radius" (km), "Distance from the Sun" (AU, three
// decimals, with the stored km as its note), "Orbital period" (days, with Julian years as its note) and "Axial tilt"
// (degrees, noted "retrograde" above 90°); for the Sun "Mean radius", "Axial tilt" (noted "to the ecliptic") and
// "Orbit: none (centre of the system)". Each measured fact carries its unit and its source title; cards round for
// display while the stored values stay unrounded.
import Foundation

/// The kind of a celestial body.
public enum BodyKind: String, Codable, CaseIterable, Sendable {
    /// A star (the Sun): no orbit around itself.
    case star
    /// A planet: it has a semi-major axis and a sidereal period.
    case planet
}

/// One body of the catalog with its stored values.
public struct CelestialBody: Codable, Equatable, Sendable, Identifiable {
    /// The id (`sun`, `mercury` … `neptune`).
    public let id: String
    /// The display name ("Earth").
    public let name: String
    /// The kind.
    public let kind: BodyKind
    /// The mean (volumetric) radius in km.
    public let meanRadiusKm: Double
    /// The orbit's semi-major axis in km; nil for the Sun.
    public let semiMajorAxisKm: Double?
    /// The sidereal orbital period in days; nil for the Sun.
    public let siderealPeriodDays: Double?
    /// The axial tilt in degrees (0…180; above 90 is retrograde rotation).
    public let axialTiltDegrees: Double

    /// Creates a body from all of its fields (no validation; ``BodyCatalog/rangeProblem(_:)`` validates).
    public init(id: String, name: String, kind: BodyKind, meanRadiusKm: Double, semiMajorAxisKm: Double?,
                siderealPeriodDays: Double?, axialTiltDegrees: Double) {
        self.id = id; self.name = name; self.kind = kind; self.meanRadiusKm = meanRadiusKm
        self.semiMajorAxisKm = semiMajorAxisKm; self.siderealPeriodDays = siderealPeriodDays
        self.axialTiltDegrees = axialTiltDegrees
    }

    /// True when the axial tilt is above 90° (retrograde rotation: Venus, Uranus).
    public var isRetrograde: Bool { axialTiltDegrees > 90 }

    /// The semi-major axis in AU, derived through ``Units/kmPerAU``; nil for the Sun.
    public var semiMajorAxisAU: Double? { semiMajorAxisKm.flatMap { Units.au(fromKm: $0) } }

    /// The sidereal period in Julian years, derived through ``Units/daysPerJulianYear``; nil for the Sun.
    public var siderealPeriodYears: Double? { siderealPeriodDays.flatMap { Units.years(fromDays: $0) } }

    /// The stored value of `quantity`, or nil when the body has none (the Sun's axis and period).
    public func value(of quantity: BodyQuantity) -> Double? {
        switch quantity {
        case .meanRadius: return meanRadiusKm
        case .semiMajorAxis: return semiMajorAxisKm
        case .siderealPeriod: return siderealPeriodDays
        case .axialTilt: return axialTiltDegrees
        }
    }

    /// The quantities the body stores, in ``BodyQuantity`` order.
    public var storedQuantities: [BodyQuantity] { BodyQuantity.allCases.filter { value(of: $0) != nil } }
}

/// Why a catalog document was refused as a whole.
public enum CatalogRefusal: String, CaseIterable, Codable, Error, Sendable {
    /// Not JSON, truncated, or a missing or malformed key.
    case damaged = "damaged"
    /// Written by a newer version (schema above ``BodyCatalog/schemaVersion``).
    case newerVersion = "newer-version"
    /// Readable but outside the catalog's ranges (see the file header).
    case outOfRange = "out-of-range"
}

/// One line of a fact card: label, value text, unit, an optional note and the source title.
public struct Fact: Codable, Equatable, Sendable {
    /// The label ("Mean radius").
    public let label: String
    /// The value rounded for display ("6,371").
    public let value: String
    /// The unit ("km", "AU", "days", "degrees"); empty only for the Sun's "Orbit: none" fact.
    public let unit: String
    /// A note shown in parentheses after the value ("57,909,000 km", "0.241 years", "retrograde"), or "".
    public let note: String
    /// The source title ("Planetary Fact Sheet — Metric"); empty only for the Sun's "Orbit: none" fact.
    public let source: String

    /// Creates a fact.
    public init(label: String, value: String, unit: String, note: String = "", source: String) {
        self.label = label; self.value = value; self.unit = unit; self.note = note; self.source = source
    }

    /// The fact as one line: "Mean radius: 6,371 km — Planetary Fact Sheet — Metric",
    /// "Axial tilt: 177.4 degrees (retrograde) — …", "Orbit: none (centre of the system)".
    public var text: String {
        var line = "\(label): \(value)"
        if !unit.isEmpty { line += " \(unit)" }
        if !note.isEmpty { line += " (\(note))" }
        if !source.isEmpty { line += " — \(source)" }
        return line
    }
}

/// The fact card of one body.
public struct FactCard: Codable, Equatable, Sendable {
    /// The body's id.
    public let bodyID: String
    /// The body's display name.
    public let name: String
    /// The body's kind.
    public let kind: BodyKind
    /// The facts in display order.
    public let facts: [Fact]

    /// Creates a fact card.
    public init(bodyID: String, name: String, kind: BodyKind, facts: [Fact]) {
        self.bodyID = bodyID; self.name = name; self.kind = kind; self.facts = facts
    }

    /// Every fact's ``Fact/text``, one per line.
    public var text: String { facts.map(\.text).joined(separator: "\n") }
}

/// The catalog of bodies and the source record of every stored value.
public struct BodyCatalog: Codable, Equatable, Sendable {
    /// The document schema this code writes and reads.
    public static let schemaVersion = 1
    /// The most bodies a document may hold.
    public static let maxBodies = 16
    /// The allowed mean radius range in km.
    public static let radiusRangeKm: ClosedRange<Double> = 1...1_000_000
    /// The allowed semi-major axis range in km.
    public static let axisRangeKm: ClosedRange<Double> = 1e6...1e10
    /// The allowed sidereal period range in days.
    public static let periodRangeDays: ClosedRange<Double> = 1...1_000_000
    /// The allowed axial tilt range in degrees.
    public static let tiltRangeDegrees: ClosedRange<Double> = 0...180

    /// The bodies in increasing distance from the Sun (the Sun first).
    public let bodies: [CelestialBody]
    /// One source record per stored value.
    public let sources: [SourceRecord]

    /// Creates a catalog (no validation; ``decode(_:)`` validates).
    public init(bodies: [CelestialBody], sources: [SourceRecord]) {
        self.bodies = bodies
        self.sources = sources
    }

    /// A planet with the values of clarification Q2.
    private static func planet(_ id: String, _ name: String, radius: Double, axis: Double, period: Double,
                               tilt: Double) -> CelestialBody {
        CelestialBody(id: id, name: name, kind: .planet, meanRadiusKm: radius, semiMajorAxisKm: axis,
                      siderealPeriodDays: period, axialTiltDegrees: tilt)
    }

    /// The bundled catalog: the Sun and the eight major planets with the exact values of spec clarification Q2 and
    /// ``SourceRecord/bundled``.
    public static let bundled = BodyCatalog(bodies: [
        CelestialBody(id: "sun", name: "Sun", kind: .star, meanRadiusKm: 695_700, semiMajorAxisKm: nil,
                      siderealPeriodDays: nil, axialTiltDegrees: 7.25),
        planet("mercury", "Mercury", radius: 2_439.7, axis: 57.909e6, period: 87.969, tilt: 0.034),
        planet("venus", "Venus", radius: 6_051.8, axis: 108.210e6, period: 224.701, tilt: 177.4),
        planet("earth", "Earth", radius: 6_371.0, axis: 149.598e6, period: 365.256, tilt: 23.44),
        planet("mars", "Mars", radius: 3_389.5, axis: 227.956e6, period: 686.980, tilt: 25.19),
        planet("jupiter", "Jupiter", radius: 69_911, axis: 778.479e6, period: 4_332.589, tilt: 3.13),
        planet("saturn", "Saturn", radius: 58_232, axis: 1_432.041e6, period: 10_759.22, tilt: 26.73),
        planet("uranus", "Uranus", radius: 25_362, axis: 2_867.043e6, period: 30_685.4, tilt: 97.77),
        planet("neptune", "Neptune", radius: 24_622, axis: 4_514.953e6, period: 60_189.0, tilt: 28.32),
    ], sources: SourceRecord.bundled)

    /// The body at `index`, or nil outside the catalog.
    public func body(at index: Int) -> CelestialBody? { bodies.indices.contains(index) ? bodies[index] : nil }

    /// The body with `id`, or nil.
    public func body(id: String) -> CelestialBody? { bodies.first { $0.id == id } }

    /// The first source record of `bodyID`'s `quantity`, or nil.
    public func source(bodyID: String, quantity: BodyQuantity) -> SourceRecord? {
        sources.first { $0.bodyID == bodyID && $0.quantity == quantity.rawValue }
    }

    // MARK: Fact cards

    /// The fact card of the body at `index` (see the file header), or nil outside the catalog.
    public func factCard(for index: Int) -> FactCard? {
        guard let body = body(at: index) else { return nil }
        func title(_ quantity: BodyQuantity) -> String { source(bodyID: body.id, quantity: quantity)?.title ?? "" }
        var facts: [Fact] = [
            Fact(label: "Mean radius", value: Units.text(body.meanRadiusKm, fractionDigits: 1, trimZeros: true),
                 unit: "km", source: title(.meanRadius)),
        ]
        if let axisKm = body.semiMajorAxisKm, let axisAU = body.semiMajorAxisAU {
            facts.append(Fact(label: "Distance from the Sun", value: Units.text(axisAU, fractionDigits: 3),
                              unit: "AU", note: "\(Units.storedText(axisKm)) km", source: title(.semiMajorAxis)))
        }
        if let days = body.siderealPeriodDays, let years = body.siderealPeriodYears {
            facts.append(Fact(label: "Orbital period", value: Units.text(days, fractionDigits: 3, trimZeros: true),
                              unit: "days", note: "\(Units.text(years, fractionDigits: 3)) years",
                              source: title(.siderealPeriod)))
        }
        let tiltNote = body.kind == .star ? "to the ecliptic" : (body.isRetrograde ? "retrograde" : "")
        facts.append(Fact(label: "Axial tilt", value: Units.text(body.axialTiltDegrees, fractionDigits: 3,
                                                                 trimZeros: true),
                          unit: "degrees", note: tiltNote, source: title(.axialTilt)))
        if body.kind == .star {
            facts.append(Fact(label: "Orbit", value: "none", unit: "", note: "centre of the system", source: ""))
        }
        return FactCard(bodyID: body.id, name: body.name, kind: body.kind, facts: facts)
    }

    // MARK: Validation

    /// The first range problem of `catalog` (see the file header), or nil when it is in range.
    public static func rangeProblem(_ catalog: BodyCatalog) -> String? {
        guard (1...maxBodies).contains(catalog.bodies.count) else { return "body count \(catalog.bodies.count)" }
        var seen: Set<String> = []
        var lastAxis: Double = 0
        var sawPlanet = false
        for body in catalog.bodies {
            guard !body.id.isEmpty, !body.name.isEmpty else { return "empty id or name" }
            guard seen.insert(body.id).inserted else { return "\(body.id): duplicate id" }
            guard body.meanRadiusKm.isFinite, radiusRangeKm.contains(body.meanRadiusKm) else {
                return "\(body.id): mean radius"
            }
            guard body.axialTiltDegrees.isFinite, tiltRangeDegrees.contains(body.axialTiltDegrees) else {
                return "\(body.id): axial tilt"
            }
            switch body.kind {
            case .star:
                guard body.semiMajorAxisKm == nil, body.siderealPeriodDays == nil else { return "\(body.id): orbit" }
                guard !sawPlanet else { return "\(body.id): star after a planet" }
            case .planet:
                guard let axis = body.semiMajorAxisKm, let period = body.siderealPeriodDays else {
                    return "\(body.id): missing orbit"
                }
                guard axis.isFinite, axisRangeKm.contains(axis) else { return "\(body.id): semi-major axis" }
                guard period.isFinite, periodRangeDays.contains(period) else { return "\(body.id): sidereal period" }
                guard axis > lastAxis else { return "\(body.id): out of order" }
                lastAxis = axis
                sawPlanet = true
            }
        }
        return nil
    }

    // MARK: Codec

    private enum CodingKeys: String, CodingKey { case bodies, schema, sources }

    /// Decodes a schema-1 document; throws for another schema or a missing or malformed key (no range checks; use
    /// ``decode(_:)``).
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        guard try c.decode(Int.self, forKey: .schema) == Self.schemaVersion else {
            throw DecodingError.dataCorruptedError(forKey: .schema, in: c, debugDescription: "not schema 1")
        }
        bodies = try c.decode([CelestialBody].self, forKey: .bodies)
        sources = try c.decode([SourceRecord].self, forKey: .sources)
    }

    /// Encodes the catalog at the current schema (the keys of the file header).
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(bodies, forKey: .bodies)
        try c.encode(Self.schemaVersion, forKey: .schema)
        try c.encode(sources, forKey: .sources)
    }

    /// The catalog as JSON with sorted keys (deterministic bytes for equal catalogs).
    public func encoded() -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return (try? encoder.encode(self)) ?? Data()
    }

    /// The catalog in `data`, or the reason the whole document is refused (see the file header for the order).
    public static func decode(_ data: Data) -> Result<BodyCatalog, CatalogRefusal> {
        struct Header: Decodable { var schema: Int }
        let decoder = JSONDecoder()
        guard let header = try? decoder.decode(Header.self, from: data), header.schema >= 1 else {
            return .failure(.damaged)
        }
        guard header.schema <= schemaVersion else { return .failure(.newerVersion) }
        guard let catalog = try? decoder.decode(BodyCatalog.self, from: data) else { return .failure(.damaged) }
        guard rangeProblem(catalog) == nil else { return .failure(.outOfRange) }
        return .success(catalog)
    }
}
