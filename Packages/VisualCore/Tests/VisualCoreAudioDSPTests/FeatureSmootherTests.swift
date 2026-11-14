// FeatureSmootherTests — feature 048 (A06-P02) T-A06-203 (FR-A06-204; SC-A06-204): a step reaches 1 − 1/e after the
// attack time and decays to 1/e of the held value after the release time, ± one update interval, at 30 and 120
// updates per second; reset returns to 0; negative elapsed time is treated as 0.
import Foundation
import Testing
@testable import VisualCoreAudioDSP

/// Steps `smoother` towards `target` at `rate` updates per second until `crossed(value)` holds and returns the time
/// of the first update at which it held (at most 5 s).
private func smootherCrossingTime(
    _ smoother: inout FeatureSmoother, target: Float, rate: Double, crossed: (Float) -> Bool
) -> Double? {
    let dt = 1 / rate
    for step in 1...Int(5 * rate) {
        smoother.update(target: target, elapsed: dt)
        if crossed(smoother.value) { return Double(step) * dt }
    }
    return nil
}

@Test(arguments: [30.0, 120.0])
func featureSmootherStepMatchesAttackAndReleaseAtRate(_ rate: Double) throws {
    let attack = 0.1
    let release = 0.4
    let dt = 1 / rate
    var smoother = FeatureSmoother(attack: attack, release: release)

    let rise = Float(1 - exp(-1.0))
    let riseTime = try #require(smootherCrossingTime(&smoother, target: 1, rate: rate) { $0 >= rise })
    #expect(abs(riseTime - attack) <= dt * 1.000_1)

    // Hold the target until the value has settled, then release.
    for _ in 0..<Int(3 * rate) { smoother.update(target: 1, elapsed: dt) }
    let held = smoother.value
    #expect(held > 0.99)
    let fall = held * Float(exp(-1.0))
    let fallTime = try #require(smootherCrossingTime(&smoother, target: 0, rate: rate) { $0 <= fall })
    #expect(abs(fallTime - release) <= dt * 1.000_1)
}

@Test func featureSmootherResetReturnsToZero() {
    var smoother = FeatureSmoother(attack: 0.1, release: 0.4)
    smoother.update(target: 1, elapsed: 0.5)
    #expect(smoother.value > 0)
    smoother.reset()
    #expect(smoother.value == 0)
    #expect(smoother == FeatureSmoother(attack: 0.1, release: 0.4))
}

@Test func featureSmootherIgnoresNegativeAndNonFiniteElapsed() {
    var smoother = FeatureSmoother(attack: 0.1, release: 0.4)
    smoother.update(target: 1, elapsed: 0.05)
    let before = smoother.value
    let result1 = smoother.update(target: 0, elapsed: -1)
    #expect(result1 == before)
    let result2 = smoother.update(target: 0, elapsed: .nan)
    #expect(result2 == before)
    let result3 = smoother.update(target: 0, elapsed: .infinity)
    #expect(result3 == before)
    #expect(smoother.value == before)
}

@Test func featureSmootherTreatsNonFiniteTargetAsZeroAndClampsTimeConstants() {
    var smoother = FeatureSmoother(attack: 0, release: -1)
    #expect(smoother.attack == FeatureSmoother.minimumTimeConstant)
    #expect(smoother.release == FeatureSmoother.minimumTimeConstant)
    smoother.update(target: 1, elapsed: 0.01)
    #expect(smoother.value == 1)
    smoother.update(target: .nan, elapsed: 0.01)
    #expect(smoother.value == 0)
}
