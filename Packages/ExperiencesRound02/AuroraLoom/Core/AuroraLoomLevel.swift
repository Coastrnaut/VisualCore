// AuroraLoomLevel — feature 301 (R02-G01-01) T-R02G0101-002 (FR-R02G0101-001, 007; clarifications Q1, Q2, Q5). An
// immutable Aurora Loom level: three ribbons (start steps and angular speed), four gates (position and target), the
// harmony's angular speed Ω, the tolerance, the move allowance and whether a tutorial precedes play. Its fingerprint is the
// SHA-256 hex of its canonical JSON (sorted keys, fingerprint excluded). A level whose start already wins is refused.
import Foundation
import VisualCoreMath

/// One ribbon of a level: its start steps and its angular speed.
public struct AuroraLoomRibbon: Sendable, Equatable, Hashable, Codable {
    /// The start wave step, 0 … 15.
    public let wave: Int
    /// The start phase step, 0 … 15.
    public let phase: Int
    /// Phase units the ribbon turns per tick, 0 … 256.
    public let omega: Int

    /// A ribbon; refuses steps outside 0 … 15 (`.level("wave")`, `.level("phase")`) and ω outside 0 … 256
    /// (`.level("omega")`).
    public init(wave: Int, phase: Int, omega: Int) throws(AuroraLoomError) {
        guard (0...15).contains(wave) else { throw .level("wave") }
        guard (0...15).contains(phase) else { throw .level("phase") }
        guard (0...256).contains(omega) else { throw .level("omega") }
        self.wave = wave
        self.phase = phase
        self.omega = omega
    }

    private enum CodingKeys: String, CodingKey { case wave, phase, omega }

    /// Decodes a ribbon and re-checks it.
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        do {
            try self.init(wave: c.decode(Int.self, forKey: .wave), phase: c.decode(Int.self, forKey: .phase),
                          omega: c.decode(Int.self, forKey: .omega))
        } catch let error as AuroraLoomError {
            throw DecodingError.dataCorrupted(.init(codingPath: c.codingPath, debugDescription: error.reasonCode))
        }
    }
}

/// One gate of a level: where it sits along the ribbons and the harmony it asks for at tick 0.
public struct AuroraLoomGate: Sendable, Equatable, Hashable, Codable {
    /// The position in sixteenths of a ribbon, 1 … 15.
    public let position: Int
    /// The target phase Θ at tick 0, 0 … 4,095.
    public let target: Int

    /// A gate; refuses a position outside 1 … 15 (`.level("position")`) or a target outside 0 … 4,095
    /// (`.level("target")`).
    public init(position: Int, target: Int) throws(AuroraLoomError) {
        guard (1...15).contains(position) else { throw .level("position") }
        guard (0..<AuroraLoomHarmony.unitsPerTurn).contains(target) else { throw .level("target") }
        self.position = position
        self.target = target
    }

    private enum CodingKeys: String, CodingKey { case position, target }

    /// Decodes a gate and re-checks it.
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        do {
            try self.init(position: c.decode(Int.self, forKey: .position), target: c.decode(Int.self, forKey: .target))
        } catch let error as AuroraLoomError {
            throw DecodingError.dataCorrupted(.init(codingPath: c.codingPath, debugDescription: error.reasonCode))
        }
    }
}

/// An immutable Aurora Loom level.
public struct AuroraLoomLevel: Sendable, Equatable {
    /// The stored-form schema.
    public static var schema: Int { 1 }

    /// The level id, a lowercase slug.
    public let id: String
    /// The design seed.
    public let seed: UInt64
    /// The difficulty band, 1 … 5.
    public let band: Int
    /// The three ribbons.
    public let ribbons: [AuroraLoomRibbon]
    /// The four gates, at distinct positions.
    public let gates: [AuroraLoomGate]
    /// The harmony's angular speed Ω in units per tick, a power of two 1 … 256.
    public let omega: Int
    /// The tolerance in units, 1 … 512 (inclusive).
    public let tolerance: Int
    /// The move allowance, 1 … 64.
    public let allowance: Int
    /// Whether a tutorial stage precedes play.
    public let tutorial: Bool
    /// The SHA-256 hex of the canonical JSON of the other fields.
    public let fingerprint: String

    /// A level; refuses any value outside its range and a start that already wins.
    ///
    /// - Throws: `.level(name)` for `"id"`, `"band"`, `"ribbons"`, `"gates"`, `"positions"` (not distinct),
    ///   `"omega"`, `"tolerance"`, `"allowance"` or `"start"` (the start steps already win).
    public init(id: String, seed: UInt64, band: Int, ribbons: [AuroraLoomRibbon], gates: [AuroraLoomGate], omega: Int,
                tolerance: Int, allowance: Int, tutorial: Bool = false) throws(AuroraLoomError) {
        guard Self.isSlug(id) else { throw .level("id") }
        guard (1...5).contains(band) else { throw .level("band") }
        guard ribbons.count == 3 else { throw .level("ribbons") }
        guard gates.count == 4 else { throw .level("gates") }
        guard Set(gates.map(\.position)).count == 4 else { throw .level("positions") }
        guard (1...256).contains(omega), omega & (omega - 1) == 0 else { throw .level("omega") }
        guard (1...512).contains(tolerance) else { throw .level("tolerance") }
        guard (1...64).contains(allowance) else { throw .level("allowance") }
        let content = Content(schema: Self.schema, id: id, seed: seed, band: band, ribbons: ribbons, gates: gates,
                              omega: omega, tolerance: tolerance, allowance: allowance, tutorial: tutorial)
        guard let data = try? Self.encoder.encode(content) else { throw .malformed("encode") }
        self.id = id
        self.seed = seed
        self.band = band
        self.ribbons = ribbons
        self.gates = gates
        self.omega = omega
        self.tolerance = tolerance
        self.allowance = allowance
        self.tutorial = tutorial
        self.fingerprint = StableHash.sha256Hex(Array(data))
        guard !AuroraLoomHarmony.wins(startSteps, level: self) else { throw .level("start") }
    }

    /// One period of the harmony in ticks, 4,096 / Ω.
    public var period: Int { AuroraLoomHarmony.unitsPerTurn / omega }

    /// The ribbons' start steps.
    public var startSteps: AuroraLoomSteps {
        AuroraLoomSteps(wave: ribbons.map(\.wave), phase: ribbons.map(\.phase))
    }

    /// The stored form: JSON with sorted keys holding the schema, every field and the fingerprint.
    public func encoded() -> Data {
        do {
            return try Self.encoder.encode(Stored(content: Content(level: self), fingerprint: fingerprint))
        } catch {
            preconditionFailure("an Aurora Loom level of checked integers always encodes: \(error)")
        }
    }

    /// Decodes a stored level, re-checking every rule and the fingerprint.
    ///
    /// - Throws: `.newerSchema(s)` above ``schema``; `.malformed(description)` for unreadable JSON, missing keys, a schema
    ///   below 1, any refusal of the initialiser or a fingerprint that does not match.
    public static func decode(_ data: Data) throws(AuroraLoomError) -> AuroraLoomLevel {
        struct Probe: Decodable { let schema: Int }
        let probe: Probe
        do { probe = try JSONDecoder().decode(Probe.self, from: data) } catch { throw .malformed("unreadable") }
        guard probe.schema <= schema else { throw .newerSchema(probe.schema) }
        guard probe.schema >= 1 else { throw .malformed("schema \(probe.schema)") }
        let stored: Stored
        do { stored = try JSONDecoder().decode(Stored.self, from: data) } catch { throw .malformed("unreadable") }
        let c = stored.content
        let level: AuroraLoomLevel
        do {
            level = try AuroraLoomLevel(id: c.id, seed: c.seed, band: c.band, ribbons: c.ribbons, gates: c.gates,
                                        omega: c.omega, tolerance: c.tolerance, allowance: c.allowance,
                                        tutorial: c.tutorial)
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
        let band: Int
        let ribbons: [AuroraLoomRibbon]
        let gates: [AuroraLoomGate]
        let omega: Int
        let tolerance: Int
        let allowance: Int
        let tutorial: Bool

        init(schema: Int, id: String, seed: UInt64, band: Int, ribbons: [AuroraLoomRibbon], gates: [AuroraLoomGate],
             omega: Int, tolerance: Int, allowance: Int, tutorial: Bool) {
            self.schema = schema
            self.id = id
            self.seed = seed
            self.band = band
            self.ribbons = ribbons
            self.gates = gates
            self.omega = omega
            self.tolerance = tolerance
            self.allowance = allowance
            self.tutorial = tutorial
        }

        init(level: AuroraLoomLevel) {
            schema = AuroraLoomLevel.schema
            id = level.id
            seed = level.seed
            band = level.band
            ribbons = level.ribbons
            gates = level.gates
            omega = level.omega
            tolerance = level.tolerance
            allowance = level.allowance
            tutorial = level.tutorial
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

        private enum Keys: String, CodingKey {
            case schema, id, seed, band, ribbons, gates, omega, tolerance, allowance, tutorial, fingerprint
        }

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

extension AuroraLoomLevel: Codable {
    /// Decodes a level through ``decode(_:)``'s rules.
    public init(from decoder: any Decoder) throws {
        let stored = try Stored(from: decoder)
        let c = stored.content
        guard c.schema <= Self.schema else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath,
                                                    debugDescription: AuroraLoomError.newerSchema(c.schema).reasonCode))
        }
        do {
            self = try AuroraLoomLevel(id: c.id, seed: c.seed, band: c.band, ribbons: c.ribbons, gates: c.gates,
                                       omega: c.omega, tolerance: c.tolerance, allowance: c.allowance,
                                       tutorial: c.tutorial)
        } catch {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: error.reasonCode))
        }
        guard fingerprint == stored.fingerprint else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath,
                                                    debugDescription: AuroraLoomError.malformed("fingerprint").reasonCode))
        }
    }

    /// Encodes the stored form.
    public func encode(to encoder: any Encoder) throws {
        try Stored(content: Content(level: self), fingerprint: fingerprint).encode(to: encoder)
    }
}
