// BackwardsAuroraLevel — feature 391 (R02-G10-01) T-R02G1001-002 (FR-R02G1001-001, 009, 013; clarifications Q1, Q2,
// Q5). An immutable Backwards Aurora level: the opening wave and the target wave (the same length and exactly the same
// multiset of heights, since a reversal only reorders samples); the checkpoints (2 … 8 distinct positions, kept
// sorted); the bend limit L (1 … 64) and the breaking limit B (L … 128); the shortest (2 … N) and longest (shortest …
// N) reversible section; the reversal budget (1 … 40); a difficulty (1 … 5) and whether a tutorial precedes play. The
// opening wave never already wins. Its fingerprint is the SHA-256 hex of its canonical JSON (schema 1, sorted keys,
// fingerprint excluded); the stored form is re-checked on decode. Samples, checkpoints, bends and reversals are named
// in words (FR-R02G1001-013).
import Foundation
import VisualCoreMath

/// An immutable, fingerprinted Backwards Aurora level.
public struct BackwardsAuroraLevel: Sendable, Equatable {
    /// The stored-form schema.
    public static var schema: Int { 1 }
    /// The allowed difficulties.
    public static let difficulties: ClosedRange<Int> = 1...5
    /// The allowed checkpoint counts.
    public static let checkpointCounts: ClosedRange<Int> = 2...8
    /// The allowed bend limits.
    public static let bendLimits: ClosedRange<Int> = 1...64
    /// The largest breaking limit (the smallest is the bend limit).
    public static let maximumBreakingLimit: Int = 128
    /// The shortest section any level may allow.
    public static let minimumSection: Int = 2
    /// The allowed reversal budgets.
    public static let budgets: ClosedRange<Int> = 1...40

    /// The level id, a lowercase slug.
    public let id: String
    /// The seed the level was built from.
    public let seed: UInt64
    /// The difficulty, 1 … 5.
    public let difficulty: Int
    /// The wave at the start of play.
    public let opening: BackwardsAuroraWave
    /// The true wave: a reordering of the opening wave.
    public let target: BackwardsAuroraWave
    /// The checkpoint positions, sorted ascending.
    public let checkpoints: [Int]
    /// The bend limit L: the wave is smooth when every |b| ≤ L.
    public let bendLimit: Int
    /// The breaking limit B: a reversal tears the aurora when one of its seam bends has |b| > B.
    public let breakingLimit: Int
    /// The shortest reversible section, in samples.
    public let shortest: Int
    /// The longest reversible section, in samples.
    public let longest: Int
    /// The reversals a play may spend.
    public let budget: Int
    /// Whether a tutorial precedes play.
    public let tutorial: Bool
    /// The SHA-256 hex of the canonical JSON.
    public let fingerprint: String

    /// A level; refuses any value outside its range and any broken rule.
    ///
    /// - Throws: `.level(name)` for `"id"`, `"difficulty"`, `"target"` (a different length or not a reordering of the
    ///   opening wave), `"checkpoints"` (a count outside 2 … 8, a repeat or a position outside the wave), `"bend"` (L
    ///   outside 1 … 64), `"breaking"` (B outside L … 128), `"shortest"` (outside 2 … N), `"longest"` (outside shortest
    ///   … N), `"budget"` or `"solved"` (the opening wave already wins).
    public init(id: String, seed: UInt64, difficulty: Int, opening: BackwardsAuroraWave, target: BackwardsAuroraWave,
                checkpoints: [Int], bendLimit: Int, breakingLimit: Int, shortest: Int, longest: Int, budget: Int,
                tutorial: Bool = false) throws(BackwardsAuroraError) {
        guard Self.isSlug(id) else { throw .level("id") }
        guard Self.difficulties.contains(difficulty) else { throw .level("difficulty") }
        let count: Int = opening.count
        guard target.count == count, target.samples.sorted() == opening.samples.sorted() else {
            throw .level("target")
        }
        let sorted: [Int] = checkpoints.sorted()
        guard Self.checkpointCounts.contains(sorted.count), Set(sorted).count == sorted.count,
              sorted.allSatisfy({ $0 >= 0 && $0 < count }) else { throw .level("checkpoints") }
        guard Self.bendLimits.contains(bendLimit) else { throw .level("bend") }
        guard breakingLimit >= bendLimit, breakingLimit <= Self.maximumBreakingLimit else { throw .level("breaking") }
        guard shortest >= Self.minimumSection, shortest <= count else { throw .level("shortest") }
        guard longest >= shortest, longest <= count else { throw .level("longest") }
        guard Self.budgets.contains(budget) else { throw .level("budget") }
        guard !Self.wins(opening, target: target, checkpoints: sorted, bendLimit: bendLimit) else {
            throw .level("solved")
        }
        let content = Content(id: id, seed: seed, difficulty: difficulty, opening: opening, target: target,
                              checkpoints: sorted, bendLimit: bendLimit, breakingLimit: breakingLimit,
                              shortest: shortest, longest: longest, budget: budget, tutorial: tutorial)
        guard let data = try? Self.encoder.encode(content) else { throw .malformed("encode") }
        self.id = id
        self.seed = seed
        self.difficulty = difficulty
        self.opening = opening
        self.target = target
        self.checkpoints = sorted
        self.bendLimit = bendLimit
        self.breakingLimit = breakingLimit
        self.shortest = shortest
        self.longest = longest
        self.budget = budget
        self.tutorial = tutorial
        self.fingerprint = StableHash.sha256Hex(Array(data))
    }

    /// The number of samples, N.
    public var count: Int { opening.count }

    /// The allowed section lengths, shortest … longest.
    public var sectionLengths: ClosedRange<Int> { shortest...longest }

    /// Per checkpoint (in position order): whether `wave` has the target's height there.
    public func matched(_ wave: BackwardsAuroraWave) -> [Bool] {
        checkpoints.map { wave.samples[$0] == target.samples[$0] }
    }

    /// Whether `wave` wins: every checkpoint at its target height and every bend within the bend limit.
    public func wins(_ wave: BackwardsAuroraWave) -> Bool {
        Self.wins(wave, target: target, checkpoints: checkpoints, bendLimit: bendLimit)
    }

    static func wins(_ wave: BackwardsAuroraWave, target: BackwardsAuroraWave, checkpoints: [Int],
                     bendLimit: Int) -> Bool {
        checkpoints.allSatisfy { wave.samples[$0] == target.samples[$0] } && wave.isSmooth(limit: bendLimit)
    }

    /// The sample at `position` in words: "sample at position 4: height -12".
    public func sampleName(_ position: Int, wave: BackwardsAuroraWave) -> String {
        "sample at position \(position): height \(wave.samples[position])"
    }

    /// Checkpoint `index` (0-based, position order) in words: "checkpoint 2 at position 7: height 5, target 5,
    /// matched" or "…: height 3, target 5, not matched".
    public func checkpointName(_ index: Int, wave: BackwardsAuroraWave) -> String {
        let position: Int = checkpoints[index]
        let height: Int = wave.samples[position]
        let goal: Int = target.samples[position]
        return "checkpoint \(index + 1) at position \(position): height \(height), target \(goal), "
            + (height == goal ? "matched" : "not matched")
    }

    /// The bend at `position` in words: "bend at position 5: 9 of limit 12".
    public func bendName(_ position: Int, wave: BackwardsAuroraWave) -> String {
        "bend at position \(position): \(abs(wave.bend(at: position))) of limit \(bendLimit)"
    }

    /// The wave's bends in words: "worst bend 9 of limit 12, smooth" or "worst bend 20 of limit 12, too sharp".
    public func bendDescription(_ wave: BackwardsAuroraWave) -> String {
        "worst bend \(wave.worstBend) of limit \(bendLimit), "
            + (wave.isSmooth(limit: bendLimit) ? "smooth" : "too sharp")
    }

    /// The reversals left in words: "1 reversal left", "3 reversals left".
    public static func reversalsText(_ left: Int) -> String {
        left == 1 ? "1 reversal left" : "\(left) reversals left"
    }

    /// The level in words: "24 samples; 3 checkpoints at positions 2, 9, 17; bend limit 12, breaking limit 30;
    /// sections of 2 to 8 samples; 6 reversals".
    public func targetDescription() -> String {
        let positions: String = checkpoints.map(String.init).joined(separator: ", ")
        let reversals: String = budget == 1 ? "1 reversal" : "\(budget) reversals"
        return "\(count) samples; \(checkpoints.count) checkpoints at positions \(positions); "
            + "bend limit \(bendLimit), breaking limit \(breakingLimit); "
            + "sections of \(shortest) to \(longest) samples; \(reversals)"
    }

    /// The stored form: JSON with sorted keys holding the schema, every field and the fingerprint.
    public func encoded() -> Data {
        do {
            return try Self.encoder.encode(Stored(content: Content(level: self), fingerprint: fingerprint))
        } catch {
            preconditionFailure("a Backwards Aurora level of checked values always encodes: \(error)")
        }
    }

    /// Decodes a stored level, re-checking every rule and the fingerprint.
    ///
    /// - Throws: `.newerSchema(s)` above ``schema``; `.malformed(description)` for unreadable JSON, missing keys, a
    ///   schema below 1, a wave out of range, any refusal of the initialiser (its reason code) or a fingerprint that
    ///   does not match.
    public static func decode(_ data: Data) throws(BackwardsAuroraError) -> BackwardsAuroraLevel {
        struct Probe: Decodable { let schema: Int }
        let probe: Probe
        do { probe = try JSONDecoder().decode(Probe.self, from: data) } catch { throw .malformed("unreadable") }
        guard probe.schema <= schema else { throw .newerSchema(probe.schema) }
        guard probe.schema >= 1 else { throw .malformed("schema \(probe.schema)") }
        let stored: Stored
        do { stored = try JSONDecoder().decode(Stored.self, from: data) } catch { throw .malformed("unreadable") }
        let level: BackwardsAuroraLevel
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

    /// The fingerprinted content; waves as sample arrays, checkpoints sorted.
    struct Content: Codable, Equatable {
        let schema: Int
        let id: String
        let seed: UInt64
        let difficulty: Int
        let opening: [Int]
        let target: [Int]
        let checkpoints: [Int]
        let bendLimit: Int
        let breakingLimit: Int
        let shortest: Int
        let longest: Int
        let budget: Int
        let tutorial: Bool

        init(id: String, seed: UInt64, difficulty: Int, opening: BackwardsAuroraWave, target: BackwardsAuroraWave,
             checkpoints: [Int], bendLimit: Int, breakingLimit: Int, shortest: Int, longest: Int, budget: Int,
             tutorial: Bool) {
            self.schema = BackwardsAuroraLevel.schema
            self.id = id
            self.seed = seed
            self.difficulty = difficulty
            self.opening = opening.samples
            self.target = target.samples
            self.checkpoints = checkpoints.sorted()
            self.bendLimit = bendLimit
            self.breakingLimit = breakingLimit
            self.shortest = shortest
            self.longest = longest
            self.budget = budget
            self.tutorial = tutorial
        }

        init(level: BackwardsAuroraLevel) {
            self.init(id: level.id, seed: level.seed, difficulty: level.difficulty, opening: level.opening,
                      target: level.target, checkpoints: level.checkpoints, bendLimit: level.bendLimit,
                      breakingLimit: level.breakingLimit, shortest: level.shortest, longest: level.longest,
                      budget: level.budget, tutorial: level.tutorial)
        }

        /// The level of this content, re-checked (waves first).
        func level() throws(BackwardsAuroraError) -> BackwardsAuroraLevel {
            let openingWave = try BackwardsAuroraWave(opening)
            let targetWave: BackwardsAuroraWave
            do { targetWave = try BackwardsAuroraWave(target) } catch { throw .level("target") }
            return try BackwardsAuroraLevel(id: id, seed: seed, difficulty: difficulty, opening: openingWave,
                                            target: targetWave, checkpoints: checkpoints, bendLimit: bendLimit,
                                            breakingLimit: breakingLimit, shortest: shortest, longest: longest,
                                            budget: budget, tutorial: tutorial)
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

extension BackwardsAuroraLevel: Codable {
    /// Decodes a level through ``decode(_:)``'s rules.
    public init(from decoder: any Decoder) throws {
        let stored = try Stored(from: decoder)
        guard stored.content.schema <= Self.schema else {
            let code = BackwardsAuroraError.newerSchema(stored.content.schema).reasonCode
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: code))
        }
        do {
            self = try stored.content.level()
        } catch {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: error.reasonCode))
        }
        guard fingerprint == stored.fingerprint else {
            let code = BackwardsAuroraError.malformed("fingerprint").reasonCode
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: code))
        }
    }

    /// Encodes the stored form.
    public func encode(to encoder: any Encoder) throws {
        try Stored(content: Content(level: self), fingerprint: fingerprint).encode(to: encoder)
    }
}
