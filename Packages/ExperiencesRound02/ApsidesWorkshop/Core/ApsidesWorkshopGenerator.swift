// ApsidesWorkshopGenerator — feature 472 (R02-G18-02) T-R02G1802-004 (FR-R02G1802-001, 005, 007; SC-R02G1802-001, 003,
// 004; clarification Q1; research R4, R6). The constructive generator of Apsides Workshop's 100 catalog levels.
// Candidate c of manifest entry n draws from `SeededRandom(seed: SeedDerivation.derive(plannedSeed, index: c))`, in
// this order: the period (band profile); the winning orbit (redrawn until valid); the target count and the apsis-target
// count (at most the target count); the sweep sectors (drawn from the sectors with a share above 0, distinct, until the
// sweep count or the visited sectors run out), each with a band of its winning share ± a drawn half-width clipped to 0
// … 1000; the apsis targets (with two, periapsis then apoapsis; with one, a drawn kind), each with its winning sector
// and a range of its winning distance ± a drawn half-width clipped to 0 … 1280; the targets ordered by event tick (ties
// keep their drawing order); the planets (each try draws a tick, a radius 1 … 3, a gap of radius + 1 … 4 lattice units
// and a side, and places the centre that far from the winning position along its radial line, rounded to lattice units;
// a centre outside −64 … 64, over the star or struck by the winning orbit is rejected; at most 60 tries); the levers to
// move and, with one, which lever; the starting orbit (the winning one with the knob redrawn, the size redrawn, or
// both). A candidate is skipped when its planets cannot all be placed, its starting orbit is invalid or equal to the
// winning one, the level rules refuse it (a starting orbit that already wins included), its targets equal the previous
// level's, or the solver does not certify a minimal plan in its band's plan range; at most 256 candidates, then
// `generation(n)`. Modelled on `CelestialEclipseLabGenerator` (feature 462).
import VisualCoreSimulation

/// The generator settings of one band.
public struct ApsidesWorkshopBandProfile: Sendable, Equatable {
    /// The periods a candidate draws from.
    public let periods: [Int]
    /// The target count.
    public let targets: ClosedRange<Int>
    /// The apsis-target count (at most the target count).
    public let apsisTargets: ClosedRange<Int>
    /// The half-width of a sweep's share band (tenths of a percent).
    public let sweepHalfWidth: ClosedRange<Int>
    /// The half-width of an apsis target's distance range (twentieths of a lattice unit).
    public let apsisHalfWidth: ClosedRange<Int>
    /// The planet count.
    public let planets: ClosedRange<Int>
    /// The levers moved away from the winning orbit (1 or 2).
    public let levers: ClosedRange<Int>
    /// The accepted lengths of the minimal plan.
    public let planRange: ClosedRange<Int>

    /// The profile of `band` (1 … 5; others take band 5's).
    public static func of(band: Int) -> ApsidesWorkshopBandProfile {
        switch band {
        case 1:
            return ApsidesWorkshopBandProfile(periods: [24], targets: 1...2, apsisTargets: 0...0,
                                              sweepHalfWidth: 60...90, apsisHalfWidth: 40...60, planets: 0...0,
                                              levers: 1...1, planRange: 1...1)
        case 2:
            return ApsidesWorkshopBandProfile(periods: [24, 32], targets: 2...2, apsisTargets: 0...1,
                                              sweepHalfWidth: 45...70, apsisHalfWidth: 40...60, planets: 0...1,
                                              levers: 1...1, planRange: 1...1)
        case 3:
            return ApsidesWorkshopBandProfile(periods: [32], targets: 2...3, apsisTargets: 1...1,
                                              sweepHalfWidth: 35...55, apsisHalfWidth: 25...45, planets: 1...1,
                                              levers: 1...2, planRange: 1...2)
        case 4:
            return ApsidesWorkshopBandProfile(periods: [32, 48], targets: 3...3, apsisTargets: 1...1,
                                              sweepHalfWidth: 25...40, apsisHalfWidth: 20...35, planets: 1...2,
                                              levers: 2...2, planRange: 2...2)
        default:
            return ApsidesWorkshopBandProfile(periods: [48], targets: 3...4, apsisTargets: 1...2,
                                              sweepHalfWidth: 18...30, apsisHalfWidth: 15...25, planets: 2...3,
                                              levers: 2...2, planRange: 2...2)
        }
    }
}

/// A certified catalog level with its plan, difficulty and the candidates skipped.
public struct ApsidesWorkshopGenerated: Sendable, Equatable {
    /// The manifest entry.
    public let entry: ApsidesWorkshopManifestEntry
    /// The level.
    public let level: ApsidesWorkshopLevel
    /// The certified minimal plan.
    public let plan: ApsidesWorkshopPlan
    /// The difficulty metrics.
    public let difficulty: ApsidesWorkshopDifficulty
    /// The index of the accepted candidate (the candidates skipped before it).
    public let skipped: Int

    /// A generated level of the given values.
    public init(entry: ApsidesWorkshopManifestEntry, level: ApsidesWorkshopLevel, plan: ApsidesWorkshopPlan,
                difficulty: ApsidesWorkshopDifficulty, skipped: Int) {
        self.entry = entry
        self.level = level
        self.plan = plan
        self.difficulty = difficulty
        self.skipped = skipped
    }
}

/// The deterministic generator of the catalog.
public enum ApsidesWorkshopGenerator {
    /// The catalog id of the digest.
    public static let catalogID: String = "apsides-workshop"
    /// The most candidates tried per manifest entry.
    public static let maxCandidates: Int = 256
    /// The most tries to place one level's planets.
    public static let planetTries: Int = 60

    /// The level id of manifest number `number`: `apsides-workshop-NNN`.
    public static func levelID(_ number: Int) -> String {
        let digits: String = String(number)
        return "apsides-workshop-" + String(repeating: "0", count: max(0, 3 - digits.count)) + digits
    }

    /// A valid orbit drawn from `random` (redrawn until valid).
    static func orbit(_ random: inout SeededRandom) -> ApsidesWorkshopOrbit {
        while true {
            let orbit = ApsidesWorkshopOrbit(size: random.int(ApsidesWorkshopOrbit.sizes),
                                             eccentricity: random.int(ApsidesWorkshopOrbit.eccentricities),
                                             direction: random.int(ApsidesWorkshopOrbit.directions))
            if orbit.isValid { return orbit }
        }
    }

    /// The integer square root of a non-negative value (⌊√n⌋).
    static func squareRoot(_ n: Int) -> Int {
        guard n > 1 else { return max(n, 0) }
        var x: Int = Int(ApsidesWorkshopFixed.integerSquareRoot(UInt64(n)))
        while x * x > n { x -= 1 }
        return x
    }

    /// The candidate level `index` of `entry` (not yet certified), or nil when its draw is skipped by the rules above
    /// (planets, starting orbit, level rules). The winning orbit is returned with it.
    public static func draw(_ entry: ApsidesWorkshopManifestEntry,
                            index: Int) -> (level: ApsidesWorkshopLevel, winning: ApsidesWorkshopOrbit)? {
        let profile = ApsidesWorkshopBandProfile.of(band: entry.band)
        var random = SeededRandom(seed: SeedDerivation.derive(entry.seed, index: UInt64(index)))
        let period: Int = profile.periods[random.int(0...(profile.periods.count - 1))]
        let winning: ApsidesWorkshopOrbit = orbit(&random)
        let points: [ApsidesWorkshopPoint] = ApsidesWorkshopSky.positions(winning, period: period).points
        let shares: [Int] = ApsidesWorkshopSky.shares(points)
        let count: Int = random.int(profile.targets)
        let apsides: Int = min(random.int(profile.apsisTargets), count)
        var visited: [Int] = []
        for sector in 0..<ApsidesWorkshopSky.sectorCount where shares[sector] > 0 { visited.append(sector) }
        var sweepSectors: [Int] = []
        while sweepSectors.count < count - apsides && sweepSectors.count < visited.count {
            let sector: Int = visited[random.int(0...(visited.count - 1))]
            if !sweepSectors.contains(sector) { sweepSectors.append(sector) }
        }
        var targets: [ApsidesWorkshopTarget] = []
        for sector in sweepSectors {
            let half: Int = random.int(profile.sweepHalfWidth)
            targets.append(.sweep(sector: sector, low: max(0, shares[sector] - half),
                                  high: min(ApsidesWorkshopSky.wholeShare, shares[sector] + half)))
        }
        for i in 0..<apsides {
            let periapsis: Bool = apsides == 2 ? i == 0 : random.int(0...1) == 0
            let distance: Int = periapsis ? winning.periapsisDistance : winning.apoapsisDistance
            let half: Int = random.int(profile.apsisHalfWidth)
            targets.append(ApsidesWorkshopTarget(kind: periapsis ? .periapsis : .apoapsis,
                                                 sector: periapsis ? winning.periapsisSector : winning.apoapsisSector,
                                                 low: max(0, distance - half),
                                                 high: min(ApsidesWorkshopLevel.distanceBounds.upperBound,
                                                           distance + half)))
        }
        var ticks: [Int] = []
        for target in targets { ticks.append(ApsidesWorkshopSky.eventTick(target, points: points, period: period)) }
        let order: [Int] = targets.indices.sorted { (ticks[$0], $0) < (ticks[$1], $1) }
        targets = order.map { targets[$0] }
        var planets: [ApsidesWorkshopPlanet] = []
        let wanted: Int = random.int(profile.planets)
        var tries: Int = 0
        while planets.count < wanted && tries < planetTries {
            tries += 1
            let tick: Int = random.int(0...(period - 1))
            let radius: Int = random.int(1...3)
            let gap: Int = radius + random.int(1...4)
            let side: Int = random.int(0...1) == 0 ? -1 : 1
            let px: Int = points[tick].x
            let py: Int = points[tick].y
            let length: Int = max(1, squareRoot(px * px + py * py))
            let unit: Int = ApsidesWorkshopSky.unit
            let cx: Int = floorDivide(px + side * px * gap * unit / length + unit / 2, unit)
            let cy: Int = floorDivide(py + side * py * gap * unit / length + unit / 2, unit)
            let planet = ApsidesWorkshopPlanet(x: cx, y: cy, radius: radius)
            let reach: Int = radius + ApsidesWorkshopSky.starRadius
            guard ApsidesWorkshopLevel.coordinates.contains(cx), ApsidesWorkshopLevel.coordinates.contains(cy),
                  cx * cx + cy * cy > reach * reach else { continue }
            var struck: Bool = false
            for i in 0..<period where ApsidesWorkshopSky.touches(planet, from: points[i],
                                                                to: points[(i + 1) % period]) {
                struck = true
            }
            if !struck { planets.append(planet) }
        }
        guard planets.count == wanted else { return nil }
        let both: Bool = random.int(profile.levers) == 2
        let knobFirst: Bool = both ? true : random.int(0...1) == 0
        var start: ApsidesWorkshopOrbit = winning
        if both || knobFirst {
            start = ApsidesWorkshopOrbit(size: start.size,
                                         eccentricity: random.int(ApsidesWorkshopOrbit.eccentricities),
                                         direction: random.int(ApsidesWorkshopOrbit.directions))
        }
        if both || !knobFirst {
            start = ApsidesWorkshopOrbit(size: random.int(ApsidesWorkshopOrbit.sizes),
                                         eccentricity: start.eccentricity, direction: start.direction)
        }
        guard start.isValid, start != winning else { return nil }
        guard let level = try? ApsidesWorkshopLevel(
            id: levelID(entry.number), seed: entry.seed, difficulty: entry.band, period: period, planets: planets,
            targets: targets, orbit: start, budget: entry.budget, tutorial: entry.number <= 3) else { return nil }
        return (level, winning)
    }

    /// The candidate level `index` of `entry` (not yet certified), or nil when its draw is skipped.
    public static func candidate(_ entry: ApsidesWorkshopManifestEntry, index: Int) -> ApsidesWorkshopLevel? {
        draw(entry, index: index)?.level
    }

    /// ⌊a / b⌋ for b > 0.
    static func floorDivide(_ a: Int, _ b: Int) -> Int {
        a >= 0 ? a / b : -((-a + b - 1) / b)
    }

    /// The certified level of `entry`: the first candidate whose targets differ from `previous`'s and whose minimal
    /// plan lies in its band's range (and within the budget) within the solver's work bound.
    ///
    /// - Throws: `.generation(number)` when none of the first ``maxCandidates`` candidates qualifies.
    public static func generate(_ entry: ApsidesWorkshopManifestEntry, previous: ApsidesWorkshopLevel?)
        throws(ApsidesWorkshopError) -> ApsidesWorkshopGenerated {
        let range: ClosedRange<Int> = ApsidesWorkshopBandProfile.of(band: entry.band).planRange
        for index in 0..<maxCandidates {
            guard let level = candidate(entry, index: index) else { continue }
            if let previous, previous.targets == level.targets { continue }
            guard let plan = ApsidesWorkshopSolver.plan(level), range.contains(plan.size),
                  plan.size <= entry.budget else { continue }
            return ApsidesWorkshopGenerated(entry: entry, level: level, plan: plan,
                                            difficulty: ApsidesWorkshopDifficulty(level: level, plan: plan),
                                            skipped: index)
        }
        throw .generation(entry.number)
    }

    /// The 100 certified levels in manifest order, each generated after the one before it (the neighbour rule).
    ///
    /// - Throws: `.generation(number)` for the first entry that yields no level.
    public static func catalog() throws(ApsidesWorkshopError) -> [ApsidesWorkshopGenerated] {
        var result: [ApsidesWorkshopGenerated] = []
        for entry in ApsidesWorkshopManifest.entries {
            result.append(try generate(entry, previous: result.last?.level))
        }
        return result
    }

    /// The catalog digest of `levels` (their fingerprints, in order).
    public static func catalogDigest(_ levels: [ApsidesWorkshopLevel]) -> String {
        PuzzleCatalog<ApsidesWorkshopRules>.digest(id: catalogID, identities: levels.map(\.fingerprint))
    }
}
