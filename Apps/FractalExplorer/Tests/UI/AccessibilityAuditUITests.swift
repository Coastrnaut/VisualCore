// AccessibilityAuditUITests — feature 026 T-A03-105, feature 027 T-A03-208, features 028–029 (SC-A03-103; constitution A03 accessibility), following A02's
// audit (feature 020).
// Runs the system accessibility audit on home and playground at the default and the largest accessibility text size,
// following the A01 pattern (feature 016). Documented exclusions (spec 020 Clarifications): contrast of the artwork
// inside the live canvas, navigation-bar chrome, contrast of text scrolled partly under the navigation bar (feature
// 027) or cut by the bottom edge of the screen (feature 029), and findings without an element. Each ignored finding is logged.
import Foundation
import XCTest

private final class FindingLog: @unchecked Sendable {
    private let lock = NSLock()
    private var items: [String] = []
    func append(_ s: String) { lock.lock(); items.append(s); lock.unlock() }
    var all: [String] { lock.lock(); defer { lock.unlock() }; return items }
}

final class AccessibilityAuditUITests: XCTestCase {
    override func setUp() { continueAfterFailure = true }

    @discardableResult
    private func audit(_ app: XCUIApplication, _ screen: String, types: XCUIAccessibilityAuditType) throws -> [String] {
        let ignored = FindingLog()
        let bars = app.navigationBars.allElementsBoundByIndex.map { $0.frame }
        let windowFrame = app.windows.firstMatch.frame
        try app.performAccessibilityAudit(for: types) { issue in
            let e = issue.element
            let id = e?.identifier ?? ""
            let detail = e.map { "type \($0.elementType.rawValue) label '\($0.label)' frame \($0.frame)" } ?? "no element"
            let description = "\(screen): \(issue.auditType.rawValue) on '\(id)' [\(detail)] — \(issue.compactDescription)"
            if id == "fe.canvas", issue.auditType == .contrast {
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
            // Feature 027: text scrolled partly under the translucent navigation bar is measured against the bar's blur,
            // not its own background (seen on iOS 26.5 at XXXL after scrolling to the zoom controls). Its reported frame starts on or
            // above the bar's bottom edge (clipped there, or above the screen when scrolled further; feature 029) ; text scrolled
            // entirely above it counts too (feature 029).
            if issue.auditType == .contrast, let frame = e?.frame,
               bars.contains(where: { frame.minY <= $0.maxY + 0.5 }) {
                ignored.append(description)
                print("A11Y-AUDIT ignored (text scrolled under the navigation bar): \(description)")
                return true
            }
            // Feature 029: text cut by the window's bottom edge (scrolled partly or fully below the screen) is measured
            // against the bottom scroll-edge effect, not its own background.
            if issue.auditType == .contrast, let frame = e?.frame, frame.maxY > windowFrame.maxY {
                ignored.append(description)
                print("A11Y-AUDIT ignored (text cut by the bottom edge of the screen): \(description)")
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

    private func run(textSize: String?) throws {
        let app = XCUIApplication()
        app.launchArguments += ["-uitestTemporaryBookmarks"]
        if let textSize { app.launchArguments += ["-UIPreferredContentSizeCategoryName", textSize] }
        app.launch()
        let label = textSize ?? "default"
        let types: XCUIAccessibilityAuditType = textSize == nil ? XCUIAccessibilityAuditType.all.subtracting([.dynamicType, .textClipped]) : .all
        let open = app.buttons["fe.home.open"]
        XCTAssertTrue(open.waitForExistence(timeout: 10))
        try audit(app, "home [\(label)]", types: types)
        for _ in 0..<3 where !open.isHittable { app.swipeUp() }
        open.tap()
        XCTAssertTrue(app.segmentedControls["fe.mode"].waitForExistence(timeout: 10))
        try audit(app, "explorer mandelbrot [\(label)]", types: types)
        app.segmentedControls["fe.mode"].buttons["Julia"].tap()
        XCTAssertTrue(app.staticTexts["fe.seed"].waitForExistence(timeout: 10))
        try audit(app, "explorer julia [\(label)]", types: types)
        // Feature 028 T-A03-310: the Go to sheet and the bookmark sheet (empty, then with one bookmark).
        app.buttons["fe.goto"].tap()
        XCTAssertTrue(app.textFields["fe.goto.real"].waitForExistence(timeout: 5))
        try audit(app, "go to sheet [\(label)]", types: types)
        app.buttons["fe.goto.cancel"].tap()
        app.buttons["fe.bookmarks"].tap()
        XCTAssertTrue(app.staticTexts["fe.bookmarks.empty"].waitForExistence(timeout: 5))
        try audit(app, "bookmarks empty [\(label)]", types: types)
        app.buttons["fe.bookmark.save"].tap()
        XCTAssertTrue(app.alerts.textFields.firstMatch.waitForExistence(timeout: 5))
        app.alerts.textFields.firstMatch.typeText("Audit")
        app.alerts.buttons["Save"].firstMatch.tap()
        XCTAssertTrue(app.descendants(matching: .any)["fe.bookmark.row.0"].waitForExistence(timeout: 5))
        try audit(app, "bookmarks list [\(label)]", types: types)
        app.buttons["fe.bookmarks.done"].tap()
        XCTAssertTrue(app.segmentedControls["fe.mode"].waitForExistence(timeout: 5))
        // Feature 029 T-A03-410: the cap and cost controls, a capture result, the tours sheet and a playing tour.
        let capture = app.buttons["fe.capture"]
        for _ in 0..<6 where !(capture.exists && capture.isHittable) { app.swipeUp() }
        capture.tap()
        XCTAssertTrue(app.descendants(matching: .any)["fe.capture.share"].waitForExistence(timeout: 20))
        try audit(app, "cost and capture [\(label)]", types: types)
        app.buttons["fe.tours"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["fe.tour.seahorse"].waitForExistence(timeout: 5))
        try audit(app, "tours sheet [\(label)]", types: types)
        app.descendants(matching: .any)["fe.tour.seahorse"].tap()
        let caption = app.descendants(matching: .any)["fe.tour.caption"]
        XCTAssertTrue(caption.waitForExistence(timeout: 10))
        for _ in 0..<6 where !caption.isHittable { app.swipeUp() }
        if app.buttons["fe.tour.stop"].exists { app.buttons["fe.tour.stop"].tap() }
        try audit(app, "tour caption [\(label)]", types: types)
        // Feature 027 T-A03-208: the explorer with the precision banner, reached through the zoom controls.
        // Julia is centered at 0, where float spacing never limits the zoom, so go back to Mandelbrot (center −0.5).
        app.segmentedControls["fe.mode"].buttons["Mandelbrot"].tap()
        let banner = app.descendants(matching: .any)["fe.precision"]
        let zoomIn = app.buttons["fe.zoomIn"]
        for _ in 0..<40 where !banner.exists {
            for _ in 0..<3 where !zoomIn.isHittable { app.swipeUp() }
            zoomIn.tap()
        }
        XCTAssertTrue(banner.exists)
        try audit(app, "explorer precision banner [\(label)]", types: types)
    }

    func testAuditDefaultTextSize() throws { try run(textSize: nil) }

    func testAuditLargestAccessibilityTextSize() throws { try run(textSize: "UICTContentSizeCategoryAccessibilityXXXL") }
}
