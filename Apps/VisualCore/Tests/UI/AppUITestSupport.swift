// AppUITestSupport — feature 190 T-U04-007 to T-U04-010 (UA-F04): helpers shared by the interface tests of the
// unified app. Elements are found by the identifiers of data-model.md section 6, never by position. The audit
// wrapper follows the pattern of the standalone apps (features 016 and 020): contrast of the artwork inside the
// live canvas, navigation-bar chrome, text only partly on screen and findings without an element are ignored, and
// each ignored finding is printed.
import Foundation
import UIKit
import XCTest

/// Launch arguments and identifiers the interface tests use.
enum VC {
    static let fixture = "-vcFixtureCatalog"
    static let reset = "-vcResetData"
    static let skipWelcome = "-vcSkipWelcome"
    static let openExperience = "-openExperience"
    static let largestText = "UICTContentSizeCategoryAccessibilityXXXL"
    static let tilePrefix = "vc.tile."
    static let sectionPrefix = "vc.section."
    static let canvas = "session.canvas"
    /// How long a test waits for its first element.
    static let firstWait: TimeInterval = 20
    /// How long a test waits for a later element.
    static let wait: TimeInterval = 10
}

private final class FindingLog: @unchecked Sendable {
    private let lock = NSLock()
    private var items: [String] = []
    func append(_ s: String) { lock.lock(); items.append(s); lock.unlock() }
    var all: [String] { lock.lock(); defer { lock.unlock() }; return items }
}

/// Launches a new instance of the app with `arguments`, at the largest accessibility text size when asked.
@MainActor
@discardableResult
func launchApp(arguments: [String], largeText: Bool = false) -> XCUIApplication {
    let app = XCUIApplication()
    app.launchArguments += arguments
    if largeText { app.launchArguments += ["-UIPreferredContentSizeCategoryName", VC.largestText] }
    app.launch()
    return app
}

/// Terminates `app` (after a moment in which the stored preferences reach the disk) and launches a new instance.
@MainActor
@discardableResult
func relaunch(_ app: XCUIApplication, arguments: [String], largeText: Bool = false) -> XCUIApplication {
    usleep(1_000_000)
    app.terminate()
    return launchApp(arguments: arguments, largeText: largeText)
}

/// The first element with the accessibility identifier `id`, of any type.
@MainActor
func element(_ app: XCUIApplication, _ id: String) -> XCUIElement {
    app.descendants(matching: .any).matching(identifier: id).firstMatch
}

/// Every element whose identifier starts with `prefix`.
@MainActor
func elements(_ app: XCUIApplication, prefix: String) -> XCUIElementQuery {
    app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH %@", prefix))
}

/// Every launcher tile (`vc.tile.<id>`).
@MainActor
func tile(_ app: XCUIApplication) -> XCUIElementQuery { elements(app, prefix: VC.tilePrefix) }

/// Waits for `element` and fails the test at the caller's line when it does not appear.
@MainActor
@discardableResult
func waitFor(_ element: XCUIElement, timeout: TimeInterval = VC.firstWait, _ message: String = "",
             file: StaticString = #filePath, line: UInt = #line) -> Bool {
    let found = element.waitForExistence(timeout: timeout)
    XCTAssertTrue(found, message.isEmpty ? "missing: \(element)" : message, file: file, line: line)
    return found
}

/// Waits until `element` is gone; true when it is.
@MainActor
func waitUntilGone(_ element: XCUIElement, timeout: TimeInterval = VC.wait) -> Bool {
    let deadline = Date().addingTimeInterval(timeout)
    while element.exists, Date() < deadline { usleep(200_000) }
    return !element.exists
}

/// Scrolls up to five times until `element` can be tapped, then taps it.
@MainActor
func scrollCatalog(_ app: XCUIApplication) {
    // On a tablet the catalog is the sidebar: a swipe on the app would scroll the detail. The catalog list is the
    // first collection view in both layouts.
    let list = app.collectionViews.firstMatch
    if list.exists { list.swipeUp() } else { app.swipeUp() }
}

/// Scrolls the catalog until `element` exists and can be tapped, then taps it.
@MainActor
func revealAndTap(_ app: XCUIApplication, _ element: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
    guard waitFor(element, timeout: VC.wait, file: file, line: line) else { return }
    for _ in 0..<5 where !element.isHittable { scrollCatalog(app) }
    element.tap()
}

/// The distinct identifiers that start with `prefix`, collected while scrolling down (lazy containers hold only
/// what is near the screen) until `expected` are found or five swipes are done.
@MainActor
func identifiers(_ app: XCUIApplication, prefix: String, expected: Int) -> [String] {
    var seen: [String] = []
    for attempt in 0...5 {
        for id in elements(app, prefix: prefix).allElementsBoundByIndex.map(\.identifier) where !seen.contains(id) {
            seen.append(id)
        }
        if seen.count >= expected || attempt == 5 { break }
        scrollCatalog(app)
    }
    return seen
}

/// The label and value texts of every element with the identifier `id` and of the texts inside them, joined.
@MainActor
func text(_ app: XCUIApplication, of id: String) -> String {
    var parts: [String] = []
    for item in app.descendants(matching: .any).matching(identifier: id).allElementsBoundByIndex {
        parts.append(item.label)
        if let value = item.value as? String { parts.append(value) }
        parts += item.staticTexts.allElementsBoundByIndex.map(\.label)
    }
    return parts.joined(separator: " ")
}

/// Opens the settings route from the catalog route (`vc.nav.settings`).
@MainActor
func openSettings(_ app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
    revealAndTap(app, element(app, "vc.nav.settings"), file: file, line: line)
    waitFor(element(app, "vc.route.settings"), timeout: VC.wait, file: file, line: line)
}

/// Opens the about route from the catalog route (`vc.nav.about`).
@MainActor
func openAbout(_ app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
    revealAndTap(app, element(app, "vc.nav.about"), file: file, line: line)
    waitFor(element(app, "vc.route.about"), timeout: VC.wait, file: file, line: line)
}

/// The first tile whose label names the tier `tier` ("Free" or "Premium").
@MainActor
func firstTile(_ app: XCUIApplication, tier: String) -> XCUIElement {
    tile(app).matching(NSPredicate(format: "label CONTAINS[c] %@", tier)).firstMatch
}

/// True on a tablet.
@MainActor var isTablet: Bool { UIDevice.current.userInterfaceIdiom == .pad }

/// Runs the system accessibility audit on what `app` shows. At the default text size the two text-size audits are
/// left out, as in the standalone apps. Returns the ignored findings.
@MainActor
@discardableResult
func audit(_ app: XCUIApplication, _ screen: String, largeText: Bool) throws -> [String] {
    let all = XCUIAccessibilityAuditType.all
    let types: XCUIAccessibilityAuditType = largeText ? all : all.subtracting([.dynamicType, .textClipped])
    let ignored = FindingLog()
    let bars = app.navigationBars.allElementsBoundByIndex.map { $0.frame }
    let screen = app.windows.firstMatch.frame
    let label = "\(screen) [\(largeText ? "largest" : "default")]"
    try app.performAccessibilityAudit(for: types) { issue in
        let e = issue.element
        let id = e?.identifier ?? ""
        let detail = e.map { "type \($0.elementType.rawValue) label '\($0.label)' frame \($0.frame)" } ?? "no element"
        let description = "\(label): \(issue.auditType.rawValue) on '\(id)' [\(detail)] — \(issue.compactDescription)"
        if id == VC.canvas, issue.auditType == .contrast {
            ignored.append(description)
            print("A11Y-AUDIT ignored (artwork in the live canvas): \(description)")
            return true
        }
        if let frame = e?.frame, bars.contains(where: { $0.insetBy(dx: -1, dy: -1).contains(frame) }),
           issue.auditType == .contrast || issue.auditType == .dynamicType || issue.auditType == .textClipped {
            ignored.append(description)
            print("A11Y-AUDIT ignored (navigation-bar chrome): \(description)")
            return true
        }
        if let frame = e?.frame, issue.auditType == .contrast, !screen.isEmpty, !screen.contains(frame) {
            // A text the scroll position cuts at the screen edge is measured on the cut glyphs; the same text is
            // audited in full where a test scrolls to it.
            ignored.append(description)
            print("A11Y-AUDIT ignored (text only partly on screen): \(description)")
            return true
        }
        if e == nil {
            ignored.append(description)
            print("A11Y-AUDIT ignored (no element identified by the audit): \(description)")
            return true
        }
        print("A11Y-AUDIT issue: \(description)")
        return false
    }
    return ignored.all
}
