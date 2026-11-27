// MushroomWeatherLevel — feature 491 (R02-G20-01) T-R02G2001-002 (FR-R02G2001-001, 002, 009, 011, 013;
// SC-R02G2001-001, 005; clarifications Q1 … Q5). An immutable Mushroom Weather level: a forest floor of 6 … 12 rows by
// 6 … 14 columns with blocked cells; a starting humidity 0 … M on every floor cell (0 on blocked cells); a diffusion
// 1 … 12; an evaporation rate 0 … 200 per cell; 0 … 6 vents on distinct floor cells with open and closed rates
// 0 … 200; pod rules (slots 1 … 6, release 1 … 40, grown release r … 80, threshold 100 … 200000); 1 … 6 colonies on
// distinct floor cells with 0 ≤ floor ≤ low ≤ high ≤ M; a mold bound 1000 … 10000; a run of 20 … 200 cycles; 5 … T
// required cycles; a starting arrangement (pods on distinct free floor cells, a state per vent, moonlight 0 … 3) under
// which no sensitive colony starts below its floor and which does not already win; an action budget 1 … 12; a
// difficulty 1 … 5 and whether a tutorial precedes play. Its fingerprint is the SHA-256 hex of its canonical JSON
// (schema 1, sorted keys, fingerprint excluded); the stored form is re-checked on decode. Pods, colonies, vents and
// progress are named in words (FR-R02G2001-013). Modelled on `MicroscopicAuroraLevel` (feature 481).
// Feature 492 (R02-G20-02) T-R02G2002-002 (FR-R02G2002-001; clarification Q1) extends it additively: the action budget
// widens to 1 … 24, and a level may list 2 … 8 distinct floor cells without a colony as its pod sites (stored row-major;
// every starting pod on a site; refused in order after "pods share a cell": "sites", "sites duplicate", "site off
// floor", "site on colony", "pod not on a site"). A level without sites omits the field from its stored form, so it
// encodes, fingerprints and plays exactly as in feature 491.
import Foundation
import VisualCoreMath

/// An immutable, fingerprinted Mushroom Weather level.
public struct MushroomWeatherLevel: Sendable, Equatable {
    /// The stored-form schema.
    public static let schema: Int = 1
    /// The difficulty range.
    public static let difficulties: ClosedRange<Int> = 1...5
    /// The row counts.
    public static let rowCounts: ClosedRange<Int> = 6...12
    /// The column counts.
    public static let columnCounts: ClosedRange<Int> = 6...14
    /// The diffusion rates D.
    public static let diffusions: ClosedRange<Int> = 1...12
    /// The evaporation rates of a cell or a vent.
    public static let evaporationRates: ClosedRange<Int> = 0...200
    /// The vent counts.
    public static let ventCounts: ClosedRange<Int> = 0...6
    /// The colony counts.
    public static let colonyCounts: ClosedRange<Int> = 1...6
    /// The moonlight levels L.
    public static let moonlightLevels: ClosedRange<Int> = 0...3
    /// The mold bounds M.
    public static let moldBounds: ClosedRange<Int> = 1000...MushroomWeatherForest.maximumMoldBound
    /// The run lengths T in cycles.
    public static let lengths: ClosedRange<Int> = 20...200
    /// The smallest required cycles K (the largest is T).
    public static let minimumRequired: Int = 5
    /// The action budgets (1 … 12 in feature 491, widened by feature 492).
    public static let budgets: ClosedRange<Int> = 1...24
    /// The number of pod sites a level may list (feature 492).
    public static let siteCounts: ClosedRange<Int> = 2...8

    /// The level's id, a lowercase slug.
    public let id: String
    /// The seed the level was generated from (0 for hand-made levels).
    public let seed: UInt64
    /// The difficulty, 1 … 5.
    public let difficulty: Int
    /// The number of rows, 6 … 12.
    public let rows: Int
    /// The number of columns, 6 … 14.
    public let columns: Int
    /// The blocked cells, row-major.
    public let blocked: [MushroomWeatherCell]
    /// The starting humidity of every cell, row-major (0 … M on floor cells, 0 on blocked cells).
    public let humidity: [Int]
    /// The diffusion rate D, 1 … 12.
    public let diffusion: Int
    /// The evaporation rate of every cell, row-major, 0 … 200 (a vent cell uses its vent's rate instead).
    public let rates: [Int]
    /// The vents, by index.
    public let vents: [MushroomWeatherVent]
    /// The pod rules.
    public let podRules: MushroomWeatherPodRules
    /// The colonies, by index (numbered from 1 in words), every one a target.
    public let colonies: [MushroomWeatherColony]
    /// The mold bound M, 1000 … 10000.
    public let moldBound: Int
    /// The run length T in cycles, 20 … 200.
    public let length: Int
    /// The required consecutive cycles in band K at the end of the run, 5 … T.
    public let required: Int
    /// The starting arrangement.
    public let start: MushroomWeatherArrangement
    /// The action budget, 1 … 24.
    public let budget: Int
    /// Whether a tutorial precedes play.
    public let tutorial: Bool
    /// The SHA-256 hex of the canonical JSON content.
    public let fingerprint: String
    /// Whether each cell is floor, row-major (derived from `blocked`).
    public let floorMask: [Bool]
    /// The pod sites, row-major, or nil when pods may stand on any floor cell no colony stands on (feature 492).
    public let sites: [MushroomWeatherCell]?

    /// A level of the given values, checked; the blocked cells and the pod sites (nil: pods may stand on any floor cell
    /// no colony stands on; feature 492) are stored row-major.
    ///
    /// - Throws: `.level(name)` naming the first value outside its range or rule.
    public init(id: String, seed: UInt64, difficulty: Int, rows: Int, columns: Int, blocked: [MushroomWeatherCell],
                humidity: [Int], diffusion: Int, rates: [Int], vents: [MushroomWeatherVent],
                podRules: MushroomWeatherPodRules, colonies: [MushroomWeatherColony], moldBound: Int, length: Int,
                required: Int, start: MushroomWeatherArrangement, budget: Int,
                tutorial: Bool = false, sites: [MushroomWeatherCell]? = nil) throws(MushroomWeatherError) {
        try self.init(id: id, seed: seed, difficulty: difficulty, rows: rows, columns: columns, blocked: blocked,
                      humidity: humidity, diffusion: diffusion, rates: rates, vents: vents, podRules: podRules,
                      colonies: colonies, moldBound: moldBound, length: length, required: required, start: start,
                      budget: budget, tutorial: tutorial, sites: sites, refusingAWin: true)
    }

    /// A level of the given values, checked; the "already won" rule only when `refusingAWin` (a probe that only reads
    /// reports passes false).
    init(id: String, seed: UInt64, difficulty: Int, rows: Int, columns: Int, blocked: [MushroomWeatherCell],
         humidity: [Int], diffusion: Int, rates: [Int], vents: [MushroomWeatherVent], podRules: MushroomWeatherPodRules,
         colonies: [MushroomWeatherColony], moldBound: Int, length: Int, required: Int,
         start: MushroomWeatherArrangement, budget: Int, tutorial: Bool, sites: [MushroomWeatherCell]? = nil,
         refusingAWin: Bool) throws(MushroomWeatherError) {
        guard Self.isSlug(id) else { throw .level("id") }
        guard Self.difficulties.contains(difficulty) else { throw .level("difficulty") }
        guard Self.rowCounts.contains(rows) else { throw .level("rows") }
        guard Self.columnCounts.contains(columns) else { throw .level("columns") }
        func inside(_ cell: MushroomWeatherCell) -> Bool {
            (0..<rows).contains(cell.row) && (0..<columns).contains(cell.column)
        }
        for cell in blocked where !inside(cell) { throw .level("blocked outside") }
        guard Set(blocked).count == blocked.count else { throw .level("blocked duplicate") }
        var mask: [Bool] = Array(repeating: true, count: rows * columns)
        for cell in blocked { mask[cell.row * columns + cell.column] = false }
        func isFloor(_ cell: MushroomWeatherCell) -> Bool { inside(cell) && mask[cell.row * columns + cell.column] }
        guard Self.moldBounds.contains(moldBound) else { throw .level("mold bound") }
        guard humidity.count == rows * columns else { throw .level("humidity") }
        for (index, value) in humidity.enumerated() {
            guard value >= 0, mask[index] || value == 0 else { throw .level("humidity") }
        }
        guard humidity.allSatisfy({ $0 <= moldBound }) else { throw .level("cell above mold bound") }
        guard Self.diffusions.contains(diffusion) else { throw .level("diffusion") }
        guard rates.count == rows * columns, rates.allSatisfy({ Self.evaporationRates.contains($0) }) else {
            throw .level("rates")
        }
        guard Self.ventCounts.contains(vents.count) else { throw .level("vents") }
        for vent in vents {
            guard isFloor(vent.cell) else { throw .level("vent off floor") }
            guard Self.evaporationRates.contains(vent.openRate), Self.evaporationRates.contains(vent.closedRate) else {
                throw .level("vent rate")
            }
        }
        guard Set(vents.map(\.cell)).count == vents.count else { throw .level("vents share a cell") }
        if let name = podRules.invalidValue { throw .level(name) }
        guard Self.colonyCounts.contains(colonies.count) else { throw .level("colonies") }
        for colony in colonies {
            guard isFloor(colony.cell) else { throw .level("colony off floor") }
            guard 0 <= colony.low, colony.low <= colony.high, colony.high <= moldBound else { throw .level("band") }
            if let floor = colony.survivalFloor {
                guard 0 <= floor, floor <= colony.low else { throw .level("survival floor") }
            }
        }
        let colonyCells: Set<MushroomWeatherCell> = Set(colonies.map(\.cell))
        guard colonyCells.count == colonies.count else { throw .level("colonies share a cell") }
        guard Self.lengths.contains(length) else { throw .level("length") }
        guard (Self.minimumRequired...length).contains(required) else { throw .level("required cycles") }
        guard start.pods.count == podRules.slots else { throw .level("pods") }
        let placed: [MushroomWeatherCell] = start.placedPods
        for pod in placed {
            guard isFloor(pod) else { throw .level("pod off floor") }
            guard !colonyCells.contains(pod) else { throw .level("pod on colony") }
        }
        guard Set(placed).count == placed.count else { throw .level("pods share a cell") }
        var sortedSites: [MushroomWeatherCell]?
        if let sites {
            guard Self.siteCounts.contains(sites.count) else { throw .level("sites") }
            guard Set(sites).count == sites.count else { throw .level("sites duplicate") }
            for site in sites {
                guard isFloor(site) else { throw .level("site off floor") }
                guard !colonyCells.contains(site) else { throw .level("site on colony") }
            }
            for pod in placed where !sites.contains(pod) { throw .level("pod not on a site") }
            sortedSites = sites.sorted()
        }
        guard start.ventsOpen.count == vents.count else { throw .level("vent states") }
        guard Self.moonlightLevels.contains(start.moonlight) else { throw .level("moonlight") }
        guard Self.budgets.contains(budget) else { throw .level("budget") }
        for colony in colonies where colony.driesOut(humidity[colony.cell.row * columns + colony.cell.column]) {
            throw .level("colony below floor")
        }
        let sorted: [MushroomWeatherCell] = blocked.sorted()
        let content = Content(schema: Self.schema, id: id, seed: seed, difficulty: difficulty, rows: rows,
                              columns: columns, blocked: sorted, humidity: humidity, diffusion: diffusion,
                              rates: rates, vents: vents, podRules: podRules, colonies: colonies,
                              moldBound: moldBound, length: length, required: required, pods: start.pods,
                              ventsOpen: start.ventsOpen, moonlight: start.moonlight, budget: budget,
                              tutorial: tutorial, sites: sortedSites)
        guard let data = try? Self.encoder.encode(content) else { throw .malformed("encode") }
        self.id = id
        self.seed = seed
        self.difficulty = difficulty
        self.rows = rows
        self.columns = columns
        self.blocked = sorted
        self.humidity = humidity
        self.diffusion = diffusion
        self.rates = rates
        self.vents = vents
        self.podRules = podRules
        self.colonies = colonies
        self.moldBound = moldBound
        self.length = length
        self.required = required
        self.start = start
        self.budget = budget
        self.tutorial = tutorial
        self.floorMask = mask
        self.sites = sortedSites
        self.fingerprint = StableHash.sha256Hex(Array(data))
        if refusingAWin {
            guard !MushroomWeatherForest.report(self, arrangement: start).wins else { throw .level("already won") }
        }
    }

    /// A probe level that skips the "already won" rule, for reading the reports of other arrangements (the content
    /// pipeline, the fixtures and hand-made test levels); every other rule is checked.
    static func probe(rows: Int, columns: Int, blocked: [MushroomWeatherCell], humidity: [Int], diffusion: Int,
                      rates: [Int], vents: [MushroomWeatherVent], podRules: MushroomWeatherPodRules,
                      colonies: [MushroomWeatherColony], moldBound: Int, length: Int, required: Int,
                      start: MushroomWeatherArrangement) throws(MushroomWeatherError) -> MushroomWeatherLevel {
        try MushroomWeatherLevel(id: "probe", seed: 0, difficulty: 1, rows: rows, columns: columns, blocked: blocked,
                                 humidity: humidity, diffusion: diffusion, rates: rates, vents: vents,
                                 podRules: podRules, colonies: colonies, moldBound: moldBound, length: length,
                                 required: required, start: start, budget: 1, tutorial: false, refusingAWin: false)
    }

    /// Whether `cell` lies inside the grid.
    public func isInside(_ cell: MushroomWeatherCell) -> Bool {
        (0..<rows).contains(cell.row) && (0..<columns).contains(cell.column)
    }

    /// Whether `cell` is a floor cell (inside the grid and not blocked).
    public func isFloor(_ cell: MushroomWeatherCell) -> Bool { isInside(cell) && floorMask[index(of: cell)] }

    /// The row-major index of `cell` (meaningful for cells inside the grid).
    public func index(of cell: MushroomWeatherCell) -> Int { cell.row * columns + cell.column }

    /// The cell at row-major index `index`.
    public func cell(at index: Int) -> MushroomWeatherCell {
        MushroomWeatherCell(row: index / columns, column: index % columns)
    }

    /// Whether a pod may stand on `cell` as far as the sites go: always for a level without sites, else exactly when
    /// `cell` is one of its sites (feature 492). The floor and colony rules are checked separately.
    public func allowsPod(_ cell: MushroomWeatherCell) -> Bool {
        guard let sites else { return true }
        return sites.contains(cell)
    }

    /// The colony cells.
    public var colonyCells: Set<MushroomWeatherCell> { Set(colonies.map(\.cell)) }

    /// The report of the starting arrangement.
    public var startReport: MushroomWeatherReport { MushroomWeatherForest.report(self, arrangement: start) }

    /// "row 3, column 7".
    public static func cellWords(_ cell: MushroomWeatherCell) -> String {
        "row \(cell.row), column \(cell.column)"
    }

    /// "1 cycle" or "12 cycles".
    static func cyclesWords(_ count: Int) -> String { count == 1 ? "1 cycle" : "\(count) cycles" }

    /// Slot `slot` in words (pods are numbered from 1): "pod 2 at row 3, column 7, grown at cycle 18", "pod 2 at row 3,
    /// column 7, not grown" or "pod 2 empty".
    public func podDescription(_ slot: Int, cell: MushroomWeatherCell?, grownAt: Int?) -> String {
        guard let cell else { return "pod \(slot + 1) empty" }
        let growth: String = grownAt.map { "grown at cycle \($0)" } ?? "not grown"
        return "pod \(slot + 1) at " + Self.cellWords(cell) + ", " + growth
    }

    /// Vent `index` in words (vents are numbered from 1): "vent 1 at row 2, column 4, open".
    public func ventDescription(_ index: Int, open: Bool) -> String {
        "vent \(index + 1) at " + Self.cellWords(vents[index].cell) + (open ? ", open" : ", closed")
    }

    /// Colony `index` in words (colonies are numbered from 1), with its humidity after the report's last cycle: "colony
    /// 1 at row 5, column 2: 412 units, band 380 … 520, in band for the last 12 of 12 cycles"; a sensitive colony adds
    /// its survival floor after the band ("…, band 380 … 520, survival floor 300, in band …").
    public func colonyDescription(_ index: Int, report: MushroomWeatherReport) -> String {
        let colony: MushroomWeatherColony = colonies[index]
        let units: Int = report.humidity[self.index(of: colony.cell)]
        var text: String = "colony \(index + 1) at " + Self.cellWords(colony.cell) + ": \(units) units, band "
            + "\(colony.low) … \(colony.high)"
        if let floor = colony.survivalFloor { text += ", survival floor \(floor)" }
        let run: Int = index < report.colonies.count ? report.colonies[index].finalRun : 0
        return text + ", in band for the last \(run) of " + Self.cyclesWords(report.cycles)
    }

    /// A failure in words: "colony 2 dries out at cycle 14", "row 3, column 4 turns to mold at cycle 9", "colony 1 is
    /// in band for only the last 3 cycles, needs 12".
    public func failureDescription(_ failure: MushroomWeatherFailure) -> String {
        switch failure {
        case .dried(let colony, let cycle): "colony \(colony + 1) dries out at cycle \(cycle)"
        case .mold(let cell, let cycle): Self.cellWords(cell) + " turns to mold at cycle \(cycle)"
        case .unstable(let colony, let run):
            "colony \(colony + 1) is in band for only the last " + Self.cyclesWords(run) + ", needs \(required)"
        }
    }

    /// A cycle's ledger in words: "cycle 5: 4120 units, 12 released, 40 evaporated, 4092 units".
    public static func ledgerDescription(_ ledger: MushroomWeatherLedger) -> String {
        "cycle \(ledger.cycle): \(ledger.before) units, \(ledger.released) released, \(ledger.evaporated) evaporated, "
            + "\(ledger.after) units"
    }

    /// The progress in words: the pods, the vents, the moonlight, the colonies, the predicted outcome and the actions
    /// left, joined by "; ".
    public func progressDescription(report: MushroomWeatherReport, arrangement: MushroomWeatherArrangement,
                                    actionsLeft: Int) -> String {
        var parts: [String] = []
        for slot in arrangement.pods.indices {
            let grownAt: Int? = slot < report.grownAt.count ? report.grownAt[slot] : nil
            parts.append(podDescription(slot, cell: arrangement.pods[slot], grownAt: grownAt))
        }
        for index in vents.indices where index < arrangement.ventsOpen.count {
            parts.append(ventDescription(index, open: arrangement.ventsOpen[index]))
        }
        parts.append("moonlight \(arrangement.moonlight) of \(Self.moonlightLevels.upperBound)")
        for index in colonies.indices { parts.append(colonyDescription(index, report: report)) }
        parts.append("needs every colony in band for the last " + Self.cyclesWords(required) + " of "
                     + Self.cyclesWords(length))
        if let failure = report.failure {
            parts.append("running now would fail: " + failureDescription(failure))
        } else {
            parts.append("running now would win")
        }
        parts.append(actionsLeft == 1 ? "1 action left" : "\(actionsLeft) actions left")
        return parts.joined(separator: "; ")
    }

    /// The stored form: JSON with sorted keys holding the schema, every field and the fingerprint.
    public func encoded() -> Data {
        do {
            return try Self.encoder.encode(Stored(content: Content(level: self), fingerprint: fingerprint))
        } catch {
            preconditionFailure("a Mushroom Weather level of checked values always encodes: \(error)")
        }
    }

    /// Decodes a stored level, re-checking every rule and the fingerprint.
    ///
    /// - Throws: `.newerSchema(s)` above ``schema``; `.level(reason)` for stored values the initialiser refuses
    ///   (clarification Q5: an invalid level is refused `r02-g20.level`; feature 491 T-R02G2001-013);
    ///   `.malformed(description)` for unreadable JSON, missing keys, a schema below 1 or a fingerprint that does not
    ///   match.
    public static func decode(_ data: Data) throws(MushroomWeatherError) -> MushroomWeatherLevel {
        struct Probe: Decodable { let schema: Int }
        let probe: Probe
        do { probe = try JSONDecoder().decode(Probe.self, from: data) } catch { throw .malformed("unreadable") }
        guard probe.schema <= schema else { throw .newerSchema(probe.schema) }
        guard probe.schema >= 1 else { throw .malformed("schema \(probe.schema)") }
        let stored: Stored
        do { stored = try JSONDecoder().decode(Stored.self, from: data) } catch { throw .malformed("unreadable") }
        let level: MushroomWeatherLevel
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

    /// The fingerprinted content.
    struct Content: Codable, Equatable {
        let schema: Int
        let id: String
        let seed: UInt64
        let difficulty: Int
        let rows: Int
        let columns: Int
        let blocked: [MushroomWeatherCell]
        let humidity: [Int]
        let diffusion: Int
        let rates: [Int]
        let vents: [MushroomWeatherVent]
        let podRules: MushroomWeatherPodRules
        let colonies: [MushroomWeatherColony]
        let moldBound: Int
        let length: Int
        let required: Int
        let pods: [MushroomWeatherCell?]
        let ventsOpen: [Bool]
        let moonlight: Int
        let budget: Int
        let tutorial: Bool
        /// Omitted from the JSON when nil (synthesized `encodeIfPresent`), so a level without sites keeps its form.
        let sites: [MushroomWeatherCell]?

        init(schema: Int, id: String, seed: UInt64, difficulty: Int, rows: Int, columns: Int,
             blocked: [MushroomWeatherCell], humidity: [Int], diffusion: Int, rates: [Int],
             vents: [MushroomWeatherVent], podRules: MushroomWeatherPodRules, colonies: [MushroomWeatherColony],
             moldBound: Int, length: Int, required: Int, pods: [MushroomWeatherCell?], ventsOpen: [Bool],
             moonlight: Int, budget: Int, tutorial: Bool, sites: [MushroomWeatherCell]? = nil) {
            self.schema = schema
            self.id = id
            self.seed = seed
            self.difficulty = difficulty
            self.rows = rows
            self.columns = columns
            self.blocked = blocked
            self.humidity = humidity
            self.diffusion = diffusion
            self.rates = rates
            self.vents = vents
            self.podRules = podRules
            self.colonies = colonies
            self.moldBound = moldBound
            self.length = length
            self.required = required
            self.pods = pods
            self.ventsOpen = ventsOpen
            self.moonlight = moonlight
            self.budget = budget
            self.tutorial = tutorial
            self.sites = sites
        }

        init(level: MushroomWeatherLevel) {
            self.init(schema: MushroomWeatherLevel.schema, id: level.id, seed: level.seed,
                      difficulty: level.difficulty, rows: level.rows, columns: level.columns, blocked: level.blocked,
                      humidity: level.humidity, diffusion: level.diffusion, rates: level.rates, vents: level.vents,
                      podRules: level.podRules, colonies: level.colonies, moldBound: level.moldBound,
                      length: level.length, required: level.required, pods: level.start.pods,
                      ventsOpen: level.start.ventsOpen, moonlight: level.start.moonlight, budget: level.budget,
                      tutorial: level.tutorial, sites: level.sites)
        }

        /// The level of this content, re-checked.
        func level() throws(MushroomWeatherError) -> MushroomWeatherLevel {
            try MushroomWeatherLevel(id: id, seed: seed, difficulty: difficulty, rows: rows, columns: columns,
                                     blocked: blocked, humidity: humidity, diffusion: diffusion, rates: rates,
                                     vents: vents, podRules: podRules, colonies: colonies, moldBound: moldBound,
                                     length: length, required: required,
                                     start: MushroomWeatherArrangement(pods: pods, ventsOpen: ventsOpen,
                                                                       moonlight: moonlight),
                                     budget: budget, tutorial: tutorial, sites: sites)
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

extension MushroomWeatherLevel: Codable {
    /// Decodes a level through ``decode(_:)``'s rules.
    public init(from decoder: any Decoder) throws {
        let stored = try Stored(from: decoder)
        guard stored.content.schema <= Self.schema else {
            let code = MushroomWeatherError.newerSchema(stored.content.schema).reasonCode
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: code))
        }
        guard stored.content.schema >= 1 else {
            let code = MushroomWeatherError.malformed("schema").reasonCode
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: code))
        }
        do {
            self = try stored.content.level()
        } catch {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: error.reasonCode))
        }
        guard fingerprint == stored.fingerprint else {
            let code = MushroomWeatherError.malformed("fingerprint").reasonCode
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: code))
        }
    }

    /// Encodes the stored form.
    public func encode(to encoder: any Encoder) throws {
        try Stored(content: Content(level: self), fingerprint: fingerprint).encode(to: encoder)
    }
}
