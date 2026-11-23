// HarmonicBridgesSchemaExampleTests — feature 419 (R02-G12-09) T-R02G1209-002 (FR-R02G1209-003, SC-R02G1209-002;
// clarification Q3; data-model.md). Host checks of Harmonic Bridges' stored schema examples
// (`HarmonicBridgesSchemaExamples.swift`), which the app registry's migration check restores because the snapshot is
// schema 3 (feature 417), ported from Echo Cartographer's (`EchoCartographerSchemaExampleTests.swift`, feature 409):
//   - the schema-1 and schema-2 examples exist, carry versions 1 and 2, decode as `ExperienceSnapshot`s of this
//     experience with schema 1 and 2, seed 7 and step 0, and store exactly `schemaExamplePayload(version:)`;
//   - `SnapshotMigrationCheck.problems(for:id:examples:)`, called as the app registry calls it, reports no problem;
//   - restored through `migrations` and `restore(payload:seed:)`: schema 1 gives level 1 with its one tuning kept (the
//     first action of the certified witness, one action spent, stage playing, not won), campaign mode, frontier 1 and
//     nothing won, the tutorial at its initial step, the sound off; schema 2 gives level 1, campaign mode, frontier 2
//     and level 1 won at its certified action count plus one with its stars (2), unverified, without a trace, nothing
//     dropped (feature 417's reconciliation keeps it), the tutorial done and the sound off;
//   - each expected digest equals the digest recomputed from the restored core;
//   - versions 0, 3, 4 and -1 give no payload and no example;
//   - building the examples twice gives identical bytes.
// Explicit types, plain loops, short runs. Nothing reads a clock or a random source.
import Foundation
import Testing
@testable import HarmonicBridgesCore
import VisualCoreExperience

@Suite struct HarmonicBridgesSchemaExampleTests {
    typealias Core = HarmonicBridgesExperienceCore

    /// The registered identifier of Harmonic Bridges.
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
        return try #require(try JSONSerialization.jsonObject(with: Data(snapshot.payload.utf8)) as? [String: Any])
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
            #expect(try Self.canonical(stored) == Self.canonical(built), "version \(expectedVersion)")
            expectedVersion += 1
        }
        #expect(Core.schemaVersion == 3)
        #expect(Core.migrations.currentVersion == 3)
    }

    /// Each stored payload migrates to a schema-3 object (progress with a solved list, a mode, the sound off) and
    /// restores to level 1.
    @Test func eachPayloadMigratesToSchemaThreeAndRestores() throws {
        let versions: [Int] = [1, 2]
        for version in versions {
            let example: MigrationExample = try #require(Core.schemaExample(version: version))
            let object: [String: Any] = try Self.payloadObject(of: example)
            let migrated: [String: Any] = try Core.migrations.migrate(object, from: version)
            let progress: [String: Any] = try #require(migrated["progress"] as? [String: Any], "version \(version)")
            #expect(progress["solved"] is [Any], "version \(version)")
            #expect(migrated["mode"] != nil, "version \(version)")
            #expect(migrated["sound"] as? Bool == false, "version \(version)")
            let core: Core = try Self.restored(example)
            #expect(core.levelNumber == 1, "version \(version)")
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

    /// The schema-1 example restores to level 1 with its one tuning (the certified witness's first action) kept, still
    /// playing.
    @Test func theSchemaOneExampleRestoresToLevelOneWithItsOneTuning() throws {
        let one: MigrationExample = try #require(Core.schemaOneExample())
        let object: [String: Any] = try Self.payloadObject(of: one)
        #expect(Set(object.keys) == ["level", "records"])
        #expect(object["level"] as? Int == 1)
        let core: Core = try Self.restored(one)
        let certified: HarmonicBridgesGenerated = try Core.generated(number: 1)
        #expect(certified.plan.tunings.count >= 1)
        let first: HarmonicBridgesAction = try #require(certified.actions.first)
        if case .tune = first {} else { Issue.record("the certified witness's first action is not a tuning") }
        var expected: HarmonicBridgesPlay = try Core.freshPlay(of: certified.level)
        try expected.apply(first, expecting: expected.fingerprint)
        #expect(core.levelNumber == 1)
        #expect(core.play.records.count == 1)
        let record: HarmonicBridgesRecord = try #require(core.play.records.first)
        #expect(record.kind == .tune)
        #expect(record.action == first)
        #expect(record.index == 0)
        #expect(core.play == expected)
        #expect(core.play.records == expected.records)
        #expect(core.play.fingerprint == expected.fingerprint)
        #expect(core.play.actionsSpent == 1)
        #expect(core.play.stage == .playing)
        #expect(core.play.stage != .won)
        #expect(core.outcome == nil)
        #expect(core.mode == .campaign)
        #expect(core.progress.frontier == 1)
        #expect(core.progress.isOpen(1))
        #expect(core.progress.isOpen(2) == false)
        #expect(core.progress.solved.isEmpty)
        #expect(core.tutorial == HarmonicBridgesTutorialStep.initial(level: 1))
        #expect(core.reconciliationDropped == 0)
        #expect(core.soundOn == false)
        #expect(try Self.digest(core).hex == one.expectedDigest)
    }

    /// The schema-2 example restores to level 1 won at the certified action count plus one with its stars, unverified
    /// and without a trace, kept by reconciliation, with the tutorial done.
    @Test func theSchemaTwoExampleRestoresToAWonUnverifiedLevelOne() throws {
        let two: MigrationExample = try #require(Core.schemaTwoExample())
        let object: [String: Any] = try Self.payloadObject(of: two)
        #expect(Set(object.keys) == ["level", "mode", "progress", "records", "tutorial"])
        let core: Core = try Self.restored(two)
        let actions: Int = try Core.generated(number: 1).actions.count
        #expect(core.certifiedActions == actions)
        #expect(core.levelNumber == 1)
        #expect(core.mode == .campaign)
        #expect(core.progress.frontier == 2)
        #expect(core.progress.isOpen(2))
        #expect(core.progress.solved.count == 1)
        let result: HarmonicBridgesProgress.Result = try #require(core.progress.solved[1])
        #expect(result.actionsSpent == actions + 1)
        #expect(result.stars == HarmonicBridgesProgress.stars(actionsSpent: actions + 1, certified: actions))
        #expect(result.stars == 2)
        #expect(result.verified == false)
        #expect(result.trace.isEmpty)
        #expect(core.reconciliationDropped == 0)
        #expect(core.play.records.isEmpty)
        #expect(core.tutorial == .done)
        #expect(core.soundOn == false)
        #expect(try Self.digest(core).hex == two.expectedDigest)
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
            #expect(try Self.canonical(payloadOne) == Self.canonical(payloadTwo), "version \(version)")
        }
        #expect(Core.schemaOneExample() == Core.schemaExample(version: 1))
        #expect(Core.schemaTwoExample() == Core.schemaExample(version: 2))
    }
}
