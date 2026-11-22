// FacetedForgeLevel — feature 371 (R02-G08-01) T-R02G0801-002 (FR-R02G0801-001, 009, 013; clarifications Q1, Q5). An
// immutable Faceted Forge level: a convex crystal given by 4 … 14 half-spaces of the 13 directions, bounded (a closed
// solid: every edge on exactly two faces) and inside the box −6 … 6 on every axis; a cut budget (1 … 12); a sliver
// limit (a fraction of the crystal's volume, 0 < s < 1/2); and the target: a multiset of at least two pieces, each a
// share of the crystal's volume and a face count (4 … 26), whose shares sum to one. A difficulty (1 … 5) and whether a
// tutorial precedes play complete it. Its fingerprint is the SHA-256 hex of its canonical JSON (sorted keys,
// fingerprint excluded); the stored form is re-checked on decode.
import Foundation
import VisualCoreMath

/// One entry of a level's target: a share of the crystal's volume and a face count.
public struct FacetedForgeTargetPiece: Sendable, Hashable, Codable, Comparable {
    /// The piece's share of the crystal's volume.
    public let share: FacetedForgeFraction
    /// The piece's number of faces.
    public let faces: Int

    /// A target entry.
    public init(share: FacetedForgeFraction, faces: Int) {
        self.share = share
        self.faces = faces
    }

    /// Ordered by share descending, then faces descending (the canonical order of pieces).
    public static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.share != rhs.share ? rhs.share < lhs.share : lhs.faces > rhs.faces
    }
}

/// An immutable, fingerprinted Faceted Forge level.
public struct FacetedForgeLevel: Sendable, Equatable {
    /// The stored-form schema.
    public static var schema: Int { 1 }
    /// The allowed numbers of crystal half-spaces.
    public static let crystalPlanes: ClosedRange<Int> = 4...14
    /// The box every crystal corner lies in, on every axis.
    public static let box: ClosedRange<Int64> = -6...6
    /// The allowed cut budgets.
    /// Widened from 1 … 12 to 1 … 20 by feature 372 (R02-G08-02) for the manifest's budgets 8 … 19; additive.
    public static let budgets: ClosedRange<Int> = 1...20
    /// The allowed face counts of a target entry.
    /// Widened from 4 … 26 to 4 … 34 by feature 372 (14 crystal planes + 20 cuts); additive.
    public static let faceCounts: ClosedRange<Int> = 4...34

    /// The level id, a lowercase slug.
    public let id: String
    /// The seed the level was built from.
    public let seed: UInt64
    /// The difficulty, 1 … 5.
    public let difficulty: Int
    /// The crystal's bounding half-spaces, sorted (as given; the crystal keeps only those that are faces).
    public let planes: [FacetedForgeHalfSpace]
    /// The cuts a play may spend.
    public let budget: Int
    /// The smallest share of the crystal a piece may have (strictly smaller fails the level).
    public let sliver: FacetedForgeFraction
    /// The target pieces, in canonical order.
    public let target: [FacetedForgeTargetPiece]
    /// Whether a tutorial precedes play.
    public let tutorial: Bool
    /// The SHA-256 hex of the canonical JSON.
    public let fingerprint: String
    /// The crystal.
    public let crystal: FacetedForgePiece

    /// A level; refuses any value outside its range and any broken rule.
    ///
    /// - Throws: `.level(name)` for `"id"`, `"difficulty"`, `"planes"`, `"order"`, `"plane"`, `"empty"`, `"closed"`,
    ///   `"box"`, `"budget"`, `"sliver"`, `"target"`, `"faces"` or `"shares"`.
    public init(id: String, seed: UInt64, difficulty: Int, planes: [FacetedForgeHalfSpace], budget: Int,
                sliver: FacetedForgeFraction, target: [FacetedForgeTargetPiece],
                tutorial: Bool = false) throws(FacetedForgeError) {
        guard Self.isSlug(id) else { throw .level("id") }
        guard (1...5).contains(difficulty) else { throw .level("difficulty") }
        guard Self.crystalPlanes.contains(planes.count) else { throw .level("planes") }
        guard zip(planes, planes.dropFirst()).allSatisfy({ $0 < $1 }) else { throw .level("order") }
        let crystal: FacetedForgePiece = try FacetedForgePiece(halfSpaces: planes)
        guard crystal.edgeIncidence.allSatisfy({ $0 == 2 }) else { throw .level("closed") }
        for p in crystal.corners {
            for c in [p.x, p.y, p.z] where c.denominator != 1 || !Self.box.contains(c.numerator) {
                guard c.denominator == 1, Self.box.contains(c.numerator) else { throw .level("box") }
            }
        }
        guard Self.budgets.contains(budget) else { throw .level("budget") }
        let half: FacetedForgeFraction = try FacetedForgeFraction(1, 2)
        guard sliver.sign > 0, sliver < half else { throw .level("sliver") }
        guard target.count >= 2, target.count <= budget + 1 else { throw .level("target") }
        guard zip(target, target.dropFirst()).allSatisfy({ !($1 < $0) }) else { throw .level("order") }
        guard target.allSatisfy({ Self.faceCounts.contains($0.faces) }) else { throw .level("faces") }
        var total: FacetedForgeFraction = .zero
        for entry in target {
            guard entry.share.sign > 0, !(entry.share < sliver) else { throw .level("shares") }
            total = try total.adding(entry.share)
        }
        guard total == .one else { throw .level("shares") }
        let content = Content(schema: Self.schema, id: id, seed: seed, difficulty: difficulty, planes: planes,
                              budget: budget, sliver: sliver, target: target, tutorial: tutorial)
        guard let data = try? Self.encoder.encode(content) else { throw .malformed("encode") }
        self.id = id
        self.seed = seed
        self.difficulty = difficulty
        self.planes = planes
        self.budget = budget
        self.sliver = sliver
        self.target = target
        self.tutorial = tutorial
        self.crystal = crystal
        self.fingerprint = StableHash.sha256Hex(Array(data))
    }

    /// A share in words: "a half", "a third", "a quarter", otherwise "n/d".
    public static func shareText(_ share: FacetedForgeFraction) -> String {
        switch (share.numerator, share.denominator) {
        case (1, 1): "the whole crystal"
        case (1, 2): "a half"
        case (1, 3): "a third"
        case (1, 4): "a quarter"
        default: share.text
        }
    }

    /// Piece `index` (0-based) in words: "piece 1: a quarter of the crystal, 6 faces" (FR-R02G0801-013).
    public func pieceName(_ index: Int, share: FacetedForgeFraction, faces: Int) -> String {
        "piece \(index + 1): \(Self.shareText(share)) of the crystal, \(faces) faces"
    }

    /// The target in words: "2 pieces: a half of the crystal with 6 faces; a half of the crystal with 6 faces".
    public func targetDescription() -> String {
        let parts: [String] = target.map { "\(Self.shareText($0.share)) of the crystal with \($0.faces) faces" }
        return "\(target.count) pieces: " + parts.joined(separator: "; ")
    }

    /// The stored form: JSON with sorted keys holding the schema, every field and the fingerprint.
    public func encoded() -> Data {
        do {
            return try Self.encoder.encode(Stored(content: Content(level: self), fingerprint: fingerprint))
        } catch {
            preconditionFailure("a Faceted Forge level of checked values always encodes: \(error)")
        }
    }

    /// Decodes a stored level, re-checking every rule and the fingerprint.
    ///
    /// - Throws: `.newerSchema(s)` above ``schema``; `.malformed(description)` for unreadable JSON, missing keys, a
    /// schema
    ///   below 1, any refusal of the initialiser or a fingerprint that does not match.
    public static func decode(_ data: Data) throws(FacetedForgeError) -> FacetedForgeLevel {
        struct Probe: Decodable { let schema: Int }
        let probe: Probe
        do { probe = try JSONDecoder().decode(Probe.self, from: data) } catch { throw .malformed("unreadable") }
        guard probe.schema <= schema else { throw .newerSchema(probe.schema) }
        guard probe.schema >= 1 else { throw .malformed("schema \(probe.schema)") }
        let stored: Stored
        do { stored = try JSONDecoder().decode(Stored.self, from: data) } catch { throw .malformed("unreadable") }
        let level: FacetedForgeLevel
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
        let planes: [FacetedForgeHalfSpace]
        let budget: Int
        let sliver: FacetedForgeFraction
        let target: [FacetedForgeTargetPiece]
        let tutorial: Bool

        init(schema: Int, id: String, seed: UInt64, difficulty: Int, planes: [FacetedForgeHalfSpace], budget: Int,
             sliver: FacetedForgeFraction, target: [FacetedForgeTargetPiece], tutorial: Bool) {
            self.schema = schema
            self.id = id
            self.seed = seed
            self.difficulty = difficulty
            self.planes = planes
            self.budget = budget
            self.sliver = sliver
            self.target = target
            self.tutorial = tutorial
        }

        init(level: FacetedForgeLevel) {
            self.init(schema: FacetedForgeLevel.schema, id: level.id, seed: level.seed, difficulty: level.difficulty,
                      planes: level.planes, budget: level.budget, sliver: level.sliver, target: level.target,
                      tutorial: level.tutorial)
        }

        /// The level of this content, re-checked.
        func level() throws(FacetedForgeError) -> FacetedForgeLevel {
            try FacetedForgeLevel(id: id, seed: seed, difficulty: difficulty, planes: planes, budget: budget,
                                  sliver: sliver, target: target, tutorial: tutorial)
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

extension FacetedForgeLevel: Codable {
    /// Decodes a level through ``decode(_:)``'s rules.
    public init(from decoder: any Decoder) throws {
        let stored = try Stored(from: decoder)
        guard stored.content.schema <= Self.schema else {
            let code = FacetedForgeError.newerSchema(stored.content.schema).reasonCode
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: code))
        }
        do {
            self = try stored.content.level()
        } catch {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: error.reasonCode))
        }
        guard fingerprint == stored.fingerprint else {
            let code = FacetedForgeError.malformed("fingerprint").reasonCode
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: code))
        }
    }

    /// Encodes the stored form.
    public func encode(to encoder: any Encoder) throws {
        try Stored(content: Content(level: self), fingerprint: fingerprint).encode(to: encoder)
    }
}
