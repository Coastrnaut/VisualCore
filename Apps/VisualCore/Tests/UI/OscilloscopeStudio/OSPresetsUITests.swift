// OSPresetsUITests — feature 066 (A08-P06) T-A08-609: Freeze holds the trace (the switch is on and the trace status and
// the canvas say frozen) and Cursors shows the cursor sliders; in a second test the built-in preset "Bass detail" is
// applied (100 Hz, ×2, 5 ms per division; the row is the selected one) and "Save preset" with a name lists a new saved
// preset after the three built-ins that becomes the selected one. The microphone is never chosen. System accessibility
// audits wait for the device campaign (owner ruling of 2026-11-13).
import XCTest

final class OSPresetsUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    /// Freeze on, Cursors on (Measure section).
    @MainActor
    func testFreezeAndCursors() {
        let app = OS.open()

        // Freeze: off on a fresh start; on after the flip, and the held window is named.
        XCTAssertEqual(OS.value(app, "freeze.toggle"), "0", "a fresh start is not frozen")
        OS.flip(app, "freeze.toggle")
        XCTAssertEqual(OS.value(app, "freeze.toggle"), "1", "the trace is frozen")
        XCTAssertTrue(OS.waitForLabel(OS.control(app, "trace.status"), timeout: OS.shortWait) { $0.hasPrefix("Frozen") },
                      "the trace status says frozen: \(OS.traceStatus(app))")
        XCTAssertTrue(OS.waitForLabel(OS.canvas(app), timeout: OS.shortWait) { $0.contains(", frozen") },
                      "the canvas says frozen: \(OS.description(app))")

        // Cursors: hidden on a fresh start; shown after the flip, with the time cursor sliders of the waveform view.
        XCTAssertEqual(OS.value(app, "cursors.show"), "0", "a fresh start hides the cursors")
        OS.flip(app, "cursors.show")
        XCTAssertEqual(OS.value(app, "cursors.show"), "1", "the cursors are shown")
        XCTAssertTrue(OS.slider(app, "cursor.a").waitForExistence(timeout: OS.shortWait), "cursor A is offered")
        XCTAssertTrue(OS.slider(app, "cursor.b").exists, "cursor B is offered")

        XCTAssertEqual(OS.value(app, "source.picker"), OS.testSignal, "the microphone is not chosen")
        XCTAssertFalse(element(app, "session.failure").exists, "no failure")
    }

    /// Built-in preset Apply, Save preset.
    @MainActor
    func testBuiltInPreset() {
        let app = OS.open()

        // Built-in preset: Bass detail (row 1) is sine 100 Hz at ×2 and 5 ms per division in the waveform view.
        let bass = "preset.1"
        XCTAssertEqual(OS.control(app, bass).label, "Apply preset " + OS.builtInPresets[1], "row 1 is Bass detail")
        OS.tap(app, bass)
        XCTAssertTrue(OS.waitForSelectedPreset(app, bass), "Bass detail is the selected preset (\(OS.value(app, bass)))")
        XCTAssertTrue(OS.waitForLabel(OS.canvas(app), timeout: OS.shortWait) {
            $0.hasPrefix(OS.describedPrefix + "test signal, sine 100 Hz,") && $0.contains(", 5 ms per division, gain ×2, ")
        }, "the canvas names the bass settings: \(OS.description(app))")
        XCTAssertEqual(OS.value(app, "gain.select"), "×2", "the gain picker follows the preset")
        XCTAssertEqual(OS.value(app, "timebase.select"), "5 ms per division", "the timebase picker follows the preset")
        XCTAssertFalse(element(app, "session.failure").exists, "no failure")
    }

    /// Saving the current settings under a name lists the preset after the built-ins, selected (its own test keeps each
    /// run well under 60 s).
    @MainActor
    func testSavePreset() {
        let app = OS.open()

        // Save preset: a saved preset with the name appears after the three built-ins and becomes selected.
        let name = "Low hum"
        OS.type(app, "preset.name", name)
        OS.tap(app, "preset.save")
        let savedID = "preset.\(OS.builtInPresets.count)"
        let saved = OS.control(app, savedID)
        XCTAssertTrue(saved.waitForExistence(timeout: OS.shortWait), "the saved preset is listed")
        XCTAssertEqual(saved.label, "Apply preset " + name, "the saved preset carries its name")
        XCTAssertTrue(OS.waitForSelectedPreset(app, savedID), "the saved preset is the selected one (\(OS.value(app, savedID)))")
        XCTAssertTrue(OS.value(app, savedID).hasPrefix("saved"), "the row says saved: \(OS.value(app, savedID))")
        XCTAssertFalse(OS.control(app, "preset.message").exists, "no store message after saving")
        XCTAssertEqual(OS.value(app, "source.picker"), OS.testSignal, "the microphone is not chosen")
        XCTAssertFalse(element(app, "session.failure").exists, "no failure")
    }
}
