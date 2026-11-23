// HarmonicBridgesLevel — feature 411 (R02-G12-01) T-R02G1201-002 (FR-R02G1201-001, 002, 003, 009, 011, 013, 014;
// SC-R02G1201-001, 003, 005; clarifications Q1, Q2, Q4, Q5). An immutable Harmonic Bridges level: 2 … 8 islands (each a
// drawing position on the 16 × 10 grid that never decides a rule), a start and a goal island (distinct), 1 … 12 strings
// (each joining islands a < b, no two strings on the same pair, a length 1 … 6, a starting peg 1 … 12 and a locked
// flag), a crossing window of 1 … 4 steps each sounding 1 … 3 tones of distinct frequencies (1 … 72, strength 1 … 3), a
// solidity threshold 1 … 12, an action budget 1 … 60, a difficulty 1 … 5 and whether a tutorial precedes play. The
// report of any pegs is the exact truth metric (HarmonicBridgesResonance.swift). Its fingerprint is the SHA-256 hex of
// its canonical JSON (schema 1, sorted keys, islands as [x, y], strings as [a, b, length, peg, locked], steps as lists
// of [F, w], fingerprint excluded); the stored form is re-checked on decode. Strings, resonances and progress are named
// in words (FR-R02G1201-013); island, string and step numbers in words are their indices, counted from 0.
import Foundation
import VisualCoreMath

/// An immutable, fingerprinted Harmonic Bridges level.
public struct HarmonicBridgesLevel: Sendable, Equatable {
    /// The stored-form schema.
    public static var schema: Int { 1 }
    /// The allowed difficulties.
    public static let difficulties: ClosedRange<Int> = 1...5
    /// The allowed island counts.
    public static let islandCounts: ClosedRange<Int> = 2...8
    /// The allowed island columns (drawing only).
    public static let columns: ClosedRange<Int> = 0...15
    /// The allowed island rows (drawing only).
    public static let rows: ClosedRange<Int> = 0...9
    /// The allowed string counts.
    public static let stringCounts: ClosedRange<Int> = 1...12
    /// The allowed string lengths.
    public static let lengths: ClosedRange<Int> = 1...6
    /// The allowed peg values.
    public static let pegs: ClosedRange<Int> = 1...12
    /// The allowed step counts of the crossing window.
    public static let stepCounts: ClosedRange<Int> = 1...4
    /// The allowed tone counts of a step.
    public static let toneCounts: ClosedRange<Int> = 1...3
    /// The allowed tone frequencies.
    public static let frequencies: ClosedRange<Int> = 1...72
    /// The allowed tone strengths.
    public static let strengths: ClosedRange<Int> = 1...3
    /// The allowed solidity thresholds, in quarters.
    public static let thresholds: ClosedRange<Int> = 1...12
    /// The allowed action budgets.
    public static let budgets: ClosedRange<Int> = 1...60

    /// The level id, a lowercase slug.
    public let id: String
    /// The seed the level was built from.
    public let seed: UInt64
    /// The difficulty, 1 … 5.
    public let difficulty: Int
    /// The islands, by index.
    public let islands: [HarmonicBridgesIsland]
    /// The strings, by index, with their starting pegs.
    public let strings: [HarmonicBridgesString]
    /// The start island.
    public let start: Int
    /// The goal island.
    public let goal: Int
    /// The tones of each step of the crossing window.
    public let steps: [[HarmonicBridgesTone]]
    /// The solidity threshold, in quarters.
    public let threshold: Int
    /// The action budget.
    public let budget: Int
    /// Whether a tutorial precedes play.
    public let tutorial: Bool
    /// The SHA-256 hex of the canonical JSON.
    public let fingerprint: String

    /// A level; refuses any value outside its range and any broken rule.
    ///
    /// - Throws: `.level(name)` for `"id"`, `"difficulty"`, `"islands"` (a count outside 2 … 8 or a position outside the
    ///   grid), `"strings"` (a count outside 1 … 12, an island out of range, a ≥ b, a repeated pair, a length or peg out
    ///   of range), `"start"` (out of range), `"goal"` (out of range or equal to the start), `"steps"` (a count outside
    ///   1 … 4 or a step with a tone count outside 1 … 3), `"tones"` (a frequency or strength out of range, or a repeated
    ///   frequency within a step), `"threshold"` or `"budget"`.
    public init(id: String, seed: UInt64, difficulty: Int, islands: [HarmonicBridgesIsland],
                strings: [HarmonicBridgesString], start: Int, goal: Int, steps: [[HarmonicBridgesTone]],
                threshold: Int, budget: Int, tutorial: Bool = false) throws(HarmonicBridgesError) {
        guard Self.isSlug(id) else { throw .level("id") }
        guard Self.difficulties.contains(difficulty) else { throw .level("difficulty") }
        guard Self.islandCounts.contains(islands.count) else { throw .level("islands") }
        for island in islands {
            guard Self.columns.contains(island.x), Self.rows.contains(island.y) else { throw .level("islands") }
        }
        guard Self.stringCounts.contains(strings.count) else { throw .level("strings") }
        var pairs: Set<Int> = []
        for string in strings {
            guard string.a >= 0, string.b < islands.count, string.a < string.b else { throw .level("strings") }
            guard Self.lengths.contains(string.length), Self.pegs.contains(string.peg) else { throw .level("strings") }
            guard pairs.insert(string.a * 16 + string.b).inserted else { throw .level("strings") }
        }
        guard start >= 0, start < islands.count else { throw .level("start") }
        guard goal >= 0, goal < islands.count, goal != start else { throw .level("goal") }
        guard Self.stepCounts.contains(steps.count) else { throw .level("steps") }
        for tones in steps {
            guard Self.toneCounts.contains(tones.count) else { throw .level("steps") }
            var heard: Set<Int> = []
            for tone in tones {
                guard Self.frequencies.contains(tone.frequency), Self.strengths.contains(tone.strength) else {
                    throw .level("tones")
                }
                guard heard.insert(tone.frequency).inserted else { throw .level("tones") }
            }
        }
        guard Self.thresholds.contains(threshold) else { throw .level("threshold") }
        guard Self.budgets.contains(budget) else { throw .level("budget") }
        let content = Content(schema: Self.schema, id: id, seed: seed, difficulty: difficulty, islands: islands,
                              strings: strings, start: start, goal: goal, steps: steps, threshold: threshold,
                              budget: budget, tutorial: tutorial)
        guard let data = try? Self.encoder.encode(content) else { throw .malformed("encode") }
        self.id = id
        self.seed = seed
        self.difficulty = difficulty
        self.islands = islands
        self.strings = strings
        self.start = start
        self.goal = goal
        self.steps = steps
        self.threshold = threshold
        self.budget = budget
        self.tutorial = tutorial
        self.fingerprint = StableHash.sha256Hex(Array(data))
    }

    /// The starting pegs, one per string.
    public var startingPegs: [Int] { strings.map(\.peg) }

    /// The truth metric at `pegs` (one per string): every swing, bridge and reachable set, per step.
    public func report(pegs: [Int]) -> HarmonicBridgesReport {
        HarmonicBridgesReport(strings: strings, pegs: pegs, steps: steps, threshold: threshold,
                              islandCount: islands.count, start: start, goal: goal)
    }

    /// The resonance of string `index` at `peg` in step `step`.
    public func resonance(_ index: Int, step: Int, peg: Int) -> HarmonicBridgesResonance {
        HarmonicBridgesResonance(string: strings[index], index: index, step: step, tones: steps[step], peg: peg,
                                 threshold: threshold)
    }

    /// Where a crossing at `report` breaks (the first unreached step and its broken string), or nil when it holds.
    public func firstBreak(_ report: HarmonicBridgesReport) -> HarmonicBridgesBreak? {
        report.firstBreak(strings: strings)
    }

    /// String `index` in words: "string 2, island 0 to island 3, peg 6" (", locked" appended for a locked string).
    public func stringName(_ index: Int, peg: Int) -> String {
        let string: HarmonicBridgesString = strings[index]
        let lock: String = string.locked ? ", locked" : ""
        return "string \(index), island \(string.a) to island \(string.b), peg \(peg)\(lock)"
    }

    /// String `index`'s resonance at `pegs` in words, per step: "step 0: modes 2 and 3, swing 7 3 4 3 7, a bridge; step
    /// 1: no modes, swing 0 0 0 0 0, not a bridge".
    public func resonanceDescription(_ index: Int, pegs: [Int]) -> String {
        var parts: [String] = []
        for step in 0..<steps.count {
            let resonance: HarmonicBridgesResonance = resonance(index, step: step, peg: pegs[index])
            let swing: String = resonance.swing.map(String.init).joined(separator: " ")
            let bridge: String = resonance.bridge ? "a bridge" : "not a bridge"
            parts.append("step \(step): \(Self.modesText(resonance.resonatingModes)), swing \(swing), \(bridge)")
        }
        return parts.joined(separator: "; ")
    }

    /// The progress in words: "step 0: 2 bridges, goal reached; step 1: 1 bridge, goal not reached; 7 actions left".
    public func progressDescription(report: HarmonicBridgesReport, actionsLeft: Int) -> String {
        var parts: [String] = []
        let counts: [Int] = report.bridgeCounts
        for step in 0..<report.reached.count {
            let noun: String = counts[step] == 1 ? "1 bridge" : "\(counts[step]) bridges"
            let reached: String = report.reached[step][goal] ? "goal reached" : "goal not reached"
            parts.append("step \(step): \(noun), \(reached)")
        }
        parts.append(actionsLeft == 1 ? "1 action left" : "\(actionsLeft) actions left")
        return parts.joined(separator: "; ")
    }

    /// "no modes", "mode 1", "modes 2 and 3", "modes 1, 2 and 3".
    static func modesText(_ modes: [Int]) -> String {
        switch modes.count {
        case 0: return "no modes"
        case 1: return "mode \(modes[0])"
        default:
            let head: String = modes.dropLast().map(String.init).joined(separator: ", ")
            return "modes \(head) and \(modes[modes.count - 1])"
        }
    }

    /// The stored form: JSON with sorted keys holding the schema, every field and the fingerprint.
    public func encoded() -> Data {
        do {
            return try Self.encoder.encode(Stored(content: Content(level: self), fingerprint: fingerprint))
        } catch {
            preconditionFailure("a Harmonic Bridges level of checked values always encodes: \(error)")
        }
    }

    /// Decodes a stored level, re-checking every rule and the fingerprint.
    ///
    /// - Throws: `.newerSchema(s)` above ``schema``; `.malformed(description)` for unreadable JSON, missing keys, a
    ///   schema below 1, any refusal of the initialiser (its reason code) or a fingerprint that does not match.
    public static func decode(_ data: Data) throws(HarmonicBridgesError) -> HarmonicBridgesLevel {
        struct Probe: Decodable { let schema: Int }
        let probe: Probe
        do { probe = try JSONDecoder().decode(Probe.self, from: data) } catch { throw .malformed("unreadable") }
        guard probe.schema <= schema else { throw .newerSchema(probe.schema) }
        guard probe.schema >= 1 else { throw .malformed("schema \(probe.schema)") }
        let stored: Stored
        do { stored = try JSONDecoder().decode(Stored.self, from: data) } catch { throw .malformed("unreadable") }
        let level: HarmonicBridgesLevel
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
        let islands: [HarmonicBridgesIsland]
        let strings: [HarmonicBridgesString]
        let start: Int
        let goal: Int
        let steps: [[HarmonicBridgesTone]]
        let threshold: Int
        let budget: Int
        let tutorial: Bool

        init(schema: Int, id: String, seed: UInt64, difficulty: Int, islands: [HarmonicBridgesIsland],
             strings: [HarmonicBridgesString], start: Int, goal: Int, steps: [[HarmonicBridgesTone]], threshold: Int,
             budget: Int, tutorial: Bool) {
            self.schema = schema
            self.id = id
            self.seed = seed
            self.difficulty = difficulty
            self.islands = islands
            self.strings = strings
            self.start = start
            self.goal = goal
            self.steps = steps
            self.threshold = threshold
            self.budget = budget
            self.tutorial = tutorial
        }

        init(level: HarmonicBridgesLevel) {
            self.init(schema: HarmonicBridgesLevel.schema, id: level.id, seed: level.seed,
                      difficulty: level.difficulty, islands: level.islands, strings: level.strings,
                      start: level.start, goal: level.goal, steps: level.steps, threshold: level.threshold,
                      budget: level.budget, tutorial: level.tutorial)
        }

        /// The level of this content, re-checked.
        func level() throws(HarmonicBridgesError) -> HarmonicBridgesLevel {
            try HarmonicBridgesLevel(id: id, seed: seed, difficulty: difficulty, islands: islands, strings: strings,
                                     start: start, goal: goal, steps: steps, threshold: threshold, budget: budget,
                                     tutorial: tutorial)
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

extension HarmonicBridgesLevel: Codable {
    /// Decodes a level through ``decode(_:)``'s rules.
    public init(from decoder: any Decoder) throws {
        let stored = try Stored(from: decoder)
        guard stored.content.schema <= Self.schema else {
            let code = HarmonicBridgesError.newerSchema(stored.content.schema).reasonCode
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: code))
        }
        do {
            self = try stored.content.level()
        } catch {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: error.reasonCode))
        }
        guard fingerprint == stored.fingerprint else {
            let code = HarmonicBridgesError.malformed("fingerprint").reasonCode
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: code))
        }
    }

    /// Encodes the stored form.
    public func encode(to encoder: any Encoder) throws {
        try Stored(content: Content(level: self), fingerprint: fingerprint).encode(to: encoder)
    }
}
