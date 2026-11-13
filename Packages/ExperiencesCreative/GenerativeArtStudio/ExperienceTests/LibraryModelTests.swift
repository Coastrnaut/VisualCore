// LibraryModelTests — feature 014 T-A01-308 (edge case "write failure"; FR-A01-305): the app model reports save
// failures and unreadable files.
import XCTest
import GenerativeArtStudioCore
@testable import GenerativeArtStudioExperience

@MainActor
final class LibraryModelTests: XCTestCase {
    func testFailedSaveSetsErrorAndKeepsEntries() throws {
        // A regular file where the library folder should be: directory creation and writes fail.
        let blocker = FileManager.default.temporaryDirectory.appendingPathComponent("gas-blocker-\(UUID().uuidString)")
        try Data("x".utf8).write(to: blocker)
        let model = LibraryModel(directory: blocker)
        let doc = CompositionEditor(family: FamilyCatalog.family(.gradientNoise)).composition
        XCTAssertNil(model.save(doc, name: "Will fail", id: nil))
        XCTAssertNotNil(model.errorMessage)
        XCTAssertTrue(model.entries.isEmpty)
    }

    func testUnreadableFilesAreCountedForTheBanner() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("gas-model-\(UUID().uuidString)")
        let model = LibraryModel(directory: dir)
        let doc = CompositionEditor(family: FamilyCatalog.family(.particles)).composition
        XCTAssertNotNil(model.save(doc, name: "Good", id: nil))
        try Data("bad".utf8).write(to: dir.appendingPathComponent("a.json"))
        try Data(#"{"kind":"dev.visualcore.gas.composition","payload":{},"savedAt":"2026-01-01T00:00:00Z","schemaVersion":3}"#.utf8)
            .write(to: dir.appendingPathComponent("b.json"))
        model.reload()
        XCTAssertEqual(model.entries.count, 1)
        XCTAssertEqual(model.problemCount, 2)
    }
}
