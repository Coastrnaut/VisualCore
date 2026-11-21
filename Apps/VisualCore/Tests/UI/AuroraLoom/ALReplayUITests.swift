// ALReplayUITests — feature 309 (R02-G01-09) T-R02G0109-004 (FR-R02G0109-002; clarification Q2; acceptance scenario 3):
// the replay of Aurora Loom (R02-G01) inside the one app. After level 1 is won with its certified solution (`AL.winLevelOne`,
// two moves), Replay starts the stored solution: the canvas description (`AuroraLoomPresenter.describe`) reads
// "Replay, move k of n."; Step (`replay-step`) is pressed, at most a few times more than the solution's length, until it
// reads "Replay, move 2 of 2."; Stop (`replay-stop`) returns to the campaign and the description no longer names the
// replay. Short bounded waits; one journey under 90 s (measured 62–72 s with launch). System accessibility audits wait for the device campaign
// (owner ruling of 2026-11-13).
import XCTest

final class ALReplayUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    /// Replay steps through the stored solution to its end and Stop returns to the campaign.
    @MainActor
    func testReplayStepsToTheEndAndStopReturnsToTheCampaign() {
        let app = AL.winLevelOne()
        XCTAssertTrue(AL.tap(app, "replay"), "Replay is tapped")
        XCTAssertTrue(AL.waitForDescription(app) { $0.contains("Replay, move ") },
                      "the canvas names the replay: \(AL.description(app))")

        let end = "Replay, move \(AL.solutionMoves) of \(AL.solutionMoves)."
        var steps = 0
        while steps < AL.solutionMoves + 2, !AL.description(app).contains(end) {
            let before = AL.description(app)
            XCTAssertTrue(AL.tap(app, "replay-step"), "Step is tapped")
            steps += 1
            _ = AL.waitForDescription(app) { $0 != before }
        }
        XCTAssertTrue(AL.description(app).contains(end), "the replay reaches its last move: \(AL.description(app))")

        XCTAssertTrue(AL.tap(app, "replay-stop"), "Stop is tapped")
        XCTAssertTrue(AL.waitForDescription(app) { !$0.contains("Replay,") },
                      "the replay has ended: \(AL.description(app))")
        XCTAssertTrue(AL.control(app, "replay").waitForExistence(timeout: AL.shortWait), "Replay is offered again")
        XCTAssertFalse(element(app, "session.failure").exists, "no failure")
    }
}
