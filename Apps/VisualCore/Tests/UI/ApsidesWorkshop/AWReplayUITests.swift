// AWReplayUITests — feature 479 (R02-G18-09) T-R02G1809-004, modelled on feature 469 (FR-R02G1809-002;
// SC-R02G1809-001; clarification Q2): the replay of Apsides Workshop (R02-G18) inside the one app. After level 1 is
// won with its certified plan (`AW.winLevelOne`), "Replay best solution" (`replay`, offered when the level has a
// verified stored solution) starts the stored trace (the periapsis tuning and the play) on a fresh play of the level in
// replay mode (the canvas no longer reports the win); Step (`replay-step`, value
// `ApsidesWorkshopControls.replayStepValue`, "Action k of n"; the position line `replay-position` reads "Replay:
// action k of n") is pressed, at most three more times than the trace's length, until the step's value reads "Action n
// of n" and the canvas description (`ApsidesWorkshopPresenter.describe`) says "Every target was met in order without
// striking a planet."; Stop (`replay-stop`, value "2 actions", `ApsidesWorkshopControls.replayStopValue`) returns to
// the campaign (`replay.stop`: the replay controls go, the `campaign` button reads "selected") and Replay is offered
// again. Short bounded waits; one test under 90 s apart from the automation-session setup of the launch. System
// accessibility audits wait for the device campaign (owner ruling of 2026-11-13).
import XCTest

final class AWReplayUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    /// Replay steps through the stored solution to its winning end and Stop returns to the campaign.
    @MainActor
    func testReplayOfTheSolvedLevelEndsWonAndStopReturnsToTheCampaign() {
        let app = AW.winLevelOne()
        XCTAssertTrue(AW.tap(app, "replay"), "Replay is tapped")
        let step = AW.control(app, "replay-step")
        XCTAssertTrue(step.waitForExistence(timeout: AW.shortWait), "the replay runs")
        XCTAssertTrue(AW.waitForDescription(app) { !$0.contains(AW.won) },
                      "the replay starts on a fresh play: \(AW.description(app))")

        guard let start = AW.replayPosition(AW.value(app, "replay-step")) else {
            XCTFail("Step shows no position: \(AW.value(app, "replay-step"))")
            return
        }
        let n = start.length
        XCTAssertEqual(start.position, 0, "the replay starts before its first action")
        XCTAssertEqual(n, AW.levelOneTraceLength, "the stored trace holds the periapsis tuning and the play")
        XCTAssertEqual(AW.value(app, "replay-stop"), n == 1 ? "1 action" : "\(n) actions",
                       "Stop names the trace's actions")
        XCTAssertEqual(AW.control(app, "replay-position").label, "Replay: action 0 of \(n)",
                       "the position line starts at the beginning")
        // Step is found and scrolled into view once; each press then taps the same element and waits for its value to
        // move on (re-finding and revealing it on every press costs seconds against the 90 s bound).
        XCTAssertTrue(AW.shown(app, "replay-step") != nil, "Step is shown")
        // The loop follows the step's own position ("Action k of n", the replay's actions played): a press counts once
        // its value moves on; a press the simulator did not deliver (or whose value moves after the wait) is retried,
        // within n + 3 presses. The canvas description can say the win a moment after the last step, so it is read
        // only once the trace is played.
        var steps = 0
        var presses = 0
        while presses < n + 3, (AW.replayPosition(AW.value(app, "replay-step"))?.position ?? n) < n {
            let before = AW.value(app, "replay-step")
            step.tap()
            presses += 1
            if AW.waitForValue(step, timeout: 5, { $0 != before }) { steps += 1 }
        }
        XCTAssertTrue(AW.waitForDescription(app) { $0.contains(AW.won) },
                      "the replay ends won: \(AW.description(app))")
        XCTAssertEqual(steps, n, "the replay is won by exactly its \(n) actions (\(presses) presses)")
        XCTAssertEqual(AW.value(app, "replay-step"), "Action \(n) of \(n)", "the replay played its whole trace")

        XCTAssertTrue(AW.tap(app, "replay-stop"), "Stop is tapped")
        XCTAssertTrue(waitUntilGone(step, timeout: AW.shortWait), "the replay has ended")
        XCTAssertTrue(AW.waitForValue(AW.control(app, "campaign")) { $0 == "selected" },
                      "Stop returns to the campaign (campaign is \(AW.value(app, "campaign")))")
        XCTAssertTrue(AW.control(app, "replay").waitForExistence(timeout: AW.shortWait), "Replay is offered again")
        XCTAssertFalse(element(app, "session.failure").exists, "no failure")
    }
}
