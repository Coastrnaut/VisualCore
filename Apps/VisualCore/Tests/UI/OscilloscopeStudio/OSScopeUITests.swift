// OSScopeUITests — feature 066 (A08-P06) T-A08-609: Oscilloscope Studio opens on the stereo test signal; the waveform,
// the gain and the timebase are changed through their menu pickers (each picker speaks the new choice and the canvas
// names it); in a second test the view switches to XY (the trace status and the canvas name the XY view of the two
// test channels, with no "XY needs two channels" mark) and to the spectrum. The microphone is never chosen. System
// accessibility audits wait for the device campaign (owner ruling of 2026-11-13).
import XCTest

final class OSScopeUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    /// Waveform Square, gain ×2, timebase 0.5 ms per division (Signal and Display sections).
    @MainActor
    func testWaveformGainAndTimebase() {
        let app = OS.open()

        // A fresh start: sine 1 kHz, ×1, 1 ms per division.
        XCTAssertEqual(OS.value(app, "signal.waveform"), "Sine", "a fresh start draws the sine")
        XCTAssertTrue(OS.pick(app, "signal.waveform", "Square"),
                      "the waveform is Square (now \(OS.value(app, "signal.waveform")))")
        XCTAssertTrue(OS.waitForLabel(OS.canvas(app), timeout: OS.shortWait) {
            $0.hasPrefix(OS.describedPrefix + "test signal, square 1 kHz,")
        }, "the canvas names the square wave: \(OS.description(app))")

        XCTAssertTrue(OS.pick(app, "gain.select", "×2"), "the gain is ×2 (now \(OS.value(app, "gain.select")))")
        XCTAssertTrue(OS.pick(app, "timebase.select", "0.5 ms per division"),
                      "the timebase is 0.5 ms per division (now \(OS.value(app, "timebase.select")))")
        XCTAssertTrue(OS.waitForLabel(OS.canvas(app), timeout: OS.shortWait) {
            $0.contains(", 0.5 ms per division, gain ×2, ")
        }, "the canvas names the timebase and the gain: \(OS.description(app))")

        XCTAssertEqual(OS.value(app, "source.picker"), OS.testSignal, "the microphone is not chosen")
        XCTAssertFalse(element(app, "session.failure").exists, "no failure")
    }

    /// The view picker: XY (its own test keeps each run well under 60 s).
    @MainActor
    func testXYView() {
        let app = OS.open()

        XCTAssertEqual(OS.value(app, "display.select"), "Waveform", "a fresh start shows the waveform view")

        // XY: the stereo test signal plots left 1 kHz against right 1.5 kHz; no "needs two channels" mark.
        XCTAssertTrue(OS.pick(app, "display.select", "XY"), "the view is XY (now \(OS.value(app, "display.select")))")
        let status = OS.control(app, "trace.status")
        XCTAssertTrue(OS.waitForLabel(status, timeout: OS.shortWait) { $0.hasPrefix("XY view, 2 channels") },
                      "the trace status names the XY view: \(OS.traceStatus(app))")
        XCTAssertTrue(OS.waitForLabel(OS.canvas(app), timeout: OS.shortWait) {
            $0.contains("XY view, left 1 kHz against right 1.5 kHz (2 : 3)")
        }, "the canvas names the XY view: \(OS.description(app))")
        XCTAssertFalse(OS.control(app, "display.status").exists, "two channels: no XY fallback mark")
        XCTAssertFalse(element(app, "session.failure").exists, "no failure")
    }

    /// The view picker: Spectrum (its own test keeps each run well under 60 s).
    @MainActor
    func testSpectrumView() {
        let app = OS.open()
        let status = OS.control(app, "trace.status")

        // Spectrum: the left channel's levels against frequency, relative to full scale.
        XCTAssertTrue(OS.pick(app, "display.select", "Spectrum"),
                      "the view is Spectrum (now \(OS.value(app, "display.select")))")
        XCTAssertTrue(OS.waitForLabel(status, timeout: OS.shortWait) { $0.hasPrefix("Spectrum view, left channel") },
                      "the trace status names the spectrum view: \(OS.traceStatus(app))")
        XCTAssertTrue(OS.waitForLabel(OS.canvas(app), timeout: OS.shortWait) { $0.contains(", spectrum view, left channel,") },
                      "the canvas names the spectrum view: \(OS.description(app))")

        XCTAssertEqual(OS.value(app, "source.picker"), OS.testSignal, "the microphone is not chosen")
        XCTAssertFalse(element(app, "session.failure").exists, "no failure")
    }
}
