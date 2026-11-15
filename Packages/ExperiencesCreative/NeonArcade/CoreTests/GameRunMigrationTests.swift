// GameRunMigrationTests — feature 076 (A10-P02) T-A10-202 (FR-A10-210; clarification 4; research D4; SC-A10-204).
// Schema 1 → 2 of the run, host-free and short: a schema-1 JSON document (a played Phase 01 run without the wave
// fields) decodes with the wave defaults and schema 1, which `validate()` names; `migrated()` lifts it to schema 2 at
// the start of wave 1 (wave step 0, `rain`, no free lane, cursor 0) keeping score, lives, player, objects, events and
// every other field, and the result validates; a hand-written Phase 01 document with an object off the lane centres
// keeps it, and later spawns use lanes; a schema-2 document without the wave fields is refused; `migrated()` leaves a
// schema-2 (or unknown) run unchanged; the schema-2 round trip keeps the wave fields.
import Foundation
import Testing
import VisualCoreMath
import VisualCoreSimulation
import NeonArcadeCore

@Suite struct GameRunMigrationTests {
    private static let waveKeys = ["wave", "waveStep", "patternId", "freeLane", "patternCursor"]

    /// `run` as a schema-1 document: the wave fields removed and the schema set to 1.
    private func schemaOneData(_ run: GameRun) throws -> Data {
        var object = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(run)) as? [String: Any])
        for key in Self.waveKeys { object.removeValue(forKey: key) }
        object["schema"] = 1
        return try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    }

    @Test func aPlayedSchemaOneRunMigratesKeepingScoreLivesPlayerAndObjects() throws {
        var played = GameRun.new()
        var random = SeededRandom(seed: 5)
        GameSimulation.steer(&played, value: 0.4)
        for _ in 0..<700 {
            played.player.invulnerableSteps = max(played.player.invulnerableSteps, 1)
            GameSimulation.advance(&played, catalog: .bundled, random: &random)
        }
        played.lives = 2
        played.events = [CollisionEvent(step: 40, objectId: 0, kind: .hit)]
        played.eventCount = 4
        #expect(!played.objects.isEmpty && played.wave == 2)
        let decoded = try JSONDecoder().decode(GameRun.self, from: schemaOneData(played))
        #expect(decoded.schema == 1)
        #expect(decoded.wave == 1 && decoded.waveStep == 0 && decoded.patternId == "rain")
        #expect(decoded.freeLane == -1 && decoded.patternCursor == 0)
        #expect(decoded.validate() == ["schema 1 is not 2"])
        let migrated = decoded.migrated()
        #expect(migrated.schema == 2 && migrated.validate().isEmpty)
        #expect(migrated.wave == 1 && migrated.waveStep == 0 && migrated.patternId == "rain")
        #expect(migrated.freeLane == -1 && migrated.patternCursor == 0)
        #expect(migrated.score == played.score && migrated.lives == 2 && migrated.player == played.player)
        #expect(migrated.objects == played.objects && migrated.events == played.events)
        #expect(migrated.step == played.step && migrated.nextObjectId == played.nextObjectId)
        #expect(migrated.eventCount == 4 && migrated.steering == played.steering)
        #expect(migrated.paused == played.paused && migrated.over == played.over)
    }

    @Test func aPhaseOneDocumentKeepsItsObjectsAndNewSpawnsUseLanes() throws {
        let text = """
        {"schema": 1, "step": 250, "score": 40, "lives": 2, "paused": false, "over": false, "steering": -0.5,
         "player": {"x": 3.25, "velocity": -4.5, "hitRadius": 0.4, "invulnerableSteps": 12},
         "objects": [{"id": 6, "contentId": "spike-ball", "kind": "hazard", "position": {"x": 3.3, "y": 12.0},
                      "velocity": {"x": 0, "y": -4.2}, "radius": 0.45, "halfLength": 0, "value": 0}],
         "nextObjectId": 7, "events": [{"step": 120, "objectId": 2, "kind": "pickup"}], "eventCount": 5}
        """
        let decoded = try JSONDecoder().decode(GameRun.self, from: Data(text.utf8))
        var run = decoded.migrated()
        #expect(run.validate().isEmpty)
        #expect(run.score == 40 && run.lives == 2 && run.player.x == 3.25 && run.player.invulnerableSteps == 12)
        #expect(run.objects.map(\.position.x) == [3.3] && run.step == 250 && run.eventCount == 5)
        var random = SeededRandom(seed: 3)
        for _ in 0..<31 { GameSimulation.advance(&run, catalog: .bundled, random: &random) }
        #expect(run.objects.first?.id == 6 && run.objects.first?.position.x == 3.3)   // kept off the lanes
        let spawned = run.objects.filter { $0.id >= 7 }
        #expect(spawned.count == 1 && spawned.allSatisfy { Lanes.centres.contains($0.position.x) })
        #expect(run.wave == 1 && run.waveStep == 31 && run.validate().isEmpty)
    }

    @Test func aSchemaTwoDocumentWithoutTheWaveFieldsIsRefused() throws {
        var object = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(GameRun.new()))
                                  as? [String: Any])
        for key in Self.waveKeys {
            var broken = object
            broken.removeValue(forKey: key)
            let data = try JSONSerialization.data(withJSONObject: broken)
            #expect(throws: DecodingError.self, "\(key)") { try JSONDecoder().decode(GameRun.self, from: data) }
        }
        object["schema"] = 1
        object["wave"] = 3   // a schema-1 document carrying a wave field still decodes; migration resets it
        let data = try JSONSerialization.data(withJSONObject: object)
        let decoded = try JSONDecoder().decode(GameRun.self, from: data)
        #expect(decoded.wave == 3 && decoded.migrated().wave == 1)
    }

    @Test func migratedLeavesOtherSchemasUnchanged() {
        var run = GameRun.new()
        run.wave = 4; run.waveStep = 321; run.patternId = "zigzag"; run.patternCursor = 5; run.freeLane = 2
        #expect(run.migrated() == run)
        run.schema = 3
        #expect(run.migrated() == run && !run.validate().isEmpty)
    }

    @Test func theSchemaTwoRoundTripKeepsTheWaveFields() throws {
        var run = GameRun.new()
        run.wave = 7; run.waveStep = 599; run.patternId = "wall"; run.freeLane = 3; run.patternCursor = 0
        let data = try JSONEncoder().encode(run)
        let text = String(decoding: data, as: UTF8.self)
        for key in Self.waveKeys { #expect(text.contains("\"\(key)\"")) }
        #expect(try JSONDecoder().decode(GameRun.self, from: data) == run)
    }
}
