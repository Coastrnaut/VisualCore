// WorldResponseTests — feature 056 (A07-P03) T-A07-302 (FR-A07-311; SC-A07-304; clarification 4; data-model
// "WorldResponse"). The audio response of every world, host-free and short: per-world rest, bounds and steps, the
// comfort flags, bounds and step limits under random targets, the return to rest, NaN targets, the tunnel's equality
// with `TunnelResponse`, the primary scales and a channel pulse that raises only the responses mapped to it.
import Foundation
import Testing
import AudioOdysseyCore

@Suite struct WorldResponseTests {
    /// A small seeded linear congruential generator for reproducible targets in 0…1 (with some outside values).
    private struct LCG {
        var state: UInt64
        mutating func next() -> Double {
            state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            return Double(state >> 11) / Double(1 << 53) * 1.4 - 0.2
        }
    }

    private let tolerance = 1e-12

    @Test func restBoundsAndStepsPerWorld() {
        let expected: [(JourneyWorld, max: Double, rest: Double)] = [(.tunnel, 0.35, 0.08), (.landscape, 0.6, 0.1),
                                                                      (.starCorridor, 1.0, 0.1)]
        for (world, max, rest) in expected {
            let response = WorldResponse(world: world, reduceMotion: false, reduceFlashing: false)
            #expect(response.primaryRange == 0...max)
            #expect(response.primary == rest && response.primaryRest == rest)
            #expect(abs(response.primaryStepLimit - 0.02 * max / 0.35) < tolerance)
            #expect(response.lightRange == 0.30...0.70 && response.light == 0.35 && response.lightStepLimit == 0.03)
            let calm = WorldResponse(world: world, reduceMotion: true, reduceFlashing: true)
            #expect(calm.primaryRange == 0...(max / 2))
            #expect(calm.primaryStepLimit == response.primaryStepLimit)
            #expect(calm.lightRange == 0.30...0.50 && calm.lightStepLimit == 0.015)
            #expect(calm.primary == min(rest, max / 2) && calm.light == 0.35)
        }
        #expect(WorldResponse.primaryStep(for: .tunnel) == 0.02)
    }

    @Test func boundsAndStepLimitsHoldForRandomTargets() {
        for world in JourneyWorld.allCases {
            for (motion, flashing) in [(false, false), (true, false), (false, true), (true, true)] {
                var response = WorldResponse(world: world, reduceMotion: motion, reduceFlashing: flashing)
                var random = LCG(state: 0xA07_302 &+ UInt64(world.rawValue))
                for _ in 0..<500 {
                    let before = response
                    response.update(primaryTarget: random.next(), lightTarget: random.next())
                    #expect(response.primaryRange.contains(response.primary))
                    #expect(response.lightRange.contains(response.light))
                    #expect(abs(response.primary - before.primary) <= response.primaryStepLimit + tolerance)
                    #expect(abs(response.light - before.light) <= response.lightStepLimit + tolerance)
                }
            }
        }
    }

    @Test func fullTargetsReachTheUpperBoundsAndSilenceReturnsToRest() {
        for world in JourneyWorld.allCases {
            var response = WorldResponse(world: world, reduceMotion: false, reduceFlashing: false)
            for _ in 0..<100 { response.update(primaryTarget: 1, lightTarget: 1) }
            #expect(abs(response.primary - response.primaryRange.upperBound) < tolerance)
            #expect(abs(response.light - 0.70) < tolerance)
            for _ in 0..<100 { response.update(primaryTarget: .nan, lightTarget: 0) }
            #expect(abs(response.primary - response.primaryRest) < tolerance)
            #expect(abs(response.light - response.lightRest) < tolerance)
        }
    }

    @Test func theTunnelCaseEqualsTunnelResponse() {
        for (motion, flashing) in [(false, false), (true, true)] {
            var world = WorldResponse(world: .tunnel, reduceMotion: motion, reduceFlashing: flashing)
            var tunnel = TunnelResponse(reduceMotion: motion, reduceFlashing: flashing)
            var random = LCG(state: 0x7E57)
            for _ in 0..<300 {
                let a = random.next(), b = random.next()
                world.update(primaryTarget: a, lightTarget: b)
                tunnel.update(rippleTarget: a, ambientTarget: b)
                #expect(world.primary == tunnel.ripple && world.light == tunnel.ambient)
                #expect(world.primaryScale == tunnel.breathingScale)
            }
        }
    }

    @Test func primaryScalesFollowTheClarification() {
        var landscape = WorldResponse(world: .landscape, reduceMotion: false, reduceFlashing: false)
        var stars = WorldResponse(world: .starCorridor, reduceMotion: false, reduceFlashing: false)
        for _ in 0..<100 {
            landscape.update(primaryTarget: 1, lightTarget: 0)
            stars.update(primaryTarget: 1, lightTarget: 0)
        }
        #expect(abs(landscape.primaryScale - 1.6) < tolerance)
        #expect(abs(stars.primaryScale - 1.6) < tolerance)
    }

    @Test func aChannelPulseRaisesOnlyTheResponsesMappedToIt() {
        var bands = [Float](repeating: 0, count: 16)
        bands[1] = 1
        var envelope = AudioEnvelope()
        for i in 0..<30 {
            envelope.update(bandEnergies: bands, flux: 0, onset: false, time: Double(i) / 60, elapsed: 1.0 / 60)
        }
        let lowOnly = WorldMapping(primary: ChannelMapping(channel: .low), light: ChannelMapping(channel: .high))
        for world in JourneyWorld.allCases {
            var mapped = WorldResponse(world: world, reduceMotion: false, reduceFlashing: false)
            var defaults = mapped
            for _ in 0..<10 {
                let a = lowOnly.target(from: envelope)
                mapped.update(primaryTarget: a.primary, lightTarget: a.light)
                let b = WorldMapping.defaults(for: world).target(from: envelope)
                defaults.update(primaryTarget: b.primary, lightTarget: b.light)
            }
            #expect(mapped.primary > mapped.primaryRest)
            #expect(mapped.light == mapped.lightRest)
            #expect((defaults.primary > defaults.primaryRest) == (world == .tunnel))
            #expect(defaults.light > defaults.lightRest)
        }
    }
}
