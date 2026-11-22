// FacetedForgeGenerator — feature 372 (R02-G08-02) T-R02G0802-004 (FR-R02G0802-001, 005; clarification Q1; research
// R4). The deterministic generator of Faceted Forge's catalog. Candidate k of manifest entry n draws from
// `SeededRandom(seed: SeedDerivation.derive(plannedSeed, index: k))`, in this order: the crystal by band (1: a cube
// −a … a, a = 3 … 6; 2: a box with each face at ±2 … 6; 3: a cube, a = 4 … 6, with one corner cut by x+y+z ≤ b,
// b = a + 1 … 3a − 2; 4: an octahedron |x|+|y|+|z| ≤ a, a = 5 … 6, written with the four body diagonals; 5: a cube,
// a = 5 … 6, with two opposite corners cut, x+y+z ≤ b and x+y+z ≥ −b); the number of cuts c by band (2 … 3, 3 … 4,
// 4 … 5, 5 … 6, 6 … 7); then c cuts, each of a drawn piece (canonical order), a drawn direction (bands 1 … 2: the axes
// and face diagonals; bands 3 … 5: all 13) and a drawn depth among the middle half of those that cross it (the outer
// quarter on each side is left out). The target is the resulting
// multiset of (share, face count); the sliver limit is 1/64. A candidate is kept when every piece's share is at least
// 1/32, bands 3 … 5 drew at least one body diagonal, and the solver certifies it within its work bound (its winning
// sequence replays through the play); otherwise k grows, at most 256 candidates. Ids `faceted-forge-NNN`; tutorial on
// levels 1 … 3; difficulty = band; budget = the manifest budget.
import VisualCoreSimulation

/// The band's crystal shape, cut-count range and drawn directions (clarification Q1).
public struct FacetedForgeBandProfile: Sendable, Equatable {
    /// The band, 1 … 5.
    public let band: Int
    /// The range of the number of cuts drawn (the smallest cut count of the level).
    public let cuts: ClosedRange<Int>
    /// The directions a cut is drawn from.
    public let directions: [Int]

    /// The profile of `band` (clamped to 1 … 5).
    public static func of(band: Int) -> FacetedForgeBandProfile {
        let b: Int = min(max(band, 1), 5)
        let directions: [Int] = b <= 2 ? Array(0...8) : Array(0...12)
        return FacetedForgeBandProfile(band: b, cuts: (b + 1)...(b + 2), directions: directions)
    }
}

/// A generated catalog level with its proof.
public struct FacetedForgeGenerated: Sendable, Equatable {
    /// The manifest entry.
    public let entry: FacetedForgeManifestEntry
    /// The certified level.
    public let level: FacetedForgeLevel
    /// The solver's certified solution.
    public let solution: FacetedForgeSolution
    /// The difficulty metrics.
    public let difficulty: FacetedForgeDifficulty
    /// The candidates skipped before this one, 0 … 255.
    public let skipped: Int

    /// A generated level of the given values.
    public init(entry: FacetedForgeManifestEntry, level: FacetedForgeLevel, solution: FacetedForgeSolution,
                difficulty: FacetedForgeDifficulty, skipped: Int) {
        self.entry = entry
        self.level = level
        self.solution = solution
        self.difficulty = difficulty
        self.skipped = skipped
    }
}

/// The deterministic generator of Faceted Forge's catalog.
public enum FacetedForgeGenerator {
    /// The catalog id of the R02-F24 digest.
    public static let catalogID = "faceted-forge"
    /// The candidates tried per entry.
    public static let maxCandidates = 256
    /// The sliver limit of every catalog level: 1/64 of the crystal.
    public static let sliver = FacetedForgeFraction(unchecked: 1, 64)
    /// The smallest share a generated piece may have: 1/32 of the crystal.
    public static let smallestShare = FacetedForgeFraction(unchecked: 1, 32)

    /// The id of manifest level `number`: `faceted-forge-NNN`.
    public static func levelID(_ number: Int) -> String {
        "faceted-forge-" + String(String(number + 1_000).dropFirst())
    }

    /// The half-spaces lo ≤ n·p ≤ hi of direction `direction`.
    static func slab(_ direction: Int, _ lo: Int, _ hi: Int) -> [FacetedForgeHalfSpace] {
        [FacetedForgeHalfSpace(direction: direction, sign: 1, depth: hi),
         FacetedForgeHalfSpace(direction: direction, sign: -1, depth: lo)]
    }

    /// The band's crystal, drawn from `random` (clarification Q1).
    static func crystal(band: Int, _ random: inout SeededRandom) -> [FacetedForgeHalfSpace] {
        switch band {
        case 1:
            let a: Int = random.int(3...6)
            return (slab(0, -a, a) + slab(1, -a, a) + slab(2, -a, a)).sorted()
        case 2:
            var planes: [FacetedForgeHalfSpace] = []
            for axis in 0..<3 { planes += slab(axis, -random.int(2...6), random.int(2...6)) }
            return planes.sorted()
        case 3:
            let a: Int = random.int(4...6)
            let b: Int = random.int((a + 1)...(3 * a - 2))
            return (slab(0, -a, a) + slab(1, -a, a) + slab(2, -a, a)
                    + [FacetedForgeHalfSpace(direction: 9, sign: 1, depth: b)]).sorted()
        case 4:
            let a: Int = random.int(5...6)
            return (slab(9, -a, a) + slab(10, -a, a) + slab(11, -a, a) + slab(12, -a, a)).sorted()
        default:
            let a: Int = random.int(5...6)
            let b: Int = random.int((a + 1)...(3 * a - 2))
            return (slab(0, -a, a) + slab(1, -a, a) + slab(2, -a, a) + slab(9, -b, b)).sorted()
        }
    }

    /// Candidate `index` of `entry` with the cuts it was drawn from, or nil when it fails a filter of clarification Q1
    /// (a share below 1/32, no body diagonal in bands 3 … 5) or the kernel refuses it.
    static func draft(_ entry: FacetedForgeManifestEntry, index: Int) -> FacetedForgeLevel? {
        var random = SeededRandom(seed: SeedDerivation.derive(entry.seed, index: UInt64(index)))
        let profile: FacetedForgeBandProfile = FacetedForgeBandProfile.of(band: entry.band)
        let planes: [FacetedForgeHalfSpace] = crystal(band: profile.band, &random)
        guard let crystal = try? FacetedForgePiece(halfSpaces: planes) else { return nil }
        var pieces: [FacetedForgePiece] = [crystal]
        var bodyDiagonal: Bool = false
        let count: Int = random.int(profile.cuts)
        for _ in 0..<count {
            let index: Int = random.int(0...(pieces.count - 1))
            let direction: Int = profile.directions[random.int(0...(profile.directions.count - 1))]
            let crossing: [Int] = FacetedForgeSolver.crossingDepths(pieces[index], direction: direction)
            guard !crossing.isEmpty else { return nil }
            let quarter: Int = crossing.count / 4
            let depths: [Int] = Array(crossing[quarter..<(crossing.count - quarter)])
            let depth: Int = depths[random.int(0...(depths.count - 1))]
            guard let halves = try? pieces[index].cut(direction: direction, depth: depth) else { return nil }
            if direction >= 9 { bodyDiagonal = true }
            pieces.remove(at: index)
            pieces = FacetedForgePiece.canonical(pieces + [halves.below, halves.above])
        }
        if profile.band >= 3 && !bodyDiagonal { return nil }
        var target: [FacetedForgeTargetPiece] = []
        for piece in pieces {
            guard let share = try? piece.volume.dividing(by: crystal.volume), !(share < smallestShare) else { return nil }
            target.append(FacetedForgeTargetPiece(share: share, faces: piece.faceCount))
        }
        return try? FacetedForgeLevel(id: levelID(entry.number), seed: entry.seed, difficulty: profile.band,
                                      planes: planes, budget: entry.budget, sliver: sliver, target: target.sorted(),
                                      tutorial: entry.number <= 3)
    }

    /// Candidate `index` of `entry` (clarification Q1), or nil when a filter or the kernel refuses it.
    public static func candidate(_ entry: FacetedForgeManifestEntry, index: Int) -> FacetedForgeLevel? {
        draft(entry, index: index)
    }

    /// Whether `actions` win `level` on a fresh play (begun, the tutorial dismissed).
    public static func wins(_ level: FacetedForgeLevel, actions: [FacetedForgeAction]) -> Bool {
        var play = FacetedForgePlay(level: level)
        do {
            try play.handle(.begin)
            if play.stage == .tutorial { try play.handle(.dismissTutorial) }
            for action in actions { try play.apply(action, expecting: play.fingerprint) }
        } catch {
            return false
        }
        return play.stage == .won
    }

    /// The certified level of `entry`: the first candidate the solver certifies.
    ///
    /// - Throws: `.generation(number)` when no candidate within ``maxCandidates`` qualifies.
    public static func generate(_ entry: FacetedForgeManifestEntry) throws(FacetedForgeError) -> FacetedForgeGenerated {
        for index in 0..<maxCandidates {
            guard let level = candidate(entry, index: index),
                  let solution = FacetedForgeSolver.solve(level),
                  solution.smallest == FacetedForgeSolver.lowerBound(level), solution.smallest <= level.budget,
                  wins(level, actions: solution.actions) else { continue }
            return FacetedForgeGenerated(entry: entry, level: level, solution: solution,
                                         difficulty: FacetedForgeDifficulty(level: level, actions: solution.actions,
                                                                            work: solution.work),
                                         skipped: index)
        }
        throw .generation(entry.number)
    }

    /// The catalog digest (R02-F24) over the levels' fingerprints in order.
    public static func catalogDigest(_ levels: [FacetedForgeLevel]) -> String {
        PuzzleCatalog<FacetedForgeRules>.digest(id: catalogID, identities: levels.map(\.fingerprint))
    }
}
