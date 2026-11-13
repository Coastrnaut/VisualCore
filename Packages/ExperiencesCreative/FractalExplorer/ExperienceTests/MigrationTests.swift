// MigrationTests — feature 031 T-A03-605 (FR-A03-603, SC-A03-603; US3 AC1; spec 031 clarification 3): bookmarks of
// schema 1 stay loadable. The committed fixture `Tests/Fixtures/bookmark-v1.json` was written once by this build
// (FE_WRITE_FIXTURE=1, only when absent) and is never edited; a schema change adds a migration and a new fixture.
import FractalExplorerCore
import VisualCoreMath
import VisualCorePersistence
import XCTest
@testable import FractalExplorerExperience

@MainActor
final class MigrationTests: XCTestCase {
    static let fixtureID = UUID(uuidString: "5E1A4C0D-0000-4000-8000-0000000000F1")!
    // Moved with the tests (feature 193): ExperienceTests/Fixtures/bookmark-v1.json, bit-identical.
    static let fixtureURL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .appendingPathComponent("Fixtures/bookmark-v1.json")

    /// The bookmark the fixture holds.
    static var expected: Bookmark {
        Bookmark(mode: .julia, framing: PlaneFraming(center: Vec2(0.125, -0.25), span: 0.75), juliaSeed: Vec2(0.285, 0.01),
                 iterationCap: 750, escapeRadius: 2, paletteID: "ocean",
                 precision: PrecisionMode(mantissaBits: 23, level: .reliable))
    }

    private func folder() -> URL { FileManager.default.temporaryDirectory.appendingPathComponent("fe-migration-\(UUID().uuidString)") }

    func testWriteFixtureOnceWhenRequested() throws {
        guard ProcessInfo.processInfo.environment["FE_WRITE_FIXTURE"] == "1" else { return }
        guard !FileManager.default.fileExists(atPath: Self.fixtureURL.path) else { return }   // never overwrite
        let dir = folder()
        defer { try? FileManager.default.removeItem(at: dir) }
        var lib = BookmarkLibrary.bookmarks(directory: dir)
        try lib.save(Self.expected, name: "Golden v1", id: Self.fixtureID, now: Date(timeIntervalSince1970: 1_793_000_000))
        try FileManager.default.copyItem(at: dir.appendingPathComponent(Self.fixtureID.uuidString + ".json"), to: Self.fixtureURL)
        print("FIXTURE written to \(Self.fixtureURL.path)")
    }

    func testVersionOneFixtureLoadsWithEveryField() throws {
        let dir = folder()
        defer { try? FileManager.default.removeItem(at: dir) }
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try FileManager.default.copyItem(at: Self.fixtureURL, to: dir.appendingPathComponent(Self.fixtureID.uuidString + ".json"))
        let text = try String(contentsOf: Self.fixtureURL, encoding: .utf8)
        XCTAssertTrue(text.contains("\"schemaVersion\" : 1") || text.contains("\"schemaVersion\":1"), "the fixture is schema 1")
        var lib = BookmarkLibrary.bookmarks(directory: dir)
        lib.reload()
        XCTAssertEqual(lib.problems, [])
        let entry = try XCTUnwrap(lib.entry(Self.fixtureID))
        XCTAssertEqual(entry.name, "Golden v1")
        XCTAssertEqual(entry.payload, Self.expected)
        XCTAssertEqual(entry.createdAt, Date(timeIntervalSince1970: 1_793_000_000))
    }

    func testNewerSchemaIsReportedAndLeftUntouched() throws {
        let dir = folder()
        defer { try? FileManager.default.removeItem(at: dir) }
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let fixture = try String(contentsOf: Self.fixtureURL, encoding: .utf8)
        let newer = fixture.replacingOccurrences(of: "\"schemaVersion\" : 1", with: "\"schemaVersion\" : 2")
            .replacingOccurrences(of: "\"schemaVersion\":1", with: "\"schemaVersion\":2")
        let url = dir.appendingPathComponent("future.json")
        try newer.write(to: url, atomically: true, encoding: .utf8)
        var lib = BookmarkLibrary.bookmarks(directory: dir)
        lib.reload()
        XCTAssertTrue(lib.entries.isEmpty)
        XCTAssertEqual(lib.problems, [.newerVersion(file: "future.json", version: 2)])
        XCTAssertEqual(try String(contentsOf: url, encoding: .utf8), newer, "left untouched")
    }
}
