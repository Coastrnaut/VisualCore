// ApsidesWorkshopLevel — feature 471 (R02-G18-01) T-R02G1801-002 (FR-R02G1801-001, 002, 009, 011, 013;
// SC-R02G1801-001, 005; clarifications Q1 … Q5). An immutable Apsides Workshop level: a period of 16 … 96 ticks (even);
// 0 … 6 exclusion planets (centre −64 … 64 lattice units, radius 1 … 8, never overlapping the star); 1 … 6 targets
// (sweeps of sector 0 … 7 with a share band low ≤ high in 0 … 1000, or apsis targets of sector 0 … 7 with a distance
// range near ≤ far in twentieths), no two identical; a starting orbit that is valid and does not already win; an action
// budget 1 … 24; a difficulty 1 … 5 and whether a tutorial precedes play. Its fingerprint is the SHA-256 hex of its
// canonical JSON (schema 1, sorted keys, fingerprint excluded); the stored form is re-checked on decode. Sectors,
// targets and progress are named in words (FR-R02G1801-013). Modelled on `CelestialEclipseLabLevel` (feature 461).
import Foundation
import VisualCoreMath

/// An immutable, fingerprinted Apsides Workshop level.
public struct ApsidesWorkshopLevel: Sendable, Equatable {
    /// The stored-form schema.
    public static let schema: Int = 1
    /// The difficulty range.
    public static let difficulties: ClosedRange<Int> = 1...5
    /// The periods in ticks (even values only).
    public static let periods: ClosedRange<Int> = 16...96
    /// The number of exclusion planets.
    public static let planetCounts: ClosedRange<Int> = 0...6
    /// The planet centre coordinates in lattice units.
    public static let coordinates: ClosedRange<Int> = -64...64
    /// The planet radii in lattice units.
    public static let radii: ClosedRange<Int> = 1...8
    /// The number of targets.
    public static let targetCounts: ClosedRange<Int> = 1...6
    /// The share bounds in tenths of a percent.
    public static let shareBounds: ClosedRange<Int> = 0...1000
    /// The distance bounds in twentieths of a lattice unit (the sky bound, 64 lattice units).
    public static let distanceBounds: ClosedRange<Int> = 0...1280
    /// The action budgets.
    public static let budgets: ClosedRange<Int> = 1...24

    /// The level's id, a lowercase slug.
    public let id: String
    /// The seed the level was generated from (0 for hand-made levels).
    public let seed: UInt64
    /// The difficulty, 1 … 5.
    public let difficulty: Int
    /// The period of one revolution in ticks.
    public let period: Int
    /// The exclusion planets, numbered by index.
    public let planets: [ApsidesWorkshopPlanet]
    /// The ordered targets, numbered by index.
    public let targets: [ApsidesWorkshopTarget]
    /// The starting orbit.
    public let orbit: ApsidesWorkshopOrbit
    /// The action budget.
    public let budget: Int
    /// Whether a tutorial precedes play.
    public let tutorial: Bool
    /// The SHA-256 hex of the canonical JSON content.
    public let fingerprint: String

    /// A level of the given values, checked.
    ///
    /// - Throws: `.level(name)` naming the first value outside its range or rule.
    public init(id: String, seed: UInt64, difficulty: Int, period: Int, planets: [ApsidesWorkshopPlanet],
                targets: [ApsidesWorkshopTarget], orbit: ApsidesWorkshopOrbit, budget: Int,
                tutorial: Bool = false) throws(ApsidesWorkshopError) {
        try self.init(id: id, seed: seed, difficulty: difficulty, period: period, planets: planets, targets: targets,
                      orbit: orbit, budget: budget, tutorial: tutorial, refusingAWin: true)
    }

    /// A level of the given values, checked; the "already won" rule only when `refusingAWin` (a probe that only reads
    /// reports passes false).
    init(id: String, seed: UInt64, difficulty: Int, period: Int, planets: [ApsidesWorkshopPlanet],
         targets: [ApsidesWorkshopTarget], orbit: ApsidesWorkshopOrbit, budget: Int, tutorial: Bool,
         refusingAWin: Bool) throws(ApsidesWorkshopError) {
        guard Self.isSlug(id) else { throw .level("id") }
        guard Self.difficulties.contains(difficulty) else { throw .level("difficulty") }
        guard Self.periods.contains(period), period % 2 == 0 else { throw .level("period") }
        guard Self.planetCounts.contains(planets.count) else { throw .level("planets") }
        for planet in planets {
            guard Self.coordinates.contains(planet.x), Self.coordinates.contains(planet.y) else {
                throw .level("planet centre")
            }
            guard Self.radii.contains(planet.radius) else { throw .level("planet radius") }
            let reach: Int = planet.radius + ApsidesWorkshopSky.starRadius
            guard planet.x * planet.x + planet.y * planet.y > reach * reach else { throw .level("planet over star") }
        }
        guard Self.targetCounts.contains(targets.count) else { throw .level("targets") }
        for target in targets {
            guard (0..<ApsidesWorkshopSky.sectorCount).contains(target.sector) else { throw .level("target sector") }
            let bounds: ClosedRange<Int> = target.kind == .sweep ? Self.shareBounds : Self.distanceBounds
            guard bounds.contains(target.low), bounds.contains(target.high) else { throw .level("target band") }
            guard target.low <= target.high else { throw .level("target band reversed") }
        }
        guard Set(targets).count == targets.count else { throw .level("targets duplicate") }
        guard orbit.isValid else { throw .level("orbit") }
        guard Self.budgets.contains(budget) else { throw .level("budget") }
        let content = Content(schema: Self.schema, id: id, seed: seed, difficulty: difficulty, period: period,
                              planets: planets, targets: targets, orbit: orbit, budget: budget, tutorial: tutorial)
        guard let data = try? Self.encoder.encode(content) else { throw .malformed("encode") }
        self.id = id
        self.seed = seed
        self.difficulty = difficulty
        self.period = period
        self.planets = planets
        self.targets = targets
        self.orbit = orbit
        self.budget = budget
        self.tutorial = tutorial
        self.fingerprint = StableHash.sha256Hex(Array(data))
        if refusingAWin {
            guard !ApsidesWorkshopSky.report(self, orbit: orbit).wins else { throw .level("already won") }
        }
    }

    /// A probe level that skips the "already won" rule, for reading the reports of other orbits (the content
    /// pipeline and the fixtures); every other rule is checked.
    static func probe(period: Int, planets: [ApsidesWorkshopPlanet], targets: [ApsidesWorkshopTarget],
                      orbit: ApsidesWorkshopOrbit) throws(ApsidesWorkshopError) -> ApsidesWorkshopLevel {
        try ApsidesWorkshopLevel(id: "probe", seed: 0, difficulty: 1, period: period, planets: planets,
                                 targets: targets, orbit: orbit, budget: 1, tutorial: false, refusingAWin: false)
    }

    /// The report of the starting orbit.
    public var startReport: ApsidesWorkshopReport { ApsidesWorkshopSky.report(self, orbit: orbit) }

    /// "sector 3".
    public func sectorName(_ index: Int) -> String { "sector \(index)" }

    /// "planet 2".
    public func planetName(_ index: Int) -> String { "planet \(index)" }

    /// A share in words: 184 → "18.4 %".
    public static func shareWords(_ share: Int) -> String { "\(share / 10).\(share % 10) %" }

    /// A distance in twentieths in words: 131 → "6.55 units".
    public static func distanceWords(_ twentieths: Int) -> String {
        let hundredths: Int = (twentieths % 20) * 5
        return "\(twentieths / 20)." + (hundredths < 10 ? "0" : "") + "\(hundredths) units"
    }

    /// The orbit in words: "size 24, eccentricity 0.35, periapsis at 45°".
    public func orbitDescription(_ orbit: ApsidesWorkshopOrbit) -> String {
        let e: Int = orbit.eccentricity * 5
        let eccentricity: String = "0." + (e < 10 ? "0" : "") + "\(e)"
        return "size \(orbit.size), eccentricity \(eccentricity), periapsis at \(orbit.direction * 15)°"
    }

    /// Target `index` in words against `report` and `orbit`: "sector 3 swept 18.4 %, needs 15.0 % to 20.0 %" or
    /// "periapsis in sector 2 at 6.55 units, needs sector 2 at 6.00 units to 7.00 units".
    public func targetDescription(_ index: Int, report: ApsidesWorkshopReport, orbit: ApsidesWorkshopOrbit) -> String {
        let target: ApsidesWorkshopTarget = targets[index]
        switch target.kind {
        case .sweep:
            return sectorName(target.sector) + " swept " + Self.shareWords(report.shares[target.sector]) + ", needs "
                + Self.shareWords(target.low) + " to " + Self.shareWords(target.high)
        case .periapsis, .apoapsis:
            let periapsis: Bool = target.kind == .periapsis
            let sector: Int = periapsis ? orbit.periapsisSector : orbit.apoapsisSector
            let distance: Int = periapsis ? orbit.periapsisDistance : orbit.apoapsisDistance
            return target.kind.rawValue + " in " + sectorName(sector) + " at " + Self.distanceWords(distance)
                + ", needs " + sectorName(target.sector) + " at " + Self.distanceWords(target.low) + " to "
                + Self.distanceWords(target.high)
        }
    }

    /// The progress in words: the targets met in order, the next one, the predicted outcome and the actions left.
    public func progressDescription(report: ApsidesWorkshopReport, orbit: ApsidesWorkshopOrbit,
                                    actionsLeft: Int) -> String {
        var parts: [String] = [orbitDescription(orbit), "\(report.met) of \(targets.count) targets met in order"]
        if case .contact(let planet, let tick) = report.failure {
            parts.append("the orbit strikes \(planetName(planet)) after tick \(tick)")
        } else if report.met < targets.count {
            parts.append("next: " + targetDescription(report.met, report: report, orbit: orbit))
        }
        parts.append(report.wins ? "playing now would win" : "playing now would fail")
        parts.append(actionsLeft == 1 ? "1 action left" : "\(actionsLeft) actions left")
        return parts.joined(separator: "; ")
    }

    /// The stored form: JSON with sorted keys holding the schema, every field and the fingerprint.
    public func encoded() -> Data {
        do {
            return try Self.encoder.encode(Stored(content: Content(level: self), fingerprint: fingerprint))
        } catch {
            preconditionFailure("an Apsides Workshop level of checked values always encodes: \(error)")
        }
    }

    /// Decodes a stored level, re-checking every rule and the fingerprint.
    ///
    /// - Throws: `.newerSchema(s)` above ``schema``; `.malformed(description)` for unreadable JSON, missing keys, a
    ///   schema below 1, any refusal of the initialiser (its reason code) or a fingerprint that does not match.
    public static func decode(_ data: Data) throws(ApsidesWorkshopError) -> ApsidesWorkshopLevel {
        struct Probe: Decodable { let schema: Int }
        let probe: Probe
        do { probe = try JSONDecoder().decode(Probe.self, from: data) } catch { throw .malformed("unreadable") }
        guard probe.schema <= schema else { throw .newerSchema(probe.schema) }
        guard probe.schema >= 1 else { throw .malformed("schema \(probe.schema)") }
        let stored: Stored
        do { stored = try JSONDecoder().decode(Stored.self, from: data) } catch { throw .malformed("unreadable") }
        let level: ApsidesWorkshopLevel
        do {
            level = try stored.content.level()
        } catch {
            throw .malformed(error.reasonCode)
        }
        guard level.fingerprint == stored.fingerprint else { throw .malformed("fingerprint") }
        return level
    }

    /// JSON with sorted keys.
    static var encoder: JSONEncoder {
        let e = JSONEncoder()
        e.outputFormatting = [.sortedKeys]
        return e
    }

    /// Whether `id` is a lowercase slug of 1 … 64 characters: a … z, 0 … 9 and single inner hyphens.
    static func isSlug(_ id: String) -> Bool {
        let scalars = Array(id.unicodeScalars)
        guard !scalars.isEmpty, scalars.count <= 64, scalars.first != "-", scalars.last != "-" else { return false }
        var previousHyphen = false
        for s in scalars {
            let hyphen = s == "-"
            guard hyphen || ("a"..."z").contains(s) || ("0"..."9").contains(s) else { return false }
            if hyphen && previousHyphen { return false }
            previousHyphen = hyphen
        }
        return true
    }

    /// The fingerprinted content.
    struct Content: Codable, Equatable {
        let schema: Int
        let id: String
        let seed: UInt64
        let difficulty: Int
        let period: Int
        let planets: [ApsidesWorkshopPlanet]
        let targets: [ApsidesWorkshopTarget]
        let orbit: ApsidesWorkshopOrbit
        let budget: Int
        let tutorial: Bool

        init(schema: Int, id: String, seed: UInt64, difficulty: Int, period: Int, planets: [ApsidesWorkshopPlanet],
             targets: [ApsidesWorkshopTarget], orbit: ApsidesWorkshopOrbit, budget: Int, tutorial: Bool) {
            self.schema = schema
            self.id = id
            self.seed = seed
            self.difficulty = difficulty
            self.period = period
            self.planets = planets
            self.targets = targets
            self.orbit = orbit
            self.budget = budget
            self.tutorial = tutorial
        }

        init(level: ApsidesWorkshopLevel) {
            self.init(schema: ApsidesWorkshopLevel.schema, id: level.id, seed: level.seed,
                      difficulty: level.difficulty, period: level.period, planets: level.planets,
                      targets: level.targets, orbit: level.orbit, budget: level.budget, tutorial: level.tutorial)
        }

        /// The level of this content, re-checked.
        func level() throws(ApsidesWorkshopError) -> ApsidesWorkshopLevel {
            try ApsidesWorkshopLevel(id: id, seed: seed, difficulty: difficulty, period: period, planets: planets,
                                     targets: targets, orbit: orbit, budget: budget, tutorial: tutorial)
        }
    }

    /// The stored form: the content flattened with its fingerprint.
    struct Stored: Codable {
        let content: Content
        let fingerprint: String

        init(content: Content, fingerprint: String) {
            self.content = content
            self.fingerprint = fingerprint
        }

        private enum Keys: String, CodingKey { case fingerprint }

        init(from decoder: any Decoder) throws {
            let c = try decoder.container(keyedBy: Keys.self)
            fingerprint = try c.decode(String.self, forKey: .fingerprint)
            content = try Content(from: decoder)
        }

        func encode(to encoder: any Encoder) throws {
            try content.encode(to: encoder)
            var c = encoder.container(keyedBy: Keys.self)
            try c.encode(fingerprint, forKey: .fingerprint)
        }
    }
}

extension ApsidesWorkshopLevel: Codable {
    /// Decodes a level through ``decode(_:)``'s rules.
    public init(from decoder: any Decoder) throws {
        let stored = try Stored(from: decoder)
        guard stored.content.schema <= Self.schema else {
            let code = ApsidesWorkshopError.newerSchema(stored.content.schema).reasonCode
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: code))
        }
        do {
            self = try stored.content.level()
        } catch {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: error.reasonCode))
        }
        guard fingerprint == stored.fingerprint else {
            let code = ApsidesWorkshopError.malformed("fingerprint").reasonCode
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: code))
        }
    }

    /// Encodes the stored form.
    public func encode(to encoder: any Encoder) throws {
        try Stored(content: Content(level: self), fingerprint: fingerprint).encode(to: encoder)
    }
}
