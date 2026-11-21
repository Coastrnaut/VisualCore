// WKReplayUITests — feature 329 (R02-G03-09) T-R02G0309-004 (FR-R02G0309-002; clarification Q2): the replay of Wave
// Knot Keeper (R02-G03) inside the one app. After level 1 is won with its certified solution (`WK.winLevelOne`, one
// move), Replay starts the stored solution; Step (`replay-step`, value "Move k of n") is pressed, at most a few times
// more than the solution's length, until its value reads "Move n of n" and the canvas description
// (`WaveKnotKeeperPresenter.describe`) says "The knot matches."; Stop (`replay-stop`) returns to the campaign and Replay
// is offered again. Short bounded waits; one test under 90 s. System accessibility audits wait for the device campaign
// (owner ruling of 2026-11-13).
import XCTest

final class WKReplayUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    /// Replay steps through the stored solution to its matching end and Stop returns to the campaign.
    @MainActor
    func testReplayStepsToTheEndAndStopReturnsToTheCampaign() {
        let app = WK.winLevelOne()
        XCTAssertTrue(WK.tap(app, "replay"), "Replay is tapped")
        let step = WK.control(app, "replay-step")
        XCTAssertTrue(step.waitForExistence(timeout: WK.shortWait), "the replay runs")

        let n = WK.levelOneShortest
        let end = "Move \(n) of \(n)"
        var steps = 0
        while steps < n + 2, WK.value(app, "replay-step") != end {
            let before = WK.value(app, "replay-step")
            XCTAssertTrue(WK.tap(app, "replay-step"), "Step is tapped")
            steps += 1
            _ = WK.waitForValue(step) { $0 != before }
        }
        XCTAssertEqual(WK.value(app, "replay-step"), end, "the replay reaches its last move")
        XCTAssertTrue(WK.waitForDescription(app) { $0.contains(WK.matches) },
                      "the replay ends on the matching knot: \(WK.description(app))")

        XCTAssertTrue(WK.tap(app, "replay-stop"), "Stop is tapped")
        XCTAssertTrue(waitUntilGone(step, timeout: WK.shortWait), "the replay has ended")
        XCTAssertTrue(WK.control(app, "replay").waitForExistence(timeout: WK.shortWait), "Replay is offered again")
        XCTAssertFalse(element(app, "session.failure").exists, "no failure")
    }
}
