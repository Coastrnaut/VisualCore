// LibraryMigrationFixtureTests — feature 017 T-A01-607 (FR-A01-607, SC-A01-603): compositions saved in the release
// format (schema v1) by CompositionLibrary open unchanged in later builds. The fixture is committed; it is (re)written
// only when GAS_WRITE_FIXTURE=1, through the same library code users run.
import Foundation
import Testing
@testable import GenerativeArtStudioCore

enum LibraryFixture {
    static let directory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        .appendingPathComponent("Fixtures/library-v1", isDirectory: true)
    static let savedAt = Date(timeIntervalSince1970: 1_794_355_200)   // 2026-11-11 00:00:00 UTC

    /// One composition per family, with fixed ids, names and values.
    static var expected: [(id: UUID, name: String, document: ArtDocument)] {
        SceneFamilyID.allCases.enumerated().map { index, family in
            let f = FamilyCatalog.family(family)
            let preset = f.presets.last ?? f.defaultPreset
            let id = UUID(uuidString: String(format: "00000000-0000-4000-8000-%012d", index + 1))!
            var doc = (try? ArtDocument.from(preset, family: family, id: id).validated().document)!
            doc.previewTime = Double(index) * 7.5
            return (id, "Fixture \(f.title)", doc)
        }
    }
}

@Test func fixtureLoadsUnchanged() throws {
    if ProcessInfo.processInfo.environment["GAS_WRITE_FIXTURE"] == "1" {
        try? FileManager.default.removeItem(at: LibraryFixture.directory)
        var writer = CompositionLibrary(directory: LibraryFixture.directory)
        for item in LibraryFixture.expected {
            _ = try writer.save(document: item.document, name: item.name, id: item.id, now: LibraryFixture.savedAt)
        }
    }
    let files = try FileManager.default.contentsOfDirectory(at: LibraryFixture.directory, includingPropertiesForKeys: nil)
        .filter { $0.pathExtension == "json" }
    #expect(files.count == 4)
    let before = try files.map { try Data(contentsOf: $0) }
    var library = CompositionLibrary(directory: LibraryFixture.directory)
    library.reload()
    #expect(library.problems.isEmpty)
    #expect(library.entries.count == 4)
    for item in LibraryFixture.expected {
        let entry = try #require(library.entry(item.id))
        #expect(entry.name == item.name)
        #expect(entry.document == item.document, "\(item.name)")
        #expect(entry.createdAt == LibraryFixture.savedAt)
    }
    #expect(Set(library.entries.map(\.document.familyID)).count == 4, "one per family")
    let after = try files.map { try Data(contentsOf: $0) }
    #expect(before == after, "loading never rewrites the files")
    let text = try String(contentsOf: files[0], encoding: .utf8)
    #expect(text.contains("\"kind\" : \"dev.visualcore.gas.composition\"") || text.contains("\"kind\":\"dev.visualcore.gas.composition\""))
    #expect(text.contains("\"schemaVersion\""))
}
