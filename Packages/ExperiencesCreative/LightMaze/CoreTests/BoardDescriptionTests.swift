// BoardDescriptionTests — feature 099 (A13-P04) T-A13-403 (FR-A13-410, FR-A13-411; SC-A13-402; clarifications Q2 and
// Q5; data-model "BoardDescription"). The board in words, host-free and short: the fixture boards lm-01 and lm-05 name
// the level, the size, every tile, each beam branch's start, turn and end cells and every target as lit or unlit; the
// summary counts the lit targets; the text follows a turn; a solved board lights every target; the largest board (12 ×
// 12, 144 tiles) stays within 4,000 characters.
import Foundation
import LightMazeCore
import Testing

@Suite struct BoardDescriptionTests {
    /// "row R, column C" counted from 1 (rows from the bottom, columns from the left).
    private func place(_ cell: Cell) -> String { "row \(cell.row + 1), column \(cell.column + 1)" }

    /// The full description of level `index` in `state`'s orientations.
    private func describe(_ state: MazeState) -> String {
        BoardDescription.full(levelName: state.level.name, levelNumber: state.levelIndex + 1, board: state.board,
                              beam: BeamTracer.trace(state.board))
    }

    @Test(arguments: [0, 4]) func fixtureBoardsNameEveryTileBranchAndTarget(index: Int) {
        let state = MazeState(levelIndex: index)
        let board: Board = state.board
        let beam: Beam = BeamTracer.trace(board)
        let text: String = describe(state)
        #expect(text.hasPrefix("Level \(index + 1), \(state.level.name): \(board.width) by \(board.height) board."))
        for tile in board.tiles {
            #expect(text.contains(place(tile.cell)), "tile at \(tile.cell) named")
        }
        #expect(text.contains("Beam 1 starts"))
        let lit = Set(beam.litTargets)
        for cell in board.targetCells {
            let word: String = lit.contains(cell) ? "lit" : "unlit"
            #expect(text.contains(place(cell) + ", " + word), "target at \(cell) is \(word)")
        }
        let litCount: Int = board.targetCells.filter { lit.contains($0) }.count
        let total: Int = board.targetCells.count
        let noun: String = total == 1 ? "target" : "targets"
        #expect(BoardDescription.targetWords(board: board, beam: beam) == "\(litCount) of \(total) \(noun) lit")
        #expect(text.count <= BoardDescription.maxLength)
    }

    @Test func firstLevelReadsExactly() {
        let text: String = describe(MazeState(levelIndex: 0))
        let expected: String = "Level 1, First light: 5 by 5 board. Emitter: row 3, column 1, facing east. "
            + "Wall: row 1, column 3. Mirror: row 3, column 3, leaning left. "
            + "Beam 1 starts at row 3, column 1 heading east, turns at row 3, column 3, and ends at the wall at row 1, "
            + "column 3. Target: row 5, column 3, unlit."
        #expect(text == expected)
    }

    @Test func fifthLevelBranchStartsTurnsAndEnds() {
        let text: String = describe(MazeState(levelIndex: 4))
        #expect(text.contains("Beam 1 starts at row 4, column 3 heading south, turns at row 2, column 3, and ends at "
            + "the wall at row 2, column 1."))
        #expect(text.contains("Mirrors: row 2, column 3, leaning right; row 2, column 6, leaning right."))
        #expect(text.contains("Walls: row 2, column 1; row 3, column 1; row 6, column 3."))
    }

    @Test func textFollowsATurn() {
        var state = MazeState(levelIndex: 0)
        let before: String = describe(state)
        state.selectTile(0)
        state.turnSelected()
        let after: String = describe(state)
        #expect(after != before)
        #expect(after.contains("Mirror: row 3, column 3, leaning right."))
        #expect(after.contains("turns at row 3, column 3, and ends at the target at row 5, column 3."))
        #expect(after.contains("Target: row 5, column 3, lit."))
        for tile in state.board.tiles {
            #expect(after.contains(place(tile.cell)), "tile at \(tile.cell) still named")
        }
    }

    @Test func solvedBoardsLightEveryTarget() throws {
        for level in LevelCatalog.bundled.levels.prefix(5) {
            let board: Board = try #require(level.solvedBoard)
            let total: Int = board.targetCells.count
            let noun: String = total == 1 ? "target" : "targets"
            let words: String = BoardDescription.targetWords(board: board, beam: BeamTracer.trace(board))
            #expect(words == "\(total) of \(total) \(noun) lit", "\(level.id)")
        }
    }

    @Test func targetWordsCountDistinctBoardTargets() {
        let board = Board(width: 4, height: 4, tiles: [.emitter(0, 0, .east), .target(3, 0), .target(3, 3)])
        let beam = Beam(segments: [], litTargets: [Cell(3, 0), Cell(3, 0), Cell(1, 1)], endReasons: [],
                        droppedBranches: 0, isSolved: false)
        #expect(BoardDescription.targetWords(board: board, beam: beam) == "1 of 2 targets lit")
        let empty = Beam(segments: [], litTargets: [], endReasons: [], droppedBranches: 0, isSolved: false)
        #expect(BoardDescription.full(levelName: "Test", levelNumber: 9, board: board, beam: empty).contains("No beam."))
    }

    @Test func largestBoardStaysWithinTheBound() {
        var tiles: [Tile] = []
        for row in 0..<12 {
            for column in 0..<12 {
                if column == 0 && row == 0 {
                    tiles.append(.emitter(0, 0, .east))
                } else if column == 11 && row == 11 {
                    tiles.append(.target(11, 11))
                } else {
                    let pick: Int = (row * 12 + column) % 3
                    let orientation: Orientation = (row + column) % 2 == 0 ? .slash : .backslash
                    if pick == 0 {
                        tiles.append(.mirror(column, row, orientation))
                    } else if pick == 1 {
                        tiles.append(.prism(column, row, orientation))
                    } else {
                        tiles.append(.wall(column, row))
                    }
                }
            }
        }
        let board = Board(width: 12, height: 12, tiles: tiles)
        #expect(tiles.count == 144)
        let text: String = BoardDescription.full(levelName: "Largest", levelNumber: 20, board: board,
                                                 beam: BeamTracer.trace(board))
        #expect(text.count <= BoardDescription.maxLength)
        #expect(text.hasPrefix("Level 20, Largest: 12 by 12 board."))
        #expect(text.contains(" more"), "lists are cut with \"and N more\"")
    }
}
