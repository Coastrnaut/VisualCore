// AESupport — feature 369 (R02-G07-09) T-R02G0709-004 (FR-R02G0709-001, 002; SC-R02G0709-001; clarifications Q1, Q2):
// helpers of the interface tests of Amethyst Escape (R02-G07) inside the one app, modelled on `CRSupport`.
// Every launch carries `-vcCandidates` (DebugLaunch: the candidates' catalog entries become available and are
// registered). A fresh start erases the data (`-vcResetData`, so no level is solved), skips the welcome and opens the
// experience directly with `-openExperience r02-g07.amethyst-escape`; a relaunch (`AE.reopen`) backgrounds the app
// first (its save point), terminates it and starts again without the reset, so the stored progress (solved levels,
// stars, the frontier, the verified winning trace) survives.
//
// The canvas (`session.canvas`) is labelled with the presenter's description (`AmethystEscapePresenter.describe`):
// "Amethyst Escape level n. ", "m of b moves spent. The pearl is … ", the exit gap, each shell with its turn and, when
// won, "The pearl escaped through the exit gap." followed by " Stars: s of 3." when the level has stars in the
// progress. The controls are found by the identifiers of `AmethystEscapeControls.identifierNames`
// (`port.identifier(name)`, that is `experience.r02-g07.amethyst-escape.<name>`): `turn-down`, `turn-up` (send
// `shell.rotate [picked shell, ∓/± 1]`; value "<Shell>, turned t of N"), `advance` (sends `pearl.advance`; value
// "The pearl is …"), `undo`, `redo`, `next-level`, `show-all-layers`, `reset-view`, `hint`, `dismiss-tutorial`,
// `failure-undo`, `retry`, `campaign`, `daily`, `practice` (value "selected" for the current mode, else ""),
// `play-level`, `replay` (when the level has a verified stored solution, not during replay), `replay-step` (value
// "Action p of n") and `replay-stop`, the stepper `shell-picker` ("Shell to turn", value "<Shell>, turned t of N",
// wrapping; `presenter.pickShell(±1)`; presentation only), the stepper `level-picker` (value "Level n, band b" plus ",
// k stars" when won; it never goes past the open frontier or below 1; presentation only), the toggle `sound` and the
// element `summary` (the "Crystal" element). The controls sit below the canvas in a scroll view; a control is scrolled
// into view before it is used, with slow drags near the left edge. Everything lives in the namespace `AE`, so that
// nothing collides with the shared helpers of `AppUITestSupport` or the other experiences.
import Foundation
import XCTest

/// Launch arguments, identifiers, level 1's certified solution and helpers of the R02-G07 interface tests.
enum AE {
    /// The experience's id in the catalog.
    static let experienceID = "r02-g07.amethyst-escape"
    /// The prefix of every identifier of the experience's controls.
    static let prefix = "experience.r02-g07.amethyst-escape."
    /// The debug argument that makes the candidates available (DebugLaunch).
    static let candidates = "-vcCandidates"
    /// A first start with erased data, straight into Amethyst Escape.
    static let fresh = [VC.reset, VC.skipWelcome, candidates, VC.openExperience, experienceID]
    /// A start over the same storage (no reset), straight into Amethyst Escape.
    static let relaunch = [VC.skipWelcome, candidates, VC.openExperience, experienceID]
    /// The longest a single check waits (each test stays under 90 s).
    static let shortWait: TimeInterval = 5
    /// The most drags one reveal makes.
    static let maxDrags = 24

    /// One action of the certified solution: turn shell `shell` (0-based, innermost first) by `step` sectors (+1
    /// clockwise, −1 anticlockwise), or roll the pearl one pocket.
    enum Action: Equatable {
        case rotate(shell: Int, step: Int)
        case advance
    }

    // Level 1, pinned here so the interface tests need no Core import (read on 2026-11-22 from the stored witness
    // `docs/games/amethyst-escape/levels/001.witness.json`; an app unit test checks them against the Core): 6 sectors,
    // two shells (shell 1 inner, shell 2 outer), budget 9, certified smallest 3; the certified actions are
    // `rotate(0, −1)`, `advance`, `advance`; every shell starts turned 0 (`AmethystEscapeCrystal`) and the panel's
    // shell pick starts at shell 1 (`AmethystEscapeMirror.pickedShell = 0`), so the play is Turn − once and Advance
    // twice; 3 moves spent of 9 equal the smallest, so three stars (`AmethystEscapeProgress.stars`); the stored trace
    // holds the 3 net actions; the tutorial starts at its first step (levels 1 … 3).

    /// Level 1's certified actions, in the order of the witness.
    static let levelOneActions: [Action] = [.rotate(shell: 0, step: -1), .advance, .advance]
    /// The shell picker's name of every shell of level 1 (`AmethystEscapeLevel.shellName`, first letter raised).
    static let levelOneShellNames: [String] = ["Shell 1 (inner)", "Shell 2 (outer)"]
    /// The shell the panel picks when a level opens (0-based).
    static let startPickedShell = 0
    /// Level 1's sectors per shell.
    static let levelOneSectors = 6
    /// Level 1's move budget.
    static let levelOneBudget = 9
    /// Level 1's certified smallest move count.
    static let levelOneSmallest = 3
    /// The length of the trace stored by the certified win (the turn and the two advances).
    static let levelOneTraceLength = 3

    /// The canvas phrase of a won level.
    static let won = "The pearl escaped through the exit gap"
    /// The canvas phrase of a level won with all three stars.
    static let threeStars = "Stars: 3 of 3"
    /// The level picker's value of level 1 once it is won with three stars.
    static let levelOneThreeStars = "Level 1, band 1, 3 stars"

    /// The canvas phrase of `moves` moves spent of level 1's budget.
    static func spent(_ moves: Int) -> String { ". \(moves) of \(levelOneBudget) moves spent." }

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

    /// Launches the app with `arguments` and waits until Amethyst Escape runs.
    @MainActor
    @discardableResult
    static func open(arguments: [String] = AE.fresh, file: StaticString = #filePath, line: UInt = #line)
        -> XCUIApplication {
        let app = launchApp(arguments: arguments)
        waitForRunning(app, file: file, line: line)
        return app
    }

    /// Backgrounds `app` (its save point), ends it and opens Amethyst Escape again over the same storage
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
        let second = launchApp(arguments: AE.relaunch)
        waitForRunning(second, file: file, line: line)
        return second
    }

    /// Waits for the experience route, the canvas labelled with a level and the level picker.
    @MainActor
    private static func waitForRunning(_ app: XCUIApplication, file: StaticString, line: UInt) {
        waitFor(element(app, "vc.route.experience"), timeout: VC.firstWait, file: file, line: line)
        waitFor(canvas(app), timeout: VC.firstWait, file: file, line: line)
        waitFor(control(app, "level-picker"), timeout: VC.wait, "the level picker is there", file: file, line: line)
        // "contains", not "hasPrefix": a shell dragged by a gesture or an isolated shell puts its words first.
        XCTAssertTrue(waitForLabel(canvas(app)) { $0.contains("Amethyst Escape level") },
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

    /// The stepper `name` (`shell-picker` or `level-picker`): the system stepper with the identifier when there is
    /// one, else the control of any type.
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

    /// Makes sure both buttons of the stepper `name` can be tapped, scrolling the stepper into view when they cannot.
    @MainActor
    private static func ready(_ app: XCUIApplication, _ name: String, file: StaticString, line: UInt) -> Bool {
        let control = stepper(app, name)
        guard control.exists || waitFor(control, timeout: shortWait, "\(name) is there", file: file, line: line)
        else { return false }
        // No scrolling when both stepper buttons can already be tapped (the stepper's own centre can be covered while
        // its buttons are not).
        let hittable = (stepperButton(app, name, up: true)?.isHittable ?? false)
            && (stepperButton(app, name, up: false)?.isHittable ?? false)
        return hittable || reveal(app, control, file: file, line: line)
    }

    /// The 0-based shell of a shell picker value "<Shell>, turned t of N" of level 1, or nil.
    static func pickedShell(_ text: String) -> Int? {
        levelOneShellNames.firstIndex { text.hasPrefix($0 + ",") }
    }

    /// Steps the shell picker the shorter way round (it wraps) until it shows shell `shell` of level 1, at most one
    /// press per shell. True when it shows the shell.
    @MainActor
    @discardableResult
    static func pickShell(_ app: XCUIApplication, _ shell: Int, file: StaticString = #filePath, line: UInt = #line)
        -> Bool {
        guard levelOneShellNames.indices.contains(shell), ready(app, "shell-picker", file: file, line: line) else {
            return false
        }
        let control = stepper(app, "shell-picker")
        let count = levelOneShellNames.count
        var current = control.value as? String ?? ""
        var presses = 0
        while pickedShell(current) != shell, presses < count {
            let at = pickedShell(current) ?? startPickedShell
            let forward = ((shell - at) % count + count) % count
            current = press(app, "shell-picker", up: forward <= count - forward)
            presses += 1
        }
        XCTAssertEqual(pickedShell(current), shell,
                       "shell-picker shows shell \(shell + 1) after \(presses) presses (now \(current))",
                       file: file, line: line)
        return pickedShell(current) == shell
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

    /// Plays level 1's certified solution with the panel: for each turn the shell picker is stepped to its shell and
    /// Turn + (step +1) or Turn − (step −1) is pressed, and the turn button's value must then name the shell's new
    /// turn; for each advance Advance is pressed. After every action the canvas must report one more move spent. True
    /// when every control was used and showed what it should.
    @MainActor
    @discardableResult
    static func playLevelOneSolution(_ app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line)
        -> Bool {
        var offsets = Array(repeating: 0, count: levelOneShellNames.count)
        var moves = 0
        for action in levelOneActions {
            switch action {
            case .rotate(let shell, let step):
                guard pickShell(app, shell, file: file, line: line) else { return false }
                let name = step > 0 ? "turn-up" : "turn-down"
                guard let button = shown(app, name, file: file, line: line) else { return false }
                button.tap()
                offsets[shell] = ((offsets[shell] + step) % levelOneSectors + levelOneSectors) % levelOneSectors
                let expected = "\(levelOneShellNames[shell]), turned \(offsets[shell]) of \(levelOneSectors)"
                XCTAssertTrue(waitForValue(button) { $0 == expected },
                              "\(name) turned \(levelOneShellNames[shell]) (now \(button.value as? String ?? ""))",
                              file: file, line: line)
            case .advance:
                guard tap(app, "advance", file: file, line: line) else { return false }
            }
            moves += 1
            XCTAssertTrue(waitForDescription(app) { $0.contains(spent(moves)) },
                          "move \(moves) is spent: \(description(app))", file: file, line: line)
        }
        return true
    }

    /// A fresh start, the tutorial dismissed and level 1 won with its certified solution; returns the app after the
    /// canvas reports the pearl escaped with all three stars.
    @MainActor
    @discardableResult
    static func winLevelOne(file: StaticString = #filePath, line: UInt = #line) -> XCUIApplication {
        let app = open(arguments: fresh, file: file, line: line)
        XCTAssertTrue(description(app).contains("Amethyst Escape level 1."),
                      "a fresh start opens level 1: \(description(app))", file: file, line: line)
        XCTAssertTrue(description(app).contains(spent(0)),
                      "level 1 starts with no move spent of its budget: \(description(app))", file: file, line: line)
        XCTAssertEqual(pickedShell(value(app, "shell-picker")), startPickedShell,
                       "the shell picker starts on shell \(startPickedShell + 1): \(value(app, "shell-picker"))",
                       file: file, line: line)
        dismissTutorialIfShown(app, file: file, line: line)
        XCTAssertTrue(playLevelOneSolution(app, file: file, line: line), "the solution is played",
                      file: file, line: line)
        XCTAssertTrue(waitForDescription(app, timeout: VC.wait) { $0.contains(won) && $0.contains(threeStars) },
                      "the canvas reports the pearl escaped with three stars: \(description(app))",
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
    static func waitForLabel(_ target: XCUIElement, timeout: TimeInterval = AE.shortWait,
                             _ condition: (String) -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while !(target.exists && condition(target.label)), Date() < deadline { usleep(200_000) }
        return target.exists && condition(target.label)
    }

    /// Waits until the value of `target` (as text) satisfies `condition`; true when it does.
    @MainActor
    static func waitForValue(_ target: XCUIElement, timeout: TimeInterval = AE.shortWait,
                             _ condition: (String) -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        func current() -> String { target.exists ? (target.value as? String ?? "") : "" }
        while !(target.exists && condition(current())), Date() < deadline { usleep(200_000) }
        return target.exists && condition(current())
    }

    /// Waits until the canvas description satisfies `condition`; true when it does.
    @MainActor
    static func waitForDescription(_ app: XCUIApplication, timeout: TimeInterval = AE.shortWait,
                                   _ condition: (String) -> Bool) -> Bool {
        waitForLabel(canvas(app), timeout: timeout, condition)
    }
}
