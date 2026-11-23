// BackwardsAuroraDifficulty — feature 392 (R02-G10-02) T-R02G1002-002 (FR-R02G1002-003; clarification Q3). The
// difficulty metrics of a certified level, taken from the level and the solver's actual result: the smallest reversal
// count, the wave length, the checkpoints, the samples the witness reverses (the sum of its section lengths) and its
// longest section, the opening's bad bends, the bend limit, the breaking margin B − L and the solver's work.
import VisualCoreSimulation

/// The difficulty metrics of a Backwards Aurora level.
public struct BackwardsAuroraDifficulty: Sendable, Hashable, Codable {
    /// The smallest reversal count (the solver's lower bound, met by the witness).
    public let smallest: Int
    /// The wave length N.
    public let length: Int
    /// The number of checkpoints.
    public let checkpoints: Int
    /// The samples the witness reverses: the sum of its section lengths.
    public let reversedSamples: Int
    /// The witness's longest section, in samples.
    public let longestSection: Int
    /// The opening wave's bad bends (interior bends above the bend limit).
    public let badBends: Int
    /// The bend limit L.
    public let bendLimit: Int
    /// The breaking margin B − L.
    public let breakingMargin: Int
    /// The reversals the solver evaluated.
    public let work: Int

    /// Metrics of the given values.
    public init(smallest: Int, length: Int, checkpoints: Int, reversedSamples: Int, longestSection: Int,
                badBends: Int, bendLimit: Int, breakingMargin: Int, work: Int) {
        self.smallest = smallest
        self.length = length
        self.checkpoints = checkpoints
        self.reversedSamples = reversedSamples
        self.longestSection = longestSection
        self.badBends = badBends
        self.bendLimit = bendLimit
        self.breakingMargin = breakingMargin
        self.work = work
    }

    /// The metrics of `actions` (the witness, `work` reversals evaluated) on `level`.
    public init(level: BackwardsAuroraLevel, actions: [BackwardsAuroraAction], work: Int) {
        var reversed: Int = 0
        var longest: Int = 0
        for action in actions {
            switch action {
            case let .reverse(start, end):
                let length: Int = end - start + 1
                reversed += length
                longest = max(longest, length)
            }
        }
        self.init(smallest: actions.count, length: level.count, checkpoints: level.checkpoints.count,
                  reversedSamples: reversed, longestSection: longest,
                  badBends: BackwardsAuroraSolver.badBends(level.opening, limit: level.bendLimit),
                  bendLimit: level.bendLimit, breakingMargin: level.breakingLimit - level.bendLimit, work: work)
    }

    /// The R02-F24 difficulty: shortest = the smallest reversal count, explored = the reversals evaluated.
    public var puzzleDifficulty: PuzzleDifficulty { PuzzleDifficulty(shortest: smallest, explored: work) }
}
