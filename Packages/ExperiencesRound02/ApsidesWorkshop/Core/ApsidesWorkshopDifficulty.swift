// ApsidesWorkshopDifficulty — feature 472 (R02-G18-02) T-R02G1802-002 (FR-R02G1802-003; SC-R02G1802-004; clarification
// Q3). The difficulty metrics of a certified Apsides Workshop level, from the level and the solver's actual result: the
// witness length (tunings), the targets, the apsis targets, the planets, the narrowest share band and the narrowest
// distance range (widths high − low; 0 for a band or range the level does not have), the orbits judged at smaller
// depths and the solver work. Modelled on `CelestialEclipseLabDifficulty` (feature 462).
import VisualCoreSimulation

/// The difficulty metrics of a certified level.
public struct ApsidesWorkshopDifficulty: Sendable, Hashable, Codable {
    /// The witness length: the plan's tunings.
    public let tunings: Int
    /// The targets.
    public let targets: Int
    /// The apsis targets among them.
    public let apsisTargets: Int
    /// The exclusion planets.
    public let planets: Int
    /// The narrowest share band of a sweep target (high − low, tenths of a percent), or 0 without sweeps.
    public let narrowestShareBand: Int
    /// The narrowest distance range of an apsis target (high − low, twentieths), or 0 without apsis targets.
    public let narrowestDistanceRange: Int
    /// The orbits judged at every depth below the plan's.
    public let orbitsSearched: Int
    /// The orbits the solver judged, the start included.
    public let work: Int

    /// The metrics of the given values.
    public init(tunings: Int, targets: Int, apsisTargets: Int, planets: Int, narrowestShareBand: Int,
                narrowestDistanceRange: Int, orbitsSearched: Int, work: Int) {
        self.tunings = tunings
        self.targets = targets
        self.apsisTargets = apsisTargets
        self.planets = planets
        self.narrowestShareBand = narrowestShareBand
        self.narrowestDistanceRange = narrowestDistanceRange
        self.orbitsSearched = orbitsSearched
        self.work = work
    }

    /// The metrics of `level` certified by `plan`.
    public init(level: ApsidesWorkshopLevel, plan: ApsidesWorkshopPlan) {
        var shareBands: [Int] = []
        var distanceRanges: [Int] = []
        for target in level.targets {
            if target.kind == .sweep {
                shareBands.append(target.high - target.low)
            } else {
                distanceRanges.append(target.high - target.low)
            }
        }
        self.init(tunings: plan.size, targets: level.targets.count, apsisTargets: distanceRanges.count,
                  planets: level.planets.count, narrowestShareBand: shareBands.min() ?? 0,
                  narrowestDistanceRange: distanceRanges.min() ?? 0, orbitsSearched: plan.orbitsSearched,
                  work: plan.work)
    }

    /// The shared difficulty of R02-F24: the shortest plan and the work explored.
    public var puzzleDifficulty: PuzzleDifficulty { PuzzleDifficulty(shortest: tunings, explored: work) }
}
