// AuroraLoomGenerator — feature 302 (R02-G01-02) T-R02G0102-004 (FR-R02G0102-001, 005; clarifications Q1, Q5; research
// R3–R5). Builds each catalog level from its manifest entry: candidate k draws from SeedDerivation.derive(seed, index: k)
// a shared winning (wave, phase), four distinct gate positions, per-gate target offsets of at most half the tolerance and
// a scramble of the six controls; the first candidate the solver proves within the band's shortest range and the move
// budget is the level. The catalog digest is R02-F24's over the level fingerprints in manifest order.
import VisualCoreSimulation

/// The parameters of one band: the harmony speed, the tolerance and the shortest solution sought.
public struct AuroraLoomBandProfile: Sendable, Equatable {
    /// The band, 1 … 5.
    public let band: Int
    /// The harmony speed Ω (every ribbon turns with it).
    public let omega: Int
    /// The tolerance in phase units.
    public let tolerance: Int
    /// The shortest solution lengths accepted.
    public let shortest: ClosedRange<Int>

    /// A profile of the given values (for tests of the generator's limits; the catalog uses ``of(band:)``).
    public init(band: Int, omega: Int, tolerance: Int, shortest: ClosedRange<Int>) {
        self.band = band
        self.omega = omega
        self.tolerance = tolerance
        self.shortest = shortest
    }

    /// The catalog profile of `band`: Ω 16, 32, 64, 128, 256; tolerance 160, 96, 64, 40, 24; shortest 1–2 … 5–6; nil
    /// outside 1 … 5.
    public static func of(band: Int) -> AuroraLoomBandProfile? {
        guard (1...5).contains(band) else { return nil }
        let omegas: [Int] = [16, 32, 64, 128, 256]
        let tolerances: [Int] = [160, 96, 64, 40, 24]
        return AuroraLoomBandProfile(band: band, omega: omegas[band - 1], tolerance: tolerances[band - 1],
                                     shortest: band...(band + 1))
    }
}

/// A generated level with its proof and metrics.
public struct AuroraLoomGenerated: Sendable, Equatable {
    /// The manifest entry it was built from.
    public let entry: AuroraLoomManifestEntry
    /// The level.
    public let level: AuroraLoomLevel
    /// The solver's proven shortest solution.
    public let solution: AuroraLoomSolution
    /// The difficulty taken from the solution.
    public let difficulty: AuroraLoomDifficulty
    /// The candidates skipped before this one, 0 … 63.
    public let skipped: Int

    /// A generated level of the given values.
    public init(entry: AuroraLoomManifestEntry, level: AuroraLoomLevel, solution: AuroraLoomSolution,
                difficulty: AuroraLoomDifficulty, skipped: Int) {
        self.entry = entry
        self.level = level
        self.solution = solution
        self.difficulty = difficulty
        self.skipped = skipped
    }
}

/// The seeded level generator of Aurora Loom.
public enum AuroraLoomGenerator {
    /// The most candidates tried per level.
    public static let maxCandidates = 64
    /// The catalog id used for the digest.
    public static let catalogID = "aurora-loom"
    /// The levels shown with a tutorial.
    public static let tutorialLevels: ClosedRange<Int> = 1...3

    /// The level of `entry`.
    ///
    /// - Throws: `.generation(entry.number)` when the band is outside 1 … 5 or no candidate is accepted within
    ///   ``maxCandidates``.
    public static func generate(_ entry: AuroraLoomManifestEntry) throws(AuroraLoomError) -> AuroraLoomGenerated {
        guard let profile = AuroraLoomBandProfile.of(band: entry.band) else { throw .generation(entry.number) }
        return try generate(entry, profile: profile)
    }

    /// The level of `entry` under `profile`.
    ///
    /// - Throws: `.generation(entry.number)` when no candidate is accepted within ``maxCandidates``.
    public static func generate(_ entry: AuroraLoomManifestEntry,
                                profile: AuroraLoomBandProfile) throws(AuroraLoomError) -> AuroraLoomGenerated {
        for k in 0..<maxCandidates {
            guard let level = candidate(entry, profile: profile, index: k),
                  let solution = AuroraLoomSolver.solve(level),
                  profile.shortest.contains(solution.shortest),
                  solution.shortest <= entry.budget else { continue }
            return AuroraLoomGenerated(entry: entry, level: level, solution: solution,
                                       difficulty: AuroraLoomDifficulty(level: level, solution: solution), skipped: k)
        }
        throw .generation(entry.number)
    }

    /// The 100 catalog levels in manifest order.
    ///
    /// - Throws: the first `.generation(number)`.
    public static func catalog() throws(AuroraLoomError) -> [AuroraLoomGenerated] {
        var result: [AuroraLoomGenerated] = []
        result.reserveCapacity(AuroraLoomManifest.entries.count)
        for entry in AuroraLoomManifest.entries {
            result.append(try generate(entry))
        }
        return result
    }

    /// The catalog digest: `PuzzleCatalog<AuroraLoomRules>.digest(id: "aurora-loom", identities:)` over the level
    /// fingerprints in order.
    public static func catalogDigest(_ levels: [AuroraLoomGenerated]) -> String {
        PuzzleCatalog<AuroraLoomRules>.digest(id: catalogID, identities: levels.map(\.level.fingerprint))
    }

    /// The level id of manifest number `number`: `aurora-loom-NNN`.
    public static func levelID(_ number: Int) -> String {
        let digits = String(number)
        return "aurora-loom-" + String(repeating: "0", count: max(0, 3 - digits.count)) + digits
    }

    /// Candidate `index` of `entry`, or nil when the drawn level is refused (for example a start that already wins).
    static func candidate(_ entry: AuroraLoomManifestEntry, profile: AuroraLoomBandProfile,
                          index: Int) -> AuroraLoomLevel? {
        var random = SeededRandom(seed: SeedDerivation.derive(entry.seed, index: UInt64(index)))
        let wave: Int = random.int(0...15)
        let phase: Int = random.int(0...15)
        var positions: [Int] = []
        while positions.count < 4 {
            let p: Int = random.int(1...15)
            if !positions.contains(p) { positions.append(p) }
        }
        let half: Int = profile.tolerance / 2
        var gates: [AuroraLoomGate] = []
        for position in positions {
            let offset: Int = random.int(-half...half)
            let target: Int = AuroraLoomHarmony.wrapPositive(wave * position * 16 + phase * 256 + offset)
            guard let gate = try? AuroraLoomGate(position: position, target: target) else { return nil }
            gates.append(gate)
        }
        var waves: [Int] = [wave, wave, wave]
        var phases: [Int] = [phase, phase, phase]
        // At most the six controls can change; a range beyond six yields no acceptable candidate (never a hang).
        let scramble: Int = min(random.int(profile.shortest), 6)
        var controls: [Int] = []
        while controls.count < scramble {
            let c: Int = random.int(0...5)
            if !controls.contains(c) { controls.append(c) }
        }
        for control in controls {
            let ribbon: Int = control / 2
            let current: Int = control % 2 == 0 ? waves[ribbon] : phases[ribbon]
            var value: Int = random.int(0...14)
            if value >= current { value += 1 }
            if control % 2 == 0 { waves[ribbon] = value } else { phases[ribbon] = value }
        }
        var ribbons: [AuroraLoomRibbon] = []
        for r in 0..<3 {
            guard let ribbon = try? AuroraLoomRibbon(wave: waves[r], phase: phases[r], omega: profile.omega) else {
                return nil
            }
            ribbons.append(ribbon)
        }
        return try? AuroraLoomLevel(id: levelID(entry.number), seed: entry.seed, band: entry.band, ribbons: ribbons,
                                    gates: gates, omega: profile.omega, tolerance: profile.tolerance,
                                    allowance: entry.budget, tutorial: tutorialLevels.contains(entry.number))
    }
}
