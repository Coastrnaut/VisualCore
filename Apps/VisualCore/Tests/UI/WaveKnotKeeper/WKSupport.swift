// WKSupport — feature 329 (R02-G03-09) T-R02G0309-004 (FR-R02G0309-001, 002; clarifications Q1, Q2): helpers of the
// interface tests of Wave Knot Keeper (R02-G03) inside the one app, modelled on `LLSupport`. Wave Knot Keeper is a
// candidate until X-R02-G03; every launch carries `-vcCandidates` (DebugLaunch: the candidates' catalog entries become
// available and are registered). A fresh start erases the data (`-vcResetData`, so no level is solved), skips the
// welcome and opens the experience directly with `-openExperience r02-g03.wave-knot-keeper`; a relaunch (`WK.reopen`)
// backgrounds the app first (its save point), terminates it and starts again without the reset, so the stored progress
// (solved levels, stars, open levels) survives.
//
// The canvas (`session.canvas`) is labelled with the presenter's description (`WaveKnotKeeperPresenter.describe`):
// "Wave Knot Keeper level n. ", the rope's points, crossings and writhe against the target, "Point k selected. " once a
// point was picked, "Moves k of m. " and, when won, "The knot matches. s of 3 stars.". The controls are found by the
// identifiers of `WaveKnotKeeperControls` (`port.identifier(name)`, that is `experience.r02-g03.wave-knot-keeper.<name>`):
// the stepper `point-picker` (value "k of n", 1-based; increment selects the next point, decrement the previous, both
// wrapping; a selection spends no move), the six direction buttons `move-plus-x`, `move-minus-x`, `move-plus-y`,
// `move-minus-y`, `move-over`, `move-under` (the Core's direction index 0 … 5 in that order; each moves the selected
// point one step), `undo`, `redo`, `next-level`, `reset-view`, `hint`, `dismiss-tutorial`, `failure-undo`, `retry`,
// `campaign`, `daily`, `practice`, `replay` (when the level has a verified recorded solution, not during replay),
// `replay-step` (value "Move k of n") and `replay-stop`, the level menu `level-picker` (value "Levels 1 to n open"; its
// items are buttons "Level 1" or "Level 1 · 3 stars") and the toggle `sound`. The controls sit below the canvas in a
// scroll view; a control is scrolled into view before it is used, with slow drags near the left edge. Everything lives
// in the namespace `WK`, so that nothing collides with the shared helpers of `AppUITestSupport` or the other
// experiences.
import Foundation
import XCTest

/// Launch arguments, identifiers, level 1's solution and helpers of the R02-G03 interface tests.
enum WK {
    /// The experience's id in the catalog.
    static let experienceID = "r02-g03.wave-knot-keeper"
    /// The prefix of every identifier of the experience's controls.
    static let prefix = "experience.r02-g03.wave-knot-keeper."
    /// The debug argument that makes the candidates available (DebugLaunch).
    static let candidates = "-vcCandidates"
    /// A first start with erased data, straight into Wave Knot Keeper.
    static let fresh = [VC.reset, VC.skipWelcome, candidates, VC.openExperience, experienceID]
    /// A start over the same storage (no reset), straight into Wave Knot Keeper.
    static let relaunch = [VC.skipWelcome, candidates, VC.openExperience, experienceID]
    /// The longest a single check waits (each test stays under 90 s, SC-R02G0309-001).
    static let shortWait: TimeInterval = 5
    /// The most drags one reveal makes.
    static let maxDrags = 24
    /// The direction buttons in the Core's direction order (`WaveKnotKeeperExperienceCore.directionOrder`: plusX,
    /// minusX, plusY, minusY, plusZ (over), minusZ (under)).
    static let directions = ["move-plus-x", "move-minus-x", "move-plus-y", "move-minus-y", "move-over", "move-under"]

    // Level 1, pinned here so the interface tests need no Core import. An app unit test checks these values against
    // `WaveKnotKeeperExperienceCore.generated(number: 1)` (its level's points and allowance, its solution's moves and
    // shortest), so a change of level 1 fails there first. Read 2026-11-21 from the Core's witness
    // docs/games/wave-knot-keeper/levels/001.witness.json: a rope of 6 points, allowance 9, the certified solution is
    // the single move point 1 (0-based) plusX.

    /// Level 1's number of control points.
    static let levelOnePointCount = 6
    /// Level 1's certified solution: (0-based point index, direction index into ``directions``).
    static let levelOneMoves: [(point: Int, direction: Int)] = [(point: 1, direction: 0)]
    /// Level 1's move allowance.
    static let levelOneAllowance = 9
    /// Level 1's certified shortest solution in moves.
    static let levelOneShortest = 1
    /// The canvas phrase of a won level.
    static let matches = "The knot matches."
    /// The canvas phrase of a level won with all three stars.
    static let threeStars = "3 of 3 stars"
    /// The level menu's value once level 1 is solved.
    static let levelTwoOpen = "Levels 1 to 2 open"

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

    /// Launches the app with `arguments` and waits until Wave Knot Keeper runs.
    @MainActor
    @discardableResult
    static func open(arguments: [String] = WK.fresh, file: StaticString = #filePath, line: UInt = #line)
        -> XCUIApplication {
        let app = launchApp(arguments: arguments)
        waitForRunning(app, file: file, line: line)
        return app
    }

    /// Backgrounds `app` (its save point), ends it and opens Wave Knot Keeper again over the same storage
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
        let second = launchApp(arguments: WK.relaunch)
        waitForRunning(second, file: file, line: line)
        return second
    }

    /// Waits for the experience route, the canvas labelled with a level and the level menu.
    @MainActor
    private static func waitForRunning(_ app: XCUIApplication, file: StaticString, line: UInt) {
        waitFor(element(app, "vc.route.experience"), timeout: VC.firstWait, file: file, line: line)
        waitFor(canvas(app), timeout: VC.firstWait, file: file, line: line)
        waitFor(control(app, "level-picker"), timeout: VC.wait, "the level menu is there", file: file, line: line)
        XCTAssertTrue(waitForLabel(canvas(app)) { $0.hasPrefix("Wave Knot Keeper level") },
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

    /// The point picker: the system stepper with the identifier when there is one, else the control of any type.
    @MainActor
    static func picker(_ app: XCUIApplication) -> XCUIElement {
        let stepper = app.steppers.matching(identifier: id("point-picker")).firstMatch
        return stepper.exists ? stepper : control(app, "point-picker")
    }

    /// The selection and the point count of a picker value "k of n" (k 1-based), as (0-based index, count), or nil.
    static func selection(_ text: String) -> (index: Int, count: Int)? {
        let parts = text.components(separatedBy: " of ")
        guard parts.count == 2, let k = Int(parts[0].trimmingCharacters(in: .whitespaces)),
              let n = Int(parts[1].trimmingCharacters(in: .whitespaces)), n > 0, (1...n).contains(k) else { return nil }
        return (k - 1, n)
    }

    /// The point picker's selection as (0-based index, count), or nil when it shows none.
    @MainActor
    static func selected(_ app: XCUIApplication) -> (index: Int, count: Int)? {
        let target = picker(app)
        guard target.exists else { return nil }
        return selection(target.value as? String ?? "")
    }

    /// The increment (`up`) or decrement button of the point picker: the inner button whose label or identifier names
    /// it, else a button with the suffixed identifier, else nil (the caller taps the end of the row).
    @MainActor
    static func pickerButton(_ app: XCUIApplication, up: Bool) -> XCUIElement? {
        let word = up ? "Increment" : "Decrement"
        let inner = picker(app).buttons
            .matching(NSPredicate(format: "label CONTAINS[c] %@ OR identifier CONTAINS[c] %@", word, word)).firstMatch
        if inner.exists { return inner }
        let suffixed = element(app, id("point-picker") + "-" + word)
        return suffixed.exists ? suffixed : nil
    }

    /// Selects point `target` (0-based) with the point picker by the shorter way round the wrap: reveals it once,
    /// presses increment or decrement the computed number of times (a selection spends no move) and reads the value
    /// once at the end. True when it shows `target`.
    @MainActor
    @discardableResult
    static func selectPoint(_ app: XCUIApplication, _ target: Int,
                            file: StaticString = #filePath, line: UInt = #line) -> Bool {
        let control = picker(app)
        guard waitFor(control, timeout: shortWait, "point-picker is there", file: file, line: line),
              reveal(app, control, file: file, line: line), let start = selected(app) else {
            XCTFail("point-picker has no selection (value \(value(app, "point-picker")))", file: file, line: line)
            return false
        }
        let count = start.count
        let ups = ((target - start.index) % count + count) % count
        let up = ups <= count / 2
        let presses = up ? ups : count - ups
        let button = pickerButton(app, up: up)
        for _ in 0..<presses {
            if let button { button.tap() } else {
                control.coordinate(withNormalizedOffset: CGVector(dx: up ? 0.95 : 0.8, dy: 0.5)).tap()
            }
        }
        let reached = waitForValue(control, timeout: shortWait) { selection($0)?.index == target }
        XCTAssertTrue(reached, "point-picker shows point \(target + 1) (now \(value(app, "point-picker")))",
                      file: file, line: line)
        return reached
    }

    /// Plays level 1's certified solution: for each move, selects its point with the picker and taps its direction.
    /// True when every direction button was tapped.
    @MainActor
    @discardableResult
    static func playLevelOneSolution(_ app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line)
        -> Bool {
        for move in levelOneMoves {
            guard selectPoint(app, move.point, file: file, line: line),
                  tap(app, directions[move.direction], file: file, line: line) else { return false }
        }
        return true
    }

    /// A fresh start, the tutorial dismissed and level 1 won with its certified solution; returns the app after the
    /// canvas reports the matching knot with all three stars.
    @MainActor
    @discardableResult
    static func winLevelOne(file: StaticString = #filePath, line: UInt = #line) -> XCUIApplication {
        let app = open(arguments: fresh, file: file, line: line)
        XCTAssertTrue(description(app).hasPrefix("Wave Knot Keeper level 1."),
                      "a fresh start opens level 1: \(description(app))", file: file, line: line)
        XCTAssertTrue(description(app).contains("A rope of \(levelOnePointCount) points"),
                      "level 1's rope: \(description(app))", file: file, line: line)
        dismissTutorialIfShown(app, file: file, line: line)
        XCTAssertTrue(playLevelOneSolution(app, file: file, line: line), "the solution is played",
                      file: file, line: line)
        XCTAssertTrue(waitForDescription(app) { $0.contains(matches) && $0.contains(threeStars) },
                      "the canvas reports the matching knot with three stars: \(description(app))",
                      file: file, line: line)
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
    static func waitForLabel(_ target: XCUIElement, timeout: TimeInterval = WK.shortWait,
                             _ condition: (String) -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while !(target.exists && condition(target.label)), Date() < deadline { usleep(200_000) }
        return target.exists && condition(target.label)
    }

    /// Waits until the value of `target` (as text) satisfies `condition`; true when it does.
    @MainActor
    static func waitForValue(_ target: XCUIElement, timeout: TimeInterval = WK.shortWait,
                             _ condition: (String) -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        func current() -> String { target.exists ? (target.value as? String ?? "") : "" }
        while !(target.exists && condition(current())), Date() < deadline { usleep(200_000) }
        return target.exists && condition(current())
    }

    /// Waits until the canvas description satisfies `condition`; true when it does.
    @MainActor
    static func waitForDescription(_ app: XCUIApplication, timeout: TimeInterval = WK.shortWait,
                                   _ condition: (String) -> Bool) -> Bool {
        waitForLabel(canvas(app), timeout: timeout, condition)
    }
}
