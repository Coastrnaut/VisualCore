// HCSupport — feature 339 (R02-G04-09) T-R02G0409-004 (FR-R02G0409-001, 002; clarifications Q1, Q2): helpers of the
// interface tests of Hue Compass (R02-G04) inside the one app, modelled on `WKSupport`. Hue Compass was a candidate until
// X-R02-G04 (2026-11-21); every launch still carries `-vcCandidates` (DebugLaunch: the candidates' catalog entries become available and are
// registered). A fresh start erases the data (`-vcResetData`, so no level is solved), skips the welcome and opens the
// experience directly with `-openExperience r02-g04.hue-compass`; a relaunch (`HC.reopen`) backgrounds the app first
// (its save point), terminates it and starts again without the reset, so the stored progress (solved levels, stars,
// open levels, the verified winning trace) survives.
//
// The canvas (`session.canvas`) is labelled with the presenter's description (`HueCompassPresenter.describe`):
// "Hue Compass level n. ", the needle's bearing and hue band, the fog, the last clue, "Units k of m. " and, when won,
// "The bearing and hue match." followed in campaign and daily mode by " s of 3 stars." (none in practice or replay).
// The controls are found by the identifiers of `HueCompassControls.identifierNames` (`port.identifier(name)`, that is
// `experience.r02-g04.hue-compass.<name>`): the turn buttons `turn-minus-4`, `turn-minus-1`, `turn-plus-1`,
// `turn-plus-4` (each sends `compass.turn [±4 or ±1]`, spends nothing; value "Bearing b of 96"), `probe`, the stepper
// `band-picker` (value "band k of 24", 1-based; increment picks the next band, decrement the previous, both wrapping;
// presentation only, it sends no action), `select` (sends the needle's current bearing with the picked band; value
// "Bearing b, band k"), `undo`, `redo`, `next-level`, `reset-view`, `hint`, `dismiss-tutorial`, `retry`, `campaign`,
// `daily`, `practice`, `replay` (when the level has a verified recorded solution, not during replay), `replay-step`
// (value "Action k of n") and `replay-stop`, the level menu `level-picker` (value "Level l; levels 1 to n open"; its
// items are buttons "Level 1" or "Level 1 · 3 stars"), the toggle `sound` and the element `summary`. The controls sit
// below the canvas in a scroll view; a control is scrolled into view before it is used, with slow drags near the left
// edge. Everything lives in the namespace `HC`, so that nothing collides with the shared helpers of `AppUITestSupport`
// or the other experiences.
import Foundation
import XCTest

/// Launch arguments, identifiers, level 1's certified witness and helpers of the R02-G04 interface tests.
enum HC {
    /// The experience's id in the catalog.
    static let experienceID = "r02-g04.hue-compass"
    /// The prefix of every identifier of the experience's controls.
    static let prefix = "experience.r02-g04.hue-compass."
    /// The debug argument that makes the candidates available (DebugLaunch).
    static let candidates = "-vcCandidates"
    /// A first start with erased data, straight into Hue Compass.
    static let fresh = [VC.reset, VC.skipWelcome, candidates, VC.openExperience, experienceID]
    /// A start over the same storage (no reset), straight into Hue Compass.
    static let relaunch = [VC.skipWelcome, candidates, VC.openExperience, experienceID]
    /// The longest a single check waits (each test stays under 90 s).
    static let shortWait: TimeInterval = 5
    /// The most drags one reveal makes.
    static let maxDrags = 24
    /// The number of bearings round the compass (`HueCompassWheel.bearings`).
    static let bearings = 96
    /// The number of hue bands (`HueCompassWheel.bands`).
    static let bands = 24

    /// One action of a certified witness (`HueCompassAction`): a turn of n bearings (positive: counter-clockwise), a
    /// probe at the needle, or the selection of a bearing with a 0-based band.
    enum Action: Equatable {
        case turn(Int)
        case probe
        case select(bearing: Int, band: Int)
    }

    // Level 1, pinned here so the interface tests need no Core import. An app unit test (AppModelTests, T-R02G0409-005)
    // checks these values against `HueCompassExperienceCore.generated(number: 1)` (its level's start, target, target
    // band, bearing and band tolerances, allowance; its solution's smallest probe count) and against
    // `HueCompassWitness.actions(for:level:)`, so a change of level 1 fails there first. Read 2026-11-21 from the
    // committed witness docs/games/hue-compass/levels/001.witness.json (level.start, level.target, level.offset,
    // level.bearingTolerance, level.bandTolerance, level.allowance, difficulty.smallest, actions); the target band is
    // `HueCompassWheel.band(of: 88, offset: 14)` = (⌊88/4⌋ + 14) mod 24 = 12.

    /// Level 1's start bearing.
    static let levelOneStart = 35
    /// Level 1's hidden target bearing.
    static let levelOneTarget = 88
    /// Level 1's hue offset.
    static let levelOneOffset = 14
    /// Level 1's target band (0-based).
    static let levelOneTargetBand = 12
    /// Level 1's bearing tolerance.
    static let levelOneBearingTolerance = 4
    /// Level 1's band tolerance.
    static let levelOneBandTolerance = 2
    /// Level 1's allowance in units (probes and the selection).
    static let levelOneAllowance = 9
    /// Level 1's certified smallest probe count.
    static let levelOneSmallest = 1
    /// Level 1's certified probe bearings, in order (`HueCompassSolution.probes`).
    static let levelOneProbes: [Int] = [8]
    /// Level 1's certified witness actions: turn 27 bearings clockwise (35 → 8), probe, select bearing 84 with band 10.
    static let levelOneWitnessActions: [Action] = [.turn(-27), .probe, .select(bearing: 84, band: 10)]

    /// The canvas phrase of a won level.
    static let matches = "The bearing and hue match."
    /// The canvas phrase of a level won with all three stars.
    static let threeStars = "3 of 3 stars"
    /// The part of the level menu's value once level 1 is solved.
    static let levelTwoOpen = "levels 1 to 2 open"

    /// The signed shortest turn from `from` to `to`, −47 … 48 (`HueCompassWitness.shortestTurn`).
    static func shortestTurn(from: Int, to: Int) -> Int {
        let d = ((to - from) % bearings + bearings) % bearings
        return d <= bearings / 2 ? d : d - bearings
    }

    /// The turn buttons the panel presses for a turn of `k` bearings: ⌊|k|/4⌋ presses of ±4, then |k| mod 4 presses
    /// of ±1, each with the sign of `k` (as `HueCompassPanelWinTests.panelTurns`).
    static func turnPresses(_ k: Int) -> [String] {
        let four = k < 0 ? "turn-minus-4" : "turn-plus-4"
        let one = k < 0 ? "turn-minus-1" : "turn-plus-1"
        return Array(repeating: four, count: abs(k) / 4) + Array(repeating: one, count: abs(k) % 4)
    }

    /// The turns the panel needs for level 1's witness: each witness turn, and before the selection the shortest turn
    /// from the needle to the selection's bearing (the panel's Select sends the needle's bearing). A turn of 0 is
    /// omitted.
    static func levelOnePanelTurns() -> [Action] {
        var bearing = levelOneStart
        var result: [Action] = []
        for action in levelOneWitnessActions {
            switch action {
            case .turn(let k):
                bearing = ((bearing + k) % bearings + bearings) % bearings
                result.append(action)
            case .probe:
                result.append(action)
            case .select(let target, _):
                let k = shortestTurn(from: bearing, to: target)
                if k != 0 { result.append(.turn(k)) }
                bearing = target
                result.append(action)
            }
        }
        return result
    }

    /// The length of the winning trace the panel records for level 1: one action per turn press, probe and selection
    /// (`HueCompassExperienceCore.winningTrace`).
    static var levelOneTraceLength: Int {
        var count = 0
        for action in levelOnePanelTurns() {
            if case .turn(let k) = action { count += turnPresses(k).count } else { count += 1 }
        }
        return count
    }

    /// The units level 1's witness spends (its probes and the selection).
    static var levelOneUnits: Int {
        var units = 0
        for action in levelOneWitnessActions {
            if case .turn = action { continue }
            units += 1
        }
        return units
    }

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

    /// Launches the app with `arguments` and waits until Hue Compass runs.
    @MainActor
    @discardableResult
    static func open(arguments: [String] = HC.fresh, file: StaticString = #filePath, line: UInt = #line)
        -> XCUIApplication {
        let app = launchApp(arguments: arguments)
        waitForRunning(app, file: file, line: line)
        return app
    }

    /// Backgrounds `app` (its save point), ends it and opens Hue Compass again over the same storage (``relaunch``,
    /// no reset).
    @MainActor
    @discardableResult
    static func reopen(_ app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line)
        -> XCUIApplication {
        // Backgrounding is the app's save point for the open experience's state (as PersistenceUITests ends a run);
        // a bare terminate would lose the win.
        XCUIDevice.shared.press(.home)
        usleep(1_000_000)
        app.terminate()
        let second = launchApp(arguments: HC.relaunch)
        waitForRunning(second, file: file, line: line)
        return second
    }

    /// Waits for the experience route, the canvas labelled with a level and the level menu.
    @MainActor
    private static func waitForRunning(_ app: XCUIApplication, file: StaticString, line: UInt) {
        waitFor(element(app, "vc.route.experience"), timeout: VC.firstWait, file: file, line: line)
        waitFor(canvas(app), timeout: VC.firstWait, file: file, line: line)
        waitFor(control(app, "level-picker"), timeout: VC.wait, "the level menu is there", file: file, line: line)
        XCTAssertTrue(waitForLabel(canvas(app)) { $0.hasPrefix("Hue Compass level") },
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
        while drags < maxDrags, target.exists, !isShown(app, target) {
            let list = controlsList(app)
            let middle = list.exists ? list.frame.midY : app.windows.firstMatch.frame.midY
            var distance = target.frame.midY - middle
            if abs(distance) < 1 { distance = 40 }
            drag(app, by: distance)
            drags += 1
        }
        let found = isShown(app, target)
        XCTAssertTrue(found, "not reached by scrolling the controls: \(target)", file: file, line: line)
        return found
    }

    /// Waits for the control `name`, scrolls it into view and returns it, or nil when it is not there.
    @MainActor
    static func shown(_ app: XCUIApplication, _ name: String, file: StaticString = #filePath, line: UInt = #line)
        -> XCUIElement? {
        let target = control(app, name)
        // An element already present skips the bounded wait, whose first check costs about a second (feature 339:
        // the 90 s per-test bound includes about 24 s of app teardown).
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

    /// The bearing a turn button's value "Bearing b of 96" shows, or nil.
    static func bearing(_ text: String) -> Int? {
        guard text.hasPrefix("Bearing "), text.hasSuffix(" of \(bearings)") else { return nil }
        return Int(text.dropFirst("Bearing ".count).dropLast(" of \(bearings)".count))
    }

    /// Turns the needle by `k` bearings with the turn buttons (⌊|k|/4⌋ presses of ±4, then |k| mod 4 of ±1) and waits
    /// until the turn buttons show the bearing `expected`. True when they do.
    @MainActor
    @discardableResult
    static func turn(_ app: XCUIApplication, by k: Int, expecting expected: Int,
                     file: StaticString = #filePath, line: UInt = #line) -> Bool {
        var current: XCUIElement?
        var currentName = ""
        for name in turnPresses(k) {
            if name != currentName {
                guard let target = shown(app, name, file: file, line: line) else { return false }
                current = target
                currentName = name
            }
            current?.tap()
        }
        let check = control(app, "turn-plus-1")
        let reached = waitForValue(check) { bearing($0) == expected }
        XCTAssertTrue(reached, "the needle points to bearing \(expected) (now \(value(app, "turn-plus-1")))",
                      file: file, line: line)
        return reached
    }

    /// The band picker: the system stepper with the identifier when there is one, else the control of any type.
    @MainActor
    static func picker(_ app: XCUIApplication) -> XCUIElement {
        let stepper = app.steppers.matching(identifier: id("band-picker")).firstMatch
        return stepper.exists ? stepper : control(app, "band-picker")
    }

    /// The 0-based band of a picker value "band k of 24" (k 1-based), or nil.
    static func pickedBand(_ text: String) -> Int? {
        let lower = text.lowercased()
        guard lower.hasPrefix("band ") else { return nil }
        let parts = lower.dropFirst("band ".count).components(separatedBy: " of ")
        guard parts.count == 2, let k = Int(parts[0].trimmingCharacters(in: .whitespaces)),
              Int(parts[1].trimmingCharacters(in: .whitespaces)) == bands, (1...bands).contains(k) else { return nil }
        return k - 1
    }

    /// The increment (`up`) or decrement button of the band picker: the inner button whose label or identifier names
    /// it, else a button with the suffixed identifier, else nil (the caller taps the end of the row).
    @MainActor
    static func pickerButton(_ app: XCUIApplication, up: Bool) -> XCUIElement? {
        let word = up ? "Increment" : "Decrement"
        let inner = picker(app).buttons
            .matching(NSPredicate(format: "label CONTAINS[c] %@ OR identifier CONTAINS[c] %@", word, word)).firstMatch
        if inner.exists { return inner }
        let suffixed = element(app, id("band-picker") + "-" + word)
        return suffixed.exists ? suffixed : nil
    }

    /// Picks band `target` (0-based) with the band picker by the shorter way round the wrap: reveals it once, presses
    /// increment or decrement the computed number of times (a pick sends no action) and reads the value once at the
    /// end. True when it shows `target`.
    @MainActor
    @discardableResult
    static func pickBand(_ app: XCUIApplication, _ target: Int,
                         file: StaticString = #filePath, line: UInt = #line) -> Bool {
        let control = picker(app)
        guard control.exists || waitFor(control, timeout: shortWait, "band-picker is there", file: file, line: line),
              reveal(app, control, file: file, line: line),
              let start = pickedBand(control.value as? String ?? "") else {
            XCTFail("band-picker shows no band (value \(value(app, "band-picker")))", file: file, line: line)
            return false
        }
        let ups = ((target - start) % bands + bands) % bands
        let up = ups <= bands / 2
        let presses = up ? ups : bands - ups
        let button = pickerButton(app, up: up)
        for _ in 0..<presses {
            if let button { button.tap() } else {
                control.coordinate(withNormalizedOffset: CGVector(dx: up ? 0.95 : 0.8, dy: 0.5)).tap()
            }
        }
        let reached = waitForValue(control, timeout: shortWait) { pickedBand($0) == target }
        XCTAssertTrue(reached, "band-picker shows band \(target + 1) (now \(value(app, "band-picker")))",
                      file: file, line: line)
        return reached
    }

    /// Plays level 1's certified witness with the panel: each turn with the turn buttons, each probe with Probe, and
    /// the selection by turning the needle to its bearing, picking its band and tapping Select. True when every
    /// control was used and showed what it should.
    @MainActor
    @discardableResult
    static func playLevelOneWitness(_ app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line)
        -> Bool {
        var bearing = levelOneStart
        var probes = 0
        for action in levelOnePanelTurns() {
            switch action {
            case .turn(let k):
                bearing = ((bearing + k) % bearings + bearings) % bearings
                guard turn(app, by: k, expecting: bearing, file: file, line: line) else { return false }
            case .probe:
                guard tap(app, "probe", file: file, line: line) else { return false }
                probes += 1
                let units = "Units \(probes) of \(levelOneAllowance)."
                XCTAssertTrue(waitForDescription(app) { $0.contains(units) },
                              "the probe spent one unit: \(description(app))", file: file, line: line)
            case .select(let selected, let band):
                XCTAssertEqual(bearing, selected, "the needle is at the selection's bearing", file: file, line: line)
                guard pickBand(app, band, file: file, line: line) else { return false }
                let expected = "Bearing \(selected), band \(band + 1)"
                XCTAssertTrue(waitForValue(control(app, "select")) { $0 == expected },
                              "Select holds \(expected) (now \(value(app, "select")))", file: file, line: line)
                guard tap(app, "select", file: file, line: line) else { return false }
            }
        }
        return true
    }

    /// A fresh start, the tutorial dismissed and level 1 won with its certified witness; returns the app after the
    /// canvas reports the match with all three stars.
    @MainActor
    @discardableResult
    static func winLevelOne(file: StaticString = #filePath, line: UInt = #line) -> XCUIApplication {
        let app = open(arguments: fresh, file: file, line: line)
        XCTAssertTrue(description(app).hasPrefix("Hue Compass level 1."),
                      "a fresh start opens level 1: \(description(app))", file: file, line: line)
        XCTAssertTrue(description(app).contains("bearing \(levelOneStart) of \(bearings)"),
                      "level 1 starts at its start bearing: \(description(app))", file: file, line: line)
        dismissTutorialIfShown(app, file: file, line: line)
        XCTAssertTrue(playLevelOneWitness(app, file: file, line: line), "the witness is played",
                      file: file, line: line)
        XCTAssertTrue(waitForDescription(app) { $0.contains(matches) && $0.contains(threeStars) },
                      "the canvas reports the match with three stars: \(description(app))",
                      file: file, line: line)
        return app
    }

    /// Opens the level menu `level-picker` and reports whether it offers an item labelled `label`.
    @MainActor
    static func menuOffers(_ app: XCUIApplication, _ label: String,
                           file: StaticString = #filePath, line: UInt = #line) -> Bool {
        guard tap(app, "level-picker", file: file, line: line) else { return false }
        let item = app.buttons.matching(NSPredicate(format: "label == %@", label)).firstMatch
        return item.waitForExistence(timeout: shortWait)
    }

    /// The position and length of a replay step value "Action k of n", or nil.
    static func replayPosition(_ text: String) -> (position: Int, length: Int)? {
        guard text.hasPrefix("Action ") else { return nil }
        let parts = text.dropFirst("Action ".count).components(separatedBy: " of ")
        guard parts.count == 2, let k = Int(parts[0]), let n = Int(parts[1]) else { return nil }
        return (k, n)
    }

    /// Waits until the label of `target` satisfies `condition`; true when it does.
    @MainActor
    static func waitForLabel(_ target: XCUIElement, timeout: TimeInterval = HC.shortWait,
                             _ condition: (String) -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while !(target.exists && condition(target.label)), Date() < deadline { usleep(200_000) }
        return target.exists && condition(target.label)
    }

    /// Waits until the value of `target` (as text) satisfies `condition`; true when it does.
    @MainActor
    static func waitForValue(_ target: XCUIElement, timeout: TimeInterval = HC.shortWait,
                             _ condition: (String) -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        func current() -> String { target.exists ? (target.value as? String ?? "") : "" }
        while !(target.exists && condition(current())), Date() < deadline { usleep(200_000) }
        return target.exists && condition(current())
    }

    /// Waits until the canvas description satisfies `condition`; true when it does.
    @MainActor
    static func waitForDescription(_ app: XCUIApplication, timeout: TimeInterval = HC.shortWait,
                                   _ condition: (String) -> Bool) -> Bool {
        waitForLabel(canvas(app), timeout: timeout, condition)
    }
}
