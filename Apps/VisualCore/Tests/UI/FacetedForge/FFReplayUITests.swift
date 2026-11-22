// FFReplayUITests — feature 379 (R02-G08-09) T-R02G0809-004 (FR-R02G0809-002; SC-R02G0809-001; clarification Q2): the
// replay of Faceted Forge (R02-G08) inside the one app. After level 1 is won with its certified cuts
// (`FF.winLevelOne`), "Replay best solution" (`replay`, offered when the level has a verified stored solution) starts
// the stored trace on a fresh play of the level (the canvas no longer reports the win); Step (`replay-step`, value
// "Cut k of n") is pressed, at most two more times than the trace's length, until the canvas description
// (`FacetedForgePresenter.describe`) says "The pieces match the target."; Stop (`replay-stop`) returns to the campaign
// (`replay.stop`: the replay controls go, the `campaign` button reads "selected") and Replay is offered again. Short
// bounded waits; one test under 90 s. System accessibility audits wait for the device campaign (owner ruling of
// 2026-11-13).
import XCTest

final class FFReplayUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    /// Replay steps through the stored solution to its winning end and Stop returns to the campaign.
    @MainActor
    func testReplayOfTheSolvedLevelEndsWonAndStopReturnsToTheCampaign() {
        let app = FF.winLevelOne()
        XCTAssertTrue(FF.tap(app, "replay"), "Replay is tapped")
        let step = FF.control(app, "replay-step")
        XCTAssertTrue(step.waitForExistence(timeout: FF.shortWait), "the replay runs")
        XCTAssertTrue(FF.waitForDescription(app) { !$0.contains(FF.won) },
                      "the replay starts on a fresh play: \(FF.description(app))")

        guard let start = FF.replayPosition(FF.value(app, "replay-step")) else {
            XCTFail("Step shows no position: \(FF.value(app, "replay-step"))")
            return
        }
        let n = start.length
        XCTAssertEqual(start.position, 0, "the replay starts before its first cut")
        XCTAssertEqual(n, FF.levelOneTraceLength, "the stored trace holds the three cuts")
        // Step is found and scrolled into view once; each press then taps the same element and waits for its value to
        // move on (re-finding and revealing it on every press costs seconds against the 90 s bound).
        XCTAssertTrue(FF.shown(app, "replay-step") != nil, "Step is shown")
        var steps = 0
        while steps < n + 2, !FF.description(app).contains(FF.won) {
            let before = FF.value(app, "replay-step")
            step.tap()
            steps += 1
            _ = FF.waitForValue(step, timeout: 2) { $0 != before }
        }
        XCTAssertTrue(FF.waitForDescription(app) { $0.contains(FF.won) },
                      "the replay ends won: \(FF.description(app))")
        XCTAssertLessThanOrEqual(steps, n, "the replay is won within its \(n) cuts")
        XCTAssertEqual(FF.value(app, "replay-step"), "Cut \(n) of \(n)", "the replay played its whole trace")

        XCTAssertTrue(FF.tap(app, "replay-stop"), "Stop is tapped")
        XCTAssertTrue(waitUntilGone(step, timeout: FF.shortWait), "the replay has ended")
        XCTAssertTrue(FF.waitForValue(FF.control(app, "campaign")) { $0 == "selected" },
                      "Stop returns to the campaign (campaign is \(FF.value(app, "campaign")))")
        XCTAssertTrue(FF.control(app, "replay").waitForExistence(timeout: FF.shortWait), "Replay is offered again")
        XCTAssertFalse(element(app, "session.failure").exists, "no failure")
    }
}
