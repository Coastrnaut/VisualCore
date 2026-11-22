// AmethystEscapeLevel — feature 361 (R02-G07-01) T-R02G0701-002 (FR-R02G0701-001, 009, 013; clarifications Q1, Q5). An
// immutable Amethyst Escape level: N = 6 … 12 sectors and 2 … 5 nested shells numbered 0 (innermost) … K − 1 (outermost).
// Each shell lists, in its own sectors 0 … N − 1, its outer apertures (non-empty; the outermost shell has exactly one, the
// exit gap), its radial walls (wall j stands between its sectors j and j + 1 mod N; at most N − 1) and its blocked wedges
// (never every sector). The pearl starts in shell 0 at a sector that is not blocked, with every shell at offset 0. A move
// budget (1 … 60), a difficulty (1 … 5) and whether a tutorial precedes play complete it. Its fingerprint is the SHA-256 hex
// of its canonical JSON (sorted keys, fingerprint excluded); the stored form is re-checked on decode.
import Foundation
import VisualCoreMath

/// One shell of the crystal, in its own sectors.
public struct AmethystEscapeShell: Sendable, Hashable, Codable {
    /// The own sectors whose outer wall is open, sorted.
    public let apertures: [Int]
    /// The radial walls, sorted: wall j stands between own sectors j and j + 1 mod N.
    public let walls: [Int]
    /// The own sectors that are blocked wedges, sorted.
    public let blocked: [Int]

    /// A shell (sorted here; the level checks it).
    public init(apertures: [Int], walls: [Int] = [], blocked: [Int] = []) {
        self.apertures = Array(Set(apertures)).sorted()
        self.walls = Array(Set(walls)).sorted()
        self.blocked = Array(Set(blocked)).sorted()
    }

    /// Whether own sector `sector` has an outer aperture.
    public func isOpen(_ sector: Int) -> Bool { apertures.contains(sector) }

    /// Whether wall `index` stands between own sectors `index` and `index + 1`.
    public func hasWall(_ index: Int) -> Bool { walls.contains(index) }

    /// Whether own sector `sector` is a blocked wedge.
    public func isBlocked(_ sector: Int) -> Bool { blocked.contains(sector) }
}

/// An immutable, fingerprinted Amethyst Escape level.
public struct AmethystEscapeLevel: Sendable, Equatable {
    /// The stored-form schema.
    public static var schema: Int { 1 }
    /// The allowed sector counts.
    public static let sectorCounts: ClosedRange<Int> = 6...12
    /// The allowed shell counts.
    public static let shellCounts: ClosedRange<Int> = 2...5
    /// The allowed move budgets.
    public static let budgets: ClosedRange<Int> = 1...60

    /// The level id, a lowercase slug.
    public let id: String
    /// The seed the level was built from.
    public let seed: UInt64
    /// The difficulty, 1 … 5.
    public let difficulty: Int
    /// The number of sectors N of every shell.
    public let sectors: Int
    /// The shells, innermost first.
    public let shells: [AmethystEscapeShell]
    /// The pearl's starting sector in shell 0.
    public let start: Int
    /// The moves (rotations and advances) a play may spend.
    public let budget: Int
    /// Whether a tutorial precedes play.
    public let tutorial: Bool
    /// The SHA-256 hex of the canonical JSON.
    public let fingerprint: String

    /// A level; refuses any value outside its range and any broken shell rule.
    ///
    /// - Throws: `.level(name)` for `"id"`, `"difficulty"`, `"sectors"`, `"shells"`, `"apertures"`, `"exit"`, `"walls"`,
    ///   `"blocked"`, `"order"`, `"start"` or `"budget"`.
    public init(id: String, seed: UInt64, difficulty: Int, sectors: Int, shells: [AmethystEscapeShell], start: Int,
                budget: Int, tutorial: Bool = false) throws(AmethystEscapeError) {
        guard Self.isSlug(id) else { throw .level("id") }
        guard (1...5).contains(difficulty) else { throw .level("difficulty") }
        guard Self.sectorCounts.contains(sectors) else { throw .level("sectors") }
        guard Self.shellCounts.contains(shells.count) else { throw .level("shells") }
        let range: Range<Int> = 0..<sectors
        for shell in shells {
            guard Self.isCanonical(shell.apertures), Self.isCanonical(shell.walls), Self.isCanonical(shell.blocked) else {
                throw .level("order")
            }
            guard !shell.apertures.isEmpty, shell.apertures.allSatisfy(range.contains) else { throw .level("apertures") }
            guard shell.walls.count < sectors, shell.walls.allSatisfy(range.contains) else { throw .level("walls") }
            guard shell.blocked.count < sectors, shell.blocked.allSatisfy(range.contains) else { throw .level("blocked") }
        }
        guard shells[shells.count - 1].apertures.count == 1 else { throw .level("exit") }
        guard range.contains(start), !shells[0].isBlocked(start) else { throw .level("start") }
        guard Self.budgets.contains(budget) else { throw .level("budget") }
        let content = Content(schema: Self.schema, id: id, seed: seed, difficulty: difficulty, sectors: sectors,
                              shells: shells, start: start, budget: budget, tutorial: tutorial)
        guard let data = try? Self.encoder.encode(content) else { throw .malformed("encode") }
        self.id = id
        self.seed = seed
        self.difficulty = difficulty
        self.sectors = sectors
        self.shells = shells
        self.start = start
        self.budget = budget
        self.tutorial = tutorial
        self.fingerprint = StableHash.sha256Hex(Array(data))
    }

    /// The outermost shell's index, K − 1.
    public var outermost: Int { shells.count - 1 }

    /// The exit gap: the outermost shell's one aperture (its own sector).
    public var exitGap: Int { shells[outermost].apertures[0] }

    /// Shell `shell` in words: "shell 1 (inner)" … "shell K (outer)"; middle shells have no qualifier.
    public func shellName(_ shell: Int) -> String {
        if shell == 0 { return "shell 1 (inner)" }
        if shell == outermost { return "shell \(shell + 1) (outer)" }
        return "shell \(shell + 1)"
    }

    /// Sector `sector` in words: "sector s of N", 1-based.
    public func sectorName(_ sector: Int) -> String {
        "sector \(sector + 1) of \(sectors)"
    }

    /// Shell `shell` in words: its apertures, walls and blocked wedges by sector (FR-R02G0701-013).
    public func description(ofShell shell: Int) -> String {
        let s = shells[shell]
        func list(_ values: [Int]) -> String {
            values.isEmpty ? "none" : values.map { String($0 + 1) }.joined(separator: ", ")
        }
        let openings: String = shell == outermost ? "exit gap at sector \(exitGap + 1)" : "openings at sectors \(list(s.apertures))"
        return "\(shellName(shell)): \(openings); walls after sectors \(list(s.walls)); blocked sectors \(list(s.blocked))"
    }

    /// The stored form: JSON with sorted keys holding the schema, every field and the fingerprint.
    public func encoded() -> Data {
        do {
            return try Self.encoder.encode(Stored(content: Content(level: self), fingerprint: fingerprint))
        } catch {
            preconditionFailure("an Amethyst Escape level of checked integers always encodes: \(error)")
        }
    }

    /// Decodes a stored level, re-checking every rule and the fingerprint.
    ///
    /// - Throws: `.newerSchema(s)` above ``schema``; `.malformed(description)` for unreadable JSON, missing keys, a schema
    ///   below 1, any refusal of the initialiser or a fingerprint that does not match.
    public static func decode(_ data: Data) throws(AmethystEscapeError) -> AmethystEscapeLevel {
        struct Probe: Decodable { let schema: Int }
        let probe: Probe
        do { probe = try JSONDecoder().decode(Probe.self, from: data) } catch { throw .malformed("unreadable") }
        guard probe.schema <= schema else { throw .newerSchema(probe.schema) }
        guard probe.schema >= 1 else { throw .malformed("schema \(probe.schema)") }
        let stored: Stored
        do { stored = try JSONDecoder().decode(Stored.self, from: data) } catch { throw .malformed("unreadable") }
        let level: AmethystEscapeLevel
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

    /// Whether `values` is strictly increasing (sorted, no repeats), the canonical order of a shell's lists.
    static func isCanonical(_ values: [Int]) -> Bool {
        zip(values, values.dropFirst()).allSatisfy { $0 < $1 }
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
        let sectors: Int
        let shells: [AmethystEscapeShell]
        let start: Int
        let budget: Int
        let tutorial: Bool

        init(schema: Int, id: String, seed: UInt64, difficulty: Int, sectors: Int, shells: [AmethystEscapeShell],
             start: Int, budget: Int, tutorial: Bool) {
            self.schema = schema
            self.id = id
            self.seed = seed
            self.difficulty = difficulty
            self.sectors = sectors
            self.shells = shells
            self.start = start
            self.budget = budget
            self.tutorial = tutorial
        }

        init(level: AmethystEscapeLevel) {
            self.init(schema: AmethystEscapeLevel.schema, id: level.id, seed: level.seed, difficulty: level.difficulty,
                      sectors: level.sectors, shells: level.shells, start: level.start, budget: level.budget,
                      tutorial: level.tutorial)
        }

        /// The level of this content, re-checked.
        func level() throws(AmethystEscapeError) -> AmethystEscapeLevel {
            try AmethystEscapeLevel(id: id, seed: seed, difficulty: difficulty, sectors: sectors, shells: shells,
                                    start: start, budget: budget, tutorial: tutorial)
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

extension AmethystEscapeLevel: Codable {
    /// Decodes a level through ``decode(_:)``'s rules.
    public init(from decoder: any Decoder) throws {
        let stored = try Stored(from: decoder)
        guard stored.content.schema <= Self.schema else {
            let code = AmethystEscapeError.newerSchema(stored.content.schema).reasonCode
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: code))
        }
        do {
            self = try stored.content.level()
        } catch {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: error.reasonCode))
        }
        guard fingerprint == stored.fingerprint else {
            let code = AmethystEscapeError.malformed("fingerprint").reasonCode
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: code))
        }
    }

    /// Encodes the stored form.
    public func encode(to encoder: any Encoder) throws {
        try Stored(content: Content(level: self), fingerprint: fingerprint).encode(to: encoder)
    }
}
