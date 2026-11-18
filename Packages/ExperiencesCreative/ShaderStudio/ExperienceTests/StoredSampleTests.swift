// StoredSampleTests — feature 164 (A22-P06) T-A22-605 (FR-A22-604; clarification Q4; data-model.md "Samples"). The
// committed sample files under `ExperienceTests/Fixtures` are answered by the code that reads them in the app. They
// were written once through the real encoders (`StudioCore.snapshotPayload()` in an `ExperienceSnapshot` with its
// engine digest and `encoded()`, `ProjectLibrary.encode(name:order:project:values:textures:)` and
// `ProjectLibrary.encode(_:)`):
//   - `snapshot-v1.json`: the snapshot (seed 7, step 0, schema 1) of Texture mix with the blend at 0.75, the textures
//     noise and checker, 2 runs, 1 reset and the shape [1, 2]; it restores;
//   - `snapshot-p02.json`: an A22-P02 payload without `textures`, `resets` and `shape` (Rings, values 0.25 and 0.5,
//     1 run); it restores with the default textures [0, 1], 0 resets and the template's shape;
//   - `snapshot-newer.json` (the v1 payload in an envelope of schema 2) is refused as `snapshot.newer-schema` and
//     `snapshot-damaged.json` (the v1 file cut in half) as `snapshot.corrupt`; neither changes the core;
//   - `project-current.json`: "Sample waves" (the Gradient project, order 1, values 0.5 and the textures noise and
//     checker); it lists and opens; `project-newer.json` (the same body, version 2) and `project-damaged.json` (cut in
//     half) are listed as unreadable with `newer-version` and `damaged`, and refused on open;
//   - `library-current.json`: the index of "Sample waves" in `project-1.json`, next 2; `library-newer.json` (version 2)
//     makes the library read only (opening still works); `library-damaged.json` (cut in half) is reported as
//     `damaged` while the project is still listed from its file, and reading does not rewrite it.
// Samples are copied into a temporary experience storage (`StudioStoragePlace`, removed afterwards): snapshots under
// their own names, projects as `project-<n>.json` (the only names the library lists) and indices as `library.json`;
// afterwards every stored copy and every bundled sample is byte for byte the sample and no file is added. No UUID and
// no path appears in any sample. Short runs only (well under 10 s, no sleep, no wall-clock assertion), no prompt, no
// network.
import Foundation
import Testing
import ShaderStudioCore
@testable import ShaderStudioExperience
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

    /// Copies each sample (`sample name`, `stored file`) of `samples` into `storage` and returns the stored files with
    /// their bytes.
    private func install(_ samples: [(String, String)], in storage: ExperienceStorage) throws -> [String: Data] {
        var files: [String: Data] = [:]
        for (name, file) in samples {
            let bytes = try sample(name)
            try storage.write(bytes, to: file)
            #expect(try storage.read(file) == bytes, "\(name): the stored copy is the sample")
            files[file] = bytes
        }
        return files
    }

    /// Expects the storage to hold exactly `files`, byte for byte, and each bundled sample of `samples` to be
    /// unchanged.
    private func expectUnchanged(_ files: [String: Data], _ samples: [(String, String)], in place: StudioStoragePlace,
                                 sourceLocation: SourceLocation = #_sourceLocation) throws {
        #expect(try place.contents() == files, "every stored file stays byte-identical, none is added",
                sourceLocation: sourceLocation)
        for (name, file) in samples {
            #expect(try sample(name) == files[file], "\(name): the bundled sample stays byte-identical",
                    sourceLocation: sourceLocation)
        }
    }

    /// The values of the project sample: 0.5, then 15 zeros.
    private static let projectValues: [Double] = [0.5] + [Double](repeating: 0, count: 15)

    // MARK: Snapshots

    @Test func theCurrentSnapshotSampleRestoresWithEveryField() async throws {
        let place = try StudioStoragePlace("sample-snapshot-v1")
        defer { place.remove() }
        let samples = [("snapshot-v1", "snapshot-v1.json")]
        let files = try install(samples, in: place.storage)
        let bytes = try place.storage.read("snapshot-v1.json")
        let snapshot = try ExperienceSnapshot(data: bytes)
        #expect(snapshot.experience == StudioTest.id)
        #expect(snapshot.schemaVersion == 1 && snapshot.seed == 7 && snapshot.stepIndex == 0)
        #expect(try snapshot.encoded() == bytes, "the sample is in the encoded form")

        var engine = try await StudioTest.engine(seed: snapshot.seed)
        try engine.restore(snapshot)
        let core = try #require(engine.core)
        #expect(try engine.digest() == snapshot.digest, "the digest of the restored state is the sample's")
        #expect(try studioDigest(core) == snapshot.digest.hex)
        #expect(core.template == 3 && core.selectedTemplate?.id == "texture-mix")
        #expect(core.values == [0.75] + [Double](repeating: 0, count: 15))
        #expect(core.textures == [TextureRecipe.noise.rawValue, TextureRecipe.checker.rawValue])
        #expect(core.runs == 2 && core.resets == 1 && core.shape == [1, 2])
        #expect(try core.snapshotPayload() == Data(snapshot.payload.utf8), "written back as the same payload")
        try expectUnchanged(files, samples, in: place)
    }

    @Test func theP02SnapshotSampleRestoresWithTheDefaults() async throws {
        let place = try StudioStoragePlace("sample-snapshot-p02")
        defer { place.remove() }
        let samples = [("snapshot-p02", "snapshot-p02.json")]
        let files = try install(samples, in: place.storage)
        let snapshot = try ExperienceSnapshot(data: try place.storage.read("snapshot-p02.json"))
        #expect(snapshot.schemaVersion == 1)
        #expect(!snapshot.payload.contains("textures") && !snapshot.payload.contains("resets")
                && !snapshot.payload.contains("shape"), "the sample has none of the optional fields")

        var engine = try await StudioTest.engine(seed: snapshot.seed)
        try engine.restore(snapshot)
        let core = try #require(engine.core)
        #expect(try engine.digest() == snapshot.digest)
        #expect(core.template == 2 && core.selectedTemplate?.id == "rings")
        #expect(core.values == [0.25, 0.5] + [Double](repeating: 0, count: 14) && core.runs == 1)
        #expect(core.textures == [0, 1] && core.textures == StudioCore.defaultTextures, "the default textures")
        #expect(core.resets == 0, "no reset")
        #expect(core.shape == StudioCore.templateShape(2) && core.shape == [2, 0], "the template's shape")
        try expectUnchanged(files, samples, in: place)
    }

    @Test func theNewerSnapshotSampleIsRefusedAndChangesNothing() async throws {
        let place = try StudioStoragePlace("sample-snapshot-newer")
        defer { place.remove() }
        let samples = [("snapshot-newer", "snapshot-newer.json")]
        let files = try install(samples, in: place.storage)
        let snapshot = try ExperienceSnapshot(data: try place.storage.read("snapshot-newer.json"))
        #expect(snapshot.schemaVersion == 2)
        var engine = try await StudioTest.engine(seed: 7)
        let before = try #require(engine.core)
        let digest = try engine.digest()
        var refusal: ExperienceError?
        do {
            try engine.restore(snapshot)
        } catch {
            refusal = error
        }
        #expect(refusal == .snapshot(.newerSchema(found: 2, current: 1)), "the newer sample is refused")
        #expect(refusal?.code == "snapshot.newer-schema")
        #expect(engine.core == before, "a refused restore changes nothing")
        #expect(try engine.digest() == digest)
        try expectUnchanged(files, samples, in: place)
    }

    @Test func theDamagedSnapshotSampleIsRefused() throws {
        let place = try StudioStoragePlace("sample-snapshot-damaged")
        defer { place.remove() }
        let samples = [("snapshot-damaged", "snapshot-damaged.json")]
        let files = try install(samples, in: place.storage)
        let bytes = try place.storage.read("snapshot-damaged.json")
        var refusal: SnapshotError?
        do {
            _ = try ExperienceSnapshot(data: bytes)
        } catch {
            refusal = error
        }
        let refused = try #require(refusal, "the damaged sample is refused before any restore")
        #expect(refused.code == "snapshot.corrupt")
        try expectUnchanged(files, samples, in: place)
    }

    // MARK: Projects

    @Test func theCurrentProjectSampleListsAndOpens() throws {
        let place = try StudioStoragePlace("sample-project-current")
        defer { place.remove() }
        let samples = [("project-current", "project-1.json"), ("library-current", ProjectLibrary.indexFile)]
        let files = try install(samples, in: place.storage)
        let library = ProjectLibrary(storage: place.storage)
        #expect(!library.isReadOnly && library.indexProblem == nil && library.next == 2)
        #expect(library.entries == [ProjectLibraryEntry(file: "project-1.json", name: "Sample waves", order: 1,
                                                        refusal: nil)])
        guard case .success(let opened) = library.open("project-1.json") else {
            Issue.record("the current project sample does not open")
            return
        }
        let gradient = try StudioLibraryTest.project()
        #expect(opened.project == gradient && opened.project.source == gradient.source)
        #expect(opened.values == Self.projectValues)
        #expect(opened.textures == [TextureRecipe.noise.rawValue, TextureRecipe.checker.rawValue])
        let encoded = try ProjectLibrary.encode(name: "Sample waves", order: 1, project: opened.project,
                                                values: opened.values, textures: opened.textures)
        #expect(encoded == files["project-1.json"], "the sample is in the encoded form")
        try expectUnchanged(files, samples, in: place)
    }

    @Test func theNewerAndDamagedProjectSamplesAreListedAsUnreadable() throws {
        let place = try StudioStoragePlace("sample-project-unreadable")
        defer { place.remove() }
        let samples = [("project-current", "project-1.json"), ("project-newer", "project-2.json"),
                       ("project-damaged", "project-3.json"), ("library-current", ProjectLibrary.indexFile)]
        let files = try install(samples, in: place.storage)
        if case .failure(let refusal) = ProjectLibrary.decode(try sample("project-newer")) {
            #expect(refusal.code == "newer-version")
        } else {
            Issue.record("project-newer decodes")
        }
        if case .failure(let refusal) = ProjectLibrary.decode(try sample("project-damaged")) {
            #expect(refusal.code == "damaged")
        } else {
            Issue.record("project-damaged decodes")
        }
        let library = ProjectLibrary(storage: place.storage)
        #expect(library.entries.map(\.file) == ["project-1.json", "project-2.json", "project-3.json"])
        #expect(library.entries.map(\.refusal) == [nil, "newer-version", "damaged"], "listed with their codes")
        #expect(library.entries.map(\.name) == ["Sample waves", "project-2.json", "project-3.json"])
        #expect(library.readable.count == 1 && library.next == 4)
        #expect(StudioLibraryTest.failure(library.open("project-2.json")) == .unreadable("newer-version"))
        #expect(StudioLibraryTest.failure(library.open("project-3.json")) == .unreadable("damaged"))
        #expect(StudioLibraryTest.failure(library.open("project-1.json")) == nil, "the readable one still opens")
        try expectUnchanged(files, samples, in: place)
    }

    // MARK: Index

    @Test func theNewerIndexSampleMakesTheLibraryReadOnly() throws {
        let place = try StudioStoragePlace("sample-library-newer")
        defer { place.remove() }
        let samples = [("project-current", "project-1.json"), ("library-newer", ProjectLibrary.indexFile)]
        let files = try install(samples, in: place.storage)
        if case .failure(let refusal) = ProjectLibrary.decodeIndex(try sample("library-newer")) {
            #expect(refusal.code == "newer-version")
        } else {
            Issue.record("library-newer decodes")
        }
        let library = ProjectLibrary(storage: place.storage)
        #expect(library.isReadOnly && library.indexProblem == "newer-version", "the library is read only")
        #expect(library.entries.map(\.name) == ["Sample waves"], "the project is listed from its file")
        #expect(StudioLibraryTest.failure(library.open("project-1.json")) == nil, "opening still works")
        #expect(StudioLibraryTest.failure(try StudioLibraryTest.save(library, "Sample tide")) == .readOnly)
        #expect(StudioLibraryTest.failure(library.rename("project-1.json", to: "Sample tide")) == .readOnly)
        #expect(StudioLibraryTest.failure(library.remove("project-1.json")) == .readOnly)
        try expectUnchanged(files, samples, in: place)
    }

    @Test func theDamagedIndexSampleStillListsTheProjectAndIsNotRewrittenByReading() throws {
        let place = try StudioStoragePlace("sample-library-damaged")
        defer { place.remove() }
        let samples = [("project-current", "project-1.json"), ("library-damaged", ProjectLibrary.indexFile)]
        let files = try install(samples, in: place.storage)
        if case .failure(let refusal) = ProjectLibrary.decodeIndex(try sample("library-damaged")) {
            #expect(refusal.code == "damaged")
        } else {
            Issue.record("library-damaged decodes")
        }
        let library = ProjectLibrary(storage: place.storage)
        #expect(library.indexProblem == "damaged" && !library.isReadOnly)
        #expect(library.entries == [ProjectLibraryEntry(file: "project-1.json", name: "Sample waves", order: 1,
                                                        refusal: nil)], "listed from the project's file")
        #expect(library.next == 2, "the counter is recovered from the files")
        #expect(StudioLibraryTest.failure(library.open("project-1.json")) == nil)
        library.reload()
        #expect(try place.storage.read(ProjectLibrary.indexFile) == files[ProjectLibrary.indexFile],
                "reading does not rewrite the index")
        try expectUnchanged(files, samples, in: place)
    }

    @Test func theCurrentIndexSampleIsInTheEncodedForm() throws {
        let bytes = try sample("library-current")
        guard case .success(let index) = ProjectLibrary.decodeIndex(bytes) else {
            Issue.record("library-current does not decode")
            return
        }
        #expect(index == ProjectLibrary.Index(next: 2, entries: [
            ProjectLibrary.Index.Item(file: "project-1.json", name: "Sample waves", order: 1)]))
        #expect(try ProjectLibrary.encode(index) == bytes)
        #expect(try sample("library-current") == bytes, "the bundled sample stays byte-identical")
    }
}
