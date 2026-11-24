// MMPlayUITests — feature 439 (R02-G14-09) T-R02G1409-004, modelled on feature 429 (FR-R02G1409-002; SC-R02G1409-001;
// clarifications Q1, Q2): Moonlit Mechanism (R02-G14) played inside the one app. A fresh start (erased data,
// `MM.fresh`) opens level 1 not won, with its budget of 9 whole (the header `actions` reads "Level 1 · 9 of 9 actions
// left") and the tutorial shown; the tutorial is dismissed and level 1's certified actions (pinned in
// `MM.levelOneActions` from the stored witness: handle turn +1, lamp step −1, run) are played with the panel: Turn +,
// Lamp − and Run, each press counting only when the header's actions left moves down by one (a lost tap is retried a
// bounded number of times). The canvas description (`MoonlitMechanismPresenter.describe`) reports "The shadows match
// every required key frame." and " Stars: 3 of 3." (three actions, the certified actions); the level picker then steps
// to level 2 and no further (the frontier), and level 1 reads "Level 1, band 1, 3 stars". After a relaunch without the
// reset (`MM.reopen`, which backgrounds the app before it ends it) the stored progress is read from the level picker:
// level 2 is still reachable and level 1 keeps its three stars. Short bounded waits; each test under 90 s apart from
// the automation-session setup of each launch. System accessibility audits wait for the device campaign (owner ruling
// of 2026-11-13).
import XCTest

final class MMPlayUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    /// Level 1's certified actions played with Turn +, Lamp − and Run win with three stars and open level 2.
    @MainActor
    func testPlayingLevelOneCertifiedActionsWinsWithThreeStars() {
        let app = MM.winLevelOne()
        XCTAssertEqual(MM.value(app, "next-level"), "level 2", "Next level offers level 2")
        MM.checkLevelPicker(app)
        XCTAssertFalse(element(app, "session.failure").exists, "no failure")
    }

    /// The win survives a relaunch: level 2 stays open and level 1 keeps its three stars.
    @MainActor
    func testProgressSurvivesARelaunch() {
        let first = MM.winLevelOne()
        let app = MM.reopen(first)
        MM.checkLevelPicker(app)
        XCTAssertFalse(element(app, "session.failure").exists, "no failure")
    }
}

extension MM {
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
