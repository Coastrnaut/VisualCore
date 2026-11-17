// AdapterSchemaExamples — feature 140 (A19-P03) T-A19-303 (FR-A19-301; clarification Q1; data-model.md
// "AdapterSchemaExamples"). The snapshot of Living Wallpapers moved from schema 1 (A19-P02: scene, preset,
// parameters, template, orientation, animation time, format and motion) to schema 2 (A19-P03: `custom` and the twelve
// colour components join it), so the registry's migration check needs one stored example of schema 1 (only that one
// is registered: the check refuses an example of the current schema); the schema-2 example serves the round-trip
// tests. The examples are built as Ambient Clock's are (`AmbientSchemaExamples.swift`): a payload of that schema in an
// envelope of that schema at step 0, with the digest that its restore through the migration chain gives.
//
// The schema-1 payload is exactly what A19-P02's encoder wrote, the eight fields and no others: the ink flow (scene 1)
// with Saffron Ink (preset 2), warp 1.2, scale 2.5 and flow 0.4, the iPad Pro 13-inch (M4) (template 5) in landscape,
// the moment 42.5 s, JPEG (format 1) and motion off. The schema-2 payload adds `custom` 1 and the Saffron Ink colours
// with colour 2 (slot 1) edited to red 0.4, green 0.2, blue 0.6.
import Foundation
import LivingWallpapersCore
import VisualCoreExperience

extension WallpaperCore {
    /// The eight schema-1 keys, sorted (A19-P02).
    public static let schemaOneKeys: Set<String> = ["animationTime", "format", "motion", "orientation", "parameters",
                                                    "preset", "scene", "template"]

    /// The edited colour of the schema-2 example: slot 1 (colour 2) at red 0.4, green 0.2, blue 0.6.
    public static let schemaTwoEditedSlot = (slot: 1, r: 0.4, g: 0.2, b: 0.6)

    /// The payload of the stored example of schema `version` (see the file header); nil for any other version.
    public static func schemaExamplePayload(version: Int) -> [String: Any]? {
        let schemaOne: [String: Any] = ["scene": 1, "preset": 2, "parameters": [1.2, 2.5, 0.4], "template": 5,
                                        "orientation": 1, "animationTime": 42.5, "format": 1, "motion": false]
        switch version {
        case 1:
            return schemaOne
        case 2:
            var colors = presetComponents(scene: 1, preset: 2)
            let edit = schemaTwoEditedSlot
            colors[edit.slot * 3] = edit.r
            colors[edit.slot * 3 + 1] = edit.g
            colors[edit.slot * 3 + 2] = edit.b
            return schemaOne.merging(["custom": 1, "colors": colors]) { _, new in new }
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

    /// The stored schema-1 example (A19-P02: the eight fields, no colour edit); registered in the app's registry.
    public static func schemaOneExample(seed: UInt64 = 7) -> MigrationExample? { schemaExample(version: 1, seed: seed) }

    /// The schema-2 example (A19-P03: colour 2 edited), for the round-trip tests; not registered, because the
    /// registry's check takes earlier schemas only.
    public static func schemaTwoExample(seed: UInt64 = 7) -> MigrationExample? { schemaExample(version: 2, seed: seed) }
}
