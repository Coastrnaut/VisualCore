// ACSupport — feature 135 (A18-P05) T-A18-505 (FR-A18-505; SC-A18-504): helpers of the interface tests of Ambient
// Clock (A18) inside the one app, modelled on `IASupport`. A18 was a candidate until X-A18 (integrated 2026-11-16);
// every launch carries `-vcCandidates` (DebugLaunch: the candidates' catalog entries become available and are
// registered; harmless once A18 is integrated). A first start erases the data
// (`-vcResetData`), skips the welcome and opens the experience directly with `-openExperience a18.ambient-clock`;
// ``again`` opens it once more without the reset, so the shell restores the stored snapshot (schema 3: night mode,
// in-app reduced motion and keep-awake among it). The canvas is labelled with the display's spoken string
// (`AmbientPresenter.describe`: the time, and the date when shown), or "Ambient Clock" before the first instant; the
// overlay that draws the time is hidden from assistive technology. The controls are found by the identifiers of
// `AmbientControls` (`port.identifier(name)`, that is `experience.a18.ambient-clock.<name>`): the menus (`hour-cycle`,
// `theme`, `palette`, `night-mode` valued "Off", "On" or "Scheduled") and the toggles (`seconds`, `date`, `motion`,
// `reduce-motion`, `keep-awake`, valued "On" or "Off"). The controls sit below the canvas in a scroll view; a control
// is scrolled into view before it is used, with slow drags near the left edge (inside the padding, so that no button
// takes the touch). Everything lives in the namespace `AC`, so that nothing collides with the shared helpers of
// `AppUITestSupport` or the other experiences.
import Foundation
import XCTest

/// Launch arguments, identifiers and helpers of the A18 interface tests.
enum AC {
    /// The experience's id in the catalog.
    static let experienceID = "a18.ambient-clock"
    /// The prefix of every identifier of the experience's controls.
    static let prefix = "experience.a18.ambient-clock."
    /// The canvas label before the first instant (`AmbientPresenter.fallbackDescription`).
    static let fallbackDescription = "Ambient Clock"
    /// The debug argument that makes the candidates available (DebugLaunch).
    static let candidates = "-vcCandidates"
    /// A first start with erased data, straight into A18.
    static let fresh = [VC.reset, VC.skipWelcome, candidates, VC.openExperience, experienceID]
    /// A later start that keeps the data, straight into A18.
    static let again = [VC.skipWelcome, candidates, VC.openExperience, experienceID]
    /// The longest a single check waits (each test stays well under 60 s).
    static let shortWait: TimeInterval = 5
    /// The most drags one reveal makes.
    static let maxDrags = 24

    /// The full identifier of the control `name`.
    static func id(_ name: String) -> String { prefix + name }

    /// The control `name` of A18, of any element type.
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

    /// Whether `text` reads as a clock time: it holds a ":" with a digit on each side ("10:42", "22:05:09").
    static func isTime(_ text: String) -> Bool {
        text.range(of: #"\d:\d"#, options: .regularExpression) != nil
    }

    /// The spoken value of the control `name`, or "" when it has none.
    @MainActor
    static func value(_ app: XCUIApplication, _ name: String) -> String {
        control(app, name).value as? String ?? ""
    }

    /// Launches the app with `arguments` and waits until A18 runs: the experience route, the canvas labelled with a
    /// time and the night-mode menu (the controls show it once the presenter's first state has arrived).
    @MainActor
    @discardableResult
    static func open(arguments: [String] = AC.fresh, file: StaticString = #filePath, line: UInt = #line)
        -> XCUIApplication {
        let app = launchApp(arguments: arguments)
        waitForRunning(app, file: file, line: line)
        return app
    }

    /// Sends `app` to the background (the shell writes the experience's snapshot on the suspension), ends it after a
    /// moment in which the stores reach the disk, and opens A18 again without erasing the data.
    @MainActor
    @discardableResult
    static func reopen(_ app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line)
        -> XCUIApplication {
        XCUIDevice.shared.press(.home)
        _ = app.wait(for: .runningBackground, timeout: shortWait)
        let second = relaunch(app, arguments: AC.again)
        waitForRunning(second, file: file, line: line)
        return second
    }

    /// Waits for the experience route, the canvas labelled with a time and the night-mode menu.
    @MainActor
    private static func waitForRunning(_ app: XCUIApplication, file: StaticString, line: UInt) {
        waitFor(element(app, "vc.route.experience"), timeout: VC.firstWait, file: file, line: line)
        waitFor(canvas(app), timeout: VC.firstWait, file: file, line: line)
        waitFor(control(app, "night-mode"), timeout: VC.wait, file: file, line: line)
        XCTAssertTrue(waitForLabel(canvas(app), timeout: shortWait) { isTime($0) },
                      "the canvas is labelled with a time: \(description(app))", file: file, line: line)
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

    /// One slow drag on the controls near their left edge (inside the padding, so that no button takes the touch),
    /// with a hold at the end, so the list moves by the drag's length without a fling. `distance` is in points:
    /// positive moves the finger up, which shows the controls further down. It is cut to 85 % of the list's height and
    /// raised to 40 points, beyond the scroll view's touch slop.
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

    /// Scrolls the controls until `target` is shown: each drag moves the list toward the target's frame, at most
    /// ``maxDrags`` drags. Fails the test at the caller's line when it never is.
    @MainActor
    @discardableResult
    static func reveal(_ app: XCUIApplication, _ target: XCUIElement,
                       file: StaticString = #filePath, line: UInt = #line) -> Bool {
        var drags = 0
        while drags < maxDrags, target.exists, !isShown(app, target) {
            let list = controlsList(app)
            let middle = list.exists ? list.frame.midY : app.windows.firstMatch.frame.midY
            var distance = target.frame.midY - middle
            // A target whose frame sits in the middle but cannot be tapped yet: nudge the list once downward.
            if abs(distance) < 1 { distance = 40 }
            drag(app, by: distance)
            drags += 1
        }
        let found = isShown(app, target)
        XCTAssertTrue(found, "not reached by scrolling the controls: \(target)", file: file, line: line)
        return found
    }

    /// Scrolls the menu `name` into view, opens it, chooses the option titled `option` and waits until the menu is
    /// valued `option`; true when it is. The option is looked for among the buttons, then the menu items, of the
    /// whole app (the menu is presented above the controls), and only a hittable one is tapped.
    @MainActor
    @discardableResult
    static func choose(_ app: XCUIApplication, _ name: String, _ option: String,
                       file: StaticString = #filePath, line: UInt = #line) -> Bool {
        let menu = control(app, name)
        guard waitFor(menu, timeout: shortWait, "\(name) is there", file: file, line: line),
              reveal(app, menu, file: file, line: line) else { return false }
        if value(app, name) == option { return true }
        menu.tap()
        let titled = NSPredicate(format: "label == %@", option)
        let deadline = Date().addingTimeInterval(shortWait)
        var item: XCUIElement?
        while item == nil, Date() < deadline {
            let candidates = app.buttons.matching(titled).allElementsBoundByIndex
                + app.menuItems.matching(titled).allElementsBoundByIndex
            item = candidates.first { $0.exists && $0.isHittable && $0.identifier != menu.identifier }
            if item == nil { usleep(200_000) }
        }
        guard let item else {
            XCTFail("\(name): no option \(option) after opening the menu", file: file, line: line)
            return false
        }
        item.tap()
        let chosen = waitForValue(menu) { $0 == option }
        XCTAssertTrue(chosen, "\(name) is valued \(option) (now \(value(app, name)))", file: file, line: line)
        return chosen
    }

    /// Scrolls the toggle `name` into view and flips it: the inner switch when there is one, otherwise the right end of
    /// the row, where the switch is drawn. Waits for the new value; true when it changed.
    @MainActor
    @discardableResult
    static func flip(_ app: XCUIApplication, _ name: String, file: StaticString = #filePath, line: UInt = #line)
        -> Bool {
        let target = control(app, name)
        guard waitFor(target, timeout: shortWait, "\(name) is there", file: file, line: line),
              reveal(app, target, file: file, line: line) else { return false }
        let before = value(app, name)
        let inner = target.switches.firstMatch
        if inner.exists {
            inner.tap()
        } else {
            target.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
        }
        let changed = waitForValue(target) { $0 != before }
        XCTAssertTrue(changed, "\(name) did not change from \(before)", file: file, line: line)
        return changed
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
    static func waitForValue(_ target: XCUIElement, timeout: TimeInterval = AC.shortWait,
                             _ condition: (String) -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while !(target.exists && condition(target.value as? String ?? "")), Date() < deadline { usleep(200_000) }
        return target.exists && condition(target.value as? String ?? "")
    }
}
