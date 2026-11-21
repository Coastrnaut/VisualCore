// HCReplayUITests — feature 339 (R02-G04-09) T-R02G0409-004 (FR-R02G0409-002; clarification Q2): the replay of Hue
// Compass (R02-G04) inside the one app. After level 1 is won with its certified witness (`HC.winLevelOne`), Replay
// starts the stored verified trace (one action per turn press, the probe and the selection: `HC.levelOneTraceLength`);
// Step (`replay-step`, value "Action k of n") is pressed, at most a few times more than the trace's length, until its
// value reads "Action n of n" and the canvas description (`HueCompassPresenter.describe`) says "The bearing and hue
// match." (no stars in replay); Stop (`replay-stop`) returns to the campaign and Replay is offered again. Short bounded
// waits; one test under 90 s. System accessibility audits wait for the device campaign (owner ruling of 2026-11-13).
import XCTest

final class HCReplayUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    /// Replay steps through the stored solution to its matching end and Stop returns to the campaign.
    @MainActor
    func testReplayStepsToTheEndAndStopReturnsToTheCampaign() {
        let app = HC.winLevelOne()
        XCTAssertTrue(HC.tap(app, "replay"), "Replay is tapped")
        let step = HC.control(app, "replay-step")
        XCTAssertTrue(step.waitForExistence(timeout: HC.shortWait), "the replay runs")

        let n = HC.levelOneTraceLength
        XCTAssertEqual(HC.replayPosition(HC.value(app, "replay-step"))?.length, n,
                       "the replay holds the recorded trace: \(HC.value(app, "replay-step"))")
        let end = "Action \(n) of \(n)"
        // Step is found and scrolled into view once; each press then taps the same element and waits for its value to
        // move on (re-finding and revealing it on every press cost about two seconds each, over the 90 s bound).
        XCTAssertTrue(HC.shown(app, "replay-step") != nil, "Step is shown")
        var steps = 0
        var current = HC.value(app, "replay-step")
        while steps < n + 2, current != end {
            let before = current
            step.tap()
            steps += 1
            _ = HC.waitForValue(step) { $0 != before }
            current = HC.value(app, "replay-step")
        }
        XCTAssertEqual(HC.value(app, "replay-step"), end, "the replay reaches its last action")
        XCTAssertTrue(HC.waitForDescription(app) { $0.contains(HC.matches) },
                      "the replay ends on the match: \(HC.description(app))")

        XCTAssertTrue(HC.tap(app, "replay-stop"), "Stop is tapped")
        XCTAssertTrue(waitUntilGone(step, timeout: HC.shortWait), "the replay has ended")
        XCTAssertTrue(HC.control(app, "replay").waitForExistence(timeout: HC.shortWait), "Replay is offered again")
        XCTAssertFalse(element(app, "session.failure").exists, "no failure")
    }
}
