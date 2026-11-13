// GASSupport — feature 193 (UA-F07) T-U07-015: helpers of the ported interface tests of Generative Art Studio (A01)
// inside the one app. A01 is a candidate, so every launch carries `-vcCandidates`; the tests open it directly with
// `-openExperience`. The controls are found by the identifiers of `GenerativeArtControls`
// (`experience.a01.generative-art-studio.<name>`). They sit below the canvas in a scroll view of limited height,
// so a control is scrolled into view before it is used. Everything lives in the namespace `GAS`, so that nothing
// collides with the shared helpers of `AppUITestSupport` or the file-private helpers of the other classes.
import Foundation
import XCTest

/// Launch arguments, identifiers and helpers of the A01 interface tests.
enum GAS {
    /// The experience's id in the catalog.
    static let experienceID = "a01.generative-art-studio"
    /// The prefix of every identifier of the experience's controls.
    static let prefix = "experience.a01.generative-art-studio."
    /// The debug argument that makes the candidates available (DebugLaunch).
    static let candidates = "-vcCandidates"
    /// The debug argument that damages every stored state before the model starts (DebugLaunch).
    static let damageState = "-vcDamageState"
    /// A first start with erased data, straight into A01.
    static let fresh = [VC.reset, VC.skipWelcome, candidates, VC.openExperience, experienceID]
    /// A further start that keeps the data, straight into A01.
    static let again = [VC.skipWelcome, candidates, VC.openExperience, experienceID]
    /// The four families: identifier suffix and title, in the order of the controls.
    static let families = [("gradient-noise", "Gradient Noise"), ("raymarched-shapes", "Raymarched Shapes"),
                           ("geometric-tiling", "Geometric Tiling"), ("particles", "Particles")]

    /// The full identifier of the control `name`.
    static func id(_ name: String) -> String { prefix + name }

    /// The control `name` of A01, of any element type.
    @MainActor
    static func control(_ app: XCUIApplication, _ name: String) -> XCUIElement {
        element(app, id(name))
    }

    /// The live canvas of the session.
    @MainActor
    static func canvas(_ app: XCUIApplication) -> XCUIElement {
        element(app, VC.canvas)
    }

    /// Launches the app with `arguments` and waits until A01 runs: the experience route, its canvas and its first
    /// control.
    @MainActor
    @discardableResult
    static func open(arguments: [String] = GAS.fresh, largeText: Bool = false,
                     file: StaticString = #filePath, line: UInt = #line) -> XCUIApplication {
        let app = launchApp(arguments: arguments, largeText: largeText)
        waitFor(element(app, "vc.route.experience"), file: file, line: line)
        waitFor(canvas(app), timeout: VC.firstWait, file: file, line: line)
        waitFor(control(app, "family.particles"), timeout: VC.wait, file: file, line: line)
        return app
    }

    /// The scroll view that holds the controls below the canvas.
    @MainActor
    static func controlsList(_ app: XCUIApplication) -> XCUIElement {
        app.scrollViews.containing(NSPredicate(format: "identifier BEGINSWITH %@", prefix)).firstMatch
    }

    /// One short drag on the controls near their left edge (inside the padding, so that no slider or button takes
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
            for _ in 0..<12 where !(target.exists && target.isHittable) { drag(app, forward: forward) }
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

    /// Waits until the label of `target` satisfies `condition`; true when it does.
    @MainActor
    static func waitForLabel(_ target: XCUIElement, timeout: TimeInterval = VC.wait,
                             _ condition: (String) -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while !(target.exists && condition(target.label)), Date() < deadline { usleep(200_000) }
        return target.exists && condition(target.label)
    }

    /// Waits until the canvas description starts with the family title `title`.
    @MainActor
    static func expectFamily(_ app: XCUIApplication, _ title: String,
                             file: StaticString = #filePath, line: UInt = #line) {
        let ok = waitForLabel(canvas(app)) { $0.hasPrefix(title + ", ") }
        XCTAssertTrue(ok, "the canvas shows \(title): \(canvas(app).label)", file: file, line: line)
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

    // MARK: Library

    /// The rename buttons of the saved entries, in the order shown (their labels are "Rename <name>").
    @MainActor
    static func renameButtons(_ app: XCUIApplication) -> XCUIElementQuery {
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@ AND label BEGINSWITH %@",
                                         id("library.rename."), "Rename "))
    }

    /// The names of the saved entries, in the order shown.
    @MainActor
    static func entryNames(_ app: XCUIApplication) -> [String] {
        renameButtons(app).allElementsBoundByIndex.map { String($0.label.dropFirst("Rename ".count)) }
    }

    /// The rename button of the entry called `name`.
    @MainActor
    static func renameButton(_ app: XCUIApplication, _ name: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@ AND label == %@",
                                         id("library.rename."), "Rename " + name)).firstMatch
    }

    /// The lowercased id of the entry called `name`, read from its rename button; nil when there is none.
    @MainActor
    static func entryID(_ app: XCUIApplication, _ name: String) -> String? {
        let button = renameButton(app, name)
        guard button.waitForExistence(timeout: VC.wait) else { return nil }
        let identifier = button.identifier
        let head = id("library.rename.")
        guard identifier.hasPrefix(head) else { return nil }
        return String(identifier.dropFirst(head.count))
    }

    /// Types `name` into the name field (replacing what is there), ends the editing with Return and saves; waits
    /// for the new entry.
    @MainActor
    static func save(_ app: XCUIApplication, as name: String, file: StaticString = #filePath, line: UInt = #line) {
        let field = control(app, "library.name")
        guard reveal(app, field, file: file, line: line) else { return }
        field.tap()
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 40) + name + "\n")
        tap(app, "save", file: file, line: line)
        waitFor(renameButton(app, name), timeout: VC.wait, "the entry \(name) after saving", file: file, line: line)
    }
}
