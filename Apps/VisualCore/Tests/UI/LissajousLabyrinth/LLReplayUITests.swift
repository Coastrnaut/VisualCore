// LLReplayUITests — feature 319 (R02-G02-09) T-R02G0209-004 (FR-R02G0209-002; clarification Q2): the replay of
// Lissajous Labyrinth (R02-G02) inside the one app. After level 1 is won with its certified solution (`LL.winLevelOne`,
// one action), Replay starts the stored solution; Step (`replay-step`, value "Action k of n") is pressed, at most a few
// times more than the solution's length, until its value reads "Action n of n" and the canvas description
// (`LissajousLabyrinthPresenter.describe`) says "The path is safe."; Stop (`replay-stop`) returns to the campaign and
// Replay is offered again. Short bounded waits; one test under 90 s. System accessibility audits wait for the device
// campaign (owner ruling of 2026-11-13).
import XCTest

final class LLReplayUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    /// Replay steps through the stored solution to its safe end and Stop returns to the campaign.
    @MainActor
    func testReplayStepsToTheEndAndStopReturnsToTheCampaign() {
        let app = LL.winLevelOne()
        XCTAssertTrue(LL.tap(app, "replay"), "Replay is tapped")
        let step = LL.control(app, "replay-step")
        XCTAssertTrue(step.waitForExistence(timeout: LL.shortWait), "the replay runs")

        let n = LL.levelOneShortest
        let end = "Action \(n) of \(n)"
        var steps = 0
        while steps < n + 2, LL.value(app, "replay-step") != end {
            let before = LL.value(app, "replay-step")
            XCTAssertTrue(LL.tap(app, "replay-step"), "Step is tapped")
            steps += 1
            _ = LL.waitForValue(step) { $0 != before }
        }
        XCTAssertEqual(LL.value(app, "replay-step"), end, "the replay reaches its last action")
        XCTAssertTrue(LL.waitForDescription(app) { $0.contains(LL.safe) },
                      "the replay ends on the safe path: \(LL.description(app))")

        XCTAssertTrue(LL.tap(app, "replay-stop"), "Stop is tapped")
        XCTAssertTrue(waitUntilGone(step, timeout: LL.shortWait), "the replay has ended")
        XCTAssertTrue(LL.control(app, "replay").waitForExistence(timeout: LL.shortWait), "Replay is offered again")
        XCTAssertFalse(element(app, "session.failure").exists, "no failure")
    }
}
