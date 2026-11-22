// ChronoConstellatorGenerator — feature 352 (R02-G06-02) T-R02G0602-004 (FR-R02G0602-001, 005; clarifications Q1, Q3,
// Q5). Builds each catalog level from its manifest entry. Candidate k of entry n draws from
// `SeededRandom(seed: SeedDerivation.derive(plannedSeed, index: k))`, in this order: for each star of the band's profile
// a rectangle loop of width 2 … 5 and height 2 … 4 (each capped by the grid) at a drawn column and row, travelled
// clockwise or, when a further draw is 1, reversed; for each star in order a target drawn among its loop's cells not
// already a target (none left: the candidate is skipped); each star's default phase 0 … L − 1; the tick limit 120 … 360.
// The budget is the manifest budget, the id `chrono-constellator-NNN`, the difficulty the band, a tutorial on levels 1 … 3.
// A candidate is kept when the solver certifies it with a smallest edit count in the band's range and at least the band's
// number of blocked windows, and its witness timeline wins through the kernel's own evaluation while the default timeline
// does not; otherwise k grows, at most 512 candidates, then `generation(n)`.
import VisualCoreSimulation

/// The shape of a band's levels.
public struct ChronoConstellatorBandProfile: Sendable, Equatable {
    /// The grid columns.
    public let columns: Int
    /// The grid rows.
    public let rows: Int
    /// The number of stars.
    public let stars: Int
    /// The smallest edit counts a level of the band may need.
    public let smallest: ClosedRange<Int>
    /// The fewest blocked windows a level of the band must have.
    public let blocked: Int

    /// A profile of the given values.
    public init(columns: Int, rows: Int, stars: Int, smallest: ClosedRange<Int>, blocked: Int) {
        self.columns = columns
        self.rows = rows
        self.stars = stars
        self.smallest = smallest
        self.blocked = blocked
    }

    /// The profile of `band` (1 … 5; others clamp).
    public static func of(band: Int) -> ChronoConstellatorBandProfile {
        switch band {
        case ...1: ChronoConstellatorBandProfile(columns: 6, rows: 5, stars: 2, smallest: 1...1, blocked: 0)
        case 2: ChronoConstellatorBandProfile(columns: 6, rows: 5, stars: 3, smallest: 2...2, blocked: 1)
        case 3: ChronoConstellatorBandProfile(columns: 7, rows: 6, stars: 3, smallest: 2...2, blocked: 2)
        case 4: ChronoConstellatorBandProfile(columns: 7, rows: 6, stars: 4, smallest: 3...3, blocked: 2)
        default: ChronoConstellatorBandProfile(columns: 8, rows: 7, stars: 5, smallest: 3...4, blocked: 3)
        }
    }
}

/// A generated catalog level with its proof.
public struct ChronoConstellatorGenerated: Sendable, Equatable {
    /// The manifest entry.
    public let entry: ChronoConstellatorManifestEntry
    /// The certified level.
    public let level: ChronoConstellatorLevel
    /// The solver's certified solution.
    public let solution: ChronoConstellatorSolution
    /// The difficulty metrics.
    public let difficulty: ChronoConstellatorDifficulty
    /// The candidates skipped before this one, 0 … 511.
    public let skipped: Int

    /// A generated level of the given values.
    public init(entry: ChronoConstellatorManifestEntry, level: ChronoConstellatorLevel, solution: ChronoConstellatorSolution,
                difficulty: ChronoConstellatorDifficulty, skipped: Int) {
        self.entry = entry
        self.level = level
        self.solution = solution
        self.difficulty = difficulty
        self.skipped = skipped
    }
}

/// The deterministic generator of Chrono Constellator's catalog.
public enum ChronoConstellatorGenerator {
    /// The catalog id of the R02-F24 digest.
    public static let catalogID = "chrono-constellator"
    /// The candidates tried per entry.
    public static let maxCandidates = 512

    /// The id of manifest level `number`: `chrono-constellator-NNN`.
    public static func levelID(_ number: Int) -> String {
        "chrono-constellator-" + String(String(number + 1_000).dropFirst())
    }

    /// The clockwise loop round the rectangle with top-left (`column`, `row`), `width` × `height` cells (both ≥ 2).
    public static func rectangle(column: Int, row: Int, width: Int, height: Int, columns: Int) -> [Int] {
        var cells: [Int] = []
        for c in column..<(column + width) { cells.append(row * columns + c) }
        for r in (row + 1)..<(row + height) { cells.append(r * columns + column + width - 1) }
        for c in stride(from: column + width - 2, through: column, by: -1) { cells.append((row + height - 1) * columns + c) }
        for r in stride(from: row + height - 2, through: row + 1, by: -1) { cells.append(r * columns + column) }
        return cells
    }

    /// Candidate `index` of `entry` (clarification Q1), or nil when a star finds no free target cell.
    public static func candidate(_ entry: ChronoConstellatorManifestEntry, index: Int) -> ChronoConstellatorLevel? {
        let profile = ChronoConstellatorBandProfile.of(band: entry.band)
        var random = SeededRandom(seed: SeedDerivation.derive(entry.seed, index: UInt64(index)))
        var loops: [[Int]] = []
        for _ in 0..<profile.stars {
            let width: Int = random.int(2...min(5, profile.columns))
            let height: Int = random.int(2...min(4, profile.rows))
            let column: Int = random.int(0...(profile.columns - width))
            let row: Int = random.int(0...(profile.rows - height))
            var loop: [Int] = rectangle(column: column, row: row, width: width, height: height, columns: profile.columns)
            if random.int(0...1) == 1 { loop.reverse() }
            loops.append(loop)
        }
        var used = Set<Int>()
        var targets: [Int] = []
        for loop in loops {
            let free: [Int] = loop.filter { !used.contains($0) }
            guard !free.isEmpty else { return nil }
            let target: Int = free[random.int(0...(free.count - 1))]
            used.insert(target)
            targets.append(target)
        }
        var stars: [ChronoConstellatorStar] = []
        for (star, loop) in loops.enumerated() {
            stars.append(ChronoConstellatorStar(loop: loop, phase: random.int(0...(loop.count - 1)), target: targets[star]))
        }
        let tickLimit: Int = random.int(120...360)
        let id: String = levelID(entry.number)
        return try? ChronoConstellatorLevel(id: id, seed: entry.seed, difficulty: min(5, max(1, entry.band)),
                                            columns: profile.columns, rows: profile.rows, stars: stars,
                                            budget: entry.budget, tickLimit: tickLimit, tutorial: entry.number <= 3)
    }

    /// The first tick on which `timeline` aligns every star, replayed through the kernel's evaluation, or nil when it
    /// fails first (collision or time).
    public static func winTick(_ level: ChronoConstellatorLevel, timeline: ChronoConstellatorTimeline) -> Int? {
        for tick in 1...level.tickLimit {
            switch ChronoConstellatorEvaluation.verdict(positions: timeline.positions(at: tick, level: level), tick: tick,
                                                        level: level) {
            case .running: continue
            case .won: return tick
            case .failed: return nil
            }
        }
        return nil
    }

    /// The witness timeline of `solution` on `level`: the default timeline with each changed phase set in star order.
    public static func timeline(_ level: ChronoConstellatorLevel,
                                solution: ChronoConstellatorSolution) -> ChronoConstellatorTimeline? {
        var timeline = ChronoConstellatorTimeline(level: level)
        for star in level.stars.indices where timeline.phases[star] != solution.phases[star] {
            guard let next = try? timeline.settingPhase(star: star, to: solution.phases[star], level: level) else {
                return nil
            }
            timeline = next
        }
        return timeline
    }

    /// The certified level of `entry`: the first candidate the solver certifies within the band's profile.
    ///
    /// - Throws: `.generation(number)` when no candidate within ``maxCandidates`` qualifies.
    public static func generate(_ entry: ChronoConstellatorManifestEntry) throws(ChronoConstellatorError)
        -> ChronoConstellatorGenerated {
        let profile = ChronoConstellatorBandProfile.of(band: entry.band)
        for index in 0..<maxCandidates {
            guard let level = candidate(entry, index: index),
                  let solution = ChronoConstellatorSolver.solve(level),
                  profile.smallest.contains(solution.lowerBound), solution.blocked >= profile.blocked,
                  solution.lowerBound <= level.budget,
                  winTick(level, timeline: ChronoConstellatorTimeline(level: level)) == nil,
                  let witness = timeline(level, solution: solution),
                  let win = winTick(level, timeline: witness) else { continue }
            let difficulty = ChronoConstellatorDifficulty(
                smallest: solution.lowerBound, winTick: win, stars: level.stars.count,
                loopLengths: level.stars.map(\.length), windows: solution.windows, blocked: solution.blocked)
            return ChronoConstellatorGenerated(entry: entry, level: level, solution: solution, difficulty: difficulty,
                                               skipped: index)
        }
        throw .generation(entry.number)
    }

    /// The catalog digest (R02-F24) over the levels' fingerprints in order.
    public static func catalogDigest(_ levels: [ChronoConstellatorLevel]) -> String {
        PuzzleCatalog<ChronoConstellatorRules>.digest(id: catalogID, identities: levels.map(\.fingerprint))
    }
}
