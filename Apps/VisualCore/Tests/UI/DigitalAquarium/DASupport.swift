// DASupport — feature 073 (A09-P06) T-A09-608 (FR-A09-630): helpers of the interface tests of Digital Aquarium (A09)
// inside the one app, modelled on `OSSupport`. A09 was a candidate until X-A09 (integrated 2026-11-14); every
// launch still carries `-vcCandidates`, and the tests open it directly with `-openExperience`. The controls are
// found by the identifiers of `AquariumControls` (`port.identifier(name)`, that is
// `experience.a09.digital-aquarium.<name>`). They sit below the
// canvas in a scroll view of limited height, so a control is scrolled into view before it is used. The habitat,
// lighting, decoration kind and piece choices are menu pickers (their spoken value is the chosen entry's title), Pause
// motion and Ambient are toggles (values "Swimming"/"Paused" and "Off"/"On"), and the saved aquariums are buttons
// labelled with their names (value "Saved aquarium", with ", selected" for the selected one). A fresh start (erased
// data) shows the Reef habitat with no food and an empty library. The canvas label is the presenter's description
// ("Digital Aquarium: Reef, 7 fish of 2 species (…), 5 plants, 3 decorations, no food, lighting soft, swimming.").
// Everything lives in the namespace `DA`, so that nothing collides with the shared helpers of `AppUITestSupport` or the
// other experiences.
import Foundation
import XCTest

/// Launch arguments, identifiers and helpers of the A09 interface tests.
enum DA {
    /// The experience's id in the catalog.
    static let experienceID = "a09.digital-aquarium"
    /// The prefix of every identifier of the experience's controls.
    static let prefix = "experience.a09.digital-aquarium."
    /// The prefix of the canvas description.
    static let describedPrefix = "Digital Aquarium: "
    /// The debug argument that makes the candidates available (DebugLaunch).
    static let candidates = "-vcCandidates"
    /// A first start with erased data, straight into A09.
    static let fresh = [VC.reset, VC.skipWelcome, candidates, VC.openExperience, experienceID]
    /// The starter habitats (`SpeciesCatalog` order: the habitat picker's entries).
    static let reef = "Reef"
    static let kelp = "Kelp"
    /// The placeholder of the empty aquarium name field.
    static let namePlaceholder = "Aquarium name"
    /// The longest a single check waits (each test stays well under 60 s).
    static let shortWait: TimeInterval = 5

    /// The full identifier of the control `name`.
    static func id(_ name: String) -> String { prefix + name }

    /// The control `name` of A09, of any element type.
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

    /// The number of decorations the canvas description names ("0 decorations", "1 decoration", …), or nil when it
    /// names none.
    @MainActor
    static func decorCount(_ app: XCUIApplication) -> Int? {
        decorCount(in: description(app))
    }

    /// The number before " decoration" in `text`, or nil.
    static func decorCount(in text: String) -> Int? {
        guard let range = text.range(of: #"(\d+) decorations?"#, options: .regularExpression) else { return nil }
        return Int(text[range].prefix { $0.isNumber })
    }

    /// The spoken value of the control `name` (a picker's chosen entry, a toggle's state, a saved row's
    /// "Saved aquarium"), or "" when it has none.
    @MainActor
    static func value(_ app: XCUIApplication, _ name: String) -> String {
        control(app, name).value as? String ?? ""
    }

    /// Launches the app with `arguments` and waits until A09 runs: the experience route, its canvas described and its
    /// habitat picker.
    @MainActor
    @discardableResult
    static func open(arguments: [String] = DA.fresh, file: StaticString = #filePath, line: UInt = #line)
        -> XCUIApplication {
        let app = launchApp(arguments: arguments)
        waitFor(element(app, "vc.route.experience"), timeout: VC.firstWait, file: file, line: line)
        waitFor(canvas(app), timeout: VC.firstWait, file: file, line: line)
        waitFor(control(app, "habitat.select"), timeout: VC.wait, file: file, line: line)
        XCTAssertTrue(waitForLabel(canvas(app)) { $0.hasPrefix(describedPrefix) },
                      "the canvas is described: \(description(app))", file: file, line: line)
        return app
    }

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
    /// then the other way, at most 14 drags each. Fails the test at the caller's line when it never can.
    @MainActor
    @discardableResult
    static func reveal(_ app: XCUIApplication, _ target: XCUIElement, upFirst: Bool = false,
                       file: StaticString = #filePath, line: UInt = #line) -> Bool {
        _ = target.waitForExistence(timeout: 1)
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

    /// Scrolls the menu picker `name` into view, opens it and picks the first entry whose visible title satisfies
    /// `predicate` (a format over `label`, evaluated by the query). Waits until the picker speaks that title as its
    /// value; true when it does.
    @MainActor
    @discardableResult
    static func pick(_ app: XCUIApplication, _ name: String, matching predicate: NSPredicate, upFirst: Bool = false,
                     file: StaticString = #filePath, line: UInt = #line) -> Bool {
        let picker = control(app, name)
        guard reveal(app, picker, upFirst: upFirst, file: file, line: line) else { return false }
        picker.tap()
        // The open menu lists its entries as buttons (or menu items, depending on the system version).
        let candidates = [app.collectionViews.buttons.matching(predicate).firstMatch,
                          app.menuItems.matching(predicate).firstMatch,
                          app.buttons.matching(predicate).firstMatch]
        let deadline = Date().addingTimeInterval(shortWait)
        var entry: XCUIElement?
        while entry == nil, Date() < deadline {
            entry = candidates.first { $0.exists }
            if entry == nil { usleep(200_000) }
        }
        XCTAssertNotNil(entry, "the menu of \(name) offers an entry matching \(predicate)", file: file, line: line)
        guard let entry else { return false }
        let title = entry.label
        entry.tap()
        return waitForValue(picker, timeout: shortWait) { $0 == title }
    }

    /// Scrolls the menu picker `name` into view, opens it and picks the entry `option` (its visible title).
    @MainActor
    @discardableResult
    static func pick(_ app: XCUIApplication, _ name: String, _ option: String, upFirst: Bool = false,
                     file: StaticString = #filePath, line: UInt = #line) -> Bool {
        pick(app, name, matching: NSPredicate(format: "label == %@", option), upFirst: upFirst, file: file, line: line)
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

    /// Waits until the canvas description satisfies `condition`; true when it does.
    @MainActor
    static func waitForDescription(_ app: XCUIApplication, timeout: TimeInterval = DA.shortWait,
                                   _ condition: (String) -> Bool) -> Bool {
        waitForLabel(canvas(app), timeout: timeout, condition)
    }
}
