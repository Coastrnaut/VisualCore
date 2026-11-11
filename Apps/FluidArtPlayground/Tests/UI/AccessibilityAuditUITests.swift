// AccessibilityAuditUITests — feature 020 T-A02-213 (SC-A02-205; analyze U1; constitution A02 accessibility).
// Runs the system accessibility audit on home and playground at the default and the largest accessibility text size,
// following the A01 pattern (feature 016). Documented exclusions (spec 020 Clarifications): contrast of the artwork
// inside the live canvas, navigation-bar chrome, and findings without an element. Each ignored finding is logged.
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
        try app.performAccessibilityAudit(for: types) { issue in
            let e = issue.element
            let id = e?.identifier ?? ""
            let detail = e.map { "type \($0.elementType.rawValue) label '\($0.label)' frame \($0.frame)" } ?? "no element"
            let description = "\(screen): \(issue.auditType.rawValue) on '\(id)' [\(detail)] — \(issue.compactDescription)"
            if id == "fap.canvas", issue.auditType == .contrast {
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
        if let textSize { app.launchArguments += ["-UIPreferredContentSizeCategoryName", textSize] }
        app.launch()
        let label = textSize ?? "default"
        let types: XCUIAccessibilityAuditType = textSize == nil ? XCUIAccessibilityAuditType.all.subtracting([.dynamicType, .textClipped]) : .all
        let open = app.buttons["fap.home.open"]
        XCTAssertTrue(open.waitForExistence(timeout: 10))
        try audit(app, "home [\(label)]", types: types)
        for _ in 0..<3 where !open.isHittable { app.swipeUp() }
        open.tap()
        XCTAssertTrue(app.buttons["fap.splash"].waitForExistence(timeout: 10))
        try audit(app, "playground [\(label)]", types: types)
    }

    func testAuditDefaultTextSize() throws { try run(textSize: nil) }

    func testAuditLargestAccessibilityTextSize() throws { try run(textSize: "UICTContentSizeCategoryAccessibilityXXXL") }
}
