// AcknowledgementsUITests — feature 197 T-U11-020 (US4; FR-U11-032; SC-U11-004): About → Acknowledgements lists
// every license that docs/legal/third-party.json marks as shipped, each row with a label and a 44-point target, and a
// row opens its readable text. System accessibility audits of this screen run in the device campaign (owner ruling of
// 2026-11-13).
import Foundation
import XCTest

final class AcknowledgementsUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    /// The ids of the shipped inventory entries, read from the repository through this file's path (the simulator
    /// runs on the host and can read it).
    private func shippedIDs() throws -> [String] {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()   // UI
            .deletingLastPathComponent()   // Tests
            .deletingLastPathComponent()   // VisualCore
            .deletingLastPathComponent()   // Apps
            .deletingLastPathComponent()   // repository
        let data = try Data(contentsOf: root.appendingPathComponent("docs/legal/third-party.json"))
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let components = try XCTUnwrap(object["components"] as? [[String: Any]])
        let ids = components.filter { ($0["scope"] as? String) == "shipped" }.compactMap { $0["id"] as? String }
        XCTAssertFalse(ids.isEmpty, "the inventory marks no license as shipped")
        return ids
    }

    @MainActor
    func testEveryShippedLicenseIsListedAndReadable() throws {
        let ids = try shippedIDs()
        let app = launchApp(arguments: [VC.reset, VC.fixture, VC.skipWelcome])
        waitFor(element(app, "vc.route.catalog"))
        openAbout(app)
        revealAndTap(app, element(app, "vc.about.acknowledgements"))
        let list = element(app, "vc.acknowledgements")
        waitFor(list, timeout: VC.wait)

        // One pass from the top: the list's order is the bundled index's, so rows are recorded as they appear.
        var seen: [String: (label: String, height: CGFloat)] = [:]
        let prefix = "vc.acknowledgements."
        for attempt in 0...12 {
            for row in elements(app, prefix: prefix).allElementsBoundByIndex where row.isHittable {
                let id = String(row.identifier.dropFirst(prefix.count))
                guard id != "text", seen[id] == nil else { continue }
                seen[id] = (row.label, row.frame.height)
            }
            if ids.allSatisfy({ seen[$0] != nil }) || attempt == 12 { break }
            list.swipeUp()
        }
        for id in ids {
            guard let row = seen[id] else {
                XCTFail("no row for the shipped license \(id); rows seen: \(seen.keys.sorted())")
                continue
            }
            XCTAssertFalse(row.label.isEmpty, "the row of \(id) has no VoiceOver label")
            XCTAssertGreaterThanOrEqual(row.height, 44, "the row of \(id) is shorter than 44 points")
        }

        let first = element(app, "vc.acknowledgements.\(ids[0])")
        for _ in 0..<12 where !(first.exists && first.isHittable) { list.swipeDown() }
        first.tap()
        let text = element(app, "vc.acknowledgements.text")
        waitFor(text, timeout: VC.wait)
        XCTAssertFalse(text.label.isEmpty, "the license text of \(ids[0]) is empty")
    }
}
