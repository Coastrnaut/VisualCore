// CopyTests — feature 024 T-A02-608 (FR-A02-609; US5 AC1; analyze U1): the home copy and the store description name
// only implemented, tested features — no promises of later work and no performance, battery or accuracy claims — and
// every store claim row names a test that exists in this target's sources.
import Foundation
import XCTest
@testable import FluidArtPlayground

final class CopyTests: XCTestCase {
    static let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()   // Apps/FluidArtPlayground
    static let repo = root.deletingLastPathComponent().deletingLastPathComponent()
    static let banned = ["coming soon", "later phase", "in a future", "fps", "frames per second", "physically accurate",
                         "battery", "realistic physics", "60 hz", "120 hz"]

    private func storeListing() throws -> String {
        try String(contentsOf: Self.repo.appendingPathComponent("docs/apps/fluid-art-playground/store-listing.md"), encoding: .utf8)
    }

    /// The store description: the block between **Description:** and the claim table.
    private func description(_ listing: String) throws -> String {
        let start = try XCTUnwrap(listing.range(of: "**Description:**"))
        let end = try XCTUnwrap(listing.range(of: "## Claim traceability"))
        return String(listing[start.upperBound..<end.lowerBound])
    }

    func testCopyHasNoUnsupportedPromises() throws {
        let texts = ["home": HomeView.summary, "store": try description(storeListing())]
        for (name, text) in texts {
            let lower = text.lowercased()
            for word in Self.banned { XCTAssertFalse(lower.contains(word), "\(name) copy contains '\(word)'") }
        }
    }

    func testEveryStoreClaimNamesAnExistingTest() throws {
        let listing = try storeListing()
        let table = listing.components(separatedBy: "## Claim traceability").last ?? ""
        let rows = table.split(separator: "\n").filter { $0.hasPrefix("| ") && !$0.hasPrefix("| Claim") && !$0.hasPrefix("|---") }
        XCTAssertGreaterThanOrEqual(rows.count, 10)
        let sources = try FileManager.default.subpathsOfDirectory(atPath: Self.root.appendingPathComponent("Tests").path)
            .filter { $0.hasSuffix(".swift") }
            .map { try String(contentsOf: Self.root.appendingPathComponent("Tests").appendingPathComponent($0), encoding: .utf8) }
            .joined(separator: "\n")
        let pattern = try NSRegularExpression(pattern: "`([A-Za-z]+Tests)\\.(test[A-Za-z0-9]+)`")
        var checked = 0
        for row in rows {
            let line = String(row)
            let matches = pattern.matches(in: line, range: NSRange(line.startIndex..., in: line))
            XCTAssertFalse(matches.isEmpty && !line.contains(".py"), "claim without a test: \(line)")
            for m in matches {
                let cls = (line as NSString).substring(with: m.range(at: 1))
                let method = (line as NSString).substring(with: m.range(at: 2))
                XCTAssertTrue(sources.contains("class \(cls)"), "missing class \(cls)")
                XCTAssertTrue(sources.contains("func \(method)("), "missing test \(cls).\(method)")
                checked += 1
            }
        }
        print("copy: \(rows.count) store claims, \(checked) test references resolved")
    }
}
