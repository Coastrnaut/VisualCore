// SandboxTrailUITests — feature 035 A04-P03 T-A04-312 (US3, US4; FR-A04-306; SC-A04-306; contracts/app-ui.md):
// trails toggle, strength and blend; the Reduce Flashing note; trails unavailable in the CPU preview; trails across
// a background round trip.
import XCTest

final class SandboxTrailUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    func testTrailsStrengthAndBlend() {
        let app = launchSandbox()
        let trails = app.switches["pu.sandbox.trails"]
        reveal(trails, in: app)
        XCTAssertEqual(trails.value as? String, "0")
        let strength = app.sliders["pu.sandbox.trailStrength"]
        XCTAssertFalse(strength.isEnabled, "strength needs trails on")
        trails.switches.firstMatch.exists ? trails.switches.firstMatch.tap() : trails.tap()
        XCTAssertEqual(trails.value as? String, "1")
        reveal(strength, in: app)
        XCTAssertTrue(strength.isEnabled)
        XCTAssertEqual(strength.value as? String, "85 percent")
        strength.adjust(toNormalizedSliderPosition: 0.5)
        // XCUITest slider positioning is approximate: about half of 0…98 percent.
        let percent = Int((strength.value as? String ?? "").components(separatedBy: " ").first ?? "") ?? -1
        XCTAssertTrue((35...60).contains(percent), "\(strength.value ?? "")")
        let additive = app.buttons["Additive"]
        reveal(additive, in: app)
        additive.tap()
        XCTAssertTrue(additive.isSelected)
        XCTAssertEqual(app.staticTexts["pu.sandbox.renderer"].label, "Renderer: GPU")
        XCTAssertFalse(app.staticTexts["pu.sandbox.trailNote"].exists, "no note without Reduce Flashing")
    }

    func testReduceFlashingShowsTheCap() {
        let app = launchSandbox(["-uitestReduceFlashing", "YES"])
        let note = app.staticTexts["pu.sandbox.trailNote"]
        reveal(note, in: app)
        XCTAssertTrue(note.label.contains("Brightness limited (Reduce Flashing)"), note.label)
    }

    func testTrailsAreUnavailableInTheCPUPreview() {
        let app = launchSandbox(["-uitestRendererFailure", "YES"])
        let trails = app.switches["pu.sandbox.trails"]
        reveal(trails, in: app)
        XCTAssertFalse(trails.isEnabled)
        XCTAssertTrue(app.staticTexts["pu.sandbox.trailNote"].label.contains("Trails need the GPU renderer"))
    }

    func testTrailsSurviveABackgroundRoundTrip() {
        let app = launchSandbox()
        let trails = app.switches["pu.sandbox.trails"]
        reveal(trails, in: app)
        trails.switches.firstMatch.exists ? trails.switches.firstMatch.tap() : trails.tap()
        XCTAssertEqual(trails.value as? String, "1")
        XCUIDevice.shared.press(.home)
        XCTAssertTrue(app.wait(for: .runningBackground, timeout: 10) || app.wait(for: .runningBackgroundSuspended, timeout: 10))
        app.activate()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))
        XCTAssertEqual(app.staticTexts["pu.sandbox.renderer"].label, "Renderer: GPU")
        XCTAssertEqual(trails.value as? String, "1", "trails stay on")
        let live = app.staticTexts["pu.sandbox.live"].label
        let start = Date()
        while app.staticTexts["pu.sandbox.live"].label == live, Date().timeIntervalSince(start) < 5 { Thread.sleep(forTimeInterval: 0.25) }
        XCTAssertNotEqual(app.staticTexts["pu.sandbox.live"].label, live, "the GPU stage runs again")
    }
}
