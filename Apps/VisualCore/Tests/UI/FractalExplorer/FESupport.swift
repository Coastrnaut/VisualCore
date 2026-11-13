// FESupport — feature 193 (UA-F07) T-U07-025: helpers of the ported interface tests of Fractal Explorer (A03) inside
// the one app. A03 is a candidate, so every launch carries `-vcCandidates`; the tests open it directly with
// `-openExperience`. The controls are found by the identifiers of `FractalControls`
// (`experience.a03.fractal-explorer.<name>`). They sit below the canvas in a scroll view of limited height (about 280
// points), so a control is scrolled into view before it is used. The canvas label is the spoken description of the
// view (`FractalState.spokenDescription`, for example "Mandelbrot set, centered at −0.5 + 0i, zoom 1×"). Everything
// lives in the namespace `FE`, so that nothing collides with the shared helpers of `AppUITestSupport` or with the
// helpers of the other ported apps.
import Foundation
import XCTest

/// Launch arguments, identifiers and helpers of the A03 interface tests.
enum FE {
    /// The experience's id in the catalog.
    static let experienceID = "a03.fractal-explorer"
    /// The experience's title (catalog name and route title).
    static let title = "Fractal Explorer"
    /// The prefix of every identifier of the experience's controls.
    static let prefix = "experience.a03.fractal-explorer."
    /// The debug argument that makes the candidates available (DebugLaunch).
    static let candidates = "-vcCandidates"
    /// A first start with erased data, straight into A03.
    static let fresh = [VC.reset, VC.skipWelcome, candidates, VC.openExperience, experienceID]
    /// A further start that keeps the data (the bookmarks in the experience's storage), straight into A03.
    static let again = [VC.skipWelcome, candidates, VC.openExperience, experienceID]
    /// The spoken description of the default Mandelbrot view.
    static let defaultMandelbrot = "Mandelbrot set, centered at −0.5 + 0i, zoom 1×"
    /// The spoken description of the default Julia view.
    static let defaultJulia = "Julia set for seed −0.8 + 0.156i, centered at 0 + 0i, zoom 1×"
    /// The render-cost line of the default iteration cap.
    static let defaultCost = "Render cost: 1× the default view (light)"

    /// The full identifier of the control `name`.
    static func id(_ name: String) -> String { prefix + name }

    /// The control `name` of A03, of any element type.
    @MainActor
    static func control(_ app: XCUIApplication, _ name: String) -> XCUIElement {
        element(app, id(name))
    }

    /// The live canvas of the session; its label is the spoken description of the view.
    @MainActor
    static func canvas(_ app: XCUIApplication) -> XCUIElement {
        element(app, VC.canvas)
    }

    /// Launches the app with `arguments` and waits until A03 runs: the experience route, its canvas and its first
    /// control.
    @MainActor
    @discardableResult
    static func open(arguments: [String] = FE.fresh, largeText: Bool = false,
                     file: StaticString = #filePath, line: UInt = #line) -> XCUIApplication {
        let app = launchApp(arguments: arguments, largeText: largeText)
        waitFor(element(app, "vc.route.experience"), file: file, line: line)
        waitFor(canvas(app), timeout: VC.firstWait, file: file, line: line)
        waitFor(control(app, "mode.mandelbrot"), timeout: VC.wait, file: file, line: line)
        return app
    }

    /// The scroll view that holds the controls below the canvas.
    @MainActor
    static func controlsList(_ app: XCUIApplication) -> XCUIElement {
        app.scrollViews.containing(NSPredicate(format: "identifier BEGINSWITH %@", prefix)).firstMatch
    }

    /// The part of the controls a person sees: the list's frame, above the home indicator when the list reaches the
    /// bottom of the window (the indicator overlays the last 34 points of an iPhone without a home button).
    @MainActor
    static func visibleControls(_ app: XCUIApplication) -> CGRect {
        var frame = controlsList(app).frame
        let window = app.windows.firstMatch.frame
        if !isTablet, frame.maxY >= window.maxY - 1 { frame.size.height = max(0, frame.height - 34) }
        return frame
    }

    /// One short drag on the controls near their left edge (inside the padding, so that no button or field takes
    /// the touch). `forward` moves the finger up, which shows the controls further down.
    @MainActor
    static func drag(_ app: XCUIApplication, forward: Bool) {
        let list = controlsList(app)
        let area = list.exists ? list : app.windows.firstMatch
        let start = area.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: forward ? 0.8 : 0.2))
            .withOffset(CGVector(dx: 8, dy: 0))
        let end = area.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: forward ? 0.3 : 0.7))
            .withOffset(CGVector(dx: 8, dy: 0))
        start.press(forDuration: 0.05, thenDragTo: end)
    }

    /// Scrolls the controls until `target` exists and can be tapped: first further down, then back up. Fails the
    /// test at the caller's line when it never can.
    @MainActor
    @discardableResult
    static func reveal(_ app: XCUIApplication, _ target: XCUIElement,
                       file: StaticString = #filePath, line: UInt = #line) -> Bool {
        _ = target.waitForExistence(timeout: VC.wait)
        for forward in [true, false] {
            for _ in 0..<14 where !(target.exists && target.isHittable) { drag(app, forward: forward) }
        }
        let found = target.exists && target.isHittable
        XCTAssertTrue(found, "not reached by scrolling the controls: \(target)", file: file, line: line)
        return found
    }

    /// Scrolls the control `name` into view and taps it.
    @MainActor
    static func tap(_ app: XCUIApplication, _ name: String, file: StaticString = #filePath, line: UInt = #line) {
        let target = control(app, name)
        guard reveal(app, target, file: file, line: line) else { return }
        target.tap()
    }

    /// Scrolls the text field `name` into view, replaces its text with `text` and ends the editing with Return, so
    /// that the keyboard does not cover the controls for the next step.
    @MainActor
    static func type(_ app: XCUIApplication, _ name: String, _ text: String,
                     file: StaticString = #filePath, line: UInt = #line) {
        let field = control(app, name)
        guard reveal(app, field, file: file, line: line) else { return }
        field.tap()
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 24) + text + "\n")
    }

    /// Waits until the label of `target` satisfies `condition`; true when it does.
    @MainActor
    static func waitForLabel(_ target: XCUIElement, timeout: TimeInterval = VC.wait,
                             _ condition: (String) -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while !(target.exists && condition(target.label)), Date() < deadline { usleep(200_000) }
        return target.exists && condition(target.label)
    }

    /// Waits until the canvas description satisfies `condition`; fails at the caller's line with `message` and the
    /// description when it never does.
    @MainActor
    static func expectCanvas(_ app: XCUIApplication, _ message: String, timeout: TimeInterval = VC.wait,
                             file: StaticString = #filePath, line: UInt = #line, _ condition: (String) -> Bool) {
        let target = canvas(app)
        let ok = waitForLabel(target, timeout: timeout, condition)
        XCTAssertTrue(ok, "\(message): '\(target.label)'", file: file, line: line)
    }

    /// Waits until `target` is (or is not) selected; true when it is as asked.
    @MainActor
    static func waitForSelection(_ target: XCUIElement, _ selected: Bool = true,
                                 timeout: TimeInterval = VC.wait) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while target.isSelected != selected, Date() < deadline { usleep(200_000) }
        return target.isSelected == selected
    }

    /// The zoom the canvas description names ("zoom 4×" gives 4), or nil when it names none that reads as a number.
    @MainActor
    static func zoom(_ app: XCUIApplication) -> Double? {
        let label = canvas(app).label
        guard let range = label.range(of: "zoom ", options: .backwards) else { return nil }
        let text = label[range.upperBound...].prefix { $0 != "×" }
        return Double(text)
    }

    /// Sends the app to the background (which stores the open experience's state) and ends it.
    @MainActor
    static func suspendAndEnd(_ app: XCUIApplication) {
        XCUIDevice.shared.press(.home)
        _ = app.wait(for: .runningBackground, timeout: VC.wait)
        usleep(1_000_000)
        app.terminate()
    }

    /// Adds a screenshot that is kept with the result.
    @MainActor
    static func attachScreenshot(_ app: XCUIApplication, named name: String, to test: XCTestCase) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        test.add(shot)
    }

    // MARK: Bookmarks

    /// The rename button of the bookmark called `name` (its label is "Rename <name>").
    @MainActor
    static func renameButton(_ app: XCUIApplication, _ name: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@ AND label == %@",
                                         id("bookmark.rename."), "Rename " + name)).firstMatch
    }

    /// The bookmarks' rename buttons, one per saved view.
    @MainActor
    static func bookmarkRows(_ app: XCUIApplication) -> XCUIElementQuery {
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", id("bookmark.rename.")))
    }

    /// The lowercased id of the bookmark called `name`, read from its rename button; nil when there is none.
    @MainActor
    static func bookmarkID(_ app: XCUIApplication, _ name: String) -> String? {
        let button = renameButton(app, name)
        guard button.waitForExistence(timeout: VC.wait) else { return nil }
        let head = id("bookmark.rename.")
        guard button.identifier.hasPrefix(head) else { return nil }
        return String(button.identifier.dropFirst(head.count))
    }

    /// Types `name` into the bookmark name field and saves the current view; waits for its row.
    @MainActor
    static func saveBookmark(_ app: XCUIApplication, as name: String,
                             file: StaticString = #filePath, line: UInt = #line) {
        type(app, "bookmark.name", name, file: file, line: line)
        tap(app, "bookmark.save", file: file, line: line)
        waitFor(renameButton(app, name), timeout: VC.wait, "the bookmark \(name) after saving", file: file, line: line)
    }

    /// Dismisses a confirmation: Cancel when there is one; from iOS 26 the confirmation can be a popover without
    /// Cancel, on a phone too, which a tap outside it dismisses. That tap goes to the canvas (a third down the
    /// window), where a tap without movement does not move the view.
    @MainActor
    static func dismissConfirmation(_ app: XCUIApplication) {
        let cancel = app.buttons["Cancel"].firstMatch
        if cancel.exists {
            cancel.tap()
        } else {
            app.windows.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.3)).tap()
        }
    }
}
