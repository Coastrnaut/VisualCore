// QualityPolicyTests — feature 021 T-A02-301 (G-QUALITY; FR-A02-307, SC-A02-304; spec clarification 4).
import Testing
@testable import VisualCoreDiagnostics

@Test func startsAtBestTier() {
    let p = QualityPolicy(tierCount: 3)
    #expect(p.tier == 0 && p.stepsDown == 0 && p.stepsUp == 0)
}

@Test func seriousAndCriticalStepDownOneTierPerInterval() {
    var p = QualityPolicy(tierCount: 3)
    #expect(p.decide(thermal: .serious, lowPower: false, now: 0) == 1)
    #expect(p.decide(thermal: .critical, lowPower: false, now: 1) == 1, "within the 2 s interval nothing changes")
    #expect(p.decide(thermal: .critical, lowPower: false, now: 2) == 2)
    #expect(p.decide(thermal: .critical, lowPower: false, now: 10) == 2, "the floor is the last tier")
    #expect(p.stepsDown == 2)
}

@Test func recoveryNeedsTheCalmPeriodAndStepsOneTierAtATime() {
    var p = QualityPolicy(tierCount: 3)
    _ = p.decide(thermal: .serious, lowPower: false, now: 0)
    _ = p.decide(thermal: .serious, lowPower: false, now: 2)
    #expect(p.tier == 2)
    #expect(p.decide(thermal: .nominal, lowPower: false, now: 3) == 2, "calm just started")
    #expect(p.decide(thermal: .fair, lowPower: false, now: 12.9) == 2, "less than 10 s calm")
    #expect(p.decide(thermal: .nominal, lowPower: false, now: 13) == 1, "10 s calm: one tier up")
    #expect(p.decide(thermal: .nominal, lowPower: false, now: 15) == 1, "the calm period restarts after a step")
    #expect(p.decide(thermal: .nominal, lowPower: false, now: 23) == 0)
    #expect(p.stepsUp == 2)
}

@Test func interruptedCalmRestarts() {
    var p = QualityPolicy(tierCount: 2)
    _ = p.decide(thermal: .serious, lowPower: false, now: 0)
    _ = p.decide(thermal: .nominal, lowPower: false, now: 1)
    _ = p.decide(thermal: .serious, lowPower: false, now: 8)
    #expect(p.decide(thermal: .nominal, lowPower: false, now: 12) == 1, "calm restarted at 12")
    #expect(p.decide(thermal: .nominal, lowPower: false, now: 22) == 0)
}

@Test func oscillatingInputDoesNotOscillateTheTier() {
    var p = QualityPolicy(tierCount: 3)
    var changes = 0, last = 0
    for i in 0..<40 {
        let t = p.decide(thermal: i % 2 == 0 ? .serious : .nominal, lowPower: false, now: Double(i) * 0.5)
        if t != last { changes += 1; last = t }
    }
    #expect(changes <= 2, "only downward steps, never back up while pressure keeps returning")
    #expect(p.stepsUp == 0)
}

@Test func lowPowerCeilingIsRespected() {
    var p = QualityPolicy(tierCount: 3, lowPowerCeiling: 1)
    #expect(p.decide(thermal: .nominal, lowPower: true, now: 0) == 1, "Low Power steps down to the ceiling")
    #expect(p.decide(thermal: .nominal, lowPower: true, now: 30) == 1, "no step up beyond the ceiling while Low Power is on")
    #expect(p.decide(thermal: .nominal, lowPower: false, now: 31) == 1)
    #expect(p.decide(thermal: .nominal, lowPower: false, now: 41) == 0, "recovers after Low Power ends and calm passes")
}

@Test func invalidConfigurationFallsBack() {
    let p = QualityPolicy(tierCount: 0, lowPowerCeiling: 9, decisionInterval: -1, calmPeriod: .nan)
    #expect(p.tierCount == 1 && p.lowPowerCeiling == 0)
    #expect(p.decisionInterval == 2 && p.calmPeriod == 10)
    var single = p
    #expect(single.decide(thermal: .critical, lowPower: true, now: 0) == 0, "one tier: nothing to change")
}

@Test func nonFiniteTimeKeepsTheTier() {
    var p = QualityPolicy(tierCount: 3)
    #expect(p.decide(thermal: .critical, lowPower: false, now: .nan) == 0)
    #expect(p.decide(thermal: .critical, lowPower: false, now: .infinity) == 0)
}

@Test func resetReturnsToBest() {
    var p = QualityPolicy(tierCount: 3)
    _ = p.decide(thermal: .critical, lowPower: false, now: 0)
    p.reset()
    #expect(p.tier == 0)
    #expect(p.decide(thermal: .critical, lowPower: false, now: 0.5) == 1, "a reset also clears the interval")
}
