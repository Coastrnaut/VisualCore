// BAPlayUITests — feature 399 (R02-G10-09) T-R02G1009-004 (FR-R02G1009-002; SC-R02G1009-001; clarifications Q1, Q2):
// Backwards Aurora (R02-G10) played inside the one app. A fresh start (erased data, `BA.fresh`) opens level 1 with no
// reversal spent of its budget of 9 and the start and end steppers on samples 0 and 1 (`BA.openingSection`, the
// presenter's `BackwardsAuroraMirror.follow` on a new level); the tutorial is dismissed and level 1's certified
// reversals (pinned in `BA` from the stored witness: samples 3 … 4, then 8 … 11) are played with the panel: before
// each reversal the end stepper is stepped up first when the target end lies above it, then the start stepper, then
// the end stepper down when still above, each from its current value ("sample k, height h"), then Reverse. The canvas
// description (`BackwardsAuroraPresenter.describe`) reports "Every checkpoint matches and every bend is within the
// limit." and " Stars: 3 of 3." (2 reversals spent, the certified smallest); the level picker then steps to level 2
// and no further (the frontier), and level 1 reads "Level 1, band 1, 3 stars". After a relaunch without the reset
// (`BA.reopen`, which backgrounds the app before it ends it) the stored progress is read from the level picker: level
// 2 is still reachable and level 1 keeps its three stars. Short bounded waits; each test under 90 s apart from the
// automation-session setup of each launch. System accessibility audits wait for the device campaign (owner ruling of
// 2026-11-13).
import XCTest

final class BAPlayUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    /// Level 1's certified reversals played with the start and end steppers and Reverse win with three stars and
    /// open level 2.
    @MainActor
    func testPlayingLevelOneCertifiedReversalsWinsWithThreeStars() {
        let app = BA.winLevelOne()
        XCTAssertTrue(BA.description(app).contains(BA.spent(BA.levelOneSmallest)),
                      "the solution spent the certified smallest: \(BA.description(app))")
        BA.checkLevelPicker(app)
        XCTAssertFalse(element(app, "session.failure").exists, "no failure")
    }

    /// The win survives a relaunch: level 2 stays open and level 1 keeps its three stars.
    @MainActor
    func testProgressSurvivesARelaunch() {
        let first = BA.winLevelOne()
        let app = BA.reopen(first)
        BA.checkLevelPicker(app)
        XCTAssertFalse(element(app, "session.failure").exists, "no failure")
    }
}

extension BA {
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
