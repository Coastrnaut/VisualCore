// GASControlsUITests — feature 193 (UA-F07) T-U07-015: port of the standalone app's ControlsUITests (feature 013
// T-A01-208; FR-A01-201, FR-A01-203, FR-A01-204, FR-A01-207) into the one app. Time: play and pause, scrub to the
// middle of the loop, the value text agrees with the slider and stands still while paused. Preset, palette, seed and
// parameters: a preset sets its seed, a palette becomes selected, shuffle changes the seed, a parameter slider moves
// its value and a reset control appears that returns it. The controls are A01's native controls below the canvas
// (the standalone app opened them in a sheet).
import XCTest

final class GASControlsUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    /// The number of seconds at the start of "60.0 s" or "60.0 seconds".
    private static func seconds(_ text: String) -> Double? {
        Double(text.split(separator: " ").first ?? "")
    }

    @MainActor
    func testTimeControls() {
        let app = GAS.open()
        let play = GAS.control(app, "time.playPause")
        GAS.reveal(app, play)
        XCTAssertEqual(play.label, "Pause", "a fresh composition plays")
        play.tap()
        XCTAssertTrue(GAS.waitForLabel(play) { $0 == "Play" }, "the label switches to Play when paused: \(play.label)")

        let scrub = app.sliders[GAS.id("time.scrub")]
        waitFor(scrub, timeout: VC.wait)
        XCTAssertEqual(scrub.label, "Time")
        scrub.adjust(toNormalizedSliderPosition: 0.5)
        let value = app.staticTexts[GAS.id("time.value")]
        waitFor(value, timeout: VC.wait)
        // XCUITest maps the position through the slider's frame and thumb insets, so the exact second depends on the
        // layout (the slider shares its row with the play button and the value text); what matters is a scrub to the
        // middle of the 120 s loop (30–70 %), reported by the value text exactly as the slider speaks it.
        _ = GAS.waitForLabel(value) { (Self.seconds($0) ?? 0) > 1 }
        let t = Self.seconds(value.label) ?? -1
        XCTAssertTrue((36...84).contains(t), "scrubbed to the middle of the loop: \(value.label)")
        XCTAssertEqual(Self.seconds((scrub.value as? String) ?? ""), t, "the text matches the slider's spoken value")
        let paused = value.label
        sleep(1)
        XCTAssertEqual(value.label, paused, "the time stands still while paused")
        XCTAssertEqual(play.label, "Play")
    }

    @MainActor
    func testPresetPaletteSeedAndParameters() {
        let app = GAS.open()
        // The one app starts A01 in the Particles family; the standalone test edited Gradient Noise.
        GAS.tap(app, "family.gradient-noise")
        GAS.expectFamily(app, "Gradient Noise")

        GAS.tap(app, "preset.noise-tide")
        let seed = GAS.control(app, "seed.value")
        XCTAssertTrue(GAS.waitForLabel(seed) { $0 == "Seed 2024" }, "the Tide preset sets its seed: \(seed.label)")

        let neon = GAS.control(app, "palette.neon")
        GAS.reveal(app, neon)
        neon.tap()
        let deadline = Date().addingTimeInterval(VC.wait)
        while !neon.isSelected, Date() < deadline { usleep(200_000) }
        XCTAssertTrue(neon.isSelected, "the chosen palette is selected")

        GAS.tap(app, "seed.shuffle")
        XCTAssertTrue(GAS.waitForLabel(seed) { $0.hasPrefix("Seed ") && $0 != "Seed 2024" },
                      "shuffle picks another seed: \(seed.label)")

        let warp = app.sliders[GAS.id("parameter.warp")]
        GAS.reveal(app, warp)
        XCTAssertEqual(warp.label, "Warp")
        let before = warp.value as? String
        warp.adjust(toNormalizedSliderPosition: 0.95)
        let moved = Date().addingTimeInterval(VC.wait)
        while (warp.value as? String) == before, Date() < moved { usleep(200_000) }
        XCTAssertNotEqual(warp.value as? String, before, "the value text follows the slider")

        let reset = app.buttons[GAS.id("reset.warp")]
        waitFor(reset, timeout: VC.wait, "a changed parameter offers its reset")
        XCTAssertEqual(reset.label, "Reset Warp")
        GAS.reveal(app, reset)
        reset.tap()
        XCTAssertTrue(waitUntilGone(reset), "the reset control goes once the value is back")
        XCTAssertEqual(warp.value as? String, before, "reset returns the preset's value")
        GAS.attachScreenshot(app, named: "a01-controls", to: self)
    }
}
