// VOPlayUITests — feature 449 (R02-G15-09) T-R02G1509-004, modelled on feature 439 (FR-R02G1509-002; SC-R02G1509-001;
// clarifications Q1, Q2): Voxel Origami (R02-G15) played inside the one app. A fresh start (erased data, `VO.fresh`)
// opens level 1 not won, with its budget of 9 whole (the header `actions` reads "Level 1 · 9 of 9 actions left") and
// the tutorial shown; the tutorial is dismissed and level 1's certified turns (pinned in `VO.levelOneTurns` from the
// stored witness: hinge 4 by −1, twice) are played with the panel: hinge 4 is chosen with Hinge + or Hinge − while the
// chosen hinge is read from the hinge control (`hinge`, "hinge h"; spending no action), then Turn − is pressed, each
// press counting only when the header's actions left moves down by one (a lost tap is retried a bounded number of
// times). The canvas description (`VoxelOrigamiPresenter.describe`) reports "The chain matches the target shape." and
// " Stars: 3 of 3." (two turns, the certified turns); the level picker then steps to level 2 and no further (the
// frontier), and level 1 reads "Level 1, band 1, 3 stars". After a relaunch without the reset (`VO.reopen`, which
// backgrounds the app before it ends it) the stored progress is read from the level picker: level 2 is still
// reachable and level 1 keeps its three stars. Short bounded waits; each test under 90 s apart from the
// automation-session setup of each launch. System accessibility audits wait for the device campaign (owner ruling of
// 2026-11-13).
import XCTest

final class VOPlayUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    /// Level 1's certified turns played with Hinge +/− and Turn − win with three stars and open level 2.
    @MainActor
    func testPlayingLevelOneCertifiedTurnsWinsWithThreeStars() {
        let app = VO.winLevelOne()
        XCTAssertEqual(VO.value(app, "next-level"), "level 2", "Next level offers level 2")
        VO.checkLevelPicker(app)
        XCTAssertFalse(element(app, "session.failure").exists, "no failure")
    }

    /// The win survives a relaunch: level 2 stays open and level 1 keeps its three stars.
    @MainActor
    func testProgressSurvivesARelaunch() {
        let first = VO.winLevelOne()
        let app = VO.reopen(first)
        VO.checkLevelPicker(app)
        XCTAssertFalse(element(app, "session.failure").exists, "no failure")
    }
}

extension VO {
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
