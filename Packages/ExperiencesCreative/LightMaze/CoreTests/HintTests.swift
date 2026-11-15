// HintTests — feature 099 (A13-P04) T-A13-402 (FR-A13-401, FR-A13-402; SC-A13-401; clarification Q1; data-model
// "Hint"). The hint rule, host-free and short: for every bundled level, repeating hint then turn from the start solves
// the level within its number of turnable tiles and the hint is then nil; the recorded solution gives nil; a board
// solved otherwise than the recorded solution gives nil; orientations that do not fit the level give nil; the hint is
// always an index among the turnable tiles and names a tile that differs from the solution.
import Foundation
import LightMazeCore
import Testing

@Suite struct HintTests {
    @Test func followingHintsSolvesEveryLevelWithinItsTurnableCount() {
        let count: Int = LevelCatalog.bundled.levels.count
        #expect(count == 20)
        for index in 0..<count {
            var state = MazeState(levelIndex: index)
            let limit: Int = state.level.turnableCount
            var hints = 0
            while hints <= limit {
                guard let tile = Hint.tile(for: state) else { break }
                let selected: Bool = state.selectTile(tile)
                let turned: Bool = state.turnSelected()
                #expect(selected && turned, "level \(index) hint \(hints)")
                hints += 1
            }
            #expect(state.isSolved, "level \(index) solved by hints")
            #expect(hints <= limit, "level \(index) took \(hints) hints for \(limit) turnable tiles")
            #expect(Hint.tile(for: state) == nil, "level \(index) no hint once solved")
        }
    }

    @Test func theRecordedSolutionGivesNoHint() {
        let levels: [Level] = LevelCatalog.bundled.levels
        for level in levels {
            #expect(Hint.tile(level: level, orientations: level.solution) == nil, "\(level.id)")
        }
    }

    @Test func aBoardSolvedOtherwiseThanTheRecordedSolutionGivesNoHint() {
        // Emitter at (0, 0) shining east onto the target at (3, 0); the mirror at (1, 2) is off the beam, so both of
        // its orientations solve the board while the recorded solution names only one.
        let board = Board(width: 4, height: 4, tiles: [
            .emitter(0, 0, .east),
            .target(3, 0),
            .mirror(1, 2, .slash),
        ])
        let level = Level(id: "hint-test", name: "Hint test", board: board, solution: [.slash],
                          author: LevelCatalog.projectAuthor, license: "MIT")
        let other: [Orientation] = [.backslash]
        let otherBoard: Board? = board.applying(other)
        #expect(otherBoard.map { BeamTracer.trace($0).isSolved } == true, "the other orientation also solves")
        #expect(Hint.tile(level: level, orientations: other) == nil)
        #expect(Hint.tile(level: level, orientations: level.solution) == nil)
    }

    @Test func orientationsThatDoNotFitTheLevelGiveNoHint() {
        let level: Level = LevelCatalog.bundled.levels[4]
        var longer: [Orientation] = level.solution
        longer.append(.slash)
        #expect(Hint.tile(level: level, orientations: []) == nil)
        #expect(Hint.tile(level: level, orientations: longer) == nil)
    }

    @Test func theHintIsAlwaysADifferingTurnableTile() {
        let levels: [Level] = LevelCatalog.bundled.levels
        for (levelIndex, level) in levels.enumerated() {
            let count: Int = level.turnableCount
            for seed in 0..<8 {
                var orientations: [Orientation] = []
                for tile in 0..<count {
                    let bit: Int = ((tile + 1) * 7 + seed * 13 + levelIndex * 5) % 3
                    orientations.append(bit == 0 ? .backslash : .slash)
                }
                guard let tile = Hint.tile(level: level, orientations: orientations) else { continue }
                #expect((0..<count).contains(tile), "\(level.id) seed \(seed)")
                #expect(orientations[tile] != level.solution[tile], "\(level.id) seed \(seed)")
                var earlierDiffer = false
                for earlier in 0..<tile where orientations[earlier] != level.solution[earlier] {
                    earlierDiffer = true
                }
                #expect(!earlierDiffer, "\(level.id) seed \(seed) first differing tile")
            }
        }
    }
}
