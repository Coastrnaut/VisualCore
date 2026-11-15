// SolverTests — feature 100 (A13-P05) T-A13-502 (FR-A13-501, FR-A13-502; SC-A13-501, SC-A13-502; clarifications Q1–Q2).
// The bounded solver, host-free and short:
// - every bundled level is solved; its answer, replayed through `MazeState` (select and turn each differing tile),
//   reads solved; its turns equal the recorded solution's turns (the fewest); it examines at most 2ⁿ sets;
// - a board whose target is walled off is unsolvable after exactly 2ⁿ sets;
// - a board solved at its start gives 0 turns after 1 set;
// - an invalid board (two emitters, no target) is refused `invalid-board` unsearched;
// - a valid 16-turnable board whose target is walled off is searched in full (65,536 sets, each trace one segment
//   long; measured, never asserted on wall clock), and the same board with a 17th mirror is refused `too-many-tiles`
//   unsearched;
// - the same level solved twice gives the same result;
// - the search order is k = 0, 1, … turns with combinations in lexicographic order (n = 4, k = 2: [0,1], [0,2],
//   [0,3], [1,2], [1,3], [2,3]), shown through the public result: a board needing exactly tiles 1 and 3 turned is
//   solved after 1 + 4 + 5 = 10 sets, one needing tiles 2 and 3 after 1 + 4 + 6 = 11.
import Foundation
import LightMazeCore
import Testing

@Suite struct SolverTests {
    @Test func everyBundledLevelIsSolvedWithItsRecordedTurns() throws {
        let levels: [Level] = LevelCatalog.bundled.levels
        #expect(levels.count == 20)
        for index in 0..<levels.count {
            let level: Level = levels[index]
            let result: SolverResult = Solver.solve(level.board)
            guard case .solved(let orientations, let turns, let examined) = result else {
                Issue.record("level \(level.id) not solved: \(result)")
                continue
            }
            let start: [Orientation] = level.startOrientations
            #expect(orientations.count == start.count, "\(level.id) answer length")
            #expect(turns == Solver.turns(from: start, to: orientations), "\(level.id) turns of the answer")
            #expect(turns == Solver.turns(from: start, to: level.solution), "\(level.id) fewest turns")
            #expect(examined >= 1 && examined <= 1 << level.turnableCount, "\(level.id) examined \(examined)")
            var state = MazeState(levelIndex: index)
            for tile in 0..<orientations.count where orientations[tile] != start[tile] {
                let selected: Bool = state.selectTile(tile)
                let turned: Bool = state.turnSelected()
                #expect(selected && turned, "\(level.id) tile \(tile)")
            }
            #expect(state.orientations == orientations, "\(level.id) replayed orientations")
            #expect(state.isSolved, "\(level.id) replayed answer reads solved")
            let board: Board = try #require(level.board.applying(orientations))
            #expect(BeamTracer.trace(board).isSolved, "\(level.id) answer traced solved")
        }
    }

    @Test func aWalledOffTargetIsUnsolvableAfterEverySet() {
        // The emitter at (0, 0) shines east straight into the wall at (1, 0); no orientation reaches the target.
        let board = Board(width: 5, height: 5, tiles: [
            .emitter(0, 0, .east),
            .wall(1, 0),
            .target(4, 4),
            .mirror(2, 2, .slash),
            .mirror(3, 1, .backslash),
            .prism(1, 3, .slash),
        ])
        #expect(board.isValid)
        let n: Int = board.turnableIndices.count
        #expect(n == 3)
        let result: SolverResult = Solver.solve(board)
        #expect(result == .unsolvable(examined: 1 << n))
        #expect(result.examined == 8)
    }

    @Test func aSolvedStartGivesNoTurnsAfterOneSet() {
        // The emitter at (0, 0) shines east onto the target at (3, 0); the mirror at (1, 2) is off the beam.
        let board = Board(width: 4, height: 4, tiles: [
            .emitter(0, 0, .east),
            .target(3, 0),
            .mirror(1, 2, .backslash),
        ])
        #expect(board.isValid)
        let result: SolverResult = Solver.solve(board)
        #expect(result == .solved(orientations: [.backslash], turns: 0, examined: 1))
        #expect(result.examined == 1)
    }

    @Test func anInvalidBoardIsRefusedUnsearched() {
        let twoEmitters = Board(width: 4, height: 4, tiles: [
            .emitter(0, 0, .east),
            .emitter(0, 3, .east),
            .target(3, 0),
            .mirror(2, 2, .slash),
        ])
        let first: SolverResult = Solver.solve(twoEmitters)
        #expect(first == .refused(.invalidBoard(.emitterCount)))
        #expect(first.examined == 0)
        if case .refused(let refusal) = first {
            #expect(refusal.code == "invalid-board")
        }
        let noTarget = Board(width: 4, height: 4, tiles: [
            .emitter(0, 0, .east),
            .mirror(2, 2, .slash),
        ])
        let second: SolverResult = Solver.solve(noTarget)
        #expect(second == .refused(.invalidBoard(.noTarget)))
        #expect(second.examined == 0)
        if case .refused(let refusal) = second {
            #expect(refusal.code == "invalid-board")
        }
        let tooSmall = Board(width: 3, height: 4, tiles: [.emitter(0, 0, .east), .target(2, 0)])
        #expect(Solver.solve(tooSmall) == .refused(.invalidBoard(.sizeOutOfRange)))
    }

    @Test func sixteenTurnableTilesAreSearchedInFullAndSeventeenRefused() {
        var board: Board = Self.walledOffBoard(mirrors: 16)
        #expect(board.isValid)
        #expect(board.turnableIndices.count == Solver.maxTurnable)
        let full: SolverResult = Solver.solve(board)
        #expect(full == .unsolvable(examined: 65_536))

        board = Self.walledOffBoard(mirrors: 17)
        #expect(board.isValid)
        #expect(board.turnableIndices.count == 17)
        let refused: SolverResult = Solver.solve(board)
        #expect(refused == .refused(.tooManyTiles(17)))
        #expect(refused.examined == 0)
        if case .refused(let refusal) = refused {
            #expect(refusal.code == "too-many-tiles")
        }
    }

    @Test func theSameLevelSolvedTwiceGivesTheSameResult() {
        let levels: [Level] = LevelCatalog.bundled.levels
        for level in levels {
            let first: SolverResult = Solver.solve(level.board)
            let second: SolverResult = Solver.solve(level.board)
            #expect(first == second, "\(level.id)")
        }
    }

    @Test func setsAreExaminedByTurnsThenInLexicographicOrder() {
        // Unsolvable boards examine every set: 2ⁿ for n = 0 … 4.
        var n = 0
        while n <= 4 {
            let board: Board = Self.walledOffBoard(mirrors: n)
            #expect(Solver.solve(board) == .unsolvable(examined: 1 << n), "n = \(n)")
            n += 1
        }
        // Exactly tiles 1 and 3 must turn: k = 0 (1 set), k = 1 (4 sets), then [0,1], [0,2], [0,3], [1,2], [1,3].
        let pairOneThree: Board = Self.twoTurnBoard(turning: (1, 3))
        let start13: [Orientation] = pairOneThree.orientations
        var answer13: [Orientation] = start13
        answer13[1] = answer13[1].toggled
        answer13[3] = answer13[3].toggled
        #expect(Solver.solve(pairOneThree) == .solved(orientations: answer13, turns: 2, examined: 10))
        // Exactly tiles 2 and 3 must turn: the last pair, after all six, so 1 + 4 + 6 = 11 sets.
        let pairTwoThree: Board = Self.twoTurnBoard(turning: (2, 3))
        let start23: [Orientation] = pairTwoThree.orientations
        var answer23: [Orientation] = start23
        answer23[2] = answer23[2].toggled
        answer23[3] = answer23[3].toggled
        #expect(Solver.solve(pairTwoThree) == .solved(orientations: answer23, turns: 2, examined: 11))
    }

    /// A 12 × 12 board whose emitter at (0, 0) shines east into the adjacent wall at (1, 0), with the target at (11, 11)
    /// walled in at (10, 11) and (11, 10), and `mirrors` mirrors in free cells from (0, 2) row by row (alternating
    /// orientations). Every trace is one segment long and never solved, so it is unsolvable for any orientations.
    static func walledOffBoard(mirrors: Int) -> Board {
        var tiles: [Tile] = [.emitter(0, 0, .east), .wall(1, 0), .target(11, 11), .wall(10, 11), .wall(11, 10)]
        var placed = 0
        while placed < mirrors {
            let column: Int = placed % 12
            let row: Int = 2 + placed / 12
            let orientation: Orientation = placed % 2 == 0 ? .slash : .backslash
            tiles.append(.mirror(column, row, orientation))
            placed += 1
        }
        return Board(width: 12, height: 12, tiles: tiles)
    }

    /// A 6 × 6 board with four mirrors (turnable indices 0 … 3) where only turning exactly the two indices of
    /// `turning` lights the target. The emitter at (0, 0) shines east; the beam must turn north at (2, 0) and east at
    /// (2, 3) to reach the target at (5, 3). Both path mirrors start backslash (east → south off the board, north →
    /// west off the board) and solve as slash; the other two mirrors, at (0, 5) and (5, 5), lie off every path.
    static func twoTurnBoard(turning: (Int, Int)) -> Board {
        let pathCells: [Cell] = [Cell(2, 0), Cell(2, 3)]
        let offCells: [Cell] = [Cell(0, 5), Cell(5, 5)]
        var cells: [Cell] = []
        var offNext = 0
        var pathNext = 0
        for index in 0..<4 {
            if index == turning.0 || index == turning.1 {
                cells.append(pathCells[pathNext])
                pathNext += 1
            } else {
                cells.append(offCells[offNext])
                offNext += 1
            }
        }
        var tiles: [Tile] = [.emitter(0, 0, .east), .target(5, 3)]
        for cell in cells {
            tiles.append(.mirror(cell.column, cell.row, .backslash))
        }
        return Board(width: 6, height: 6, tiles: tiles)
    }
}
