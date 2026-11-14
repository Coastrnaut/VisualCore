// AOSupport — feature 059 (A07-P06) T-A07-609 (FR-A07-630): helpers of the interface tests of Audio Odyssey (A07)
// inside the one app, modelled on `MLSupport`. A07 was a candidate until X-A07 (integrated 2026-11-14); as in `MLSupport`,
// every launch carries `-vcCandidates`; the tests open it directly with `-openExperience`. The controls are found by
// the identifiers of `OdysseyControls` (`port.identifier(name)`, that is `experience.a07.audio-odyssey.<name>`). They
// sit below the canvas in a scroll view of limited height, so a control is scrolled into view before it is used, and a
// slider is brought toward the middle of the panel before it is dragged. A fresh start plays the demo signal; the
// microphone is never chosen here (no permission prompt automation). The canvas label is the presenter's description
// ("Audio Odyssey: Tunnel, 4 units per second, standard easing, flying, …"). Everything lives in the namespace `AO`, so
// that nothing collides with the shared helpers of `AppUITestSupport` or the other experiences.
import Foundation
import XCTest

/// Launch arguments, identifiers and helpers of the A07 interface tests.
enum AO {
    /// The experience's id in the catalog.
    static let experienceID = "a07.audio-odyssey"
    /// The prefix of every identifier of the experience's controls.
    static let prefix = "experience.a07.audio-odyssey."
    /// The prefix of the canvas description.
    static let describedPrefix = "Audio Odyssey: "
    /// The debug argument that makes the candidates available (DebugLaunch).
    static let candidates = "-vcCandidates"
    /// A first start with erased data, straight into A07.
    static let fresh = [VC.reset, VC.skipWelcome, candidates, VC.openExperience, experienceID]
    /// The names of the built-in journeys (`JourneyPreset.builtIns`), in the order of the rows `preset.0…2`.
    static let builtInJourneys = ["Deep tunnel", "Rolling hills", "Night stars"]
    /// The longest a single check waits (each test stays well under 60 s).
    static let shortWait: TimeInterval = 5

    /// The full identifier of the control `name`.
    static func id(_ name: String) -> String { prefix + name }

    /// The control `name` of A07, of any element type.
    @MainActor
    static func control(_ app: XCUIApplication, _ name: String) -> XCUIElement {
        element(app, id(name))
    }

    /// The slider `name` of A07.
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

    /// Launches the app with `arguments` and waits until A07 runs: the experience route, its canvas and its first
    /// world choice.
    @MainActor
    @discardableResult
    static func open(arguments: [String] = AO.fresh, file: StaticString = #filePath, line: UInt = #line)
        -> XCUIApplication {
        let app = launchApp(arguments: arguments)
        waitFor(element(app, "vc.route.experience"), timeout: VC.firstWait, file: file, line: line)
        waitFor(canvas(app), timeout: VC.firstWait, file: file, line: line)
        waitFor(control(app, "world.0"), timeout: VC.wait, file: file, line: line)
        XCTAssertTrue(waitForLabel(canvas(app)) { $0.hasPrefix(describedPrefix) },
                      "the canvas is described: \(description(app))", file: file, line: line)
        return app
    }

    /// The scroll view that holds the controls below the canvas.
    @MainActor
    static func controlsList(_ app: XCUIApplication) -> XCUIElement {
        app.scrollViews.containing(NSPredicate(format: "identifier BEGINSWITH %@", prefix)).firstMatch
    }

    /// One short drag on the controls near their left edge (inside the padding, so that no button takes the touch).
    /// `forward` moves the finger up, which shows the controls further down.
    @MainActor
    static func drag(_ app: XCUIApplication, forward: Bool) {
        let list = controlsList(app)
        let area = list.exists ? list : app.windows.firstMatch
        let start = area.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: forward ? 0.9 : 0.1))
            .withOffset(CGVector(dx: 8, dy: 0))
        let end = area.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: forward ? 0.12 : 0.88))
            .withOffset(CGVector(dx: 8, dy: 0))
        start.press(forDuration: 0.05, thenDragTo: end)
    }

    /// Scrolls the controls until `target` exists and can be tapped: first further down (or up with `upFirst`),
    /// then the other way, at most 14 drags each. Fails the test at the caller's line when it never can.
    @MainActor
    @discardableResult
    static func reveal(_ app: XCUIApplication, _ target: XCUIElement, upFirst: Bool = false,
                       file: StaticString = #filePath, line: UInt = #line) -> Bool {
        _ = target.waitForExistence(timeout: 1)
        // Stop as soon as the target is reachable (labelled break, as in `IGSupport`).
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

    /// Scrolls the choice `name` into view, taps it and asserts that it becomes selected.
    @MainActor
    static func choose(_ app: XCUIApplication, _ name: String, upFirst: Bool = false,
                       file: StaticString = #filePath, line: UInt = #line) {
        tap(app, name, upFirst: upFirst, file: file, line: line)
        XCTAssertTrue(waitForSelection(control(app, name)), "\(name) is selected", file: file, line: line)
    }

    /// Scrolls the slider `name` into view, brings it toward the middle of the panel, lets the list come to rest and
    /// moves it to `position` (0…1).
    @MainActor
    static func adjust(_ app: XCUIApplication, _ name: String, to position: CGFloat,
                       file: StaticString = #filePath, line: UInt = #line) {
        let target = slider(app, name)
        guard reveal(app, target, file: file, line: line) else { return }
        // A slider revealed at the edge of the controls can take the drag as a scroll: bring it toward the middle first
        // (one short drag of about a quarter of the panel), as `ML.adjust` does since X-A06.
        let list = controlsList(app)
        let area = list.exists ? list : app.windows.firstMatch
        if target.frame.midY > area.frame.minY + area.frame.height * 0.65 {
            let from = area.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0.6)).withOffset(CGVector(dx: 8, dy: 0))
            let to = area.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0.35)).withOffset(CGVector(dx: 8, dy: 0))
            from.press(forDuration: 0.05, thenDragTo: to)
        }
        usleep(500_000)
        target.adjust(toNormalizedSliderPosition: position)
    }

    /// The spoken value of the slider `name`, or "" when it has none.
    @MainActor
    static func sliderValue(_ app: XCUIApplication, _ name: String) -> String {
        slider(app, name).value as? String ?? ""
    }

    /// The value of the switch `name` ("1" on, "0" off), or "" when it has none.
    @MainActor
    static func switchValue(_ app: XCUIApplication, _ name: String) -> String {
        control(app, name).value as? String ?? ""
    }

    /// Scrolls the toggle `name` into view and flips it: the inner switch when there is one, otherwise the right end of
    /// the row, where the switch is drawn (a tap on the label does not flip a toggle; the pattern of `PUSupport`).
    /// Waits for the new value.
    @MainActor
    static func flip(_ app: XCUIApplication, _ name: String, file: StaticString = #filePath, line: UInt = #line) {
        let target = control(app, name)
        guard reveal(app, target, file: file, line: line) else { return }
        let before = switchValue(app, name)
        let inner = target.switches.firstMatch
        if inner.exists {
            inner.tap()
        } else {
            target.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
        }
        let deadline = Date().addingTimeInterval(shortWait)
        while switchValue(app, name) == before, Date() < deadline { usleep(200_000) }
        XCTAssertNotEqual(switchValue(app, name), before, "\(name) did not change", file: file, line: line)
    }

    /// Scrolls the menu picker `name` into view, opens it and picks the entry `option` (its visible title). Waits until
    /// the picker speaks `option` as its value; true when it does.
    @MainActor
    @discardableResult
    static func pick(_ app: XCUIApplication, _ name: String, _ option: String,
                     file: StaticString = #filePath, line: UInt = #line) -> Bool {
        let picker = control(app, name)
        guard reveal(app, picker, file: file, line: line) else { return false }
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
        if let current = field.value as? String, !current.isEmpty, current != "Journey name" {
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

    /// Waits until `target` is (or is not) selected; true when it is as asked.
    @MainActor
    static func waitForSelection(_ target: XCUIElement, _ selected: Bool = true,
                                 timeout: TimeInterval = AO.shortWait) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while target.isSelected != selected, Date() < deadline { usleep(200_000) }
        return target.isSelected == selected
    }
}
