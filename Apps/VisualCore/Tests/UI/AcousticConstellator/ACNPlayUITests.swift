// ACNPlayUITests — feature 429 (R02-G13-09) T-R02G1309-004 (FR-R02G1309-002; SC-R02G1309-001; clarifications Q1, Q2):
// Acoustic Constellator (R02-G13) played inside the one app. A fresh start (erased data, `ACN.fresh`) opens level 1 not
// won, with its budget of 9 whole, the tutorial shown and the star and partner steppers on star 0 and partner 1
// (`ACN.levelOneOpening`, the presenter's `AcousticConstellatorMirror.follow` on a new level); the tutorial is
// dismissed and level 1's certified actions (pinned in `ACN` from the stored witness: link stars 0 and 1, then listen)
// are played with the panel: the star stepper, then the partner stepper, is read from its value ("star i, rate r, phase
// p", "star j, rate r, phase p, not linked") and stepped only when it differs from the link's pair, a press counting
// only when the value moves, then Link, then Listen. The canvas description (`AcousticConstellatorPresenter.describe`)
// reports "The symbol rings together." and " Stars: 3 of 3." (two actions, the certified actions); the level picker
// then steps to level 2 and no further (the frontier), and level 1 reads "Level 1, band 1, 3 stars". After a relaunch
// without the reset (`ACN.reopen`, which backgrounds the app before it ends it) the stored progress is read from the
// level picker: level 2 is still reachable and level 1 keeps its three stars. Short bounded waits; each test under 90 s
// apart from the automation-session setup of each launch. System accessibility audits wait for the device campaign
// (owner ruling of 2026-11-13).
import XCTest

final class ACNPlayUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    /// Level 1's certified link played with the star and partner steppers, Link and Listen win with three stars and
    /// open level 2.
    @MainActor
    func testPlayingLevelOneCertifiedActionsWinsWithThreeStars() {
        let app = ACN.winLevelOne()
        XCTAssertTrue(ACN.isLinked(ACN.value(app, "partner")),
                      "the chosen pair stays linked: \(ACN.value(app, "partner"))")
        ACN.checkLevelPicker(app)
        XCTAssertFalse(element(app, "session.failure").exists, "no failure")
    }

    /// The win survives a relaunch: level 2 stays open and level 1 keeps its three stars.
    @MainActor
    func testProgressSurvivesARelaunch() {
        let first = ACN.winLevelOne()
        let app = ACN.reopen(first)
        ACN.checkLevelPicker(app)
        XCTAssertFalse(element(app, "session.failure").exists, "no failure")
    }
}

extension ACN {
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
