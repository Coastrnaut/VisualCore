// PlacedForceStabilityTests — feature 034 A04-P02 T-A04-209 (US2; FR-A04-202; SC-A04-202 at the app level; manual §11
// fixture 4: singularities).
import Testing
import VisualCoreMath
@testable import ParticleUniverseCore

@Test(arguments: PlacedForceKind.allCases)
func emittersOnAForceCenterStayFinite(kind: PlacedForceKind) throws {
    // Every family's emitter sits exactly on the force at strength 2; 10,000 fixed steps.
    let center = Vec2(120, -80)
    for family in EmitterFamily.allCases {
        var sim = try SceneSimulation(scene: ParticleScene(seed: 4, emitters: [SceneEmitter(family: family, position: center)]))
        sim.setPlacedForce(PlacedForce(kind: kind, position: center, strength: 2))
        sim.run(steps: 10_000)
        #expect(sim.nonFiniteRemoved == 0, "\(kind) on \(family)")
        #expect(sim.instances().allSatisfy { $0.position.isFinite && $0.size.isFinite })
        #expect(sim.liveCount > 0)
    }
}
