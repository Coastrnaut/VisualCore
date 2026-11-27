// BinaryGardensSchemaExamples — feature 509 (R02-G21-09) T-R02G2109-002 (FR-R02G2109-003, SC-R02G2109-002;
// clarification Q3; research R3; data-model.md; contracts/api.md). Binary Gardens' snapshot is schema 3 (feature 507),
// so the app registry's migration check stores one example of each earlier schema, built as Mushroom Weather's are
// (`MushroomWeatherSchemaExamples.swift`, feature 499): a payload of that schema in an envelope of that schema at step
// 0 with seed 2_509, and the digest its restore through the migration chain (1 → 2, feature 505; 2 → 3, feature 507)
// gives.
//   schema 1: `{level: 1, records}` — a play of certified level 1 with one accepted arrangement action other than the
//             certified one: star 2's ring change `star.ring [1, 1]` (0-based star 1 to ring index 1; on level 1 only
//             star 2's ring and luminosity are adjustable and the certified plan is one luminosity change). An
//             arrangement action never ends the level, so the play is still playing and not won;
//   schema 2: `{level: 1, mode: {mode: campaign}, progress: {frontier: 2, solved: [level 1 with 2 actions spent, one
//             above its certified action count of 1 (the plan's arrangement actions, the run not counted), with its 2
//             stars]}, records: <a fresh play's>, tutorial: done}` — a won level written before traces existed
//             (restored unverified, without a trace; feature 507's reconciliation keeps such results). A fresh play
//             already holds its begin and tutorial-dismissal records, so those are its records.
// Nothing here reads a clock or a random source.
import Foundation
import VisualCoreExperience

extension BinaryGardensExperienceCore {
    /// The arrangement action of the schema-1 example: star 2 (0-based star 1) to ring index 1, `star.ring [1, 1]`.
    static let schemaOneExampleAction: BinaryGardensAction = .ring(star: 1, index: 1)

    /// The payload of the stored example of schema `version` (1 or 2; see the file header); nil for any other version,
    /// when certified level 1 cannot be generated or when the kernel refuses the schema-1 action.
    public static func schemaExamplePayload(version: Int) -> [String: Any]? {
        switch version {
        case 1:
            guard let certified = try? generated(number: 1), certified.plan.actions.first != schemaOneExampleAction,
                  var play = try? freshPlay(of: certified.level) else { return nil }
            do throws(BinaryGardensError) {
                try play.apply(schemaOneExampleAction, expecting: play.fingerprint)
            } catch {
                return nil
            }
            guard play.stage == .playing, let records = schemaExampleJSON(play.records) else { return nil }
            return ["level": 1, "records": records]
        case 2:
            guard let certified = try? generated(number: 1),
                  let mode = schemaExampleJSON(BinaryGardensMode.campaign),
                  let tutorial = schemaExampleJSON(BinaryGardensTutorialStep.done) else { return nil }
            guard let fresh = try? freshPlay(of: certified.level),
                  let records = schemaExampleJSON(fresh.records) else { return nil }
            let actions: Int = certified.plan.size
            let actionsSpent: Int = actions + 1
            let stars: Int = BinaryGardensProgress.stars(actionsSpent: actionsSpent, certified: actions)
            let solved: [[String: Any]] = [["actionsSpent": actionsSpent, "level": 1, "stars": stars]]
            return ["level": 1, "mode": mode, "progress": ["frontier": 2, "solved": solved], "records": records,
                    "tutorial": tutorial]
        default:
            return nil
        }
    }

    /// The stored example of schema `version` for the registry's migration check: ``schemaExamplePayload(version:)`` in
    /// an envelope of that schema at step 0 with seed `seed`, and the digest its restore through ``migrations`` gives.
    /// Nil for another version, or if the encoding, the migration or the restore fails.
    public static func schemaExample(version: Int, seed: UInt64 = 2_509) -> MigrationExample? {
        guard let id = ExperienceID(rawValue: experienceID), let payload = schemaExamplePayload(version: version),
              let data = try? JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys]),
              let upgraded = try? migrations.migrate(payload, from: version),
              let migrated = try? JSONSerialization.data(withJSONObject: upgraded, options: [.sortedKeys]),
              let restored = try? restore(payload: migrated, seed: seed) else { return nil }
        var builder = DigestBuilder(domain: id.rawValue)
        guard (try? restored.writeDigest(into: &builder)) != nil else { return nil }
        let digest = builder.finish()
        guard let snapshot = try? ExperienceSnapshot(experience: id, schemaVersion: version, seed: seed, stepIndex: 0,
                                                     digest: digest, payload: data),
              let encoded = try? snapshot.encoded() else { return nil }
        return MigrationExample(version: version, snapshot: encoded, expectedDigest: digest.hex)
    }

    /// The stored schema-1 example; registered since schema 3 (feature 509).
    public static func schemaOneExample(seed: UInt64 = 2_509) -> MigrationExample? {
        schemaExample(version: 1, seed: seed)
    }

    /// The stored schema-2 example; registered since schema 3 (feature 509).
    public static func schemaTwoExample(seed: UInt64 = 2_509) -> MigrationExample? {
        schemaExample(version: 2, seed: seed)
    }

    /// `value` encoded with sorted keys and read back as a JSON object (array, dictionary or string).
    static func schemaExampleJSON<T: Encodable>(_ value: T) -> Any? {
        guard let data = try? payloadEncoder().encode(value) else { return nil }
        return try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
    }
}
