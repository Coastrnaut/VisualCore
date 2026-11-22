// CCPlayUITests — feature 349 (R02-G05-09) T-R02G0509-004 (FR-R02G0509-001, 002; clarifications Q1, Q2): Colorfall
// Canyons (R02-G05) played inside the one app. A fresh start (erased data, `CC.fresh`) opens level 1 at tick 0 with its
// budget; the tutorial is dismissed and level 1's certified solution (pinned in `CC`: carve cell 10 twice, then step
// the 120 ticks) is played with the panel: the cell picker stepped forward to "row 2, column 5" and Carve, the picker
// checked and Carve again, then Run. The canvas description (`ColorfallCanyonsPresenter.describe`) reports "Every basin is
// filled with its colours." at tick 17 and " Stars: 3 of 3." (2 actions, the certified smallest); the level picker then
// steps to level 2 and no further (the frontier), and level 1 reads "Level 1, band 1, 3 stars". After a relaunch
// without the reset (`CC.reopen`, which backgrounds the app before it ends it) the stored progress is read from the
// level picker: level 2 is still reachable and level 1 keeps its three stars. Short bounded waits; each test under
// 90 s. System accessibility audits wait for the device campaign (owner ruling of 2026-11-13).
import XCTest

final class CCPlayUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    /// Level 1's certified solution played with the cell picker, Carve and Run wins with three stars and opens level 2.
    @MainActor
    func testPlayingLevelOneCertifiedSolutionWinsWithThreeStars() {
        let app = CC.winLevelOne()
        XCTAssertTrue(CC.description(app).contains("Tick \(CC.levelOneWinTick) of \(CC.levelOneTickLimit);"),
                      "the play is won at tick \(CC.levelOneWinTick): \(CC.description(app))")
        let left = CC.levelOneBudget - CC.levelOneSmallest
        XCTAssertTrue(CC.description(app).contains("; \(left) actions left."),
                      "the solution spent the certified smallest: \(CC.description(app))")
        CC.checkLevelPicker(app)
        XCTAssertFalse(element(app, "session.failure").exists, "no failure")
    }

    /// The win survives a relaunch: level 2 stays open and level 1 keeps its three stars.
    @MainActor
    func testProgressSurvivesARelaunch() {
        let first = CC.winLevelOne()
        let app = CC.reopen(first)
        CC.checkLevelPicker(app)
        XCTAssertFalse(element(app, "session.failure").exists, "no failure")
    }
}

extension CC {
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
