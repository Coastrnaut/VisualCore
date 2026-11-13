// EmitterSlotTests — feature 035 A04-P03 T-A04-307 (US1; FR-A04-304; SC-A04-301; research R4, R5; clarification 4).
import Testing
import VisualCoreMath
import VisualCoreSimulation
@testable import ParticleUniverseCore

private func run(_ sim: inout SceneSimulation, seconds: Double) { sim.run(steps: Int(seconds * 120)) }

@Test func oneToEightEmittersAllEmitWithinTheLimit() throws {
    // SC-A04-301.
    var sim = try SceneSimulation(scene: .single(.halo, seed: 9))
    sim.setLiveLimit(3_000)
    let families: [EmitterFamily] = [.fountain, .curtain, .firework, .halo, .fountain, .curtain, .halo]
    for (k, f) in families.enumerated() {
        let added = sim.addEmitter(SceneEmitter(family: f, position: SceneSimulation.placement(of: f, index: k + 1)))
        #expect(added)
    }
    #expect(sim.visibleEmitters.count == 8)
    let ninth = sim.addEmitter(SceneEmitter(family: .halo))
    #expect(!sim.canAddEmitter && !ninth, "8 is the maximum")
    var emitted = Set<Int>()
    for _ in 0..<600 {
        sim.run(steps: 1)
        #expect(sim.liveCount <= 3_000)
        for i in 0..<8 where sim.state.system.liveCount(source: i) > 0 { emitted.insert(i) }
    }
    #expect(emitted == Set(0..<8), "every emitter emits")
}

@Test func removingDeletesNoParticleAndRestylesNothing() throws {
    var sim = try SceneSimulation(scene: .single(.halo, seed: 4))
    sim.addEmitter(SceneEmitter(family: .fountain))
    run(&sim, seconds: 1)
    let before = sim.instances()
    let removed = sim.removeEmitter(at: 1)
    #expect(removed)
    #expect(sim.instances() == before, "same particles, same sizes and colors")
    #expect(sim.visibleEmitters.map(\.family) == [.halo] && sim.retiredSlots == 1)
    run(&sim, seconds: 0.5)
    #expect(sim.state.system.liveCount(source: 1) > 0, "the removed emitter's particles fade naturally")
    let last = sim.removeEmitter(at: 0), bad = sim.removeEmitter(at: 5)
    #expect(!last, "the last emitter stays")
    #expect(!bad)
}

@Test func retiredSlotsAreReusedOnlyAfterTheirParticlesFade() throws {
    var sim = try SceneSimulation(scene: .single(.halo, seed: 5))
    for k in 1...7 { sim.addEmitter(SceneEmitter(family: .curtain, position: SceneSimulation.placement(of: .curtain, index: k))) }
    run(&sim, seconds: 0.5)
    let removed = sim.removeEmitter(at: 3)
    #expect(removed)
    #expect(!sim.canAddEmitter, "8 slots busy while the removed emitter's particles fade")
    run(&sim, seconds: 3.5)   // Curtain particles live 2–3 s
    #expect(sim.state.system.liveCount(source: 3) == 0)
    #expect(sim.canAddEmitter)
    let reused = sim.addEmitter(SceneEmitter(family: .firework))
    #expect(reused)
    #expect(sim.slots.count == 8 && sim.retiredSlots == 0, "slot 3 was reused")
}

@Test func familyForcesFollowTheVisibleEmitters() throws {
    var sim = try SceneSimulation(scene: .single(.halo))
    let halo = sim.activeForces
    sim.addEmitter(SceneEmitter(family: .fountain))
    sim.addEmitter(SceneEmitter(family: .fountain))
    #expect(sim.activeForces == halo + EmitterFamily.fountain.forces(), "two Fountains bring one gravity")
    let r1 = sim.removeEmitter(at: 1), r2 = sim.removeEmitter(at: 1)
    #expect(r1 && r2)
    #expect(sim.activeForces == halo)
    sim.setPlacedForce(PlacedForce(kind: .vortex, position: .zero))
    let set = sim.setEmitter(at: 0, SceneEmitter(family: .firework))
    #expect(set)
    #expect(sim.activeForces == [PlacedForce(kind: .vortex, position: .zero).particleForce] + EmitterFamily.firework.forces(),
            "the placed force stays first")
}

@Test func placementAlternatesAndClamps() {
    let base = EmitterFamily.fountain.emitter().position
    #expect(SceneSimulation.placement(of: .fountain, index: 0) == base)
    #expect(SceneSimulation.placement(of: .fountain, index: 1) == Vec2(base.x + 150, base.y))
    #expect(SceneSimulation.placement(of: .fountain, index: 2) == Vec2(base.x - 150, base.y))
    #expect(SceneSimulation.placement(of: .fountain, index: 3) == Vec2(base.x + 300, base.y))
    #expect(SceneSimulation.placement(of: .fountain, index: 7) == Vec2(450, base.y), "clamped")
}

@Test func rebuildDropsRetiredSlotsAndKeepsOrder() throws {
    var sim = try SceneSimulation(scene: .single(.halo, seed: 1))
    sim.addEmitter(SceneEmitter(family: .curtain))
    sim.addEmitter(SceneEmitter(family: .firework))
    sim.removeEmitter(at: 1)
    let scene = sim.rebuildScene(seed: 77)
    #expect(scene.emitters.map(\.family) == [.halo, .firework] && scene.seed == 77)
    let rebuilt = try SceneSimulation(scene: scene)
    #expect(rebuilt.slots.count == 2 && rebuilt.retiredSlots == 0)
}
