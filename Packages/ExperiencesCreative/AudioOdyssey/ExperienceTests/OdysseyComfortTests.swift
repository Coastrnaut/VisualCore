// OdysseyComfortTests — feature 056 (A07-P03) T-A07-303 (FR-A07-301–303; SC-A07-301–303; story 1). The pace of Audio
// Odyssey on the adapter core, simulated steps only (no wall clock, each test well under 10 s): 200 seeded sequences
// of `speed.set` and `easing.select` keep the speed and its change per step within the active limits and settle within
// 1 % of every reachable target; the gentle easing takes at least twice as long as brisk to go from 2 to 7 units/s;
// calm motion, in-app (`comfort.calm`) or mirrored from the system (`comfort.reduce-motion`), caps the speed at
// 2.5 units/s with no sway under every easing.
import Foundation
import Testing
@testable import AudioOdysseyExperience
import AudioOdysseyCore
import VisualCoreExperience
import VisualCoreMath

/// SplitMix64: a small seeded generator for the sequences (deterministic for a seed).
private struct SplitMix {
    var state: UInt64

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// A value in `0..<bound`.
    mutating func below(_ bound: Int) -> Int { Int(next() % UInt64(bound)) }
}

/// Applies `control` with `values` to `core` and returns whether it was accepted.
@discardableResult
private func send(_ core: inout OdysseyCore, _ control: String, _ values: [Double] = []) -> Bool {
    core.apply(ExperienceAction(control: control, values: values, step: 0)).isAccepted
}

/// Advances `core` by one step; returns a description of the first broken rule (speed above the limit, a change
/// above the acceleration in force for that step, distance going back), or nil. The callers count the problems and
/// expect once, so a sequence of thousands of steps stays fast.
private func step(_ core: inout OdysseyCore) -> String? {
    let limits = core.limits
    let before = core.state
    core.update(step: 0)
    let after = core.state
    if after.speed > limits.maxSpeed + 1e-12 { return "speed \(after.speed) above \(limits.maxSpeed)" }
    if abs(after.speed - before.speed) > limits.maxAcceleration * OdysseyCore.stepDuration + 1e-12 {
        return "change \(after.speed - before.speed) above the acceleration \(limits.maxAcceleration)"
    }
    if after.distance < before.distance { return "distance went back" }
    return nil
}

/// Runs `count` steps and returns the problems found (at most the first 5).
private func run(_ core: inout OdysseyCore, _ count: Int) -> [String] {
    var problems: [String] = []
    for _ in 0..<max(0, count) {
        if let problem = step(&core), problems.count < 5 { problems.append(problem) }
    }
    return problems
}

/// The steps the flight needs to go from its speed to `target` under its limits, plus a margin of 10.
private func stepsToSettle(_ core: OdysseyCore, at target: Double) -> Int {
    let gap = abs(min(target, core.limits.maxSpeed) - core.state.speed)
    return Int((gap / core.limits.maxAcceleration / OdysseyCore.stepDuration).rounded(.up)) + 10
}

@Suite struct OdysseyComfortTests {
    @Test func seededSpeedAndEasingSequencesStayWithinTheLimitsAndSettle() {
        var problems: [String] = []
        var unsettled: [String] = []
        for seed in 0..<200 {
            var rng = SplitMix(state: UInt64(seed) &* 0x2545_F491_4F6C_DD1D &+ 1)
            var core = OdysseyCore(seed: UInt64(seed))
            for _ in 0..<6 {
                if rng.below(2) == 0 {
                    let target = 0.5 + 0.5 * Double(rng.below(14))   // 0.5 … 7 on the 0.5 grid
                    #expect(send(&core, "speed.set", [target]))
                    #expect(core.state.speedTarget == target)
                } else {
                    let easing = rng.below(3)
                    #expect(send(&core, "easing.select", [Double(easing)]))
                    #expect(core.state.easing.rawValue == easing)
                }
                problems += run(&core, 30 + rng.below(211)).map { "seed \(seed): \($0)" }
            }
            // The final target is reachable (≤ 7 < the standard maximum 8): it settles within 1 %.
            let target = core.state.speedTarget
            problems += run(&core, stepsToSettle(core, at: target)).map { "seed \(seed): \($0)" }
            if abs(core.state.speed - target) > 0.01 * target {
                unsettled.append("seed \(seed): \(core.state.speed) vs \(target)")
            }
            #expect(core.limits.maxAcceleration
                    == ComfortLimits.standard.maxAcceleration * core.state.easing.accelerationFactor)
        }
        #expect(problems.isEmpty, "\(problems.prefix(10))")
        #expect(unsettled.isEmpty, "\(unsettled.prefix(10))")
    }

    @Test func gentleTakesAtLeastTwiceAsLongAsBriskFromSlowToFast() {
        func settleSteps(_ easing: Easing) -> Int {
            var core = OdysseyCore(seed: 7)
            send(&core, "easing.select", [Double(Easing.brisk.rawValue)])
            send(&core, "speed.set", [2])
            #expect(run(&core, 400).isEmpty)   // 2 / 1.5 ≈ 1.33 s
            #expect(core.state.speed == 2)
            send(&core, "easing.select", [Double(easing.rawValue)])
            send(&core, "speed.set", [7])
            var count = 0
            var problems: [String] = []
            while abs(core.state.speed - 7) > 0.01 * 7, count < 5_000 {
                if let problem = step(&core), problems.count < 5 { problems.append(problem) }
                count += 1
            }
            #expect(problems.isEmpty, "\(easing): \(problems)")
            #expect(count < 5_000, "\(easing) settles")
            return count
        }
        let gentle = settleSteps(.gentle), standard = settleSteps(.standard), brisk = settleSteps(.brisk)
        #expect(Double(gentle) >= 2 * Double(brisk), "gentle \(gentle) steps, brisk \(brisk)")
        #expect(gentle > standard && standard > brisk)
    }

    @Test func calmMotionCapsTheSpeedAndRemovesTheSway() {
        for control in ["comfort.calm", "comfort.reduce-motion"] {
            for easing in Easing.allCases {
                var core = OdysseyCore(seed: 11)
                #expect(send(&core, control, [1]))
                #expect(core.calmInEffect)
                #expect(send(&core, "easing.select", [Double(easing.rawValue)]))
                #expect(send(&core, "speed.set", [7]))
                #expect(core.limits.maxSpeed == ComfortLimits.reducedMotion.maxSpeed)
                var top = 0.0, swayed = 0, problems: [String] = []
                for _ in 0..<stepsToSettle(core, at: 7) {
                    if let problem = step(&core), problems.count < 5 { problems.append(problem) }
                    top = max(top, core.state.speed)
                    if core.flight.sway(limits: core.limits) != 0 { swayed += 1 }
                }
                #expect(problems.isEmpty, "\(control) \(easing): \(problems)")
                #expect(top <= 2.5 + 1e-12, "\(control) \(easing): \(top)")
                #expect(swayed == 0, "\(control) \(easing): sway in \(swayed) steps")
                #expect(abs(top - 2.5) < 1e-9, "\(control) \(easing): the calm cap is reached and held: \(top)")
                #expect(core.state.speedTarget == 7, "the chosen speed is kept, only capped")
            }
        }
        // The in-app setting is state (in the digest); the system mirror is not.
        var calm = OdysseyCore(seed: 3), mirrored = OdysseyCore(seed: 3)
        send(&calm, "comfort.calm", [1])
        send(&mirrored, "comfort.reduce-motion", [1])
        #expect(calm.state.calmMotion && !mirrored.state.calmMotion)
        #expect(calm.state.digestText.contains("|calm=1|") && mirrored.state.digestText.contains("|calm=0|"))
        // Off again: the standard limits apply.
        send(&calm, "comfort.calm", [0])
        #expect(!calm.calmInEffect)
        #expect(calm.limits.maxSpeed == ComfortLimits.standard.maxSpeed)
    }
}
