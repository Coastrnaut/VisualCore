// ECGSupport — feature 409 (R02-G11-09) T-R02G1109-004 (FR-R02G1109-002; SC-R02G1109-001; clarifications Q1, Q2):
// helpers of the interface tests of Echo Cartographer (R02-G11) inside the one app, modelled on `BASupport` (feature
// 399). The namespace is `ECG` (`EC` belongs to Effects Composer). Echo Cartographer is a candidate, so every launch
// carries `-vcCandidates` (DebugLaunch: the candidates' catalog entries become available and are registered). A fresh
// start erases the data (`-vcResetData`, so no level is solved), skips the welcome and opens the experience directly
// with `-openExperience r02-g11.echo-cartographer`; a relaunch (`ECG.reopen`) backgrounds the app first (its save
// point), terminates it and starts again without the reset, so the stored progress (solved levels, stars, the frontier,
// the verified winning trace) survives.
//
// The canvas (`session.canvas`) is labelled with the presenter's description (`EchoCartographerPresenter.describe`):
// "Echo Cartographer level n. ", the progress "k of b beacon(s) located, e energy left" (with the last pulse's report),
// and, when won, "Every beacon is located." followed by " Stars: s of 3." when the level has stars in the progress,
// then the goal and the tutorial. The controls are found by the identifiers of Clarification Q1
// (`port.identifier(name)`, that is `experience.r02-g11.echo-cartographer.<name>`): the buttons `pulse`, `claim` and
// `mark` (value: the cursor's cell in words), `undo`, `redo`, `next-level`, `reset-view`, `hint`, `dismiss-tutorial`,
// `failure-undo`, `retry`, `campaign`, `daily`, `practice` (value "selected" for the current mode, else "not
// selected"), `play-level`, `replay` (when the level has a verified stored solution, not during replay), `replay-step`
// (value "Action k of n") and `replay-stop`; the steppers `column-picker` and `row-picker` (labelled "Column of the
// chosen cell" and "Row of the chosen cell"; both carry the value `EchoCartographerMirror.cursorLabel`, "column c, row
// r: known" with known one of unknown, open or wall — or "column c, row r" before a play is followed — clamped to the
// chamber) and `level-picker` ("Level n, band b" plus ", k stars" when won; never past the open frontier or below 1) —
// all presentation only; the toggle `sound` and the element `summary` (the "Chamber" element). The controls sit below
// the canvas in a scroll view; a control is scrolled into view before it is used, with slow drags near the left edge.
// Everything lives in the namespace `ECG`, so that nothing collides with the shared helpers of `AppUITestSupport` or
// the other experiences.
import Foundation
import XCTest

/// Launch arguments, identifiers, level 1's certified actions and helpers of the R02-G11 interface tests.
enum ECG {
    /// The experience's id in the catalog.
    static let experienceID = "r02-g11.echo-cartographer"
    /// The prefix of every identifier of the experience's controls.
    static let prefix = "experience.r02-g11.echo-cartographer."
    /// The debug argument that makes the candidates available (DebugLaunch).
    static let candidates = "-vcCandidates"
    /// A first start with erased data, straight into Echo Cartographer.
    static let fresh = [VC.reset, VC.skipWelcome, candidates, VC.openExperience, experienceID]
    /// A start over the same storage (no reset), straight into Echo Cartographer.
    static let relaunch = [VC.skipWelcome, candidates, VC.openExperience, experienceID]
    /// The longest a single check waits (each test stays under 90 s).
    static let shortWait: TimeInterval = 5
    /// The most drags one reveal makes.
    static let maxDrags = 24
    /// The most presses one stepper makes to reach a value (level 1's chamber is 6 × 6; it needs at most 5).
    static let maxPresses = 12

    // Level 1, pinned here so the interface tests need no Core import (read on 2026-11-23 from the stored witness
    // `docs/games/echo-cartographer/levels/001.witness.json`; an app unit test checks them against the Core,
    // `EchoCartographerExperienceCore.certifiedActions(1)`, the level's entry and its chamber): a 6 × 6 chamber,
    // 1 beacon, energy 9, tutorial on, entry at column 0, row 3. The witness's actions, encoded
    // `{"pulse": {"_0": column, "_1": row}}` and `{"claim": {...}}` (`EchoCartographerAction.pulse(Int, Int)` and
    // `.claim(Int, Int)`, the values `cell.pulse [column, row]` and `cell.claim [column, row]` send), are pulse(0, 3),
    // pulse(0, 2) and claim(1, 2): two pulses equal the certified pulses, so three stars; the stored trace holds the
    // three actions.
    //
    // The cursor: `EchoCartographerMirror.follow` on a new level puts it on the entry; within a level it stays where
    // it was set (an action only clamps it to the chamber), so before each action both steppers are read and stepped
    // from their values.

    /// One certified action of level 1: a pulse or a claim at a cell.
    struct Action {
        /// True for a claim, false for a pulse.
        let claim: Bool
        /// The cell's column.
        let column: Int
        /// The cell's row.
        let row: Int
    }

    /// Level 1's certified actions, in the order of the witness.
    static let certifiedActions: [Action] = [
        Action(claim: false, column: 0, row: 3),
        Action(claim: false, column: 0, row: 2),
        Action(claim: true, column: 1, row: 2),
    ]
    /// The cell the column and row steppers show when level 1 opens (its entry; `EchoCartographerMirror.follow`).
    static let levelOneEntry: (column: Int, row: Int) = (column: 0, row: 3)
    /// Level 1's chamber (width, height).
    static let levelOneChamber: (width: Int, height: Int) = (width: 6, height: 6)
    /// The length of the trace stored by the certified win (the three actions).
    static let levelOneTraceLength = 3

    /// The canvas phrase of a fresh level 1 (its one beacon not yet located).
    static let noneLocated = "0 of 1 beacon located"
    /// The canvas phrase of level 1 with its beacon located.
    static let allLocated = "1 of 1 beacon located"
    /// The canvas phrase of a won level.
    static let won = "Every beacon is located."
    /// The canvas phrase of a level won with all three stars.
    static let threeStars = "Stars: 3 of 3."
    /// The level picker's value of level 1 once it is won with three stars (band 1: levels 1 … 20).
    static let levelOneThreeStars = "Level 1, band 1, 3 stars"

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

    /// Launches the app with `arguments` and waits until Echo Cartographer runs.
    @MainActor
    @discardableResult
    static func open(arguments: [String] = ECG.fresh, file: StaticString = #filePath, line: UInt = #line)
        -> XCUIApplication {
        let app = launchApp(arguments: arguments)
        waitForRunning(app, file: file, line: line)
        return app
    }

    /// Backgrounds `app` (its save point), ends it and opens Echo Cartographer again over the same storage
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
        let second = launchApp(arguments: ECG.relaunch)
        waitForRunning(second, file: file, line: line)
        return second
    }

    /// Waits for the experience route, the canvas labelled with a level and the level picker.
    @MainActor
    private static func waitForRunning(_ app: XCUIApplication, file: StaticString, line: UInt) {
        waitFor(element(app, "vc.route.experience"), timeout: VC.firstWait, file: file, line: line)
        waitFor(canvas(app), timeout: VC.firstWait, file: file, line: line)
        waitFor(control(app, "level-picker"), timeout: VC.wait, "the level picker is there", file: file, line: line)
        XCTAssertTrue(waitForLabel(canvas(app)) { $0.contains("Echo Cartographer level") },
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

    /// Whether `target`'s whole frame lies inside the controls list's visible frame (or the window when there is no
    /// list), whatever its hittability says.
    @MainActor
    static func insideList(_ app: XCUIApplication, _ target: XCUIElement) -> Bool {
        let list = controlsList(app)
        let visible = (list.exists ? list.frame : app.windows.firstMatch.frame).insetBy(dx: 0, dy: -1)
        let frame = target.frame
        return !frame.isEmpty && frame.minY >= visible.minY && frame.maxY <= visible.maxY
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
        // in view as it can be.
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
            || (target.exists && insideList(app, target))
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

    /// The stepper `name` (`column-picker`, `row-picker` or `level-picker`): the system stepper with the identifier
    /// when there is one, else the control of any type.
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
        // A restored panel can report a visible button as not hittable (nested scroll views right after a relaunch);
        // a coordinate tap still reaches it, and an unchanged value fails the caller.
        if let button = stepperButton(app, name, up: up) {
            if button.isHittable { button.tap() } else {
                button.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            }
        } else {
            control.coordinate(withNormalizedOffset: CGVector(dx: up ? 0.95 : 0.8, dy: 0.5)).tap()
        }
        _ = waitForValue(control, timeout: 2) { $0 != before }
        return control.value as? String ?? ""
    }

    /// Makes sure both buttons of the stepper `name` can be tapped, scrolling the stepper into view when they cannot.
    @MainActor
    private static func ready(_ app: XCUIApplication, _ name: String, file: StaticString, line: UInt) -> Bool {
        let control = stepper(app, name)
        guard control.exists || waitFor(control, timeout: shortWait, "\(name) is there", file: file, line: line)
        else { return false }
        // No scrolling when both stepper buttons can already be tapped (the stepper's own centre can be covered while
        // its buttons are not). Right after a relaunch the restored panel is still being laid out, so the buttons get a
        // bounded moment (at most 5 s, checked every 0.25 s) to become tappable before any scrolling.
        var hittable = false
        var checks = 0
        while !hittable, checks < 20 {
            hittable = (stepperButton(app, name, up: true)?.isHittable ?? false)
                && (stepperButton(app, name, up: false)?.isHittable ?? false)
            if !hittable { usleep(250_000) }
            checks += 1
        }
        return hittable || reveal(app, control, file: file, line: line)
    }

    /// The number after `prefix` up to the first non-digit of `text` (a leading "−" or "-" not accepted), or nil.
    static func number(after prefix: String, in text: String) -> Int? {
        guard text.hasPrefix(prefix) else { return nil }
        let digits = text.dropFirst(prefix.count).prefix { $0.isASCII && $0.isNumber }
        return digits.isEmpty ? nil : Int(digits)
    }

    /// The cursor's cell of a column or row stepper value "column c, row r: known" (or "column c, row r"), or nil.
    static func cell(_ text: String) -> (column: Int, row: Int)? {
        guard let column = number(after: "column ", in: text),
              let comma = text.range(of: ", row ") else { return nil }
        let digits = text[comma.upperBound...].prefix { $0.isASCII && $0.isNumber }
        guard !digits.isEmpty, let row = Int(digits) else { return nil }
        return (column, row)
    }

    /// The column of a stepper value (``cell(_:)``), or nil.
    static func pickedColumn(_ text: String) -> Int? { cell(text)?.column }

    /// The row of a stepper value (``cell(_:)``), or nil.
    static func pickedRow(_ text: String) -> Int? { cell(text)?.row }

    /// The cursor's cell as the column stepper shows it, or nil when it cannot be read.
    @MainActor
    static func cursor(_ app: XCUIApplication) -> (column: Int, row: Int)? {
        cell(stepper(app, "column-picker").value as? String ?? "")
    }

    /// Steps the clamped stepper `name` from its current value (read with `parse`) to `target`, at most
    /// ``maxPresses`` presses: up when it is below the target, else down; it stops when a press leaves its value
    /// unchanged (an end of its range). True when it shows the target.
    @MainActor
    @discardableResult
    static func step(_ app: XCUIApplication, _ name: String, to target: Int,
                     parse: (String) -> Int?, file: StaticString = #filePath, line: UInt = #line) -> Bool {
        let control = stepper(app, name)
        var current = control.value as? String ?? ""
        // No reveal when the stepper already shows the target.
        if parse(current) == target { return true }
        guard ready(app, name, file: file, line: line) else { return false }
        current = control.value as? String ?? ""
        var presses = 0
        while let at = parse(current), at != target, presses < maxPresses {
            let after = press(app, name, up: at < target)
            presses += 1
            if after == current { break }   // an end of the range: it cannot move further
            current = after
        }
        let reached = parse(current) == target
        XCTAssertTrue(reached, "\(name) shows \(target) after \(presses) presses (now \(current))",
                      file: file, line: line)
        return reached
    }

    /// Moves the cursor to `column`, `row` with the steppers, each stepped from its current value: the column stepper
    /// first, then the row stepper. True when the cursor reads the target cell.
    @MainActor
    @discardableResult
    static func chooseCell(_ app: XCUIApplication, column: Int, row: Int,
                           file: StaticString = #filePath, line: UInt = #line) -> Bool {
        guard cursor(app) != nil else {
            XCTFail("the column and row steppers cannot be read: \(stepper(app, "column-picker").value ?? "nil")",
                    file: file, line: line)
            return false
        }
        guard step(app, "column-picker", to: column, parse: pickedColumn, file: file, line: line),
              step(app, "row-picker", to: row, parse: pickedRow, file: file, line: line) else { return false }
        guard let after = cursor(app), after.column == column, after.row == row,
              pickedColumn(stepper(app, "row-picker").value as? String ?? "") == column else {
            XCTFail("the cursor reads \(String(describing: cursor(app))), not column \(column), row \(row)",
                    file: file, line: line)
            return false
        }
        return true
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
        guard ready(app, "level-picker", file: file, line: line) else { return "" }
        let control = stepper(app, "level-picker")
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

    /// Plays one certified action with the panel: moves the cursor to its cell (``chooseCell``), checks that Pulse or
    /// Claim names that cell and taps it. True when every control was used and showed what it should.
    @MainActor
    @discardableResult
    static func play(_ app: XCUIApplication, _ action: Action, file: StaticString = #filePath, line: UInt = #line)
        -> Bool {
        guard chooseCell(app, column: action.column, row: action.row, file: file, line: line),
              let button = shown(app, action.claim ? "claim" : "pulse", file: file, line: line) else { return false }
        let shownCell = cell(button.value as? String ?? "")
        XCTAssertTrue(shownCell?.column == action.column && shownCell?.row == action.row,
                      "\(action.claim ? "Claim" : "Pulse") names the cell: \(button.value as? String ?? "")",
                      file: file, line: line)
        button.tap()
        return true
    }

    /// Plays level 1's certified actions with the panel (``play(_:_:file:line:)``); after every pulse the canvas must
    /// report a pulse from the action's cell, after the claim every beacon located. True when every action was played.
    @MainActor
    @discardableResult
    static func playLevelOneSolution(_ app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line)
        -> Bool {
        for (index, action) in certifiedActions.enumerated() {
            guard play(app, action, file: file, line: line) else { return false }
            if action.claim {
                XCTAssertTrue(waitForDescription(app) { $0.contains(allLocated) },
                              "action \(index + 1) locates the beacon: \(description(app))", file: file, line: line)
            } else {
                let report = "pulse from column \(action.column), row \(action.row)"
                XCTAssertTrue(waitForDescription(app) { $0.contains(report) },
                              "action \(index + 1) is a pulse from its cell: \(description(app))", file: file,
                              line: line)
            }
        }
        return true
    }

    /// A fresh start, the tutorial dismissed and level 1 won with its certified actions; returns the app after the
    /// canvas reports every beacon located with all three stars.
    @MainActor
    @discardableResult
    static func winLevelOne(file: StaticString = #filePath, line: UInt = #line) -> XCUIApplication {
        let app = open(arguments: fresh, file: file, line: line)
        XCTAssertTrue(description(app).contains("Echo Cartographer level 1."),
                      "a fresh start opens level 1: \(description(app))", file: file, line: line)
        XCTAssertTrue(description(app).contains(noneLocated),
                      "level 1 starts with its beacon not located: \(description(app))", file: file, line: line)
        let opening = cursor(app)
        XCTAssertTrue(opening?.column == levelOneEntry.column && opening?.row == levelOneEntry.row,
                      "the cursor starts on the entry, column 0, row 3 (now \(String(describing: opening)))",
                      file: file, line: line)
        dismissTutorialIfShown(app, file: file, line: line)
        XCTAssertTrue(playLevelOneSolution(app, file: file, line: line), "the solution is played",
                      file: file, line: line)
        XCTAssertTrue(waitForDescription(app, timeout: VC.wait) { $0.contains(won) && $0.contains(threeStars) },
                      "the canvas reports every beacon located with three stars: \(description(app))",
                      file: file, line: line)
        return app
    }

    /// The position and length of a replay step value "Action k of n", or nil.
    static func replayPosition(_ text: String) -> (position: Int, length: Int)? {
        guard text.hasPrefix("Action ") else { return nil }
        let parts = text.dropFirst("Action ".count).components(separatedBy: " of ")
        guard parts.count == 2, let p = Int(parts[0]), let n = Int(parts[1]) else { return nil }
        return (p, n)
    }

    /// Waits until the label of `target` satisfies `condition`; true when it does.
    @MainActor
    static func waitForLabel(_ target: XCUIElement, timeout: TimeInterval = ECG.shortWait,
                             _ condition: (String) -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while !(target.exists && condition(target.label)), Date() < deadline { usleep(200_000) }
        return target.exists && condition(target.label)
    }

    /// Waits until the value of `target` (as text) satisfies `condition`; true when it does.
    @MainActor
    static func waitForValue(_ target: XCUIElement, timeout: TimeInterval = ECG.shortWait,
                             _ condition: (String) -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        func current() -> String { target.exists ? (target.value as? String ?? "") : "" }
        while !(target.exists && condition(current())), Date() < deadline { usleep(200_000) }
        return target.exists && condition(current())
    }

    /// Waits until the canvas description satisfies `condition`; true when it does.
    @MainActor
    static func waitForDescription(_ app: XCUIApplication, timeout: TimeInterval = ECG.shortWait,
                                   _ condition: (String) -> Bool) -> Bool {
        waitForLabel(canvas(app), timeout: timeout, condition)
    }
}
