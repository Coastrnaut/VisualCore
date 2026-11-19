// ReleaseSampleTests — feature 185 (A25-P06) T-A25-605 (clarification Q4; data-model.md "Sample files"; contracts/
// release.md "Samples"; analyze C1). The committed release samples under `ExperienceTests/Fixtures` are answered by the
// code that reads them in the app. They were written once through the real encoders (the engine's `snapshot()` of
// `ComposerCore` and `ExperienceSnapshot.encoded()`, `LookLibrary.encode(name:order:chain:)` and
// `LookLibrary.encode(_:)`):
//   - `snapshot-v1.json`: the snapshot (seed 1, step 0, schema 1) of a two-effect chain (a colour grade with
//     exposure 1, then a distort at its defaults); it restores; `snapshot-newer.json` (the same in an envelope of schema
//     2) is refused as `snapshot.newer-schema` and `snapshot-damaged.json` (the v1 file cut in half) as
//     `snapshot.corrupt`; neither changes the core;
//   - `preset-current.json`: that chain saved as "Warm look", order 1 (`a25.preset` v1 embedding `a25.effect-chain`
//     v1); it opens; `preset-newer.json` (the envelope's version 2) and `preset-damaged.json` (cut in half) are listed
//     as unreadable with `newer-version` and `damaged` and are refused on open;
//   - `presets-current.json`: the index of `preset-1.json` ("Warm look", order 1), next 2; it lists;
//     `presets-newer.json` (version 2) makes the library read only (opening still works); `presets-damaged.json` (cut
//     in half) is reported as `damaged` while the look is still listed from its file, and reading does not rewrite it.
// An oversized look (69,633 bytes, written by the test into its temporary storage, never committed) is listed as
// unreadable `too-large` and kept. Samples are copied into a temporary experience storage (`PresetStoragePlace`,
// removed afterwards): snapshots under their own names, looks as `preset-<n>.json` (the only names the library lists)
// and indices as `presets.json`; afterwards every stored copy and every bundled sample is byte for byte the sample and
// no file is added. No UUID, no date and no path appears in any sample. Short runs only (well under 10 s, no sleep, no
// wall-clock assertion), no prompt, no network.
import EffectsComposerCore
import Foundation
import Testing
import VisualCoreExperience
@testable import EffectsComposerExperience

/// The bytes of the bundled sample `name` (without extension).
private func releaseSample(_ name: String) throws -> Data {
    let url = try #require(Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures"),
                           "missing Fixtures/\(name).json")
    return try Data(contentsOf: url)
}

/// The release samples of A25-P06: snapshots, looks and indices, current, newer and damaged.
@MainActor
@Suite(.serialized) struct ReleaseSampleTests {
    // MARK: Helpers

    /// Every sample this suite reads, without extension.
    static let names = ["snapshot-v1", "snapshot-newer", "snapshot-damaged", "preset-current", "preset-newer",
                        "preset-damaged", "presets-current", "presets-newer", "presets-damaged"]

    /// The chain every current sample holds: a colour grade with exposure 1, then a distort at its defaults.
    static let chain = EffectChain(nodes: [
        EffectNode(id: 1, effect: .grade, enabled: true, values: ["contrast": 1, "exposure": 1, "saturation": 1]),
        EffectNode(id: 2, effect: .distort, enabled: true, values: ["amplitude": 0.01, "frequency": 4]),
    ])

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
    private func expectUnchanged(_ files: [String: Data], _ samples: [(String, String)], in place: PresetStoragePlace,
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

    /// The refusal code of a look file's decoding; nil when it decodes.
    private func presetRefusal(_ data: Data) -> String? {
        if case .failure(let refusal) = LookLibrary.decode(data) { return refusal.code }
        return nil
    }

    /// The refusal code of an index file's decoding; nil when it decodes.
    private func indexRefusal(_ data: Data) -> String? {
        if case .failure(let refusal) = LookLibrary.decodeIndex(data) { return refusal.code }
        return nil
    }

    /// The states of `entries` as codes: `readable` or the refusal code.
    private func codes(_ entries: [LookLibraryEntry]) -> [String] {
        entries.map { $0.refusal ?? "readable" }
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
        let place = try PresetStoragePlace("release-snapshot-v1")
        defer { place.remove() }
        let samples = [("snapshot-v1", "snapshot-v1.json")]
        let files = try install(samples, in: place.storage)
        let bytes = try place.storage.read("snapshot-v1.json")
        let snapshot = try ExperienceSnapshot(data: bytes)
        #expect(snapshot.experience == ComposerTest.id)
        #expect(snapshot.schemaVersion == 1 && snapshot.seed == 1 && snapshot.stepIndex == 0)
        let encoded = try snapshot.encoded()
        #expect(encoded == bytes, "the sample is in the encoded form")

        var engine = try await ComposerTest.engine(seed: snapshot.seed)
        try engine.restore(snapshot)
        let core = try #require(engine.core)
        #expect(core.chain == Self.chain, "the two-effect chain")
        let digest = try engine.digest()
        #expect(digest == snapshot.digest, "the digest of the restored state is the sample's")
        let payload = try core.snapshotPayload()
        #expect(payload == Data(snapshot.payload.utf8), "written back as the same payload")
        try expectUnchanged(files, samples, in: place)
    }

    @Test func theNewerSnapshotSampleIsRefusedAndChangesNothing() async throws {
        let place = try PresetStoragePlace("release-snapshot-newer")
        defer { place.remove() }
        let samples = [("snapshot-newer", "snapshot-newer.json")]
        let files = try install(samples, in: place.storage)
        let snapshot = try ExperienceSnapshot(data: try place.storage.read("snapshot-newer.json"))
        #expect(snapshot.schemaVersion == 2)
        var engine = try await ComposerTest.engine(seed: 1)
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
        #expect(after.chain == before.chain && after.chain == .empty, "a refused restore changes nothing")
        let afterDigest = try engine.digest()
        #expect(afterDigest == digest)
        try expectUnchanged(files, samples, in: place)
    }

    @Test func theDamagedSnapshotSampleIsRefused() throws {
        let place = try PresetStoragePlace("release-snapshot-damaged")
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

    // MARK: Looks

    @Test func theCurrentPresetSampleOpensAndIsInTheEncodedForm() throws {
        let place = try PresetStoragePlace("release-preset-current")
        defer { place.remove() }
        let samples = [("preset-current", "preset-1.json"), ("presets-current", LookLibrary.indexFile)]
        let files = try install(samples, in: place.storage)
        let bytes = try releaseSample("preset-current")
        guard case .success(let decoded) = LookLibrary.decode(bytes) else {
            Issue.record("preset-current does not decode")
            return
        }
        #expect(decoded.saved.name == "Warm look" && decoded.saved.order == 1)
        #expect(decoded.chain == Self.chain)
        let encoded = try LookLibrary.encode(name: "Warm look", order: 1, chain: decoded.chain)
        #expect(encoded == bytes, "the sample is in the encoded form")
        let library = LookLibrary(storage: place.storage)
        let problem = library.indexProblem
        #expect(problem == nil && !library.isReadOnly && library.next == 2)
        #expect(codes(library.entries) == ["readable"])
        let opened = try #require(PresetTest.value(library.open(file: "preset-1.json")))
        #expect(opened == Self.chain && opened.fingerprint() == Self.chain.fingerprint(), "opens as the stored chain")
        library.reload()
        try expectUnchanged(files, samples, in: place)
    }

    @Test func theNewerAndDamagedPresetSamplesAreListedAsUnreadable() throws {
        let place = try PresetStoragePlace("release-preset-unreadable")
        defer { place.remove() }
        let samples = [("preset-current", "preset-1.json"), ("preset-newer", "preset-2.json"),
                       ("preset-damaged", "preset-3.json"), ("presets-current", LookLibrary.indexFile)]
        let files = try install(samples, in: place.storage)
        #expect(presetRefusal(try releaseSample("preset-newer")) == "newer-version")
        #expect(presetRefusal(try releaseSample("preset-damaged")) == "damaged")
        let library = LookLibrary(storage: place.storage)
        let problem = library.indexProblem
        #expect(problem == nil && !library.isReadOnly)
        #expect(library.entries.map(\.file) == ["preset-1.json", "preset-2.json", "preset-3.json"])
        #expect(codes(library.entries) == ["readable", "newer-version", "damaged"], "listed with their codes")
        #expect(library.next == 4)
        #expect(PresetTest.failure(library.open(file: "preset-2.json")) == .unreadable("newer-version"))
        #expect(PresetTest.failure(library.open(file: "preset-3.json")) == .unreadable("damaged"))
        #expect(PresetTest.failure(library.open(file: "preset-1.json")) == nil, "the readable one still opens")
        library.reload()
        try expectUnchanged(files, samples, in: place)
    }

    @Test func anOversizedPresetIsListedAsTooLargeAndKept() throws {
        let place = try PresetStoragePlace("release-preset-too-large")
        defer { place.remove() }
        let samples = [("preset-current", "preset-1.json")]
        var files = try install(samples, in: place.storage)
        var big = try releaseSample("preset-current")
        big.append(Data(repeating: 0x20, count: LookLibrary.maxFileBytes + 1 - big.count))
        #expect(big.count == 69_633)
        try place.storage.write(big, to: "preset-2.json")
        files["preset-2.json"] = big
        #expect(presetRefusal(big) == "too-large")
        let library = LookLibrary(storage: place.storage)
        #expect(library.entries.map(\.file) == ["preset-1.json", "preset-2.json"])
        #expect(codes(library.entries) == ["readable", "too-large"], "listed as too-large")
        #expect(PresetTest.failure(library.open(file: "preset-2.json")) == .unreadable("too-large"))
        library.reload()
        #expect(place.storage.exists("preset-2.json"), "the oversized file is kept")
        try expectUnchanged(files, samples, in: place)
    }

    // MARK: Index

    @Test func theCurrentIndexSampleListsAndIsInTheEncodedForm() throws {
        let place = try PresetStoragePlace("release-presets-current")
        defer { place.remove() }
        let samples = [("preset-current", "preset-1.json"), ("presets-current", LookLibrary.indexFile)]
        let files = try install(samples, in: place.storage)
        let bytes = try releaseSample("presets-current")
        guard case .success(let index) = LookLibrary.decodeIndex(bytes) else {
            Issue.record("presets-current does not decode")
            return
        }
        let item = LookLibrary.Index.Item(file: "preset-1.json", name: "Warm look", order: 1)
        #expect(index == LookLibrary.Index(entries: [item], next: 2))
        let encoded = try LookLibrary.encode(index)
        #expect(encoded == bytes, "the sample is in the encoded form")
        let library = LookLibrary(storage: place.storage)
        let problem = library.indexProblem
        #expect(problem == nil && !library.isReadOnly && library.next == 2)
        #expect(library.entries.map(\.file) == ["preset-1.json"] && library.entries.first?.name == "Warm look")
        try expectUnchanged(files, samples, in: place)
    }

    @Test func theNewerIndexSampleMakesTheLibraryReadOnly() throws {
        let place = try PresetStoragePlace("release-presets-newer")
        defer { place.remove() }
        let samples = [("preset-current", "preset-1.json"), ("presets-newer", LookLibrary.indexFile)]
        let files = try install(samples, in: place.storage)
        #expect(indexRefusal(try releaseSample("presets-newer")) == "newer-version")
        let library = LookLibrary(storage: place.storage)
        let problem = library.indexProblem
        #expect(library.isReadOnly && problem == "newer-version", "the library is read only")
        #expect(library.entries.map(\.file) == ["preset-1.json"], "the look is listed from its file")
        #expect(PresetTest.failure(library.open(file: "preset-1.json")) == nil, "opening still works")
        #expect(PresetTest.failure(library.save(name: "Other look", chain: Self.chain)) == .readOnly)
        #expect(PresetTest.failure(library.rename(file: "preset-1.json", to: "Other look")) == .readOnly)
        #expect(PresetTest.failure(library.remove(file: "preset-1.json")) == .readOnly)
        try expectUnchanged(files, samples, in: place)
    }

    @Test func theDamagedIndexSampleStillListsTheLookAndIsNotRewrittenByReading() throws {
        let place = try PresetStoragePlace("release-presets-damaged")
        defer { place.remove() }
        let samples = [("preset-current", "preset-1.json"), ("presets-damaged", LookLibrary.indexFile)]
        let files = try install(samples, in: place.storage)
        #expect(indexRefusal(try releaseSample("presets-damaged")) == "damaged")
        let library = LookLibrary(storage: place.storage)
        let problem = library.indexProblem
        #expect(problem == "damaged" && !library.isReadOnly)
        #expect(library.entries.map(\.file) == ["preset-1.json"], "listed from the look's file")
        #expect(codes(library.entries) == ["readable"] && library.entries.first?.name == "Warm look")
        #expect(library.next == 2, "the counter is recovered from the files")
        #expect(PresetTest.failure(library.open(file: "preset-1.json")) == nil)
        library.reload()
        let index = try place.storage.read(LookLibrary.indexFile)
        #expect(index == files[LookLibrary.indexFile], "reading does not rewrite the index")
        try expectUnchanged(files, samples, in: place)
    }
}
