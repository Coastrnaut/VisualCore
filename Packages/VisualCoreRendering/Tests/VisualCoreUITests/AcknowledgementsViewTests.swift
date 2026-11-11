// AcknowledgementsViewTests — feature 017 T-A01-610 (FR-A01-605).
import SwiftUI
import UIKit
import XCTest
@testable import VisualCoreUI

@MainActor
final class AcknowledgementsViewTests: XCTestCase {
    private func folder(_ entries: String, files: [String: String]) throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("licenses-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try entries.write(to: dir.appendingPathComponent("licenses.json"), atomically: true, encoding: .utf8)
        for (name, text) in files { try text.write(to: dir.appendingPathComponent(name), atomically: true, encoding: .utf8) }
        return dir
    }

    func testLoadsIndexAndTexts() throws {
        let dir = try folder(#"[{"id":"angle","name":"ANGLE","license":"BSD-3-Clause","file":"angle.txt"}]"#,
                             files: ["angle.txt": "Copyright The ANGLE Project Authors"])
        let inventory = try XCTUnwrap(LicenseInventory(folder: dir))
        XCTAssertEqual(inventory.entries.map(\.id), ["angle"])
        XCTAssertEqual(inventory.text(for: inventory.entries[0]), "Copyright The ANGLE Project Authors")
        let missing = LicenseInventory.Entry(id: "x", name: "X", license: "MIT", file: "nope.txt")
        XCTAssertTrue(inventory.text(for: missing).contains("could not be read"))
    }

    func testMissingOrBadIndexIsNil() throws {
        XCTAssertNil(LicenseInventory(folder: FileManager.default.temporaryDirectory.appendingPathComponent("none-\(UUID())")))
        XCTAssertNil(LicenseInventory(folder: try folder("not json", files: [:])))
    }

    func testViewHostsWithAndWithoutInventory() throws {
        let dir = try folder(#"[{"id":"a","name":"A","license":"MIT","file":"a.txt"}]"#, files: ["a.txt": "MIT text"])
        for inventory in [LicenseInventory(folder: dir), nil] {
            let host = UIHostingController(rootView: NavigationStack { AcknowledgementsView(inventory: inventory) })
            host.view.frame = CGRect(x: 0, y: 0, width: 390, height: 600)
            host.view.layoutIfNeeded()
            XCTAssertNotNil(host.view)
        }
    }
}
