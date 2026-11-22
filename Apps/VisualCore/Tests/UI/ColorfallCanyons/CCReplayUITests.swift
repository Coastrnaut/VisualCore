// CCReplayUITests — feature 349 (R02-G05-09) T-R02G0509-004 (FR-R02G0509-002; clarification Q2): the replay of
// Colorfall Canyons (R02-G05) inside the one app. After level 1 is won with its certified solution (`CC.winLevelOne`),
// Replay (`replay`, offered when the level has a verified stored solution) starts the stored trace on a fresh play of
// the level (the canvas no longer reports the win); Step (`replay-step`, value "Action p of n") is pressed, at most two
// more times than the trace's length, until the canvas description (`ColorfallCanyonsPresenter.describe`) says "Every
// basin is filled with its colours."; Stop (`replay-stop`) returns to the campaign (`replay.stop`: the replay controls
// go, the `campaign` button reads "selected") and Replay is offered again. Short bounded waits; one test under 90 s.
// System accessibility audits wait for the device campaign (owner ruling of 2026-11-13).
import XCTest

final class CCReplayUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    /// Replay steps through the stored solution to its winning end and Stop returns to the campaign.
    @MainActor
    func testReplayOfTheSolvedLevelEndsWonAndStopReturnsToTheCampaign() {
        let app = CC.winLevelOne()
        XCTAssertTrue(CC.tap(app, "replay"), "Replay is tapped")
        let step = CC.control(app, "replay-step")
        XCTAssertTrue(step.waitForExistence(timeout: CC.shortWait), "the replay runs")
        XCTAssertTrue(CC.waitForDescription(app) { !$0.contains(CC.filled) },
                      "the replay starts on a fresh play: \(CC.description(app))")

        guard let start = CC.replayPosition(CC.value(app, "replay-step")) else {
            XCTFail("Step shows no position: \(CC.value(app, "replay-step"))")
            return
        }
        let n = start.length
        XCTAssertEqual(start.position, 0, "the replay starts before its first action")
        XCTAssertGreaterThanOrEqual(n, CC.levelOneSmallest, "the stored trace holds at least the carves")
        // Step is found and scrolled into view once; each press then taps the same element and waits for its value to
        // move on (re-finding and revealing it on every press costs seconds against the 90 s bound).
        XCTAssertTrue(CC.shown(app, "replay-step") != nil, "Step is shown")
        var steps = 0
        while steps < n + 2, !CC.description(app).contains(CC.filled) {
            let before = CC.value(app, "replay-step")
            step.tap()
            steps += 1
            _ = CC.waitForValue(step, timeout: 2) { $0 != before }
        }
        XCTAssertTrue(CC.waitForDescription(app) { $0.contains(CC.filled) },
                      "the replay ends won: \(CC.description(app))")
        XCTAssertLessThanOrEqual(steps, n, "the replay is won within its \(n) actions")

        XCTAssertTrue(CC.tap(app, "replay-stop"), "Stop is tapped")
        XCTAssertTrue(waitUntilGone(step, timeout: CC.shortWait), "the replay has ended")
        XCTAssertTrue(CC.waitForValue(CC.control(app, "campaign")) { $0 == "selected" },
                      "Stop returns to the campaign (campaign is \(CC.value(app, "campaign")))")
        XCTAssertTrue(CC.control(app, "replay").waitForExistence(timeout: CC.shortWait), "Replay is offered again")
        XCTAssertFalse(element(app, "session.failure").exists, "no failure")
    }
}
