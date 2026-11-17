// ZGReleaseUITests — feature 150 (A20-P06) T-A20-608 (FR-A20-607; Clarifications Q5): the release journey of Digital
// Zen Garden (A20) inside the one app. A fresh start (erased data) opens A20 with the three calm switches of
// `GardenControls` (`calm-sound`, `calm-drift`, `calm-haptics`, native toggles whose value is "0" when off) all off;
// Make picture (`still-make`) draws the garden at 1600 by 1200 pixels, the picture message (`still-message`) reads
// `GardenPresenter.stillMadeMessage` ("The picture is ready to share: 1600 by 1200 pixels.") and the share control
// (`still-share`) is offered. One journey, short bounded waits (at most 10 s each), no sleeps, well under 60 s. System
// accessibility audits wait for the device campaign (owner ruling of 2026-11-13).
import XCTest

final class ZGReleaseUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    /// The message `GardenPresenter.stillMadeMessage` shows once the picture is written.
    private static let stillReady = "The picture is ready to share: 1600 by 1200 pixels."

    /// Whether the toggle value `value` reads off ("0" from a native switch, "Off" when spoken).
    private static func isOff(_ value: String) -> Bool { value == "0" || value == "Off" }

    /// A fresh start shows every calm switch off, and Make picture offers a 1600 by 1200 picture to share.
    @MainActor
    func testAFreshStartIsCalmAndMakesAPictureToShare() {
        let app = ZG.open()

        for name in ["calm-sound", "calm-drift", "calm-haptics"] {
            let toggle = ZG.control(app, name)
            XCTAssertTrue(waitFor(toggle, timeout: ZG.shortWait, "\(name) is there"), "\(name) is there")
            XCTAssertTrue(ZG.reveal(app, toggle), "\(name) is scrolled into view")
            XCTAssertTrue(ZG.waitForValue(toggle) { Self.isOff($0) },
                          "\(name) is off on a fresh start: \(String(describing: toggle.value))")
        }

        XCTAssertTrue(ZG.tap(app, "still-make"), "Make picture is tapped")
        let message = ZG.control(app, "still-message")
        XCTAssertTrue(ZG.waitForLabel(message, timeout: VC.wait) { $0 == Self.stillReady },
                      "the picture is ready: \(message)")
        let share = ZG.control(app, "still-share")
        XCTAssertTrue(share.waitForExistence(timeout: ZG.shortWait), "Share picture is offered")
        XCTAssertFalse(element(app, "session.failure").exists, "no failure")
    }
}
