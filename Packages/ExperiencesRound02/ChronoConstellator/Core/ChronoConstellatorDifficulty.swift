// ChronoConstellatorDifficulty — feature 352 (R02-G06-02) T-R02G0602-002 (FR-R02G0602-003; clarification Q3). The
// difficulty metrics of a certified Chrono Constellator level, derived from the level and its solver result: the smallest
// edit count, the win tick of the witness, the star count, the loop lengths, the alignment windows considered (ticks with
// the smallest misaligned count) and how many of them a collision blocks.

import VisualCoreSimulation

/// The difficulty metrics of a certified level.
public struct ChronoConstellatorDifficulty: Sendable, Hashable, Codable {
    /// The smallest number of edits that wins (the solver's lower bound m*).
    public let smallest: Int
    /// The first tick on which the witness timeline puts every star on its target.
    public let winTick: Int
    /// The number of stars.
    public let stars: Int
    /// The length of every star's loop, in star order.
    public let loopLengths: [Int]
    /// The alignment windows considered: the ticks whose misaligned count is the smallest.
    public let windows: Int
    /// The windows whose phase-only timeline makes two stars collide.
    public let blocked: Int

    /// Metrics of the given values.
    public init(smallest: Int, winTick: Int, stars: Int, loopLengths: [Int], windows: Int, blocked: Int) {
        self.smallest = smallest
        self.winTick = winTick
        self.stars = stars
        self.loopLengths = loopLengths
        self.windows = windows
        self.blocked = blocked
    }

    /// The R02-F24 difficulty of the progression rule: the smallest edit count, with the windows considered as the
    /// explored measure.
    public var puzzleDifficulty: PuzzleDifficulty {
        PuzzleDifficulty(shortest: smallest, explored: windows)
    }
}
