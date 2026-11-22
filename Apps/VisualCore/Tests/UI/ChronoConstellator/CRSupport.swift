// CRSupport — feature 359 (R02-G06-09) T-R02G0609-004 (FR-R02G0609-001, 002; SC-R02G0609-001; clarifications Q1, Q2):
// helpers of the interface tests of Chrono Constellator (R02-G06) inside the one app, modelled on `CCSupport`.
// Chrono Constellator is a candidate; every launch carries `-vcCandidates` (DebugLaunch: the candidates' catalog
// entries become available and are registered). A fresh start erases the data (`-vcResetData`, so no level is solved),
// skips the welcome and opens the experience directly with `-openExperience r02-g06.chrono-constellator`; a relaunch
// (`CR.reopen`) backgrounds the app first (its save point), terminates it and starts again without the reset, so the
// stored progress (solved levels, stars, the frontier, the verified winning trace) survives.
//
// The canvas (`session.canvas`) is labelled with the presenter's description (`ChronoConstellatorPresenter.describe`):
// "Chrono Constellator level n. ", "Tick t of l; k edits left. ", each star with its start phase and, when won, "Every
// star stands on its target." followed by " Stars: s of 3." when the level has stars in the progress. The controls are
// found by the identifiers of `ChronoConstellatorControls.identifierNames` (`port.identifier(name)`, that is
// `experience.r02-g06.chrono-constellator.<name>`): `phase-down`, `phase-up` (send `star.phase [picked star, phase ∓/±
// 1 round its loop]`; value "phase p of L"), `add-hold`, `remove-hold`, `step-1`, `step-10`, `run` (sends `time.step
// [min(1200, limit − tick)]`; value "k ticks left"), `rewind`, `undo`, `redo`, `next-level`, `reset-view`, `hint`,
// `dismiss-tutorial`, `failure-undo`, `failure-rewind`, `retry`, `campaign`, `daily`, `practice` (value "selected" for
// the current mode, else ""), `play-level`, `replay` (when the level has a verified stored solution, not during
// replay), `replay-step` (value "Action p of n") and `replay-stop`, the stepper `star-picker` (value "Star n (shape)",
// wrapping; `presenter.pickStar(±1)`; presentation only), the stepper `level-picker` (value "Level n, band b" plus ", k
// stars" when won; it never goes past the open frontier or below 1; presentation only), the toggle `sound` and the
// element `summary` (the "Sky" element). The controls sit below the canvas in a scroll view; a control is scrolled into
// view before it is used, with slow drags near the left edge. Everything lives in the namespace `CR`, so that nothing
// collides with the shared helpers of `AppUITestSupport` or the other experiences.
import Foundation
import XCTest

/// Launch arguments, identifiers, level 1's certified solution and helpers of the R02-G06 interface tests.
enum CR {
    /// The experience's id in the catalog.
    static let experienceID = "r02-g06.chrono-constellator"
    /// The prefix of every identifier of the experience's controls.
    static let prefix = "experience.r02-g06.chrono-constellator."
    /// The debug argument that makes the candidates available (DebugLaunch).
    static let candidates = "-vcCandidates"
    /// A first start with erased data, straight into Chrono Constellator.
    static let fresh = [VC.reset, VC.skipWelcome, candidates, VC.openExperience, experienceID]
    /// A start over the same storage (no reset), straight into Chrono Constellator.
    static let relaunch = [VC.skipWelcome, candidates, VC.openExperience, experienceID]
    /// The longest a single check waits (each test stays under 90 s).
    static let shortWait: TimeInterval = 5
    /// The most drags one reveal makes.
    static let maxDrags = 24

    /// One phase change of the certified solution: star `star` (0-based) starts at phase `phase` of its loop.
    struct PhaseChange: Equatable {
        let star: Int
        let phase: Int
    }

    // Level 1, pinned here so the interface tests need no Core import (computed by agent C of feature 359 on 2026-11-22
    // with a throwaway host test against `ChronoConstellatorExperienceCore.level(number: 1)`, `certifiedActions(1)` and
    // `opening(number: 1)`, played with the panel's rule; an app unit test checks them against the Core): 6 columns × 5
    // rows, two stars (star 1 a ring with a loop of 10 cells at default phase 7, star 2 a cross with a loop of 6 cells
    // at default phase 3), budget 9, tick limit 145, certified smallest 1; the certified actions are `phase(0, 8)` then
    // `step(145)`; one Phase + on star 1 and Run win at tick 3 with 1 edit in use (8 left), so three stars; the stored
    // trace holds 2 actions; the tutorial starts at its first step (levels 1 … 3).

    /// Level 1's default start phase of every star.
    static let levelOneDefaultPhases: [Int] = [7, 3]
    /// Level 1's loop length of every star.
    static let levelOneLoopLengths: [Int] = [10, 6]
    /// Level 1's certified phase changes, in the order of `certifiedActions(1)`.
    static let levelOnePhaseChanges: [PhaseChange] = [PhaseChange(star: 0, phase: 8)]
    /// The star picker's value of every star of level 1.
    static let levelOneStarNames: [String] = ["Star 1 (ring)", "Star 2 (cross)"]
    /// Level 1's budget of edits.
    static let levelOneBudget = 9
    /// Level 1's tick limit.
    static let levelOneTickLimit = 145
    /// Level 1's certified smallest edit count.
    static let levelOneSmallest = 1
    /// The tick at which level 1's certified play is won.
    static let levelOneWinTick = 3
    /// The length of the trace stored by the certified win (the phase press and the run).
    static let levelOneTraceLength = 2

    /// The canvas phrase of a won level.
    static let won = "Every star stands on its target"
    /// The canvas phrase of a level won with all three stars.
    static let threeStars = "Stars: 3 of 3"
    /// The level picker's value of level 1 once it is won with three stars.
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

    /// Launches the app with `arguments` and waits until Chrono Constellator runs.
    @MainActor
    @discardableResult
    static func open(arguments: [String] = CR.fresh, file: StaticString = #filePath, line: UInt = #line)
        -> XCUIApplication {
        let app = launchApp(arguments: arguments)
        waitForRunning(app, file: file, line: line)
        return app
    }

    /// Backgrounds `app` (its save point), ends it and opens Chrono Constellator again over the same storage
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
        let second = launchApp(arguments: CR.relaunch)
        waitForRunning(second, file: file, line: line)
        return second
    }

    /// Waits for the experience route, the canvas labelled with a level and the level picker.
    @MainActor
    private static func waitForRunning(_ app: XCUIApplication, file: StaticString, line: UInt) {
        waitFor(element(app, "vc.route.experience"), timeout: VC.firstWait, file: file, line: line)
        waitFor(canvas(app), timeout: VC.firstWait, file: file, line: line)
        waitFor(control(app, "level-picker"), timeout: VC.wait, "the level picker is there", file: file, line: line)
        // "contains", not "hasPrefix": a star dragged by a gesture puts "Star n (shape) would start at …" first.
        XCTAssertTrue(waitForLabel(canvas(app)) { $0.contains("Chrono Constellator level") },
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

    /// The stepper `name` (`star-picker` or `level-picker`): the system stepper with the identifier when there is one,
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

    /// Steps the star picker the shorter way round (it wraps) until it shows star `star` of level 1, at most one press
    /// per star. True when it shows the star.
    @MainActor
    @discardableResult
    static func pickStar(_ app: XCUIApplication, _ star: Int, file: StaticString = #filePath, line: UInt = #line)
        -> Bool {
        guard levelOneStarNames.indices.contains(star), ready(app, "star-picker", file: file, line: line) else {
            return false
        }
        let control = stepper(app, "star-picker")
        let count = levelOneStarNames.count
        let target = levelOneStarNames[star]
        var current = control.value as? String ?? ""
        var presses = 0
        while current != target, presses < count {
            let at = levelOneStarNames.firstIndex(of: current) ?? 0
            let forward = ((star - at) % count + count) % count
            current = press(app, "star-picker", up: forward <= count - forward)
            presses += 1
        }
        XCTAssertEqual(current, target, "star-picker shows star \(star + 1) after \(presses) presses", file: file,
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

    /// Plays level 1's certified solution with the panel: for each changed star the star picker is stepped to it and
    /// Phase + or Phase − is pressed the shorter way round its loop (Phase + when (target − current) mod L ≤ L / 2)
    /// until it starts at its certified phase; then Run. True when every control was used and showed what it should.
    @MainActor
    @discardableResult
    static func playLevelOneSolution(_ app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line)
        -> Bool {
        var phases = levelOneDefaultPhases
        for change in levelOnePhaseChanges {
            guard pickStar(app, change.star, file: file, line: line) else { return false }
            let length = levelOneLoopLengths[change.star]
            let forward = ((change.phase - phases[change.star]) % length + length) % length
            let up = forward <= length - forward
            let name = up ? "phase-up" : "phase-down"
            guard let button = shown(app, name, file: file, line: line) else { return false }
            for _ in 0..<min(forward, length - forward) {
                let before = button.value as? String ?? ""
                button.tap()
                phases[change.star] = ((phases[change.star] + (up ? 1 : -1)) % length + length) % length
                XCTAssertTrue(waitForValue(button) { $0 != before }, "\(name) moved the phase (still \(before))",
                              file: file, line: line)
            }
            let expected = "phase \(change.phase) of \(length)"
            XCTAssertEqual(button.value as? String ?? "", expected, "star \(change.star + 1) starts at its certified "
                           + "phase", file: file, line: line)
        }
        let left = "; \(levelOneBudget - levelOneSmallest) edits left."
        XCTAssertTrue(waitForDescription(app) { $0.contains(left) },
                      "the phase changes spent \(levelOneSmallest) edit(s): \(description(app))",
                      file: file, line: line)
        let ticks = "\(levelOneTickLimit) ticks left"
        XCTAssertTrue(waitForValue(control(app, "run")) { $0 == ticks },
                      "Run steps the \(levelOneTickLimit) ticks left (now \(value(app, "run")))",
                      file: file, line: line)
        return tap(app, "run", file: file, line: line)
    }

    /// A fresh start, the tutorial dismissed and level 1 won with its certified solution; returns the app after the
    /// canvas reports every star on its target with all three stars.
    @MainActor
    @discardableResult
    static func winLevelOne(file: StaticString = #filePath, line: UInt = #line) -> XCUIApplication {
        let app = open(arguments: fresh, file: file, line: line)
        XCTAssertTrue(description(app).contains("Chrono Constellator level 1."),
                      "a fresh start opens level 1: \(description(app))", file: file, line: line)
        XCTAssertTrue(description(app).contains("Tick 0 of \(levelOneTickLimit); \(levelOneBudget) edits left."),
                      "level 1 starts at tick 0 with its budget: \(description(app))", file: file, line: line)
        dismissTutorialIfShown(app, file: file, line: line)
        XCTAssertTrue(playLevelOneSolution(app, file: file, line: line), "the solution is played",
                      file: file, line: line)
        XCTAssertTrue(waitForDescription(app, timeout: VC.wait) { $0.contains(won) && $0.contains(threeStars) },
                      "the canvas reports every star on its target with three stars: \(description(app))",
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
    static func waitForLabel(_ target: XCUIElement, timeout: TimeInterval = CR.shortWait,
                             _ condition: (String) -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while !(target.exists && condition(target.label)), Date() < deadline { usleep(200_000) }
        return target.exists && condition(target.label)
    }

    /// Waits until the value of `target` (as text) satisfies `condition`; true when it does.
    @MainActor
    static func waitForValue(_ target: XCUIElement, timeout: TimeInterval = CR.shortWait,
                             _ condition: (String) -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        func current() -> String { target.exists ? (target.value as? String ?? "") : "" }
        while !(target.exists && condition(current())), Date() < deadline { usleep(200_000) }
        return target.exists && condition(current())
    }

    /// Waits until the canvas description satisfies `condition`; true when it does.
    @MainActor
    static func waitForDescription(_ app: XCUIApplication, timeout: TimeInterval = CR.shortWait,
                                   _ condition: (String) -> Bool) -> Bool {
        waitForLabel(canvas(app), timeout: timeout, condition)
    }
}
