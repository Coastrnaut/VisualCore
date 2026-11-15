// BalanceTests — feature 079 (A10-P05) T-A10-502 (FR-A10-510; clarification 3; research D3; SC-A10-503). The
// game's difficulty curve measured with the three simulated players over seeds 1…20, at most 6,000 steps each:
// idle median wave ≤ 2, dodger median wave ≥ 3, collector median score > dodger median score > idle median score.
// The players' steering rules are checked on hand-built runs, and the results are deterministic: two passes give the
// same final runs, and stepping in chunks of two steps (a 1/30 s frame of the experience) with a decision before each
// step gives the same final runs as stepping one at a time (1/60 s); the experience tests cover real frame pacing.
// Measures the curve, not anyone's ability.
import Foundation
import Testing
import VisualCoreMath
import VisualCoreSimulation
import NeonArcadeCore

@Suite struct BalanceTests {
    private static let seeds = Array(UInt64(1)...20)
    private static let maxSteps = 6_000

    /// The median of `values` (the mean of the two middle values for an even count).
    private func median(_ values: [Int]) -> Double {
        let sorted = values.sorted()
        let mid = sorted.count / 2
        return sorted.count % 2 == 0 ? Double(sorted[mid - 1] + sorted[mid]) / 2 : Double(sorted[mid])
    }

    /// The results of `kind` over the seeds.
    private func results(_ kind: SimulatedPlayer.Kind) -> [(waves: Int, score: Int)] {
        Self.seeds.map { SimulatedPlayer.play(kind, seed: $0, maxSteps: Self.maxSteps) }
    }

    /// The final run of `kind` stepping in frames of `stepsPerFrame` steps, deciding before each step.
    private func chunkedRun(_ kind: SimulatedPlayer.Kind, seed: UInt64, stepsPerFrame: Int) -> GameRun {
        var run = GameRun.new()
        var random = SeededRandom(seed: seed)
        var steps = 0
        while steps < Self.maxSteps, !run.over {
            for _ in 0..<stepsPerFrame where steps < Self.maxSteps && !run.over {
                let value = SimulatedPlayer.steering(kind, run: run)
                if value != run.steering { GameSimulation.steer(&run, value: value) }
                GameSimulation.advance(&run, catalog: .bundled, random: &random)
                steps += 1
            }
        }
        return run
    }

    @Test func theCurveMeetsItsTargets() {
        let idle = results(.idle), dodger = results(.dodger), collector = results(.collector)
        let idleWave = median(idle.map(\.waves)), dodgerWave = median(dodger.map(\.waves))
        let idleScore = median(idle.map(\.score)), dodgerScore = median(dodger.map(\.score))
        let collectorScore = median(collector.map(\.score))
        #expect(idleWave <= 2, "idle median wave \(idleWave)")
        #expect(dodgerWave >= 3, "dodger median wave \(dodgerWave)")
        #expect(collectorScore > dodgerScore, "collector \(collectorScore) vs dodger \(dodgerScore)")
        #expect(dodgerScore > idleScore, "dodger \(dodgerScore) vs idle \(idleScore)")
        for result in idle + dodger + collector { #expect(result.waves >= 1 && result.score >= 0) }
    }

    @Test func resultsAreDeterministicAndIndependentOfChunking() {
        for kind in SimulatedPlayer.Kind.allCases {
            for seed in Self.seeds.prefix(5) {
                let first = SimulatedPlayer.finalRun(kind, seed: seed, maxSteps: Self.maxSteps)
                let second = SimulatedPlayer.finalRun(kind, seed: seed, maxSteps: Self.maxSteps)
                #expect(first == second)
                #expect(chunkedRun(kind, seed: seed, stepsPerFrame: 2) == first)
                #expect(chunkedRun(kind, seed: seed, stepsPerFrame: 1) == first)
                let played = SimulatedPlayer.play(kind, seed: seed, maxSteps: Self.maxSteps)
                #expect(played.waves == first.wave && played.score == first.score)
                #expect(first.over || first.step == Self.maxSteps)
            }
        }
    }

    @Test func theIdlePlayerNeverSteers() {
        var run = GameRun.new()
        run.objects = [FallingObject(id: 0, contentId: "spike-ball", kind: .hazard, position: Vec2(4.5, 3),
                                     velocity: Vec2(0, -4), radius: 0.5)]
        run.nextObjectId = 1
        #expect(SimulatedPlayer.steering(.idle, run: run) == 0)
        let final = SimulatedPlayer.finalRun(.idle, seed: 7, maxSteps: 600)
        #expect(final.steering == 0 && final.player.x == GameRun.fieldWidth / 2)
    }

    @Test func theDodgerSteersAwayFromAThreatElseToTheCentre() {
        var run = GameRun.new()
        run.player.x = 4.0
        // A hazard 2 units above, 0.5 to the right: steer left, fully.
        run.objects = [FallingObject(id: 0, contentId: "spike-ball", kind: .hazard, position: Vec2(4.5, 3.5),
                                     velocity: Vec2(0, -4), radius: 0.5)]
        run.nextObjectId = 1
        #expect(SimulatedPlayer.steering(.dodger, run: run) == -1)
        // Too high (≥ 4 above): no threat; back to the centre lane (x 4.5), proportionally (0.5 / 0.5 = 1).
        run.objects[0].position = Vec2(4.5, 5.6)
        #expect(SimulatedPlayer.steering(.dodger, run: run) == 1)
        // Far sideways (edge gap above 1): no threat.
        run.objects[0].position = Vec2(7.0, 3.5)
        #expect(SimulatedPlayer.steering(.dodger, run: run) == 1)
        // An orb is never a threat; at the centre with no threat the dodger holds still.
        run.player.x = SimulatedPlayer.centreX
        run.objects = [FallingObject(id: 0, contentId: "glow-orb", kind: .orb, position: Vec2(4.5, 3),
                                     velocity: Vec2(0, -4), radius: 0.25, value: 10)]
        #expect(SimulatedPlayer.steering(.dodger, run: run) == 0)
        // Against the left wall a threat to the right sends it right (the away side has no room).
        run.player.x = 0.5
        run.objects = [FallingObject(id: 0, contentId: "spike-ball", kind: .hazard, position: Vec2(0.6, 3),
                                     velocity: Vec2(0, -4), radius: 0.5)]
        #expect(SimulatedPlayer.steering(.dodger, run: run) == 1)
    }

    @Test func theCollectorSeeksOrbsWhenSafe() {
        var run = GameRun.new()
        run.objects = [FallingObject(id: 0, contentId: "glow-orb", kind: .orb, position: Vec2(2.7, 6),
                                     velocity: Vec2(0, -4), radius: 0.25, value: 10)]
        run.nextObjectId = 1
        #expect(SimulatedPlayer.steering(.collector, run: run) == -1)
        #expect(SimulatedPlayer.steering(.dodger, run: run) == 0)
        // A threat comes first.
        run.objects.append(FallingObject(id: 1, contentId: "spike-ball", kind: .hazard, position: Vec2(4.2, 3),
                                         velocity: Vec2(0, -4), radius: 0.5))
        run.nextObjectId = 2
        #expect(SimulatedPlayer.steering(.collector, run: run) == 1)
        // A passed orb is ignored.
        run.objects = [FallingObject(id: 2, contentId: "glow-orb", kind: .orb, position: Vec2(2.7, 1.0),
                                     velocity: Vec2(0, -4), radius: 0.25, value: 10)]
        #expect(SimulatedPlayer.steering(.collector, run: run) == 0)
    }
}
