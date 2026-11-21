// ALSupport — feature 309 (R02-G01-09) T-R02G0109-004 (FR-R02G0109-001, 002, 008; clarifications Q1, Q2 and the
// amendment of 2026-11-20): helpers of the interface tests of Aurora Loom (R02-G01) inside the one app, modelled on
// `AUSupport`. Aurora Loom is a candidate; every launch carries `-vcCandidates` (DebugLaunch: the candidates' catalog
// entries become available and are registered). A fresh start erases the data (`-vcResetData`, so no level is solved),
// skips the welcome and opens the experience directly with `-openExperience r02-g01.aurora-loom`; a relaunch
// (`AL.reopen`) is the same start without the reset, so the stored progress (solved levels, stars, open levels) survives.
//
// The canvas (`session.canvas`) is labelled with the presenter's description (`AuroraLoomPresenter.describe`): "Aurora
// Loom level n, band b. ", in replay "Replay, move k of n. ", the ribbons' steps, the gate crossings and the moves, and
// when won "The loom is in harmony. s of 3 stars.". The controls are found by the identifiers of `AuroraLoomControls`
// (`port.identifier(name)`, that is `experience.r02-g01.aurora-loom.<name>`): the steppers `wave-1` … `wave-3` and
// `phase-1` … `phase-3` (value: the pending or current step, for example "15"; increment and decrement wrap 0 … 15 and
// only set a pending step), the buttons `apply` and `clear` (shown only while a step is pending; Apply commits every
// pending change as one move each), `undo`, `redo`, `next-level`, `hint`, `retry`, `daily`, `practice`, `campaign`,
// `replay`, `replay-step`, `replay-stop` and `skip-tutorial`, the level menu `level-picker` (value "Level n"; its
// items are buttons "Level 1" … up to the frontier) and the toggle `sound`. The controls sit below the canvas in a
// scroll view; a control is scrolled into view before it is used, with slow drags near the left edge (inside the
// padding, so that no control takes the touch). Everything lives in the namespace `AL`, so that nothing collides with
// the shared helpers of `AppUITestSupport` or the other experiences.
import Foundation
import XCTest

/// Launch arguments, identifiers, level 1's solution and helpers of the R02-G01 interface tests.
enum AL {
    /// The experience's id in the catalog.
    static let experienceID = "r02-g01.aurora-loom"
    /// The prefix of every identifier of the experience's controls.
    static let prefix = "experience.r02-g01.aurora-loom."
    /// The debug argument that makes the candidates available (DebugLaunch).
    static let candidates = "-vcCandidates"
    /// A first start with erased data, straight into Aurora Loom.
    static let fresh = [VC.reset, VC.skipWelcome, candidates, VC.openExperience, experienceID]
    /// A start over the same storage (no reset), straight into Aurora Loom.
    static let relaunch = [VC.skipWelcome, candidates, VC.openExperience, experienceID]
    /// The longest a single check waits (each test stays under 90 s, SC-R02G0109-001).
    static let shortWait: TimeInterval = 5
    /// The most drags one reveal makes.
    static let maxDrags = 24
    /// The number of steps of a wave or phase control (0 … 15, wrapping).
    static let stepCount = 16

    // Level 1, pinned here so the interface tests need no Core import. An app unit test checks these values against
    // `AuroraLoomExperienceCore` (the level's start steps and its certified solution), so a change of level 1 fails
    // there first.

    /// Level 1's start wave steps of ribbons 1 … 3.
    static let levelOneWave = [15, 15, 3]
    /// Level 1's start phase steps of ribbons 1 … 3.
    static let levelOnePhase = [12, 12, 3]
    /// The ribbon (1-based) the certified solution of level 1 changes.
    static let solutionRibbon = 3
    /// The certified solution's wave step of ``solutionRibbon``.
    static let solutionWave = 15
    /// The certified solution's phase step of ``solutionRibbon``.
    static let solutionPhase = 12
    /// The certified solution's length in moves (one per changed control).
    static let solutionMoves = 2
    /// Level 1's move allowance.
    static let levelOneAllowance = 9
    /// The canvas phrase of a level won with all three stars.
    static let threeStars = "3 of 3 stars"

    /// The full identifier of the control `name`.
    static func id(_ name: String) -> String { prefix + name }

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

    /// Launches the app with `arguments` and waits until Aurora Loom runs.
    @MainActor
    @discardableResult
    static func open(arguments: [String] = AL.fresh, file: StaticString = #filePath, line: UInt = #line)
        -> XCUIApplication {
        let app = launchApp(arguments: arguments)
        waitForRunning(app, file: file, line: line)
        return app
    }

    /// Ends `app` after a moment in which the stored progress reaches the disk, and opens Aurora Loom again over the
    /// same storage (``relaunch``, no reset).
    @MainActor
    @discardableResult
    static func reopen(_ app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line)
        -> XCUIApplication {
        // Backgrounding is the app's save point for the open experience's state (as PersistenceUITests ends a run);
        // a bare terminate would lose the win.
        XCUIDevice.shared.press(.home)
        usleep(1_000_000)
        app.terminate()
        let second = launchApp(arguments: AL.relaunch)
        waitForRunning(second, file: file, line: line)
        return second
    }

    /// Waits for the experience route, the canvas labelled with a level and the level menu (the controls show it once
    /// the presenter's first state has arrived).
    @MainActor
    private static func waitForRunning(_ app: XCUIApplication, file: StaticString, line: UInt) {
        waitFor(element(app, "vc.route.experience"), timeout: VC.firstWait, file: file, line: line)
        waitFor(canvas(app), timeout: VC.firstWait, file: file, line: line)
        waitFor(control(app, "level-picker"), timeout: VC.wait, "the level menu is there", file: file, line: line)
        XCTAssertTrue(waitForLabel(canvas(app)) { $0.hasPrefix("Aurora Loom level") },
                      "the canvas is labelled with a level: \(description(app))", file: file, line: line)
    }

    /// Taps `skip-tutorial` when the tutorial shows it (a fresh start does); nothing otherwise.
    @MainActor
    static func skipTutorialIfShown(_ app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        let skip = control(app, "skip-tutorial")
        guard skip.waitForExistence(timeout: 2) else { return }
        guard reveal(app, skip, file: file, line: line) else { return }
        skip.tap()
        XCTAssertTrue(waitUntilGone(skip, timeout: shortWait), "the tutorial is skipped", file: file, line: line)
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

    /// The step the stepper `name` shows (its value, the pending or current step), or nil when it is not a number.
    @MainActor
    static func step(_ app: XCUIApplication, _ name: String) -> Int? {
        let target = stepper(app, name)
        guard target.exists else { return nil }
        return Int((target.value as? String ?? "").trimmingCharacters(in: .whitespaces))
    }

    /// Scrolls the stepper `name` into view and presses its increment (`up`) or decrement button: the inner button
    /// whose label or identifier names it when there is one, then a button with the suffixed identifier, otherwise the
    /// matching end of the row, where the system stepper is drawn (increment at the right end, decrement left of it).
    @MainActor
    static func press(_ app: XCUIApplication, _ name: String, up: Bool,
                      file: StaticString = #filePath, line: UInt = #line) {
        let target = stepper(app, name)
        guard waitFor(target, timeout: shortWait, "\(name) is there", file: file, line: line),
              reveal(app, target, file: file, line: line) else { return }
        let word = up ? "Increment" : "Decrement"
        let inner = target.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@ OR identifier CONTAINS[c] %@",
                                                        word, word)).firstMatch
        if inner.exists, inner.isHittable {
            inner.tap()
            return
        }
        let suffixed = element(app, id(name) + "-" + word)
        if suffixed.exists, suffixed.isHittable {
            suffixed.tap()
            return
        }
        target.coordinate(withNormalizedOffset: CGVector(dx: up ? 0.95 : 0.8, dy: 0.5)).tap()
    }

    /// Sets the stepper `name` to the pending step `target` by the shorter way round the wrap (0 … 15): reveals the
    /// stepper once, resolves its increment or decrement button once, presses it the computed number of times (pending
    /// steps change at once and spend no move) and reads the value once at the end. True when it shows `target`.
    @MainActor
    @discardableResult
    static func setStep(_ app: XCUIApplication, _ name: String, to target: Int,
                        file: StaticString = #filePath, line: UInt = #line) -> Bool {
        let control = stepper(app, name)
        guard waitFor(control, timeout: shortWait, "\(name) is there", file: file, line: line),
              reveal(app, control, file: file, line: line), let start = step(app, name) else {
            XCTFail("\(name) has no numeric step (value \(value(app, name)))", file: file, line: line)
            return false
        }
        let downs = ((start - target) % stepCount + stepCount) % stepCount
        let up = downs > stepCount / 2
        let presses = up ? stepCount - downs : downs
        let word = up ? "Increment" : "Decrement"
        var button = control.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@ OR identifier CONTAINS[c] %@",
                                                          word, word)).firstMatch
        if !button.exists { button = element(app, id(name) + "-" + word) }
        for _ in 0..<presses {
            if button.exists { button.tap() } else { press(app, name, up: up, file: file, line: line) }
        }
        let reached = waitForValue(control, timeout: shortWait) {
            Int($0.trimmingCharacters(in: .whitespaces)) == target
        }
        XCTAssertTrue(reached, "\(name) shows \(target) (now \(value(app, name)))", file: file, line: line)
        return reached
    }

    /// Sets level 1's certified solution on ribbon 3 as pending steps (wave, then phase) and taps Apply. True when
    /// Apply was tapped.
    @MainActor
    @discardableResult
    static func applyLevelOneSolution(_ app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line)
        -> Bool {
        guard setStep(app, "wave-\(solutionRibbon)", to: solutionWave, file: file, line: line),
              setStep(app, "phase-\(solutionRibbon)", to: solutionPhase, file: file, line: line) else { return false }
        return tap(app, "apply", file: file, line: line)
    }

    /// A fresh start, the tutorial skipped and level 1 won with its certified solution; returns the app after the
    /// canvas reports all three stars.
    @MainActor
    @discardableResult
    static func winLevelOne(file: StaticString = #filePath, line: UInt = #line) -> XCUIApplication {
        let app = open(arguments: fresh, file: file, line: line)
        XCTAssertTrue(description(app).contains("Aurora Loom level 1,"),
                      "a fresh start opens level 1: \(description(app))", file: file, line: line)
        skipTutorialIfShown(app, file: file, line: line)
        XCTAssertTrue(applyLevelOneSolution(app, file: file, line: line), "the solution is applied",
                      file: file, line: line)
        XCTAssertTrue(waitForDescription(app) { $0.contains(threeStars) },
                      "the canvas reports the win with three stars: \(description(app))", file: file, line: line)
        return app
    }

    /// Opens the level menu `level-picker` and reports whether it offers the item "Level `number`".
    @MainActor
    static func menuOffersLevel(_ app: XCUIApplication, _ number: Int,
                                file: StaticString = #filePath, line: UInt = #line) -> Bool {
        guard tap(app, "level-picker", file: file, line: line) else { return false }
        let item = app.buttons.matching(NSPredicate(format: "label == %@", "Level \(number)")).firstMatch
        return item.waitForExistence(timeout: shortWait)
    }

    /// Waits until the label of `target` satisfies `condition`; true when it does.
    @MainActor
    static func waitForLabel(_ target: XCUIElement, timeout: TimeInterval = AL.shortWait,
                             _ condition: (String) -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while !(target.exists && condition(target.label)), Date() < deadline { usleep(200_000) }
        return target.exists && condition(target.label)
    }

    /// Waits until the value of `target` (as text) satisfies `condition`; true when it does.
    @MainActor
    static func waitForValue(_ target: XCUIElement, timeout: TimeInterval = AL.shortWait,
                             _ condition: (String) -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        func current() -> String { target.exists ? (target.value as? String ?? "") : "" }
        while !(target.exists && condition(current())), Date() < deadline { usleep(200_000) }
        return target.exists && condition(current())
    }

    /// Waits until the canvas description satisfies `condition`; true when it does.
    @MainActor
    static func waitForDescription(_ app: XCUIApplication, timeout: TimeInterval = AL.shortWait,
                                   _ condition: (String) -> Bool) -> Bool {
        waitForLabel(canvas(app), timeout: timeout, condition)
    }
}
