// MazeFeedbackTests — feature 099 (A13-P04) T-A13-407 (FR-A13-420, FR-A13-421; SC-A13-403; clarification Q3; research
// D3–D5; contract contracts/feedback.md "Success cue"). The success cue through the session host and the presenter,
// short runs and synthetic frame times only (no wall-clock assertion):
//   - one cue per transition to solved (words, sweep, `success` haptic), none on further frames of the solved board;
//     again after an undo and a new solve, with the haptic dropped inside the route's rate limit;
//   - the words name the level, the moves and the level that opened; with VoiceOver off they are kept and shown but
//     not posted;
//   - the border brightens once over 0.6 s of frame time and settles; Reduce Motion and Reduce Flashing keep it at 1;
//   - the solved board carries a border and a tick, an unsolved one neither;
//   - suspension stops the sound and ends the brightening.
import Foundation
import XCTest
@testable import LightMazeExperience
import LightMazeCore
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreSimulation
import VisualCoreUI

/// A clock the tests move by hand.
@MainActor
private final class ManualClock {
    var now = 100.0
}

@MainActor
final class MazeFeedbackTests: XCTestCase {
    private func action(_ control: String, _ values: [Double] = []) -> ExperienceAction {
        ExperienceAction(control: control, values: values, step: 0)
    }

    /// Level 1 solved (its one recorded turn).
    private func solvedLevelOne() -> MazeCore {
        MazeCore.played(seed: 1, entries: MazeCore.fixtureEntries(level: 0))
    }

    func testOneCuePerSolveWithWordsSoundAndRateLimitedHaptic() async throws {
        let sound = RecordingMazeSoundSink()
        let haptics = RecordingHapticSink()
        let clock = ManualClock()
        let route = ExperienceFeedback(hapticSink: haptics, announcementSink: RecordingAnnouncementSink(),
                                       clock: { clock.now }, voiceOverRunning: { false })
        let announcements = RecordingAnnouncementSink()
        let session = ExperienceSession()
        let shell = try await MazeTest.open(session, voiceOverRunning: { false }, announcementSink: announcements,
                                            soundSink: sound, feedback: route)
        let presenter = shell.presenter
        XCTAssertTrue(shell.handle(control: "tile.select", values: [0]).isAccepted)
        XCTAssertTrue(shell.handle(control: "tile.turn").isAccepted)
        try MazeTest.frames(session, 1)
        XCTAssertTrue(try MazeTest.core(shell).isSolved)
        XCTAssertEqual(presenter.cuesPlayed, 1)
        XCTAssertEqual(sound.successes, 1)
        XCTAssertEqual(haptics.played, [.success])
        let words = "Level 1 solved in 1 move. Level 2 is open."
        XCTAssertEqual(presenter.spoken.last, words)
        XCTAssertEqual(presenter.mirror.message, words)
        XCTAssertEqual(announcements.announced.filter { $0 == words }, [], "not posted while VoiceOver is off")

        try MazeTest.frames(session, 3)
        XCTAssertEqual(presenter.cuesPlayed, 1, "further frames of the solved board play nothing")

        XCTAssertTrue(shell.handle(control: "move.undo").isAccepted)
        try MazeTest.frames(session, 1)
        XCTAssertTrue(shell.handle(control: "tile.turn").isAccepted)
        try MazeTest.frames(session, 1)
        XCTAssertEqual(presenter.cuesPlayed, 2, "a new solve plays the cue again")
        XCTAssertEqual(sound.successes, 2)
        XCTAssertEqual(presenter.spoken.last, "Level 1 solved in 1 move.", "level 2 was already open")
        XCTAssertEqual(haptics.played, [.success], "the second haptic falls inside the rate limit")

        XCTAssertTrue(shell.handle(control: "move.undo").isAccepted)
        try MazeTest.frames(session, 1)
        clock.now += 1
        XCTAssertTrue(shell.handle(control: "tile.turn").isAccepted)
        try MazeTest.frames(session, 1)
        XCTAssertEqual(haptics.played, [.success, .success], "outside the interval it plays")
        session.close()
    }

    func testTheBorderBrightensOnceAndReduceFlagsKeepItStatic() {
        let solved = solvedLevelOne()
        let unsolved = MazeCore(seed: 1)
        for flags in [(false, false), (true, false), (false, true)] {
            let presenter = MazePresenter(experienceID: MazeTest.id, voiceOverRunning: { false },
                                          announcementSink: RecordingAnnouncementSink(),
                                          reduceMotion: flags.0, reduceFlashing: flags.1,
                                          soundSink: RecordingMazeSoundSink(),
                                          feedback: ExperienceFeedback(hapticSink: RecordingHapticSink()))
            presenter.recordSolve(unsolved)
            presenter.recordSolve(solved)
            XCTAssertEqual(presenter.cuesPlayed, 1)
            var highest = 1.0
            var rises = 0, falls = 0
            var previous = presenter.borderBrightness(solved: true)
            for _ in 0..<16 {
                presenter.advanceCueClock(0.05)
                let value = presenter.borderBrightness(solved: true)
                highest = max(highest, value)
                if value > previous { rises += 1 }
                if value < previous { falls += 1 }
                previous = value
            }
            if flags.0 || flags.1 {
                XCTAssertEqual(highest, 1, "static under Reduce Motion or Reduce Flashing")
            } else {
                XCTAssertGreaterThan(highest, 1.4)
                XCTAssertLessThanOrEqual(highest, SuccessCue.peak)
                XCTAssertGreaterThan(rises, 0)
                XCTAssertGreaterThan(falls, 0)
            }
            XCTAssertEqual(previous, 1, "settled after 0.6 s")
            XCTAssertNil(presenter.cueStart, "a finished brightening is forgotten")
        }
    }

    func testTheSolvedBoardHasABorderAndTick() {
        let ids = MazePresenter.scene(solvedLevelOne()).children.map(\.id)
        XCTAssertTrue(ids.contains("solved.border"))
        XCTAssertTrue(ids.contains("solved.tick"))
        let plain = MazePresenter.scene(MazeCore(seed: 1)).children.map(\.id)
        XCTAssertFalse(plain.contains("solved.border"))
        XCTAssertFalse(plain.contains("solved.tick"))
    }

    func testSuspensionStopsTheSoundAndEndsTheBrightening() {
        let sound = RecordingMazeSoundSink()
        let presenter = MazePresenter(experienceID: MazeTest.id, voiceOverRunning: { false },
                                      announcementSink: RecordingAnnouncementSink(), soundSink: sound,
                                      feedback: ExperienceFeedback(hapticSink: RecordingHapticSink()))
        presenter.recordSolve(MazeCore(seed: 1))
        presenter.recordSolve(solvedLevelOne())
        XCTAssertNotNil(presenter.cueStart)
        presenter.suspended()
        XCTAssertEqual(sound.stops, 1)
        XCTAssertNil(presenter.cueStart)
        XCTAssertEqual(presenter.borderBrightness(solved: true), 1, "not replayed")
        XCTAssertEqual(presenter.cuesPlayed, 1)
    }
}
