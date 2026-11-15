// TWSupport — feature 094 (A12-P06) T-A12-609 (FR-A12-630): helpers of the interface tests of Tiny Worlds (A12) inside
// the one app, modelled on `PPSupport`. A12 was a candidate until X-A12 (integrated 2026-11-15); every launch still carries `-vcCandidates`
// (DebugLaunch: the candidates' catalog entries become available and are registered), and the tests open it directly
// with `-openExperience a12.tiny-worlds`. The controls are found by the identifiers of `WorldsControls`
// (`port.identifier(name)`, that is `experience.a12.tiny-worlds.<name>`): New seed (`new-seed`), Turn left and right
// (`turn-left`, `turn-right`, value "view from the north-east"), Zoom in and out (`zoom-in`, `zoom-out`, value
// "18 metres away"), Reset view (`reset-view`, value "view from the north-east, 35 degrees up, 18 metres away"), the
// status line (`status`), the segmented pack picker (`pack`: Island, Asteroid garden, Miniature city), Open pack
// (`open-pack`), Place (`place`, value "0 of 24 props"), the answer line (`message`), the sun-direction stepper
// (`light-azimuth`, value "30 degrees") and the slot rows (`slot-<n>-save`, `slot-<n>-status`, `slot-<n>-picture`).
// They sit below the canvas in a scroll view and the list is long, so a control is scrolled into view before it is
// used; the stack is not lazy, so every control exists and its frame tells which way to scroll. The canvas label is
// the presenter's description ("Tiny Worlds: Island, seed 1; view from the north-east, 35 degrees up, 18 metres
// away." and, with props, "…; 1 prop, the tree selected."), which the tests read without scrolling. Everything lives in
// the namespace `TW`, so that nothing collides with the shared helpers of `AppUITestSupport` or the other experiences.
import Foundation
import XCTest

/// Launch arguments, identifiers and helpers of the A12 interface tests.
enum TW {
    /// The experience's id in the catalog.
    static let experienceID = "a12.tiny-worlds"
    /// The prefix of every identifier of the experience's controls.
    static let prefix = "experience.a12.tiny-worlds."
    /// The prefix of the canvas description.
    static let describedPrefix = "Tiny Worlds: "
    /// The debug argument that makes the candidates available (DebugLaunch).
    static let candidates = "-vcCandidates"
    /// A first start with erased data, straight into A12.
    static let fresh = [VC.reset, VC.skipWelcome, candidates, VC.openExperience, experienceID]
    /// The longest a single check waits (each test stays well under 60 s).
    static let shortWait: TimeInterval = 5
    /// The most drags one reveal makes.
    static let maxDrags = 24

    /// The full identifier of the control `name`.
    static func id(_ name: String) -> String { prefix + name }

    /// The control `name` of A12, of any element type.
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

    /// The spoken value of the control `name`, or "" when it has none.
    @MainActor
    static func value(_ app: XCUIApplication, _ name: String) -> String {
        control(app, name).value as? String ?? ""
    }

    /// Launches the app with `arguments` and waits until A12 runs: the experience route, its canvas described and its
    /// New seed button (the controls show it once the presenter's first state has arrived).
    @MainActor
    @discardableResult
    static func open(arguments: [String] = TW.fresh, file: StaticString = #filePath, line: UInt = #line)
        -> XCUIApplication {
        let app = launchApp(arguments: arguments)
        waitFor(element(app, "vc.route.experience"), timeout: VC.firstWait, file: file, line: line)
        waitFor(canvas(app), timeout: VC.firstWait, file: file, line: line)
        waitFor(control(app, "new-seed"), timeout: VC.wait, file: file, line: line)
        XCTAssertTrue(waitForLabel(canvas(app)) { $0.hasPrefix(describedPrefix) },
                      "the canvas is described: \(description(app))", file: file, line: line)
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

    /// Scrolls the control `name` into view and taps it.
    @MainActor
    static func tap(_ app: XCUIApplication, _ name: String, file: StaticString = #filePath, line: UInt = #line) {
        let target = control(app, name)
        guard waitFor(target, timeout: shortWait, "\(name) is there", file: file, line: line),
              reveal(app, target, file: file, line: line) else { return }
        target.tap()
    }

    /// Scrolls the segmented picker `name` into view and taps the segment titled `segment`: found by its label, then
    /// by `index` among `count` buttons, and as a last resort by its place on the control (segments share the width).
    /// Waits until the picker speaks `segment`; true when it does.
    @MainActor
    @discardableResult
    static func chooseSegment(_ app: XCUIApplication, _ name: String, _ segment: String, index: Int, of count: Int,
                              file: StaticString = #filePath, line: UInt = #line) -> Bool {
        let control = app.segmentedControls.matching(identifier: id(name)).firstMatch
        let target = control.waitForExistence(timeout: shortWait) ? control : self.control(app, name)
        guard waitFor(target, timeout: shortWait, "\(name) is there", file: file, line: line),
              reveal(app, target, file: file, line: line) else { return false }
        let labelled = target.buttons.matching(NSPredicate(format: "label ==[c] %@", segment)).firstMatch
        let x = (CGFloat(index) + 0.5) / CGFloat(count)
        if labelled.exists && labelled.isHittable {
            labelled.tap()
        } else if target.buttons.count == count {
            target.buttons.element(boundBy: index).tap()
        } else {
            target.coordinate(withNormalizedOffset: CGVector(dx: x, dy: 0.5)).tap()
        }
        if waitForValue(target, timeout: 2, { $0 == segment }) { return true }
        // The segment did not take the tap: tap its place on the control instead.
        print("TW.chooseSegment \(name): value still \(target.value as? String ?? "-"); tapping by place")
        target.coordinate(withNormalizedOffset: CGVector(dx: x, dy: 0.5)).tap()
        return waitForValue(target, timeout: shortWait) { $0 == segment }
    }

    /// The stepper `name`: the system stepper with the identifier when there is one, else the control of any type.
    @MainActor
    static func stepper(_ app: XCUIApplication, _ name: String) -> XCUIElement {
        let stepper = app.steppers.matching(identifier: id(name)).firstMatch
        return stepper.exists ? stepper : control(app, name)
    }

    /// Scrolls the stepper `name` into view and presses its Increment button: the inner button whose label or
    /// identifier names it when there is one, otherwise the right end of the row, where the system stepper draws it.
    @MainActor
    static func increment(_ app: XCUIApplication, _ name: String,
                          file: StaticString = #filePath, line: UInt = #line) {
        let target = stepper(app, name)
        guard waitFor(target, timeout: shortWait, "\(name) is there", file: file, line: line),
              reveal(app, target, file: file, line: line) else { return }
        let inner = target.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@ OR identifier CONTAINS[c] %@",
                                                        "Increment", "Increment")).firstMatch
        if inner.exists, inner.isHittable {
            inner.tap()
        } else {
            target.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
        }
    }

    /// Taps the control `name` up to `times` times, until its spoken value differs from `before`; true when it does.
    @MainActor
    @discardableResult
    static func tapUntilChanged(_ app: XCUIApplication, _ name: String, from before: String, times: Int,
                                file: StaticString = #filePath, line: UInt = #line) -> Bool {
        for _ in 0..<times {
            tap(app, name, file: file, line: line)
            if waitForValue(control(app, name), timeout: 2, { !$0.isEmpty && $0 != before }) { return true }
        }
        return false
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
    static func waitForValue(_ target: XCUIElement, timeout: TimeInterval = TW.shortWait,
                             _ condition: (String) -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while !(target.exists && condition(target.value as? String ?? "")), Date() < deadline { usleep(200_000) }
        return target.exists && condition(target.value as? String ?? "")
    }

    /// Waits until the canvas description satisfies `condition`; true when it does.
    @MainActor
    static func waitForDescription(_ app: XCUIApplication, timeout: TimeInterval = TW.shortWait,
                                   _ condition: (String) -> Bool) -> Bool {
        waitForLabel(canvas(app), timeout: timeout, condition)
    }
}
