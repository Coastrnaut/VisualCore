// CCSupport — feature 349 (R02-G05-09) T-R02G0509-004 (FR-R02G0509-001, 002; clarifications Q1, Q2): helpers of the
// interface tests of Colorfall Canyons (R02-G05) inside the one app, modelled on `HCSupport`. Colorfall Canyons was a
// candidate until X-R02-G05 (2026-11-21); every launch still carries `-vcCandidates` (DebugLaunch: the candidates' catalog entries become
// available and are registered). A fresh start erases the data (`-vcResetData`, so no level is solved), skips the
// welcome and opens the experience directly with `-openExperience r02-g05.colorfall-canyons`; a relaunch (`CC.reopen`)
// backgrounds the app first (its save point), terminates it and starts again without the reset, so the stored progress
// (solved levels, stars, the frontier, the verified winning trace) survives.
//
// The canvas (`session.canvas`) is labelled with the presenter's description (`ColorfallCanyonsPresenter.describe`):
// "Colorfall Canyons level n. ", "Tick t of l; k actions left. ", each spring and basin and, when won, "Every basin is
// filled with its colours." followed by " Stars: s of 3." when the level has stars in the progress. The controls are
// found by the identifiers of `ColorfallCanyonsControls.identifierNames` (`port.identifier(name)`, that is
// `experience.r02-g05.colorfall-canyons.<name>`): `carve` (sends `canyon.carve [picked cell]`), `valve-0` … `valve-2`,
// `step-1`, `step-10`, `run` (sends `time.step [min(600, limit − tick)]`; value "k ticks left"), `undo`, `redo`,
// `next-level`, `reset-view`, `hint`, `dismiss-tutorial`, `failure-undo`, `retry`, `campaign`, `daily`, `practice`
// (value "selected" for the current mode, else ""), `play-level`, `replay` (when the level has a verified stored
// solution, not during replay), `replay-step` (value "Action p of n") and `replay-stop`, the stepper `cell-picker`
// (value "row r, column c", 1-based, or "none"; it steps through the carvable cells, wrapping, and keeps its index,
// clamped, when the carvable list changes; presentation only), the stepper `level-picker` (value "Level n, band b" plus
// ", k stars" when won; it never goes past the open frontier or below 1; presentation only), the toggle `sound` and the
// element `summary`. The controls sit below the canvas in a scroll view; a control is scrolled into view before it is
// used, with slow drags near the left edge. Everything lives in the namespace `CC`, so that nothing collides with the
// shared helpers of `AppUITestSupport` or the other experiences.
import Foundation
import XCTest

/// Launch arguments, identifiers, level 1's certified solution and helpers of the R02-G05 interface tests.
enum CC {
    /// The experience's id in the catalog.
    static let experienceID = "r02-g05.colorfall-canyons"
    /// The prefix of every identifier of the experience's controls.
    static let prefix = "experience.r02-g05.colorfall-canyons."
    /// The debug argument that makes the candidates available (DebugLaunch).
    static let candidates = "-vcCandidates"
    /// A first start with erased data, straight into Colorfall Canyons.
    static let fresh = [VC.reset, VC.skipWelcome, candidates, VC.openExperience, experienceID]
    /// A start over the same storage (no reset), straight into Colorfall Canyons.
    static let relaunch = [VC.skipWelcome, candidates, VC.openExperience, experienceID]
    /// The longest a single check waits (each test stays under 90 s).
    static let shortWait: TimeInterval = 5
    /// The most drags one reveal makes.
    static let maxDrags = 24

    /// One action of the certified solution (`ColorfallCanyonsAction`): a carve of a cell or a time step of n ticks.
    enum Action: Equatable {
        case carve(Int)
        case step(Int)
    }

    // Level 1, pinned here so the interface tests need no Core import (verified by the lead of feature 349 against
    // `ColorfallCanyonsExperienceCore` and the certified level 1, 2026-11-21): 6 columns × 5 rows, one spring, budget 9,
    // tick limit 120, certified smallest 2; the certified actions carve cell 10 twice and step 120 ticks; the play is won
    // at tick 17 with 2 actions spent (the smallest), so three stars.

    /// Level 1's columns.
    static let levelOneColumns = 6
    /// Level 1's rows.
    static let levelOneRows = 5
    /// Level 1's springs.
    static let levelOneSprings = 1
    /// Level 1's budget of carves and valve toggles.
    static let levelOneBudget = 9
    /// Level 1's tick limit.
    static let levelOneTickLimit = 120
    /// Level 1's certified smallest edit count.
    static let levelOneSmallest = 2
    /// Level 1's certified actions.
    static let levelOneActions: [Action] = [.carve(10), .carve(10), .step(120)]
    /// The tick at which level 1's certified play is won.
    static let levelOneWinTick = 17
    /// Level 1's carvable cells at the start, in the cell picker's order (cell 10 is index 8).
    static let levelOneCarvable: [Int] = [0, 2, 3, 5, 6, 7, 8, 9, 10, 11, 13, 15, 18, 19, 20, 21, 22, 23, 25, 26, 27,
                                          28, 29]

    /// The canvas phrase of a won level.
    static let filled = "Every basin is filled"
    /// The canvas phrase of a level won with all three stars.
    static let threeStars = "Stars: 3 of 3"
    /// The level picker's value of level 1 once it is won with three stars.
    static let levelOneThreeStars = "Level 1, band 1, 3 stars"

    /// The cell picker's label of `cell` on a grid of `columns`: "row r, column c", 1-based.
    static func cellLabel(_ cell: Int, columns: Int = CC.levelOneColumns) -> String {
        "row \(cell / max(columns, 1) + 1), column \(cell % max(columns, 1) + 1)"
    }

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

    /// Launches the app with `arguments` and waits until Colorfall Canyons runs.
    @MainActor
    @discardableResult
    static func open(arguments: [String] = CC.fresh, file: StaticString = #filePath, line: UInt = #line)
        -> XCUIApplication {
        let app = launchApp(arguments: arguments)
        waitForRunning(app, file: file, line: line)
        return app
    }

    /// Backgrounds `app` (its save point), ends it and opens Colorfall Canyons again over the same storage
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
        let second = launchApp(arguments: CC.relaunch)
        waitForRunning(second, file: file, line: line)
        return second
    }

    /// Waits for the experience route, the canvas labelled with a level and the level picker.
    @MainActor
    private static func waitForRunning(_ app: XCUIApplication, file: StaticString, line: UInt) {
        waitFor(element(app, "vc.route.experience"), timeout: VC.firstWait, file: file, line: line)
        waitFor(canvas(app), timeout: VC.firstWait, file: file, line: line)
        waitFor(control(app, "level-picker"), timeout: VC.wait, "the level picker is there", file: file, line: line)
        // "contains", not "hasPrefix": a cell highlighted by a gesture puts "Carving row r, column c. " first.
        XCTAssertTrue(waitForLabel(canvas(app)) { $0.contains("Colorfall Canyons level") },
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
        // A drag that leaves the target where it was means the list is at its end: a hittable target is then as far
        // in view as it can be (the panel's header grows after a carve, so the picker can sit at the list's edge).
        var stuck = false
        while drags < maxDrags, target.exists, !isShown(app, target) {
            let list = controlsList(app)
            let middle = list.exists ? list.frame.midY : app.windows.firstMatch.frame.midY
            let before = target.frame
            var distance = before.midY - middle
            if abs(distance) < 1 { distance = 40 }
            drag(app, by: distance)
            drags += 1
            if target.frame == before {
                stuck = true
                break
            }
        }
        let found = isShown(app, target) || (stuck && target.exists && target.isHittable)
        XCTAssertTrue(found, "not reached by scrolling the controls: \(target)", file: file, line: line)
        return found
    }

    /// Waits for the control `name`, scrolls it into view and returns it, or nil when it is not there.
    @MainActor
    static func shown(_ app: XCUIApplication, _ name: String, file: StaticString = #filePath, line: UInt = #line)
        -> XCUIElement? {
        let target = control(app, name)
        // An element already present skips the bounded wait, whose first check costs about a second.
        guard target.exists || waitFor(target, timeout: shortWait, "\(name) is there", file: file, line: line),
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

    /// The stepper `name` (`cell-picker` or `level-picker`): the system stepper with the identifier when there is one,
    /// else the control of any type.
    @MainActor
    static func stepper(_ app: XCUIApplication, _ name: String) -> XCUIElement {
        let found = app.steppers.matching(identifier: id(name)).firstMatch
        return found.exists ? found : control(app, name)
    }

    /// The increment (`up`) or decrement button of the stepper `name`: the inner button whose label or identifier
    /// names it, else a button with the suffixed identifier, else nil (the caller taps the end of the row).
    @MainActor
    static func stepperButton(_ app: XCUIApplication, _ name: String, up: Bool) -> XCUIElement? {
        let word = up ? "Increment" : "Decrement"
        let inner = stepper(app, name).buttons
            .matching(NSPredicate(format: "label CONTAINS[c] %@ OR identifier CONTAINS[c] %@", word, word)).firstMatch
        if inner.exists { return inner }
        let suffixed = element(app, id(name) + "-" + word)
        return suffixed.exists ? suffixed : nil
    }

    /// Presses the increment (`up`) or decrement button of the stepper `name` once and waits briefly until its value
    /// changes; returns the value after the press.
    @MainActor
    @discardableResult
    static func press(_ app: XCUIApplication, _ name: String, up: Bool) -> String {
        let control = stepper(app, name)
        let before = control.value as? String ?? ""
        if let button = stepperButton(app, name, up: up) { button.tap() } else {
            control.coordinate(withNormalizedOffset: CGVector(dx: up ? 0.95 : 0.8, dy: 0.5)).tap()
        }
        _ = waitForValue(control, timeout: 2) { $0 != before }
        return control.value as? String ?? ""
    }

    /// Steps the cell picker forward (wrapping) until it shows `cell` of level 1's grid, at most one press per
    /// carvable cell and two more (the carvable list may change after a carve). True when it shows the cell.
    @MainActor
    @discardableResult
    static func pickCell(_ app: XCUIApplication, _ cell: Int, file: StaticString = #filePath, line: UInt = #line)
        -> Bool {
        let target = cellLabel(cell)
        let control = stepper(app, "cell-picker")
        guard control.exists || waitFor(control, timeout: shortWait, "cell-picker is there", file: file, line: line)
        else { return false }
        // Only the increment button is pressed: when it is already hittable the stepper needs no scrolling (after a
        // carve the stepper's own centre can be covered while its buttons are not).
        if !(stepperButton(app, "cell-picker", up: true)?.isHittable ?? false) {
            guard reveal(app, control, file: file, line: line) else { return false }
        }
        var presses = 0
        var current = control.value as? String ?? ""
        while current != target, presses < levelOneCarvable.count + 2 {
            current = press(app, "cell-picker", up: true)
            presses += 1
        }
        XCTAssertEqual(current, target, "cell-picker shows cell \(cell) after \(presses) presses", file: file,
                       line: line)
        return current == target
    }

    /// The level number of a level picker value "Level n, band b[, k stars]", or nil.
    static func pickedLevel(_ text: String) -> Int? {
        guard text.hasPrefix("Level ") else { return nil }
        let rest = text.dropFirst("Level ".count)
        guard let comma = rest.firstIndex(of: ",") else { return nil }
        return Int(rest[rest.startIndex..<comma])
    }

    /// Steps the level picker to `level` (it holds open levels only), at most four presses; returns its value then.
    @MainActor
    @discardableResult
    static func pickLevel(_ app: XCUIApplication, _ level: Int, file: StaticString = #filePath, line: UInt = #line)
        -> String {
        let control = stepper(app, "level-picker")
        guard control.exists || waitFor(control, timeout: shortWait, "level-picker is there", file: file, line: line)
        else { return "" }
        // As for the cell picker: no scrolling when both stepper buttons can already be tapped.
        let ready = (stepperButton(app, "level-picker", up: true)?.isHittable ?? false)
            && (stepperButton(app, "level-picker", up: false)?.isHittable ?? false)
        if !ready {
            guard reveal(app, control, file: file, line: line) else { return "" }
        }
        var current = control.value as? String ?? ""
        var presses = 0
        while let picked = pickedLevel(current), picked != level, presses < 4 {
            let after = press(app, "level-picker", up: picked < level)
            presses += 1
            if after == current { break }   // the frontier or level 1: the picker cannot move further
            current = after
        }
        return current
    }

    /// Plays level 1's certified solution with the panel: the cell picker stepped to cell 10 and Carve, again (the
    /// picker is checked before the second carve), then Run. True when every control was used and showed what it
    /// should.
    @MainActor
    @discardableResult
    static func playLevelOneSolution(_ app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line)
        -> Bool {
        var spent = 0
        for action in levelOneActions {
            switch action {
            case .carve(let cell):
                guard pickCell(app, cell, file: file, line: line) else { return false }
                guard tap(app, "carve", file: file, line: line) else { return false }
                spent += 1
                let left = "; \(levelOneBudget - spent) actions left."
                XCTAssertTrue(waitForDescription(app) { $0.contains(left) },
                              "the carve spent one action: \(description(app))", file: file, line: line)
            case .step(let ticks):
                let expected = "\(ticks) ticks left"
                XCTAssertTrue(waitForValue(control(app, "run")) { $0 == expected },
                              "Run steps the \(ticks) ticks left (now \(value(app, "run")))", file: file, line: line)
                guard tap(app, "run", file: file, line: line) else { return false }
            }
        }
        return true
    }

    /// A fresh start, the tutorial dismissed and level 1 won with its certified solution; returns the app after the
    /// canvas reports every basin filled with all three stars.
    @MainActor
    @discardableResult
    static func winLevelOne(file: StaticString = #filePath, line: UInt = #line) -> XCUIApplication {
        let app = open(arguments: fresh, file: file, line: line)
        XCTAssertTrue(description(app).contains("Colorfall Canyons level 1."),
                      "a fresh start opens level 1: \(description(app))", file: file, line: line)
        XCTAssertTrue(description(app).contains("Tick 0 of \(levelOneTickLimit); \(levelOneBudget) actions left."),
                      "level 1 starts at tick 0 with its budget: \(description(app))", file: file, line: line)
        dismissTutorialIfShown(app, file: file, line: line)
        XCTAssertTrue(playLevelOneSolution(app, file: file, line: line), "the solution is played",
                      file: file, line: line)
        XCTAssertTrue(waitForDescription(app, timeout: VC.wait) { $0.contains(filled) && $0.contains(threeStars) },
                      "the canvas reports every basin filled with three stars: \(description(app))",
                      file: file, line: line)
        return app
    }

    /// The position and length of a replay step value "Action p of n", or nil.
    static func replayPosition(_ text: String) -> (position: Int, length: Int)? {
        guard text.hasPrefix("Action ") else { return nil }
        let parts = text.dropFirst("Action ".count).components(separatedBy: " of ")
        guard parts.count == 2, let p = Int(parts[0]), let n = Int(parts[1]) else { return nil }
        return (p, n)
    }

    /// Waits until the label of `target` satisfies `condition`; true when it does.
    @MainActor
    static func waitForLabel(_ target: XCUIElement, timeout: TimeInterval = CC.shortWait,
                             _ condition: (String) -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while !(target.exists && condition(target.label)), Date() < deadline { usleep(200_000) }
        return target.exists && condition(target.label)
    }

    /// Waits until the value of `target` (as text) satisfies `condition`; true when it does.
    @MainActor
    static func waitForValue(_ target: XCUIElement, timeout: TimeInterval = CC.shortWait,
                             _ condition: (String) -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        func current() -> String { target.exists ? (target.value as? String ?? "") : "" }
        while !(target.exists && condition(current())), Date() < deadline { usleep(200_000) }
        return target.exists && condition(current())
    }

    /// Waits until the canvas description satisfies `condition`; true when it does.
    @MainActor
    static func waitForDescription(_ app: XCUIApplication, timeout: TimeInterval = CC.shortWait,
                                   _ condition: (String) -> Bool) -> Bool {
        waitForLabel(canvas(app), timeout: timeout, condition)
    }
}
