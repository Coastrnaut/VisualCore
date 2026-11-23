// HarmonicBridgesDifficulty — feature 412 (R02-G12-02) T-R02G1202-002 (FR-R02G1202-003; clarification Q3). The
// difficulty metrics of a certified level, all from the level and the solver's actual plan: the witness tuning count,
// the islands, the strings, the locked strings, the steps of the crossing window, the tones sounded over all steps, the
// solidity threshold, the choices of fewer tunings tried (the minimality proof) and the solver's work.
import Foundation
import VisualCoreSimulation

/// The difficulty metrics of a certified Harmonic Bridges level.
public struct HarmonicBridgesDifficulty: Sendable, Hashable, Codable {
    /// The tunings of the witness plan.
    public let tunings: Int
    /// The islands.
    public let islands: Int
    /// The strings.
    public let strings: Int
    /// The locked strings.
    public let locked: Int
    /// The steps of the crossing window.
    public let steps: Int
    /// The tones sounded, summed over all steps.
    public let tones: Int
    /// The solidity threshold, in quarters.
    public let threshold: Int
    /// The choices of fewer tunings the solver tried, none of which wins.
    public let smallerChoices: Int
    /// The choices the solver tried in all.
    public let work: Int

    /// Metrics of the given values.
    public init(tunings: Int, islands: Int, strings: Int, locked: Int, steps: Int, tones: Int, threshold: Int,
                smallerChoices: Int, work: Int) {
        self.tunings = tunings
        self.islands = islands
        self.strings = strings
        self.locked = locked
        self.steps = steps
        self.tones = tones
        self.threshold = threshold
        self.smallerChoices = smallerChoices
        self.work = work
    }

    /// The metrics of `plan` on `level`.
    public init(level: HarmonicBridgesLevel, plan: HarmonicBridgesPlan) {
        var locked: Int = 0
        for string in level.strings where string.locked { locked += 1 }
        var tones: Int = 0
        for step in level.steps { tones += step.count }
        self.init(tunings: plan.tunings.count, islands: level.islands.count, strings: level.strings.count,
                  locked: locked, steps: level.steps.count, tones: tones, threshold: level.threshold,
                  smallerChoices: plan.smallerChoices, work: plan.work)
    }

    /// The R02-F24 difficulty: shortest = the witness tuning count, explored = the choices the solver tried.
    public var puzzleDifficulty: PuzzleDifficulty { PuzzleDifficulty(shortest: tunings, explored: work) }
}
