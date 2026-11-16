// MESupport — feature 115 (A15-P06) T-A15-609 (clarification Q4): helpers of the interface tests of Molecular Explorer
// (A15) inside the one app, modelled on `SSESupport`. A15 is a candidate until X-A15; every launch carries
// `-vcCandidates` (DebugLaunch: the candidates' catalog entries become available and are registered). A first start
// erases the data (`-vcResetData`, which also removes the experience's storage, so there is no `recent.json` and no
// `settings.json`: the Recent menu holds only the molecule opened at start and the labels are shown for all atoms),
// skips the welcome and opens the experience directly with `-openExperience a15.molecular-explorer`; ``again`` opens it
// once more without the reset. The controls are found by the identifiers of `MoleculeControls`
// (`port.identifier(name)`, that is `experience.a15.molecular-explorer.<name>`): the status line (`status`, value the
// status with a capital first letter, "Benzene selected, molecule 4 of 5"), the Display picker (`display-mode`,
// segments "Ball and stick" and "Space filling"), the legend (`legend`, "Space filling: atoms at their van der Waals
// radius, no bonds. …"), Next atom (`next-atom`), the atom panel (`atom-panel`, "Oxygen (O), atom 1 of 3" and its
// position and radii lines, or "No atom selected"), the Labels picker (`labels`, segments "All", "Selected" and
// "None", value the chosen title), the Recent menu (`recent`, value the recent titles newest first joined by ", ", or
// "No recent molecules") and the Library buttons (`library-<id>`, ids water, methane, ethanol, benzene, caffeine).
// The Import button (`import`) is never tapped: it shows the system file importer. The controls sit below the canvas in
// a scroll view that is not lazy, so every control exists and its frame tells which way to scroll; a control is
// scrolled into view before it is used, with slow drags near the left edge (inside the padding, so that no button —
// the Import button included — takes the touch). Everything lives in the namespace `ME`, so that nothing collides
// with the shared helpers of `AppUITestSupport` or the other experiences.
import Foundation
import XCTest

/// Launch arguments, identifiers and helpers of the A15 interface tests.
enum ME {
    /// The experience's id in the catalog.
    static let experienceID = "a15.molecular-explorer"
    /// The prefix of every identifier of the experience's controls.
    static let prefix = "experience.a15.molecular-explorer."
    /// The prefix of the canvas description.
    static let describedPrefix = "Molecular Explorer: "
    /// The debug argument that makes the candidates available (DebugLaunch).
    static let candidates = "-vcCandidates"
    /// A first start with erased data, straight into A15.
    static let fresh = [VC.reset, VC.skipWelcome, candidates, VC.openExperience, experienceID]
    /// A later start that keeps the data, straight into A15.
    static let again = [VC.skipWelcome, candidates, VC.openExperience, experienceID]
    /// The longest a single check waits (each test stays well under 60 s).
    static let shortWait: TimeInterval = 5
    /// The most drags one reveal makes.
    static let maxDrags = 24

    /// The full identifier of the control `name`.
    static func id(_ name: String) -> String { prefix + name }

    /// The control `name` of A15, of any element type.
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

    /// Whether the status sentence `status` names `title` as the selected molecule ("Benzene selected, molecule 4 of
    /// 5").
    static func names(_ status: String, _ title: String) -> Bool { status.hasPrefix("\(title) selected,") }

    /// Launches the app with `arguments` and waits until A15 runs: the experience route, its canvas described and its
    /// status line (the controls show it once the presenter's first state has arrived).
    @MainActor
    @discardableResult
    static func open(arguments: [String] = ME.fresh, file: StaticString = #filePath, line: UInt = #line)
        -> XCUIApplication {
        let app = launchApp(arguments: arguments)
        waitForRunning(app, file: file, line: line)
        return app
    }

    /// Ends `app` (after a moment in which the stores reach the disk) and opens A15 again without erasing the data.
    @MainActor
    @discardableResult
    static func reopen(_ app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line)
        -> XCUIApplication {
        let second = relaunch(app, arguments: ME.again)
        waitForRunning(second, file: file, line: line)
        return second
    }

    /// Waits for the experience route, the described canvas and the status line of A15.
    @MainActor
    private static func waitForRunning(_ app: XCUIApplication, file: StaticString, line: UInt) {
        waitFor(element(app, "vc.route.experience"), timeout: VC.firstWait, file: file, line: line)
        waitFor(canvas(app), timeout: VC.firstWait, file: file, line: line)
        waitFor(control(app, "status"), timeout: VC.wait, file: file, line: line)
        XCTAssertTrue(waitForLabel(canvas(app)) { $0.hasPrefix(describedPrefix) },
                      "the canvas is described: \(description(app))", file: file, line: line)
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

    /// Scrolls the control `name` into view and taps it. Never used for `import`, which shows the system importer.
    @MainActor
    static func tap(_ app: XCUIApplication, _ name: String, file: StaticString = #filePath, line: UInt = #line) {
        precondition(name != "import", "the interface tests never show the system file importer")
        let target = control(app, name)
        guard waitFor(target, timeout: shortWait, "\(name) is there", file: file, line: line),
              reveal(app, target, file: file, line: line) else { return }
        target.tap()
    }

    /// Taps the Library button of the molecule `id` ("benzene") and waits until the status line names `title`
    /// ("Benzene"); true when it does.
    @MainActor
    @discardableResult
    static func chooseFromLibrary(_ app: XCUIApplication, id: String, title: String,
                                  file: StaticString = #filePath, line: UInt = #line) -> Bool {
        tap(app, "library-\(id)", file: file, line: line)
        let named = waitForStatus(app) { names($0, title) }
        XCTAssertTrue(named, "the status names \(title) (now \(value(app, "status")))", file: file, line: line)
        return named
    }

    /// Scrolls the segmented picker `name` (`display-mode` or `labels`) into view and taps its segment `title`
    /// ("Space filling", "None"). The segments are buttons of the segmented control; when the identified element does
    /// not expose them, the app's segmented controls are searched (as `SSE.chooseScale` does). True when a segment was
    /// tapped.
    @MainActor
    @discardableResult
    static func chooseSegment(_ app: XCUIApplication, picker name: String, _ title: String,
                              file: StaticString = #filePath, line: UInt = #line) -> Bool {
        let picker = control(app, name)
        guard waitFor(picker, timeout: shortWait, "the \(name) picker is there", file: file, line: line),
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
        XCTAssertNotNil(segment, "the \(name) picker offers \(title)", file: file, line: line)
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
    static func waitForValue(_ target: XCUIElement, timeout: TimeInterval = ME.shortWait,
                             _ condition: (String) -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while !(target.exists && condition(target.value as? String ?? "")), Date() < deadline { usleep(200_000) }
        return target.exists && condition(target.value as? String ?? "")
    }

    /// Waits until the status line's value satisfies `condition`; true when it does.
    @MainActor
    static func waitForStatus(_ app: XCUIApplication, timeout: TimeInterval = ME.shortWait,
                              _ condition: (String) -> Bool) -> Bool {
        waitForValue(control(app, "status"), timeout: timeout, condition)
    }
}
