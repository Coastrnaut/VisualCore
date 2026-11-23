// BackwardsAuroraGenerator — feature 392 (R02-G10-02) T-R02G1002-004 (FR-R02G1002-001, 003, 005; clarification Q1).
// The deterministic level generator of Backwards Aurora. Candidate c of a manifest entry draws from
// `SeededRandom(seed: SeedDerivation.derive(seed, index: c))`, in this order: the wave length; the target, a gently
// curving wave (start height −24 … 24, slope −3 … 3, the slope changing by −1 … 1 per sample and kept within −4 … 4,
// heights kept within −64 … 64); the bend limit L = max(1, the target's worst bend); the reversal count k; then up to
// ``placements`` placements, each drawing k section lengths left to right (each within the band's range and what still
// fits; every band has N ≥ 4k + 2) and spreading the spare samples over the k + 1 gaps, one draw per spare sample (first
// start ≥ 2, each start at least 3 after the previous end, last end ≤ N − 3, so no two sections share or touch a seam
// position and every seam position is interior). The first placement in which no section is a palindrome in the target
// and all four seam bends of every section, reversed alone, exceed L is kept; a candidate with none is dropped. The
// opening wave is the target with all k sections reversed, so it has exactly 4k bad bends and the seam-count bound is
// k. Then the checkpoint sections (band + 1 of the k, by a partial shuffle) and one position in each where the opening
// differs from the target. The breaking limit is 128 in bands 1 … 2, then min(128, L + margin). A candidate is kept
// only when the solver certifies it with exactly k reversals within the budget; at most 256 candidates per entry.
import VisualCoreSimulation

/// The generation profile of a band (clarification Q1).
public struct BackwardsAuroraBandProfile: Sendable, Equatable {
    /// The band, 1 … 5.
    public let band: Int
    /// The wave lengths.
    public let lengths: ClosedRange<Int>
    /// The reversal counts k (the smallest reversal count of the band's levels).
    public let reversals: ClosedRange<Int>
    /// The section lengths.
    public let sectionLengths: ClosedRange<Int>
    /// The number of checkpoints, band + 1.
    public let checkpoints: Int
    /// The breaking margin B − L before the cap at 128; nil means B = 128.
    public let breakingMargin: Int?

    /// A profile of the given values.
    public init(band: Int, lengths: ClosedRange<Int>, reversals: ClosedRange<Int>, sectionLengths: ClosedRange<Int>,
                checkpoints: Int, breakingMargin: Int?) {
        self.band = band
        self.lengths = lengths
        self.reversals = reversals
        self.sectionLengths = sectionLengths
        self.checkpoints = checkpoints
        self.breakingMargin = breakingMargin
    }

    /// The profile of `band` (clamped to 1 … 5).
    public static func of(band: Int) -> BackwardsAuroraBandProfile {
        switch min(max(band, 1), 5) {
        case 1: BackwardsAuroraBandProfile(band: 1, lengths: 14...16, reversals: 2...3, sectionLengths: 2...4,
                                           checkpoints: 2, breakingMargin: nil)
        case 2: BackwardsAuroraBandProfile(band: 2, lengths: 18...22, reversals: 3...4, sectionLengths: 2...5,
                                           checkpoints: 3, breakingMargin: nil)
        case 3: BackwardsAuroraBandProfile(band: 3, lengths: 22...26, reversals: 4...5, sectionLengths: 2...6,
                                           checkpoints: 4, breakingMargin: 48)
        case 4: BackwardsAuroraBandProfile(band: 4, lengths: 26...30, reversals: 5...6, sectionLengths: 2...6,
                                           checkpoints: 5, breakingMargin: 32)
        default: BackwardsAuroraBandProfile(band: 5, lengths: 30...32, reversals: 6...7, sectionLengths: 2...6,
                                            checkpoints: 6, breakingMargin: 16)
        }
    }

    /// The breaking limit for bend limit `bendLimit`: 128, or min(128, L + margin).
    public func breakingLimit(bendLimit: Int) -> Int {
        guard let margin = breakingMargin else { return BackwardsAuroraLevel.maximumBreakingLimit }
        return min(BackwardsAuroraLevel.maximumBreakingLimit, bendLimit + margin)
    }
}

/// A generated, certified level with its solution, bound, difficulty and the candidates skipped.
public struct BackwardsAuroraGenerated: Sendable, Equatable {
    /// The manifest entry.
    public let entry: BackwardsAuroraManifestEntry
    /// The certified level.
    public let level: BackwardsAuroraLevel
    /// The solver's certified solution.
    public let solution: BackwardsAuroraSolution
    /// The lower-bound argument the solution meets.
    public let bound: BackwardsAuroraBound
    /// The difficulty metrics.
    public let difficulty: BackwardsAuroraDifficulty
    /// The candidates skipped before this one, 0 … 255.
    public let skipped: Int

    /// A generated level of the given values.
    public init(entry: BackwardsAuroraManifestEntry, level: BackwardsAuroraLevel, solution: BackwardsAuroraSolution,
                bound: BackwardsAuroraBound, difficulty: BackwardsAuroraDifficulty, skipped: Int) {
        self.entry = entry
        self.level = level
        self.solution = solution
        self.bound = bound
        self.difficulty = difficulty
        self.skipped = skipped
    }
}

/// The deterministic level generator of Backwards Aurora.
public enum BackwardsAuroraGenerator {
    /// The catalog id.
    public static let catalogID: String = "backwards-aurora"
    /// The most candidates tried per entry.
    public static let maxCandidates: Int = 256
    /// The most section placements tried per candidate.
    public static let placements: Int = 16

    /// The level id of manifest number `number`: "backwards-aurora-001" … "backwards-aurora-100".
    public static func levelID(_ number: Int) -> String {
        let digits: String = String(number)
        return "backwards-aurora-" + String(repeating: "0", count: max(0, 3 - digits.count)) + digits
    }

    /// The candidate level `index` of `entry`, or nil when its draws do not make a valid candidate.
    public static func candidate(_ entry: BackwardsAuroraManifestEntry, index: Int) -> BackwardsAuroraLevel? {
        let profile: BackwardsAuroraBandProfile = .of(band: entry.band)
        var random = SeededRandom(seed: SeedDerivation.derive(entry.seed, index: UInt64(index)))
        let count: Int = random.int(profile.lengths)
        var samples: [Int] = []
        var height: Int = random.int(-24...24)
        var slope: Int = random.int(-3...3)
        for _ in 0..<count {
            samples.append(min(max(height, -64), 64))
            slope = min(max(slope + random.int(-1...1), -4), 4)
            height += slope
        }
        guard let target = try? BackwardsAuroraWave(samples) else { return nil }
        let bendLimit: Int = max(1, target.worstBend)
        guard BackwardsAuroraLevel.bendLimits.contains(bendLimit) else { return nil }
        let k: Int = random.int(profile.reversals)
        var found: [(start: Int, end: Int)]? = nil
        for _ in 0..<placements {
            let sections: [(start: Int, end: Int)] = place(count: count, k: k,
                                                           lengths: profile.sectionLengths, random: &random)
            if accepts(sections, target: target, bendLimit: bendLimit) {
                found = sections
                break
            }
        }
        guard let sections = found else { return nil }
        var opening: BackwardsAuroraWave = target
        for section in sections { opening = opening.reversed(start: section.start, end: section.end) }
        guard BackwardsAuroraSolver.badBends(opening, limit: bendLimit) == 4 * k else { return nil }
        var chosen: [Int] = Array(0..<k)
        for i in 0..<profile.checkpoints {
            let j: Int = random.int(i...(k - 1))
            chosen.swapAt(i, j)
        }
        var checkpoints: [Int] = []
        for m in chosen.prefix(profile.checkpoints) {
            let section = sections[m]
            let differing: [Int] = (section.start...section.end).filter {
                opening.samples[$0] != target.samples[$0]
            }
            guard !differing.isEmpty else { return nil }
            checkpoints.append(differing[random.int(0...(differing.count - 1))])
        }
        return try? BackwardsAuroraLevel(id: levelID(entry.number), seed: entry.seed, difficulty: profile.band,
                                         opening: opening, target: target, checkpoints: checkpoints,
                                         bendLimit: bendLimit, breakingLimit: profile.breakingLimit(bendLimit: bendLimit),
                                         shortest: BackwardsAuroraLevel.minimumSection, longest: count,
                                         budget: entry.budget, tutorial: entry.number <= 3)
    }

    /// One placement of `k` sections in a wave of `count` samples: lengths drawn left to right within `lengths` and
    /// what still fits, then the spare samples spread over the k + 1 gaps; first start 2 + gap 0, each next start the
    /// previous end + 3 + its gap, so the last end is at most `count` − 3. Requires `count` ≥ 4k + 2.
    static func place(count: Int, k: Int, lengths: ClosedRange<Int>,
                      random: inout SeededRandom) -> [(start: Int, end: Int)] {
        let available: Int = count - 4 - 2 * (k - 1)
        var drawn: [Int] = []
        var used: Int = 0
        for m in 0..<k {
            let rest: Int = k - m - 1
            let high: Int = min(lengths.upperBound, available - used - lengths.lowerBound * rest)
            let length: Int = random.int(lengths.lowerBound...max(lengths.lowerBound, high))
            drawn.append(length)
            used += length
        }
        var gaps: [Int] = Array(repeating: 0, count: k + 1)
        for _ in 0..<max(0, available - used) { gaps[random.int(0...k)] += 1 }
        var sections: [(start: Int, end: Int)] = []
        var start: Int = 2 + gaps[0]
        for m in 0..<k {
            let end: Int = start + drawn[m] - 1
            sections.append((start: start, end: end))
            start = end + 3 + gaps[m + 1]
        }
        return sections
    }

    /// Whether every section of `sections` is not a palindrome in `target` and, reversed alone, gives all its seam
    /// bends a magnitude above `bendLimit`.
    static func accepts(_ sections: [(start: Int, end: Int)], target: BackwardsAuroraWave, bendLimit: Int) -> Bool {
        for section in sections {
            guard section.end <= target.count - 3, !target.isPalindrome(start: section.start, end: section.end) else {
                return false
            }
            let alone: BackwardsAuroraWave = target.reversed(start: section.start, end: section.end)
            for seam in BackwardsAuroraWave.seams(start: section.start, end: section.end, count: target.count)
            where abs(alone.bend(at: seam)) <= bendLimit {
                return false
            }
        }
        return true
    }

    /// The certified level of `entry`: the first candidate the solver certifies with exactly its k reversals (the
    /// seam-count bound) within the budget.
    ///
    /// - Throws: `.generation(number)` when no candidate within ``maxCandidates`` qualifies.
    public static func generate(_ entry: BackwardsAuroraManifestEntry) throws(BackwardsAuroraError)
        -> BackwardsAuroraGenerated {
        let profile: BackwardsAuroraBandProfile = .of(band: entry.band)
        for index in 0..<maxCandidates {
            guard let level = candidate(entry, index: index) else { continue }
            let bound: BackwardsAuroraBound = BackwardsAuroraSolver.lowerBound(level)
            guard profile.reversals.contains(bound.smallest), bound.smallest <= level.budget,
                  let solution = BackwardsAuroraSolver.solve(level),
                  solution.smallest == bound.smallest else { continue }
            return BackwardsAuroraGenerated(entry: entry, level: level, solution: solution, bound: bound,
                                            difficulty: BackwardsAuroraDifficulty(level: level,
                                                                                  actions: solution.actions,
                                                                                  work: solution.work),
                                            skipped: index)
        }
        throw .generation(entry.number)
    }

    /// The catalog digest (R02-F24) over the levels' fingerprints in order.
    public static func catalogDigest(_ levels: [BackwardsAuroraLevel]) -> String {
        PuzzleCatalog<BackwardsAuroraRules>.digest(id: catalogID, identities: levels.map(\.fingerprint))
    }
}
