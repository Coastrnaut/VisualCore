// SolutionReplayTests — feature 098 (A13-P03) T-A13-302 (FR-A13-301, FR-A13-330; SC-A13-304; clarification Q5). The
// replay proof of the shipping levels, host-free and short: from a fresh state, each of the 20 levels is chosen and its
// recorded solution is played as tile selections and turns (only the tiles whose solution differs from the start); the
// level reads solved and the move count equals the turns made.
import Foundation
import LightMazeCore
import Testing

@Suite struct SolutionReplayTests {
    @Test func everyRecordedSolutionReplaysFromAFreshState() {
        #expect(LevelCatalog.bundled.levels.count == 20)
        for index in 0..<20 {
            var state = MazeState.initial
            let chosen: Bool = state.selectLevel(index)
            #expect(chosen && state.moves.isEmpty, "level \(index + 1) chosen")
            let solution: [Orientation] = state.level.solution
            let start: [Orientation] = state.level.startOrientations
            #expect(!state.isSolved, "level \(index + 1) starts unsolved")
            var turns: Int = 0
            for position in 0..<solution.count where start[position] != solution[position] {
                let selected: Bool = state.selectTile(position)
                let turned: Bool = state.turnSelected()
                #expect(selected && turned, "level \(index + 1) tile \(position)")
                turns += 1
            }
            #expect(turns > 0, "level \(index + 1) needs at least one turn")
            #expect(state.isSolved, "level \(index + 1) solved")
            #expect(state.orientations == solution, "level \(index + 1) orientations")
            #expect(state.moves.count == turns, "level \(index + 1) moves")
        }
    }
}
