// CelestialEclipseLabGenerator — feature 462 (R02-G17-02) T-R02G1702-004 (FR-R02G1702-001, 005, 007; SC-R02G1702-001,
// 003, 004; clarification Q1). The constructive level generator of Celestial Eclipse Lab. Candidate c of a manifest
// entry draws from `SeededRandom(seed: SeedDerivation.derive(plannedSeed, index: c))`, in this order: the body count;
// a depth rank per body (a Fisher–Yates shuffle of 0 … count − 1, from the last index down); for each body its period
// (4 … 8), centre x and y (−8 … 8 each), semi-axes a and b (3 … 10 each), direction (forward or backward) and tilt
// (−1 … 1), its orbit positions being (cx + round(a·cos), cy + round(b·sin), 4·rank − 12 + round(tilt·sin)) from a
// fixed integer table of cos and sin × 1000 per period (rounded half away from zero; no floating point), then its
// radius (1 … 4); body 0 is fixed, the others movable; the horizon; the winning phases (one per body); the target
// count, the target being the first that many eclipse events of the winning phases' timeline, each with window open =
// first − 0 … 2 (at least 0) and close = first + 0 … 2 (at most horizon − 1); the number of bodies to move away (drawn
// from the one-value range moved … moved, so a draw is consumed, as measured), each a drawn movable body given a drawn
// different phase. Budget = the manifest's; ids `celestial-eclipse-lab-NNN`; tutorial on levels 1 … 3; difficulty =
// band. `generate` keeps the first candidate the level rules accept (starting phases that already win are refused)
// whose target sequence of (front, back) pairs differs from the previous level's and whose minimal plan lies in its
// band's range within the solver's work bound; at most 256 candidates, then `generation(n)`. The ranges were measured
// by a prototype of this generator on the real kernel and the real manifest before they were written down. Modelled on
// `StarlitCartoucheGenerator` (feature 452).
import VisualCoreSimulation

/// The values of one band (clarification Q1).
public struct CelestialEclipseLabBandProfile: Sendable, Equatable {
    /// The body counts.
    public let bodies: ClosedRange<Int>
    /// The target counts.
    public let targets: ClosedRange<Int>
    /// The horizons (ticks).
    public let horizon: ClosedRange<Int>
    /// The bodies moved away from their winning phases (at most the movable count).
    public let moved: Int
    /// The accepted minimal plan sizes (phase changes).
    public let planRange: ClosedRange<Int>

    /// The profile of `band` (1 … 5; others clamp): band 1 (3, 1 … 2, 24 … 32, 2, 1 … 2), 2 (3 … 4, 2 … 3, 28 … 36,
    /// 3, 2 … 3), 3 (4 … 5, 2 … 3, 32 … 40, 4, 3 … 4), 4 (5 … 6, 3 … 4, 36 … 44, 4, 3 … 4), 5 (6, 3 … 4, 40 … 48, 5,
    /// 4 … 5) as (bodies, targets, horizon, moved, plan range).
    public static func of(band: Int) -> CelestialEclipseLabBandProfile {
        switch min(max(band, 1), 5) {
        case 1: CelestialEclipseLabBandProfile(bodies: 3...3, targets: 1...2, horizon: 24...32, moved: 2,
                                               planRange: 1...2)
        case 2: CelestialEclipseLabBandProfile(bodies: 3...4, targets: 2...3, horizon: 28...36, moved: 3,
                                               planRange: 2...3)
        case 3: CelestialEclipseLabBandProfile(bodies: 4...5, targets: 2...3, horizon: 32...40, moved: 4,
                                               planRange: 3...4)
        case 4: CelestialEclipseLabBandProfile(bodies: 5...6, targets: 3...4, horizon: 36...44, moved: 4,
                                               planRange: 3...4)
        default: CelestialEclipseLabBandProfile(bodies: 6...6, targets: 3...4, horizon: 40...48, moved: 5,
                                                planRange: 4...5)
        }
    }
}

/// A certified catalog level with its plan, difficulty and the candidates skipped before it.
public struct CelestialEclipseLabGenerated: Sendable, Equatable {
    /// The manifest entry.
    public let entry: CelestialEclipseLabManifestEntry
    /// The level.
    public let level: CelestialEclipseLabLevel
    /// The minimal plan.
    public let plan: CelestialEclipseLabPlan
    /// The difficulty metrics.
    public let difficulty: CelestialEclipseLabDifficulty
    /// The index of the accepted candidate (the candidates skipped before it).
    public let skipped: Int

    /// A generated level of the given values.
    public init(entry: CelestialEclipseLabManifestEntry, level: CelestialEclipseLabLevel, plan: CelestialEclipseLabPlan,
                difficulty: CelestialEclipseLabDifficulty, skipped: Int) {
        self.entry = entry
        self.level = level
        self.plan = plan
        self.difficulty = difficulty
        self.skipped = skipped
    }
}

/// The constructive generator of Celestial Eclipse Lab (see the file header).
public enum CelestialEclipseLabGenerator {
    /// The catalog id of the digest.
    public static let catalogID: String = "celestial-eclipse-lab"
    /// The most candidates tried per entry.
    public static let maxCandidates: Int = 256

    /// round(1000·cos(2πk/p)), round(1000·sin(2πk/p)) for k = 0 … p − 1, periods p = 4 … 8.
    static let unitCircle: [Int: [(Int, Int)]] = [
        4: [(1000, 0), (0, 1000), (-1000, 0), (0, -1000)],
        5: [(1000, 0), (309, 951), (-809, 588), (-809, -588), (309, -951)],
        6: [(1000, 0), (500, 866), (-500, 866), (-1000, 0), (-500, -866), (500, -866)],
        7: [(1000, 0), (623, 782), (-223, 975), (-901, 434), (-901, -434), (-223, -975), (623, -782)],
        8: [(1000, 0), (707, 707), (0, 1000), (-707, 707), (-1000, 0), (-707, -707), (0, -1000), (707, -707)],
    ]

    /// The level id of manifest number `number`: `celestial-eclipse-lab-NNN`.
    public static func levelID(_ number: Int) -> String {
        let digits: String = String(number)
        return "celestial-eclipse-lab-" + String(repeating: "0", count: max(0, 3 - digits.count)) + digits
    }

    /// `value · unit / 1000` rounded half away from zero.
    static func scaled(_ value: Int, _ unit: Int) -> Int {
        let product: Int = value * unit
        return product >= 0 ? (product + 500) / 1000 : -((-product + 500) / 1000)
    }

    /// Candidate `index` of `entry`, or nil when its draws do not give a valid level (values the level rules refuse,
    /// starting phases that already win, or fewer eclipse events than the target count).
    public static func candidate(_ entry: CelestialEclipseLabManifestEntry, index: Int) -> CelestialEclipseLabLevel? {
        var random = SeededRandom(seed: SeedDerivation.derive(entry.seed, index: UInt64(index)))
        let profile: CelestialEclipseLabBandProfile = .of(band: entry.band)
        let count: Int = random.int(profile.bodies)
        var rank: [Int] = Array(0..<count)
        var last: Int = count - 1
        while last > 0 {
            let other: Int = random.int(0...last)
            rank.swapAt(last, other)
            last -= 1
        }
        var bodies: [CelestialEclipseLabBody] = []
        for body in 0..<count {
            let period: Int = random.int(4...8)
            let cx: Int = random.int(-8...8)
            let cy: Int = random.int(-8...8)
            let a: Int = random.int(3...10)
            let b: Int = random.int(3...10)
            let forward: Bool = random.int(0...1) == 0
            let tilt: Int = random.int(-1...1)
            let layer: Int = 4 * rank[body] - 12
            guard let table = unitCircle[period] else { return nil }
            var orbit: [CelestialEclipseLabVector] = []
            for k in 0..<period {
                let (cosine, sine) = table[forward ? k : (period - k) % period]
                orbit.append(CelestialEclipseLabVector(cx + scaled(a, cosine), cy + scaled(b, sine),
                                                       layer + scaled(tilt, sine)))
            }
            let radius: Int = random.int(1...4)
            bodies.append(CelestialEclipseLabBody(orbit: orbit, radius: radius, fixed: body == 0))
        }
        let horizon: Int = random.int(profile.horizon)
        var winning: [Int] = []
        for body in bodies { winning.append(random.int(0...(body.period - 1))) }
        let targetCount: Int = random.int(profile.targets)
        let first: (front: Int, back: Int) = bodies[0].nearestBack > bodies[1].farthestFront ? (0, 1) : (1, 0)
        guard let probe = try? CelestialEclipseLabLevel.probe(
            bodies: bodies, horizon: horizon,
            target: [CelestialEclipseLabTarget(front: first.front, back: first.back, open: 0, close: 0)],
            phases: winning) else { return nil }
        let events: [CelestialEclipseLabInterval] = CelestialEclipseLabSky.intervals(probe, phases: winning)
        guard events.count >= targetCount else { return nil }
        var target: [CelestialEclipseLabTarget] = []
        for event in events.prefix(targetCount) {
            let open: Int = max(0, event.first - random.int(0...2))
            let close: Int = min(horizon - 1, event.first + random.int(0...2))
            target.append(CelestialEclipseLabTarget(front: event.front, back: event.back, open: open, close: close))
        }
        var phases: [Int] = winning
        var pool: [Int] = Array(1..<count)
        let moved: Int = min(random.int(profile.moved...profile.moved), pool.count)
        for _ in 0..<moved {
            let body: Int = pool.remove(at: random.int(0...(pool.count - 1)))
            var offset: Int = random.int(0...(bodies[body].period - 2))
            if offset >= winning[body] { offset += 1 }
            phases[body] = offset
        }
        return try? CelestialEclipseLabLevel(id: levelID(entry.number), seed: entry.seed, difficulty: entry.band,
                                             bodies: bodies, horizon: horizon, target: target, phases: phases,
                                             budget: entry.budget, tutorial: entry.number <= 3)
    }

    /// The target sequence of (front, back) pairs of `level`.
    static func pairs(_ level: CelestialEclipseLabLevel) -> [[Int]] { level.target.map { [$0.front, $0.back] } }

    /// The certified level of `entry`: the first candidate whose target sequence differs from `previous`'s and whose
    /// minimal plan lies in its band's range (and within the budget) within the solver's work bound.
    ///
    /// - Throws: `.generation(number)` when none of the first ``maxCandidates`` candidates qualifies.
    public static func generate(_ entry: CelestialEclipseLabManifestEntry, previous: CelestialEclipseLabLevel?)
        throws(CelestialEclipseLabError) -> CelestialEclipseLabGenerated {
        let range: ClosedRange<Int> = CelestialEclipseLabBandProfile.of(band: entry.band).planRange
        for index in 0..<maxCandidates {
            guard let level = candidate(entry, index: index) else { continue }
            if let previous, pairs(previous) == pairs(level) { continue }
            guard let plan = CelestialEclipseLabSolver.plan(level, maxChanges: range.upperBound),
                  range.contains(plan.size), plan.size <= entry.budget else { continue }
            return CelestialEclipseLabGenerated(entry: entry, level: level, plan: plan,
                                                difficulty: CelestialEclipseLabDifficulty(level: level, plan: plan),
                                                skipped: index)
        }
        throw .generation(entry.number)
    }

    /// The 100 certified levels in manifest order, each generated after the one before it (the neighbour rule).
    ///
    /// - Throws: `.generation(number)` for the first entry that yields no level.
    public static func catalog() throws(CelestialEclipseLabError) -> [CelestialEclipseLabGenerated] {
        var result: [CelestialEclipseLabGenerated] = []
        for entry in CelestialEclipseLabManifest.entries {
            result.append(try generate(entry, previous: result.last?.level))
        }
        return result
    }

    /// The catalog digest of `levels` (their fingerprints, in order).
    public static func catalogDigest(_ levels: [CelestialEclipseLabLevel]) -> String {
        PuzzleCatalog<CelestialEclipseLabRules>.digest(id: catalogID, identities: levels.map(\.fingerprint))
    }
}
