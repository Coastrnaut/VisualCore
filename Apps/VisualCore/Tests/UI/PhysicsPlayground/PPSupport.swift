// PPSupport — feature 087 (A11-P06) T-A11-608 (FR-A11-630): helpers of the interface tests of Physics Playground (A11)
// inside the one app, modelled on `NASupport`. A11 was a candidate until X-A11 (integrated 2026-11-15); every launch still carries `-vcCandidates`
// (DebugLaunch: the candidates' catalog entries become available and are registered), and the tests open it directly
// with `-openExperience a11.physics-playground`. The controls are found by the identifiers of `PlaygroundControls`
// (`port.identifier(name)`, that is `experience.a11.physics-playground.<name>`): Drop circle and Drop box
// (`drop-circle`, `drop-box`, value "11 bodies"), Pause / Run (`pause`, value "Running"/"Paused"), Step (`step`,
// enabled only while paused), the time-scale segmented picker (`time-scale`: ¼×, ½×, 1×, 2×), the preset menu picker
// (`preset`: Free play, Pendulum, Spring chain, Stacked objects), the experiment line (`experiment`), the tutorial
// Start buttons (`tutorial-0-start`, `tutorial-1-start`), the running tutorial's step (`tutorial-progress`,
// `tutorial-step`), Stop (`tutorial-stop`), the Force arrows toggle (`force-arrows`, value "On"/"Off"), the status
// line (`status`), the state panel's note (`panel`) and the arrow note (`arrow-note`). They sit below the canvas in a
// scroll view of 280 points, and the list is long (about 2,000 points), so a control is scrolled into view before it
// is used; the stack is not lazy, so every control exists and its frame tells which way to scroll. The canvas label
// is the presenter's description ("Physics Playground: 11 bodies, running, normal speed (time scale 1×); …;
// none pinned, no selection, arrows off. Experiment: Free play." and, while a tutorial runs, "Tutorial: Controlling
// time, step 1 of 4: Pause the world."), which the tests read without scrolling. Everything lives in the namespace
// `PP`, so that nothing collides with the shared helpers of `AppUITestSupport` or the other experiences.
import Foundation
import XCTest

/// Launch arguments, identifiers and helpers of the A11 interface tests.
enum PP {
    /// The experience's id in the catalog.
    static let experienceID = "a11.physics-playground"
    /// The prefix of every identifier of the experience's controls.
    static let prefix = "experience.a11.physics-playground."
    /// The prefix of the canvas description.
    static let describedPrefix = "Physics Playground: "
    /// The debug argument that makes the candidates available (DebugLaunch).
    static let candidates = "-vcCandidates"
    /// A first start with erased data, straight into A11.
    static let fresh = [VC.reset, VC.skipWelcome, candidates, VC.openExperience, experienceID]
    /// The longest a single check waits (each test stays well under 60 s).
    static let shortWait: TimeInterval = 5
    /// The most drags one reveal makes.
    static let maxDrags = 24

    /// The full identifier of the control `name`.
    static func id(_ name: String) -> String { prefix + name }

    /// The control `name` of A11, of any element type.
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

    /// The spoken value of the control `name` (a button's state, a toggle's "On"/"Off"), or "" when it has none.
    @MainActor
    static func value(_ app: XCUIApplication, _ name: String) -> String {
        control(app, name).value as? String ?? ""
    }

    /// The number of bodies the description `text` names ("no bodies", "1 body", "11 bodies"), or nil.
    static func bodyCount(in text: String) -> Int? {
        guard text.hasPrefix(describedPrefix) else { return nil }
        let rest = text.dropFirst(describedPrefix.count)
        if rest.hasPrefix("no bodies") { return 0 }
        guard let range = rest.range(of: #"^\d+ bod(y|ies)"#, options: .regularExpression) else { return nil }
        return Int(rest[range].prefix { $0.isNumber })
    }

    /// The number of bodies on the canvas, or nil when the description names none.
    @MainActor
    static func bodyCount(_ app: XCUIApplication) -> Int? { bodyCount(in: description(app)) }

    /// Whether the description `text` says the world is paused (", paused, " follows the body count).
    static func isPaused(_ text: String) -> Bool {
        text.contains(" bodies, paused, ") || text.contains(" body, paused, ")
    }

    /// Whether the description `text` says the world runs.
    static func isRunning(_ text: String) -> Bool {
        text.contains(" bodies, running, ") || text.contains(" body, running, ")
    }

    /// Launches the app with `arguments` and waits until A11 runs: the experience route, its canvas described and its
    /// Drop circle button (the controls show it once the presenter is ready).
    @MainActor
    @discardableResult
    static func open(arguments: [String] = PP.fresh, file: StaticString = #filePath, line: UInt = #line)
        -> XCUIApplication {
        let app = launchApp(arguments: arguments)
        waitFor(element(app, "vc.route.experience"), timeout: VC.firstWait, file: file, line: line)
        waitFor(canvas(app), timeout: VC.firstWait, file: file, line: line)
        waitFor(control(app, "drop-circle"), timeout: VC.wait, file: file, line: line)
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
    /// with a hold at the end, so the list moves by the drag's length without a fling (the lesson of feature 066).
    /// `distance` is in points: positive moves the finger up, which shows the controls further down. It is cut to 85 %
    /// of the list's height and raised to 40 points, beyond the scroll view's touch slop.
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

    /// Scrolls the controls until `target` is shown: each drag moves the list toward the target's frame (the stack is
    /// not lazy, so an element off screen still has its frame), at most ``maxDrags`` drags. Fails the test at the
    /// caller's line when it never is.
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

    /// Scrolls the toggle `name` into view and flips it: the inner switch when there is one, otherwise the right end of
    /// the row, where the switch is drawn. Waits for the new value.
    @MainActor
    static func flip(_ app: XCUIApplication, _ name: String, file: StaticString = #filePath, line: UInt = #line) {
        let target = control(app, name)
        guard waitFor(target, timeout: shortWait, "\(name) is there", file: file, line: line),
              reveal(app, target, file: file, line: line) else { return }
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

    /// Scrolls the segmented picker `name` into view and taps the segment spoken as `segment` (each segment's
    /// accessibility label is its words, "half speed"). The segmented control is looked up by its identifier first,
    /// since the identifier may also be inherited by the segments; the segment is found by its label, then by
    /// `index` among `count` buttons, and as a last resort by its place on the control (segments share the width).
    @MainActor
    static func chooseSegment(_ app: XCUIApplication, _ name: String, _ segment: String, index: Int, of count: Int,
                              file: StaticString = #filePath, line: UInt = #line) {
        let control = app.segmentedControls.matching(identifier: id(name)).firstMatch
        let target = control.waitForExistence(timeout: shortWait) ? control : self.control(app, name)
        guard waitFor(target, timeout: shortWait, "\(name) is there", file: file, line: line),
              reveal(app, target, file: file, line: line) else { return }
        let labelled = target.buttons.matching(NSPredicate(format: "label ==[c] %@", segment)).firstMatch
        print("PP.chooseSegment \(name): control \(target.elementType.rawValue) frame \(target.frame) value " +
              "\(target.value as? String ?? "-") buttons \(target.buttons.count) labelled \(labelled.exists) " +
              "frame \(labelled.exists ? labelled.frame : .zero) hittable \(labelled.exists && labelled.isHittable)")
        if labelled.exists && labelled.isHittable {
            labelled.tap()
        } else if target.buttons.count == count {
            target.buttons.element(boundBy: index).tap()
        } else {
            let x = (CGFloat(index) + 0.5) / CGFloat(count)
            target.coordinate(withNormalizedOffset: CGVector(dx: x, dy: 0.5)).tap()
        }
        if waitForValue(target, timeout: 2, { $0 == segment }) { return }
        // The segment did not take the tap: tap its place on the control instead.
        print("PP.chooseSegment \(name): value still \(target.value as? String ?? "-"); tapping by place")
        let x = (CGFloat(index) + 0.5) / CGFloat(count)
        target.coordinate(withNormalizedOffset: CGVector(dx: x, dy: 0.5)).tap()
        XCTAssertTrue(waitForValue(target, timeout: shortWait) { $0 == segment },
                      "\(name) speaks \(segment) (now \(target.value as? String ?? "-"))", file: file, line: line)
    }

    /// Scrolls the menu picker `name` into view, opens it and picks the entry titled `option`. Waits until the picker
    /// speaks `option` as its value; true when it does.
    @MainActor
    @discardableResult
    static func pick(_ app: XCUIApplication, _ name: String, _ option: String,
                     file: StaticString = #filePath, line: UInt = #line) -> Bool {
        let picker = control(app, name)
        guard waitFor(picker, timeout: shortWait, "\(name) is there", file: file, line: line),
              reveal(app, picker, file: file, line: line) else { return false }
        picker.tap()
        // The open menu lists its entries as buttons (or menu items, depending on the system version).
        let predicate = NSPredicate(format: "label == %@", option)
        let candidates = [app.collectionViews.buttons.matching(predicate).firstMatch,
                          app.menuItems.matching(predicate).firstMatch,
                          app.buttons.matching(predicate).firstMatch]
        let deadline = Date().addingTimeInterval(shortWait)
        var entry: XCUIElement?
        while entry == nil, Date() < deadline {
            entry = candidates.first { $0.exists }
            if entry == nil { usleep(200_000) }
        }
        XCTAssertNotNil(entry, "the menu of \(name) offers \(option)", file: file, line: line)
        guard let entry else { return false }
        entry.tap()
        return waitForValue(picker, timeout: shortWait) { $0 == option }
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
    static func waitForValue(_ target: XCUIElement, timeout: TimeInterval = PP.shortWait,
                             _ condition: (String) -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while !(target.exists && condition(target.value as? String ?? "")), Date() < deadline { usleep(200_000) }
        return target.exists && condition(target.value as? String ?? "")
    }

    /// Waits until the canvas description satisfies `condition`; true when it does.
    @MainActor
    static func waitForDescription(_ app: XCUIApplication, timeout: TimeInterval = PP.shortWait,
                                   _ condition: (String) -> Bool) -> Bool {
        waitForLabel(canvas(app), timeout: timeout, condition)
    }

    /// Waits until `target` is enabled (`enabled` true) or disabled; true when it is.
    @MainActor
    static func waitForEnabled(_ target: XCUIElement, _ enabled: Bool, timeout: TimeInterval = PP.shortWait) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while !(target.exists && target.isEnabled == enabled), Date() < deadline { usleep(200_000) }
        return target.exists && target.isEnabled == enabled
    }
}
