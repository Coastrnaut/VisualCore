// AEPlayUITests — feature 369 (R02-G07-09) T-R02G0709-004 (FR-R02G0709-001, 002; SC-R02G0709-001; clarifications Q1,
// Q2): Amethyst Escape (R02-G07) played inside the one app. A fresh start (erased data, `AE.fresh`) opens level 1 with
// no move spent of its budget of 9 and the shell picker on shell 1; the tutorial is dismissed and level 1's certified
// solution (pinned in `AE` from the stored witness: shell 1 turned one sector anticlockwise, then two advances) is
// played with the panel: the shell picker on "Shell 1 (inner)", Turn − once, Advance twice. The canvas description
// (`AmethystEscapePresenter.describe`) reports "The pearl escaped through the exit gap." and " Stars: 3 of 3." (3 moves
// spent, the certified smallest); the level picker then steps to level 2 and no further (the frontier), and level 1
// reads "Level 1, band 1, 3 stars". After a relaunch without the reset (`AE.reopen`, which backgrounds the app before
// it ends it) the stored progress is read from the level picker: level 2 is still reachable and level 1 keeps its
// three stars. Short bounded waits; each test under 90 s. System accessibility audits wait for the device campaign
// (owner ruling of 2026-11-13).
import XCTest

final class AEPlayUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    /// Level 1's certified solution played with the shell picker, Turn ± and Advance wins with three stars and opens
    /// level 2.
    @MainActor
    func testPlayingLevelOneCertifiedSolutionWinsWithThreeStars() {
        let app = AE.winLevelOne()
        XCTAssertTrue(AE.description(app).contains(AE.spent(AE.levelOneSmallest)),
                      "the solution spent the certified smallest: \(AE.description(app))")
        AE.checkLevelPicker(app)
        XCTAssertFalse(element(app, "session.failure").exists, "no failure")
    }

    /// The win survives a relaunch: level 2 stays open and level 1 keeps its three stars.
    @MainActor
    func testProgressSurvivesARelaunch() {
        let first = AE.winLevelOne()
        let app = AE.reopen(first)
        AE.checkLevelPicker(app)
        XCTAssertFalse(element(app, "session.failure").exists, "no failure")
    }
}

extension AE {
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
