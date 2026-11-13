// FrameBudgetMonitorTests — feature 037 A04-P05 T-A04-504 (US2; FR-A04-510 to FR-A04-514; clarification 1). The drawn
// detail follows the frame times: more than 25% of the last 120 frames over 1.2× the budget steps down one tier, at
// least 95% of the last 600 under 0.8× the budget steps up one tier, both windows restart after a change.
import Testing
@testable import ParticleUniverseCore

private let budget = 1.0 / 60
private let slow = budget * 1.5      // over 1.2× the budget
private let onTime = budget          // neither slow nor fast
private let fast = budget * 0.5      // under 0.8× the budget

private func feed(_ monitor: inout FrameBudgetMonitor, _ time: Double, count: Int) {
    for _ in 0..<count { monitor.record(frameTime: time) }
}

@Test func startsAtFullDetail() {
    let m = FrameBudgetMonitor()
    #expect(m.tier == 0)
}

@Test func moreThanAQuarterOfSlowFramesStepsDownOneTier() {
    var m = FrameBudgetMonitor()
    feed(&m, slow, count: 31)
    feed(&m, onTime, count: 88)
    #expect(m.tier == 0, "the window of 120 is not complete yet")
    #expect(m.record(frameTime: onTime) == 1, "31 of 120 frames slow: more than 25%")
}

@Test func exactlyAQuarterOfSlowFramesKeepsTheTier() {
    var m = FrameBudgetMonitor()
    feed(&m, slow, count: 30)
    feed(&m, onTime, count: 500)
    #expect(m.tier == 0)
}

@Test func framesAtExactlyTheThresholdAreNotSlow() {
    var m = FrameBudgetMonitor()
    feed(&m, budget * 1.2, count: 240)
    #expect(m.tier == 0)
}

@Test func sustainedSlowFramesStepOneTierPerWindow() {
    var m = FrameBudgetMonitor()
    feed(&m, slow, count: 119)
    #expect(m.tier == 0)
    #expect(m.record(frameTime: slow) == 1)
    feed(&m, slow, count: 119)
    #expect(m.tier == 1, "the window restarted after the change")
    #expect(m.record(frameTime: slow) == 2)
    feed(&m, slow, count: 120)
    #expect(m.tier == 3)
    feed(&m, slow, count: 1_200)
    #expect(m.tier == 3, "never above maxTier")
}

@Test func headroomStepsUpOneTierPerWindow() {
    var m = FrameBudgetMonitor()
    feed(&m, slow, count: 360)
    #expect(m.tier == 3)
    feed(&m, fast, count: 599)
    #expect(m.tier == 3)
    #expect(m.record(frameTime: fast) == 2, "600 of 600 fast")
    feed(&m, fast, count: 599)
    #expect(m.tier == 2, "the window restarted after the change")
    #expect(m.record(frameTime: fast) == 1)
    feed(&m, fast, count: 600)
    #expect(m.tier == 0)
    feed(&m, fast, count: 3_000)
    #expect(m.tier == 0, "never below 0")
}

@Test func ninetyFivePercentFastIsEnoughAndLessIsNot() {
    var up = FrameBudgetMonitor()
    feed(&up, slow, count: 120)
    #expect(up.tier == 1)
    feed(&up, onTime, count: 30)
    feed(&up, fast, count: 570)
    #expect(up.tier == 0, "570 of 600 fast: 95%")

    var stay = FrameBudgetMonitor()
    feed(&stay, slow, count: 120)
    feed(&stay, onTime, count: 31)
    feed(&stay, fast, count: 569)
    #expect(stay.tier == 1, "569 of 600 fast: below 95%")
}

@Test func aSingleSlowFrameChangesNothing() {
    var m = FrameBudgetMonitor()
    m.record(frameTime: 1.0)
    feed(&m, onTime, count: 1_000)
    #expect(m.tier == 0)
    var lowered = FrameBudgetMonitor()
    feed(&lowered, slow, count: 120)
    lowered.record(frameTime: 0.5)
    feed(&lowered, onTime, count: 500)
    #expect(lowered.tier == 1)
}

@Test func restartClearsTheWindowsAndKeepsTheTier() {
    var m = FrameBudgetMonitor()
    feed(&m, slow, count: 100)
    m.restart()
    #expect(m.tier == 0)
    feed(&m, slow, count: 30)
    feed(&m, onTime, count: 90)
    #expect(m.tier == 0, "the 100 slow frames before the restart are forgotten")

    var lowered = FrameBudgetMonitor()
    feed(&lowered, slow, count: 120)
    #expect(lowered.tier == 1)
    feed(&lowered, fast, count: 500)
    lowered.restart()
    #expect(lowered.tier == 1, "a restart keeps the tier")
    feed(&lowered, fast, count: 500)
    #expect(lowered.tier == 1, "the restart cleared the fast frames too")
    feed(&lowered, fast, count: 100)
    #expect(lowered.tier == 0)
}

@Test func nonFiniteAndNonPositiveTimesAreIgnored() {
    var m = FrameBudgetMonitor()
    for bad in [Double.nan, .infinity, -.infinity, 0, -1, -.ulpOfOne] {
        feed(&m, bad, count: 200)
    }
    let reference = FrameBudgetMonitor()
    #expect(m == reference, "nothing was recorded")
    feed(&m, slow, count: 60)
    feed(&m, .nan, count: 100)
    feed(&m, onTime, count: 59)
    #expect(m.tier == 0, "the ignored frames did not fill the window")
    #expect(m.record(frameTime: onTime) == 1)
}

@Test func theTierStaysWithinItsRange() {
    var m = FrameBudgetMonitor(budget: 1.0 / 120, maxTier: 1)
    feed(&m, 1.0 / 30, count: 1_000)
    #expect(m.tier == 1)
    feed(&m, 1.0 / 1_000, count: 3_000)
    #expect(m.tier == 0)
    var none = FrameBudgetMonitor(maxTier: -2)
    feed(&none, slow, count: 1_000)
    #expect(none.tier == 0, "a negative maxTier means a single tier")
}

@Test func theBudgetScalesTheThresholds() {
    var m = FrameBudgetMonitor(budget: 1.0 / 30)
    feed(&m, 1.0 / 40, count: 1_200)   // 0.75× of a 1/30 s budget: fast, already at tier 0
    #expect(m.tier == 0)
    feed(&m, 1.0 / 20, count: 120)     // 1.5× the budget
    #expect(m.tier == 1)
    var sixty = FrameBudgetMonitor()
    feed(&sixty, 1.0 / 40, count: 120) // 1/40 s is slow against 1/60 s
    #expect(sixty.tier == 1)
}

@Test func theSameSequenceGivesTheSameTiers() {
    var generator = SplitMix(seed: 42)
    var times: [Double] = []
    for _ in 0..<5_000 { times.append(budget * (0.3 + 1.4 * generator.unit())) }
    var a = FrameBudgetMonitor(), b = FrameBudgetMonitor()
    let tiersA = times.map { a.record(frameTime: $0) }
    let tiersB = times.map { b.record(frameTime: $0) }
    #expect(tiersA == tiersB)
    #expect(a == b)
}

/// A small deterministic generator for the frame-time sequence.
private struct SplitMix {
    var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func unit() -> Double {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        z ^= z >> 31
        return Double(z >> 11) / Double(1 << 53)
    }

}

// MARK: T-A04-516 — the budget from the host's frame interval

@Test func aMonitorStartsAtAGivenTierWithinItsBounds() {
    #expect(FrameBudgetMonitor(budget: 1.0 / 120, tier: 2).tier == 2)
    #expect(FrameBudgetMonitor(budget: 1.0 / 120, tier: 2).budget == 1.0 / 120)
    #expect(FrameBudgetMonitor(maxTier: 3, tier: 9).tier == 3)
    #expect(FrameBudgetMonitor(tier: -1).tier == 0)
}

private func near(_ a: Double?, _ b: Double) -> Bool { a.map { abs($0 - b) < 1e-9 } ?? false }

@Test func theIntervalIsTheSmallestStepBetweenConsecutiveTargets() {
    var estimate = FrameIntervalEstimate()
    #expect(estimate.observe(index: 0, target: 100) == nil)
    #expect(near(estimate.observe(index: 1, target: 100 + 2.0 / 60), 2.0 / 60))
    #expect(near(estimate.observe(index: 2, target: 100 + 3.0 / 60), 1.0 / 60))
    // A late frame skips whole intervals: its longer step leaves the estimate unchanged.
    #expect(near(estimate.observe(index: 3, target: 100 + 6.0 / 60), 1.0 / 60))
}

@Test func stepsAcrossGapsOutOfRangeOrNotFiniteAreIgnored() {
    var estimate = FrameIntervalEstimate()
    estimate.observe(index: 0, target: 10)
    #expect(estimate.observe(index: 2, target: 10 + 1.0 / 60) == nil, "a gap in the frame index")
    #expect(estimate.observe(index: 3, target: 10 + 1.0 / 60 + 0.001) == nil, "shorter than 1/240 s")
    #expect(estimate.observe(index: 4, target: 20) == nil, "longer than 0.1 s")
    #expect(estimate.observe(index: 5, target: .nan) == nil)
    #expect(near(estimate.observe(index: 5, target: 20 + 1.0 / 120), 1.0 / 120))
    estimate.reset()
    #expect(estimate.interval == nil)
    #expect(estimate.observe(index: 6, target: 30) == nil, "the first frame after a reset has no step")
}
