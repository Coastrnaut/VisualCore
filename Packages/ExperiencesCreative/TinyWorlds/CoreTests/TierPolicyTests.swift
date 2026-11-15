// TierPolicyTests — feature 093 (A12-P05) T-A12-502 (FR-A12-502; SC-A12-502; clarification 3). Scripted pressure
// sequences on the frame clock, host-free: the host level alone (clamped), Low Power Mode, a memory warning held until
// 30 s after it, repeated warnings restarting the hold, Low Power Mode from time 0, and non-finite times ignored.
import Foundation
import Testing
import TinyWorldsCore

@Suite struct TierPolicyTests {
    @Test func withoutPressureTheHostLevelIsDrawn() {
        let policy = TierPolicy()
        let tiers = [0, 1, 2, 0].map { policy.tier(host: $0, lowPower: false, now: 5) }
        #expect(tiers == [0, 1, 2, 0])
        #expect(policy.tier(host: -4, lowPower: false, now: 0) == 0)
        #expect(policy.tier(host: 9, lowPower: false, now: 0) == 2)
    }

    @Test func lowPowerModeDrawsTheLightestTierWhileOn() {
        let policy = TierPolicy()
        #expect(policy.tier(host: 0, lowPower: true, now: 0) == 2, "from the first frame")
        #expect(policy.tier(host: 1, lowPower: true, now: 10) == 2)
        #expect(policy.tier(host: 0, lowPower: false, now: 11) == 0, "back when it ends")
    }

    @Test func memoryWarningHoldsTheLowestTierForThirtySeconds() {
        var policy = TierPolicy()
        policy.recordMemoryWarning(at: 10)
        #expect(policy.tier(host: 0, lowPower: false, now: 10) == 2)
        #expect(policy.tier(host: 0, lowPower: false, now: 39.9) == 2)
        #expect(policy.tier(host: 0, lowPower: false, now: 40) == 0)
        #expect(policy.tier(host: 1, lowPower: false, now: 40) == 1)
    }

    @Test func repeatedWarningsRestartTheHoldAndNeverGoBelowTheLightest() {
        var policy = TierPolicy()
        for t in stride(from: 0.0, through: 20, by: 5) { policy.recordMemoryWarning(at: t) }
        #expect(policy.lastWarning == 20)
        #expect(policy.tier(host: 2, lowPower: true, now: 25) == 2)
        #expect(policy.tier(host: 0, lowPower: false, now: 49.9) == 2)
        #expect(policy.tier(host: 0, lowPower: false, now: 50) == 0)
    }

    @Test func nonFiniteTimesAreIgnored() {
        var policy = TierPolicy()
        policy.recordMemoryWarning(at: .nan)
        policy.recordMemoryWarning(at: .infinity)
        #expect(policy.lastWarning == nil)
        #expect(policy.tier(host: 0, lowPower: false, now: .nan) == 0)
        policy.recordMemoryWarning(at: 1)
        #expect(policy.tier(host: 0, lowPower: false, now: .nan) == 2, "an unknown time keeps a received warning")
    }
}
