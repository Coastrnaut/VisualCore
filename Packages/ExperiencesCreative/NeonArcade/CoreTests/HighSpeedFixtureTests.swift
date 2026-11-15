// HighSpeedFixtureTests — feature 077 (A10-P03) T-A10-303 (FR-A10-330; clarification 5; research D5; SC-A10-305).
// The regression fixture of the manual's Phase 03 and the remaining proof of G-COLLISION2D: a circle hazard of radius
// 0.4 falling at 20, 50 and 100 units/s straight through the resting player (x 4.5, y 1.5, radius 0.4) within one
// step starts out of contact (centre distance 0.81 > 0.8, or half a step's displacement when that is larger) and is
// hit at that very step — at 100 units/s (1.67 units per step) it is out of contact at both ends of the step, so only
// the swept test catches it; the same hazard 1.5 units sideways passes without a hit. The hazard exists before the
// step (not spawned in it) and the run is at wave step 0, where the wave director spawns nothing (first spawn at 30).
import Foundation
import Testing
import VisualCoreMath
import VisualCoreSimulation
import NeonArcadeCore

@Suite struct HighSpeedFixtureTests {
    static let speeds: [Double] = [20, 50, 100]
    private let hazardRadius = 0.4
    private let contact = PlayerState.hitRadius + 0.4

    /// A fresh run at `step` (wave step 0) with the player resting at x 4.5 and one circle hazard (id 0) at
    /// `x` falling at `speed`, placed above the player so that its path crosses the player's line within one step.
    private func fixture(speed: Double, x: Double, step: Int = 120) -> GameRun {
        var run = GameRun.new()
        run.step = step
        let displacement = speed * GameSimulation.step
        let y = GameRun.playerY + max(contact + 0.01, displacement / 2)
        run.objects = [FallingObject(id: 0, contentId: "spike-ball", kind: .hazard, position: Vec2(x, y),
                                     velocity: Vec2(0, -speed), radius: hazardRadius)]
        run.nextObjectId = 1
        return run
    }

    @Test(arguments: speeds) func aFastHazardThroughThePlayerIsHitAtThatStep(speed: Double) {
        var run = fixture(speed: speed, x: GameRun.fieldWidth / 2)
        #expect(run.validate().isEmpty)
        #expect(run.waveStep == 0 && WaveDirector.firstSpawnStep > 0)
        let start = run.objects[0].position
        let end = start + run.objects[0].velocity * GameSimulation.step
        #expect(start.y - GameRun.playerY > contact)               // Out of contact before the step.
        #expect(end.y < GameRun.playerY + contact)                  // Its path reaches the player in the step.
        if speed == 100 { #expect(GameRun.playerY - end.y > contact) }   // Tunnels: out of contact after it too.
        let before = run.step
        var random = SeededRandom(seed: 7)
        GameSimulation.advance(&run, catalog: .bundled, random: &random)
        #expect(run.events == [CollisionEvent(step: before, objectId: 0, kind: .hit)])
        #expect(run.eventCount == 1)
        #expect(run.lives == GameRun.startLives - 1)
        #expect(run.player.invulnerableSteps == PlayerState.invulnerabilitySteps - 1)
        #expect(!run.objects.contains(where: { $0.id == 0 }))
        #expect(run.objects.isEmpty)                                // Nothing spawned at wave step 0.
    }

    @Test(arguments: speeds) func theSameHazardBesideThePlayerPasses(speed: Double) {
        var run = fixture(speed: speed, x: GameRun.fieldWidth / 2 + 1.5)
        #expect(run.validate().isEmpty)
        var random = SeededRandom(seed: 7)
        GameSimulation.advance(&run, catalog: .bundled, random: &random)
        #expect(run.events.isEmpty)
        #expect(run.eventCount == 0)
        #expect(run.lives == GameRun.startLives)
        #expect(run.objects.map(\.id) == [0])
        #expect(abs(run.objects[0].position.y - (GameRun.playerY + max(contact + 0.01, speed / 120) - speed / 60))
                < 1e-12)
    }
}
