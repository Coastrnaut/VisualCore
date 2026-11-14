// RailFlightTests — feature 054 (A07-P01) T-A07-102 (FR-A07-102, FR-A07-104; SC-A07-102).
import Foundation
import Testing
@testable import VisualCoreMath

@Suite struct RailFlightTests {
    @Test func limitValues() {
        let s = ComfortLimits.standard, r = ComfortLimits.reducedMotion
        #expect(s == ComfortLimits(maxSpeed: 8, maxAcceleration: 1.5, maxTurnRate: .pi / 4, swayAmplitude: 0.25,
                                   maxRoll: 0))
        #expect(r == ComfortLimits(maxSpeed: 2.5, maxAcceleration: 0.75, maxTurnRate: .pi / 4, swayAmplitude: 0,
                                   maxRoll: 0))
        #expect(RailFlight.maxStep == 0.1)
    }

    @Test func seededSequencesNeverExceedSpeedOrAcceleration() {
        var rng = RailTestLCG(seed: 54)
        for seq in 0..<200 {
            let limits = seq % 2 == 0 ? ComfortLimits.standard : .reducedMotion
            let start = rng.range(0, 12)
            var f = RailFlight(distance: rng.range(0, 100), speed: start, targetSpeed: rng.range(0, 12))
            for _ in 0..<100 {
                if rng.next() < 0.1 { f.targetSpeed = rng.range(-2, 15) }
                if rng.next() < 0.05 { f.paused.toggle() }
                let dt = rng.range(0, 0.25)
                let before = f
                f.advance(by: dt, limits: limits)
                #expect(f.speed <= max(limits.maxSpeed, start) + 1e-12, "seq \(seq)")
                #expect(abs(f.speed - before.speed) <= limits.maxAcceleration * min(dt, RailFlight.maxStep) + 1e-12)
                #expect(f.distance >= before.distance)
                #expect(f.speed >= 0)
            }
        }
    }

    @Test func reducedMotionHasNoSwayAndCapsSpeed() {
        let r = ComfortLimits.reducedMotion
        var f = RailFlight(targetSpeed: 20)
        for _ in 0..<600 {
            f.advance(by: 1.0 / 60, limits: r)
            #expect(f.speed <= 2.5)
            #expect(f.sway(limits: r) == 0)
        }
        #expect(f.speed == 2.5)
    }

    @Test func swayFollowsDistance() {
        let s = ComfortLimits.standard
        #expect(RailFlight(distance: 10).sway(limits: s) == 0.25 * sin(2 * .pi * 10 / 40))
        #expect(abs(RailFlight(distance: 10).sway(limits: s) - 0.25) < 1e-12)
    }

    @Test func invalidTimeStepsChangeNothing() {
        let start = RailFlight(distance: 5, speed: 2, targetSpeed: 6)
        for dt in [Double.nan, -.infinity, .infinity, -0.5, 0, -0.0] {
            var f = start
            f.advance(by: dt, limits: .standard)
            #expect(f == start, "dt \(dt)")
        }
    }

    @Test func largeStepsAreCapped() {
        var a = RailFlight(targetSpeed: 8), b = a
        a.advance(by: 5, limits: .standard)
        b.advance(by: RailFlight.maxStep, limits: .standard)
        #expect(a == b)
    }

    @Test func sameInputsGiveSameStates() {
        func run() -> RailFlight {
            var rng = RailTestLCG(seed: 99)
            var f = RailFlight(targetSpeed: 6)
            for _ in 0..<500 { f.advance(by: rng.range(0, 0.05), limits: .standard) }
            return f
        }
        #expect(run() == run())
    }

    @Test func pauseEasesToZeroAndResumeEasesBack() {
        var f = RailFlight(speed: 6, targetSpeed: 6)
        f.paused = true
        var last = f.speed
        for _ in 0..<60 {
            f.advance(by: 0.1, limits: .standard)
            #expect(f.speed <= last)
            #expect(last - f.speed <= 0.15 + 1e-12)
            last = f.speed
        }
        #expect(f.speed == 0)
        let parked = f.distance
        f.advance(by: 0.1, limits: .standard)
        #expect(f.distance == parked)
        f.paused = false
        f.advance(by: 0.1, limits: .standard)
        #expect(f.speed > 0 && f.speed <= 0.15 + 1e-12)
    }

    @Test func overspeedDeceleratesGradually() {
        var f = RailFlight(speed: 8, targetSpeed: 8)
        f.advance(by: 0.1, limits: .reducedMotion)
        #expect(abs(f.speed - 7.925) < 1e-12)
    }

    @Test func codableRoundTrip() throws {
        let f = RailFlight(distance: 12.5, speed: 3, targetSpeed: 4, paused: true)
        let back = try JSONDecoder().decode(RailFlight.self, from: JSONEncoder().encode(f))
        #expect(back == f)
        let l = try JSONDecoder().decode(ComfortLimits.self, from: JSONEncoder().encode(ComfortLimits.standard))
        #expect(l == .standard)
    }
}
