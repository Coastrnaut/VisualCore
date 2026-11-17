// StoredSampleTests — feature 157 (A21-P06) T-A21-605 (FR-A21-604; clarification Q4; contracts/release.md
// "Samples"). The committed sample files under `ExperienceTests/Fixtures` are answered by the code that reads them in
// the app. They were written once through the real encoders (`ExperienceEngine.snapshot()` with
// `ExperienceSnapshot.encoded()`, and `SkyPreferences.encoded()`):
//   - `snapshot-v1.json`: the encoded snapshot (seed 7, step 0, schema 1) of Violet veil with hue 0.1 and limit 0.5,
//     whose payload is that core's `SkyCore.snapshotPayload()` and whose digest is its engine digest; it restores;
//   - `snapshot-newer.json` (the same payload in an envelope of schema 2) is refused as `snapshot.newer-schema` and
//     `snapshot-damaged.json` (the v1 file cut in half) as `snapshot.corrupt`; neither changes the core;
//   - `prefs-current.json` (the envelope `a21.preferences` version 1: Violet veil, sound on, volume 0.4) opens with its
//     values; `prefs-newer.json` (the same body, version 2), `prefs-damaged.json` (the current value cut in half) and
//     `prefs-out-of-range.json` (volume 3) open with the defaults and the refusals `newer-version`, `damaged` and
//     `out-of-range`.
// Snapshot samples are copied into a temporary experience storage as files, preference samples as the experience value
// `prefs.v1` (`AuroraTest.storage()`, removed afterwards), and read from there; afterwards the stored copy and the
// bundled sample are both byte for byte the sample. No UUID and no path appears in any sample. A fake loop
// (``FakeLoops``) keeps the sound silent. Short runs only (well under 10 s, no sleep, no wall-clock assertion), no
// prompt, no network.
import Foundation
import Testing
import AuroraCore
@testable import AuroraExperience
import VisualCoreExperience
import VisualCoreExperienceHost

/// The bytes of the bundled sample `name` (without extension).
private func sample(_ name: String) throws -> Data {
    let url = try #require(Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures"),
                           "missing Fixtures/\(name).json")
    return try Data(contentsOf: url)
}

@MainActor
@Suite(.serialized) struct StoredSampleTests {
    // MARK: Helpers

    /// Copies the sample `name` into `storage` as the file `name.json` and returns its bytes.
    private func installFile(_ name: String, in storage: ExperienceStorage) throws -> Data {
        let bytes = try sample(name)
        try storage.write(bytes, to: name + ".json")
        #expect(try storage.read(name + ".json") == bytes, "\(name): the stored copy is the sample")
        return bytes
    }

    /// Expects the stored file `name.json` of `storage` and the bundled sample `name` to be byte for byte `bytes`, and
    /// the storage to hold only that file.
    private func expectFileUnchanged(_ name: String, _ bytes: Data, in storage: ExperienceStorage,
                                     sourceLocation: SourceLocation = #_sourceLocation) throws {
        #expect(try storage.read(name + ".json") == bytes, "\(name): stays byte-identical",
                sourceLocation: sourceLocation)
        #expect(try sample(name) == bytes, "\(name): the bundled sample stays byte-identical",
                sourceLocation: sourceLocation)
        #expect(storage.list() == [name + ".json"], "no file is added or removed", sourceLocation: sourceLocation)
    }

    /// Copies the sample `name` into `storage` as the experience value `prefs.v1` and returns its bytes.
    private func installPreferences(_ name: String, in storage: ExperienceStorage) throws -> Data {
        let bytes = try sample(name)
        try storage.setValue(bytes, for: SkyPreferences.storageKey)
        #expect(storage.value(for: SkyPreferences.storageKey) == bytes, "\(name): the stored copy is the sample")
        return bytes
    }

    /// Expects `prefs.v1` of `storage` and the bundled sample `name` to be byte for byte `bytes`.
    private func expectPreferencesUnchanged(_ name: String, _ bytes: Data, in storage: ExperienceStorage,
                                            sourceLocation: SourceLocation = #_sourceLocation) throws {
        #expect(storage.value(for: SkyPreferences.storageKey) == bytes, "\(name): stays byte-identical",
                sourceLocation: sourceLocation)
        #expect(try sample(name) == bytes, "\(name): the bundled sample stays byte-identical",
                sourceLocation: sourceLocation)
    }

    // MARK: Snapshots

    @Test func theSchemaOneSnapshotSampleRestores() async throws {
        let place = try AuroraTest.storage()
        defer { place.cleanUp() }
        let stored = try installFile("snapshot-v1", in: place.storage)
        let bytes = try place.storage.read("snapshot-v1.json")
        let snapshot = try ExperienceSnapshot(data: bytes)
        #expect(snapshot.experience == AuroraTest.id)
        #expect(snapshot.schemaVersion == 1 && snapshot.seed == 7 && snapshot.stepIndex == 0)
        #expect(try snapshot.encoded() == bytes, "the sample is in the encoded form")

        var engine = try await AuroraTest.engine(seed: snapshot.seed)
        try engine.restore(snapshot)
        let core = try #require(engine.core)
        #expect(try engine.digest() == snapshot.digest, "the digest of the restored sky is the sample's")
        #expect(try skyDigest(core) == snapshot.digest.hex)
        #expect(core.scene == SkyPresets.violetVeil.scene && core.hue == 0.1 && core.limit == 0.5)
        #expect(try core.snapshotPayload() == Data(snapshot.payload.utf8), "written back as the same payload")
        try expectFileUnchanged("snapshot-v1", stored, in: place.storage)
    }

    @Test func theNewerSnapshotSampleIsRefusedAndChangesNothing() async throws {
        let place = try AuroraTest.storage()
        defer { place.cleanUp() }
        let stored = try installFile("snapshot-newer", in: place.storage)
        let snapshot = try ExperienceSnapshot(data: try place.storage.read("snapshot-newer.json"))
        #expect(snapshot.schemaVersion == 2)
        var engine = try await AuroraTest.engine(seed: 7)
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
        try expectFileUnchanged("snapshot-newer", stored, in: place.storage)
    }

    @Test func theDamagedSnapshotSampleIsRefused() throws {
        let place = try AuroraTest.storage()
        defer { place.cleanUp() }
        let stored = try installFile("snapshot-damaged", in: place.storage)
        let bytes = try place.storage.read("snapshot-damaged.json")
        var refusal: SnapshotError?
        do {
            _ = try ExperienceSnapshot(data: bytes)
        } catch {
            refusal = error
        }
        let refused = try #require(refusal, "the damaged sample is refused before any restore")
        #expect(refused.code == "snapshot.corrupt")
        try expectFileUnchanged("snapshot-damaged", stored, in: place.storage)
    }

    // MARK: Preferences

    @Test func theCurrentPreferencesSampleOpensWithItsValues() async throws {
        let place = try AuroraTest.storage()
        defer { place.cleanUp() }
        let stored = try installPreferences("prefs-current", in: place.storage)
        let expected = SkyPreferences(scene: SkyPresets.violetVeil.scene, soundOn: true, volume: 0.4)
        #expect(try SkyPreferences.decode(stored).get() == expected)
        #expect(expected.encoded() == stored, "the sample is in the encoded form")
        let loops = FakeLoops()
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await AuroraTest.open(session, storage: place.storage, loopFactory: loops.factory)
        try AuroraTest.draw(session, frames: 2)
        let presenter = shell.presenter
        #expect(presenter.preferencesRefusal == nil && presenter.mirror.message == nil)
        #expect(presenter.preferences == expected)
        #expect(try AuroraTest.core(shell).scene == SkyPresets.violetVeil.scene, "it opens on Violet veil")
        #expect(presenter.mirror.soundOn && presenter.mirror.volume == 0.4, "sound on at volume 0.4")
        try expectPreferencesUnchanged("prefs-current", stored, in: place.storage)
    }

    @Test func theNewerDamagedAndOutOfRangePreferencesSamplesOpenTheDefaults() async throws {
        let cases: [(String, String)] = [("prefs-newer", "newer-version"), ("prefs-damaged", "damaged"),
                                         ("prefs-out-of-range", "out-of-range")]
        for (name, code) in cases {
            let place = try AuroraTest.storage()
            defer { place.cleanUp() }
            let stored = try installPreferences(name, in: place.storage)
            if case .failure(let refusal) = SkyPreferences.decode(stored) {
                #expect(refusal.code == code, "\(name)")
            } else {
                Issue.record("\(name): the sample decodes")
            }
            let loops = FakeLoops()
            let session = ExperienceSession()
            defer { session.close() }
            let shell = try await AuroraTest.open(session, storage: place.storage, loopFactory: loops.factory)
            try AuroraTest.draw(session, frames: 2)
            let presenter = shell.presenter
            #expect(presenter.preferencesRefusal?.code == code, "\(name)")
            #expect(presenter.preferences == .defaults, "\(name)")
            #expect(presenter.mirror.message == AuroraPresenter.readFailedMessage, "\(name)")
            #expect(try AuroraTest.core(shell) == SkyCore(), "\(name): the default sky")
            #expect(!presenter.mirror.soundOn && presenter.mirror.volume == 0.5, "\(name): sound off, volume 0.5")
            try expectPreferencesUnchanged(name, stored, in: place.storage)
        }
    }
}
