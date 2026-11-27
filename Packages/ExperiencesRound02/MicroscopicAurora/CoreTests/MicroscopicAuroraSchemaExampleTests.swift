// MicroscopicAuroraSchemaExampleTests — feature 489 (R02-G19-09) T-R02G1909-002 (FR-R02G1909-003; SC-R02G1909-002;
// clarification Q3; data-model.md), modelled on feature 479 (`ApsidesWorkshopSchemaExampleTests.swift`). Host checks
// of Microscopic Aurora's stored schema examples (`MicroscopicAuroraSchemaExamples.swift`), which the app registry's
// migration check restores because the snapshot is schema 3 (feature 487):
//   - the schema-1 and schema-2 examples exist, carry versions 1 and 2, decode as `ExperienceSnapshot`s of this
//     experience with schema 1 and 2, seed 7 and step 0, and store exactly `schemaExamplePayload(version:)`;
//   - `SnapshotMigrationCheck.problems(for:id:examples:)`, called as the app registry calls it, reports no problem;
//   - restored through `migrations` and `restore(payload:seed:)`: schema 1 gives level 1 with the first certified
//     placement kept (the certified plan's first action, one action spent, stage playing, not won), campaign mode,
//     frontier 1 and nothing won, the tutorial at its initial step, the sound off; schema 2 gives level 1, campaign
//     mode, frontier 2 and level 1 won at its certified placement count plus one with its stars (fewer than 3),
//     unverified, without a trace, nothing dropped (feature 487's reconciliation keeps it), a fresh play's records,
//     the tutorial done and the sound off;
//   - each expected digest equals the digest recomputed from a fresh restore of the migrated payload;
//   - versions 0, 3, 4 and -1 give no payload and no example;
//   - building the examples twice gives identical bytes.
// Explicit types, plain loops, short runs (each test well under 10 s). Nothing reads a clock or a random source.
import Foundation
import Testing
@testable import MicroscopicAuroraCore
import VisualCoreExperience

@Suite struct MicroscopicAuroraSchemaExampleTests {
    typealias Core = MicroscopicAuroraExperienceCore

    /// The registered identifier of Microscopic Aurora.
    static func id() throws -> ExperienceID {
        try #require(ExperienceID(rawValue: Core.experienceID))
    }

    /// The snapshot stored in `example`.
    static func snapshot(of example: MigrationExample) throws -> ExperienceSnapshot {
        try ExperienceSnapshot(data: example.snapshot)
    }

    /// The stored payload of `example` as a JSON object.
    static func payloadObject(of example: MigrationExample) throws -> [String: Any] {
        let snapshot: ExperienceSnapshot = try snapshot(of: example)
        let json: Any = try JSONSerialization.jsonObject(with: Data(snapshot.payload.utf8))
        return try #require(json as? [String: Any])
    }

    /// `object` serialized with sorted keys (a canonical form for comparing JSON objects).
    static func canonical(_ object: [String: Any]) throws -> Data {
        try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    }

    /// The core restored from `example` the way the engine does: the stored payload migrated from its schema through
    /// `migrations`, then `restore(payload:seed:)` with the snapshot's seed.
    static func restored(_ example: MigrationExample) throws -> Core {
        let snapshot: ExperienceSnapshot = try snapshot(of: example)
        let object: [String: Any] = try payloadObject(of: example)
        let migrated: [String: Any] = try Core.migrations.migrate(object, from: snapshot.schemaVersion)
        let data: Data = try canonical(migrated)
        return try Core.restore(payload: data, seed: snapshot.seed)
    }

    /// The digest of `core` as the engine computes it (domain: the experience identifier).
    static func digest(_ core: Core) throws -> StateDigest {
        var builder: DigestBuilder = DigestBuilder(domain: Core.experienceID)
        try core.writeDigest(into: &builder)
        return builder.finish()
    }

    /// Both examples exist, carry versions 1 and 2, decode as snapshots of this experience at seed 7, step 0, and
    /// store exactly the payload `schemaExamplePayload(version:)` builds.
    @Test func bothExamplesExistWithTheirVersionsAndPayloadsAtSeedSevenStepZero() throws {
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
            let stored: [String: Any] = try Self.payloadObject(of: example)
            let built: [String: Any] = try #require(Core.schemaExamplePayload(version: expectedVersion))
            let storedData: Data = try Self.canonical(stored)
            let builtData: Data = try Self.canonical(built)
            #expect(storedData == builtData, "version \(expectedVersion)")
            expectedVersion += 1
        }
        #expect(one.expectedDigest != two.expectedDigest)
        #expect(Core.schemaVersion == 3)
        #expect(Core.migrations.currentVersion == 3)
    }

    /// Each stored payload migrates to a schema-3 object (progress with a solved list, a mode, the sound off) and
    /// restores to level 1 with the expected digest.
    @Test func eachPayloadMigratesToSchemaThreeAndRestores() throws {
        let versions: [Int] = [1, 2]
        for version in versions {
            let example: MigrationExample = try #require(Core.schemaExample(version: version))
            let object: [String: Any] = try Self.payloadObject(of: example)
            let migrated: [String: Any] = try Core.migrations.migrate(object, from: version)
            let progress: [String: Any] = try #require(migrated["progress"] as? [String: Any], "version \(version)")
            #expect(progress["solved"] != nil, "version \(version)")
            #expect(migrated["mode"] != nil, "version \(version)")
            #expect(migrated["sound"] as? Bool == false, "version \(version)")
            let core: Core = try Self.restored(example)
            #expect(core.levelNumber == 1, "version \(version)")
            let digest: StateDigest = try Self.digest(core)
            #expect(digest.hex == example.expectedDigest, "version \(version)")
        }
    }

    /// The registry's migration check reports no problem with both examples and names both versions without them.
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

    /// The schema-1 example restores to level 1 with the first certified placement kept (the certified plan's first
    /// action; one action spent), still playing and not won, campaign mode with nothing won.
    @Test func theSchemaOneExampleRestoresToLevelOneWithTheFirstCertifiedWell() throws {
        let one: MigrationExample = try #require(Core.schemaOneExample())
        let object: [String: Any] = try Self.payloadObject(of: one)
        #expect(Set(object.keys) == ["level", "records"])
        #expect(object["level"] as? Int == 1)
        let core: Core = try Self.restored(one)
        let certified: MicroscopicAuroraGenerated = try Core.generated(number: 1)
        let first: MicroscopicAuroraAction = try #require(certified.plan.actions.first)
        var expected: MicroscopicAuroraPlay = try Core.freshPlay(of: certified.level)
        let freshCount: Int = expected.records.count
        try expected.apply(first, expecting: expected.fingerprint)
        #expect(core.levelNumber == 1)
        #expect(core.certifiedPlacements == certified.plan.size)
        #expect(core.play.records.count == freshCount + 1)
        let record: MicroscopicAuroraRecord = try #require(core.play.records.last)
        #expect(record.kind == .place)
        #expect(record.action == first)
        #expect(record.index == freshCount)
        #expect(core.play.records == expected.records)
        #expect(core.play.fingerprint == expected.fingerprint)
        #expect(core.play.wells == expected.wells)
        #expect(core.play.placedWells.count == 1)
        #expect(core.play.actionsSpent == 1)
        #expect(MicroscopicAuroraProgress.actionsSpent(core.play) == 1)
        #expect(core.play.stage == .playing)
        #expect(core.play.stage != .won)
        #expect(core.outcome == nil)
        #expect(core.mode == .campaign)
        #expect(core.progress.frontier == 1)
        #expect(core.progress.isOpen(1))
        #expect(core.progress.isOpen(2) == false)
        #expect(core.progress.solved.isEmpty)
        #expect(core.tutorial == MicroscopicAuroraTutorialStep.initial(level: 1))
        #expect(core.reconciliationDropped == 0)
        #expect(core.soundOn == false)
        let digest: StateDigest = try Self.digest(core)
        #expect(digest.hex == one.expectedDigest)
    }

    /// The schema-2 example restores to level 1 won at the certified placement count plus one with its stars,
    /// unverified and without a trace, kept by reconciliation, with a fresh play's records and the tutorial done.
    @Test func theSchemaTwoExampleRestoresToAWonUnverifiedLevelOne() throws {
        let two: MigrationExample = try #require(Core.schemaTwoExample())
        let object: [String: Any] = try Self.payloadObject(of: two)
        #expect(Set(object.keys) == ["level", "mode", "progress", "records", "tutorial"])
        let core: Core = try Self.restored(two)
        let certified: MicroscopicAuroraGenerated = try Core.generated(number: 1)
        let placements: Int = certified.plan.size
        #expect(placements >= 1)
        let fresh: MicroscopicAuroraPlay = try Core.freshPlay(of: certified.level)
        #expect(core.certifiedPlacements == placements)
        #expect(core.levelNumber == 1)
        #expect(core.mode == .campaign)
        #expect(core.progress.frontier == 2)
        #expect(core.progress.isOpen(2))
        #expect(core.progress.solved.count == 1)
        let result: MicroscopicAuroraProgress.Result = try #require(core.progress.solved[1])
        #expect(result.actionsSpent == placements + 1)
        #expect(result.stars == MicroscopicAuroraProgress.stars(actionsSpent: placements + 1, certified: placements))
        #expect(result.stars < 3)
        #expect(result.verified == false)
        #expect(result.trace.isEmpty)
        #expect(core.reconciliationDropped == 0)
        #expect(core.play.records == fresh.records)
        #expect(core.play.actionsSpent == 0)
        #expect(core.play.stage == fresh.stage)
        #expect(core.tutorial == .done)
        #expect(core.soundOn == false)
        let digest: StateDigest = try Self.digest(core)
        #expect(digest.hex == two.expectedDigest)
    }

    /// Versions other than 1 and 2 give no payload and no example.
    @Test func otherVersionsGiveNoPayloadAndNoExample() {
        let versions: [Int] = [0, 3, 4, -1]
        for version in versions {
            #expect(Core.schemaExamplePayload(version: version) == nil, "version \(version)")
            #expect(Core.schemaExample(version: version) == nil, "version \(version)")
        }
    }

    /// Building the examples twice gives identical bytes and digests.
    @Test func buildingTheExamplesTwiceGivesIdenticalBytes() throws {
        let versions: [Int] = [1, 2]
        for version in versions {
            let first: MigrationExample = try #require(Core.schemaExample(version: version))
            let second: MigrationExample = try #require(Core.schemaExample(version: version))
            #expect(first == second, "version \(version)")
            #expect(first.snapshot == second.snapshot, "version \(version)")
            #expect(first.expectedDigest == second.expectedDigest, "version \(version)")
            let payloadOne: [String: Any] = try #require(Core.schemaExamplePayload(version: version))
            let payloadTwo: [String: Any] = try #require(Core.schemaExamplePayload(version: version))
            let dataOne: Data = try Self.canonical(payloadOne)
            let dataTwo: Data = try Self.canonical(payloadTwo)
            #expect(dataOne == dataTwo, "version \(version)")
        }
        #expect(Core.schemaOneExample() == Core.schemaExample(version: 1))
        #expect(Core.schemaTwoExample() == Core.schemaExample(version: 2))
    }
}
