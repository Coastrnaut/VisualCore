// ParticleBudgetTests — feature 034 A04-P02 T-A04-204 (G-PQUALITY; FR-A04-203; SC-A04-204; contract C6, C7).
import Testing
@testable import VisualCoreDiagnostics

@Test func standardTableForFourThousand() {
    let b = ParticleBudget.standard
    #expect((0...3).map { b.limit(requested: 4_000, tier: $0) } == [4_000, 2_400, 1_400, 800])
    #expect(b.limit(requested: 4_000, tier: 9) == 800, "tiers past the end use the last share")
    #expect(b.limit(requested: 4_000, tier: -2) == 4_000)
}

@Test func minimumAndRequestedBounds() {
    let b = ParticleBudget.standard
    #expect(b.limit(requested: 300, tier: 3) == 100, "0.2 × 300 = 60 is raised to the minimum")
    #expect(b.limit(requested: 50, tier: 3) == 50, "never above the request (research R3)")
    #expect(b.limit(requested: 0, tier: 0) == 0 && b.limit(requested: -5, tier: 1) == 0)
    #expect(b.limit(requested: 999, tier: 2) == 349, "rounded down")
    for requested in stride(from: 1, through: 20_000, by: 37) {
        for tier in 0...4 {
            let l = b.limit(requested: requested, tier: tier)
            #expect(l <= requested && l >= min(requested, 100))
        }
    }
}

@Test func sanitizedConstruction() {
    let b = ParticleBudget(shares: [2, -1, .nan], minimum: -3)
    #expect(b.shares == [1, 0, 1] && b.minimum == 0)
    #expect(ParticleBudget(shares: [], minimum: 10).shares == [1])
}

@Test func seriousHeatLowersTheLimitAndCalmRaisesIt() {
    // SC-A04-204: QualityPolicy(tierCount: 4, lowPowerCeiling: 1) drives the budget.
    var policy = QualityPolicy(tierCount: 4, lowPowerCeiling: 1)
    let b = ParticleBudget.standard
    #expect(b.limit(requested: 4_000, tier: policy.decide(thermal: .serious, lowPower: false, now: 0)) == 2_400,
            "the first decision steps down at once")
    #expect(b.limit(requested: 4_000, tier: policy.decide(thermal: .serious, lowPower: false, now: 1)) == 2_400,
            "at most one change per decision interval")
    #expect(b.limit(requested: 4_000, tier: policy.decide(thermal: .critical, lowPower: false, now: 2)) == 1_400)
    var t = 2.0, limit = 1_400
    while t < 40 { t += 0.5; limit = b.limit(requested: 4_000, tier: policy.decide(thermal: .nominal, lowPower: false, now: t)) }
    #expect(limit == 4_000, "after calm periods the limit returns to the request")
}

@Test func lowPowerHoldsAtTierOne() {
    var policy = QualityPolicy(tierCount: 4, lowPowerCeiling: 1)
    var t = 0.0, tier = 0
    while t < 60 { tier = policy.decide(thermal: .nominal, lowPower: true, now: t); t += 1 }
    #expect(tier == 1)
    #expect(ParticleBudget.standard.limit(requested: 4_000, tier: tier) == 2_400)
}

@Test func currentConditionsAreReadable() {
    let c = DeviceConditions.current()
    #expect(FramePacing.Thermal.allCases.contains(c.thermal))
    #expect(DeviceConditions.nominal == DeviceConditions(thermal: .nominal, lowPower: false))
}
