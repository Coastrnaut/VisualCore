// SandboxUITests — feature 033 T-A04-107 (FR-A04-106; US1 AC1/AC2; SC-A04-106): families with descriptions, bounded
// live count, pause/step/new seed.
import XCTest

final class SandboxUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    func openSandbox(_ extraArguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += extraArguments
        app.launch()
        let open = app.buttons["pu.home.open"]
        XCTAssertTrue(open.waitForExistence(timeout: 10))
        open.tap()
        XCTAssertTrue(app.staticTexts["pu.sandbox.live"].waitForExistence(timeout: 10))
        return app
    }

    /// (live, limit) from "Live particles: N of LIMIT".
    func counts(_ app: XCUIApplication) -> (Int, Int) {
        let parts = app.staticTexts["pu.sandbox.live"].label.components(separatedBy: CharacterSet.decimalDigits.inverted)
            .filter { !$0.isEmpty }.compactMap(Int.init)
        XCTAssertEqual(parts.count, 2, app.staticTexts["pu.sandbox.live"].label)
        return (parts.first ?? -1, parts.last ?? -1)
    }

    func testEveryFamilyIsSelectableAndDescribed() {
        let app = openSandbox()
        let expected = ["Fountain": "fountain", "Curtain": "curtain", "Halo": "ring", "Firework": "Bursts"]
        for (title, word) in expected {
            let segment = app.buttons[title]
            XCTAssertTrue(segment.waitForExistence(timeout: 5), title)
            segment.tap()
            let description = app.staticTexts["pu.sandbox.description"]
            let changed = expectation(for: NSPredicate(format: "label CONTAINS %@", word), evaluatedWith: description)
            wait(for: [changed], timeout: 5)
            XCTAssertTrue(segment.isSelected, title)
            XCTAssertTrue(app.descendants(matching: .any)["pu.sandbox.canvas"].label.contains(title), title)
        }
    }

    func testLiveCountGrowsAndStaysWithinTheLimit() {
        let app = openSandbox()
        let start = Date()
        var (live, limit) = counts(app)
        while live == 0, Date().timeIntervalSince(start) < 10 { Thread.sleep(forTimeInterval: 0.25); (live, limit) = counts(app) }
        XCTAssertGreaterThan(live, 0, "particles appear while playing")
        XCTAssertEqual(limit, 4_000)
        for _ in 0..<8 {
            Thread.sleep(forTimeInterval: 0.25)
            let (n, l) = counts(app)
            XCTAssertLessThanOrEqual(n, l)
        }
        XCTAssertTrue(app.staticTexts["pu.sandbox.dropped"].label.hasPrefix("Dropped: "))
    }

    func testPauseStepAndNewSeed() {
        let app = openSandbox()
        let play = app.buttons["pu.sandbox.play"]
        let step = app.buttons["pu.sandbox.step"]
        XCTAssertFalse(step.isEnabled, "Step is only for a paused scene")
        play.tap()                                         // pause
        XCTAssertTrue(step.isEnabled)
        let paused = counts(app).0
        Thread.sleep(forTimeInterval: 1)
        XCTAssertEqual(counts(app).0, paused, "a paused scene does not advance")
        for _ in 0..<12 { step.tap() }                     // 0.1 s of fountain: about 60 more particles
        XCTAssertGreaterThan(counts(app).0, paused, "Step advances a paused scene")
        app.buttons["pu.sandbox.reseed"].tap()
        XCTAssertEqual(counts(app).0, 0, "a new seed restarts the scene")
        step.tap()
        XCTAssertGreaterThan(counts(app).0, 0)
    }
}

extension SandboxUITests {
    /// Feature 033 T-A04-115 (spec edge cases: background): a playing scene plays again after the background; a paused
    /// scene stays paused.
    func testBackgroundRoundTripKeepsThePersonsChoice() {
        let app = openSandbox()
        let play = app.buttons["pu.sandbox.play"]
        XCUIDevice.shared.press(.home)
        XCTAssertTrue(app.wait(for: .runningBackground, timeout: 10) || app.wait(for: .runningBackgroundSuspended, timeout: 10))
        app.activate()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))
        XCTAssertTrue(play.waitForExistence(timeout: 5))
        XCTAssertEqual(play.label, "Pause", "still playing after the background")
        let before = counts(app).0
        Thread.sleep(forTimeInterval: 1)
        XCTAssertNotEqual(counts(app).0, before, "the scene advances again")

        play.tap()                                         // pause
        XCTAssertEqual(play.label, "Play")
        let paused = counts(app).0
        XCUIDevice.shared.press(.home)
        _ = app.wait(for: .runningBackgroundSuspended, timeout: 10)
        app.activate()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))
        XCTAssertEqual(play.label, "Play", "a paused scene stays paused")
        Thread.sleep(forTimeInterval: 1)
        XCTAssertEqual(counts(app).0, paused)
    }
}

extension SandboxUITests {
    /// Feature 034 T-A04-214 (US4 AC2; FR-A04-206): the GPU stage draws the scene; it advances while playing and
    /// holds while paused. Context recreation is covered by ParticleLayerSceneTests (analyze E1).
    func testGPUStageAdvancesAndHolds() {
        let app = openSandbox()
        XCTAssertEqual(app.staticTexts["pu.sandbox.renderer"].label, "Renderer: GPU")
        let start = Date()
        while counts(app).0 == 0, Date().timeIntervalSince(start) < 10 { Thread.sleep(forTimeInterval: 0.25) }
        let a = counts(app).0
        Thread.sleep(forTimeInterval: 0.5)
        XCTAssertNotEqual(counts(app).0, a, "the GPU frames advance the simulation")
        app.buttons["pu.sandbox.play"].tap()
        let held = counts(app).0
        Thread.sleep(forTimeInterval: 1)
        XCTAssertEqual(counts(app).0, held, "paused: the GPU stage redraws the held state")
        app.descendants(matching: .any)["pu.sandbox.canvas"].coordinate(withNormalizedOffset: CGVector(dx: 0.25, dy: 0.75)).tap()
        XCTAssertTrue(app.staticTexts["pu.sandbox.force"].label.hasPrefix("Force: Attractor at (-"), "taps work over the GPU stage")
    }

    /// Feature 034 T-A04-214 (US4 AC3): when the GPU path fails the CPU preview takes over with a note.
    func testCPUFallbackKeepsWorking() {
        let app = openSandbox(["-uitestRendererFailure", "YES"])
        XCTAssertTrue(app.staticTexts["pu.sandbox.renderer"].label.hasPrefix("Renderer: CPU preview ("))
        let start = Date()
        while counts(app).0 == 0, Date().timeIntervalSince(start) < 10 { Thread.sleep(forTimeInterval: 0.25) }
        XCTAssertGreaterThan(counts(app).0, 0, "the CPU preview advances the scene")
        app.descendants(matching: .any)["pu.sandbox.canvas"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertTrue(app.staticTexts["pu.sandbox.force"].label.hasPrefix("Force: Attractor at ("))
    }
}
