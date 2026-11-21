// WKPlayUITests — feature 329 (R02-G03-09) T-R02G0309-004 (FR-R02G0309-001, 002; clarifications Q1, Q2): Wave Knot
// Keeper (R02-G03) played inside the one app. A fresh start (erased data, `WK.fresh`) opens level 1; the tutorial is
// dismissed and level 1's certified solution (pinned in `WK`: point 2 one step right) is played with the panel: the
// point picker selects each move's point by the shorter way round the wrap and the move's direction button moves it.
// The canvas description (`WaveKnotKeeperPresenter.describe`) reports "The knot matches. 3 of 3 stars." and the level
// menu's value is "Levels 1 to 2 open". After a relaunch without the reset (`WK.reopen`, which backgrounds the app
// before it ends it) the stored progress is read from the level menu: its value still says level 2 is open and it
// offers "Level 1 · 3 stars". Short bounded waits; each test under 90 s. System accessibility audits wait for the
// device campaign (owner ruling of 2026-11-13).
import XCTest

final class WKPlayUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    /// Level 1's solution played with the point picker and the direction buttons wins with three stars and opens
    /// level 2.
    @MainActor
    func testPlayingLevelOneSolutionWinsWithThreeStars() {
        let app = WK.winLevelOne()
        XCTAssertTrue(WK.description(app).contains("Moves \(WK.levelOneShortest) of \(WK.levelOneAllowance)."),
                      "each direction tap spent one move: \(WK.description(app))")
        XCTAssertTrue(WK.waitForValue(WK.control(app, "level-picker")) { $0 == WK.levelTwoOpen },
                      "the level menu opens level 2: \(WK.value(app, "level-picker"))")
        XCTAssertFalse(element(app, "session.failure").exists, "no failure")
    }

    /// The win survives a relaunch: level 2 stays open and level 1 keeps its three stars.
    @MainActor
    func testProgressSurvivesARelaunch() {
        let first = WK.winLevelOne()
        let app = WK.reopen(first)
        XCTAssertTrue(WK.waitForValue(WK.control(app, "level-picker")) { $0 == WK.levelTwoOpen },
                      "level 2 is still open after the relaunch: \(WK.value(app, "level-picker"))")
        XCTAssertTrue(WK.menuOffers(app, "Level 1 · 3 stars"),
                      "the level menu keeps level 1's three stars: " + WK.description(app))
        XCTAssertFalse(element(app, "session.failure").exists, "no failure")
    }
}
