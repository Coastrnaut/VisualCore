// LLPlayUITests — feature 319 (R02-G02-09) T-R02G0209-004 (FR-R02G0209-001, 002; clarifications Q1, Q2): Lissajous
// Labyrinth (R02-G02) played inside the one app. A fresh start (erased data, `LL.fresh`) opens level 1; the tutorial is
// dismissed, level 1's certified solution (pinned in `LL`: phase C 12 → 3) is set as pending values with the panel's
// steppers, by the shorter way round the wrap, and Apply commits it: the canvas description
// (`LissajousLabyrinthPresenter.describe`) reports "The path is safe. 3 of 3 stars." and the level menu's value is
// "Levels 1 to 2 open". After a relaunch without the reset (`LL.reopen`, which backgrounds the app before it ends it)
// the stored progress is read from the level menu: its value still says level 2 is open and it offers "Level 1 · 3
// stars". Short bounded waits; each test under 90 s. System accessibility audits wait for the device campaign (owner
// ruling of 2026-11-13).
import XCTest

final class LLPlayUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    /// Level 1's solution set as pending values and applied wins with three stars and opens level 2.
    @MainActor
    func testApplyingLevelOneSolutionWinsWithThreeStars() {
        let app = LL.winLevelOne()
        XCTAssertTrue(LL.description(app).contains("Actions \(LL.levelOneShortest) of \(LL.levelOneAllowance)."),
                      "Apply spent one action per changed dial: \(LL.description(app))")
        XCTAssertFalse(LL.control(app, "apply").exists, "nothing is pending after Apply")
        XCTAssertTrue(LL.waitForValue(LL.control(app, "level-picker")) { $0 == LL.levelTwoOpen },
                      "the level menu opens level 2: \(LL.value(app, "level-picker"))")
        XCTAssertFalse(element(app, "session.failure").exists, "no failure")
    }

    /// The win survives a relaunch: level 2 stays open and level 1 keeps its three stars.
    @MainActor
    func testProgressSurvivesARelaunch() {
        let first = LL.winLevelOne()
        let app = LL.reopen(first)
        XCTAssertTrue(LL.waitForValue(LL.control(app, "level-picker")) { $0 == LL.levelTwoOpen },
                      "level 2 is still open after the relaunch: \(LL.value(app, "level-picker"))")
        XCTAssertTrue(LL.menuOffers(app, "Level 1 · 3 stars"),
                      "the level menu keeps level 1's three stars: " + LL.description(app))
        XCTAssertFalse(element(app, "session.failure").exists, "no failure")
    }
}
