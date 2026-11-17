// IASupport — feature 129 (A17-P06) T-A17-608 (clarification Q4; FR-A17-607): helpers of the interface tests of
// Interactive Anatomy (A17) inside the one app, modelled on `SLSupport`. A17 is a candidate until X-A17; every launch
// carries `-vcCandidates` (DebugLaunch: the candidates' catalog entries become available and are registered). A first
// start erases the data (`-vcResetData`), skips the welcome and opens the experience directly with
// `-openExperience a17.interactive-anatomy`. A fresh start shows the right knee with every layer shown and nothing
// selected; the canvas is described "Right knee, bones, …; selected: nothing selected.". The controls are found by the
// identifiers of `AnatomyControls` (`port.identifier(name)`, that is `experience.a17.interactive-anatomy.<name>`): the
// layer toggles (`layer-bones`, `layer-cartilage`, `layer-ligaments`, valued "Shown" or "Hidden"), the structure rows
// (`structure-<i>`, labelled "<English name>, <layer words>", valued "Selected", "Not selected" or "Hidden" and
// disabled when hidden; Femur is 0, Anterior cruciate ligament 8), the search field (`search-field`, labelled "Search
// structures") and its results (`search-result-<i>`), the "About this model" row (`about-model`, valued with the model
// statement), the description panel (`panel`, its lines combined into its label), the isolate controls
// (`isolate-part`, `isolate-layer-<l>`, `isolate-mode`, `show-all`, each valued "Showing everything" or "Isolated:
// <target>, <mode>") and the camera buttons. The controls sit below the canvas in a scroll view that is not lazy, so
// every control exists and its frame tells which way to scroll; a control is scrolled into view before it is used,
// with slow drags near the left edge (inside the padding, so that no button takes the touch). Everything lives in the
// namespace `IA`, so that nothing collides with the shared helpers of `AppUITestSupport` or the other experiences.
import Foundation
import XCTest

/// Launch arguments, identifiers and helpers of the A17 interface tests.
enum IA {
    /// The experience's id in the catalog.
    static let experienceID = "a17.interactive-anatomy"
    /// The prefix of every identifier of the experience's controls.
    static let prefix = "experience.a17.interactive-anatomy."
    /// The prefix of the canvas description (`AnatomyCore.describe()`).
    static let describedPrefix = "Right knee, "
    /// The debug argument that makes the candidates available (DebugLaunch).
    static let candidates = "-vcCandidates"
    /// A first start with erased data, straight into A17.
    static let fresh = [VC.reset, VC.skipWelcome, candidates, VC.openExperience, experienceID]
    /// The longest a single check waits (each test stays well under 60 s).
    static let shortWait: TimeInterval = 5
    /// The most drags one reveal makes.
    static let maxDrags = 24
    /// The list index of Femur (the first part of the bones layer).
    static let femurIndex = 0
    /// The list index of the anterior cruciate ligament (the first part of the ligaments layer).
    static let aclIndex = 8
    /// The model statement (`AnatomyReview.modelStatement`, FR-A17-503).
    static let modelStatement = "Schematic model for learning; shapes are simplified."
    /// The review sentence of a part no clinician has reviewed (`AnatomyReview.notReviewedSentence`).
    static let notReviewed = "Not reviewed by a clinician."
    /// A fragment of the citation of the bundled parts (Gray's Anatomy of the Human Body, 1918).
    static let citationFragment = "Anatomy of the Human Body"

    /// The full identifier of the control `name`.
    static func id(_ name: String) -> String { prefix + name }

    /// The control `name` of A17, of any element type.
    @MainActor
    static func control(_ app: XCUIApplication, _ name: String) -> XCUIElement {
        element(app, id(name))
    }

    /// The structure row of part `index` (`structure-<index>`).
    @MainActor
    static func row(_ app: XCUIApplication, _ index: Int) -> XCUIElement {
        control(app, "structure-\(index)")
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

    /// The text of the description panel: its combined label (and its value, when it has one).
    @MainActor
    static func panelText(_ app: XCUIApplication) -> String {
        let panel = control(app, "panel")
        guard panel.exists else { return "" }
        let value = panel.value as? String ?? ""
        return value.isEmpty ? panel.label : panel.label + "\n" + value
    }

    /// Launches the app with `arguments` and waits until A17 runs: the experience route, its canvas described and the
    /// first structure row (the controls show it once the presenter's first state has arrived).
    @MainActor
    @discardableResult
    static func open(arguments: [String] = IA.fresh, file: StaticString = #filePath, line: UInt = #line)
        -> XCUIApplication {
        let app = launchApp(arguments: arguments)
        waitFor(element(app, "vc.route.experience"), timeout: VC.firstWait, file: file, line: line)
        waitFor(canvas(app), timeout: VC.firstWait, file: file, line: line)
        waitFor(row(app, femurIndex), timeout: VC.wait, file: file, line: line)
        XCTAssertTrue(waitForLabel(canvas(app)) { $0.hasPrefix(describedPrefix) },
                      "the canvas is described: \(description(app))", file: file, line: line)
        return app
    }

    /// Scrolls the structure row `index` into view, taps it and waits until it is valued "Selected"; true when it is.
    @MainActor
    @discardableResult
    static func select(_ app: XCUIApplication, _ index: Int, file: StaticString = #filePath, line: UInt = #line)
        -> Bool {
        guard tap(app, "structure-\(index)", file: file, line: line) else { return false }
        let selected = waitForValue(row(app, index)) { $0 == "Selected" }
        XCTAssertTrue(selected, "structure-\(index) is selected (now \(value(app, "structure-\(index)")))",
                      file: file, line: line)
        return selected
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

    /// Scrolls `target` into view and taps it; false when it is not there or cannot be reached.
    @MainActor
    @discardableResult
    static func tap(_ app: XCUIApplication, element target: XCUIElement, _ what: String,
                    file: StaticString = #filePath, line: UInt = #line) -> Bool {
        guard waitFor(target, timeout: shortWait, "\(what) is there", file: file, line: line),
              reveal(app, target, file: file, line: line) else { return false }
        target.tap()
        return true
    }

    /// Scrolls the control `name` into view and taps it.
    @MainActor
    @discardableResult
    static func tap(_ app: XCUIApplication, _ name: String, file: StaticString = #filePath, line: UInt = #line)
        -> Bool {
        tap(app, element: control(app, name), name, file: file, line: line)
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
    static func waitForValue(_ target: XCUIElement, timeout: TimeInterval = IA.shortWait,
                             _ condition: (String) -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while !(target.exists && condition(target.value as? String ?? "")), Date() < deadline { usleep(200_000) }
        return target.exists && condition(target.value as? String ?? "")
    }

    /// Waits until the panel's text satisfies `condition`; true when it does.
    @MainActor
    static func waitForPanel(_ app: XCUIApplication, timeout: TimeInterval = IA.shortWait,
                             _ condition: (String) -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition(panelText(app)), Date() < deadline { usleep(200_000) }
        return condition(panelText(app))
    }
}
