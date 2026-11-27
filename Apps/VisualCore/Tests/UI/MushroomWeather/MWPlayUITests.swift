// MWPlayUITests — feature 499 (R02-G20-09) T-R02G2009-004, modelled on feature 489 (FR-R02G2009-002, 007;
// SC-R02G2009-001; clarifications Q1, Q2): Mushroom Weather (R02-G20) played in the one app. A fresh start (erased
// data, `MW.fresh`) opens level 1 not won, with its budget of 9 whole (the header `actions` reads "Level 1 · 9 of 9
// actions left"), the panel on pod 1 and the first site (row 0, column 4), vent 1 open, and the tutorial shown; the
// tutorial is dismissed and level 1's certified plan (pinned in `MW.levelOnePlan` from
// docs/games/mushroom-weather/levels/001.witness.json: a pod in slot 0 at row 2, column 5, then vent 1 (index 0)
// closed, then the run) is played with the panel: Slot − or + until the `slot` value reads "pod k", Site − or + until
// the `site` value names the target site ("site at row r, column c"; both presentation only, no action spent, a lost
// tap retried), then Place, the press counting only when the header's `actions` text changes with the actions left
// down by one; then vent 1's toggle (`vent-0`) until its value reads "closed", counted the same way (a lost tap is
// retried a bounded number of times, never once the value moved); finally Run ends the level without spending an
// action. The canvas description (`MushroomWeatherPresenter.describe`) reports "Every colony ended the run in its band."
// and the `stars` text reads "Best: 3 of 3 stars" (two actions, the certified count); the level picker then steps to
// level 2 and no further (the frontier), and level 1 reads "Level 1, band 1, 3 of 3 stars". After a relaunch without
// the reset (`MW.reopen`, which backgrounds the app before it ends it) the stored progress is read from the level
// picker: level 2 is still reachable and level 1 keeps its three stars. Short bounded waits; each test under 90 s apart
// from the automation-session setup of each launch. System accessibility audits wait for the device campaign (owner
// ruling of 2026-11-13).
import XCTest

final class MWPlayUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    /// Level 1's certified plan played with Slot −/+, Site −/+, Place, vent 1's toggle and Run wins with three stars
    /// and opens level 2.
    @MainActor
    func testPlayingLevelOneCertifiedPlanWinsWithThreeStars() {
        let app = MW.winLevelOne()
        XCTAssertEqual(MW.value(app, "next-level"), "level 2", "Next level offers level 2")
        XCTAssertFalse(MW.control(app, "explanation").exists, "a win shows no failure explanation")
        MW.checkLevelPicker(app)
        XCTAssertFalse(element(app, "session.failure").exists, "no failure")
    }

    /// The win survives a relaunch: level 2 stays open and level 1 keeps its three stars.
    @MainActor
    func testProgressSurvivesARelaunch() {
        let first = MW.winLevelOne()
        let app = MW.reopen(first)
        MW.checkLevelPicker(app)
        XCTAssertFalse(element(app, "session.failure").exists, "no failure")
    }
}

extension MW {
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
