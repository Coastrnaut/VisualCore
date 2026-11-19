// ReleaseSampleTests — feature 171 (A23-P06) T-A23-605 (FR-A23-604; data-model.md "Samples"). The committed release
// samples under `ExperienceTests/Fixtures` are answered by the code that reads them in the app. They were written once
// through the real encoders (`ExperienceEngine.snapshot()` of `LabCore` and `ExperienceSnapshot.encoded()`,
// `GraphLibrary.encode(name:order:graph:)` and `GraphLibrary.encode(_:)`):
//   - `snapshot-v1.json`: the snapshot (seed 7, step 0, schema 1) of the starter graph with a Gradient (node 3, at
//     40, 300) added and selected; it restores; `snapshot-newer.json` (the v1 payload in an envelope of schema 2) is
//     refused as `snapshot.newer-schema` and `snapshot-damaged.json` (the v1 file cut in half) as `snapshot.corrupt`;
//     neither changes the core;
//   - `graph-newer.json` ("Sample ramp", order 2, the Gradient-into-Output graph, envelope version 2) and
//     `graph-damaged.json` (the version 1 file cut in half) are listed as unreadable with `newer-version` and
//     `damaged`, beside the current `graph-sample.json` (A23-P04), and refused on open;
//   - `library-current.json`: the index of "Sample clouds" in `graph-1.json`, next 2; it lists;
//     `library-newer.json` (version 2) makes the library read only (opening still works); `library-damaged.json` (cut
//     in half) is reported as `damaged` while the graph is still listed from its file, and reading does not rewrite
//     it.
// An oversized saved graph (81,921 bytes, written by the test into its temporary storage, never committed) is listed
// as unreadable `too-large` and kept. Samples are copied into a temporary experience storage (`LabStoragePlace`,
// removed afterwards): snapshots under their own names, graphs as `graph-<n>.json` (the only names the library lists)
// and indices as `library.json`; afterwards every stored copy and every bundled sample is byte for byte the sample and
// no file is added. No UUID and no path appears in any sample. Short runs only (well under 10 s, no sleep, no
// wall-clock assertion), no prompt, no network.
import Foundation
import Testing
import VisualCoreExperience
@testable import VisualProgrammingLabExperience
import VisualProgrammingLabCore

/// The bytes of the bundled sample `name` (without extension).
private func releaseSample(_ name: String) throws -> Data {
    let url = try #require(Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures"),
                           "missing Fixtures/\(name).json")
    return try Data(contentsOf: url)
}

/// The release samples of A23-P06: snapshots, saved graphs and indices, current, newer and damaged.
@MainActor
@Suite(.serialized) struct ReleaseSampleTests {
    // MARK: Helpers

    /// Every sample this suite reads, without extension.
    static let names = ["snapshot-v1", "snapshot-newer", "snapshot-damaged", "graph-sample", "graph-newer",
                        "graph-damaged", "library-current", "library-newer", "library-damaged"]

    /// The graph of `snapshot-v1.json`: the starter graph with a Gradient (node 3) at (40, 300).
    static var snapshotGraph: VisualGraph {
        var graph = LabCore.starterGraph
        graph.nodes.append(GraphNode(id: NodeID(3), kind: .gradient, position: CanvasPoint(x: 40, y: 300)))
        return graph
    }

    /// Copies each sample (`sample name`, `stored file`) of `samples` into `storage` and returns the stored files with
    /// their bytes.
    private func install(_ samples: [(String, String)], in storage: ExperienceStorage) throws -> [String: Data] {
        var files: [String: Data] = [:]
        for (name, file) in samples {
            let bytes = try releaseSample(name)
            try storage.write(bytes, to: file)
            let stored = try storage.read(file)
            #expect(stored == bytes, "\(name): the stored copy is the sample")
            files[file] = bytes
        }
        return files
    }

    /// Expects the storage to hold exactly `files`, byte for byte, and each bundled sample of `samples` to be
    /// unchanged.
    private func expectUnchanged(_ files: [String: Data], _ samples: [(String, String)], in place: LabStoragePlace,
                                 sourceLocation: SourceLocation = #_sourceLocation) throws {
        let contents = try place.contents()
        #expect(contents == files, "every stored file stays byte-identical, none is added",
                sourceLocation: sourceLocation)
        for (name, file) in samples {
            let bundled = try releaseSample(name)
            #expect(bundled == files[file], "\(name): the bundled sample stays byte-identical",
                    sourceLocation: sourceLocation)
        }
    }

    /// The refusal code of a saved graph file's decoding; nil when it decodes.
    private func graphRefusal(_ data: Data) -> String? {
        if case .failure(let refusal) = GraphLibrary.decode(data) { return refusal.code }
        return nil
    }

    /// The refusal code of an index file's decoding; nil when it decodes.
    private func indexRefusal(_ data: Data) -> String? {
        if case .failure(let refusal) = GraphLibrary.decodeIndex(data) { return refusal.code }
        return nil
    }

    @Test func noSampleHoldsAPathOrAUUID() throws {
        for name in Self.names {
            let text = try #require(String(data: try releaseSample(name), encoding: .utf8), "\(name) is UTF-8")
            let hasPath = text.contains("/Users") || text.contains("file:")
            #expect(!hasPath && !text.contains("-4000-"), "\(name): no path and no UUID")
        }
    }

    // MARK: Snapshots

    @Test func theCurrentSnapshotSampleRestores() async throws {
        let place = try LabStoragePlace("release-snapshot-v1")
        defer { place.remove() }
        let samples = [("snapshot-v1", "snapshot-v1.json")]
        let files = try install(samples, in: place.storage)
        let bytes = try place.storage.read("snapshot-v1.json")
        let snapshot = try ExperienceSnapshot(data: bytes)
        #expect(snapshot.experience == LabTest.id)
        #expect(snapshot.schemaVersion == 1 && snapshot.seed == 7 && snapshot.stepIndex == 0)
        let encoded = try snapshot.encoded()
        #expect(encoded == bytes, "the sample is in the encoded form")

        var engine = try await LabTest.engine(seed: snapshot.seed)
        try engine.restore(snapshot)
        let core = try #require(engine.core)
        let digest = try engine.digest()
        #expect(digest == snapshot.digest, "the digest of the restored state is the sample's")
        #expect(try labDigest(core) == snapshot.digest.hex)
        #expect(core.graph == Self.snapshotGraph, "the starter graph with the Gradient")
        #expect(core.selection == NodeID(3), "the Gradient is selected")
        let payload = try core.snapshotPayload()
        #expect(payload == Data(snapshot.payload.utf8), "written back as the same payload")
        try expectUnchanged(files, samples, in: place)
    }

    @Test func theNewerSnapshotSampleIsRefusedAndChangesNothing() async throws {
        let place = try LabStoragePlace("release-snapshot-newer")
        defer { place.remove() }
        let samples = [("snapshot-newer", "snapshot-newer.json")]
        let files = try install(samples, in: place.storage)
        let snapshot = try ExperienceSnapshot(data: try place.storage.read("snapshot-newer.json"))
        #expect(snapshot.schemaVersion == 2)
        var engine = try await LabTest.engine(seed: 7)
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
        let after = try #require(engine.core)
        #expect(after == before, "a refused restore changes nothing")
        let afterDigest = try engine.digest()
        #expect(afterDigest == digest)
        try expectUnchanged(files, samples, in: place)
    }

    @Test func theDamagedSnapshotSampleIsRefused() throws {
        let place = try LabStoragePlace("release-snapshot-damaged")
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

    // MARK: Saved graphs

    @Test func theNewerAndDamagedGraphSamplesAreListedAsUnreadable() throws {
        let place = try LabStoragePlace("release-graph-unreadable")
        defer { place.remove() }
        let samples = [("graph-sample", "graph-1.json"), ("graph-newer", "graph-2.json"),
                       ("graph-damaged", "graph-3.json"), ("library-current", GraphLibrary.indexFile)]
        let files = try install(samples, in: place.storage)
        #expect(graphRefusal(try releaseSample("graph-newer")) == "newer-version")
        #expect(graphRefusal(try releaseSample("graph-damaged")) == "damaged")
        let library = GraphLibrary(storage: place.storage)
        let problem = library.indexProblem
        #expect(problem == nil && !library.isReadOnly)
        let expected = [
            GraphLibraryEntry(file: "graph-1.json", name: "Sample clouds", order: 1, state: .readable),
            GraphLibraryEntry(file: "graph-2.json", name: "graph-2.json", order: 0, state: .unreadable("newer-version")),
            GraphLibraryEntry(file: "graph-3.json", name: "graph-3.json", order: 0, state: .unreadable("damaged"))]
        #expect(library.entries == expected, "listed with their codes")
        #expect(library.readable.count == 1 && library.next == 4)
        let newer = LabLibraryTest.failure(library.open("graph-2.json"))
        #expect(newer == .unreadable("newer-version"))
        let damaged = LabLibraryTest.failure(library.open("graph-3.json"))
        #expect(damaged == .unreadable("damaged"))
        let current = LabLibraryTest.failure(library.open("graph-1.json"))
        #expect(current == nil, "the readable one still opens")
        library.reload()
        try expectUnchanged(files, samples, in: place)
    }

    @Test func anOversizedGraphIsListedAsTooLargeAndKept() throws {
        let place = try LabStoragePlace("release-graph-too-large")
        defer { place.remove() }
        let samples = [("graph-sample", "graph-1.json")]
        var files = try install(samples, in: place.storage)
        var big = try releaseSample("graph-sample")
        big.append(Data(repeating: 0x20, count: GraphLibrary.maxFileBytes + 1 - big.count))
        #expect(big.count == 81_921)
        try place.storage.write(big, to: "graph-2.json")
        files["graph-2.json"] = big
        #expect(graphRefusal(big) == "too-large")
        let library = GraphLibrary(storage: place.storage)
        let expected = [
            GraphLibraryEntry(file: "graph-1.json", name: "Sample clouds", order: 1, state: .readable),
            GraphLibraryEntry(file: "graph-2.json", name: "graph-2.json", order: 0, state: .unreadable("too-large"))]
        #expect(library.entries == expected, "listed as too-large")
        let refused = LabLibraryTest.failure(library.open("graph-2.json"))
        #expect(refused == .unreadable("too-large"))
        library.reload()
        #expect(place.storage.exists("graph-2.json"), "the oversized file is kept")
        try expectUnchanged(files, samples, in: place)
    }

    // MARK: Index

    @Test func theCurrentIndexSampleListsAndIsInTheEncodedForm() throws {
        let place = try LabStoragePlace("release-library-current")
        defer { place.remove() }
        let samples = [("graph-sample", "graph-1.json"), ("library-current", GraphLibrary.indexFile)]
        let files = try install(samples, in: place.storage)
        let bytes = try releaseSample("library-current")
        guard case .success(let index) = GraphLibrary.decodeIndex(bytes) else {
            Issue.record("library-current does not decode")
            return
        }
        let item = GraphLibrary.Index.Item(file: "graph-1.json", name: "Sample clouds", order: 1)
        #expect(index == GraphLibrary.Index(entries: [item], next: 2))
        let encoded = try GraphLibrary.encode(index)
        #expect(encoded == bytes, "the sample is in the encoded form")
        let library = GraphLibrary(storage: place.storage)
        let problem = library.indexProblem
        #expect(problem == nil && !library.isReadOnly && library.next == 2)
        #expect(library.entries == [GraphLibraryEntry(file: "graph-1.json", name: "Sample clouds", order: 1,
                                                      state: .readable)])
        let opened = LabLibraryTest.failure(library.open("graph-1.json"))
        #expect(opened == nil)
        try expectUnchanged(files, samples, in: place)
    }

    @Test func theNewerIndexSampleMakesTheLibraryReadOnly() throws {
        let place = try LabStoragePlace("release-library-newer")
        defer { place.remove() }
        let samples = [("graph-sample", "graph-1.json"), ("library-newer", GraphLibrary.indexFile)]
        let files = try install(samples, in: place.storage)
        #expect(indexRefusal(try releaseSample("library-newer")) == "newer-version")
        let library = GraphLibrary(storage: place.storage)
        let problem = library.indexProblem
        #expect(library.isReadOnly && problem == "newer-version", "the library is read only")
        let names = library.entries.map(\.name)
        #expect(names == ["Sample clouds"], "the graph is listed from its file")
        let opened = LabLibraryTest.failure(library.open("graph-1.json"))
        #expect(opened == nil, "opening still works")
        let saved = LabLibraryTest.failure(library.save(name: "Sample tide", graph: LabLibraryTest.ramp))
        #expect(saved == .readOnly)
        let renamed = LabLibraryTest.failure(library.rename("graph-1.json", to: "Sample tide"))
        #expect(renamed == .readOnly)
        let removed = LabLibraryTest.failure(library.remove("graph-1.json"))
        #expect(removed == .readOnly)
        try expectUnchanged(files, samples, in: place)
    }

    @Test func theDamagedIndexSampleStillListsTheGraphAndIsNotRewrittenByReading() throws {
        let place = try LabStoragePlace("release-library-damaged")
        defer { place.remove() }
        let samples = [("graph-sample", "graph-1.json"), ("library-damaged", GraphLibrary.indexFile)]
        let files = try install(samples, in: place.storage)
        #expect(indexRefusal(try releaseSample("library-damaged")) == "damaged")
        let library = GraphLibrary(storage: place.storage)
        let problem = library.indexProblem
        #expect(problem == "damaged" && !library.isReadOnly)
        #expect(library.entries == [GraphLibraryEntry(file: "graph-1.json", name: "Sample clouds", order: 1,
                                                      state: .readable)], "listed from the graph's file")
        #expect(library.next == 2, "the counter is recovered from the files")
        let opened = LabLibraryTest.failure(library.open("graph-1.json"))
        #expect(opened == nil)
        library.reload()
        let index = try place.storage.read(GraphLibrary.indexFile)
        #expect(index == files[GraphLibrary.indexFile], "reading does not rewrite the index")
        try expectUnchanged(files, samples, in: place)
    }
}
