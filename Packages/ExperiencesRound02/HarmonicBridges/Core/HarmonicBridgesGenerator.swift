// HarmonicBridgesGenerator — feature 412 (R02-G12-02) T-R02G1202-004 (FR-R02G1202-001, 005; SC-R02G1202-001, 003, 004;
// clarifications Q1, Q5). The constructive seeded level generator of Harmonic Bridges. Candidate c of manifest entry n
// draws from `SeededRandom(seed: SeedDerivation.derive(plannedSeed, index: c))`, in this order: the scrambled count k in
// the band's range; the path length P = min(7, k + (0 or 1)); the island count min(8, P + 1 + (0 or 1)); the step count
// in the band's range and, for each step, its tone count in the band's range and then each tone's frequency (drawn
// without repeat from ``HarmonicBridgesGenerator/frequencies``) followed by its strength 1 … 3; the threshold in the
// band's range; the path from island 0 through P − 1 distinct interior islands (the interior islands 1 … I − 2
// shuffled, the first P − 1 taken) to the last island; for each path string, in path order, a (length, peg) drawn from
// the pairs that are a bridge in every step (lengths 1 … 6 outer, pegs 1 … 12 inner; none: the candidate is skipped);
// the k scrambled path strings (the path indices shuffled, the first k taken), which in path order get instead a peg
// drawn from those not a bridge in every step at their length (none: skipped); then the decoy count in the band's range
// and the decoys on the unused island pairs (in (a, b) order, shuffled, at most that many taken), each drawing a length
// 1 … 6, a peg 1 … 12 and then locked with chance 3 in 10; finally the strings are shuffled. Start is island 0, goal the
// last; the budget is the manifest's; ids `harmonic-bridges-NNN`; tutorial on levels 1 … 3; difficulty = band. Island
// drawing positions are laid out from the path order without any draw and never decide a rule. A candidate is kept when
// the solver's plan has a tuning count in the band's range and at most budget − 1 tunings (the test needs the last
// action) within the work bound, and its witness wins through the kernel; at most 256 candidates, then
// `generation(n)`. The ranges were measured by a prototype before they were written down (research R4).
import Foundation
import VisualCoreSimulation

/// What a band asks of its levels (clarification Q1; data model).
public struct HarmonicBridgesBandProfile: Sendable, Equatable {
    /// The band, 1 … 5.
    public let band: Int
    /// The scrambled path strings drawn, which are also the witness tuning counts accepted.
    public let scrambled: ClosedRange<Int>
    /// The steps of the crossing window.
    public let steps: ClosedRange<Int>
    /// The tones of each step.
    public let tones: ClosedRange<Int>
    /// The solidity thresholds.
    public let thresholds: ClosedRange<Int>
    /// The decoy strings.
    public let decoys: ClosedRange<Int>

    /// A profile of the given values.
    public init(band: Int, scrambled: ClosedRange<Int>, steps: ClosedRange<Int>, tones: ClosedRange<Int>,
                thresholds: ClosedRange<Int>, decoys: ClosedRange<Int>) {
        self.band = band
        self.scrambled = scrambled
        self.steps = steps
        self.tones = tones
        self.thresholds = thresholds
        self.decoys = decoys
    }

    /// The profile of `band` (clamped to 1 … 5).
    public static func of(band: Int) -> HarmonicBridgesBandProfile {
        switch min(5, max(1, band)) {
        case 1: HarmonicBridgesBandProfile(band: 1, scrambled: 1...2, steps: 1...1, tones: 2...2, thresholds: 1...3,
                                           decoys: 1...2)
        case 2: HarmonicBridgesBandProfile(band: 2, scrambled: 2...3, steps: 1...2, tones: 2...3, thresholds: 2...4,
                                           decoys: 2...3)
        case 3: HarmonicBridgesBandProfile(band: 3, scrambled: 3...4, steps: 2...2, tones: 2...3, thresholds: 2...5,
                                           decoys: 2...4)
        case 4: HarmonicBridgesBandProfile(band: 4, scrambled: 4...5, steps: 2...3, tones: 2...3, thresholds: 3...6,
                                           decoys: 3...4)
        default: HarmonicBridgesBandProfile(band: 5, scrambled: 5...6, steps: 3...4, tones: 3...3, thresholds: 3...6,
                                            decoys: 3...5)
        }
    }
}

/// A certified catalog level with its plan and metrics.
public struct HarmonicBridgesGenerated: Sendable, Equatable {
    /// The manifest entry it came from.
    public let entry: HarmonicBridgesManifestEntry
    /// The level.
    public let level: HarmonicBridgesLevel
    /// The certified minimal plan.
    public let plan: HarmonicBridgesPlan
    /// The difficulty metrics.
    public let difficulty: HarmonicBridgesDifficulty
    /// The candidates skipped before this one.
    public let skipped: Int

    /// A generated level of the given values (not checked).
    public init(entry: HarmonicBridgesManifestEntry, level: HarmonicBridgesLevel, plan: HarmonicBridgesPlan,
                difficulty: HarmonicBridgesDifficulty, skipped: Int) {
        self.entry = entry
        self.level = level
        self.plan = plan
        self.difficulty = difficulty
        self.skipped = skipped
    }

    /// The witness actions: the plan's tunings in string order, then one test.
    public var actions: [HarmonicBridgesAction] { HarmonicBridgesSolver.actions(plan) }
}

/// The seeded level generator (clarification Q1).
public enum HarmonicBridgesGenerator {
    /// The catalog id of R02-F24's digest.
    public static let catalogID: String = "harmonic-bridges"
    /// The most candidates tried per manifest entry.
    public static let maxCandidates: Int = 256
    /// The tone frequencies a step draws from.
    public static let frequencies: [Int] = [6, 12, 18, 24, 30, 36, 48, 60, 72]
    /// The longest start-to-goal path, in strings.
    public static let maxPath: Int = 7
    /// A decoy is locked when a draw in 0 … 9 is below this (chance 3 in 10).
    public static let lockedInTen: Int = 3

    /// The level id of number `number`: "harmonic-bridges-001" … "harmonic-bridges-100".
    public static func levelID(_ number: Int) -> String {
        let digits: String = String(number)
        return "harmonic-bridges-" + String(repeating: "0", count: max(0, 3 - digits.count)) + digits
    }

    /// Candidate `index` of `entry` in the drawing order of clarification Q1, or nil when no (length, peg) is a bridge
    /// in every step, when a scrambled path string has no peg that breaks it, or when the values make no valid level.
    public static func candidate(_ entry: HarmonicBridgesManifestEntry, index: Int) -> HarmonicBridgesLevel? {
        let profile: HarmonicBridgesBandProfile = .of(band: entry.band)
        var random = SeededRandom(seed: SeedDerivation.derive(entry.seed, index: UInt64(index)))
        let scrambledCount: Int = random.int(profile.scrambled)
        let pathLength: Int = min(maxPath, scrambledCount + random.int(0...1))
        let islandCount: Int = min(HarmonicBridgesLevel.islandCounts.upperBound, pathLength + 1 + random.int(0...1))
        let stepCount: Int = random.int(profile.steps)
        var steps: [[HarmonicBridgesTone]] = []
        for _ in 0..<stepCount {
            let toneCount: Int = random.int(profile.tones)
            var pool: [Int] = frequencies
            var tones: [HarmonicBridgesTone] = []
            for _ in 0..<toneCount {
                let frequency: Int = pool.remove(at: random.int(0...(pool.count - 1)))
                let strength: Int = random.int(HarmonicBridgesLevel.strengths)
                tones.append(HarmonicBridgesTone(frequency: frequency, strength: strength))
            }
            steps.append(tones)
        }
        let threshold: Int = random.int(profile.thresholds)
        guard pathLength >= 1, islandCount - 2 >= pathLength - 1 else { return nil }
        var interior: [Int] = []
        if islandCount > 2 {
            for island in 1...(islandCount - 2) { interior.append(island) }
        }
        random.shuffle(&interior)
        var path: [Int] = [0]
        for position in 0..<(pathLength - 1) { path.append(interior[position]) }
        path.append(islandCount - 1)
        var good: [(length: Int, peg: Int)] = []
        for length in HarmonicBridgesLevel.lengths {
            for peg in HarmonicBridgesLevel.pegs where bridgesEveryStep(length: length, peg: peg, steps: steps,
                                                                        threshold: threshold) {
                good.append((length, peg))
            }
        }
        guard !good.isEmpty else { return nil }
        var lengths: [Int] = []
        var pegs: [Int] = []
        for _ in 0..<pathLength {
            let pair: (length: Int, peg: Int) = good[random.int(0...(good.count - 1))]
            lengths.append(pair.length)
            pegs.append(pair.peg)
        }
        var order: [Int] = Array(0..<pathLength)
        random.shuffle(&order)
        var scrambled: [Bool] = Array(repeating: false, count: pathLength)
        for position in 0..<scrambledCount { scrambled[order[position]] = true }
        for position in 0..<pathLength where scrambled[position] {
            var bad: [Int] = []
            for peg in HarmonicBridgesLevel.pegs where !bridgesEveryStep(length: lengths[position], peg: peg,
                                                                         steps: steps, threshold: threshold) {
                bad.append(peg)
            }
            guard !bad.isEmpty else { return nil }
            pegs[position] = bad[random.int(0...(bad.count - 1))]
        }
        var strings: [HarmonicBridgesString] = []
        var used: Set<Int> = []
        for position in 0..<pathLength {
            let a: Int = min(path[position], path[position + 1])
            let b: Int = max(path[position], path[position + 1])
            used.insert(a * 16 + b)
            strings.append(HarmonicBridgesString(a: a, b: b, length: lengths[position], peg: pegs[position]))
        }
        let decoyCount: Int = random.int(profile.decoys)
        var pairs: [(a: Int, b: Int)] = []
        for a in 0..<islandCount {
            for b in (a + 1)..<max(a + 1, islandCount) where !used.contains(a * 16 + b) { pairs.append((a, b)) }
        }
        random.shuffle(&pairs)
        for position in 0..<min(decoyCount, pairs.count) {
            let length: Int = random.int(HarmonicBridgesLevel.lengths)
            let peg: Int = random.int(HarmonicBridgesLevel.pegs)
            let locked: Bool = random.int(0...9) < lockedInTen
            strings.append(HarmonicBridgesString(a: pairs[position].a, b: pairs[position].b, length: length, peg: peg,
                                                 locked: locked))
        }
        random.shuffle(&strings)
        return try? HarmonicBridgesLevel(id: levelID(entry.number), seed: entry.seed, difficulty: profile.band,
                                         islands: layout(path: path, islandCount: islandCount), strings: strings,
                                         start: 0, goal: islandCount - 1, steps: steps, threshold: threshold,
                                         budget: entry.budget, tutorial: entry.number <= 3)
    }

    /// The certified level of `entry`: the first candidate whose minimal plan has a tuning count in the band's range
    /// and at most budget − 1 tunings, within the work bound, and whose witness wins through the kernel; `skipped` is
    /// the candidates passed over before it.
    ///
    /// - Throws: `.generation(number)` when no candidate of the first ``maxCandidates`` qualifies.
    public static func generate(_ entry: HarmonicBridgesManifestEntry) throws(HarmonicBridgesError)
        -> HarmonicBridgesGenerated {
        let profile: HarmonicBridgesBandProfile = .of(band: entry.band)
        for index in 0..<maxCandidates {
            guard let level = candidate(entry, index: index), let plan = HarmonicBridgesSolver.plan(level) else {
                continue
            }
            let tunings: Int = plan.tunings.count
            guard tunings >= 1, profile.scrambled.contains(tunings), tunings <= level.budget - 1 else { continue }
            guard HarmonicBridgesSolver.wins(level, actions: HarmonicBridgesSolver.actions(plan)) else { continue }
            return HarmonicBridgesGenerated(entry: entry, level: level, plan: plan,
                                            difficulty: HarmonicBridgesDifficulty(level: level, plan: plan),
                                            skipped: index)
        }
        throw .generation(entry.number)
    }

    /// R02-F24's catalog digest over the level fingerprints in order.
    public static func catalogDigest(_ levels: [HarmonicBridgesLevel]) -> String {
        var identities: [String] = []
        for level in levels { identities.append(level.fingerprint) }
        return PuzzleCatalog<HarmonicBridgesRules>.digest(id: catalogID, identities: identities)
    }

    /// Whether a string of `length` at `peg` is a bridge in every one of `steps` against `threshold`.
    static func bridgesEveryStep(length: Int, peg: Int, steps: [[HarmonicBridgesTone]], threshold: Int) -> Bool {
        let string = HarmonicBridgesString(a: 0, b: 1, length: length, peg: peg)
        for (step, tones) in steps.enumerated() {
            let resonance = HarmonicBridgesResonance(string: string, index: 0, step: step, tones: tones, peg: peg,
                                                     threshold: threshold)
            if !resonance.bridge { return false }
        }
        return true
    }

    /// The drawing positions, laid out from the path order without any draw: path island i of P + 1 at column
    /// i · 15 / P, alternating rows 3 and 6; any island off the path on row 9 from column 2, four columns apart. All
    /// lie in 0 … 15 × 0 … 9 and are distinct.
    static func layout(path: [Int], islandCount: Int) -> [HarmonicBridgesIsland] {
        var positions: [HarmonicBridgesIsland?] = Array(repeating: nil, count: islandCount)
        let span: Int = max(1, path.count - 1)
        for (position, island) in path.enumerated() {
            positions[island] = HarmonicBridgesIsland(x: position * 15 / span, y: position % 2 == 0 ? 3 : 6)
        }
        var result: [HarmonicBridgesIsland] = []
        var spare: Int = 0
        for island in 0..<islandCount {
            if let placed = positions[island] {
                result.append(placed)
            } else {
                result.append(HarmonicBridgesIsland(x: min(15, 2 + 4 * spare), y: 9))
                spare += 1
            }
        }
        return result
    }
}
