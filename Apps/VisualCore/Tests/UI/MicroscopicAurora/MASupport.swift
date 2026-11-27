// MASupport — feature 489 (R02-G19-09) T-R02G1909-004, modelled on feature 479 (FR-R02G1909-002, 007; SC-R02G1909-001;
// clarifications Q1, Q2; research R2): helpers of the interface tests of Microscopic Aurora (R02-G19) inside the one
// app, ported from `AWSupport` (feature 479). The namespace is `MA` (no other UI test uses `MA`). Microscopic Aurora is
// a candidate; every launch carries `-vcCandidates` (DebugLaunch: the candidates' catalog entries become available and
// are registered). A fresh start erases the data (`-vcResetData`, so no level is solved), skips the welcome and opens
// the experience directly with `-openExperience r02-g19.microscopic-aurora`; a relaunch (`MA.reopen`) backgrounds the
// app first (its save point, the lesson of feature 309), terminates it and starts again without the reset, so the
// stored progress (solved levels, stars, the frontier, the verified winning trace) survives.
//
// The canvas (`session.canvas`) is labelled with the presenter's description (`MicroscopicAuroraPresenter.describe`):
// "Microscopic Aurora level n. ", the progress (`MicroscopicAuroraLevel.progressDescription`, "<wells>; <coverage>;
// playing now would win|fail…; a actions left") and ". ", then, when won, "The trails covered the stencil as one
// pattern.", then the teaching sentences (the mode, the band, the goal, the best stars "Best: s of 3 stars" or "Best:
// not won yet") and, while the tutorial shows, "Tutorial: <instruction>". The controls are found by the identifiers of
// Clarification Q1 (`port.identifier(name)`, that is `experience.r02-g19.microscopic-aurora.<name>`;
// `MicroscopicAuroraControls`): the header text `actions` ("Level n · a of b actions left"), `status` ("Ready",
// "Playing", "Won", "Failed: …"), `failure`, `progress`, `summary` (labelled "Dish"), `message`; the tutorial's
// `tutorial` and `dismiss-tutorial` ("Dismiss tutorial", one dismissal ends the tutorial); `hint`, `hint-text`,
// `explanation`, `band`, `stars`, `goal`; the selection rows: `slot-minus` and `slot-plus` ("Well −", "Well +",
// wrapping over the three slots) around the text `slot` (value "well k", k = slot + 1), `site-minus` and `site-plus`
// ("Site −", "Site +", wrapping over the level's sites in the level's order) around the text `site` (value "site at row
// r, column c", `MicroscopicAuroraLevel.cellWords`), `strength-minus` and `strength-plus` (clamped to 1 … 4) around the
// text `strength` (value "strength s"), and the sense toggle `sense` (title "Clockwise" or "Counterclockwise",
// accessibility label "Switch the turning sense", value "clockwise" or "counterclockwise"); every selection change is
// presentation only (no action spent); `place` ("Place", `well.place [slot, row, column, strength, sense]`, one
// action), `remove`, `selection`; the tick row `tick-minus`, `tick`, `tick-plus`, `play` ("Play", `swim.play`, ends
// the level and spends no action) and `tick-detail`; `undo`, `redo`, `next-level` (value "level n + 1" or "no further
// level open"); `freeze`, `reset-view`; `campaign`, `daily`, `practice` (value "selected" or "not selected"); the
// stepper `level-picker` (labelled "Level to play"; value "Level n, band b" plus ", s of 3 stars" when won; never past
// the open frontier or below 1) and `play-level`; the replay section: `replay` ("Replay best solution"),
// `replay-position` ("Replay: action k of n"), `replay-step` ("Step", value "Action k of n") and `replay-stop`
// ("Stop", value "n actions" or "1 action"); the toggle `sound`. A level opens with slot 0 (well 1), the level's first
// site, strength 2 and counterclockwise selected. The controls sit below the canvas in a scroll view; a control is
// scrolled into view before it is used, with slow drags near the left edge. Everything lives in the namespace `MA`, so
// that nothing collides with the shared helpers of `AppUITestSupport` or the other experiences.
import Foundation
import XCTest

/// Launch arguments, identifiers, level 1's certified wells and helpers of the R02-G19 interface tests.
enum MA {
    /// One certified well of level 1, as the panel selects it: the slot (0 … 2), the site (row, column), the strength
    /// (1 … 4) and the sense.
    struct Well: Equatable {
        /// The slot, 0 … 2 (the panel shows "well slot + 1").
        let slot: Int
        /// The site's row.
        let row: Int
        /// The site's column.
        let column: Int
        /// The strength, 1 … 4.
        let strength: Int
        /// Whether the well turns counterclockwise.
        let counterclockwise: Bool

        /// The `site` control's value naming this well's site ("site at row r, column c").
        var siteValue: String { MA.siteValue(row: row, column: column) }
        /// The `sense` control's value of this well ("clockwise" or "counterclockwise").
        var senseValue: String { counterclockwise ? "counterclockwise" : "clockwise" }
    }

    /// The experience's id in the catalog.
    static let experienceID = "r02-g19.microscopic-aurora"
    /// The prefix of every identifier of the experience's controls.
    static let prefix = "experience.r02-g19.microscopic-aurora."
    /// The debug argument that makes the candidates available (DebugLaunch).
    static let candidates = "-vcCandidates"
    /// A first start with erased data, straight into Microscopic Aurora.
    static let fresh = [VC.reset, VC.skipWelcome, candidates, VC.openExperience, experienceID]
    /// A start over the same storage (no reset), straight into Microscopic Aurora.
    static let relaunch = [VC.skipWelcome, candidates, VC.openExperience, experienceID]
    /// The longest a single check waits (each test stays under 90 s).
    static let shortWait: TimeInterval = 5
    /// The most drags one reveal makes.
    static let maxDrags = 24
    /// The most taps of Place (or Play) one certified step makes, lost taps included.
    static let maxTaps = 3
    /// The most taps of a − or + button (or the sense toggle) that bring a selection to the wanted value, lost taps
    /// included (level 1 moves the site by one and toggles the sense once).
    static let maxChooseTaps = 8

    // Level 1, pinned here so the interface tests need no Core import (probed on 2026-11-26 from
    // `MicroscopicAuroraExperienceCore.certifiedActions(1)` and `opening(number: 1)`; an app unit test checks them
    // against the Core): budget 9; tutorial on (step `place`); the level's sites in the panel's order are row 9, column
    // 7; row 11, column 18; row 17, column 8. The panel opens at slot 0, site index 0, strength 2, counterclockwise
    // (`MicroscopicAuroraMirror`). The certified plan is one placement, `place(slot: 0, well: row 11, column 18,
    // strength 2, clockwise)`; the play follows it. A placement spends one action; the selection and the play spend
    // none. The certified win spends one action (three stars) and the stored trace holds the placement and the play
    // (two actions).

    /// Level 1's sites in the order Site − and Site + walk them (`MicroscopicAuroraLevel.sites`).
    static let levelOneSites: [(row: Int, column: Int)] = [(9, 7), (11, 18), (17, 8)]
    /// The selection the panel opens with on level 1: slot 0, the first site, strength 2, counterclockwise.
    static let levelOneOpening = Well(slot: 0, row: 9, column: 7, strength: 2, counterclockwise: true)
    /// Level 1's certified wells in placement order; the play follows them.
    static let levelOnePlan: [Well] = [Well(slot: 0, row: 11, column: 18, strength: 2, counterclockwise: false)]
    /// Level 1's action budget.
    static let levelOneBudget = 9
    /// The number of level 1's certified placements (each spends an action; the play spends none).
    static var certifiedActionCount: Int { levelOnePlan.count }
    /// The length of the trace stored by the certified win (the placements and the play).
    static var levelOneTraceLength: Int { levelOnePlan.count + 1 }

    /// The canvas phrase of a fresh level 1's budget (nothing spent).
    static let fullBudget = "; 9 actions left"
    /// The canvas phrase of a won level (`MicroscopicAuroraPresenter.describe`).
    static let won = "The trails covered the stencil as one pattern."
    /// The `stars` text (and canvas sentence) of a level won with all three stars.
    static let threeStars = "Best: 3 of 3 stars"
    /// The canvas phrase while the tutorial shows.
    static let tutorial = " Tutorial: "
    /// The level picker's value of level 1 once it is won with three stars (band 1).
    static let levelOneThreeStars = "Level 1, band 1, 3 of 3 stars"

    /// The full identifier of the control `name`.
    static func id(_ name: String) -> String { prefix + name }

    /// The `site` control's value of the site at `row`, `column` ("site at " + `MicroscopicAuroraLevel.cellWords`).
    static func siteValue(row: Int, column: Int) -> String { "site at row \(row), column \(column)" }

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

    /// The number after `marker` at the start of `text` (all of the rest must be digits), or nil.
    static func number(after marker: String, in text: String) -> Int? {
        guard text.hasPrefix(marker) else { return nil }
        let rest = text.dropFirst(marker.count)
        guard !rest.isEmpty, rest.allSatisfy({ $0.isASCII && $0.isNumber }) else { return nil }
        return Int(rest)
    }

    /// The slot (0 … 2) of a `slot` value "well k", or nil.
    static func slotIndex(_ text: String) -> Int? { number(after: "well ", in: text).map { $0 - 1 } }

    /// The strength of a `strength` value "strength s", or nil.
    static func strengthValue(_ text: String) -> Int? { number(after: "strength ", in: text) }

    /// The index in ``levelOneSites`` of a `site` value "site at row r, column c", or nil.
    static func siteIndex(_ text: String) -> Int? {
        levelOneSites.firstIndex { siteValue(row: $0.row, column: $0.column) == text }
    }

    /// Launches the app with `arguments` and waits until Microscopic Aurora runs.
    @MainActor
    @discardableResult
    static func open(arguments: [String] = MA.fresh, file: StaticString = #filePath, line: UInt = #line)
        -> XCUIApplication {
        let app = launchApp(arguments: arguments)
        waitForRunning(app, file: file, line: line)
        return app
    }

    /// Backgrounds `app` (its save point), ends it and opens Microscopic Aurora again over the same storage
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
        let second = launchApp(arguments: MA.relaunch)
        waitForRunning(second, file: file, line: line)
        return second
    }

    /// Waits for the experience route, the canvas labelled with a level and the level picker.
    @MainActor
    private static func waitForRunning(_ app: XCUIApplication, file: StaticString, line: UInt) {
        waitFor(element(app, "vc.route.experience"), timeout: VC.firstWait, file: file, line: line)
        waitFor(canvas(app), timeout: VC.firstWait, file: file, line: line)
        waitFor(control(app, "level-picker"), timeout: VC.wait, "the level picker is there", file: file, line: line)
        XCTAssertTrue(waitForLabel(canvas(app)) { $0.contains("Microscopic Aurora level") },
                      "the canvas is labelled with a level: \(description(app))", file: file, line: line)
    }

    /// Taps `dismiss-tutorial` when the tutorial shows it (a fresh start of level 1 does); nothing otherwise. One
    /// dismissal ends the tutorial (`MicroscopicAuroraTutorialStep.dismissed()`); it spends no action.
    @MainActor
    static func dismissTutorialIfShown(_ app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        let dismiss = control(app, "dismiss-tutorial")
        guard dismiss.waitForExistence(timeout: 2) else { return }
        guard reveal(app, dismiss, file: file, line: line) else { return }
        let budget: Int = actionsLeft(actionsText(app)) ?? -1
        dismiss.tap()
        XCTAssertTrue(waitUntilGone(dismiss, timeout: shortWait), "the tutorial is dismissed", file: file, line: line)
        XCTAssertTrue(waitForDescription(app) { !$0.contains(tutorial) },
                      "the canvas no longer reads the tutorial: \(description(app))", file: file, line: line)
        XCTAssertEqual(actionsLeft(actionsText(app)) ?? -1, budget, "dismissing the tutorial spends no action",
                       file: file, line: line)
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

    /// Brings a selection (the slot, the site or the strength) to `wanted` with the `plus` and `minus` buttons
    /// (presentation only, no action spent): `read` gives the selection from its control's value before each tap, and
    /// a tap counts only when the reading moves; a lost tap is retried, within ``maxChooseTaps`` taps. With `wrap` (the
    /// count of the values that wrap round: three slots, the level's sites) the shorter way round is taken. True when
    /// the panel shows `wanted`.
    @MainActor
    private static func choose(_ app: XCUIApplication, _ what: String, wanted: Int, wrap: Int?,
                               plus plusName: String, minus minusName: String, valueName: String,
                               read: (String) -> Int?, file: StaticString, line: UInt) -> Bool {
        let reading = control(app, valueName)
        guard var current = read(value(app, valueName)) else {
            XCTFail("the \(what) cannot be read: '\(value(app, valueName))'", file: file, line: line)
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
            let up: Bool
            if let wrap { up = ((wanted - before + wrap) % wrap) * 2 <= wrap } else { up = before < wanted }
            let words = reading.value as? String ?? ""
            (up ? plus : minus).tap()
            taps += 1
            // The selection's control value moves with the selection; an unchanged value is a lost tap.
            _ = waitForValue(reading, timeout: shortWait) { $0 != words }
            current = read(value(app, valueName)) ?? before
        }
        XCTAssertEqual(current, wanted, "\(what) \(wanted) is reached with \(plusName) / \(minusName) in \(taps) taps "
                       + "('\(value(app, valueName))')", file: file, line: line)
        XCTAssertEqual(actionsLeft(actionsText(app)) ?? -1, budget, "moving the \(what) spends no action",
                       file: file, line: line)
        return current == wanted
    }

    /// Brings the edited slot to `slot` (0 … 2) with Well − or Well + (the `slot` value reads "well slot + 1").
    @MainActor
    @discardableResult
    static func chooseSlot(_ app: XCUIApplication, _ slot: Int, file: StaticString = #filePath, line: UInt = #line)
        -> Bool {
        choose(app, "slot", wanted: slot, wrap: 3, plus: "slot-plus", minus: "slot-minus", valueName: "slot",
               read: slotIndex, file: file, line: line)
    }

    /// Brings the selected site to the one at `row`, `column` (one of ``levelOneSites``) with Site − or Site +.
    @MainActor
    @discardableResult
    static func chooseSite(_ app: XCUIApplication, row: Int, column: Int,
                           file: StaticString = #filePath, line: UInt = #line) -> Bool {
        guard let wanted = levelOneSites.firstIndex(where: { $0.row == row && $0.column == column }) else {
            XCTFail("row \(row), column \(column) is not one of level 1's sites", file: file, line: line)
            return false
        }
        return choose(app, "site", wanted: wanted, wrap: levelOneSites.count, plus: "site-plus", minus: "site-minus",
                      valueName: "site", read: siteIndex, file: file, line: line)
    }

    /// Brings the selected strength to `strength` (1 … 4) with Strength − or Strength +.
    @MainActor
    @discardableResult
    static func chooseStrength(_ app: XCUIApplication, _ strength: Int,
                               file: StaticString = #filePath, line: UInt = #line) -> Bool {
        choose(app, "strength", wanted: strength, wrap: nil, plus: "strength-plus", minus: "strength-minus",
               valueName: "strength", read: strengthValue, file: file, line: line)
    }

    /// Whether the sense toggle names `wanted` ("clockwise" or "counterclockwise"): its value, or its title should a
    /// system ever expose the title as the label. The comparison is exact ("clockwise" is inside "counterclockwise").
    @MainActor
    static func senseIs(_ app: XCUIApplication, _ wanted: String) -> Bool {
        let sense = control(app, "sense")
        guard sense.exists else { return false }
        return (sense.value as? String ?? "").lowercased() == wanted || sense.label.lowercased() == wanted
    }

    /// Toggles the sense until it names `counterclockwise` or clockwise (presentation only, no action spent); a tap
    /// counts only when the value moves, a lost tap is retried within ``maxChooseTaps`` taps. True when it does.
    @MainActor
    @discardableResult
    static func chooseSense(_ app: XCUIApplication, counterclockwise: Bool,
                            file: StaticString = #filePath, line: UInt = #line) -> Bool {
        let wanted = counterclockwise ? "counterclockwise" : "clockwise"
        guard !senseIs(app, wanted) else { return true }
        guard let toggle = shown(app, "sense", file: file, line: line) else { return false }
        let budget: Int = actionsLeft(actionsText(app)) ?? -1
        var taps = 0
        while !senseIs(app, wanted), taps < maxChooseTaps {
            let words = toggle.value as? String ?? ""
            toggle.tap()
            taps += 1
            _ = waitForValue(toggle, timeout: shortWait) { $0 != words }
        }
        let reached = senseIs(app, wanted)
        XCTAssertTrue(reached, "the sense reads \(wanted) after \(taps) taps ('\(value(app, "sense"))')",
                      file: file, line: line)
        XCTAssertEqual(actionsLeft(actionsText(app)) ?? -1, budget, "toggling the sense spends no action",
                       file: file, line: line)
        return reached
    }

    /// Places one pinned well with the panel: the slot, the site, the strength and the sense are selected (each read
    /// from its control's value), then Place is tapped; the header's `actions` text is read before and after each tap,
    /// and the press counts only when the text changes, with the actions left down by one; a lost tap (the text did
    /// not change) is retried, within ``maxTaps`` taps. True when the placement was spent exactly once.
    @MainActor
    @discardableResult
    static func place(_ app: XCUIApplication, _ well: Well, file: StaticString = #filePath, line: UInt = #line)
        -> Bool {
        guard chooseSlot(app, well.slot, file: file, line: line),
              chooseSite(app, row: well.row, column: well.column, file: file, line: line),
              chooseStrength(app, well.strength, file: file, line: line),
              chooseSense(app, counterclockwise: well.counterclockwise, file: file, line: line) else { return false }
        // The selection is read back whole before the action is spent: no later choice moved an earlier one.
        XCTAssertEqual(value(app, "slot"), "well \(well.slot + 1)", "the slot stays selected", file: file, line: line)
        XCTAssertEqual(value(app, "site"), well.siteValue, "the site stays selected", file: file, line: line)
        XCTAssertEqual(value(app, "strength"), "strength \(well.strength)", "the strength stays selected",
                       file: file, line: line)
        guard let target = shown(app, "place", file: file, line: line) else { return false }
        let header = control(app, "actions")
        let beforeText = actionsText(app)
        guard let before = actionsLeft(beforeText) else {
            XCTFail("the actions line cannot be read: \(beforeText)", file: file, line: line)
            return false
        }
        var taps = 0
        var afterText = beforeText
        while afterText == beforeText, taps < maxTaps {
            target.tap()
            taps += 1
            _ = waitForLabel(header, timeout: shortWait) { $0 != beforeText }
            afterText = actionsText(app)
        }
        let after = actionsLeft(afterText) ?? before
        let spent = after == before - 1
        XCTAssertTrue(spent, "Place well \(well.slot + 1) at \(well.siteValue), strength \(well.strength), "
                      + "\(well.senseValue) spends one action: \(before) → \(after) in \(taps) taps (\(afterText)); "
                      + "message '\(text(app, "message"))'", file: file, line: line)
        return spent
    }

    /// Taps Play (`swim.play`, no action spent) until the `status` text reports the level ended ("Won" or
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

    /// Plays level 1's certified wells (``levelOnePlan``, then the play) with the panel, in order. True when every
    /// placement was spent exactly once and the play won.
    @MainActor
    @discardableResult
    static func playLevelOneSolution(_ app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line)
        -> Bool {
        for well in levelOnePlan {
            guard place(app, well, file: file, line: line) else { return false }
        }
        return play(app, file: file, line: line)
    }

    /// A fresh start, the tutorial dismissed and level 1 won with its certified wells; returns the app after the canvas
    /// reports the stencil covered and the `stars` text reads three stars.
    @MainActor
    @discardableResult
    static func winLevelOne(file: StaticString = #filePath, line: UInt = #line) -> XCUIApplication {
        let app = open(arguments: fresh, file: file, line: line)
        XCTAssertTrue(description(app).contains("Microscopic Aurora level 1."),
                      "a fresh start opens level 1: \(description(app))", file: file, line: line)
        XCTAssertTrue(!description(app).contains(won) && description(app).contains(fullBudget),
                      "level 1 starts not won and with its budget whole: \(description(app))",
                      file: file, line: line)
        XCTAssertEqual(actionsText(app), "Level 1 · \(levelOneBudget) of \(levelOneBudget) actions left",
                       "the header shows level 1's whole budget", file: file, line: line)
        let opening = levelOneOpening
        XCTAssertEqual(value(app, "slot"), "well \(opening.slot + 1)", "level 1 opens on well 1", file: file,
                       line: line)
        XCTAssertEqual(value(app, "site"), opening.siteValue, "level 1 opens on its first site", file: file,
                       line: line)
        XCTAssertEqual(value(app, "strength"), "strength \(opening.strength)", "level 1 opens at strength 2",
                       file: file, line: line)
        XCTAssertTrue(senseIs(app, opening.senseValue), "level 1 opens \(opening.senseValue): \(value(app, "sense"))",
                      file: file, line: line)
        XCTAssertTrue(description(app).contains(tutorial), "level 1 shows the tutorial: \(description(app))",
                      file: file, line: line)
        dismissTutorialIfShown(app, file: file, line: line)
        XCTAssertTrue(playLevelOneSolution(app, file: file, line: line), "the solution is played",
                      file: file, line: line)
        XCTAssertTrue(waitForDescription(app, timeout: VC.wait) { $0.contains(won) },
                      "the canvas reports the stencil covered: \(description(app))", file: file, line: line)
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
    static func waitForLabel(_ target: XCUIElement, timeout: TimeInterval = MA.shortWait,
                             _ condition: (String) -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while !(target.exists && condition(target.label)), Date() < deadline { usleep(200_000) }
        return target.exists && condition(target.label)
    }

    /// Waits until the value of `target` (as text) satisfies `condition`; true when it does.
    @MainActor
    static func waitForValue(_ target: XCUIElement, timeout: TimeInterval = MA.shortWait,
                             _ condition: (String) -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        func current() -> String { target.exists ? (target.value as? String ?? "") : "" }
        while !(target.exists && condition(current())), Date() < deadline { usleep(200_000) }
        return target.exists && condition(current())
    }

    /// Waits until the canvas description satisfies `condition`; true when it does.
    @MainActor
    static func waitForDescription(_ app: XCUIApplication, timeout: TimeInterval = MA.shortWait,
                                   _ condition: (String) -> Bool) -> Bool {
        waitForLabel(canvas(app), timeout: timeout, condition)
    }
}
