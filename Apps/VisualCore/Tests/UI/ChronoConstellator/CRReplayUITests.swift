// CRReplayUITests — feature 359 (R02-G06-09) T-R02G0609-004 (FR-R02G0609-002; SC-R02G0609-001; clarification Q2): the
// replay of Chrono Constellator (R02-G06) inside the one app. After level 1 is won with its certified solution
// (`CR.winLevelOne`), "Replay best solution" (`replay`, offered when the level has a verified stored solution) starts
// the stored trace on a fresh play of the level (the canvas no longer reports the win); Step (`replay-step`, value
// "Action p of n") is pressed, at most two more times than the trace's length, until the canvas description
// (`ChronoConstellatorPresenter.describe`) says "Every star stands on its target."; Stop (`replay-stop`) returns to the
// campaign (`replay.stop`: the replay controls go, the `campaign` button reads "selected") and Replay is offered again.
// Short bounded waits; one test under 90 s. System accessibility audits wait for the device campaign (owner ruling of
// 2026-11-13).
import XCTest

final class CRReplayUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    /// Replay steps through the stored solution to its winning end and Stop returns to the campaign.
    @MainActor
    func testReplayOfTheSolvedLevelEndsWonAndStopReturnsToTheCampaign() {
        let app = CR.winLevelOne()
        XCTAssertTrue(CR.tap(app, "replay"), "Replay is tapped")
        let step = CR.control(app, "replay-step")
        XCTAssertTrue(step.waitForExistence(timeout: CR.shortWait), "the replay runs")
        XCTAssertTrue(CR.waitForDescription(app) { !$0.contains(CR.won) },
                      "the replay starts on a fresh play: \(CR.description(app))")

        guard let start = CR.replayPosition(CR.value(app, "replay-step")) else {
            XCTFail("Step shows no position: \(CR.value(app, "replay-step"))")
            return
        }
        let n = start.length
        XCTAssertEqual(start.position, 0, "the replay starts before its first action")
        XCTAssertEqual(n, CR.levelOneTraceLength, "the stored trace holds the phase press and the run")
        // Step is found and scrolled into view once; each press then taps the same element and waits for its value to
        // move on (re-finding and revealing it on every press costs seconds against the 90 s bound).
        XCTAssertTrue(CR.shown(app, "replay-step") != nil, "Step is shown")
        var steps = 0
        while steps < n + 2, !CR.description(app).contains(CR.won) {
            let before = CR.value(app, "replay-step")
            step.tap()
            steps += 1
            _ = CR.waitForValue(step, timeout: 2) { $0 != before }
        }
        XCTAssertTrue(CR.waitForDescription(app) { $0.contains(CR.won) },
                      "the replay ends won: \(CR.description(app))")
        XCTAssertLessThanOrEqual(steps, n, "the replay is won within its \(n) actions")
        XCTAssertEqual(CR.value(app, "replay-step"), "Action \(n) of \(n)", "the replay played its whole trace")

        XCTAssertTrue(CR.tap(app, "replay-stop"), "Stop is tapped")
        XCTAssertTrue(waitUntilGone(step, timeout: CR.shortWait), "the replay has ended")
        XCTAssertTrue(CR.waitForValue(CR.control(app, "campaign")) { $0 == "selected" },
                      "Stop returns to the campaign (campaign is \(CR.value(app, "campaign")))")
        XCTAssertTrue(CR.control(app, "replay").waitForExistence(timeout: CR.shortWait), "Replay is offered again")
        XCTAssertFalse(element(app, "session.failure").exists, "no failure")
    }
}
