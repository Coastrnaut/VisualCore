// PlantGrammar — feature 219 (R02-F19) T-R02F19-002 (FR-R02F19-001, FR-R02F19-006; clarifications Q1, Q2, Q5;
// data-model.md). A bracketed, stochastic L-system (Prusinkiewicz and Lindenmayer, The Algorithmic Beauty of Plants,
// 1990): a start word, context-free rules that replace one character by one of up to eight weighted successor words,
// a generation count and the turtle's settings and seed. Stored as JSON schema 1 with sorted keys; a newer schema is
// refused, damaged or out-of-range data is refused with its code.
import Foundation

/// One rewriting rule: a predecessor character and its weighted successor words.
public struct PlantRule: Sendable, Equatable {
    /// The most successors of a rule.
    public static let maxSuccessors = 8
    /// The longest successor word.
    public static let maxWordLength = 256

    /// The character the rule rewrites.
    public let predecessor: Character
    /// The successor words with their weights (finite and positive); one is chosen per occurrence by cumulative weight.
    public let successors: [(word: String, weight: Double)]

    /// A rule with one successor (no chance).
    public init(_ predecessor: Character, _ word: String) throws(PlantError) {
        try self.init(predecessor, weighted: [(word, 1)])
    }

    /// A rule with weighted successors; refuses 0 or more than ``maxSuccessors`` successors, an empty or too long word
    /// with ``PlantError/rule(_:)`` and a weight that is not finite and positive with ``PlantError/weight(_:)``.
    public init(_ predecessor: Character, weighted: [(String, Double)]) throws(PlantError) {
        guard (1...Self.maxSuccessors).contains(weighted.count) else { throw .rule("successors of \(predecessor)") }
        for (word, weight) in weighted {
            guard !word.isEmpty, word.count <= Self.maxWordLength else { throw .rule("word of \(predecessor)") }
            guard weight.isFinite, weight > 0 else { throw .weight(String(predecessor)) }
        }
        self.predecessor = predecessor
        successors = weighted.map { (word: $0.0, weight: $0.1) }
    }

    /// Rules are equal when their predecessors and successor lists (words and weights, in order) are equal.
    public static func == (a: PlantRule, b: PlantRule) -> Bool {
        a.predecessor == b.predecessor && a.successors.count == b.successors.count
            && zip(a.successors, b.successors).allSatisfy { $0.word == $1.word && $0.weight == $1.weight }
    }
}

/// A plant's grammar and turtle settings.
public struct PlantGrammar: Sendable, Equatable {
    /// The stored-form schema.
    public static let schema = 1
    /// The most generations.
    public static let maxGenerations = 12
    /// The longest word.
    public static let maxWord = 1_048_576
    /// The most rules.
    public static let maxRules = 64
    /// The most branches a word may draw.
    public static let maxBranches = 65_536

    /// The start word (axiom), 1 … ``maxWord`` symbols.
    public let start: String
    /// The rules, at most ``maxRules``, with distinct predecessors.
    public let rules: [PlantRule]
    /// The generations of rewriting, 0 … ``maxGenerations``.
    public let generations: Int
    /// The turn angle δ in radians, 0 … π.
    public let angle: Double
    /// The length drawn by F, finite and positive.
    public let step: Double
    /// The starting branch radius, finite and positive.
    public let radius: Double
    /// The factor applied to the radius by `!`, 0 < k ≤ 1.
    public let radiusFactor: Double
    /// The seed of the weighted choices.
    public let seed: UInt64

    /// Creates the grammar or refuses a value outside its range with the matching ``PlantError``.
    public init(start: String, rules: [PlantRule], generations: Int, angle: Double, step: Double, radius: Double = 0.05,
                radiusFactor: Double = 0.8, seed: UInt64 = 0) throws(PlantError) {
        guard !start.isEmpty, start.count <= Self.maxWord else { throw .rule("start") }
        guard rules.count <= Self.maxRules else { throw .rule("too many rules") }
        var seen = Set<Character>()
        for rule in rules {
            guard seen.insert(rule.predecessor).inserted else { throw .rule("duplicate \(rule.predecessor)") }
        }
        guard (0...Self.maxGenerations).contains(generations) else { throw .generations(generations) }
        guard angle.isFinite, angle >= 0, angle <= Double.pi else { throw .turtleParameter("angle") }
        guard step.isFinite, step > 0 else { throw .turtleParameter("step") }
        guard radius.isFinite, radius > 0 else { throw .turtleParameter("radius") }
        guard radiusFactor.isFinite, radiusFactor > 0, radiusFactor <= 1 else { throw .turtleParameter("radiusFactor") }
        self.start = start
        self.rules = rules
        self.generations = generations
        self.angle = angle
        self.step = step
        self.radius = radius
        self.radiusFactor = radiusFactor
        self.seed = seed
    }

    /// The rule for `symbol`, or nil when the symbol is kept as it is.
    public func rule(for symbol: Character) -> PlantRule? { rules.first { $0.predecessor == symbol } }

    /// The stored form: JSON with sorted keys.
    public func encoded() -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        // Strings, integers and finite doubles only, so encoding cannot fail.
        return (try? encoder.encode(self)) ?? Data()
    }

    /// Reads a stored grammar; refuses a newer schema, damaged data and values outside their ranges.
    public static func decode(_ data: Data) throws(PlantError) -> PlantGrammar {
        do {
            return try JSONDecoder().decode(PlantGrammar.self, from: data)
        } catch let error as PlantError {
            throw error
        } catch {
            throw .malformed(String(describing: error))
        }
    }
}

extension PlantGrammar: Codable {
    private enum Key: String, CodingKey {
        case schema, start, rules, generations, angle, step, radius, radiusFactor, seed
    }

    private struct StoredSuccessor: Codable {
        let word: String
        let weight: Double
    }

    private struct StoredRule: Codable {
        let predecessor: String
        let successors: [StoredSuccessor]
    }

    /// Reads the stored form (see ``decode(_:)``).
    public init(from decoder: any Decoder) throws {
        let c: KeyedDecodingContainer<Key>
        let schemaValue: Int
        do {
            c = try decoder.container(keyedBy: Key.self)
            schemaValue = try c.decode(Int.self, forKey: .schema)
        } catch {
            throw PlantError.malformed(String(describing: error))
        }
        guard schemaValue <= Self.schema else { throw PlantError.newerSchema(schemaValue) }
        guard schemaValue == Self.schema else { throw PlantError.malformed("schema \(schemaValue)") }
        do {
            let stored = try c.decode([StoredRule].self, forKey: .rules)
            var rules: [PlantRule] = []
            for rule in stored {
                guard rule.predecessor.count == 1, let symbol = rule.predecessor.first else {
                    throw PlantError.malformed("predecessor \(rule.predecessor)")
                }
                rules.append(try PlantRule(symbol, weighted: rule.successors.map { ($0.word, $0.weight) }))
            }
            try self.init(start: try c.decode(String.self, forKey: .start), rules: rules,
                          generations: try c.decode(Int.self, forKey: .generations),
                          angle: try c.decode(Double.self, forKey: .angle),
                          step: try c.decode(Double.self, forKey: .step),
                          radius: try c.decode(Double.self, forKey: .radius),
                          radiusFactor: try c.decode(Double.self, forKey: .radiusFactor),
                          seed: try c.decode(UInt64.self, forKey: .seed))
        } catch let error as PlantError {
            throw error
        } catch {
            throw PlantError.malformed(String(describing: error))
        }
    }

    /// Writes the stored form with the schema.
    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: Key.self)
        try c.encode(Self.schema, forKey: .schema)
        try c.encode(start, forKey: .start)
        let stored = rules.map { rule in
            StoredRule(predecessor: String(rule.predecessor),
                       successors: rule.successors.map { StoredSuccessor(word: $0.word, weight: $0.weight) })
        }
        try c.encode(stored, forKey: .rules)
        try c.encode(generations, forKey: .generations)
        try c.encode(angle, forKey: .angle)
        try c.encode(step, forKey: .step)
        try c.encode(radius, forKey: .radius)
        try c.encode(radiusFactor, forKey: .radiusFactor)
        try c.encode(seed, forKey: .seed)
    }
}
