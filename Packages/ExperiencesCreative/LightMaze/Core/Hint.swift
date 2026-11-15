// Hint — feature 099 (A13-P04) T-A13-402 (FR-A13-401, FR-A13-402; clarification Q1; data-model "Hint"; research D1).
// The hint of Light Maze: which turnable tile to turn next. The rule is the level's recorded solution, with no search:
// - nil when the orientations do not fit the level (a count other than its number of turnable tiles), or when the
//   tracer reads the board with those orientations solved (also when it is solved otherwise than the recorded
//   solution);
// - otherwise the first index i (board order of the turnable tiles) with `orientations[i] != level.solution[i]`;
// - nil when no index differs.
// The index is an index among the level's turnable tiles, the same index space as `MazeState.orientations` and
// `MazeState.selection`. Following hints (select, then turn) changes one differing tile per step, so a level is solved
// within as many hints as tiles differ from its solution.
import Foundation

/// The hint rule: the first turnable tile whose orientation differs from the level's recorded solution.
public enum Hint {
    /// The index (among `level`'s turnable tiles) of the first tile whose orientation in `orientations` differs from
    /// `level.solution`; nil when `orientations` does not fit the level, when the board with them is solved, or when
    /// no tile differs.
    public static func tile(level: Level, orientations: [Orientation]) -> Int? {
        guard let board = level.board.applying(orientations), !BeamTracer.trace(board).isSolved else { return nil }
        let count = min(orientations.count, level.solution.count)
        for index in 0..<count where orientations[index] != level.solution[index] {
            return index
        }
        return nil
    }

    /// The hint for `state`: ``tile(level:orientations:)`` with the state's level and orientations.
    public static func tile(for state: MazeState) -> Int? {
        tile(level: state.level, orientations: state.orientations)
    }
}
