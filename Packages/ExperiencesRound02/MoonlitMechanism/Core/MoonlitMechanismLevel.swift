// MoonlitMechanismLevel — feature 431 (R02-G14-01) T-R02G1401-002 (FR-R02G1401-001, 003, 005, 009, 011, 013, 014;
// SC-R02G1401-001, 003, 005; clarifications Q1, Q3, Q4, Q5). An immutable Moonlit Mechanism level: 2 … 5 gears (gear 0
// the driver, every other gear meshing with a lower-index parent), each with 6 … 20 teeth, a starting phase, a blade
// pattern with at least one solid and one open blade, a depth 1 … 3, a centre on the wall, a slot table (per slot a
// non-empty list of offsets within ±8) and, for a child, a mesh divisor gcd(Tₚ, T_c) of at least 2 with an alignment
// value below it; a wall of W 8 … 24 × H 6 … 16 cells; 2 … 5 lamp heights with a starting height; 2 … 6 key frames with
// strictly increasing handle turns (the first ≥ 0), non-empty sorted targets and at least one required; 0 … 12
// forbidden cells disjoint from every target; a stray allowance 0 … 4; an action budget 1 … 40; a difficulty 1 … 5 and
// whether a tutorial precedes play. Its fingerprint is the SHA-256 hex of its canonical JSON (schema 1, sorted keys,
// fingerprint excluded); the stored form is re-checked on decode. Gears, the lamp and progress are named in words
// (FR-R02G1401-013); gear and key-frame numbers in words are their indices, counted from 0.
import Foundation
import VisualCoreMath

/// An immutable, fingerprinted Moonlit Mechanism level.
public struct MoonlitMechanismLevel: Sendable, Equatable {
    /// The stored-form schema.
    public static let schema: Int = 1
    /// The difficulty bands.
    public static let difficulties: ClosedRange<Int> = 1...5
    /// The gear counts.
    public static let gearCounts: ClosedRange<Int> = 2...5
    /// The tooth counts.
    public static let toothCounts: ClosedRange<Int> = 6...20
    /// The depths.
    public static let depths: ClosedRange<Int> = 1...3
    /// The largest slot offset in either direction.
    public static let maxOffset: Int = 8
    /// The wall widths.
    public static let widths: ClosedRange<Int> = 8...24
    /// The wall heights.
    public static let heights: ClosedRange<Int> = 6...16
    /// The lamp height counts.
    public static let lampCounts: ClosedRange<Int> = 2...5
    /// The key-frame counts.
    public static let frameCounts: ClosedRange<Int> = 2...6
    /// The largest number of forbidden cells.
    public static let maxForbidden: Int = 12
    /// The stray allowances.
    public static let allowances: ClosedRange<Int> = 0...4
    /// The action budgets.
    public static let budgets: ClosedRange<Int> = 1...40
    /// The largest handle-turn count of a key frame.
    public static let maxTurns: Int = 400

    /// The level's slug.
    public let id: String
    /// The level's seed.
    public let seed: UInt64
    /// The difficulty band, 1 … 5.
    public let difficulty: Int
    /// The gears; gear 0 is the driver.
    public let gears: [MoonlitMechanismGear]
    /// The wall width W.
    public let width: Int
    /// The wall height H.
    public let rows: Int
    /// The number of lamp heights L.
    public let lampHeights: Int
    /// The starting lamp height, 0 … L − 1.
    public let startingHeight: Int
    /// The key frames, in order.
    public let keyFrames: [MoonlitMechanismKeyFrame]
    /// The forbidden cells, sorted.
    public let forbidden: [Int]
    /// The stray allowance.
    public let allowance: Int
    /// The action budget.
    public let budget: Int
    /// Whether a tutorial precedes play.
    public let tutorial: Bool
    /// The SHA-256 hex of the canonical JSON.
    public let fingerprint: String

    /// A level; refuses any value outside its range and any broken rule.
    ///
    /// - Throws: `.level(name)` for `"id"`, `"difficulty"`, `"gears"` (a count outside 2 … 5, the driver with a
    ///   parent, a gear without a lower-index parent), `"teeth"`, `"phase"`, `"blades"` (a length other than the teeth
    ///   or all solid or all open), `"depth"`, `"slots"` (a count other than the teeth, an empty list or an offset
    ///   beyond ±8), `"mesh"` (a divisor below 2 or an alignment value not below it, or a driver alignment other than
    ///   0), `"wall"`, `"lamp"` (a count outside 2 … 5 or a starting height out of range), `"centre"` (outside the
    ///   wall), `"keyFrames"` (a count outside 2 … 6, turns negative, above 400 or not increasing, an empty, unsorted,
    ///   repeated or off-wall target, none required), `"forbidden"` (more than 12, unsorted, repeated, off the wall or
    ///   inside a target), `"allowance"` or `"budget"`.
    public init(id: String, seed: UInt64, difficulty: Int, gears: [MoonlitMechanismGear], width: Int, rows: Int,
                lampHeights: Int, startingHeight: Int, keyFrames: [MoonlitMechanismKeyFrame], forbidden: [Int],
                allowance: Int, budget: Int, tutorial: Bool = false) throws(MoonlitMechanismError) {
        guard Self.isSlug(id) else { throw .level("id") }
        guard Self.difficulties.contains(difficulty) else { throw .level("difficulty") }
        guard Self.gearCounts.contains(gears.count) else { throw .level("gears") }
        guard Self.widths.contains(width), Self.heights.contains(rows) else { throw .level("wall") }
        for (index, gear) in gears.enumerated() {
            if index == 0 {
                guard gear.parent == nil else { throw .level("gears") }
            } else {
                guard let parent = gear.parent, parent >= 0, parent < index else { throw .level("gears") }
            }
            guard Self.toothCounts.contains(gear.teeth) else { throw .level("teeth") }
            guard gear.phase >= 0, gear.phase < gear.teeth else { throw .level("phase") }
            guard gear.blades.count == gear.teeth, gear.blades.contains(true), gear.blades.contains(false) else {
                throw .level("blades")
            }
            guard Self.depths.contains(gear.depth) else { throw .level("depth") }
            guard gear.slots.count == gear.teeth else { throw .level("slots") }
            for slot in gear.slots {
                guard !slot.isEmpty else { throw .level("slots") }
                for offset in slot {
                    guard abs(offset.column) <= Self.maxOffset, abs(offset.row) <= Self.maxOffset else {
                        throw .level("slots")
                    }
                }
            }
            guard gear.centre.column >= 0, gear.centre.column < width, gear.centre.row >= 0, gear.centre.row < rows
            else { throw .level("centre") }
            if let parent = gear.parent {
                let g: Int = MoonlitMechanismTrain.gcd(gears[parent].teeth, gear.teeth)
                guard g >= 2, gear.alignment >= 0, gear.alignment < g else { throw .level("mesh") }
            } else {
                guard gear.alignment == 0 else { throw .level("mesh") }
            }
        }
        guard Self.lampCounts.contains(lampHeights), startingHeight >= 0, startingHeight < lampHeights else {
            throw .level("lamp")
        }
        let cells: Int = width * rows
        guard Self.frameCounts.contains(keyFrames.count), keyFrames.contains(where: \.required) else {
            throw .level("keyFrames")
        }
        var previous: Int = -1
        var targets: Set<Int> = []
        for frame in keyFrames {
            guard frame.turns > previous, frame.turns <= Self.maxTurns else { throw .level("keyFrames") }
            previous = frame.turns
            guard !frame.target.isEmpty, Self.isSortedDistinct(frame.target, below: cells) else {
                throw .level("keyFrames")
            }
            targets.formUnion(frame.target)
        }
        guard forbidden.count <= Self.maxForbidden, Self.isSortedDistinct(forbidden, below: cells),
              targets.isDisjoint(with: forbidden) else { throw .level("forbidden") }
        guard Self.allowances.contains(allowance) else { throw .level("allowance") }
        guard Self.budgets.contains(budget) else { throw .level("budget") }
        let content = Content(schema: Self.schema, id: id, seed: seed, difficulty: difficulty, gears: gears,
                              width: width, rows: rows, lampHeights: lampHeights, startingHeight: startingHeight,
                              keyFrames: keyFrames, forbidden: forbidden, allowance: allowance, budget: budget,
                              tutorial: tutorial)
        guard let data = try? Self.encoder.encode(content) else { throw .malformed("encode") }
        self.id = id
        self.seed = seed
        self.difficulty = difficulty
        self.gears = gears
        self.width = width
        self.rows = rows
        self.lampHeights = lampHeights
        self.startingHeight = startingHeight
        self.keyFrames = keyFrames
        self.forbidden = forbidden
        self.allowance = allowance
        self.budget = budget
        self.tutorial = tutorial
        self.fingerprint = StableHash.sha256Hex(Array(data))
    }

    /// The starting phases, one per gear.
    public var startingPhases: [Int] { gears.map(\.phase) }

    /// The run (truth metric and outcome) of the set-up `phases` with the lamp at `height`.
    public func run(phases: [Int], height: Int) -> MoonlitMechanismRunReport {
        MoonlitMechanismTrain.run(gears, phases: phases, height: height, width: width, rows: rows, frames: keyFrames,
                                  forbidden: forbidden, allowance: allowance)
    }

    /// Gear `index` in words: "gear 2, 12 teeth, phase 5".
    public func gearName(_ index: Int, phase: Int) -> String {
        "gear \(index), \(gears[index].teeth) teeth, phase \(phase)"
    }

    /// The lamp in words: "lamp height 1 of 3" (heights counted from 0, of the count).
    public func lampName(_ height: Int) -> String {
        "lamp height \(height) of \(lampHeights)"
    }

    /// The progress in words: "aligned; key frame 0: 6 of 6 covered, 1 stray, required; key frame 1: …; won; 5
    /// actions left", or "gear 2 jammed, 1 tooth off; …".
    public func progressDescription(report: MoonlitMechanismRunReport, actionsLeft: Int) -> String {
        var parts: [String] = []
        let jammed: [String] = report.errors.indices.compactMap { index in
            let error: Int = report.errors[index]
            guard error != 0 else { return nil }
            return "gear \(index) jammed, \(error == 1 ? "1 tooth" : "\(error) teeth") off"
        }
        parts.append(jammed.isEmpty ? "aligned" : jammed.joined(separator: ", "))
        for (index, frame) in report.frames.enumerated() {
            let total: Int = frame.covered + frame.missing
            var text: String = "key frame \(index): \(frame.covered) of \(total) covered, \(frame.stray) stray"
            if !frame.forbidden.isEmpty { text += ", \(frame.forbidden.count) forbidden" }
            text += keyFrames[index].required ? ", required" : ", not required"
            parts.append(text)
        }
        let outcome: String
        switch report.outcome {
        case .won: outcome = "won"
        case .jammed(let child): outcome = "jams at gear \(child)"
        case .forbidden(let frame, let cell): outcome = "key frame \(frame) shadows forbidden cell \(cell)"
        case .missing(let frame, let count): outcome = "key frame \(frame) misses \(count)"
        case .stray(let frame, let count): outcome = "key frame \(frame) strays \(count)"
        }
        parts.append(outcome)
        parts.append(actionsLeft == 1 ? "1 action left" : "\(actionsLeft) actions left")
        return parts.joined(separator: "; ")
    }

    /// Whether `cells` are strictly increasing within 0 ..< `bound`.
    static func isSortedDistinct(_ cells: [Int], below bound: Int) -> Bool {
        var previous: Int = -1
        for cell in cells {
            guard cell > previous, cell < bound else { return false }
            previous = cell
        }
        return true
    }

    /// The stored form: JSON with sorted keys holding the schema, every field and the fingerprint.
    public func encoded() -> Data {
        do {
            return try Self.encoder.encode(Stored(content: Content(level: self), fingerprint: fingerprint))
        } catch {
            preconditionFailure("a Moonlit Mechanism level of checked values always encodes: \(error)")
        }
    }

    /// Decodes a stored level, re-checking every rule and the fingerprint.
    ///
    /// - Throws: `.newerSchema(s)` above ``schema``; `.malformed(description)` for unreadable JSON, missing keys, a
    ///   schema below 1, any refusal of the initialiser (its reason code) or a fingerprint that does not match.
    public static func decode(_ data: Data) throws(MoonlitMechanismError) -> MoonlitMechanismLevel {
        struct Probe: Decodable { let schema: Int }
        let probe: Probe
        do { probe = try JSONDecoder().decode(Probe.self, from: data) } catch { throw .malformed("unreadable") }
        guard probe.schema <= schema else { throw .newerSchema(probe.schema) }
        guard probe.schema >= 1 else { throw .malformed("schema \(probe.schema)") }
        let stored: Stored
        do { stored = try JSONDecoder().decode(Stored.self, from: data) } catch { throw .malformed("unreadable") }
        let level: MoonlitMechanismLevel
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
        let gears: [MoonlitMechanismGear]
        let width: Int
        let rows: Int
        let lampHeights: Int
        let startingHeight: Int
        let keyFrames: [MoonlitMechanismKeyFrame]
        let forbidden: [Int]
        let allowance: Int
        let budget: Int
        let tutorial: Bool

        init(schema: Int, id: String, seed: UInt64, difficulty: Int, gears: [MoonlitMechanismGear], width: Int,
             rows: Int, lampHeights: Int, startingHeight: Int, keyFrames: [MoonlitMechanismKeyFrame], forbidden: [Int],
             allowance: Int, budget: Int, tutorial: Bool) {
            self.schema = schema
            self.id = id
            self.seed = seed
            self.difficulty = difficulty
            self.gears = gears
            self.width = width
            self.rows = rows
            self.lampHeights = lampHeights
            self.startingHeight = startingHeight
            self.keyFrames = keyFrames
            self.forbidden = forbidden
            self.allowance = allowance
            self.budget = budget
            self.tutorial = tutorial
        }

        init(level: MoonlitMechanismLevel) {
            self.init(schema: MoonlitMechanismLevel.schema, id: level.id, seed: level.seed,
                      difficulty: level.difficulty, gears: level.gears, width: level.width, rows: level.rows,
                      lampHeights: level.lampHeights, startingHeight: level.startingHeight,
                      keyFrames: level.keyFrames, forbidden: level.forbidden, allowance: level.allowance,
                      budget: level.budget, tutorial: level.tutorial)
        }

        /// The level of this content, re-checked.
        func level() throws(MoonlitMechanismError) -> MoonlitMechanismLevel {
            try MoonlitMechanismLevel(id: id, seed: seed, difficulty: difficulty, gears: gears, width: width,
                                      rows: rows, lampHeights: lampHeights, startingHeight: startingHeight,
                                      keyFrames: keyFrames, forbidden: forbidden, allowance: allowance,
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

extension MoonlitMechanismLevel: Codable {
    /// Decodes a level through ``decode(_:)``'s rules.
    public init(from decoder: any Decoder) throws {
        let stored = try Stored(from: decoder)
        guard stored.content.schema <= Self.schema else {
            let code = MoonlitMechanismError.newerSchema(stored.content.schema).reasonCode
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: code))
        }
        do {
            self = try stored.content.level()
        } catch {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: error.reasonCode))
        }
        guard fingerprint == stored.fingerprint else {
            let code = MoonlitMechanismError.malformed("fingerprint").reasonCode
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: code))
        }
    }

    /// Encodes the stored form.
    public func encode(to encoder: any Encoder) throws {
        try Stored(content: Content(level: self), fingerprint: fingerprint).encode(to: encoder)
    }
}
