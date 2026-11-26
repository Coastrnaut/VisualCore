// MicroscopicAuroraDifficulty — feature 482 (R02-G19-02) T-R02G1902-002 (FR-R02G1902-003; clarifications Q2, Q3). The
// certified plan of a level (the fewest placements, the sets judged at each smaller depth, the nearest miss and the work)
// and the difficulty metrics derived from the level and its plan: witness length, stencil, coverage, swarm, sites, sets
// searched, work and nearest miss, with R02-F24's shared difficulty record.
import VisualCoreSimulation

/// A certified plan: the fewest placements after which the play wins.
public struct MicroscopicAuroraPlan: Sendable, Equatable, Codable {
    /// The placements in slot order (the `play` is not included).
    public let actions: [MicroscopicAuroraAction]
    /// The winning set of wells, in site order.
    public let wells: [MicroscopicAuroraWell]
    /// The sets judged at each depth below the plan's size (depth 0 is no well: 1), none winning.
    public let setsByDepth: [Int]
    /// The smallest shape loss among the sets judged at smaller depths.
    public let nearestMiss: Int
    /// The sets judged in all.
    public let work: Int

    /// A plan of the given values.
    public init(actions: [MicroscopicAuroraAction], wells: [MicroscopicAuroraWell], setsByDepth: [Int],
                nearestMiss: Int, work: Int) {
        self.actions = actions
        self.wells = wells
        self.setsByDepth = setsByDepth
        self.nearestMiss = nearestMiss
        self.work = work
    }

    /// The number of placements.
    public var size: Int { actions.count }
}

/// The difficulty metrics of a certified level, from the level and its plan.
public struct MicroscopicAuroraDifficulty: Sendable, Hashable, Codable {
    /// The witness length (placements).
    public let placements: Int
    /// The stencil's size in cells.
    public let stencil: Int
    /// The required coverage in tenths of a percent.
    public let coverage: Int
    /// The swarm's size.
    public let swarm: Int
    /// The number of sites.
    public let sites: Int
    /// The sets judged at depths below the plan.
    public let setsSearched: Int
    /// The sets judged in all.
    public let work: Int
    /// The smallest shape loss among the sets judged at smaller depths.
    public let nearestMiss: Int

    /// The metrics of `level` certified by `plan`.
    public init(level: MicroscopicAuroraLevel, plan: MicroscopicAuroraPlan) {
        placements = plan.size
        stencil = level.stencil.count
        coverage = level.coverage
        swarm = level.swimmers.count
        sites = level.sites?.count ?? 0
        setsSearched = plan.setsByDepth.reduce(0, +)
        work = plan.work
        nearestMiss = plan.nearestMiss
    }

    /// The shared difficulty record (R02-F24): the witness length as the shortest solution, the sets judged as the
    /// states explored.
    public var puzzleDifficulty: PuzzleDifficulty { PuzzleDifficulty(shortest: placements, explored: work) }
}
