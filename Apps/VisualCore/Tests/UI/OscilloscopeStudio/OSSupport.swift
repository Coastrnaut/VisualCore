// OSSupport — feature 066 (A08-P06) T-A08-609: helpers of the interface tests of Oscilloscope Studio (A08) inside the
// one app, modelled on `AOSupport`. A08 is a candidate until X-A08; every launch carries `-vcCandidates`, and the tests
// open it directly with `-openExperience`. The controls are found by the identifiers of `ScopeControls`
// (`port.identifier(name)`, that is `experience.a08.oscilloscope-studio.<name>`). They sit below the canvas in a scroll
// view of limited height, so a control is scrolled into view before it is used. The choices are menu pickers (their
// spoken value is the chosen entry's title), Freeze and Cursors are toggles, and the preset rows are buttons whose
// value reads "built-in" or "saved", with ", selected" for the selected one. A fresh start shows the stereo test
// signal; the microphone is never chosen here (no permission prompt automation). The canvas label is the presenter's
// description ("Oscilloscope Studio: test signal, sine 1 kHz, 2 channels, waveform view, 1 ms per division, gain ×1,
// …"). Everything lives in the namespace `OS`, so that nothing collides with the shared helpers of `AppUITestSupport`
// or the other experiences.
import Foundation
import XCTest

/// Launch arguments, identifiers and helpers of the A08 interface tests.
enum OS {
    /// The experience's id in the catalog.
    static let experienceID = "a08.oscilloscope-studio"
    /// The prefix of every identifier of the experience's controls.
    static let prefix = "experience.a08.oscilloscope-studio."
    /// The prefix of the canvas description.
    static let describedPrefix = "Oscilloscope Studio: "
    /// The debug argument that makes the candidates available (DebugLaunch).
    static let candidates = "-vcCandidates"
    /// A first start with erased data, straight into A08.
    static let fresh = [VC.reset, VC.skipWelcome, candidates, VC.openExperience, experienceID]
    /// The names of the built-in presets (`ScopePreset.builtIns`), in the order of the rows `preset.0…2`.
    static let builtInPresets = ["Audio overview", "Bass detail", "Spectrum check"]
    /// The placeholder of the empty preset name field.
    static let namePlaceholder = "Preset name"
    /// The name the source picker speaks for the test signal.
    static let testSignal = "Test signal"
    /// The longest a single check waits (each test stays well under 60 s).
    static let shortWait: TimeInterval = 5

    /// The full identifier of the control `name`.
    static func id(_ name: String) -> String { prefix + name }

    /// The control `name` of A08, of any element type.
    @MainActor
    static func control(_ app: XCUIApplication, _ name: String) -> XCUIElement {
        element(app, id(name))
    }

    /// The slider `name` of A08.
    @MainActor
    static func slider(_ app: XCUIApplication, _ name: String) -> XCUIElement {
        app.sliders.matching(identifier: id(name)).firstMatch
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

    /// The trace status line (`trace.status`), or "" when it is not there.
    @MainActor
    static func traceStatus(_ app: XCUIApplication) -> String {
        let s = control(app, "trace.status")
        return s.exists ? s.label : ""
    }

    /// The spoken value of the control `name` (a picker's chosen entry, a switch's "1"/"0", a preset row's
    /// "built-in"/"saved"), or "" when it has none.
    @MainActor
    static func value(_ app: XCUIApplication, _ name: String) -> String {
        control(app, name).value as? String ?? ""
    }

    /// Launches the app with `arguments` and waits until A08 runs: the experience route, its canvas and its source
    /// picker on the test signal.
    @MainActor
    @discardableResult
    static func open(arguments: [String] = OS.fresh, file: StaticString = #filePath, line: UInt = #line)
        -> XCUIApplication {
        let app = launchApp(arguments: arguments)
        waitFor(element(app, "vc.route.experience"), timeout: VC.firstWait, file: file, line: line)
        waitFor(canvas(app), timeout: VC.firstWait, file: file, line: line)
        waitFor(control(app, "source.picker"), timeout: VC.wait, file: file, line: line)
        XCTAssertTrue(waitForLabel(canvas(app)) { $0.hasPrefix(describedPrefix) },
                      "the canvas is described: \(description(app))", file: file, line: line)
        XCTAssertEqual(value(app, "source.picker"), testSignal, "a fresh start shows the test signal",
                       file: file, line: line)
        return app
    }

    /// The scroll view that holds the controls below the canvas.
    @MainActor
    static func controlsList(_ app: XCUIApplication) -> XCUIElement {
        app.scrollViews.containing(NSPredicate(format: "identifier BEGINSWITH %@", prefix)).firstMatch
    }

    /// One short, slow drag on the controls near their left edge (inside the padding, so that no button takes the
    /// touch): about half the list's height with a hold at the end, so the list moves by the drag's length without a
    /// fling that would carry a control past the screen (feature 066: long flings overshot the Display section).
    /// `forward` moves the finger up, which shows the controls further down.
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
    /// then the other way, at most 14 drags each. Fails the test at the caller's line when it never can.
    @MainActor
    @discardableResult
    static func reveal(_ app: XCUIApplication, _ target: XCUIElement, upFirst: Bool = false,
                       file: StaticString = #filePath, line: UInt = #line) -> Bool {
        _ = target.waitForExistence(timeout: 1)
        // Stop as soon as the target is reachable (labelled break, as in `AOSupport`).
        search: for forward in (upFirst ? [false, true] : [true, false]) {
            for _ in 0..<14 {
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

    /// Scrolls the toggle `name` into view and flips it: the inner switch when there is one, otherwise the right end of
    /// the row, where the switch is drawn (a tap on the label does not flip a toggle; the pattern of `AOSupport`).
    /// Waits for the new value.
    @MainActor
    static func flip(_ app: XCUIApplication, _ name: String, file: StaticString = #filePath, line: UInt = #line) {
        let target = control(app, name)
        guard reveal(app, target, file: file, line: line) else { return }
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

    /// Scrolls the menu picker `name` into view, opens it and picks the entry `option` (its visible title). Waits until
    /// the picker speaks `option` as its value; true when it does.
    @MainActor
    @discardableResult
    static func pick(_ app: XCUIApplication, _ name: String, _ option: String, upFirst: Bool = false,
                     file: StaticString = #filePath, line: UInt = #line) -> Bool {
        let picker = control(app, name)
        guard reveal(app, picker, upFirst: upFirst, file: file, line: line) else { return false }
        picker.tap()
        // The open menu lists its entries as buttons (or menu items, depending on the system version).
        let item = app.collectionViews.buttons[option].firstMatch
        let entry: XCUIElement
        if item.waitForExistence(timeout: 2) {
            entry = item
        } else if app.menuItems[option].firstMatch.exists {
            entry = app.menuItems[option].firstMatch
        } else {
            entry = app.buttons[option].firstMatch
        }
        XCTAssertTrue(entry.waitForExistence(timeout: shortWait), "the menu offers \(option)", file: file, line: line)
        guard entry.exists else { return false }
        entry.tap()
        return waitForValue(picker, timeout: shortWait) { $0 == option }
    }

    /// Scrolls the text field `name` into view, replaces its text with `value` and presses return.
    @MainActor
    static func type(_ app: XCUIApplication, _ name: String, _ value: String,
                     file: StaticString = #filePath, line: UInt = #line) {
        let field = control(app, name)
        guard reveal(app, field, file: file, line: line) else { return }
        field.tap()
        if let current = field.value as? String, !current.isEmpty, current != namePlaceholder {
            field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count))
        }
        field.typeText(value + "\n")                    // return dismisses the keyboard
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
    static func waitForValue(_ target: XCUIElement, timeout: TimeInterval = 3,
                             _ condition: (String) -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while !(target.exists && condition(target.value as? String ?? "")), Date() < deadline { usleep(200_000) }
        return target.exists && condition(target.value as? String ?? "")
    }

    /// Waits until the preset row `name` speaks ", selected" in its value (the rows carry no selected trait);
    /// true when it does.
    @MainActor
    static func waitForSelectedPreset(_ app: XCUIApplication, _ name: String,
                                      timeout: TimeInterval = OS.shortWait) -> Bool {
        waitForValue(control(app, name), timeout: timeout) { $0.hasSuffix(", selected") }
    }
}
