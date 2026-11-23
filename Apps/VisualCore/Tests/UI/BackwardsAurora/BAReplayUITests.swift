// BAReplayUITests — feature 399 (R02-G10-09) T-R02G1009-004 (FR-R02G1009-002; SC-R02G1009-001; clarification Q2): the
// replay of Backwards Aurora (R02-G10) inside the one app. After level 1 is won with its certified reversals
// (`BA.winLevelOne`), "Replay best solution" (`replay`, offered when the level has a verified stored solution) starts
// the stored trace on a fresh play of the level (the canvas no longer reports the win); Step (`replay-step`, value
// "Reversal k of n") is pressed, at most two more times than the trace's length, until the canvas description
// (`BackwardsAuroraPresenter.describe`) says "Every checkpoint matches and every bend is within the limit."; Stop
// (`replay-stop`) returns to the campaign (`replay.stop`: the replay controls go, the `campaign` button reads
// "selected") and Replay is offered again. Short bounded waits; one test under 90 s apart from the automation-session
// setup of the launch. System accessibility audits wait for the device campaign (owner ruling of 2026-11-13).
import XCTest

final class BAReplayUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    /// Replay steps through the stored solution to its winning end and Stop returns to the campaign.
    @MainActor
    func testReplayOfTheSolvedLevelEndsWonAndStopReturnsToTheCampaign() {
        let app = BA.winLevelOne()
        XCTAssertTrue(BA.tap(app, "replay"), "Replay is tapped")
        let step = BA.control(app, "replay-step")
        XCTAssertTrue(step.waitForExistence(timeout: BA.shortWait), "the replay runs")
        XCTAssertTrue(BA.waitForDescription(app) { !$0.contains(BA.won) },
                      "the replay starts on a fresh play: \(BA.description(app))")

        guard let start = BA.replayPosition(BA.value(app, "replay-step")) else {
            XCTFail("Step shows no position: \(BA.value(app, "replay-step"))")
            return
        }
        let n = start.length
        XCTAssertEqual(start.position, 0, "the replay starts before its first reversal")
        XCTAssertEqual(n, BA.levelOneTraceLength, "the stored trace holds the two reversals")
        // Step is found and scrolled into view once; each press then taps the same element and waits for its value to
        // move on (re-finding and revealing it on every press costs seconds against the 90 s bound).
        XCTAssertTrue(BA.shown(app, "replay-step") != nil, "Step is shown")
        var steps = 0
        while steps < n + 2, !BA.description(app).contains(BA.won) {
            let before = BA.value(app, "replay-step")
            step.tap()
            steps += 1
            _ = BA.waitForValue(step, timeout: 2) { $0 != before }
        }
        XCTAssertTrue(BA.waitForDescription(app) { $0.contains(BA.won) },
                      "the replay ends won: \(BA.description(app))")
        XCTAssertLessThanOrEqual(steps, n, "the replay is won within its \(n) reversals")
        XCTAssertEqual(BA.value(app, "replay-step"), "Reversal \(n) of \(n)", "the replay played its whole trace")

        XCTAssertTrue(BA.tap(app, "replay-stop"), "Stop is tapped")
        XCTAssertTrue(waitUntilGone(step, timeout: BA.shortWait), "the replay has ended")
        XCTAssertTrue(BA.waitForValue(BA.control(app, "campaign")) { $0 == "selected" },
                      "Stop returns to the campaign (campaign is \(BA.value(app, "campaign")))")
        XCTAssertTrue(BA.control(app, "replay").waitForExistence(timeout: BA.shortWait), "Replay is offered again")
        XCTAssertFalse(element(app, "session.failure").exists, "no failure")
    }
}
