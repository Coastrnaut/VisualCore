// DocumentStoreTests — feature 014 T-A01-301 (FR-A01-305–FR-A01-307, FR-A01-309; SC-A01-304; edge cases).
import Foundation
import Testing
@testable import VisualCorePersistence

private struct Note: Codable, Sendable, Equatable { var title: String; var stars: Int; var created: Date }

private func tempDir() -> URL {
    FileManager.default.temporaryDirectory.appendingPathComponent("vc-store-\(UUID().uuidString)")
}

/// v1 renamed `name` → `title`; v0 files are migrated on load.
private let chain = MigrationChain(currentVersion: 1, steps: [0: { old in
    var new = old
    new["title"] = old["name"]
    new.removeValue(forKey: "name")
    return new
}])

private func store(_ dir: URL) -> DocumentStore<Note> { DocumentStore(directory: dir, kind: "test.note", migrations: chain) }

@Test func roundTripUpdateInPlaceAndDelete() throws {
    let dir = tempDir(), s = store(dir)
    let a = Note(title: "A", stars: 1, created: Date(timeIntervalSince1970: 1_000_000))
    try s.save(a, id: "a")
    #expect(try s.load(id: "a").value == a)
    var b = a; b.stars = 5
    try s.save(b, id: "a")
    #expect(try s.load(id: "a").value.stars == 5)
    #expect(s.load().items.count == 1)
    try s.delete(id: "a")
    #expect(!s.exists(id: "a"))
    #expect(throws: StoreProblem.notFound(id: "a")) { try s.load(id: "a") }
    #expect(throws: StoreProblem.notFound(id: "a")) { try s.delete(id: "a") }
}

@Test func missingDirectoryIsCreatedAndEmpty() throws {
    let dir = tempDir(), s = store(dir)
    #expect(s.load().items.isEmpty && s.load().problems.isEmpty)
    try s.save(Note(title: "x", stars: 0, created: .now), id: "x")
    #expect(FileManager.default.fileExists(atPath: dir.path))
}

@Test func interruptedWriteKeepsTheOldFile() throws {
    let dir = tempDir()
    var s = store(dir)
    try s.save(Note(title: "old", stars: 1, created: .now), id: "n")
    let before = try Data(contentsOf: dir.appendingPathComponent("n.json"))
    struct Crash: Error {}
    s.beforeReplace = { throw Crash() }
    #expect(throws: StoreProblem.self) { try s.save(Note(title: "new", stars: 2, created: .now), id: "n") }
    #expect(try Data(contentsOf: dir.appendingPathComponent("n.json")) == before)
    // A crash that left a temporary file behind: the next load cleans it up and still reads the old version.
    try Data("{partial".utf8).write(to: dir.appendingPathComponent(".n.tmp-ABC"))
    s.beforeReplace = nil
    let report = s.load()
    #expect(report.items.map(\.value.title) == ["old"] && report.problems.isEmpty)
    #expect(!FileManager.default.fileExists(atPath: dir.appendingPathComponent(".n.tmp-ABC").path))
}

@Test func badFilesAreReportedAndLeftUntouched() throws {
    let dir = tempDir(), s = DocumentStore<Note>(directory: dir, kind: "test.note", migrations: chain, maxBytes: 4096)
    for i in 0..<5 { try s.save(Note(title: "good\(i)", stars: i, created: .now), id: "good\(i)") }
    let bad: [String: Data] = [
        "corrupt.json": Data("not json".utf8),
        "future.json": Data(#"{"kind":"test.note","payload":{"title":"z","stars":1,"created":"2026-01-01T00:00:00Z"},"savedAt":"2026-01-01T00:00:00Z","schemaVersion":9}"#.utf8),
        "other.json": Data(#"{"kind":"other.kind","payload":{},"savedAt":"2026-01-01T00:00:00Z","schemaVersion":1}"#.utf8),
        "huge.json": Data(repeating: 32, count: 5000),
        "badpayload.json": Data(#"{"kind":"test.note","payload":{"title":3},"savedAt":"2026-01-01T00:00:00Z","schemaVersion":1}"#.utf8),
    ]
    for (name, data) in bad { try data.write(to: dir.appendingPathComponent(name)) }
    try Data("ignored".utf8).write(to: dir.appendingPathComponent("readme.txt"))
    let report = s.load()
    #expect(report.items.count == 5)
    #expect(report.problems.count == 5)
    #expect(report.problems.contains(.newerVersion(file: "future.json", version: 9)))
    #expect(report.problems.contains(.wrongKind(file: "other.json", found: "other.kind")))
    #expect(report.problems.contains(.tooLarge(file: "huge.json", bytes: 5000)))
    #expect(report.problems.contains { if case .corrupt(file: "corrupt.json", _) = $0 { true } else { false } })
    #expect(report.problems.contains { if case .corrupt(file: "badpayload.json", _) = $0 { true } else { false } })
    for (name, data) in bad { #expect(try Data(contentsOf: dir.appendingPathComponent(name)) == data, "\(name) untouched") }
}

@Test func olderVersionsMigrateOnLoadWithoutRewriting() throws {
    let dir = tempDir(), s = store(dir)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let v0 = Data(#"{"kind":"test.note","payload":{"name":"legacy","stars":3,"created":"2025-05-05T00:00:00Z"},"savedAt":"2025-05-05T00:00:00Z","schemaVersion":0}"#.utf8)
    try v0.write(to: dir.appendingPathComponent("old.json"))
    let item = try s.load(id: "old")
    #expect(item.value.title == "legacy" && item.migratedFrom == 0)
    #expect(try Data(contentsOf: dir.appendingPathComponent("old.json")) == v0, "load does not rewrite")
    try s.save(item.value, id: "old")
    #expect(try s.load(id: "old").migratedFrom == nil, "a later save writes the current version")
    #expect(throws: MigrationError.missingStep(1)) { try MigrationChain(currentVersion: 2).migrate([:], from: 1) }
    #expect(throws: MigrationError.newerVersion(5)) { try chain.migrate([:], from: 5) }
}

@Test func invalidIDsAndOversizeWritesAreRejected() throws {
    let dir = tempDir(), s = DocumentStore<Note>(directory: dir, kind: "test.note", migrations: chain, maxBytes: 64)
    for id in ["", ".hidden", "a/b", "../x", String(repeating: "a", count: 129)] {
        #expect(throws: StoreProblem.invalidID(id)) { try s.save(Note(title: "", stars: 0, created: .now), id: id) }
    }
    #expect(throws: StoreProblem.self) { try s.save(Note(title: String(repeating: "x", count: 200), stars: 0, created: .now), id: "big") }
    #expect(!s.exists(id: "big"))
}
