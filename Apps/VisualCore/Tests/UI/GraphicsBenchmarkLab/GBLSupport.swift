// GBLSupport — feature 177 (A24-P05) T-A24-507 (FR-A24-505, SC-A24-504; clarifications "What does 'About these
// numbers' say" and the background fact; contracts/review.md "Interface"): helpers of the interface tests of Graphics
// Benchmark Lab (A24) inside the one app, modelled on Visual Programming Lab's `VPLSupport`. Every launch carries
// `-vcCandidates` (DebugLaunch: the candidates' catalog entries become available and are registered). A fresh start
// erases the data (`-vcResetData`), skips the welcome and opens the experience directly with
// `-openExperience a24.graphics-benchmark-lab`. A fresh lab is "Ready".
//
// The controls are found by the identifiers of `GBLControls` and `ResultsView` (`port.identifier(name)`, that is
// `experience.a24.graphics-benchmark-lab.<name>`): `case-quads`, `run-start`, `run-stop`, `status` (spoken as
// "Status, <word>"), `summary`, `result-save`, `results`, `result-row-<n>`, `result-open-<n>`, `result-opened`,
// `results-done`; and A24-P05's `qualification` (in the summary and the opened result), `repeatability`, `explain`,
// `explanation` and `explanation-done`. The results and the explanation are inline in the controls (never a sheet, a
// menu or a popover over the drawing: the A23-P05 lesson), so every control is scrolled into view before it is tapped.
// Every wait is bounded (``shortWait``, `VC.wait`, `VC.firstWait`). Everything lives in the namespace `GBL`, so nothing
// collides with the shared helpers of `AppUITestSupport` or the other experiences. System accessibility audits wait
// for the device campaign (owner ruling of 2026-11-13).
import Foundation
import XCTest

/// Launch arguments, identifiers and helpers of the A24 interface tests.
enum GBL {
    /// The experience's id in the catalog.
    static let experienceID = "a24.graphics-benchmark-lab"
    /// The prefix of every identifier of the experience's controls.
    static let prefix = "experience.a24.graphics-benchmark-lab."
    /// The debug argument that makes the candidates available (DebugLaunch).
    static let candidates = "-vcCandidates"
    /// A first start with erased data, straight into A24.
    static let fresh = [VC.reset, VC.skipWelcome, candidates, VC.openExperience, experienceID]
    /// A start over the existing storage, straight into A24 (``fresh`` without the reset).
    static let relaunch = [VC.skipWelcome, candidates, VC.openExperience, experienceID]
    /// The longest a single check waits.
    static let shortWait: TimeInterval = 5
    /// The most drags one reveal makes.
    static let maxDrags = 24

    /// The full identifier of the control `name`.
    static func id(_ name: String) -> String { prefix + name }

    /// The control `name` of A24, of any element type.
    @MainActor
    static func control(_ app: XCUIApplication, _ name: String) -> XCUIElement {
        element(app, id(name))
    }

    /// The live canvas of the session.
    @MainActor
    static func canvas(_ app: XCUIApplication) -> XCUIElement { element(app, VC.canvas) }

    /// The status word without its spoken prefix ("Ready"), or "" when it is not there.
    @MainActor
    static func status(_ app: XCUIApplication) -> String {
        let s = control(app, "status")
        guard s.exists else { return "" }
        let label = s.label
        let spoken = "Status, "
        return label.hasPrefix(spoken) ? String(label.dropFirst(spoken.count)) : label
    }

    /// Waits until the status word satisfies `condition`; true when it does.
    @MainActor
    static func waitForStatus(_ app: XCUIApplication, timeout: TimeInterval = GBL.shortWait,
                              _ condition: (String) -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition(status(app)), Date() < deadline { usleep(200_000) }
        return condition(status(app))
    }

    /// The spoken text of `target`: its label and, when it has one, its value, or "" when it is not there.
    @MainActor
    static func spoken(_ target: XCUIElement) -> String {
        guard target.exists else { return "" }
        let value = target.value as? String ?? ""
        return value.isEmpty ? target.label : target.label + ", " + value
    }

    /// Launches the app with `arguments` and waits until A24 runs with its controls and a Ready status.
    @MainActor
    @discardableResult
    static func open(arguments: [String] = GBL.fresh, file: StaticString = #filePath, line: UInt = #line)
        -> XCUIApplication {
        let app = launchApp(arguments: arguments)
        waitFor(element(app, "vc.route.experience"), timeout: VC.firstWait, file: file, line: line)
        waitFor(canvas(app), timeout: VC.firstWait, file: file, line: line)
        waitFor(control(app, "run-start"), timeout: VC.wait, "the Start run button is there", file: file, line: line)
        waitFor(control(app, "status"), timeout: VC.wait, "the status line is there", file: file, line: line)
        XCTAssertTrue(waitForStatus(app) { $0 == "Ready" }, "a fresh lab is Ready: \(status(app))",
                      file: file, line: line)
        return app
    }

    /// The scroll view that holds the controls below the canvas.
    @MainActor
    static func controlsList(_ app: XCUIApplication) -> XCUIElement {
        app.scrollViews.containing(NSPredicate(format: "identifier BEGINSWITH %@", prefix)).firstMatch
    }

    /// Whether `target` lies wholly inside the visible controls (or, when taller than them, covers their middle) and
    /// can be tapped.
    @MainActor
    static func isShown(_ app: XCUIApplication, _ target: XCUIElement) -> Bool {
        guard target.exists, target.isHittable else { return false }
        let list = controlsList(app)
        guard list.exists else { return true }
        let visible = list.frame.insetBy(dx: 0, dy: -1), frame = target.frame
        if frame.height >= visible.height { return frame.minY <= visible.midY && frame.maxY >= visible.midY }
        return frame.minY >= visible.minY && frame.maxY <= visible.maxY
    }

    /// One slow drag on the controls near their left edge, with a hold at the end, so the list moves by the drag's
    /// length without a fling. Positive `distance` moves the finger up (shows the controls further down); it is cut to
    /// 85 % of the list's height and raised to 40 points, beyond the scroll view's touch slop.
    @MainActor
    static func drag(_ app: XCUIApplication, by distance: CGFloat) {
        let list = controlsList(app)
        let area = list.exists ? list : app.windows.firstMatch
        let height = max(area.frame.height, 1)
        let size = min(max(abs(distance), 40), height * 0.85)
        let half = size / 2 / height
        let up = distance > 0
        let start = area.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0.5 + (up ? half : -half)))
            .withOffset(CGVector(dx: 8, dy: 0))
        let end = area.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0.5 + (up ? -half : half)))
            .withOffset(CGVector(dx: 8, dy: 0))
        start.press(forDuration: 0.05, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.1)
    }

    /// Scrolls the controls until `target` is shown, at most ``maxDrags`` drags; true when it is. With `required`,
    /// fails the test at the caller's line when it never is.
    @MainActor
    @discardableResult
    static func reveal(_ app: XCUIApplication, _ target: XCUIElement, required: Bool = true,
                       file: StaticString = #filePath, line: UInt = #line) -> Bool {
        var drags = 0
        while drags < maxDrags, target.exists, !isShown(app, target) {
            let list = controlsList(app)
            let middle = list.exists ? list.frame.midY : app.windows.firstMatch.frame.midY
            var distance = target.frame.midY - middle
            if abs(distance) < 1 { distance = 40 }
            drag(app, by: distance)
            drags += 1
        }
        let found = isShown(app, target)
        if required {
            XCTAssertTrue(found, "not reached by scrolling the controls: \(target)", file: file, line: line)
        }
        return found
    }

    /// Waits for `target`, scrolls it into view and taps it; true when it was tapped.
    @MainActor
    @discardableResult
    static func tap(_ app: XCUIApplication, _ target: XCUIElement, _ what: String,
                    file: StaticString = #filePath, line: UInt = #line) -> Bool {
        guard waitFor(target, timeout: shortWait, "\(what) is there", file: file, line: line),
              reveal(app, target, file: file, line: line) else { return false }
        target.tap()
        return true
    }

    /// Waits until the spoken text (label and value) of `target` satisfies `condition`; true when it does.
    @MainActor
    static func waitForSpoken(_ target: XCUIElement, timeout: TimeInterval = GBL.shortWait,
                              _ condition: (String) -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while !(target.exists && condition(spoken(target))), Date() < deadline { usleep(200_000) }
        return target.exists && condition(spoken(target))
    }

    /// Whether `container` holds a static text containing `text`, or speaks it in its own label (a combined element).
    @MainActor
    static func holds(_ container: XCUIElement, _ text: String) -> Bool {
        guard container.exists else { return false }
        if container.label.contains(text) { return true }
        return container.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", text)).firstMatch.exists
    }

    /// Waits until the app has left the foreground (running in the background, suspended or not); true when it has.
    @MainActor
    static func waitForBackground(_ app: XCUIApplication, timeout: TimeInterval = GBL.shortWait) -> Bool {
        // `app.wait(for:)` spins the run loop; a polled `app.state` behind `usleep` never refreshes (A24-P05 f3 run).
        app.wait(for: .runningBackground, timeout: timeout)
            || app.wait(for: .runningBackgroundSuspended, timeout: 2)
    }

    /// Lets `duration` seconds pass with a bounded expectation that is never fulfilled (no bare sleep).
    static func pause(_ duration: TimeInterval) {
        guard duration > 0 else { return }
        let elapsed = XCTestExpectation(description: "a bounded pause of \(duration) s")
        _ = XCTWaiter.wait(for: [elapsed], timeout: duration)
    }
}
