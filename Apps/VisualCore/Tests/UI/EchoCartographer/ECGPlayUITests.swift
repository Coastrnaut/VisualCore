// ECGPlayUITests — feature 409 (R02-G11-09) T-R02G1109-004 (FR-R02G1109-002; SC-R02G1109-001; clarifications Q1,
// Q2):
// Echo Cartographer (R02-G11) played inside the one app. A fresh start (erased data, `ECG.fresh`) opens level 1 with
// its one beacon not located and the column and row steppers on the entry, column 0, row 3 (`ECG.levelOneEntry`, the
// presenter's `EchoCartographerMirror.follow` on a new level); the tutorial is dismissed and level 1's certified
// actions (pinned in `ECG` from the stored witness: pulse at column 0, row 3; pulse at column 0, row 2; claim at
// column 1, row 2)
// are played with the panel: before each action the column stepper, then the row stepper, is stepped from the cursor's
// cell to the action's cell, each read from its value ("column c, row r: known"), then Pulse or Claim. The canvas
// description (`EchoCartographerPresenter.describe`) reports "Every beacon is located." and " Stars: 3 of 3." (two
// pulses, the certified pulses); the level picker then steps to level 2 and no further (the frontier), and level 1
// reads "Level 1, band 1, 3 stars". After a relaunch without the reset (`ECG.reopen`, which backgrounds the app before
// it ends it) the stored progress is read from the level picker: level 2 is still reachable and level 1 keeps its three
// stars. Short bounded waits; each test under 90 s apart from the automation-session setup of each launch. System
// accessibility audits wait for the device campaign (owner ruling of 2026-11-13).
import XCTest

final class ECGPlayUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    /// Level 1's certified actions played with the column and row steppers, Pulse and Claim win with three stars and
    /// open level 2.
    @MainActor
    func testPlayingLevelOneCertifiedActionsWinsWithThreeStars() {
        let app = ECG.winLevelOne()
        XCTAssertTrue(ECG.description(app).contains(ECG.allLocated),
                      "the solution located the beacon: \(ECG.description(app))")
        ECG.checkLevelPicker(app)
        XCTAssertFalse(element(app, "session.failure").exists, "no failure")
    }

    /// The win survives a relaunch: level 2 stays open and level 1 keeps its three stars.
    @MainActor
    func testProgressSurvivesARelaunch() {
        let first = ECG.winLevelOne()
        let app = ECG.reopen(first)
        ECG.checkLevelPicker(app)
        XCTAssertFalse(element(app, "session.failure").exists, "no failure")
    }
}

extension ECG {
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
