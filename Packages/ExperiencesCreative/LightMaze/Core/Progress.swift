// Progress — feature 098 (A13-P03) T-A13-302 (FR-A13-301, FR-A13-321; clarifications Q2, Q4; data-model "Progress",
// "LevelProgress"; contracts/progress.md). The device's level progression of Light Maze: for each of the 20 catalog
// levels, in catalog order, whether it is open, whether it is solved and the fewest moves it took.
//
// Written as JSON with sorted keys, at most 16 KB:
// `{"levels":[{"best":n|null,"id":"lm-01","open":true,"solved":false},…],"schema":1}`.
// `decode(_:catalog:)` refuses, in this order:
// - `too-large`: more than ``Progress/maxBytes`` bytes;
// - `damaged`: not JSON, truncated, no integer `schema`, a schema below 1;
// - `newer-version`: a schema above 1 (whatever else the payload holds);
// - `damaged`: a missing or malformed key, a level count other than the catalog's, an id other than the catalog id at
//   its position (unknown or reordered ids), level 1 not open, a solved level that is not open or whose best is not
//   1…999, or an unsolved level with a best.
// A refusal changes nothing; the caller continues from fresh progress (`Progress.fresh()`).
//
// Solving a level marks it solved, keeps the fewest moves (at least 1, at most 999) and opens the next level. The
// progress lives outside the engine state, so replays and fixtures do not depend on it.
import Foundation

/// Why a saved progress document was refused.
public enum ProgressRefusal: String, CaseIterable, Codable, Error, Sendable {
    /// Not JSON, truncated, or a missing, malformed, unknown or inconsistent value.
    case damaged = "damaged"
    /// More than ``Progress/maxBytes`` bytes.
    case tooLarge = "too-large"
    /// Written by a newer version (schema above ``Progress/schemaVersion``).
    case newerVersion = "newer-version"
}

/// The progress of one level: open, solved and the fewest moves it took.
///
/// Invariant: a solved level is open and has a best of 1…999; an unsolved level has no best.
public struct LevelProgress: Codable, Equatable, Sendable {
    /// The highest best a level can record.
    public static let maxBest = 999

    /// The catalog id of the level ("lm-01" …).
    public var id: String
    /// True when the level can be chosen.
    public var open: Bool
    /// True when the level has been solved at least once.
    public var solved: Bool
    /// The fewest moves the level was solved in (1…999), or nil while unsolved.
    public var best: Int?

    /// A level's progress with the given values (not checked; see ``isValid``).
    public init(id: String, open: Bool, solved: Bool, best: Int?) {
        self.id = id
        self.open = open
        self.solved = solved
        self.best = best
    }

    /// True when the invariant holds: solved ⇒ open and best 1…999; unsolved ⇒ best nil.
    public var isValid: Bool {
        if solved {
            guard open, let best else { return false }
            return best >= 1 && best <= Self.maxBest
        }
        return best == nil
    }

    private enum CodingKeys: String, CodingKey { case best, id, open, solved }

    /// Decodes a level's progress; every key must be present (`best` may be null).
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        open = try c.decode(Bool.self, forKey: .open)
        solved = try c.decode(Bool.self, forKey: .solved)
        guard c.contains(.best) else {
            throw DecodingError.keyNotFound(CodingKeys.best, .init(codingPath: c.codingPath,
                                                                    debugDescription: "best is required"))
        }
        best = try c.decodeIfPresent(Int.self, forKey: .best)
    }

    /// Encodes every key, writing `best` as null while unsolved.
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        if let best {
            try c.encode(best, forKey: .best)
        } else {
            try c.encodeNil(forKey: .best)
        }
        try c.encode(id, forKey: .id)
        try c.encode(open, forKey: .open)
        try c.encode(solved, forKey: .solved)
    }
}

/// The level progression of Light Maze: one ``LevelProgress`` per catalog level, in catalog order.
public struct Progress: Codable, Equatable, Sendable {
    /// The file schema this code writes and reads.
    public static let schemaVersion = 1
    /// The largest document accepted, in bytes (16 KB).
    public static let maxBytes = 16 * 1024

    /// The progress of each catalog level, in catalog order.
    public private(set) var levels: [LevelProgress]

    private init(levels: [LevelProgress]) { self.levels = levels }

    /// Fresh progress for `catalog`: level 1 open, nothing else open, nothing solved.
    public static func fresh(_ catalog: LevelCatalog = .bundled) -> Progress {
        var levels: [LevelProgress] = []
        for (index, level) in catalog.levels.enumerated() {
            levels.append(LevelProgress(id: level.id, open: index == 0, solved: false, best: nil))
        }
        return Progress(levels: levels)
    }

    /// True when level `index` is open; false for an index outside the progress.
    public func isOpen(_ index: Int) -> Bool {
        levels.indices.contains(index) && levels[index].open
    }

    /// True when level `index` is solved; false for an index outside the progress.
    public func isSolved(_ index: Int) -> Bool {
        levels.indices.contains(index) && levels[index].solved
    }

    /// The fewest moves level `index` was solved in, or nil (unsolved, or an index outside the progress).
    public func best(_ index: Int) -> Int? {
        levels.indices.contains(index) ? levels[index].best : nil
    }

    /// Records that level `levelIndex` was solved in `moves` moves: the level becomes open and solved, its best becomes
    /// min(best, max(1, moves)) (at most 999), and the next level, if any, opens. Returns whether anything changed
    /// (false for an index outside the progress or a solve that improves nothing).
    @discardableResult
    public mutating func recordSolved(levelIndex: Int, moves: Int) -> Bool {
        guard levels.indices.contains(levelIndex) else { return false }
        let before = levels
        let count = min(max(1, moves), LevelProgress.maxBest)
        var level = levels[levelIndex]
        level.open = true
        level.solved = true
        level.best = min(level.best ?? count, count)
        levels[levelIndex] = level
        let next = levelIndex + 1
        if levels.indices.contains(next) {
            levels[next].open = true
        }
        return levels != before
    }

    private enum CodingKeys: String, CodingKey { case levels, schema }

    /// Decodes a schema-1 document, throwing for another schema; catalog checks are done by ``decode(_:catalog:)``.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let schema = try c.decode(Int.self, forKey: .schema)
        guard schema == Self.schemaVersion else {
            throw DecodingError.dataCorrupted(.init(codingPath: c.codingPath, debugDescription: "not schema 1"))
        }
        levels = try c.decode([LevelProgress].self, forKey: .levels)
    }

    /// Encodes the progress at the current schema.
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(levels, forKey: .levels)
        try c.encode(Self.schemaVersion, forKey: .schema)
    }

    /// The progress as JSON with sorted keys (deterministic bytes for equal progress).
    public func encoded() -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return (try? encoder.encode(self)) ?? Data()
    }

    /// True when the progress matches `catalog`: the same ids in the same order, level 1 open and every level valid.
    public func matches(_ catalog: LevelCatalog) -> Bool {
        guard levels.count == catalog.levels.count, let first = levels.first, first.open else { return false }
        for index in 0..<levels.count {
            let level = levels[index]
            guard level.id == catalog.levels[index].id, level.isValid else { return false }
        }
        return true
    }

    /// The progress in `data`, or the reason it is refused (see the file header for the order of the checks).
    public static func decode(_ data: Data, catalog: LevelCatalog = .bundled) -> Result<Progress, ProgressRefusal> {
        guard data.count <= maxBytes else { return .failure(.tooLarge) }
        struct Header: Decodable { var schema: Int }
        let decoder = JSONDecoder()
        guard let header = try? decoder.decode(Header.self, from: data), header.schema >= schemaVersion else {
            return .failure(.damaged)
        }
        guard header.schema <= schemaVersion else { return .failure(.newerVersion) }
        guard let progress = try? decoder.decode(Progress.self, from: data), progress.matches(catalog) else {
            return .failure(.damaged)
        }
        return .success(progress)
    }
}
