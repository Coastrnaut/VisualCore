// StoredSampleTests — feature 136 (A18-P06) T-A18-605 (FR-A18-604; clarification Q4; contracts/release.md
// "Samples"). The committed sample files under `ExperienceTests/Fixtures` are answered by the code that reads them in
// the app:
//   - `snapshot-v1.json`, `snapshot-v2.json`, `snapshot-v3.json`: encoded snapshots (seed 7, step 0) whose payloads are
//     those of `AmbientCore.schemaExamplePayload(version:)` 1, 2 and 3; all three restore, v1 and v2 migrated to
//     schema 3 (v1: theme 0, palette 0 and the night, motion and keep-awake defaults; v2: the wave field with palette
//     1 and the same defaults), each with the digest of its schema example;
//   - `snapshot-newer.json` (the schema-3 payload in an envelope of schema 4) is refused as `snapshot.newer-schema`
//     and `snapshot-damaged.json` (the v3 file cut in half) as `snapshot.corrupt`; neither changes the core;
//   - `favourites-current.json` (two valid entries, synthetic ids `00000000-0000-4000-8000-…`) loads both,
//     `favourites-newer.json` (schema 2) reports `newer-version` and `favourites-damaged.json` (cut in half)
//     `damaged`, both with an empty list.
// Each sample is copied into a temporary experience storage and a private defaults suite (removed afterwards) and read
// from there; afterwards the stored copy and the bundled sample are both byte for byte the sample. Short runs only
// (well under 10 s, no sleep, no wall-clock assertion), no prompt, no network.
import Foundation
import Testing
import AmbientClockCore
@testable import AmbientClockExperience
import VisualCoreExperience

/// A storage over a fresh temporary folder and a private defaults suite; `cleanUp()` removes both.
@MainActor
private struct SampleStorage {
    let root: URL
    let suite: String
    let defaults: UserDefaults
    let storage: ExperienceStorage

    init(_ name: String) throws {
        suite = "a18.sample-tests." + name
        root = FileManager.default.temporaryDirectory.appendingPathComponent(suite, isDirectory: true)
        try? FileManager.default.removeItem(at: root)
        defaults = try #require(UserDefaults(suiteName: suite))
        storage = ExperienceStorage(id: AmbientTest.id, root: root, defaults: defaults)
    }

    /// Removes the folder and the defaults suite.
    func cleanUp() {
        try? FileManager.default.removeItem(at: root)
        defaults.removePersistentDomain(forName: suite)
    }
}

/// The bytes of the bundled sample `name` (without extension).
private func sample(_ name: String) throws -> Data {
    let url = try #require(Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures"),
                           "missing Fixtures/\(name).json")
    return try Data(contentsOf: url)
}

/// The synthetic id with number `n`.
private func syntheticID(_ n: Int) -> UUID {
    UUID(uuidString: String(format: "00000000-0000-4000-8000-%012d", n))!
}

@MainActor
@Suite(.serialized) struct StoredSampleTests {
    // MARK: Snapshots

    /// Copies the sample `name` into `fixture`'s storage as `name.json` and returns the bytes read back from there.
    private func stored(_ name: String, in fixture: SampleStorage) throws -> Data {
        let bytes = try sample(name)
        try fixture.storage.write(bytes, to: name + ".json")
        let read = try fixture.storage.read(name + ".json")
        #expect(read == bytes, "\(name): the stored copy is the sample")
        return read
    }

    /// Expects the stored copy of `name` and the bundled sample to be byte for byte `bytes`.
    private func expectUnchanged(_ name: String, _ bytes: Data, in fixture: SampleStorage) throws {
        #expect(try fixture.storage.read(name + ".json") == bytes, "\(name): the stored copy stays byte-identical")
        #expect(try sample(name) == bytes, "\(name): the bundled sample stays byte-identical")
    }

    @Test func theSchemaSamplesRestoreWithTheOlderOnesMigrated() async throws {
        let fixture = try SampleStorage("snapshots")
        defer { fixture.cleanUp() }
        for version in 1...3 {
            let name = "snapshot-v\(version)"
            let bytes = try stored(name, in: fixture)
            let snapshot = try ExperienceSnapshot(data: bytes)
            #expect(snapshot.schemaVersion == version, "\(name)")
            #expect(snapshot.seed == 7 && snapshot.stepIndex == 0, "\(name)")
            #expect(try snapshot.encoded() == bytes, "\(name) is in the encoded form")
            // The payload is the schema example's.
            let payload = try JSONSerialization.jsonObject(with: Data(snapshot.payload.utf8)) as? NSDictionary
            let expectedPayload = try #require(AmbientCore.schemaExamplePayload(version: version))
            #expect(payload == (expectedPayload as NSDictionary), "\(name): the payload of the schema example")
            let example = try #require(AmbientCore.schemaExample(version: version))
            #expect(snapshot.digest.hex == example.expectedDigest, "\(name): the digest of the schema example")

            var engine = try await AmbientTest.engine(seed: snapshot.seed)
            try engine.restore(snapshot)
            let core = try #require(engine.core)
            #expect(try engine.digest().hex == example.expectedDigest, "\(name)")
            // Kept from every schema: the format, motion and speed.
            #expect(core.hourCycle == 2 && core.showSeconds && !core.showDate, "\(name)")
            #expect(core.motion && core.speed == 1.5, "\(name)")
            // Written back as schema 3, with all thirteen fields.
            let written = try core.snapshotPayload()
            let object = try #require(try JSONSerialization.jsonObject(with: written) as? [String: Any])
            #expect(Set(object.keys) == AmbientFixtures.schemaThreeKeys, "\(name)")
            try expectUnchanged(name, bytes, in: fixture)
        }
    }

    @Test func theSchemaOneSampleMigratesToTheDefaults() async throws {
        let fixture = try SampleStorage("v1")
        defer { fixture.cleanUp() }
        let bytes = try stored("snapshot-v1", in: fixture)
        var engine = try await AmbientTest.engine(seed: 7)
        try engine.restore(try ExperienceSnapshot(data: bytes))
        let core = try #require(engine.core)
        #expect(core.theme == 0 && core.palette == 0, "the theme and palette defaults")
        #expect(core.nightMode == 0 && core.nightStart == 1320 && core.nightEnd == 420 && core.nightDim == 0.5)
        #expect(!core.reduceMotion && !core.keepAwake)
        try expectUnchanged("snapshot-v1", bytes, in: fixture)
    }

    @Test func theSchemaTwoSampleMigratesKeepingItsTheme() async throws {
        let fixture = try SampleStorage("v2")
        defer { fixture.cleanUp() }
        let bytes = try stored("snapshot-v2", in: fixture)
        var engine = try await AmbientTest.engine(seed: 7)
        try engine.restore(try ExperienceSnapshot(data: bytes))
        let core = try #require(engine.core)
        #expect(core.theme == 2 && core.palette == 1, "the wave field with palette 1")
        #expect(core.outcome?.code == "theme-wave-field")
        #expect(core.nightMode == 0 && core.nightStart == 1320 && core.nightEnd == 420 && core.nightDim == 0.5)
        #expect(!core.reduceMotion && !core.keepAwake)
        try expectUnchanged("snapshot-v2", bytes, in: fixture)
    }

    @Test func theSchemaThreeSampleRestoresAsItIs() async throws {
        let fixture = try SampleStorage("v3")
        defer { fixture.cleanUp() }
        let bytes = try stored("snapshot-v3", in: fixture)
        var engine = try await AmbientTest.engine(seed: 7)
        try engine.restore(try ExperienceSnapshot(data: bytes))
        let core = try #require(engine.core)
        #expect(core.theme == 2 && core.palette == 1)
        #expect(core.nightMode == 1 && core.nightStart == 1290 && core.nightEnd == 375 && core.nightDim == 0.4)
        #expect(core.reduceMotion && core.keepAwake)
        try expectUnchanged("snapshot-v3", bytes, in: fixture)
    }

    @Test func theNewerSnapshotSampleIsRefusedAndChangesNothing() async throws {
        let fixture = try SampleStorage("newer")
        defer { fixture.cleanUp() }
        let bytes = try stored("snapshot-newer", in: fixture)
        let snapshot = try ExperienceSnapshot(data: bytes)
        #expect(snapshot.schemaVersion == 4)
        var engine = try await AmbientTest.engine(seed: 7)
        let before = try #require(engine.core)
        let digest = try engine.digest()
        var refusal: ExperienceError?
        do {
            try engine.restore(snapshot)
        } catch {
            refusal = error
        }
        #expect(refusal == .snapshot(.newerSchema(found: 4, current: 3)), "the newer sample is refused")
        #expect(SnapshotError.newerSchema(found: 4, current: 3).code == "snapshot.newer-schema")
        #expect(engine.core == before, "a refused restore changes nothing")
        #expect(try engine.digest() == digest)
        try expectUnchanged("snapshot-newer", bytes, in: fixture)
    }

    @Test func theDamagedSnapshotSampleIsRefused() throws {
        let fixture = try SampleStorage("damaged")
        defer { fixture.cleanUp() }
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

    // MARK: Favourites

    /// Installs the sample `name` as `favourites.json` in `fixture`'s storage and returns its bytes and a library
    /// over the storage (which reads the file at once).
    private func favourites(_ name: String, in fixture: SampleStorage) throws -> (Data, AmbientFavourites) {
        let bytes = try sample(name)
        try fixture.storage.write(bytes, to: AmbientFavourites.fileName)
        let library = AmbientFavourites(storage: fixture.storage, clock: FixedClock(AmbientFixtures.instant))
        return (bytes, library)
    }

    /// Expects `favourites.json` in `fixture`'s storage and the bundled sample `name` to be byte for byte `bytes`.
    private func expectFavouritesUnchanged(_ name: String, _ bytes: Data, in fixture: SampleStorage) throws {
        #expect(try fixture.storage.read(AmbientFavourites.fileName) == bytes, "\(name): stays byte-identical")
        #expect(try sample(name) == bytes, "\(name): the bundled sample stays byte-identical")
    }

    @Test func theCurrentFavouritesSampleLoadsBothEntries() throws {
        let fixture = try SampleStorage("favourites-current")
        defer { fixture.cleanUp() }
        let (bytes, library) = try favourites("favourites-current", in: fixture)
        #expect(library.problems.isEmpty)
        #expect(library.entries.count == 2)
        #expect(library.entries.map(\.id) == [syntheticID(1), syntheticID(2)])
        #expect(library.entries.map(\.name) == ["Evening", "Night shapes"])
        let evening = try ThemePreset(theme: 2, palette: 1, speed: 1.5, motion: true)
        let shapes = try ThemePreset(theme: 3, palette: 2, speed: 0.5, motion: false)
        #expect(library.entries.map(\.preset) == [evening, shapes])
        #expect(try AmbientFavourites.decode(bytes).get() == library.entries)
        library.reload()
        #expect(library.entries.count == 2 && library.problems.isEmpty)
        try expectFavouritesUnchanged("favourites-current", bytes, in: fixture)
    }

    @Test func theNewerAndDamagedFavouritesSamplesReportTheirProblem() throws {
        let cases: [(String, FavouritesProblem, String)] = [("favourites-newer", .newerVersion(2), "newer-version"),
                                                           ("favourites-damaged", .damaged, "damaged")]
        for (name, problem, code) in cases {
            let fixture = try SampleStorage(name)
            defer { fixture.cleanUp() }
            let (bytes, library) = try favourites(name, in: fixture)
            #expect(library.entries.isEmpty, "\(name): an empty list")
            #expect(library.problems == [problem], "\(name)")
            #expect(library.problems.first?.code == code, "\(name)")
            library.reload()
            #expect(library.problems == [problem], "\(name): reported again on reload")
            try expectFavouritesUnchanged(name, bytes, in: fixture)
        }
    }
}
