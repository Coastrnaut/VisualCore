// CRPlayUITests — feature 359 (R02-G06-09) T-R02G0609-004 (FR-R02G0609-001, 002; SC-R02G0609-001; clarifications Q1,
// Q2): Chrono Constellator (R02-G06) played inside the one app. A fresh start (erased data, `CR.fresh`) opens level 1
// at tick 0 with its budget; the tutorial is dismissed and level 1's certified solution (pinned in `CR`: star 1 from
// its default phase 7 to phase 8 of its 10-cell loop, then the 145 ticks) is played with the panel: the star picker on
// "Star 1 (ring)", Phase + once (the shorter way round), then Run. The canvas description
// (`ChronoConstellatorPresenter.describe`) reports "Every star stands on its target." at tick 3 and " Stars: 3 of 3."
// (1 edit in use, the certified smallest); the level picker then steps to level 2 and no further (the frontier), and
// level 1 reads "Level 1, band 1, 3 stars". After a relaunch without the reset (`CR.reopen`, which backgrounds the app
// before it ends it) the stored progress is read from the level picker: level 2 is still reachable and level 1 keeps
// its three stars. Short bounded waits; each test under 90 s. System accessibility audits wait for the device campaign
// (owner ruling of 2026-11-13).
import XCTest

final class CRPlayUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    /// Level 1's certified solution played with the star picker, Phase ± and Run wins with three stars and opens
    /// level 2.
    @MainActor
    func testPlayingLevelOneCertifiedSolutionWinsWithThreeStars() {
        let app = CR.winLevelOne()
        XCTAssertTrue(CR.description(app).contains("Tick \(CR.levelOneWinTick) of \(CR.levelOneTickLimit);"),
                      "the play is won at tick \(CR.levelOneWinTick): \(CR.description(app))")
        let left = CR.levelOneBudget - CR.levelOneSmallest
        XCTAssertTrue(CR.description(app).contains("; \(left) edits left."),
                      "the solution spent the certified smallest: \(CR.description(app))")
        CR.checkLevelPicker(app)
        XCTAssertFalse(element(app, "session.failure").exists, "no failure")
    }

    /// The win survives a relaunch: level 2 stays open and level 1 keeps its three stars.
    @MainActor
    func testProgressSurvivesARelaunch() {
        let first = CR.winLevelOne()
        let app = CR.reopen(first)
        CR.checkLevelPicker(app)
        XCTAssertFalse(element(app, "session.failure").exists, "no failure")
    }
}

extension CR {
    /// Checks the progress through the level picker: it steps to level 2 and no further (level 2 is the frontier), and
    /// back to level 1, which shows its three stars.
    @MainActor
    static func checkLevelPicker(_ app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        let two = pickLevel(app, 2, file: file, line: line)
        XCTAssertTrue(two.hasPrefix("Level 2, band"), "the level picker reaches level 2: \(two)", file: file,
                      line: line)
        let beyond = press(app, "level-picker", up: true)
        XCTAssertTrue(beyond.hasPrefix("Level 2, band"), "the level picker stops at the frontier: \(beyond)",
                      file: file, line: line)
        let one = pickLevel(app, 1, file: file, line: line)
        XCTAssertEqual(one, levelOneThreeStars, "level 1 keeps its three stars", file: file, line: line)
    }
}
