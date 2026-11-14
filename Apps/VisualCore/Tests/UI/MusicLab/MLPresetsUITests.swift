// MLPresetsUITests — feature 052 (A06-P06) T-A06-609 (US4 scenarios 1 and 2; FR-A06-630): a mapping strength slider
// changes the mapping, the built-in preset "Pulse geometry" shows the Geometry scene, and "Save current as…" with a
// name lists a new saved preset. The microphone is never chosen. System accessibility audits wait for the device
// campaign (owner ruling of 2026-11-13).
import XCTest

final class MLPresetsUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    /// Strength slider, built-in preset Apply, Save current as… (US4 scenario 1).
    @MainActor
    func testMappingBuiltInPresetAndSave() {
        let app = ML.open()

        // Mapping: the first strength slider of the Bars scene moves (0…4 in steps of 0.1).
        let gain = "mapping.0.0.gain"
        let before = ML.sliderValue(app, gain)
        // A drag on the simulator sometimes does not register; up to three drags to different positions, each followed
        // by a bounded wait, because the spoken value follows the state that the next frame refreshes.
        var changed = false
        for position in [0.9, 0.25, 0.6] where !changed {
            ML.adjust(app, gain, to: CGFloat(position))
            changed = ML.waitForValue(ML.slider(app, gain), timeout: 2) { $0 != before }
        }
        XCTAssertTrue(changed, "the strength changed from \(before) (now \(ML.sliderValue(app, gain)))")

        // Built-in preset: Pulse geometry shows the Geometry scene.
        let pulse = "preset.\(ML.builtInPresetIDs[2]).apply"
        ML.tap(app, pulse)
        XCTAssertTrue(ML.waitForLabel(ML.canvas(app), timeout: ML.shortWait) {
            $0.hasPrefix(ML.describedPrefix + "Geometry scene")
        }, "the canvas names Geometry: \(ML.description(app))")
        // The canvas description above proves the scene; scrolling back to the scene picker would double the run time.

        // Save current as…: a saved preset with its own Apply button (or its name) appears.
        let name = "Night drive"
        ML.type(app, "preset.name", name)
        ML.tap(app, "preset.save")
        let saved = ML.userPresetApplyButtons(app).firstMatch
        let listed = saved.waitForExistence(timeout: ML.shortWait) || app.staticTexts[name].exists
        XCTAssertTrue(listed, "the saved preset is listed")
        XCTAssertFalse(ML.control(app, "preset.message").exists, "no library message after saving")
        XCTAssertFalse(element(app, "session.failure").exists, "no failure")
    }
}
