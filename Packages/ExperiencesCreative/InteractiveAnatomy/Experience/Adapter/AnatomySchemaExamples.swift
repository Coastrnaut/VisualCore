// AnatomySchemaExamples — X-A17 follow-through (2026-11-16; feature 126's view schema 2, feature 129's old-view
// coverage). The snapshot of Interactive Anatomy moved from view schema 1 (A17-P02: camera, layers, selection, framing)
// to schema 2 (A17-P03: the isolate joins it), so the registry's migration check needs one stored example of schema 1.
// The example is built as Molecular Explorer's are: a schema-1 payload in an envelope of schema 1 at step 0, with the
// digest that its restore through the migration chain gives.
import Foundation
import InteractiveAnatomyCore
import VisualCoreExperience

extension AnatomyCore {
    /// The schema-1 payload of the stored example: turn 5, tilt 2, zoom 1, the ligaments hidden, the tibia selected and
    /// framed. Nil for any other version.
    public static func schemaExamplePayload(version: Int) -> [String: Any]? {
        guard version == 1 else { return nil }
        return ["schema": 1, "camera": ["turn": 5, "tilt": 2, "zoom": 1], "visibleLayers": [true, true, false],
                "selection": "knee.tibia", "framed": "knee.tibia"]
    }

    /// The stored example of schema `version` for the registry's migration check: ``schemaExamplePayload(version:)``
    /// in an envelope of that schema at step 0 with seed `seed`, and the digest its restore through ``migrations``
    /// gives. Nil for another version, or if the encoding, the migration or the restore fails.
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

    /// The stored schema-1 example (A17-P02 view: camera, layers, selection and framing).
    public static func schemaOneExample(seed: UInt64 = 7) -> MigrationExample? { schemaExample(version: 1, seed: seed) }
}
