// BinaryGardensGenerator — feature 502 (R02-G21-02) T-R02G2102-003 (FR-R02G2102-001, 005, 007, 009; SC-R02G2102-001,
// 003, 004; clarification Q1; research R4, R5, R7, R12, R15). Builds each catalog level from its manifest entry:
// candidate c of entry n draws from `SeededRandom(seed: SeedDerivation.derive(plannedSeed, index: c))` in this order —
// the adjustable controls (the band's count of the seven controls; the emphasised control first when the emphasis names
// one, `adjust orbit` a ring, `phase twin stars` a phase, `set luminosity` a luminosity, on a star drawn 0 … 1; the
// rest by a partial shuffle); the star speed ω (1 … the band's maximum); the ring count and the distinct ring radii
// (sorted); the luminosity level count and the distinct levels in 4 … 32 (sorted); the phase step (the band's, no
// draw); T_max (the band's range when the tilt is adjustable, else 0, no draw); σ (the band's range); the clamp radius
// (2 … 4); the winning arrangement (each star's ring, a phase on the grid and a luminosity, then a tilt 0 … T_max;
// redrawn up to 16 times until the stars keep σ); the worlds (the band's count; each a radius from the largest ring
// radius + 3 to min(60, largest + 20), a phase 0 … 47 and a speed of magnitude 1 … 3 with a sign, index 1 negative);
// each world's comfort margin m and window slack s (the band's ranges; the lethal margin ℓ and the bloom margin b are
// the band's fixed values); the lethal tolerance E; the changed controls (the band's plan length p of the adjustable
// controls by a partial shuffle) and each one's starting value, drawn uniformly among its other legal values (all
// redrawn up to 16 times until the start keeps σ). Every range is drawn with `SeededRandom.int(_:)`, a single-value
// range included; a partial shuffle takes n of m items by n Fisher–Yates steps with `index(below:)`. Locked controls
// start at their winning values. Each world's bounds come from its winning run (flux F at ticks 1 … 48 sorted
// F₍₁₎ ≤ … ≤ F₍₄₈₎, integral I*): c_lo = ⌊F₍ₖ₎·(1000 − m)/1000⌋, c_hi = ⌈F₍₄₉₋ₖ₎·(1000 + m)/1000⌉,
// λ_lo = min(c_lo − 1, ⌊F₍₁₎·(1000 − ℓ)/1000⌋), λ_hi = max(c_hi + 1, ⌈F₍₄₈₎·(1000 + ℓ)/1000⌉), W = max(1, w* − s) for
// the winning run's longest cyclic comfortable window w*, B_lo = ⌊I*·(1000 − b)/1000⌋, B_hi = ⌈I*·(1000 + b)/1000⌉, so
// the winning run has no lethal tick and keeps every window and bloom band. A candidate is skipped when the winning
// arrangement or the start cannot keep σ within its redraws, a world's c_lo is 0, its λ_hi exceeds 200 000 (a guard that
// cannot fire under the kernel's 128 000-milliflux cap: λ_hi ≤ 166 400), the level rules refuse it (a start that
// already wins included), the winning arrangement with any one changed control put back to its starting value still
// wins ("reducible"), its ring radii and worlds equal the previous level's (FR-R02G2102-007), the solver's minimal plan
// (searched to depth p, work bounded) is not p actions, or the plan does not win through the play; at most 64
// candidates, then `generation(n)`. Ids `binary-gardens-NNN`, tutorial on levels 1 … 3, difficulty = band, budget =
// the manifest's, phase step 8 (bands 1 … 2) or 6 (bands 3 … 5). Band profiles as measured on the real 100 entries
// (research R4, 2026-11-27). Integers only; no clock. Modelled on `MushroomWeatherGenerator` (feature 492).
import VisualCoreSimulation

/// The band profile of the generator (clarification Q1, measured by research R4).
public struct BinaryGardensBandProfile: Sendable, Equatable {
    /// The number of adjustable controls.
    public let adjustable: Int
    /// The ring counts.
    public let rings: ClosedRange<Int>
    /// The ring radii, in distance units.
    public let ringRadii: ClosedRange<Int>
    /// The luminosity level counts (the levels are drawn in ``BinaryGardensGenerator/luminosityRange``).
    public let luminosities: ClosedRange<Int>
    /// The phase step g of the band's levels.
    public let phaseStep: Int
    /// The largest tilts T_max when the tilt is adjustable.
    public let maxTilt: ClosedRange<Int>
    /// The world counts.
    public let worlds: ClosedRange<Int>
    /// The minimum separations σ.
    public let separation: ClosedRange<Int>
    /// The largest star speed ω.
    public let maxStarSpeed: Int
    /// The trim k: the comfortable band is read from F₍ₖ₎ … F₍₄₉₋ₖ₎ of the winning run.
    public let trim: Int
    /// The comfort margins m, in ‰.
    public let comfortMargin: ClosedRange<Int>
    /// The lethal margin ℓ, in ‰.
    public let lethalMargin: Int
    /// The bloom margin b, in ‰.
    public let bloomMargin: Int
    /// The window slacks s, in ticks.
    public let windowSlack: ClosedRange<Int>
    /// The lethal tolerances E, in ticks.
    public let tolerance: ClosedRange<Int>
    /// The plan length p (arrangement actions of the minimal plan).
    public let plan: Int

    /// The profile of `band` 1 … 5 (a larger band uses band 5's).
    public static func of(band: Int) -> Self {
        switch band {
        case 1: Self(adjustable: 2, rings: 3...3, ringRadii: 2...12, luminosities: 2...2, phaseStep: 8,
                     maxTilt: 2...2, worlds: 1...1, separation: 0...0, maxStarSpeed: 1, trim: 1,
                     comfortMargin: 60...90, lethalMargin: 300, bloomMargin: 150, windowSlack: 4...8,
                     tolerance: 6...8, plan: 1)
        case 2: Self(adjustable: 3, rings: 3...4, ringRadii: 2...12, luminosities: 2...3, phaseStep: 8,
                     maxTilt: 2...3, worlds: 1...2, separation: 0...0, maxStarSpeed: 2, trim: 4,
                     comfortMargin: 40...70, lethalMargin: 250, bloomMargin: 100, windowSlack: 3...6,
                     tolerance: 4...6, plan: 2)
        case 3: Self(adjustable: 4, rings: 4...4, ringRadii: 2...16, luminosities: 3...3, phaseStep: 6,
                     maxTilt: 3...3, worlds: 2...2, separation: 2...4, maxStarSpeed: 2, trim: 6,
                     comfortMargin: 30...50, lethalMargin: 200, bloomMargin: 80, windowSlack: 2...4,
                     tolerance: 3...5, plan: 3)
        case 4: Self(adjustable: 5, rings: 4...5, ringRadii: 2...16, luminosities: 3...3, phaseStep: 6,
                     maxTilt: 3...3, worlds: 2...3, separation: 2...5, maxStarSpeed: 3, trim: 8,
                     comfortMargin: 20...40, lethalMargin: 150, bloomMargin: 60, windowSlack: 1...3,
                     tolerance: 2...4, plan: 3)
        default: Self(adjustable: 5, rings: 5...5, ringRadii: 2...16, luminosities: 3...4, phaseStep: 6,
                      maxTilt: 3...3, worlds: 3...3, separation: 3...6, maxStarSpeed: 3, trim: 10,
                      comfortMargin: 10...30, lethalMargin: 100, bloomMargin: 40, windowSlack: 0...2,
                      tolerance: 1...3, plan: 4)
        }
    }
}

/// A generated catalog level with its certificate.
public struct BinaryGardensGenerated: Sendable, Equatable {
    /// The manifest entry.
    public let entry: BinaryGardensManifestEntry
    /// The level.
    public let level: BinaryGardensLevel
    /// The certified plan.
    public let plan: BinaryGardensPlan
    /// The difficulty metrics.
    public let difficulty: BinaryGardensDifficulty
    /// The index of the accepted candidate (the candidates skipped before it).
    public let skipped: Int

    /// A generated level of the given values.
    public init(entry: BinaryGardensManifestEntry, level: BinaryGardensLevel, plan: BinaryGardensPlan,
                difficulty: BinaryGardensDifficulty, skipped: Int) {
        self.entry = entry
        self.level = level
        self.plan = plan
        self.difficulty = difficulty
        self.skipped = skipped
    }
}

/// The bounds of one world set from its winning run (research R12).
struct BinaryGardensWorldBounds: Sendable, Equatable {
    /// λ_lo.
    let lethalLow: Int
    /// c_lo.
    let comfortLow: Int
    /// c_hi.
    let comfortHigh: Int
    /// λ_hi.
    let lethalHigh: Int
    /// W.
    let window: Int
    /// B_lo.
    let bloomLow: Int
    /// B_hi.
    let bloomHigh: Int
}

/// A drawn candidate before the neighbour rule and the solver: the level, its winning arrangement and the changed
/// controls in drawing order.
struct BinaryGardensDraft: Sendable, Equatable {
    /// The level.
    let level: BinaryGardensLevel
    /// The winning arrangement.
    let winning: BinaryGardensArrangement
    /// The adjustable controls in drawing order.
    let adjustable: [BinaryGardensControl]
    /// The changed controls in drawing order (the band's plan length of them).
    let changed: [BinaryGardensControl]
}

/// The catalog generator.
public enum BinaryGardensGenerator {
    /// The catalog's id.
    public static let catalogID: String = "binary-gardens"
    /// The candidates tried per manifest entry.
    public static let maxCandidates: Int = 64
    /// The redraws of the winning arrangement and of the start until the stars keep the separation.
    public static let maxRedraws: Int = 16
    /// The luminosity levels' range, in luminosity units.
    static let luminosityRange: ClosedRange<Int> = 4...32
    /// The clamp radii, in distance units.
    static let clampRadii: ClosedRange<Int> = 2...4
    /// The magnitudes of a world's speed.
    static let worldSpeedMagnitudes: ClosedRange<Int> = 1...3
    /// The farthest a world orbits beyond the largest ring, in distance units.
    static let worldReach: Int = 20
    /// The nearest a world orbits beyond the largest ring, in distance units.
    static let worldGap: Int = 3

    /// "binary-gardens-007".
    public static func levelID(_ number: Int) -> String {
        let digits: String = String(number)
        return catalogID + "-" + String(repeating: "0", count: max(0, 3 - digits.count)) + digits
    }

    /// The control an emphasis names first (`adjust orbit` a ring, `phase twin stars` a phase, `set luminosity` a
    /// luminosity, as the offset within a star's three controls), nil for `watch world`, `commit light window` and any
    /// other text.
    static func emphasisOffset(_ emphasis: String) -> Int? {
        switch emphasis {
        case "adjust orbit": 0
        case "phase twin stars": 1
        case "set luminosity": 2
        default: nil
        }
    }

    /// `count` of `items` by `count` Fisher–Yates steps from the front: step i swaps item i with item
    /// i + `index(below: items.count − i)`; the first `count` items in that order.
    static func partialShuffle<T>(_ random: inout SeededRandom, _ items: [T], count: Int) -> [T] {
        var pool: [T] = items
        let taken: Int = min(max(0, count), pool.count)
        for i in 0..<taken { pool.swapAt(i, i + random.index(below: pool.count - i)) }
        return Array(pool[0..<taken])
    }

    /// `count` distinct values of `range`, each drawn with `int(range)` and redrawn while it repeats, sorted.
    static func distinctSorted(_ random: inout SeededRandom, count: Int, in range: ClosedRange<Int>) -> [Int] {
        var values: [Int] = []
        while values.count < count {
            let value: Int = random.int(range)
            if !values.contains(value) { values.append(value) }
        }
        return values.sorted()
    }

    /// Whether the stars of `arrangement` on `sky`'s rings and speed keep the separation `separation` at every tick
    /// 0 … 47 (the kernel's own minimum-separation reading).
    static func keeps(_ sky: BinaryGardensLevel, separation: Int, _ arrangement: BinaryGardensArrangement) -> Bool {
        BinaryGardensSky.minimumSeparation(sky, arrangement).squared
            >= separation * separation * BinaryGardensSky.squaredScale
    }

    /// The bounds of one world from its winning flux at ticks 1 … 48 (research R12), or nil when c_lo is 0 (the kernel
    /// needs 0 ≤ λ_lo < c_lo), λ_hi exceeds ``BinaryGardensLevel/maximumFlux`` or B_hi exceeds
    /// ``BinaryGardensLevel/maximumBloom`` (guards that the kernel's flux cap keeps from firing).
    static func bounds(flux: [Int], trim: Int, comfort: Int, lethal: Int, bloom: Int,
                       slack: Int) -> BinaryGardensWorldBounds? {
        guard flux.count == BinaryGardensSky.cycle, (1...24).contains(trim) else { return nil }
        let sorted: [Int] = flux.sorted()
        let cycle: Int = BinaryGardensSky.cycle
        let comfortLow: Int = sorted[trim - 1] * (1000 - comfort) / 1000
        let comfortHigh: Int = (sorted[cycle - trim] * (1000 + comfort) + 999) / 1000
        guard comfortLow >= 1 else { return nil }
        let lethalLow: Int = min(comfortLow - 1, sorted[0] * (1000 - lethal) / 1000)
        let lethalHigh: Int = max(comfortHigh + 1, (sorted[cycle - 1] * (1000 + lethal) + 999) / 1000)
        guard lethalHigh <= BinaryGardensLevel.maximumFlux else { return nil }
        var comfortable: [Bool] = []
        var integral: Int = 0
        for value in flux {
            comfortable.append(comfortLow <= value && value <= comfortHigh)
            integral += value
        }
        let longest: Int = BinaryGardensSky.longestCyclicRun(comfortable).length
        let bloomLow: Int = integral * (1000 - bloom) / 1000
        let bloomHigh: Int = (integral * (1000 + bloom) + 999) / 1000
        guard bloomHigh <= BinaryGardensLevel.maximumBloom else { return nil }
        return BinaryGardensWorldBounds(lethalLow: lethalLow, comfortLow: comfortLow, comfortHigh: comfortHigh,
                                        lethalHigh: lethalHigh, window: max(1, longest - slack),
                                        bloomLow: bloomLow, bloomHigh: bloomHigh)
    }

    /// The draft of candidate `index` of `entry`, or nil when the winning arrangement or the start cannot keep the
    /// separation within ``maxRedraws``, a world's bounds are refused
    /// (``bounds(flux:trim:comfort:lethal:bloom:slack:)``), the level rules refuse the level or the winning arrangement
    /// is reducible.
    static func draft(_ entry: BinaryGardensManifestEntry, index: Int) -> BinaryGardensDraft? {
        let profile: BinaryGardensBandProfile = .of(band: entry.band)
        var random = SeededRandom(seed: SeedDerivation.derive(entry.seed, index: UInt64(index)))
        // The adjustable controls: the emphasised one first, the rest by a partial shuffle.
        var adjustable: [BinaryGardensControl] = []
        var pool: [BinaryGardensControl] = BinaryGardensControl.allCases
        if let offset = emphasisOffset(entry.emphasis) {
            let star: Int = random.int(0...1)
            if let control = BinaryGardensControl(rawValue: star * 3 + offset) {
                adjustable.append(control)
                pool.removeAll { $0 == control }
            }
        }
        adjustable += partialShuffle(&random, pool, count: profile.adjustable - adjustable.count)
        let starSpeed: Int = random.int(1...profile.maxStarSpeed)
        let ringRadii: [Int] = distinctSorted(&random, count: random.int(profile.rings), in: profile.ringRadii)
        let luminosityLevels: [Int] = distinctSorted(&random, count: random.int(profile.luminosities),
                                                     in: luminosityRange)
        let phaseStep: Int = profile.phaseStep
        let maxTilt: Int = adjustable.contains(.tilt) ? random.int(profile.maxTilt) : 0
        let separation: Int = random.int(profile.separation)
        let clampRadius: Int = random.int(clampRadii)
        // A probe of the sky (rings, speed, luminosities, tilts, grid) for the legal values and the separation.
        let placeholder = BinaryGardensWorld(radius: BinaryGardensLevel.worldRadii.upperBound, phase: 0, speed: 0,
                                             lethalLow: 0, comfortLow: 1, comfortHigh: 1, lethalHigh: 2, window: 1,
                                             bloomLow: 0, bloomHigh: 0)
        let plain = BinaryGardensStar(ring: 0, phase: 0, luminosity: 0, ringAdjustable: true, phaseAdjustable: false,
                                      luminosityAdjustable: false)
        guard let sky = try? BinaryGardensLevel.probe(
            ringRadii: ringRadii, starSpeed: starSpeed, luminosityLevels: luminosityLevels, stars: [plain, plain],
            maxTilt: maxTilt, startTilt: 0, minimumSeparation: 0, clampRadius: clampRadius, worlds: [placeholder],
            lethalTolerance: 0, phaseStep: phaseStep) else { return nil }
        let phaseSlots: Int = BinaryGardensSky.cycle / phaseStep
        var winning: BinaryGardensArrangement?
        for _ in 0..<maxRedraws {
            var rings: [Int] = []
            var phases: [Int] = []
            var luminosities: [Int] = []
            for _ in 0..<2 {
                rings.append(random.int(0...(ringRadii.count - 1)))
                phases.append(phaseStep * random.int(0...(phaseSlots - 1)))
                luminosities.append(random.int(0...(luminosityLevels.count - 1)))
            }
            let drawn = BinaryGardensArrangement(rings: rings, phases: phases, luminosities: luminosities,
                                                 tilt: random.int(0...maxTilt))
            if keeps(sky, separation: separation, drawn) {
                winning = drawn
                break
            }
        }
        guard let winning else { return nil }
        // The worlds' orbits, then each world's margins, then the tolerance.
        let largest: Int = ringRadii[ringRadii.count - 1]
        let worldRadii: ClosedRange<Int> = (largest + worldGap)...min(BinaryGardensLevel.worldRadii.upperBound,
                                                                      largest + worldReach)
        var orbits: [(radius: Int, phase: Int, speed: Int)] = []
        for _ in 0..<random.int(profile.worlds) {
            let radius: Int = random.int(worldRadii)
            let phase: Int = random.int(BinaryGardensLevel.phases)
            let magnitude: Int = random.int(worldSpeedMagnitudes)
            let speed: Int = random.index(below: 2) == 1 ? -magnitude : magnitude
            orbits.append((radius, phase, speed))
        }
        var margins: [(comfort: Int, slack: Int)] = []
        for _ in orbits { margins.append((random.int(profile.comfortMargin), random.int(profile.windowSlack))) }
        let tolerance: Int = random.int(profile.tolerance)
        // The changed controls and their starting values.
        let changed: [BinaryGardensControl] = partialShuffle(&random, adjustable, count: profile.plan)
        var start: BinaryGardensArrangement?
        for _ in 0..<maxRedraws {
            var drawn: BinaryGardensArrangement = winning
            for control in changed {
                var others: [Int] = []
                for value in control.values(in: sky) where value != control.value(of: winning) { others.append(value) }
                guard !others.isEmpty else { return nil }
                drawn = control.setting(others[random.int(0...(others.count - 1))], in: drawn)
            }
            if keeps(sky, separation: separation, drawn) {
                start = drawn
                break
            }
        }
        guard let start else { return nil }
        // Each world's bounds from the winning run.
        var wide: [BinaryGardensWorld] = []
        for orbit in orbits {
            wide.append(BinaryGardensWorld(radius: orbit.radius, phase: orbit.phase, speed: orbit.speed, lethalLow: 0,
                                           comfortLow: 1, comfortHigh: BinaryGardensLevel.maximumFlux - 1,
                                           lethalHigh: BinaryGardensLevel.maximumFlux, window: 1, bloomLow: 0,
                                           bloomHigh: BinaryGardensLevel.maximumBloom))
        }
        var winningStars: [BinaryGardensStar] = []
        for star in 0..<2 {
            winningStars.append(BinaryGardensStar(ring: winning.rings[star], phase: winning.phases[star],
                                                  luminosity: winning.luminosities[star], ringAdjustable: true,
                                                  phaseAdjustable: false, luminosityAdjustable: false))
        }
        guard let run = try? BinaryGardensLevel.probe(
            ringRadii: ringRadii, starSpeed: starSpeed, luminosityLevels: luminosityLevels, stars: winningStars,
            maxTilt: maxTilt, startTilt: winning.tilt, minimumSeparation: separation, clampRadius: clampRadius,
            worlds: wide, lethalTolerance: tolerance, phaseStep: phaseStep) else { return nil }
        let report: BinaryGardensReport = run.startReport
        var worlds: [BinaryGardensWorld] = []
        for (world, orbit) in orbits.enumerated() {
            guard let b = bounds(flux: report.worlds[world].flux, trim: profile.trim, comfort: margins[world].comfort,
                                 lethal: profile.lethalMargin, bloom: profile.bloomMargin,
                                 slack: margins[world].slack) else { return nil }
            worlds.append(BinaryGardensWorld(radius: orbit.radius, phase: orbit.phase, speed: orbit.speed,
                                             lethalLow: b.lethalLow, comfortLow: b.comfortLow,
                                             comfortHigh: b.comfortHigh, lethalHigh: b.lethalHigh, window: b.window,
                                             bloomLow: b.bloomLow, bloomHigh: b.bloomHigh))
        }
        var stars: [BinaryGardensStar] = []
        for star in 0..<2 {
            let base: Int = star * 3
            stars.append(BinaryGardensStar(
                ring: start.rings[star], phase: start.phases[star], luminosity: start.luminosities[star],
                ringAdjustable: adjustable.contains { $0.rawValue == base },
                phaseAdjustable: adjustable.contains { $0.rawValue == base + 1 },
                luminosityAdjustable: adjustable.contains { $0.rawValue == base + 2 }))
        }
        guard let level = try? BinaryGardensLevel(
            id: levelID(entry.number), seed: entry.seed, difficulty: entry.band, ringRadii: ringRadii,
            starSpeed: starSpeed, luminosityLevels: luminosityLevels, stars: stars, maxTilt: maxTilt,
            startTilt: start.tilt, minimumSeparation: separation, clampRadius: clampRadius, worlds: worlds,
            lethalTolerance: tolerance, budget: entry.budget, tutorial: entry.number <= 3,
            phaseStep: phaseStep) else { return nil }
        guard !isReducible(level, winning: winning, changed: changed) else { return nil }
        return BinaryGardensDraft(level: level, winning: winning, adjustable: adjustable, changed: changed)
    }

    /// Candidate `index` of `entry`, or nil when the winning arrangement or the start cannot keep the separation within
    /// ``maxRedraws``, a world's c_lo is 0 or its λ_hi exceeds 200 000, the level rules refuse it (a start that already
    /// wins included) or it is reducible (the neighbour rule and the solver are applied by ``generate(_:previous:)``).
    public static func candidate(_ entry: BinaryGardensManifestEntry, index: Int) -> BinaryGardensLevel? {
        draft(entry, index: index)?.level
    }

    /// Whether `winning` still wins `level` with any one of the `changed` controls put back to its starting value.
    static func isReducible(_ level: BinaryGardensLevel, winning: BinaryGardensArrangement,
                            changed: [BinaryGardensControl]) -> Bool {
        for control in changed {
            let reduced: BinaryGardensArrangement = control.setting(control.value(of: level.start), in: winning)
            if BinaryGardensSky.report(level, arrangement: reduced).wins { return true }
        }
        return false
    }

    /// The certified level of `entry`: the first candidate whose ring radii and worlds are not both equal to
    /// `previous`'s and whose minimal plan has the band's plan length and wins through the play.
    ///
    /// - Throws: `.generation(number)` when no candidate within ``maxCandidates`` qualifies.
    public static func generate(_ entry: BinaryGardensManifestEntry,
                                previous: BinaryGardensLevel?) throws(BinaryGardensError) -> BinaryGardensGenerated {
        let profile: BinaryGardensBandProfile = .of(band: entry.band)
        for index in 0..<maxCandidates {
            guard let level = candidate(entry, index: index) else { continue }
            if let previous, previous.ringRadii == level.ringRadii, previous.worlds == level.worlds { continue }
            guard let plan = BinaryGardensSolver.plan(level, maxDepth: profile.plan), plan.size == profile.plan else {
                continue
            }
            guard BinaryGardensSolver.replayWins(level, actions: plan.actions) else { continue }
            return BinaryGardensGenerated(entry: entry, level: level, plan: plan,
                                          difficulty: BinaryGardensDifficulty(level: level, plan: plan),
                                          skipped: index)
        }
        throw .generation(entry.number)
    }

    /// The 100 certified levels in manifest order (each generated after the one before it, the neighbour rule's input).
    public static func catalog() throws(BinaryGardensError) -> [BinaryGardensGenerated] {
        var result: [BinaryGardensGenerated] = []
        var previous: BinaryGardensLevel?
        for entry in BinaryGardensManifest.entries {
            let generated: BinaryGardensGenerated = try generate(entry, previous: previous)
            result.append(generated)
            previous = generated.level
        }
        return result
    }

    /// The catalog digest over the level fingerprints in manifest order (R02-F24).
    public static func catalogDigest(_ levels: [BinaryGardensLevel]) -> String {
        PuzzleCatalog<BinaryGardensPuzzle>.digest(id: catalogID, identities: levels.map(\.fingerprint))
    }
}
