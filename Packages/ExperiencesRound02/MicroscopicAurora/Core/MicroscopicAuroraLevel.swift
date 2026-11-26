// MicroscopicAuroraLevel — feature 481 (R02-G19-01) T-R02G1901-002 (FR-R02G1901-001, 002, 009, 011, 013;
// SC-R02G1901-001, 005; clarifications Q1 … Q5). An immutable Microscopic Aurora level: an enclosure of radius 6 … 11
// cells; a swim of 120 … 480 ticks; swarm rules (ρ 2 … 6, σ 1 … ρ, κ 2 … 8, weights 0 … 8, a_max 2 … 16, v_max 8 … 48);
// 4 … 16 swimmers starting inside with velocities within ±v_max and a coherence at least the requirement; a stencil of
// 4 … 120 distinct cells whose centres lie inside; a threshold 1 … 64; a required coverage 500 … 1000 and coherence
// 2 … N; three well slots whose wells lie inside on distinct cells with strengths 1 … 4 and do not already win; an
// action budget 1 … 12; a difficulty 1 … 5 and whether a tutorial precedes play. Its fingerprint is the SHA-256 hex of
// its canonical JSON (schema 1, sorted keys, fingerprint excluded); the stored form is re-checked on decode. Wells,
// coverage and progress are named in words (FR-R02G1901-013). Modelled on `ApsidesWorkshopLevel` (feature 471).
import Foundation
import VisualCoreMath

/// An immutable, fingerprinted Microscopic Aurora level.
public struct MicroscopicAuroraLevel: Sendable, Equatable {
    /// The stored-form schema.
    public static let schema: Int = 1
    /// The difficulty range.
    public static let difficulties: ClosedRange<Int> = 1...5
    /// The enclosure radii in cells.
    public static let radii: ClosedRange<Int> = 6...11
    /// The swim lengths in ticks.
    public static let lengths: ClosedRange<Int> = 120...480
    /// The swarm sizes.
    public static let swarmSizes: ClosedRange<Int> = 4...16
    /// The stencil sizes.
    public static let stencilSizes: ClosedRange<Int> = 4...120
    /// The trail thresholds.
    public static let thresholds: ClosedRange<Int> = 1...64
    /// The required coverages in tenths of a percent.
    public static let coverages: ClosedRange<Int> = 500...1000
    /// The number of well slots.
    public static let slots: Int = 3
    /// The action budgets.
    public static let budgets: ClosedRange<Int> = 1...12

    /// The level's id, a lowercase slug.
    public let id: String
    /// The seed the level was generated from (0 for hand-made levels).
    public let seed: UInt64
    /// The difficulty, 1 … 5.
    public let difficulty: Int
    /// The enclosure radius R in cells.
    public let radius: Int
    /// The swim length T in ticks.
    public let length: Int
    /// The swarm rules.
    public let rules: MicroscopicAuroraSwarmRules
    /// The swimmers at tick 0, numbered by index.
    public let swimmers: [MicroscopicAuroraSwimmer]
    /// The target stencil, row-major.
    public let stencil: [MicroscopicAuroraCell]
    /// The trail density at which a cell is lit.
    public let threshold: Int
    /// The required coverage in tenths of a percent.
    public let coverage: Int
    /// The required coherence (the smallest allowed largest group).
    public let coherence: Int
    /// The starting wells, one entry per slot (nil for an empty slot).
    public let wells: [MicroscopicAuroraWell?]
    /// The action budget.
    public let budget: Int
    /// Whether a tutorial precedes play.
    public let tutorial: Bool
    /// The SHA-256 hex of the canonical JSON content.
    public let fingerprint: String

    /// A level of the given values, checked; the stencil is stored row-major.
    ///
    /// - Throws: `.level(name)` naming the first value outside its range or rule.
    public init(id: String, seed: UInt64, difficulty: Int, radius: Int, length: Int,
                rules: MicroscopicAuroraSwarmRules, swimmers: [MicroscopicAuroraSwimmer],
                stencil: [MicroscopicAuroraCell], threshold: Int, coverage: Int, coherence: Int,
                wells: [MicroscopicAuroraWell?], budget: Int, tutorial: Bool = false) throws(MicroscopicAuroraError) {
        try self.init(id: id, seed: seed, difficulty: difficulty, radius: radius, length: length, rules: rules,
                      swimmers: swimmers, stencil: stencil, threshold: threshold, coverage: coverage,
                      coherence: coherence, wells: wells, budget: budget, tutorial: tutorial, refusingAWin: true)
    }

    /// A level of the given values, checked; the "already won" rule only when `refusingAWin` (a probe that only reads
    /// reports passes false).
    init(id: String, seed: UInt64, difficulty: Int, radius: Int, length: Int, rules: MicroscopicAuroraSwarmRules,
         swimmers: [MicroscopicAuroraSwimmer], stencil: [MicroscopicAuroraCell], threshold: Int, coverage: Int,
         coherence: Int, wells: [MicroscopicAuroraWell?], budget: Int, tutorial: Bool,
         refusingAWin: Bool) throws(MicroscopicAuroraError) {
        guard Self.isSlug(id) else { throw .level("id") }
        guard Self.difficulties.contains(difficulty) else { throw .level("difficulty") }
        guard Self.radii.contains(radius) else { throw .level("radius") }
        guard Self.lengths.contains(length) else { throw .level("length") }
        if let name = rules.invalidValue { throw .level(name) }
        guard Self.swarmSizes.contains(swimmers.count) else { throw .level("swimmers") }
        for swimmer in swimmers {
            guard MicroscopicAuroraDish.isInside(swimmer.position, radius: radius) else {
                throw .level("swimmer outside")
            }
            guard abs(swimmer.velocity.x) <= rules.maxSpeed, abs(swimmer.velocity.y) <= rules.maxSpeed else {
                throw .level("swimmer speed")
            }
        }
        guard Self.stencilSizes.contains(stencil.count) else { throw .level("stencil") }
        guard Set(stencil).count == stencil.count else { throw .level("stencil duplicate") }
        for cell in stencil {
            guard Self.isUsable(cell, radius: radius) else { throw .level("stencil outside") }
        }
        guard Self.thresholds.contains(threshold) else { throw .level("threshold") }
        guard Self.coverages.contains(coverage) else { throw .level("coverage") }
        guard (2...swimmers.count).contains(coherence) else { throw .level("coherence") }
        guard wells.count == Self.slots else { throw .level("wells") }
        let placed: [MicroscopicAuroraWell] = wells.compactMap { $0 }
        for well in placed {
            guard Self.isUsable(well.cell, radius: radius) else { throw .level("well outside") }
            guard MicroscopicAuroraWell.strengths.contains(well.strength) else { throw .level("well strength") }
        }
        guard Set(placed.map(\.cell)).count == placed.count else { throw .level("wells share a cell") }
        guard Self.budgets.contains(budget) else { throw .level("budget") }
        guard MicroscopicAuroraDish.coherence(swimmers, radius: rules.coherenceRadius) >= coherence else {
            throw .level("start incoherent")
        }
        let sorted: [MicroscopicAuroraCell] = stencil.sorted()
        let content = Content(schema: Self.schema, id: id, seed: seed, difficulty: difficulty, radius: radius,
                              length: length, rules: rules, swimmers: swimmers, stencil: sorted,
                              threshold: threshold, coverage: coverage, coherence: coherence, wells: wells,
                              budget: budget, tutorial: tutorial)
        guard let data = try? Self.encoder.encode(content) else { throw .malformed("encode") }
        self.id = id
        self.seed = seed
        self.difficulty = difficulty
        self.radius = radius
        self.length = length
        self.rules = rules
        self.swimmers = swimmers
        self.stencil = sorted
        self.threshold = threshold
        self.coverage = coverage
        self.coherence = coherence
        self.wells = wells
        self.budget = budget
        self.tutorial = tutorial
        self.fingerprint = StableHash.sha256Hex(Array(data))
        if refusingAWin {
            guard !MicroscopicAuroraDish.report(self, wells: placed).wins else { throw .level("already won") }
        }
    }

    /// A probe level that skips the "already won" rule, for reading the reports of other wells (the content pipeline
    /// and the fixtures); every other rule is checked.
    static func probe(radius: Int, length: Int, rules: MicroscopicAuroraSwarmRules,
                      swimmers: [MicroscopicAuroraSwimmer], stencil: [MicroscopicAuroraCell], threshold: Int,
                      coverage: Int, coherence: Int,
                      wells: [MicroscopicAuroraWell?]) throws(MicroscopicAuroraError) -> MicroscopicAuroraLevel {
        try MicroscopicAuroraLevel(id: "probe", seed: 0, difficulty: 1, radius: radius, length: length, rules: rules,
                                   swimmers: swimmers, stencil: stencil, threshold: threshold, coverage: coverage,
                                   coherence: coherence, wells: wells, budget: 1, tutorial: false,
                                   refusingAWin: false)
    }

    /// Whether `cell` is on the dish and its centre lies inside the enclosure of `radius` cells.
    public static func isUsable(_ cell: MicroscopicAuroraCell, radius: Int) -> Bool {
        let range: Range<Int> = 0..<MicroscopicAuroraDish.cells
        return range.contains(cell.row) && range.contains(cell.column)
            && MicroscopicAuroraDish.isInside(cell.centre, radius: radius)
    }

    /// The placed starting wells, in slot order.
    public var placedWells: [MicroscopicAuroraWell] { wells.compactMap { $0 } }

    /// The report of the starting wells.
    public var startReport: MicroscopicAuroraReport { MicroscopicAuroraDish.report(self, wells: placedWells) }

    /// "row 7, column 12".
    public static func cellWords(_ cell: MicroscopicAuroraCell) -> String {
        "row \(cell.row), column \(cell.column)"
    }

    /// A coverage in words: 850 → "85.0 %".
    public static func coverageWords(_ coverage: Int) -> String { "\(coverage / 10).\(coverage % 10) %" }

    /// Slot `slot` in words (slots are numbered from 1): "well 2 at row 7, column 12, strength 3, counterclockwise" or
    /// "well 2 empty".
    public func wellDescription(_ slot: Int, well: MicroscopicAuroraWell?) -> String {
        guard let well else { return "well \(slot + 1) empty" }
        return "well \(slot + 1) at " + Self.cellWords(well.cell) + ", strength \(well.strength), "
            + well.sense.rawValue
    }

    /// The coverage in words: "stencil 34 of 40 cells lit, 85.0 %, needs 80.0 %".
    public func coverageDescription(report: MicroscopicAuroraReport) -> String {
        "stencil \(report.litStencil.count) of \(stencil.count) cells lit, " + Self.coverageWords(report.coverage)
            + ", needs " + Self.coverageWords(coverage)
    }

    /// A failure in words: "swimmer 3 leaves the dish at tick 41", "the swarm splits at tick 88 (largest group 3, needs
    /// 4)", "stencil 30 of 40 cells lit, needs 32", "row 9, column 4 is not joined to the pattern".
    public func failureDescription(_ failure: MicroscopicAuroraFailure) -> String {
        switch failure {
        case .exit(let swimmer, let tick): "swimmer \(swimmer + 1) leaves the dish at tick \(tick)"
        case .coherence(let tick, let group):
            "the swarm splits at tick \(tick) (largest group \(group), needs \(coherence))"
        case .coverage(let lit, let needed): "stencil \(lit) of \(stencil.count) cells lit, needs \(needed)"
        case .connectedness(let cell): Self.cellWords(cell) + " is not joined to the pattern"
        }
    }

    /// The progress in words: the wells, the coverage, the predicted outcome and the actions left.
    public func progressDescription(report: MicroscopicAuroraReport, wells: [MicroscopicAuroraWell?],
                                    actionsLeft: Int) -> String {
        var parts: [String] = wells.indices.map { wellDescription($0, well: wells[$0]) }
        parts.append(coverageDescription(report: report))
        if let failure = report.failure {
            parts.append("playing now would fail: " + failureDescription(failure))
        } else {
            parts.append("playing now would win")
        }
        parts.append(actionsLeft == 1 ? "1 action left" : "\(actionsLeft) actions left")
        return parts.joined(separator: "; ")
    }

    /// The stored form: JSON with sorted keys holding the schema, every field and the fingerprint.
    public func encoded() -> Data {
        do {
            return try Self.encoder.encode(Stored(content: Content(level: self), fingerprint: fingerprint))
        } catch {
            preconditionFailure("a Microscopic Aurora level of checked values always encodes: \(error)")
        }
    }

    /// Decodes a stored level, re-checking every rule and the fingerprint.
    ///
    /// - Throws: `.newerSchema(s)` above ``schema``; `.malformed(description)` for unreadable JSON, missing keys, a
    ///   schema below 1, any refusal of the initialiser (its reason code) or a fingerprint that does not match.
    public static func decode(_ data: Data) throws(MicroscopicAuroraError) -> MicroscopicAuroraLevel {
        struct Probe: Decodable { let schema: Int }
        let probe: Probe
        do { probe = try JSONDecoder().decode(Probe.self, from: data) } catch { throw .malformed("unreadable") }
        guard probe.schema <= schema else { throw .newerSchema(probe.schema) }
        guard probe.schema >= 1 else { throw .malformed("schema \(probe.schema)") }
        let stored: Stored
        do { stored = try JSONDecoder().decode(Stored.self, from: data) } catch { throw .malformed("unreadable") }
        let level: MicroscopicAuroraLevel
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
        let radius: Int
        let length: Int
        let rules: MicroscopicAuroraSwarmRules
        let swimmers: [MicroscopicAuroraSwimmer]
        let stencil: [MicroscopicAuroraCell]
        let threshold: Int
        let coverage: Int
        let coherence: Int
        let wells: [MicroscopicAuroraWell?]
        let budget: Int
        let tutorial: Bool

        init(schema: Int, id: String, seed: UInt64, difficulty: Int, radius: Int, length: Int,
             rules: MicroscopicAuroraSwarmRules, swimmers: [MicroscopicAuroraSwimmer],
             stencil: [MicroscopicAuroraCell], threshold: Int, coverage: Int, coherence: Int,
             wells: [MicroscopicAuroraWell?], budget: Int, tutorial: Bool) {
            self.schema = schema
            self.id = id
            self.seed = seed
            self.difficulty = difficulty
            self.radius = radius
            self.length = length
            self.rules = rules
            self.swimmers = swimmers
            self.stencil = stencil
            self.threshold = threshold
            self.coverage = coverage
            self.coherence = coherence
            self.wells = wells
            self.budget = budget
            self.tutorial = tutorial
        }

        init(level: MicroscopicAuroraLevel) {
            self.init(schema: MicroscopicAuroraLevel.schema, id: level.id, seed: level.seed,
                      difficulty: level.difficulty, radius: level.radius, length: level.length, rules: level.rules,
                      swimmers: level.swimmers, stencil: level.stencil, threshold: level.threshold,
                      coverage: level.coverage, coherence: level.coherence, wells: level.wells,
                      budget: level.budget, tutorial: level.tutorial)
        }

        /// The level of this content, re-checked.
        func level() throws(MicroscopicAuroraError) -> MicroscopicAuroraLevel {
            try MicroscopicAuroraLevel(id: id, seed: seed, difficulty: difficulty, radius: radius, length: length,
                                       rules: rules, swimmers: swimmers, stencil: stencil, threshold: threshold,
                                       coverage: coverage, coherence: coherence, wells: wells, budget: budget,
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

extension MicroscopicAuroraLevel: Codable {
    /// Decodes a level through ``decode(_:)``'s rules.
    public init(from decoder: any Decoder) throws {
        let stored = try Stored(from: decoder)
        guard stored.content.schema <= Self.schema else {
            let code = MicroscopicAuroraError.newerSchema(stored.content.schema).reasonCode
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: code))
        }
        guard stored.content.schema >= 1 else {
            let code = MicroscopicAuroraError.malformed("schema").reasonCode
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: code))
        }
        do {
            self = try stored.content.level()
        } catch {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: error.reasonCode))
        }
        guard fingerprint == stored.fingerprint else {
            let code = MicroscopicAuroraError.malformed("fingerprint").reasonCode
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: code))
        }
    }

    /// Encodes the stored form.
    public func encode(to encoder: any Encoder) throws {
        try Stored(content: Content(level: self), fingerprint: fingerprint).encode(to: encoder)
    }
}
