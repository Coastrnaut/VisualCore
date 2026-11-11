// AccessibilityAuditUITests — feature 026 T-A03-105 (SC-A03-103; constitution A03 accessibility), following A02's
// audit (feature 020).
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
    }

    func testAuditDefaultTextSize() throws { try run(textSize: nil) }

    func testAuditLargestAccessibilityTextSize() throws { try run(textSize: "UICTContentSizeCategoryAccessibilityXXXL") }
}
