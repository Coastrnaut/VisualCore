// AmbientSchemaExamples — feature 133 (A18-P03) T-A18-304 (FR-A18-306; G-THEMES; clarification Q3). The snapshot of
// Ambient Clock moved from schema 1 (A18-P02: hour cycle, seconds, date, motion, speed) to schema 2 (A18-P03: the
// theme and its palette join it), so the registry's migration check needs one stored example of schema 1 (only that
// one is registered: the check refuses an example of the current schema); the schema-2 example serves the round-trip
// tests. The examples are built as Interactive Anatomy's are
// (`AnatomySchemaExamples.swift`): a payload of that schema in an envelope of that schema at step 0, with the digest
// that its restore through the migration chain gives.
import AmbientClockCore
import Foundation
import VisualCoreExperience

extension AmbientCore {
    /// The payload of the stored example of schema `version`: the 24-hour clock with seconds, no date line, motion on
    /// at speed 1.5; schema 2 adds the wave field (theme 2) with its palette 1. Nil for any other version.
    public static func schemaExamplePayload(version: Int) -> [String: Any]? {
        let schemaOne: [String: Any] = ["hourCycle": 2, "showSeconds": true, "showDate": false, "motion": true,
                                        "speed": 1.5]
        switch version {
        case 1:
            return schemaOne
        case 2:
            return schemaOne.merging(["theme": 2, "palette": 1]) { _, new in new }
        default:
            return nil
        }
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

    /// The stored schema-1 example (A18-P02: format, motion and speed; no theme or palette).
    public static func schemaOneExample(seed: UInt64 = 7) -> MigrationExample? { schemaExample(version: 1, seed: seed) }

    /// The schema-2 example (A18-P03: the wave field with its palette 1), for the round-trip tests; not registered,
    /// because the registry's check takes earlier schemas only.
    public static func schemaTwoExample(seed: UInt64 = 7) -> MigrationExample? { schemaExample(version: 2, seed: seed) }
}
