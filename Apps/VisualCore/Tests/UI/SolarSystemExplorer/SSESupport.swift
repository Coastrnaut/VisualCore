// SSESupport — feature 108 (A14-P06) T-A14-609 (FR-A14-630; clarification Q4): helpers of the interface tests of Solar
// System Explorer (A14) inside the one app, modelled on `LMSupport`. A14 is a candidate until X-A14 (its registration
// sits in `ExperienceRegistry.candidates`); every launch carries `-vcCandidates` (DebugLaunch: the candidates' catalog
// entries become available and are registered), starts with erased data (`-vcResetData`, so the state is fresh: the
// Sun selected at 2000-01-01, the enhanced scale, paused at 1 day/s, no tour and no saved view), skips the welcome and
// opens the experience directly with `-openExperience a14.solar-system-explorer`. The controls are found by the
// identifiers of `SolarControls` (`port.identifier(name)`, that is `experience.a14.solar-system-explorer.<name>`): the
// date (`date`, value "2000-01-01"), the date buttons (`date-minus-365` … `date-plus-365`), the Body menu (`body`; its
// items are buttons titled with the body's name), Play/Pause (`play-pause`), the Scale picker (`scale`, segments
// "Enhanced" and "True relative"), the Tour menu (`tour`; items "Inner planets", "Giant planets"; value
// "Inner planets, stop 1 of 5" or "No tour"), Next stop, Pause tour and Stop tour (`tour-next`, `tour-pause`,
// `tour-stop`), Save view and Restore view (`save-view`, `restore-view`, answered in `view-message`), the legend
// (`legend`, value the scale label), the status line (`status`, value "Earth selected, body 4 of 9") and the answer
// line (`message`). The canvas overlay (labels and caption) is hidden from accessibility, so the tests read the
// status, legend, date and the canvas label (`session.canvas`), which is the presenter's description ("Solar System
// Explorer: Sun in focus on 2000-01-01; 9 bodies. … Tour Inner planets, stop 1 of 5: …"). The controls sit below the
// canvas in a scroll view, so a control is scrolled into view before it is used. Everything lives in the namespace
// `SSE`, so that nothing collides with the shared helpers of `AppUITestSupport` or the other experiences.
import Foundation
import XCTest

/// Launch arguments, identifiers and helpers of the A14 interface tests.
enum SSE {
    /// The experience's id in the catalog.
    static let experienceID = "a14.solar-system-explorer"
    /// The prefix of every identifier of the experience's controls.
    static let prefix = "experience.a14.solar-system-explorer."
    /// The prefix of the canvas description.
    static let describedPrefix = "Solar System Explorer: "
    /// The debug argument that makes the candidates available (DebugLaunch).
    static let candidates = "-vcCandidates"
    /// A first start with erased data, straight into A14.
    static let fresh = [VC.reset, VC.skipWelcome, candidates, VC.openExperience, experienceID]
    /// The bodies in catalog order (the Body menu's entries and the tours' stop bodies).
    static let bodies = ["Sun", "Mercury", "Venus", "Earth", "Mars", "Jupiter", "Saturn", "Uranus", "Neptune"]
    /// The longest a single check waits (each test stays well under 60 s).
    static let shortWait: TimeInterval = 5
    /// The most drags one reveal makes.
    static let maxDrags = 24

    /// The full identifier of the control `name`.
    static func id(_ name: String) -> String { prefix + name }

    /// The control `name` of A14, of any element type.
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

    /// Whether the status sentence `status` names `body` as the selected body ("Earth selected, body 4 of 9").
    static func names(_ status: String, _ body: String) -> Bool { status.hasPrefix("\(body) selected,") }

    /// Launches the app with `arguments` and waits until A14 runs: the experience route, its canvas described and its
    /// status line (the controls show it once the presenter's first state has arrived).
    @MainActor
    @discardableResult
    static func open(arguments: [String] = SSE.fresh, file: StaticString = #filePath, line: UInt = #line)
        -> XCUIApplication {
        let app = launchApp(arguments: arguments)
        waitFor(element(app, "vc.route.experience"), timeout: VC.firstWait, file: file, line: line)
        waitFor(canvas(app), timeout: VC.firstWait, file: file, line: line)
        waitFor(control(app, "status"), timeout: VC.wait, file: file, line: line)
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

    /// Scrolls the menu `name` (`body` or `tour`) into view, opens it and taps the first enabled item titled `title`.
    /// The open menu lists its items as buttons or menu items, depending on the system version, so all three queries
    /// of `PPSupport.pick` are tried. True when an item was tapped.
    @MainActor
    @discardableResult
    static func choose(_ app: XCUIApplication, menu name: String, item title: String,
                       file: StaticString = #filePath, line: UInt = #line) -> Bool {
        let menu = control(app, name)
        guard waitFor(menu, timeout: shortWait, "the \(name) menu is there", file: file, line: line),
              reveal(app, menu, file: file, line: line) else { return false }
        menu.tap()
        let predicate = NSPredicate(format: "label == %@", title)
        let candidates = [app.collectionViews.buttons.matching(predicate).firstMatch,
                          app.menuItems.matching(predicate).firstMatch,
                          app.buttons.matching(predicate).firstMatch]
        let deadline = Date().addingTimeInterval(shortWait)
        var entry: XCUIElement?
        while entry == nil, Date() < deadline {
            entry = candidates.first { $0.exists && $0.isEnabled }
            if entry == nil { usleep(200_000) }
        }
        XCTAssertNotNil(entry, "the \(name) menu offers an enabled item \(title)", file: file, line: line)
        guard let entry else { return false }
        entry.tap()
        return true
    }

    /// Chooses `body` from the Body menu and waits until the status line names it; true when it does.
    @MainActor
    @discardableResult
    static func chooseBody(_ app: XCUIApplication, _ body: String,
                           file: StaticString = #filePath, line: UInt = #line) -> Bool {
        guard choose(app, menu: "body", item: body, file: file, line: line) else { return false }
        let named = waitForStatus(app) { names($0, body) }
        XCTAssertTrue(named, "the status names \(body) (now \(value(app, "status")))", file: file, line: line)
        return named
    }

    /// Scrolls the Scale picker into view and taps its segment `title` ("True relative"). The segments are buttons of
    /// the segmented control; when the identified element does not expose them, the app's segmented controls are
    /// searched. True when a segment was tapped.
    @MainActor
    @discardableResult
    static func chooseScale(_ app: XCUIApplication, _ title: String,
                            file: StaticString = #filePath, line: UInt = #line) -> Bool {
        let picker = control(app, "scale")
        guard waitFor(picker, timeout: shortWait, "the Scale picker is there", file: file, line: line),
              reveal(app, picker, file: file, line: line) else { return false }
        let candidates = [picker.buttons[title].firstMatch,
                          app.segmentedControls.buttons[title].firstMatch,
                          app.buttons[title].firstMatch]
        let deadline = Date().addingTimeInterval(shortWait)
        var segment: XCUIElement?
        while segment == nil, Date() < deadline {
            segment = candidates.first { $0.exists && $0.isHittable }
            if segment == nil { usleep(200_000) }
        }
        XCTAssertNotNil(segment, "the Scale picker offers \(title)", file: file, line: line)
        guard let segment else { return false }
        segment.tap()
        return true
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
    static func waitForValue(_ target: XCUIElement, timeout: TimeInterval = SSE.shortWait,
                             _ condition: (String) -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while !(target.exists && condition(target.value as? String ?? "")), Date() < deadline { usleep(200_000) }
        return target.exists && condition(target.value as? String ?? "")
    }

    /// Waits until the status line's value satisfies `condition`; true when it does.
    @MainActor
    static func waitForStatus(_ app: XCUIApplication, timeout: TimeInterval = SSE.shortWait,
                              _ condition: (String) -> Bool) -> Bool {
        waitForValue(control(app, "status"), timeout: timeout, condition)
    }

    /// The 1-based stop of a tour value ("Inner planets, stop 2 of 5, paused" → 2), or nil without a tour.
    static func tourStop(_ value: String) -> Int? {
        guard let range = value.range(of: ", stop ") else { return nil }
        let digits = value[range.upperBound...].prefix { $0.isNumber }
        return Int(digits)
    }
}
