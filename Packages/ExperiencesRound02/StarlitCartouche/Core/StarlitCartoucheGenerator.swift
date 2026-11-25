// StarlitCartoucheGenerator — feature 452 (R02-G16-02) T-R02G1602-004 (FR-R02G1602-001, 005; SC-R02G1602-001, 003,
// 004; clarification Q1). The constructive level generator of Starlit Cartouche. Candidate c of a manifest entry draws
// from `SeededRandom(seed: SeedDerivation.derive(plannedSeed, index: c))`, in this order: the star count (band + 4 …
// band + 5); for each star a glyph point (redrawn until distinct) and an orbit of 1 … 3 positions with coordinates
// −5 … 5; the range (6 … 8); the start star; a route of band + 1 … band + 2 legs, each choosing up to 8 times a next
// star other than the current one and the first flyable wait counted from a drawn offset 0 … 3 (waits 0 … 8, modulo
// 9), adding the corridor (travel 1 … 3) when new; band + 1 drawn decoy corridors (new pairs only, at most 24
// corridors); hazards (band + 2 for `avoid hazard`, else 0 … band; each on a drawn corridor with a drawn interval from
// 0 … last arrival + 2 of length 0 … 3, dropped when it would meet a leg of the route on that corridor; at most 8); the
// deadline (the last arrival plus 0 … max(0, 5 − band), at most 64); and the windows (every visited star for `time
// launch`, else each star with a 1 in 3 draw: open = earliest arrival − 0 … 2 (0 for the start), close = latest arrival
// or departure + 0 … 2; the others [0, 64]). Symbol = the corridors the route flew; beacon = its last star; budget =
// the manifest's; ids `starlit-cartouche-NNN`; tutorial on levels 1 … 3; difficulty = band. `generate` keeps the first
// candidate whose minimal plan lies in its band's range within the solver's work bound; at most 256 candidates, then
// `generation(n)`. The ranges were measured by a prototype of this generator on the real kernel before they were
// written down. Modelled on `VoxelOrigamiGenerator` (feature 442).
import VisualCoreSimulation

/// The values of one band (clarification Q1).
public struct StarlitCartoucheBandProfile: Sendable, Equatable {
    /// The star counts.
    public let stars: ClosedRange<Int>
    /// The route lengths (legs).
    public let route: ClosedRange<Int>
    /// The decoy corridors drawn.
    public let decoys: Int
    /// The accepted minimal plan sizes (legs).
    public let planRange: ClosedRange<Int>

    /// The profile of `band` (1 … 5; others clamp): stars b + 4 … b + 5, route b + 1 … b + 2, decoys b + 1, plans
    /// b + 1 … b + 2.
    public static func of(band: Int) -> StarlitCartoucheBandProfile {
        let b: Int = min(max(band, 1), 5)
        return StarlitCartoucheBandProfile(stars: (b + 4)...(b + 5), route: (b + 1)...(b + 2), decoys: b + 1,
                                           planRange: (b + 1)...(b + 2))
    }
}

/// A certified catalog level with its plan, difficulty and the candidates skipped before it.
public struct StarlitCartoucheGenerated: Sendable, Equatable {
    /// The manifest entry.
    public let entry: StarlitCartoucheManifestEntry
    /// The level.
    public let level: StarlitCartoucheLevel
    /// The minimal plan.
    public let plan: StarlitCartouchePlan
    /// The difficulty metrics.
    public let difficulty: StarlitCartoucheDifficulty
    /// The index of the accepted candidate (the candidates skipped before it).
    public let skipped: Int

    /// A generated level of the given values.
    public init(entry: StarlitCartoucheManifestEntry, level: StarlitCartoucheLevel, plan: StarlitCartouchePlan,
                difficulty: StarlitCartoucheDifficulty, skipped: Int) {
        self.entry = entry
        self.level = level
        self.plan = plan
        self.difficulty = difficulty
        self.skipped = skipped
    }
}

/// The constructive generator of Starlit Cartouche (see the file header).
public enum StarlitCartoucheGenerator {
    /// The catalog id of the digest.
    public static let catalogID: String = "starlit-cartouche"
    /// The most candidates tried per entry.
    public static let maxCandidates: Int = 256
    /// The most draws per route leg.
    public static let drawsPerLeg: Int = 8

    /// `starlit-cartouche-NNN`.
    public static func levelID(_ number: Int) -> String {
        let digits: String = String(number)
        return "starlit-cartouche-" + String(repeating: "0", count: max(0, 3 - digits.count)) + digits
    }

    /// One flown leg of the constructed route.
    private struct RouteLeg {
        let corridor: Int
        let depart: Int
        let arrive: Int
    }

    /// Candidate `index` of `entry`, or nil when its draws do not give a valid level (no flyable next star within the
    /// draw bound, or values the level rules refuse).
    public static func candidate(_ entry: StarlitCartoucheManifestEntry, index: Int) -> StarlitCartoucheLevel? {
        var random = SeededRandom(seed: SeedDerivation.derive(entry.seed, index: UInt64(index)))
        let profile: StarlitCartoucheBandProfile = .of(band: entry.band)
        let band: Int = min(max(entry.band, 1), 5)
        let count: Int = random.int(profile.stars)
        var glyphs: [StarlitCartoucheGlyphPoint] = []
        var orbits: [[StarlitCartoucheVector]] = []
        while glyphs.count < count {
            let glyph = StarlitCartoucheGlyphPoint(random.int(0...4), random.int(0...4))
            if glyphs.contains(glyph) { continue }
            glyphs.append(glyph)
            var orbit: [StarlitCartoucheVector] = []
            let length: Int = random.int(1...3)
            for _ in 0..<length {
                orbit.append(StarlitCartoucheVector(random.int(-5...5), random.int(-5...5), random.int(-5...5)))
            }
            orbits.append(orbit)
        }
        let range: Int = random.int(6...8)
        var probes: [StarlitCartoucheStar] = []
        for i in 0..<count {
            probes.append(StarlitCartoucheStar(orbit: orbits[i], glyph: glyphs[i], open: 0, close: 64))
        }
        let start: Int = random.int(0...(count - 1))
        var corridors: [StarlitCartoucheCorridor] = []
        var symbol: Set<Int> = []
        var star: Int = start
        var beat: Int = 0
        var arrivals: [Int: [Int]] = [start: [0]]
        var departures: [Int: [Int]] = [:]
        var route: [RouteLeg] = []
        let legs: Int = random.int(profile.route)
        for _ in 0..<legs {
            var flown: Bool = false
            for _ in 0..<drawsPerLeg {
                let next: Int = random.int(0...(count - 1))
                if next == star { continue }
                let offset: Int = random.int(0...3)
                var wait: Int = -1
                for w0 in StarlitCartoucheChart.waits {
                    let w: Int = (w0 + offset) % 9
                    let d: Int = probes[star].position(at: beat + w)
                        .squaredDistance(to: probes[next].position(at: beat + w))
                    if d <= range * range {
                        wait = w
                        break
                    }
                }
                if wait < 0 { continue }
                var corridorIndex: Int? = nil
                for i in corridors.indices where corridors[i].joins(star, next) { corridorIndex = i }
                if corridorIndex == nil {
                    corridors.append(StarlitCartoucheCorridor(star, next, travel: random.int(1...3)))
                    corridorIndex = corridors.count - 1
                }
                let used: Int = corridorIndex ?? 0
                let depart: Int = beat + wait
                let arrive: Int = depart + corridors[used].travel
                symbol.insert(used)
                departures[star, default: []].append(depart)
                arrivals[next, default: []].append(arrive)
                route.append(RouteLeg(corridor: used, depart: depart, arrive: arrive))
                star = next
                beat = arrive
                flown = true
                break
            }
            if !flown { return nil }
        }
        for _ in 0..<profile.decoys {
            let a: Int = random.int(0...(count - 1))
            let b: Int = random.int(0...(count - 1))
            if a == b || corridors.count >= StarlitCartoucheLevel.maxCorridors { continue }
            if corridors.contains(where: { $0.joins(a, b) }) { continue }
            corridors.append(StarlitCartoucheCorridor(a, b, travel: random.int(1...3)))
        }
        var hazards: [StarlitCartoucheHazard] = []
        let hazardCount: Int = entry.emphasis == "avoid hazard" ? band + 2 : random.int(0...band)
        for _ in 0..<hazardCount where hazards.count < StarlitCartoucheLevel.maxHazards {
            let corridor: Int = random.int(0...(corridors.count - 1))
            let from: Int = random.int(0...(beat + 2))
            let to: Int = from + random.int(0...3)
            if route.contains(where: { $0.corridor == corridor && from <= $0.arrive && $0.depart <= to }) { continue }
            hazards.append(StarlitCartoucheHazard(corridor: corridor, from: from, to: to))
        }
        let deadline: Int = min(beat + random.int(0...max(0, 5 - band)), StarlitCartoucheLevel.deadlines.upperBound)
        var stars: [StarlitCartoucheStar] = []
        for i in 0..<count {
            var open: Int = 0
            var close: Int = StarlitCartoucheLevel.deadlines.upperBound
            if entry.emphasis == "time launch" || random.int(0...2) == 0, let visits = arrivals[i] {
                let earliest: Int = visits.min() ?? 0
                let latest: Int = max(visits.max() ?? 0, departures[i]?.max() ?? 0)
                open = max(0, earliest - random.int(0...2))
                close = min(StarlitCartoucheLevel.deadlines.upperBound, latest + random.int(0...2))
                if i == start { open = 0 }
            }
            stars.append(StarlitCartoucheStar(orbit: orbits[i], glyph: glyphs[i], open: open, close: close))
        }
        return try? StarlitCartoucheLevel(id: levelID(entry.number), seed: entry.seed, difficulty: band, stars: stars,
                                          range: range, corridors: corridors, hazards: hazards, start: start,
                                          beacon: star, deadline: deadline, symbol: symbol.sorted(),
                                          budget: entry.budget, tutorial: entry.number <= 3)
    }

    /// The certified level of `entry`: the first candidate whose minimal plan lies in its band's range (and within the
    /// budget) within the solver's work bound.
    ///
    /// - Throws: `.generation(number)` when none of the first ``maxCandidates`` candidates qualifies.
    public static func generate(_ entry: StarlitCartoucheManifestEntry)
        throws(StarlitCartoucheError) -> StarlitCartoucheGenerated {
        let range: ClosedRange<Int> = StarlitCartoucheBandProfile.of(band: entry.band).planRange
        for index in 0..<maxCandidates {
            guard let level = candidate(entry, index: index) else { continue }
            guard let plan = StarlitCartoucheSolver.plan(level, maxLegs: range.upperBound),
                  range.contains(plan.size), plan.size <= entry.budget else { continue }
            return StarlitCartoucheGenerated(entry: entry, level: level, plan: plan,
                                             difficulty: StarlitCartoucheDifficulty(level: level, plan: plan),
                                             skipped: index)
        }
        throw .generation(entry.number)
    }

    /// The catalog digest of `levels` (their fingerprints, in order).
    public static func catalogDigest(_ levels: [StarlitCartoucheLevel]) -> String {
        PuzzleCatalog<StarlitCartoucheRules>.digest(id: catalogID, identities: levels.map(\.fingerprint))
    }
}
