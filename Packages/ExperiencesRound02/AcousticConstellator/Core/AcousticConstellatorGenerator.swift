// AcousticConstellatorGenerator — feature 422 (R02-G13-02) T-R02G1302-004 (FR-R02G1302-001, 005; SC-R02G1302-001, 003,
// 004; clarifications Q1, Q5). The constructive seeded level generator of Acoustic Constellator. Candidate c of manifest
// entry n draws from `SeededRandom(seed: SeedDerivation.derive(plannedSeed, index: c))`, in this order: the star count n
// in the band's range; the symbol as a spanning tree (the stars 0 … n − 1 shuffled, then each star of that order after
// the first joined to an earlier one drawn by its position) plus, from band 3, one extra pair not already in it (drawn
// from the absent pairs in pair order: a cycle); a base rate 0 … 11 and, in star order, each star's rate base + 0 or 1
// (1 when a draw in 0 … 2 is below 1, chance 1 in 3), modulo 12; in star order, each star's starting phase 0 … 11; the
// missing count in the band's range (at most the symbol's size) and the missing pairs as the first that many of the
// symbol's pairs (in pair order) shuffled, the other symbol pairs being the fixed links; the coupling K 2 … 8, the snap
// limit 3 … 5 and the hold 4 … 8. The window is the band's (no draw). Then the degree limit is min(4, max(2, the
// symbol's largest degree + 1)), the link limit min(16, the symbol's size + 2) and the threshold ⌊3n²/5⌋. The symbol and
// the fixed links are stored in pair order; the budget is the manifest's; ids `acoustic-constellator-NNN`; tutorial on
// levels 1 … 3; difficulty = band. Star drawing positions are laid out from the symbol's tree order without any draw
// and never decide a rule. A candidate is kept when the solver's minimal plan has an action count in the band's plan
// range and at most budget − 1 actions (the listen needs the last action) within the work bound, and its witness wins
// through the kernel; at most 256 candidates, then `generation(n)`. The ranges were measured by a prototype before
// they were written down (research R4).
import Foundation
import VisualCoreSimulation

/// What a band asks of its levels (clarification Q1; data model).
public struct AcousticConstellatorBandProfile: Sendable, Equatable {
    /// The band, 1 … 5.
    public let band: Int
    /// The star counts drawn.
    public let stars: ClosedRange<Int>
    /// The missing symbol pairs drawn (at most the symbol's size).
    public let missing: ClosedRange<Int>
    /// The window, in ticks.
    public let window: Int
    /// The witness action counts (before the listen) accepted.
    public let planRange: ClosedRange<Int>
    /// Whether the symbol gets one extra pair beyond its spanning tree (a cycle).
    public let cycle: Bool

    /// A profile of the given values.
    public init(band: Int, stars: ClosedRange<Int>, missing: ClosedRange<Int>, window: Int,
                planRange: ClosedRange<Int>, cycle: Bool) {
        self.band = band
        self.stars = stars
        self.missing = missing
        self.window = window
        self.planRange = planRange
        self.cycle = cycle
    }

    /// The profile of `band` (clamped to 1 … 5).
    public static func of(band: Int) -> AcousticConstellatorBandProfile {
        switch min(5, max(1, band)) {
        case 1: AcousticConstellatorBandProfile(band: 1, stars: 3...4, missing: 1...2, window: 24, planRange: 1...2,
                                                cycle: false)
        case 2: AcousticConstellatorBandProfile(band: 2, stars: 4...5, missing: 1...2, window: 24, planRange: 2...3,
                                                cycle: false)
        case 3: AcousticConstellatorBandProfile(band: 3, stars: 5...6, missing: 2...3, window: 32, planRange: 3...4,
                                                cycle: true)
        case 4: AcousticConstellatorBandProfile(band: 4, stars: 6...7, missing: 2...3, window: 40, planRange: 4...5,
                                                cycle: true)
        default: AcousticConstellatorBandProfile(band: 5, stars: 7...8, missing: 3...4, window: 48, planRange: 5...6,
                                                 cycle: true)
        }
    }
}

/// A certified catalog level with its plan and metrics.
public struct AcousticConstellatorGenerated: Sendable, Equatable {
    /// The manifest entry it came from.
    public let entry: AcousticConstellatorManifestEntry
    /// The level.
    public let level: AcousticConstellatorLevel
    /// The certified minimal plan.
    public let plan: AcousticConstellatorPlan
    /// The difficulty metrics.
    public let difficulty: AcousticConstellatorDifficulty
    /// The candidates skipped before this one.
    public let skipped: Int

    /// A generated level of the given values (not checked).
    public init(entry: AcousticConstellatorManifestEntry, level: AcousticConstellatorLevel,
                plan: AcousticConstellatorPlan, difficulty: AcousticConstellatorDifficulty, skipped: Int) {
        self.entry = entry
        self.level = level
        self.plan = plan
        self.difficulty = difficulty
        self.skipped = skipped
    }

    /// The witness actions: the plan's links in pair order, its nudges in star order, then one listen.
    public var actions: [AcousticConstellatorAction] { AcousticConstellatorSolver.actions(plan) }
}

/// The seeded level generator (clarification Q1).
public enum AcousticConstellatorGenerator {
    /// The catalog id of R02-F24's digest.
    public static let catalogID: String = "acoustic-constellator"
    /// The most candidates tried per manifest entry.
    public static let maxCandidates: Int = 256
    /// A star's rate is the base rate + 1 when a draw in 0 … 2 is below this (chance 1 in 3).
    public static let fasterInThree: Int = 1
    /// The couplings K drawn.
    public static let couplings: ClosedRange<Int> = 2...8
    /// The snap limits σ drawn.
    public static let snapLimits: ClosedRange<Int> = 3...5
    /// The holds H drawn.
    public static let holds: ClosedRange<Int> = 4...8

    /// The level id of number `number`: "acoustic-constellator-001" … "acoustic-constellator-100".
    public static func levelID(_ number: Int) -> String {
        let digits: String = String(number)
        return "acoustic-constellator-" + String(repeating: "0", count: max(0, 3 - digits.count)) + digits
    }

    /// The degree limit of `symbol` on `stars` stars: min(4, max(2, the symbol's largest degree + 1)).
    public static func degreeLimit(symbol: [AcousticConstellatorLink], stars: Int) -> Int {
        var degrees: [Int] = Array(repeating: 0, count: stars)
        for pair in symbol {
            degrees[pair.a] += 1
            degrees[pair.b] += 1
        }
        return min(4, max(2, (degrees.max() ?? 0) + 1))
    }

    /// The link limit of a symbol of `size` pairs: min(16, size + 2).
    public static func linkLimit(symbolSize size: Int) -> Int { min(AcousticConstellatorLevel.maxLinkLimit, size + 2) }

    /// The coherence threshold of `stars` stars: ⌊3n²/5⌋.
    public static func threshold(stars: Int) -> Int { 3 * stars * stars / 5 }

    /// Candidate `index` of `entry` in the drawing order of clarification Q1, or nil when the values make no valid
    /// level (a symbol star of degree 5 or more: the degree limit is capped at 4, so the level is refused).
    public static func candidate(_ entry: AcousticConstellatorManifestEntry,
                                 index: Int) -> AcousticConstellatorLevel? {
        let profile: AcousticConstellatorBandProfile = .of(band: entry.band)
        var random = SeededRandom(seed: SeedDerivation.derive(entry.seed, index: UInt64(index)))
        let n: Int = random.int(profile.stars)
        var order: [Int] = Array(0..<n)
        random.shuffle(&order)
        var symbol: [AcousticConstellatorLink] = []
        for position in 1..<n {
            let earlier: Int = order[random.int(0...(position - 1))]
            symbol.append(AcousticConstellatorLink.between(order[position], earlier))
        }
        if profile.cycle {
            var absent: [AcousticConstellatorLink] = []
            for a in 0..<n {
                for b in (a + 1)..<max(a + 1, n) where !symbol.contains(AcousticConstellatorLink(a: a, b: b)) {
                    absent.append(AcousticConstellatorLink(a: a, b: b))
                }
            }
            guard !absent.isEmpty else { return nil }
            symbol.append(absent[random.int(0...(absent.count - 1))])
        }
        symbol.sort()
        let base: Int = random.int(AcousticConstellatorLevel.rates)
        var rates: [Int] = []
        for _ in 0..<n {
            let faster: Int = random.int(0...2) < fasterInThree ? 1 : 0
            rates.append(AcousticConstellatorClock.reduce(base + faster))
        }
        var phases: [Int] = []
        for _ in 0..<n { phases.append(random.int(AcousticConstellatorLevel.phases)) }
        let missingCount: Int = min(random.int(profile.missing), symbol.count)
        var shuffled: [AcousticConstellatorLink] = symbol
        random.shuffle(&shuffled)
        let missing: Set<AcousticConstellatorLink> = Set(shuffled.prefix(missingCount))
        let fixed: [AcousticConstellatorLink] = symbol.filter { !missing.contains($0) }
        let coupling: Int = random.int(couplings)
        let snapLimit: Int = random.int(snapLimits)
        let hold: Int = random.int(holds)
        let positions: [(x: Int, y: Int, z: Int)] = layout(order: order)
        var stars: [AcousticConstellatorStar] = []
        for star in 0..<n {
            stars.append(AcousticConstellatorStar(x: positions[star].x, y: positions[star].y, z: positions[star].z,
                                                  rate: rates[star], phase: phases[star]))
        }
        return try? AcousticConstellatorLevel(id: levelID(entry.number), seed: entry.seed, difficulty: profile.band,
                                              stars: stars, fixedLinks: fixed, symbol: symbol, coupling: coupling,
                                              degreeLimit: degreeLimit(symbol: symbol, stars: n),
                                              linkLimit: linkLimit(symbolSize: symbol.count), snapLimit: snapLimit,
                                              threshold: threshold(stars: n), hold: hold, window: profile.window,
                                              budget: entry.budget, tutorial: entry.number <= 3)
    }

    /// The certified level of `entry`: the first candidate whose minimal plan has an action count in the band's plan
    /// range and at most budget − 1 actions, within the work bound, and whose witness wins through the kernel;
    /// `skipped` is the candidates passed over before it.
    ///
    /// - Throws: `.generation(number)` when no candidate of the first ``maxCandidates`` qualifies.
    public static func generate(_ entry: AcousticConstellatorManifestEntry) throws(AcousticConstellatorError)
        -> AcousticConstellatorGenerated {
        let profile: AcousticConstellatorBandProfile = .of(band: entry.band)
        for index in 0..<maxCandidates {
            guard let level = candidate(entry, index: index), let plan = AcousticConstellatorSolver.plan(level) else {
                continue
            }
            let size: Int = plan.size
            guard size >= 1, profile.planRange.contains(size), size <= level.budget - 1 else { continue }
            guard AcousticConstellatorSolver.wins(level, actions: AcousticConstellatorSolver.actions(plan)) else {
                continue
            }
            return AcousticConstellatorGenerated(entry: entry, level: level, plan: plan,
                                                 difficulty: AcousticConstellatorDifficulty(level: level, plan: plan),
                                                 skipped: index)
        }
        throw .generation(entry.number)
    }

    /// R02-F24's catalog digest over the level fingerprints in order.
    public static func catalogDigest(_ levels: [AcousticConstellatorLevel]) -> String {
        var identities: [String] = []
        for level in levels { identities.append(level.fingerprint) }
        return PuzzleCatalog<AcousticConstellatorRules>.digest(id: catalogID, identities: identities)
    }

    /// The circle points (x, y) of n = 3 … 8 stars: point k at angle 360°·k/n clockwise from the top on a circle of
    /// radius 5 around (6, 6), rounded; distinct and within 0 … 11.
    static let circle: [[(x: Int, y: Int)]] = [
        [(6, 1), (10, 8), (2, 9)],
        [(6, 1), (11, 6), (6, 11), (1, 6)],
        [(6, 1), (11, 4), (9, 10), (3, 10), (1, 4)],
        [(6, 1), (10, 3), (10, 8), (6, 11), (2, 9), (2, 3)],
        [(6, 1), (10, 3), (11, 7), (8, 11), (4, 11), (1, 7), (2, 3)],
        [(6, 1), (10, 2), (11, 6), (10, 10), (6, 11), (2, 10), (1, 6), (2, 2)],
    ]

    /// The drawing positions, laid out from the symbol's tree order without any draw: the star at position k of
    /// `order` takes circle point k of n, at depth 5 for even k and 7 for odd k. All lie in 0 … 11 and are distinct.
    static func layout(order: [Int]) -> [(x: Int, y: Int, z: Int)] {
        let points: [(x: Int, y: Int)] = circle[order.count - 3]
        var result: [(x: Int, y: Int, z: Int)] = Array(repeating: (0, 0, 0), count: order.count)
        for (position, star) in order.enumerated() {
            result[star] = (points[position].x, points[position].y, position % 2 == 0 ? 5 : 7)
        }
        return result
    }
}
