// NASupport — feature 078 (A10-P04) T-A10-404 (FR-A10-422; SC-A10-405): helpers of the interface tests of Neon Arcade
// (A10) inside the one app, modelled on `DASupport`. A10 was a candidate until X-A10 (integrated 2026-11-15);
// every launch still carries `-vcCandidates`, and the tests open it directly with `-openExperience`. The controls are found by the identifiers of `ArcadeControls`
// (`port.identifier(name)`, that is `experience.a10.neon-arcade.<name>`): Start / Play again (`run.start`), the hold
// buttons Steer left and Steer right (`run.left`, `run.right`), Straight (`run.straight`), the Pause toggle
// (`run.pause`, values "Playing"/"Paused"), Restart (`run.restart`), the Sound and Haptics toggles
// (`settings.sound`, `settings.haptics`), the status line (`run.status`), the sensitivity control
// (`settings.sensitivity`, five steps, default 2) and the best-score text (`scores.best`). They sit below the canvas in
// a scroll view of limited height, so a control is scrolled into view before it is used. The canvas label is the
// presenter's description ("Neon Arcade: Neon Dodge, wave 1, score 0, 3 lives, no objects falling, title screen.").
// Everything lives in the namespace `NA`, so that nothing collides with the shared helpers of `AppUITestSupport` or the
// other experiences.
import Foundation
import XCTest

/// Launch arguments, identifiers and helpers of the A10 interface tests.
enum NA {
    /// The experience's id in the catalog.
    static let experienceID = "a10.neon-arcade"
    /// The prefix of every identifier of the experience's controls.
    static let prefix = "experience.a10.neon-arcade."
    /// The prefix of the canvas description.
    static let describedPrefix = "Neon Arcade: "
    /// The debug argument that makes the candidates available (DebugLaunch).
    static let candidates = "-vcCandidates"
    /// A first start with erased data, straight into A10.
    static let fresh = [VC.reset, VC.skipWelcome, candidates, VC.openExperience, experienceID]
    /// The longest a single check waits (each test stays well under 60 s).
    static let shortWait: TimeInterval = 5

    /// The full identifier of the control `name`.
    static func id(_ name: String) -> String { prefix + name }

    /// The control `name` of A10, of any element type.
    @MainActor
    static func control(_ app: XCUIApplication, _ name: String) -> XCUIElement {
        element(app, id(name))
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

    /// The spoken value of the control `name` (a toggle's state, the sensitivity step), or "" when it has none.
    @MainActor
    static func value(_ app: XCUIApplication, _ name: String) -> String {
        control(app, name).value as? String ?? ""
    }

    /// Launches the app with `arguments` and waits until A10 runs: the experience route, its canvas described and its
    /// Start button (a fresh start shows the title screen).
    @MainActor
    @discardableResult
    static func open(arguments: [String] = NA.fresh, file: StaticString = #filePath, line: UInt = #line)
        -> XCUIApplication {
        let app = launchApp(arguments: arguments)
        waitFor(element(app, "vc.route.experience"), timeout: VC.firstWait, file: file, line: line)
        waitFor(canvas(app), timeout: VC.firstWait, file: file, line: line)
        waitFor(control(app, "run.start"), timeout: VC.wait, file: file, line: line)
        XCTAssertTrue(waitForLabel(canvas(app)) { $0.hasPrefix(describedPrefix) },
                      "the canvas is described: \(description(app))", file: file, line: line)
        return app
    }

    /// Opens A10 and starts a run: Start, then the description says "playing".
    @MainActor
    @discardableResult
    static func openAndStart(file: StaticString = #filePath, line: UInt = #line) -> XCUIApplication {
        let app = open(file: file, line: line)
        XCTAssertTrue(waitForDescription(app) { $0.contains("title screen") },
                      "a fresh start shows the title screen: \(description(app))", file: file, line: line)
        tap(app, "run.start", upFirst: true, file: file, line: line)
        XCTAssertTrue(waitForDescription(app) { NA.isPlaying($0) },
                      "Start begins a run: \(description(app))", file: file, line: line)
        return app
    }

    /// Whether the description `text` names the playing screen (", playing"; the best score may follow it).
    static func isPlaying(_ text: String) -> Bool { text.contains(", playing") }

    /// Whether the description `text` names the paused screen.
    static func isPaused(_ text: String) -> Bool { text.contains(", paused") }

    /// The scroll view that holds the controls below the canvas.
    @MainActor
    static func controlsList(_ app: XCUIApplication) -> XCUIElement {
        app.scrollViews.containing(NSPredicate(format: "identifier BEGINSWITH %@", prefix)).firstMatch
    }

    /// One short, slow drag on the controls near their left edge (inside the padding, so that no button takes the
    /// touch): about half the list's height with a hold at the end, so the list moves by the drag's length without a
    /// fling (the lesson of feature 066). `forward` moves the finger up, which shows the controls further down.
    @MainActor
    static func drag(_ app: XCUIApplication, forward: Bool) {
        let list = controlsList(app)
        let area = list.exists ? list : app.windows.firstMatch
        let start = area.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: forward ? 0.75 : 0.25))
            .withOffset(CGVector(dx: 8, dy: 0))
        let end = area.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: forward ? 0.3 : 0.7))
            .withOffset(CGVector(dx: 8, dy: 0))
        start.press(forDuration: 0.05, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.1)
    }

    /// Scrolls the controls until `target` exists and can be tapped: first further down (or up with `upFirst`),
    /// then the other way, at most 10 drags each. Fails the test at the caller's line when it never can.
    @MainActor
    @discardableResult
    static func reveal(_ app: XCUIApplication, _ target: XCUIElement, upFirst: Bool = false,
                       file: StaticString = #filePath, line: UInt = #line) -> Bool {
        _ = target.waitForExistence(timeout: 1)
        search: for forward in (upFirst ? [false, true] : [true, false]) {
            for _ in 0..<10 {
                if target.exists && target.isHittable { break search }
                drag(app, forward: forward)
            }
        }
        let found = target.exists && target.isHittable
        XCTAssertTrue(found, "not reached by scrolling the controls: \(target)", file: file, line: line)
        return found
    }

    /// Scrolls the control `name` into view and taps it.
    @MainActor
    static func tap(_ app: XCUIApplication, _ name: String, upFirst: Bool = false,
                    file: StaticString = #filePath, line: UInt = #line) {
        let target = control(app, name)
        guard reveal(app, target, upFirst: upFirst, file: file, line: line) else { return }
        target.tap()
    }

    /// Scrolls the hold button `name` into view and holds it for `seconds` (the press sends its steering, the release
    /// sends straight).
    @MainActor
    static func hold(_ app: XCUIApplication, _ name: String, seconds: TimeInterval = 0.4, upFirst: Bool = false,
                     file: StaticString = #filePath, line: UInt = #line) {
        let target = control(app, name)
        guard reveal(app, target, upFirst: upFirst, file: file, line: line) else { return }
        target.press(forDuration: seconds)
    }

    /// Scrolls the toggle `name` into view and flips it: the inner switch when there is one, otherwise the right end of
    /// the row, where the switch is drawn. Waits for the new value.
    @MainActor
    static func flip(_ app: XCUIApplication, _ name: String, upFirst: Bool = false,
                     file: StaticString = #filePath, line: UInt = #line) {
        let target = control(app, name)
        guard reveal(app, target, upFirst: upFirst, file: file, line: line) else { return }
        let before = value(app, name)
        let inner = target.switches.firstMatch
        if inner.exists {
            inner.tap()
        } else {
            target.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
        }
        let deadline = Date().addingTimeInterval(shortWait)
        while value(app, name) == before, Date() < deadline { usleep(200_000) }
        XCTAssertNotEqual(value(app, name), before, "\(name) did not change", file: file, line: line)
    }

    /// Scrolls the sensitivity control into view and moves it one step, whatever kind of control it is: a stepper
    /// (its Increment button, or Decrement at the last step), a slider (adjusted to the other end), a segmented
    /// control (an unselected segment) or a menu picker (an entry other than the current one). Returns the value
    /// before the change; the caller waits for the new one.
    @MainActor
    @discardableResult
    static func changeSensitivity(_ app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line)
        -> String {
        let name = "settings.sensitivity"
        let target = control(app, name)
        guard reveal(app, target, file: file, line: line) else { return "" }
        let before = value(app, name)
        let steppers = app.steppers.matching(identifier: id(name))
        let scope = steppers.firstMatch.exists ? steppers.firstMatch : target
        let increment = scope.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@ OR identifier CONTAINS[c] %@",
                                                           "Increment", "Increment")).firstMatch
        let decrement = scope.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@ OR identifier CONTAINS[c] %@",
                                                           "Decrement", "Decrement")).firstMatch
        switch target.elementType {
        case _ where increment.exists || decrement.exists:
            if increment.exists && increment.isEnabled { increment.tap() } else { decrement.tap() }
        case .slider:
            let position = target.normalizedSliderPosition
            target.adjust(toNormalizedSliderPosition: position < 0.5 ? 1.0 : 0.0)
        case .segmentedControl:
            let other = target.buttons.matching(NSPredicate(format: "selected == NO")).firstMatch
            XCTAssertTrue(other.exists, "the sensitivity offers another step", file: file, line: line)
            if other.exists { other.tap() }
        default:
            // A menu picker: open it and choose an entry other than the current one.
            target.tap()
            let other = NSPredicate(format: "label != %@ AND label != ''", before)
            let candidates = [app.collectionViews.buttons.matching(other).firstMatch,
                              app.menuItems.matching(other).firstMatch]
            let deadline = Date().addingTimeInterval(shortWait)
            var entry: XCUIElement?
            while entry == nil, Date() < deadline {
                entry = candidates.first { $0.exists }
                if entry == nil { usleep(200_000) }
            }
            XCTAssertNotNil(entry, "the sensitivity menu offers another step (value \(before))", file: file, line: line)
            entry?.tap()
        }
        return before
    }

    /// Waits until the label of `target` satisfies `condition`; true when it does.
    @MainActor
    static func waitForLabel(_ target: XCUIElement, timeout: TimeInterval = VC.wait,
                             _ condition: (String) -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while !(target.exists && condition(target.label)), Date() < deadline { usleep(200_000) }
        return target.exists && condition(target.label)
    }

    /// Waits until the accessibility value of `target` satisfies `condition`; true when it does.
    @MainActor
    static func waitForValue(_ target: XCUIElement, timeout: TimeInterval = NA.shortWait,
                             _ condition: (String) -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while !(target.exists && condition(target.value as? String ?? "")), Date() < deadline { usleep(200_000) }
        return target.exists && condition(target.value as? String ?? "")
    }

    /// Waits until the canvas description satisfies `condition`; true when it does.
    @MainActor
    static func waitForDescription(_ app: XCUIApplication, timeout: TimeInterval = NA.shortWait,
                                   _ condition: (String) -> Bool) -> Bool {
        waitForLabel(canvas(app), timeout: timeout, condition)
    }
}
