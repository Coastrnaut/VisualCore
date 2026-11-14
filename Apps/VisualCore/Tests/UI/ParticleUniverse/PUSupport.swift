// PUSupport — feature 193 (UA-F07) T-U07-028: helpers of the ported interface tests of Particle Universe (A04) inside
// the one app. A04 is a candidate, so every launch carries `-vcCandidates`; the tests open it directly with
// `-openExperience`. The controls are found by the identifiers of `ParticleControls`
// (`experience.a04.particle-universe.<name>`). They sit below the canvas in a scroll view of limited height (about 280
// points), so a control is scrolled into view before it is used. The canvas label is the presenter's description
// ("Particle scene: <Family>, <force or no force placed>, playing|paused."). The canvas shows the world square
// −500…500 (y up) fitted into it, so a world point maps to the canvas around its middle with the shorter side as the
// square's side; a tap or a drag there places the force. Everything lives in the namespace `PU`, so that nothing
// collides with the shared helpers of `AppUITestSupport` or with the helpers of the other ported apps.
import Foundation
import XCTest

/// Launch arguments, identifiers and helpers of the A04 interface tests.
enum PU {
    /// The experience's id in the catalog.
    static let experienceID = "a04.particle-universe"
    /// The experience's title (catalog name and route title).
    static let title = "Particle Universe"
    /// The prefix of every identifier of the experience's controls.
    static let prefix = "experience.a04.particle-universe."
    /// The debug argument that makes the candidates available (DebugLaunch).
    static let candidates = "-vcCandidates"
    /// A first start with erased data, straight into A04.
    static let fresh = [VC.reset, VC.skipWelcome, candidates, VC.openExperience, experienceID]
    /// A further start that keeps the data (the settings), straight into A04.
    static let again = [VC.skipWelcome, candidates, VC.openExperience, experienceID]
    /// The scene's particle limit (`ParticleScene.defaultLimit`).
    static let limit = 4_000
    /// Half the side of the world square (`PlacedForce.worldHalfExtent`).
    static let half = 500.0

    /// The full identifier of the control `name`.
    static func id(_ name: String) -> String { prefix + name }

    /// The control `name` of A04, of any element type.
    @MainActor
    static func control(_ app: XCUIApplication, _ name: String) -> XCUIElement {
        element(app, id(name))
    }

    /// The slider `name` of A04.
    @MainActor
    static func slider(_ app: XCUIApplication, _ name: String) -> XCUIElement {
        app.sliders.matching(identifier: id(name)).firstMatch
    }

    /// The switch `name` of A04 (a toggle).
    @MainActor
    static func toggle(_ app: XCUIApplication, _ name: String) -> XCUIElement {
        app.switches.matching(identifier: id(name)).firstMatch
    }

    /// The live canvas of the session; its label is the presenter's description.
    @MainActor
    static func canvas(_ app: XCUIApplication) -> XCUIElement {
        element(app, VC.canvas)
    }

    /// Launches the app with `arguments` and waits until A04 runs: the experience route, its canvas and its first
    /// control.
    @MainActor
    @discardableResult
    static func open(arguments: [String] = PU.fresh, largeText: Bool = false,
                     file: StaticString = #filePath, line: UInt = #line) -> XCUIApplication {
        let app = launchApp(arguments: arguments, largeText: largeText)
        waitUntilRunning(app, file: file, line: line)
        return app
    }

    /// Waits until A04 runs in `app`: the experience route, its canvas and its play control.
    @MainActor
    static func waitUntilRunning(_ app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        waitFor(element(app, "vc.route.experience"), timeout: VC.firstWait, file: file, line: line)
        waitFor(canvas(app), timeout: VC.firstWait, file: file, line: line)
        waitFor(control(app, "play"), timeout: VC.wait, file: file, line: line)
    }

    /// Sets the one app's Reduce Motion and Reduce Flashing choices to On where asked (from a fresh start, through
    /// the settings route), then starts the app again straight into A04 and waits until it runs.
    @MainActor
    static func openWithSettings(reduceMotion: Bool = false, reduceFlashing: Bool = false,
                                 file: StaticString = #filePath, line: UInt = #line) -> XCUIApplication {
        let first = launchApp(arguments: [VC.reset, VC.skipWelcome, candidates])
        waitFor(element(first, "vc.route.catalog"), timeout: VC.firstWait, file: file, line: line)
        openSettings(first, file: file, line: line)
        if reduceMotion { chooseOn(first, "vc.settings.reduceMotion", file: file, line: line) }
        if reduceFlashing { chooseOn(first, "vc.settings.reduceFlashing", file: file, line: line) }
        let app = relaunch(first, arguments: again)
        waitUntilRunning(app, file: file, line: line)
        return app
    }

    /// Opens the settings picker `id` and chooses On; waits until the picker says so.
    @MainActor
    private static func chooseOn(_ app: XCUIApplication, _ id: String, file: StaticString, line: UInt) {
        let picker = element(app, id)
        waitFor(picker, timeout: VC.wait, file: file, line: line)
        for _ in 0..<5 where !picker.isHittable { scrollCatalog(app) }
        picker.tap()
        let option = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "On")).firstMatch
        XCTAssertTrue(option.waitForExistence(timeout: 5), "no option On in \(id)", file: file, line: line)
        option.tap()
        let deadline = Date().addingTimeInterval(5)
        while (picker.value as? String) != "On", Date() < deadline { usleep(200_000) }
        XCTAssertEqual(picker.value as? String, "On", id, file: file, line: line)
    }

    /// The scroll view that holds the controls below the canvas.
    @MainActor
    static func controlsList(_ app: XCUIApplication) -> XCUIElement {
        app.scrollViews.containing(NSPredicate(format: "identifier BEGINSWITH %@", prefix)).firstMatch
    }

    /// The part of the controls a person sees: the list's frame, above the home indicator when the list reaches the
    /// bottom of the window (the indicator overlays the last 34 points of an iPhone without a home button).
    @MainActor
    static func visibleControls(_ app: XCUIApplication) -> CGRect {
        var frame = controlsList(app).frame
        let window = app.windows.firstMatch.frame
        if !isTablet, frame.maxY >= window.maxY - 1 { frame.size.height = max(0, frame.height - 34) }
        return frame
    }

    /// One short drag on the controls near their left edge (inside the padding, so that no button, slider or toggle
    /// takes the touch). `forward` moves the finger up, which shows the controls further down.
    @MainActor
    static func drag(_ app: XCUIApplication, forward: Bool) {
        let list = controlsList(app)
        let area = list.exists ? list : app.windows.firstMatch
        let start = area.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: forward ? 0.8 : 0.2))
            .withOffset(CGVector(dx: 8, dy: 0))
        let end = area.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: forward ? 0.3 : 0.7))
            .withOffset(CGVector(dx: 8, dy: 0))
        start.press(forDuration: 0.05, thenDragTo: end)
    }

    /// Scrolls the controls until `target` exists and can be tapped: first further down, then back up. Fails the
    /// test at the caller's line when it never can.
    @MainActor
    @discardableResult
    static func reveal(_ app: XCUIApplication, _ target: XCUIElement,
                       file: StaticString = #filePath, line: UInt = #line) -> Bool {
        _ = target.waitForExistence(timeout: VC.wait)
        // Stop as soon as the target is reachable: a `for … where` loop would keep querying the accessibility tree
        // 28 times after the target was found (about 5 s per call in the first Infinite Geometry k2 run).
        search: for forward in [true, false] {
            for _ in 0..<14 {
                if target.exists && target.isHittable { break search }
                drag(app, forward: forward)
            }
        }
        let found = target.exists && target.isHittable
        XCTAssertTrue(found, "not reached by scrolling the controls: \(target)", file: file, line: line)
        return found
    }

    /// Scrolls the control `name` into view and taps it.
    @MainActor
    static func tap(_ app: XCUIApplication, _ name: String, file: StaticString = #filePath, line: UInt = #line) {
        let target = control(app, name)
        guard reveal(app, target, file: file, line: line) else { return }
        target.tap()
    }

    /// Scrolls the slider `name` into view, lets the list come to rest and moves it to `position` (0…1).
    @MainActor
    static func adjust(_ app: XCUIApplication, _ name: String, to position: CGFloat,
                       file: StaticString = #filePath, line: UInt = #line) {
        let target = slider(app, name)
        guard reveal(app, target, file: file, line: line) else { return }
        usleep(500_000)
        target.adjust(toNormalizedSliderPosition: position)
    }

    /// The spoken value of the slider `name`, or "" when it has none.
    @MainActor
    static func value(_ app: XCUIApplication, _ name: String) -> String {
        slider(app, name).value as? String ?? ""
    }

    /// Waits until the spoken value of the slider `name` satisfies `condition`; true when it does.
    @MainActor
    static func waitForValue(_ app: XCUIApplication, _ name: String, timeout: TimeInterval = VC.wait,
                             _ condition: (String) -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition(value(app, name)), Date() < deadline { usleep(200_000) }
        return condition(value(app, name))
    }

    /// The value of the switch `name` ("1" on, "0" off, "" when it is not there).
    @MainActor
    static func switchValue(_ app: XCUIApplication, _ name: String) -> String {
        let target = toggle(app, name)
        return target.exists ? (target.value as? String ?? "") : ""
    }

    /// Scrolls the switch `name` into view and flips it: the inner switch when there is one, otherwise the right end
    /// of the row, where the switch is drawn (a tap on the label does not flip a toggle). Waits for the new value.
    @MainActor
    static func flip(_ app: XCUIApplication, _ name: String, file: StaticString = #filePath, line: UInt = #line) {
        let target = toggle(app, name)
        guard reveal(app, target, file: file, line: line) else { return }
        let before = switchValue(app, name)
        let inner = target.switches.firstMatch
        if inner.exists {
            inner.tap()
        } else {
            target.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
        }
        let deadline = Date().addingTimeInterval(VC.wait)
        while switchValue(app, name) == before, Date() < deadline { usleep(200_000) }
        XCTAssertNotEqual(switchValue(app, name), before, "\(name) did not change", file: file, line: line)
    }

    /// Waits until the label of `target` satisfies `condition`; true when it does.
    @MainActor
    static func waitForLabel(_ target: XCUIElement, timeout: TimeInterval = VC.wait,
                             _ condition: (String) -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while !(target.exists && condition(target.label)), Date() < deadline { usleep(200_000) }
        return target.exists && condition(target.label)
    }

    /// Waits until `target` is (or is not) selected; true when it is as asked.
    @MainActor
    static func waitForSelection(_ target: XCUIElement, _ selected: Bool = true,
                                 timeout: TimeInterval = VC.wait) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while target.isSelected != selected, Date() < deadline { usleep(200_000) }
        return target.isSelected == selected
    }

    /// The whole numbers in `text`, in order (separators of thousands removed).
    static func numbers(_ text: String) -> [Int] {
        text.replacingOccurrences(of: ",", with: "").components(separatedBy: CharacterSet.decimalDigits.inverted)
            .filter { !$0.isEmpty }.compactMap(Int.init)
    }

    /// (live, limit) from "Live particles: N of LIMIT", or nil when the text does not read so.
    @MainActor
    static func counts(_ app: XCUIApplication) -> (live: Int, limit: Int)? {
        let parts = numbers(control(app, "live").label)
        return parts.count == 2 ? (parts[0], parts[1]) : nil
    }

    /// The live particle count, or −1 when the text does not read as one.
    @MainActor
    static func live(_ app: XCUIApplication) -> Int { counts(app)?.live ?? -1 }

    /// Waits until the live count satisfies `condition`; the last count read.
    @MainActor
    @discardableResult
    static func waitForLive(_ app: XCUIApplication, timeout: TimeInterval = VC.wait, _ condition: (Int) -> Bool) -> Int {
        let deadline = Date().addingTimeInterval(timeout)
        var n = live(app)
        while !condition(n), Date() < deadline { usleep(200_000); n = live(app) }
        return n
    }

    /// The number of emitters from "Emitters: N of 8", or −1.
    @MainActor
    static func emitterCount(_ app: XCUIApplication) -> Int {
        numbers(control(app, "emitters").label).first ?? -1
    }

    /// (kind, x, y) from "Force: Kind at x, y", or nil for "Force: none — …" and any other text.
    @MainActor
    static func force(_ app: XCUIApplication) -> (kind: String, x: Int, y: Int)? {
        let text = control(app, "force").label
        guard let regex = try? NSRegularExpression(pattern: #"^Force: (.+) at (-?\d+), (-?\d+)$"#),
              let m = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) else { return nil }
        func group(_ i: Int) -> String {
            Range(m.range(at: i), in: text).map { String(text[$0]) } ?? ""
        }
        guard let x = Int(group(2)), let y = Int(group(3)) else { return nil }
        return (group(1), x, y)
    }

    /// Waits until the force text satisfies `condition`; true when it does.
    @MainActor
    static func waitForForce(_ app: XCUIApplication, timeout: TimeInterval = VC.wait,
                             _ condition: ((kind: String, x: Int, y: Int)?) -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition(force(app)), Date() < deadline { usleep(200_000) }
        return condition(force(app))
    }

    /// The canvas point that shows the world point (`x`, `y`): the world square is fitted into the canvas around its
    /// middle, the shorter side being its side; y points up.
    @MainActor
    static func world(_ app: XCUIApplication, x: Double, y: Double) -> XCUICoordinate {
        let c = canvas(app)
        let side = Double(min(c.frame.width, c.frame.height))
        return c.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .withOffset(CGVector(dx: x / (2 * half) * side, dy: -y / (2 * half) * side))
    }

    /// Sends the app to the background and brings it back; fails at the caller's line when it does not return.
    @MainActor
    static func backgroundAndReturn(_ app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        XCUIDevice.shared.press(.home)
        _ = app.wait(for: .runningBackground, timeout: VC.wait)
            || app.wait(for: .runningBackgroundSuspended, timeout: 2)
        app.activate()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: VC.wait), "back in the foreground", file: file, line: line)
        waitFor(canvas(app), timeout: VC.wait, file: file, line: line)
    }

    /// Adds a screenshot that is kept with the result.
    @MainActor
    static func attachScreenshot(_ app: XCUIApplication, named name: String, to test: XCTestCase) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        test.add(shot)
    }
}
