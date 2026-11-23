// EchoCartographerLevel — feature 401 (R02-G11-01) T-R02G1101-002 (FR-R02G1101-001, 004, 009, 013; clarifications Q1,
// Q3, Q5). An immutable Echo Cartographer level: the chamber (W × H, 5 … 16, with its walls), the entry (an open cell),
// the 1 … 4 hidden beacons (distinct open cells other than the entry, each reachable from the entry through open cells,
// kept in cell-index order), the claim tolerance (0 … 2 cells, the larger of the column and row differences), the energy
// budget (1 … 60), the cost of a missed claim (1 … 3), a difficulty (1 … 5) and whether a tutorial precedes play. A
// level always hides at least one beacon, so it is never solved at load. The claim rule lives here, shared by the play
// and the rules: a claim locates the not-yet-located beacon within the tolerance that is nearest (then lowest row, then
// lowest column); a claim within the tolerance only of located beacons changes nothing; otherwise it misses. Its
// fingerprint is the SHA-256 hex of its canonical JSON (schema 1, sorted keys, walls and beacons as sorted cell
// indices, fingerprint excluded); the stored form is re-checked on decode. Cells, echoes and progress are named in words
// (FR-R02G1101-013).
import Foundation
import VisualCoreMath

/// What a claim on a cell does (clarification Q3).
public enum EchoCartographerClaimResult: Sendable, Equatable {
    /// Locates the beacon with this index in ``EchoCartographerLevel/beacons``.
    case hit(Int)
    /// Within the tolerance only of beacons already located: refused as a no-op.
    case alreadyLocated
    /// No beacon within the tolerance: a miss.
    case miss
}

/// An immutable, fingerprinted Echo Cartographer level.
public struct EchoCartographerLevel: Sendable, Equatable {
    /// The stored-form schema.
    public static var schema: Int { 1 }
    /// The allowed difficulties.
    public static let difficulties: ClosedRange<Int> = 1...5
    /// The allowed beacon counts.
    public static let beaconCounts: ClosedRange<Int> = 1...4
    /// The allowed claim tolerances, in cells.
    public static let tolerances: ClosedRange<Int> = 0...2
    /// The allowed energy budgets.
    public static let energies: ClosedRange<Int> = 1...60
    /// The allowed costs of a missed claim.
    public static let missCosts: ClosedRange<Int> = 1...3
    /// The most markers a play may hold.
    public static let maximumMarkers: Int = 8

    /// The level id, a lowercase slug.
    public let id: String
    /// The seed the level was built from.
    public let seed: UInt64
    /// The difficulty, 1 … 5.
    public let difficulty: Int
    /// The chamber.
    public let chamber: EchoCartographerChamber
    /// The entry, the one cell known open at the start.
    public let entry: EchoCartographerCell
    /// The hidden beacons, in cell-index order.
    public let beacons: [EchoCartographerCell]
    /// The claim tolerance, 0 … 2 cells.
    public let tolerance: Int
    /// The energy budget.
    public let energy: Int
    /// The energy a missed claim costs (never more than the energy left).
    public let missCost: Int
    /// Whether a tutorial precedes play.
    public let tutorial: Bool
    /// The SHA-256 hex of the canonical JSON.
    public let fingerprint: String

    /// A level; refuses any value outside its range and any broken rule.
    ///
    /// - Throws: `.level(name)` for `"id"`, `"difficulty"`, `"entry"` (outside the chamber or a wall), `"beacons"` (a
    ///   count outside 1 … 4, a repeat, a cell outside the chamber, on a wall, on the entry or unreachable from the
    ///   entry), `"tolerance"`, `"energy"` or `"miss"`.
    public init(id: String, seed: UInt64, difficulty: Int, chamber: EchoCartographerChamber,
                entry: EchoCartographerCell, beacons: [EchoCartographerCell], tolerance: Int, energy: Int,
                missCost: Int, tutorial: Bool = false) throws(EchoCartographerError) {
        guard Self.isSlug(id) else { throw .level("id") }
        guard Self.difficulties.contains(difficulty) else { throw .level("difficulty") }
        guard chamber.isOpen(entry) else { throw .level("entry") }
        let sorted: [EchoCartographerCell] = beacons.sorted()
        guard Self.beaconCounts.contains(sorted.count), Set(sorted).count == sorted.count else {
            throw .level("beacons")
        }
        let reach: [Int?] = chamber.pathLengths(from: entry)
        for beacon in sorted {
            guard chamber.isOpen(beacon), beacon != entry, reach[chamber.index(beacon)] != nil else {
                throw .level("beacons")
            }
        }
        guard Self.tolerances.contains(tolerance) else { throw .level("tolerance") }
        guard Self.energies.contains(energy) else { throw .level("energy") }
        guard Self.missCosts.contains(missCost) else { throw .level("miss") }
        let content = Content(id: id, seed: seed, difficulty: difficulty, chamber: chamber, entry: entry,
                              beacons: sorted, tolerance: tolerance, energy: energy, missCost: missCost,
                              tutorial: tutorial)
        guard let data = try? Self.encoder.encode(content) else { throw .malformed("encode") }
        self.id = id
        self.seed = seed
        self.difficulty = difficulty
        self.chamber = chamber
        self.entry = entry
        self.beacons = sorted
        self.tolerance = tolerance
        self.energy = energy
        self.missCost = missCost
        self.tutorial = tutorial
        self.fingerprint = StableHash.sha256Hex(Array(data))
    }

    /// The opening knowledge: only the entry known open.
    public var openingKnowledge: EchoCartographerKnowledge {
        EchoCartographerKnowledge(chamber: chamber, entry: entry)
    }

    /// The report of a pulse from `cell` (the chamber's rays and the beacons' sorted path lengths).
    public func echo(from cell: EchoCartographerCell) -> EchoCartographerEcho {
        chamber.echo(from: cell, beacons: beacons)
    }

    /// What a claim on `cell` does when the beacons with the indices in `located` are already located: the nearest
    /// unlocated beacon within the tolerance (ties: lowest row, then lowest column, which is the beacons' order), else
    /// `.alreadyLocated` when a located beacon is within the tolerance, else `.miss`.
    public func claim(_ cell: EchoCartographerCell, located: Set<Int>) -> EchoCartographerClaimResult {
        var best: (distance: Int, index: Int)? = nil
        var nearLocated: Bool = false
        for (index, beacon) in beacons.enumerated() {
            let distance: Int = cell.distance(to: beacon)
            guard distance <= tolerance else { continue }
            if located.contains(index) {
                nearLocated = true
                continue
            }
            if best == nil || distance < best!.distance { best = (distance, index) }
        }
        if let best { return .hit(best.index) }
        return nearLocated ? .alreadyLocated : .miss
    }

    /// `cell` in words with what is known of it: "column 3, row 5: open" (or "wall", "unknown").
    public func cellName(_ cell: EchoCartographerCell, knowledge: EchoCartographerKnowledge) -> String {
        let known: String
        switch knowledge[cell] {
        case .unknown: known = "unknown"
        case .open: known = "open"
        case .wall: known = "wall"
        }
        return "column \(cell.x), row \(cell.y): \(known)"
    }

    /// A pulse report in words: "pulse from column 2, row 4; north: wall at 2 cells; east: edge at 5 cells; south: wall
    /// at 1 cell; west: edge at 3 cells; echoes at 3, 7 cells".
    public func echoDescription(_ echo: EchoCartographerEcho) -> String {
        var parts: [String] = ["pulse from column \(echo.emitter.x), row \(echo.emitter.y)"]
        for ray in echo.rays {
            let what: String = ray.wall == nil ? "edge" : "wall"
            parts.append("\(ray.direction.rawValue): \(what) at \(Self.cellsText(ray.distance))")
        }
        if echo.beaconDistances.isEmpty {
            parts.append("no echoes")
        } else {
            let list: String = echo.beaconDistances.map(String.init).joined(separator: ", ")
            parts.append(echo.beaconDistances.count == 1 ? "echo at \(Self.cellsText(echo.beaconDistances[0]))"
                         : "echoes at \(list) cells")
        }
        return parts.joined(separator: "; ")
    }

    /// The progress in words: "1 of 3 beacons located, 7 energy left".
    public func progressDescription(located: Int, energy: Int) -> String {
        let noun: String = beacons.count == 1 ? "beacon" : "beacons"
        return "\(located) of \(beacons.count) \(noun) located, \(energy) energy left"
    }

    /// The level in words: "chamber 9 by 7; entry at column 1, row 3; 2 beacons; tolerance 1 cell; 12 energy; a miss
    /// costs 2".
    public func levelDescription() -> String {
        let noun: String = beacons.count == 1 ? "1 beacon" : "\(beacons.count) beacons"
        return "chamber \(chamber.width) by \(chamber.height); entry at column \(entry.x), row \(entry.y); \(noun); "
            + "tolerance \(Self.cellsText(tolerance)); \(energy) energy; a miss costs \(missCost)"
    }

    /// "1 cell", "3 cells", "0 cells".
    static func cellsText(_ n: Int) -> String { n == 1 ? "1 cell" : "\(n) cells" }

    /// The stored form: JSON with sorted keys holding the schema, every field and the fingerprint.
    public func encoded() -> Data {
        do {
            return try Self.encoder.encode(Stored(content: Content(level: self), fingerprint: fingerprint))
        } catch {
            preconditionFailure("an Echo Cartographer level of checked values always encodes: \(error)")
        }
    }

    /// Decodes a stored level, re-checking every rule and the fingerprint.
    ///
    /// - Throws: `.newerSchema(s)` above ``schema``; `.malformed(description)` for unreadable JSON, missing keys, a
    ///   schema below 1, any refusal of the initialisers (its reason code) or a fingerprint that does not match.
    public static func decode(_ data: Data) throws(EchoCartographerError) -> EchoCartographerLevel {
        struct Probe: Decodable { let schema: Int }
        let probe: Probe
        do { probe = try JSONDecoder().decode(Probe.self, from: data) } catch { throw .malformed("unreadable") }
        guard probe.schema <= schema else { throw .newerSchema(probe.schema) }
        guard probe.schema >= 1 else { throw .malformed("schema \(probe.schema)") }
        let stored: Stored
        do { stored = try JSONDecoder().decode(Stored.self, from: data) } catch { throw .malformed("unreadable") }
        let level: EchoCartographerLevel
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

    /// The fingerprinted content; walls, entry and beacons as cell indices (walls and beacons sorted).
    struct Content: Codable, Equatable {
        let schema: Int
        let id: String
        let seed: UInt64
        let difficulty: Int
        let width: Int
        let height: Int
        let walls: [Int]
        let entry: Int
        let beacons: [Int]
        let tolerance: Int
        let energy: Int
        let missCost: Int
        let tutorial: Bool

        init(id: String, seed: UInt64, difficulty: Int, chamber: EchoCartographerChamber, entry: EchoCartographerCell,
             beacons: [EchoCartographerCell], tolerance: Int, energy: Int, missCost: Int, tutorial: Bool) {
            self.schema = EchoCartographerLevel.schema
            self.id = id
            self.seed = seed
            self.difficulty = difficulty
            self.width = chamber.width
            self.height = chamber.height
            self.walls = chamber.walls.sorted()
            self.entry = chamber.index(entry)
            self.beacons = beacons.map { chamber.index($0) }.sorted()
            self.tolerance = tolerance
            self.energy = energy
            self.missCost = missCost
            self.tutorial = tutorial
        }

        init(level: EchoCartographerLevel) {
            self.init(id: level.id, seed: level.seed, difficulty: level.difficulty, chamber: level.chamber,
                      entry: level.entry, beacons: level.beacons, tolerance: level.tolerance, energy: level.energy,
                      missCost: level.missCost, tutorial: level.tutorial)
        }

        /// The level of this content, re-checked (chamber first; repeated walls and out-of-grid indices refused).
        func level() throws(EchoCartographerError) -> EchoCartographerLevel {
            guard Set(walls).count == walls.count else { throw .level("walls") }
            let chamber = try EchoCartographerChamber(width: width, height: height, walls: Set(walls))
            let count: Int = width * height
            guard entry >= 0, entry < count else { throw .level("entry") }
            guard beacons.allSatisfy({ $0 >= 0 && $0 < count }) else { throw .level("beacons") }
            return try EchoCartographerLevel(id: id, seed: seed, difficulty: difficulty, chamber: chamber,
                                             entry: chamber.cell(entry), beacons: beacons.map { chamber.cell($0) },
                                             tolerance: tolerance, energy: energy, missCost: missCost,
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

extension EchoCartographerLevel: Codable {
    /// Decodes a level through ``decode(_:)``'s rules.
    public init(from decoder: any Decoder) throws {
        let stored = try Stored(from: decoder)
        guard stored.content.schema <= Self.schema else {
            let code = EchoCartographerError.newerSchema(stored.content.schema).reasonCode
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: code))
        }
        do {
            self = try stored.content.level()
        } catch {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: error.reasonCode))
        }
        guard fingerprint == stored.fingerprint else {
            let code = EchoCartographerError.malformed("fingerprint").reasonCode
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: code))
        }
    }

    /// Encodes the stored form.
    public func encode(to encoder: any Encoder) throws {
        try Stored(content: Content(level: self), fingerprint: fingerprint).encode(to: encoder)
    }
}
