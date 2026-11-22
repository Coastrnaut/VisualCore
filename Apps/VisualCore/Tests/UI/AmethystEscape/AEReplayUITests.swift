// AEReplayUITests — feature 369 (R02-G07-09) T-R02G0709-004 (FR-R02G0709-002; SC-R02G0709-001; clarification Q2): the
// replay of Amethyst Escape (R02-G07) inside the one app. After level 1 is won with its certified solution
// (`AE.winLevelOne`), "Replay best solution" (`replay`, offered when the level has a verified stored solution) starts
// the stored trace on a fresh play of the level (the canvas no longer reports the win); Step (`replay-step`, value
// "Action p of n") is pressed, at most two more times than the trace's length, until the canvas description
// (`AmethystEscapePresenter.describe`) says "The pearl escaped through the exit gap."; Stop (`replay-stop`) returns to
// the campaign (`replay.stop`: the replay controls go, the `campaign` button reads "selected") and Replay is offered
// again. Short bounded waits; one test under 90 s. System accessibility audits wait for the device campaign (owner
// ruling of 2026-11-13).
import XCTest

final class AEReplayUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    /// Replay steps through the stored solution to its winning end and Stop returns to the campaign.
    @MainActor
    func testReplayOfTheSolvedLevelEndsWonAndStopReturnsToTheCampaign() {
        let app = AE.winLevelOne()
        XCTAssertTrue(AE.tap(app, "replay"), "Replay is tapped")
        let step = AE.control(app, "replay-step")
        XCTAssertTrue(step.waitForExistence(timeout: AE.shortWait), "the replay runs")
        XCTAssertTrue(AE.waitForDescription(app) { !$0.contains(AE.won) },
                      "the replay starts on a fresh play: \(AE.description(app))")

        guard let start = AE.replayPosition(AE.value(app, "replay-step")) else {
            XCTFail("Step shows no position: \(AE.value(app, "replay-step"))")
            return
        }
        let n = start.length
        XCTAssertEqual(start.position, 0, "the replay starts before its first action")
        XCTAssertEqual(n, AE.levelOneTraceLength, "the stored trace holds the turn and the two advances")
        // Step is found and scrolled into view once; each press then taps the same element and waits for its value to
        // move on (re-finding and revealing it on every press costs seconds against the 90 s bound).
        XCTAssertTrue(AE.shown(app, "replay-step") != nil, "Step is shown")
        var steps = 0
        while steps < n + 2, !AE.description(app).contains(AE.won) {
            let before = AE.value(app, "replay-step")
            step.tap()
            steps += 1
            _ = AE.waitForValue(step, timeout: 2) { $0 != before }
        }
        XCTAssertTrue(AE.waitForDescription(app) { $0.contains(AE.won) },
                      "the replay ends won: \(AE.description(app))")
        XCTAssertLessThanOrEqual(steps, n, "the replay is won within its \(n) actions")
        XCTAssertEqual(AE.value(app, "replay-step"), "Action \(n) of \(n)", "the replay played its whole trace")

        XCTAssertTrue(AE.tap(app, "replay-stop"), "Stop is tapped")
        XCTAssertTrue(waitUntilGone(step, timeout: AE.shortWait), "the replay has ended")
        XCTAssertTrue(AE.waitForValue(AE.control(app, "campaign")) { $0 == "selected" },
                      "Stop returns to the campaign (campaign is \(AE.value(app, "campaign")))")
        XCTAssertTrue(AE.control(app, "replay").waitForExistence(timeout: AE.shortWait), "Replay is offered again")
        XCTAssertFalse(element(app, "session.failure").exists, "no failure")
    }
}
