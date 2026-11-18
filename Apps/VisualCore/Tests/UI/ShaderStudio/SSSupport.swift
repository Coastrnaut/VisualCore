// SSSupport — feature 161 (A22-P03) T-A22-311 (FR-A22-307; contracts/editor.md "Interface"): helpers of the interface
// tests of Shader Studio (A22) inside the one app, modelled on `AUSupport`. A22 is a candidate; every launch carries
// `-vcCandidates` (DebugLaunch: the candidates' catalog entries become available and are registered). A fresh start
// erases the data (`-vcResetData`), skips the welcome and opens the experience directly with
// `-openExperience a22.shader-studio`. A fresh studio opens on the Gradient template (one uniform, `u_speed`, 0…4,
// default 1, shown as "1.00"); its status reads "Waiting" until the first run.
//
// The canvas (`session.canvas`) is labelled with the presenter's description (`StudioPresenter.describe`): "Shader
// Studio, " then the template's title and the status. The controls are found by the identifiers of `StudioControls` and
// `StudioEditor` (`port.identifier(name)`, that is `experience.a22.shader-studio.<name>`):
//
//   - `template` (segmented picker), `run` (button; ⌘R on a hardware keyboard also runs) and `status` (its value is
//     the status line: "Waiting", "Compiled", "Failed: N errors", "Refused: <code>");
//   - `editor`: the SwiftUI `TextEditor`; its value is the document's source;
//   - `gutter`, with one element per line, `gutter-line-<n>` (n from 1); a marked line's label contains "error";
//   - `diagnostics`, with one element per entry, `diagnostic-<k>` (k from 0), labelled "Line N: message";
//   - `uniform-<k>`: the inspector's sliders (k from 0), valued in the uniform's range ("1.00");
//   - `reset`: the inspector's button that sends the defaults.
//
// The source is edited without select-all (whose menu differs between iOS 26 and 27): a tap below the text's last line
// puts the caret at the end of the document, `typeText` appends, and as many `XCUIKeyboardKey.delete` presses as
// characters were typed take the addition back. Every wait is bounded (``shortWait``, `VC.wait`, `VC.firstWait`).
// Everything lives in the namespace `SS`, so that nothing collides with the shared helpers of `AppUITestSupport` or
// the other experiences.
import Foundation
import XCTest

/// Launch arguments, identifiers and helpers of the A22 interface tests.
enum SS {
    /// The experience's id in the catalog.
    static let experienceID = "a22.shader-studio"
    /// The prefix of every identifier of the experience's controls.
    static let prefix = "experience.a22.shader-studio."
    /// The debug argument that makes the candidates available (DebugLaunch).
    static let candidates = "-vcCandidates"
    /// A first start with erased data, straight into A22.
    static let fresh = [VC.reset, VC.skipWelcome, candidates, VC.openExperience, experienceID]
    /// The longest a single check waits (each test stays well under 60 s).
    static let shortWait: TimeInterval = 5
    /// The longest a run waits for its status (the compile happens at the next frame).
    static let runWait: TimeInterval = 10
    /// The most drags one reveal makes.
    static let maxDrags = 24

    /// The full identifier of the control `name`.
    static func id(_ name: String) -> String { prefix + name }

    /// The control `name` of A22, of any element type.
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

    /// The status line (the `status` control's value, or its label when it carries no value).
    @MainActor
    static func status(_ app: XCUIApplication) -> String {
        let s = control(app, "status")
        guard s.exists else { return "" }
        let v = s.value as? String ?? ""
        return v.isEmpty ? s.label : v
    }

    /// The editor (`editor`), a SwiftUI `TextEditor`.
    @MainActor
    static func editor(_ app: XCUIApplication) -> XCUIElement { control(app, "editor") }

    /// The editor's text (its value), or "" when it is not there.
    @MainActor
    static func source(_ app: XCUIApplication) -> String {
        let e = editor(app)
        return e.exists ? (e.value as? String ?? "") : ""
    }

    /// The gutter line `n` (from 1).
    @MainActor
    static func gutterLine(_ app: XCUIApplication, _ n: Int) -> XCUIElement { control(app, "gutter-line-\(n)") }

    /// The gutter lines whose label marks an error.
    @MainActor
    static func markedLines(_ app: XCUIApplication) -> XCUIElementQuery {
        elements(app, prefix: id("gutter-line-")).matching(NSPredicate(format: "label CONTAINS[c] %@", "error"))
    }

    /// The diagnostics entry `k` (from 0).
    @MainActor
    static func diagnostic(_ app: XCUIApplication, _ k: Int) -> XCUIElement { control(app, "diagnostic-\(k)") }

    /// Every diagnostics entry.
    @MainActor
    static func diagnostics(_ app: XCUIApplication) -> XCUIElementQuery { elements(app, prefix: id("diagnostic-")) }

    /// Launches the app with `arguments` and waits until A22 runs.
    @MainActor
    @discardableResult
    static func open(arguments: [String] = SS.fresh, file: StaticString = #filePath, line: UInt = #line)
        -> XCUIApplication {
        let app = launchApp(arguments: arguments)
        waitFor(element(app, "vc.route.experience"), timeout: VC.firstWait, file: file, line: line)
        waitFor(canvas(app), timeout: VC.firstWait, file: file, line: line)
        waitFor(control(app, "run"), timeout: VC.wait, "the Run button is there", file: file, line: line)
        waitFor(editor(app), timeout: VC.wait, "the editor is there", file: file, line: line)
        XCTAssertTrue(waitForLabel(canvas(app)) { $0.hasPrefix("Shader Studio") },
                      "the canvas is labelled with the studio: \(description(app))", file: file, line: line)
        // The opening template compiles at the first frames; its status settling marks the end of the editor's
        // first loads, so an edit made after this is not reset by them (A22-P04: a caret placed before the first
        // compile finished went back to the start).
        XCTAssertTrue(waitForValue(control(app, "status"), timeout: runWait) { $0.hasPrefix("Compiled") },
                      "the opening template compiled", file: file, line: line)
        return app
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

    /// Scrolls the controls until `target` is shown, at most ``maxDrags`` drags; true when it is. With `required`,
    /// fails the test at the caller's line when it never is.
    @MainActor
    @discardableResult
    static func reveal(_ app: XCUIApplication, _ target: XCUIElement, required: Bool = true,
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
        if required {
            XCTAssertTrue(found, "not reached by scrolling the controls: \(target)", file: file, line: line)
        }
        return found
    }

    /// Waits for the control `name`, scrolls it into view and returns it, or nil when it is not there.
    @MainActor
    static func shown(_ app: XCUIApplication, _ name: String, file: StaticString = #filePath, line: UInt = #line)
        -> XCUIElement? {
        let target = control(app, name)
        guard waitFor(target, timeout: shortWait, "\(name) is there", file: file, line: line),
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

    /// Puts the caret at the end of the document. The editor is as tall as its wrapped text plus one spare line
    /// (A22-P03), so a tap in that spare line places the caret after the last character: the controls are dragged
    /// until the editor's bottom edge is inside them (at most ``maxDrags`` drags), then the editor is tapped 6
    /// points above its bottom edge, near its right side. Waits for the keyboard focus; true when the editor has it.
    /// (⌘↓ from the hardware keyboard did not move the caret of this editor on the iOS 27.2 simulator, A22-P04.)
    @MainActor
    @discardableResult
    static func caretToEnd(_ app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) -> Bool {
        let e = editor(app)
        guard waitFor(e, timeout: shortWait, "the editor is there", file: file, line: line) else { return false }
        let list = controlsList(app)
        var drags = 0
        while drags < maxDrags, list.exists, e.exists,
              e.frame.maxY > list.frame.maxY - 2 || e.frame.maxY < list.frame.minY + 30 {
            let below = e.frame.maxY - (list.frame.maxY - 2)
            drag(app, by: below > 0 ? below + 24 : e.frame.maxY - list.frame.midY)
            drags += 1
        }
        let frame = e.frame
        e.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: frame.width * 0.9, dy: max(frame.height - 6, 1))).tap()
        func hasFocus() -> Bool { e.value(forKey: "hasKeyboardFocus") as? Bool ?? false }
        let deadline = Date().addingTimeInterval(shortWait)
        while !hasFocus(), Date() < deadline { usleep(200_000) }
        let focused = hasFocus()
        XCTAssertTrue(focused, "the editor has the keyboard focus", file: file, line: line)
        return focused
    }

    /// Appends `text` at the end of the document; true when the editor's text then ends with it.
    @MainActor
    @discardableResult
    static func append(_ app: XCUIApplication, _ text: String, file: StaticString = #filePath, line: UInt = #line)
        -> Bool {
        guard caretToEnd(app, file: file, line: line) else { return false }
        editor(app).typeText(text)
        let ends = waitForValue(editor(app)) { $0.hasSuffix(text) }
        XCTAssertTrue(ends, "the editor ends with the typed line: \(source(app))", file: file, line: line)
        return ends
    }

    /// Deletes the last `count` characters of the document (caret moved to the end first, then `count` presses of
    /// `XCUIKeyboardKey.delete`); true when the editor's text then equals `expected`.
    @MainActor
    @discardableResult
    static func deleteLast(_ app: XCUIApplication, _ count: Int, expecting expected: String,
                           file: StaticString = #filePath, line: UInt = #line) -> Bool {
        guard caretToEnd(app, file: file, line: line) else { return false }
        editor(app).typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: count))
        // A burst of deletes can lose a few keys on the simulator (A22-P04: three were left); the characters still
        // past the expected text are deleted again, at most three rounds.
        var rounds = 0
        while rounds < 3, !waitForValue(editor(app), timeout: 1, { $0 == expected }) {
            let now = source(app)
            guard now.hasPrefix(expected), now.count > expected.count else { break }
            editor(app).typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: now.count - expected.count))
            rounds += 1
        }
        let restored = waitForValue(editor(app)) { $0 == expected }
        XCTAssertTrue(restored, "the editor is back to the valid source: \(source(app))", file: file, line: line)
        return restored
    }

    /// Runs the document: the Run button when it can be brought into view (with the keyboard dismissed by the drag
    /// when the controls dismiss it), otherwise ⌘R on the hardware keyboard. Then waits until the status satisfies
    /// `condition`; true when it does.
    @MainActor
    @discardableResult
    static func run(_ app: XCUIApplication, until condition: @escaping (String) -> Bool,
                    file: StaticString = #filePath, line: UInt = #line) -> Bool {
        let button = control(app, "run")
        if waitFor(button, timeout: shortWait, "the Run button is there", file: file, line: line),
           reveal(app, button, required: false) {
            button.tap()
        } else {
            app.typeKey("r", modifierFlags: .command)
        }
        let deadline = Date().addingTimeInterval(runWait)
        while !condition(status(app)), Date() < deadline { usleep(200_000) }
        let reached = condition(status(app))
        XCTAssertTrue(reached, "the status after Run: \(status(app))", file: file, line: line)
        return reached
    }

    /// Waits until the label of `target` satisfies `condition`; true when it does.
    @MainActor
    static func waitForLabel(_ target: XCUIElement, timeout: TimeInterval = SS.shortWait,
                             _ condition: (String) -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while !(target.exists && condition(target.label)), Date() < deadline { usleep(200_000) }
        return target.exists && condition(target.label)
    }

    /// Waits until the value of `target` (as text) satisfies `condition`; true when it does.
    @MainActor
    static func waitForValue(_ target: XCUIElement, timeout: TimeInterval = SS.shortWait,
                             _ condition: (String) -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        func current() -> String { target.exists ? (target.value as? String ?? "") : "" }
        while !(target.exists && condition(current())), Date() < deadline { usleep(200_000) }
        return target.exists && condition(current())
    }

    /// Waits until `query` holds no element; true when it is empty.
    @MainActor
    static func waitUntilEmpty(_ query: XCUIElementQuery, timeout: TimeInterval = SS.shortWait) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while query.count > 0, Date() < deadline { usleep(200_000) }
        return query.count == 0
    }
}

// Feature 162 (A22-P04) T-A22-412 (FR-A22-407; contracts/limits.md "Guidance", "Library"): helpers of
// `SSLibraryUITests`. The guidance sentence under the status is `guidance` (its label). The library is opened with
// `library`; inside it `save` asks for a name in `project-name` and `save-confirm` saves; the rows are `project-<k>`
// (k from 0, newest first, labelled with the name); tapping a row selects it and `open`, `rename`, `remove` act on it.
// The library may be a sheet or a section, so its controls are tapped where they are (scrolled to only when not
// hittable), and the editor is reached again by closing a sheet that still covers it.
extension SS {
    /// The guidance sentence under the status (the `guidance` control's label, or its value when it has no label).
    @MainActor
    static func guidance(_ app: XCUIApplication) -> String {
        let g = control(app, "guidance")
        guard g.exists else { return "" }
        return g.label.isEmpty ? (g.value as? String ?? "") : g.label
    }

    /// The library row `k` (from 0, newest first).
    @MainActor
    static func project(_ app: XCUIApplication, _ k: Int) -> XCUIElement { control(app, "project-\(k)") }

    /// Waits for the control `name`, wherever it is (the controls or the library sheet), and taps it: directly when
    /// it can be tapped, otherwise after scrolling the controls to it. True when it was tapped.
    @MainActor
    @discardableResult
    static func tapAnywhere(_ app: XCUIApplication, _ name: String,
                            file: StaticString = #filePath, line: UInt = #line) -> Bool {
        let target = control(app, name)
        guard waitFor(target, timeout: shortWait, "\(name) is there", file: file, line: line) else { return false }
        if !target.isHittable { reveal(app, target, required: false) }
        let deadline = Date().addingTimeInterval(shortWait)
        while !target.isHittable, Date() < deadline { usleep(200_000) }
        XCTAssertTrue(target.isHittable, "\(name) can be tapped", file: file, line: line)
        guard target.isHittable else { return false }
        target.tap()
        return true
    }

    /// Brings the editor back: when a library sheet still covers it, the sheet is swiped down (at most twice). True
    /// when the editor can be tapped.
    @MainActor
    @discardableResult
    static func backToEditor(_ app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) -> Bool {
        let e = editor(app)
        var swipes = 0
        while swipes < 2, !(e.exists && e.isHittable) {
            let window = app.windows.firstMatch
            window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.15))
                .press(forDuration: 0.05, thenDragTo: window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.95)))
            _ = waitForHittable(e)
            swipes += 1
        }
        let back = e.exists && e.isHittable
        XCTAssertTrue(back, "the editor can be reached again", file: file, line: line)
        return back
    }

    /// Waits until `target` can be tapped; true when it can.
    @MainActor
    static func waitForHittable(_ target: XCUIElement, timeout: TimeInterval = SS.shortWait) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while !(target.exists && target.isHittable), Date() < deadline { usleep(200_000) }
        return target.exists && target.isHittable
    }
}
