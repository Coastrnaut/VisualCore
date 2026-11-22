// ChronoConstellatorLevel — feature 351 (R02-G06-01) T-R02G0601-002 (FR-R02G0601-001, 009, 013; clarifications Q1, Q5).
// An immutable Chrono Constellator level: a sky grid of 5 … 12 columns by 5 … 10 rows, 2 … 5 stars each travelling round
// its own closed loop of 4 … 32 distinct cells (consecutive cells and the last and the first are 4-neighbours) from a
// default start phase, each with a target cell on its loop (targets pairwise distinct), an edit budget (1 … 20), a tick
// limit (1 … 1,200 ticks of 1/120 s), a difficulty (1 … 5) and whether a tutorial precedes play. Cells are indexed
// row-major (index = row · columns + column). Its fingerprint is the SHA-256 hex of its canonical JSON (sorted keys,
// fingerprint excluded); the stored form is re-checked on decode.
import Foundation
import VisualCoreMath

/// The fixed shape of a star, so stars are told apart without colour (FR-R02G0601-013): star i has shape i.
public enum ChronoConstellatorShape: Int, Sendable, Codable, CaseIterable, Hashable {
    /// A ring (star 1).
    case ring = 0
    /// A cross (star 2).
    case cross = 1
    /// A diamond (star 3).
    case diamond = 2
    /// A triangle (star 4).
    case triangle = 3
    /// A square (star 5).
    case square = 4

    /// The shape's name in words.
    public var name: String {
        switch self {
        case .ring: "ring"
        case .cross: "cross"
        case .diamond: "diamond"
        case .triangle: "triangle"
        case .square: "square"
        }
    }
}

/// A star: its loop of cells, its default start phase and its target.
public struct ChronoConstellatorStar: Sendable, Hashable, Codable {
    /// The cells of the loop in travel order; the star moves from `loop[k]` to `loop[(k + 1) mod L]` on a tick.
    public let loop: [Int]
    /// The default start phase, an index into ``loop``.
    public let phase: Int
    /// The target cell, which lies on ``loop``.
    public let target: Int

    /// A star (not checked; the level checks it).
    public init(loop: [Int], phase: Int, target: Int) {
        self.loop = loop
        self.phase = phase
        self.target = target
    }

    /// The loop length L.
    public var length: Int { loop.count }
}

/// An immutable, fingerprinted Chrono Constellator level.
public struct ChronoConstellatorLevel: Sendable, Equatable {
    /// The stored-form schema.
    public static var schema: Int { 1 }
    /// The allowed column counts.
    public static let columnRange: ClosedRange<Int> = 5...12
    /// The allowed row counts.
    public static let rowRange: ClosedRange<Int> = 5...10
    /// The allowed star counts.
    public static let starCounts: ClosedRange<Int> = 2...5
    /// The allowed loop lengths.
    public static let loopLengths: ClosedRange<Int> = 4...32
    /// The allowed edit budgets.
    public static let budgets: ClosedRange<Int> = 1...20
    /// The allowed tick limits.
    public static let tickLimits: ClosedRange<Int> = 1...1_200
    /// The fixed tick, in seconds (the catalog's 0.008333 s timestep).
    public static let tickSeconds: Double = 1.0 / 120.0

    /// The level id, a lowercase slug.
    public let id: String
    /// The seed the level was built from.
    public let seed: UInt64
    /// The difficulty, 1 … 5.
    public let difficulty: Int
    /// The number of columns.
    public let columns: Int
    /// The number of rows.
    public let rows: Int
    /// The stars, 2 … 5.
    public let stars: [ChronoConstellatorStar]
    /// The edits (changed phases plus holds) a timeline may have in use at once.
    public let budget: Int
    /// The tick at which an undecided play fails (`time`).
    public let tickLimit: Int
    /// Whether a tutorial precedes play.
    public let tutorial: Bool
    /// The SHA-256 hex of the canonical JSON.
    public let fingerprint: String

    /// A level; refuses any value outside its range and any broken loop or target rule.
    ///
    /// - Throws: `.level(name)` for `"id"`, `"difficulty"`, `"columns"`, `"rows"`, `"stars"`, `"loop"`, `"phase"`,
    ///   `"target"`, `"targets"`, `"budget"` or `"tick-limit"`.
    public init(id: String, seed: UInt64, difficulty: Int, columns: Int, rows: Int, stars: [ChronoConstellatorStar],
                budget: Int, tickLimit: Int, tutorial: Bool = false) throws(ChronoConstellatorError) {
        guard Self.isSlug(id) else { throw .level("id") }
        guard (1...5).contains(difficulty) else { throw .level("difficulty") }
        guard Self.columnRange.contains(columns) else { throw .level("columns") }
        guard Self.rowRange.contains(rows) else { throw .level("rows") }
        guard Self.starCounts.contains(stars.count) else { throw .level("stars") }
        let count: Int = columns * rows
        for star in stars {
            guard Self.isLoop(star.loop, columns: columns, count: count) else { throw .level("loop") }
            guard (0..<star.length).contains(star.phase) else { throw .level("phase") }
            guard star.loop.contains(star.target) else { throw .level("target") }
        }
        let targets: [Int] = stars.map(\.target)
        guard Set(targets).count == targets.count else { throw .level("targets") }
        guard Self.budgets.contains(budget) else { throw .level("budget") }
        guard Self.tickLimits.contains(tickLimit) else { throw .level("tick-limit") }
        let content = Content(schema: Self.schema, id: id, seed: seed, difficulty: difficulty, columns: columns,
                              rows: rows, stars: stars, budget: budget, tickLimit: tickLimit, tutorial: tutorial)
        guard let data = try? Self.encoder.encode(content) else { throw .malformed("encode") }
        self.id = id
        self.seed = seed
        self.difficulty = difficulty
        self.columns = columns
        self.rows = rows
        self.stars = stars
        self.budget = budget
        self.tickLimit = tickLimit
        self.tutorial = tutorial
        self.fingerprint = StableHash.sha256Hex(Array(data))
    }

    /// The number of cells.
    public var cellCount: Int { columns * rows }

    /// Whether cells `a` and `b` are 4-neighbours in a grid of `columns` columns (both assumed in the grid).
    public static func isNeighbour(_ a: Int, _ b: Int, columns: Int) -> Bool {
        let (ar, ac) = (a / columns, a % columns)
        let (br, bc) = (b / columns, b % columns)
        return abs(ar - br) + abs(ac - bc) == 1
    }

    /// Whether `a` and `b` are 4-neighbours in this level's grid.
    public func isNeighbour(_ a: Int, _ b: Int) -> Bool { Self.isNeighbour(a, b, columns: columns) }

    /// The shape of star `index` (star i has shape i).
    public static func shape(of index: Int) -> ChronoConstellatorShape {
        ChronoConstellatorShape(rawValue: index) ?? .ring
    }

    /// The row and column (1-based) of `cell` in words.
    public func place(_ cell: Int) -> String {
        "row \(cell / columns + 1), column \(cell % columns + 1)"
    }

    /// Star `index` in words, number and shape: "star n (shape): loop of L cells, target row r, column c"
    /// (FR-R02G0601-013).
    public func description(ofStar index: Int) -> String {
        let star = stars[index]
        return "star \(index + 1) (\(Self.shape(of: index).name)): loop of \(star.length) cells, target \(place(star.target))"
    }

    /// The stored form: JSON with sorted keys holding the schema, every field and the fingerprint.
    public func encoded() -> Data {
        do {
            return try Self.encoder.encode(Stored(content: Content(level: self), fingerprint: fingerprint))
        } catch {
            preconditionFailure("a Chrono Constellator level of checked integers always encodes: \(error)")
        }
    }

    /// Decodes a stored level, re-checking every rule and the fingerprint.
    ///
    /// - Throws: `.newerSchema(s)` above ``schema``; `.malformed(description)` for unreadable JSON, missing keys, a schema
    ///   below 1, any refusal of the initialiser or a fingerprint that does not match.
    public static func decode(_ data: Data) throws(ChronoConstellatorError) -> ChronoConstellatorLevel {
        struct Probe: Decodable { let schema: Int }
        let probe: Probe
        do { probe = try JSONDecoder().decode(Probe.self, from: data) } catch { throw .malformed("unreadable") }
        guard probe.schema <= schema else { throw .newerSchema(probe.schema) }
        guard probe.schema >= 1 else { throw .malformed("schema \(probe.schema)") }
        let stored: Stored
        do { stored = try JSONDecoder().decode(Stored.self, from: data) } catch { throw .malformed("unreadable") }
        let level: ChronoConstellatorLevel
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

    /// Whether `loop` is a closed loop of 4 … 32 distinct in-grid cells whose consecutive cells, and whose last and first
    /// cells, are 4-neighbours.
    static func isLoop(_ loop: [Int], columns: Int, count: Int) -> Bool {
        guard loopLengths.contains(loop.count), Set(loop).count == loop.count,
              loop.allSatisfy({ (0..<count).contains($0) }) else { return false }
        for index in 0..<loop.count {
            let next: Int = loop[(index + 1) % loop.count]
            guard isNeighbour(loop[index], next, columns: columns) else { return false }
        }
        return true
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
        let columns: Int
        let rows: Int
        let stars: [ChronoConstellatorStar]
        let budget: Int
        let tickLimit: Int
        let tutorial: Bool

        init(schema: Int, id: String, seed: UInt64, difficulty: Int, columns: Int, rows: Int,
             stars: [ChronoConstellatorStar], budget: Int, tickLimit: Int, tutorial: Bool) {
            self.schema = schema
            self.id = id
            self.seed = seed
            self.difficulty = difficulty
            self.columns = columns
            self.rows = rows
            self.stars = stars
            self.budget = budget
            self.tickLimit = tickLimit
            self.tutorial = tutorial
        }

        init(level: ChronoConstellatorLevel) {
            self.init(schema: ChronoConstellatorLevel.schema, id: level.id, seed: level.seed,
                      difficulty: level.difficulty, columns: level.columns, rows: level.rows, stars: level.stars,
                      budget: level.budget, tickLimit: level.tickLimit, tutorial: level.tutorial)
        }

        /// The level of this content, re-checked.
        func level() throws(ChronoConstellatorError) -> ChronoConstellatorLevel {
            try ChronoConstellatorLevel(id: id, seed: seed, difficulty: difficulty, columns: columns, rows: rows,
                                        stars: stars, budget: budget, tickLimit: tickLimit, tutorial: tutorial)
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

extension ChronoConstellatorLevel: Codable {
    /// Decodes a level through ``decode(_:)``'s rules.
    public init(from decoder: any Decoder) throws {
        let stored = try Stored(from: decoder)
        guard stored.content.schema <= Self.schema else {
            let code = ChronoConstellatorError.newerSchema(stored.content.schema).reasonCode
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: code))
        }
        do {
            self = try stored.content.level()
        } catch {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: error.reasonCode))
        }
        guard fingerprint == stored.fingerprint else {
            let code = ChronoConstellatorError.malformed("fingerprint").reasonCode
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: code))
        }
    }

    /// Encodes the stored form.
    public func encode(to encoder: any Encoder) throws {
        try Stored(content: Content(level: self), fingerprint: fingerprint).encode(to: encoder)
    }
}
