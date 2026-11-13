// CompositionLibraryTests — feature 014 T-A01-303 (FR-A01-301–FR-A01-307; SC-A01-301, SC-A01-303, SC-A01-304).
import Foundation
import Testing
import VisualCorePersistence
import VisualCoreSimulation
@testable import GenerativeArtStudioCore

private func dir() -> URL { FileManager.default.temporaryDirectory.appendingPathComponent("gas-lib-\(UUID().uuidString)") }
private let t0 = Date(timeIntervalSince1970: 1_800_000_000)

@Test func roundTripsThroughANewLibraryInstance() throws {
    let d = dir()
    var lib = CompositionLibrary(directory: d)
    var rng = SeededRandom(seed: 314)
    var saved: [LibraryEntry] = []
    for i in 0..<32 {
        let family = FamilyCatalog.all[i % 4]
        var e = CompositionEditor(family: family)
        for def in family.schema.definitions { e.setParameter(def.name, normalized: rng.double()) }
        e.setSeed(i == 0 ? .max : (i == 1 ? 0 : rng.next()))
        saved.append(try lib.save(document: e.composition, name: "Comp \(i)", now: t0.addingTimeInterval(Double(i))))
    }
    var reopened = CompositionLibrary(directory: d)
    reopened.reload()
    #expect(reopened.problems.isEmpty)
    #expect(reopened.entries.count == 32)
    for s in saved { #expect(reopened.entry(s.id) == s, "\(s.name) round trip") }
    #expect(reopened.entries.contains { $0.document.seed == .max })
    #expect(Set(reopened.entries.map(\.document.familyID)).count == 4)
}

@Test func orderingFavoritesThenRecencyThenName() throws {
    var lib = CompositionLibrary(directory: dir())
    let doc = CompositionEditor(family: FamilyCatalog.family(.particles)).composition
    let a = try lib.save(document: doc, name: "b", now: t0)
    let b = try lib.save(document: doc, name: "a", now: t0)
    let c = try lib.save(document: doc, name: "c", now: t0.addingTimeInterval(10))
    #expect(lib.entries.map(\.id) == [c.id, b.id, a.id], "newest first, then name")
    try lib.setFavorite(a.id, true)
    #expect(lib.entries.first?.id == a.id)
    var reopened = CompositionLibrary(directory: lib.store.directory)
    reopened.reload()
    #expect(reopened.entries.map(\.id) == lib.entries.map(\.id))
}

@Test func updateInPlaceDuplicateRenameDelete() throws {
    var lib = CompositionLibrary(directory: dir())
    var editor = CompositionEditor(family: FamilyCatalog.family(.geometricTiling))
    let first = try lib.save(document: editor.composition, name: "  Stars  ", now: t0)
    #expect(first.name == "Stars")
    editor.setParameter("cells", normalized: 1)
    let updated = try lib.save(document: editor.composition, name: "Stars", id: first.id, now: t0.addingTimeInterval(5))
    #expect(updated.id == first.id && updated.createdAt == first.createdAt && updated.modifiedAt > first.modifiedAt)
    #expect(lib.entries.count == 1 && lib.entries[0].document.parameters["cells"] == 24)

    let copy = try lib.duplicate(first.id, now: t0.addingTimeInterval(6))
    #expect(copy.id != first.id && copy.name == "Stars copy" && !copy.favorite)
    #expect(copy.document.id != updated.document.id)
    var changed = copy.document
    changed.parameters["cells"] = 3
    try lib.save(document: changed, name: copy.name, id: copy.id)
    #expect(lib.entry(first.id)?.document.parameters["cells"] == 24, "duplicate is independent")

    try lib.rename(copy.id, to: "   ")
    #expect(lib.entry(copy.id)?.name == "Untitled")
    try lib.rename(copy.id, to: String(repeating: "x", count: 80))
    #expect(lib.entry(copy.id)?.name.count == 60)

    try lib.delete(first.id)
    #expect(lib.entry(first.id) == nil && !lib.store.exists(id: first.id.uuidString))
    // The deleted composition was still open: saving it again recreates the entry.
    let recreated = try lib.save(document: editor.composition, name: "Stars", id: first.id)
    #expect(recreated.id == first.id && lib.store.exists(id: first.id.uuidString))
    #expect(throws: StoreProblem.notFound(id: UUID(uuidString: "00000000-0000-0000-0000-000000000009")!.uuidString)) {
        try lib.rename(UUID(uuidString: "00000000-0000-0000-0000-000000000009")!, to: "x")
    }
}

@Test func badFilesAreReportedNotLost() throws {
    let d = dir()
    var lib = CompositionLibrary(directory: d)
    let doc = CompositionEditor(family: FamilyCatalog.family(.gradientNoise)).composition
    for i in 0..<5 { try lib.save(document: doc, name: "ok \(i)") }
    let corrupt = Data("garbage".utf8)
    let future = Data(#"{"kind":"dev.visualcore.gas.composition","payload":{},"savedAt":"2026-01-01T00:00:00Z","schemaVersion":4}"#.utf8)
    try corrupt.write(to: d.appendingPathComponent("broken.json"))
    try future.write(to: d.appendingPathComponent("future.json"))
    var reopened = CompositionLibrary(directory: d)
    reopened.reload()
    #expect(reopened.entries.count == 5 && reopened.problems.count == 2)
    #expect(try Data(contentsOf: d.appendingPathComponent("broken.json")) == corrupt)
    #expect(try Data(contentsOf: d.appendingPathComponent("future.json")) == future)
    #expect(CompositionLibrary.defaultDirectory().lastPathComponent == "Compositions")
}

@Test func fractionalSecondTimesReloadEqual() throws {
    let d = dir()
    var lib = CompositionLibrary(directory: d)
    let saved = try lib.save(document: CompositionEditor(family: FamilyCatalog.family(.particles)).composition, name: "now",
                             now: Date(timeIntervalSince1970: 1_800_000_000.734))
    var reopened = CompositionLibrary(directory: d)
    reopened.reload()
    #expect(reopened.entry(saved.id) == saved)
}

@Test func editorOpensASavedCompositionWithItsValuesAsBaseline() throws {
    var e = CompositionEditor(family: FamilyCatalog.family(.raymarchedShapes))
    e.setParameter("blend", normalized: 1)
    e.setSeed(42)
    let saved = e.composition
    var reopened = CompositionEditor(family: FamilyCatalog.family(.raymarchedShapes), document: saved)
    #expect(reopened.composition == saved && reopened.presetID == nil)
    reopened.setParameter("blend", normalized: 0)
    reopened.resetAll()
    #expect(reopened.composition.parameters == saved.parameters, "reset returns to the saved values")
    let wrong = CompositionEditor(family: FamilyCatalog.family(.particles), document: saved)
    #expect(wrong.composition.familyID == "particles" && wrong.presetID != nil)
}
