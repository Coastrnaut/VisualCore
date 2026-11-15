// SensitivityTests — feature 078 (A10-P04) T-A10-402 (FR-A10-401; clarification 1; research D1; SC-A10-401). The
// sensitivity steps, host-free and short: five reaches 2.5, 2.0, 1.5, 1.0, 0.6 with default step 2; each step's
// steering for fixed offsets equals offset ÷ reach clamped to −1…1; for one offset the steps are ordered gentle →
// sharp and every value lies within −1…1; steering is symmetric; a non-finite offset gives 0; a step outside 0…4 is
// clamped to the nearest step.
import Foundation
import Testing
import NeonArcadeCore

@Suite struct SensitivityTests {
    @Test func theFiveReachesAndTheDefault() {
        #expect(Sensitivity.reaches == [2.5, 2.0, 1.5, 1.0, 0.6])
        #expect(Sensitivity.defaultStep == 2 && Sensitivity.steps == 0...4)
        #expect(Sensitivity.reach(step: Sensitivity.defaultStep) == 1.5)
    }

    @Test(arguments: [0, 1, 2, 3, 4])
    func eachStepSteersByItsReach(step: Int) {
        let reach = Sensitivity.reaches[step]
        for offset in [0.0, 0.3, -0.3, 0.5, 1.2, -1.2] {
            let expected = min(max(offset / reach, -1), 1)
            #expect(abs(Sensitivity.steering(offset: offset, step: step) - expected) < 1e-12)
        }
        #expect(Sensitivity.steering(offset: reach, step: step) == 1)
        #expect(Sensitivity.steering(offset: -reach, step: step) == -1)
        #expect(Sensitivity.steering(offset: 9, step: step) == 1)
        #expect(Sensitivity.steering(offset: -9, step: step) == -1)
    }

    @Test func oneOffsetIsOrderedGentleToSharpAndBounded() {
        for offset in [0.25, 0.5, 0.55, -0.5] {
            let values = Sensitivity.steps.map { Sensitivity.steering(offset: offset, step: $0) }
            #expect(values.allSatisfy { (-1...1).contains($0) })
            let magnitudes = values.map(abs)
            #expect(zip(magnitudes, magnitudes.dropFirst()).allSatisfy { $0 < $1 })
        }
        // Offset 0.5: 0.2, 0.25, 0.333…, 0.5, 0.833…
        let half = Sensitivity.steps.map { Sensitivity.steering(offset: 0.5, step: $0) }
        #expect(abs(half[0] - 0.2) < 1e-12 && abs(half[1] - 0.25) < 1e-12 && abs(half[3] - 0.5) < 1e-12)
    }

    @Test func nonFiniteOffsetsGiveNoSteering() {
        for offset in [Double.nan, .infinity, -.infinity] {
            #expect(Sensitivity.steering(offset: offset, step: 2) == 0)
        }
    }

    @Test func outOfRangeStepsAreClamped() {
        #expect(Sensitivity.clampedStep(-1) == 0 && Sensitivity.clampedStep(7) == 4 && Sensitivity.clampedStep(3) == 3)
        #expect(Sensitivity.steering(offset: 0.5, step: -5) == Sensitivity.steering(offset: 0.5, step: 0))
        #expect(Sensitivity.steering(offset: 0.5, step: 99) == Sensitivity.steering(offset: 0.5, step: 4))
        #expect(Sensitivity.reach(step: Int.min) == 2.5 && Sensitivity.reach(step: Int.max) == 0.6)
    }
}
