// MovesTests — feature 098 (A13-P03) T-A13-302 (FR-A13-310, FR-A13-330; SC-A13-302; clarification Q3; data-model
// "Move", "MazeState"). The moves of the maze state, host-free and short: turning appends a move with its exact
// orientations; undo restores the orientations and the beam of the earlier state and removes the move; undo with no
// moves is refused; at most 64 moves are kept (the oldest dropped); reset and choosing a level empty the moves; the
// moves round-trip through the sorted-key JSON, a schema-1 payload migrates with no moves and inconsistent moves are
// refused.
import Foundation
import LightMazeCore
import Testing

@Suite struct MovesTests {
    @Test func turningAppendsTheExactMove() {
        var state = MazeState(levelIndex: 9)
        let start: [Orientation] = state.orientations
        state.selectTile(2)
        state.turnSelected()
        #expect(state.moves == [Move(tile: 2, before: start[2], after: start[2].toggled)])
        state.selectTile(0)
        state.turnSelected()
        #expect(state.moves.count == 2 && state.moves[1] == Move(tile: 0, before: start[0], after: start[0].toggled))
        let refused: Bool = state.selectTile(-5)
        #expect(!refused && state.moves.count == 2, "a refused selection adds no move")
    }

    @Test func undoRestoresTheEarlierOrientationsAndBeam() {
        var state = MazeState(levelIndex: 12)
        var history: [MazeState] = [state]
        let count: Int = state.orientations.count
        for step in 0..<10 {
            state.selectTile((step * 3) % count)
            state.turnSelected()
            history.append(state)
        }
        #expect(state.moves.count == 10)
        for step in stride(from: 9, through: 0, by: -1) {
            let undone: Bool = state.undo()
            #expect(undone, "undo \(step)")
            #expect(state.orientations == history[step].orientations, "orientations after undo to \(step)")
            #expect(state.beam == history[step].beam, "beam after undo to \(step)")
            #expect(state.moves == history[step].moves)
        }
        #expect(state.orientations == state.level.startOrientations && state.moves.isEmpty)
        let again: Bool = state.undo()
        #expect(!again, "no moves to undo")
    }

    @Test func undoOnASolvedLevelUnsolvesIt() {
        var state = MazeState.initial
        state.selectTile(0)
        state.turnSelected()
        #expect(state.isSolved && state.moves.count == 1)
        let undone: Bool = state.undo()
        #expect(undone && !state.isSolved && state.selection == 0, "the selection stays")
        #expect(state.orientations == state.level.startOrientations)
    }

    @Test func undoWithNoMovesIsRefused() {
        var state = MazeState.initial
        let before = state
        let undone: Bool = state.undo()
        #expect(!undone && state == before)
    }

    @Test func atMostSixtyFourMovesAreKept() {
        var state = MazeState(levelIndex: 5)
        state.selectTile(0)
        for _ in 0..<71 {
            state.turnSelected()
        }
        #expect(state.moves.count == MazeState.maxMoves && MazeState.maxMoves == 64)
        var history: [Orientation] = []
        for move in state.moves {
            history.append(move.before)
        }
        // 71 turns of one tile: turns 8…71 remain; the 8th turn starts after 7 toggles, from the toggled start.
        #expect(history[0] == state.level.startOrientations[0].toggled)
        for _ in 0..<64 {
            state.undo()
        }
        #expect(state.moves.isEmpty && state.orientations[0] == state.level.startOrientations[0].toggled)
        let undone: Bool = state.undo()
        #expect(!undone, "the dropped moves cannot be undone")
    }

    @Test func resetAndChoosingALevelEmptyTheMoves() {
        var state = MazeState(levelIndex: 3)
        state.selectTile(0)
        state.turnSelected()
        state.reset()
        #expect(state.moves.isEmpty && state.orientations == state.level.startOrientations)
        state.selectTile(0)
        state.turnSelected()
        state.selectLevel(3)
        #expect(state.moves.isEmpty)
        state.selectTile(0)
        state.turnSelected()
        state.selectLevel(7)
        #expect(state.moves.isEmpty && state.levelIndex == 7)
        let before = state
        state.selectTile(0)
        state.turnSelected()
        state.selectLevel(40)
        #expect(state.moves.count == 1 && state != before, "a refused level keeps the moves")
    }

    @Test func movesRoundTripAndSchemaOneMigrates() {
        var state = MazeState(levelIndex: 9)
        for position in 0..<3 {
            state.selectTile(position)
            state.turnSelected()
        }
        state.undo()
        #expect(MazeState.decode(state.encoded()) == .success(state))
        let schemaOne = #"{"levelIndex":0,"orientations":["backslash"],"schema":1,"selection":-1}"#
        #expect(MazeState.decode(Data(schemaOne.utf8)) == .success(MazeState.initial))
        let ignored = #"{"levelIndex":0,"moves":[{"after":"slash","before":"backslash","tile":0}],"#
            + #""orientations":["slash"],"schema":1,"selection":-1}"#
        guard case .success(let migrated) = MazeState.decode(Data(ignored.utf8)) else {
            Issue.record("a schema-1 payload decodes")
            return
        }
        #expect(migrated.moves.isEmpty && migrated.isSolved, "schema 1 has no moves")
    }

    @Test func inconsistentMovesAreRefused() {
        let head = #"{"levelIndex":0,"moves":"#
        let tail = #","orientations":["slash"],"schema":2,"selection":0}"#
        let good = #"{"after":"slash","before":"backslash","tile":0}"#
        var tooMany: [String] = []
        for index in 0..<65 {
            tooMany.append(index % 2 == 0 ? good : #"{"after":"backslash","before":"slash","tile":0}"#)
        }
        let damaged: [String] = [
            #"[{"after":"slash","before":"slash","tile":0}]"#,
            #"[{"after":"slash","before":"backslash","tile":1}]"#,
            #"[{"after":"slash","before":"backslash","tile":-1}]"#,
            #"[{"after":"backslash","before":"slash","tile":0}]"#,
            #"[{"after":"slash","before":"backslash"}]"#,
            #"[{"after":"up","before":"backslash","tile":0}]"#,
            #"{}"#,
            "[" + tooMany.joined(separator: ",") + "]",
        ]
        for moves in damaged {
            let payload: String = head + moves + tail
            #expect(MazeState.decode(Data(payload.utf8)) == .failure(.damaged), "\(moves.prefix(80))")
        }
        let accepted: String = head + "[" + good + "]" + tail
        guard case .success(let state) = MazeState.decode(Data(accepted.utf8)) else {
            Issue.record("one consistent move decodes")
            return
        }
        #expect(state.moves.count == 1 && state.isSolved)
    }
}
