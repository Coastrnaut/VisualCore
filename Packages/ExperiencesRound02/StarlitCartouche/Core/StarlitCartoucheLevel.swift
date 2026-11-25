// StarlitCartoucheLevel — feature 451 (R02-G16-01) T-R02G1601-002 (FR-R02G1601-001, 009, 011, 013;
// SC-R02G1601-001, 005; clarifications Q1 … Q5). An immutable Starlit Cartouche level: 4 … 12 stars (each with an orbit
// of 1 … 4 lattice positions, coordinates −8 … 8, a glyph point on the 5 × 5 grid distinct from every other star's, and
// a window 0 ≤ open ≤ close ≤ 64, independent of the deadline, so a leg can arrive inside its window and still past the
// deadline); a range 1 … 12; at most 24 undirected corridors (no star joined to itself, no corridor twice, travel
// 1 … 3); at most 8 hazard tubes (a corridor and a closed interval from ≤ to, from ≥ 0); the start star (its window
// contains beat 0) and the beacon star; a deadline 1 … 64; the symbol, 1 … 12 distinct corridor indices (sorted); an
// action budget 1 … 24 (widened from 1 … 16 by feature 452 (R02-G16-02) T-R02G1602-002 for the manifest's budgets
// 8 … 19); a difficulty 1 … 5 and whether a tutorial precedes play. Its fingerprint is the SHA-256 hex of its canonical
// JSON (schema 1, sorted keys, fingerprint excluded); the stored form is re-checked on decode. Stars, corridors and
// progress are named in words (FR-R02G1601-013); star numbers are their indices. Modelled on `VoxelOrigamiLevel`
// (feature 441).
import Foundation
import VisualCoreMath

/// An immutable, fingerprinted Starlit Cartouche level.
public struct StarlitCartoucheLevel: Sendable, Equatable {
    /// The stored-form schema.
    public static let schema: Int = 1
    /// The difficulty range.
    public static let difficulties: ClosedRange<Int> = 1...5
    /// The star count range.
    public static let starCounts: ClosedRange<Int> = 4...12
    /// The orbit length range.
    public static let orbitLengths: ClosedRange<Int> = 1...4
    /// The coordinate range of every orbit position.
    public static let coordinates: ClosedRange<Int> = -8...8
    /// The glyph grid's coordinate range.
    public static let glyphCells: ClosedRange<Int> = 0...4
    /// The range range.
    public static let ranges: ClosedRange<Int> = 1...12
    /// The most corridors.
    public static let maxCorridors: Int = 24
    /// The travel time range.
    public static let travels: ClosedRange<Int> = 1...3
    /// The most hazards.
    public static let maxHazards: Int = 8
    /// The deadline range.
    public static let deadlines: ClosedRange<Int> = 1...64
    /// The symbol's stroke count range.
    public static let strokeCounts: ClosedRange<Int> = 1...12
    /// The budget range.
    public static let budgets: ClosedRange<Int> = 1...24

    /// The level id, a lowercase slug.
    public let id: String
    /// The seed the level was built from.
    public let seed: UInt64
    /// The difficulty, 1 … 5.
    public let difficulty: Int
    /// The stars.
    public let stars: [StarlitCartoucheStar]
    /// The range r: a corridor is flyable when its stars are at most r apart.
    public let range: Int
    /// The corridors.
    public let corridors: [StarlitCartoucheCorridor]
    /// The hazard tubes.
    public let hazards: [StarlitCartoucheHazard]
    /// The star the ship starts at, at beat 0.
    public let start: Int
    /// The star the route must end at.
    public let beacon: Int
    /// The last beat any leg may arrive.
    public let deadline: Int
    /// The symbol's strokes: sorted, distinct corridor indices.
    public let symbol: [Int]
    /// The action budget, 1 … 24 (1 … 16 until feature 452 widened it for the manifest's budgets 8 … 19).
    public let budget: Int
    /// Whether a tutorial precedes play.
    public let tutorial: Bool
    /// The SHA-256 hex of the canonical JSON content.
    public let fingerprint: String

    /// A level of the given values, checked.
    ///
    /// - Throws: `.level(name)` naming the first value outside its range or rule.
    public init(id: String, seed: UInt64, difficulty: Int, stars: [StarlitCartoucheStar], range: Int,
                corridors: [StarlitCartoucheCorridor], hazards: [StarlitCartoucheHazard], start: Int, beacon: Int,
                deadline: Int, symbol: [Int], budget: Int, tutorial: Bool = false) throws(StarlitCartoucheError) {
        guard Self.isSlug(id) else { throw .level("id") }
        guard Self.difficulties.contains(difficulty) else { throw .level("difficulty") }
        guard Self.starCounts.contains(stars.count) else { throw .level("stars") }
        guard Self.deadlines.contains(deadline) else { throw .level("deadline") }
        var glyphs: Set<StarlitCartoucheGlyphPoint> = []
        for star in stars {
            guard Self.orbitLengths.contains(star.orbit.count) else { throw .level("orbit") }
            for p in star.orbit {
                guard Self.coordinates.contains(p.x), Self.coordinates.contains(p.y), Self.coordinates.contains(p.z)
                else { throw .level("position") }
            }
            guard Self.glyphCells.contains(star.glyph.x), Self.glyphCells.contains(star.glyph.y) else {
                throw .level("glyph")
            }
            guard glyphs.insert(star.glyph).inserted else { throw .level("glyph repeated") }
            guard star.open >= 0, star.open <= star.close, star.close <= Self.deadlines.upperBound else {
                throw .level("window")
            }
        }
        guard Self.ranges.contains(range) else { throw .level("range") }
        guard corridors.count <= Self.maxCorridors else { throw .level("corridors") }
        var pairs: Set<[Int]> = []
        for corridor in corridors {
            guard corridor.a >= 0, corridor.b < stars.count, corridor.a < corridor.b else { throw .level("corridor") }
            guard Self.travels.contains(corridor.travel) else { throw .level("travel") }
            guard pairs.insert([corridor.a, corridor.b]).inserted else { throw .level("corridor repeated") }
        }
        guard hazards.count <= Self.maxHazards else { throw .level("hazards") }
        for hazard in hazards {
            guard hazard.corridor >= 0, hazard.corridor < corridors.count else { throw .level("hazard corridor") }
            guard hazard.from >= 0, hazard.from <= hazard.to else { throw .level("hazard interval") }
        }
        guard start >= 0, start < stars.count, stars[start].admits(0) else { throw .level("start") }
        guard beacon >= 0, beacon < stars.count else { throw .level("beacon") }
        guard Self.strokeCounts.contains(symbol.count), Self.isSortedDistinct(symbol) else { throw .level("symbol") }
        for stroke in symbol {
            guard stroke >= 0, stroke < corridors.count else { throw .level("symbol stroke") }
        }
        guard Self.budgets.contains(budget) else { throw .level("budget") }
        let content = Content(schema: Self.schema, id: id, seed: seed, difficulty: difficulty, stars: stars,
                              range: range, corridors: corridors, hazards: hazards, start: start, beacon: beacon,
                              deadline: deadline, symbol: symbol, budget: budget, tutorial: tutorial)
        guard let data = try? Self.encoder.encode(content) else { throw .malformed("encode") }
        self.id = id
        self.seed = seed
        self.difficulty = difficulty
        self.stars = stars
        self.range = range
        self.corridors = corridors
        self.hazards = hazards
        self.start = start
        self.beacon = beacon
        self.deadline = deadline
        self.symbol = symbol
        self.budget = budget
        self.tutorial = tutorial
        self.fingerprint = StableHash.sha256Hex(Array(data))
    }

    /// The truth metric of the starting route (the ship at the start star at beat 0, nothing drawn).
    public var startReport: StarlitCartoucheRouteReport {
        StarlitCartoucheChart.report(self, star: start, beat: 0, drawn: [], legs: [])
    }

    /// "star 3".
    public func starName(_ index: Int) -> String { "star \(index)" }

    /// "the corridor between star 1 and star 4".
    public func corridorName(_ index: Int) -> String {
        let corridor: StarlitCartoucheCorridor = corridors[index]
        return "the corridor between \(starName(corridor.a)) and \(starName(corridor.b))"
    }

    /// The progress in words: the ship's star and beat, strokes drawn of the symbol, missing strokes, the beats left to
    /// the deadline and the actions left.
    public func progressDescription(report: StarlitCartoucheRouteReport, actionsLeft: Int) -> String {
        var parts: [String] = ["at \(starName(report.star)), beat \(report.beat)"]
        let drawnInSymbol: Int = symbol.count - report.missing.count
        parts.append("\(drawnInSymbol) of \(symbol.count) strokes drawn")
        if report.missing.isEmpty {
            parts.append(report.star == beacon ? "the cartouche is complete" : "fly to the beacon, \(starName(beacon))")
        }
        if !report.stray.isEmpty { parts.append("\(report.stray.count) stray strokes") }
        let beatsLeft: Int = max(deadline - report.beat, 0)
        parts.append(beatsLeft == 1 ? "1 beat to the deadline" : "\(beatsLeft) beats to the deadline")
        parts.append(actionsLeft == 1 ? "1 action left" : "\(actionsLeft) actions left")
        return parts.joined(separator: "; ")
    }

    /// Whether `values` are strictly increasing.
    static func isSortedDistinct(_ values: [Int]) -> Bool {
        var previous: Int? = nil
        for value in values {
            if let last = previous, !(last < value) { return false }
            previous = value
        }
        return true
    }

    /// The stored form: JSON with sorted keys holding the schema, every field and the fingerprint.
    public func encoded() -> Data {
        do {
            return try Self.encoder.encode(Stored(content: Content(level: self), fingerprint: fingerprint))
        } catch {
            preconditionFailure("a Starlit Cartouche level of checked values always encodes: \(error)")
        }
    }

    /// Decodes a stored level, re-checking every rule and the fingerprint.
    ///
    /// - Throws: `.newerSchema(s)` above ``schema``; `.malformed(description)` for unreadable JSON, missing keys, a
    ///   schema below 1, any refusal of the initialiser (its reason code) or a fingerprint that does not match.
    public static func decode(_ data: Data) throws(StarlitCartoucheError) -> StarlitCartoucheLevel {
        struct Probe: Decodable { let schema: Int }
        let probe: Probe
        do { probe = try JSONDecoder().decode(Probe.self, from: data) } catch { throw .malformed("unreadable") }
        guard probe.schema <= schema else { throw .newerSchema(probe.schema) }
        guard probe.schema >= 1 else { throw .malformed("schema \(probe.schema)") }
        let stored: Stored
        do { stored = try JSONDecoder().decode(Stored.self, from: data) } catch { throw .malformed("unreadable") }
        let level: StarlitCartoucheLevel
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
        let stars: [StarlitCartoucheStar]
        let range: Int
        let corridors: [StarlitCartoucheCorridor]
        let hazards: [StarlitCartoucheHazard]
        let start: Int
        let beacon: Int
        let deadline: Int
        let symbol: [Int]
        let budget: Int
        let tutorial: Bool

        init(schema: Int, id: String, seed: UInt64, difficulty: Int, stars: [StarlitCartoucheStar], range: Int,
             corridors: [StarlitCartoucheCorridor], hazards: [StarlitCartoucheHazard], start: Int, beacon: Int,
             deadline: Int, symbol: [Int], budget: Int, tutorial: Bool) {
            self.schema = schema
            self.id = id
            self.seed = seed
            self.difficulty = difficulty
            self.stars = stars
            self.range = range
            self.corridors = corridors
            self.hazards = hazards
            self.start = start
            self.beacon = beacon
            self.deadline = deadline
            self.symbol = symbol
            self.budget = budget
            self.tutorial = tutorial
        }

        init(level: StarlitCartoucheLevel) {
            self.init(schema: StarlitCartoucheLevel.schema, id: level.id, seed: level.seed,
                      difficulty: level.difficulty, stars: level.stars, range: level.range,
                      corridors: level.corridors, hazards: level.hazards, start: level.start, beacon: level.beacon,
                      deadline: level.deadline, symbol: level.symbol, budget: level.budget, tutorial: level.tutorial)
        }

        /// The level of this content, re-checked.
        func level() throws(StarlitCartoucheError) -> StarlitCartoucheLevel {
            try StarlitCartoucheLevel(id: id, seed: seed, difficulty: difficulty, stars: stars, range: range,
                                      corridors: corridors, hazards: hazards, start: start, beacon: beacon,
                                      deadline: deadline, symbol: symbol, budget: budget, tutorial: tutorial)
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

extension StarlitCartoucheLevel: Codable {
    /// Decodes a level through ``decode(_:)``'s rules.
    public init(from decoder: any Decoder) throws {
        let stored = try Stored(from: decoder)
        guard stored.content.schema <= Self.schema else {
            let code = StarlitCartoucheError.newerSchema(stored.content.schema).reasonCode
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: code))
        }
        do {
            self = try stored.content.level()
        } catch {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: error.reasonCode))
        }
        guard fingerprint == stored.fingerprint else {
            let code = StarlitCartoucheError.malformed("fingerprint").reasonCode
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: code))
        }
    }

    /// Encodes the stored form.
    public func encode(to encoder: any Encoder) throws {
        try Stored(content: Content(level: self), fingerprint: fingerprint).encode(to: encoder)
    }
}
