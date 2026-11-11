// LiveLimitTests — feature 034 A04-P02 T-A04-203 (G-PQUALITY; FR-A04-203; SC-A04-203; contract C5; research R4).
import Testing
import VisualCoreMath
@testable import VisualCoreSimulation

@Test func liveLimitIsClampedAndDefaultsToCapacity() {
    var ps = ParticleSystem(capacity: 500)
    #expect(ps.liveLimit == 500)
    ps.liveLimit = 0; #expect(ps.liveLimit == 1)
    ps.liveLimit = 9_999; #expect(ps.liveLimit == 500)
    ps.liveLimit = 120; #expect(ps.liveLimit == 120)
}

@Test func demandOfTenTimesTheLimitNeverExceedsIt() {
    // SC-A04-203: demand 10× the limit; live ≤ liveLimit ≤ capacity at every step; dropped = demand − created.
    // Lifetimes outlast the run, so created = the final live count.
    var ps = ParticleSystem(capacity: 4_000, seed: 5)
    ps.emitters = [Emitter(rate: 0, lifetime: 100...100, speed: 0...10)]
    ps.liveLimit = 2_400
    var demand = 0
    for _ in 0..<600 {
        ps.burst(40)                                // 600 × 40 = 24,000 = 10 × 2,400
        demand += 40
        ps.step(1.0 / 120)
        #expect(ps.aliveCount <= ps.liveLimit && ps.liveLimit <= ps.capacity)
    }
    #expect(demand == 10 * ps.liveLimit)
    #expect(ps.aliveCount == 2_400)
    #expect(ps.droppedCount == demand - ps.aliveCount)
}

@Test func aLoweredLimitIsReachedByExpiryAndThenHeld() {
    // US3 AC2 with SC-A04-203: after the tier drops, live never grows while above the new limit, reaches it once the
    // older particles expire (lifetime 0.5 s), and stays at or below it; raising the limit lets it grow again.
    var ps = ParticleSystem(capacity: 4_000, seed: 6)
    ps.emitters = [Emitter(rate: 0, lifetime: 0.5...0.5, speed: 0...10)]
    var previous = 0
    for step in 0..<720 {
        if step == 240 { ps.liveLimit = 800 }
        if step == 480 { ps.liveLimit = 4_000 }
        ps.burst(400)
        ps.step(1.0 / 120)
        if ps.aliveCount > ps.liveLimit { #expect(ps.aliveCount <= previous, "never grows above the limit") }
        if (301..<480).contains(step) { #expect(ps.aliveCount <= 800) }
        if step == 479 { #expect(ps.aliveCount == 800) }
        previous = ps.aliveCount
    }
    #expect(ps.aliveCount > 800)
}

@Test func loweringTheLimitRemovesNobody() {
    var ps = ParticleSystem(capacity: 1_000, seed: 1)
    ps.emitters = [Emitter(rate: 0, lifetime: 10...10)]
    ps.burst(1_000)
    ps.step(1.0 / 120)
    #expect(ps.aliveCount == 1_000)
    ps.liveLimit = 100
    ps.burst(50)
    ps.step(1.0 / 120)
    #expect(ps.aliveCount == 1_000, "existing particles stay; nothing visibly vanishes")
    #expect(ps.droppedCount == 50)
}

@Test func untouchedLimitKeepsResultsIdentical() {
    func run(touch: Bool) -> UInt64 {
        var ps = ParticleSystem(capacity: 800, seed: 77)
        ps.emitters = [Emitter(rate: 2_000, lifetime: 0.5...1.5)]
        ps.forces = [.gravity(Vec2(0, -100))]
        if touch { ps.liveLimit = ps.capacity }
        for _ in 0..<300 { ps.step(1.0 / 120) }
        return ps.checksum()
    }
    #expect(run(touch: false) == run(touch: true))
}
