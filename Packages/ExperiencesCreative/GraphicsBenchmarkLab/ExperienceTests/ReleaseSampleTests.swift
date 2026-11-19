// ReleaseSampleTests — feature 178 (A24-P06) T-A24-605 (FR-A24-604; data-model.md "Samples"). The committed release
// samples under `ExperienceTests/Fixtures` are answered by the code that reads them in the app. They were written once
// through the real encoders (`ExperienceShell.snapshot()` of `BenchCore` and `ExperienceSnapshot.encoded()`,
// `ResultLibrary.save(_:)`, which writes `ResultLibrary.encode(order:run:)` and `ResultLibrary.encode(_:)`):
//   - `snapshot-v1.json`: the snapshot (seed 1, step 0, schema 1) of the core with Shader ALU (case 1) selected, two
//     start and one stop request; it restores; `snapshot-newer.json` (the same in an envelope of schema 2) is refused
//     as `snapshot.newer-schema` and `snapshot-damaged.json` (the v1 file cut in half) as `snapshot.corrupt`; neither
//     changes the core;
//   - `result-current.json`: a synthetic completed quads run (3 warm-up, 4 measured, 2 cool-down frames, with a
//     report) saved as order 1 (`a24.saved-result` v1, run file v3); it opens; `result-newer.json` (envelope version
//     2) and `result-damaged.json` (cut in half) are listed as unreadable with `newer-version` and `damaged` and are
//     refused on open;
//   - `results-current.json`: the index of `result-1.json`, next 2; it lists; `results-newer.json` (version 2) makes
//     the library read only (opening still works); `results-damaged.json` (cut in half) is reported as `damaged` while
//     the result is still listed from its file, and reading does not rewrite it.
// An oversized saved result (2,162,689 bytes, written by the test into its temporary storage, never committed) is
// listed as unreadable `too-large` and kept. Samples are copied into a temporary experience storage
// (`BenchStoragePlace`, removed afterwards): snapshots under their own names, results as `result-<n>.json` (the only
// names the library lists) and indices as `results.json`; afterwards every stored copy and every bundled sample is
// byte for byte the sample and no file is added. No UUID, no date and no path appears in any sample. Short runs only
// (well under 10 s, no sleep, no wall-clock assertion), no prompt, no network.
import Foundation
import Testing
import VisualCoreExperience
@testable import GraphicsBenchmarkLabExperience
import GraphicsBenchmarkLabCore

/// The bytes of the bundled sample `name` (without extension).
private func releaseSample(_ name: String) throws -> Data {
    let url = try #require(Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures"),
                           "missing Fixtures/\(name).json")
    return try Data(contentsOf: url)
}

/// The release samples of A24-P06: snapshots, saved results and indices, current, newer and damaged.
@MainActor
@Suite(.serialized) struct ReleaseSampleTests {
    // MARK: Helpers

    /// Every sample this suite reads, without extension.
    static let names = ["snapshot-v1", "snapshot-newer", "snapshot-damaged", "result-current", "result-newer",
                        "result-damaged", "results-current", "results-newer", "results-damaged"]

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
    private func expectUnchanged(_ files: [String: Data], _ samples: [(String, String)], in place: BenchStoragePlace,
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

    /// The refusal code of a saved result file's decoding; nil when it decodes.
    private func resultRefusal(_ data: Data) -> String? {
        if case .failure(let refusal) = ResultLibrary.decode(data) { return refusal.code }
        return nil
    }

    /// The refusal code of an index file's decoding; nil when it decodes.
    private func indexRefusal(_ data: Data) -> String? {
        if case .failure(let refusal) = ResultLibrary.decodeIndex(data) { return refusal.code }
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
        let place = try BenchStoragePlace("release-snapshot-v1")
        defer { place.remove() }
        let samples = [("snapshot-v1", "snapshot-v1.json")]
        let files = try install(samples, in: place.storage)
        let bytes = try place.storage.read("snapshot-v1.json")
        let snapshot = try ExperienceSnapshot(data: bytes)
        #expect(snapshot.experience == BenchTest.id)
        #expect(snapshot.schemaVersion == 1 && snapshot.seed == 1 && snapshot.stepIndex == 0)
        let encoded = try snapshot.encoded()
        #expect(encoded == bytes, "the sample is in the encoded form")

        var engine = try await BenchTest.engine(seed: snapshot.seed)
        try engine.restore(snapshot)
        let core = try #require(engine.core)
        let digest = try engine.digest()
        #expect(digest == snapshot.digest, "the digest of the restored state is the sample's")
        #expect(try BenchTest.digest(core) == snapshot.digest.hex)
        #expect(core.selectedCase == 1 && core.startRequests == 2 && core.stopRequests == 1,
                "Shader ALU, two starts and one stop")
        let payload = try core.snapshotPayload()
        #expect(payload == Data(snapshot.payload.utf8), "written back as the same payload")
        try expectUnchanged(files, samples, in: place)
    }

    @Test func theNewerSnapshotSampleIsRefusedAndChangesNothing() async throws {
        let place = try BenchStoragePlace("release-snapshot-newer")
        defer { place.remove() }
        let samples = [("snapshot-newer", "snapshot-newer.json")]
        let files = try install(samples, in: place.storage)
        let snapshot = try ExperienceSnapshot(data: try place.storage.read("snapshot-newer.json"))
        #expect(snapshot.schemaVersion == 2)
        var engine = try await BenchTest.engine(seed: 1)
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
        let place = try BenchStoragePlace("release-snapshot-damaged")
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

    // MARK: Saved results

    @Test func theCurrentResultSampleOpensAndIsInTheEncodedForm() throws {
        let place = try BenchStoragePlace("release-result-current")
        defer { place.remove() }
        let samples = [("result-current", "result-1.json"), ("results-current", ResultLibrary.indexFile)]
        let files = try install(samples, in: place.storage)
        let bytes = try releaseSample("result-current")
        guard case .success(let decoded) = ResultLibrary.decode(bytes) else {
            Issue.record("result-current does not decode")
            return
        }
        #expect(decoded.order == 1)
        #expect(decoded.run.benchmarkCase == .quads && decoded.run.state == .completed)
        #expect(decoded.run.samples.count == 9 && decoded.run.report != nil, "3 + 4 + 2 frames with a report")
        let encoded = try ResultLibrary.encode(order: decoded.order, run: decoded.run)
        #expect(encoded == bytes, "the sample is in the encoded form")
        let library = ResultLibrary(storage: place.storage)
        let problem = library.indexProblem
        #expect(problem == nil && !library.isReadOnly && library.next == 2)
        #expect(ResultTest.codes(library.entries) == ["readable"])
        let opened = try #require(ResultTest.value(library.open(file: "result-1.json")))
        let same = opened.run == decoded.run
        #expect(same, "opens as the stored run")
        library.reload()
        try expectUnchanged(files, samples, in: place)
    }

    @Test func theNewerAndDamagedResultSamplesAreListedAsUnreadable() throws {
        let place = try BenchStoragePlace("release-result-unreadable")
        defer { place.remove() }
        let samples = [("result-current", "result-1.json"), ("result-newer", "result-2.json"),
                       ("result-damaged", "result-3.json"), ("results-current", ResultLibrary.indexFile)]
        let files = try install(samples, in: place.storage)
        #expect(resultRefusal(try releaseSample("result-newer")) == "newer-version")
        #expect(resultRefusal(try releaseSample("result-damaged")) == "damaged")
        let library = ResultLibrary(storage: place.storage)
        let problem = library.indexProblem
        #expect(problem == nil && !library.isReadOnly)
        #expect(library.entries.map(\.file) == ["result-1.json", "result-3.json", "result-2.json"])
        #expect(ResultTest.codes(library.entries) == ["readable", "damaged", "newer-version"],
                "listed with their codes")
        #expect(library.next == 4)
        #expect(ResultTest.failure(library.open(file: "result-2.json")) == .unreadable("newer-version"))
        #expect(ResultTest.failure(library.open(file: "result-3.json")) == .unreadable("damaged"))
        #expect(ResultTest.failure(library.open(file: "result-1.json")) == nil, "the readable one still opens")
        library.reload()
        try expectUnchanged(files, samples, in: place)
    }

    @Test func anOversizedResultIsListedAsTooLargeAndKept() throws {
        let place = try BenchStoragePlace("release-result-too-large")
        defer { place.remove() }
        let samples = [("result-current", "result-1.json")]
        var files = try install(samples, in: place.storage)
        var big = try releaseSample("result-current")
        big.append(Data(repeating: 0x20, count: ResultLibrary.maxFileBytes + 1 - big.count))
        #expect(big.count == 2_162_689)
        try place.storage.write(big, to: "result-2.json")
        files["result-2.json"] = big
        #expect(resultRefusal(big) == "too-large")
        let library = ResultLibrary(storage: place.storage)
        #expect(library.entries.map(\.file) == ["result-1.json", "result-2.json"])
        #expect(ResultTest.codes(library.entries) == ["readable", "too-large"], "listed as too-large")
        #expect(ResultTest.failure(library.open(file: "result-2.json")) == .unreadable("too-large"))
        library.reload()
        #expect(place.storage.exists("result-2.json"), "the oversized file is kept")
        try expectUnchanged(files, samples, in: place)
    }

    // MARK: Index

    @Test func theCurrentIndexSampleListsAndIsInTheEncodedForm() throws {
        let place = try BenchStoragePlace("release-results-current")
        defer { place.remove() }
        let samples = [("result-current", "result-1.json"), ("results-current", ResultLibrary.indexFile)]
        let files = try install(samples, in: place.storage)
        let bytes = try releaseSample("results-current")
        guard case .success(let index) = ResultLibrary.decodeIndex(bytes) else {
            Issue.record("results-current does not decode")
            return
        }
        let item = ResultLibrary.Index.Item(file: "result-1.json", order: 1)
        #expect(index == ResultLibrary.Index(entries: [item], next: 2))
        let encoded = try ResultLibrary.encode(index)
        #expect(encoded == bytes, "the sample is in the encoded form")
        let library = ResultLibrary(storage: place.storage)
        let problem = library.indexProblem
        #expect(problem == nil && !library.isReadOnly && library.next == 2)
        #expect(library.entries.map(\.file) == ["result-1.json"] && library.entries.first?.order == 1)
        try expectUnchanged(files, samples, in: place)
    }

    @Test func theNewerIndexSampleMakesTheLibraryReadOnly() throws {
        let place = try BenchStoragePlace("release-results-newer")
        defer { place.remove() }
        let samples = [("result-current", "result-1.json"), ("results-newer", ResultLibrary.indexFile)]
        let files = try install(samples, in: place.storage)
        #expect(indexRefusal(try releaseSample("results-newer")) == "newer-version")
        let library = ResultLibrary(storage: place.storage)
        let problem = library.indexProblem
        #expect(library.isReadOnly && problem == "newer-version", "the library is read only")
        #expect(library.entries.map(\.file) == ["result-1.json"], "the result is listed from its file")
        #expect(ResultTest.failure(library.open(file: "result-1.json")) == nil, "opening still works")
        #expect(ResultTest.failure(library.save(try ResultTest.run(measured: 4))) == .readOnly)
        #expect(ResultTest.failure(library.remove(file: "result-1.json")) == .readOnly)
        try expectUnchanged(files, samples, in: place)
    }

    @Test func theDamagedIndexSampleStillListsTheResultAndIsNotRewrittenByReading() throws {
        let place = try BenchStoragePlace("release-results-damaged")
        defer { place.remove() }
        let samples = [("result-current", "result-1.json"), ("results-damaged", ResultLibrary.indexFile)]
        let files = try install(samples, in: place.storage)
        #expect(indexRefusal(try releaseSample("results-damaged")) == "damaged")
        let library = ResultLibrary(storage: place.storage)
        let problem = library.indexProblem
        #expect(problem == "damaged" && !library.isReadOnly)
        #expect(library.entries.map(\.file) == ["result-1.json"], "listed from the result's file")
        #expect(ResultTest.codes(library.entries) == ["readable"])
        #expect(library.next == 2, "the counter is recovered from the files")
        #expect(ResultTest.failure(library.open(file: "result-1.json")) == nil)
        _ = library.list()
        let index = try place.storage.read(ResultLibrary.indexFile)
        #expect(index == files[ResultLibrary.indexFile], "reading does not rewrite the index")
        try expectUnchanged(files, samples, in: place)
    }
}
