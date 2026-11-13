// CopyTests — feature 031 T-A03-606 (FR-A03-605, SC-A03-605; US4 AC2), after A02: the home copy and the store description name
// only implemented, tested features — no promises of later work and no performance, battery or accuracy claims — and
// every store claim row names a test that exists in this target's sources.
import Foundation
import XCTest
@testable import FractalExplorerExperience

final class CopyTests: XCTestCase {
    // Since feature 193 the tests live in Packages/ExperiencesCreative/FractalExplorer/ExperienceTests and the
    // interface tests in Apps/VisualCore/Tests/UI/FractalExplorer; a claim naming a retired test resolves through
    // specs/193-ua-f07-legacy-adoption/test-map.csv.
    static let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    static let repo = root.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    static let testFolders = [root.appendingPathComponent("ExperienceTests"),
                              repo.appendingPathComponent("Apps/VisualCore/Tests/UI/FractalExplorer"),
                              repo.appendingPathComponent("Apps/VisualCore/Tests/UI")]
    static let banned = ["coming soon", "later phase", "in a future", "fps", "frames per second", "battery", "60 hz",
                         "120 hz", "fast", "faster", "real-time", "real time", "unlimited", "infinite zoom", "endless zoom",
                         "deep zoom", "iphone 15", "ipad pro", "m5", "a16", "benchmark", "guaranteed"]

    private func storeListing() throws -> String {
        try String(contentsOf: Self.repo.appendingPathComponent("docs/apps/fractal-explorer/store-listing.md"), encoding: .utf8)
    }

    /// The store description: the block between **Description:** and the claim table.
    private func description(_ listing: String) throws -> String {
        let start = try XCTUnwrap(listing.range(of: "**Description:**"))
        let end = try XCTUnwrap(listing.range(of: "## Claim traceability"))
        return String(listing[start.upperBound..<end.lowerBound])
    }

    func testCopyHasNoUnsupportedPromises() throws {
        // The standalone home screen is retired with the app (feature 193); the one app shows A03 by its catalog
        // summary, which is checked in its place.
        let catalog = try JSONSerialization.jsonObject(with: Data(contentsOf: Self.repo.appendingPathComponent(
            "Catalog/experiences.json"))) as? [String: Any]
        let entries = catalog?["experiences"] as? [[String: Any]] ?? []
        let home = try XCTUnwrap(entries.first { $0["id"] as? String == "a03.fractal-explorer" }?["summary"] as? String)
        let texts = ["catalog": home, "store": try description(storeListing())]
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
        let sources = try Self.testFolders.flatMap { folder in
            try FileManager.default.contentsOfDirectory(atPath: folder.path).filter { $0.hasSuffix(".swift") }
                .map { try String(contentsOf: folder.appendingPathComponent($0), encoding: .utf8) }
        }.joined(separator: "\n")
        // Old interface tests ported under another name: old "Class.method" → new "Class.method" names.
        let map = try String(contentsOf: Self.repo.appendingPathComponent("specs/193-ua-f07-legacy-adoption/test-map.csv"),
                             encoding: .utf8)
        var ported: [String: [(String, String)]] = [:]
        for row in map.split(separator: "\n").dropFirst() {
            let cells = row.split(separator: ",", maxSplits: 5, omittingEmptySubsequences: false).map(String.init)
            guard cells.count >= 5, cells[0] == "FractalExplorer" else { continue }
            let methods = cells[4] == "-" ? [] : cells[4].split(separator: ";").map { (cells[3], String($0)) }
            ported[cells[1] + "." + cells[2]] = methods
        }
        let pattern = try NSRegularExpression(pattern: "`([A-Za-z]+Tests)\\.(test[A-Za-z0-9]+)`")
        var checked = 0
        for row in rows {
            let line = String(row)
            let matches = pattern.matches(in: line, range: NSRange(line.startIndex..., in: line))
            XCTAssertFalse(matches.isEmpty && !line.contains(".py"), "claim without a test: \(line)")
            for m in matches {
                let cls = (line as NSString).substring(with: m.range(at: 1))
                let method = (line as NSString).substring(with: m.range(at: 2))
                let names = sources.contains("class \(cls)") ? [(cls, method)] : ported[cls + "." + method] ?? [(cls, method)]
                for (c, m) in names {
                    XCTAssertTrue(sources.contains("class \(c)"), "missing class \(c) (claim \(cls).\(method))")
                    XCTAssertTrue(sources.contains("func \(m)("), "missing test \(c).\(m) (claim \(cls).\(method))")
                }
                checked += 1
            }
        }
        print("copy: \(rows.count) store claims, \(checked) test references resolved")
    }
}
