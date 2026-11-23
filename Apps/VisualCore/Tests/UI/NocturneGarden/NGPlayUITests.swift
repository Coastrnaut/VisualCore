// NGPlayUITests — feature 389 (R02-G09-09) T-R02G0909-004 (FR-R02G0909-002; SC-R02G0909-001; clarifications Q1, Q2):
// Nocturne Garden (R02-G09) played inside the one app. A fresh start (erased data, `NG.fresh`) opens level 1 with no
// move spent of its budget of 9 and the pickers on tulip, column 0, row 0, size 2 and sun 2
// (`NG.levelOneStartingPicks`, the Core's `NocturneGardenMirror.follow` on a new level); the tutorial is dismissed
// and level 1's certified moves (pinned in `NG` from the stored witness: a tulip at column 4, row 0, size 2 and a star
// at column 11, row 0, size 2) are played with the panel: before each plant the kind, column, row and size steppers
// are stepped from their current values to the plant's, then Plant (a sun move would step the sun stepper, then Set
// sun). The canvas description (`NocturneGardenPresenter.describe`) reports "The shadow matches the target." and
// " Stars: 3 of 3." (2 moves spent, the certified smallest); the level picker then steps to level 2 and no further
// (the frontier), and level 1 reads "Level 1, band 1, 3 stars". After a relaunch without the reset (`NG.reopen`,
// which backgrounds the app before it ends it) the stored progress is read from the level picker: level 2 is still
// reachable and level 1 keeps its three stars. Short bounded waits; each test under 90 s. System accessibility audits
// wait for the device campaign (owner ruling of 2026-11-13).
import XCTest

final class NGPlayUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    /// Level 1's certified plants played with the kind, column, row and size steppers and Plant win with three stars
    /// and open level 2.
    @MainActor
    func testPlayingLevelOneCertifiedMovesWinsWithThreeStars() {
        let app = NG.winLevelOne()
        XCTAssertTrue(NG.description(app).contains(NG.spent(NG.levelOneSmallest)),
                      "the solution spent the certified smallest: \(NG.description(app))")
        NG.checkLevelPicker(app)
        XCTAssertFalse(element(app, "session.failure").exists, "no failure")
    }

    /// The win survives a relaunch: level 2 stays open and level 1 keeps its three stars.
    @MainActor
    func testProgressSurvivesARelaunch() {
        let first = NG.winLevelOne()
        let app = NG.reopen(first)
        NG.checkLevelPicker(app)
        XCTAssertFalse(element(app, "session.failure").exists, "no failure")
    }
}

extension NG {
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
