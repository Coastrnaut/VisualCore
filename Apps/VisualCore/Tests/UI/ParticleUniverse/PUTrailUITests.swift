// PUTrailUITests — feature 193 (UA-F07) T-U07-028: port of the standalone app's SandboxTrailUITests (feature 035
// A04-P03 T-A04-312; US3, US4; FR-A04-306; SC-A04-306) into the one app. The Trails toggle, the trail strength and the
// blend; trails under Reduce Flashing; trails across a background round trip.
//
// Differences from the standalone test, recorded in the test map: the trail strength appears only while trails are
// on (the standalone slider was shown disabled); the blend is the "Glowing blend" toggle (`blend`) instead of a
// Normal/Additive segment; there are no renderer and trail-note texts and no CPU preview (adapter difference 3), so
// the Reduce Flashing port turns on the one app's Reduce Flashing setting and checks that trails work under the
// brightness cap with no failure, and the round trip checks the toggle and that the scene runs again.
import XCTest

final class PUTrailUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    @MainActor
    func testTrailsStrengthAndBlend() {
        let app = PU.open()
        let trails = PU.toggle(app, "trails")
        PU.reveal(app, trails)
        XCTAssertEqual(PU.switchValue(app, "trails"), "0", "trails start off")
        XCTAssertFalse(PU.slider(app, "trailStrength").exists, "the strength needs trails on")
        PU.flip(app, "trails")
        XCTAssertEqual(PU.switchValue(app, "trails"), "1")
        let strength = PU.slider(app, "trailStrength")
        waitFor(strength, timeout: VC.wait, "the trail strength with trails on")
        PU.reveal(app, strength)
        XCTAssertTrue(strength.isEnabled)
        XCTAssertEqual(PU.value(app, "trailStrength"), "85 percent")
        PU.adjust(app, "trailStrength", to: 0.5)
        // XCUITest slider positioning is approximate: about half of 0…100 percent.
        XCTAssertTrue(PU.waitForValue(app, "trailStrength") { value in
            (35...65).contains(Int(value.split(separator: " ").first ?? "") ?? -1)
        }, PU.value(app, "trailStrength"))
        XCTAssertEqual(PU.switchValue(app, "blend"), "0", "normal blend first")
        PU.flip(app, "blend")
        XCTAssertEqual(PU.switchValue(app, "blend"), "1", "glowing (additive) blend")
        XCTAssertFalse(element(app, "session.failure").exists, "no failure")
    }

    /// Under the one app's Reduce Flashing the stage caps the brightness; trails still work and the scene runs.
    @MainActor
    func testTrailsWorkUnderReduceFlashing() {
        let app = PU.openWithSettings(reduceFlashing: true)
        PU.flip(app, "trails")
        XCTAssertEqual(PU.switchValue(app, "trails"), "1")
        let before = PU.waitForLive(app) { $0 > 0 }
        XCTAssertNotEqual(PU.waitForLive(app, timeout: 5) { $0 != before }, before, "the scene runs with trails")
        XCTAssertFalse(element(app, "session.failure").exists, "no failure")
        PU.attachScreenshot(app, named: "a04-trails-reduce-flashing", to: self)
    }

    @MainActor
    func testTrailsSurviveABackgroundRoundTrip() {
        let app = PU.open()
        PU.flip(app, "trails")
        XCTAssertEqual(PU.switchValue(app, "trails"), "1")
        PU.backgroundAndReturn(app)
        let trails = PU.toggle(app, "trails")
        waitFor(trails, timeout: VC.wait)
        XCTAssertEqual(PU.switchValue(app, "trails"), "1", "trails stay on")
        let live = PU.waitForLive(app) { $0 > 0 }
        XCTAssertNotEqual(PU.waitForLive(app, timeout: 5) { $0 != live }, live, "the stage runs again")
        XCTAssertFalse(element(app, "session.failure").exists, "no failure")
    }
}
