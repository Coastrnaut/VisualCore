// BinaryGardensSchemaExampleTests — feature 509 (R02-G21-09) T-R02G2109-002 (FR-R02G2109-003; SC-R02G2109-002;
// clarification Q3; data-model.md), modelled on feature 499 (`MushroomWeatherSchemaExampleTests.swift`). Host checks of
// Binary Gardens' stored schema examples (`BinaryGardensSchemaExamples.swift`), which the app registry's migration
// check restores because the snapshot is schema 3 (feature 507):
//   - the schema-1 and schema-2 examples exist, carry versions 1 and 2, decode as `ExperienceSnapshot`s of this
//     experience with schema 1 and 2, seed 2_509 and step 0, and store exactly `schemaExamplePayload(version:)`;
//   - `SnapshotMigrationCheck.problems(for:id:examples:)`, called as the app registry calls it, reports no problem;
//   - restored through `migrations` and `restore(payload:seed:)`: schema 1 gives level 1 with star 2's ring change
//     kept (`star.ring [1, 1]`: star 2 on ring index 1, one action spent, stage playing, not won), campaign mode,
//     frontier 1 and nothing won, the tutorial at its initial step, the sound off; schema 2 gives level 1, campaign
//     mode, frontier 2 and level 1 won with 2 actions spent (the certified count 1 plus one) and 2 stars, unverified,
//     without a trace, nothing dropped (feature 507's reconciliation keeps it), a fresh play's records, the tutorial
//     done and the sound off;
//   - each expected digest equals the digest recomputed from a fresh restore of the migrated payload, and equals the
//     digest pinned here (computed from the code of features 501 … 509 and pinned as built);
//   - versions 0, 3, 4 and -1 give no payload and no example;
//   - building the examples twice gives identical bytes.
// Explicit types, plain loops, short runs (each test well under 10 s). Nothing reads a clock or a random source.
import Foundation
import Testing
@testable import BinaryGardensCore
import VisualCoreExperience

@Suite struct BinaryGardensSchemaExampleTests {
    typealias Core = BinaryGardensExperienceCore

    /// The seed of the stored examples' envelopes (contracts/api.md).
    static let seed: UInt64 = 2_509
    /// The expected digest of the schema-1 example, pinned as built (feature 509).
    static let pinnedSchemaOneDigest: String = "6e86428b1814de1cc7c304232167dba4a2bdef729d180c3eacba1eddd9abe768"
    /// The expected digest of the schema-2 example, pinned as built (feature 509).
    static let pinnedSchemaTwoDigest: String = "b6c2babfb06bc0583faf3db33b94c3d98e50f4d1dabfa56ecdb52936a275680d"

    /// The registered identifier of Binary Gardens.
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

    /// Both examples exist, carry versions 1 and 2, decode as snapshots of this experience at seed 2_509, step 0, and
    /// store exactly the payload `schemaExamplePayload(version:)` builds.
    @Test func bothExamplesExistWithTheirVersionsAndPayloadsAtSeed2509StepZero() throws {
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
            #expect(snapshot.seed == Self.seed)
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

    /// The expected digests equal the digests pinned as built.
    @Test func theExpectedDigestsMatchThePinnedDigests() throws {
        let one: MigrationExample = try #require(Core.schemaOneExample())
        let two: MigrationExample = try #require(Core.schemaTwoExample())
        #expect(one.expectedDigest == Self.pinnedSchemaOneDigest)
        #expect(two.expectedDigest == Self.pinnedSchemaTwoDigest)
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

    /// The schema-1 example restores to level 1 with star 2's ring change kept (`star.ring [1, 1]`, not the certified
    /// first action; one action spent), still playing and not won, campaign mode with nothing won.
    @Test func theSchemaOneExampleRestoresToLevelOneWithStarTwosRingChange() throws {
        let one: MigrationExample = try #require(Core.schemaOneExample())
        let object: [String: Any] = try Self.payloadObject(of: one)
        #expect(Set(object.keys) == ["level", "records"])
        #expect(object["level"] as? Int == 1)
        let core: Core = try Self.restored(one)
        let certified: BinaryGardensGenerated = try Core.generated(number: 1)
        let change: BinaryGardensAction = .ring(star: 1, index: 1)
        #expect(Core.schemaOneExampleAction == change)
        #expect(certified.plan.actions.first != change, "not the certified action")
        #expect(Core.kernelAction("star.ring", [1, 1]) == change, "the control star.ring [1, 1]")
        var expected: BinaryGardensPlay = try Core.freshPlay(of: certified.level)
        let freshCount: Int = expected.records.count
        let startRing: Int = expected.arrangement.rings[1]
        #expect(startRing != 1, "the change moves star 2")
        try expected.apply(change, expecting: expected.fingerprint)
        #expect(core.levelNumber == 1)
        #expect(core.certifiedActionCount == certified.plan.size)
        #expect(core.play.records.count == freshCount + 1)
        let record: BinaryGardensRecord = try #require(core.play.records.last)
        #expect(record.kind == .ring)
        #expect(record.action == change)
        #expect(record.index == freshCount)
        #expect(core.play.records == expected.records)
        #expect(core.play.fingerprint == expected.fingerprint)
        #expect(core.play.arrangement == expected.arrangement)
        #expect(core.play.arrangement.rings[1] == 1)
        #expect(core.play.arrangement.rings[0] == certified.level.start.rings[0], "star 1 unchanged")
        #expect(core.play.actionsSpent == 1)
        #expect(BinaryGardensProgress.actionsSpent(core.play) == 1)
        #expect(core.play.stage == .playing)
        #expect(core.play.stage != .won)
        #expect(core.outcome == nil)
        #expect(core.mode == .campaign)
        #expect(core.progress.frontier == 1)
        #expect(core.progress.isOpen(1))
        #expect(core.progress.isOpen(2) == false)
        #expect(core.progress.solved.isEmpty)
        #expect(core.tutorial == BinaryGardensTutorialStep.initial(level: 1))
        #expect(core.reconciliationDropped == 0)
        #expect(core.soundOn == false)
        let digest: StateDigest = try Self.digest(core)
        #expect(digest.hex == one.expectedDigest)
    }

    /// The schema-2 example restores to level 1 won with 2 actions spent (the certified count 1 plus one) and 2 stars,
    /// unverified and without a trace, kept by reconciliation, with a fresh play's records and the tutorial done.
    @Test func theSchemaTwoExampleRestoresToAWonUnverifiedLevelOne() throws {
        let two: MigrationExample = try #require(Core.schemaTwoExample())
        let object: [String: Any] = try Self.payloadObject(of: two)
        #expect(Set(object.keys) == ["level", "mode", "progress", "records", "tutorial"])
        let core: Core = try Self.restored(two)
        let certified: BinaryGardensGenerated = try Core.generated(number: 1)
        let actions: Int = certified.plan.size
        #expect(actions == 1, "level 1's certified plan is one luminosity change")
        let fresh: BinaryGardensPlay = try Core.freshPlay(of: certified.level)
        #expect(core.certifiedActionCount == actions)
        #expect(core.levelNumber == 1)
        #expect(core.mode == .campaign)
        #expect(core.progress.frontier == 2)
        #expect(core.progress.isOpen(2))
        #expect(core.progress.solved.count == 1)
        let result: BinaryGardensProgress.Result = try #require(core.progress.solved[1])
        #expect(result.actionsSpent == 2)
        #expect(result.actionsSpent == actions + 1)
        #expect(result.stars == 2)
        #expect(result.stars == BinaryGardensProgress.stars(actionsSpent: actions + 1, certified: actions))
        #expect(result.verified == false)
        #expect(result.trace.isEmpty)
        #expect(core.canReplay(level: 1) == false, "an unverified result has no replay")
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
