// HBReplayUITests — feature 419 (R02-G12-09) T-R02G1209-004 (FR-R02G1209-002; SC-R02G1209-001; clarification Q2):
// the replay of Harmonic Bridges (R02-G12) inside the one app. After level 1 is won with its certified actions
// (`HB.winLevelOne`), "Replay best solution" (`replay`, offered when the level has a verified stored solution) starts
// the stored trace on a fresh play of the level (the canvas no longer reports the win); Step (`replay-step`, value
// "Action k of n") is pressed, at most three more times than the trace's length, until the canvas description
// (`HarmonicBridgesPresenter.describe`) says "The crossing holds in every step."; Stop (`replay-stop`) returns to the
// campaign (`replay.stop`: the replay controls go, the `campaign` button reads "selected") and Replay is offered again.
// Short bounded waits; one test under 90 s apart from the automation-session setup of the launch. System accessibility
// audits wait for the device campaign (owner ruling of 2026-11-13).
import XCTest

final class HBReplayUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    /// Replay steps through the stored solution to its winning end and Stop returns to the campaign.
    @MainActor
    func testReplayOfTheSolvedLevelEndsWonAndStopReturnsToTheCampaign() {
        let app = HB.winLevelOne()
        XCTAssertTrue(HB.tap(app, "replay"), "Replay is tapped")
        let step = HB.control(app, "replay-step")
        XCTAssertTrue(step.waitForExistence(timeout: HB.shortWait), "the replay runs")
        XCTAssertTrue(HB.waitForDescription(app) { !$0.contains(HB.won) },
                      "the replay starts on a fresh play: \(HB.description(app))")

        guard let start = HB.replayPosition(HB.value(app, "replay-step")) else {
            XCTFail("Step shows no position: \(HB.value(app, "replay-step"))")
            return
        }
        let n = start.length
        XCTAssertEqual(start.position, 0, "the replay starts before its first action")
        XCTAssertEqual(n, HB.levelOneTraceLength, "the stored trace holds the tuning and the test")
        // Step is found and scrolled into view once; each press then taps the same element and waits for its value to
        // move on (re-finding and revealing it on every press costs seconds against the 90 s bound).
        XCTAssertTrue(HB.shown(app, "replay-step") != nil, "Step is shown")
        // The loop follows the step's own position ("Action k of n", the replay's record count): a press counts once
        // its value moves on; a press the simulator did not deliver (or whose value moves after the wait) is retried,
        // within n + 3 presses. The canvas description can say "won" a moment after the last step, so it is read only
        // once the trace is played.
        var steps = 0
        var presses = 0
        while presses < n + 3, (HB.replayPosition(HB.value(app, "replay-step"))?.position ?? n) < n {
            let before = HB.value(app, "replay-step")
            step.tap()
            presses += 1
            if HB.waitForValue(step, timeout: 5, { $0 != before }) { steps += 1 }
        }
        XCTAssertTrue(HB.waitForDescription(app) { $0.contains(HB.won) },
                      "the replay ends won: \(HB.description(app))")
        XCTAssertEqual(steps, n, "the replay is won by exactly its \(n) actions (\(presses) presses)")
        XCTAssertEqual(HB.value(app, "replay-step"), "Action \(n) of \(n)", "the replay played its whole trace")

        XCTAssertTrue(HB.tap(app, "replay-stop"), "Stop is tapped")
        XCTAssertTrue(waitUntilGone(step, timeout: HB.shortWait), "the replay has ended")
        XCTAssertTrue(HB.waitForValue(HB.control(app, "campaign")) { $0 == "selected" },
                      "Stop returns to the campaign (campaign is \(HB.value(app, "campaign")))")
        XCTAssertTrue(HB.control(app, "replay").waitForExistence(timeout: HB.shortWait), "Replay is offered again")
        XCTAssertFalse(element(app, "session.failure").exists, "no failure")
    }
}
