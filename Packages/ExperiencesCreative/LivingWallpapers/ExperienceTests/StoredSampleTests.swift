// StoredSampleTests — feature 143 (A19-P06) T-A19-605 (FR-A19-604; clarification Q4; contracts/release.md
// "Samples"). The committed sample files under `ExperienceTests/Fixtures` are answered by the code that reads them in
// the app:
//   - `snapshot-v1.json`, `snapshot-v2.json`: encoded snapshots (seed 7, step 0) whose payloads are those of
//     `WallpaperCore.schemaExamplePayload(version:)` 1 and 2; both restore, v1 migrated to schema 2 (`custom` 0 and
//     Saffron Ink's own colours), v2 with its edited colour 2, each with the digest of its schema example;
//   - `snapshot-newer.json` (the schema-2 payload in an envelope of schema 3) is refused as `snapshot.newer-schema`
//     and `snapshot-damaged.json` (the v2 file cut in half) as `snapshot.corrupt`; neither changes the core;
//   - `history-current.json` (the envelope `a19.export-history` schema 1 with two entries) loads both,
//     `history-newer.json` (schema 2) reports `newer-version` and `history-damaged.json` (cut in half) `damaged`,
//     both with an empty history.
// Each sample is copied into a temporary experience storage (`TemporaryWallpaperStorage`, removed afterwards) and read
// from there; afterwards the stored copy and the bundled sample are both byte for byte the sample. Short runs only
// (well under 10 s, no sleep, no wall-clock assertion), no prompt, no network.
import Foundation
import Testing
import LivingWallpapersCore
@testable import LivingWallpapersExperience
import VisualCoreExperience

/// The bytes of the bundled sample `name` (without extension).
private func sample(_ name: String) throws -> Data {
    let url = try #require(Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures"),
                           "missing Fixtures/\(name).json")
    return try Data(contentsOf: url)
}

@MainActor
@Suite(.serialized) struct StoredSampleTests {
    /// The fixed instant of the history samples' store: 2026-11-17 12:00:00 UTC.
    static let instant = Date(timeIntervalSince1970: 1_794_916_800)

    // MARK: Snapshots

    /// Copies the sample `name` into `fixture`'s storage as `name.json` and returns the bytes read back from there.
    private func stored(_ name: String, in fixture: TemporaryWallpaperStorage) throws -> Data {
        let bytes = try sample(name)
        try fixture.storage.write(bytes, to: name + ".json")
        let read = try fixture.storage.read(name + ".json")
        #expect(read == bytes, "\(name): the stored copy is the sample")
        return read
    }

    /// Expects the stored copy of `name` and the bundled sample to be byte for byte `bytes`.
    private func expectUnchanged(_ name: String, _ bytes: Data, in fixture: TemporaryWallpaperStorage) throws {
        #expect(try fixture.storage.read(name + ".json") == bytes, "\(name): the stored copy stays byte-identical")
        #expect(try sample(name) == bytes, "\(name): the bundled sample stays byte-identical")
    }

    @Test func theSchemaSamplesRestoreWithTheOlderOneMigrated() async throws {
        let fixture = try TemporaryWallpaperStorage("sample-snapshots")
        defer { fixture.remove() }
        for version in 1...2 {
            let name = "snapshot-v\(version)"
            let bytes = try stored(name, in: fixture)
            let snapshot = try ExperienceSnapshot(data: bytes)
            #expect(snapshot.schemaVersion == version, "\(name)")
            #expect(snapshot.seed == 7 && snapshot.stepIndex == 0, "\(name)")
            #expect(try snapshot.encoded() == bytes, "\(name) is in the encoded form")
            // The payload is the schema example's.
            let payload = try JSONSerialization.jsonObject(with: Data(snapshot.payload.utf8)) as? NSDictionary
            let expectedPayload = try #require(WallpaperCore.schemaExamplePayload(version: version))
            #expect(payload == (expectedPayload as NSDictionary), "\(name): the payload of the schema example")
            let example = try #require(WallpaperCore.schemaExample(version: version))
            #expect(snapshot.digest.hex == example.expectedDigest, "\(name): the digest of the schema example")

            var engine = try await WallpaperTest.engine(seed: snapshot.seed)
            try engine.restore(snapshot)
            let core = try #require(engine.core)
            #expect(try engine.digest().hex == example.expectedDigest, "\(name)")
            // Kept from every schema: scene, preset, parameters, canvas, time, format and motion.
            #expect(core.scene == 1 && core.preset == 2 && core.parameters == [1.2, 2.5, 0.4], "\(name)")
            #expect(core.template == 5 && core.orientation == 1 && core.animationTime == 42.5, "\(name)")
            #expect(core.format == 1 && !core.motion && core.seed == 7, "\(name)")
            // Written back as schema 2, with all ten fields.
            let written = try core.snapshotPayload()
            let object = try #require(try JSONSerialization.jsonObject(with: written) as? [String: Any])
            #expect(Set(object.keys) == WallpaperCore.schemaOneKeys.union(["colors", "custom"]), "\(name)")
            try expectUnchanged(name, bytes, in: fixture)
        }
    }

    @Test func theSchemaOneSampleMigratesToThePresetColours() async throws {
        let fixture = try TemporaryWallpaperStorage("sample-v1")
        defer { fixture.remove() }
        let bytes = try stored("snapshot-v1", in: fixture)
        var engine = try await WallpaperTest.engine(seed: 7)
        try engine.restore(try ExperienceSnapshot(data: bytes))
        let core = try #require(engine.core)
        #expect(core.custom == 0, "the migration adds custom 0")
        #expect(core.colors == WallpaperCore.presetComponents(scene: 1, preset: 2), "Saffron Ink's own colours")
        #expect(core.project.customColors == nil)
        try expectUnchanged("snapshot-v1", bytes, in: fixture)
    }

    @Test func theSchemaTwoSampleKeepsItsEditedColour() async throws {
        let fixture = try TemporaryWallpaperStorage("sample-v2")
        defer { fixture.remove() }
        let bytes = try stored("snapshot-v2", in: fixture)
        var engine = try await WallpaperTest.engine(seed: 7)
        try engine.restore(try ExperienceSnapshot(data: bytes))
        let core = try #require(engine.core)
        let edit = WallpaperCore.schemaTwoEditedSlot
        #expect(core.custom == 1)
        #expect(core.colors[(edit.slot * 3)...(edit.slot * 3 + 2)] == [edit.r, edit.g, edit.b])
        let colours = try #require(core.project.customColors)
        #expect(colours[edit.slot] == RGBColor(r: edit.r, g: edit.g, b: edit.b))
        try expectUnchanged("snapshot-v2", bytes, in: fixture)
    }

    @Test func theNewerSnapshotSampleIsRefusedAndChangesNothing() async throws {
        let fixture = try TemporaryWallpaperStorage("sample-newer")
        defer { fixture.remove() }
        let bytes = try stored("snapshot-newer", in: fixture)
        let snapshot = try ExperienceSnapshot(data: bytes)
        #expect(snapshot.schemaVersion == 3)
        var engine = try await WallpaperTest.engine(seed: 7)
        let before = try #require(engine.core)
        let digest = try engine.digest()
        var refusal: ExperienceError?
        do {
            try engine.restore(snapshot)
        } catch {
            refusal = error
        }
        #expect(refusal == .snapshot(.newerSchema(found: 3, current: 2)), "the newer sample is refused")
        #expect(SnapshotError.newerSchema(found: 3, current: 2).code == "snapshot.newer-schema")
        #expect(engine.core == before, "a refused restore changes nothing")
        #expect(try engine.digest() == digest)
        try expectUnchanged("snapshot-newer", bytes, in: fixture)
    }

    @Test func theDamagedSnapshotSampleIsRefused() throws {
        let fixture = try TemporaryWallpaperStorage("sample-damaged")
        defer { fixture.remove() }
        let bytes = try stored("snapshot-damaged", in: fixture)
        var refusal: SnapshotError?
        do {
            _ = try ExperienceSnapshot(data: bytes)
        } catch {
            refusal = error
        }
        let refused = try #require(refusal, "the damaged sample is refused before any restore")
        #expect(refused.code == "snapshot.corrupt")
        try expectUnchanged("snapshot-damaged", bytes, in: fixture)
    }

    // MARK: History

    /// Installs the sample `name` as `history.json` in `fixture`'s storage and returns its bytes and a store over the
    /// storage (which reads the file at once).
    private func history(_ name: String, in fixture: TemporaryWallpaperStorage) throws -> (Data, HistoryStore) {
        let bytes = try sample(name)
        try fixture.storage.write(bytes, to: HistoryStore.fileName)
        let store = HistoryStore(storage: fixture.storage, clock: FixedClock(Self.instant))
        return (bytes, store)
    }

    /// Expects `history.json` in `fixture`'s storage and the bundled sample `name` to be byte for byte `bytes`.
    private func expectHistoryUnchanged(_ name: String, _ bytes: Data, in fixture: TemporaryWallpaperStorage) throws {
        #expect(try fixture.storage.read(HistoryStore.fileName) == bytes, "\(name): stays byte-identical")
        #expect(try sample(name) == bytes, "\(name): the bundled sample stays byte-identical")
    }

    @Test func theCurrentHistorySampleLoadsBothEntries() throws {
        let fixture = try TemporaryWallpaperStorage("sample-history-current")
        defer { fixture.remove() }
        let (bytes, store) = try history("history-current", in: fixture)
        #expect(store.problem == nil)
        let newest = ExportHistory.Entry(scene: "aurora-bands", template: "iphone-se-3", orientation: .portrait,
                                         format: .png, width: 750, height: 1334, madeAt: 1_794_916_860)
        let older = ExportHistory.Entry(scene: "ink-flow", template: "iphone-se-3", orientation: .landscape,
                                        format: .heic, width: 1334, height: 750, madeAt: 1_794_916_800)
        #expect(store.history.entries == [newest, older], "both entries, newest first")
        #expect(store.shown == [newest, older])
        #expect(ExportHistory.decode(bytes) == .success(store.history))
        let reread = HistoryStore.read(fixture.storage)
        #expect(reread.history == store.history && reread.problem == nil)
        try expectHistoryUnchanged("history-current", bytes, in: fixture)
    }

    @Test func theNewerAndDamagedHistorySamplesReportTheirProblem() throws {
        let cases: [(String, HistoryRefusal, String)] = [("history-newer", .newerVersion(2), "newer-version"),
                                                         ("history-damaged", .damaged, "damaged")]
        for (name, refusal, code) in cases {
            let fixture = try TemporaryWallpaperStorage("sample-" + name)
            defer { fixture.remove() }
            let (bytes, store) = try history(name, in: fixture)
            #expect(store.history.entries.isEmpty, "\(name): an empty history")
            #expect(store.problem == refusal, "\(name)")
            #expect(store.problem?.code == code, "\(name)")
            let reread = HistoryStore.read(fixture.storage)
            #expect(reread.problem == refusal, "\(name): reported again on a second read")
            try expectHistoryUnchanged(name, bytes, in: fixture)
        }
    }
}
