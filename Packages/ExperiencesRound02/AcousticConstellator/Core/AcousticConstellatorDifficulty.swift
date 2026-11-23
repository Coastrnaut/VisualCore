// AcousticConstellatorDifficulty — feature 422 (R02-G13-02) T-R02G1302-002 (FR-R02G1302-003; clarification Q3). The
// difficulty metrics of a certified level, all from the level and the solver's actual plan: the witness action count
// (before the listen), the stars, the symbol's pairs and cycles (pairs − stars + 1), the fixed links, the rate spread
// (0 when every star has the same natural rate, else 1), the window, the hold, the coherence threshold, the sets of
// smaller sizes tried (the minimality proof) and the solver's work (listens).
import Foundation
import VisualCoreSimulation

/// The difficulty metrics of a certified Acoustic Constellator level.
public struct AcousticConstellatorDifficulty: Sendable, Hashable, Codable {
    /// The actions of the witness plan before the listen (links and nudges).
    public let actions: Int
    /// The stars.
    public let stars: Int
    /// The target symbol's pairs.
    public let symbolPairs: Int
    /// The target symbol's independent cycles: pairs − stars + 1 (the stars the symbol touches, which in a generated
    /// level are all of them).
    public let cycles: Int
    /// The fixed links.
    public let fixedLinks: Int
    /// The rate spread: 0 when every star has the same natural rate, else 1.
    public let rateSpread: Int
    /// The window, in ticks.
    public let window: Int
    /// The hold, in ticks.
    public let hold: Int
    /// The coherence threshold θ.
    public let threshold: Int
    /// The sets of smaller sizes the solver tried, none of which wins.
    public let smallerSets: Int
    /// The listens the solver ran in all.
    public let work: Int

    /// Metrics of the given values.
    public init(actions: Int, stars: Int, symbolPairs: Int, cycles: Int, fixedLinks: Int, rateSpread: Int,
                window: Int, hold: Int, threshold: Int, smallerSets: Int, work: Int) {
        self.actions = actions
        self.stars = stars
        self.symbolPairs = symbolPairs
        self.cycles = cycles
        self.fixedLinks = fixedLinks
        self.rateSpread = rateSpread
        self.window = window
        self.hold = hold
        self.threshold = threshold
        self.smallerSets = smallerSets
        self.work = work
    }

    /// The metrics of `plan` on `level`.
    public init(level: AcousticConstellatorLevel, plan: AcousticConstellatorPlan) {
        let rates: [Int] = level.naturalRates
        let spread: Int = rates.allSatisfy { $0 == rates.first } ? 0 : 1
        self.init(actions: plan.size, stars: level.stars.count, symbolPairs: level.symbol.count,
                  cycles: level.symbol.count - level.symbolStars.count + 1, fixedLinks: level.fixedLinks.count,
                  rateSpread: spread, window: level.window, hold: level.hold, threshold: level.threshold,
                  smallerSets: plan.smallerSets, work: plan.work)
    }

    /// The R02-F24 difficulty: shortest = the witness action count, explored = the listens the solver ran.
    public var puzzleDifficulty: PuzzleDifficulty { PuzzleDifficulty(shortest: actions, explored: work) }
}
