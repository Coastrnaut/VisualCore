// HCPlayUITests — feature 339 (R02-G04-09) T-R02G0409-004 (FR-R02G0409-001, 002; clarifications Q1, Q2): Hue Compass
// (R02-G04) played inside the one app. A fresh start (erased data, `HC.fresh`) opens level 1 at its start bearing; the
// tutorial is dismissed and level 1's certified witness (pinned in `HC`: turn 27 bearings clockwise, probe, select
// bearing 84 with band 10) is played with the panel: each turn as presses of the ±4 then the ±1 turn button, the probe
// with Probe, and the selection by turning the needle to its bearing (turns spend nothing), stepping the band picker the
// shorter way round to its band and tapping Select. The canvas description (`HueCompassPresenter.describe`) reports
// "The bearing and hue match. 3 of 3 stars." and the level menu's value says levels 1 to 2 are open. After a relaunch
// without the reset (`HC.reopen`, which backgrounds the app before it ends it) the stored progress is read from the
// level menu: its value still says level 2 is open and it offers "Level 1 · 3 stars". Short bounded waits; each test
// under 90 s. System accessibility audits wait for the device campaign (owner ruling of 2026-11-13).
import XCTest

final class HCPlayUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    /// Level 1's witness played with the turn buttons, Probe, the band picker and Select wins with three stars and
    /// opens level 2.
    @MainActor
    func testPlayingLevelOneWitnessWinsWithThreeStars() {
        let app = HC.winLevelOne()
        XCTAssertTrue(HC.description(app).contains("Units \(HC.levelOneUnits) of \(HC.levelOneAllowance)."),
                      "the probe and the selection spent one unit each: \(HC.description(app))")
        XCTAssertTrue(HC.waitForValue(HC.control(app, "level-picker")) { $0.contains(HC.levelTwoOpen) },
                      "the level menu opens level 2: \(HC.value(app, "level-picker"))")
        XCTAssertTrue(HC.menuOffers(app, "Level 2"), "the level menu offers level 2")
        XCTAssertFalse(element(app, "session.failure").exists, "no failure")
    }

    /// The win survives a relaunch: level 2 stays open and level 1 keeps its three stars.
    @MainActor
    func testProgressSurvivesARelaunch() {
        let first = HC.winLevelOne()
        let app = HC.reopen(first)
        XCTAssertTrue(HC.waitForValue(HC.control(app, "level-picker")) { $0.contains(HC.levelTwoOpen) },
                      "level 2 is still open after the relaunch: \(HC.value(app, "level-picker"))")
        XCTAssertTrue(HC.menuOffers(app, "Level 1 · 3 stars"),
                      "the level menu keeps level 1's three stars: " + HC.description(app))
        XCTAssertFalse(element(app, "session.failure").exists, "no failure")
    }
}
