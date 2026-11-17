// AUSoundUITests — feature 156 (A21-P05) T-A21-507 (FR-A21-502, FR-A21-506; SC-A21-503): the sound choice of Aurora
// (A21) inside the one app. A fresh start (erased data) reads the sound (`sound`) Off and the volume (`volume`) at its
// default; turning the sound on and moving the volume slider changes both controls; the presenter saves the choice in
// the sky preferences at once. After the app was ended, a start over the same storage (`AU.relaunch`, no reset) reads
// the sound On and the same volume. One journey, well under 60 s. System accessibility audits wait for the device
// campaign (owner ruling of 2026-11-13).
import XCTest

final class AUSoundUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    /// The sound turned on and a new volume survive the end of the app.
    @MainActor
    func testTheSoundChoiceComesBackAfterARelaunch() {
        let app = AU.open()
        waitFor(AU.control(app, "sound"), timeout: AU.shortWait, "the Sound toggle is there")
        XCTAssertTrue(AU.isOff(AU.value(app, "sound")), "a fresh start has the sound off (\(AU.value(app, "sound")))")

        XCTAssertTrue(AU.turnOn(app, "sound"), "the sound is turned on")
        guard let volume = AU.shown(app, "volume") else { return }
        let defaultVolume = AU.value(app, "volume")
        volume.adjust(toNormalizedSliderPosition: 0.4)
        XCTAssertTrue(AU.waitForValue(volume) { !$0.isEmpty && $0 != defaultVolume },
                      "the volume changed from \(defaultVolume) (now \(AU.value(app, "volume")))")
        let chosenVolume = AU.value(app, "volume")
        XCTAssertTrue(AU.isOn(AU.value(app, "sound")), "the sound reads on (\(AU.value(app, "sound")))")

        let second = AU.reopen(app)
        waitFor(AU.control(second, "sound"), timeout: AU.shortWait, "the Sound toggle is there after the relaunch")
        XCTAssertTrue(AU.waitForValue(AU.control(second, "sound")) { AU.isOn($0) },
                      "the sound is still on (now \(AU.value(second, "sound")))")
        XCTAssertTrue(AU.waitForValue(AU.control(second, "volume")) { $0 == chosenVolume },
                      "the volume is still \(chosenVolume) (now \(AU.value(second, "volume")))")
        XCTAssertFalse(element(second, "session.failure").exists, "no failure")
    }
}
