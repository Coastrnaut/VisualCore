// AUSupport — feature 156 (A21-P05) T-A21-506, T-A21-507 (FR-A21-506; SC-A21-503): helpers of the interface tests of
// Aurora (A21) inside the one app, modelled on `ZGSupport`. A21 was a candidate until X-A21 (integrated 2026-11-17);
// every launch carries `-vcCandidates` (DebugLaunch: the candidates' catalog entries become available and are
// registered; harmless now that A21 is integrated). A fresh start erases the data (`-vcResetData`, so the stored sky
// preferences are gone), skips the welcome and opens the experience
// directly with `-openExperience a21.aurora`; a relaunch (`AU.relaunch`) is the same start without the reset, so the
// stored preferences (the sound choice and the volume among them) survive. A fresh sky is Polar night, sound Off,
// volume 50 %, Still sky Off and Reduced flashing Off.
//
// The canvas (`session.canvas`) is labelled with the presenter's description (`AuroraPresenter.describe`): "Aurora, "
// then the preset's name, the colour shift, the speed, the ribbons, the stars, the clouds and the brightness limit.
// The controls are found by the identifiers of `AuroraControls` (`port.identifier(name)`, that is
// `experience.a21.aurora.<name>`): the segmented picker `preset` (Polar night, Violet veil, Dawn haze), the sliders
// `hue`, `speed`, `turbulence`, `clouds`, `limit` and `volume` (value for example "50 %"), the steppers `ribbons` and
// `stars`, the toggles `sound`, `still` and `reduced-flash` (value "On" or "Off"), the button `hide-controls` and, while
// the controls are hidden, the text `show-controls` ("Controls hidden. Tap the sky to show them."). The controls sit
// below the canvas in a scroll view; a control is scrolled into view before it is used, with slow drags near the left
// edge (inside the padding, so that no control takes the touch). Everything lives in the namespace `AU`, so that
// nothing collides with the shared helpers of `AppUITestSupport` or the other experiences.
import Foundation
import XCTest

/// Launch arguments, identifiers and helpers of the A21 interface tests.
enum AU {
    /// The experience's id in the catalog.
    static let experienceID = "a21.aurora"
    /// The prefix of every identifier of the experience's controls.
    static let prefix = "experience.a21.aurora."
    /// The debug argument that makes the candidates available (DebugLaunch).
    static let candidates = "-vcCandidates"
    /// A first start with erased data, straight into A21.
    static let fresh = [VC.reset, VC.skipWelcome, candidates, VC.openExperience, experienceID]
    /// A start over the same storage (no reset), straight into A21.
    static let relaunch = [VC.skipWelcome, candidates, VC.openExperience, experienceID]
    /// The longest a single check waits (each test stays well under 60 s).
    static let shortWait: TimeInterval = 5
    /// The most drags one reveal makes.
    static let maxDrags = 24
    /// The preset titles, in the order of `SkyPresets.all`.
    static let presets = ["Polar night", "Violet veil", "Dawn haze"]

    /// The full identifier of the control `name`.
    static func id(_ name: String) -> String { prefix + name }

    /// The control `name` of A21, of any element type.
    @MainActor
    static func control(_ app: XCUIApplication, _ name: String) -> XCUIElement {
        element(app, id(name))
    }

    /// The value of the control `name` as text, or "" when it has none.
    @MainActor
    static func value(_ app: XCUIApplication, _ name: String) -> String {
        control(app, name).value as? String ?? ""
    }

    /// Whether a toggle's value reads on: "On" (the spoken value) or "1" (a plain switch).
    static func isOn(_ value: String) -> Bool { value == "On" || value == "1" }

    /// Whether a toggle's value reads off: "Off" (the spoken value) or "0" (a plain switch).
    static func isOff(_ value: String) -> Bool { value == "Off" || value == "0" }

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

    /// Launches the app with `arguments` and waits until A21 runs.
    @MainActor
    @discardableResult
    static func open(arguments: [String] = AU.fresh, file: StaticString = #filePath, line: UInt = #line)
        -> XCUIApplication {
        let app = launchApp(arguments: arguments)
        waitForRunning(app, file: file, line: line)
        return app
    }

    /// Ends `app` after a moment in which the stored preferences reach the disk, and opens A21 again over the same
    /// storage (``relaunch``, no reset).
    @MainActor
    @discardableResult
    static func reopen(_ app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line)
        -> XCUIApplication {
        usleep(1_000_000)
        app.terminate()
        let second = launchApp(arguments: AU.relaunch)
        waitForRunning(second, file: file, line: line)
        return second
    }

    /// Waits for the experience route, the canvas labelled with a sky and the preset picker (the controls show it once
    /// the presenter's first state has arrived).
    @MainActor
    private static func waitForRunning(_ app: XCUIApplication, file: StaticString, line: UInt) {
        waitFor(element(app, "vc.route.experience"), timeout: VC.firstWait, file: file, line: line)
        waitFor(canvas(app), timeout: VC.firstWait, file: file, line: line)
        waitFor(control(app, "preset"), timeout: VC.wait, "the preset picker is there", file: file, line: line)
        XCTAssertTrue(waitForLabel(canvas(app)) { $0.hasPrefix("Aurora") },
                      "the canvas is labelled with the sky: \(description(app))", file: file, line: line)
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

    /// Scrolls the controls until `target` is shown, at most ``maxDrags`` drags. Fails the test at the caller's line
    /// when it never is.
    @MainActor
    @discardableResult
    static func reveal(_ app: XCUIApplication, _ target: XCUIElement,
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
        XCTAssertTrue(found, "not reached by scrolling the controls: \(target)", file: file, line: line)
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

    /// Chooses the preset titled `title` on the segmented `preset` picker; true when the picker then names it (its
    /// value).
    @MainActor
    @discardableResult
    static func choosePreset(_ app: XCUIApplication, _ title: String,
                             file: StaticString = #filePath, line: UInt = #line) -> Bool {
        guard let picker = shown(app, "preset", file: file, line: line) else { return false }
        if value(app, "preset") == title { return true }
        var segment = picker.buttons[title]
        if !segment.exists { segment = app.segmentedControls.buttons[title] }
        guard waitFor(segment, timeout: shortWait, "the \(title) segment is there", file: file, line: line) else {
            return false
        }
        segment.tap()
        let chosen = waitForValue(picker) { $0 == title }
        XCTAssertTrue(chosen, "the preset picker names \(title) (now \(value(app, "preset")))", file: file, line: line)
        return chosen
    }

    /// Scrolls the toggle `name` into view and flips it: the inner switch when there is one, otherwise the right end of
    /// the row, where the switch is drawn. Waits for the new value; true when it changed.
    @MainActor
    @discardableResult
    static func flip(_ app: XCUIApplication, _ name: String, file: StaticString = #filePath, line: UInt = #line)
        -> Bool {
        guard let target = shown(app, name, file: file, line: line) else { return false }
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

    /// Flips the toggle `name` unless it already reads on; true when it then reads on.
    @MainActor
    @discardableResult
    static func turnOn(_ app: XCUIApplication, _ name: String, file: StaticString = #filePath, line: UInt = #line)
        -> Bool {
        guard waitFor(control(app, name), timeout: shortWait, "\(name) is there", file: file, line: line) else {
            return false
        }
        if isOn(value(app, name)) { return true }
        flip(app, name, file: file, line: line)
        let on = waitForValue(control(app, name)) { isOn($0) }
        XCTAssertTrue(on, "\(name) reads on (now \(value(app, name)))", file: file, line: line)
        return on
    }

    /// Waits until the label of `target` satisfies `condition`; true when it does.
    @MainActor
    static func waitForLabel(_ target: XCUIElement, timeout: TimeInterval = AU.shortWait,
                             _ condition: (String) -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while !(target.exists && condition(target.label)), Date() < deadline { usleep(200_000) }
        return target.exists && condition(target.label)
    }

    /// Waits until the value of `target` (as text) satisfies `condition`; true when it does.
    @MainActor
    static func waitForValue(_ target: XCUIElement, timeout: TimeInterval = AU.shortWait,
                             _ condition: (String) -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        func current() -> String { target.exists ? (target.value as? String ?? "") : "" }
        while !(target.exists && condition(current())), Date() < deadline { usleep(200_000) }
        return target.exists && condition(current())
    }

    /// Waits until the canvas description satisfies `condition`; true when it does.
    @MainActor
    static func waitForDescription(_ app: XCUIApplication, timeout: TimeInterval = AU.shortWait,
                                   _ condition: (String) -> Bool) -> Bool {
        waitForLabel(canvas(app), timeout: timeout, condition)
    }
}
