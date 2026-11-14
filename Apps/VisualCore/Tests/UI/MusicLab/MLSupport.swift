// MLSupport — feature 052 (A06-P06) T-A06-609 (US4, FR-A06-630): helpers of the interface tests of VisualCore Music
// Lab (A06) inside the one app. A06 is a candidate until X-A06, so every launch carries `-vcCandidates`; the tests open
// it directly with `-openExperience` (the pattern of `IGSupport`). The controls are found by the identifiers of
// `MusicLabControls` (`port.identifier(name)`, that is `experience.a06.visualcore-music-lab.<name>`). They sit below
// the canvas in a scroll view of limited height, so a control is scrolled into view before it is used. A fresh start
// plays the demo signal; the microphone is never chosen here (no permission prompt automation). The canvas label is
// the presenter's description ("Music Lab: <Scene> scene, …"). Everything lives in the namespace `ML`, so that nothing
// collides with the shared helpers of `AppUITestSupport` or the other experiences.
import Foundation
import XCTest

/// Launch arguments, identifiers and helpers of the A06 interface tests.
enum ML {
    /// The experience's id in the catalog.
    static let experienceID = "a06.visualcore-music-lab"
    /// The prefix of every identifier of the experience's controls.
    static let prefix = "experience.a06.visualcore-music-lab."
    /// The prefix of the canvas description.
    static let describedPrefix = "Music Lab: "
    /// The debug argument that makes the candidates available (DebugLaunch).
    static let candidates = "-vcCandidates"
    /// A first start with erased data, straight into A06.
    static let fresh = [VC.reset, VC.skipWelcome, candidates, VC.openExperience, experienceID]
    /// The ids of the built-in presets (`MusicPreset.builtIns`), lowercased as in the identifiers.
    static let builtInPresetIDs = ["00000000-0000-4000-8000-0000000006a1", "00000000-0000-4000-8000-0000000006a2",
                                   "00000000-0000-4000-8000-0000000006a3"]
    /// The longest a single check waits (each test stays well under 60 s).
    static let shortWait: TimeInterval = 5

    /// The full identifier of the control `name`.
    static func id(_ name: String) -> String { prefix + name }

    /// The control `name` of A06, of any element type.
    @MainActor
    static func control(_ app: XCUIApplication, _ name: String) -> XCUIElement {
        element(app, id(name))
    }

    /// The slider `name` of A06.
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

    /// Launches the app with `arguments` and waits until A06 runs: the experience route, its canvas and its first
    /// demo-mode choice.
    @MainActor
    @discardableResult
    static func open(arguments: [String] = ML.fresh, file: StaticString = #filePath, line: UInt = #line)
        -> XCUIApplication {
        let app = launchApp(arguments: arguments)
        waitFor(element(app, "vc.route.experience"), timeout: VC.firstWait, file: file, line: line)
        waitFor(canvas(app), timeout: VC.firstWait, file: file, line: line)
        waitFor(control(app, "source.demo"), timeout: VC.wait, file: file, line: line)
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

    /// Scrolls the slider `name` into view, lets the list come to rest and moves it to `position` (0…1).
    @MainActor
    static func adjust(_ app: XCUIApplication, _ name: String, to position: CGFloat,
                       file: StaticString = #filePath, line: UInt = #line) {
        let target = slider(app, name)
        guard reveal(app, target, file: file, line: line) else { return }
        usleep(500_000)
        target.adjust(toNormalizedSliderPosition: position)
    }

    /// The spoken value of the slider `name`, or "" when it has none.
    @MainActor
    static func sliderValue(_ app: XCUIApplication, _ name: String) -> String {
        slider(app, name).value as? String ?? ""
    }

    /// Scrolls the text field `name` into view, replaces its text with `value` and presses return.
    @MainActor
    static func type(_ app: XCUIApplication, _ name: String, _ value: String,
                     file: StaticString = #filePath, line: UInt = #line) {
        let field = control(app, name)
        guard reveal(app, field, file: file, line: line) else { return }
        field.tap()
        if let current = field.value as? String, !current.isEmpty, current != "Preset name" {
            field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count))
        }
        field.typeText(value + "\n")                    // return dismisses the keyboard
    }

    /// The Apply buttons of saved (not built-in) presets.
    @MainActor
    static func userPresetApplyButtons(_ app: XCUIApplication) -> XCUIElementQuery {
        var formats = ["identifier BEGINSWITH %@", "identifier ENDSWITH %@"]
        var arguments: [Any] = [id("preset."), ".apply"]
        for builtIn in builtInPresetIDs {
            formats.append("NOT (identifier CONTAINS %@)")
            arguments.append(builtIn)
        }
        let predicate = NSPredicate(format: formats.joined(separator: " AND "), argumentArray: arguments)
        return app.descendants(matching: .any).matching(predicate)
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
                                 timeout: TimeInterval = ML.shortWait) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while target.isSelected != selected, Date() < deadline { usleep(200_000) }
        return target.isSelected == selected
    }
}
