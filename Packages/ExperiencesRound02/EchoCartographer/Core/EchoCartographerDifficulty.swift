// EchoCartographerDifficulty — feature 402 (R02-G11-02) T-R02G1102-002 (FR-R02G1102-003; clarification Q3). The
// difficulty metrics of a certified level, all from the level and the solver's actual plan: the witness pulse count,
// the chamber's width and height, the region's cells (reachable from the entry, the entry included), the beacons, the
// tolerance, the placements fitting before the last pulse (capped at 1 000) and the solver's work.
import Foundation
import VisualCoreSimulation

/// The difficulty metrics of a certified Echo Cartographer level.
public struct EchoCartographerDifficulty: Sendable, Hashable, Codable {
    /// The pulses of the witness plan.
    public let pulses: Int
    /// The chamber's width.
    public let width: Int
    /// The chamber's height.
    public let height: Int
    /// The cells reachable from the entry, the entry included.
    public let region: Int
    /// The beacons.
    public let beacons: Int
    /// The claim tolerance.
    public let tolerance: Int
    /// The placements fitting every pulse but the last (capped at 1 000).
    public let placementsBeforeLast: Int
    /// The enumeration nodes the solver visited.
    public let work: Int

    /// Metrics of the given values.
    public init(pulses: Int, width: Int, height: Int, region: Int, beacons: Int, tolerance: Int,
                placementsBeforeLast: Int, work: Int) {
        self.pulses = pulses
        self.width = width
        self.height = height
        self.region = region
        self.beacons = beacons
        self.tolerance = tolerance
        self.placementsBeforeLast = placementsBeforeLast
        self.work = work
    }

    /// The metrics of `plan` on `level`.
    public init(level: EchoCartographerLevel, plan: EchoCartographerPlan) {
        self.init(pulses: plan.pulses.count, width: level.chamber.width, height: level.chamber.height,
                  region: EchoCartographerSolver.region(level).count + 1, beacons: level.beacons.count,
                  tolerance: level.tolerance, placementsBeforeLast: plan.placementsBeforeLast, work: plan.work)
    }

    /// The R02-F24 difficulty: shortest = the witness pulse count, explored = the enumeration nodes visited.
    public var puzzleDifficulty: PuzzleDifficulty { PuzzleDifficulty(shortest: pulses, explored: work) }
}
