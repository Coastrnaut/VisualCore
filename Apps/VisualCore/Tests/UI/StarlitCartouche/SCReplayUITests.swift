// SCReplayUITests — feature 459 (R02-G16-09) T-R02G1609-004, modelled on feature 449 (FR-R02G1609-002;
// SC-R02G1609-001; clarification Q2): the replay of Starlit Cartouche (R02-G16) inside the one app. After level 1 is
// won with its certified legs (`SC.winLevelOne`), "Replay best solution" (`replay`, offered when the level has a
// verified stored solution) starts the stored trace on a fresh play of the level in replay mode (the canvas no longer
// reports the win); Step (`replay-step`, value `StarlitCartoucheControls.replayStepValue`, "Leg k of n"; the position
// line `replay-position` reads "Replay: leg k of n") is pressed, at most three more times than the trace's length,
// until the step's value reads "Leg n of n" and the canvas description (`StarlitCartouchePresenter.describe`) says "The
// trail draws the symbol and the ship rests at the beacon."; Stop (`replay-stop`, value "2 legs",
// `StarlitCartoucheControls.replayStopValue`) returns to the campaign (`replay.stop`: the replay controls go, the
// `campaign` button reads "selected") and Replay is offered again. Short bounded waits; one test under 90 s apart from
// the automation-session setup of the launch. System accessibility audits wait for the device campaign (owner ruling
// of 2026-11-13).
import XCTest

final class SCReplayUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    /// Replay steps through the stored solution to its winning end and Stop returns to the campaign.
    @MainActor
    func testReplayOfTheSolvedLevelEndsWonAndStopReturnsToTheCampaign() {
        let app = SC.winLevelOne()
        XCTAssertTrue(SC.tap(app, "replay"), "Replay is tapped")
        let step = SC.control(app, "replay-step")
        XCTAssertTrue(step.waitForExistence(timeout: SC.shortWait), "the replay runs")
        XCTAssertTrue(SC.waitForDescription(app) { !$0.contains(SC.won) },
                      "the replay starts on a fresh play: \(SC.description(app))")

        guard let start = SC.replayPosition(SC.value(app, "replay-step")) else {
            XCTFail("Step shows no position: \(SC.value(app, "replay-step"))")
            return
        }
        let n = start.length
        XCTAssertEqual(start.position, 0, "the replay starts before its first leg")
        XCTAssertEqual(n, SC.levelOneTraceLength, "the stored trace holds the two legs")
        XCTAssertEqual(SC.value(app, "replay-stop"), n == 1 ? "1 leg" : "\(n) legs", "Stop names the trace's legs")
        XCTAssertEqual(SC.control(app, "replay-position").label, "Replay: leg 0 of \(n)",
                       "the position line starts at the beginning")
        // Step is found and scrolled into view once; each press then taps the same element and waits for its value to
        // move on (re-finding and revealing it on every press costs seconds against the 90 s bound).
        XCTAssertTrue(SC.shown(app, "replay-step") != nil, "Step is shown")
        // The loop follows the step's own position ("Leg k of n", the replay's legs played): a press counts once its
        // value moves on; a press the simulator did not deliver (or whose value moves after the wait) is retried,
        // within n + 3 presses. The canvas description can say the win a moment after the last step, so it is read only
        // once the trace is played.
        var steps = 0
        var presses = 0
        while presses < n + 3, (SC.replayPosition(SC.value(app, "replay-step"))?.position ?? n) < n {
            let before = SC.value(app, "replay-step")
            step.tap()
            presses += 1
            if SC.waitForValue(step, timeout: 5, { $0 != before }) { steps += 1 }
        }
        XCTAssertTrue(SC.waitForDescription(app) { $0.contains(SC.won) },
                      "the replay ends won: \(SC.description(app))")
        XCTAssertEqual(steps, n, "the replay is won by exactly its \(n) legs (\(presses) presses)")
        XCTAssertEqual(SC.value(app, "replay-step"), "Leg \(n) of \(n)", "the replay played its whole trace")

        XCTAssertTrue(SC.tap(app, "replay-stop"), "Stop is tapped")
        XCTAssertTrue(waitUntilGone(step, timeout: SC.shortWait), "the replay has ended")
        XCTAssertTrue(SC.waitForValue(SC.control(app, "campaign")) { $0 == "selected" },
                      "Stop returns to the campaign (campaign is \(SC.value(app, "campaign")))")
        XCTAssertTrue(SC.control(app, "replay").waitForExistence(timeout: SC.shortWait), "Replay is offered again")
        XCTAssertFalse(element(app, "session.failure").exists, "no failure")
    }
}
