// MazeHintTests — feature 099 (A13-P04) T-A13-406 (FR-A13-401, FR-A13-402, FR-A13-410, FR-A13-411; SC-A13-401,
// SC-A13-402; clarifications Q1, Q2 and Q5; contract contracts/feedback.md). Hints and the spoken board through the
// engine, the session host and the presenter, short runs only (each test well under 10 s):
//   - `hint.show` selects the first tile that differs from the recorded solution, changes no move, and is refused with
//     `a13.already-solved` on a solved board;
//   - following hints through the engine (hint, then turn) solves every one of the 20 levels within its turnable count;
//   - the Hint control answers "Hint: turn the mirror at row R, column C." (columns from the left, rows from the bottom)
//     or "Level 1 is already solved.", keeps the words and shows them, and posts them only while VoiceOver runs;
//   - Describe shows and speaks `BoardDescription.full`; the canvas description carries the count of lit targets.
import Foundation
import XCTest
@testable import LightMazeExperience
import LightMazeCore
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreUI

@MainActor
final class MazeHintTests: XCTestCase {
    private func action(_ control: String, _ values: [Double] = []) -> ExperienceAction {
        ExperienceAction(control: control, values: values, step: 0)
    }

    func testHintSelectsTheFirstDifferingTileAndIsRefusedWhenSolved() {
        var core = MazeCore(seed: 1)
        let expected = Hint.tile(for: core.state)
        XCTAssertNotNil(expected, "level 1 starts unsolved")
        XCTAssertTrue(core.apply(action("hint.show")).isAccepted)
        XCTAssertEqual(core.state.selection, expected)
        XCTAssertEqual(core.state.moves.count, 0, "a hint is not a move")
        XCTAssertTrue(core.apply(action("tile.turn")).isAccepted)
        XCTAssertTrue(core.isSolved)
        let before = core
        XCTAssertEqual(core.apply(action("hint.show")), .rejected(.rule(code: MazeRule.alreadySolved)))
        XCTAssertEqual(core, before, "a refused hint changes nothing")
        XCTAssertTrue(MazeCore.actionIDs.contains("hint.show"))
    }

    func testFollowingHintsSolvesEveryLevel() {
        for level in 0..<MazeCore.levelCount {
            var core = MazeCore(seed: 1)
            XCTAssertTrue(core.apply(action("level.select", [Double(level)])).isAccepted)
            let limit = core.level.turnableCount
            var hints = 0
            while !core.isSolved && hints <= limit {
                XCTAssertTrue(core.apply(action("hint.show")).isAccepted, "level \(level + 1) hint \(hints + 1)")
                XCTAssertTrue(core.apply(action("tile.turn")).isAccepted)
                hints += 1
            }
            XCTAssertTrue(core.isSolved, "level \(level + 1) solved by hints")
            XCTAssertLessThanOrEqual(hints, limit, "level \(level + 1) within its turnable count")
        }
    }

    func testTheHintControlAnswersInWordsAndKeepsThemWithVoiceOverOff() async throws {
        let sink = RecordingAnnouncementSink()
        let session = ExperienceSession()
        let shell = try await MazeTest.open(session, voiceOverRunning: { false }, announcementSink: sink,
                                            soundSink: RecordingMazeSoundSink(),
                                            feedback: ExperienceFeedback(hapticSink: RecordingHapticSink()))
        let presenter = shell.presenter
        let start = try MazeTest.core(shell)
        let tile = try XCTUnwrap(Hint.tile(for: start.state))
        let cell = start.board.tiles[start.board.turnableIndices[tile]].cell
        let words = presenter.showHint(port: shell.port)
        XCTAssertEqual(words, "Hint: turn the mirror at row \(cell.row + 1), column \(cell.column + 1).")
        XCTAssertEqual(presenter.mirror.message, words)
        XCTAssertEqual(presenter.spoken.last, words, "kept with VoiceOver off")
        XCTAssertEqual(sink.announced, [], "nothing is posted while VoiceOver is off")
        XCTAssertEqual(try MazeTest.core(shell).state.selection, tile)

        XCTAssertTrue(shell.handle(control: "tile.turn").isAccepted)
        try MazeTest.frames(session, 1)
        XCTAssertEqual(presenter.showHint(port: shell.port), "Level 1 is already solved.")
        XCTAssertEqual(MazePresenter.answerWords(control: "hint.show",
                                                 result: .rejected(.rule(code: MazeRule.alreadySolved))),
                       "This level is already solved.")
        session.close()
    }

    func testDescribeSpeaksTheFullBoardAndTheSummaryCountsLitTargets() async throws {
        let sink = RecordingAnnouncementSink()
        let session = ExperienceSession()
        let shell = try await MazeTest.open(session, voiceOverRunning: { true }, announcementSink: sink,
                                            soundSink: RecordingMazeSoundSink(),
                                            feedback: ExperienceFeedback(hapticSink: RecordingHapticSink()))
        let presenter = shell.presenter
        let core = try MazeTest.core(shell)
        let expected = BoardDescription.full(levelName: core.level.name, levelNumber: 1, board: core.board,
                                             beam: core.beam)
        XCTAssertEqual(presenter.describeBoard(), expected)
        XCTAssertEqual(presenter.mirror.message, expected)
        XCTAssertEqual(presenter.spoken.last, expected)
        XCTAssertEqual(sink.announced.last, expected, "posted while VoiceOver runs")
        XCTAssertLessThanOrEqual(expected.count, BoardDescription.maxLength)
        XCTAssertTrue(shell.accessibilitySummary.contains("0 of 1 target lit; not solved."))
        XCTAssertTrue(presenter.nativeActions.contains("hint.show"))
        session.close()
    }
}
