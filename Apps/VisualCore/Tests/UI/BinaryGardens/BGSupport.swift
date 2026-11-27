// BGSupport — feature 509 (R02-G21-09) T-R02G2109-004, modelled on feature 499 (FR-R02G2109-002, 007; SC-R02G2109-001;
// clarifications Q1, Q2): helpers of the interface tests of Binary Gardens (R02-G21) inside the one app, ported from
// `MWSupport` (feature 499). The namespace is `BG` (no other UI test uses `BG`). Binary Gardens was a candidate
// until X-R02-G21 (2026-11-27); every launch still carries `-vcCandidates` (DebugLaunch: the candidates' catalog
// entries become available and are registered; harmless now that it is integrated). A fresh start erases the data (`-vcResetData`, so no level is solved), skips
// the welcome and opens the experience directly with `-openExperience r02-g21.binary-gardens`; a relaunch (`BG.reopen`)
// backgrounds the app first (its save point, the lesson of feature 309), terminates it and starts again without the
// reset, so the stored progress (solved levels, stars, the frontier, the verified winning trace) survives.
//
// The canvas (`session.canvas`) is labelled with the presenter's description (`BinaryGardensPresenter.describe`):
// "Binary Gardens level n. ", the progress (`BinaryGardensLevel.progressDescription`, "<star 1>; <star 2>; tilt t of T
// steps; <worlds>; stars closest at tick …; running now would win|fail…; a actions left") and ". ", then, when won,
// "Every world kept its window and bloomed." (the canvas's own sentence; the spoken announcement of feature 506, "Every
// world kept its light and bloomed. …", is not on screen), then the teaching sentences (the mode, the band, the goal,
// the best stars "Best: s of 3 stars" or "Best: not won yet") and, while the tutorial shows, "Tutorial: <instruction>".
// The controls are found by the identifiers of Clarification Q1 (`port.identifier(name)`, that is
// `experience.r02-g21.binary-gardens.<name>`; `BinaryGardensControls.identifierNames`): the header text `actions`
// ("Level n · a of b actions left"), `status` ("Ready", "Playing", "Won", "Failed: …"), `failure`, `progress`,
// `summary` (labelled "Gardens"), `message`, `preview-refusal`; the tutorial's `tutorial` and `dismiss-tutorial`
// ("Dismiss tutorial", one dismissal ends the tutorial, no action spent); `hint`, `hint-text`, `explanation`, `band`,
// `stars`, `goal`; the segmented star picker `star` ("Star 1" / "Star 2", value `BinaryGardensMirror.starValue`, "star
// k of 2"; presentation only) and `star-detail`; the rows `ring-minus`/`ring`/`ring-plus`,
// `phase-minus`/`phase`/`phase-plus`, `luminosity-minus` ("Luminosity −", `star.luminosity [star, index − 1]`, one
// action) / `luminosity` (value `BinaryGardensMirror.luminosityValue`, "level l of L, luminosity u", ", locked" when the
// level locks the selected star's luminosity) / `luminosity-plus`, `tilt-minus`/`tilt`/`tilt-plus`,
// `tick-minus`/`tick`/`tick-plus`, `run` ("Run", `light.run`, ends the level and spends no action) and `tick-detail`;
// `undo`, `redo`, `next-level` (value "level n + 1" or "no further level open"); `ring-choice`, `luminosity-choice`,
// `phase-target`, `set-phase`, `tilt-choice`, `inspect`, `inspect-detail`, `reset-view`; `mode`, `campaign`, `daily`,
// `practice` (value "selected" or "not selected"); the stepper `level-picker` (labelled "Level to play"; value "Level n,
// band b" plus ", s of 3 stars" when won; never past the open frontier or below 1) and `play-level`; the replay section:
// `replay` ("Replay best solution", value "level n"), `replay-position` ("Replay: action k of n"), `replay-step`
// ("Step", value "Action k of n") and `replay-stop` ("Stop", value "n actions" or "1 action"); the toggle `sound`. A
// level opens with star 1 selected (`BinaryGardensMirror.star` 0). The controls sit below the canvas in a scroll view;
// a control is scrolled into view before it is used, with slow drags near the left edge. Everything lives in the
// namespace `BG`, so that nothing collides with the shared helpers of `AppUITestSupport` or the other experiences.
import Foundation
import XCTest

/// Launch arguments, identifiers, level 1's certified plan and helpers of the R02-G21 interface tests.
enum BG {
    /// One certified action of level 1 in the witness's order (the run follows them).
    enum Step: Equatable {
        /// A luminosity set (`star.luminosity [star, index]`): the star (0 or 1; the panel shows "Star star + 1") and
        /// the luminosity index (0 … levels − 1; the panel shows "level index + 1 of L").
        case luminosity(star: Int, index: Int)
    }

    /// The experience's id in the catalog.
    static let experienceID = "r02-g21.binary-gardens"
    /// The prefix of every identifier of the experience's controls.
    static let prefix = "experience.r02-g21.binary-gardens."
    /// The debug argument that makes the candidates available (DebugLaunch).
    static let candidates = "-vcCandidates"
    /// A first start with erased data, straight into Binary Gardens.
    static let fresh = [VC.reset, VC.skipWelcome, candidates, VC.openExperience, experienceID]
    /// A start over the same storage (no reset), straight into Binary Gardens.
    static let relaunch = [VC.skipWelcome, candidates, VC.openExperience, experienceID]
    /// The longest a single check waits (each test stays under 90 s).
    static let shortWait: TimeInterval = 5
    /// The most drags one reveal makes.
    static let maxDrags = 24
    /// The most taps of a − or + button (or Run) one certified step makes, lost taps included.
    static let maxTaps = 3
    /// The most taps of a star segment that bring the panel to the wanted star, lost taps included.
    static let maxChooseTaps = 3

    // Level 1, pinned here so the interface tests need no Core import (from
    // docs/games/binary-gardens/levels/001.witness.json, read on 2026-11-27, which `BinaryGardensExperienceCore`
    // certifies as level 1; an app unit test checks them against the Core): budget 9; tutorial on; two luminosity
    // levels (19 and 27 units); both stars at luminosity index 1; star 1 locks its ring, phase and luminosity, star 2
    // locks only its phase; tilt locked (T_max 0). The panel opens on star 1. The certified plan is one action,
    // `luminosity(star: 1, index: 0)` (star 2 dimmed one level); the run follows it. A luminosity change spends one
    // action; the star choice and the run spend none. The certified win spends one action (three stars) and the stored
    // trace holds the luminosity change and the run (two actions).

    /// Level 1's luminosity levels in units, by index (`BinaryGardensLevel.luminosityLevels`).
    static let levelOneLuminosityLevels: [Int] = [19, 27]
    /// Level 1's stars' luminosity indices at the start.
    static let levelOneStartLuminosity: [Int] = [1, 1]
    /// Whether level 1 locks each star's luminosity.
    static let levelOneLuminosityLocked: [Bool] = [true, false]
    /// The star the panel opens with (0-based).
    static let openingStar = 0
    /// Level 1's certified actions in the witness's order; the run follows them.
    static let levelOnePlan: [Step] = [.luminosity(star: 1, index: 0)]
    /// Level 1's action budget.
    static let levelOneBudget = 9
    /// The number of level 1's certified actions (each spends an action; the run spends none).
    static var certifiedActionCount: Int { levelOnePlan.count }
    /// The length of the trace stored by the certified win (the actions and the run).
    static var levelOneTraceLength: Int { levelOnePlan.count + 1 }

    /// The canvas phrase of a fresh level 1's budget (nothing spent).
    static let fullBudget = "; 9 actions left"
    /// The canvas phrase of a won level (`BinaryGardensPresenter.describe`).
    static let won = "Every world kept its window and bloomed."
    /// The `stars` text (and canvas sentence) of a level won with all three stars.
    static let threeStars = "Best: 3 of 3 stars"
    /// The canvas phrase while the tutorial shows.
    static let tutorial = " Tutorial: "
    /// The level picker's value of level 1 once it is won with three stars (band 1).
    static let levelOneThreeStars = "Level 1, band 1, 3 of 3 stars"

    /// The full identifier of the control `name`.
    static func id(_ name: String) -> String { prefix + name }

    /// The `star` control's value of star `star` (0 or 1; `BinaryGardensMirror.starValue`, "star k of 2").
    static func starValue(_ star: Int) -> String { "star \(star + 1) of 2" }

    /// The `luminosity` control's value of level 1's star `star` at luminosity `index`
    /// (`BinaryGardensMirror.luminosityValue`, "level l of 2, luminosity u", ", locked" when level 1 locks it).
    static func luminosityValue(star: Int, index: Int) -> String {
        let count = levelOneLuminosityLevels.count, units = levelOneLuminosityLevels[index]
        let words = "level \(index + 1) of \(count), luminosity \(units)"
        return levelOneLuminosityLocked[star] ? words + ", locked" : words
    }

    /// The luminosity index (0-based) of a `luminosity` value "level l of L, …", or nil.
    static func luminosityIndex(_ text: String) -> Int? {
        guard text.hasPrefix("level ") else { return nil }
        let digits = text.dropFirst("level ".count).prefix { $0.isASCII && $0.isNumber }
        guard !digits.isEmpty, let level = Int(digits),
              text.dropFirst("level ".count + digits.count).hasPrefix(" of ") else { return nil }
        return level - 1
    }

    /// The star (0-based) of a `star` value "star k of 2", or nil.
    static func starIndex(_ text: String) -> Int? {
        guard text.hasPrefix("star "), text.hasSuffix(" of 2") else { return nil }
        let middle = text.dropFirst("star ".count).dropLast(" of 2".count)
        guard !middle.isEmpty, middle.allSatisfy({ $0.isASCII && $0.isNumber }), let k = Int(middle) else {
            return nil
        }
        return k - 1
    }

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

    /// Launches the app with `arguments` and waits until Binary Gardens runs.
    @MainActor
    @discardableResult
    static func open(arguments: [String] = BG.fresh, file: StaticString = #filePath, line: UInt = #line)
        -> XCUIApplication {
        let app = launchApp(arguments: arguments)
        waitForRunning(app, file: file, line: line)
        return app
    }

    /// Backgrounds `app` (its save point), ends it and opens Binary Gardens again over the same storage
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
        let second = launchApp(arguments: BG.relaunch)
        waitForRunning(second, file: file, line: line)
        return second
    }

    /// Waits for the experience route, the canvas labelled with a level and the level picker.
    @MainActor
    private static func waitForRunning(_ app: XCUIApplication, file: StaticString, line: UInt) {
        waitFor(element(app, "vc.route.experience"), timeout: VC.firstWait, file: file, line: line)
        waitFor(canvas(app), timeout: VC.firstWait, file: file, line: line)
        waitFor(control(app, "level-picker"), timeout: VC.wait, "the level picker is there", file: file, line: line)
        XCTAssertTrue(waitForLabel(canvas(app)) { $0.contains("Binary Gardens level") },
                      "the canvas is labelled with a level: \(description(app))", file: file, line: line)
    }

    /// Taps `dismiss-tutorial` when the tutorial shows it (a fresh start of level 1 does); nothing otherwise. One
    /// dismissal ends the tutorial (`tutorial.dismiss`); it spends no action.
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

    /// The star picker (`star`): the segmented control with the identifier when there is one (the segments may
    /// inherit the identifier, so the segmented control is looked up first), else the control of any type.
    @MainActor
    static func starPicker(_ app: XCUIApplication) -> XCUIElement {
        let found = app.segmentedControls.matching(identifier: id("star")).firstMatch
        return found.exists ? found : control(app, "star")
    }

    /// The star the panel edits, read from the star picker's value ("star k of 2"), or nil.
    @MainActor
    static func selectedStar(_ app: XCUIApplication) -> Int? {
        starIndex(starPicker(app).value as? String ?? "")
    }

    /// Brings the panel to star `star` (0 or 1) with the segmented star picker (presentation only, no action spent):
    /// the picker's value ("star k of 2") is read before each tap, and a tap counts only when the value moves; a lost
    /// tap is retried within ``maxChooseTaps`` taps (the segment titled "Star k" when it can be tapped, else its place
    /// on the control, the two segments sharing the width). True when the picker reads `star`.
    @MainActor
    @discardableResult
    static func chooseStar(_ app: XCUIApplication, _ star: Int, file: StaticString = #filePath, line: UInt = #line)
        -> Bool {
        let picker = starPicker(app)
        guard picker.exists || waitFor(picker, timeout: shortWait, "the star picker is there", file: file, line: line),
              reveal(app, picker, file: file, line: line) else { return false }
        guard selectedStar(app) != nil else {
            XCTFail("the star cannot be read: '\(picker.value as? String ?? "")'", file: file, line: line)
            return false
        }
        let budget: Int = actionsLeft(actionsText(app)) ?? -1
        let title = "Star \(star + 1)"
        var taps = 0
        while selectedStar(app) != star, taps < maxChooseTaps {
            let before = picker.value as? String ?? ""
            // The picker carries an adjustable action (feature 506), so VoiceOver-style increment and decrement move it;
            // a segment tap is the fallback when the element is not adjustable.
            let appSegment = app.segmentedControls.buttons[title].firstMatch
            let anyButton = app.buttons[title].firstMatch
            if appSegment.exists && appSegment.isHittable {
                appSegment.press(forDuration: 0.15)
            } else if anyButton.exists && anyButton.isHittable {
                anyButton.tap()
            } else {
                let segment = picker.buttons.matching(NSPredicate(format: "label ==[c] %@", title)).firstMatch
                if segment.exists && segment.isHittable {
                    segment.tap()
                } else {
                    picker.coordinate(withNormalizedOffset: CGVector(dx: (CGFloat(star) + 0.5) / 2, dy: 0.5)).tap()
                }
            }
            taps += 1
            _ = waitForValue(picker, timeout: shortWait) { $0 != before }
        }
        if selectedStar(app) != star {
            let tree: String = picker.debugDescription.replacingOccurrences(of: "\n", with: " | ")
            let lum: String = app.descendants(matching: .any)["experience.r02-g21.binary-gardens.luminosity"]
                .firstMatch.value as? String ?? "?"
            let detail: String = app.descendants(matching: .any)["experience.r02-g21.binary-gardens.star-detail"]
                .firstMatch.label
            let segment2 = picker.buttons["Star 2"].firstMatch
            XCTFail("BG star after taps: value=\(picker.value as? String ?? "") detail=\(detail) luminosity=\(lum) "
                    + "segment2 selected=\(segment2.isSelected) hittable=\(segment2.isHittable) "
                    + "frame=\(segment2.frame) tree=\(tree.prefix(200))", file: file, line: line)
        }
        XCTAssertEqual(picker.value as? String ?? "", starValue(star),
                       "star \(star + 1) is chosen in \(taps) taps", file: file, line: line)
        XCTAssertEqual(actionsLeft(actionsText(app)) ?? -1, budget, "choosing the star spends no action",
                       file: file, line: line)
        return selectedStar(app) == star
    }

    /// Taps `target` until the header's `actions` text changes, within ``maxTaps`` taps: the text is read before and
    /// after each tap, and the press counts only when the text changes with the actions left down by one; a lost tap
    /// (the text and `moved` both unchanged) is retried. True when the action was spent exactly once.
    @MainActor
    private static func spendOne(_ app: XCUIApplication, _ target: XCUIElement, _ what: String,
                                 moved: () -> Bool, file: StaticString, line: UInt) -> Bool {
        let header = control(app, "actions")
        let beforeText = actionsText(app)
        guard let before = actionsLeft(beforeText) else {
            XCTFail("the actions line cannot be read: \(beforeText)", file: file, line: line)
            return false
        }
        var taps = 0
        var afterText = beforeText
        // A tap whose effect already shows elsewhere (`moved`) is never repeated: a second tap would spend again.
        while afterText == beforeText, !moved(), taps < maxTaps {
            target.tap()
            taps += 1
            _ = waitForLabel(header, timeout: shortWait) { $0 != beforeText }
            afterText = actionsText(app)
        }
        if afterText == beforeText {
            _ = waitForLabel(header, timeout: shortWait) { $0 != beforeText }
            afterText = actionsText(app)
        }
        let after = actionsLeft(afterText) ?? before
        let spent = after == before - 1
        XCTAssertTrue(spent, "\(what) spends one action: \(before) → \(after) in \(taps) taps (\(afterText)); "
                      + "message '\(text(app, "message"))'", file: file, line: line)
        return spent
    }

    /// Sets one pinned luminosity with the panel: star `star` is chosen (read from the star picker's value), the
    /// `luminosity` value is read, then Luminosity − (or +) is pressed once per level, each press counting only when the
    /// header's `actions` text moves with the actions left down by one (a lost tap is retried within ``maxTaps`` taps,
    /// never once the `luminosity` value moved). True when every press was spent exactly once and the value reads
    /// `index`.
    @MainActor
    @discardableResult
    static func setLuminosity(_ app: XCUIApplication, star: Int, index: Int,
                              file: StaticString = #filePath, line: UInt = #line) -> Bool {
        guard chooseStar(app, star, file: file, line: line) else { return false }
        let reading = control(app, "luminosity")
        guard reading.exists || waitFor(reading, timeout: shortWait, "luminosity is there", file: file, line: line),
              var current = luminosityIndex(value(app, "luminosity")) else {
            XCTFail("the luminosity cannot be read: '\(value(app, "luminosity"))'", file: file, line: line)
            return false
        }
        XCTAssertEqual(value(app, "luminosity"), luminosityValue(star: star, index: current),
                       "the luminosity reads star \(star + 1)'s level", file: file, line: line)
        var presses = 0
        while current != index, presses < levelOneLuminosityLevels.count {
            let name = index < current ? "luminosity-minus" : "luminosity-plus"
            guard let button = shown(app, name, file: file, line: line) else { return false }
            let words = value(app, "luminosity")
            let spent = spendOne(app, button, name == "luminosity-minus" ? "Luminosity −" : "Luminosity +",
                                 moved: { value(app, "luminosity") != words }, file: file, line: line)
            presses += 1
            _ = waitForValue(reading, timeout: shortWait) { $0 != words }
            guard spent, let next = luminosityIndex(value(app, "luminosity")) else { return false }
            current = next
        }
        // The star stays selected while the action is spent (the change goes to the selected star).
        XCTAssertEqual(selectedStar(app), star, "star \(star + 1) stays selected", file: file, line: line)
        let reads = value(app, "luminosity") == luminosityValue(star: star, index: index)
        XCTAssertTrue(reads, "the luminosity reads '\(luminosityValue(star: star, index: index))': "
                      + "'\(value(app, "luminosity"))'", file: file, line: line)
        return reads
    }

    /// Taps Run (`light.run`, no action spent) until the `status` text reports the level ended ("Won" or "Failed: …"),
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

    /// Plays level 1's certified plan (``levelOnePlan``, then the run) with the panel, in order. Run is pressed only
    /// once every certified action shows in the actions count. True when every action was spent exactly once and the
    /// run won.
    @MainActor
    @discardableResult
    static func playLevelOneSolution(_ app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line)
        -> Bool {
        for step in levelOnePlan {
            switch step {
            case .luminosity(let star, let index):
                guard setLuminosity(app, star: star, index: index, file: file, line: line) else { return false }
            }
        }
        XCTAssertEqual(actionsLeft(actionsText(app)), levelOneBudget - certifiedActionCount,
                       "every certified action shows in the actions count before Run", file: file, line: line)
        return run(app, file: file, line: line)
    }

    /// A fresh start, the tutorial dismissed and level 1 won with its certified plan; returns the app after the canvas
    /// reports every world bloomed and the `stars` text reads three stars.
    @MainActor
    @discardableResult
    static func winLevelOne(file: StaticString = #filePath, line: UInt = #line) -> XCUIApplication {
        let app = open(arguments: fresh, file: file, line: line)
        XCTAssertTrue(description(app).contains("Binary Gardens level 1."),
                      "a fresh start opens level 1: \(description(app))", file: file, line: line)
        XCTAssertTrue(!description(app).contains(won) && description(app).contains(fullBudget),
                      "level 1 starts not won and with its budget whole: \(description(app))",
                      file: file, line: line)
        XCTAssertEqual(actionsText(app), "Level 1 · \(levelOneBudget) of \(levelOneBudget) actions left",
                       "the header shows level 1's whole budget", file: file, line: line)
        XCTAssertEqual(selectedStar(app), openingStar, "level 1 opens on star 1", file: file, line: line)
        XCTAssertEqual(value(app, "luminosity"),
                       luminosityValue(star: openingStar, index: levelOneStartLuminosity[openingStar]),
                       "level 1 opens with star 1's luminosity", file: file, line: line)
        XCTAssertTrue(description(app).contains(tutorial), "level 1 shows the tutorial: \(description(app))",
                      file: file, line: line)
        dismissTutorialIfShown(app, file: file, line: line)
        XCTAssertTrue(playLevelOneSolution(app, file: file, line: line), "the solution is played",
                      file: file, line: line)
        XCTAssertTrue(waitForDescription(app, timeout: VC.wait) { $0.contains(won) },
                      "the canvas reports every world bloomed: \(description(app))", file: file, line: line)
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
    static func waitForLabel(_ target: XCUIElement, timeout: TimeInterval = BG.shortWait,
                             _ condition: (String) -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while !(target.exists && condition(target.label)), Date() < deadline { usleep(200_000) }
        return target.exists && condition(target.label)
    }

    /// Waits until the value of `target` (as text) satisfies `condition`; true when it does.
    @MainActor
    static func waitForValue(_ target: XCUIElement, timeout: TimeInterval = BG.shortWait,
                             _ condition: (String) -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        func current() -> String { target.exists ? (target.value as? String ?? "") : "" }
        while !(target.exists && condition(current())), Date() < deadline { usleep(200_000) }
        return target.exists && condition(current())
    }

    /// Waits until the canvas description satisfies `condition`; true when it does.
    @MainActor
    static func waitForDescription(_ app: XCUIApplication, timeout: TimeInterval = BG.shortWait,
                                   _ condition: (String) -> Bool) -> Bool {
        waitForLabel(canvas(app), timeout: timeout, condition)
    }
}
