// SLSupport — feature 122 (A16-P06) T-A16-608 (clarification Q4; FR-A16-630, FR-A16-622): helpers of the interface
// tests of Simulation Lab (A16) inside the one app, modelled on `MESupport`. A16 is a candidate until X-A16; every
// launch carries `-vcCandidates` (DebugLaunch: the candidates' catalog entries become available and are registered).
// A first start erases the data (`-vcResetData`, which also removes the experience's storage, so the library holds no
// `preset-<uuid>.json` and no saved experiment is listed), skips the welcome and opens the experience directly with
// `-openExperience a16.simulation-lab`; ``again`` opens it once more without the reset. A fresh start runs the
// cellular automaton Life. The controls are found by the identifiers of `SimulationControls`
// (`port.identifier(name)`, that is `experience.a16.simulation-lab.<name>`): Run / Pause (`run-pause`, title "Pause"
// while running and "Run" while paused), Step (`step`), Reset (`reset`), the status line (`status`, value
// "Running at ×1, step 120", "Paused, step 12", reaction-diffusion and the wave adding ", time step 1"), the message
// line (`message`, only when there is one), the approximation label (`approximation`, value the family's method and
// limits), the Seed row (`seed-column`, `seed-row` and the button `seed`, title "Seed"), the Time step stepper
// (`time-step`, reaction-diffusion and the wave only), the bundled presets (`bundled-<index>`, titles Life, HighLife,
// Seeds, Spots, Mazes, Pulse; Spots is 3), the experiment name (`preset-name`, a text field labelled "Experiment
// name"), Save experiment (`preset-save`), the saved experiments (`saved-<uuid>`, title the saved name, each with
// `delete-<uuid>`) and Capture (`capture`). Capture is never tapped: its share link would lead to the share sheet
// (the capture is proved by the package tests). The controls sit below the canvas in a scroll view that is not lazy,
// so every control exists and its frame tells which way to scroll; a control is scrolled into view before it is used,
// with slow drags near the left edge (inside the padding, so that no button takes the touch). Everything lives in the
// namespace `SL`, so that nothing collides with the shared helpers of `AppUITestSupport` or the other experiences.
import Foundation
import XCTest

/// Launch arguments, identifiers and helpers of the A16 interface tests.
enum SL {
    /// The experience's id in the catalog.
    static let experienceID = "a16.simulation-lab"
    /// The prefix of every identifier of the experience's controls.
    static let prefix = "experience.a16.simulation-lab."
    /// The prefix of the canvas description.
    static let describedPrefix = "Simulation Lab: "
    /// The debug argument that makes the candidates available (DebugLaunch).
    static let candidates = "-vcCandidates"
    /// A first start with erased data, straight into A16.
    static let fresh = [VC.reset, VC.skipWelcome, candidates, VC.openExperience, experienceID]
    /// A later start that keeps the data, straight into A16.
    static let again = [VC.skipWelcome, candidates, VC.openExperience, experienceID]
    /// The longest a single check waits (each test stays well under 60 s).
    static let shortWait: TimeInterval = 5
    /// The most drags one reveal makes.
    static let maxDrags = 24
    /// The index of the bundled preset Spots (Life, HighLife, Seeds, Spots, Mazes, Pulse).
    static let spotsIndex = 3
    /// The approximation label of reaction-diffusion (`SimulationCore`, FR-A16-622).
    static let eulerApproximation =
        "Approximation: 64 × 64 cells, half-precision values, wrap boundary, explicit Euler step."

    /// The full identifier of the control `name`.
    static func id(_ name: String) -> String { prefix + name }

    /// The control `name` of A16, of any element type.
    @MainActor
    static func control(_ app: XCUIApplication, _ name: String) -> XCUIElement {
        element(app, id(name))
    }

    /// The live canvas of the session; its label is the presenter's description.
    @MainActor
    static func canvas(_ app: XCUIApplication) -> XCUIElement {
        element(app, VC.canvas)
    }

    /// The canvas description, or "" when the canvas is not there.
    @MainActor
    static func description(_ app: XCUIApplication) -> String {
        let c = canvas(app)
        return c.exists ? c.label : ""
    }

    /// The spoken value of the control `name`, or "" when it has none.
    @MainActor
    static func value(_ app: XCUIApplication, _ name: String) -> String {
        control(app, name).value as? String ?? ""
    }

    /// The status line's value.
    @MainActor
    static func status(_ app: XCUIApplication) -> String { value(app, "status") }

    /// The step count named by the status sentence `status` ("Paused, step 12, time step 1" → 12), or nil.
    static func stepCount(_ status: String) -> Int? {
        guard let range = status.range(of: ", step ") else { return nil }
        let digits = status[range.upperBound...].prefix { $0.isNumber }
        return Int(digits)
    }

    /// The saved-experiment buttons titled `name` (`saved-<uuid>`).
    @MainActor
    static func saved(_ app: XCUIApplication, named name: String) -> XCUIElementQuery {
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@ AND label == %@", id("saved-"), name))
    }

    /// Launches the app with `arguments` and waits until A16 runs: the experience route, its canvas described and its
    /// status line (the controls show it once the presenter's first state has arrived).
    @MainActor
    @discardableResult
    static func open(arguments: [String] = SL.fresh, file: StaticString = #filePath, line: UInt = #line)
        -> XCUIApplication {
        let app = launchApp(arguments: arguments)
        waitForRunning(app, file: file, line: line)
        return app
    }

    /// Ends `app` (after a moment in which the stores reach the disk) and opens A16 again without erasing the data.
    @MainActor
    @discardableResult
    static func reopen(_ app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line)
        -> XCUIApplication {
        let second = relaunch(app, arguments: SL.again)
        waitForRunning(second, file: file, line: line)
        return second
    }

    /// Waits for the experience route, the described canvas and the status line of A16.
    @MainActor
    private static func waitForRunning(_ app: XCUIApplication, file: StaticString, line: UInt) {
        waitFor(element(app, "vc.route.experience"), timeout: VC.firstWait, file: file, line: line)
        waitFor(canvas(app), timeout: VC.firstWait, file: file, line: line)
        waitFor(control(app, "status"), timeout: VC.wait, file: file, line: line)
        XCTAssertTrue(waitForLabel(canvas(app)) { $0.hasPrefix(describedPrefix) },
                      "the canvas is described: \(description(app))", file: file, line: line)
    }

    /// Pauses the simulation when it runs (Run / Pause titled "Pause") and waits until the status starts "Paused";
    /// true when it does.
    @MainActor
    @discardableResult
    static func pause(_ app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) -> Bool {
        if status(app).hasPrefix("Running") { tap(app, "run-pause", file: file, line: line) }
        let paused = waitForStatus(app) { $0.hasPrefix("Paused") }
        XCTAssertTrue(paused, "the status starts Paused (now \(status(app)))", file: file, line: line)
        return paused
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

    /// One slow drag on the controls near their left edge (inside the padding, so that no button takes the touch),
    /// with a hold at the end, so the list moves by the drag's length without a fling. `distance` is in points:
    /// positive moves the finger up, which shows the controls further down. It is cut to 85 % of the list's height and
    /// raised to 40 points, beyond the scroll view's touch slop.
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

    /// Scrolls the controls until `target` is shown: each drag moves the list toward the target's frame, at most
    /// ``maxDrags`` drags. Fails the test at the caller's line when it never is.
    @MainActor
    @discardableResult
    static func reveal(_ app: XCUIApplication, _ target: XCUIElement,
                       file: StaticString = #filePath, line: UInt = #line) -> Bool {
        var drags = 0
        while drags < maxDrags, target.exists, !isShown(app, target) {
            let list = controlsList(app)
            let middle = list.exists ? list.frame.midY : app.windows.firstMatch.frame.midY
            var distance = target.frame.midY - middle
            // A target whose frame sits in the middle but cannot be tapped yet: nudge the list once downward.
            if abs(distance) < 1 { distance = 40 }
            drag(app, by: distance)
            drags += 1
        }
        let found = isShown(app, target)
        XCTAssertTrue(found, "not reached by scrolling the controls: \(target)", file: file, line: line)
        return found
    }

    /// Scrolls `target` into view and taps it; false when it is not there or cannot be reached.
    @MainActor
    @discardableResult
    static func tap(_ app: XCUIApplication, element target: XCUIElement, _ what: String,
                    file: StaticString = #filePath, line: UInt = #line) -> Bool {
        guard waitFor(target, timeout: shortWait, "\(what) is there", file: file, line: line),
              reveal(app, target, file: file, line: line) else { return false }
        target.tap()
        return true
    }

    /// Scrolls the control `name` into view and taps it. Never used for `capture` or `share`, which lead to the share
    /// sheet.
    @MainActor
    @discardableResult
    static func tap(_ app: XCUIApplication, _ name: String, file: StaticString = #filePath, line: UInt = #line)
        -> Bool {
        precondition(name != "capture" && name != "share", "the interface tests never show the share sheet")
        return tap(app, element: control(app, name), name, file: file, line: line)
    }

    /// Waits until the label of `target` satisfies `condition`; true when it does.
    @MainActor
    static func waitForLabel(_ target: XCUIElement, timeout: TimeInterval = VC.wait,
                             _ condition: (String) -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while !(target.exists && condition(target.label)), Date() < deadline { usleep(200_000) }
        return target.exists && condition(target.label)
    }

    /// Waits until the accessibility value of `target` satisfies `condition`; true when it does.
    @MainActor
    static func waitForValue(_ target: XCUIElement, timeout: TimeInterval = SL.shortWait,
                             _ condition: (String) -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while !(target.exists && condition(target.value as? String ?? "")), Date() < deadline { usleep(200_000) }
        return target.exists && condition(target.value as? String ?? "")
    }

    /// Waits until the status line's value satisfies `condition`; true when it does.
    @MainActor
    static func waitForStatus(_ app: XCUIApplication, timeout: TimeInterval = SL.shortWait,
                              _ condition: (String) -> Bool) -> Bool {
        waitForValue(control(app, "status"), timeout: timeout, condition)
    }
}
