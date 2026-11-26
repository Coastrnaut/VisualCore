// AWPlayUITests — feature 479 (R02-G18-09) T-R02G1809-004, modelled on feature 469 (FR-R02G1809-002; SC-R02G1809-001;
// clarifications Q1, Q2): Apsides Workshop (R02-G18) played in the one app. A fresh start (erased data, `AW.fresh`)
// opens level 1 not won, with its budget of 9 whole (the header `actions` reads "Level 1 · 9 of 9 actions left"), the
// orbit at size 18, eccentricity step 10 (0.50) and direction step 6 (90°), and the tutorial shown; the tutorial is
// dismissed and level 1's certified plan (pinned in `AW.levelOnePlan` from the stored witness: one periapsis tuning to
// eccentricity step 0 and direction step 0, then the play) is played with the panel: the pending eccentricity is moved
// with Eccentricity − or + while it is read from the `eccentricity` control's value ("pending eccentricity 0.ee"), the
// pending direction with Direction − or + read from the `direction` control's value ("pending periapsis at d°"; both
// presentation only, no action spent, a lost tap retried), then Set periapsis is pressed, the press counting only when
// the header's actions left moves down by one (a lost tap is retried a bounded number of times); finally Play ends the
// level without spending an action. The canvas description (`ApsidesWorkshopPresenter.describe`) reports "Every target
// was met in order without striking a planet." and the `stars` text reads "Best: 3 of 3 stars" (one tuning, the
// certified count); the level picker then steps to level 2 and no further (the frontier), and level 1 reads "Level 1,
// band 1, 3 of 3 stars". After a relaunch without the reset (`AW.reopen`, which backgrounds the app before it ends it)
// the stored progress is read from the level picker: level 2 is still reachable and level 1 keeps its three stars.
// Short bounded waits; each test under 90 s apart from the automation-session setup of each launch. System
// accessibility audits wait for the device campaign (owner ruling of 2026-11-13).
import XCTest

final class AWPlayUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    /// Level 1's certified plan played with Eccentricity −/+, Direction −/+, Set periapsis and Play wins with three
    /// stars and opens level 2.
    @MainActor
    func testPlayingLevelOneCertifiedPlanWinsWithThreeStars() {
        let app = AW.winLevelOne()
        XCTAssertEqual(AW.value(app, "next-level"), "level 2", "Next level offers level 2")
        AW.checkLevelPicker(app)
        XCTAssertFalse(element(app, "session.failure").exists, "no failure")
    }

    /// The win survives a relaunch: level 2 stays open and level 1 keeps its three stars.
    @MainActor
    func testProgressSurvivesARelaunch() {
        let first = AW.winLevelOne()
        let app = AW.reopen(first)
        AW.checkLevelPicker(app)
        XCTAssertFalse(element(app, "session.failure").exists, "no failure")
    }
}

extension AW {
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
