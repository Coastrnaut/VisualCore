// LWSupport — feature 142 (A19-P05) T-A19-503, T-A19-504 (FR-A19-501, FR-A19-502; SC-A19-501, SC-A19-502): helpers
// of the interface tests of Living Wallpapers (A19) inside the one app, modelled on `ACSupport`. A19 is a candidate,
// so every launch carries `-vcCandidates` (DebugLaunch: the candidates' catalog entries become available and are
// registered). A start erases the data (`-vcResetData`, so the export history is empty), skips the welcome and opens
// the experience directly with `-openExperience a19.living-wallpapers`; ``limited(_:)`` adds the automation-only
// argument `-lwExportLimit <n>` (`LaunchOptions`, read under `DEBUG || VISUALCORE_AUTOMATION`), which caps the
// presenter's export limit at n so that a template larger than n shows the notice of `ExportNotice`. A fresh project
// is Ink Flow on the iPhone 16 Pro template, portrait, PNG (`WallpaperProject`'s default).
//
// The controls are found by the identifiers of `WallpaperControls` (`port.identifier(name)`, that is
// `experience.a19.living-wallpapers.<name>`): the menus `scene`, `preset`, `template` (the nine device names of
// `CanvasTemplates`), `orientation` (Portrait, Landscape) and `format` (PNG, JPEG, HEIC), whose accessibility label is
// "<title>, <current value>" (`EditorLabel.text`, for example "Device, iPhone 16 Pro"); the buttons `export`,
// `export-offered`, `export-cancel`, `export-retry`, `share`, `help`, `result-help` and `clear-history`; the texts
// `export-message` ("Exported <FORMAT>, <W> × <H> pixels, sRGB." after a written export), `export-notice` and
// `history-<i>`; and `export-progress` while a job runs. The help sheet's Done button is `help-done`. Sizes are printed
// with " × " (U+00D7 between spaces). The controls sit below the canvas in a scroll view; a control is scrolled into
// view before it is used, with slow drags near the left edge (inside the padding, so that no button takes the touch).
// Everything lives in the namespace `LW`, so that nothing collides with the shared helpers of `AppUITestSupport` or
// the other experiences.
import Foundation
import XCTest

/// Launch arguments, identifiers and helpers of the A19 interface tests.
enum LW {
    /// The experience's id in the catalog.
    static let experienceID = "a19.living-wallpapers"
    /// The prefix of every identifier of the experience's controls.
    static let prefix = "experience.a19.living-wallpapers."
    /// The debug argument that makes the candidates available (DebugLaunch).
    static let candidates = "-vcCandidates"
    /// The automation-only argument that caps the export edge limit (`LaunchOptions.exportLimitFlag`).
    static let exportLimitFlag = "-lwExportLimit"
    /// A first start with erased data, straight into A19.
    static let fresh = [VC.reset, VC.skipWelcome, candidates, VC.openExperience, experienceID]
    /// The longest a single check waits (each test stays well under 60 s).
    static let shortWait: TimeInterval = 5
    /// The longest an export of a phone template may take from the tap to its result line.
    static let exportWait: TimeInterval = 20
    /// The most drags one reveal makes.
    static let maxDrags = 24
    /// The most drags a collection pass makes from the top of the controls to their end.
    static let maxCollectDrags = 16
    /// The device name of the iPhone SE template (`CanvasTemplates`, id `iphone-se-3`).
    static let iPhoneSE = "iPhone SE (3rd generation)"
    /// The device name of the iPhone 16 Pro template (`CanvasTemplates`, id `iphone-16-pro`), the fresh default.
    static let iPhone16Pro = "iPhone 16 Pro"
    /// The phrases no text of the experience may hold (clarification Q5), compared in lower case.
    static let refusedPhrases = ["live wallpaper", "set as wallpaper", "automatically", "sets your wallpaper",
                                 "installs", "animated wallpaper"]
    /// The sentence the help must hold (`WallpaperHelp`, "Make it your wallpaper").
    static let personSetsWallpaper = "You set the wallpaper yourself"

    /// A first start with erased data and the export edge limit capped at `limit`.
    static func limited(_ limit: Int) -> [String] { fresh + [exportLimitFlag, String(limit)] }

    /// A pixel size as the experience prints it: "<w> × <h>" (U+00D7 between spaces).
    static func size(_ width: Int, _ height: Int) -> String { "\(width) \u{00D7} \(height)" }

    /// The full identifier of the control `name`.
    static func id(_ name: String) -> String { prefix + name }

    /// The control `name` of A19, of any element type.
    @MainActor
    static func control(_ app: XCUIApplication, _ name: String) -> XCUIElement {
        element(app, id(name))
    }

    /// The label of the control `name`, or "" when it is not there.
    @MainActor
    static func label(_ app: XCUIApplication, _ name: String) -> String {
        let target = control(app, name)
        return target.exists ? target.label : ""
    }

    /// Launches the app with `arguments` and waits until A19 runs: the experience route, the canvas and the Export
    /// button (the controls show it once the presenter's first state has arrived).
    @MainActor
    @discardableResult
    static func open(arguments: [String] = LW.fresh, file: StaticString = #filePath, line: UInt = #line)
        -> XCUIApplication {
        let app = launchApp(arguments: arguments)
        waitFor(element(app, "vc.route.experience"), timeout: VC.firstWait, file: file, line: line)
        waitFor(element(app, VC.canvas), timeout: VC.firstWait, file: file, line: line)
        waitFor(control(app, "export"), timeout: VC.wait, "the Export button is there", file: file, line: line)
        return app
    }

    /// The scroll view that holds the controls below the canvas (not the help sheet's, whose only identified
    /// element is `help-done`).
    @MainActor
    static func controlsList(_ app: XCUIApplication) -> XCUIElement {
        app.scrollViews.containing(NSPredicate(format: "identifier == %@", id("export"))).firstMatch
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

    /// Waits for the control `name`, scrolls it into view and taps it; true when it was tapped.
    @MainActor
    @discardableResult
    static func tap(_ app: XCUIApplication, _ name: String, file: StaticString = #filePath, line: UInt = #line)
        -> Bool {
        let target = control(app, name)
        guard waitFor(target, timeout: shortWait, "\(name) is there", file: file, line: line),
              reveal(app, target, file: file, line: line) else { return false }
        target.tap()
        return true
    }

    /// Whether the menu `menu` shows `option`: its label ends in ", <option>" (`EditorLabel.text`) or its value is
    /// `option`.
    @MainActor
    static func shows(_ menu: XCUIElement, _ option: String) -> Bool {
        guard menu.exists else { return false }
        return menu.label.hasSuffix(", " + option) || (menu.value as? String) == option
    }

    /// Scrolls the menu `name` into view, opens it, chooses the option titled `option` and waits until the menu
    /// shows `option` (``shows(_:_:)``); true when it does. The option is looked for among the buttons, then the menu
    /// items, of the whole app (the menu is presented above the controls), and only a hittable one is tapped.
    @MainActor
    @discardableResult
    static func choose(_ app: XCUIApplication, _ name: String, _ option: String,
                       file: StaticString = #filePath, line: UInt = #line) -> Bool {
        let menu = control(app, name)
        guard waitFor(menu, timeout: shortWait, "\(name) is there", file: file, line: line),
              reveal(app, menu, file: file, line: line) else { return false }
        if shows(menu, option) { return true }
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
        let chosen = waitForLabel(menu, timeout: shortWait) { _ in shows(menu, option) }
        XCTAssertTrue(chosen, "\(name) shows \(option) (now \(menu.label))", file: file, line: line)
        return chosen
    }

    /// Waits (at most ``exportWait``) until the export job has ended: no progress is shown and `export-message` is
    /// there. Returns the message, or "" when the job did not end in time (the test fails at the caller's line).
    @MainActor
    @discardableResult
    static func waitForExport(_ app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line)
        -> String {
        let progress = control(app, "export-progress"), message = control(app, "export-message")
        let deadline = Date().addingTimeInterval(exportWait)
        while !(message.exists && !progress.exists), Date() < deadline { usleep(200_000) }
        let ended = message.exists && !progress.exists
        XCTAssertTrue(ended, "the export ended within \(Int(exportWait)) s (progress shown: \(progress.exists))",
                      file: file, line: line)
        return ended ? message.label : ""
    }

    /// Waits until the label of `target` satisfies `condition`; true when it does.
    @MainActor
    static func waitForLabel(_ target: XCUIElement, timeout: TimeInterval = LW.shortWait,
                             _ condition: (String) -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while !(target.exists && condition(target.label)), Date() < deadline { usleep(200_000) }
        return target.exists && condition(target.label)
    }

    // MARK: Collected texts (T-A19-504)

    /// One text the interface shows: the element's type, identifier and label (and value, when it has one).
    struct ShownText: Hashable, CustomStringConvertible {
        /// The element type's name ("staticText", "button", …).
        let kind: String
        /// The accessibility identifier, "" when none.
        let identifier: String
        /// The accessibility label.
        let label: String
        /// The accessibility value as text, "" when none.
        let value: String

        /// The label and value, joined by a space.
        var text: String { value.isEmpty ? label : label + " " + value }

        /// "<kind> '<identifier>': <text>".
        var description: String { "\(kind) '\(identifier)': \(text)" }
    }

    /// The element types whose labels are collected: static texts and buttons (FR-A19-502), and the switches,
    /// sliders, text fields and links, which also show a label.
    static let collectedTypes: Set<XCUIElement.ElementType> = [.staticText, .button, .switch, .toggle, .slider,
                                                               .textField, .link, .menuItem]

    /// The name of `type` in the failure messages.
    static func kindName(_ type: XCUIElement.ElementType) -> String {
        switch type {
        case .staticText: return "staticText"
        case .button: return "button"
        case .switch, .toggle: return "switch"
        case .slider: return "slider"
        case .textField: return "textField"
        case .link: return "link"
        case .menuItem: return "menuItem"
        default: return "type \(type.rawValue)"
        }
    }

    /// Every text of a collected type that `app` exposes now, from one snapshot of its whole element tree (the
    /// screen as the person sees it, the shell's chrome included; nothing is left out). Empty labels are skipped.
    @MainActor
    static func texts(_ app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) -> Set<ShownText> {
        guard let root = try? app.snapshot() else {
            XCTFail("the element tree could not be read", file: file, line: line)
            return []
        }
        var found = Set<ShownText>()
        var stack: [XCUIElementSnapshot] = [root]
        while let next = stack.popLast() {
            stack.append(contentsOf: next.children)
            guard collectedTypes.contains(next.elementType), !next.label.isEmpty else { continue }
            let value = next.value.map { "\($0)" } ?? ""
            found.insert(ShownText(kind: kindName(next.elementType), identifier: next.identifier, label: next.label,
                                   value: value))
        }
        return found
    }

    /// The texts of the experience screen: collected at the top of the controls, then after each drag toward their
    /// end, until the controls stop moving (their end is reached) or ``maxCollectDrags`` drags are done.
    @MainActor
    static func screenTexts(_ app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line)
        -> Set<ShownText> {
        var found = texts(app, file: file, line: line)
        let marker = control(app, "export")
        var drags = 0
        while drags < maxCollectDrags {
            let before = marker.exists ? marker.frame.minY : 0
            let list = controlsList(app)
            drag(app, by: (list.exists ? list.frame.height : 300) * 0.8)
            drags += 1
            found.formUnion(texts(app, file: file, line: line))
            if abs((marker.exists ? marker.frame.minY : 0) - before) < 1 { break }
        }
        return found
    }

    /// Opens the help from the control `name` (`help` or `result-help`), collects the texts while scrolling the
    /// sheet to its end, closes it with Done (`help-done`) and waits until it is gone. Returns the collected texts.
    @MainActor
    static func helpTexts(_ app: XCUIApplication, from name: String = "help",
                          file: StaticString = #filePath, line: UInt = #line) -> Set<ShownText> {
        guard tap(app, name, file: file, line: line) else { return [] }
        let done = element(app, id("help-done"))
        guard waitFor(done, timeout: shortWait, "the help sheet is open", file: file, line: line) else { return [] }
        var found = texts(app, file: file, line: line)
        let sheet = app.scrollViews.containing(NSPredicate(format: "identifier == %@", id("help-done"))).firstMatch
        for _ in 0..<6 where !done.isHittable {
            if sheet.exists { sheet.swipeUp() } else { app.swipeUp() }
            found.formUnion(texts(app, file: file, line: line))
        }
        XCTAssertTrue(done.isHittable, "the help's Done button can be tapped", file: file, line: line)
        done.tap()
        XCTAssertTrue(waitUntilGone(done, timeout: shortWait), "the help sheet closed", file: file, line: line)
        return found
    }

    /// The collected texts that hold a refused phrase (case-insensitive), each with the phrase it holds.
    static func refusals(in texts: Set<ShownText>) -> [String] {
        texts.sorted { $0.description < $1.description }.flatMap { shown -> [String] in
            let lower = shown.text.lowercased()
            return refusedPhrases.filter { lower.contains($0) }.map { "\"\($0)\" in \(shown)" }
        }
    }
}
