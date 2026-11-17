// SnapshotMigrationTests — feature 140 (A19-P03) T-A19-304 (FR-A19-301; SC-A19-301; clarification Q1;
// contracts/editor.md "Schemas"; data-model.md "WallpaperCore snapshot schema 2"). The snapshot of Living Wallpapers
// is schema 2:
//   - the stored schema-1 example (`WallpaperCore.schemaOneExample()`) is accepted by the registry's
//     `SnapshotMigrationCheck`, and the schema-2 example is refused there as "not an earlier version";
//   - the schema-1 example holds exactly the eight A19-P02 keys, restores as schema 2 with `custom` 0 and the preset's
//     colours (every other field kept) and matches its expected digest; a schema-1 payload handed to the restore
//     without the migration is refused;
//   - the schema-2 example round-trips through two engines with its digest and keeps its edited colour;
//   - a snapshot of a newer schema is refused and changes nothing.
import Foundation
import Testing
import LivingWallpapersCore
@testable import LivingWallpapersExperience
import VisualCoreExperience

@MainActor
@Suite struct SnapshotMigrationTests {
    @Test func theSchemaIsTwoAndTheSchemaOneExampleIsAcceptedByTheRegistryCheck() async throws {
        #expect(WallpaperCore.schemaVersion == 2)
        #expect(WallpaperCore.migrations.currentVersion == 2)
        #expect(WallpaperCore.digestDomain == "a19.wallpaper.v2")
        let one = try #require(WallpaperCore.schemaOneExample())
        #expect(one.version == 1)
        let problems = await SnapshotMigrationCheck.problems(for: WallpaperCore.self, id: WallpaperTest.id,
                                                              examples: [one])
        #expect(problems == [])
        let two = try #require(WallpaperCore.schemaTwoExample())
        #expect(two.version == 2)
        let refused = await SnapshotMigrationCheck.problems(for: WallpaperCore.self, id: WallpaperTest.id,
                                                             examples: [one, two])
        #expect(refused == ["version 2: not an earlier version (current is 2)"])
        #expect(WallpaperCore.schemaExample(version: 3) == nil)
        #expect(WallpaperCore.schemaExamplePayload(version: 0) == nil)
    }

    @Test func theSchemaOneExampleRestoresAsSchemaTwoWithCustomZero() async throws {
        let one = try #require(WallpaperCore.schemaOneExample())
        let snapshot = try ExperienceSnapshot(data: one.snapshot)
        #expect(snapshot.schemaVersion == 1)
        let payload = try #require(try JSONSerialization.jsonObject(with: Data(snapshot.payload.utf8))
            as? [String: Any])
        #expect(Set(payload.keys) == WallpaperCore.schemaOneKeys)
        var engine = try await WallpaperTest.engine(seed: snapshot.seed)
        try engine.restore(snapshot)
        let core = try #require(engine.core)
        #expect(core.custom == 0)
        #expect(core.colors == WallpaperCore.presetComponents(scene: 1, preset: 2))
        #expect(core.scene == 1 && core.preset == 2 && core.parameters == [1.2, 2.5, 0.4])
        #expect(core.template == 5 && core.orientation == 1 && core.animationTime == 42.5)
        #expect(core.format == 1 && !core.motion && core.seed == 7)
        #expect(try engine.digest().hex == one.expectedDigest)
        #expect(core.project.customColors == nil)
        // After the migration the state is written as schema 2.
        let written = try core.snapshotPayload()
        let object = try #require(try JSONSerialization.jsonObject(with: written) as? [String: Any])
        #expect(Set(object.keys) == WallpaperCore.schemaOneKeys.union(["colors", "custom"]))
        #expect(object["custom"] as? Int == 0)
    }

    @Test func aSchemaOnePayloadNeedsTheMigration() throws {
        let one = try #require(WallpaperCore.schemaOneExample())
        let snapshot = try ExperienceSnapshot(data: one.snapshot)
        #expect(throws: (any Error).self) {
            _ = try WallpaperCore.restore(payload: Data(snapshot.payload.utf8), seed: 7)
        }
    }

    @Test func theSchemaTwoExampleRoundTripsThroughTwoEngines() async throws {
        let two = try #require(WallpaperCore.schemaTwoExample())
        let snapshot = try ExperienceSnapshot(data: two.snapshot)
        #expect(snapshot.schemaVersion == 2)
        var first = try await WallpaperTest.engine(seed: snapshot.seed)
        try first.restore(snapshot)
        let core = try #require(first.core)
        let edit = WallpaperCore.schemaTwoEditedSlot
        #expect(core.custom == 1)
        #expect(core.colors[(edit.slot * 3)...(edit.slot * 3 + 2)] == [edit.r, edit.g, edit.b])
        #expect(core.scene == 1 && core.preset == 2)
        #expect(try first.digest().hex == two.expectedDigest)
        let colours = try #require(core.project.customColors)
        #expect(colours[edit.slot] == RGBColor(r: edit.r, g: edit.g, b: edit.b))
        let again = try first.snapshot()
        var second = try await WallpaperTest.engine(seed: snapshot.seed)
        try second.restore(again)
        #expect(second.core == first.core)
        #expect(try second.digest() == first.digest())
        let payload = try core.snapshotPayload()
        let restored = try WallpaperCore.restore(payload: payload, seed: 7)
        #expect(try restored.snapshotPayload() == payload)
        #expect(try wallpaperDigest(restored) == wallpaperDigest(core))
    }

    @Test func theDigestWritesTheColoursOnlyWhileCustom() throws {
        let base = WallpaperCore()
        let (edited, accepted) = wallpaperApplied(base, "preset.color", [0, 0.5, 0.5, 0.5])
        #expect(accepted == .accepted)
        let (reset, _) = wallpaperApplied(edited, "preset.reset", [])
        #expect(try wallpaperDigest(edited) != wallpaperDigest(base))
        #expect(try wallpaperDigest(reset) == wallpaperDigest(base))
        let (other, _) = wallpaperApplied(edited, "preset.color", [0, 0.5, 0.5, 0.6])
        #expect(try wallpaperDigest(other) != wallpaperDigest(edited))
    }

    @Test func aNewerSchemaIsRefusedAndChangesNothing() async throws {
        let two = try #require(WallpaperCore.schemaTwoExample())
        let current = try ExperienceSnapshot(data: two.snapshot)
        let newer = try ExperienceSnapshot(experience: WallpaperTest.id, schemaVersion: 3, seed: current.seed,
                                           stepIndex: 0, digest: current.digest, payload: Data(current.payload.utf8))
        var engine = try await WallpaperTest.engine(seed: current.seed)
        let before = try #require(engine.core)
        let digest = try engine.digest()
        #expect(throws: (any Error).self) { try engine.restore(newer) }
        #expect(engine.core == before)
        #expect(try engine.digest() == digest)
    }
}
