// SCPlayUITests — feature 459 (R02-G16-09) T-R02G1609-004, modelled on feature 449 (FR-R02G1609-002; SC-R02G1609-001;
// clarifications Q1, Q2): Starlit Cartouche (R02-G16) played in the one app. A fresh start (erased data, `SC.fresh`)
// opens level 1 not won, with its budget of 9 whole (the header `actions` reads "Level 1 · 9 of 9 actions left") and
// the tutorial shown; the tutorial is dismissed and level 1's certified legs (pinned in `SC.levelOneLegs` from the
// stored witness: from star 1 to star 4 after 1 beat, then to star 5 after 0 beats) are played with the panel: each
// destination is chosen with Star + or Star − while the chosen star is read from the star control's value (`star`,
// `legLabel`, "star d …"; Star + and Star − skip the ship's own star; spending no action), the wait with Wait + or
// Wait − read from the wait control's value (`wait`, "…, wait w beats"), then Fly is pressed, each press counting only
// when the header's actions left moves down by one (a lost tap is retried a bounded number of times). The canvas
// description (`StarlitCartouchePresenter.describe`) reports "The trail draws the symbol and the ship rests at the
// beacon." and " Stars: 3 of 3." (two legs, the certified legs); the level picker then steps to level 2 and no further
// (the frontier), and level 1 reads "Level 1, band 1, 3 stars". After a relaunch without the reset (`SC.reopen`, which
// backgrounds the app before it ends it) the stored progress is read from the level picker: level 2 is still reachable
// and level 1 keeps its three stars. Short bounded waits; each test under 90 s apart from the automation-session setup
// of each launch. System accessibility audits wait for the device campaign (owner ruling of 2026-11-13).
import XCTest

final class SCPlayUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    /// Level 1's certified legs played with Star +/−, Wait +/− and Fly win with three stars and open level 2.
    @MainActor
    func testPlayingLevelOneCertifiedLegsWinsWithThreeStars() {
        let app = SC.winLevelOne()
        XCTAssertEqual(SC.value(app, "next-level"), "level 2", "Next level offers level 2")
        SC.checkLevelPicker(app)
        XCTAssertFalse(element(app, "session.failure").exists, "no failure")
    }

    /// The win survives a relaunch: level 2 stays open and level 1 keeps its three stars.
    @MainActor
    func testProgressSurvivesARelaunch() {
        let first = SC.winLevelOne()
        let app = SC.reopen(first)
        SC.checkLevelPicker(app)
        XCTAssertFalse(element(app, "session.failure").exists, "no failure")
    }
}

extension SC {
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
