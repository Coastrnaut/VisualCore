// AUReleaseUITests — feature 157 (A21-P06) T-A21-608 (FR-A21-607; SC-A21-604): the first-session defaults of Aurora
// (A21) inside the one app, at the release gate (clarification Q5, manual §11 first-session flow). A fresh start
// (erased data, `AU.fresh`) opens A21 on the default sky: the canvas description (`AuroraPresenter.describe`) names
// Polar night, and the toggles `sound`, `still` and `reduced-flash` read off. One journey, well under 60 s. System
// accessibility audits wait for the device campaign (owner ruling of 2026-11-13).
import XCTest

final class AUReleaseUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    /// A fresh start opens on Polar night with the sound, Still sky and Reduced flashing off.
    @MainActor
    func testAFreshStartOpensOnTheDefaultSkyWithEverythingOff() {
        let app = AU.open(arguments: AU.fresh)
        XCTAssertTrue(AU.waitForDescription(app) { $0.contains(AU.presets[0]) },
                      "a fresh sky is Polar night: \(AU.description(app))")

        for name in ["sound", "still", "reduced-flash"] {
            waitFor(AU.control(app, name), timeout: AU.shortWait, "the \(name) toggle is there")
            XCTAssertTrue(AU.isOff(AU.value(app, name)), "a fresh start has \(name) off (\(AU.value(app, name)))")
        }
        XCTAssertFalse(element(app, "session.failure").exists, "no failure")
    }
}
