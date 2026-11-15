// WaveDirectorTests — feature 076 (A10-P02) T-A10-202 (FR-A10-201, 202, 204, 211; clarifications 1–3; research D1,
// D3; SC-A10-201, 203). Lanes, the pattern table and the wave director, host-free and short: five lane centres 1.8
// apart; four patterns (rain, wall, zigzag, orb-trail) with author "VisualCore project" and license "MIT"; over 20
// seeds × 10,000 simulated steps (the player kept invulnerable so the run lasts) every spawned object starts at a lane
// centre, every wave's pattern is in the table and at least three patterns appear per seed; waves advance every 600
// steps, wave 1 is `rain` and no wave repeats the previous wave's pattern; every wall row has exactly one free lane,
// never the previous row's, four spike-balls of radius 0.5 sharing one speed in the wave's range; the free lane is
// reachable in time (research D3 arithmetic, and a simulated crossing); zigzag walks 0→4→0; orb-trail guards every
// second orb with bars in the neighbouring lanes; rain spawns one object per gap; the director is deterministic.
import Foundation
import Testing
import VisualCoreMath
import VisualCoreSimulation
import NeonArcadeCore

@Suite struct WaveDirectorTests {
    /// Runs only the director for `steps` steps from `run`, returning each step's wave state before it and requests.
    private func direct(_ run: inout GameRun, _ random: inout SeededRandom, steps: Int)
        -> [(wave: Int, waveStep: Int, patternId: String, freeLane: Int, requests: [SpawnRequest])] {
        var out: [(wave: Int, waveStep: Int, patternId: String, freeLane: Int, requests: [SpawnRequest])] = []
        out.reserveCapacity(steps)
        for _ in 0..<steps {
            let before = run
            let requests = WaveDirector.step(&run, random: &random)
            out.append((before.wave, before.waveStep, before.patternId, before.freeLane, requests))
        }
        return out
    }

    @Test func theLanesAndThePatternTable() {
        #expect(Lanes.count == 5)
        #expect(Lanes.centres.map { ($0 * 10).rounded() / 10 } == [0.9, 2.7, 4.5, 6.3, 8.1])
        #expect(Lanes.centre(0) == 0.9 && Lanes.centre(2) == 4.5)
        for lane in 1..<Lanes.count { #expect(abs(Lanes.centre(lane) - Lanes.centre(lane - 1) - 1.8) < 1e-12) }
        #expect(Lanes.centres.allSatisfy { PlayerState.xRange.contains($0) })
        #expect(PatternTable.ids == ["rain", "wall", "zigzag", "orb-trail"])
        #expect(PatternTable.bundled.map(\.rule) == [.rain, .wall, .zigzag, .orbTrail])
        #expect(PatternTable.bundled.allSatisfy { $0.author == "VisualCore project" && $0.license == "MIT" })
        #expect(PatternTable.bundled.allSatisfy { !$0.name.isEmpty && !$0.spawns.isEmpty && $0.id == $0.rule.rawValue })
        #expect(PatternTable.pattern(id: "wall")?.rowEvery == 120)
        #expect(PatternTable.bundled.filter { $0.rule != .wall }.allSatisfy { $0.rowEvery == 0 })
        #expect(PatternTable.pattern(id: "spiral") == nil && PatternTable.firstPatternId == "rain")
        #expect(WaveDirector.waveLength == 600 && WaveDirector.firstSpawnStep == 30)
        #expect((0..<8).map(WaveDirector.zigzagLane) == [0, 1, 2, 3, 4, 3, 2, 1])
    }

    @Test func everySpawnStartsAtALaneCentreAndThreePatternsAppearPerSeed() {
        var offLane = 0, unknownPattern = 0, fewPatterns = 0, spawned = 0
        for seed in UInt64(1)...20 {
            var game = GameRun.new()
            var random = SeededRandom(seed: seed)
            var steering = SeededRandom(seed: seed &+ 500)
            var patterns: Set<String> = []
            for i in 0..<10_000 {
                if i % 41 == 0 { GameSimulation.steer(&game, value: steering.range(-1...1)) }
                game.player.invulnerableSteps = max(game.player.invulnerableSteps, 1)   // keeps the run going
                let firstNew = game.nextObjectId
                if PatternTable.pattern(id: game.patternId) == nil { unknownPattern += 1 }
                patterns.insert(game.patternId)
                GameSimulation.advance(&game, catalog: .bundled, random: &random)
                for object in game.objects where object.id >= firstNew {
                    spawned += 1
                    if !Lanes.centres.contains(object.position.x) { offLane += 1 }
                }
            }
            if patterns.count < 3 { fewPatterns += 1 }
            #expect(game.wave == 10_000 / 600 + 1 && game.waveStep == 10_000 % 600, "seed \(seed)")
            #expect(game.validate().isEmpty)
        }
        #expect(offLane == 0 && unknownPattern == 0 && fewPatterns == 0)
        #expect(spawned > 20 * 300, "\(spawned)")
    }

    @Test func wavesAdvanceEvery600StepsWithAnotherPattern() {
        for seed in UInt64(1)...20 {
            var run = GameRun.new()
            var random = SeededRandom(seed: seed)
            let steps = direct(&run, &random, steps: 6000)
            #expect(steps[0].wave == 1 && steps[0].patternId == "rain")
            var repeats = 0, wrongClock = 0
            for (i, step) in steps.enumerated() {
                if step.wave != i / 600 + 1 || step.waveStep != i % 600 { wrongClock += 1 }
                if i > 0 && step.waveStep == 0 && step.patternId == steps[i - 1].patternId { repeats += 1 }
                if i > 0 && step.waveStep != 0 && step.patternId != steps[i - 1].patternId { repeats += 1 }
                if step.waveStep < 30 && !step.requests.isEmpty { wrongClock += 1 }
            }
            #expect(repeats == 0 && wrongClock == 0, "seed \(seed)")
            #expect(run.wave == 11 && run.waveStep == 0)
        }
    }

    @Test func everyWallLeavesExactlyOneFreeLaneNeverThePrevious() {
        var rows = 0, bad = 0
        for seed in UInt64(1)...20 {
            var run = GameRun.new()
            var random = SeededRandom(seed: seed)
            var previousFree = -1
            for step in direct(&run, &random, steps: 10_000) where step.patternId == "wall" {
                if step.waveStep >= 30 && (step.waveStep - 30) % 120 == 0 {
                    rows += 1
                    let lanes = step.requests.map(\.lane)
                    let free = Set(0..<5).subtracting(lanes)
                    let speeds = Set(step.requests.compactMap(\.fallSpeed))
                    let range = Difficulty(wave: step.wave).fallSpeed
                    if step.requests.count != 4 || Set(lanes).count != 4 || free.count != 1
                        || free.first == previousFree || step.freeLane != previousFree
                        || speeds.count != 1 || !range.contains(speeds.first ?? -1)
                        || !step.requests.allSatisfy({ $0.kind == .hazard && $0.contentId == "spike-ball"
                                                       && $0.radius == 0.5 }) { bad += 1 }
                    previousFree = free.first ?? -1
                } else if !step.requests.isEmpty {
                    bad += 1
                }
            }
            #expect(run.freeLane == previousFree)
        }
        #expect(rows > 100 && bad == 0, "\(rows) rows, \(bad) bad")
    }

    @Test func theFreeLaneIsReachableInTime() {
        // Research D3: the widest distance from any player position to any lane centre.
        let widest = Lanes.centres.map { max(abs($0 - PlayerState.xRange.lowerBound),
                                             abs($0 - PlayerState.xRange.upperBound)) }.max() ?? 0
        #expect(abs(widest - 7.6) < 1e-9)
        let accelTime = PlayerState.maxSpeed / PlayerState.acceleration                  // 0.15 s
        let accelDistance = 0.5 * PlayerState.acceleration * accelTime * accelTime      // 0.675 units
        let crossing = accelTime + (widest - accelDistance) / PlayerState.maxSpeed      // ≈ 0.92 s
        #expect(crossing < 1)
        // The row: spawned at y 16.5, it touches the player's line (y 1.5) once its distance is the summed radii.
        let rowFall = (GameSimulation.spawnY - GameRun.playerY - WaveDirector.wallRadius - PlayerState.hitRadius)
            / Difficulty.ceiling.fallSpeed.upperBound                                    // 2.82 s
        #expect(rowFall > 2.8 && crossing < rowFall / 2)
        // Simulated: from rest at the left wall, full steering reaches lane 4's centre well before the row arrives.
        var game = GameRun.new()
        game.player.x = PlayerState.xRange.lowerBound
        var random = SeededRandom(seed: 1)
        GameSimulation.steer(&game, value: 1)
        var steps = 0
        while game.player.x < Lanes.centre(4) && steps < 600 {
            GameSimulation.advance(&game, catalog: ArcadeCatalog(items: []), random: &random)
            steps += 1
        }
        #expect(steps <= 60 && Double(steps) * GameSimulation.step < rowFall)
    }

    @Test func zigzagWalksTheLanesAndBack() {
        var run = GameRun.new()
        run.wave = 3; run.patternId = "zigzag"
        var random = SeededRandom(seed: 4)
        let start = random
        let steps = direct(&run, &random, steps: 599)
        let lanes = steps.flatMap(\.requests).map(\.lane)
        let gap = Difficulty(wave: 3).spawnGap
        #expect(lanes.count == (599 - 30) / gap + 1)
        #expect(Array(lanes.prefix(10)) == [0, 1, 2, 3, 4, 3, 2, 1, 0, 1])
        #expect(steps.flatMap(\.requests).allSatisfy { $0.kind == .hazard && $0.contentId == "spike-ball"
                                                       && $0.radius == nil && $0.fallSpeed == nil })
        #expect(random == start)   // zigzag draws nothing
    }

    @Test func anOrbTrailGuardsEverySecondOrb() {
        for trail in 0..<Lanes.count {
            var run = GameRun.new()
            run.wave = 2; run.patternId = "orb-trail"; run.patternCursor = trail
            var random = SeededRandom(seed: 8)
            let spawns = direct(&run, &random, steps: 599).map(\.requests).filter { !$0.isEmpty }
            #expect(spawns.count == (599 - 30) / Difficulty(wave: 2).spawnGap + 1)
            let guards = [trail - 1, trail + 1].filter { (0..<5).contains($0) }
            for (n, requests) in spawns.enumerated() {
                #expect(requests.first == SpawnRequest(lane: trail, kind: .orb, contentId: "glow-orb"))
                let bars = requests.dropFirst()
                #expect(bars.map(\.lane) == (n % 2 == 1 ? guards : []))
                #expect(bars.allSatisfy { $0.kind == .hazard && $0.contentId == "bar" })
            }
        }
    }

    @Test func rainSpawnsOneObjectPerGapAndTheOrbTrailLaneIsDrawnAtTheWaveStart() {
        var run = GameRun.new()
        var random = SeededRandom(seed: 21)
        let steps = direct(&run, &random, steps: 600)
        let spawns = steps.filter { !$0.requests.isEmpty }
        #expect(spawns.map(\.waveStep) == Array(stride(from: 30, through: 599, by: 40)))
        #expect(spawns.allSatisfy { $0.requests.count == 1 && $0.requests[0].contentId == nil })
        #expect(Set(spawns.map { $0.requests[0].lane }).count > 1)
        #expect(run.wave == 2 && run.waveStep == 0 && run.patternId != "rain")
        // A wave that begins as orb-trail has its trail lane in the cursor; others start at 0.
        for seed in UInt64(1)...40 {
            var r = GameRun.new()
            var g = SeededRandom(seed: seed)
            _ = direct(&r, &g, steps: 1800)
            #expect((0..<8).contains(r.patternCursor) && r.validate().isEmpty)
            if r.patternId != "orb-trail" { #expect(r.patternCursor == 0) }
        }
    }

    @Test func theDirectorIsDeterministicAndChangesOnlyTheWaveFields() {
        var a = GameRun.new(), b = GameRun.new()
        var ra = SeededRandom(seed: 99), rb = SeededRandom(seed: 99)
        let sa = direct(&a, &ra, steps: 3000).map { "\($0.wave) \($0.patternId) \($0.requests)" }
        let sb = direct(&b, &rb, steps: 3000).map { "\($0.wave) \($0.patternId) \($0.requests)" }
        #expect(sa == sb && a == b && ra == rb)
        var stripped = a
        stripped.wave = 1; stripped.waveStep = 0; stripped.patternId = "rain"; stripped.freeLane = -1
        stripped.patternCursor = 0
        #expect(stripped == GameRun.new())
    }
}
