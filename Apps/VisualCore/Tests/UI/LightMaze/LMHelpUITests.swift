// LMHelpUITests — feature 101 (A13-P06) T-A13-608 (FR-A13-630; research D4): the help controls of Light Maze (A13)
// inside the one app. On a fresh start (erased data) level 1 is not solved, so Hint answers with the tile to turn
// ("Hint: turn the mirror at row 2, column 3.", columns from the left, rows from the bottom) in the answer line
// (`message`); Describe shows the full board description there ("Level 1, First light: 5 by 5 board. …"). One journey
// per test, well under 60 s. System accessibility audits wait for the device campaign (owner ruling of 2026-11-13).
import XCTest

final class LMHelpUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    /// Hint names the mirror to turn; Describe shows the board in words.
    @MainActor
    func testHintNamesATileAndDescribeShowsTheBoard() {
        let app = LM.open()

        LM.tap(app, "hint")
        let message = LM.control(app, "message")
        waitFor(message, timeout: LM.shortWait, "the answer line is there")
        XCTAssertTrue(LM.waitForValue(message) { $0.hasPrefix("Hint: turn the mirror at row") },
                      "Hint names a mirror (now \(LM.value(app, "message")))")

        LM.tap(app, "describe")
        XCTAssertTrue(LM.waitForValue(LM.control(app, "message")) { $0.hasPrefix("Level 1, First light") },
                      "Describe shows the board (now \(LM.value(app, "message")))")
        XCTAssertFalse(element(app, "session.failure").exists, "no failure")
    }
}
