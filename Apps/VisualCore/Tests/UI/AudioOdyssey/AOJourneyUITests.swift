// AOJourneyUITests — feature 059 (A07-P06) T-A07-609 (FR-A07-630): Audio Odyssey opens on the demo signal; the worlds
// Landscape, Star corridor and Tunnel are switched by identifier (each becomes selected and the canvas names it), the
// flight pauses and resumes; in a second test the speed slider changes the speed and calm motion is switched on. The
// microphone is never chosen. System accessibility audits wait for the device campaign (owner ruling of 2026-11-13).
import XCTest

final class AOJourneyUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    /// The three worlds, then Pause and Resume (all in the Journey section at the top of the controls).
    @MainActor
    func testWorldsPauseAndResume() {
        let app = AO.open()

        for (index, name) in [(1, "Landscape"), (2, "Star corridor"), (0, "Tunnel")] {
            AO.choose(app, "world.\(index)", upFirst: true)
            XCTAssertTrue(AO.waitForLabel(AO.canvas(app), timeout: AO.shortWait) {
                $0.hasPrefix(AO.describedPrefix + name + ",")
            }, "the canvas names \(name): \(AO.description(app))")
        }

        AO.tap(app, "flight.pause", upFirst: true)
        XCTAssertTrue(AO.control(app, "flight.resume").waitForExistence(timeout: AO.shortWait), "Resume is offered")
        XCTAssertTrue(AO.waitForLabel(AO.canvas(app), timeout: AO.shortWait) { $0.contains(", paused,") },
                      "the canvas says paused: \(AO.description(app))")

        AO.tap(app, "flight.resume", upFirst: true)
        XCTAssertTrue(AO.control(app, "flight.pause").waitForExistence(timeout: AO.shortWait), "Pause is offered again")
        XCTAssertTrue(AO.waitForLabel(AO.canvas(app), timeout: AO.shortWait) { $0.contains(", flying,") },
                      "the canvas says flying: \(AO.description(app))")
        XCTAssertFalse(element(app, "session.failure").exists, "no failure")
    }

    /// The speed slider and calm motion (Comfort section); its own test keeps each under the 60 s limit.
    @MainActor
    func testSpeedSliderAndCalmMotion() {
        let app = AO.open()

        // Speed: 0.5…7 units per second in steps of 0.5; a fresh start flies at 4.
        let speed = "speed.slider"
        let before = AO.sliderValue(app, speed)
        // A drag on the simulator sometimes does not register; up to three drags to different positions, each followed
        // by a bounded wait, because the spoken value follows the state that the next frame refreshes.
        var changed = false
        for position in [0.9, 0.2, 0.7] where !changed {
            AO.adjust(app, speed, to: CGFloat(position))
            changed = AO.waitForValue(AO.slider(app, speed), timeout: 2) { $0 != before && $0.hasSuffix("units per second") }
        }
        XCTAssertTrue(changed, "the speed changed from \(before) (now \(AO.sliderValue(app, speed)))")
        let spoken = AO.sliderValue(app, speed)
        XCTAssertTrue(AO.waitForLabel(AO.canvas(app), timeout: AO.shortWait) { $0.contains(", \(spoken), ") },
                      "the canvas names the new speed \(spoken): \(AO.description(app))")

        // Calm motion: off on a fresh start, on after the flip, and the canvas says so.
        AO.flip(app, "comfort.calm")
        XCTAssertEqual(AO.switchValue(app, "comfort.calm"), "1", "calm motion is on")
        XCTAssertTrue(AO.waitForLabel(AO.canvas(app), timeout: AO.shortWait) { $0.contains("calm motion") },
                      "the canvas says calm motion: \(AO.description(app))")

        XCTAssertNotEqual(AO.control(app, "source.picker").value as? String, "Microphone", "the microphone is not chosen")
        XCTAssertFalse(element(app, "session.failure").exists, "no failure")
    }
}
