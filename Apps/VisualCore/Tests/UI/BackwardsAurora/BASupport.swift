// BASupport — feature 399 (R02-G10-09) T-R02G1009-004 (FR-R02G1009-002; SC-R02G1009-001; clarifications Q1, Q2;
// research R2): helpers of the interface tests of Backwards Aurora (R02-G10) inside the one app, modelled on
// `NGSupport` (feature 389). Backwards Aurora was a candidate until X-R02-G10 (2026-11-23); every launch still carries `-vcCandidates`
// (DebugLaunch: the candidates' catalog entries become available and are registered). A fresh start erases the data
// (`-vcResetData`, so no level is solved), skips the welcome and opens the experience directly with
// `-openExperience r02-g10.backwards-aurora`; a relaunch (`BA.reopen`) backgrounds the app first (its save point),
// terminates it and starts again without the reset, so the stored progress (solved levels, stars, the frontier, the
// verified winning trace) survives.
//
// The canvas (`session.canvas`) is labelled with the presenter's description (`BackwardsAuroraPresenter.describe`):
// "Backwards Aurora level n. ", "m of b reversals spent. ", the bends, distance and remaining reversals in words, the
// checkpoints and, when won, "Every checkpoint matches and every bend is within the limit." followed by " Stars: s of
// 3." when the level has stars in the progress. The controls are found by the identifiers of Clarification Q1
// (`port.identifier(name)`, that is `experience.r02-g10.backwards-aurora.<name>`): the buttons `reverse` (value
// "section s to e, n samples"), `undo`, `redo`, `next-level`, `reset-view`, `hint`, `dismiss-tutorial`,
// `failure-undo`, `retry`, `campaign`, `daily`, `practice` (value "selected" for the current mode, else "not
// selected"), `play-level`, `replay` (when the level has a verified stored solution, not during replay),
// `replay-step` (value "Reversal k of n") and `replay-stop`; the steppers `start-picker` (value "sample k, height h",
// clamped to 0 … N − 2, the end follows to stay after it), `end-picker` (value "sample k, height h", clamped to
// 1 … N − 1, the start follows to stay before it) and `level-picker` ("Level n, band b" plus ", k stars" when won;
// never past the open frontier or below 1) — all presentation only; the toggle `sound` and the element `summary` (the
// "Aurora" element). The controls sit below the canvas in a scroll view; a control is scrolled into view before it is
// used, with slow drags near the left edge. Everything lives in the namespace `BA`, so that nothing collides with the
// shared helpers of `AppUITestSupport` or the other experiences.
import Foundation
import XCTest

/// Launch arguments, identifiers, level 1's certified reversals and helpers of the R02-G10 interface tests.
enum BA {
    /// The experience's id in the catalog.
    static let experienceID = "r02-g10.backwards-aurora"
    /// The prefix of every identifier of the experience's controls.
    static let prefix = "experience.r02-g10.backwards-aurora."
    /// The debug argument that makes the candidates available (DebugLaunch).
    static let candidates = "-vcCandidates"
    /// A first start with erased data, straight into Backwards Aurora.
    static let fresh = [VC.reset, VC.skipWelcome, candidates, VC.openExperience, experienceID]
    /// A start over the same storage (no reset), straight into Backwards Aurora.
    static let relaunch = [VC.skipWelcome, candidates, VC.openExperience, experienceID]
    /// The longest a single check waits (each test stays under 90 s).
    static let shortWait: TimeInterval = 5
    /// The most drags one reveal makes.
    static let maxDrags = 24
    /// The most presses one stepper makes to reach a value (level 1's wave has 14 samples; it needs at most 7).
    static let maxPresses = 30

    // Level 1, pinned here so the interface tests need no Core import (read on 2026-11-23 from the stored witness
    // `docs/games/backwards-aurora/levels/001.witness.json`; an app unit test checks them against the Core,
    // `BackwardsAuroraExperienceCore.certifiedActions(1)` and the panel's opening section): a wave of 14 samples,
    // budget 9, certified smallest 2, checkpoints at samples 4 and 11, bend limit 1, tutorial on. The witness's
    // actions, encoded `{"reverse": {"_0": start, "_1": end}}` (`BackwardsAuroraAction.reverse(Int, Int)`, both ends
    // inclusive, the values `wave.reverse [start, end]` sends), are reverse(3, 4) and reverse(8, 11). Two reversals
    // equal the smallest, so three stars (`BackwardsAuroraProgress.stars`); the stored trace holds the two reversals.
    //
    // The starting section: `BackwardsAuroraMirror.follow` on a new level sets start 0 and end 1. Within a level the
    // section stays where it was set (a reversal only clamps it to the wave), so before each reversal both steppers are
    // read and stepped from their values.

    /// Level 1's certified reversals (start, end; both inclusive), in the order of the witness.
    static let certifiedReversals: [(start: Int, end: Int)] = [(start: 3, end: 4), (start: 8, end: 11)]
    /// The section the start and end steppers show when level 1 opens (`BackwardsAuroraMirror.follow`).
    static let openingSection: (start: Int, end: Int) = (start: 0, end: 1)
    /// Level 1's reversal budget.
    static let levelOneBudget = 9
    /// Level 1's certified smallest reversal count.
    static let levelOneSmallest = 2
    /// The length of the trace stored by the certified win (the two reversals).
    static let levelOneTraceLength = 2

    /// The canvas phrase of a won level.
    static let won = "Every checkpoint matches and every bend is within the limit."
    /// The canvas phrase of a level won with all three stars.
    static let threeStars = "Stars: 3 of 3."
    /// The level picker's value of level 1 once it is won with three stars (band 1: levels 1 … 20).
    static let levelOneThreeStars = "Level 1, band 1, 3 stars"

    /// The canvas phrase of `reversals` reversals spent of level 1's budget.
    static func spent(_ reversals: Int) -> String { ". \(reversals) of \(levelOneBudget) reversals spent." }

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

    /// Launches the app with `arguments` and waits until Backwards Aurora runs.
    @MainActor
    @discardableResult
    static func open(arguments: [String] = BA.fresh, file: StaticString = #filePath, line: UInt = #line)
        -> XCUIApplication {
        let app = launchApp(arguments: arguments)
        waitForRunning(app, file: file, line: line)
        return app
    }

    /// Backgrounds `app` (its save point), ends it and opens Backwards Aurora again over the same storage
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
        let second = launchApp(arguments: BA.relaunch)
        waitForRunning(second, file: file, line: line)
        return second
    }

    /// Waits for the experience route, the canvas labelled with a level and the level picker.
    @MainActor
    private static func waitForRunning(_ app: XCUIApplication, file: StaticString, line: UInt) {
        waitFor(element(app, "vc.route.experience"), timeout: VC.firstWait, file: file, line: line)
        waitFor(canvas(app), timeout: VC.firstWait, file: file, line: line)
        waitFor(control(app, "level-picker"), timeout: VC.wait, "the level picker is there", file: file, line: line)
        XCTAssertTrue(waitForLabel(canvas(app)) { $0.contains("Backwards Aurora level") },
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

    /// The stepper `name` (`start-picker`, `end-picker` or `level-picker`): the system stepper with the identifier
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

    /// The sample of a start or end stepper value "sample k, height h" (or "sample k"), or nil.
    static func pickedSample(_ text: String) -> Int? { number(after: "sample ", in: text) }

    /// The section the start and end steppers show, or nil when one cannot be read.
    @MainActor
    static func currentSection(_ app: XCUIApplication) -> (start: Int, end: Int)? {
        func read(_ name: String) -> String { stepper(app, name).value as? String ?? "" }
        guard let start = pickedSample(read("start-picker")), let end = pickedSample(read("end-picker"))
        else { return nil }
        return (start, end)
    }

    /// Steps the clamped stepper `name` from its current value (read with `parse`) to `target`, at most
    /// ``maxPresses`` presses: up when it is below the target, else down; it stops when a press leaves its value
    /// unchanged (an end of its range). True when it shows the target.
    @MainActor
    @discardableResult
    static func step(_ app: XCUIApplication, _ name: String, to target: Int,
                     parse: (String) -> Int?, file: StaticString = #filePath, line: UInt = #line) -> Bool {
        guard ready(app, name, file: file, line: line) else { return false }
        let control = stepper(app, name)
        var current = control.value as? String ?? ""
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

    /// Sets the section to `start` … `end` with the steppers, each stepped from its current value: the end stepper up
    /// first when the target end lies above it, then the start stepper (so the start never has to pass the end and
    /// push it), then the end stepper down when it is still above the target. True when both show their values.
    @MainActor
    @discardableResult
    static func chooseSection(_ app: XCUIApplication, start: Int, end: Int,
                              file: StaticString = #filePath, line: UInt = #line) -> Bool {
        guard let before = currentSection(app) else {
            XCTFail("the start and end steppers cannot be read", file: file, line: line)
            return false
        }
        if end > before.end {
            guard step(app, "end-picker", to: end, parse: pickedSample, file: file, line: line) else { return false }
        }
        guard step(app, "start-picker", to: start, parse: pickedSample, file: file, line: line) else { return false }
        if let now = currentSection(app), now.end > end {
            guard step(app, "end-picker", to: end, parse: pickedSample, file: file, line: line) else { return false }
        }
        guard let after = currentSection(app), after.start == start, after.end == end else {
            XCTFail("the section reads \(String(describing: currentSection(app))), not \(start) … \(end)",
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

    /// Plays one certified reversal with the panel: steps the section to its ends (``chooseSection``), checks
    /// Reverse's value and taps Reverse. True when every control was used and showed what it should.
    @MainActor
    @discardableResult
    static func play(_ app: XCUIApplication, start: Int, end: Int, file: StaticString = #filePath, line: UInt = #line)
        -> Bool {
        guard chooseSection(app, start: start, end: end, file: file, line: line),
              let button = shown(app, "reverse", file: file, line: line) else { return false }
        let words = "section \(start) to \(end), \(end - start + 1) samples"
        XCTAssertEqual(button.value as? String ?? "", words, "Reverse shows the section", file: file, line: line)
        button.tap()
        return true
    }

    /// Plays level 1's certified reversals with the panel (``play(_:start:end:file:line:)``); after every reversal
    /// the canvas must report one more reversal spent. True when every reversal was played.
    @MainActor
    @discardableResult
    static func playLevelOneSolution(_ app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line)
        -> Bool {
        for (index, reversal) in certifiedReversals.enumerated() {
            guard play(app, start: reversal.start, end: reversal.end, file: file, line: line) else { return false }
            XCTAssertTrue(waitForDescription(app) { $0.contains(spent(index + 1)) },
                          "reversal \(index + 1) is spent: \(description(app))", file: file, line: line)
        }
        return true
    }

    /// A fresh start, the tutorial dismissed and level 1 won with its certified reversals; returns the app after the
    /// canvas reports every checkpoint matches with all three stars.
    @MainActor
    @discardableResult
    static func winLevelOne(file: StaticString = #filePath, line: UInt = #line) -> XCUIApplication {
        let app = open(arguments: fresh, file: file, line: line)
        XCTAssertTrue(description(app).contains("Backwards Aurora level 1."),
                      "a fresh start opens level 1: \(description(app))", file: file, line: line)
        XCTAssertTrue(description(app).contains(spent(0)),
                      "level 1 starts with no reversal spent of its budget: \(description(app))", file: file,
                      line: line)
        let opening = currentSection(app)
        XCTAssertTrue(opening?.start == openingSection.start && opening?.end == openingSection.end,
                      "the steppers start on samples 0 and 1 (now \(String(describing: opening)))",
                      file: file, line: line)
        dismissTutorialIfShown(app, file: file, line: line)
        XCTAssertTrue(playLevelOneSolution(app, file: file, line: line), "the solution is played",
                      file: file, line: line)
        XCTAssertTrue(waitForDescription(app, timeout: VC.wait) { $0.contains(won) && $0.contains(threeStars) },
                      "the canvas reports every checkpoint matches with three stars: \(description(app))",
                      file: file, line: line)
        return app
    }

    /// The position and length of a replay step value "Reversal k of n", or nil.
    static func replayPosition(_ text: String) -> (position: Int, length: Int)? {
        guard text.hasPrefix("Reversal ") else { return nil }
        let parts = text.dropFirst("Reversal ".count).components(separatedBy: " of ")
        guard parts.count == 2, let p = Int(parts[0]), let n = Int(parts[1]) else { return nil }
        return (p, n)
    }

    /// Waits until the label of `target` satisfies `condition`; true when it does.
    @MainActor
    static func waitForLabel(_ target: XCUIElement, timeout: TimeInterval = BA.shortWait,
                             _ condition: (String) -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while !(target.exists && condition(target.label)), Date() < deadline { usleep(200_000) }
        return target.exists && condition(target.label)
    }

    /// Waits until the value of `target` (as text) satisfies `condition`; true when it does.
    @MainActor
    static func waitForValue(_ target: XCUIElement, timeout: TimeInterval = BA.shortWait,
                             _ condition: (String) -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        func current() -> String { target.exists ? (target.value as? String ?? "") : "" }
        while !(target.exists && condition(current())), Date() < deadline { usleep(200_000) }
        return target.exists && condition(current())
    }

    /// Waits until the canvas description satisfies `condition`; true when it does.
    @MainActor
    static func waitForDescription(_ app: XCUIApplication, timeout: TimeInterval = BA.shortWait,
                                   _ condition: (String) -> Bool) -> Bool {
        waitForLabel(canvas(app), timeout: timeout, condition)
    }
}
