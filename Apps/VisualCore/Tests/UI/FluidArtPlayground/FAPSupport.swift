// FAPSupport — feature 193 (UA-F07) T-U07-022: helpers of the ported interface tests of Fluid Art Playground (A02)
// inside the one app. A02 is a candidate, so every launch carries `-vcCandidates`; the tests open it directly with
// `-openExperience`. The controls are found by the identifiers of `FluidArtControls`
// (`experience.a02.fluid-art-playground.<name>`). They sit below the canvas in a scroll view of limited height
// (about 280 points), so a control is scrolled into view before it is used: a slider adjusted without being revealed
// sends its drag to the canvas. Everything lives in the namespace `FAP`, so that nothing collides with the shared
// helpers of `AppUITestSupport` or with the helpers of the other ported apps.
import Foundation
import XCTest

/// Launch arguments, identifiers and helpers of the A02 interface tests.
enum FAP {
    /// The experience's id in the catalog.
    static let experienceID = "a02.fluid-art-playground"
    /// The experience's title (catalog name and route title).
    static let title = "Fluid Art Playground"
    /// The prefix of every identifier of the experience's controls.
    static let prefix = "experience.a02.fluid-art-playground."
    /// The debug argument that makes the candidates available (DebugLaunch).
    static let candidates = "-vcCandidates"
    /// A first start with erased data, straight into A02.
    static let fresh = [VC.reset, VC.skipWelcome, candidates, VC.openExperience, experienceID]
    /// The default brush text (`FluidConfiguration.brushRadius` 0.04).
    static let defaultBrush = "4% of the canvas"

    /// The full identifier of the control `name`.
    static func id(_ name: String) -> String { prefix + name }

    /// The control `name` of A02, of any element type.
    @MainActor
    static func control(_ app: XCUIApplication, _ name: String) -> XCUIElement {
        element(app, id(name))
    }

    /// The slider `name` of A02.
    @MainActor
    static func slider(_ app: XCUIApplication, _ name: String) -> XCUIElement {
        app.sliders[id(name)]
    }

    /// The live canvas of the session; its label is `FluidCanvasDescription.text`.
    @MainActor
    static func canvas(_ app: XCUIApplication) -> XCUIElement {
        element(app, VC.canvas)
    }

    /// Launches the app with `arguments` and waits until A02 runs: the experience route, its canvas and its first
    /// control.
    @MainActor
    @discardableResult
    static func open(arguments: [String] = FAP.fresh, largeText: Bool = false,
                     file: StaticString = #filePath, line: UInt = #line) -> XCUIApplication {
        let app = launchApp(arguments: arguments, largeText: largeText)
        waitFor(element(app, "vc.route.experience"), file: file, line: line)
        waitFor(canvas(app), timeout: VC.firstWait, file: file, line: line)
        waitFor(control(app, "splash"), timeout: VC.wait, file: file, line: line)
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
    static func value(_ app: XCUIApplication, _ name: String) -> String {
        slider(app, name).value as? String ?? ""
    }

    /// Waits until the spoken value of the slider `name` satisfies `condition`; true when it does.
    @MainActor
    static func waitForValue(_ app: XCUIApplication, _ name: String, timeout: TimeInterval = VC.wait,
                             _ condition: (String) -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition(value(app, name)), Date() < deadline { usleep(200_000) }
        return condition(value(app, name))
    }

    /// Waits until the label of `target` satisfies `condition`; true when it does.
    @MainActor
    static func waitForLabel(_ target: XCUIElement, timeout: TimeInterval = VC.wait,
                             _ condition: (String) -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while !(target.exists && condition(target.label)), Date() < deadline { usleep(200_000) }
        return target.exists && condition(target.label)
    }

    /// Waits until `target` is (or is not) selected; true when it is as asked.
    @MainActor
    static func waitForSelection(_ target: XCUIElement, _ selected: Bool = true,
                                 timeout: TimeInterval = VC.wait) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while target.isSelected != selected, Date() < deadline { usleep(200_000) }
        return target.isSelected == selected
    }

    /// Adds a screenshot that is kept with the result.
    @MainActor
    static func attachScreenshot(_ app: XCUIApplication, named name: String, to test: XCTestCase) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        test.add(shot)
    }
}
