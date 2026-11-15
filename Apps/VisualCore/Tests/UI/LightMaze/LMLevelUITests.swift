// LMLevelUITests — feature 101 (A13-P06) T-A13-608 (FR-A13-630; research D4): the level controls of Light Maze (A13)
// inside the one app. On a fresh start (erased data) level 1, First light, holds one mirror: Select next selects it
// and Turn solves the level (the status line ends "; solved"); Undo takes the turn back ("; not solved"); Turn solves
// it again; the solve opens level 2, so the Level menu's item "2. Around the corner" is enabled and choosing it opens
// level 2 (the status line begins "Level 2"). One journey per test, well under 60 s. System accessibility audits
// wait for the device campaign (owner ruling of 2026-11-13).
import XCTest

final class LMLevelUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    /// Turn solves level 1, Undo takes it back, Turn solves it again and the Level menu opens the opened level 2.
    @MainActor
    func testSolveUndoAndChooseTheOpenedLevel() {
        let app = LM.open()

        XCTAssertTrue(LM.waitForStatus(app) { $0.hasPrefix("Level 1, First light;") && LM.isNotSolved($0) },
                      "a fresh start is level 1, not solved (now \(LM.value(app, "status")))")

        LM.tap(app, "select-next")
        LM.tap(app, "turn")
        XCTAssertTrue(LM.waitForStatus(app) { LM.isSolved($0) },
                      "Turn solves level 1 (now \(LM.value(app, "status")))")

        LM.tap(app, "undo")
        XCTAssertTrue(LM.waitForStatus(app) { LM.isNotSolved($0) },
                      "Undo takes the turn back (now \(LM.value(app, "status")))")

        LM.tap(app, "turn")
        XCTAssertTrue(LM.waitForStatus(app) { LM.isSolved($0) },
                      "Turn solves level 1 again (now \(LM.value(app, "status")))")

        XCTAssertTrue(LM.chooseLevel(app, titlePrefix: "2. "), "the Level menu offers level 2")
        XCTAssertTrue(LM.waitForStatus(app) { $0.hasPrefix("Level 2") },
                      "choosing level 2 opens it (now \(LM.value(app, "status")))")
        XCTAssertFalse(element(app, "session.failure").exists, "no failure")
    }
}
