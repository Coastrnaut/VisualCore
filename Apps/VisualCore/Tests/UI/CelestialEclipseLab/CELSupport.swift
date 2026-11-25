// CELSupport — feature 469 (R02-G17-09) T-R02G1709-004, modelled on feature 459 (FR-R02G1709-002; SC-R02G1709-001;
// clarifications Q1, Q2): helpers of the interface tests of Celestial Eclipse Lab (R02-G17) inside the one app, ported
// from `SCSupport` (feature 459). The namespace is `CEL` (no other UI test uses `CEL`). Celestial Eclipse Lab stays a
// candidate until X-R02-G17, so every launch carries `-vcCandidates` (DebugLaunch: the candidates' catalog entries
// become available and are registered). A fresh start erases the data (`-vcResetData`, so no level is solved), skips
// the welcome and opens the experience directly with `-openExperience r02-g17.celestial-eclipse-lab`; a relaunch
// (`CEL.reopen`) backgrounds the app first (its save point, the lesson of feature 309), terminates it and starts again
// without the reset, so the stored progress (solved levels, stars, the frontier, the verified winning trace) survives.
//
// The canvas (`session.canvas`) is labelled with the presenter's description (`CelestialEclipseLabPresenter.describe`):
// "Celestial Eclipse Lab level n. ", the progress (`CelestialEclipseLabLevel.progressDescription`, "m of n eclipses in
// order; next: …; a run now would win|fail; a actions left") and ". ", the pending preview, and, when won, "Every
// target eclipse came in order inside its window." followed by the finished message, then the teaching sentences (the
// mode, the band, the goal, the best stars "Best: s of 3 stars" or "Best: not won yet") and, while the tutorial shows,
// "Tutorial: <instruction>". The controls are found by the identifiers of Clarification Q1 (`port.identifier(name)`,
// that is `experience.r02-g17.celestial-eclipse-lab.<name>`; `CelestialEclipseLabControls`): the header text
// `actions` ("Level n · a of b actions left"), `status`, `failure`, `progress`, `summary` (labelled "Sky"), `message`;
// the tutorial's `tutorial` and `dismiss-tutorial` ("Dismiss tutorial"); `hint`, `hint-text`, `explanation`, `band`,
// `stars` ("Best: s of 3 stars", "Best: not won yet"), `goal`; the planet row: `planet-minus` and `planet-plus`
// ("Planet −", "Planet +"; `orbit.choose [body]`, the previous or next movable body, wrapping, presentation only, no
// action spent) around the text `planet` (labelled "Chosen planet", value "body j, phase p of q" or "body j, fixed"),
// and `planet-detail`; the phase row: `phase-minus`, `phase-plus` ("Phase −", "Phase +"; the chosen planet's pending
// phase moved by one modulo its period, presentation only, no action spent; their value is the phase line "phase P" or
// "phase P → Q"), the text `phase` (labelled "Pending phase", value "pending phase p"), `set-phase` ("Set phase",
// `orbit.phase [body, pending]`, one action; disabled while the pending phase equals the current one) and
// `reset-view`; the tick row `tick-minus`, `tick`, `tick-plus`, `run` ("Run", `clock.run`, ends the level and spends no
// action) and `tick-detail`; `undo`, `redo`, `next-level` (value "level n + 1" or "no further level open");
// `campaign`, `daily`, `practice` (value "selected" for the current mode, else "not selected"); the stepper
// `level-picker` (labelled "Level to play"; value "Level n, band b" plus ", s of 3 stars" when won; never past the open
// frontier or below 1) and `play-level`; the replay section: `replay` ("Replay best solution", when the level has a
// verified stored solution, not during replay), `replay-position` ("Replay: action k of n"), `replay-step` ("Step",
// value `CelestialEclipseLabControls.replayStepValue`, "Action k of n") and `replay-stop` ("Stop", value "n actions",
// or "1 action", `CelestialEclipseLabControls.replayStopValue`); the toggle `sound`. A level opens with the
// lowest-numbered movable body chosen and no pending phase (a new play, or a phase set, clears the pending phase). The
// controls sit below the canvas in a scroll view; a control is scrolled into view before it is used, with slow drags
// near the left edge. Everything lives in the namespace `CEL`, so that nothing collides with the shared helpers of
// `AppUITestSupport` or the other experiences.
import Foundation
import XCTest

/// Launch arguments, identifiers, level 1's certified plan and helpers of the R02-G17 interface tests.
enum CEL {
    /// The experience's id in the catalog.
    static let experienceID = "r02-g17.celestial-eclipse-lab"
    /// The prefix of every identifier of the experience's controls.
    static let prefix = "experience.r02-g17.celestial-eclipse-lab."
    /// The debug argument that makes the candidates available (DebugLaunch).
    static let candidates = "-vcCandidates"
    /// A first start with erased data, straight into Celestial Eclipse Lab.
    static let fresh = [VC.reset, VC.skipWelcome, candidates, VC.openExperience, experienceID]
    /// A start over the same storage (no reset), straight into Celestial Eclipse Lab.
    static let relaunch = [VC.skipWelcome, candidates, VC.openExperience, experienceID]
    /// The longest a single check waits (each test stays under 90 s).
    static let shortWait: TimeInterval = 5
    /// The most drags one reveal makes.
    static let maxDrags = 24
    /// The most taps of Set phase (or Run) one certified step makes, lost taps included.
    static let maxTaps = 3
    /// The most taps of Planet + / Planet − (or Phase + / Phase −) that bring the chosen planet (or the pending phase)
    /// to the wanted one, lost taps included (level 1 has two movable bodies; the longest period is 8).
    static let maxChooseTaps = 12

    // Level 1, pinned here so the interface tests need no Core import (read on 2026-11-25 from the stored witness
    // `docs/games/celestial-eclipse-lab/levels/001.witness.json`; an app unit test checks them against the Core and
    // level 1's budget): three bodies, body 0 fixed (period 7), body 1 movable (period 8, phase 3), body 2 movable
    // (period 4, phase 2); budget 9; tutorial on (levels 1 … 3). The witness's actions, encoded
    // `{"phase": {"_0": 1, "_1": 2}}`, `{"phase": {"_0": 2, "_1": 0}}` and `{"run": {}}` (the values
    // `orbit.phase [body, offset]` and `clock.run` send), are phase(1, 2), phase(2, 0), then the run. Each phase change
    // spends one action; choosing a planet, moving the pending phase and the run spend none. The certified win spends
    // two actions (three stars) and the stored trace holds the two phase changes and the run (three actions).

    /// Level 1's certified phase changes (body, target phase), in the order of the witness; the run follows them.
    static let levelOnePlan: [(body: Int, phase: Int)] = [(1, 2), (2, 0)]
    /// Level 1's action budget.
    static let levelOneBudget = 9
    /// The number of level 1's certified phase changes (each spends an action; the run spends none).
    static var certifiedActionCount: Int { levelOnePlan.count }
    /// The length of the trace stored by the certified win (the two phase changes and the run).
    static var levelOneTraceLength: Int { levelOnePlan.count + 1 }

    /// The canvas phrase of a fresh level 1's budget (nothing spent).
    static let fullBudget = "; 9 actions left"
    /// The canvas phrase of a won level (`CelestialEclipseLabPresenter.describe`).
    static let won = "Every target eclipse came in order inside its window."
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

    /// The body of a planet value "body j, phase p of q" or "body j, fixed": the number right after the leading
    /// "body ", or nil.
    static func body(_ text: String) -> Int? {
        guard text.hasPrefix("body ") else { return nil }
        let digits = text.dropFirst("body ".count).prefix { $0.isASCII && $0.isNumber }
        return digits.isEmpty ? nil : Int(digits)
    }

    /// The current phase of a planet value "body j, phase p of q": the number after ", phase ", or nil (a fixed body).
    static func currentPhase(_ text: String) -> Int? {
        guard let marker = text.range(of: ", phase ") else { return nil }
        let digits = text[marker.upperBound...].prefix { $0.isASCII && $0.isNumber }
        return digits.isEmpty ? nil : Int(digits)
    }

    /// The pending phase of a phase value "pending phase p": the number after "pending phase ", or nil.
    static func pending(_ text: String) -> Int? {
        guard text.hasPrefix("pending phase ") else { return nil }
        let digits = text.dropFirst("pending phase ".count).prefix { $0.isASCII && $0.isNumber }
        return digits.isEmpty ? nil : Int(digits)
    }

    /// The chosen body as the planet control's value says, or nil.
    @MainActor
    static func chosenBody(_ app: XCUIApplication) -> Int? { body(value(app, "planet")) }

    /// The chosen body's current phase as the planet control's value says, or nil.
    @MainActor
    static func chosenPhase(_ app: XCUIApplication) -> Int? { currentPhase(value(app, "planet")) }

    /// The pending phase as the phase control's value says, or nil.
    @MainActor
    static func pendingPhase(_ app: XCUIApplication) -> Int? { pending(value(app, "phase")) }

    /// Launches the app with `arguments` and waits until Celestial Eclipse Lab runs.
    @MainActor
    @discardableResult
    static func open(arguments: [String] = CEL.fresh, file: StaticString = #filePath, line: UInt = #line)
        -> XCUIApplication {
        let app = launchApp(arguments: arguments)
        waitForRunning(app, file: file, line: line)
        return app
    }

    /// Backgrounds `app` (its save point), ends it and opens Celestial Eclipse Lab again over the same storage
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
        let second = launchApp(arguments: CEL.relaunch)
        waitForRunning(second, file: file, line: line)
        return second
    }

    /// Waits for the experience route, the canvas labelled with a level and the level picker.
    @MainActor
    private static func waitForRunning(_ app: XCUIApplication, file: StaticString, line: UInt) {
        waitFor(element(app, "vc.route.experience"), timeout: VC.firstWait, file: file, line: line)
        waitFor(canvas(app), timeout: VC.firstWait, file: file, line: line)
        waitFor(control(app, "level-picker"), timeout: VC.wait, "the level picker is there", file: file, line: line)
        XCTAssertTrue(waitForLabel(canvas(app)) { $0.contains("Celestial Eclipse Lab level") },
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

    /// Brings a chosen number (the chosen body or the pending phase) to `wanted` with the `plus` and `minus` buttons
    /// (presentation only, no action spent): `read` gives the current choice before each tap, and a tap counts only
    /// when the reading moves; a lost tap is retried, within ``maxChooseTaps`` taps. Planet + and Planet − skip fixed
    /// bodies (and wrap), so a step can move by more than one; the loop only compares with `wanted`. True when the
    /// panel shows `wanted` chosen.
    @MainActor
    private static func choose(_ app: XCUIApplication, _ what: String, wanted: Int, plus plusName: String,
                               minus minusName: String, read: (XCUIApplication) -> Int?,
                               file: StaticString, line: UInt) -> Bool {
        guard var current = read(app) else {
            XCTFail("the chosen \(what) cannot be read: '\(value(app, "planet"))' / '\(value(app, "phase"))'",
                    file: file, line: line)
            return false
        }
        guard current != wanted else { return true }
        let budget: Int = actionsLeft(actionsText(app)) ?? -1
        let plus: XCUIElement? = shown(app, plusName, file: file, line: line)
        let minus: XCUIElement? = shown(app, minusName, file: file, line: line)
        guard let plus, let minus else { return false }
        var taps = 0
        while current != wanted, taps < maxChooseTaps {
            let before = current
            (before < wanted ? plus : minus).tap()
            taps += 1
            // Both buttons of a row carry the row's words as their value (Planet ± the body line, Phase ± the phase
            // line), so the tapped button's value moves with the choice.
            let words = plus.value as? String ?? ""
            _ = waitForValue(plus, timeout: shortWait) { $0 != words }
            current = read(app) ?? before
        }
        XCTAssertEqual(current, wanted, "\(what) \(wanted) is chosen with \(plusName) / \(minusName) in \(taps) taps "
                       + "('\(value(app, "planet"))', '\(value(app, "phase"))')", file: file, line: line)
        XCTAssertEqual(actionsLeft(actionsText(app)) ?? -1, budget, "choosing a \(what) spends no action",
                       file: file, line: line)
        return current == wanted
    }

    /// Brings the chosen planet to `body` with Planet + or Planet −.
    @MainActor
    @discardableResult
    static func chooseBody(_ app: XCUIApplication, _ body: Int,
                           file: StaticString = #filePath, line: UInt = #line) -> Bool {
        choose(app, "planet", wanted: body, plus: "planet-plus", minus: "planet-minus",
               read: { chosenBody($0) }, file: file, line: line)
    }

    /// Brings the chosen planet's pending phase to `phase` with Phase + or Phase −.
    @MainActor
    @discardableResult
    static func choosePending(_ app: XCUIApplication, _ phase: Int,
                              file: StaticString = #filePath, line: UInt = #line) -> Bool {
        choose(app, "pending phase", wanted: phase, plus: "phase-plus", minus: "phase-minus",
               read: { pendingPhase($0) }, file: file, line: line)
    }

    /// Plays one pinned phase change with the panel: the body is chosen first, then its pending phase (each read from
    /// its control's value), then Set phase is tapped; the header's actions left is read before and after each tap, and
    /// the press counts only when the count moves down by one; a lost tap (the count did not move) is retried, within
    /// ``maxTaps`` taps. True when the change was spent exactly once and the planet then reads the new phase.
    @MainActor
    @discardableResult
    static func setPhase(_ app: XCUIApplication, body: Int, phase: Int,
                         file: StaticString = #filePath, line: UInt = #line) -> Bool {
        guard chooseBody(app, body, file: file, line: line) else { return false }
        guard choosePending(app, phase, file: file, line: line) else { return false }
        XCTAssertEqual(chosenBody(app), body, "the chosen planet stays body \(body) after the pending phase moved",
                       file: file, line: line)
        guard let target = shown(app, "set-phase", file: file, line: line) else { return false }
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
        XCTAssertTrue(spent, "Set phase of body \(body) to \(phase) spends one action: \(before) → \(after) in "
                      + "\(taps) taps (\(actionsText(app)))", file: file, line: line)
        XCTAssertTrue(waitForValue(control(app, "planet")) { currentPhase($0) == phase },
                      "body \(body) now has phase \(phase): \(value(app, "planet"))", file: file, line: line)
        return spent
    }

    /// Taps Run (`clock.run`, no action spent) until the `status` text reports the level ended ("Won" or "Failed: …"),
    /// within ``maxTaps`` taps (a tap counts only when the status moves). True when the canvas then reports the win.
    @MainActor
    @discardableResult
    static func run(_ app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) -> Bool {
        guard let target = shown(app, "run", file: file, line: line) else { return false }
        let budget: Int = actionsLeft(actionsText(app)) ?? -1
        let status = control(app, "status")
        var taps = 0
        var ended = false
        while !ended, taps < maxTaps {
            target.tap()
            taps += 1
            ended = waitForLabel(status, timeout: shortWait) { $0 == "Won" || $0.hasPrefix("Failed") }
        }
        XCTAssertTrue(ended, "Run ends the level in \(taps) taps (status \(text(app, "status")))", file: file,
                      line: line)
        XCTAssertEqual(actionsLeft(actionsText(app)) ?? -1, budget, "the run spends no action", file: file,
                       line: line)
        return waitForDescription(app, timeout: VC.wait) { $0.contains(won) }
    }

    /// Plays level 1's certified plan (``levelOnePlan``, then the run) with the panel, in order. True when every
    /// phase change was spent exactly once and the run won.
    @MainActor
    @discardableResult
    static func playLevelOneSolution(_ app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line)
        -> Bool {
        for change in levelOnePlan {
            guard setPhase(app, body: change.body, phase: change.phase, file: file, line: line) else { return false }
        }
        return run(app, file: file, line: line)
    }

    /// A fresh start, the tutorial dismissed and level 1 won with its certified plan; returns the app after the canvas
    /// reports every target eclipse in order and the `stars` text reads three stars.
    @MainActor
    @discardableResult
    static func winLevelOne(file: StaticString = #filePath, line: UInt = #line) -> XCUIApplication {
        let app = open(arguments: fresh, file: file, line: line)
        XCTAssertTrue(description(app).contains("Celestial Eclipse Lab level 1."),
                      "a fresh start opens level 1: \(description(app))", file: file, line: line)
        XCTAssertTrue(!description(app).contains(won) && description(app).contains(fullBudget),
                      "level 1 starts not won and with its budget whole: \(description(app))",
                      file: file, line: line)
        XCTAssertEqual(actionsText(app), "Level 1 · \(levelOneBudget) of \(levelOneBudget) actions left",
                       "the header shows level 1's whole budget", file: file, line: line)
        XCTAssertTrue(description(app).contains(tutorial), "level 1 shows the tutorial: \(description(app))",
                      file: file, line: line)
        dismissTutorialIfShown(app, file: file, line: line)
        XCTAssertTrue(playLevelOneSolution(app, file: file, line: line), "the solution is played",
                      file: file, line: line)
        XCTAssertTrue(waitForDescription(app, timeout: VC.wait) { $0.contains(won) },
                      "the canvas reports every target eclipse in order: \(description(app))", file: file, line: line)
        XCTAssertTrue(waitForLabel(control(app, "stars")) { $0 == threeStars },
                      "the stars text reads three stars: \(text(app, "stars"))", file: file, line: line)
        XCTAssertEqual(actionsLeft(actionsText(app)), levelOneBudget - certifiedActionCount,
                       "the certified win spends its \(certifiedActionCount) actions", file: file, line: line)
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
    static func waitForLabel(_ target: XCUIElement, timeout: TimeInterval = CEL.shortWait,
                             _ condition: (String) -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while !(target.exists && condition(target.label)), Date() < deadline { usleep(200_000) }
        return target.exists && condition(target.label)
    }

    /// Waits until the value of `target` (as text) satisfies `condition`; true when it does.
    @MainActor
    static func waitForValue(_ target: XCUIElement, timeout: TimeInterval = CEL.shortWait,
                             _ condition: (String) -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        func current() -> String { target.exists ? (target.value as? String ?? "") : "" }
        while !(target.exists && condition(current())), Date() < deadline { usleep(200_000) }
        return target.exists && condition(current())
    }

    /// Waits until the canvas description satisfies `condition`; true when it does.
    @MainActor
    static func waitForDescription(_ app: XCUIApplication, timeout: TimeInterval = CEL.shortWait,
                                   _ condition: (String) -> Bool) -> Bool {
        waitForLabel(canvas(app), timeout: timeout, condition)
    }
}
