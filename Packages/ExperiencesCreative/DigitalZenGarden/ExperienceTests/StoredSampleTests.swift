// StoredSampleTests — feature 150 (A20-P06) T-A20-605 (FR-A20-604; clarification Q4; contracts/release.md
// "Samples"). The committed sample files under `ExperienceTests/Fixtures` are answered by the code that reads them in
// the app. The fixture garden is two fine strokes, a flat slate and a river pebble on the warm tone (the garden of
// `GardenLibraryTest.document(strokes: 2)` as `GardenDocument` encodes it):
//   - `snapshot-v1.json`: the encoded snapshot (seed 7, step 0, schema 1) whose payload is the fixture garden's
//     `GardenCore.snapshotPayload()` and whose digest is the engine digest of that garden; it restores;
//   - `snapshot-newer.json` (the same payload in an envelope of schema 2) is refused as `snapshot.newer-schema` and
//     `snapshot-damaged.json` (the v1 file cut in half) as `snapshot.corrupt`; neither changes the core;
//   - `garden-current.json` (the envelope `a20.saved-garden` version 1, "Morning Rake", order 1) is listed and opens;
//     `garden-newer.json` (version 2, "Evening Stones", order 2) and `garden-damaged.json` (the current file cut in
//     half) are listed as unreadable with `newer-version` and `damaged`, never opened and never deleted;
//   - `library-current.json` (the envelope `a20.garden-library` version 1 naming `garden-1.json` "Morning Rake" and
//     `garden-2.json` "Evening Stones", next 3) lists two gardens; `library-newer.json` (version 2) makes the library
//     read only (opening still works); `library-damaged.json` (the current index cut in half) is reported `damaged`
//     and is not rewritten by reading (only the next change rebuilds it).
// Each sample is copied into a temporary experience storage (`GardenStoragePlace`, removed afterwards) and read from
// there; afterwards the stored copy and the bundled sample are both byte for byte the sample. No UUID appears in any
// sample. Short runs only (well under 10 s, no sleep, no wall-clock assertion), no prompt, no network.
import Foundation
import Testing
import DigitalZenGardenCore
@testable import DigitalZenGardenExperience
import VisualCoreExperience

/// The bytes of the bundled sample `name` (without extension).
private func sample(_ name: String) throws -> Data {
    let url = try #require(Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures"),
                           "missing Fixtures/\(name).json")
    return try Data(contentsOf: url)
}

@MainActor
@Suite(.serialized) struct StoredSampleTests {
    // MARK: Helpers

    /// Copies each sample of `installs` (sample name → stored file name) into `place`'s storage and returns the bytes
    /// of each sample by stored file name.
    private func install(_ installs: [String: String], in place: GardenStoragePlace) throws -> [String: Data] {
        var stored: [String: Data] = [:]
        for (name, file) in installs {
            let bytes = try sample(name)
            try place.storage.write(bytes, to: file)
            #expect(try place.storage.read(file) == bytes, "\(name): the stored copy is the sample")
            stored[file] = bytes
        }
        return stored
    }

    /// Expects every stored file of `stored` and each bundled sample of `installs` to be byte for byte as installed,
    /// and the storage to hold exactly those files.
    private func expectUnchanged(_ stored: [String: Data], _ installs: [String: String],
                                 in place: GardenStoragePlace, sourceLocation: SourceLocation = #_sourceLocation) throws {
        for (file, bytes) in stored {
            #expect(try place.storage.read(file) == bytes, "\(file): stays byte-identical",
                    sourceLocation: sourceLocation)
        }
        for (name, file) in installs {
            #expect(try sample(name) == stored[file], "\(name): the bundled sample stays byte-identical",
                    sourceLocation: sourceLocation)
        }
        #expect(Set(place.storage.list()) == Set(stored.keys), "no file is added or removed",
                sourceLocation: sourceLocation)
    }

    // MARK: Snapshots

    @Test func theSchemaOneSnapshotSampleRestores() async throws {
        let place = try GardenStoragePlace("sample-snapshot-v1")
        defer { place.remove() }
        let installs = ["snapshot-v1": "snapshot-v1.json"]
        let stored = try install(installs, in: place)
        let bytes = try place.storage.read("snapshot-v1.json")
        let snapshot = try ExperienceSnapshot(data: bytes)
        #expect(snapshot.experience == GardenTest.id)
        #expect(snapshot.schemaVersion == 1 && snapshot.seed == 7 && snapshot.stepIndex == 0)
        #expect(try snapshot.encoded() == bytes, "the sample is in the encoded form")

        var engine = try await GardenTest.engine(seed: snapshot.seed)
        try engine.restore(snapshot)
        let core = try #require(engine.core)
        #expect(try engine.digest() == snapshot.digest, "the digest of the restored garden is the sample's")
        let garden = core.document
        #expect(garden.strokes.map(\.rake) == ["fine-rake", "fine-rake"])
        #expect(garden.stones.map(\.kind) == ["flat-slate", "river-pebble"])
        #expect(garden.tone == "warm" && garden.nextStoneID == 3)
        #expect(try core.snapshotPayload() == Data(snapshot.payload.utf8), "written back as the same payload")
        try expectUnchanged(stored, installs, in: place)
    }

    @Test func theNewerSnapshotSampleIsRefusedAndChangesNothing() async throws {
        let place = try GardenStoragePlace("sample-snapshot-newer")
        defer { place.remove() }
        let installs = ["snapshot-newer": "snapshot-newer.json"]
        let stored = try install(installs, in: place)
        let snapshot = try ExperienceSnapshot(data: try place.storage.read("snapshot-newer.json"))
        #expect(snapshot.schemaVersion == 2)
        var engine = try await GardenTest.engine(seed: 7)
        let before = try #require(engine.core)
        let digest = try engine.digest()
        var refusal: ExperienceError?
        do {
            try engine.restore(snapshot)
        } catch {
            refusal = error
        }
        #expect(refusal == .snapshot(.newerSchema(found: 2, current: 1)), "the newer sample is refused")
        #expect(SnapshotError.newerSchema(found: 2, current: 1).code == "snapshot.newer-schema")
        #expect(engine.core == before, "a refused restore changes nothing")
        #expect(try engine.digest() == digest)
        try expectUnchanged(stored, installs, in: place)
    }

    @Test func theDamagedSnapshotSampleIsRefused() throws {
        let place = try GardenStoragePlace("sample-snapshot-damaged")
        defer { place.remove() }
        let installs = ["snapshot-damaged": "snapshot-damaged.json"]
        let stored = try install(installs, in: place)
        let bytes = try place.storage.read("snapshot-damaged.json")
        var refusal: SnapshotError?
        do {
            _ = try ExperienceSnapshot(data: bytes)
        } catch {
            refusal = error
        }
        let refused = try #require(refusal, "the damaged sample is refused before any restore")
        #expect(refused.code == "snapshot.corrupt")
        try expectUnchanged(stored, installs, in: place)
    }

    // MARK: Garden files

    @Test func theCurrentGardenSampleIsListedAndOpens() throws {
        let place = try GardenStoragePlace("sample-garden-current")
        defer { place.remove() }
        let installs = ["garden-current": GardenLibrary.fileName(1)]
        let stored = try install(installs, in: place)
        let library = GardenLibrary(storage: place.storage)
        #expect(library.indexProblem == nil && !library.isReadOnly)
        #expect(library.entries == [GardenLibraryEntry(file: "garden-1.json", name: "Morning Rake", order: 1,
                                                       refusal: nil)])
        let opened = library.open("garden-1.json")
        let document = try opened.get().document
        #expect(document.strokes.count == 2 && document.stones.count == 2 && document.tone == "warm")
        #expect(try GardenLibrary.encode(GardenLibrary.SavedGarden(name: "Morning Rake", order: 1,
                                                                    document: document))
                == stored["garden-1.json"], "the opened garden encodes to the sample")
        try expectUnchanged(stored, installs, in: place)
    }

    @Test func theNewerAndDamagedGardenSamplesAreListedUnreadable() throws {
        let cases: [(String, String)] = [("garden-newer", "newer-version"), ("garden-damaged", "damaged")]
        for (name, code) in cases {
            let place = try GardenStoragePlace("sample-" + name)
            defer { place.remove() }
            let installs = [name: GardenLibrary.fileName(1)]
            let stored = try install(installs, in: place)
            let library = GardenLibrary(storage: place.storage)
            #expect(library.entries == [GardenLibraryEntry(file: "garden-1.json", name: "garden-1.json", order: 0,
                                                           refusal: code)], "\(name)")
            #expect(library.readable.isEmpty, "\(name)")
            let opened = library.open("garden-1.json")
            #expect(opened.map { $0.entry } == .failure(.unreadable(code)), "\(name): never opened")
            library.reload()
            #expect(library.entries.first?.refusal == code, "\(name): listed again on a second read")
            try expectUnchanged(stored, installs, in: place)
        }
    }

    // MARK: Index files

    @Test func theCurrentIndexSampleListsTwoGardens() throws {
        let place = try GardenStoragePlace("sample-library-current")
        defer { place.remove() }
        let installs = ["library-current": GardenLibrary.indexFile, "garden-current": GardenLibrary.fileName(1),
                        "garden-newer": GardenLibrary.fileName(2)]
        let stored = try install(installs, in: place)
        let index = try GardenLibrary.decodeIndex(try #require(stored[GardenLibrary.indexFile])).get()
        #expect(index.next == 3)
        #expect(index.entries.map(\.file) == ["garden-1.json", "garden-2.json"])
        #expect(index.entries.map(\.name) == ["Morning Rake", "Evening Stones"])
        let library = GardenLibrary(storage: place.storage)
        #expect(library.indexProblem == nil && !library.isReadOnly)
        #expect(library.next == 3)
        // The readable garden by its file, the unreadable one by the name the index remembers.
        #expect(library.entries == [
            GardenLibraryEntry(file: "garden-1.json", name: "Morning Rake", order: 1, refusal: nil),
            GardenLibraryEntry(file: "garden-2.json", name: "Evening Stones", order: 0, refusal: "newer-version")])
        try expectUnchanged(stored, installs, in: place)
    }

    @Test func theNewerIndexSampleMakesTheLibraryReadOnly() throws {
        let place = try GardenStoragePlace("sample-library-newer")
        defer { place.remove() }
        let installs = ["library-newer": GardenLibrary.indexFile, "garden-current": GardenLibrary.fileName(1)]
        let stored = try install(installs, in: place)
        let library = GardenLibrary(storage: place.storage)
        #expect(library.isReadOnly, "a newer index makes the library read only")
        #expect(library.indexProblem == "newer-version")
        #expect(library.readable.map(\.name) == ["Morning Rake"])
        let opened = library.open("garden-1.json")
        #expect(opened.map { $0.entry.name } == .success("Morning Rake"), "opening still works")
        let document = try opened.get().document
        let saved = library.save(name: "Another", document: document)
        #expect(saved == .failure(.readOnly), "a change is refused")
        let renamed = library.rename("garden-1.json", to: "Renamed")
        #expect(renamed == .failure(.readOnly))
        let deleted = library.delete("garden-1.json")
        #expect(deleted == .failure(.readOnly))
        try expectUnchanged(stored, installs, in: place)
    }

    @Test func theDamagedIndexSampleIsNotRewrittenByReading() throws {
        let place = try GardenStoragePlace("sample-library-damaged")
        defer { place.remove() }
        let installs = ["library-damaged": GardenLibrary.indexFile, "garden-current": GardenLibrary.fileName(1)]
        let stored = try install(installs, in: place)
        let library = GardenLibrary(storage: place.storage)
        #expect(library.indexProblem == "damaged")
        #expect(!library.isReadOnly, "a damaged index does not make the library read only")
        #expect(library.readable.map(\.name) == ["Morning Rake"], "the garden files are the truth")
        #expect(library.next == 2, "the counter is recovered from the files")
        library.reload()
        let opened = library.open("garden-1.json")
        #expect(opened.map { $0.entry.name } == .success("Morning Rake"))
        let again = GardenLibrary(storage: place.storage)
        #expect(again.indexProblem == "damaged", "reading leaves the damaged index as it is")
        try expectUnchanged(stored, installs, in: place)
    }
}
