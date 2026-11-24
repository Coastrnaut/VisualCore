// VOSupport — feature 449 (R02-G15-09) T-R02G1509-004, modelled on feature 439 (FR-R02G1509-002; SC-R02G1509-001;
// clarifications Q1, Q2): helpers of the interface tests of Voxel Origami (R02-G15) inside the one app, modelled on
// `MMSupport` (feature 439). The namespace is `VO` (no other UI test uses `VO`). Voxel Origami is a candidate until
// X-R02-G15; every launch carries `-vcCandidates` (DebugLaunch: the candidates' catalog entries become available and
// are registered). A fresh start erases the data (`-vcResetData`, so no level is solved), skips the welcome and opens
// the experience directly with `-openExperience r02-g15.voxel-origami`; a relaunch (`VO.reopen`) backgrounds the app
// first (its save point), terminates it and starts again without the reset, so the stored progress (solved levels,
// stars, the frontier, the verified winning trace) survives.
//
// The canvas (`session.canvas`) is labelled with the presenter's description (`VoxelOrigamiPresenter.describe`):
// "Voxel Origami level n. ", the progress ("c of k cubes in place; the shape matches the target | does not match yet;
// a actions left", `VoxelOrigamiLevel.progressDescription`) and ". ", and, when won, "The chain matches the target
// shape." followed by the finished message and " Stars: s of 3." when the level has stars in the progress, then the
// goal and, while the tutorial shows, " Tutorial: <instruction>". The controls are found by the identifiers of
// Clarification Q1 (`port.identifier(name)`, that is `experience.r02-g15.voxel-origami.<name>`;
// `VoxelOrigamiControls`): the header text `actions` ("Level n · a of b actions left"), `status`, `failure`,
// `progress`, `summary` (labelled "Solid"), `message`, `pending`; the tutorial's `instruction` and `dismiss-tutorial`
// ("Dismiss", labelled "Dismiss the tutorial"); `hint`, `goal`, `hint-text`, `explanation`, `failure-undo`, `retry`;
// the hinge row: `hinge-minus` and `hinge-plus` ("Hinge −", "Hinge +"; `hinge.choose [h ∓ 1]`, presentation only, no
// action spent; value `VoxelOrigamiMirror.hingeDetail`), the text `hinge` (`VoxelOrigamiMirror.hingeLabel`, "hinge h")
// and the adjustable `hinge-detail` (labelled "Chosen hinge", value `hingeDetail`, "hinge h, turned d degrees", with
// ", nothing would move" when the hinge cannot turn); the turn row: `turn-minus`, `turn-plus` ("Turn −", "Turn +";
// `hinge.turn [h, ∓1]` on the chosen hinge); `undo`, `redo`, `next-level`, `reset-view`; `campaign`, `daily`,
// `practice` (value "selected" for the current mode, else "not selected"); the stepper `level-picker` (labelled
// "Level to play"; value "Level n, band b" plus ", k stars" when won; never past the open frontier or below 1) and
// `play-level`; the replay section: `replay` ("Replay best solution", when the level has a verified stored solution,
// not during replay), `replay-position` ("Replay: turn k of n"), `replay-step` ("Step", value
// `VoxelOrigamiControls.replayStepValue`, "Turn k of n") and `replay-stop` ("Stop", value "n turns",
// `VoxelOrigamiControls.replayStopValue`); the toggle `sound`. The controls sit below the canvas in a scroll view; a
// control is scrolled into view before it is used, with slow drags near the left edge. Everything lives in the
// namespace `VO`, so that nothing collides with the shared helpers of `AppUITestSupport` or the other experiences.
import Foundation
import XCTest

/// Launch arguments, identifiers, level 1's certified turns and helpers of the R02-G15 interface tests.
enum VO {
    /// The experience's id in the catalog.
    static let experienceID = "r02-g15.voxel-origami"
    /// The prefix of every identifier of the experience's controls.
    static let prefix = "experience.r02-g15.voxel-origami."
    /// The debug argument that makes the candidates available (DebugLaunch).
    static let candidates = "-vcCandidates"
    /// A first start with erased data, straight into Voxel Origami.
    static let fresh = [VC.reset, VC.skipWelcome, candidates, VC.openExperience, experienceID]
    /// A start over the same storage (no reset), straight into Voxel Origami.
    static let relaunch = [VC.skipWelcome, candidates, VC.openExperience, experienceID]
    /// The longest a single check waits (each test stays under 90 s).
    static let shortWait: TimeInterval = 5
    /// The most drags one reveal makes.
    static let maxDrags = 24
    /// The most taps one certified turn makes, lost taps (the actions left did not move) included.
    static let maxTaps = 3
    /// The most taps of Hinge + or Hinge − that bring the chosen hinge to the wanted one, lost taps included.
    static let maxHingeTaps = 12

    // Level 1, pinned here so the interface tests need no Core import (read on 2026-11-24 from the stored witness
    // `docs/games/voxel-origami/levels/001.witness.json`; an app unit test checks them against the Core,
    // `VoxelOrigamiExperienceCore.certifiedActions(1)` (static) and level 1's budget): a chain of six cubes, two
    // turnable hinges, upright orientations, budget 9, tutorial on (levels 1 … 3). The witness's actions, encoded
    // `{"turn": {"_0": 4, "_1": -1}}` twice (the values `hinge.turn [4, -1]` sends), are turn(4, -1) twice. Every
    // turn spends one action; choosing a hinge spends none (presentation state of the adapter). The certified win
    // spends two actions (three stars) and the stored trace holds the two turns.
    //
    // A turn is a hinge (1 … cubes − 1) with its step (±1, a quarter turn back or forward).

    /// Level 1's certified turns, in the order of the witness.
    static let levelOneTurns: [(hinge: Int, step: Int)] = [(4, -1), (4, -1)]
    /// Level 1's action budget.
    static let levelOneBudget = 9
    /// The number of level 1's certified turns (every one spends an action).
    static var certifiedActionCount: Int { levelOneTurns.count }
    /// The length of the trace stored by the certified win (the two turns).
    static var levelOneTraceLength: Int { levelOneTurns.count }

    /// The canvas phrase of a fresh level 1's budget (nothing spent).
    static let fullBudget = "; 9 actions left"
    /// The canvas phrase of a won level (`VoxelOrigamiPresenter.describe`).
    static let won = "The chain matches the target shape."
    /// The canvas phrase of a level won with all three stars.
    static let threeStars = "Stars: 3 of 3."
    /// The canvas phrase while the tutorial shows.
    static let tutorial = " Tutorial: "
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

    /// The header line `actions` ("Level n · a of b actions left"), or "" when it is not there.
    @MainActor
    static func actionsText(_ app: XCUIApplication) -> String {
        let header = control(app, "actions")
        return header.exists ? header.label : ""
    }

    /// The actions left of a header line "Level n · a of b actions left", or nil.
    static func actionsLeft(_ text: String) -> Int? {
        guard let dot = text.range(of: " · ") else { return nil }
        let digits = text[dot.upperBound...].prefix { $0.isASCII && $0.isNumber }
        guard !digits.isEmpty, text[dot.upperBound...].dropFirst(digits.count).hasPrefix(" of ") else { return nil }
        return Int(digits)
    }

    /// The hinge number of a hinge text "hinge h" (`hingeLabel`) or "hinge h, turned d degrees[, nothing would
    /// move]" (`hingeDetail`), or nil.
    static func hingeNumber(_ text: String) -> Int? {
        guard text.hasPrefix("hinge ") else { return nil }
        let digits = text.dropFirst("hinge ".count).prefix { $0.isASCII && $0.isNumber }
        return digits.isEmpty ? nil : Int(digits)
    }

    /// The chosen hinge as the panel shows it, or nil: the text `hinge`'s label ("hinge h"), else the value of the
    /// adjustable `hinge-detail`, else the value of `hinge-plus` (both `hingeDetail`).
    @MainActor
    static func chosenHinge(_ app: XCUIApplication) -> Int? {
        let label = control(app, "hinge")
        if label.exists, let h = hingeNumber(label.label) { return h }
        if let h = hingeNumber(value(app, "hinge-detail")) { return h }
        return hingeNumber(value(app, "hinge-plus"))
    }

    /// Launches the app with `arguments` and waits until Voxel Origami runs.
    @MainActor
    @discardableResult
    static func open(arguments: [String] = VO.fresh, file: StaticString = #filePath, line: UInt = #line)
        -> XCUIApplication {
        let app = launchApp(arguments: arguments)
        waitForRunning(app, file: file, line: line)
        return app
    }

    /// Backgrounds `app` (its save point), ends it and opens Voxel Origami again over the same storage
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
        let second = launchApp(arguments: VO.relaunch)
        waitForRunning(second, file: file, line: line)
        return second
    }

    /// Waits for the experience route, the canvas labelled with a level and the level picker.
    @MainActor
    private static func waitForRunning(_ app: XCUIApplication, file: StaticString, line: UInt) {
        waitFor(element(app, "vc.route.experience"), timeout: VC.firstWait, file: file, line: line)
        waitFor(canvas(app), timeout: VC.firstWait, file: file, line: line)
        waitFor(control(app, "level-picker"), timeout: VC.wait, "the level picker is there", file: file, line: line)
        XCTAssertTrue(waitForLabel(canvas(app)) { $0.contains("Voxel Origami level") },
                      "the canvas is labelled with a level: \(description(app))", file: file, line: line)
    }

    /// Taps `dismiss-tutorial` when the tutorial shows it (a fresh start of level 1 does); nothing otherwise. One
    /// dismissal ends the tutorial for this opening (`tutorial.dismiss`).
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

    /// Brings the chosen hinge to `hinge` with Hinge + or Hinge − (`hinge.choose`, which spends no action): the chosen
    /// hinge (``chosenHinge(_:)``) is read before each tap, and a tap counts only when the reading moves; a lost tap
    /// is retried, within ``maxHingeTaps`` taps. True when the panel shows `hinge` chosen.
    @MainActor
    @discardableResult
    static func chooseHinge(_ app: XCUIApplication, _ hinge: Int,
                            file: StaticString = #filePath, line: UInt = #line) -> Bool {
        guard var current = chosenHinge(app) else {
            XCTFail("the chosen hinge cannot be read: '\(control(app, "hinge").label)' / "
                    + "'\(value(app, "hinge-detail"))'", file: file, line: line)
            return false
        }
        guard current != hinge else { return true }
        let budget: Int = actionsLeft(actionsText(app)) ?? -1
        let plus: XCUIElement? = shown(app, "hinge-plus", file: file, line: line)
        let minus: XCUIElement? = shown(app, "hinge-minus", file: file, line: line)
        guard let plus, let minus else { return false }
        var taps = 0
        while current != hinge, taps < maxHingeTaps {
            let before = current
            (before < hinge ? plus : minus).tap()
            taps += 1
            _ = waitForValue(plus, timeout: shortWait) { hingeNumber($0) != before }
            current = chosenHinge(app) ?? before
        }
        XCTAssertEqual(current, hinge, "hinge \(hinge) is chosen with Hinge + / Hinge − in \(taps) taps "
                       + "('\(control(app, "hinge").label)', '\(value(app, "hinge-detail"))')", file: file, line: line)
        XCTAssertEqual(actionsLeft(actionsText(app)) ?? -1, budget, "choosing a hinge spends no action",
                       file: file, line: line)
        return current == hinge
    }

    /// The turn button that plays a step: −1 is `turn-minus`, +1 is `turn-plus`; nil for any other step.
    static func button(step: Int) -> String? {
        switch step {
        case -1: "turn-minus"
        case 1: "turn-plus"
        default: nil
        }
    }

    /// Plays one pinned turn with the panel: the hinge is chosen first (``chooseHinge(_:_:file:line:)``), then the turn
    /// button is tapped; the header's actions left is read before and after each tap, and the press counts only when
    /// the count moves down by one; a lost tap (the count did not move) is retried, within ``maxTaps`` taps. True when
    /// the turn was spent exactly once.
    @MainActor
    @discardableResult
    static func play(_ app: XCUIApplication, hinge: Int, step: Int,
                     file: StaticString = #filePath, line: UInt = #line) -> Bool {
        guard let name = button(step: step) else {
            XCTFail("no panel button turns by \(step)", file: file, line: line)
            return false
        }
        guard chooseHinge(app, hinge, file: file, line: line) else { return false }
        guard let target = shown(app, name, file: file, line: line) else { return false }
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
        XCTAssertTrue(spent, "\(name) on hinge \(hinge) spends one action: \(before) → \(after) in \(taps) taps "
                      + "(\(actionsText(app)))", file: file, line: line)
        return spent
    }

    /// Plays level 1's certified turns (``levelOneTurns``) with the panel, in order. True when every turn was spent
    /// exactly once.
    @MainActor
    @discardableResult
    static func playLevelOneSolution(_ app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line)
        -> Bool {
        for turn in levelOneTurns {
            guard play(app, hinge: turn.hinge, step: turn.step, file: file, line: line) else { return false }
        }
        return true
    }

    /// A fresh start, the tutorial dismissed and level 1 won with its certified turns; returns the app after the
    /// canvas reports the chain matching the target shape with all three stars.
    @MainActor
    @discardableResult
    static func winLevelOne(file: StaticString = #filePath, line: UInt = #line) -> XCUIApplication {
        let app = open(arguments: fresh, file: file, line: line)
        XCTAssertTrue(description(app).contains("Voxel Origami level 1."),
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
        XCTAssertTrue(waitForDescription(app, timeout: VC.wait) { $0.contains(won) && $0.contains(threeStars) },
                      "the canvas reports the chain matching with three stars: \(description(app))",
                      file: file, line: line)
        XCTAssertEqual(actionsLeft(actionsText(app)), levelOneBudget - certifiedActionCount,
                       "the certified win spends its \(certifiedActionCount) actions", file: file, line: line)
        return app
    }

    /// The position and length of a replay step value "Turn k of n", or nil.
    static func replayPosition(_ text: String) -> (position: Int, length: Int)? {
        guard text.hasPrefix("Turn ") else { return nil }
        let parts = text.dropFirst("Turn ".count).components(separatedBy: " of ")
        guard parts.count == 2, let p = Int(parts[0]), let n = Int(parts[1]) else { return nil }
        return (p, n)
    }

    /// Waits until the label of `target` satisfies `condition`; true when it does.
    @MainActor
    static func waitForLabel(_ target: XCUIElement, timeout: TimeInterval = VO.shortWait,
                             _ condition: (String) -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while !(target.exists && condition(target.label)), Date() < deadline { usleep(200_000) }
        return target.exists && condition(target.label)
    }

    /// Waits until the value of `target` (as text) satisfies `condition`; true when it does.
    @MainActor
    static func waitForValue(_ target: XCUIElement, timeout: TimeInterval = VO.shortWait,
                             _ condition: (String) -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        func current() -> String { target.exists ? (target.value as? String ?? "") : "" }
        while !(target.exists && condition(current())), Date() < deadline { usleep(200_000) }
        return target.exists && condition(current())
    }

    /// Waits until the canvas description satisfies `condition`; true when it does.
    @MainActor
    static func waitForDescription(_ app: XCUIApplication, timeout: TimeInterval = VO.shortWait,
                                   _ condition: (String) -> Bool) -> Bool {
        waitForLabel(canvas(app), timeout: timeout, condition)
    }
}
