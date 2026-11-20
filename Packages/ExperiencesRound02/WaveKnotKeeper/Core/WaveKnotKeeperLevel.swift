// WaveKnotKeeperLevel — feature 321 (R02-G03-01) T-R02G0301-002 (FR-R02G0301-001, 007; clarifications Q1, Q3, Q4, Q5).
// An immutable Wave Knot Keeper level: a closed rope of 6 … 16 distinct integer control points in −16 … 16 on each axis
// (segment i joins point i to point i + 1, the last to the first), 0 … 4 crossing gates (inclusive integer boxes where
// strands may pass), the target projected crossing count and writhe, the tension bound (the largest allowed sum of
// squared segment lengths), the move allowance and whether a tutorial precedes play. Its fingerprint is the SHA-256 hex
// of its canonical JSON (sorted keys, fingerprint excluded). A level is refused when its start rope passes through
// itself, already wins, or is tenser than its bound.
import Foundation
import VisualCoreMath

/// A lattice point of the rope: integer coordinates, each −16 … 16 for a valid point.
public struct WaveKnotKeeperPoint: Sendable, Hashable, Codable {
    /// The x coordinate.
    public let x: Int
    /// The y coordinate.
    public let y: Int
    /// The z coordinate (the projection's depth: larger z is over).
    public let z: Int

    /// The coordinate range of a rope point.
    public static let bounds: ClosedRange<Int> = -16...16

    /// A point of the given coordinates (not checked; see ``isInBounds``).
    public init(x: Int, y: Int, z: Int) {
        self.x = x
        self.y = y
        self.z = z
    }

    /// Whether every coordinate lies in ``bounds``.
    public var isInBounds: Bool { Self.bounds.contains(x) && Self.bounds.contains(y) && Self.bounds.contains(z) }

    /// This point moved one lattice step along `direction`.
    public func moved(_ direction: WaveKnotKeeperDirection) -> WaveKnotKeeperPoint {
        let d = direction.offset
        return WaveKnotKeeperPoint(x: x + d.x, y: y + d.y, z: z + d.z)
    }
}

/// A crossing gate: an axis-aligned inclusive integer box inside the bounds, where strands may pass through each other.
public struct WaveKnotKeeperGate: Sendable, Hashable, Codable {
    /// The lower corner.
    public let min: WaveKnotKeeperPoint
    /// The upper corner (each coordinate ≥ the lower corner's).
    public let max: WaveKnotKeeperPoint

    /// A gate; refuses corners outside the bounds or a lower corner above the upper one on any axis (`.level("gate")`).
    public init(min: WaveKnotKeeperPoint, max: WaveKnotKeeperPoint) throws(WaveKnotKeeperError) {
        guard min.isInBounds, max.isInBounds, min.x <= max.x, min.y <= max.y, min.z <= max.z else {
            throw .level("gate")
        }
        self.min = min
        self.max = max
    }

    /// Whether `point` lies in the box (boundary included).
    public func contains(_ point: WaveKnotKeeperPoint) -> Bool {
        (min.x...max.x).contains(point.x) && (min.y...max.y).contains(point.y) && (min.z...max.z).contains(point.z)
    }

    private enum CodingKeys: String, CodingKey { case min, max }

    /// Decodes a gate and re-checks it.
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        do {
            try self.init(min: c.decode(WaveKnotKeeperPoint.self, forKey: .min),
                          max: c.decode(WaveKnotKeeperPoint.self, forKey: .max))
        } catch let error as WaveKnotKeeperError {
            throw DecodingError.dataCorrupted(.init(codingPath: c.codingPath, debugDescription: error.reasonCode))
        }
    }
}

/// The target of a level: the projected crossing count (0 … 32) and the writhe (−32 … 32), the knot signature.
public struct WaveKnotKeeperTarget: Sendable, Hashable, Codable {
    /// The number of crossings of the xy-projection.
    public let crossings: Int
    /// The sum of the crossing signs.
    public let writhe: Int

    /// A target; refuses crossings outside 0 … 32, writhe outside −32 … 32 or |writhe| above the crossings
    /// (`.level("target")`).
    public init(crossings: Int, writhe: Int) throws(WaveKnotKeeperError) {
        guard (0...32).contains(crossings), (-32...32).contains(writhe), abs(writhe) <= crossings,
              (crossings - writhe) % 2 == 0 else {
            throw .level("target")
        }
        self.crossings = crossings
        self.writhe = writhe
    }

    private enum CodingKeys: String, CodingKey { case crossings, writhe }

    /// Decodes a target and re-checks it.
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        do {
            try self.init(crossings: c.decode(Int.self, forKey: .crossings), writhe: c.decode(Int.self, forKey: .writhe))
        } catch let error as WaveKnotKeeperError {
            throw DecodingError.dataCorrupted(.init(codingPath: c.codingPath, debugDescription: error.reasonCode))
        }
    }
}

/// One lattice direction a control point may step along.
public enum WaveKnotKeeperDirection: String, Sendable, Codable, CaseIterable {
    /// One step towards larger x.
    case plusX
    /// One step towards smaller x.
    case minusX
    /// One step towards larger y.
    case plusY
    /// One step towards smaller y.
    case minusY
    /// One step towards larger z (over, in the projection).
    case plusZ
    /// One step towards smaller z (under, in the projection).
    case minusZ

    /// The unit step of the direction.
    public var offset: (x: Int, y: Int, z: Int) {
        switch self {
        case .plusX: (1, 0, 0)
        case .minusX: (-1, 0, 0)
        case .plusY: (0, 1, 0)
        case .minusY: (0, -1, 0)
        case .plusZ: (0, 0, 1)
        case .minusZ: (0, 0, -1)
        }
    }

    /// The opposite direction.
    public var opposite: WaveKnotKeeperDirection {
        switch self {
        case .plusX: .minusX
        case .minusX: .plusX
        case .plusY: .minusY
        case .minusY: .plusY
        case .plusZ: .minusZ
        case .minusZ: .plusZ
        }
    }
}

/// One move: control point `point` (an index into the rope) steps one unit along `direction`. Not checked here;
/// ``WaveKnotKeeperPlay`` checks it.
public struct WaveKnotKeeperMove: Sendable, Hashable, Codable {
    /// The index of the control point that moves.
    public let point: Int
    /// The direction of the step.
    public let direction: WaveKnotKeeperDirection

    /// A move of the given values (not checked).
    public init(point: Int, direction: WaveKnotKeeperDirection) {
        self.point = point
        self.direction = direction
    }
}

/// An immutable, fingerprinted Wave Knot Keeper level.
public struct WaveKnotKeeperLevel: Sendable, Equatable {
    /// The stored-form schema.
    public static var schema: Int { 1 }
    /// The number of control points a rope may have.
    public static let pointCounts: ClosedRange<Int> = 6...16
    /// The largest number of gates.
    public static let maxGates = 4
    /// The allowances a level may have.
    public static let allowances: ClosedRange<Int> = 1...64
    /// The tension bounds a level may have (the largest tension of a valid rope is below 16 × 3 × 32² = 49,152).
    public static let tensionBounds: ClosedRange<Int> = 1...49_152

    /// The level id, a lowercase slug.
    public let id: String
    /// The seed the level was built from.
    public let seed: UInt64
    /// The band, 1 … 5.
    public let band: Int
    /// The rope's control points at the start, in order around the closed rope.
    public let points: [WaveKnotKeeperPoint]
    /// The crossing gates, 0 … 4.
    public let gates: [WaveKnotKeeperGate]
    /// The target crossing count and writhe.
    public let target: WaveKnotKeeperTarget
    /// The largest allowed tension (sum of squared segment lengths).
    public let tensionBound: Int
    /// The move allowance, 1 … 64.
    public let allowance: Int
    /// Whether a tutorial precedes play.
    public let tutorial: Bool
    /// The SHA-256 hex of the canonical JSON.
    public let fingerprint: String

    /// A level; refuses any value outside its range and a start that passes through itself, already wins or is tenser
    /// than the bound.
    ///
    /// - Throws: `.level(name)` for `"id"`, `"band"`, `"points"` (count, bounds or two equal points), `"gates"`,
    ///   `"tension-bound"`, `"allowance"`, `"self-intersecting"`, `"won-at-start"` or `"tension-at-start"`.
    public init(id: String, seed: UInt64, band: Int, points: [WaveKnotKeeperPoint], gates: [WaveKnotKeeperGate],
                target: WaveKnotKeeperTarget, tensionBound: Int, allowance: Int,
                tutorial: Bool = false) throws(WaveKnotKeeperError) {
        guard Self.isSlug(id) else { throw .level("id") }
        guard (1...5).contains(band) else { throw .level("band") }
        guard Self.pointCounts.contains(points.count), points.allSatisfy({ $0.isInBounds }),
              Set(points).count == points.count else { throw .level("points") }
        guard gates.count <= Self.maxGates else { throw .level("gates") }
        guard Self.tensionBounds.contains(tensionBound) else { throw .level("tension-bound") }
        guard Self.allowances.contains(allowance) else { throw .level("allowance") }
        let content = Content(schema: Self.schema, id: id, seed: seed, band: band, points: points, gates: gates,
                              target: target, tensionBound: tensionBound, allowance: allowance, tutorial: tutorial)
        guard let data = try? Self.encoder.encode(content) else { throw .malformed("encode") }
        self.id = id
        self.seed = seed
        self.band = band
        self.points = points
        self.gates = gates
        self.target = target
        self.tensionBound = tensionBound
        self.allowance = allowance
        self.tutorial = tutorial
        self.fingerprint = StableHash.sha256Hex(Array(data))
        guard WaveKnotKeeperGeometry.isSimple(points) else { throw .level("self-intersecting") }
        guard !wins(points) else { throw .level("won-at-start") }
        guard WaveKnotKeeperGeometry.tension(points) <= tensionBound else { throw .level("tension-at-start") }
    }

    /// Whether `points` win this level: the xy-projection is not degenerate and its crossing count and writhe equal the
    /// target's.
    public func wins(_ points: [WaveKnotKeeperPoint]) -> Bool {
        let summary = WaveKnotKeeperGeometry.summary(points)
        return !summary.degenerate && summary.crossings == target.crossings && summary.writhe == target.writhe
    }

    /// Whether some gate contains both `a` and `b` (the gate exemption of a move from `a` to `b`).
    public func gateContains(_ a: WaveKnotKeeperPoint, _ b: WaveKnotKeeperPoint) -> Bool {
        gates.contains { $0.contains(a) && $0.contains(b) }
    }

    /// The stored form: JSON with sorted keys holding the schema, every field and the fingerprint.
    public func encoded() -> Data {
        do {
            return try Self.encoder.encode(Stored(content: Content(level: self), fingerprint: fingerprint))
        } catch {
            preconditionFailure("a Wave Knot Keeper level of checked integers always encodes: \(error)")
        }
    }

    /// Decodes a stored level, re-checking every rule and the fingerprint.
    ///
    /// - Throws: `.newerSchema(s)` above ``schema``; `.malformed(description)` for unreadable JSON, missing keys, a schema
    ///   below 1, any refusal of the initialiser or a fingerprint that does not match.
    public static func decode(_ data: Data) throws(WaveKnotKeeperError) -> WaveKnotKeeperLevel {
        struct Probe: Decodable { let schema: Int }
        let probe: Probe
        do { probe = try JSONDecoder().decode(Probe.self, from: data) } catch { throw .malformed("unreadable") }
        guard probe.schema <= schema else { throw .newerSchema(probe.schema) }
        guard probe.schema >= 1 else { throw .malformed("schema \(probe.schema)") }
        let stored: Stored
        do { stored = try JSONDecoder().decode(Stored.self, from: data) } catch { throw .malformed("unreadable") }
        let level: WaveKnotKeeperLevel
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
        let points: [WaveKnotKeeperPoint]
        let gates: [WaveKnotKeeperGate]
        let target: WaveKnotKeeperTarget
        let tensionBound: Int
        let allowance: Int
        let tutorial: Bool

        init(schema: Int, id: String, seed: UInt64, band: Int, points: [WaveKnotKeeperPoint],
             gates: [WaveKnotKeeperGate], target: WaveKnotKeeperTarget, tensionBound: Int, allowance: Int,
             tutorial: Bool) {
            self.schema = schema
            self.id = id
            self.seed = seed
            self.band = band
            self.points = points
            self.gates = gates
            self.target = target
            self.tensionBound = tensionBound
            self.allowance = allowance
            self.tutorial = tutorial
        }

        init(level: WaveKnotKeeperLevel) {
            self.init(schema: WaveKnotKeeperLevel.schema, id: level.id, seed: level.seed, band: level.band,
                      points: level.points, gates: level.gates, target: level.target,
                      tensionBound: level.tensionBound, allowance: level.allowance, tutorial: level.tutorial)
        }

        /// The level of this content, re-checked.
        func level() throws(WaveKnotKeeperError) -> WaveKnotKeeperLevel {
            try WaveKnotKeeperLevel(id: id, seed: seed, band: band, points: points, gates: gates, target: target,
                                    tensionBound: tensionBound, allowance: allowance, tutorial: tutorial)
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
            case schema, id, seed, band, points, gates, target, tensionBound, allowance, tutorial, fingerprint
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

extension WaveKnotKeeperLevel: Codable {
    /// Decodes a level through ``decode(_:)``'s rules.
    public init(from decoder: any Decoder) throws {
        let stored = try Stored(from: decoder)
        guard stored.content.schema <= Self.schema else {
            let code = WaveKnotKeeperError.newerSchema(stored.content.schema).reasonCode
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: code))
        }
        do {
            self = try stored.content.level()
        } catch {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: error.reasonCode))
        }
        guard fingerprint == stored.fingerprint else {
            let code = WaveKnotKeeperError.malformed("fingerprint").reasonCode
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: code))
        }
    }

    /// Encodes the stored form.
    public func encode(to encoder: any Encoder) throws {
        try Stored(content: Content(level: self), fingerprint: fingerprint).encode(to: encoder)
    }
}
