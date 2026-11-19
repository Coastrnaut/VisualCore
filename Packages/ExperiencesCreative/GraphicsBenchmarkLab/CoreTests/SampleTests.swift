// SampleTests — feature 173 (A24-P01) T-A24-105 (FR-A24-102; SC-A24-103; clarification Q3). A well-formed sample set
// (warm-up, measurement, cool-down; the first interval absent; durations at 0 and 1,000 ms) validates; NaN, infinity,
// negative and over-1,000 ms durations are refused naming the frame and the field; an absent interval after the first
// sample is refused; indices that do not increase, a negative index and a phase that goes back are refused as out of
// order; 20,000 samples are accepted and 20,001 refused. The phases are ordered warm-up, measurement, cool-down.
// Synthetic data only.
import Foundation
import Testing
@testable import GraphicsBenchmarkLabCore

@Suite struct SampleTests {
    /// The refusal of `samples`, or nil when they validate.
    private static func refusal(_ samples: [FrameSample]) -> SampleError? {
        do {
            try SampleSet.validate(samples)
            return nil
        } catch {
            return error
        }
    }

    /// Two warm-up, three measured and one cool-down sample, frames 0…5, the first without an interval.
    private static func valid() -> [FrameSample] {
        [
            FrameSample(frameIndex: 0, phase: .warmUp, intervalMs: nil, cpuMs: 2.5),
            FrameSample(frameIndex: 1, phase: .warmUp, intervalMs: 16.7, cpuMs: 2.25),
            FrameSample(frameIndex: 2, phase: .measure, intervalMs: 16.6, cpuMs: 0, gpuMs: 4.5),
            FrameSample(frameIndex: 3, phase: .measure, intervalMs: 33.3, cpuMs: 3, gpuMs: 1_000, dropped: true),
            FrameSample(frameIndex: 5, phase: .measure, intervalMs: 1_000, cpuMs: 1_000),
            FrameSample(frameIndex: 6, phase: .coolDown, intervalMs: 0, cpuMs: 1.5),
        ]
    }

    @Test func phaseOrder() {
        #expect(RunPhase.warmUp < RunPhase.measure)
        #expect(RunPhase.measure < RunPhase.coolDown)
        let sorted = [RunPhase.coolDown, .warmUp, .measure].sorted()
        #expect(sorted == [.warmUp, .measure, .coolDown])
    }

    @Test func validSetsAccepted() {
        let error = Self.refusal(Self.valid())
        #expect(error == nil)
        let empty = Self.refusal([])
        #expect(empty == nil)
    }

    @Test func nonFiniteDurationsNameFrameAndField() {
        let fields = ["intervalMs", "cpuMs", "gpuMs"]
        for field in fields {
            for bad in [Double.nan, Double.infinity, -Double.infinity] {
                var samples = Self.valid()
                switch field {
                case "intervalMs": samples[3].intervalMs = bad
                case "cpuMs": samples[3].cpuMs = bad
                default: samples[3].gpuMs = bad
                }
                let error = Self.refusal(samples)
                #expect(error == .notFinite(frame: 3, field: field))
            }
        }
    }

    @Test func durationsOutsideTheirRangeNameFrameAndField() {
        let fields = ["intervalMs", "cpuMs", "gpuMs"]
        for field in fields {
            for bad in [-0.001, 1_000.001] {
                var samples = Self.valid()
                switch field {
                case "intervalMs": samples[2].intervalMs = bad
                case "cpuMs": samples[2].cpuMs = bad
                default: samples[2].gpuMs = bad
                }
                let error = Self.refusal(samples)
                #expect(error == .outOfRange(frame: 2, field: field))
            }
        }
    }

    @Test func absentIntervalOnlyOnTheFirstSample() {
        var samples = Self.valid()
        samples[4].intervalMs = nil
        let error = Self.refusal(samples)
        #expect(error == .outOfRange(frame: 5, field: "intervalMs"))
    }

    @Test func outOfOrderRefused() {
        var repeated = Self.valid()
        repeated[2].frameIndex = 1
        let repeatedError = Self.refusal(repeated)
        #expect(repeatedError == .outOfOrder(frame: 1))
        var backwards = Self.valid()
        backwards[4].frameIndex = 2
        let backwardsError = Self.refusal(backwards)
        #expect(backwardsError == .outOfOrder(frame: 2))
        var negative = Self.valid()
        negative[0].frameIndex = -1
        let negativeError = Self.refusal(negative)
        #expect(negativeError == .outOfOrder(frame: -1))
        var phase = Self.valid()
        phase[4].phase = .warmUp
        let phaseError = Self.refusal(phase)
        #expect(phaseError == .outOfOrder(frame: 5))
    }

    @Test func sampleCountCap() {
        var samples: [FrameSample] = []
        samples.reserveCapacity(SampleLimits.maxSamples + 1)
        for index in 0..<SampleLimits.maxSamples {
            samples.append(FrameSample(frameIndex: index, phase: .measure, intervalMs: index == 0 ? nil : 8.3,
                                       cpuMs: 1))
        }
        let atCap = Self.refusal(samples)
        #expect(atCap == nil)
        samples.append(FrameSample(frameIndex: SampleLimits.maxSamples, phase: .measure, intervalMs: 8.3, cpuMs: 1))
        let pastCap = Self.refusal(samples)
        #expect(pastCap == .tooManySamples(count: 20_001))
    }

    @Test func limits() {
        #expect(SampleLimits.maxSamples == 20_000)
        #expect(SampleLimits.maxDurationMs == 1_000)
    }
}
