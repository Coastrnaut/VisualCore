// MAPlayUITests — feature 489 (R02-G19-09) T-R02G1909-004, modelled on feature 479 (FR-R02G1909-002, 007;
// SC-R02G1909-001; clarifications Q1, Q2; research R2): Microscopic Aurora (R02-G19) played in the one app. A fresh
// start (erased data, `MA.fresh`) opens level 1 not won, with its budget of 9 whole (the header `actions` reads "Level
// 1 · 9 of 9 actions left"), the panel on well 1, the first site (row 9, column 7), strength 2 and counterclockwise,
// and the tutorial shown; the tutorial is dismissed and level 1's certified wells (pinned in `MA.levelOnePlan` from
// `MicroscopicAuroraExperienceCore.certifiedActions(1)`: one well in slot 0 at row 11, column 18, strength 2,
// clockwise, then the play) are placed with the panel: Well − or + until the `slot` value reads "well k", Site − or +
// until the `site` value names the target site ("site at row r, column c"), Strength − or + until the `strength` value
// reads "strength s", the sense toggle until its value names the sense (all presentation only, no action spent, a lost
// tap retried), then Place, the press counting only when the header's `actions` text changes with the actions left down
// by one (a lost tap is retried a bounded number of times); finally Play ends the level without spending an action. The
// canvas description (`MicroscopicAuroraPresenter.describe`) reports "The trails covered the stencil as one pattern."
// and the `stars` text reads "Best: 3 of 3 stars" (one placement, the certified count); the level picker then steps to
// level 2 and no further (the frontier), and level 1 reads "Level 1, band 1, 3 of 3 stars". After a relaunch without
// the reset (`MA.reopen`, which backgrounds the app before it ends it) the stored progress is read from the level
// picker: level 2 is still reachable and level 1 keeps its three stars. Short bounded waits; each test under 90 s apart
// from the automation-session setup of each launch. System accessibility audits wait for the device campaign (owner
// ruling of 2026-11-13).
import XCTest

final class MAPlayUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    /// Level 1's certified wells placed with Well −/+, Site −/+, Strength −/+, the sense toggle, Place and Play win
    /// with three stars and open level 2.
    @MainActor
    func testPlayingLevelOneCertifiedWellsWinsWithThreeStars() {
        let app = MA.winLevelOne()
        XCTAssertEqual(MA.value(app, "next-level"), "level 2", "Next level offers level 2")
        XCTAssertFalse(MA.control(app, "explanation").exists, "a win shows no failure explanation")
        MA.checkLevelPicker(app)
        XCTAssertFalse(element(app, "session.failure").exists, "no failure")
    }

    /// The win survives a relaunch: level 2 stays open and level 1 keeps its three stars.
    @MainActor
    func testProgressSurvivesARelaunch() {
        let first = MA.winLevelOne()
        let app = MA.reopen(first)
        MA.checkLevelPicker(app)
        XCTAssertFalse(element(app, "session.failure").exists, "no failure")
    }
}

extension MA {
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
