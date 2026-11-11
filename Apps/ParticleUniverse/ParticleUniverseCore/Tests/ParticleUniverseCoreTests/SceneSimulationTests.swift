// SceneSimulationTests — feature 033 T-A04-108 (FR-A04-105; spec edge cases: ignored commands, rebuild from the seed).
import Testing
import VisualCoreMath
import VisualCoreSimulation
@testable import ParticleUniverseCore

private let scene = ParticleScene(seed: 7, particleLimit: 1_000,
                                  emitters: [SceneEmitter(family: .fountain), SceneEmitter(family: .firework)],
                                  forces: [.attractor(x: 0, y: 0, strength: 300, radius: 300), .drag(k: 0.1)])

@Test func invalidScenesAreNotBuilt() {
    var bad = scene
    bad.particleLimit = 5
    #expect(throws: SceneError.limitOutOfRange(5)) { try SceneSimulation(scene: bad) }
}

@Test func forcesComeFromTheSceneThenTheFamilies() throws {
    let sim = try SceneSimulation(scene: scene)
    #expect(sim.liveCount == 0 && sim.stepIndex == 0)
    var s = sim
    s.run(steps: 1)
    #expect(s.liveCount > 0 && s.liveCount <= 1_000)
}

@Test func commandsApplyAndInvalidOnesAreCounted() throws {
    var sim = try SceneSimulation(scene: scene)
    sim.apply(.setEmitting(emitter: 0, on: false))
    sim.apply(.setEmitting(emitter: 1, on: false))
    sim.run(steps: 1)
    #expect(sim.liveCount == 0, "both emitters stopped")
    sim.apply(.burst(emitter: 0, count: 1_000_000))   // clamped to 5,000, then limited by the pool (1,000)
    sim.run(steps: 1)
    #expect(sim.liveCount == 1_000)
    #expect(sim.droppedCount == 4_000)
    sim.apply(.moveAttractor(index: 1, x: 3, y: 4))    // index 1 is drag, not an attractor
    sim.apply(.moveAttractor(index: 7, x: 3, y: 4))
    sim.apply(.burst(emitter: 5, count: 1))
    sim.apply(.setEmitting(emitter: -1, on: true))
    sim.apply(.moveAttractor(index: 0, x: .nan, y: 0))
    #expect(sim.ignoredCommands == 5)
    sim.apply(.moveAttractor(index: 0, x: 3, y: 4))
    #expect(sim.ignoredCommands == 5)
}

@Test func sameSceneAndSeedGiveTheSameStateAndReseedingDiffers() throws {
    var a = try SceneSimulation(scene: scene), b = try SceneSimulation(scene: scene)
    a.run(steps: 300); b.run(steps: 300)
    #expect(a.checksum() == b.checksum())
    var other = scene
    other.seed = 8
    var c = try SceneSimulation(scene: other)
    c.run(steps: 300)
    #expect(c.checksum() != a.checksum())
}
