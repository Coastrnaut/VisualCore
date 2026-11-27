// MushroomWeatherGenerator — feature 492 (R02-G20-02) T-R02G2002-004 (FR-R02G2002-001, 005, 007; SC-R02G2002-001, 003,
// 004; clarification Q1). Builds each catalog level from its manifest entry: candidate c draws from
// `SeededRandom(seed: SeedDerivation.derive(plannedSeed, index: c))` in a fixed order — rows, columns; the blocked count
// and cells; the starting humidity of each floor cell in row-major order (0 … 200); D (4 … 12); each floor cell's rate
// (20 … 60); the pod rules (release 10 … 30, grown release min(80, r + 0 … 30), threshold 800 … 4000); the colony cells;
// the vents, each on a "near" cell (a floor cell without a colony within one step, diagonals included, of a colony),
// open rate 120 … 200, closed rate 0 … 30, a starting state; the starting moonlight (0 … 3); M (1000 … 2000); T
// (30 … 40); K (6 … 10); the sites (near cells that are not vents, the band's count, sorted); the winning choice (pod
// count, moonlight change, vent toggles, picked by partial shuffles); a margin per colony; each colony's sensitivity.
// The level starts with no pod. Each colony's band is its minimum and maximum over the last K cycles of the winning run,
// widened by its margin and clamped to 0 … M; a sensitive colony's floor is min(low·3/4, its lowest value over the
// winning run). A candidate is skipped when there are too few near cells, the winning run fails, the kernel refuses the
// level (including a start that already wins), the winning choice still wins with any one action removed
// ("reducible"), its floor and colonies equal the previous level's, the solver's minimal plan is not the band's plan
// length, or the plan does not win through the play; at most 64 candidates, then `generation(n)`. Ranges measured on a
// prototype over the real manifest (2026-11-26): every entry within candidate index 2, at most 1,128 arrangements
// judged for one entry. Integers only; no clock. Modelled on `MicroscopicAuroraGenerator` (feature 482).
import VisualCoreSimulation

/// The band profile of the generator (clarification Q1).
public struct MushroomWeatherBandProfile: Sendable, Equatable {
    /// The row counts.
    public let rows: ClosedRange<Int>
    /// The column counts.
    public let columns: ClosedRange<Int>
    /// The blocked cell counts.
    public let blocked: ClosedRange<Int>
    /// The number of vents.
    public let vents: Int
    /// The number of pod slots.
    public let slots: Int
    /// The number of colonies.
    public let colonies: Int
    /// The number of pod sites.
    public let sites: Int
    /// The plan length (arrangement actions of the minimal plan).
    public let plan: Int
    /// The margins that widen each colony's band.
    public let margin: ClosedRange<Int>

    /// The profile of `band` 1 … 5 (a larger band uses band 5's).
    public static func of(band: Int) -> Self {
        switch band {
        case 1: Self(rows: 6...7, columns: 6...7, blocked: 2...5, vents: 1, slots: 2, colonies: 2, sites: 4, plan: 2,
                     margin: 4...6)
        case 2: Self(rows: 6...8, columns: 6...8, blocked: 3...6, vents: 2, slots: 2, colonies: 3, sites: 4, plan: 3,
                     margin: 3...5)
        case 3: Self(rows: 7...8, columns: 7...9, blocked: 3...7, vents: 2, slots: 3, colonies: 3, sites: 5, plan: 3,
                     margin: 2...4)
        case 4: Self(rows: 7...9, columns: 8...10, blocked: 4...8, vents: 3, slots: 3, colonies: 4, sites: 6, plan: 4,
                     margin: 1...3)
        default: Self(rows: 8...9, columns: 8...10, blocked: 4...8, vents: 3, slots: 4, colonies: 5, sites: 6, plan: 5,
                      margin: 1...2)
        }
    }
}

/// A generated catalog level with its certificate.
public struct MushroomWeatherGenerated: Sendable, Equatable {
    /// The manifest entry.
    public let entry: MushroomWeatherManifestEntry
    /// The level.
    public let level: MushroomWeatherLevel
    /// The certified plan.
    public let plan: MushroomWeatherPlan
    /// The difficulty metrics.
    public let difficulty: MushroomWeatherDifficulty
    /// The index of the accepted candidate (the candidates skipped before it).
    public let skipped: Int

    /// A generated level of the given values.
    public init(entry: MushroomWeatherManifestEntry, level: MushroomWeatherLevel, plan: MushroomWeatherPlan,
                difficulty: MushroomWeatherDifficulty, skipped: Int) {
        self.entry = entry
        self.level = level
        self.plan = plan
        self.difficulty = difficulty
        self.skipped = skipped
    }
}

/// The catalog generator.
public enum MushroomWeatherGenerator {
    /// The catalog's id.
    public static let catalogID: String = "mushroom-weather"
    /// The candidates tried per manifest entry.
    public static let maxCandidates: Int = 64
    /// The starting humidity of a floor cell.
    static let startHumidity: ClosedRange<Int> = 0...200
    /// The diffusion rates D.
    static let diffusions: ClosedRange<Int> = 4...12
    /// The evaporation rate of a floor cell.
    static let rates: ClosedRange<Int> = 20...60
    /// The pod release r.
    static let releases: ClosedRange<Int> = 10...30
    /// The grown release's increase over r (capped at 80).
    static let grownIncreases: ClosedRange<Int> = 0...30
    /// The growth thresholds.
    static let thresholds: ClosedRange<Int> = 800...4000
    /// A vent's open rates.
    static let openRates: ClosedRange<Int> = 120...200
    /// A vent's closed rates.
    static let closedRates: ClosedRange<Int> = 0...30
    /// The mold bounds M.
    static let moldBounds: ClosedRange<Int> = 1000...2000
    /// The run lengths T.
    static let lengths: ClosedRange<Int> = 30...40
    /// The required cycles K.
    static let required: ClosedRange<Int> = 6...10

    /// "mushroom-weather-007".
    public static func levelID(_ number: Int) -> String {
        let digits: String = String(number)
        return catalogID + "-" + String(repeating: "0", count: max(0, 3 - digits.count)) + digits
    }

    /// `count` distinct cells of a `rows` × `columns` grid for which `allowed` holds, each drawn as a row then a column
    /// and redrawn until it qualifies, in drawing order.
    static func draw(_ random: inout SeededRandom, rows: Int, columns: Int, count: Int,
                     allowed: (MushroomWeatherCell) -> Bool) -> [MushroomWeatherCell] {
        var cells: [MushroomWeatherCell] = []
        while cells.count < count {
            let cell = MushroomWeatherCell(row: random.int(0...(rows - 1)), column: random.int(0...(columns - 1)))
            if allowed(cell) && !cells.contains(cell) { cells.append(cell) }
        }
        return cells
    }

    /// Candidate `index` of `entry`, or nil when it has too few near cells, its winning run fails, the kernel refuses
    /// it or its winning choice is reducible (the neighbour rule and the solver are applied by
    /// ``generate(_:previous:)``).
    public static func candidate(_ entry: MushroomWeatherManifestEntry, index: Int) -> MushroomWeatherLevel? {
        let profile: MushroomWeatherBandProfile = .of(band: entry.band)
        var random = SeededRandom(seed: SeedDerivation.derive(entry.seed, index: UInt64(index)))
        let rows: Int = random.int(profile.rows)
        let columns: Int = random.int(profile.columns)
        let blockedCount: Int = random.int(profile.blocked)
        let blocked: [MushroomWeatherCell] = draw(&random, rows: rows, columns: columns,
                                                  count: blockedCount) { _ in true }.sorted()
        let blockedSet: Set<MushroomWeatherCell> = Set(blocked)
        func isFloor(_ cell: MushroomWeatherCell) -> Bool { !blockedSet.contains(cell) }
        var humidity: [Int] = []
        for row in 0..<rows {
            for column in 0..<columns {
                humidity.append(isFloor(MushroomWeatherCell(row: row, column: column)) ? random.int(startHumidity) : 0)
            }
        }
        let diffusion: Int = random.int(diffusions)
        var cellRates: [Int] = []
        for row in 0..<rows {
            for column in 0..<columns {
                cellRates.append(isFloor(MushroomWeatherCell(row: row, column: column)) ? random.int(rates) : 0)
            }
        }
        let release: Int = random.int(releases)
        let grownRelease: Int = min(80, release + random.int(grownIncreases))
        let threshold: Int = random.int(thresholds)
        let podRules = MushroomWeatherPodRules(slots: profile.slots, release: release, grownRelease: grownRelease,
                                               growthThreshold: threshold)
        let colonyCells: [MushroomWeatherCell] = draw(&random, rows: rows, columns: columns, count: profile.colonies,
                                                      allowed: isFloor)
        let colonySet: Set<MushroomWeatherCell> = Set(colonyCells)
        func isNear(_ cell: MushroomWeatherCell) -> Bool {
            isFloor(cell) && !colonySet.contains(cell)
                && colonyCells.contains { max(abs($0.row - cell.row), abs($0.column - cell.column)) <= 1 }
        }
        var nearCount: Int = 0
        for row in 0..<rows {
            for column in 0..<columns where isNear(MushroomWeatherCell(row: row, column: column)) { nearCount += 1 }
        }
        guard nearCount >= profile.vents + profile.sites else { return nil }
        let ventCells: [MushroomWeatherCell] = draw(&random, rows: rows, columns: columns, count: profile.vents,
                                                    allowed: isNear)
        var vents: [MushroomWeatherVent] = []
        var ventsOpen: [Bool] = []
        for cell in ventCells {
            vents.append(MushroomWeatherVent(cell: cell, openRate: random.int(openRates),
                                             closedRate: random.int(closedRates)))
            ventsOpen.append(random.int(0...1) == 1)
        }
        let ventSet: Set<MushroomWeatherCell> = Set(ventCells)
        let moonlight: Int = random.int(MushroomWeatherLevel.moonlightLevels)
        let moldBound: Int = random.int(moldBounds)
        let length: Int = random.int(lengths)
        let requiredCycles: Int = random.int(required)
        let sites: [MushroomWeatherCell] = draw(&random, rows: rows, columns: columns, count: profile.sites) {
            isNear($0) && !ventSet.contains($0)
        }.sorted()
        // The winning choice has exactly the plan's length and at least one pod: k pods, then the rest as a moonlight
        // change (always when the rest exceeds the vents, else drawn when there is a rest) and vent toggles.
        let podCount: Int = random.int(max(1, profile.plan - profile.vents - 1)...min(profile.plan, profile.slots,
                                                                                    profile.sites))
        let rest: Int = profile.plan - podCount
        let moonlightChanges: Int = rest > profile.vents ? 1 : (rest > 0 ? random.int(0...1) : 0)
        let ventCount: Int = rest - moonlightChanges
        var pickSites: [Int] = Array(0..<sites.count)
        for i in 0..<podCount { pickSites.swapAt(i, random.int(i...(pickSites.count - 1))) }
        var pickVents: [Int] = Array(0..<vents.count)
        for i in 0..<ventCount { pickVents.swapAt(i, random.int(i...(pickVents.count - 1))) }
        var newMoonlight: Int?
        if moonlightChanges == 1 {
            let others: [Int] = MushroomWeatherLevel.moonlightLevels.filter { $0 != moonlight }
            newMoonlight = others[random.int(0...(others.count - 1))]
        }
        let choice = MushroomWeatherSolver.Choice(pods: Array(pickSites[0..<podCount]).sorted(),
                                                  vents: Array(pickVents[0..<ventCount]).sorted(),
                                                  moonlight: newMoonlight)
        let margins: [Int] = (0..<profile.colonies).map { _ in random.int(profile.margin) }
        let sensitive: [Bool] = (0..<profile.colonies).map { _ in random.int(0...1) == 1 }
        let start = MushroomWeatherArrangement(pods: Array(repeating: nil, count: profile.slots), ventsOpen: ventsOpen,
                                               moonlight: moonlight)
        let wide: [MushroomWeatherColony] = colonyCells.map { MushroomWeatherColony(cell: $0, low: 0, high: moldBound) }
        guard let probe = try? MushroomWeatherLevel.probe(
            rows: rows, columns: columns, blocked: blocked, humidity: humidity, diffusion: diffusion,
            rates: cellRates, vents: vents, podRules: podRules, colonies: wide, moldBound: moldBound, length: length,
            required: requiredCycles, start: start) else { return nil }
        var winningPods: [MushroomWeatherCell?] = Array(repeating: nil, count: profile.slots)
        for (slot, site) in choice.pods.enumerated() { winningPods[slot] = sites[site] }
        var winningVents: [Bool] = ventsOpen
        for vent in choice.vents { winningVents[vent].toggle() }
        let winning = MushroomWeatherArrangement(pods: winningPods, ventsOpen: winningVents,
                                                 moonlight: newMoonlight ?? moonlight)
        let (report, fields) = MushroomWeatherForest.run(probe, arrangement: winning, keepFields: true)
        guard report.failure == nil else { return nil }
        var colonies: [MushroomWeatherColony] = []
        for (i, cell) in colonyCells.enumerated() {
            let cellIndex: Int = probe.index(of: cell)
            var tailLow: Int = Int.max
            var tailHigh: Int = Int.min
            for field in fields.suffix(requiredCycles) {
                tailLow = min(tailLow, field[cellIndex])
                tailHigh = max(tailHigh, field[cellIndex])
            }
            let low: Int = max(0, tailLow - margins[i])
            let high: Int = min(moldBound, tailHigh + margins[i])
            var survivalFloor: Int?
            if sensitive[i] {
                var lowest: Int = Int.max
                for field in fields { lowest = min(lowest, field[cellIndex]) }
                survivalFloor = min(low * 3 / 4, lowest)
            }
            colonies.append(MushroomWeatherColony(cell: cell, low: low, high: high, survivalFloor: survivalFloor))
        }
        guard let level = try? MushroomWeatherLevel(
            id: levelID(entry.number), seed: entry.seed, difficulty: entry.band, rows: rows, columns: columns,
            blocked: blocked, humidity: humidity, diffusion: diffusion, rates: cellRates, vents: vents,
            podRules: podRules, colonies: colonies, moldBound: moldBound, length: length, required: requiredCycles,
            start: start, budget: entry.budget, tutorial: entry.number <= 3, sites: sites) else { return nil }
        guard !isReducible(level, choice) else { return nil }
        return level
    }

    /// Whether the winning `choice` still wins `level` with any one of its actions removed (a pod, a vent toggle or the
    /// moonlight change).
    static func isReducible(_ level: MushroomWeatherLevel, _ choice: MushroomWeatherSolver.Choice) -> Bool {
        var reduced: [MushroomWeatherSolver.Choice] = []
        for i in choice.pods.indices {
            var pods: [Int] = choice.pods
            pods.remove(at: i)
            reduced.append(MushroomWeatherSolver.Choice(pods: pods, vents: choice.vents, moonlight: choice.moonlight))
        }
        for i in choice.vents.indices {
            var vents: [Int] = choice.vents
            vents.remove(at: i)
            reduced.append(MushroomWeatherSolver.Choice(pods: choice.pods, vents: vents, moonlight: choice.moonlight))
        }
        if choice.moonlight != nil {
            reduced.append(MushroomWeatherSolver.Choice(pods: choice.pods, vents: choice.vents, moonlight: nil))
        }
        for other in reduced {
            let arrangement: MushroomWeatherArrangement = MushroomWeatherSolver.arrangement(level, other)
            if MushroomWeatherForest.report(level, arrangement: arrangement).wins { return true }
        }
        return false
    }

    /// The certified level of `entry`: the first candidate whose floor and colonies differ from `previous`'s and whose
    /// minimal plan has the band's plan length and wins through the play.
    ///
    /// - Throws: `.generation(number)` when no candidate within ``maxCandidates`` qualifies.
    public static func generate(_ entry: MushroomWeatherManifestEntry,
                                previous: MushroomWeatherLevel?) throws(MushroomWeatherError)
        -> MushroomWeatherGenerated {
        let profile: MushroomWeatherBandProfile = .of(band: entry.band)
        for index in 0..<maxCandidates {
            guard let level = candidate(entry, index: index) else { continue }
            if let previous, previous.rows == level.rows, previous.columns == level.columns,
               previous.blocked == level.blocked, previous.colonies == level.colonies { continue }
            guard let plan = MushroomWeatherSolver.plan(level), plan.size == profile.plan else { continue }
            guard MushroomWeatherSolver.replayWins(level, actions: plan.actions) else { continue }
            return MushroomWeatherGenerated(entry: entry, level: level, plan: plan,
                                            difficulty: MushroomWeatherDifficulty(level: level, plan: plan),
                                            skipped: index)
        }
        throw .generation(entry.number)
    }

    /// The 100 certified levels in manifest order.
    public static func catalog() throws(MushroomWeatherError) -> [MushroomWeatherGenerated] {
        var result: [MushroomWeatherGenerated] = []
        var previous: MushroomWeatherLevel?
        for entry in MushroomWeatherManifest.entries {
            let generated: MushroomWeatherGenerated = try generate(entry, previous: previous)
            result.append(generated)
            previous = generated.level
        }
        return result
    }

    /// The catalog digest over the level fingerprints in manifest order (R02-F24).
    public static func catalogDigest(_ levels: [MushroomWeatherLevel]) -> String {
        PuzzleCatalog<MushroomWeatherPuzzle>.digest(id: catalogID, identities: levels.map(\.fingerprint))
    }
}
