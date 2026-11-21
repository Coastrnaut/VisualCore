// HueCompassDifficulty — feature 332 (R02-G04-02) T-R02G0402-002 (FR-R02G0402-003, 005; clarifications Q1, Q3). The
// difficulty metrics of a generated level, the band profiles the generator builds to, and the generated level with its
// proof. The smallest probe count comes from `HueCompassSolver`; harder bands use tolerances no looser and fog no denser
// than easier ones.
import VisualCoreSimulation

/// The difficulty of one level, from the level and the solver's actual result.
public struct HueCompassDifficulty: Sendable, Equatable, Hashable, Codable {
    /// The smallest number of probes after which one selection is accepted for every consistent target.
    public let smallest: Int
    /// The size of the largest class after the best single probe (fewer is easier).
    public let largestAfterBestSingle: Int
    /// The level's bearing tolerance.
    public let bearingTolerance: Int
    /// The level's band tolerance.
    public let bandTolerance: Int
    /// The band's clear-fog share in percent.
    public let clearShare: Int
    /// The solver's work: probe sets tried.
    public let work: Int

    /// A difficulty of the given values.
    public init(smallest: Int, largestAfterBestSingle: Int, bearingTolerance: Int, bandTolerance: Int, clearShare: Int,
                work: Int) {
        self.smallest = smallest
        self.largestAfterBestSingle = largestAfterBestSingle
        self.bearingTolerance = bearingTolerance
        self.bandTolerance = bandTolerance
        self.clearShare = clearShare
        self.work = work
    }

    /// The R02-F24 difficulty the progression rule reads: the smallest probe count, with the solver's work as explored.
    public var puzzleDifficulty: PuzzleDifficulty {
        PuzzleDifficulty(shortest: smallest, explored: work)
    }
}

/// What the generator builds for one band (clarification Q1).
public struct HueCompassBandProfile: Sendable, Equatable {
    /// The bearing tolerance of the band's levels.
    public let bearingTolerance: Int
    /// The band tolerance of the band's levels.
    public let bandTolerance: Int
    /// The share of clear (density 0) fog bearings, in percent.
    public let clearShare: Int
    /// The smallest probe counts a kept level may have.
    public let smallest: ClosedRange<Int>

    /// A profile of the given values.
    public init(bearingTolerance: Int, bandTolerance: Int, clearShare: Int, smallest: ClosedRange<Int>) {
        self.bearingTolerance = bearingTolerance
        self.bandTolerance = bandTolerance
        self.clearShare = clearShare
        self.smallest = smallest
    }

    /// The profile of `band` (1 … 5): tolerances (4, 2), (3, 1), (2, 1), (1, 0), (1, 0); clear share 0, 10, 20, 30, 40 %;
    /// smallest probes 1, 1, 1, 1 … 2, 2. A band outside 1 … 5 is clamped into it.
    public static func of(band: Int) -> HueCompassBandProfile {
        switch min(max(band, 1), 5) {
        case 1: HueCompassBandProfile(bearingTolerance: 4, bandTolerance: 2, clearShare: 0, smallest: 1...1)
        case 2: HueCompassBandProfile(bearingTolerance: 3, bandTolerance: 1, clearShare: 10, smallest: 1...1)
        case 3: HueCompassBandProfile(bearingTolerance: 2, bandTolerance: 1, clearShare: 20, smallest: 1...1)
        case 4: HueCompassBandProfile(bearingTolerance: 1, bandTolerance: 0, clearShare: 30, smallest: 1...2)
        default: HueCompassBandProfile(bearingTolerance: 1, bandTolerance: 0, clearShare: 40, smallest: 2...2)
        }
    }
}

/// A generated catalog level with its proof.
public struct HueCompassGenerated: Sendable, Equatable {
    /// The manifest entry it was built from.
    public let entry: HueCompassManifestEntry
    /// The level.
    public let level: HueCompassLevel
    /// The solver's result for the level.
    public let solution: HueCompassSolution
    /// The level's difficulty.
    public let difficulty: HueCompassDifficulty
    /// How many earlier candidates were skipped, 0 … 63.
    public let skipped: Int

    /// A generated level of the given values.
    public init(entry: HueCompassManifestEntry, level: HueCompassLevel, solution: HueCompassSolution,
                difficulty: HueCompassDifficulty, skipped: Int) {
        self.entry = entry
        self.level = level
        self.solution = solution
        self.difficulty = difficulty
        self.skipped = skipped
    }
}
