// HueCompassGenerator — feature 332 (R02-G04-02) T-R02G0402-004 (FR-R02G0402-001, 003, 005; clarifications Q1, Q3, Q5).
// Builds each of the 100 catalog levels from its manifest entry. Candidate k of entry n draws from
// `SeededRandom(seed: SeedDerivation.derive(plannedSeed, index: k))`, in this order: the offset (0 … 23); the 96 fog
// densities, each clear (0) when a draw 0 … 99 is below the band's clear share, otherwise 1 … 9; the target (0 … 95);
// the start, redrawn until it is farther from the target than the bearing tolerance. Tolerances come from the band
// profile; the allowance is the manifest budget; ids `hue-compass-NNN`; levels 1 … 3 have the tutorial. A candidate is
// kept when `HueCompassSolver` settles it within depth 2 with a smallest probe count in the band's range and an
// ambiguity counterexample; otherwise k grows, at most 64 candidates, then `generation(n)`.
import VisualCoreSimulation

/// The seeded level generator of Hue Compass.
public enum HueCompassGenerator {
    /// The catalog id the digest is taken under.
    public static let catalogID: String = "hue-compass"
    /// The manifest numbers whose levels show the tutorial.
    public static let tutorialLevels: ClosedRange<Int> = 1...3
    /// The largest number of candidates tried per level.
    public static let maximumCandidates: Int = 64

    /// The level id of manifest number `number`: `hue-compass-NNN`.
    public static func levelID(_ number: Int) -> String {
        let digits: String = String(number)
        return "hue-compass-" + String(repeating: "0", count: max(0, 3 - digits.count)) + digits
    }

    /// Candidate `index` of `entry`, drawn as the file header states.
    public static func candidate(_ entry: HueCompassManifestEntry, index: Int) -> HueCompassLevel {
        candidate(entry, index: index, profile: HueCompassBandProfile.of(band: entry.band))
    }

    /// Candidate `index` of `entry` under `profile` (the generator's own profile, or a test's).
    static func candidate(_ entry: HueCompassManifestEntry, index: Int,
                          profile: HueCompassBandProfile) -> HueCompassLevel {
        var random = SeededRandom(seed: SeedDerivation.derive(entry.seed, index: UInt64(index)))
        let offset: Int = random.int(0...(HueCompassWheel.bands - 1))
        var fog: [Int] = []
        fog.reserveCapacity(HueCompassWheel.bearings)
        for _ in 0..<HueCompassWheel.bearings {
            fog.append(random.int(0...99) < profile.clearShare ? 0 : random.int(1...9))
        }
        let target: Int = random.int(0...(HueCompassWheel.bearings - 1))
        var start: Int = random.int(0...(HueCompassWheel.bearings - 1))
        while HueCompassWheel.bearingDistance(start, target) <= profile.bearingTolerance {
            start = random.int(0...(HueCompassWheel.bearings - 1))
        }
        do {
            return try HueCompassLevel(id: levelID(entry.number), seed: entry.seed, band: entry.band, offset: offset,
                                       fog: fog, target: target, start: start,
                                       bearingTolerance: profile.bearingTolerance,
                                       bandTolerance: profile.bandTolerance, allowance: entry.budget,
                                       tutorial: tutorialLevels.contains(entry.number))
        } catch {
            preconditionFailure("a candidate of manifest entry \(entry.number) is valid by construction: \(error)")
        }
    }

    /// The level of `entry`: the first candidate the solver proves within the band's range, with its proof.
    ///
    /// - Throws: `.generation(entry.number)` when none of the 64 candidates qualifies.
    public static func generate(_ entry: HueCompassManifestEntry) throws(HueCompassError) -> HueCompassGenerated {
        try generate(entry, profile: HueCompassBandProfile.of(band: entry.band))
    }

    /// The level of `entry` under `profile`.
    static func generate(_ entry: HueCompassManifestEntry,
                         profile: HueCompassBandProfile) throws(HueCompassError) -> HueCompassGenerated {
        for index in 0..<maximumCandidates {
            let level: HueCompassLevel = candidate(entry, index: index, profile: profile)
            guard let solution = HueCompassSolver.solve(level), profile.smallest.contains(solution.smallest),
                  solution.ambiguity != nil, solution.smallest + 1 <= level.allowance else { continue }
            let difficulty = HueCompassDifficulty(smallest: solution.smallest,
                                                  largestAfterBestSingle: solution.largestAfterBestSingle,
                                                  bearingTolerance: level.bearingTolerance,
                                                  bandTolerance: level.bandTolerance, clearShare: profile.clearShare,
                                                  work: solution.work)
            return HueCompassGenerated(entry: entry, level: level, solution: solution, difficulty: difficulty,
                                       skipped: index)
        }
        throw .generation(entry.number)
    }

    /// The catalog digest: R02-F24's digest over the level fingerprints in manifest order.
    public static func catalogDigest(_ levels: [HueCompassLevel]) -> String {
        PuzzleCatalog<HueCompassRules>.digest(id: catalogID, identities: levels.map(\.fingerprint))
    }
}
