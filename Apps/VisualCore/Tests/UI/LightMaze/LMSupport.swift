// LMSupport — feature 101 (A13-P06) T-A13-608 (FR-A13-630; research D4): helpers of the interface tests of Light Maze
// (A13) inside the one app, modelled on `TWSupport`. A13 was a candidate until X-A13 (integrated 2026-11-15); every launch still carries
// `-vcCandidates` (DebugLaunch: the candidates' catalog entries become available and are registered), starts with
// erased data (`-vcResetData`, so the level progress is fresh and level 2 is locked until level 1 is solved), skips
// the welcome and opens the experience directly with `-openExperience a13.light-maze`. The controls are found by the
// identifiers of `MazeControls` (`port.identifier(name)`, that is `experience.a13.light-maze.<name>`): Previous level
// and Next level (`previous-level`, `next-level`), the Level menu (`level`; its items are buttons titled "2. Around
// the corner", locked ones disabled and ending " (locked)", solved ones "… (solved, best 1)"), Select previous and
// Select next (`select-previous`, `select-next`), Turn (`turn`), Undo (`undo`), Restart (`reset-level`), Hint
// (`hint`), Describe (`describe`), the status line (`status`, whose value is the status sentence with a capital
// first letter: "Level 1, First light; 1 mirror, 1 target; …; 1 of 1 target lit; solved") and the answer line
// (`message`, shown only when there is one; its value is the words). They sit below the canvas in a scroll view, so a
// control is scrolled into view before it is used; the stack is not lazy, so every control exists and its frame tells
// which way to scroll. The canvas label is the presenter's description ("Light Maze: level 1, First light; …").
// Everything lives in the namespace `LM`, so that nothing collides with the shared helpers of `AppUITestSupport` or
// the other experiences.
import Foundation
import XCTest

/// Launch arguments, identifiers and helpers of the A13 interface tests.
enum LM {
    /// The experience's id in the catalog.
    static let experienceID = "a13.light-maze"
    /// The prefix of every identifier of the experience's controls.
    static let prefix = "experience.a13.light-maze."
    /// The prefix of the canvas description.
    static let describedPrefix = "Light Maze: "
    /// The debug argument that makes the candidates available (DebugLaunch).
    static let candidates = "-vcCandidates"
    /// A first start with erased data, straight into A13.
    static let fresh = [VC.reset, VC.skipWelcome, candidates, VC.openExperience, experienceID]
    /// The longest a single check waits (each test stays well under 60 s).
    static let shortWait: TimeInterval = 5
    /// The most drags one reveal makes.
    static let maxDrags = 24

    /// The full identifier of the control `name`.
    static func id(_ name: String) -> String { prefix + name }

    /// The control `name` of A13, of any element type.
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

    /// Launches the app with `arguments` and waits until A13 runs: the experience route, its canvas described and its
    /// status line (the controls show it once the presenter's first state has arrived).
    @MainActor
    @discardableResult
    static func open(arguments: [String] = LM.fresh, file: StaticString = #filePath, line: UInt = #line)
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

    /// Scrolls the Level menu (`level`) into view, opens it and taps the first enabled item whose title begins with
    /// `titlePrefix` ("2. "). The open menu lists its items as buttons or menu items, depending on the system version,
    /// so all three queries of `PPSupport.pick` are tried. True when an item was tapped.
    @MainActor
    @discardableResult
    static func chooseLevel(_ app: XCUIApplication, titlePrefix: String,
                            file: StaticString = #filePath, line: UInt = #line) -> Bool {
        let menu = control(app, "level")
        guard waitFor(menu, timeout: shortWait, "the Level menu is there", file: file, line: line),
              reveal(app, menu, file: file, line: line) else { return false }
        menu.tap()
        let predicate = NSPredicate(format: "label BEGINSWITH %@", titlePrefix)
        let candidates = [app.collectionViews.buttons.matching(predicate).firstMatch,
                          app.menuItems.matching(predicate).firstMatch,
                          app.buttons.matching(predicate).firstMatch]
        let deadline = Date().addingTimeInterval(shortWait)
        var entry: XCUIElement?
        while entry == nil, Date() < deadline {
            entry = candidates.first { $0.exists && $0.isEnabled }
            if entry == nil { usleep(200_000) }
        }
        XCTAssertNotNil(entry, "the Level menu offers an enabled item starting \(titlePrefix)", file: file, line: line)
        guard let entry else { return false }
        entry.tap()
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
    static func waitForValue(_ target: XCUIElement, timeout: TimeInterval = LM.shortWait,
                             _ condition: (String) -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while !(target.exists && condition(target.value as? String ?? "")), Date() < deadline { usleep(200_000) }
        return target.exists && condition(target.value as? String ?? "")
    }

    /// Waits until the status line's value satisfies `condition`; true when it does.
    @MainActor
    static func waitForStatus(_ app: XCUIApplication, timeout: TimeInterval = LM.shortWait,
                              _ condition: (String) -> Bool) -> Bool {
        waitForValue(control(app, "status"), timeout: timeout, condition)
    }

    /// Whether the status sentence `status` says the level is solved (it ends "; solved", not "; not solved").
    static func isSolved(_ status: String) -> Bool {
        status.hasSuffix("solved") && !status.hasSuffix("not solved")
    }

    /// Whether the status sentence `status` says the level is not solved.
    static func isNotSolved(_ status: String) -> Bool { status.hasSuffix("not solved") }
}
