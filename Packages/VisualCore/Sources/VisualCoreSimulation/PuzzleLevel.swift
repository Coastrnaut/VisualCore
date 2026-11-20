// PuzzleLevel — feature 223 (R02-F23) T-R02F23-003 (FR-R02F23-001, 007; clarification Q2; SC-R02F23-001; research R2).
// An immutable puzzle level: rules id, start, explicit solution (at most 4,096 moves), uniqueness promise, fairness
// budget and optional generator seed. Its identity is the SHA-256 hex (StableHash) of its canonical JSON: schema 1,
// sorted keys, the identity excluded, and a missing seed written as an explicit `null` so the canonical bytes of a
// level are fixed. The stored form is the canonical content plus the identity; decoding re-runs every rule, recomputes
// the identity and refuses a mismatch as edited.
import Foundation
import VisualCoreMath

/// An immutable puzzle level of one rules family, with a content identity.
public struct PuzzleLevel<Rules: PuzzleRules>: Sendable, Equatable {
    /// The stored-form schema this version writes and the newest it reads.
    public static var schema: Int { 1 }

    /// The id of the rules the level is played with, a lowercase slug of 1 … 64 characters.
    public let rulesID: String
    /// The starting position.
    public let start: Rules.State
    /// The explicit solution, at most ``FairnessBudget/maxLength`` moves.
    public let solution: [Rules.Move]
    /// What the level promises about its solutions.
    public let uniqueness: PuzzleUniqueness
    /// The bounds the level must stay within.
    public let budget: FairnessBudget
    /// The generator seed that produced the level, if it was generated.
    public let seed: UInt64?
    /// The SHA-256 of the canonical JSON content as 64 lower-case hexadecimal digits.
    public let identity: String

    /// A level of the given content; its identity is computed from it.
    ///
    /// - Throws: `.rulesID` unless `rulesID` is a lowercase slug of 1 … 64 characters; `.solutionLength` when the
    ///   solution has more than ``FairnessBudget/maxLength`` (4,096) moves. Whether the solution is legal, solves the
    ///   level and fits the budget is the validator's verdict, not a refusal here.
    public init(rulesID: String, start: Rules.State, solution: [Rules.Move], uniqueness: PuzzleUniqueness = .none,
                budget: FairnessBudget, seed: UInt64? = nil) throws(PuzzleError) {
        guard PuzzleError.isSlug(rulesID) else { throw .rulesID }
        guard solution.count <= FairnessBudget.maxLength else { throw .solutionLength }
        self.rulesID = rulesID
        self.start = start
        self.solution = solution
        self.uniqueness = uniqueness
        self.budget = budget
        self.seed = seed
        self.identity = Self.identity(of: Form(schema: Self.schema, rulesID: rulesID, start: start, solution: solution,
                                               uniqueness: uniqueness, budget: budget, seed: seed, identity: nil))
    }

    /// The content and, in the stored form, the identity. The seed key is always written (`null` when absent); the
    /// identity key is written only when set, so the form without it is the canonical content that is hashed.
    private struct Form: Codable {
        var schema: Int
        var rulesID: String
        var start: Rules.State
        var solution: [Rules.Move]
        var uniqueness: PuzzleUniqueness
        var budget: FairnessBudget
        var seed: UInt64?
        var identity: String?

        private enum CodingKeys: String, CodingKey {
            case schema, rulesID, start, solution, uniqueness, budget, seed, identity
        }

        init(schema: Int, rulesID: String, start: Rules.State, solution: [Rules.Move], uniqueness: PuzzleUniqueness,
             budget: FairnessBudget, seed: UInt64?, identity: String?) {
            self.schema = schema
            self.rulesID = rulesID
            self.start = start
            self.solution = solution
            self.uniqueness = uniqueness
            self.budget = budget
            self.seed = seed
            self.identity = identity
        }

        /// Reads a stored form; every key is required, the seed may be `null`.
        init(from decoder: any Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            schema = try c.decode(Int.self, forKey: .schema)
            rulesID = try c.decode(String.self, forKey: .rulesID)
            start = try c.decode(Rules.State.self, forKey: .start)
            solution = try c.decode([Rules.Move].self, forKey: .solution)
            uniqueness = try c.decode(PuzzleUniqueness.self, forKey: .uniqueness)
            budget = try c.decode(FairnessBudget.self, forKey: .budget)
            guard c.contains(.seed) else {
                throw DecodingError.keyNotFound(CodingKeys.seed, .init(codingPath: c.codingPath,
                                                                       debugDescription: "seed missing"))
            }
            seed = try c.decodeIfPresent(UInt64.self, forKey: .seed)
            identity = try c.decode(String.self, forKey: .identity)
        }

        func encode(to encoder: any Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(schema, forKey: .schema)
            try c.encode(rulesID, forKey: .rulesID)
            try c.encode(start, forKey: .start)
            try c.encode(solution, forKey: .solution)
            try c.encode(uniqueness, forKey: .uniqueness)
            try c.encode(budget, forKey: .budget)
            if let seed { try c.encode(seed, forKey: .seed) } else { try c.encodeNil(forKey: .seed) }
            try c.encodeIfPresent(identity, forKey: .identity)
        }
    }

    /// Only the schema, read before the rest so a newer layout is recognised.
    private struct SchemaProbe: Decodable {
        var schema: Int
    }

    /// The canonical JSON of `form` with sorted keys.
    private static func json(_ form: Form) -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        do {
            return try encoder.encode(form)
        } catch {
            // The rules' State and Move are Codable by contract and every other value is an integer, string or
            // array; a State or Move whose encoding throws breaks the PuzzleRules contract, a programming error.
            preconditionFailure("PuzzleLevel.encoded: \(error)")
        }
    }

    /// The identity of `form`'s content (its identity field must be nil).
    private static func identity(of form: Form) -> String {
        StableHash.sha256Hex(Array(json(form)))
    }

    /// This level as its stored form.
    private var storedForm: Form {
        Form(schema: Self.schema, rulesID: rulesID, start: start, solution: solution, uniqueness: uniqueness,
             budget: budget, seed: seed, identity: identity)
    }

    /// Rebuilds a level from a stored form with every rule of the initialiser and checks its identity.
    private init(stored s: Form) throws(PuzzleError) {
        guard s.schema <= Self.schema else { throw .newerSchema(s.schema) }
        guard s.schema >= 1 else { throw .malformed("schema \(s.schema)") }
        do {
            try self.init(rulesID: s.rulesID, start: s.start, solution: s.solution, uniqueness: s.uniqueness,
                          budget: s.budget, seed: s.seed)
        } catch {
            throw .malformed(error.reasonCode)
        }
        guard identity == s.identity else { throw .edited }
    }

    /// The stored form as JSON with sorted keys: the canonical content plus the identity.
    public func encoded() -> Data {
        Self.json(storedForm)
    }

    /// Reads a level from its stored form, re-runs every rule and recomputes the identity.
    ///
    /// - Throws: `.newerSchema(s)` for a schema above ``schema``; `.malformed(description)` for unreadable JSON,
    ///   missing or mistyped keys, a schema below 1, a bad budget or any refusal of the initialiser; `.edited` when the
    ///   stored identity does not match the content.
    public static func decode(_ data: Data) throws(PuzzleError) -> PuzzleLevel {
        let decoder = JSONDecoder()
        let probe: SchemaProbe
        do {
            probe = try decoder.decode(SchemaProbe.self, from: data)
        } catch {
            throw .malformed("unreadable: \(error)")
        }
        guard probe.schema <= schema else { throw .newerSchema(probe.schema) }
        let stored: Form
        do {
            stored = try decoder.decode(Form.self, from: data)
        } catch {
            throw .malformed("unreadable: \(error)")
        }
        return try PuzzleLevel(stored: stored)
    }
}

extension PuzzleLevel: Codable {
    /// Encodes the level as its schema-1 stored form.
    public func encode(to encoder: any Encoder) throws {
        try storedForm.encode(to: encoder)
    }

    /// Decodes a level with every rule of ``decode(_:)``; a refusal is a `DecodingError.dataCorrupted` whose
    /// description is the reason code.
    public init(from decoder: any Decoder) throws {
        let stored = try Form(from: decoder)
        do {
            try self.init(stored: stored)
        } catch {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: error.reasonCode))
        }
    }
}
