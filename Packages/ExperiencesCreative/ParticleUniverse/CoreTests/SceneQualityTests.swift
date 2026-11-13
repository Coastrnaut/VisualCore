// SceneQualityTests — feature 034 A04-P02 T-A04-210 (US3; FR-A04-205; SC-A04-203, SC-A04-204; manual §11 fixture 2).
import Testing
import VisualCoreDiagnostics
@testable import ParticleUniverseCore

private let hot = DeviceConditions(thermal: .serious, lowPower: false)

@Test func nominalKeepsTheRequestedLimit() {
    var q = SceneQuality()
    #expect(q.update(conditions: .nominal, now: 0, requested: 4_000) == 4_000 && q.tier == 0)
}

@Test func heatLowersTheLiveLimitAndTheSimulationYields() throws {
    // Fixture 2: a high count respects the cap and yields to the quality controller.
    var sim = try SceneSimulation(scene: ParticleScene(particleLimit: 2_000, emitters: [SceneEmitter(family: .curtain)]))
    var q = SceneQuality()
    var t = 0.0
    var limits: [Int] = []
    for frame in 0..<3_000 {          // 50 s at 60 frames/s: 10 s hot, then calm (three 10 s calm periods)
        let conditions = frame < 600 ? hot : .nominal
        let limit = q.update(conditions: conditions, now: t, requested: sim.scene.particleLimit)
        if limits.last != limit { limits.append(limit) }
        let before = sim.liveCount
        sim.setLiveLimit(limit)
        sim.advance(frame: 1.0 / 60)
        t += 1.0 / 60
        #expect(sim.liveCount <= max(limit, before), "never grows above the effective limit")
        #expect(sim.liveLimit == limit && limit <= 2_000)
    }
    #expect(limits.first == 1_200, "the first hot decision steps down at once (SC-A04-204)")
    #expect(limits.contains(400), "serious heat reaches the lowest tier")
    #expect(limits.last == 2_000, "calm periods restore the request")
    #expect(sim.droppedCount > 0)
}

@Test func lowPowerKeepsTierOne() {
    var q = SceneQuality()
    var limit = 0
    for i in 0..<120 { limit = q.update(conditions: DeviceConditions(thermal: .nominal, lowPower: true), now: Double(i), requested: 4_000) }
    #expect(q.tier == 1 && limit == 2_400)
    q.reset()
    #expect(q.tier == 0 && q.effectiveLimit == 0)
}
