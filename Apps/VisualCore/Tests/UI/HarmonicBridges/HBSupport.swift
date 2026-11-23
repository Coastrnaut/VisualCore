// HBSupport — feature 419 (R02-G12-09) T-R02G1209-004 (FR-R02G1209-002; SC-R02G1209-001; clarifications Q1, Q2):
// helpers of the interface tests of Harmonic Bridges (R02-G12) inside the one app, modelled on `ECGSupport` (feature
// 409). The namespace is `HB` (no other UI test uses it). Harmonic Bridges was a candidate until X-R02-G12
// (2026-11-23); every launch still carries `-vcCandidates` (DebugLaunch: the candidates' catalog entries become
// available and are registered). A fresh start erases the data (`-vcResetData`, so no level is solved), skips the
// welcome and opens the experience directly with `-openExperience r02-g12.harmonic-bridges`; a relaunch (`HB.reopen`)
// backgrounds the app first (its save point), terminates it and starts again without the reset, so the stored progress
// (solved levels, stars, the frontier, the verified winning trace) survives.
//
// The canvas (`session.canvas`) is labelled with the presenter's description (`HarmonicBridgesPresenter.describe`):
// "Harmonic Bridges level n. ", the progress "step s: k bridge(s), goal reached|goal not reached; a actions left"
// (`HarmonicBridgesLevel.progressDescription`), and, when won, "The crossing holds in every step." followed by
// " Stars: s of 3." when the level has stars in the progress, then the goal and the tutorial. The controls are found by
// the identifiers of Clarification Q1 (`port.identifier(name)`, that is `experience.r02-g12.harmonic-bridges.<name>`):
// the buttons `tune` (value: the chosen string and peg in words), `test`, `undo`, `redo`, `next-level`, `reset-view`,
// `dismiss-tutorial`, `hint`, `failure-undo`, `retry`, `campaign`, `daily`, `practice` (value "selected" for the
// current mode, else "not selected"), `play-level`, `replay` (when the level has a verified stored solution, not during
// replay), `replay-step` (value "Action k of n") and `replay-stop`; the steppers `string` (labelled "Chosen string";
// value `HarmonicBridgesMirror.stringWords`, the string as the level words it at its current peg, "string i, island a
// to island b, peg p" with ", locked" for a locked string — or "string i" before a play is followed; clamped to the
// level's strings), `peg` (labelled "Peg to tune the chosen string to"; value `HarmonicBridgesMirror.pegWords`, "peg
// p" with ", the current peg" when the chosen string is already at it; clamped to 1 … 12) and `level-picker` ("Level
// n, band b" plus ", k stars" when won; never past the open frontier or below 1) — all presentation only; the toggle
// `sound` and the text elements `summary` (the "Crossing" element), `status`, `actions`, `message`, `failure`,
// `instruction`, `hint-text`, `goal` and `replay-position`. The controls sit below the canvas in a scroll view; a
// control is scrolled into view before it is used, with slow drags near the left edge. Everything lives in the
// namespace `HB`, so that nothing collides with the shared helpers of `AppUITestSupport` or the other experiences.
import Foundation
import XCTest

/// Launch arguments, identifiers, level 1's certified actions and helpers of the R02-G12 interface tests.
enum HB {
    /// The experience's id in the catalog.
    static let experienceID = "r02-g12.harmonic-bridges"
    /// The prefix of every identifier of the experience's controls.
    static let prefix = "experience.r02-g12.harmonic-bridges."
    /// The debug argument that makes the candidates available (DebugLaunch).
    static let candidates = "-vcCandidates"
    /// A first start with erased data, straight into Harmonic Bridges.
    static let fresh = [VC.reset, VC.skipWelcome, candidates, VC.openExperience, experienceID]
    /// A start over the same storage (no reset), straight into Harmonic Bridges.
    static let relaunch = [VC.skipWelcome, candidates, VC.openExperience, experienceID]
    /// The longest a single check waits (each test stays under 90 s).
    static let shortWait: TimeInterval = 5
    /// The most drags one reveal makes.
    static let maxDrags = 24
    /// The most presses one stepper makes to reach a value (pegs run 1 … 12; level 1 needs one press).
    static let maxPresses = 12

    // Level 1, pinned here so the interface tests need no Core import (read on 2026-11-23 from the stored witness
    // `docs/games/harmonic-bridges/levels/001.witness.json`; an app unit test checks them against the Core,
    // `HarmonicBridgesExperienceCore.certifiedActions(1)` and level 1's starting pegs and budget): two islands, one
    // string (string 0, island 0 to island 1, unlocked, at peg 11), one step, budget 9, tutorial on. The witness's
    // actions, encoded `{"tune": {"_0": string, "_1": peg}}` and `{"test": {}}` (`HarmonicBridgesAction.tune(Int, Int)`
    // and `.test`, the values `string.tune [string, peg]` and `crossing.test` send), are tune(0, 12) and test: two
    // actions equal the certified actions, so three stars; the stored trace holds the two actions.
    //
    // The choice: `HarmonicBridgesMirror.follow` on a new level chooses string 0 at its current peg (here peg 11);
    // within a level the chosen string stays (clamped) and the peg stays where it was set, and stepping the string
    // makes the peg that string's current peg. So before each tuning the string stepper is stepped first, then the peg
    // stepper, each read from its value.

    /// One certified tuning of level 1: tune string `string` to peg `peg`.
    struct Tuning {
        /// The string's index.
        let string: Int
        /// The peg it is tuned to.
        let peg: Int
    }

    /// Level 1's certified tunings, in the order of the witness (the witness then ends with one test).
    static let certifiedTunings: [Tuning] = [Tuning(string: 0, peg: 12)]
    /// The number of level 1's certified actions: its tunings plus the test.
    static let certifiedActionCount = 2
    /// The choice the string and peg steppers show when level 1 opens (string 0 at its current peg;
    /// `HarmonicBridgesMirror.follow`).
    static let levelOneOpening: (string: Int, peg: Int) = (string: 0, peg: 11)
    /// Level 1's action budget.
    static let levelOneBudget = 9
    /// The number of level 1's strings.
    static let levelOneStringCount = 1
    /// The length of the trace stored by the certified win (the tuning and the test).
    static let levelOneTraceLength = 2

    /// The canvas phrase of a fresh level 1 (its crossing not yet holding).
    static let notReached = "goal not reached"
    /// The canvas phrase of a fresh level 1's budget (nothing spent).
    static let fullBudget = "9 actions left"
    /// The canvas phrase of level 1 after its one tuning (one action spent).
    static let afterTuning = "8 actions left"
    /// The canvas phrase of a won level (`HarmonicBridgesFeedbackPlan.wonText`).
    static let won = "The crossing holds in every step."
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

    /// Launches the app with `arguments` and waits until Harmonic Bridges runs.
    @MainActor
    @discardableResult
    static func open(arguments: [String] = HB.fresh, file: StaticString = #filePath, line: UInt = #line)
        -> XCUIApplication {
        let app = launchApp(arguments: arguments)
        waitForRunning(app, file: file, line: line)
        return app
    }

    /// Backgrounds `app` (its save point), ends it and opens Harmonic Bridges again over the same storage
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
        let second = launchApp(arguments: HB.relaunch)
        waitForRunning(second, file: file, line: line)
        return second
    }

    /// Waits for the experience route, the canvas labelled with a level and the level picker.
    @MainActor
    private static func waitForRunning(_ app: XCUIApplication, file: StaticString, line: UInt) {
        waitFor(element(app, "vc.route.experience"), timeout: VC.firstWait, file: file, line: line)
        waitFor(canvas(app), timeout: VC.firstWait, file: file, line: line)
        waitFor(control(app, "level-picker"), timeout: VC.wait, "the level picker is there", file: file, line: line)
        XCTAssertTrue(waitForLabel(canvas(app)) { $0.contains("Harmonic Bridges level") },
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

    /// The stepper `name` (`string`, `peg` or `level-picker`): the system stepper with the identifier when there is
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

    /// The chosen string of a string stepper value "string i, island a to island b, peg p[, locked]" (or "string i"),
    /// or nil.
    static func pickedString(_ text: String) -> Int? { number(after: "string ", in: text) }

    /// The current peg of the chosen string in a string stepper value ("…, peg p[, locked]"), or nil when the value
    /// names no peg.
    static func currentPeg(_ text: String) -> Int? {
        guard let range = text.range(of: ", peg ", options: .backwards) else { return nil }
        let digits = text[range.upperBound...].prefix { $0.isASCII && $0.isNumber }
        return digits.isEmpty ? nil : Int(digits)
    }

    /// The chosen peg of a peg stepper value "peg p" or "peg p, the current peg", or nil.
    static func pickedPeg(_ text: String) -> Int? { number(after: "peg ", in: text) }

    /// Whether a peg stepper value says the chosen string is already at the chosen peg.
    static func isCurrentPeg(_ text: String) -> Bool { text.hasSuffix(", the current peg") }

    /// The choice as the string and peg steppers show it, or nil when either cannot be read.
    @MainActor
    static func choice(_ app: XCUIApplication) -> (string: Int, peg: Int)? {
        guard let string = pickedString(stepper(app, "string").value as? String ?? ""),
              let peg = pickedPeg(stepper(app, "peg").value as? String ?? "") else { return nil }
        return (string, peg)
    }

    /// Steps the clamped stepper `name` from its current value (read with `parse`) to `target`, at most
    /// ``maxPresses`` presses: up when it is below the target, else down. A press counts only when the value moves; a
    /// press that leaves the value unchanged (an end of its range) stops the stepping. True when it shows the target.
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
        var moves = 0
        while let at = parse(current), at != target, presses < maxPresses {
            let after = press(app, name, up: at < target)
            presses += 1
            if after == current { break }   // an end of the range: it cannot move further
            moves += 1
            current = after
        }
        let reached = parse(current) == target
        XCTAssertTrue(reached, "\(name) shows \(target) after \(moves) moves in \(presses) presses (now \(current))",
                      file: file, line: line)
        return reached
    }

    /// Chooses `string` and `peg` with the steppers, each stepped from its current value: the string stepper first
    /// (which makes the peg that string's current peg), then the peg stepper. True when both steppers read the target.
    @MainActor
    @discardableResult
    static func choose(_ app: XCUIApplication, string: Int, peg: Int,
                       file: StaticString = #filePath, line: UInt = #line) -> Bool {
        guard choice(app) != nil else {
            XCTFail("the string and peg steppers cannot be read: \(stepper(app, "string").value ?? "nil"), "
                    + "\(stepper(app, "peg").value ?? "nil")", file: file, line: line)
            return false
        }
        guard step(app, "string", to: string, parse: pickedString, file: file, line: line),
              step(app, "peg", to: peg, parse: pickedPeg, file: file, line: line) else { return false }
        guard let after = choice(app), after.string == string, after.peg == peg else {
            XCTFail("the choice reads \(String(describing: choice(app))), not string \(string), peg \(peg)",
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

    /// Plays one certified tuning with the panel: chooses its string and peg (``choose``), checks that Tune names that
    /// choice ("…; tune to peg p") and taps it; the string stepper then reads the tuned peg as the string's current peg
    /// and the peg stepper says ", the current peg". True when every control was used and showed what it should.
    @MainActor
    @discardableResult
    static func play(_ app: XCUIApplication, _ tuning: Tuning, file: StaticString = #filePath, line: UInt = #line)
        -> Bool {
        guard choose(app, string: tuning.string, peg: tuning.peg, file: file, line: line),
              let button = shown(app, "tune", file: file, line: line) else { return false }
        let named = button.value as? String ?? ""
        XCTAssertTrue(pickedString(named) == tuning.string && named.hasSuffix("; tune to peg \(tuning.peg)"),
                      "Tune names the choice: \(named)", file: file, line: line)
        button.tap()
        let string = stepper(app, "string")
        XCTAssertTrue(waitForValue(string) { currentPeg($0) == tuning.peg },
                      "string \(tuning.string) is at peg \(tuning.peg): \(string.value as? String ?? "")",
                      file: file, line: line)
        XCTAssertTrue(waitForValue(stepper(app, "peg")) { isCurrentPeg($0) },
                      "the peg stepper names the current peg: \(stepper(app, "peg").value as? String ?? "")",
                      file: file, line: line)
        return true
    }

    /// Plays level 1's certified solution with the panel: each tuning (``play(_:_:file:line:)``), after which the
    /// canvas reports the action spent, then Test. True when every action was played.
    @MainActor
    @discardableResult
    static func playLevelOneSolution(_ app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line)
        -> Bool {
        for (index, tuning) in certifiedTunings.enumerated() {
            guard play(app, tuning, file: file, line: line) else { return false }
            let left = "\(levelOneBudget - index - 1) actions left"
            XCTAssertTrue(waitForDescription(app) { $0.contains(left) },
                          "tuning \(index + 1) spends one action: \(description(app))", file: file, line: line)
        }
        return tap(app, "test", file: file, line: line)
    }

    /// A fresh start, the tutorial dismissed and level 1 won with its certified actions; returns the app after the
    /// canvas reports the crossing holding in every step with all three stars.
    @MainActor
    @discardableResult
    static func winLevelOne(file: StaticString = #filePath, line: UInt = #line) -> XCUIApplication {
        let app = open(arguments: fresh, file: file, line: line)
        XCTAssertTrue(description(app).contains("Harmonic Bridges level 1."),
                      "a fresh start opens level 1: \(description(app))", file: file, line: line)
        XCTAssertTrue(description(app).contains(notReached) && description(app).contains(fullBudget),
                      "level 1 starts with its goal not reached and its budget whole: \(description(app))",
                      file: file, line: line)
        let opening = choice(app)
        XCTAssertTrue(opening?.string == levelOneOpening.string && opening?.peg == levelOneOpening.peg,
                      "the choice starts on string 0 at its current peg 11 (now \(String(describing: opening)))",
                      file: file, line: line)
        XCTAssertTrue(isCurrentPeg(stepper(app, "peg").value as? String ?? ""),
                      "the opening peg is the string's current peg: \(stepper(app, "peg").value ?? "nil")",
                      file: file, line: line)
        dismissTutorialIfShown(app, file: file, line: line)
        XCTAssertTrue(playLevelOneSolution(app, file: file, line: line), "the solution is played",
                      file: file, line: line)
        XCTAssertTrue(waitForDescription(app, timeout: VC.wait) { $0.contains(won) && $0.contains(threeStars) },
                      "the canvas reports the crossing holding with three stars: \(description(app))",
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
    static func waitForLabel(_ target: XCUIElement, timeout: TimeInterval = HB.shortWait,
                             _ condition: (String) -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while !(target.exists && condition(target.label)), Date() < deadline { usleep(200_000) }
        return target.exists && condition(target.label)
    }

    /// Waits until the value of `target` (as text) satisfies `condition`; true when it does.
    @MainActor
    static func waitForValue(_ target: XCUIElement, timeout: TimeInterval = HB.shortWait,
                             _ condition: (String) -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        func current() -> String { target.exists ? (target.value as? String ?? "") : "" }
        while !(target.exists && condition(current())), Date() < deadline { usleep(200_000) }
        return target.exists && condition(current())
    }

    /// Waits until the canvas description satisfies `condition`; true when it does.
    @MainActor
    static func waitForDescription(_ app: XCUIApplication, timeout: TimeInterval = HB.shortWait,
                                   _ condition: (String) -> Bool) -> Bool {
        waitForLabel(canvas(app), timeout: timeout, condition)
    }
}
