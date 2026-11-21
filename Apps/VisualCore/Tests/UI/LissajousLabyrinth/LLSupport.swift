// LLSupport — feature 319 (R02-G02-09) T-R02G0209-004 (FR-R02G0209-001, 002; clarifications Q1, Q2): helpers of the
// interface tests of Lissajous Labyrinth (R02-G02) inside the one app, modelled on `ALSupport`. Lissajous Labyrinth was a
// candidate until X-R02-G02 (2026-11-21); every launch still carries `-vcCandidates` (DebugLaunch: the candidates'
// catalog entries become available and are registered). A fresh start erases the data (`-vcResetData`, so no level is solved), skips the
// welcome and opens the experience directly with `-openExperience r02-g02.lissajous-labyrinth`; a relaunch
// (`LL.reopen`) backgrounds the app first (its save point), terminates it and starts again without the reset, so the
// stored progress (solved levels, stars, open levels) survives.
//
// The canvas (`session.canvas`) is labelled with the presenter's description (`LissajousLabyrinthPresenter.describe`):
// "Lissajous Labyrinth level n. ", the four dials ("Frequency a 7. " …), the checkpoints, "Actions k of m. " and, when
// won, "The path is safe. s of 3 stars.". The controls are found by the identifiers of `LissajousLabyrinthControls`
// (`port.identifier(name)`, that is `experience.r02-g02.lissajous-labyrinth.<name>`): the steppers `frequency-a`,
// `frequency-b` (1 … 9) and `phase-a`, `phase-c` (0 … 15) — value "\(shown)" or "\(shown), pending; now \(current)";
// increment and decrement wrap and only set a pending value — the buttons `apply` and `clear` (shown only while
// something is pending; Apply sends one action per pending dial in the planner's coprime order), `undo`, `redo`,
// `next-level`, `reset-view`, `hint`, `dismiss-tutorial`, `failure-undo`, `retry`, `campaign`, `daily`, `practice`,
// `replay` (when the level has a recorded solution, not during replay), `replay-step` (value "Action k of n") and
// `replay-stop`, the level menu `level-picker` (value "Levels 1 to n open"; its items are buttons "Level 1" or
// "Level 1 · 3 stars") and the toggle `sound`. The controls sit below the canvas in a scroll view; a control is
// scrolled into view before it is used, with slow drags near the left edge. Everything lives in the namespace `LL`, so
// that nothing collides with the shared helpers of `AppUITestSupport` or the other experiences.
import Foundation
import XCTest

/// Launch arguments, identifiers, level 1's solution and helpers of the R02-G02 interface tests.
enum LL {
    /// The experience's id in the catalog.
    static let experienceID = "r02-g02.lissajous-labyrinth"
    /// The prefix of every identifier of the experience's controls.
    static let prefix = "experience.r02-g02.lissajous-labyrinth."
    /// The debug argument that makes the candidates available (DebugLaunch).
    static let candidates = "-vcCandidates"
    /// A first start with erased data, straight into Lissajous Labyrinth.
    static let fresh = [VC.reset, VC.skipWelcome, candidates, VC.openExperience, experienceID]
    /// A start over the same storage (no reset), straight into Lissajous Labyrinth.
    static let relaunch = [VC.skipWelcome, candidates, VC.openExperience, experienceID]
    /// The longest a single check waits (each test stays under 90 s, SC-R02G0209-001).
    static let shortWait: TimeInterval = 5
    /// The most drags one reveal makes.
    static let maxDrags = 24
    /// The steppers in the panel's order.
    static let dials = ["frequency-a", "frequency-b", "phase-a", "phase-c"]

    // Level 1, pinned here so the interface tests need no Core import. An app unit test checks these values against
    // `LissajousLabyrinthExperienceCore` (`freshPlay(of:)` of level 1 and `generated(number: 1).solution`), so a
    // change of level 1 fails there first. Computed 2026-11-21: the certified solution is the single action phaseC = 3.

    /// Level 1's start dials, keyed by stepper name.
    static let levelOneStart = ["frequency-a": 7, "frequency-b": 1, "phase-a": 5, "phase-c": 12]
    /// The dials level 1's certified solution reaches, keyed by stepper name.
    static let levelOneFinal = ["frequency-a": 7, "frequency-b": 1, "phase-a": 5, "phase-c": 3]
    /// Level 1's action allowance.
    static let levelOneAllowance = 9
    /// Level 1's certified shortest solution in actions.
    static let levelOneShortest = 1
    /// The canvas phrase of a won level.
    static let safe = "The path is safe."
    /// The canvas phrase of a level won with all three stars.
    static let threeStars = "3 of 3 stars"
    /// The level menu's value once level 1 is solved.
    static let levelTwoOpen = "Levels 1 to 2 open"

    /// The full identifier of the control `name`.
    static func id(_ name: String) -> String { prefix + name }

    /// The values the stepper `name` takes: 1 … 9 for a frequency, 0 … 15 for a phase.
    static func range(_ name: String) -> ClosedRange<Int> { name.hasPrefix("frequency") ? 1...9 : 0...15 }

    /// The control `name`, of any element type.
    @MainActor
    static func control(_ app: XCUIApplication, _ name: String) -> XCUIElement {
        element(app, id(name))
    }

    /// The value of the control `name` as text, or "" when it has none.
    @MainActor
    static func value(_ app: XCUIApplication, _ name: String) -> String {
        control(app, name).value as? String ?? ""
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

    /// Launches the app with `arguments` and waits until Lissajous Labyrinth runs.
    @MainActor
    @discardableResult
    static func open(arguments: [String] = LL.fresh, file: StaticString = #filePath, line: UInt = #line)
        -> XCUIApplication {
        let app = launchApp(arguments: arguments)
        waitForRunning(app, file: file, line: line)
        return app
    }

    /// Backgrounds `app` (its save point), ends it and opens Lissajous Labyrinth again over the same storage
    /// (``relaunch``, no reset).
    @MainActor
    @discardableResult
    static func reopen(_ app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line)
        -> XCUIApplication {
        // Backgrounding is the app's save point for the open experience's state (as PersistenceUITests ends a run);
        // a bare terminate would lose the win.
        XCUIDevice.shared.press(.home)
        usleep(1_000_000)
        app.terminate()
        let second = launchApp(arguments: LL.relaunch)
        waitForRunning(second, file: file, line: line)
        return second
    }

    /// Waits for the experience route, the canvas labelled with a level and the level menu.
    @MainActor
    private static func waitForRunning(_ app: XCUIApplication, file: StaticString, line: UInt) {
        waitFor(element(app, "vc.route.experience"), timeout: VC.firstWait, file: file, line: line)
        waitFor(canvas(app), timeout: VC.firstWait, file: file, line: line)
        waitFor(control(app, "level-picker"), timeout: VC.wait, "the level menu is there", file: file, line: line)
        XCTAssertTrue(waitForLabel(canvas(app)) { $0.hasPrefix("Lissajous Labyrinth level") },
                      "the canvas is labelled with a level: \(description(app))", file: file, line: line)
    }

    /// Taps `dismiss-tutorial` when the tutorial shows it (a fresh start of level 1 does); nothing otherwise.
    @MainActor
    static func dismissTutorialIfShown(_ app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        let dismiss = control(app, "dismiss-tutorial")
        guard dismiss.waitForExistence(timeout: 2) else { return }
        guard reveal(app, dismiss, file: file, line: line) else { return }
        dismiss.tap()
        XCTAssertTrue(waitUntilGone(dismiss, timeout: shortWait), "the tutorial is dismissed", file: file, line: line)
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

    /// Scrolls the controls until `target` is shown, at most ``maxDrags`` drags. Fails the test at the caller's line
    /// when it never is.
    @MainActor
    @discardableResult
    static func reveal(_ app: XCUIApplication, _ target: XCUIElement,
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
        XCTAssertTrue(found, "not reached by scrolling the controls: \(target)", file: file, line: line)
        return found
    }

    /// Waits for the control `name`, scrolls it into view and returns it, or nil when it is not there.
    @MainActor
    static func shown(_ app: XCUIApplication, _ name: String, file: StaticString = #filePath, line: UInt = #line)
        -> XCUIElement? {
        let target = control(app, name)
        guard waitFor(target, timeout: shortWait, "\(name) is there", file: file, line: line),
              reveal(app, target, file: file, line: line) else { return nil }
        return target
    }

    /// Waits for the control `name`, scrolls it into view and taps it; true when it was tapped.
    @MainActor
    @discardableResult
    static func tap(_ app: XCUIApplication, _ name: String, file: StaticString = #filePath, line: UInt = #line)
        -> Bool {
        guard let target = shown(app, name, file: file, line: line) else { return false }
        target.tap()
        return true
    }

    /// The stepper `name`: the system stepper with the identifier when there is one, else the control of any type.
    @MainActor
    static func stepper(_ app: XCUIApplication, _ name: String) -> XCUIElement {
        let stepper = app.steppers.matching(identifier: id(name)).firstMatch
        return stepper.exists ? stepper : control(app, name)
    }

    /// The value a stepper's text shows: the leading number of "12" or "3, pending; now 12", or nil.
    static func shownValue(_ text: String) -> Int? {
        Int(text.split(separator: ",").first.map { $0.trimmingCharacters(in: .whitespaces) } ?? "")
    }

    /// The value the stepper `name` shows (pending or current), or nil when it has none.
    @MainActor
    static func dial(_ app: XCUIApplication, _ name: String) -> Int? {
        let target = stepper(app, name)
        guard target.exists else { return nil }
        return shownValue(target.value as? String ?? "")
    }

    /// The increment (`up`) or decrement button of the stepper `name`: the inner button whose label or identifier names
    /// it, else a button with the suffixed identifier, else nil (the caller taps the end of the row).
    @MainActor
    static func stepButton(_ app: XCUIApplication, _ name: String, up: Bool) -> XCUIElement? {
        let word = up ? "Increment" : "Decrement"
        let inner = stepper(app, name).buttons
            .matching(NSPredicate(format: "label CONTAINS[c] %@ OR identifier CONTAINS[c] %@", word, word)).firstMatch
        if inner.exists { return inner }
        let suffixed = element(app, id(name) + "-" + word)
        return suffixed.exists ? suffixed : nil
    }

    /// Sets the stepper `name` to the pending value `target` by the shorter way round the wrap: reveals it once,
    /// presses increment or decrement the computed number of times (pending values spend no action) and reads the
    /// value once at the end. True when it shows `target`.
    @MainActor
    @discardableResult
    static func setDial(_ app: XCUIApplication, _ name: String, to target: Int,
                        file: StaticString = #filePath, line: UInt = #line) -> Bool {
        let control = stepper(app, name)
        guard waitFor(control, timeout: shortWait, "\(name) is there", file: file, line: line),
              reveal(app, control, file: file, line: line), let start = dial(app, name) else {
            XCTFail("\(name) has no numeric value (value \(value(app, name)))", file: file, line: line)
            return false
        }
        let count = range(name).count
        let downs = ((start - target) % count + count) % count
        let up = downs > count / 2
        let presses = up ? count - downs : downs
        let button = stepButton(app, name, up: up)
        for _ in 0..<presses {
            if let button { button.tap() } else {
                control.coordinate(withNormalizedOffset: CGVector(dx: up ? 0.95 : 0.8, dy: 0.5)).tap()
            }
        }
        let reached = waitForValue(control, timeout: shortWait) { shownValue($0) == target }
        XCTAssertTrue(reached, "\(name) shows \(target) (now \(value(app, name)))", file: file, line: line)
        return reached
    }

    /// Sets every dial that level 1's certified solution changes as a pending value and taps Apply. True when Apply
    /// was tapped.
    @MainActor
    @discardableResult
    static func applyLevelOneSolution(_ app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line)
        -> Bool {
        for name in dials where levelOneFinal[name] != levelOneStart[name] {
            guard let target = levelOneFinal[name], setDial(app, name, to: target, file: file, line: line) else {
                return false
            }
        }
        return tap(app, "apply", file: file, line: line)
    }

    /// A fresh start, the tutorial dismissed and level 1 won with its certified solution; returns the app after the
    /// canvas reports the safe path with all three stars.
    @MainActor
    @discardableResult
    static func winLevelOne(file: StaticString = #filePath, line: UInt = #line) -> XCUIApplication {
        let app = open(arguments: fresh, file: file, line: line)
        XCTAssertTrue(description(app).hasPrefix("Lissajous Labyrinth level 1."),
                      "a fresh start opens level 1: \(description(app))", file: file, line: line)
        dismissTutorialIfShown(app, file: file, line: line)
        XCTAssertTrue(applyLevelOneSolution(app, file: file, line: line), "the solution is applied",
                      file: file, line: line)
        XCTAssertTrue(waitForDescription(app) { $0.contains(safe) && $0.contains(threeStars) },
                      "the canvas reports the safe path with three stars: \(description(app))", file: file, line: line)
        return app
    }

    /// Opens the level menu `level-picker` and reports whether it offers an item labelled `label`.
    @MainActor
    static func menuOffers(_ app: XCUIApplication, _ label: String,
                           file: StaticString = #filePath, line: UInt = #line) -> Bool {
        guard tap(app, "level-picker", file: file, line: line) else { return false }
        let item = app.buttons.matching(NSPredicate(format: "label == %@", label)).firstMatch
        return item.waitForExistence(timeout: shortWait)
    }

    /// Waits until the label of `target` satisfies `condition`; true when it does.
    @MainActor
    static func waitForLabel(_ target: XCUIElement, timeout: TimeInterval = LL.shortWait,
                             _ condition: (String) -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while !(target.exists && condition(target.label)), Date() < deadline { usleep(200_000) }
        return target.exists && condition(target.label)
    }

    /// Waits until the value of `target` (as text) satisfies `condition`; true when it does.
    @MainActor
    static func waitForValue(_ target: XCUIElement, timeout: TimeInterval = LL.shortWait,
                             _ condition: (String) -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        func current() -> String { target.exists ? (target.value as? String ?? "") : "" }
        while !(target.exists && condition(current())), Date() < deadline { usleep(200_000) }
        return target.exists && condition(current())
    }

    /// Waits until the canvas description satisfies `condition`; true when it does.
    @MainActor
    static func waitForDescription(_ app: XCUIApplication, timeout: TimeInterval = LL.shortWait,
                                   _ condition: (String) -> Bool) -> Bool {
        waitForLabel(canvas(app), timeout: timeout, condition)
    }
}
