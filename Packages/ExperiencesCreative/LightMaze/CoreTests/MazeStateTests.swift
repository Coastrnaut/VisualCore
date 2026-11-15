// MazeStateTests — feature 096 (A13-P01) T-A13-103 (FR-A13-122; clarification Q5; data-model "MazeState"). The saved
// maze state, host-free and short: the initial state is the first level in its starting orientations with nothing
// selected; choosing a level (0…19, others refused), selecting and turning a tile, and resetting; the first level is
// solved by turning its mirror; the beam follows the state; the sorted-key JSON round trip is exact; damaged payloads
// (not JSON, truncated, missing keys, out-of-range level, wrong orientation count, bad selection) and newer payloads
// are refused with their reason.
import Foundation
import LightMazeCore
import Testing

@Suite struct MazeStateTests {
    @Test func theInitialStateIsTheFirstLevelUnselected() {
        let state = MazeState.initial
        #expect(state.levelIndex == 0 && state.selection == -1 && state.selectedTileIndex == nil)
        #expect(state.orientations == LevelCatalog.bundled.levels[0].startOrientations)
        #expect(state.level.id == "lm-01" && state.board == state.level.board)
        #expect(!state.isSolved && state.beam.endReasons == [.wall])
        #expect(MazeState.schemaVersion == 1 && MazeState.noSelection == -1)
    }

    @Test func choosingALevelAcceptsOnlyTheCatalog() {
        var state = MazeState.initial
        var accepted = state.selectLevel(19)
        #expect(accepted && state.level.id == "lm-20" && state.orientations == state.level.startOrientations)
        let before = state
        for index in [20, -1, Int.max, Int.min] {
            accepted = state.selectLevel(index)
            #expect(!accepted, "level \(index)")
        }
        #expect(state == before)
        #expect(MazeState(levelIndex: 99).levelIndex == 19 && MazeState(levelIndex: -5).levelIndex == 0)
    }

    @Test func selectingTurningAndResetting() {
        var state = MazeState.initial
        var accepted = state.turnSelected()
        #expect(!accepted, "nothing selected")
        accepted = state.selectTile(1) || state.selectTile(-1)
        #expect(!accepted && state.selection == -1)
        accepted = state.selectTile(0)
        #expect(accepted && state.selection == 0 && state.selectedTileIndex == 2)
        accepted = state.turnSelected()
        #expect(accepted)
        #expect(state.orientations == LevelCatalog.bundled.levels[0].solution)
        #expect(state.isSolved && state.beam.litTargets == [Cell(2, 4)])
        #expect(state.board.tiles[2].orientation == .slash)
        accepted = state.turnSelected()
        #expect(accepted && !state.isSolved, "turning back unsolves")
        state.turnSelected()
        state.reset()
        #expect(state == MazeState.initial)
        state.selectLevel(15)
        state.selectTile(1)
        state.selectLevel(15)
        #expect(state.selection == -1, "choosing a level clears the selection")
    }

    @Test func everyLevelIsSolvedByTurningToItsSolution() {
        for index in 0..<20 {
            var state = MazeState(levelIndex: index)
            let solution = state.level.solution
            for position in 0..<solution.count where state.orientations[position] != solution[position] {
                state.selectTile(position)
                state.turnSelected()
            }
            #expect(state.isSolved, "level \(index + 1)")
        }
    }

    @Test func theJSONRoundTripIsExactAndSorted() throws {
        var state = MazeState(levelIndex: 9)
        state.selectTile(3)
        state.turnSelected()
        let data = state.encoded()
        #expect(MazeState.decode(data) == .success(state))
        let text = String(decoding: data, as: UTF8.self)
        #expect(text.hasPrefix(#"{"levelIndex":9,"orientations":["#))
        #expect(text.hasSuffix(#"],"schema":1,"selection":3}"#))
        #expect(MazeState.decode(MazeState.initial.encoded()) == .success(MazeState.initial))
    }

    @Test func damagedAndNewerPayloadsAreRefused() {
        let one = #"["backslash"]"#
        let damaged: [String] = [
            "not json",
            #"{"levelIndex":0,"orientations":["backslash"],"schema":1,"selection":-1"#,
            #"{"levelIndex":0,"orientations":["backslash"],"selection":-1}"#,
            #"{"levelIndex":0,"orientations":["backslash"],"schema":"1","selection":-1}"#,
            #"{"levelIndex":0,"orientations":["backslash"],"schema":0,"selection":-1}"#,
            #"{"orientations":\#(one),"schema":1,"selection":-1}"#,
            #"{"levelIndex":20,"orientations":\#(one),"schema":1,"selection":-1}"#,
            #"{"levelIndex":-1,"orientations":\#(one),"schema":1,"selection":-1}"#,
            #"{"levelIndex":0,"orientations":[],"schema":1,"selection":-1}"#,
            #"{"levelIndex":0,"orientations":["slash","slash"],"schema":1,"selection":-1}"#,
            #"{"levelIndex":0,"orientations":["sideways"],"schema":1,"selection":-1}"#,
            #"{"levelIndex":0,"orientations":\#(one),"schema":1,"selection":1}"#,
            #"{"levelIndex":0,"orientations":\#(one),"schema":1,"selection":-2}"#,
            #"{"levelIndex":0,"orientations":\#(one),"schema":1}"#,
        ]
        for payload in damaged {
            #expect(MazeState.decode(Data(payload.utf8)) == .failure(.damaged), "\(payload)")
        }
        let newer: [String] = [
            #"{"levelIndex":0,"orientations":\#(one),"schema":2,"selection":-1}"#,
            #"{"schema":7}"#,
        ]
        for payload in newer {
            #expect(MazeState.decode(Data(payload.utf8)) == .failure(.newerVersion), "\(payload)")
        }
        let valid = #"{"levelIndex":0,"orientations":["slash"],"schema":1,"selection":0}"#
        guard case .success(let state) = MazeState.decode(Data(valid.utf8)) else {
            Issue.record("a valid payload decodes")
            return
        }
        #expect(state.isSolved && state.selection == 0)
        #expect(MazeStateRefusal.allCases.map(\.rawValue) == ["damaged", "newer-version"])
    }
}
