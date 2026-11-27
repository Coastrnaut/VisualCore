// MushroomWeatherDifficulty — feature 492 (R02-G20-02) T-R02G2002-002 (FR-R02G2002-003; clarifications Q2, Q3). The
// certified plan of a level (the fewest arrangement actions, the arrangements judged at each smaller depth, the nearest
// miss and the work) and the difficulty metrics derived from the level and its plan: witness length, colonies,
// narrowest band, pod sites, vents, arrangements searched, work and nearest miss, with R02-F24's shared difficulty
// record. Integers only. Modelled on `MicroscopicAuroraDifficulty` (feature 482).
import VisualCoreSimulation

/// A certified plan: the fewest arrangement actions after which the run wins.
public struct MushroomWeatherPlan: Sendable, Equatable, Codable {
    /// The placements in slot order, then the vent toggles, then the moonlight change (the `run` is not included).
    public let actions: [MushroomWeatherAction]
    /// The winning arrangement.
    public let arrangement: MushroomWeatherArrangement
    /// The arrangements judged at each depth below the plan's size (depth 0 is the start: 1), none winning.
    public let arrangementsByDepth: [Int]
    /// The smallest band loss among the arrangements judged at smaller depths.
    public let nearestMiss: Int
    /// The arrangements judged in all.
    public let work: Int

    /// A plan of the given values.
    public init(actions: [MushroomWeatherAction], arrangement: MushroomWeatherArrangement, arrangementsByDepth: [Int],
                nearestMiss: Int, work: Int) {
        self.actions = actions
        self.arrangement = arrangement
        self.arrangementsByDepth = arrangementsByDepth
        self.nearestMiss = nearestMiss
        self.work = work
    }

    /// The number of arrangement actions (the witness length without the `run`).
    public var size: Int { actions.count }
}

/// The difficulty metrics of a certified level, from the level and its plan.
public struct MushroomWeatherDifficulty: Sendable, Hashable, Codable {
    /// The witness length (arrangement actions).
    public let actions: Int
    /// The number of colonies.
    public let colonies: Int
    /// The narrowest colony band (high − low).
    public let narrowestBand: Int
    /// The number of pod sites (0 for a level without sites).
    public let sites: Int
    /// The number of vents.
    public let vents: Int
    /// The arrangements judged at depths below the plan.
    public let arrangementsSearched: Int
    /// The arrangements judged in all.
    public let work: Int
    /// The smallest band loss among the arrangements judged at smaller depths.
    public let nearestMiss: Int

    /// The metrics of `level` certified by `plan`.
    public init(level: MushroomWeatherLevel, plan: MushroomWeatherPlan) {
        actions = plan.size
        colonies = level.colonies.count
        var narrowest: Int = Int.max
        for colony in level.colonies { narrowest = min(narrowest, colony.high - colony.low) }
        narrowestBand = narrowest
        sites = level.sites?.count ?? 0
        vents = level.vents.count
        arrangementsSearched = plan.arrangementsByDepth.reduce(0, +)
        work = plan.work
        nearestMiss = plan.nearestMiss
    }

    /// The shared difficulty record (R02-F24): the witness length as the shortest solution, the arrangements judged as
    /// the states explored.
    public var puzzleDifficulty: PuzzleDifficulty { PuzzleDifficulty(shortest: actions, explored: work) }
}
