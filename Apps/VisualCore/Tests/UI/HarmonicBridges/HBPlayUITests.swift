// HBPlayUITests — feature 419 (R02-G12-09) T-R02G1209-004 (FR-R02G1209-002; SC-R02G1209-001; clarifications Q1,
// Q2):
// Harmonic Bridges (R02-G12) played inside the one app. A fresh start (erased data, `HB.fresh`) opens level 1 with its
// goal not reached, its budget of 9 whole and the string and peg steppers on string 0 at its current peg 11
// (`HB.levelOneOpening`, the presenter's `HarmonicBridgesMirror.follow` on a new level); the tutorial is dismissed and
// level 1's certified actions (pinned in `HB` from the stored witness: tune string 0 to peg 12, then test) are played
// with the panel: the string stepper, then the peg stepper, is stepped from its value ("string i, island a to island
// b, peg p", "peg p[, the current peg]") to the tuning's string and peg, a press counting only when the value moves,
// then Tune, then Test. The canvas description (`HarmonicBridgesPresenter.describe`) reports "The crossing holds in
// every step." and " Stars: 3 of 3." (two actions, the certified actions); the level picker then steps to level 2 and
// no further (the frontier), and level 1 reads "Level 1, band 1, 3 stars". After a relaunch without the reset
// (`HB.reopen`, which backgrounds the app before it ends it) the stored progress is read from the level picker: level
// 2 is still reachable and level 1 keeps its three stars. Short bounded waits; each test under 90 s apart from the
// automation-session setup of each launch. System accessibility audits wait for the device campaign (owner ruling of
// 2026-11-13).
import XCTest

final class HBPlayUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    /// Level 1's certified tuning played with the string and peg steppers, Tune and Test win with three stars and open
    /// level 2.
    @MainActor
    func testPlayingLevelOneCertifiedActionsWinsWithThreeStars() {
        let app = HB.winLevelOne()
        XCTAssertFalse(HB.description(app).contains(HB.notReached),
                       "the solution reached the goal in every step: \(HB.description(app))")
        HB.checkLevelPicker(app)
        XCTAssertFalse(element(app, "session.failure").exists, "no failure")
    }

    /// The win survives a relaunch: level 2 stays open and level 1 keeps its three stars.
    @MainActor
    func testProgressSurvivesARelaunch() {
        let first = HB.winLevelOne()
        let app = HB.reopen(first)
        HB.checkLevelPicker(app)
        XCTAssertFalse(element(app, "session.failure").exists, "no failure")
    }
}

extension HB {
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
