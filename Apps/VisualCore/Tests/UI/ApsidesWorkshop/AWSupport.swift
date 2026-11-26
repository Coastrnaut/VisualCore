// AWSupport — feature 479 (R02-G18-09) T-R02G1809-004, modelled on feature 469 (FR-R02G1809-002; SC-R02G1809-001;
// clarifications Q1, Q2): helpers of the interface tests of Apsides Workshop (R02-G18) inside the one app, ported from
// `CELSupport` (feature 469). The namespace is `AW` (no other UI test uses `AW`). Apsides Workshop is a candidate until
// X-R02-G18; every launch carries `-vcCandidates` (DebugLaunch: the candidates' catalog entries become available and
// are registered). A fresh start erases the data (`-vcResetData`, so no level is solved), skips the welcome and opens
// the experience directly with `-openExperience r02-g18.apsides-workshop`; a relaunch (`AW.reopen`) backgrounds the app
// first (its save point, the lesson of feature 309), terminates it and starts again without the reset, so the stored
// progress (solved levels, stars, the frontier, the verified winning trace) survives.
//
// The canvas (`session.canvas`) is labelled with the presenter's description (`ApsidesWorkshopPresenter.describe`):
// "Apsides Workshop level n. ", the progress (`ApsidesWorkshopLevel.progressDescription`, "<orbit>; m of n targets met
// in order; next: …; playing now would win|fail; a actions left") and ". ", the pending preview, and, when won, "Every
// target was met in order without striking a planet." followed by the finished message, then the teaching sentences
// (the mode, the band, the goal, the best stars "Best: s of 3 stars" or "Best: not won yet") and, while the tutorial
// shows, "Tutorial: <instruction>". The controls are found by the identifiers of Clarification Q1
// (`port.identifier(name)`, that is `experience.r02-g18.apsides-workshop.<name>`; `ApsidesWorkshopControls`): the
// header text `actions` ("Level n · a of b actions left"), `status` ("Ready", "Playing", "Won", "Failed: …"),
// `failure`, `progress`, `summary` (labelled "Sky"), `message`; the tutorial's `tutorial` and `dismiss-tutorial`
// ("Dismiss tutorial"); `hint`, `hint-text`, `explanation`, `band`, `stars` ("Best: s of 3 stars", "Best: not won
// yet"), `goal`; the pending orbit rows: `eccentricity-minus` and `eccentricity-plus` ("Eccentricity −",
// "Eccentricity +") around the text `eccentricity` (value "pending eccentricity 0.ee", step k × 0.05),
// `direction-minus` and `direction-plus` ("Direction −", "Direction +", 15° per step, wrapping 0 … 23) around the text
// `direction` (value "pending periapsis at d°"), `size-minus` and `size-plus` around `size` (value "pending size a"),
// each press moving the pending orbit only (presentation, no action spent); `set-periapsis` ("Set periapsis",
// `orbit.periapsis [k, d]` with the pending eccentricity and direction, one action; disabled while nothing is pending),
// `set-size`, `reset-view`; the tick row `tick-minus`, `tick`, `tick-plus`, `play` ("Play", `orbit.play`, ends the
// level and spends no action) and `tick-detail`; `undo`, `redo`, `next-level` (value "level n + 1" or "no further
// level open"); `campaign`, `daily`, `practice` (value "selected" for the current mode, else "not selected"); the
// stepper `level-picker` (labelled "Level to play"; value "Level n, band b" plus ", s of 3 stars" when won; never past
// the open frontier or below 1) and `play-level`; the replay section: `replay` ("Replay best solution", when the level
// has a verified stored solution, not during replay), `replay-position` ("Replay: action k of n"), `replay-step`
// ("Step", value `ApsidesWorkshopControls.replayStepValue`, "Action k of n") and `replay-stop` ("Stop", value "n
// actions" or "1 action", `ApsidesWorkshopControls.replayStopValue`); the toggle `sound`. A level opens with no pending
// orbit (the pending values equal the current orbit; a tuning set clears the pending change). The controls sit below
// the canvas in a scroll view; a control is scrolled into view before it is used, with slow drags near the left edge.
// Everything lives in the namespace `AW`, so that nothing collides with the shared helpers of `AppUITestSupport` or
// the other experiences.
import Foundation
import XCTest

/// Launch arguments, identifiers, level 1's certified plan and helpers of the R02-G18 interface tests.
enum AW {
    /// The experience's id in the catalog.
    static let experienceID = "r02-g18.apsides-workshop"
    /// The prefix of every identifier of the experience's controls.
    static let prefix = "experience.r02-g18.apsides-workshop."
    /// The debug argument that makes the candidates available (DebugLaunch).
    static let candidates = "-vcCandidates"
    /// A first start with erased data, straight into Apsides Workshop.
    static let fresh = [VC.reset, VC.skipWelcome, candidates, VC.openExperience, experienceID]
    /// A start over the same storage (no reset), straight into Apsides Workshop.
    static let relaunch = [VC.skipWelcome, candidates, VC.openExperience, experienceID]
    /// The longest a single check waits (each test stays under 90 s).
    static let shortWait: TimeInterval = 5
    /// The most drags one reveal makes.
    static let maxDrags = 24
    /// The most taps of Set periapsis (or Play) one certified step makes, lost taps included.
    static let maxTaps = 3
    /// The most taps of Eccentricity ± (or Direction ±) that bring the pending value to the wanted one, lost taps
    /// included (level 1 moves the eccentricity by ten steps and the direction by six).
    static let maxChooseTaps = 16

    // Level 1, pinned here so the interface tests need no Core import (read on 2026-11-26 from the stored witness
    // `docs/games/apsides-workshop/levels/001.witness.json`; an app unit test checks them against the Core and level
    // 1's budget): the orbit opens at size 18, eccentricity step 10 (0.50), direction step 6 (90°); budget 9; tutorial
    // on. The witness's actions, encoded `{"periapsis": {"_0": 0, "_1": 0}}` and `{"play": {}}` (the values
    // `orbit.periapsis [k, d]` and `orbit.play` send), are periapsis(0, 0), then the play. The tuning spends one
    // action; moving the pending orbit and the play spend none. The certified win spends one action (three stars) and
    // the stored trace holds the tuning and the play (two actions).

    /// Level 1's starting orbit (size, eccentricity step, direction step).
    static let levelOneStart: (size: Int, eccentricity: Int, direction: Int) = (18, 10, 6)
    /// Level 1's certified periapsis tunings (eccentricity step, direction step), in the order of the witness; the
    /// play follows them.
    static let levelOnePlan: [(eccentricity: Int, direction: Int)] = [(0, 0)]
    /// Level 1's action budget.
    static let levelOneBudget = 9
    /// The number of level 1's certified tunings (each spends an action; the play spends none).
    static var certifiedActionCount: Int { levelOnePlan.count }
    /// The length of the trace stored by the certified win (the tuning and the play).
    static var levelOneTraceLength: Int { levelOnePlan.count + 1 }

    /// The canvas phrase of a fresh level 1's budget (nothing spent).
    static let fullBudget = "; 9 actions left"
    /// The canvas phrase of a won level (`ApsidesWorkshopPresenter.describe`).
    static let won = "Every target was met in order without striking a planet."
    /// The `stars` text (and canvas sentence) of a level won with all three stars.
    static let threeStars = "Best: 3 of 3 stars"
    /// The canvas phrase while the tutorial shows.
    static let tutorial = " Tutorial: "
    /// The level picker's value of level 1 once it is won with three stars (band 1).
    static let levelOneThreeStars = "Level 1, band 1, 3 of 3 stars"

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

    /// The label of the text `name`, or "" when it is not there.
    @MainActor
    static func text(_ app: XCUIApplication, _ name: String) -> String {
        let found = control(app, name)
        return found.exists ? found.label : ""
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

    /// The header line `actions` ("Level n · a of b actions left"), or "" when it is not there.
    @MainActor
    static func actionsText(_ app: XCUIApplication) -> String { text(app, "actions") }

    /// The actions left of a header line "Level n · a of b actions left", or nil.
    static func actionsLeft(_ text: String) -> Int? {
        guard let dot = text.range(of: " · ") else { return nil }
        let digits = text[dot.upperBound...].prefix { $0.isASCII && $0.isNumber }
        guard !digits.isEmpty, text[dot.upperBound...].dropFirst(digits.count).hasPrefix(" of ") else { return nil }
        return Int(digits)
    }

    /// The eccentricity step of a value "pending eccentricity 0.ee" (ee = step × 5, two digits), or nil.
    static func eccentricityStep(_ text: String) -> Int? {
        let marker = "pending eccentricity 0."
        guard text.hasPrefix(marker) else { return nil }
        let digits = text.dropFirst(marker.count).prefix { $0.isASCII && $0.isNumber }
        guard digits.count == 2, let hundredths = Int(digits), hundredths % 5 == 0 else { return nil }
        return hundredths / 5
    }

    /// The direction step of a value "pending periapsis at d°" (d = step × 15), or nil.
    static func directionStep(_ text: String) -> Int? {
        let marker = "pending periapsis at "
        guard text.hasPrefix(marker) else { return nil }
        let digits = text.dropFirst(marker.count).prefix { $0.isASCII && $0.isNumber }
        guard !digits.isEmpty, let degrees = Int(digits), degrees % 15 == 0 else { return nil }
        return degrees / 15
    }

    /// The pending eccentricity step as the `eccentricity` control's value says, or nil.
    @MainActor
    static func pendingEccentricity(_ app: XCUIApplication) -> Int? { eccentricityStep(value(app, "eccentricity")) }

    /// The pending direction step as the `direction` control's value says, or nil.
    @MainActor
    static func pendingDirection(_ app: XCUIApplication) -> Int? { directionStep(value(app, "direction")) }

    /// Launches the app with `arguments` and waits until Apsides Workshop runs.
    @MainActor
    @discardableResult
    static func open(arguments: [String] = AW.fresh, file: StaticString = #filePath, line: UInt = #line)
        -> XCUIApplication {
        let app = launchApp(arguments: arguments)
        waitForRunning(app, file: file, line: line)
        return app
    }

    /// Backgrounds `app` (its save point), ends it and opens Apsides Workshop again over the same storage
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
        let second = launchApp(arguments: AW.relaunch)
        waitForRunning(second, file: file, line: line)
        return second
    }

    /// Waits for the experience route, the canvas labelled with a level and the level picker.
    @MainActor
    private static func waitForRunning(_ app: XCUIApplication, file: StaticString, line: UInt) {
        waitFor(element(app, "vc.route.experience"), timeout: VC.firstWait, file: file, line: line)
        waitFor(canvas(app), timeout: VC.firstWait, file: file, line: line)
        waitFor(control(app, "level-picker"), timeout: VC.wait, "the level picker is there", file: file, line: line)
        XCTAssertTrue(waitForLabel(canvas(app)) { $0.contains("Apsides Workshop level") },
                      "the canvas is labelled with a level: \(description(app))", file: file, line: line)
    }

    /// Taps `dismiss-tutorial` when the tutorial shows it (a fresh start of level 1 does); nothing otherwise. One
    /// dismissal ends the tutorial for this opening.
    @MainActor
    static func dismissTutorialIfShown(_ app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        let dismiss = control(app, "dismiss-tutorial")
        guard dismiss.waitForExistence(timeout: 2) else { return }
        guard reveal(app, dismiss, file: file, line: line) else { return }
        dismiss.tap()
        XCTAssertTrue(waitUntilGone(dismiss, timeout: shortWait), "the tutorial is dismissed", file: file, line: line)
        XCTAssertTrue(waitForDescription(app) { !$0.contains(tutorial) },
                      "the canvas no longer reads the tutorial: \(description(app))", file: file, line: line)
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

    /// The stepper `name` (`level-picker`): the system stepper with the identifier when there is one, else the control
    /// of any type.
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

    /// The level number of a level picker value "Level n, band b[, s of 3 stars]", or nil.
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

    /// Brings a pending step (the eccentricity or the direction) to `wanted` with the `plus` and `minus` buttons
    /// (presentation only, no action spent): `read` gives the pending step from its control's value before each tap,
    /// and a tap counts only when the reading moves; a lost tap is retried, within ``maxChooseTaps`` taps. With
    /// `wraps` (the direction, 0 … 23) the shorter way round is taken. True when the panel shows `wanted` pending.
    @MainActor
    private static func choose(_ app: XCUIApplication, _ what: String, wanted: Int, wraps: Bool,
                               plus plusName: String, minus minusName: String, valueName: String,
                               read: (XCUIApplication) -> Int?, file: StaticString, line: UInt) -> Bool {
        guard var current = read(app) else {
            XCTFail("the pending \(what) cannot be read: '\(value(app, valueName))'", file: file, line: line)
            return false
        }
        guard current != wanted else { return true }
        let budget: Int = actionsLeft(actionsText(app)) ?? -1
        let plus: XCUIElement? = shown(app, plusName, file: file, line: line)
        let minus: XCUIElement? = shown(app, minusName, file: file, line: line)
        guard let plus, let minus else { return false }
        let reading = control(app, valueName)
        var taps = 0
        while current != wanted, taps < maxChooseTaps {
            let before = current
            let up: Bool = wraps ? ((wanted - before + 24) % 24) <= 12 : before < wanted
            let words = reading.value as? String ?? ""
            (up ? plus : minus).tap()
            taps += 1
            // The pending control's value moves with the pending orbit; an unchanged value is a lost tap.
            _ = waitForValue(reading, timeout: shortWait) { $0 != words }
            current = read(app) ?? before
        }
        XCTAssertEqual(current, wanted, "pending \(what) \(wanted) is reached with \(plusName) / \(minusName) in "
                       + "\(taps) taps ('\(value(app, valueName))')", file: file, line: line)
        XCTAssertEqual(actionsLeft(actionsText(app)) ?? -1, budget, "moving the pending \(what) spends no action",
                       file: file, line: line)
        return current == wanted
    }

    /// Brings the pending eccentricity to step `step` with Eccentricity + or Eccentricity −.
    @MainActor
    @discardableResult
    static func chooseEccentricity(_ app: XCUIApplication, _ step: Int,
                                   file: StaticString = #filePath, line: UInt = #line) -> Bool {
        choose(app, "eccentricity", wanted: step, wraps: false, plus: "eccentricity-plus",
               minus: "eccentricity-minus", valueName: "eccentricity", read: { pendingEccentricity($0) },
               file: file, line: line)
    }

    /// Brings the pending periapsis direction to step `step` with Direction + or Direction −.
    @MainActor
    @discardableResult
    static func chooseDirection(_ app: XCUIApplication, _ step: Int,
                                file: StaticString = #filePath, line: UInt = #line) -> Bool {
        choose(app, "direction", wanted: step, wraps: true, plus: "direction-plus", minus: "direction-minus",
               valueName: "direction", read: { pendingDirection($0) }, file: file, line: line)
    }

    /// Plays one pinned periapsis tuning with the panel: the pending eccentricity is moved first, then the pending
    /// direction (each read from its control's value), then Set periapsis is tapped; the header's actions left is read
    /// before and after each tap, and the press counts only when the count moves down by one; a lost tap (the count did
    /// not move) is retried, within ``maxTaps`` taps. True when the tuning was spent exactly once.
    @MainActor
    @discardableResult
    static func setPeriapsis(_ app: XCUIApplication, eccentricity: Int, direction: Int,
                             file: StaticString = #filePath, line: UInt = #line) -> Bool {
        guard chooseEccentricity(app, eccentricity, file: file, line: line) else { return false }
        guard chooseDirection(app, direction, file: file, line: line) else { return false }
        XCTAssertEqual(pendingEccentricity(app), eccentricity,
                       "the pending eccentricity stays \(eccentricity) after the direction moved",
                       file: file, line: line)
        guard let target = shown(app, "set-periapsis", file: file, line: line) else { return false }
        guard let before = actionsLeft(actionsText(app)) else {
            XCTFail("the actions line cannot be read: \(actionsText(app))", file: file, line: line)
            return false
        }
        let header = control(app, "actions")
        var taps = 0
        var after = before
        while after == before, taps < maxTaps {
            target.tap()
            taps += 1
            _ = waitForLabel(header, timeout: shortWait) { actionsLeft($0) != before }
            after = actionsLeft(actionsText(app)) ?? before
        }
        let spent = after == before - 1
        XCTAssertTrue(spent, "Set periapsis to eccentricity \(eccentricity), direction \(direction) spends one action: "
                      + "\(before) → \(after) in \(taps) taps (\(actionsText(app)))", file: file, line: line)
        XCTAssertTrue(waitForValue(control(app, "eccentricity")) { eccentricityStep($0) == eccentricity },
                      "the orbit now has eccentricity step \(eccentricity): \(value(app, "eccentricity"))",
                      file: file, line: line)
        XCTAssertTrue(waitForValue(control(app, "direction")) { directionStep($0) == direction },
                      "the orbit now has direction step \(direction): \(value(app, "direction"))",
                      file: file, line: line)
        return spent
    }

    /// Taps Play (`orbit.play`, no action spent) until the `status` text reports the level ended ("Won" or
    /// "Failed: …"), within ``maxTaps`` taps (a tap counts only when the status moves). True when the canvas then
    /// reports the win.
    @MainActor
    @discardableResult
    static func play(_ app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) -> Bool {
        guard let target = shown(app, "play", file: file, line: line) else { return false }
        let budget: Int = actionsLeft(actionsText(app)) ?? -1
        let status = control(app, "status")
        var taps = 0
        var ended = false
        while !ended, taps < maxTaps {
            target.tap()
            taps += 1
            ended = waitForLabel(status, timeout: shortWait) { $0 == "Won" || $0.hasPrefix("Failed") }
        }
        XCTAssertTrue(ended, "Play ends the level in \(taps) taps (status \(text(app, "status")))", file: file,
                      line: line)
        XCTAssertEqual(actionsLeft(actionsText(app)) ?? -1, budget, "the play spends no action", file: file,
                       line: line)
        return waitForDescription(app, timeout: VC.wait) { $0.contains(won) }
    }

    /// Plays level 1's certified plan (``levelOnePlan``, then the play) with the panel, in order. True when every
    /// tuning was spent exactly once and the play won.
    @MainActor
    @discardableResult
    static func playLevelOneSolution(_ app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line)
        -> Bool {
        for tuning in levelOnePlan {
            guard setPeriapsis(app, eccentricity: tuning.eccentricity, direction: tuning.direction,
                               file: file, line: line) else { return false }
        }
        return play(app, file: file, line: line)
    }

    /// A fresh start, the tutorial dismissed and level 1 won with its certified plan; returns the app after the canvas
    /// reports every target met in order and the `stars` text reads three stars.
    @MainActor
    @discardableResult
    static func winLevelOne(file: StaticString = #filePath, line: UInt = #line) -> XCUIApplication {
        let app = open(arguments: fresh, file: file, line: line)
        XCTAssertTrue(description(app).contains("Apsides Workshop level 1."),
                      "a fresh start opens level 1: \(description(app))", file: file, line: line)
        XCTAssertTrue(!description(app).contains(won) && description(app).contains(fullBudget),
                      "level 1 starts not won and with its budget whole: \(description(app))",
                      file: file, line: line)
        XCTAssertEqual(actionsText(app), "Level 1 · \(levelOneBudget) of \(levelOneBudget) actions left",
                       "the header shows level 1's whole budget", file: file, line: line)
        XCTAssertEqual(pendingEccentricity(app), levelOneStart.eccentricity,
                       "level 1 opens at eccentricity step \(levelOneStart.eccentricity): "
                       + value(app, "eccentricity"),
                       file: file, line: line)
        XCTAssertEqual(pendingDirection(app), levelOneStart.direction,
                       "level 1 opens at direction step \(levelOneStart.direction): \(value(app, "direction"))",
                       file: file, line: line)
        XCTAssertEqual(value(app, "size"), "pending size \(levelOneStart.size)",
                       "level 1 opens at size \(levelOneStart.size)", file: file, line: line)
        XCTAssertTrue(description(app).contains(tutorial), "level 1 shows the tutorial: \(description(app))",
                      file: file, line: line)
        dismissTutorialIfShown(app, file: file, line: line)
        XCTAssertTrue(playLevelOneSolution(app, file: file, line: line), "the solution is played",
                      file: file, line: line)
        XCTAssertTrue(waitForDescription(app, timeout: VC.wait) { $0.contains(won) },
                      "the canvas reports every target met in order: \(description(app))", file: file, line: line)
        XCTAssertTrue(waitForLabel(control(app, "stars")) { $0 == threeStars },
                      "the stars text reads three stars: \(text(app, "stars"))", file: file, line: line)
        XCTAssertEqual(actionsLeft(actionsText(app)), levelOneBudget - certifiedActionCount,
                       "the certified win spends its \(certifiedActionCount) action", file: file, line: line)
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
    static func waitForLabel(_ target: XCUIElement, timeout: TimeInterval = AW.shortWait,
                             _ condition: (String) -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while !(target.exists && condition(target.label)), Date() < deadline { usleep(200_000) }
        return target.exists && condition(target.label)
    }

    /// Waits until the value of `target` (as text) satisfies `condition`; true when it does.
    @MainActor
    static func waitForValue(_ target: XCUIElement, timeout: TimeInterval = AW.shortWait,
                             _ condition: (String) -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        func current() -> String { target.exists ? (target.value as? String ?? "") : "" }
        while !(target.exists && condition(current())), Date() < deadline { usleep(200_000) }
        return target.exists && condition(current())
    }

    /// Waits until the canvas description satisfies `condition`; true when it does.
    @MainActor
    static func waitForDescription(_ app: XCUIApplication, timeout: TimeInterval = AW.shortWait,
                                   _ condition: (String) -> Bool) -> Bool {
        waitForLabel(canvas(app), timeout: timeout, condition)
    }
}
