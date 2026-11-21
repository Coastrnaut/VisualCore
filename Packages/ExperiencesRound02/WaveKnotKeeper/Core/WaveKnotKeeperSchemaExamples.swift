// WaveKnotKeeperSchemaExamples — feature 329 (R02-G03-09) T-R02G0309-002 (FR-R02G0309-003; clarification Q3;
// data-model.md). Wave Knot Keeper's snapshot is schema 3 (feature 327), so the app registry's migration check stores
// one example of each earlier schema, built as Lissajous Labyrinth's are (`LissajousLabyrinthSchemaExamples.swift`): a
// payload of that schema in an envelope of that schema at step 0 with seed 7, and the digest its restore through the
// migration chain gives.
//   schema 1: `{level: 1, records}` — a play of certified level 1 with one move that does not win (the first legal move
//             in point order, then direction order, that leaves the level unsolved);
//   schema 2: `{level: 1, mode: campaign, progress: {frontier: 2, solved: [level 1 at its certified shortest, 3 stars]},
//             records: [], tutorial: done}` — a solved level written before traces existed (restored unverified).
// Nothing here reads a clock or a random source.
import Foundation
import VisualCoreExperience

extension WaveKnotKeeperExperienceCore {
    /// The payload of the stored example of schema `version` (1 or 2; see the file header); nil for any other version
    /// or when a certified level cannot be generated.
    public static func schemaExamplePayload(version: Int) -> [String: Any]? {
        switch version {
        case 1:
            guard let level = try? level(number: 1), var play = try? freshPlay(of: level),
                  let move = firstLosingMove(play) else { return nil }
            do {
                try play.apply(move, expecting: play.fingerprint)
            } catch {
                return nil
            }
            guard play.stage == .playing, let records = schemaExampleJSON(play.records) else { return nil }
            return ["level": 1, "records": records]
        case 2:
            guard let certified = try? generated(number: 1), let mode = schemaExampleJSON(WaveKnotKeeperMode.campaign),
                  let tutorial = schemaExampleJSON(WaveKnotKeeperTutorialStep.done) else { return nil }
            let shortest = certified.solution.shortest
            let solved: [[String: Any]] = [["level": 1, "bestMoves": shortest,
                                            "stars": WaveKnotKeeperProgress.stars(moves: shortest, shortest: shortest)]]
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

    /// The first move of `play`, in point order and then direction order, that the rules accept and that leaves the play
    /// unsolved; nil when there is none.
    static func firstLosingMove(_ play: WaveKnotKeeperPlay) -> WaveKnotKeeperMove? {
        for point in play.points.indices {
            for direction in WaveKnotKeeperDirection.allCases {
                let move = WaveKnotKeeperMove(point: point, direction: direction)
                var trial = play
                guard (try? trial.apply(move, expecting: trial.fingerprint)) != nil else { continue }
                if trial.stage == .playing { return move }
            }
        }
        return nil
    }

    /// `value` encoded with sorted keys and read back as a JSON object (array, dictionary or string).
    static func schemaExampleJSON<T: Encodable>(_ value: T) -> Any? {
        guard let data = try? payloadEncoder().encode(value) else { return nil }
        return try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
    }
}
