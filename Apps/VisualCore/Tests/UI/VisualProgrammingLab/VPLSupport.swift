// VPLSupport — feature 170 (A23-P05) T-A23-505 (FR-A23-504, SC-A23-504; clarification Q4; User Story 4;
// contracts/tests.md "Interface"): helpers of the interface tests of Visual Programming Lab (A23) inside the one app,
// modelled on `SSSupport`. Every launch carries `-vcCandidates` (DebugLaunch: the candidates' catalog entries become
// available and are registered). A fresh start erases the data (`-vcResetData`), skips the welcome and opens the
// experience directly with `-openExperience a23.visual-programming-lab`. A fresh lab opens on the starter graph,
// Noise 1 → Output 2, whose status reads "Ready".
//
// The canvas (`session.canvas`) is labelled with the presenter's description (`LabPresenter.describe`): "Visual
// Programming Lab, N nodes, M connections, <status>". The controls are found by the identifiers of `LabControls` and
// `LabLibraryView` (`port.identifier(name)`, that is `experience.a23.visual-programming-lab.<name>`):
//
//   - `add-node`: a button that opens an inline list of the seven kinds, one button `add-node-<kind>` each
//     (`add-node-time`, `add-node-constant`, `add-node-noise`, `add-node-gradient`, `add-node-mix`, `add-node-blur`,
//     `add-node-output`, titled "Time" … "Output"); the new node takes the next identity (3 after the starter graph);
//   - `status`: the checker's status line, spoken as "Status, <line>" (its label);
//   - `feedback`: the sentence of the last refusal (its label), shown when there is one;
//   - `node-list`: per node a row `node-row-<id>` and per input a button `input-<id>-<index>` whose value is the
//     current source's title ("None", "Noise 1 image"); it opens an inline list of option buttons
//     `input-<id>-<index>-option-<tag>`, `<tag>` being `none` or "<source id>-<output index>" ("Noise 1 image" is
//     `1-0`, "Constant 3 colour" is `3-1`); the connections are lines `connection-<target>-<index>` labelled
//     "Noise 1 image → Output 2 image". An input already fed refuses a second source, so an input is set to "None"
//     before it is set to another output;
//   - `library` (the button; the sheet's scroll view carries the same identifier, so the button is found among the
//     buttons), in the sheet `library-name`, `library-save`, `library-row-<file>` (labelled "Saved graph <name>",
//     `<file>` being `graph-<n>`), `library-open-<file>`, `library-done`, `library-message`.
//
// The lists are inline buttons, not menus: while a SwiftUI menu is up over the canvas, which presents a new frame 30
// times a second, XCTest never sees the app idle ("App animations complete" never arrives, 60 s per tap) and taps on
// menu entries are unreliable. Every entry is therefore found by its identifier and tapped like any other control,
// after scrolling it into view. Every wait is bounded
// (``shortWait``, `VC.wait`, `VC.firstWait`). Everything lives in the namespace `VPL`, so that nothing collides with
// the shared helpers of `AppUITestSupport` or the other experiences. System accessibility audits wait for the device
// campaign (owner ruling of 2026-11-13).
import Foundation
import XCTest

/// Launch arguments, identifiers and helpers of the A23 interface tests.
enum VPL {
    /// The experience's id in the catalog.
    static let experienceID = "a23.visual-programming-lab"
    /// The prefix of every identifier of the experience's controls.
    static let prefix = "experience.a23.visual-programming-lab."
    /// The debug argument that makes the candidates available (DebugLaunch).
    static let candidates = "-vcCandidates"
    /// A first start with erased data, straight into A23.
    static let fresh = [VC.reset, VC.skipWelcome, candidates, VC.openExperience, experienceID]
    /// A start over the existing storage, straight into A23 (``fresh`` without the reset).
    static let relaunch = [VC.skipWelcome, candidates, VC.openExperience, experienceID]
    /// The longest a single check waits (each test stays well under 60 s).
    static let shortWait: TimeInterval = 5
    /// The most drags one reveal makes.
    static let maxDrags = 24

    /// The full identifier of the control `name`.
    static func id(_ name: String) -> String { prefix + name }

    /// The control `name` of A23, of any element type.
    @MainActor
    static func control(_ app: XCUIApplication, _ name: String) -> XCUIElement {
        element(app, id(name))
    }

    /// The live canvas of the session; its label is the presenter's description.
    @MainActor
    static func canvas(_ app: XCUIApplication) -> XCUIElement { element(app, VC.canvas) }

    /// The canvas description, or "" when the canvas is not there.
    @MainActor
    static func description(_ app: XCUIApplication) -> String {
        let c = canvas(app)
        return c.exists ? c.label : ""
    }

    /// The status line without its spoken prefix ("Ready"), or "" when it is not there.
    @MainActor
    static func status(_ app: XCUIApplication) -> String {
        let s = control(app, "status")
        guard s.exists else { return "" }
        let label = s.label
        let spoken = "Status, "
        return label.hasPrefix(spoken) ? String(label.dropFirst(spoken.count)) : label
    }

    /// The sentence of the last refusal (the `feedback` label), or "" when there is none.
    @MainActor
    static func feedback(_ app: XCUIApplication) -> String {
        let f = control(app, "feedback")
        return f.exists ? f.label : ""
    }

    /// Waits until the status line satisfies `condition`; true when it does.
    @MainActor
    static func waitForStatus(_ app: XCUIApplication, timeout: TimeInterval = VPL.shortWait,
                              _ condition: (String) -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition(status(app)), Date() < deadline { usleep(200_000) }
        return condition(status(app))
    }

    /// Launches the app with `arguments` and waits until A23 runs with its controls and a status line.
    @MainActor
    @discardableResult
    static func open(arguments: [String] = VPL.fresh, file: StaticString = #filePath, line: UInt = #line)
        -> XCUIApplication {
        let app = launchApp(arguments: arguments)
        waitFor(element(app, "vc.route.experience"), timeout: VC.firstWait, file: file, line: line)
        waitFor(canvas(app), timeout: VC.firstWait, file: file, line: line)
        waitFor(control(app, "add-node"), timeout: VC.wait, "the Add node menu is there", file: file, line: line)
        waitFor(control(app, "status"), timeout: VC.wait, "the status line is there", file: file, line: line)
        XCTAssertTrue(waitForLabel(canvas(app)) { $0.hasPrefix("Visual Programming Lab") },
                      "the canvas is labelled with the lab: \(description(app))", file: file, line: line)
        return app
    }

    /// Ends `app` (after a second in which the stored data reaches the disk) and opens A23 again without the reset.
    @MainActor
    @discardableResult
    static func reopen(_ app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line)
        -> XCUIApplication {
        usleep(1_000_000)
        app.terminate()
        return open(arguments: relaunch, file: file, line: line)
    }

    /// The scroll view that holds the controls below the canvas (not the library sheet's, which shares the
    /// `library` identifier).
    @MainActor
    static func controlsList(_ app: XCUIApplication) -> XCUIElement {
        app.scrollViews.matching(NSPredicate(format: "identifier != %@", id("library")))
            .containing(NSPredicate(format: "identifier BEGINSWITH %@", prefix)).firstMatch
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

    /// Scrolls the controls until `target` is shown, at most ``maxDrags`` drags; true when it is. With `required`,
    /// fails the test at the caller's line when it never is.
    @MainActor
    @discardableResult
    static func reveal(_ app: XCUIApplication, _ target: XCUIElement, required: Bool = true,
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
        if required {
            XCTAssertTrue(found, "not reached by scrolling the controls: \(target)", file: file, line: line)
        }
        return found
    }

    /// Waits for `target`, scrolls it into view and taps it; true when it was tapped.
    @MainActor
    @discardableResult
    static func tap(_ app: XCUIApplication, _ target: XCUIElement, _ what: String,
                    file: StaticString = #filePath, line: UInt = #line) -> Bool {
        guard waitFor(target, timeout: shortWait, "\(what) is there", file: file, line: line),
              reveal(app, target, file: file, line: line) else { return false }
        target.tap()
        return true
    }

    /// The identifier name of the add button of the kind titled `kind` ("Mix" → `add-node-mix`).
    static func addName(_ kind: String) -> String { "add-node-" + kind.lowercased() }

    /// Opens the `add-node` list and taps the kind titled `kind` (`add-node-<kind>`); then waits for the row
    /// `node-row-<expectedID>`. True when the new node is listed.
    @MainActor
    @discardableResult
    static func addNode(_ app: XCUIApplication, _ kind: String, expectedID: Int,
                        file: StaticString = #filePath, line: UInt = #line) -> Bool {
        guard tap(app, control(app, "add-node"), "the Add node button", file: file, line: line),
              tap(app, control(app, addName(kind)), "the \(kind) entry of the Add node list", file: file, line: line)
        else { return false }
        let row = control(app, "node-row-\(expectedID)")
        let added = row.waitForExistence(timeout: shortWait)
        XCTAssertTrue(added, "\(kind) \(expectedID) is listed: \(description(app))", file: file, line: line)
        return added
    }

    /// Opens the list of the input button `input-<node>-<index>` and taps the option `option` ("None", "Noise 1
    /// image") by its tag `tag` (`none`, `1-0`; the button `input-<node>-<index>-option-<tag>`). With `expectValue`,
    /// waits until the input button speaks `option` as its value and returns whether it does; otherwise returns true
    /// once the option was tapped (a refused choice leaves the input as it was).
    @MainActor
    @discardableResult
    static func choose(_ app: XCUIApplication, node: Int, input index: Int, _ option: String, tag: String,
                       expectValue: Bool = true, file: StaticString = #filePath, line: UInt = #line) -> Bool {
        let name = "input-\(node)-\(index)"
        let button = control(app, name)
        guard tap(app, button, name, file: file, line: line),
              tap(app, control(app, name + "-option-" + tag), "the option \(option) of \(name)",
                  file: file, line: line) else { return false }
        guard expectValue else { return true }
        let chosen = waitForValue(button) { $0 == option }
        XCTAssertTrue(chosen, "\(name) speaks \(option) (now \(button.value as? String ?? "-"))",
                      file: file, line: line)
        return chosen
    }

    /// The connection line into input `index` of `node` (`connection-<node>-<index>`).
    @MainActor
    static func connection(_ app: XCUIApplication, node: Int, input index: Int) -> XCUIElement {
        control(app, "connection-\(node)-\(index)")
    }

    /// The library button of the controls (the sheet's scroll view carries the same identifier).
    @MainActor
    static func libraryButton(_ app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(identifier: id("library")).firstMatch
    }

    /// Waits for the control `name` of the library sheet and taps it once it can be tapped; true when it was tapped.
    @MainActor
    @discardableResult
    static func tapInSheet(_ app: XCUIApplication, _ name: String,
                           file: StaticString = #filePath, line: UInt = #line) -> Bool {
        let target = control(app, name)
        guard waitFor(target, timeout: shortWait, "\(name) is there", file: file, line: line) else { return false }
        let hittable = waitForHittable(target)
        XCTAssertTrue(hittable, "\(name) can be tapped", file: file, line: line)
        guard hittable else { return false }
        target.tap()
        return true
    }

    /// Waits until the label of `target` satisfies `condition`; true when it does.
    @MainActor
    static func waitForLabel(_ target: XCUIElement, timeout: TimeInterval = VPL.shortWait,
                             _ condition: (String) -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while !(target.exists && condition(target.label)), Date() < deadline { usleep(200_000) }
        return target.exists && condition(target.label)
    }

    /// Waits until the value of `target` (as text) satisfies `condition`; true when it does.
    @MainActor
    static func waitForValue(_ target: XCUIElement, timeout: TimeInterval = VPL.shortWait,
                             _ condition: (String) -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        func current() -> String { target.exists ? (target.value as? String ?? "") : "" }
        while !(target.exists && condition(current())), Date() < deadline { usleep(200_000) }
        return target.exists && condition(current())
    }

    /// Waits until `target` can be tapped; true when it can.
    @MainActor
    static func waitForHittable(_ target: XCUIElement, timeout: TimeInterval = VPL.shortWait) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while !(target.exists && target.isHittable), Date() < deadline { usleep(200_000) }
        return target.exists && target.isHittable
    }
}
