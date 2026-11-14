// IGSupport — feature 045 (A05-P06) T-A05-610 (US4, FR-A05-630): helpers of the interface tests of Infinite Geometry
// (A05) inside the one app. A05 is a candidate, so every launch carries `-vcCandidates`; the tests open it directly with
// `-openExperience`. The controls are found by the identifiers of `GeometryControls` (`port.identifier(name)`, that is
// `experience.a05.infinite-geometry.<name>`). They sit below the canvas in a scroll view of limited height, so a
// control is scrolled into view before it is used (the pattern of `PUSupport`). The canvas label is the presenter's
// description ("Infinite Geometry: <Kind>, <symmetry>, <N> elements[, field of view <F>°]."). Everything lives in the
// namespace `IG`, so that nothing collides with the shared helpers of `AppUITestSupport` or the other experiences.
import Foundation
import XCTest

/// Launch arguments, identifiers and helpers of the A05 interface tests.
enum IG {
    /// The experience's id in the catalog.
    static let experienceID = "a05.infinite-geometry"
    /// The experience's title (catalog name and route title).
    static let title = "Infinite Geometry"
    /// The prefix of every identifier of the experience's controls.
    static let prefix = "experience.a05.infinite-geometry."
    /// The prefix of the canvas description.
    static let describedPrefix = "Infinite Geometry: "
    /// The debug argument that makes the candidates available (DebugLaunch).
    static let candidates = "-vcCandidates"
    /// A first start with erased data, straight into A05.
    static let fresh = [VC.reset, VC.skipWelcome, candidates, VC.openExperience, experienceID]
    /// A further start that keeps the data, straight into A05.
    static let again = [VC.skipWelcome, candidates, VC.openExperience, experienceID]
    /// The index of the 3D composition among the curated presets (`GeometryPreset.curated`).
    static let solidPreset = 3
    /// The index of the kaleidoscope among the curated presets.
    static let kaleidoscopePreset = 2

    /// The full identifier of the control `name`.
    static func id(_ name: String) -> String { prefix + name }

    /// The control `name` of A05, of any element type.
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

    /// Launches the app with `arguments` and waits until A05 runs: the experience route, its canvas with a
    /// description and its first preset choice.
    @MainActor
    @discardableResult
    static func open(arguments: [String] = IG.fresh, file: StaticString = #filePath, line: UInt = #line)
        -> XCUIApplication {
        let app = launchApp(arguments: arguments)
        waitUntilRunning(app, file: file, line: line)
        return app
    }

    /// Waits until A05 runs in `app`: the experience route, its described canvas and its first preset choice.
    @MainActor
    static func waitUntilRunning(_ app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        waitFor(element(app, "vc.route.experience"), timeout: VC.firstWait, file: file, line: line)
        waitFor(canvas(app), timeout: VC.firstWait, file: file, line: line)
        waitFor(control(app, "preset.0"), timeout: VC.wait, file: file, line: line)
        XCTAssertTrue(waitForLabel(canvas(app)) { $0.hasPrefix(describedPrefix) },
                      "the canvas is described: \(description(app))", file: file, line: line)
    }

    /// The scroll view that holds the controls below the canvas.
    @MainActor
    static func controlsList(_ app: XCUIApplication) -> XCUIElement {
        app.scrollViews.containing(NSPredicate(format: "identifier BEGINSWITH %@", prefix)).firstMatch
    }

    /// One short drag on the controls near their left edge (inside the padding, so that no button or stepper takes
    /// the touch). `forward` moves the finger up, which shows the controls further down.
    @MainActor
    static func drag(_ app: XCUIApplication, forward: Bool) {
        let list = controlsList(app)
        let area = list.exists ? list : app.windows.firstMatch
        // Most of the list's height per drag, so a control far down is reached in about half the drags (each drag
        // costs about 2 s on the simulator).
        let start = area.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: forward ? 0.9 : 0.1))
            .withOffset(CGVector(dx: 8, dy: 0))
        let end = area.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: forward ? 0.12 : 0.88))
            .withOffset(CGVector(dx: 8, dy: 0))
        start.press(forDuration: 0.05, thenDragTo: end)
    }

    /// Scrolls the controls until `target` exists and can be tapped: first further down, then back up. Fails the
    /// test at the caller's line when it never can.
    @MainActor
    @discardableResult
    static func reveal(_ app: XCUIApplication, _ target: XCUIElement, upFirst: Bool = false,
                       file: StaticString = #filePath, line: UInt = #line) -> Bool {
        // A list row that is off screen is not in the tree until it is scrolled to, so waiting for it first only
        // spends time (it cost 10 s per control in the first k2 run): look briefly, then scroll and look again.
        _ = target.waitForExistence(timeout: 1)
        // Stop as soon as the target is reachable: a `for … where` loop would keep querying the accessibility tree
        // 28 times after the target was found (about 5 s per call in the first Infinite Geometry k2 run).
        // `upFirst` for controls near the top (the presets): searching down first from the library section at the
        // bottom would spend every drag at the end of the list.
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

    /// Scrolls the stepper `name` into view and presses its increment (`up`) or decrement button: the inner button
    /// whose label or identifier names it when there is one, otherwise the matching end of the row, where the system
    /// stepper is drawn (increment at the right end, decrement just left of it).
    @MainActor
    static func step(_ app: XCUIApplication, _ name: String, up: Bool = true,
                     file: StaticString = #filePath, line: UInt = #line) {
        let target = control(app, name)
        guard reveal(app, target, file: file, line: line) else { return }
        let word = up ? "Increment" : "Decrement"
        let inner = target.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@ OR identifier CONTAINS[c] %@",
                                                        word, word)).firstMatch
        if inner.exists, inner.isHittable {
            inner.tap()
            return
        }
        let suffixed = element(app, id(name) + "-" + word)
        if suffixed.exists, suffixed.isHittable {
            suffixed.tap()
            return
        }
        target.coordinate(withNormalizedOffset: CGVector(dx: up ? 0.95 : 0.8, dy: 0.5)).tap()
    }

    /// The label of the control `name` after waiting for it, or "" when it is not there.
    @MainActor
    static func text(_ app: XCUIApplication, _ name: String) -> String {
        let target = control(app, name)
        _ = target.waitForExistence(timeout: VC.wait)
        return target.exists ? target.label : ""
    }

    /// Scrolls the text field `name` into view, replaces its text with `value` and presses return.
    @MainActor
    static func type(_ app: XCUIApplication, _ name: String, _ value: String,
                     file: StaticString = #filePath, line: UInt = #line) {
        let field = control(app, name)
        guard reveal(app, field, file: file, line: line) else { return }
        field.tap()
        if let current = field.value as? String, !current.isEmpty, current != "Composition name",
           current != "New name" {
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

    /// Waits until the canvas description satisfies `condition`; true when it does.
    @MainActor
    static func waitForDescription(_ app: XCUIApplication, timeout: TimeInterval = VC.wait,
                                   _ condition: (String) -> Bool) -> Bool {
        waitForLabel(canvas(app), timeout: timeout, condition)
    }

    /// Waits until `target` is (or is not) selected; true when it is as asked.
    @MainActor
    static func waitForSelection(_ target: XCUIElement, _ selected: Bool = true,
                                 timeout: TimeInterval = VC.wait) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while target.isSelected != selected, Date() < deadline { usleep(200_000) }
        return target.isSelected == selected
    }

    /// Chooses the curated preset `index` and waits until the canvas names `kind`.
    @MainActor
    static func choosePreset(_ app: XCUIApplication, _ index: Int, kind: String,
                             file: StaticString = #filePath, line: UInt = #line) {
        tap(app, "preset.\(index)", upFirst: true, file: file, line: line)
        XCTAssertTrue(waitForDescription(app) { $0.hasPrefix(describedPrefix + kind + ",") },
                      "the canvas names \(kind): \(description(app))", file: file, line: line)
    }
}
