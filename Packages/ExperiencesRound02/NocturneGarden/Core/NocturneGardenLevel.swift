// NocturneGardenLevel — feature 381 (R02-G09-01) T-R02G0901-002 (FR-R02G0901-001, 009, 013; clarifications Q1, Q3,
// Q5). An immutable Nocturne Garden level: a bed of width 16 … 32 by height 12 … 24 cells; the target silhouette (a
// non-empty set of cells) and the forbidden regions (cells apart from the target), all inside the bed; the bloom supply
// (a count per kind, total 1 … 12); the allowed sizes (within 1 … 3) and sun elevations (within 1 … 4) with the
// opening sun among them; the move budget (1 … 40); the required match p / q (0 < p / q ≤ 1); the leak allowance
// (≥ 0); a difficulty (1 … 5) and whether a tutorial precedes play. Its fingerprint is the SHA-256 hex of its
// canonical JSON (schema 1, sorted keys, cells as sorted row-major indices, fingerprint excluded); the stored form is
// re-checked on decode. Blooms, regions and measures are named in words (FR-R02G0901-013).
import Foundation
import VisualCoreMath

/// An immutable, fingerprinted Nocturne Garden level.
public struct NocturneGardenLevel: Sendable, Equatable {
    /// The stored-form schema.
    public static var schema: Int { 1 }
    /// The allowed bed widths.
    public static let widths: ClosedRange<Int> = 16...32
    /// The allowed bed heights.
    public static let heights: ClosedRange<Int> = 12...24
    /// The allowed difficulties.
    public static let difficulties: ClosedRange<Int> = 1...5
    /// The allowed supply totals (blooms over all kinds).
    public static let supplyTotals: ClosedRange<Int> = 1...12
    /// The allowed move budgets.
    public static let budgets: ClosedRange<Int> = 1...40

    /// The level id, a lowercase slug.
    public let id: String
    /// The seed the level was built from.
    public let seed: UInt64
    /// The difficulty, 1 … 5.
    public let difficulty: Int
    /// The bed's width in cells.
    public let width: Int
    /// The bed's height in cells.
    public let height: Int
    /// The target silhouette: row-major cell indices.
    public let target: Set<Int>
    /// The forbidden regions: row-major cell indices, disjoint from the target.
    public let forbidden: Set<Int>
    /// The supply: blooms available per kind (kinds with none are absent).
    public let supply: [NocturneGardenKind: Int]
    /// The allowed bloom sizes.
    public let sizes: Set<Int>
    /// The allowed sun elevations.
    public let elevations: Set<Int>
    /// The opening sun elevation.
    public let sun: Int
    /// The moves a play may spend.
    public let budget: Int
    /// The required match: |M ∩ T| / |M ∪ T| must reach it.
    public let required: NocturneGardenRatio
    /// The most forbidden cells the mask may darken; one more fails the level.
    public let leakAllowance: Int
    /// Whether a tutorial precedes play.
    public let tutorial: Bool
    /// The SHA-256 hex of the canonical JSON.
    public let fingerprint: String

    /// A level; refuses any value outside its range and any broken rule.
    ///
    /// - Throws: `.level(name)` for `"id"`, `"difficulty"`, `"width"`, `"height"`, `"target"` (empty or outside the
    ///   bed), `"forbidden"` (outside the bed or on the target), `"supply"` (a negative count or a total outside 1 …
    ///   12), `"sizes"`, `"elevations"`, `"sun"` (not an allowed elevation), `"budget"` or `"leak"` (negative).
    public init(id: String, seed: UInt64, difficulty: Int, width: Int, height: Int, target: Set<Int>,
                forbidden: Set<Int>, supply: [NocturneGardenKind: Int], sizes: Set<Int>, elevations: Set<Int>,
                sun: Int, budget: Int, required: NocturneGardenRatio, leakAllowance: Int,
                tutorial: Bool = false) throws(NocturneGardenError) {
        guard Self.isSlug(id) else { throw .level("id") }
        guard Self.difficulties.contains(difficulty) else { throw .level("difficulty") }
        guard Self.widths.contains(width) else { throw .level("width") }
        guard Self.heights.contains(height) else { throw .level("height") }
        let cellCount: Int = width * height
        guard !target.isEmpty, target.allSatisfy({ $0 >= 0 && $0 < cellCount }) else { throw .level("target") }
        guard forbidden.allSatisfy({ $0 >= 0 && $0 < cellCount }), forbidden.isDisjoint(with: target) else {
            throw .level("forbidden")
        }
        var total: Int = 0
        var kept: [NocturneGardenKind: Int] = [:]
        for (kind, count) in supply {
            guard count >= 0 else { throw .level("supply") }
            total += count
            if count > 0 { kept[kind] = count }
        }
        guard Self.supplyTotals.contains(total) else { throw .level("supply") }
        guard !sizes.isEmpty, sizes.allSatisfy({ NocturneGardenBloom.sizes.contains($0) }) else {
            throw .level("sizes")
        }
        guard !elevations.isEmpty, elevations.allSatisfy({ NocturneGardenBloom.elevations.contains($0) }) else {
            throw .level("elevations")
        }
        guard elevations.contains(sun) else { throw .level("sun") }
        guard Self.budgets.contains(budget) else { throw .level("budget") }
        guard leakAllowance >= 0 else { throw .level("leak") }
        let content = Content(id: id, seed: seed, difficulty: difficulty, width: width, height: height,
                              target: target, forbidden: forbidden, supply: kept, sizes: sizes,
                              elevations: elevations, sun: sun, budget: budget, required: required,
                              leakAllowance: leakAllowance, tutorial: tutorial)
        guard let data = try? Self.encoder.encode(content) else { throw .malformed("encode") }
        self.id = id
        self.seed = seed
        self.difficulty = difficulty
        self.width = width
        self.height = height
        self.target = target
        self.forbidden = forbidden
        self.supply = kept
        self.sizes = sizes
        self.elevations = elevations
        self.sun = sun
        self.budget = budget
        self.required = required
        self.leakAllowance = leakAllowance
        self.tutorial = tutorial
        self.fingerprint = StableHash.sha256Hex(Array(data))
    }

    /// The number of `kind` the supply holds (0 when none).
    public func supplyCount(_ kind: NocturneGardenKind) -> Int { supply[kind] ?? 0 }

    /// The total supply over all kinds.
    public var supplyTotal: Int { supply.values.reduce(0, +) }

    /// The bed's cell count, width × height.
    public var cellCount: Int { width * height }

    /// The cell `index` in words: "column 3, row 0".
    public func cellName(_ index: Int) -> String {
        "column \(index % width), row \(index / width)"
    }

    /// The region of cell `index` in words: "target", "forbidden" or "open".
    public func regionName(_ index: Int) -> String {
        if target.contains(index) { return "target" }
        if forbidden.contains(index) { return "forbidden" }
        return "open"
    }

    /// Bloom `index` (0-based, canonical order) in words: "bloom 1: tulip at column 3, row 0, size 2".
    public func bloomName(_ index: Int, bloom: NocturneGardenBloom) -> String {
        "bloom \(index + 1): \(bloom.kind.name) at column \(bloom.column), row \(bloom.row), size \(bloom.size)"
    }

    /// The sun `elevation` in words: "sun 1 of 4, high, shadows half as tall" … "sun 4 of 4, low, shadows twice as
    /// tall".
    public static func sunName(_ elevation: Int) -> String {
        switch elevation {
        case 1: "sun 1 of 4, high, shadows half as tall"
        case 2: "sun 2 of 4, upper middle, shadows as tall as the blooms"
        case 3: "sun 3 of 4, lower middle, shadows one and a half times as tall"
        case 4: "sun 4 of 4, low, shadows twice as tall"
        default: "sun \(elevation)"
        }
    }

    /// `count` cells in words: "1 cell", "0 cells", "12 cells".
    public static func cellsText(_ count: Int) -> String {
        count == 1 ? "1 cell" : "\(count) cells"
    }

    /// The match in words: "match 12/16, needs 3/4" (shared cells over cells in either).
    public func matchText(shared: Int, either: Int) -> String {
        "match \(shared)/\(either), needs \(required.text)"
    }

    /// The leak in words: "leak 1 cell, 2 allowed".
    public func leakText(_ leak: Int) -> String {
        "leak \(Self.cellsText(leak)), \(leakAllowance) allowed"
    }

    /// The level in words: "target 24 cells; forbidden 10 cells; needs a match of 3/4 with a leak of at most 1 cell;
    /// 6 moves; 3 blooms: 2 tulip, 1 rose; sun 2 of 4, …".
    public func targetDescription() -> String {
        var parts: [String] = []
        for kind in NocturneGardenKind.allCases where supplyCount(kind) > 0 {
            parts.append("\(supplyCount(kind)) \(kind.name)")
        }
        let blooms: String = supplyTotal == 1 ? "1 bloom" : "\(supplyTotal) blooms"
        let moves: String = budget == 1 ? "1 move" : "\(budget) moves"
        return "target \(Self.cellsText(target.count)); forbidden \(Self.cellsText(forbidden.count)); "
            + "needs a match of \(required.text) with a leak of at most \(Self.cellsText(leakAllowance)); "
            + "\(moves); \(blooms): " + parts.joined(separator: ", ") + "; " + Self.sunName(sun)
    }

    /// The stored form: JSON with sorted keys holding the schema, every field and the fingerprint.
    public func encoded() -> Data {
        do {
            return try Self.encoder.encode(Stored(content: Content(level: self), fingerprint: fingerprint))
        } catch {
            preconditionFailure("a Nocturne Garden level of checked values always encodes: \(error)")
        }
    }

    /// Decodes a stored level, re-checking every rule and the fingerprint.
    ///
    /// - Throws: `.newerSchema(s)` above ``schema``; `.malformed(description)` for unreadable JSON, missing keys, a
    ///   schema below 1, any refusal of the initialiser (its reason code) or a fingerprint that does not match.
    public static func decode(_ data: Data) throws(NocturneGardenError) -> NocturneGardenLevel {
        struct Probe: Decodable { let schema: Int }
        let probe: Probe
        do { probe = try JSONDecoder().decode(Probe.self, from: data) } catch { throw .malformed("unreadable") }
        guard probe.schema <= schema else { throw .newerSchema(probe.schema) }
        guard probe.schema >= 1 else { throw .malformed("schema \(probe.schema)") }
        let stored: Stored
        do { stored = try JSONDecoder().decode(Stored.self, from: data) } catch { throw .malformed("unreadable") }
        let level: NocturneGardenLevel
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

    /// The fingerprinted content; cells and ranges as sorted arrays, the supply keyed by kind name.
    struct Content: Codable, Equatable {
        let schema: Int
        let id: String
        let seed: UInt64
        let difficulty: Int
        let width: Int
        let height: Int
        let target: [Int]
        let forbidden: [Int]
        let supply: [String: Int]
        let sizes: [Int]
        let elevations: [Int]
        let sun: Int
        let budget: Int
        let required: NocturneGardenRatio
        let leakAllowance: Int
        let tutorial: Bool

        init(id: String, seed: UInt64, difficulty: Int, width: Int, height: Int, target: Set<Int>,
             forbidden: Set<Int>, supply: [NocturneGardenKind: Int], sizes: Set<Int>, elevations: Set<Int>, sun: Int,
             budget: Int, required: NocturneGardenRatio, leakAllowance: Int, tutorial: Bool) {
            self.schema = NocturneGardenLevel.schema
            self.id = id
            self.seed = seed
            self.difficulty = difficulty
            self.width = width
            self.height = height
            self.target = target.sorted()
            self.forbidden = forbidden.sorted()
            var named: [String: Int] = [:]
            for (kind, count) in supply { named[kind.rawValue] = count }
            self.supply = named
            self.sizes = sizes.sorted()
            self.elevations = elevations.sorted()
            self.sun = sun
            self.budget = budget
            self.required = required
            self.leakAllowance = leakAllowance
            self.tutorial = tutorial
        }

        init(level: NocturneGardenLevel) {
            self.init(id: level.id, seed: level.seed, difficulty: level.difficulty, width: level.width,
                      height: level.height, target: level.target, forbidden: level.forbidden, supply: level.supply,
                      sizes: level.sizes, elevations: level.elevations, sun: level.sun, budget: level.budget,
                      required: level.required, leakAllowance: level.leakAllowance, tutorial: level.tutorial)
        }

        /// The level of this content, re-checked; an unknown kind name is refused as `"supply"`.
        func level() throws(NocturneGardenError) -> NocturneGardenLevel {
            var kinds: [NocturneGardenKind: Int] = [:]
            for (name, count) in supply {
                guard let kind = NocturneGardenKind(rawValue: name) else { throw .level("supply") }
                kinds[kind] = count
            }
            return try NocturneGardenLevel(id: id, seed: seed, difficulty: difficulty, width: width, height: height,
                                           target: Set(target), forbidden: Set(forbidden), supply: kinds,
                                           sizes: Set(sizes), elevations: Set(elevations), sun: sun, budget: budget,
                                           required: required, leakAllowance: leakAllowance, tutorial: tutorial)
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

extension NocturneGardenLevel: Codable {
    /// Decodes a level through ``decode(_:)``'s rules.
    public init(from decoder: any Decoder) throws {
        let stored = try Stored(from: decoder)
        guard stored.content.schema <= Self.schema else {
            let code = NocturneGardenError.newerSchema(stored.content.schema).reasonCode
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: code))
        }
        do {
            self = try stored.content.level()
        } catch {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: error.reasonCode))
        }
        guard fingerprint == stored.fingerprint else {
            let code = NocturneGardenError.malformed("fingerprint").reasonCode
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: code))
        }
    }

    /// Encodes the stored form.
    public func encode(to encoder: any Encoder) throws {
        try Stored(content: Content(level: self), fingerprint: fingerprint).encode(to: encoder)
    }
}
