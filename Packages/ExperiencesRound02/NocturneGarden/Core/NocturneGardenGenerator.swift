// NocturneGardenGenerator — feature 382 (R02-G09-02) T-R02G0902-004 (FR-R02G0902-001, 005, 006; clarifications Q1, Q3,
// Q5; analyze findings C1, C2). Builds each catalog level from its manifest entry: candidate k draws from
// `SeededRandom(seed: SeedDerivation.derive(seed, index: k))`, in this order — one bloom size from the band's sizes, a
// construction sun from the band's elevations, the bloom count, the blooms (kind, column, row; each cast wholly in the
// bed and adding at least 3 new cells; at most 64 draws), the forbidden ring's kept cells (in ascending cell order), the
// decoy kind (bands 3 … 5) and the opening sun. The target is the blooms' exact mask. A candidate is kept only when the
// solver certifies it within its work bound with a smallest move count in the band's range and within the manifest
// budget, and the witness replays to a win; otherwise k grows, up to 256 candidates, then `.generation(number)`.
import VisualCoreSimulation

/// What a band asks of its levels (clarification Q1; analyze C1 for the smallest range).
public struct NocturneGardenBandProfile: Sendable, Equatable {
    /// The band, 1 … 5.
    public let band: Int
    /// The bed width.
    public let width: Int
    /// The bed height.
    public let height: Int
    /// The range of the smallest move count a level of the band may have.
    public let smallest: ClosedRange<Int>
    /// The allowed bloom sizes.
    public let sizes: Set<Int>
    /// The allowed sun elevations.
    public let elevations: Set<Int>
    /// The range of the construction's bloom count.
    public let blooms: ClosedRange<Int>
    /// The forbidden ring's Chebyshev distance from the target.
    public let ring: Int
    /// The share of ring cells kept as forbidden: `keep.numerator` in `keep.denominator`.
    public let keep: (numerator: Int, denominator: Int)
    /// The required match.
    public let required: NocturneGardenRatio
    /// The leak allowance.
    public let leakAllowance: Int
    /// Whether the supply holds one decoy kind the construction does not use.
    public let decoy: Bool

    /// The profile of `band` (clamped to 1 … 5).
    public static func of(band: Int) -> NocturneGardenBandProfile {
        let all: Set<Int> = [1, 2, 3]
        let suns: Set<Int> = [1, 2, 3, 4]
        switch min(max(band, 1), 5) {
        case 1:
            return Self(band: 1, width: 16, height: 12, smallest: 2...3, sizes: [2], elevations: [2, 3], blooms: 1...2,
                        ring: 1, keep: (1, 2), required: ratio(4, 5), leakAllowance: 2, decoy: false)
        case 2:
            return Self(band: 2, width: 20, height: 14, smallest: 3...4, sizes: [1, 2], elevations: [2, 3],
                        blooms: 2...3, ring: 1, keep: (1, 2), required: ratio(17, 20), leakAllowance: 2, decoy: false)
        case 3:
            return Self(band: 3, width: 24, height: 16, smallest: 4...5, sizes: all, elevations: suns, blooms: 3...4,
                        ring: 2, keep: (3, 4), required: ratio(9, 10), leakAllowance: 1, decoy: true)
        case 4:
            return Self(band: 4, width: 28, height: 20, smallest: 5...6, sizes: all, elevations: suns, blooms: 4...5,
                        ring: 2, keep: (3, 4), required: ratio(19, 20), leakAllowance: 1, decoy: true)
        default:
            return Self(band: 5, width: 32, height: 24, smallest: 6...7, sizes: all, elevations: suns, blooms: 5...6,
                        ring: 2, keep: (3, 4), required: .whole, leakAllowance: 0, decoy: true)
        }
    }

    /// A ratio known to be valid.
    private static func ratio(_ numerator: Int, _ denominator: Int) -> NocturneGardenRatio {
        (try? NocturneGardenRatio(numerator, denominator)) ?? .whole
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.band == rhs.band && lhs.width == rhs.width && lhs.height == rhs.height && lhs.smallest == rhs.smallest
            && lhs.sizes == rhs.sizes && lhs.elevations == rhs.elevations && lhs.blooms == rhs.blooms
            && lhs.ring == rhs.ring && lhs.keep == rhs.keep && lhs.required == rhs.required
            && lhs.leakAllowance == rhs.leakAllowance && lhs.decoy == rhs.decoy
    }
}

/// A certified catalog level with its solution, bound, difficulty and the candidates skipped.
public struct NocturneGardenGenerated: Sendable, Equatable {
    /// The manifest entry.
    public let entry: NocturneGardenManifestEntry
    /// The certified level.
    public let level: NocturneGardenLevel
    /// The solver's certified solution.
    public let solution: NocturneGardenSolution
    /// The lower-bound argument the solution meets.
    public let bound: NocturneGardenBound
    /// The difficulty metrics.
    public let difficulty: NocturneGardenDifficulty
    /// The candidates skipped before this one, 0 … 255.
    public let skipped: Int

    /// A generated level of the given values.
    public init(entry: NocturneGardenManifestEntry, level: NocturneGardenLevel, solution: NocturneGardenSolution,
                bound: NocturneGardenBound, difficulty: NocturneGardenDifficulty, skipped: Int) {
        self.entry = entry
        self.level = level
        self.solution = solution
        self.bound = bound
        self.difficulty = difficulty
        self.skipped = skipped
    }
}

/// The deterministic level generator of Nocturne Garden.
public enum NocturneGardenGenerator {
    /// The catalog id.
    public static let catalogID: String = "nocturne-garden"
    /// The most candidates tried per entry.
    public static let maxCandidates: Int = 256
    /// The most bloom draws per candidate.
    static let maxDraws: Int = 64

    /// The level id of `number`: `nocturne-garden-NNN`.
    public static func levelID(_ number: Int) -> String {
        "nocturne-garden-" + String(String(number + 1_000).dropFirst())
    }

    /// Candidate `index` of `entry`, or nil when its draws do not give a valid level.
    public static func candidate(_ entry: NocturneGardenManifestEntry, index: Int) -> NocturneGardenLevel? {
        let profile: NocturneGardenBandProfile = .of(band: entry.band)
        var random = SeededRandom(seed: SeedDerivation.derive(entry.seed, index: UInt64(index)))
        let width: Int = profile.width
        let height: Int = profile.height
        let sizes: [Int] = profile.sizes.sorted()
        let elevations: [Int] = profile.elevations.sorted()
        let size: Int = sizes[random.int(0...(sizes.count - 1))]
        let construction: Int = elevations[random.int(0...(elevations.count - 1))]
        let wanted: Int = random.int(profile.blooms)
        let kinds: [NocturneGardenKind] = NocturneGardenKind.allCases
        var blooms: [NocturneGardenBloom] = []
        var target: Set<Int> = []
        var draws: Int = 0
        while blooms.count < wanted && draws < maxDraws {
            draws += 1
            let bloom = NocturneGardenBloom(kind: kinds[random.int(0...(kinds.count - 1))],
                                            column: random.int(0...(width - 1)), row: random.int(0...(height - 1)),
                                            size: size)
            let polygon: [NocturneGardenLattice] = bloom.castPolygon(elevation: construction)
            guard polygon.allSatisfy({ $0.x >= 0 && $0.x <= 2 * width && $0.y >= 0 && $0.y <= 2 * height }) else {
                continue
            }
            let cells: Set<Int> = bloom.cells(elevation: construction, width: width, height: height)
            guard cells.subtracting(target).count >= 3 else { continue }
            target.formUnion(cells)
            blooms.append(bloom)
        }
        guard blooms.count == wanted else { return nil }
        var forbidden: Set<Int> = []
        for cell in ring(target, distance: profile.ring, width: width, height: height)
        where random.int(0...(profile.keep.denominator - 1)) < profile.keep.numerator {
            forbidden.insert(cell)
        }
        var supply: [NocturneGardenKind: Int] = [:]
        for bloom in blooms { supply[bloom.kind, default: 0] += 1 }
        if profile.decoy {
            let unused: [NocturneGardenKind] = kinds.filter { supply[$0] == nil }
            if !unused.isEmpty { supply[unused[random.int(0...(unused.count - 1))]] = 1 }
        }
        let opening: Int = elevations[random.int(0...(elevations.count - 1))]
        return try? NocturneGardenLevel(id: levelID(entry.number), seed: entry.seed, difficulty: profile.band,
                                        width: width, height: height, target: target, forbidden: forbidden,
                                        supply: supply, sizes: profile.sizes, elevations: profile.elevations,
                                        sun: opening, budget: entry.budget, required: profile.required,
                                        leakAllowance: profile.leakAllowance, tutorial: entry.number <= 3)
    }

    /// The cells outside `target` within Chebyshev `distance` of it, inside the bed, ascending.
    static func ring(_ target: Set<Int>, distance: Int, width: Int, height: Int) -> [Int] {
        var result: Set<Int> = []
        for cell in target {
            let column: Int = cell % width
            let row: Int = cell / width
            for dr in -distance...distance {
                for dc in -distance...distance {
                    let c: Int = column + dc
                    let r: Int = row + dr
                    guard c >= 0, c < width, r >= 0, r < height else { continue }
                    let other: Int = r * width + c
                    if !target.contains(other) { result.insert(other) }
                }
            }
        }
        return result.sorted()
    }

    /// The certified level of `entry`: the first candidate the solver certifies in the band's range and budget.
    ///
    /// - Throws: `.generation(number)` when no candidate within ``maxCandidates`` qualifies.
    public static func generate(_ entry: NocturneGardenManifestEntry) throws(NocturneGardenError)
        -> NocturneGardenGenerated {
        let profile: NocturneGardenBandProfile = .of(band: entry.band)
        for index in 0..<maxCandidates {
            guard let level = candidate(entry, index: index),
                  let bound = NocturneGardenSolver.lowerBound(level),
                  profile.smallest.contains(bound.smallest), bound.smallest <= level.budget,
                  let solution = NocturneGardenSolver.solve(level),
                  solution.smallest == bound.smallest else { continue }
            return NocturneGardenGenerated(entry: entry, level: level, solution: solution, bound: bound,
                                           difficulty: NocturneGardenDifficulty(level: level,
                                                                                actions: solution.actions,
                                                                                work: solution.work),
                                           skipped: index)
        }
        throw .generation(entry.number)
    }

    /// The catalog digest (R02-F24) over the levels' fingerprints in order.
    public static func catalogDigest(_ levels: [NocturneGardenLevel]) -> String {
        PuzzleCatalog<NocturneGardenRules>.digest(id: catalogID, identities: levels.map(\.fingerprint))
    }
}
