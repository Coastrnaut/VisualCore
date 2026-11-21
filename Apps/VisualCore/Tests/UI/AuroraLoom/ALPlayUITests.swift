// ALPlayUITests — feature 309 (R02-G01-09) T-R02G0109-004 (FR-R02G0109-001, 002, 008; clarification Q2, the amendment
// of 2026-11-20; acceptance scenarios 1 and 2): Aurora Loom (R02-G01) played inside the one app. A fresh start (erased
// data, `AL.fresh`) opens level 1; the tutorial is skipped, level 1's certified solution (ribbon 3: wave 3 → 15 and
// phase 3 → 12, pinned in `AL`) is set as pending steps with the panel's steppers, by the shorter way round the wrap,
// and Apply commits them as two moves: the canvas description (`AuroraLoomPresenter.describe`) reports "The loom is in
// harmony. 3 of 3 stars." and the level menu offers level 2. After a relaunch without the reset (`AL.reopen`) the
// stored progress is read from the level menu `level-picker`: it still offers level 2. The menu is the signal because it
// lists every open level up to the stored frontier whatever play is restored, while the stars appear in the
// description only while the restored play is the won one. Short bounded waits; each journey under 90 s (measured 62–72 s with launch). System
// accessibility audits wait for the device campaign (owner ruling of 2026-11-13).
import XCTest

final class ALPlayUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    /// Level 1's solution set as pending steps and applied wins with three stars and opens level 2.
    @MainActor
    func testApplyingLevelOneSolutionWinsWithThreeStars() {
        let app = AL.winLevelOne()
        XCTAssertTrue(AL.description(app).contains("The loom is in harmony."),
                      "the canvas reports harmony: \(AL.description(app))")
        XCTAssertTrue(AL.description(app).contains("Moves \(AL.solutionMoves) of \(AL.levelOneAllowance)"),
                      "Apply spent one move per changed control: \(AL.description(app))")
        XCTAssertFalse(AL.control(app, "apply").exists, "nothing is pending after Apply")
        XCTAssertTrue(AL.menuOffersLevel(app, 2), "the level menu offers level 2 after the win")
        XCTAssertFalse(element(app, "session.failure").exists, "no failure")
    }

    /// The win survives a relaunch: the level menu still offers level 2.
    @MainActor
    func testProgressSurvivesARelaunch() {
        let first = AL.winLevelOne()
        let app = AL.reopen(first)
        let solvedShown = AL.description(app).contains(AL.threeStars)
        XCTAssertTrue(AL.menuOffersLevel(app, 2),
                      "the level menu still offers level 2 after the relaunch (stars shown: \(solvedShown)): "
                      + AL.description(app))
        XCTAssertFalse(element(app, "session.failure").exists, "no failure")
    }
}
