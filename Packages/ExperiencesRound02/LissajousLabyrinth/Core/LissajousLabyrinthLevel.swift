// LissajousLabyrinthLevel — feature 311 (R02-G02-01) T-R02G0201-002 (FR-R02G0201-001, 007; clarifications Q1, Q2, Q5).
// An immutable Lissajous Labyrinth level: the tracer's amplitudes and third-axis frequency, the start dials, the ordered
// checkpoints and the obstacles (balls), the action allowance and whether a tutorial precedes play. Its fingerprint is the
// SHA-256 hex of its canonical JSON (sorted keys, fingerprint excluded). A level whose start already wins is refused.
import Foundation
import VisualCoreMath

/// A ball: an integer centre and radius, used for checkpoints and obstacles.
public struct LissajousLabyrinthBall: Sendable, Equatable, Hashable, Codable {
    /// The centre's x, −5,000 … 5,000.
    public let x: Int
    /// The centre's y, −5,000 … 5,000.
    public let y: Int
    /// The centre's z, −5,000 … 5,000.
    public let z: Int
    /// The radius, 64 … 1,024.
    public let radius: Int

    /// The coordinate range of a centre.
    public static let coordinateRange: ClosedRange<Int> = -5_000...5_000
    /// The radius range.
    public static let radiusRange: ClosedRange<Int> = 64...1_024

    /// A ball; refuses a coordinate outside −5,000 … 5,000 (`.level("centre")`) or a radius outside 64 … 1,024
    /// (`.level("radius")`).
    public init(x: Int, y: Int, z: Int, radius: Int) throws(LissajousLabyrinthError) {
        guard Self.coordinateRange.contains(x), Self.coordinateRange.contains(y), Self.coordinateRange.contains(z) else {
            throw .level("centre")
        }
        guard Self.radiusRange.contains(radius) else { throw .level("radius") }
        self.x = x
        self.y = y
        self.z = z
        self.radius = radius
    }

    private enum CodingKeys: String, CodingKey { case x, y, z, radius }

    /// Decodes a ball and re-checks it.
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        do {
            try self.init(x: c.decode(Int.self, forKey: .x), y: c.decode(Int.self, forKey: .y),
                          z: c.decode(Int.self, forKey: .z), radius: c.decode(Int.self, forKey: .radius))
        } catch let error as LissajousLabyrinthError {
            throw DecodingError.dataCorrupted(.init(codingPath: c.codingPath, debugDescription: error.reasonCode))
        }
    }
}

/// One of the four dials a player turns.
public enum LissajousLabyrinthDial: String, Sendable, Codable, CaseIterable {
    /// The x frequency a, 1 … 9.
    case frequencyA
    /// The y frequency b, 1 … 9.
    case frequencyB
    /// The x phase φ in sixteenths of a turn, 0 … 15.
    case phaseA
    /// The z phase ψ in sixteenths of a turn, 0 … 15.
    case phaseC

    /// The values the dial accepts.
    public var range: ClosedRange<Int> {
        switch self {
        case .frequencyA, .frequencyB: 1...9
        case .phaseA, .phaseC: 0...15
        }
    }
}

/// The four dial values.
public struct LissajousLabyrinthDials: Sendable, Equatable, Hashable, Codable {
    /// The x frequency a.
    public var frequencyA: Int
    /// The y frequency b.
    public var frequencyB: Int
    /// The x phase φ.
    public var phaseA: Int
    /// The z phase ψ.
    public var phaseC: Int

    /// Dials of the given values (unchecked; see ``isValid``).
    public init(frequencyA: Int, frequencyB: Int, phaseA: Int, phaseC: Int) {
        self.frequencyA = frequencyA
        self.frequencyB = frequencyB
        self.phaseA = phaseA
        self.phaseC = phaseC
    }

    /// The value of `dial`.
    public subscript(dial: LissajousLabyrinthDial) -> Int {
        get {
            switch dial {
            case .frequencyA: frequencyA
            case .frequencyB: frequencyB
            case .phaseA: phaseA
            case .phaseC: phaseC
            }
        }
        set {
            switch dial {
            case .frequencyA: frequencyA = newValue
            case .frequencyB: frequencyB = newValue
            case .phaseA: phaseA = newValue
            case .phaseC: phaseC = newValue
            }
        }
    }

    /// Whether every dial is in range and the two frequencies are coprime.
    public var isValid: Bool {
        for dial in LissajousLabyrinthDial.allCases where !dial.range.contains(self[dial]) { return false }
        return Self.gcd(frequencyA, frequencyB) == 1
    }

    /// The greatest common divisor of two positive integers.
    static func gcd(_ a: Int, _ b: Int) -> Int {
        var (x, y) = (a, b)
        while y != 0 { (x, y) = (y, x % y) }
        return x
    }
}

/// An immutable, fingerprinted Lissajous Labyrinth level.
public struct LissajousLabyrinthLevel: Sendable, Equatable {
    /// The stored-form schema.
    public static var schema: Int { 1 }

    /// The level id, a lowercase slug.
    public let id: String
    /// The seed the level was built from.
    public let seed: UInt64
    /// The band, 1 … 5.
    public let band: Int
    /// The amplitudes A, B, C, each 1 … 4.
    public let amplitudes: [Int]
    /// The level-fixed z frequency c, 1 … 9.
    public let frequencyC: Int
    /// The dials at the start.
    public let start: LissajousLabyrinthDials
    /// The checkpoints in the order they must be visited, 1 … 6.
    public let checkpoints: [LissajousLabyrinthBall]
    /// The obstacles, 0 … 8.
    public let obstacles: [LissajousLabyrinthBall]
    /// The action allowance, 1 … 64.
    public let allowance: Int
    /// Whether a tutorial precedes play.
    public let tutorial: Bool
    /// The SHA-256 hex of the canonical JSON.
    public let fingerprint: String

    /// A level; refuses any value outside its range and a start that already wins.
    ///
    /// - Throws: `.level(name)` for `"id"`, `"band"`, `"amplitudes"`, `"frequency-c"`, `"start"` (invalid dials),
    ///   `"checkpoints"`, `"obstacles"`, `"allowance"` or `"won-at-start"`.
    public init(id: String, seed: UInt64, band: Int, amplitudes: [Int], frequencyC: Int, start: LissajousLabyrinthDials,
                checkpoints: [LissajousLabyrinthBall], obstacles: [LissajousLabyrinthBall], allowance: Int,
                tutorial: Bool = false) throws(LissajousLabyrinthError) {
        guard Self.isSlug(id) else { throw .level("id") }
        guard (1...5).contains(band) else { throw .level("band") }
        guard amplitudes.count == 3, amplitudes.allSatisfy({ (1...4).contains($0) }) else { throw .level("amplitudes") }
        guard (1...9).contains(frequencyC) else { throw .level("frequency-c") }
        guard start.isValid else { throw .level("start") }
        guard (1...6).contains(checkpoints.count) else { throw .level("checkpoints") }
        guard obstacles.count <= 8 else { throw .level("obstacles") }
        guard (1...64).contains(allowance) else { throw .level("allowance") }
        let content = Content(schema: Self.schema, id: id, seed: seed, band: band, amplitudes: amplitudes,
                              frequencyC: frequencyC, start: start, checkpoints: checkpoints, obstacles: obstacles,
                              allowance: allowance, tutorial: tutorial)
        guard let data = try? Self.encoder.encode(content) else { throw .malformed("encode") }
        self.id = id
        self.seed = seed
        self.band = band
        self.amplitudes = amplitudes
        self.frequencyC = frequencyC
        self.start = start
        self.checkpoints = checkpoints
        self.obstacles = obstacles
        self.allowance = allowance
        self.tutorial = tutorial
        self.fingerprint = StableHash.sha256Hex(Array(data))
        guard LissajousLabyrinthLap.verdict(start, level: self) != .won else { throw .level("won-at-start") }
    }

    /// The stored form: JSON with sorted keys holding the schema, every field and the fingerprint.
    public func encoded() -> Data {
        do {
            return try Self.encoder.encode(Stored(content: Content(level: self), fingerprint: fingerprint))
        } catch {
            preconditionFailure("a Lissajous Labyrinth level of checked integers always encodes: \(error)")
        }
    }

    /// Decodes a stored level, re-checking every rule and the fingerprint.
    ///
    /// - Throws: `.newerSchema(s)` above ``schema``; `.malformed(description)` for unreadable JSON, missing keys, a schema
    ///   below 1, any refusal of the initialiser or a fingerprint that does not match.
    public static func decode(_ data: Data) throws(LissajousLabyrinthError) -> LissajousLabyrinthLevel {
        struct Probe: Decodable { let schema: Int }
        let probe: Probe
        do { probe = try JSONDecoder().decode(Probe.self, from: data) } catch { throw .malformed("unreadable") }
        guard probe.schema <= schema else { throw .newerSchema(probe.schema) }
        guard probe.schema >= 1 else { throw .malformed("schema \(probe.schema)") }
        let stored: Stored
        do { stored = try JSONDecoder().decode(Stored.self, from: data) } catch { throw .malformed("unreadable") }
        let level: LissajousLabyrinthLevel
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
        let amplitudes: [Int]
        let frequencyC: Int
        let start: LissajousLabyrinthDials
        let checkpoints: [LissajousLabyrinthBall]
        let obstacles: [LissajousLabyrinthBall]
        let allowance: Int
        let tutorial: Bool

        init(schema: Int, id: String, seed: UInt64, band: Int, amplitudes: [Int], frequencyC: Int,
             start: LissajousLabyrinthDials, checkpoints: [LissajousLabyrinthBall], obstacles: [LissajousLabyrinthBall],
             allowance: Int, tutorial: Bool) {
            self.schema = schema
            self.id = id
            self.seed = seed
            self.band = band
            self.amplitudes = amplitudes
            self.frequencyC = frequencyC
            self.start = start
            self.checkpoints = checkpoints
            self.obstacles = obstacles
            self.allowance = allowance
            self.tutorial = tutorial
        }

        init(level: LissajousLabyrinthLevel) {
            self.init(schema: LissajousLabyrinthLevel.schema, id: level.id, seed: level.seed, band: level.band,
                      amplitudes: level.amplitudes, frequencyC: level.frequencyC, start: level.start,
                      checkpoints: level.checkpoints, obstacles: level.obstacles, allowance: level.allowance,
                      tutorial: level.tutorial)
        }

        /// The level of this content, re-checked.
        func level() throws(LissajousLabyrinthError) -> LissajousLabyrinthLevel {
            try LissajousLabyrinthLevel(id: id, seed: seed, band: band, amplitudes: amplitudes, frequencyC: frequencyC,
                                        start: start, checkpoints: checkpoints, obstacles: obstacles,
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

        private enum Keys: String, CodingKey {
            case schema, id, seed, band, amplitudes, frequencyC, start, checkpoints, obstacles, allowance, tutorial
            case fingerprint
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

extension LissajousLabyrinthLevel: Codable {
    /// Decodes a level through ``decode(_:)``'s rules.
    public init(from decoder: any Decoder) throws {
        let stored = try Stored(from: decoder)
        guard stored.content.schema <= Self.schema else {
            let code = LissajousLabyrinthError.newerSchema(stored.content.schema).reasonCode
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: code))
        }
        do {
            self = try stored.content.level()
        } catch {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: error.reasonCode))
        }
        guard fingerprint == stored.fingerprint else {
            let code = LissajousLabyrinthError.malformed("fingerprint").reasonCode
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: code))
        }
    }

    /// Encodes the stored form.
    public func encode(to encoder: any Encoder) throws {
        try Stored(content: Content(level: self), fingerprint: fingerprint).encode(to: encoder)
    }
}
