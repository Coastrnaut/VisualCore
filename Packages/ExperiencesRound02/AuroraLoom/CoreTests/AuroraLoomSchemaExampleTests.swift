// AuroraLoomSchemaExampleTests - feature 309 (R02-G01-09) T-R02G0109-002 (FR-R02G0109-003; clarification Q3;
// data-model.md). Host checks of Aurora Loom's stored schema examples (`AuroraLoomSchemaExamples.swift`), which the app
// registry's migration check restores because the snapshot is schema 3:
//   - the schema-1 and schema-2 examples exist, carry versions 1 and 2 and decode as `ExperienceSnapshot`s of this
//     experience with schema 1 and 2, seed 7 and step 0;
//   - `SnapshotMigrationCheck.problems(for:id:examples:)`, called as the app registry calls it, reports no problem;
//   - restored through `migrations` and `restore(payload:seed:)`: schema 1 gives level 2 with two move records that do
//     not win, campaign mode, frontier 2 and nothing solved; schema 2 gives level 1, campaign mode, frontier 2 and level
//     1 solved at its certified shortest with 3 stars, unverified, with an empty trace and nothing dropped;
//   - each expected digest equals the digest recomputed from the restored core;
//   - versions 0, 3 and 4 give no payload and no example;
//   - building the examples twice gives identical bytes.
// Explicit types, plain loops, short runs. Nothing reads a clock or a random source.
import Foundation
import Testing
@testable import AuroraLoomCore
import VisualCoreExperience

@Suite struct AuroraLoomSchemaExampleTests {
    typealias Core = AuroraLoomExperienceCore

    /// The registered identifier of Aurora Loom.
    static func id() throws -> ExperienceID {
        try #require(ExperienceID(rawValue: Core.experienceID))
    }

    /// The snapshot stored in `example`.
    static func snapshot(of example: MigrationExample) throws -> ExperienceSnapshot {
        try ExperienceSnapshot(data: example.snapshot)
    }

    /// The core restored from `example` the way the engine does: the stored payload migrated from its schema through
    /// `migrations`, then `restore(payload:seed:)` with the snapshot's seed.
    static func restored(_ example: MigrationExample) throws -> Core {
        let snapshot: ExperienceSnapshot = try snapshot(of: example)
        let object: [String: Any] = try #require(
            try JSONSerialization.jsonObject(with: Data(snapshot.payload.utf8)) as? [String: Any])
        let migrated: [String: Any] = try Core.migrations.migrate(object, from: snapshot.schemaVersion)
        let data: Data = try JSONSerialization.data(withJSONObject: migrated, options: [.sortedKeys])
        return try Core.restore(payload: data, seed: snapshot.seed)
    }

    /// The digest of `core` as the engine computes it (domain: the experience identifier).
    static func digest(_ core: Core) throws -> StateDigest {
        var builder: DigestBuilder = DigestBuilder(domain: Core.experienceID)
        try core.writeDigest(into: &builder)
        return builder.finish()
    }

    @Test func bothExamplesExistWithTheirVersionsAndDecodeAsSnapshotsAtSeedSevenStepZero() throws {
        let id: ExperienceID = try Self.id()
        let one: MigrationExample = try #require(Core.schemaOneExample())
        let two: MigrationExample = try #require(Core.schemaTwoExample())
        #expect(one.version == 1)
        #expect(two.version == 2)
        let examples: [MigrationExample] = [one, two]
        var expectedVersion: Int = 1
        for example in examples {
            let snapshot: ExperienceSnapshot = try Self.snapshot(of: example)
            #expect(snapshot.experience == id)
            #expect(snapshot.schemaVersion == expectedVersion)
            #expect(snapshot.seed == 7)
            #expect(snapshot.stepIndex == 0)
            #expect(snapshot.digest.hex == example.expectedDigest)
            #expect(example.expectedDigest.count == 64)
            expectedVersion += 1
        }
        #expect(Core.schemaVersion == 3)
        #expect(Core.migrations.currentVersion == 3)
    }

    @Test func theRegistryCheckReportsNoProblems() async throws {
        let id: ExperienceID = try Self.id()
        let one: MigrationExample = try #require(Core.schemaOneExample())
        let two: MigrationExample = try #require(Core.schemaTwoExample())
        let problems: [String] = await SnapshotMigrationCheck.problems(for: Core.self, id: id, examples: [one, two])
        #expect(problems == [])
        // Without the examples the check names both missing versions.
        let missing: [String] = await SnapshotMigrationCheck.problems(for: Core.self, id: id, examples: [])
        #expect(missing == ["version 1: no stored example", "version 2: no stored example"])
    }

    @Test func theSchemaOneExampleRestoresToLevelTwoWithTwoMovesInCampaign() throws {
        let one: MigrationExample = try #require(Core.schemaOneExample())
        let snapshot: ExperienceSnapshot = try Self.snapshot(of: one)
        let object: [String: Any] = try #require(
            try JSONSerialization.jsonObject(with: Data(snapshot.payload.utf8)) as? [String: Any])
        #expect(Set(object.keys) == ["level", "records"])
        let core: Core = try Self.restored(one)
        #expect(core.levelNumber == 2)
        #expect(core.play.records.count == 2)
        var moves: Int = 0
        for record in core.play.records where record.kind == .move {
            moves += 1
        }
        #expect(moves == 2)
        #expect(core.play.records[0].ribbon == 0 && core.play.records[0].control == .wave)
        #expect(core.play.records[1].ribbon == 1 && core.play.records[1].control == .phase)
        #expect(core.play.stage != .won)
        #expect(core.mode == .campaign)
        #expect(core.progress.frontier == 2)
        #expect(core.progress.solved.isEmpty)
        #expect(core.reconciliationDropped == 0)
        #expect(try Self.digest(core).hex == one.expectedDigest)
    }

    @Test func theSchemaTwoExampleRestoresToASolvedUnverifiedLevelOne() throws {
        let two: MigrationExample = try #require(Core.schemaTwoExample())
        let snapshot: ExperienceSnapshot = try Self.snapshot(of: two)
        let object: [String: Any] = try #require(
            try JSONSerialization.jsonObject(with: Data(snapshot.payload.utf8)) as? [String: Any])
        #expect(Set(object.keys) == ["level", "mode", "progress", "records", "tutorial"])
        let core: Core = try Self.restored(two)
        let shortest: Int = try Core.generated(number: 1).solution.shortest
        #expect(core.levelNumber == 1)
        #expect(core.mode == .campaign)
        #expect(core.progress.frontier == 2)
        #expect(core.progress.solved.count == 1)
        let result: AuroraLoomProgress.Result = try #require(core.progress.solved[1])
        #expect(result.bestMoves == shortest)
        #expect(result.stars == 3)
        #expect(result.verified == false)
        #expect(result.trace.isEmpty)
        #expect(core.reconciliationDropped == 0)
        #expect(core.play.records.isEmpty)
        #expect(core.tutorial == .done)
        #expect(try Self.digest(core).hex == two.expectedDigest)
    }

    @Test func otherVersionsGiveNoPayloadAndNoExample() {
        let versions: [Int] = [0, 3, 4]
        for version in versions {
            #expect(Core.schemaExamplePayload(version: version) == nil, "version \(version)")
            #expect(Core.schemaExample(version: version) == nil, "version \(version)")
        }
    }

    @Test func buildingTheExamplesTwiceGivesIdenticalBytes() throws {
        let versions: [Int] = [1, 2]
        for version in versions {
            let first: MigrationExample = try #require(Core.schemaExample(version: version))
            let second: MigrationExample = try #require(Core.schemaExample(version: version))
            #expect(first == second, "version \(version)")
            #expect(first.snapshot == second.snapshot, "version \(version)")
            #expect(first.expectedDigest == second.expectedDigest, "version \(version)")
        }
        #expect(Core.schemaOneExample() == Core.schemaExample(version: 1))
        #expect(Core.schemaTwoExample() == Core.schemaExample(version: 2))
    }
}
