// MyceliumArchitectLevel — feature 511 (R02-G22-01) T-R02G2201-002 (FR-R02G2201-001, 002, 010, 014; clarifications
// Q1, Q4, Q5; research R13, R15). An immutable, checked Mycelium Architect level: the board with its root, terminals,
// rocks, toxins and fixed nutrients; the field strength and reach; the curvature and obstacle penalties; the placement
// limits and starting seeds; the pulses, nutrient budget, weight limit and action budget. A level is refused when a
// value is out of range, two features share a cell, nothing can be placed or seeded, or its starting arrangement
// already wins. Its fingerprint is the SHA-256 hex of its canonical JSON (schema 1, sorted keys, fingerprint
// excluded); decode re-checks every rule. Modelled on `BinaryGardensLevel` (feature 501).

import Foundation
import VisualCoreMath

/// A checked Mycelium Architect level.
public struct MyceliumArchitectLevel: Sendable, Equatable {
    /// The stored-form schema.
    public static let schema = 1
    /// The difficulty range.
    public static let difficulties = 1...5
    /// The board width and height range.
    public static let sides = 4...32
    /// The terminal count range.
    public static let terminalCounts = 1...6
    /// The fixed nutrient count range.
    public static let fixedNutrientCounts = 0...8
    /// The nutrient strength range.
    public static let strengths = 1...8
    /// The nutrient reach range.
    public static let reaches = 1...16
    /// The curvature and obstacle penalty range.
    public static let penalties = 0...8
    /// The placed nutrient and placed blocker limit range.
    public static let placementLimits = 0...6
    /// The seed limit range.
    public static let seedLimits = 1...4
    /// The growth pulse range.
    public static let pulseRange = 1...128
    /// The nutrient budget range (an even 4094 keeps the network within 2048 nodes).
    public static let nutrientBudgets = 2...4094
    /// The action budget range.
    public static let budgets = 1...24

    /// The level's slug.
    public let id: String
    /// The level's seed.
    public let seed: UInt64
    /// The difficulty, 1 … 5.
    public let difficulty: Int
    /// The board width W, 4 … 32.
    public let width: Int
    /// The board height H, 4 … 32.
    public let height: Int
    /// The root cell.
    public let root: MyceliumArchitectCell
    /// The terminals, 1 … 6, in their numbered order.
    public let terminals: [MyceliumArchitectCell]
    /// The rocks, in ascending (row, column).
    public let rocks: [MyceliumArchitectCell]
    /// The toxic cells, in ascending (row, column).
    public let toxins: [MyceliumArchitectCell]
    /// The fixed nutrients, 0 … 8, in ascending (row, column).
    public let fixedNutrients: [MyceliumArchitectCell]
    /// The nutrient strength s, 1 … 8.
    public let strength: Int
    /// The nutrient reach R, 1 … 16.
    public let reach: Int
    /// The curvature penalty κ, 0 … 8.
    public let curvature: Int
    /// The obstacle penalty ο, 0 … 8.
    public let obstacle: Int
    /// The placed nutrient limit, 0 … 6.
    public let maxNutrients: Int
    /// The placed blocker limit, 0 … 6.
    public let maxBlockers: Int
    /// The seed limit, 1 … 4.
    public let maxSeeds: Int
    /// The locked starting seeds, 0 … maxSeeds, in ascending number.
    public let startSeeds: [MyceliumArchitectDirection]
    /// The growth pulses P, 1 … 128.
    public let pulses: Int
    /// The nutrient budget, 2 … 4094.
    public let nutrientBudget: Int
    /// The branch-weight limit, 2 … nutrientBudget.
    public let weightLimit: Int
    /// The action budget, 1 … 24.
    public let budget: Int
    /// Whether a tutorial precedes play.
    public let tutorial: Bool
    /// The SHA-256 hex of the canonical JSON content.
    public let fingerprint: String

    /// A level of the given values, checked.
    ///
    /// - Throws: `.level(name)` naming the first value outside its range or rule.
    public init(id: String, seed: UInt64, difficulty: Int, width: Int, height: Int, root: MyceliumArchitectCell,
                terminals: [MyceliumArchitectCell], rocks: [MyceliumArchitectCell], toxins: [MyceliumArchitectCell],
                fixedNutrients: [MyceliumArchitectCell], strength: Int, reach: Int, curvature: Int, obstacle: Int,
                maxNutrients: Int, maxBlockers: Int, maxSeeds: Int, startSeeds: [MyceliumArchitectDirection],
                pulses: Int, nutrientBudget: Int, weightLimit: Int, budget: Int,
                tutorial: Bool) throws(MyceliumArchitectError) {
        try self.init(id: id, seed: seed, difficulty: difficulty, width: width, height: height, root: root,
                      terminals: terminals, rocks: rocks, toxins: toxins, fixedNutrients: fixedNutrients,
                      strength: strength, reach: reach, curvature: curvature, obstacle: obstacle,
                      maxNutrients: maxNutrients, maxBlockers: maxBlockers, maxSeeds: maxSeeds,
                      startSeeds: startSeeds, pulses: pulses, nutrientBudget: nutrientBudget,
                      weightLimit: weightLimit, budget: budget, tutorial: tutorial, refusingAWin: true)
    }

    /// A level of the given values, checked; the "already won" rule only when `refusingAWin` (a probe that only reads
    /// reports passes false).
    init(id: String, seed: UInt64, difficulty: Int, width: Int, height: Int, root: MyceliumArchitectCell,
         terminals: [MyceliumArchitectCell], rocks: [MyceliumArchitectCell], toxins: [MyceliumArchitectCell],
         fixedNutrients: [MyceliumArchitectCell], strength: Int, reach: Int, curvature: Int, obstacle: Int,
         maxNutrients: Int, maxBlockers: Int, maxSeeds: Int, startSeeds: [MyceliumArchitectDirection],
         pulses: Int, nutrientBudget: Int, weightLimit: Int, budget: Int, tutorial: Bool,
         refusingAWin: Bool) throws(MyceliumArchitectError) {
        guard Self.isSlug(id) else { throw .level("id") }
        guard Self.difficulties.contains(difficulty) else { throw .level("difficulty") }
        guard Self.sides.contains(width) else { throw .level("width") }
        guard Self.sides.contains(height) else { throw .level("height") }
        func onBoard(_ c: MyceliumArchitectCell) -> Bool {
            (0..<width).contains(c.column) && (0..<height).contains(c.row)
        }
        guard onBoard(root) else { throw .level("root") }
        guard Self.terminalCounts.contains(terminals.count) else { throw .level("terminal count") }
        guard terminals.allSatisfy(onBoard) else { throw .level("terminal") }
        guard rocks.allSatisfy(onBoard) else { throw .level("rock") }
        guard toxins.allSatisfy(onBoard) else { throw .level("toxin") }
        guard Self.fixedNutrientCounts.contains(fixedNutrients.count) else { throw .level("fixed nutrient count") }
        guard fixedNutrients.allSatisfy(onBoard) else { throw .level("fixed nutrient") }
        let features = [root] + terminals + rocks + toxins + fixedNutrients
        guard Set(features).count == features.count else { throw .level("shared cell") }
        guard Self.strengths.contains(strength) else { throw .level("strength") }
        guard Self.reaches.contains(reach) else { throw .level("reach") }
        guard Self.penalties.contains(curvature) else { throw .level("curvature") }
        guard Self.penalties.contains(obstacle) else { throw .level("obstacle") }
        guard Self.placementLimits.contains(maxNutrients) else { throw .level("max nutrients") }
        guard Self.placementLimits.contains(maxBlockers) else { throw .level("max blockers") }
        guard Self.seedLimits.contains(maxSeeds) else { throw .level("max seeds") }
        guard startSeeds.count <= maxSeeds, Set(startSeeds).count == startSeeds.count else {
            throw .level("start seeds")
        }
        guard Self.pulseRange.contains(pulses) else { throw .level("pulses") }
        guard Self.nutrientBudgets.contains(nutrientBudget) else { throw .level("nutrient budget") }
        guard (2...nutrientBudget).contains(weightLimit) else { throw .level("weight limit") }
        guard Self.budgets.contains(budget) else { throw .level("budget") }
        guard maxNutrients > 0 || maxBlockers > 0 || startSeeds.count < maxSeeds else {
            throw .level("nothing placeable")
        }
        let content = Content(schema: Self.schema, id: id, seed: seed, difficulty: difficulty, width: width,
                              height: height, root: root, terminals: terminals, rocks: rocks.sorted(),
                              toxins: toxins.sorted(), fixedNutrients: fixedNutrients.sorted(), strength: strength,
                              reach: reach, curvature: curvature, obstacle: obstacle, maxNutrients: maxNutrients,
                              maxBlockers: maxBlockers, maxSeeds: maxSeeds, startSeeds: startSeeds.sorted(),
                              pulses: pulses, nutrientBudget: nutrientBudget, weightLimit: weightLimit,
                              budget: budget, tutorial: tutorial)
        guard let data = try? Self.encoder.encode(content) else { throw .malformed("encode") }
        self.id = id
        self.seed = seed
        self.difficulty = difficulty
        self.width = width
        self.height = height
        self.root = root
        self.terminals = terminals
        self.rocks = rocks.sorted()
        self.toxins = toxins.sorted()
        self.fixedNutrients = fixedNutrients.sorted()
        self.strength = strength
        self.reach = reach
        self.curvature = curvature
        self.obstacle = obstacle
        self.maxNutrients = maxNutrients
        self.maxBlockers = maxBlockers
        self.maxSeeds = maxSeeds
        self.startSeeds = startSeeds.sorted()
        self.pulses = pulses
        self.nutrientBudget = nutrientBudget
        self.weightLimit = weightLimit
        self.budget = budget
        self.tutorial = tutorial
        self.fingerprint = StableHash.sha256Hex(Array(data))
        if refusingAWin {
            guard !MyceliumArchitectGrowth.report(self, arrangement: start).wins else { throw .level("already won") }
        }
    }

    /// The starting arrangement: nothing placed, the starting seeds.
    public var start: MyceliumArchitectArrangement {
        MyceliumArchitectArrangement(nutrients: [], blockers: [], seeds: startSeeds)
    }

    /// The growth report of the starting arrangement.
    public var startReport: MyceliumArchitectReport { MyceliumArchitectGrowth.report(self, arrangement: start) }

    /// Whether `cell` is on the board.
    public func contains(_ cell: MyceliumArchitectCell) -> Bool {
        (0..<width).contains(cell.column) && (0..<height).contains(cell.row)
    }

    /// Whether `cell` is empty in `arrangement`: on the board and not the root, a terminal, a rock, a toxin, a fixed
    /// nutrient or a placed item.
    public func isEmpty(_ cell: MyceliumArchitectCell, in arrangement: MyceliumArchitectArrangement) -> Bool {
        contains(cell) && cell != root && !terminals.contains(cell) && !rocks.contains(cell)
            && !toxins.contains(cell) && !fixedNutrients.contains(cell) && !arrangement.nutrients.contains(cell)
            && !arrangement.blockers.contains(cell)
    }

    // MARK: Words (FR-R02G2201-014)

    /// A whole number in words with grouped digits, "1 792".
    public static func grouped(_ value: Int) -> String {
        let digits = String(abs(value))
        var out = ""
        for (i, ch) in digits.enumerated() {
            if i > 0 && (digits.count - i) % 3 == 0 { out.append(" ") }
            out.append(ch)
        }
        return value < 0 ? "−" + out : out
    }

    /// A cell in words with its nutrient value, its occupant and whether the predicted network reaches it:
    /// "(9, 4): nutrient value 36, empty, grown at pulse 7".
    public func cellDescription(_ cell: MyceliumArchitectCell, arrangement: MyceliumArchitectArrangement,
                                report: MyceliumArchitectReport) -> String {
        guard contains(cell) else { return "\(cell.words): off the board" }
        let value = report.field[cell.row][cell.column]
        let occupant: String
        if cell == root {
            occupant = "the root"
        } else if let t = terminals.firstIndex(of: cell) {
            occupant = "terminal \(t + 1)"
        } else if rocks.contains(cell) {
            occupant = "rock"
        } else if toxins.contains(cell) {
            occupant = "toxin"
        } else if fixedNutrients.contains(cell) {
            occupant = "fixed nutrient"
        } else if arrangement.nutrients.contains(cell) {
            occupant = "placed nutrient"
        } else if arrangement.blockers.contains(cell) {
            occupant = "blocker"
        } else {
            occupant = "empty"
        }
        let growth: String
        if let i = report.grown.firstIndex(of: cell) {
            growth = i == 0 ? "the network's root" : "grown at pulse \(report.grownPulses[i])"
        } else {
            growth = "not reached"
        }
        return "\(cell.words): nutrient value \(Self.grouped(value)), \(occupant), \(growth)"
    }

    /// A step in words: "tip 2 at pulse 7: east to (9, 4), score 12".
    public func stepDescription(_ step: MyceliumArchitectStep) -> String {
        var text = "tip \(step.tip + 1) at pulse \(step.pulse): \(step.direction.words) to \(step.to.words), "
            + "score \(Self.grouped(step.score))"
        if let born = step.newTip { text += ", fed and branched into tip \(born + 1)" }
        return text
    }

    /// A terminal in words: "terminal 1 reached at pulse 11, path weight 23" or "terminal 2 at (3, 7) not reached".
    public func terminalDescription(_ terminal: Int, report: MyceliumArchitectReport) -> String {
        if let pulse = report.terminalPulses[terminal], let weight = report.terminalPathWeights[terminal] {
            return "terminal \(terminal + 1) reached at pulse \(pulse), path weight \(Self.grouped(weight))"
        }
        return "terminal \(terminal + 1) at \(terminals[terminal].words) not reached"
    }

    /// A failure in words: "tip 3 grew into toxin at (5, 6) on pulse 9".
    public func failureDescription(_ failure: MyceliumArchitectFailure) -> String {
        switch failure {
        case let .toxic(pulse, tip, cell):
            "tip \(tip + 1) grew into toxin at \(cell.words) on pulse \(pulse)"
        case let .starved(pulse, tip, cell, weight, budget):
            "tip \(tip + 1) ran out of nutrient on pulse \(pulse): growing to \(cell.words) would make the branch "
                + "weight \(Self.grouped(weight)), above the budget of \(Self.grouped(budget))"
        case let .unreached(terminal):
            "terminal \(terminal + 1) at \(terminals[terminal].words) was not reached"
        case let .overweight(weight, limit):
            "the network's branch weight \(Self.grouped(weight)) is above the limit of \(Self.grouped(limit))"
        }
    }

    /// The progress in words: "branch weight 41 of 48, budget 60; 2 of 3 terminals reached; running now would fail:
    /// …; 4 actions left".
    public func progressDescription(report: MyceliumArchitectReport, actionsLeft: Int) -> String {
        var parts = ["branch weight \(Self.grouped(report.totalWeight)) of \(Self.grouped(weightLimit)), budget "
                        + Self.grouped(nutrientBudget),
                     "\(report.terminalsReached) of \(terminals.count) terminals reached"]
        if let failure = report.failure {
            parts.append("running now would fail: " + failureDescription(failure))
        } else {
            parts.append("running now would win")
        }
        parts.append(actionsLeft == 1 ? "1 action left" : "\(actionsLeft) actions left")
        return parts.joined(separator: "; ")
    }

    // MARK: Stored form (FR-R02G2201-010)

    /// The stored form: JSON with sorted keys holding the schema, every field and the fingerprint.
    public func encoded() -> Data {
        do {
            return try Self.encoder.encode(Stored(content: Content(level: self), fingerprint: fingerprint))
        } catch {
            preconditionFailure("a Mycelium Architect level of checked values always encodes: \(error)")
        }
    }

    /// Decodes a stored level, re-checking every rule and the fingerprint, in this order: broken JSON, a newer schema,
    /// a schema below 1 or a missing field, a value the initialiser refuses, a fingerprint that does not match.
    ///
    /// - Throws: `.malformed("unreadable")`, `.newerSchema(s)`, `.malformed("schema <s>")`, `.level(reason)` or
    ///   `.malformed("fingerprint")`.
    public static func decode(_ data: Data) throws(MyceliumArchitectError) -> MyceliumArchitectLevel {
        struct Probe: Decodable { let schema: Int }
        let probe: Probe
        do { probe = try JSONDecoder().decode(Probe.self, from: data) } catch { throw .malformed("unreadable") }
        guard probe.schema <= schema else { throw .newerSchema(probe.schema) }
        guard probe.schema >= 1 else { throw .malformed("schema \(probe.schema)") }
        let stored: Stored
        do { stored = try JSONDecoder().decode(Stored.self, from: data) } catch { throw .malformed("unreadable") }
        let level: MyceliumArchitectLevel
        do {
            level = try stored.content.level()
        } catch {
            if case .level = error { throw error }
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

    /// The fingerprinted content: every stored field but the fingerprint, the schema included.
    struct Content: Codable, Equatable {
        let schema: Int
        let id: String
        let seed: UInt64
        let difficulty: Int
        let width: Int
        let height: Int
        let root: MyceliumArchitectCell
        let terminals: [MyceliumArchitectCell]
        let rocks: [MyceliumArchitectCell]
        let toxins: [MyceliumArchitectCell]
        let fixedNutrients: [MyceliumArchitectCell]
        let strength: Int
        let reach: Int
        let curvature: Int
        let obstacle: Int
        let maxNutrients: Int
        let maxBlockers: Int
        let maxSeeds: Int
        let startSeeds: [MyceliumArchitectDirection]
        let pulses: Int
        let nutrientBudget: Int
        let weightLimit: Int
        let budget: Int
        let tutorial: Bool

        init(schema: Int, id: String, seed: UInt64, difficulty: Int, width: Int, height: Int,
             root: MyceliumArchitectCell, terminals: [MyceliumArchitectCell], rocks: [MyceliumArchitectCell],
             toxins: [MyceliumArchitectCell], fixedNutrients: [MyceliumArchitectCell], strength: Int, reach: Int,
             curvature: Int, obstacle: Int, maxNutrients: Int, maxBlockers: Int, maxSeeds: Int,
             startSeeds: [MyceliumArchitectDirection], pulses: Int, nutrientBudget: Int, weightLimit: Int,
             budget: Int, tutorial: Bool) {
            self.schema = schema
            self.id = id
            self.seed = seed
            self.difficulty = difficulty
            self.width = width
            self.height = height
            self.root = root
            self.terminals = terminals
            self.rocks = rocks
            self.toxins = toxins
            self.fixedNutrients = fixedNutrients
            self.strength = strength
            self.reach = reach
            self.curvature = curvature
            self.obstacle = obstacle
            self.maxNutrients = maxNutrients
            self.maxBlockers = maxBlockers
            self.maxSeeds = maxSeeds
            self.startSeeds = startSeeds
            self.pulses = pulses
            self.nutrientBudget = nutrientBudget
            self.weightLimit = weightLimit
            self.budget = budget
            self.tutorial = tutorial
        }

        init(level: MyceliumArchitectLevel) {
            self.init(schema: MyceliumArchitectLevel.schema, id: level.id, seed: level.seed,
                      difficulty: level.difficulty, width: level.width, height: level.height, root: level.root,
                      terminals: level.terminals, rocks: level.rocks, toxins: level.toxins,
                      fixedNutrients: level.fixedNutrients, strength: level.strength, reach: level.reach,
                      curvature: level.curvature, obstacle: level.obstacle, maxNutrients: level.maxNutrients,
                      maxBlockers: level.maxBlockers, maxSeeds: level.maxSeeds, startSeeds: level.startSeeds,
                      pulses: level.pulses, nutrientBudget: level.nutrientBudget, weightLimit: level.weightLimit,
                      budget: level.budget, tutorial: level.tutorial)
        }

        /// The level of this content, re-checked.
        func level() throws(MyceliumArchitectError) -> MyceliumArchitectLevel {
            try MyceliumArchitectLevel(id: id, seed: seed, difficulty: difficulty, width: width, height: height,
                                       root: root, terminals: terminals, rocks: rocks, toxins: toxins,
                                       fixedNutrients: fixedNutrients, strength: strength, reach: reach,
                                       curvature: curvature, obstacle: obstacle, maxNutrients: maxNutrients,
                                       maxBlockers: maxBlockers, maxSeeds: maxSeeds, startSeeds: startSeeds,
                                       pulses: pulses, nutrientBudget: nutrientBudget, weightLimit: weightLimit,
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

extension MyceliumArchitectLevel: Codable {
    /// Decodes a level through ``decode(_:)``'s rules.
    public init(from decoder: any Decoder) throws {
        let stored = try Stored(from: decoder)
        guard stored.content.schema <= Self.schema else {
            let code = MyceliumArchitectError.newerSchema(stored.content.schema).reasonCode
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: code))
        }
        guard stored.content.schema >= 1 else {
            let code = MyceliumArchitectError.malformed("schema").reasonCode
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: code))
        }
        do {
            self = try stored.content.level()
        } catch {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: error.reasonCode))
        }
        guard fingerprint == stored.fingerprint else {
            let code = MyceliumArchitectError.malformed("fingerprint").reasonCode
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: code))
        }
    }

    /// Encodes the stored form.
    public func encode(to encoder: any Encoder) throws {
        try Stored(content: Content(level: self), fingerprint: fingerprint).encode(to: encoder)
    }
}
