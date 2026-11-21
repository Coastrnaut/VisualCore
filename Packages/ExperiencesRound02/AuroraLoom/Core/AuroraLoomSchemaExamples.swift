// AuroraLoomSchemaExamples — feature 309 (R02-G01-09) T-R02G0109-002 (FR-R02G0109-003; clarification Q3; data-model.md).
// Aurora Loom's snapshot is schema 3 (feature 307), so the app registry's migration check stores one example of each
// earlier schema, built as Ambient Clock's are (`AmbientSchemaExamples.swift`): a payload of that schema in an envelope
// of that schema at step 0 with seed 7, and the digest its restore through the migration chain gives.
//   schema 1: `{level: 2, records}` — a play of certified level 2 with two moves that do not win (ribbon 0's wave and
//             ribbon 1's phase changed to the first steps that leave the level unsolved);
//   schema 2: `{level: 1, mode: campaign, progress: {frontier: 2, solved: [level 1 at its certified shortest, 3 stars]},
//             records: [], tutorial: done}` — a solved level written before traces existed (restored unverified).
// Nothing here reads a clock or a random source.
import Foundation
import VisualCoreExperience

extension AuroraLoomExperienceCore {
    /// The payload of the stored example of schema `version` (1 or 2; see the file header); nil for any other version
    /// or when a certified level cannot be generated.
    public static func schemaExamplePayload(version: Int) -> [String: Any]? {
        switch version {
        case 1:
            guard let level = try? level(number: 2), var play = try? freshPlay(of: level) else { return nil }
            var steps = level.startSteps
            guard let wave = firstLosingStep(steps, level: level, ribbon: 0, control: .wave) else { return nil }
            steps.wave[0] = wave
            guard let phase = firstLosingStep(steps, level: level, ribbon: 1, control: .phase) else { return nil }
            do {
                try play.apply(AuroraLoomMove(ribbon: 0, control: .wave, step: wave), expecting: play.fingerprint)
                try play.apply(AuroraLoomMove(ribbon: 1, control: .phase, step: phase), expecting: play.fingerprint)
            } catch {
                return nil
            }
            guard let records = jsonObject(play.records) else { return nil }
            return ["level": 2, "records": records]
        case 2:
            guard let certified = try? generated(number: 1), let mode = jsonObject(AuroraLoomMode.campaign),
                  let tutorial = jsonObject(AuroraLoomTutorialStep.done) else { return nil }
            let shortest = certified.solution.shortest
            let solved: [[String: Any]] = [["level": 1, "bestMoves": shortest,
                                            "stars": AuroraLoomProgress.stars(moves: shortest, shortest: shortest)]]
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

    /// The first step of `control` of `ribbon` after the current one whose single change leaves `level` unsolved from
    /// `steps`; nil when every other step solves it.
    static func firstLosingStep(_ steps: AuroraLoomSteps, level: AuroraLoomLevel, ribbon: Int,
                                control: AuroraLoomControl) -> Int? {
        let current = control == .wave ? steps.wave[ribbon] : steps.phase[ribbon]
        for offset in 1...15 {
            let candidate = (current + offset) % 16
            var next = steps
            if control == .wave { next.wave[ribbon] = candidate } else { next.phase[ribbon] = candidate }
            if !AuroraLoomHarmony.wins(next, level: level) { return candidate }
        }
        return nil
    }

    /// `value` encoded with sorted keys and read back as a JSON object (array, dictionary or string).
    static func jsonObject<T: Encodable>(_ value: T) -> Any? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        guard let data = try? encoder.encode(value) else { return nil }
        return try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
    }
}
