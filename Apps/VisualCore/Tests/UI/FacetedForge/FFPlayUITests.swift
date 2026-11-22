// FFPlayUITests — feature 379 (R02-G08-09) T-R02G0809-004 (FR-R02G0809-002; SC-R02G0809-001; clarifications Q1, Q2):
// Faceted Forge (R02-G08) played inside the one app. A fresh start (erased data, `FF.fresh`) opens level 1 with no cut
// spent of its budget of 9 and the pickers on piece 1, direction z, depth 0 (`FF.levelOneInitialChoice`, the Core's
// `FacetedForgePreviewChoice.initial`); the tutorial is dismissed and level 1's certified cuts (pinned in `FF` from the
// stored witness: piece 1 along x+y at depth −3, piece 1 along x+y at depth 1, piece 2 along x+z at depth −5) are
// played with the panel: before each cut the piece, direction and depth steppers are stepped from their current
// values to the cut's, then Cut. The canvas description (`FacetedForgePresenter.describe`) reports "The pieces match
// the target." and " Stars: 3 of 3." (3 cuts spent, the certified smallest); the level picker then steps to level 2
// and no further (the frontier), and level 1 reads "Level 1, band 1, 3 stars". After a relaunch without the reset
// (`FF.reopen`, which backgrounds the app before it ends it) the stored progress is read from the level picker: level
// 2 is still reachable and level 1 keeps its three stars. Short bounded waits; each test under 90 s. System
// accessibility audits wait for the device campaign (owner ruling of 2026-11-13).
import XCTest

final class FFPlayUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    /// Level 1's certified cuts played with the piece, direction and depth steppers and Cut win with three stars and
    /// open level 2.
    @MainActor
    func testPlayingLevelOneCertifiedCutsWinsWithThreeStars() {
        let app = FF.winLevelOne()
        XCTAssertTrue(FF.description(app).contains(FF.spent(FF.levelOneSmallest)),
                      "the solution spent the certified smallest: \(FF.description(app))")
        FF.checkLevelPicker(app)
        XCTAssertFalse(element(app, "session.failure").exists, "no failure")
    }

    /// The win survives a relaunch: level 2 stays open and level 1 keeps its three stars.
    @MainActor
    func testProgressSurvivesARelaunch() {
        let first = FF.winLevelOne()
        let app = FF.reopen(first)
        FF.checkLevelPicker(app)
        XCTAssertFalse(element(app, "session.failure").exists, "no failure")
    }
}

extension FF {
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
