// MMReplayUITests — feature 439 (R02-G14-09) T-R02G1409-004, modelled on feature 429 (FR-R02G1409-002; SC-R02G1409-001;
// clarification Q2): the replay of Moonlit Mechanism (R02-G14) inside the one app. After level 1 is won with its
// certified actions (`MM.winLevelOne`), "Replay best solution" (`replay`, offered when the level has a verified stored
// solution) starts the stored trace on a fresh play of the level in replay mode with the tutorial done (the canvas no
// longer reports the win); Step (`replay-step`, value `MoonlitMechanismControls.replayStepValue`, "Action k of n"; the
// position line `replay-position` reads "Replay: action k of n") is pressed, at most three more times than the trace's
// length, until the step's value reads "Action n of n" and the canvas description
// (`MoonlitMechanismPresenter.describe`) says "The shadows match every required key frame."; Stop (`replay-stop`, value
// "3 actions", `MoonlitMechanismControls.replayStopValue`) returns to the campaign (`replay.stop`: the replay controls
// go, the `campaign` button reads "selected") and Replay is offered again. Short bounded waits; one test under 90 s
// apart from the automation-session setup of the launch. System accessibility audits wait for the device campaign
// (owner ruling of 2026-11-13).
import XCTest

final class MMReplayUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    /// Replay steps through the stored solution to its winning end and Stop returns to the campaign.
    @MainActor
    func testReplayOfTheSolvedLevelEndsWonAndStopReturnsToTheCampaign() {
        let app = MM.winLevelOne()
        XCTAssertTrue(MM.tap(app, "replay"), "Replay is tapped")
        let step = MM.control(app, "replay-step")
        XCTAssertTrue(step.waitForExistence(timeout: MM.shortWait), "the replay runs")
        XCTAssertTrue(MM.waitForDescription(app) { !$0.contains(MM.won) },
                      "the replay starts on a fresh play: \(MM.description(app))")

        guard let start = MM.replayPosition(MM.value(app, "replay-step")) else {
            XCTFail("Step shows no position: \(MM.value(app, "replay-step"))")
            return
        }
        let n = start.length
        XCTAssertEqual(start.position, 0, "the replay starts before its first action")
        XCTAssertEqual(n, MM.levelOneTraceLength, "the stored trace holds the turn, the lamp step and the run")
        XCTAssertEqual(MM.value(app, "replay-stop"), "\(n) actions", "Stop names the trace's actions")
        XCTAssertEqual(MM.control(app, "replay-position").label, "Replay: action 0 of \(n)",
                       "the position line starts at the beginning")
        // Step is found and scrolled into view once; each press then taps the same element and waits for its value to
        // move on (re-finding and revealing it on every press costs seconds against the 90 s bound).
        XCTAssertTrue(MM.shown(app, "replay-step") != nil, "Step is shown")
        // The loop follows the step's own position ("Action k of n", the replay's records played): a press counts once
        // its value moves on; a press the simulator did not deliver (or whose value moves after the wait) is retried,
        // within n + 3 presses. The canvas description can say the win a moment after the last step, so it is read only
        // once the trace is played.
        var steps = 0
        var presses = 0
        while presses < n + 3, (MM.replayPosition(MM.value(app, "replay-step"))?.position ?? n) < n {
            let before = MM.value(app, "replay-step")
            step.tap()
            presses += 1
            if MM.waitForValue(step, timeout: 5, { $0 != before }) { steps += 1 }
        }
        XCTAssertTrue(MM.waitForDescription(app) { $0.contains(MM.won) },
                      "the replay ends won: \(MM.description(app))")
        XCTAssertEqual(steps, n, "the replay is won by exactly its \(n) actions (\(presses) presses)")
        XCTAssertEqual(MM.value(app, "replay-step"), "Action \(n) of \(n)", "the replay played its whole trace")

        XCTAssertTrue(MM.tap(app, "replay-stop"), "Stop is tapped")
        XCTAssertTrue(waitUntilGone(step, timeout: MM.shortWait), "the replay has ended")
        XCTAssertTrue(MM.waitForValue(MM.control(app, "campaign")) { $0 == "selected" },
                      "Stop returns to the campaign (campaign is \(MM.value(app, "campaign")))")
        XCTAssertTrue(MM.control(app, "replay").waitForExistence(timeout: MM.shortWait), "Replay is offered again")
        XCTAssertFalse(element(app, "session.failure").exists, "no failure")
    }
}
