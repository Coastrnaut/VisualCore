// AOPresetsUITests — feature 059 (A07-P06) T-A07-609 (FR-A07-630): a mapping change (what the tunnel width follows),
// the built-in journey "Rolling hills" applied (the canvas names the Landscape), and "Save journey" with a name lists a
// new saved journey that becomes the selected one. The microphone is never chosen. System accessibility audits wait
// for the device campaign (owner ruling of 2026-11-13).
import XCTest

final class AOPresetsUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    /// Mapping change (its own test keeps each run well under 60 s).
    @MainActor
    func testMappingChange() {
        let app = AO.open()

        // Mapping: the tunnel width follows the bass on a fresh start; the menu picks the highs.
        let channel = "mapping.primary.channel"
        XCTAssertTrue(AO.pick(app, channel, "Highs"),
                      "the tunnel width follows the highs (now \(AO.control(app, channel).value as? String ?? "nil"))")
        XCTAssertNotEqual(AO.control(app, "source.picker").value as? String, "Microphone", "the microphone is not chosen")
        XCTAssertFalse(element(app, "session.failure").exists, "no failure")
    }

    /// Built-in journey Apply, Save journey.
    @MainActor
    func testBuiltInJourneyAndSave() {
        let app = AO.open()

        // Built-in journey: Rolling hills (row 1) shows the Landscape at 4 units per second with standard easing.
        AO.tap(app, "preset.1")
        XCTAssertTrue(AO.waitForSelection(AO.control(app, "preset.1")), "Rolling hills is the selected journey")
        XCTAssertTrue(AO.waitForLabel(AO.canvas(app), timeout: AO.shortWait) {
            $0.hasPrefix(AO.describedPrefix + "Landscape, 4 units per second, standard easing")
        }, "the canvas names the Landscape: \(AO.description(app))")

        // Save journey: a saved journey with the name appears after the three built-ins and becomes selected.
        let name = "Night drive"
        AO.type(app, "preset.name", name)
        AO.tap(app, "preset.save")
        let saved = AO.control(app, "preset.\(AO.builtInJourneys.count)")
        XCTAssertTrue(saved.waitForExistence(timeout: AO.shortWait) || app.staticTexts[name].exists,
                      "the saved journey is listed")
        XCTAssertEqual(saved.label, name, "the saved journey carries its name")
        XCTAssertTrue(AO.waitForSelection(saved), "the saved journey is the selected one")
        XCTAssertFalse(AO.control(app, "preset.message").exists, "no library message after saving")
        XCTAssertNotEqual(AO.control(app, "source.picker").value as? String, "Microphone", "the microphone is not chosen")
        XCTAssertFalse(element(app, "session.failure").exists, "no failure")
    }
}
