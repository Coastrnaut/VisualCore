// ColorfallCanyonsLevel — feature 341 (R02-G05-01) T-R02G0501-002 (FR-R02G0501-001, 009, 013; clarifications Q1, Q5).
// An immutable Colorfall Canyons level: a grid of 4 … 12 columns by 4 … 10 rows of cells with heights 0 … 15 and a
// ground (open, rock or drain), 1 … 3 springs and 1 … 4 basins placed on distinct open cells, at least one drain, a flow
// rate (1 … 8 units per tick), an action budget (1 … 30), a tick limit (1 … 3,600 ticks of 1/60 s), a difficulty (1 … 5)
// and whether a tutorial precedes play. Cells are indexed row-major (index = row · columns + column). Its fingerprint is
// the SHA-256 hex of its canonical JSON (sorted keys, fingerprint excluded); the stored form is re-checked on decode.
import Foundation
import VisualCoreMath

/// One of the three colours of light-fluid.
public enum ColorfallCanyonsColor: Int, Sendable, Codable, CaseIterable, Hashable {
    /// Electric cyan.
    case cyan = 0
    /// Coral.
    case coral = 1
    /// Yellow.
    case yellow = 2

    /// The colour's name in words, for players who do not tell the colours apart (FR-R02G0501-013).
    public var name: String {
        switch self {
        case .cyan: "cyan"
        case .coral: "coral"
        case .yellow: "yellow"
        }
    }
}

/// The ground of a cell, as stored in a level.
public enum ColorfallCanyonsGround: Int, Sendable, Codable, CaseIterable, Hashable {
    /// Open ground: holds and passes fluid; springs and basins sit on open ground.
    case open = 0
    /// Rock: never holds or passes fluid.
    case rock = 1
    /// A drain: receives fluid and counts it as spilled.
    case drain = 2
}

/// What a cell is, with springs and basins resolved.
public enum ColorfallCanyonsCellKind: Sendable, Hashable {
    /// Open ground.
    case open
    /// Rock.
    case rock
    /// The spring of the given index.
    case spring(Int)
    /// The basin of the given index.
    case basin(Int)
    /// A drain.
    case drain
}

/// A spring of one colour.
public struct ColorfallCanyonsSpring: Sendable, Hashable, Codable {
    /// The cell the spring sits on.
    public let cell: Int
    /// The colour it releases.
    public let color: ColorfallCanyonsColor
    /// The units it releases per tick while open and not dry, 1 … 4.
    public let release: Int
    /// The units it can release in all, 1 … 999.
    public let supply: Int
    /// Whether its valve is open when play begins.
    public let open: Bool

    /// A spring of the given values (checked by the level).
    public init(cell: Int, color: ColorfallCanyonsColor, release: Int, supply: Int, open: Bool) {
        self.cell = cell
        self.color = color
        self.release = release
        self.supply = supply
        self.open = open
    }
}

/// A basin with its required fill and colour mix.
public struct ColorfallCanyonsBasin: Sendable, Hashable, Codable {
    /// The cell the basin sits on.
    public let cell: Int
    /// The most units it may hold, 1 … 999; more is an overflow.
    public let capacity: Int
    /// The units it must hold for a win, 0 … capacity (0: no target, but contamination and overflow still count).
    public let fill: Int
    /// The required share of each colour in per mille, three values summing to 1,000.
    public let shares: [Int]
    /// The tolerance of every colour's share in per mille, 0 … 500.
    public let tolerance: Int
    /// Whether wrong colour (a colour whose share is 0) beyond ``toleratedWrong`` fails the level.
    public let isProtected: Bool
    /// The wrong-colour units a protected basin tolerates, 0 … 999.
    public let toleratedWrong: Int

    /// A basin of the given values (checked by the level).
    public init(cell: Int, capacity: Int, fill: Int, shares: [Int], tolerance: Int, isProtected: Bool,
                toleratedWrong: Int) {
        self.cell = cell
        self.capacity = capacity
        self.fill = fill
        self.shares = shares
        self.tolerance = tolerance
        self.isProtected = isProtected
        self.toleratedWrong = toleratedWrong
    }

    /// The units of wrong colour (colours whose required share is 0) in `masses`.
    public func wrongMass(_ masses: [Int]) -> Int {
        var wrong: Int = 0
        for color in ColorfallCanyonsColor.allCases where shares[color.rawValue] == 0 { wrong += masses[color.rawValue] }
        return wrong
    }

    /// Whether `masses` meets the basin's target: at least ``fill`` units and, for every colour c,
    /// |1,000 · mass_c − share_c · volume| ≤ tolerance · volume. A basin with fill 0 always meets it.
    public func accepts(_ masses: [Int]) -> Bool {
        guard fill > 0 else { return true }
        let volume: Int = masses.reduce(0, +)
        guard volume >= fill else { return false }
        for c in 0..<3 where abs(1_000 * masses[c] - shares[c] * volume) > tolerance * volume { return false }
        return true
    }

    /// The required mix in words and amounts, e.g. "at least 12 units: cyan 500 ± 100 per mille, coral 500 ± 100 per
    /// mille, yellow none" (FR-R02G0501-013).
    public var description: String {
        let parts: [String] = ColorfallCanyonsColor.allCases.map { color in
            let share: Int = shares[color.rawValue]
            return share == 0 ? "\(color.name) none" : "\(color.name) \(share) ± \(tolerance) per mille"
        }
        let head: String = fill == 0 ? "no target fill" : "at least \(fill) units"
        return head + ": " + parts.joined(separator: ", ") + (isProtected ? ", protected (\(toleratedWrong) wrong units tolerated)" : "")
    }
}

/// An immutable, fingerprinted Colorfall Canyons level.
public struct ColorfallCanyonsLevel: Sendable, Equatable {
    /// The stored-form schema.
    public static var schema: Int { 1 }
    /// The column counts a level may have.
    public static let columnRange: ClosedRange<Int> = 4...12
    /// The row counts a level may have.
    public static let rowRange: ClosedRange<Int> = 4...10
    /// The heights a cell may have.
    public static let heights: ClosedRange<Int> = 0...15
    /// The flow rates a level may have.
    public static let flowRates: ClosedRange<Int> = 1...8
    /// The action budgets a level may have.
    public static let budgets: ClosedRange<Int> = 1...30
    /// The tick limits a level may have (60 s at 1/60 s per tick).
    public static let tickLimits: ClosedRange<Int> = 1...3_600
    /// The fixed tick, in seconds.
    public static let tickSeconds: Double = 1.0 / 60.0

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
    /// The starting height of every cell, row-major.
    public let heights: [Int]
    /// The ground of every cell, row-major.
    public let grounds: [ColorfallCanyonsGround]
    /// The springs, 1 … 3.
    public let springs: [ColorfallCanyonsSpring]
    /// The basins, 1 … 4.
    public let basins: [ColorfallCanyonsBasin]
    /// The units an open cell passes downhill per tick at most.
    public let flowRate: Int
    /// The carves and valve toggles a play may spend.
    public let budget: Int
    /// The tick at which an undecided play fails (`time`).
    public let tickLimit: Int
    /// Whether a tutorial precedes play.
    public let tutorial: Bool
    /// The SHA-256 hex of the canonical JSON.
    public let fingerprint: String

    /// A level; refuses any value outside its range and any broken placement rule.
    ///
    /// - Throws: `.level(name)` for `"id"`, `"difficulty"`, `"columns"`, `"rows"`, `"heights"`, `"grounds"`,
    ///   `"springs"`, `"spring"`, `"basins"`, `"basin"`, `"placement"`, `"drain"`, `"target"`, `"flow-rate"`,
    ///   `"budget"` or `"tick-limit"`.
    public init(id: String, seed: UInt64, difficulty: Int, columns: Int, rows: Int, heights: [Int],
                grounds: [ColorfallCanyonsGround], springs: [ColorfallCanyonsSpring], basins: [ColorfallCanyonsBasin],
                flowRate: Int, budget: Int, tickLimit: Int, tutorial: Bool = false) throws(ColorfallCanyonsError) {
        guard Self.isSlug(id) else { throw .level("id") }
        guard (1...5).contains(difficulty) else { throw .level("difficulty") }
        guard Self.columnRange.contains(columns) else { throw .level("columns") }
        guard Self.rowRange.contains(rows) else { throw .level("rows") }
        let count: Int = columns * rows
        guard heights.count == count, heights.allSatisfy({ Self.heights.contains($0) }) else { throw .level("heights") }
        guard grounds.count == count else { throw .level("grounds") }
        guard (1...3).contains(springs.count) else { throw .level("springs") }
        for spring in springs {
            guard (0..<count).contains(spring.cell), (1...4).contains(spring.release), (1...999).contains(spring.supply)
            else { throw .level("spring") }
        }
        guard (1...4).contains(basins.count) else { throw .level("basins") }
        for basin in basins {
            guard (0..<count).contains(basin.cell), (1...999).contains(basin.capacity),
                  (0...basin.capacity).contains(basin.fill), basin.shares.count == 3,
                  basin.shares.allSatisfy({ (0...1_000).contains($0) }), basin.shares.reduce(0, +) == 1_000,
                  (0...500).contains(basin.tolerance), (0...999).contains(basin.toleratedWrong)
            else { throw .level("basin") }
        }
        let placed: [Int] = springs.map(\.cell) + basins.map(\.cell)
        guard Set(placed).count == placed.count, placed.allSatisfy({ grounds[$0] == .open }) else {
            throw .level("placement")
        }
        guard grounds.contains(.drain) else { throw .level("drain") }
        guard basins.contains(where: { $0.fill > 0 }) else { throw .level("target") }
        guard Self.flowRates.contains(flowRate) else { throw .level("flow-rate") }
        guard Self.budgets.contains(budget) else { throw .level("budget") }
        guard Self.tickLimits.contains(tickLimit) else { throw .level("tick-limit") }
        let content = Content(schema: Self.schema, id: id, seed: seed, difficulty: difficulty, columns: columns,
                              rows: rows, heights: heights, grounds: grounds, springs: springs, basins: basins,
                              flowRate: flowRate, budget: budget, tickLimit: tickLimit, tutorial: tutorial)
        guard let data = try? Self.encoder.encode(content) else { throw .malformed("encode") }
        self.id = id
        self.seed = seed
        self.difficulty = difficulty
        self.columns = columns
        self.rows = rows
        self.heights = heights
        self.grounds = grounds
        self.springs = springs
        self.basins = basins
        self.flowRate = flowRate
        self.budget = budget
        self.tickLimit = tickLimit
        self.tutorial = tutorial
        self.fingerprint = StableHash.sha256Hex(Array(data))
    }

    /// The number of cells.
    public var cellCount: Int { columns * rows }

    /// What `cell` is: a spring or basin when one sits on it, else its ground.
    public func kind(of cell: Int) -> ColorfallCanyonsCellKind {
        if let s = springs.firstIndex(where: { $0.cell == cell }) { return .spring(s) }
        if let b = basins.firstIndex(where: { $0.cell == cell }) { return .basin(b) }
        switch grounds[cell] {
        case .open: return .open
        case .rock: return .rock
        case .drain: return .drain
        }
    }

    /// The in-grid 4-neighbours of `cell` in the fixed order east, south, west, north.
    public func neighbours(of cell: Int) -> [Int] {
        let column: Int = cell % columns
        let row: Int = cell / columns
        var result: [Int] = []
        if column + 1 < columns { result.append(cell + 1) }
        if row + 1 < rows { result.append(cell + columns) }
        if column > 0 { result.append(cell - 1) }
        if row > 0 { result.append(cell - columns) }
        return result
    }

    /// Whether `cell` may be carved at the given current heights: open ground without a spring or basin, above height 0.
    public func isCarvable(_ cell: Int, heights current: [Int]) -> Bool {
        guard (0..<cellCount).contains(cell), current.count == cellCount else { return false }
        guard case .open = kind(of: cell) else { return false }
        return current[cell] > 0
    }

    /// The stored form: JSON with sorted keys holding the schema, every field and the fingerprint.
    public func encoded() -> Data {
        do {
            return try Self.encoder.encode(Stored(content: Content(level: self), fingerprint: fingerprint))
        } catch {
            preconditionFailure("a Colorfall Canyons level of checked integers always encodes: \(error)")
        }
    }

    /// Decodes a stored level, re-checking every rule and the fingerprint.
    ///
    /// - Throws: `.newerSchema(s)` above ``schema``; `.malformed(description)` for unreadable JSON, missing keys, a schema
    ///   below 1, any refusal of the initialiser or a fingerprint that does not match.
    public static func decode(_ data: Data) throws(ColorfallCanyonsError) -> ColorfallCanyonsLevel {
        struct Probe: Decodable { let schema: Int }
        let probe: Probe
        do { probe = try JSONDecoder().decode(Probe.self, from: data) } catch { throw .malformed("unreadable") }
        guard probe.schema <= schema else { throw .newerSchema(probe.schema) }
        guard probe.schema >= 1 else { throw .malformed("schema \(probe.schema)") }
        let stored: Stored
        do { stored = try JSONDecoder().decode(Stored.self, from: data) } catch { throw .malformed("unreadable") }
        let level: ColorfallCanyonsLevel
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
        let columns: Int
        let rows: Int
        let heights: [Int]
        let grounds: [ColorfallCanyonsGround]
        let springs: [ColorfallCanyonsSpring]
        let basins: [ColorfallCanyonsBasin]
        let flowRate: Int
        let budget: Int
        let tickLimit: Int
        let tutorial: Bool

        init(schema: Int, id: String, seed: UInt64, difficulty: Int, columns: Int, rows: Int, heights: [Int],
             grounds: [ColorfallCanyonsGround], springs: [ColorfallCanyonsSpring], basins: [ColorfallCanyonsBasin],
             flowRate: Int, budget: Int, tickLimit: Int, tutorial: Bool) {
            self.schema = schema
            self.id = id
            self.seed = seed
            self.difficulty = difficulty
            self.columns = columns
            self.rows = rows
            self.heights = heights
            self.grounds = grounds
            self.springs = springs
            self.basins = basins
            self.flowRate = flowRate
            self.budget = budget
            self.tickLimit = tickLimit
            self.tutorial = tutorial
        }

        init(level: ColorfallCanyonsLevel) {
            self.init(schema: ColorfallCanyonsLevel.schema, id: level.id, seed: level.seed,
                      difficulty: level.difficulty, columns: level.columns, rows: level.rows, heights: level.heights,
                      grounds: level.grounds, springs: level.springs, basins: level.basins, flowRate: level.flowRate,
                      budget: level.budget, tickLimit: level.tickLimit, tutorial: level.tutorial)
        }

        /// The level of this content, re-checked.
        func level() throws(ColorfallCanyonsError) -> ColorfallCanyonsLevel {
            try ColorfallCanyonsLevel(id: id, seed: seed, difficulty: difficulty, columns: columns, rows: rows,
                                      heights: heights, grounds: grounds, springs: springs, basins: basins,
                                      flowRate: flowRate, budget: budget, tickLimit: tickLimit, tutorial: tutorial)
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

extension ColorfallCanyonsLevel: Codable {
    /// Decodes a level through ``decode(_:)``'s rules.
    public init(from decoder: any Decoder) throws {
        let stored = try Stored(from: decoder)
        guard stored.content.schema <= Self.schema else {
            let code = ColorfallCanyonsError.newerSchema(stored.content.schema).reasonCode
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: code))
        }
        do {
            self = try stored.content.level()
        } catch {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: error.reasonCode))
        }
        guard fingerprint == stored.fingerprint else {
            let code = ColorfallCanyonsError.malformed("fingerprint").reasonCode
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: code))
        }
    }

    /// Encodes the stored form.
    public func encode(to encoder: any Encoder) throws {
        try Stored(content: Content(level: self), fingerprint: fingerprint).encode(to: encoder)
    }
}
