// GameRunTests — feature 075 (A10-P01) T-A10-103 (FR-A10-110; clarifications 1, 3 and 4; data-model "GameRun",
// schema 1). The run record, host-free and short: a new run (schema 1, step 0, score 0, three lives, steering 0, the
// player at rest in the middle with hit radius 0.4, no objects or events) is valid; the JSON round trip keeps every
// field; `validate()` names each broken limit (score, lives, steering, player range, objects ≤ 24, events ≤ 256, id
// order, over without lost lives, schema); a restart gives the new-run values. A10-P02 (feature 076, T-A10-202;
// FR-A10-210; clarification 4): schema 2 — a new run is in wave 1 at wave step 0 with `rain`, no free lane and cursor
// 0; the round trip keeps the wave fields (a run in wave 2); `validate()` names a broken wave, wave step, pattern, free
// lane or cursor; a restart in a late wave starts wave 1 with `rain`.
import Foundation
import Testing
import VisualCoreMath
import VisualCoreSimulation
import NeonArcadeCore

@Suite struct GameRunTests {
    @Test func aNewRunHasTheStartValuesAndIsValid() {
        let run = GameRun.new()
        #expect(run.schema == 2 && run.step == 0 && run.score == 0 && run.lives == 3)
        #expect(!run.paused && !run.over && run.steering == 0)
        #expect(run.player == PlayerState(x: 4.5, velocity: 0, hitRadius: 0.4, invulnerableSteps: 0))
        #expect(run.player.center == Vec2(4.5, 1.5))
        #expect(run.objects.isEmpty && run.events.isEmpty && run.eventCount == 0 && run.nextObjectId == 0)
        #expect(run.wave == 1 && run.waveStep == 0 && run.patternId == "rain" && run.freeLane == -1)
        #expect(run.patternCursor == 0)
        #expect(run.validate().isEmpty)
        #expect(GameRun.currentSchema == 2 && GameRun.schemaOne == 1)
        #expect(GameRun.maxScore == 9_999_999 && GameRun.maxObjects == 24 && GameRun.maxEvents == 256)
        #expect(PlayerState.invulnerabilitySteps == 90 && PlayerState.xRange == 0.5...8.5)
    }

    @Test func theJSONRoundTripKeepsEveryField() throws {
        var run = GameRun.new()
        var random = SeededRandom(seed: 5)
        GameSimulation.steer(&run, value: 0.4)
        for _ in 0..<700 {
            run.player.invulnerableSteps = max(run.player.invulnerableSteps, 1)   // keeps the run going into wave 2
            GameSimulation.advance(&run, catalog: .bundled, random: &random)
        }
        #expect(run.wave == 2 && run.waveStep == 100 && run.patternId != "rain")
        run.events = [CollisionEvent(step: 12, objectId: 0, kind: .pickup)]
        run.eventCount = 3
        #expect(!run.objects.isEmpty)
        let data = try JSONEncoder().encode(run)
        let decoded = try JSONDecoder().decode(GameRun.self, from: data)
        #expect(decoded == run)
        #expect(decoded.validate().isEmpty)
    }

    @Test func validateNamesEveryBrokenLimit() {
        let base = GameRun.new()
        func problems(_ change: (inout GameRun) -> Void) -> [String] {
            var run = base
            change(&run)
            return run.validate()
        }
        #expect(!problems { $0.schema = 1 }.isEmpty)
        #expect(!problems { $0.schema = 3 }.isEmpty)
        #expect(!problems { $0.wave = 0 }.isEmpty)
        #expect(problems { $0.wave = 40 }.isEmpty)
        #expect(!problems { $0.waveStep = -1 }.isEmpty)
        #expect(!problems { $0.waveStep = 600 }.isEmpty)
        #expect(problems { $0.waveStep = 599 }.isEmpty)
        #expect(!problems { $0.patternId = "spiral" }.isEmpty)
        #expect(problems { $0.patternId = "orb-trail" }.isEmpty)
        #expect(!problems { $0.freeLane = -2 }.isEmpty)
        #expect(!problems { $0.freeLane = 5 }.isEmpty)
        #expect(problems { $0.freeLane = 4 }.isEmpty)
        #expect(!problems { $0.patternCursor = -1 }.isEmpty)
        #expect(!problems { $0.patternCursor = 8 }.isEmpty)
        #expect(problems { $0.patternCursor = 7 }.isEmpty)
        #expect(!problems { $0.score = 10_000_000 }.isEmpty)
        #expect(!problems { $0.score = -1 }.isEmpty)
        #expect(!problems { $0.lives = 4 }.isEmpty)
        #expect(!problems { $0.lives = 0 }.isEmpty)               // lives 0 but not over
        #expect(problems { $0.lives = 0; $0.over = true }.isEmpty)
        #expect(!problems { $0.over = true }.isEmpty)             // over with lives left
        #expect(!problems { $0.steering = 1.5 }.isEmpty)
        #expect(!problems { $0.steering = .nan }.isEmpty)
        #expect(!problems { $0.player.x = 8.6 }.isEmpty)
        #expect(!problems { $0.player.x = .infinity }.isEmpty)
        #expect(!problems { $0.player.velocity = 9.5 }.isEmpty)
        #expect(!problems { $0.player.hitRadius = 0.5 }.isEmpty)
        #expect(!problems { $0.player.invulnerableSteps = 91 }.isEmpty)
        let object = { (id: Int) in
            FallingObject(id: id, contentId: "glow-orb", kind: .orb, position: Vec2(2, 8), velocity: Vec2(0, -4),
                          radius: 0.25, value: 10)
        }
        #expect(problems { $0.objects = [object(0), object(1)]; $0.nextObjectId = 2 }.isEmpty)
        #expect(!problems { $0.objects = [object(1), object(0)]; $0.nextObjectId = 2 }.isEmpty)
        #expect(!problems { $0.objects = [object(0)]; $0.nextObjectId = 0 }.isEmpty)
        #expect(!problems { $0.objects = (0..<25).map(object); $0.nextObjectId = 25 }.isEmpty)
        #expect(!problems { var o = object(0); o.position.x = .nan; $0.objects = [o]; $0.nextObjectId = 1 }.isEmpty)
        let event = CollisionEvent(step: 0, objectId: 0, kind: .hit)
        #expect(!problems { $0.step = 300; $0.events = Array(repeating: event, count: 257); $0.eventCount = 257 }
            .isEmpty)
        #expect(!problems { $0.step = 10; $0.events = [event]; $0.eventCount = 0 }.isEmpty)
        #expect(problems { $0.step = 10; $0.events = [event]; $0.eventCount = 1 }.isEmpty)
        #expect(!problems { $0.step = 0; $0.events = [event]; $0.eventCount = 1 }.isEmpty)
    }

    @Test func restartGivesTheNewRunValues() {
        var run = GameRun.new()
        var random = SeededRandom(seed: 9)
        GameSimulation.steer(&run, value: -1)
        for _ in 0..<300 { GameSimulation.advance(&run, catalog: .bundled, random: &random) }
        run.score = 120; run.lives = 1; run.paused = true
        GameSimulation.restart(&run)
        #expect(run == GameRun.new())
        #expect(run.steering == 0 && run.score == 0 && run.lives == 3 && !run.paused && !run.over)
    }

    @Test func aRestartInALateWaveStartsWaveOneWithRain() {
        var run = GameRun.new()
        var random = SeededRandom(seed: 12)
        for _ in 0..<1900 {
            run.player.invulnerableSteps = max(run.player.invulnerableSteps, 1)
            GameSimulation.advance(&run, catalog: .bundled, random: &random)
        }
        #expect(run.wave == 4 && run.waveStep == 100)
        GameSimulation.restart(&run)
        #expect(run == GameRun.new())
        #expect(run.wave == 1 && run.waveStep == 0 && run.patternId == "rain" && run.freeLane == -1)
        GameSimulation.advance(&run, catalog: .bundled, random: &random)
        #expect(run.wave == 1 && run.waveStep == 1 && run.patternId == "rain")
    }
}
