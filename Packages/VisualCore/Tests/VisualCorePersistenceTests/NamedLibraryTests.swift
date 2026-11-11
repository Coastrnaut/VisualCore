// NamedLibraryTests — feature 028 T-A03-302 (FR-A03-302; contract framing-library-bookmarks).
import Foundation
import Testing
@testable import VisualCorePersistence

private struct Spot: Codable, Sendable, Equatable { var x: Double; var label: String }

private func folder() -> URL { FileManager.default.temporaryDirectory.appendingPathComponent("vc-lib-\(UUID().uuidString)") }

private func library(_ dir: URL) -> NamedLibrary<Spot> {
    NamedLibrary(directory: dir, kind: "test.spot", migrations: MigrationChain(currentVersion: 1)) { spot in
        spot.x.isFinite && spot.label != "bad" ? spot : nil
    }
}

private let t0 = Date(timeIntervalSince1970: 1_800_000_000.75)

@Suite struct NamedLibraryTests {
    @Test func saveAndReloadEqual() throws {
        let dir = folder(); defer { try? FileManager.default.removeItem(at: dir) }
        var lib = library(dir)
        let e = try lib.save(Spot(x: 1.5, label: "a"), name: "First", now: t0)
        #expect(e.createdAt == Date(timeIntervalSince1970: 1_800_000_000))
        var again = library(dir); again.reload()
        #expect(again.entries == [e])
        #expect(again.problems.isEmpty)
    }

    @Test func namesAreNormalized() {
        #expect(NamedLibrary<Spot>.normalizedName("   ") == "Untitled")
        #expect(NamedLibrary<Spot>.normalizedName("  Seahorse valley \n") == "Seahorse valley")
        #expect(NamedLibrary<Spot>.normalizedName(String(repeating: "x", count: 80)).count == 60)
    }

    @Test func orderingFavoritesThenRecentThenName() throws {
        let dir = folder(); defer { try? FileManager.default.removeItem(at: dir) }
        var lib = library(dir)
        let old = try lib.save(Spot(x: 0, label: ""), name: "Old", now: t0)
        let b = try lib.save(Spot(x: 0, label: ""), name: "b", now: t0 + 10)
        let a = try lib.save(Spot(x: 0, label: ""), name: "a", now: t0 + 10)
        #expect(lib.entries.map(\.id) == [a.id, b.id, old.id])
        try lib.setFavorite(old.id, true)
        #expect(lib.entries.first?.id == old.id)
        var again = library(dir); again.reload()
        #expect(again.entries.map(\.id) == [old.id, a.id, b.id])
    }

    @Test func renameUpdatesModifiedAndUpdateInPlaceKeepsCreated() throws {
        let dir = folder(); defer { try? FileManager.default.removeItem(at: dir) }
        var lib = library(dir)
        let e = try lib.save(Spot(x: 1, label: ""), name: "One", now: t0)
        try lib.rename(e.id, to: "  Uno ", now: t0 + 60)
        #expect(lib.entry(e.id)?.name == "Uno")
        #expect(lib.entry(e.id)?.modifiedAt == Date(timeIntervalSince1970: 1_800_000_060))
        let updated = try lib.save(Spot(x: 2, label: ""), name: "Uno", id: e.id, now: t0 + 120)
        #expect(updated.createdAt == e.createdAt)
        #expect(lib.entries.count == 1)
        #expect(lib.entry(e.id)?.payload.x == 2)
    }

    @Test func duplicateGetsNewIdentityAndCopyName() throws {
        let dir = folder(); defer { try? FileManager.default.removeItem(at: dir) }
        var lib = library(dir)
        let e = try lib.save(Spot(x: 3, label: "p"), name: "Spiral", now: t0)
        try lib.setFavorite(e.id, true)
        let copy = try lib.duplicate(e.id, now: t0 + 1)
        #expect(copy.id != e.id)
        #expect(copy.name == "Spiral copy")
        #expect(copy.favorite == false)
        #expect(copy.payload == e.payload)
        #expect(throws: StoreProblem.notFound(id: UUID(uuidString: "00000000-0000-0000-0000-000000000000")!.uuidString)) {
            try lib.duplicate(UUID(uuidString: "00000000-0000-0000-0000-000000000000")!)
        }
    }

    @Test func deleteRemovesTheFile() throws {
        let dir = folder(); defer { try? FileManager.default.removeItem(at: dir) }
        var lib = library(dir)
        let e = try lib.save(Spot(x: 1, label: ""), name: "Gone", now: t0)
        try lib.delete(e.id)
        #expect(lib.entries.isEmpty)
        var again = library(dir); again.reload()
        #expect(again.entries.isEmpty)
    }

    @Test func damagedAndNewerFilesAreReportedAndKept() throws {
        let dir = folder(); defer { try? FileManager.default.removeItem(at: dir) }
        var lib = library(dir)
        try lib.save(Spot(x: 1, label: ""), name: "Good", now: t0)
        let damaged = dir.appendingPathComponent("damaged.json")
        try Data("not json".utf8).write(to: damaged)
        let newer = dir.appendingPathComponent("newer.json")
        try Data(#"{"kind":"test.spot","schemaVersion":9,"savedAt":"2027-01-01T00:00:00Z","payload":{}}"#.utf8).write(to: newer)
        lib.reload()
        #expect(lib.entries.count == 1)
        #expect(lib.problems.count == 2)
        #expect(lib.problems.contains(.newerVersion(file: "newer.json", version: 9)))
        #expect(FileManager.default.fileExists(atPath: damaged.path))
        #expect(FileManager.default.fileExists(atPath: newer.path))
    }

    @Test func validationRejectsOnSaveAndOnLoad() throws {
        let dir = folder(); defer { try? FileManager.default.removeItem(at: dir) }
        var lib = library(dir)
        #expect(throws: StoreProblem.self) { try lib.save(Spot(x: .nan, label: ""), name: "Bad", now: t0) }
        #expect(lib.entries.isEmpty)
        // A file that decodes but fails validation (written by a permissive library over the same folder).
        var permissive = NamedLibrary<Spot>(directory: dir, kind: "test.spot", migrations: MigrationChain(currentVersion: 1))
        try permissive.save(Spot(x: 1, label: "bad"), name: "Bad label", now: t0)
        lib.reload()
        #expect(lib.entries.isEmpty)
        #expect(lib.problems.count == 1)
    }
}
