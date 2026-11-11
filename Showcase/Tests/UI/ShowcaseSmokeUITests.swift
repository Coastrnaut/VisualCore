// ShowcaseSmokeUITests — feature 007 T-F610: repeatable smoke test (FR-F611; SC-F601, SC-F603–SC-F605; US1–US4).
// Real touches go through XCUITest → RenderView → PointerEvents; results are read from accessibility diagnostics
// (contract specs/007-showcase-app/contracts/showcase-contract.md).
import XCTest

final class ShowcaseSmokeUITests: XCTestCase {
    static let sceneIDs = ["gradient-texture", "animated-geometry", "distortion", "particles", "post-processing"]

    override func setUp() { continueAfterFailure = false }
    override func tearDown() { XCUIDevice.shared.orientation = .portrait }

    @MainActor private func launch(_ extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-uitestReduceMotion", "NO"] + extra
        app.launch()
        XCTAssertTrue(app.navigationBars["VisualCore"].waitForExistence(timeout: 20))
        return app
    }

    @MainActor private func open(_ id: String, in app: XCUIApplication) {
        let row = app.descendants(matching: .any)["showcase.scene.\(id)"]
        if !row.waitForExistence(timeout: 5) || !row.isHittable { app.swipeUp() }
        XCTAssertTrue(row.waitForExistence(timeout: 5), "row \(id)")
        row.tap()
        XCTAssertTrue(app.staticTexts["showcase.diagnostics"].waitForExistence(timeout: 10), "diagnostics for \(id)")
    }

    @MainActor private func back(_ app: XCUIApplication) {
        let button = app.navigationBars.buttons.element(boundBy: 0)
        if button.exists { button.tap() }
        XCTAssertTrue(app.navigationBars["VisualCore"].waitForExistence(timeout: 10))
    }

    @MainActor private func values(_ app: XCUIApplication) -> [String: String] {
        var out: [String: String] = [:]
        let label = app.staticTexts["showcase.diagnostics"].label
        for part in label.split(separator: " ") {
            let kv = part.split(separator: "=", maxSplits: 1)
            if kv.count == 2 { out[String(kv[0])] = String(kv[1]) }
        }
        if let r = label.range(of: "error=") { out["error"] = String(label[r.upperBound...]) }
        return out
    }

    @MainActor private func status(_ app: XCUIApplication) -> String { app.staticTexts["showcase.status"].label }

    /// Waits until `condition` holds, polling the accessibility tree every 0.1 s.
    @MainActor private func eventually(_ timeout: TimeInterval = 3, _ message: @autoclosure () -> String, _ condition: () -> Bool) {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        XCTAssertTrue(condition(), message())
    }

    /// Integer value of `key=` in a space-separated status string.
    private func number(_ key: String, in text: String) -> Double? {
        text.split(separator: " ").first { $0.hasPrefix("\(key)=") }.flatMap { Double($0.dropFirst(key.count + 1)) }
    }

    @MainActor private func framesAdvance(_ app: XCUIApplication, within timeout: TimeInterval = 2) {
        let start = Int(values(app)["frames"] ?? "") ?? 0
        eventually(timeout, "frames advance from \(start)") { (Int(values(app)["frames"] ?? "") ?? 0) > start }
    }

    @MainActor func testEveryScenePresentsFramesWithoutError() {
        // SC-F601, US1 AC1–AC3, SC-F603
        let app = launch()
        for id in Self.sceneIDs {
            open(id, in: app)
            framesAdvance(app)
            let v = values(app)
            XCTAssertEqual(v["error"], "none", "\(id): \(app.staticTexts["showcase.diagnostics"].label)")
            XCTAssertEqual(v["leaked"], "0")
            XCTAssertFalse(status(app).trimmingCharacters(in: .whitespaces).isEmpty, "\(id) reports status")
            back(app)
        }
    }

    @MainActor func testParticlesRespondToDragAndPinch() {
        // US3 AC2
        let app = launch()
        open("particles", in: app)
        let canvas = app.otherElements["showcase.canvas"]
        canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.7))
            .press(forDuration: 0.1, thenDragTo: canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.7, dy: 0.65)),
                   withVelocity: .slow, thenHoldForDuration: 0.2)
        eventually(3, "particles after drag: \(status(app))") { (number("particles", in: status(app)) ?? 0) > 0 }
        canvas.pinch(withScale: 2.5, velocity: 2)
        eventually(3, "zoom after pinch: \(status(app))") { (number("zoom", in: status(app)) ?? 0) > 1.2 }
    }

    @MainActor func testDistortionFollowsTheFingerAndSurvivesRotation() {
        // US3 AC1, edge case rotation
        let app = launch()
        open("distortion", in: app)
        let canvas = app.otherElements["showcase.canvas"]
        canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(forDuration: 0.1, thenDragTo: canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.6)),
                   withVelocity: .slow, thenHoldForDuration: 0.1)
        eventually(3, "touch reported: \(status(app))") { status(app).contains("last=") }
        let first = status(app)
        XCUIDevice.shared.orientation = .landscapeLeft
        sleep(2)
        framesAdvance(app)
        canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.3))
            .press(forDuration: 0.1, thenDragTo: canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.7, dy: 0.4)),
                   withVelocity: .slow, thenHoldForDuration: 0.1)
        eventually(3, "touch after rotation: \(status(app))") { status(app) != first && status(app).contains("last=") }
        XCTAssertEqual(values(app)["error"], "none")
    }

    @MainActor func testPostProcessingToggle() {
        // US2 AC2
        let app = launch(["-showcase.reduceFlashing", "NO"])
        open("post-processing", in: app)
        eventually(3, "graph active: \(status(app))") { status(app).hasPrefix("passes=grade>glow>wave") }
        let toggle = app.switches["showcase.effectToggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        (toggle.switches.firstMatch.exists ? toggle.switches.firstMatch : toggle).tap()
        eventually(3, "effect off: \(status(app))") { status(app) == "passes=off" }
        (toggle.switches.firstMatch.exists ? toggle.switches.firstMatch : toggle).tap()
        eventually(3, "effect back on: \(status(app))") { status(app).hasPrefix("passes=grade>glow>wave") }
        framesAdvance(app)
    }

    @MainActor func testContextLossRecovers() {
        // US4 AC2, SC-F605
        let app = launch()
        open("gradient-texture", in: app)
        framesAdvance(app)
        let gen = Int(values(app)["gen"] ?? "") ?? -1
        app.buttons["showcase.contextLoss"].tap()
        eventually(2, "generation +1") { Int(values(app)["gen"] ?? "") == gen + 1 }
        framesAdvance(app, within: 1.5)
        XCTAssertEqual(values(app)["leaked"], "0")
        XCTAssertEqual(values(app)["error"], "none")
    }

    @MainActor func testBackgroundAndForegroundResume() {
        // US4 AC3
        let app = launch()
        open("animated-geometry", in: app)
        framesAdvance(app)
        XCUIDevice.shared.press(.home)
        sleep(2)
        app.activate()
        XCTAssertTrue(app.staticTexts["showcase.diagnostics"].waitForExistence(timeout: 10))
        eventually(5, "active again: \(app.staticTexts["showcase.diagnostics"].label)") { values(app)["state"] == "active" }
        framesAdvance(app)
    }

    @MainActor func testInjectedShaderErrorShowsFileAndLine() {
        // US2 AC3, FR-F604
        let app = launch(["-showcaseInjectShaderError", "YES"])
        open("gradient-texture", in: app)
        let error = app.staticTexts["showcase.error"]
        XCTAssertTrue(error.waitForExistence(timeout: 5))
        XCTAssertTrue(error.label.hasPrefix("broken.frag:5:"), error.label)
        app.buttons["showcase.retry"].tap()
        eventually(3, "error cleared") { !app.staticTexts["showcase.error"].exists && values(app)["error"] == "none" }
    }

    @MainActor func testLargestTextSizeKeepsTheListUsable() {
        // SC-F604
        let app = launch(["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"])
        for id in Self.sceneIDs {
            let row = app.descendants(matching: .any)["showcase.scene.\(id)"]
            var tries = 0
            while !(row.exists && row.isHittable) && tries < 6 { app.swipeUp(); tries += 1 }
            XCTAssertTrue(row.exists && row.isHittable, "row \(id) reachable at the largest text size")
            XCTAssertFalse(row.label.isEmpty)
        }
    }
}
