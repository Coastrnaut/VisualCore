// CELPlayUITests — feature 469 (R02-G17-09) T-R02G1709-004, modelled on feature 459 (FR-R02G1709-002;
// SC-R02G1709-001; clarifications Q1, Q2): Celestial Eclipse Lab (R02-G17) played in the one app. A fresh start (erased
// data, `CEL.fresh`) opens level 1 not won, with its budget of 9 whole (the header `actions` reads "Level 1 · 9 of 9
// actions left") and the tutorial shown; the tutorial is dismissed and level 1's certified plan (pinned in
// `CEL.levelOnePlan` from the stored witness: body 1 to phase 2, then body 2 to phase 0, then the run) is played with
// the panel: each body is chosen with Planet + or Planet − while the chosen body is read from the planet control's
// value (`planet`, "body j, phase p of q"; spending no action), its pending phase is moved with Phase + or Phase − read
// from the phase control's value (`phase`, "pending phase p"; presentation only), then Set phase is pressed, each press
// counting only when the header's actions left moves down by one (a lost tap is retried a bounded number of times);
// finally Run ends the level without spending an action. The canvas description
// (`CelestialEclipseLabPresenter.describe`)
// reports "Every target eclipse came in order inside its window." and the `stars` text reads "Best: 3 of 3 stars" (two
// phase changes, the certified count); the level picker then steps to level 2 and no further (the frontier), and level
// 1 reads "Level 1, band 1, 3 of 3 stars". After a relaunch without the reset (`CEL.reopen`, which backgrounds the app
// before it ends it) the stored progress is read from the level picker: level 2 is still reachable and level 1 keeps
// its three stars. Short bounded waits; each test under 90 s apart from the automation-session setup of each launch.
// System accessibility audits wait for the device campaign (owner ruling of 2026-11-13).
import XCTest

final class CELPlayUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    /// Level 1's certified plan played with Planet +/−, Phase +/−, Set phase and Run wins with three stars and opens
    /// level 2.
    @MainActor
    func testPlayingLevelOneCertifiedPlanWinsWithThreeStars() {
        let app = CEL.winLevelOne()
        XCTAssertEqual(CEL.value(app, "next-level"), "level 2", "Next level offers level 2")
        CEL.checkLevelPicker(app)
        XCTAssertFalse(element(app, "session.failure").exists, "no failure")
    }

    /// The win survives a relaunch: level 2 stays open and level 1 keeps its three stars.
    @MainActor
    func testProgressSurvivesARelaunch() {
        let first = CEL.winLevelOne()
        let app = CEL.reopen(first)
        CEL.checkLevelPicker(app)
        XCTAssertFalse(element(app, "session.failure").exists, "no failure")
    }
}

extension CEL {
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
