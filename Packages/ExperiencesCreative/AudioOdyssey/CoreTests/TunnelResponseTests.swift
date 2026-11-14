// TunnelResponseTests — feature 055 (A07-P02) T-A07-204 (FR-A07-210, FR-A07-211; SC-A07-203; data-model
// "TunnelResponse"). The audio response of the tunnel, host-free and short: rest values, bounds under random targets,
// the step limits, a step input, the return to rest in silence, the comfort settings, NaN targets and the breathing
// scale.
import Foundation
import Testing
import AudioOdysseyCore

@Suite struct TunnelResponseTests {
    /// A small seeded linear congruential generator for reproducible targets in 0…1 (with some outside values).
    private struct LCG {
        var state: UInt64
        mutating func next() -> Double {
            state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            return Double(state >> 11) / Double(1 << 53) * 1.4 - 0.2
        }
    }

    private let tolerance = 1e-12

    @Test func itStartsAtRest() {
        let response = TunnelResponse(reduceMotion: false, reduceFlashing: false)
        #expect(response.ripple == TunnelResponse.restRipple && response.ripple == 0.08)
        #expect(response.ambient == TunnelResponse.restAmbient && response.ambient == 0.35)
        #expect(response.rippleRange == 0...0.35)
        #expect(response.ambientRange == 0.30...0.70)
        #expect(response.rippleStepLimit == 0.02 && response.ambientStepLimit == 0.03)
    }

    @Test func boundsAndStepLimitsHoldForRandomTargets() {
        for (motion, flashing) in [(false, false), (true, false), (false, true), (true, true)] {
            var response = TunnelResponse(reduceMotion: motion, reduceFlashing: flashing)
            var random = LCG(state: 0xA07)
            for _ in 0..<1_000 {
                let before = response
                response.update(rippleTarget: random.next(), ambientTarget: random.next())
                #expect(response.rippleRange.contains(response.ripple))
                #expect(response.ambientRange.contains(response.ambient))
                #expect(abs(response.ripple - before.ripple) <= response.rippleStepLimit + tolerance)
                #expect(abs(response.ambient - before.ambient) <= response.ambientStepLimit + tolerance)
            }
        }
    }

    @Test func aStepInputReachesItsValueAfterTheLimitedUpdates() {
        var response = TunnelResponse(reduceMotion: false, reduceFlashing: false)
        let rippleUpdates = Int(((0.35 - 0.08) / 0.02).rounded(.up))
        let ambientUpdates = Int(((0.70 - 0.35) / 0.03).rounded(.up))
        for index in 1...max(rippleUpdates, ambientUpdates) {
            response.update(rippleTarget: 1, ambientTarget: 1)
            if index == rippleUpdates - 1 { #expect(response.ripple < 0.35 - tolerance) }
            if index == rippleUpdates { #expect(abs(response.ripple - 0.35) < tolerance) }
            if index == ambientUpdates - 1 { #expect(response.ambient < 0.70 - tolerance) }
            if index == ambientUpdates { #expect(abs(response.ambient - 0.70) < tolerance) }
        }
        // The first update of the step moves by exactly one step limit (no jump).
        var fresh = TunnelResponse(reduceMotion: false, reduceFlashing: false)
        fresh.update(rippleTarget: 1, ambientTarget: 1)
        #expect(abs(fresh.ripple - 0.10) < tolerance && abs(fresh.ambient - 0.38) < tolerance)
    }

    @Test func zeroTargetsReturnToRestWithinTwoSecondsAtSixtyHertz() {
        for (motion, flashing) in [(false, false), (true, true)] {
            var response = TunnelResponse(reduceMotion: motion, reduceFlashing: flashing)
            for _ in 0..<200 { response.update(rippleTarget: 1, ambientTarget: 1) }
            #expect(abs(response.ripple - response.rippleRange.upperBound) < tolerance)
            #expect(abs(response.ambient - response.ambientRange.upperBound) < tolerance)
            for _ in 0..<120 { response.update(rippleTarget: 0, ambientTarget: 0) }
            #expect(abs(response.ripple - TunnelResponse.restRipple) <= 0.05 * TunnelResponse.restRipple)
            #expect(abs(response.ambient - TunnelResponse.restAmbient) <= 0.05 * TunnelResponse.restAmbient)
        }
    }

    @Test func reduceMotionHalvesTheRippleRange() {
        var response = TunnelResponse(reduceMotion: true, reduceFlashing: false)
        #expect(response.rippleRange == 0...0.175)
        #expect(response.ripple == 0.08)
        #expect(response.ambientRange == 0.30...0.70 && response.ambientStepLimit == 0.03)
        for _ in 0..<100 { response.update(rippleTarget: 1, ambientTarget: 0) }
        #expect(abs(response.ripple - 0.175) < tolerance)
    }

    @Test func reduceFlashingHalvesTheAmbientRangeAndStep() {
        var response = TunnelResponse(reduceMotion: false, reduceFlashing: true)
        #expect(response.ambientRange == 0.30...0.50)
        #expect(response.ambientStepLimit == 0.015)
        #expect(response.rippleRange == 0...0.35 && response.rippleStepLimit == 0.02)
        response.update(rippleTarget: 0, ambientTarget: 1)
        #expect(abs(response.ambient - 0.365) < tolerance)
        for _ in 0..<100 { response.update(rippleTarget: 0, ambientTarget: 1) }
        #expect(abs(response.ambient - 0.50) < tolerance)
    }

    @Test func aNaNTargetCountsAsZero() {
        var response = TunnelResponse(reduceMotion: false, reduceFlashing: false)
        for _ in 0..<30 { response.update(rippleTarget: 1, ambientTarget: 1) }
        for _ in 0..<30 { response.update(rippleTarget: .nan, ambientTarget: .nan) }
        #expect(abs(response.ripple - 0.08) < tolerance)
        #expect(abs(response.ambient - 0.35) < tolerance)
        #expect(!response.ripple.isNaN && !response.ambient.isNaN)
        #expect(TunnelResponse.map(.nan, rest: 0.08, range: 0...0.35) == 0.08)
        #expect(TunnelResponse.map(5, rest: 0.08, range: 0...0.35) == 0.35)
        #expect(TunnelResponse.map(-5, rest: 0.08, range: 0...0.35) == 0.08)
    }

    @Test func theBreathingScaleIsOnePlusHalfTheRipple() {
        var response = TunnelResponse(reduceMotion: false, reduceFlashing: false)
        #expect(abs(response.breathingScale - 1.04) < tolerance)
        for _ in 0..<30 { response.update(rippleTarget: 1, ambientTarget: 0) }
        #expect(abs(response.breathingScale - (1 + 0.35 * 0.5)) < tolerance)
        #expect(abs(response.breathingScale - (1 + response.ripple * TunnelResponse.breathingGain)) < tolerance)
    }
}
