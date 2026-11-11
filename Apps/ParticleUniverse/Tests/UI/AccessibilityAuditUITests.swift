// AccessibilityAuditUITests — feature 033 T-A04-107 (SC-A04-106; constitution A04 accessibility), following A03's
// audit (feature 026): home and sandbox at the default and the largest accessibility text size. Documented exclusions
// (as A01–A03): contrast of the particles inside the preview canvas, navigation-bar chrome, text scrolled under the
// navigation bar or cut by the bottom edge, and findings without an element. Each ignored finding is logged.
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

    private func audit(_ app: XCUIApplication, _ screen: String, types: XCUIAccessibilityAuditType) throws {
        let ignored = FindingLog()
        let bars = app.navigationBars.allElementsBoundByIndex.map { $0.frame }
        let windowFrame = app.windows.firstMatch.frame
        try app.performAccessibilityAudit(for: types) { issue in
            let e = issue.element
            let id = e?.identifier ?? ""
            let detail = e.map { "type \($0.elementType.rawValue) label '\($0.label)' frame \($0.frame)" } ?? "no element"
            let description = "\(screen): \(issue.auditType.rawValue) on '\(id)' [\(detail)] — \(issue.compactDescription)"
            func ignore(_ why: String) -> Bool {
                ignored.append(description)
                print("A11Y-AUDIT ignored (\(why)): \(description)")
                return true
            }
            if id == "pu.sandbox.canvas", issue.auditType == .contrast { return ignore("particles in the preview canvas") }
            if let frame = e?.frame, bars.contains(where: { $0.insetBy(dx: -1, dy: -1).contains(frame) }),
               issue.auditType == .contrast || issue.auditType == .dynamicType || issue.auditType == .textClipped {
                return ignore("navigation-bar chrome")
            }
            if issue.auditType == .contrast, let frame = e?.frame, bars.contains(where: { frame.minY <= $0.maxY + 0.5 }) {
                return ignore("text scrolled under the navigation bar")
            }
            if issue.auditType == .contrast, let frame = e?.frame, frame.maxY > windowFrame.maxY {
                return ignore("text cut by the bottom edge of the screen")
            }
            if e == nil { return ignore("no element identified by the audit") }
            print("A11Y-AUDIT issue: \(description)")
            return false
        }
        print("A11Y-AUDIT \(screen): \(ignored.all.count) ignored")
    }

    private func run(textSize: String?) throws {
        let app = XCUIApplication()
        if let textSize { app.launchArguments += ["-UIPreferredContentSizeCategoryName", textSize] }
        app.launch()
        let label = textSize ?? "default"
        let types: XCUIAccessibilityAuditType = textSize == nil ? XCUIAccessibilityAuditType.all.subtracting([.dynamicType, .textClipped]) : .all
        let open = app.buttons["pu.home.open"]
        XCTAssertTrue(open.waitForExistence(timeout: 10))
        try audit(app, "home [\(label)]", types: types)
        open.tap()
        XCTAssertTrue(app.descendants(matching: .any)["pu.sandbox.canvas"].waitForExistence(timeout: 10))
        app.buttons["pu.sandbox.play"].tap()   // pause, so the audit sees a stable screen
        try audit(app, "sandbox [\(label)]", types: types)
        app.swipeUp()
        try audit(app, "sandbox scrolled [\(label)]", types: types)
    }

    func testAuditDefaultTextSize() throws { try run(textSize: nil) }
    func testAuditLargestAccessibilityTextSize() throws { try run(textSize: "UICTContentSizeCategoryAccessibilityXXXL") }
}
