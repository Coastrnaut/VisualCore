// TrailDecayTests — feature 035 A04-P03 T-A04-302 (G-BLENDTRAIL; FR-A04-302; contract C1, C2; research R1, R4).
import Testing
import VisualCoreMath
@testable import VisualCoreSimulation

@Test func factorIsFrameRateIndependent() {
    for s in [0.5, 0.8, 0.95, 0.98] {
        let whole = TrailDecay.factor(strength: s, delta: 1.0 / 30)
        let halves = TrailDecay.factor(strength: s, delta: 1.0 / 60) * TrailDecay.factor(strength: s, delta: 1.0 / 60)
        #expect(abs(whole - halves) < 1e-12)
        #expect(abs(TrailDecay.factor(strength: s, delta: 1.0 / 60) - s) < 1e-12, "s is the fraction kept per 1/60 s")
    }
}

@Test func factorEdgeCases() {
    #expect(TrailDecay.factor(strength: 0, delta: 1.0 / 60) == 0)
    #expect(TrailDecay.factor(strength: 0.9, delta: 0) == 1)
    #expect(TrailDecay.factor(strength: 0.9, delta: -1) == 1)
    #expect(TrailDecay.factor(strength: 0.9, delta: .nan) == 1)
    #expect(TrailDecay.factor(strength: .nan, delta: 1.0 / 60) == 0)
    #expect(TrailDecay.factor(strength: 5, delta: 1.0 / 60) == 0.98, "strength clamped to 0.98")
    #expect(TrailDecay.clampedStrength(-1) == 0 && TrailDecay.clampedStrength(0.5) == 0.5)
}

@Test func step8AlwaysReachesZero() {
    // The −1/255 term guarantees the fade ends: every 8-bit value reaches 0 at the strongest setting and a fast frame.
    let f = TrailDecay.factor(strength: 0.98, delta: 1.0 / 120)
    for start in UInt8(1)...UInt8(255) {
        var v = start, frames = 0
        while v > 0 && frames < 300 { v = TrailDecay.step8(v, factor: f); frames += 1 }
        #expect(v == 0, "value \(start) reached 0")
        #expect(frames <= 255)
    }
    #expect(TrailDecay.step8(200, factor: 1) == 199, "even a factor of 1 loses one level per frame")
    #expect(TrailDecay.step8(10, factor: 0) == 0)
    #expect(TrailDecay.step8(100, factor: 0.5) == 49)
}

@Test func equalElapsedTimeFadesAlikeAtThirtyAndSixtyHertz() {
    // SC-A04-303 model: after 10 frames at 60 Hz versus 5 at 30 Hz, and after 1 s, every start value agrees within
    // 6/255 for every strength (research R1).
    for s in [0.5, 0.8, 0.9, 0.95, 0.98] {
        for frames in [10, 60] {
            for start in UInt8(1)...UInt8(255) {
                var a = start, b = start
                for _ in 0..<frames {
                    a = TrailDecay.step8(a, factor: TrailDecay.factor(strength: s, delta: 1.0 / 60), subtract: TrailDecay.subtraction(delta: 1.0 / 60))
                }
                for _ in 0..<(frames / 2) {
                    b = TrailDecay.step8(b, factor: TrailDecay.factor(strength: s, delta: 1.0 / 30), subtract: TrailDecay.subtraction(delta: 1.0 / 30))
                }
                #expect(abs(Int(a) - Int(b)) <= 6, "s \(s), \(frames) frames, start \(start)")
            }
        }
    }
    #expect(TrailDecay.subtraction(delta: 1.0 / 30) == 2 && TrailDecay.subtraction(delta: 1.0 / 120) == 1)
    #expect(TrailDecay.subtraction(delta: .nan) == 1)
}

@Test func liveCountPerSource() {
    var ps = ParticleSystem(capacity: 500, seed: 3)
    ps.emitters = [Emitter(rate: 0, lifetime: 10...10), Emitter(rate: 0, lifetime: 10...10)]
    ps.burst(30, from: 0)
    ps.burst(12, from: 1)
    ps.step(1.0 / 120)
    #expect(ps.liveCount(source: 0) == 30 && ps.liveCount(source: 1) == 12)
    #expect(ps.liveCount(source: 2) == 0 && ps.liveCount(source: -1) == 0)
}
