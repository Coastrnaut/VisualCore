// HueCompassLevel — feature 331 (R02-G04-01) T-R02G0401-002 (FR-R02G0401-001, 008; clarifications Q1, Q3, Q5). An
// immutable Hue Compass level: the hue offset (0 … 23), the fog density of every bearing (96 × 0 … 9), the hidden target
// bearing, the start bearing (never already within the bearing tolerance of the target), the bearing tolerance
// (0 … 4), the band tolerance (0 … 2), the allowance shared by probes and the selection (2 … 24), the band (1 … 5) and
// whether a tutorial precedes play. Its fingerprint is the SHA-256 hex of its canonical JSON (sorted keys, fingerprint
// excluded); the stored form is re-checked on decode.
import Foundation
import VisualCoreMath

/// An immutable, fingerprinted Hue Compass level.
public struct HueCompassLevel: Sendable, Equatable {
    /// The stored-form schema.
    public static var schema: Int { 1 }
    /// The allowances a level may have.
    public static let allowances: ClosedRange<Int> = 2...24
    /// The bearing tolerances a level may have.
    public static let bearingTolerances: ClosedRange<Int> = 0...4
    /// The band tolerances a level may have.
    public static let bandTolerances: ClosedRange<Int> = 0...2
    /// The densities one bearing's fog may have.
    public static let densities: ClosedRange<Int> = 0...9

    /// The level id, a lowercase slug.
    public let id: String
    /// The seed the level was built from.
    public let seed: UInt64
    /// The band, 1 … 5.
    public let band: Int
    /// The hue offset, 0 … 23: the band of bearing b is (⌊b/4⌋ + offset) mod 24.
    public let offset: Int
    /// The fog density of every bearing, 96 values of 0 … 9.
    public let fog: [Int]
    /// The hidden target bearing, 0 … 95.
    public let target: Int
    /// The bearing the compass points at when play begins, 0 … 95.
    public let start: Int
    /// The largest circular bearing distance a winning selection may have from the target.
    public let bearingTolerance: Int
    /// The largest circular band distance a winning selection's band may have from the target's band.
    public let bandTolerance: Int
    /// The units probes and the selection may spend together.
    public let allowance: Int
    /// Whether a tutorial precedes play.
    public let tutorial: Bool
    /// The SHA-256 hex of the canonical JSON.
    public let fingerprint: String

    /// A level; refuses any value outside its range and a start already within the bearing tolerance of the target.
    ///
    /// - Throws: `.level(name)` for `"id"`, `"band"`, `"offset"`, `"fog"`, `"target"`, `"start"`,
    ///   `"bearing-tolerance"`, `"band-tolerance"`, `"allowance"` or `"solved-at-start"`.
    public init(id: String, seed: UInt64, band: Int, offset: Int, fog: [Int], target: Int, start: Int,
                bearingTolerance: Int, bandTolerance: Int, allowance: Int,
                tutorial: Bool = false) throws(HueCompassError) {
        let bearings: ClosedRange<Int> = 0...(HueCompassWheel.bearings - 1)
        guard Self.isSlug(id) else { throw .level("id") }
        guard (1...5).contains(band) else { throw .level("band") }
        guard (0..<HueCompassWheel.bands).contains(offset) else { throw .level("offset") }
        guard fog.count == HueCompassWheel.bearings, fog.allSatisfy({ Self.densities.contains($0) }) else {
            throw .level("fog")
        }
        guard bearings.contains(target) else { throw .level("target") }
        guard bearings.contains(start) else { throw .level("start") }
        guard Self.bearingTolerances.contains(bearingTolerance) else { throw .level("bearing-tolerance") }
        guard Self.bandTolerances.contains(bandTolerance) else { throw .level("band-tolerance") }
        guard Self.allowances.contains(allowance) else { throw .level("allowance") }
        guard HueCompassWheel.bearingDistance(start, target) > bearingTolerance else { throw .level("solved-at-start") }
        let content = Content(schema: Self.schema, id: id, seed: seed, band: band, offset: offset, fog: fog,
                              target: target, start: start, bearingTolerance: bearingTolerance,
                              bandTolerance: bandTolerance, allowance: allowance, tutorial: tutorial)
        guard let data = try? Self.encoder.encode(content) else { throw .malformed("encode") }
        self.id = id
        self.seed = seed
        self.band = band
        self.offset = offset
        self.fog = fog
        self.target = target
        self.start = start
        self.bearingTolerance = bearingTolerance
        self.bandTolerance = bandTolerance
        self.allowance = allowance
        self.tutorial = tutorial
        self.fingerprint = StableHash.sha256Hex(Array(data))
    }

    /// The target's hue band.
    public var targetBand: Int { HueCompassWheel.band(of: target, offset: offset) }

    /// The hue band of `bearing` in this level.
    public func band(of bearing: Int) -> Int { HueCompassWheel.band(of: bearing, offset: offset) }

    /// The clue at `bearing` (taken modulo 96): the hue gap to the target's band and the fog depth of the shorter arc.
    public func clue(at bearing: Int) -> HueCompassClue {
        let b: Int = HueCompassWheel.mod(bearing, HueCompassWheel.bearings)
        var depth: Int = 0
        for inside in HueCompassWheel.arc(from: b, to: target) { depth += fog[inside] }
        return HueCompassClue(bearing: b, hueGap: HueCompassWheel.bandDistance(band(of: b), targetBand), depth: depth)
    }

    /// Whether selecting `bearing` and `band` wins: the bearing within the bearing tolerance of the target and the band
    /// within the band tolerance of the target's band.
    public func accepts(bearing: Int, band: Int) -> Bool {
        HueCompassWheel.bearingDistance(bearing, target) <= bearingTolerance
            && HueCompassWheel.bandDistance(band, targetBand) <= bandTolerance
    }

    /// The stored form: JSON with sorted keys holding the schema, every field and the fingerprint.
    public func encoded() -> Data {
        do {
            return try Self.encoder.encode(Stored(content: Content(level: self), fingerprint: fingerprint))
        } catch {
            preconditionFailure("a Hue Compass level of checked integers always encodes: \(error)")
        }
    }

    /// Decodes a stored level, re-checking every rule and the fingerprint.
    ///
    /// - Throws: `.newerSchema(s)` above ``schema``; `.malformed(description)` for unreadable JSON, missing keys, a schema
    ///   below 1, any refusal of the initialiser or a fingerprint that does not match.
    public static func decode(_ data: Data) throws(HueCompassError) -> HueCompassLevel {
        struct Probe: Decodable { let schema: Int }
        let probe: Probe
        do { probe = try JSONDecoder().decode(Probe.self, from: data) } catch { throw .malformed("unreadable") }
        guard probe.schema <= schema else { throw .newerSchema(probe.schema) }
        guard probe.schema >= 1 else { throw .malformed("schema \(probe.schema)") }
        let stored: Stored
        do { stored = try JSONDecoder().decode(Stored.self, from: data) } catch { throw .malformed("unreadable") }
        let level: HueCompassLevel
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
        let band: Int
        let offset: Int
        let fog: [Int]
        let target: Int
        let start: Int
        let bearingTolerance: Int
        let bandTolerance: Int
        let allowance: Int
        let tutorial: Bool

        init(schema: Int, id: String, seed: UInt64, band: Int, offset: Int, fog: [Int], target: Int, start: Int,
             bearingTolerance: Int, bandTolerance: Int, allowance: Int, tutorial: Bool) {
            self.schema = schema
            self.id = id
            self.seed = seed
            self.band = band
            self.offset = offset
            self.fog = fog
            self.target = target
            self.start = start
            self.bearingTolerance = bearingTolerance
            self.bandTolerance = bandTolerance
            self.allowance = allowance
            self.tutorial = tutorial
        }

        init(level: HueCompassLevel) {
            self.init(schema: HueCompassLevel.schema, id: level.id, seed: level.seed, band: level.band,
                      offset: level.offset, fog: level.fog, target: level.target, start: level.start,
                      bearingTolerance: level.bearingTolerance, bandTolerance: level.bandTolerance,
                      allowance: level.allowance, tutorial: level.tutorial)
        }

        /// The level of this content, re-checked.
        func level() throws(HueCompassError) -> HueCompassLevel {
            try HueCompassLevel(id: id, seed: seed, band: band, offset: offset, fog: fog, target: target, start: start,
                                bearingTolerance: bearingTolerance, bandTolerance: bandTolerance,
                                allowance: allowance, tutorial: tutorial)
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

extension HueCompassLevel: Codable {
    /// Decodes a level through ``decode(_:)``'s rules.
    public init(from decoder: any Decoder) throws {
        let stored = try Stored(from: decoder)
        guard stored.content.schema <= Self.schema else {
            let code = HueCompassError.newerSchema(stored.content.schema).reasonCode
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: code))
        }
        do {
            self = try stored.content.level()
        } catch {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: error.reasonCode))
        }
        guard fingerprint == stored.fingerprint else {
            let code = HueCompassError.malformed("fingerprint").reasonCode
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: code))
        }
    }

    /// Encodes the stored form.
    public func encode(to encoder: any Encoder) throws {
        try Stored(content: Content(level: self), fingerprint: fingerprint).encode(to: encoder)
    }
}
