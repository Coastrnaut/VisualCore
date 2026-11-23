// NGReplayUITests — feature 389 (R02-G09-09) T-R02G0909-004 (FR-R02G0909-002; SC-R02G0909-001; clarification Q2): the
// replay of Nocturne Garden (R02-G09) inside the one app. After level 1 is won with its certified moves
// (`NG.winLevelOne`), "Replay best solution" (`replay`, offered when the level has a verified stored solution) starts
// the stored trace on a fresh play of the level (the canvas no longer reports the win); Step (`replay-step`, value
// "Move k of n") is pressed, at most two more times than the trace's length, until the canvas description
// (`NocturneGardenPresenter.describe`) says "The shadow matches the target."; Stop (`replay-stop`) returns to the
// campaign (`replay.stop`: the replay controls go, the `campaign` button reads "selected") and Replay is offered again.
// Short bounded waits; one test under 90 s. System accessibility audits wait for the device campaign (owner ruling of
// 2026-11-13).
import XCTest

final class NGReplayUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    /// Replay steps through the stored solution to its winning end and Stop returns to the campaign.
    @MainActor
    func testReplayOfTheSolvedLevelEndsWonAndStopReturnsToTheCampaign() {
        let app = NG.winLevelOne()
        XCTAssertTrue(NG.tap(app, "replay"), "Replay is tapped")
        let step = NG.control(app, "replay-step")
        XCTAssertTrue(step.waitForExistence(timeout: NG.shortWait), "the replay runs")
        XCTAssertTrue(NG.waitForDescription(app) { !$0.contains(NG.won) },
                      "the replay starts on a fresh play: \(NG.description(app))")

        guard let start = NG.replayPosition(NG.value(app, "replay-step")) else {
            XCTFail("Step shows no position: \(NG.value(app, "replay-step"))")
            return
        }
        let n = start.length
        XCTAssertEqual(start.position, 0, "the replay starts before its first move")
        XCTAssertEqual(n, NG.levelOneTraceLength, "the stored trace holds the two plants")
        // Step is found and scrolled into view once; each press then taps the same element and waits for its value to
        // move on (re-finding and revealing it on every press costs seconds against the 90 s bound).
        XCTAssertTrue(NG.shown(app, "replay-step") != nil, "Step is shown")
        var steps = 0
        while steps < n + 2, !NG.description(app).contains(NG.won) {
            let before = NG.value(app, "replay-step")
            step.tap()
            steps += 1
            _ = NG.waitForValue(step, timeout: 2) { $0 != before }
        }
        XCTAssertTrue(NG.waitForDescription(app) { $0.contains(NG.won) },
                      "the replay ends won: \(NG.description(app))")
        XCTAssertLessThanOrEqual(steps, n, "the replay is won within its \(n) moves")
        XCTAssertEqual(NG.value(app, "replay-step"), "Move \(n) of \(n)", "the replay played its whole trace")

        XCTAssertTrue(NG.tap(app, "replay-stop"), "Stop is tapped")
        XCTAssertTrue(waitUntilGone(step, timeout: NG.shortWait), "the replay has ended")
        XCTAssertTrue(NG.waitForValue(NG.control(app, "campaign")) { $0 == "selected" },
                      "Stop returns to the campaign (campaign is \(NG.value(app, "campaign")))")
        XCTAssertTrue(NG.control(app, "replay").waitForExistence(timeout: NG.shortWait), "Replay is offered again")
        XCTAssertFalse(element(app, "session.failure").exists, "no failure")
    }
}
