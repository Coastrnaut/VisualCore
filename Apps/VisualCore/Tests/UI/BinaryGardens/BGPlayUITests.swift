// BGPlayUITests — feature 509 (R02-G21-09) T-R02G2109-004, modelled on feature 499 (FR-R02G2109-002, 007;
// SC-R02G2109-001; clarifications Q1, Q2): Binary Gardens (R02-G21) played in the one app. A fresh start (erased data,
// `BG.fresh`) opens level 1 not won, with its budget of 9 whole (the header `actions` reads "Level 1 · 9 of 9 actions
// left"), the panel on star 1 (the `star` value "star 1 of 2") and the tutorial shown; the tutorial is dismissed and
// level 1's certified plan (pinned in `BG.levelOnePlan` from docs/games/binary-gardens/levels/001.witness.json: star 2's
// luminosity down one level, from index 1 to index 0, then the run) is played with the panel: Star 2 is chosen until the
// `star` value reads "star 2 of 2" (presentation only, no action spent, a lost tap retried); the `luminosity` value
// reads "level 2 of 2, luminosity 27"; Luminosity − is pressed, counting only when the actions-left count of the
// header's `actions` text moves from 9 to 8 (a lost tap retried a bounded number of times, never once the value moved),
// and the value then reads "level 1 of 2, luminosity 19"; finally Run ends the level without spending an action. The
// canvas description (`BinaryGardensPresenter.describe`) reports "Every world kept its window and bloomed." and the
// `stars` text reads "Best: 3 of 3 stars" (one action, the certified count); the level picker then steps to level 2 and
// no further (the frontier), and level 1 reads "Level 1, band 1, 3 of 3 stars". After a relaunch without the reset
// (`BG.reopen`, which backgrounds the app before it ends it) the stored progress is read from the level picker: level 2
// is still reachable and level 1 keeps its three stars. Short bounded waits; each test under 90 s apart from the
// automation-session setup of each launch. System accessibility audits wait for the device campaign (owner ruling of
// 2026-11-13).
import XCTest

final class BGPlayUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    /// Level 1's certified plan played with Star 2, Luminosity − and Run wins with three stars and opens level 2.
    @MainActor
    func testPlayingLevelOneCertifiedPlanWinsWithThreeStars() {
        let app = BG.winLevelOne()
        XCTAssertEqual(BG.value(app, "next-level"), "level 2", "Next level offers level 2")
        XCTAssertFalse(BG.control(app, "explanation").exists, "a win shows no failure explanation")
        BG.checkLevelPicker(app)
        XCTAssertFalse(element(app, "session.failure").exists, "no failure")
    }

    /// The win survives a relaunch: level 2 stays open and level 1 keeps its three stars.
    @MainActor
    func testProgressSurvivesARelaunch() {
        let first = BG.winLevelOne()
        let app = BG.reopen(first)
        BG.checkLevelPicker(app)
        XCTAssertFalse(element(app, "session.failure").exists, "no failure")
    }
}

extension BG {
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
