// VOReplayUITests — feature 449 (R02-G15-09) T-R02G1509-004, modelled on feature 439 (FR-R02G1509-002;
// SC-R02G1509-001; clarification Q2): the replay of Voxel Origami (R02-G15) inside the one app. After level 1 is won
// with its certified turns (`VO.winLevelOne`), "Replay best solution" (`replay`, offered when the level has a verified
// stored solution) starts the stored trace on a fresh play of the level in replay mode with the tutorial done (the
// canvas no longer reports the win); Step (`replay-step`, value `VoxelOrigamiControls.replayStepValue`, "Turn k of n";
// the position line `replay-position` reads "Replay: turn k of n") is pressed, at most three more times than the
// trace's length, until the step's value reads "Turn n of n" and the canvas description
// (`VoxelOrigamiPresenter.describe`) says "The chain matches the target shape."; Stop (`replay-stop`, value "2 turns",
// `VoxelOrigamiControls.replayStopValue`) returns to the campaign (`replay.stop`: the replay controls go, the
// `campaign` button reads "selected") and Replay is offered again. Short bounded waits; one test under 90 s apart from
// the automation-session setup of the launch. System accessibility audits wait for the device campaign (owner ruling
// of 2026-11-13).
import XCTest

final class VOReplayUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    /// Replay steps through the stored solution to its winning end and Stop returns to the campaign.
    @MainActor
    func testReplayOfTheSolvedLevelEndsWonAndStopReturnsToTheCampaign() {
        let app = VO.winLevelOne()
        XCTAssertTrue(VO.tap(app, "replay"), "Replay is tapped")
        let step = VO.control(app, "replay-step")
        XCTAssertTrue(step.waitForExistence(timeout: VO.shortWait), "the replay runs")
        XCTAssertTrue(VO.waitForDescription(app) { !$0.contains(VO.won) },
                      "the replay starts on a fresh play: \(VO.description(app))")

        guard let start = VO.replayPosition(VO.value(app, "replay-step")) else {
            XCTFail("Step shows no position: \(VO.value(app, "replay-step"))")
            return
        }
        let n = start.length
        XCTAssertEqual(start.position, 0, "the replay starts before its first turn")
        XCTAssertEqual(n, VO.levelOneTraceLength, "the stored trace holds the two turns")
        XCTAssertEqual(VO.value(app, "replay-stop"), "\(n) turns", "Stop names the trace's turns")
        XCTAssertEqual(VO.control(app, "replay-position").label, "Replay: turn 0 of \(n)",
                       "the position line starts at the beginning")
        // Step is found and scrolled into view once; each press then taps the same element and waits for its value to
        // move on (re-finding and revealing it on every press costs seconds against the 90 s bound).
        XCTAssertTrue(VO.shown(app, "replay-step") != nil, "Step is shown")
        // The loop follows the step's own position ("Turn k of n", the replay's turns played): a press counts once its
        // value moves on; a press the simulator did not deliver (or whose value moves after the wait) is retried,
        // within n + 3 presses. The canvas description can say the win a moment after the last step, so it is read only
        // once the trace is played.
        var steps = 0
        var presses = 0
        while presses < n + 3, (VO.replayPosition(VO.value(app, "replay-step"))?.position ?? n) < n {
            let before = VO.value(app, "replay-step")
            step.tap()
            presses += 1
            if VO.waitForValue(step, timeout: 5, { $0 != before }) { steps += 1 }
        }
        XCTAssertTrue(VO.waitForDescription(app) { $0.contains(VO.won) },
                      "the replay ends won: \(VO.description(app))")
        XCTAssertEqual(steps, n, "the replay is won by exactly its \(n) turns (\(presses) presses)")
        XCTAssertEqual(VO.value(app, "replay-step"), "Turn \(n) of \(n)", "the replay played its whole trace")

        XCTAssertTrue(VO.tap(app, "replay-stop"), "Stop is tapped")
        XCTAssertTrue(waitUntilGone(step, timeout: VO.shortWait), "the replay has ended")
        XCTAssertTrue(VO.waitForValue(VO.control(app, "campaign")) { $0 == "selected" },
                      "Stop returns to the campaign (campaign is \(VO.value(app, "campaign")))")
        XCTAssertTrue(VO.control(app, "replay").waitForExistence(timeout: VO.shortWait), "Replay is offered again")
        XCTAssertFalse(element(app, "session.failure").exists, "no failure")
    }
}
