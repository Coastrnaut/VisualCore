// CrashRecoveryTests — feature 017 T-A01-607 (FR-A01-607, SC-A01-603): stale exports from a killed session are removed
// at launch, an interrupted save leaves the previous version readable, and compositions saved in the release format
// (the committed Core fixture) render exactly like freshly built documents.
import XCTest
import GenerativeArtStudioCore
import VisualCoreTestSupport
@testable import GenerativeArtStudio

@MainActor
final class CrashRecoveryTests: XCTestCase {
    static let fixture = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("Core/Tests/GenerativeArtStudioCoreTests/Fixtures/library-v1", isDirectory: true)

    private func copyFixture() throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("crash-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.copyItem(at: Self.fixture, to: dir)
        return dir
    }

    func testStaleExportsAreRemovedAtLaunchAndSavedWorkIsUntouched() throws {
        let exports = FileManager.default.temporaryDirectory.appendingPathComponent("Exports-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: exports, withIntermediateDirectories: true)
        for name in ["A-1080x1080.png", "B-864x1080.png"] { try Data([1, 2, 3]).write(to: exports.appendingPathComponent(name)) }
        let library = try copyFixture()
        let before = try FileManager.default.contentsOfDirectory(atPath: library.path).sorted()
        XCTAssertEqual(LaunchCleanup.run(exports: exports), 2)
        XCTAssertFalse(FileManager.default.fileExists(atPath: exports.path))
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: library.path).sorted(), before)
        XCTAssertEqual(LaunchCleanup.run(exports: exports), 0, "nothing to clean twice")
        XCTAssertEqual(ExportRunner.directory.lastPathComponent, "Exports", "the real cleanup targets only tmp/Exports")
    }

    func testInterruptedSaveKeepsThePreviousVersion() throws {
        let dir = try copyFixture()
        let files = try FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil).filter { $0.pathExtension == "json" }
        let original = try files.map { try Data(contentsOf: $0) }
        // A save killed after writing its temporary file but before replacing the target.
        let id = files[0].deletingPathExtension().lastPathComponent
        try Data("{\"kind\":\"dev.visualcore.gas.compo".utf8).write(to: dir.appendingPathComponent(".\(id).tmp-killed"))
        var library = CompositionLibrary(directory: dir)
        library.reload()
        XCTAssertEqual(library.entries.count, 4)
        XCTAssertTrue(library.problems.isEmpty, "\(library.problems)")
        XCTAssertEqual(try files.map { try Data(contentsOf: $0) }, original, "previous versions intact")
        let leftovers = try FileManager.default.contentsOfDirectory(atPath: dir.path).filter { $0.contains(".tmp-") }
        XCTAssertEqual(leftovers, [], "the interrupted temporary file is cleaned on load")
    }

    func testFixtureCompositionsRenderLikeFreshDocuments() throws {
        var library = CompositionLibrary(directory: try copyFixture())
        library.reload()
        XCTAssertEqual(library.entries.count, 4)
        for entry in library.entries {
            let family = try XCTUnwrap(entry.document.family)
            let preset = family.presets.last ?? family.defaultPreset
            var fresh = try ArtDocument.from(preset, family: family.id, id: entry.document.id).validated().document
            fresh.previewTime = entry.document.previewTime
            XCTAssertEqual(entry.document, fresh, family.title)
            let a = try ArtRender.pixels(entry.document), b = try ArtRender.pixels(fresh)
            XCTAssertEqual(ImageComparison.compare(a, b).maxAbsolute, 0, "\(family.title) renders identically")
        }
    }
}
