// FacetedForgeSchemaExamples — feature 379 (R02-G08-09) T-R02G0809-002 (FR-R02G0809-003, SC-R02G0809-002;
// clarification Q3; data-model.md). Faceted Forge's snapshot is schema 3 (feature 377), so the app registry's
// migration check stores one example of each earlier schema, built as Amethyst Escape's are
// (`AmethystEscapeSchemaExamples.swift`): a payload of that schema in an envelope of that schema at step 0 with seed 7,
// and the digest its restore through the migration chain gives.
//   schema 1: `{level: 1, records}` — a play of certified level 1 with one cut: the first cut of its certified
//             solution (the certified smallest cut count is above 1, so the play is still playing and not won);
//   schema 2: `{level: 1, mode: campaign, progress: {frontier: 2, solved: [level 1 at its certified smallest cut count
//             plus one, with its stars]}, records: [], tutorial: done}` — a won level written before traces existed
//             (restored unverified, without a trace; feature 377's reconciliation keeps such results).
// Nothing here reads a clock or a random source.
import Foundation
import VisualCoreExperience

extension FacetedForgeExperienceCore {
    /// The payload of the stored example of schema `version` (1 or 2; see the file header); nil for any other version
    /// or when a certified level cannot be generated.
    public static func schemaExamplePayload(version: Int) -> [String: Any]? {
        switch version {
        case 1:
            guard let certified = try? generated(number: 1), let first = certified.solution.actions.first,
                  var play = try? freshPlay(of: certified.level) else { return nil }
            do {
                try play.apply(first, expecting: play.fingerprint)
            } catch {
                return nil
            }
            guard play.stage == .playing, let records = schemaExampleJSON(play.records) else { return nil }
            return ["level": 1, "records": records]
        case 2:
            guard let certified = try? generated(number: 1),
                  let mode = schemaExampleJSON(FacetedForgeMode.campaign),
                  let tutorial = schemaExampleJSON(FacetedForgeTutorialStep.done) else { return nil }
            let smallest: Int = certified.solution.smallest
            let cutsMade: Int = smallest + 1
            let solved: [[String: Any]] = [["cutsMade": cutsMade, "level": 1,
                                            "stars": FacetedForgeProgress.stars(cutsMade: cutsMade,
                                                                                smallest: smallest)]]
            return ["level": 1, "mode": mode, "progress": ["frontier": 2, "solved": solved], "records": [Any](),
                    "tutorial": tutorial]
        default:
            return nil
        }
    }

    /// The stored example of schema `version` for the registry's migration check: ``schemaExamplePayload(version:)`` in
    /// an envelope of that schema at step 0 with seed `seed`, and the digest its restore through ``migrations`` gives.
    /// Nil for another version, or if the encoding, the migration or the restore fails.
    public static func schemaExample(version: Int, seed: UInt64 = 7) -> MigrationExample? {
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

    /// The stored schema-1 example; registered since schema 3.
    public static func schemaOneExample(seed: UInt64 = 7) -> MigrationExample? { schemaExample(version: 1, seed: seed) }

    /// The stored schema-2 example; registered since schema 3.
    public static func schemaTwoExample(seed: UInt64 = 7) -> MigrationExample? { schemaExample(version: 2, seed: seed) }

    /// `value` encoded with sorted keys and read back as a JSON object (array, dictionary or string).
    static func schemaExampleJSON<T: Encodable>(_ value: T) -> Any? {
        guard let data = try? payloadEncoder().encode(value) else { return nil }
        return try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
    }
}
