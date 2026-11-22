// AmethystEscapeGenerator — feature 362 (R02-G07-02) T-R02G0702-004 (FR-R02G0702-001, 005; clarifications Q1, Q3, Q5).
// The deterministic generator of Amethyst Escape's catalog. Candidate k of a manifest entry draws from
// `SeededRandom(seed: SeedDerivation.derive(plannedSeed, index: k))`, in this order: the band's profile (sectors × shells
// 6 × 2, 6 × 3, 8 × 3, 8 × 4, 10 × 4); for each shell from the innermost its apertures (the outermost shell one drawn
// sector, the exit gap; every other shell 1 … 2 distinct drawn sectors), its walls (each sector in order with a draw
// 0 … 99 below 35; when every sector is walled the lowest wall is removed) and its blocked wedges (each sector that is
// not an aperture with a draw 0 … 99 below 25); then the start, drawn among shell 0's sectors that are not blocked. A
// candidate is kept when the pearl does not escape by advances alone and the solver proves a smallest move count in the
// band's range (3 … 4, 5 … 6, 7 … 8, 9 … 10, 11 … 12) within the manifest budget, and its witness replays to a win
// through the play; otherwise the next candidate is tried, at most 512.
import VisualCoreSimulation

/// The level shape and the smallest move counts of one band.
public struct AmethystEscapeBandProfile: Sendable, Equatable {
    /// The number of sectors.
    public let sectors: Int
    /// The number of shells.
    public let shells: Int
    /// The smallest move counts a level of the band may need.
    public let smallest: ClosedRange<Int>

    /// A profile of the given values.
    public init(sectors: Int, shells: Int, smallest: ClosedRange<Int>) {
        self.sectors = sectors
        self.shells = shells
        self.smallest = smallest
    }

    /// The profile of `band` (1 … 5; others clamp).
    public static func of(band: Int) -> AmethystEscapeBandProfile {
        switch band {
        case ...1: AmethystEscapeBandProfile(sectors: 6, shells: 2, smallest: 3...4)
        case 2: AmethystEscapeBandProfile(sectors: 6, shells: 3, smallest: 5...6)
        case 3: AmethystEscapeBandProfile(sectors: 8, shells: 3, smallest: 7...8)
        case 4: AmethystEscapeBandProfile(sectors: 8, shells: 4, smallest: 9...10)
        default: AmethystEscapeBandProfile(sectors: 10, shells: 4, smallest: 11...12)
        }
    }
}

/// A generated catalog level with its proof.
public struct AmethystEscapeGenerated: Sendable, Equatable {
    /// The manifest entry.
    public let entry: AmethystEscapeManifestEntry
    /// The certified level.
    public let level: AmethystEscapeLevel
    /// The solver's certified solution.
    public let solution: AmethystEscapeSolution
    /// The difficulty metrics.
    public let difficulty: AmethystEscapeDifficulty
    /// The candidates skipped before this one, 0 … 511.
    public let skipped: Int

    /// A generated level of the given values.
    public init(entry: AmethystEscapeManifestEntry, level: AmethystEscapeLevel, solution: AmethystEscapeSolution,
                difficulty: AmethystEscapeDifficulty, skipped: Int) {
        self.entry = entry
        self.level = level
        self.solution = solution
        self.difficulty = difficulty
        self.skipped = skipped
    }
}

/// The deterministic generator of Amethyst Escape's catalog.
public enum AmethystEscapeGenerator {
    /// The catalog id of the R02-F24 digest.
    public static let catalogID = "amethyst-escape"
    /// The candidates tried per entry.
    public static let maxCandidates = 512

    /// The id of manifest level `number`: `amethyst-escape-NNN`.
    public static func levelID(_ number: Int) -> String {
        "amethyst-escape-" + String(String(number + 1_000).dropFirst())
    }

    /// Candidate `index` of `entry` (clarification Q1), or nil when the drawn level is refused by the kernel.
    public static func candidate(_ entry: AmethystEscapeManifestEntry, index: Int) -> AmethystEscapeLevel? {
        let profile = AmethystEscapeBandProfile.of(band: entry.band)
        let n: Int = profile.sectors
        var random = SeededRandom(seed: SeedDerivation.derive(entry.seed, index: UInt64(index)))
        var shells: [AmethystEscapeShell] = []
        for shell in 0..<profile.shells {
            var apertures: [Int] = []
            if shell == profile.shells - 1 {
                apertures.append(random.int(0...(n - 1)))
            } else {
                let count: Int = random.int(1...2)
                while apertures.count < count {
                    let sector: Int = random.int(0...(n - 1))
                    if !apertures.contains(sector) { apertures.append(sector) }
                }
            }
            var walls: [Int] = []
            for sector in 0..<n where random.int(0...99) < 35 { walls.append(sector) }
            if walls.count >= n { walls.removeFirst() }
            var blocked: [Int] = []
            for sector in 0..<n where !apertures.contains(sector) && random.int(0...99) < 25 { blocked.append(sector) }
            shells.append(AmethystEscapeShell(apertures: apertures, walls: walls, blocked: blocked))
        }
        let open: [Int] = (0..<n).filter { !shells[0].isBlocked($0) }
        guard !open.isEmpty else { return nil }
        let start: Int = open[random.int(0...(open.count - 1))]
        return try? AmethystEscapeLevel(id: levelID(entry.number), seed: entry.seed,
                                        difficulty: min(5, max(1, entry.band)), sectors: n, shells: shells, start: start,
                                        budget: entry.budget, tutorial: entry.number <= 3)
    }

    /// Whether `actions` win `level` when played from the opening through the kernel's play (begun, tutorial dismissed).
    public static func wins(_ level: AmethystEscapeLevel, actions: [AmethystEscapeAction]) -> Bool {
        var play = AmethystEscapePlay(level: level)
        do {
            try play.handle(.begin)
            if play.stage == .tutorial { try play.handle(.dismissTutorial) }
            for action in actions { try play.apply(action, expecting: play.fingerprint) }
        } catch {
            return false
        }
        return play.stage == .won
    }

    /// The certified level of `entry`: the first candidate the solver certifies within the band's profile.
    ///
    /// - Throws: `.generation(number)` when no candidate within ``maxCandidates`` qualifies.
    public static func generate(_ entry: AmethystEscapeManifestEntry) throws(AmethystEscapeError) -> AmethystEscapeGenerated {
        let profile = AmethystEscapeBandProfile.of(band: entry.band)
        for index in 0..<maxCandidates {
            guard let level = candidate(entry, index: index),
                  !AmethystEscapeSolver.escapesByAdvancing(level),
                  let solution = AmethystEscapeSolver.solve(level, maxDepth: min(profile.smallest.upperBound, level.budget)),
                  profile.smallest.contains(solution.smallest), solution.smallest <= level.budget,
                  wins(level, actions: solution.actions) else { continue }
            return AmethystEscapeGenerated(entry: entry, level: level, solution: solution,
                                           difficulty: AmethystEscapeDifficulty(level: level, solution: solution),
                                           skipped: index)
        }
        throw .generation(entry.number)
    }

    /// The catalog digest (R02-F24) over the levels' fingerprints in order.
    public static func catalogDigest(_ levels: [AmethystEscapeLevel]) -> String {
        PuzzleCatalog<AmethystEscapeRules>.digest(id: catalogID, identities: levels.map(\.fingerprint))
    }
}
