// ZGSupport — feature 149 (A20-P05) T-A20-505, T-A20-506 (FR-A20-504; SC-A20-502): helpers of the interface tests
// of Digital Zen Garden (A20) inside the one app, modelled on `LWSupport`. A20 was a candidate until X-A20
// (integrated 2026-11-17); every launch carries `-vcCandidates` (DebugLaunch: the candidates' catalog entries
// become available and are registered; harmless once A20 is integrated). A start erases the data (`-vcResetData`, so
// the library of saved gardens is empty), skips the welcome and opens the experience directly with
// `-openExperience a20.digital-zen-garden`. A fresh garden is Pale sand, Fine rake, the Rake tool, no strokes and no
// stones, with River pebble as the kind that Place puts down.
//
// The canvas (`session.canvas`) is labelled with the presenter's description (`GardenPresenter.describe`), for example
// "Zen garden, Pale sand, Fine rake, 1 stroke, 1 stone, River pebble selected, 1 of 1, turned 0°"; ``strokes(_:)`` and
// ``stones(_:)`` read its counts. The controls are found by the identifiers of `GardenControls`
// (`port.identifier(name)`, that is `experience.a20.digital-zen-garden.<name>`): the buttons `undo`, `redo`,
// `pattern-rows` (and the other patterns), `stone-place`, `stone-remove`, `library-save` and per saved garden
// `library-open-<n>` (labelled "Open <name>"); the segmented picker `tool` (Rake, Stones; at the accessibility sizes the
// buttons `tool-0`, `tool-1`); the menu `stone-kind` (label "Stone", value the kind's name); the text field
// `library-name`; the texts `selection` (label "Selection", value the spoken selection) and `library-message`
// ("Saved <name>.", "Opened <name>."). The controls sit below the canvas in a scroll view; a control is scrolled into
// view before it is used, with slow drags near the left edge (inside the padding, so that no button takes the touch).
// Everything lives in the namespace `ZG`, so that nothing collides with the shared helpers of `AppUITestSupport` or
// the other experiences.
import Foundation
import XCTest

/// Launch arguments, identifiers and helpers of the A20 interface tests.
enum ZG {
    /// The experience's id in the catalog.
    static let experienceID = "a20.digital-zen-garden"
    /// The prefix of every identifier of the experience's controls.
    static let prefix = "experience.a20.digital-zen-garden."
    /// The debug argument that makes the candidates available (DebugLaunch).
    static let candidates = "-vcCandidates"
    /// A first start with erased data, straight into A20.
    static let fresh = [VC.reset, VC.skipWelcome, candidates, VC.openExperience, experienceID]
    /// The longest a single check waits (each test stays well under 60 s).
    static let shortWait: TimeInterval = 5
    /// The most drags one reveal makes.
    static let maxDrags = 24
    /// The stone kind the tests place (`GardenPalette.stones[0]`, the default kind of Place).
    static let riverPebble = "River pebble"

    /// The full identifier of the control `name`.
    static func id(_ name: String) -> String { prefix + name }

    /// The control `name` of A20, of any element type.
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

    /// The number before " stroke" or " strokes" in `description`; nil when it names none.
    static func strokes(_ description: String) -> Int? { count(in: description, noun: "stroke") }

    /// The number before " stone" or " stones" in `description`; nil when it names none.
    static func stones(_ description: String) -> Int? { count(in: description, noun: "stone") }

    /// The number of ", <n> <noun>" or ", <n> <noun>s," in `text`.
    private static func count(in text: String, noun: String) -> Int? {
        guard let range = text.range(of: #", (\d+) "# + noun + #"s?(,|$)"#, options: .regularExpression) else {
            return nil
        }
        let digits = text[range].filter(\.isNumber)
        return Int(digits)
    }

    /// Launches the app with `arguments` and waits until A20 runs: the experience route, the canvas labelled with a
    /// garden description and the Undo button (the controls show it once the presenter's first state has arrived).
    @MainActor
    @discardableResult
    static func open(arguments: [String] = ZG.fresh, file: StaticString = #filePath, line: UInt = #line)
        -> XCUIApplication {
        let app = launchApp(arguments: arguments)
        waitFor(element(app, "vc.route.experience"), timeout: VC.firstWait, file: file, line: line)
        waitFor(canvas(app), timeout: VC.firstWait, file: file, line: line)
        waitFor(control(app, "undo"), timeout: VC.wait, "the Undo button is there", file: file, line: line)
        XCTAssertTrue(waitForLabel(canvas(app)) { $0.hasPrefix("Zen garden") },
                      "the canvas is labelled with the garden: \(description(app))", file: file, line: line)
        return app
    }

    /// The scroll view that holds the controls below the canvas.
    @MainActor
    static func controlsList(_ app: XCUIApplication) -> XCUIElement {
        app.scrollViews.containing(NSPredicate(format: "identifier == %@", id("undo"))).firstMatch
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

    /// Waits for the control `name`, scrolls it into view and taps it; true when it was tapped.
    @MainActor
    @discardableResult
    static func tap(_ app: XCUIApplication, _ name: String, file: StaticString = #filePath, line: UInt = #line)
        -> Bool {
        tap(app, control(app, name), name, file: file, line: line)
    }

    /// Chooses the tool titled `title` (index `index` of Rake, Stones) on the `tool` picker: the segment of the
    /// segmented picker, or at the accessibility sizes the button `tool-<index>`. True when it was tapped.
    @MainActor
    @discardableResult
    static func chooseTool(_ app: XCUIApplication, _ title: String, index: Int,
                           file: StaticString = #filePath, line: UInt = #line) -> Bool {
        let column = control(app, "tool-" + String(index))
        if column.exists { return tap(app, column, "tool-\(index)", file: file, line: line) }
        let picker = control(app, "tool")
        guard waitFor(picker, timeout: shortWait, "the tool picker is there", file: file, line: line),
              reveal(app, picker, file: file, line: line) else { return false }
        let segment = picker.buttons[title]
        guard waitFor(segment, timeout: shortWait, "the \(title) segment is there", file: file, line: line) else {
            return false
        }
        segment.tap()
        return true
    }

    /// Scrolls the menu `name` into view and, unless its value already is `option`, opens it and chooses the option
    /// titled `option`; true when the menu then shows `option` (its value).
    @MainActor
    @discardableResult
    static func choose(_ app: XCUIApplication, _ name: String, _ option: String,
                       file: StaticString = #filePath, line: UInt = #line) -> Bool {
        let menu = control(app, name)
        guard waitFor(menu, timeout: shortWait, "\(name) is there", file: file, line: line),
              reveal(app, menu, file: file, line: line) else { return false }
        if (menu.value as? String) == option { return true }
        menu.tap()
        let titled = NSPredicate(format: "label == %@", option)
        let item = app.buttons.matching(titled).firstMatch
        let fallback = app.menuItems.matching(titled).firstMatch
        if item.waitForExistence(timeout: shortWait), item.isHittable {
            item.tap()
        } else if fallback.waitForExistence(timeout: 1) {
            fallback.tap()
        } else {
            XCTFail("\(name): no option \(option) after opening the menu", file: file, line: line)
            return false
        }
        let chosen = waitForValue(menu) { $0 == option }
        XCTAssertTrue(chosen, "\(name) shows \(option)", file: file, line: line)
        return chosen
    }

    /// The Open button of the saved garden called `name`: a `library-open-<n>` button labelled "Open <name>".
    @MainActor
    static func openButton(_ app: XCUIApplication, named name: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@ AND label == %@",
                                         id("library-open-"), "Open " + name)).firstMatch
    }

    /// Waits until the label of `target` satisfies `condition`; true when it does.
    @MainActor
    static func waitForLabel(_ target: XCUIElement, timeout: TimeInterval = ZG.shortWait,
                             _ condition: (String) -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while !(target.exists && condition(target.label)), Date() < deadline { usleep(200_000) }
        return target.exists && condition(target.label)
    }

    /// Waits until the value of `target` (as text) satisfies `condition`; true when it does.
    @MainActor
    static func waitForValue(_ target: XCUIElement, timeout: TimeInterval = ZG.shortWait,
                             _ condition: (String) -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        func current() -> String { target.exists ? (target.value as? String ?? "") : "" }
        while !(target.exists && condition(current())), Date() < deadline { usleep(200_000) }
        return target.exists && condition(current())
    }

    /// Waits until the canvas description satisfies `condition`; true when it does.
    @MainActor
    static func waitForDescription(_ app: XCUIApplication, timeout: TimeInterval = ZG.shortWait,
                                   _ condition: (String) -> Bool) -> Bool {
        waitForLabel(canvas(app), timeout: timeout, condition)
    }
}
